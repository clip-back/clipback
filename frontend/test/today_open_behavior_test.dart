import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_navigation.dart';
import 'fixtures/today_server.dart';
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;

// Frozen current-behavior checks for the home Today open (#301 T1–T6).
// Only server requests, visible widgets and HomeScreen/DetailScreen
// arguments/callbacks are asserted; app root private state is never read.

const _todayPath = '/api/v1/recommendations/today';
const _refreshPath = '/api/v1/auth/refresh';
const _aToken = 'Bearer fixture-access';

/// Every Today notice the open can show; a late response shows none of them.
const _notices = [
  '콘텐츠를 5개 이상 저장하면 오늘의 추천을 볼 수 있어요.',
  '오늘 추천할 콘텐츠가 없어요. 나중에 다시 확인해 주세요.',
  '오늘의 콘텐츠를 불러오지 못했어요. 다시 시도해 주세요.',
  '이 콘텐츠는 더 이상 볼 수 없어요.',
];
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Every request the real app sent, logged on arrival before any fake delay.
class _Log {
  final requests = <http.Request>[];
  Iterable<http.Request> get todayGets =>
      requests.where((r) => r.method == 'GET' && r.url.path == _todayPath);
  Iterable<http.Request> contentGets(int id) => requests.where(
    (r) => r.method == 'GET' && r.url.path == '/api/v1/contents/$id',
  );
  Iterable<http.Request> get refreshes =>
      requests.where((r) => r.url.path == _refreshPath);
  Iterable<http.Request> get viewRequests =>
      requests.where((r) => r.url.path.endsWith('/view'));
  List<Map<String, dynamic>> get views => [
    for (final r in viewRequests) jsonDecode(r.body) as Map<String, dynamic>,
  ];

