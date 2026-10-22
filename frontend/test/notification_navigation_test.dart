import 'dart:async';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_navigation.dart';
import 'fixtures/notification_alignment_fixture.dart' as fixture;
import 'support/app_startup.dart';

// Runtime discovery keeps this target executable on the frozen source, where
// the bell opens NotificationSheet and intentionally fails the C03 target.
Finder get _notifications => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == 'NotificationListScreen',
);
Finder get _home => find.byType(HomeScreen);
Finder get _retainedHome => find.byType(HomeScreen, skipOffstage: false);
Finder get _panel => find.byType(HomeContentPanel, skipOffstage: false);

Finder _underHome(Finder child) =>
    find.descendant(of: _retainedHome, matching: child, skipOffstage: false);

ScrollPosition _vertical(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: _underHome(
              find.byType(SingleChildScrollView, skipOffstage: false),
            ).first,
            matching: find.byType(Scrollable, skipOffstage: false),
            skipOffstage: false,
          )
          .first,
    )
    .position;

Finder get _recentList => _underHome(
  find.byWidgetPredicate(
    (widget) =>
        widget is ListView &&
        widget.scrollDirection == Axis.horizontal &&
        widget.controller?.keepScrollOffset == false,
    skipOffstage: false,
  ),
);

ScrollPosition _horizontal(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: _recentList,
        matching: find.byType(Scrollable, skipOffstage: false),
        skipOffstage: false,
      ),
    )
    .position;

int _dot(WidgetTester tester) => tester
    .widget<PageDots>(_underHome(find.byType(PageDots, skipOffstage: false)))
    .activeIndex;

Finder get _bell => _underHome(
  find.byWidgetPredicate(
    (widget) => widget is SvgIconButton && widget.asset == Assets.bell,
    skipOffstage: false,
  ),
);

VoidCallback _openCallback(WidgetTester tester) {
  try {
    return (tester.widget(_retainedHome) as dynamic).onOpenNotifications
        as VoidCallback;
  } on NoSuchMethodError {
    // Baseline lacks the optional root callback. Preserve its genuine bell
    // action, then let _open report the absent full-screen C03 target.
    return tester.widget<SvgIconButton>(_bell).onPressed;
  }
}

VoidCallback _back(WidgetTester tester) =>
    (tester.widget(_notifications) as dynamic).onBack as VoidCallback;

VoidCallback _settings(WidgetTester tester) =>
    (tester.widget(_notifications) as dynamic).onOpenSettings as VoidCallback;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_bell);
  await tester.pumpAndSettle();
  expect(_notifications, findsOneWidget);
  expect(_home, findsNothing);
  expect(_retainedHome, findsOneWidget);
}

typedef _HomeSnapshot = ({
  State panel,
  ScrollPosition vertical,
  ScrollPosition horizontal,
  double top,
  double rail,
  int dot,
});

Future<_HomeSnapshot> _prime(WidgetTester tester) async {
  // Drag the real rail while visible, then return the vertical viewport to a
  // small nonzero offset at which the real bell remains tappable.
  await tester.ensureVisible(_recentList);
  await tester.pumpAndSettle();
  await tester.drag(_recentList, const Offset(-306, 0));
  await tester.pumpAndSettle();
  expect(_horizontal(tester).pixels, greaterThan(0));
  expect(_dot(tester), greaterThan(0));
  _vertical(tester).jumpTo(16);
  await tester.pumpAndSettle();
  expect(_vertical(tester).pixels, closeTo(16, .2));
  expect(_bell.hitTestable(), findsOneWidget);
  return (
    panel: tester.state(_panel),
    vertical: _vertical(tester),
    horizontal: _horizontal(tester),
    top: _vertical(tester).pixels,
    rail: _horizontal(tester).pixels,
    dot: _dot(tester),
  );
}

void _preserved(WidgetTester tester, _HomeSnapshot before) {
  expect(tester.state(_panel), same(before.panel));
  expect(_vertical(tester), same(before.vertical));
  expect(_horizontal(tester), same(before.horizontal));
  expect(_vertical(tester).pixels, closeTo(before.top, .2));
  expect(_horizontal(tester).pixels, closeTo(before.rail, .2));
  expect(_dot(tester), before.dot);
}

void _reset(WidgetTester tester, _HomeSnapshot before) {
  expect(_home, findsOneWidget);
  expect(tester.state(_panel), isNot(same(before.panel)));
  expect(_vertical(tester).pixels, 0);
  expect(_horizontal(tester).pixels, 0);
  expect(_dot(tester), 0);
}

