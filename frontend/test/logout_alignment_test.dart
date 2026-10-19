import 'dart:async';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/session_restore_screen.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'fixtures/logout_alignment_fixture.dart' as fixture;
import 'support/account_preview.dart' as account;
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;

Finder get _confirmation => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == 'LogoutConfirmationScreen',
);
Finder _key(String key) => find.byKey(ValueKey(key));
Future<void> _open(WidgetTester tester) async {
  await tester.ensureVisible(find.text('로그아웃'));
  await tester.tap(find.text('로그아웃'));
  await tester.pumpAndSettle();
}

Future<void> _root(
  WidgetTester tester,
  fixture.LogoutServer server,
  fixture.LogoutMemoryStorage storage,
  Future<void> Function() body, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  SocialAuth? social,
}) async {
  final previousPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(
          key: UniqueKey(),
          sessionStorage: storage,
          socialAuth: social ?? isolated.ArchiveAllSocialAuth(),
        ),
      );
      await completeAppStartup(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(ClipbackNavigationBar),
          matching: find.text('마이'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MyScreen), findsOneWidget);
      await tester.tap(find.byType(MyProfileRow));
      await tester.pumpAndSettle();
      expect(find.byType(AccountManagementScreen), findsOneWidget);
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  }, () => server.client);
}

Map<String, Object?> _measurement(WidgetTester tester) =>
    fixture.logoutMeasure(tester.element(_confirmation));
void _expectJudgment(WidgetTester tester) {
  final measurement = _measurement(tester);
  final judgment = fixture.logoutJudgment(measurement);
  final buttons = measurement['buttons'] as Map;
  expect(buttons['confirm']['background'], '0xFF1A1A1A');
  expect(buttons['cancel']['background'], '0xFFFFFFFF');
  expect(buttons['cancel']['borderColor'], '0xFF767676');
  expect(buttons['cancel']['borderWidth'], 1);
  for (final role in ['confirm', 'cancel']) {
    expect(buttons[role]['radius'], 8);
  }
  expect(
    Theme.of(tester.element(_confirmation)).scaffoldBackgroundColor,
    const Color(0xFFF5F5F5),
  );
  for (final pair in {
    'stylePassed': 'styleFailures',
    'layoutPassed': 'layoutFailures',
    'assetPassed': 'assetFailures',
  }.entries) {
    expect(judgment[pair.key], isTrue, reason: '${judgment[pair.value]}');
  }
}