  /// View UUIDs vary per run: presence and format first, then identity.
  List<String> viewIds() {
    final ids = <String>[];
    for (final body in views) {
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
      TodayServer server,
      http.Request request,
      Future<http.Response> Function() forward,
    );

/// Holds the stored-session clear so the real session invalidation stays
/// started (clear pending) until the test releases it. It never makes an
/// invalid session usable: the clear always completes as the real one does.
class _GatedClearStorage extends isolated.ArchiveAllMemoryStorage {
  Completer<void>? gate;
  var clears = 0;
  @override
  Future<void> clear() async {
    clears++;
    await gate?.future;
    await super.clear();
  }
}

/// The real [ClipbackApp] (real ClipbackApi and repositories) on the
/// [TodayServer] fake, as in today_root_test's withHome.
Future<void> _withApp(
  WidgetTester t,
  Future<void> Function(TodayServer, _Log) check, {
  _Intercept? intercept,
  isolated.ArchiveAllMemoryStorage? storage,
}) async {
  final server = TodayServer();
  final log = _Log();
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = MockClient((request) async {
    log.requests.add(request);
    Future<http.Response> forward() {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return server.todayClient.send(copy).then(http.Response.fromStream);
    }

    return await intercept?.call(server, request, forward) ?? await forward();
  });
  await http.runWithClient(() async {
    try {
      await t.pumpWidget(
        ClipbackApp(
          sessionStorage: storage ?? isolated.ArchiveAllMemoryStorage(),
          socialAuth: isolated.ArchiveAllSocialAuth(),
        ),
      );
      await completeAppStartup(t);
      await check(server, log);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  }, () => client);
}

HomeScreen _home(WidgetTester t) =>
    t.widget<HomeScreen>(find.byType(HomeScreen));
DetailScreen _detail(WidgetTester t) =>
    t.widget<DetailScreen>(find.byType(DetailScreen));

void _expectNoNotice() {
  for (final notice in _notices) {
    expect(find.text(notice), findsNothing);
  }
}

/// The first content's detail of the five-item fixture with one view.
void _expectOpenedFirst(WidgetTester t, _Log log) {
  expect(find.byType(DetailScreen), findsOneWidget);
  expect(find.text('1 / 5'), findsOneWidget);
  expect(_detail(t).content.apiId, 606);
  expect(log.views, hasLength(1));
  expect(log.views.single, containsPair('recommendation_item_id', 1306));
  expect(log.viewIds(), hasLength(1));
}

void _expectStayedHome(WidgetTester t, _Log log) {
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.byType(DetailScreen), findsNothing);
  expect(log.views, isEmpty);
  _expectNoNotice();
}

void main() {
  testWidgets(
    'T1 account A list response after logout and account B home opens nothing, B opens anew',
    (t) async {
      final aGate = Completer<void>();
      const bToken = 'Bearer b-access';
      await _withApp(
        t,
        (s, log) async {
          _home(t).onOpenToday();
          await t.pump();
          expect(log.todayGets, hasLength(1));
          expect(log.todayGets.single.headers['Authorization'], _aToken);

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
          expect(log.todayGets, hasLength(1));

          // Account A's response arrives only after account B's home is shown.
          aGate.complete();
          await t.pumpAndSettle();
          _expectStayedHome(t, log);
          expect(log.todayGets, hasLength(1));

          _home(t).onOpenToday();
          await t.pumpAndSettle();
          expect(log.todayGets, hasLength(2));
          expect(log.todayGets.last.headers['Authorization'], bToken);
          _expectOpenedFirst(t, log);
          expect(log.viewRequests.single.headers['Authorization'], bToken);
        },
        intercept: (s, request, forward) async {
          switch (request.url.path) {
            case '/api/v1/auth/logout':
              return http.Response('', 204);
            case '/api/v1/auth/guest':
              return s.json({
                'access_token': 'b-access',
                'refresh_token': 'b-refresh',
                'expires_in': 3600,
                'refresh_expires_in': 86400,
              }, 201);
            case _todayPath when request.headers['Authorization'] == _aToken:
              final response = await forward();
              await aGate.future;
              return response;
          }
          return null;
        },
      );
    },
  );

  testWidgets(
    'T2 old home callback called after home, archive, home requests nothing',
    (t) async {
      await _withApp(t, (s, log) async {
        final old = _home(t);
        old.onTab(AppRoute.archive);
        await t.pumpAndSettle();
        t
            .widget<ArchiveScreen>(find.byType(ArchiveScreen))
            .onTab(AppRoute.home);
        await t.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(ArchiveScreen), findsNothing);

        old.onOpenToday();
        await t.pumpAndSettle();
        expect(log.todayGets, isEmpty);
        _expectStayedHome(t, log);

        // Control: the new home's callback proceeds.
        _home(t).onOpenToday();
        await t.pumpAndSettle();
        expect(log.todayGets, hasLength(1));
        _expectOpenedFirst(t, log);
      });
    },
  );

  testWidgets(
    'T3 callback received under the save sheet, called after the close transition, requests nothing',
    (t) async {
      await _withApp(t, (s, log) async {
        await t.tap(find.byType(NavAddButton));
        await t.pumpAndSettle();
        expect(find.byType(AddContentSheet), findsOneWidget);
        final underSheet = t
            .widget<HomeScreen>(find.byType(HomeScreen, skipOffstage: false))
            .onOpenToday;

        final context = t.element(find.byType(AddContentSheet));
        final route = ModalRoute.of(context)! as TransitionRoute<dynamic>;
        var closed = false;
        unawaited(route.completed.then((_) => closed = true));
        Navigator.of(context).pop();
        await t.pumpAndSettle();
        expect(closed, isTrue);
        expect(find.byType(AddContentSheet), findsNothing);

        underSheet();
        await t.pumpAndSettle();
        expect(log.todayGets, isEmpty);
        _expectStayedHome(t, log);

        // Control: a callback taken after the close proceeds, so the old one
        // was not blocked by a sheet still being present.
        _home(t).onOpenToday();
        await t.pumpAndSettle();
        expect(log.todayGets, hasLength(1));
        _expectOpenedFirst(t, log);
      });
    },
  );

  testWidgets(
    'T4 list response completed in background records one view, detail shown after resume',
    (t) async {
      await _withApp(t, (s, log) async {
        s.pending = Completer<void>();
        _home(t).onOpenToday();
        await t.pump();
        expect(log.todayGets, hasLength(1));

        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await t.pumpAndSettle();
        s.pending!.complete();
        await t.pumpAndSettle();
        // Before resume: the open already finished (first content read and
        // one view recorded), but no frame is drawn while paused, so the
        // screen still shows home.
        expect(log.contentGets(606), hasLength(1));
        expect(log.views, hasLength(1));
        expect(log.views.single, containsPair('recommendation_item_id', 1306));
        final id = log.viewIds().single;
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(DetailScreen), findsNothing);
        _expectNoNotice();

        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        // After resume.
        _expectOpenedFirst(t, log);
        expect(log.viewIds().single, id);
        expect(log.todayGets, hasLength(1));
      });
    },
  );

