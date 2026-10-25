import 'dart:async';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'auth_navigation.dart';
import 'fixtures/notice_alignment_fixture.dart' as fixture;
import 'support/app_startup.dart';

Finder get _notice => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == 'NoticeListScreen',
);

Finder get _myList =>
    find.descendant(of: find.byType(MyScreen), matching: find.byType(ListView));

ScrollPosition _myPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: _myList, matching: find.byType(Scrollable)).first,
    )
    .position;

VoidCallback _noticeBack(WidgetTester tester) =>
    (tester.widget(_notice) as dynamic).onBack as VoidCallback;

Future<double> _openNotice(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('공지사항'),
    100,
    scrollable: find
        .descendant(of: _myList, matching: find.byType(Scrollable))
        .first,
  );
  await tester.ensureVisible(find.text('공지사항'));
  await tester.pumpAndSettle();
  final offset = _myPosition(tester).pixels;
  expect(offset, greaterThan(0), reason: 'Use a real scrolled My viewport.');
  await tester.tap(find.text('공지사항'));
  await tester.pumpAndSettle();
  // Discovery instead of a new production import lets this test compile on the
  // frozen baseline, where the legacy sheet intentionally fails this target.
  expect(_notice, findsOneWidget);
  expect(find.byType(MyScreen), findsNothing);
  return offset;
}

Future<void> _openMy(WidgetTester tester) async {
  tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
  await tester.pumpAndSettle();
  expect(find.byType(MyScreen), findsOneWidget);
}

Future<void> _root(
  WidgetTester tester,
  fixture.NoticeServer server,
  fixture.NoticeMemoryStorage storage,
  fixture.NoticeSocial social,
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
      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason:
            'The seeded memory session must restore before navigation. '
            'Unexpected memory requests: ${server.unexpected}',
      );
      await _openMy(tester);
      await body();
    } finally {
      final clearGate = storage.clearGate;
      if (clearGate != null && !clearGate.isCompleted) clearGate.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  }, () => server.client);
}

void _resume(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await fixture.noticeLoadFonts(loadForTest: true);
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
      '${platform.name} member and guest notice header and OS back preserve My offset and only refresh stats',
      (tester) async {
        for (final kind in ['member', 'guest']) {
          final server = fixture.NoticeServer(kind);
          final storage = fixture.NoticeMemoryStorage();
          await _root(
            tester,
            server,
            storage,
            fixture.NoticeSocial(),
            () async {
              for (final action in ['header', 'os']) {
                final beforeRequests = server.requests.length;
                final beforeRecords = server.records.length;
                final before = await _openNotice(tester);
                if (action == 'header') {
                  await tester.tap(
                    find.byKey(const ValueKey('notice-back-hit')),
                  );
                } else {
                  await tester.binding.handlePopRoute();
                }
                await tester.pumpAndSettle();
                expect(find.byType(MyScreen), findsOneWidget);
                expect(_notice, findsNothing);
                expect(_myPosition(tester).pixels, closeTo(before, .2));
                expect(server.requests.length, beforeRequests + 1);
                expect(server.requests.last, {
                  'method': 'GET',
                  'path': '/api/v1/users/me/stats',
                  'query': <String, String>{},
                });
                expect(server.records.length, beforeRecords);
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
    'My notice storage is cleared by account category management and root tab departures',
    (tester) async {
      final server = fixture.NoticeServer('member');
      await _root(
        tester,
        server,
        fixture.NoticeMemoryStorage(),
        fixture.NoticeSocial(),
        () async {
          for (final destination in ['account', 'category', 'root tab']) {
            final saved = await _openNotice(tester);
            _noticeBack(tester)();
            await tester.pumpAndSettle();
            expect(_myPosition(tester).pixels, closeTo(saved, .2));
            final my = tester.widget<MyScreen>(find.byType(MyScreen));
            switch (destination) {
              case 'account':
                my.onOpenAccount();
                await tester.pumpAndSettle();
                tester
                    .widget<AccountManagementScreen>(
                      find.byType(AccountManagementScreen),
                    )
                    .onBack();
              case 'category':
                my.onOpenCategoryManagement();
                await tester.pumpAndSettle();
                tester
                    .widget<CategoryManagementScreen>(
                      find.byType(CategoryManagementScreen),
                    )
                    .onBack();
              case 'root tab':
                my.onTab(AppRoute.home);
                await tester.pumpAndSettle();
                await _openMy(tester);
            }
            await tester.pumpAndSettle();
            expect(find.byType(MyScreen), findsOneWidget);
            expect(
              _myPosition(tester).pixels,
              0,
              reason: '$destination must not inherit the notice-only bucket.',
            );
          }
          expect(server.writes, 0);
          expect(server.logoutCalls, 0);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  testWidgets(
    'session generation reset blocks old notice back even inside a new guest notice',
    (tester) async {
      final server = fixture.NoticeServer('member');
      final storage = fixture.NoticeMemoryStorage();
      final social = fixture.NoticeSocial();
      await _root(tester, server, storage, social, () async {
        await _openNotice(tester);
        final staleBack = _noticeBack(tester);
        // Exercise My/notices in the short viewport, but use an ordinary height
        // through the unchanged introduction pages before the new guest enters.
        tester.view.physicalSize = const Size(320, 812);
        await tester.pumpAndSettle();
        social.revoked = true;
        _resume(tester);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(storage.value, isNull);
        staleBack();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        social.revoked = false;
        await startGuestAndFinishOnboarding(tester);
        tester.view.physicalSize = const Size(320, 480);
        await tester.pumpAndSettle();
        await _openMy(tester);
        expect(_myPosition(tester).pixels, 0);
        expect(
          tester.widget<MyScreen>(find.byType(MyScreen)).user.name,
          server.expected.name,
        );
        await _openNotice(tester);
        staleBack();
        await tester.pumpAndSettle();
        expect(_notice, findsOneWidget);
        expect(find.byType(MyScreen), findsNothing);
        _noticeBack(tester)();
        await tester.pumpAndSettle();
        expect(find.byType(MyScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'pending invalidation clear blocks both old and newly rebuilt notice back callbacks',
    (tester) async {
      final server = fixture.NoticeServer('member');
      final storage = fixture.NoticeMemoryStorage();
      final social = fixture.NoticeSocial();
      await _root(tester, server, storage, social, () async {
        await _openNotice(tester);
        final staleBack = _noticeBack(tester);
        storage.clearGate = Completer<void>();
        social.revoked = true;
        _resume(tester);
        await tester.pumpAndSettle();
        expect(server.logoutCalls, 1);
        expect(storage.value, isNotNull);
        expect(_notice, findsOneWidget);
        final pendingBack = _noticeBack(tester);
        staleBack();
        pendingBack();
        await tester.pumpAndSettle();
        expect(_notice, findsOneWidget);
        expect(find.byType(MyScreen), findsNothing);
        storage.clearGate!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(storage.value, isNull);
        pendingBack();
        staleBack();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