Future<void> _root(
  WidgetTester tester,
  fixture.NotificationServer server,
  fixture.NotificationMemoryStorage storage,
  fixture.NotificationSocial social,
  Future<void> Function() body, {
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final previousPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 480);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  addTearDown(server.client.close);
  // The shared, frozen capture fixture only needs list data. This unit also
  // traverses detail, so compose its existing records into the real GET shape
  // here without changing the BEFORE/AFTER native fixture or source snapshot.
  final client = MockClient((request) async {
    final match = RegExp(
      r'^/api/v1/contents/(\d+)$',
    ).firstMatch(request.url.path);
    if (request.method == 'GET' && match != null) {
      server.requests.add({
        'method': request.method,
        'path': request.url.path,
        'query': request.url.queryParameters,
      });
      final id = int.parse(match[1]!);
      final record = server.records.where((row) => row['id'] == id).firstOrNull;
      return record == null
          ? server.json({'detail': 'Unknown navigation fixture content'}, 404)
          : server.json(record);
    }
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await server.client.send(copy));
  });
  addTearDown(client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(
          key: UniqueKey(),
          sessionStorage: storage,
          socialAuth: social,
        ),
      );
      await completeAppStartup(tester);
      expect(_home, findsOneWidget);
      expect(server.unexpected, isEmpty);
      await body();
    } finally {
      final logoutGate = server.logoutGate;
      if (logoutGate != null && !logoutGate.isCompleted) {
        logoutGate.complete(http.Response('', 204));
      }
      final clearGate = storage.clearGate;
      if (clearGate != null && !clearGate.isCompleted) clearGate.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  }, () => client);
}

