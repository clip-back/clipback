import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_navigation.dart';
import 'fixtures/weekly_server.dart';
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;

// Frozen current-behavior checks for the home weekly recommendation visit
// (#294 W1–W9, W8′). Only server requests, visible widgets and HomeScreen
// arguments/callbacks are asserted; app root private state is never read.

const _weeklyPath = '/api/v1/recommendations/weekly';
const _exposurePath = '/api/v1/recommendations/exposures';
const _refreshPath = '/api/v1/auth/refresh';
const _failure = '이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.';

/// A height that keeps both weekly cards below the fold, so no exposure is
/// recorded automatically and a direct callback call is the only source.
const _cardsBelowFold = Size(393, 300);
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Every request the real app sent, logged on arrival before any fake delay.
class _Log {
  final requests = <http.Request>[];
  Iterable<http.Request> get weeklyGets =>
      requests.where((r) => r.method == 'GET' && r.url.path == _weeklyPath);
  Iterable<http.Request> get refreshes =>
      requests.where((r) => r.url.path == _refreshPath);
  Iterable<http.Request> get exposureRequests =>
      requests.where((r) => r.url.path == _exposurePath);
  List<Map<String, dynamic>> get exposures => [
    for (final r in exposureRequests)
      jsonDecode(r.body) as Map<String, dynamic>,
  ];
  List<int> get exposedItems => [
    for (final body in exposures) body['recommendation_item_id'] as int,
  ];

  /// Exposure UUIDs vary per run: presence and format first, then identity.
  List<String> exposureIds() {
    final ids = <String>[];
    for (final body in exposures) {
      expect(body.containsKey('client_event_id'), isTrue);
      final id = body['client_event_id'];
      expect(id, isA<String>());
      expect(id, matches(_uuid));
      ids.add(id as String);
    }
    return ids;
  }
}

typedef _Intercept =
    Future<http.Response?> Function(
      WeeklyServer server,
      http.Request request,
      Future<http.Response> Function() forward,
    );