class _RevocableAppleSocial extends isolated.ArchiveAllSocialAuth {
  bool revoked = false;
  int credentialChecks = 0;
  @override
  Future<AppleCredentialStatus> appleCredentialState() async {
    credentialChecks++;
    return revoked
        ? AppleCredentialStatus.revoked
        : AppleCredentialStatus.authorized;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await fixture.logoutInspectFonts(loadForTest: true);
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
                'Unexpected fixture share method ${call.method}',
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
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width J03 actual font geometry asset and member guest zero-request entry',
        (tester) async {
          for (final kind in ['member', 'guest']) {
            final server = fixture.LogoutServer(kind),
                storage = fixture.LogoutMemoryStorage();
            await _root(
              tester,
              server,
              storage,
              () async {
                await _open(tester);
                expect(_confirmation, findsOneWidget);
                expect(server.logoutCalls, 0);
                _expectJudgment(tester);
                expect(storage.value, isNotNull);
                expect(tester.takeException(), isNull);
              },
              platform: platform,
              width: width,
            );
          }
        },
      );
    }
    testWidgets(
      '${platform.name} low viewport scroll keeps illustration text and footer accessible',
      (tester) async {
        final server = fixture.LogoutServer('member'),
            storage = fixture.LogoutMemoryStorage();
        await _root(
          tester,
          server,
          storage,
          () async {
            await _open(tester);
            expect(_confirmation, findsOneWidget);
            tester.view.physicalSize = const Size(320, 480);
            await tester.pumpAndSettle();
            final element = tester.element(_confirmation),
                position = fixture.logoutPosition(element)!;
            expect(position.maxScrollExtent, greaterThan(0));
            await tester.drag(_key('logout-scroll'), const Offset(0, -450));
            await tester.pumpAndSettle();
            expect(position.pixels, closeTo(position.maxScrollExtent, .2));
            _expectJudgment(tester);
            final m = _measurement(tester),
                image = (m['assets'] as Map)['illustration']['bounds'] as Map,
                body = (m['bounds'] as Map)['body'] as Map;
            expect(
              image['bottom'],
              lessThanOrEqualTo((body['bottom'] as num) - 23.8),
            );
            await tester.tap(_key('logout-cancel'));
            await tester.pumpAndSettle();
            expect(find.byType(AccountManagementScreen), findsOneWidget);
            expect(server.logoutCalls, 0);
            expect(tester.takeException(), isNull);
          },
          platform: platform,
          width: 320,
        );
      },
    );
  }
  testWidgets(
    'member and guest cancel header and OS back preserve original session content and cumulative stats',
    (tester) async {
      for (final kind in ['member', 'guest']) {
        final server = fixture.LogoutServer(kind),
            storage = fixture.LogoutMemoryStorage();
        await _root(tester, server, storage, () async {
          final initialRecords = server.records.length;
          for (final action in ['cancel', 'header', 'os']) {
            await _open(tester);
            expect(_confirmation, findsOneWidget);
            final Future<void> Function() staleConfirm =
                (tester.widget(_confirmation) as dynamic).onConfirm;
            if (action == 'os') {
              await tester.binding.handlePopRoute();
            } else {
              await tester.tap(
                _key(action == 'cancel' ? 'logout-cancel' : 'logout-back-hit'),
              );
            }
            await tester.pumpAndSettle();
            expect(find.byType(AccountManagementScreen), findsOneWidget);
            await staleConfirm();
            await tester.pumpAndSettle();
            expect(server.logoutCalls, 0);
            expect(storage.value, isNotNull);
            expect(server.records.length, initialRecords);
            final user = tester
                .widget<AccountManagementScreen>(
                  find.byType(AccountManagementScreen),
                )
                .user;
            expect(user.name, server.expected.name);
            expect(user.savedContentCount, server.expected.savedContentCount);
            expect(
              user.revisitedContentCount,
              server.expected.revisitedContentCount,
            );
          }
        });
      }
    },
  );
  testWidgets(
    'confirm makes one request pending locks all exits and failure stays retryable then succeeds',
    (tester) async {
      for (final kind in ['member', 'guest']) {
        final server = fixture.LogoutServer(kind),
            storage = fixture.LogoutMemoryStorage();
        await _root(tester, server, storage, () async {
          await _open(tester);
          expect(_confirmation, findsOneWidget);
          server.logoutGate = Completer<http.Response>();
          await tester.tap(_key('logout-confirm'));
          await tester.pump();
          expect(server.logoutCalls, 1);
          expect(_measurement(tester)['authBusy'], isTrue);
          _expectJudgment(tester);
          for (final key in [
            'logout-confirm',
            'logout-cancel',
            'logout-back-hit',
          ]) {
            await tester.tap(_key(key));
            await tester.pump();
          }
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(_confirmation, findsOneWidget);
          expect(server.logoutCalls, 1);
          server.logoutGate!.complete(
            server.json({'detail': '로그아웃 대역 요청 실패'}, 503),
          );
          await tester.pumpAndSettle();
          expect(_confirmation, findsOneWidget);
          expect(_measurement(tester)['authBusy'], isFalse);
          expect(storage.value, isNotNull);
          expect(find.text('로그아웃 대역 요청 실패'), findsOneWidget);
          ScaffoldMessenger.of(
            tester.element(_confirmation),
          ).hideCurrentSnackBar();
          await tester.pumpAndSettle();
          server.logoutGate = null;
          await tester.tap(_key('logout-confirm'));
          await tester.pumpAndSettle();
          expect(server.logoutCalls, 2);
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(storage.value, isNull);
          expect(tester.takeException(), isNull);
        });
      }
    },
  );
  testWidgets(
    'server logout followed by local clear failure prioritizes existing session restore recovery',
    (tester) async {
      final server = fixture.LogoutServer('member'),
          storage = fixture.LogoutMemoryStorage()..failClear = true;
      await _root(tester, server, storage, () async {
        await _open(tester);
        expect(_confirmation, findsOneWidget);
        await tester.tap(_key('logout-confirm'));
        await tester.pumpAndSettle();
        expect(server.logoutCalls, 1);
        expect(find.byType(SessionRestoreScreen), findsOneWidget);
        expect(_confirmation, findsNothing);
        expect(storage.value, isNotNull);
        expect(tester.takeException(), isNull);
      });
    },
  );
  testWidgets(
    'disposed confirmation ignores late UI response and retains successful logout session clearing',
    (tester) async {
      final server = fixture.LogoutServer('guest'),
          storage = fixture.LogoutMemoryStorage();
      await _root(tester, server, storage, () async {
        await _open(tester);
        expect(_confirmation, findsOneWidget);
        server.logoutGate = Completer<http.Response>();
        await tester.tap(_key('logout-confirm'));
        await tester.pump();
        expect(server.logoutCalls, 1);
        await tester.pumpWidget(
          const MaterialApp(home: Text('Unmounted fixture')),
        );
        await tester.pump();
        server.logoutGate!.complete(http.Response('', 204));
        await tester.pumpAndSettle();
        expect(find.text('Unmounted fixture'), findsOneWidget);
        expect(storage.value, isNull);
        expect(storage.clears, 1);
        expect(tester.takeException(), isNull);
      });
    },
  );
  testWidgets(
    'J03 immediately yields to revoked session security and stale confirmation sends no extra request',
    (tester) async {
      final server = fixture.LogoutServer('member'),
          storage = fixture.LogoutMemoryStorage(),
          social = _RevocableAppleSocial();
      await _root(tester, server, storage, () async {
        await _open(tester);
        expect(_confirmation, findsOneWidget);
        final Future<void> Function() staleConfirm =
            (tester.widget(_confirmation) as dynamic).onConfirm;
        expect(server.logoutCalls, 0);
        social.revoked = true;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(social.credentialChecks, greaterThan(0));
        expect(_confirmation, findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(storage.value, isNull);
        final revocationRequests = server.logoutCalls;
        expect(revocationRequests, 1);
        await staleConfirm();
        await tester.pumpAndSettle();
        expect(server.logoutCalls, revocationRequests);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, social: social);
    },
  );
  test('J03 uses the registered actual Bold font file', () async {
    final result = await fixture.logoutInspectFonts();
    expect(result['available'], isTrue);
    expect(result['declared'], isTrue);
    expect(result['bytes'], greaterThan(1000));
    expect(
      account.accountMember.revisitedContentCount,
      greaterThan(account.accountMember.savedContentCount),
    );
  });
}