  testWidgets(
    'T5 press again while the first content read is pending keeps one list GET',
    (t) async {
      final preflight = Completer<http.Response>();
      await _withApp(
        t,
        (s, log) async {
          _home(t).onOpenToday();
          await t.pumpAndSettle();
          // The list GET has finished: only its success starts the read.
          expect(log.todayGets, hasLength(1));
          expect(log.contentGets(606), hasLength(1));
          _expectStayedHome(t, log);

          _home(t).onOpenToday();
          await t.pumpAndSettle();
          expect(log.todayGets, hasLength(1));
          expect(log.contentGets(606), hasLength(1));
          _expectStayedHome(t, log);

          preflight.complete(
            s.json(s.records.firstWhere((record) => record['id'] == 606)),
          );
          await t.pumpAndSettle();
          _expectOpenedFirst(t, log);
          expect(log.todayGets, hasLength(1));
          expect(log.contentGets(606), hasLength(1));
        },
        intercept: (s, request, forward) async =>
            request.url.path == '/api/v1/contents/606'
            ? await preflight.future
            : null,
      );
    },
  );

  group('T6 final auth invalidation, then the late list response', () {
    for (final duringClear in [true, false]) {
      testWidgets(
        'T6${duringClear ? 'a during the session clear' : 'b after the login screen'} opens nothing and records nothing',
        (t) async {
          final storage = _GatedClearStorage();
          var unauthorized = false;
          await _withApp(
            t,
            storage: storage,
            (s, log) async {
              s.pending = Completer<void>();
              _home(t).onOpenToday();
              await t.pump();
              expect(log.todayGets, hasLength(1));

              // Another request is rejected and its token refresh is too.
              unauthorized = true;
              if (duringClear) storage.gate = Completer<void>();
              final h = _home(t);
              h.onToggleBookmark(h.contents.first);
              if (duringClear) {
                for (var i = 0; i < 20 && storage.clears == 0; i++) {
                  await t.pump();
                }
                expect(storage.clears, 1);
                expect(find.byType(HomeScreen), findsOneWidget);
                expect(find.byType(LoginScreen), findsNothing);
              } else {
                await t.pumpAndSettle();
                expect(find.byType(LoginScreen), findsOneWidget);
              }
              expect(log.refreshes, hasLength(1));

              s.pending!.complete();
              await t.pumpAndSettle();
              expect(find.byType(DetailScreen), findsNothing);
              expect(log.views, isEmpty);
              _expectNoNotice();

              if (duringClear) {
                storage.gate!.complete();
                await t.pumpAndSettle();
                expect(find.byType(LoginScreen), findsOneWidget);
                expect(find.byType(DetailScreen), findsNothing);
                expect(log.views, isEmpty);
                _expectNoNotice();
              }
              expect(storage.clears, 1);
              expect(log.todayGets, hasLength(1));
            },
            intercept: (s, request, forward) async {
              if (!unauthorized) return null;
              if (request.url.path == _refreshPath ||
                  request.url.path.endsWith('/favorite')) {
                return s.json({'detail': 'expired'}, 401);
              }
              return null;
            },
          );
        },
      );
    }
  });
}