/// The real [ClipbackApp] (real ClipbackApi and RemoteContentRepository) on
/// the [WeeklyServer] fake, as in weekly_root_test's withHome.
Future<void> _withApp(
  WidgetTester t,
  Future<void> Function(WeeklyServer, _Log) check, {
  _Intercept? intercept,
  void Function(WeeklyServer)? setup,
  bool startup = true,
  Size size = const Size(393, 852),
}) async {
  final server = WeeklyServer();
  final log = _Log();
  setup?.call(server);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = MockClient((request) async {
    log.requests.add(request);
    Future<http.Response> forward() {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return server.weeklyClient.send(copy).then(http.Response.fromStream);
    }

    return await intercept?.call(server, request, forward) ?? await forward();
  });
  await http.runWithClient(() async {
    try {
      await t.pumpWidget(
        ClipbackApp(
          sessionStorage: isolated.ArchiveAllMemoryStorage(),
          socialAuth: isolated.ArchiveAllSocialAuth(),
        ),
      );
      if (startup) await completeAppStartup(t);
      await check(server, log);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  }, () => client);
}

/// #379: the app start loads the weekly visit before home is shown, so a test
/// that holds a home visit's first GET starts that visit by a new login
/// (logout, then guest), whose first GET still follows home's first frame.
Future<void> _logout(WidgetTester t) async {
  _home(t).onTab(AppRoute.my);
  await t.pumpAndSettle();
  t.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
  await t.pumpAndSettle();
  await logoutFromAccount(t);
  await t.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
}

/// Logs out, restarts the request log at the new login (counts and item IDs
/// read as from the app start before) and logs in as a guest, the first GET
/// held by [hold] and answered in [mode].
Future<void> _newLogin(
  WidgetTester t,
  WeeklyServer s,
  _Log log, {
  Completer<void>? hold,
  String? mode,
}) async {
  await _logout(t);
  log.requests.clear();
  s.batch = 800;
  if (mode != null) s.weeklyMode = mode;
  s.weeklyPending = hold;
  await startGuestAndFinishOnboarding(t);
  expect(find.byType(HomeScreen), findsOneWidget);
}

HomeScreen _home(WidgetTester t) =>
    t.widget<HomeScreen>(find.byType(HomeScreen));
Finder get _message => find.text(_failure);
Finder _card(int id) => find.byKey(ValueKey('weekly-card-$id'));
List<int> _items(WidgetTester t) =>
    _home(t).weeklyItems.map((item) => item.id).toList();

void _openSaveSheet(WidgetTester t) => t
    .widget<ClipbackNavigationBar>(find.byType(ClipbackNavigationBar))
    .onAdd!();

void _background(WidgetTester t) =>
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
void _foreground(WidgetTester t) =>
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

/// Taps the one visible notice's [다시 시도]; a duplicate notice queued behind
/// it would surface afterwards and fail the caller's next findsNothing.
Future<void> _retryFromNotice(WidgetTester t) async {
  await t.tap(find.text('다시 시도'));
  await t.pumpAndSettle();
}

typedef _AfterRemoval = ({
  int newRequests,
  int newExposures,
  int messages,
  Object? exception,
});
const _AfterRemoval _quietAfterRemoval = (
  newRequests: 0,
  newExposures: 0,
  messages: 0,
  exception: null,
);

/// Observations after the app was replaced; uncaught async errors would fail
/// the test through the testWidgets zone before these are compared.
_AfterRemoval _observeAfterRemoval(
  WidgetTester t,
  _Log log, {
  required int requests,
  required int exposures,
}) => (
  newRequests: log.requests.length - requests,
  newExposures: log.exposures.length - exposures,
  messages: _message.evaluate().length,
  exception: t.takeException(),
);

Future<void> _removeApp(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  expect(find.byType(ClipbackApp), findsNothing);
}

void main() {
  group('W1 deferred failure notice', () {
    testWidgets(
      'W1a failure behind the save sheet shows once after the close transition',
      (t) async {
        final pending = Completer<void>();
        await _withApp(t, (s, log) async {
          await _newLogin(t, s, log, hold: pending, mode: 'error');
          _openSaveSheet(t);
          await t.pumpAndSettle();
          pending.complete();
          await t.pumpAndSettle();
          expect(log.weeklyGets, hasLength(1));
          expect(_message, findsNothing);

          final context = t.element(find.byType(SaveContentTopBar));
          final route = ModalRoute.of(context)! as TransitionRoute<dynamic>;
          var closed = false;
          unawaited(route.completed.then((_) => closed = true));
          Navigator.of(context).pop();
          // Until the close transition completes, every frame is silent.
          var frames = 0;
          expect(_message, findsNothing);
          while (!closed) {
            await t.pump();
            frames++;
            expect(_message, findsNothing);
            expect(frames, lessThan(60));
          }
          expect(_message, findsNothing);

          // After the transition ended: exactly one notice.
          await t.pumpAndSettle();
          expect(_message, findsOneWidget);
          expect(find.byType(SnackBarAction), findsOneWidget);
          s.weeklyMode = 'empty';
          await _retryFromNotice(t);
          expect(log.weeklyGets, hasLength(2));
          expect(_message, findsNothing);
        });
      },
    );

    testWidgets(
      'W1b failure in background shows once on resume; its retry adds one GET',
      (t) async {
        final pending = Completer<void>();
        await _withApp(
          t,
          (s, log) async {
            _background(t);
            await t.pumpAndSettle();
            pending.complete();
            await t.pumpAndSettle();
            expect(log.weeklyGets, hasLength(1));
            expect(_message, findsNothing);

            _foreground(t);
            await t.pumpAndSettle();
            expect(_message, findsOneWidget);
            s.weeklyMode = 'empty';
            await _retryFromNotice(t);
            expect(log.weeklyGets, hasLength(2));
            expect(_message, findsNothing);
          },
          setup: (s) => s
            ..weeklyMode = 'error'
            ..weeklyPending = pending,
        );
      },
    );
  });

  testWidgets(
    'W2 account A response after logout and account B home is ignored',
    (t) async {
      final aGate = Completer<void>();
      const aToken = 'Bearer fixture-access', bToken = 'Bearer b-access';
      Completer<void>? hold;
      var guests = 0;
      await _withApp(
        t,
        (s, log) async {
          // Account A is a new login (its first GET follows home's frame).
          await _logout(t);
          log.requests.clear();
          s.batch = 800;
          hold = aGate;
          await startGuestAndFinishOnboarding(t);
          expect(log.weeklyGets.single.headers['Authorization'], aToken);
          expect(_items(t), isEmpty);

          _home(t).onTab(AppRoute.my);
          await t.pumpAndSettle();
          t.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
          await t.pumpAndSettle();
          await logoutFromAccount(t);
          await t.pumpAndSettle();
          expect(find.byType(LoginScreen), findsOneWidget);
          await startGuestAndFinishOnboarding(t);
          await t.pumpAndSettle();
          expect(find.byType(HomeScreen), findsOneWidget);

          final bGets = log.weeklyGets.where(
            (r) => r.headers['Authorization'] == bToken,
          );
          expect(bGets, hasLength(1));
          expect(log.weeklyGets, hasLength(2));
          final bItems = _items(t);
          expect(bItems, hasLength(2));
          final bExposures = log.exposures.length;
          expect(log.exposedItems.toSet(), bItems.toSet());

          // Account A's response arrives only after account B's home is shown.
          aGate.complete();
          await t.pumpAndSettle();
          expect(_items(t), bItems);
          expect(_card(8011), findsNothing);
          expect(_card(8012), findsNothing);
          expect(log.exposures, hasLength(bExposures));
          expect(log.exposedItems, isNot(contains(8011)));
          expect(log.exposedItems, isNot(contains(8012)));
          expect(
            log.exposureRequests.map((r) => r.headers['Authorization']),
            everyElement(bToken),
          );
          expect(bGets, hasLength(1));
          expect(_message, findsNothing);
        },
        intercept: (s, request, forward) async {
          switch (request.url.path) {
            case '/api/v1/auth/logout':
              return http.Response('', 204);
            case '/api/v1/auth/guest' when guests++ > 0:
              return s.json({
                'access_token': 'b-access',
                'refresh_token': 'b-refresh',
                'expires_in': 3600,
                'refresh_expires_in': 86400,
              }, 201);
            case _weeklyPath when hold != null:
              // Account A: batch 801 (items 8011, 8012), held until later.
              final gate = hold!;
              hold = null;
              final response = await forward();
              await gate.future;
              return response;
          }
          return null;
        },
      );
    },
  );

  testWidgets(
    'W3 background failure then another tab: same visit, deferred notice once on home, retry adds one GET',
    (t) async {
      final pending = Completer<void>();
      await _withApp(t, (s, log) async {
        await _newLogin(t, s, log, hold: pending, mode: 'error');
        _background(t);
        await t.pumpAndSettle();
        pending.complete();
        await t.pumpAndSettle();
        expect(_message, findsNothing);

        _home(t).onTab(AppRoute.my);
        await t.pumpAndSettle();
        _foreground(t);
        await t.pumpAndSettle();
        expect(find.byType(MyScreen), findsOneWidget);
        expect(_message, findsNothing);
        expect(log.weeklyGets, hasLength(1));

        s.weeklyMode = 'normal';
        t.widget<MyScreen>(find.byType(MyScreen)).onTab(AppRoute.home);
        await t.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(log.weeklyGets, hasLength(1));
        expect(_items(t), isEmpty);
        expect(_message, findsOneWidget);
        await _retryFromNotice(t);
        expect(log.weeklyGets, hasLength(2));
        expect(_items(t), hasLength(2));
        expect(_message, findsNothing);
      });
    },
  );

  testWidgets(
    'W4 one weekly GET during splash; the first home frame already has the cards',
    (t) async {
      await _withApp(t, (s, log) async {
        await t.pump();
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(log.weeklyGets, hasLength(1));

        // Just before launch readiness (the splash lasts 900ms).
        await t.pump(const Duration(milliseconds: 899));
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(log.weeklyGets, hasLength(1));

        // Splash done and home mounted with the cards in its first frame.
        await t.pump(const Duration(milliseconds: 1));
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(_items(t), hasLength(2));

        await t.pump();
        expect(log.weeklyGets, hasLength(1));
        await t.pumpAndSettle();
        expect(log.weeklyGets, hasLength(1));
        expect(_items(t), hasLength(2));
      }, startup: false);
    },
  );

  testWidgets(
    'W5 old home callbacks called on the new home visit record and open nothing',
    (t) async {
      await _withApp(t, (s, log) async {
        final old = _home(t);
        final oldItems = _items(t);
        expect(oldItems, [8011, 8012]);
        expect(log.exposures, isEmpty);

        // An account change starts the new visit (leaving home keeps one).
        // The login screens get a full-height view; the new home is shown at
        // the short height again, so no exposure is recorded automatically.
        t.view.physicalSize = const Size(393, 852);
        old.onTab(AppRoute.my);
        await t.pumpAndSettle();
        t.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
        await t.pumpAndSettle();
        await logoutFromAccount(t);
        await t.pumpAndSettle();
        // The new visit's response repeats the same item IDs.
        s.batch = 800;
        await performLoginChoice(
          t,
          t.widget<LoginScreen>(find.byType(LoginScreen)).onContinue,
        );
        await t.pumpAndSettle();
        t.widget<OnboardingScreen>(find.byType(OnboardingScreen)).onDone();
        await t.pumpAndSettle();
        t.view.physicalSize = _cardsBelowFold;
        await completeInterestSelection(t);
        await t.pumpAndSettle();
        expect(log.weeklyGets, hasLength(2));
        expect(_items(t), oldItems);
        expect(identical(_home(t).weeklyItems, old.weeklyItems), isFalse);

        // Called on home, not on another screen.
        old.onWeeklyExposed!(oldItems.first);
        old.onWeeklySelected!(old.weeklyItems.first);
        await t.pumpAndSettle();
        expect(log.exposures, isEmpty);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(ArchiveScreen), findsNothing);

        // Control: the same calls through the current home take effect.
        _home(t).onWeeklyExposed!(oldItems.first);
        await t.pumpAndSettle();
        expect(log.exposedItems, [oldItems.first]);
        expect(log.exposureIds(), hasLength(1));
        _home(t).onWeeklySelected!(_home(t).weeklyItems.first);
        await t.pumpAndSettle();
        expect(find.byType(ArchiveScreen), findsOneWidget);
      }, size: _cardsBelowFold);
    },
  );

  testWidgets(
    'W6 exposure called right after the sheet push, before a frame, records nothing',
    (t) async {
      await _withApp(t, (s, log) async {
        final h = _home(t);
        expect(_items(t), [8011, 8012]);
        expect(h.weeklyExposureEnabled, isTrue);
        expect(log.exposures, isEmpty);

        _openSaveSheet(t);
        h.onWeeklyExposed!(8011);
        await t.pumpAndSettle();
        expect(find.byType(SaveContentTopBar), findsOneWidget);
        expect(log.exposures, isEmpty);

        // Control: the same visit records once the sheet has closed.
        Navigator.of(t.element(find.byType(SaveContentTopBar))).pop();
        await t.pumpAndSettle();
        _home(t).onWeeklyExposed!(8011);
        await t.pumpAndSettle();
        expect(log.exposedItems, [8011]);
        expect(log.exposureIds(), hasLength(1));
        expect(log.weeklyGets, hasLength(1));
      }, size: _cardsBelowFold);
    },
  );

  testWidgets(
    'W7 GET 401, refresh success, replayed GET 200 keeps the same visit',
    (t) async {
      var weeklyGets = 0;
      await _withApp(
        t,
        (s, log) async {
          expect(log.weeklyGets, hasLength(2));
          expect(log.refreshes, hasLength(1));
          expect(
            log.weeklyGets.map((r) => r.headers['Authorization']).toList(),
            ['Bearer fixture-access', 'Bearer rotated-access'],
          );
          expect(_items(t), hasLength(2));
          for (final id in _items(t)) {
            expect(_card(id), findsOneWidget);
          }
          expect(_message, findsNothing);
          expect(log.exposedItems..sort(), [..._items(t)]..sort());
          final ids = log.exposureIds();
          expect(ids, hasLength(2));
          expect(ids.toSet(), hasLength(2));

          // Scrolling and rebuilding the same visit adds no exposure.
          final scroll = find.byKey(const ValueKey('home-scroll'));
          await t.drag(scroll, const Offset(0, -400));
          await t.pumpAndSettle();
          await t.drag(scroll, const Offset(0, 400));
          await t.pumpAndSettle();
          expect(log.exposures, hasLength(2));
          expect(log.weeklyGets, hasLength(2));
        },
        intercept: (s, request, forward) async {
          if (request.url.path == _refreshPath) {
            return s.json({
              'access_token': 'rotated-access',
              'refresh_token': 'rotated-refresh',
              'expires_in': 3600,
              'refresh_expires_in': 86400,
            }, 201);
          }
          if (request.url.path == _weeklyPath && weeklyGets++ == 0) {
            return s.json({'detail': 'expired'}, 401);
          }
          return null;
        },
      );
    },
  );

  group('W8 app removed while the weekly GET is pending', () {
    for (final success in [true, false]) {
      testWidgets(
        'W8${success ? 'a success' : 'b failure'} completed after removal changes nothing',
        (t) async {
          final pending = Completer<void>();
          await _withApp(t, (s, log) async {
            await _newLogin(t, s, log, hold: pending);
            expect(log.weeklyGets, hasLength(1));
            expect(_items(t), isEmpty);
            final requests = log.requests.length;

            await _removeApp(t);
            if (!success) s.weeklyMode = 'error';
            pending.complete();
            await t.pumpAndSettle();
            expect(
              _observeAfterRemoval(t, log, requests: requests, exposures: 0),
              _quietAfterRemoval,
            );
            expect(log.exposures, isEmpty);
          });
        },
      );
    }

    testWidgets(
      'W8′ success completed before removal shows cards; after removal same as W8a',
      (t) async {
        final pending = Completer<void>();
        await _withApp(t, (s, log) async {
          await _newLogin(t, s, log, hold: pending);
          expect(_items(t), isEmpty);
          pending.complete();
          await t.pumpAndSettle();
          expect(_items(t), [8011, 8012]);
          expect(_card(8011), findsOneWidget);
          expect(_card(8012), findsOneWidget);
          expect(log.exposedItems, [8011, 8012]);
          expect(log.exposureIds(), hasLength(2));
          final requests = log.requests.length;

          await _removeApp(t);
          await t.pumpAndSettle();
          expect(
            _observeAfterRemoval(t, log, requests: requests, exposures: 2),
            _quietAfterRemoval,
          );
          expect(log.weeklyGets, hasLength(1));
        });
      },
    );
  });

  /// Steps a new login up to its last tap ('다음' on interests). The tap
  /// selects home synchronously: the new visit and its first load are
  /// scheduled, and no frame has been drawn yet.
  Future<void> tapIntoNewLoginHome(WidgetTester t, _Log log) async {
    await _logout(t);
    log.requests.clear();
    await performLoginChoice(
      t,
      t.widget<LoginScreen>(find.byType(LoginScreen)).onContinue,
    );
    await t.pumpAndSettle();
    t.widget<OnboardingScreen>(find.byType(OnboardingScreen)).onDone();
    await t.pumpAndSettle();
    await t.tap(find.byType(InterestOptionTile).first);
    await t.pump();
    expect(find.byType(InterestSelectionScreen), findsOneWidget);
    expect(log.weeklyGets, isEmpty);
    await t.tap(find.text('다음'));
    // No frame since the tap: home is chosen but not drawn yet.
    expect(find.byType(InterestSelectionScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(t.binding.hasScheduledFrame, isTrue);
  }

  testWidgets(
    'W9 app removed while the first load waits for the next frame sends no GET',
    (t) async {
      await _withApp(t, (s, log) async {
        // A new login keeps the gap the app start had before #379.
        await tapIntoNewLoginHome(t, log);
        expect(log.weeklyGets, isEmpty);
        final requests = log.requests.length;

        await _removeApp(t);
        await t.pump();
        await t.pumpAndSettle();
        expect(
          _observeAfterRemoval(t, log, requests: requests, exposures: 0),
          _quietAfterRemoval,
        );
        expect(log.weeklyGets, isEmpty);
      });
    },
  );

  testWidgets(
    'W9 control: without removal the next frame draws home and sends the GET',
    (t) async {
      await _withApp(t, (s, log) async {
        await tapIntoNewLoginHome(t, log);
        await t.pump();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(log.weeklyGets, hasLength(1));
      });
    },
  );
}