void _resume(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await fixture.notificationLoadFonts(loadForTest: true);
  });
  setUp(() {
    var revision = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.huturu.app/share'), (
          call,
        ) async {
          switch (call.method) {
            case 'getState':
              return {
                'revision': revision,
                'drafts': <Object>[],
                'receipts': <Object>[],
              };
            case 'blockCredential':
              return ++revision;
            case 'publishCredential':
              return true;
            case 'presentDraft':
            case 'acknowledgeReceipts':
              return null;
            default:
              throw StateError(
                'Unexpected isolated share method ${call.method}',
              );
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.huturu.app/share'),
          null,
        ),
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '${platform.name} member and guest header and OS back preserve actual home scroll and recent dot',
      (tester) async {
        for (final kind in ['member', 'guest']) {
          final server = fixture.NotificationServer(kind);
          final storage = fixture.NotificationMemoryStorage();
          await _root(
            tester,
            server,
            storage,
            fixture.NotificationSocial(),
            () async {
              for (final action in ['header', 'os']) {
                final before = await _prime(tester);
                final requests = server.requests.length;
                final weeklyRequests = server.requests
                    .where((r) => r['path'] == '/api/v1/recommendations/weekly')
                    .length;
                final records = server.records.length;
                await _open(tester);
                _preserved(tester, before);
                if (action == 'header') {
                  await tester.tap(
                    find.byKey(const ValueKey('notification-back-hit')),
                  );
                } else {
                  await tester.binding.handlePopRoute();
                }
                await tester.pumpAndSettle();
                expect(_notifications, findsNothing);
                expect(_home, findsOneWidget);
                _preserved(tester, before);
                expect(server.requests.length, requests + 1);
                // Leaving notifications for Home is a new Weekly visit.
                expect(
                  server.requests
                      .where(
                        (r) => r['path'] == '/api/v1/recommendations/weekly',
                      )
                      .length,
                  weeklyRequests + 1,
                );
                expect(server.records.length, records);
                expect(server.writes, 0);
                expect(server.logoutCalls, 0);
                expect(storage.value, isNotNull);
                expect(tester.takeException(), isNull);
              }
            },
            platform: platform,
          );
        }
      },
    );
  }

  testWidgets(
    'leaving the home notification pair resets scroll for other routes',
    (tester) async {
      final server = fixture.NotificationServer('member');
      await _root(
        tester,
        server,
        fixture.NotificationMemoryStorage(),
        fixture.NotificationSocial(),
        () async {
          for (final destination in ['archive', 'search', 'detail']) {
            final before = await _prime(tester);
            await _open(tester);
            _back(tester)();
            await tester.pumpAndSettle();
            _preserved(tester, before);
            final home = tester.widget<HomeScreen>(_home);
            switch (destination) {
              case 'archive':
                home.onTab(AppRoute.archive);
                await tester.pumpAndSettle();
                tester
                    .widget<ArchiveScreen>(find.byType(ArchiveScreen))
                    .onTab(AppRoute.home);
              case 'search':
                home.onSearch();
                await tester.pumpAndSettle();
                tester
                    .widget<SearchScreen>(find.byType(SearchScreen))
                    .onClose();
              case 'detail':
                home.onOpenContent(home.contents.first);
                await tester.pumpAndSettle();
                tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
            }
            await tester.pumpAndSettle();
            _reset(tester, before);
          }
          expect(server.unexpected, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  testWidgets(
    'hidden home cannot receive touches focus or accessibility while notifications are visible',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final server = fixture.NotificationServer('member');
      try {
        await _root(
          tester,
          server,
          fixture.NotificationMemoryStorage(),
          fixture.NotificationSocial(),
          () async {
            final before = await _prime(tester);
            await _open(tester);
            expect(_bell.hitTestable(), findsNothing);
            expect(_recentList.hitTestable(), findsNothing);
            expect(find.text('최근 저장한 콘텐츠'), findsNothing);
            final labels = tester.semantics
                .simulatedAccessibilityTraversal()
                .map((node) => node.label)
                .join('\n');
            expect(labels, isNot(contains('최근 저장한 콘텐츠')));
            expect(labels, isNot(contains('이번주 허투루 픽 🎯')));
            final focusExclusion = find.ancestor(
              of: _retainedHome,
              matching: find.byType(ExcludeFocus, skipOffstage: false),
            );
            expect(focusExclusion, findsWidgets);
            expect(
              tester
                  .widgetList<ExcludeFocus>(focusExclusion)
                  .any((w) => w.excluding),
              isTrue,
            );
            final oldRequests = server.requests.length;
            // The bell shares its coordinates with the visible settings button.
            // Tap the retained My tab's coordinates instead: C03 has no bottom bar
            // or row action there, so a route change would expose hidden input.
            final retainedMyLabel = _underHome(
              find.text('마이', skipOffstage: false),
            );
            expect(retainedMyLabel.hitTestable(), findsNothing);
            await tester.tapAt(tester.getCenter(retainedMyLabel));
            await tester.pumpAndSettle();
            expect(_notifications, findsOneWidget);
            expect(server.requests.length, oldRequests);
            _preserved(tester, before);
            _back(tester)();
            await tester.pumpAndSettle();
            _preserved(tester, before);
            expect(tester.takeException(), isNull);
          },
        );
      } finally {
        // Widget-test end-of-test verification runs before addTearDown hooks.
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'settings opens the existing ReminderSheet and preserves notification and home state',
    (tester) async {
      final server = fixture.NotificationServer('member');
      await _root(
        tester,
        server,
        fixture.NotificationMemoryStorage(),
        fixture.NotificationSocial(),
        () async {
          final before = await _prime(tester);
          final requests = server.requests.length;
          final weeklyRequests = server.requests
              .where((r) => r['path'] == '/api/v1/recommendations/weekly')
              .length;
          await _open(tester);
          final notificationElement = tester.element(_notifications);
          final savedBack = _back(tester);
          for (var i = 0; i < 2; i++) {
            await tester.tap(
              find.byKey(const ValueKey('notification-settings-hit')),
            );
            await tester.pumpAndSettle();
            expect(find.byType(ReminderSheet), findsOneWidget);
            expect(find.text('리마인드 설정'), findsOneWidget);
            for (final setting in mockReminderSettings) {
              expect(find.text(setting.label), findsOneWidget);
              expect(find.text(setting.value), findsOneWidget);
            }
            savedBack();
            _back(tester)();
            await tester.pumpAndSettle();
            expect(find.byType(ReminderSheet), findsOneWidget);
            expect(tester.element(_notifications), same(notificationElement));
            expect(_home, findsNothing);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.byType(ReminderSheet), findsNothing);
            expect(tester.element(_notifications), same(notificationElement));
            _preserved(tester, before);
          }
          _back(tester)();
          await tester.pumpAndSettle();
          _preserved(tester, before);
          expect(server.requests.length, requests + 1);
          // Leaving notifications for Home is a new Weekly visit.
          expect(
            server.requests
                .where((r) => r['path'] == '/api/v1/recommendations/weekly')
                .length,
            weeklyRequests + 1,
          );
          expect(server.writes, 0);
          expect(server.logoutCalls, 0);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  testWidgets(
    'feed refresh while notifications are visible keeps home state but resets recent rail and dot',
    (tester) async {
      final server = fixture.NotificationServer('member');
      await _root(
        tester,
        server,
        fixture.NotificationMemoryStorage(),
        fixture.NotificationSocial(),
        () async {
          final before = await _prime(tester);
          final home = tester.widget<HomeScreen>(_home);
          final version = home.feed!.version;
          final ids = home.contents.take(4).map((item) => item.id).toList();
          final feedRequests = server.requests
              .where((r) => r['path'] == '/api/v1/feed')
              .length;
          await _open(tester);
          // Exercise the existing refresh callback as a background data update;
          // this is independent of the hidden widget's blocked touch surface.
          home.onRetry!();
          await tester.pumpAndSettle();
          expect(_notifications, findsOneWidget);
          expect(_home, findsNothing);
          expect(tester.state(_panel), same(before.panel));
          final updated = tester.widget<HomeScreen>(_retainedHome);
          expect(updated.feed!.version, greaterThan(version));
          expect(updated.contents.take(4).map((item) => item.id), ids);
          expect(_vertical(tester), same(before.vertical));
          expect(_vertical(tester).pixels, closeTo(before.top, .2));
          expect(_horizontal(tester).pixels, 0);
          expect(_dot(tester), 0);
          expect(
            server.requests.where((r) => r['path'] == '/api/v1/feed').length,
            feedRequests + 1,
          );
          _back(tester)();
          await tester.pumpAndSettle();
          expect(_home, findsOneWidget);
          expect(tester.state(_panel), same(before.panel));
          expect(_vertical(tester).pixels, closeTo(before.top, .2));
          expect(_horizontal(tester).pixels, 0);
          expect(_dot(tester), 0);
          expect(server.unexpected, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  testWidgets(
    'busy revocation blocks both saved and current notification actions',
    (tester) async {
      final server = fixture.NotificationServer('member');
      final storage = fixture.NotificationMemoryStorage();
      final social = fixture.NotificationSocial();
      await _root(tester, server, storage, social, () async {
        final before = await _prime(tester);
        final staleOpen = _openCallback(tester);
        await _open(tester);
        final staleBack = _back(tester), staleSettings = _settings(tester);
        server.logoutGate = Completer<http.Response>();
        social.revoked = true;
        _resume(tester);
        await tester.pumpAndSettle();
        expect(server.logoutCalls, 1);
        expect(storage.value, isNotNull);
        expect(_notifications, findsOneWidget);
        expect(find.byType(ReminderSheet), findsNothing);
        staleOpen();
        staleBack();
        staleSettings();
        _back(tester)();
        _settings(tester)();
        await tester.pumpAndSettle();
        expect(_notifications, findsOneWidget);
        expect(find.byType(ReminderSheet), findsNothing);
        _preserved(tester, before);
        server.logoutGate!.complete(http.Response('', 204));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        staleOpen();
        staleBack();
        staleSettings();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'pending session clear blocks previous and rebuilt back and settings callbacks',
    (tester) async {
      final server = fixture.NotificationServer('member');
      final storage = fixture.NotificationMemoryStorage();
      final social = fixture.NotificationSocial();
      await _root(tester, server, storage, social, () async {
        await _prime(tester);
        final staleOpen = _openCallback(tester);
        await _open(tester);
        final staleBack = _back(tester), staleSettings = _settings(tester);
        storage.clearGate = Completer<void>();
        social.revoked = true;
        _resume(tester);
        await tester.pumpAndSettle();
        expect(server.logoutCalls, 1);
        expect(storage.clearStarted, greaterThan(0));
        expect(storage.value, isNotNull);
        expect(_notifications, findsOneWidget);
        final pendingBack = _back(tester), pendingSettings = _settings(tester);
        staleOpen();
        staleBack();
        staleSettings();
        pendingBack();
        pendingSettings();
        await tester.pumpAndSettle();
        expect(_notifications, findsOneWidget);
        expect(find.byType(ReminderSheet), findsNothing);
        storage.clearGate!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(storage.value, isNull);
        pendingBack();
        pendingSettings();
        staleOpen();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'account generation and auth epoch reject old actions within a new guest flow',
    (tester) async {
      final server = fixture.NotificationServer('member');
      final storage = fixture.NotificationMemoryStorage();
      final social = fixture.NotificationSocial();
      await _root(tester, server, storage, social, () async {
        final before = await _prime(tester);
        final staleOpen = _openCallback(tester);
        await _open(tester);
        final staleBack = _back(tester), staleSettings = _settings(tester);
        // The unchanged introduction overflows at 320x480. Use an ordinary
        // height only for that auth sequence; Home/notifications remain 320x480.
        tester.view.physicalSize = const Size(320, 812);
        await tester.pumpAndSettle();
        social.revoked = true;
        _resume(tester);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(storage.value, isNull);
        social.revoked = false;
        await startGuestAndFinishOnboarding(tester);
        tester.view.physicalSize = const Size(320, 480);
        await tester.pumpAndSettle();
        expect(_home, findsOneWidget);
        expect(tester.state(_panel), isNot(same(before.panel)));
        expect(_vertical(tester).pixels, 0);
        staleOpen();
        staleBack();
        staleSettings();
        await tester.pumpAndSettle();
        expect(_home, findsOneWidget);
        expect(_notifications, findsNothing);
        expect(find.byType(ReminderSheet), findsNothing);
        await _open(tester);
        staleOpen();
        staleBack();
        staleSettings();
        await tester.pumpAndSettle();
        expect(_notifications, findsOneWidget);
        expect(find.byType(ReminderSheet), findsNothing);
        _back(tester)();
        await tester.pumpAndSettle();
        expect(_home, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
