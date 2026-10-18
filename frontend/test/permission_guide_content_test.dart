import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'fixtures/permission_guide_alignment_fixture.dart' as f;
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as login;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await f.permissionLoadFonts(loadForTest: true);
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
      '${platform.name} low viewport keeps B01 footer outside scrolled content and exposes last guide',
      (tester) async {
        final previous = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = platform;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 812);
        final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
            bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
        tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
        tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
        addTearDown(tester.view.reset);
        final server = login.LoginServer(),
            storage = login.LoginMemoryStorage(),
            social = login.LoginControlledSocial(platform);
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
            expect(find.byType(LoginScreen), findsOneWidget);
            await tester.tap(
              find.byKey(const ValueKey('login-provider-kakao')),
            );
            await tester.pumpAndSettle();
            final sheet = find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == 'PermissionGuideSheet',
            );
            expect(sheet, findsOneWidget);
            tester.view.physicalSize = const Size(320, 360);
            await tester.pumpAndSettle();
            final root = tester.element(find.byType(ClipbackApp)),
                position = f.permissionPosition(root)!;
            expect(position.maxScrollExtent, greaterThan(0));
            final start = f.permissionMeasure(root),
                judgment = f.permissionJudgment(start, requireActive: true);
            for (final pair in {
              'stylePassed': 'styleFailures',
              'layoutPassed': 'layoutFailures',
              'assetPassed': 'assetFailures',
            }.entries) {
              expect(
                judgment[pair.key],
                isTrue,
                reason: '${judgment[pair.value]}',
              );
            }
            final before = (start['button'] as Map)['bounds'] as Map;
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            final after = f.permissionMeasure(root),
                bounds = after['bounds'] as Map;
            final viewport = bounds['scroll'] as Map,
                last = bounds['row-1'] as Map,
                button = bounds['continue-hit'] as Map;
            expect(
              (viewport['bottom'] as num) - (last['bottom'] as num),
              closeTo(24, .26),
            );
            expect(
              (button['top'] as num),
              greaterThanOrEqualTo((viewport['bottom'] as num) - .26),
            );
            expect((after['button'] as Map)['bounds'], before);
            expect(social.calls, isEmpty);
            expect(server.guestIssuances, 0);
            expect(server.socialIssuances, 0);
            expect(storage.value, isNull);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            debugDefaultTargetPlatformOverride = previous;
          }
        }, () => server.client);
      },
    );
  }
}
