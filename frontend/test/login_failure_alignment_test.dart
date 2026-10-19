import 'dart:convert';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_navigation.dart';
import 'fixtures/login_failure_fixture.dart' as f;
import 'fixtures/splash_alignment_fixture.dart' as splash;
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as login;
import 'support/login_failure_preview.dart' as preview;

Future<void> _withFailure(
  WidgetTester tester,
  Future<void> Function() body, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  String kind = 'http',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 50.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() {
    tester.view.reset();
    debugDefaultTargetPlatformOverride = null;
  });
  final server = preview.FailureServer(),
      storage = splash.SplashMemoryStorage(),
      social = login.LoginControlledSocial(platform)
        ..cancel = false
        ..fail = kind == 'sdk';
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(sessionStorage: storage, socialAuth: social),
      );
      await completeAppStartup(tester);
      final attempt = await startLoginChoice(
        tester,
        () => tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google),
      );
      await attempt.completion;
      await tester.pumpAndSettle();
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      server.controlledClient.close();
      server.client.close();
      debugDefaultTargetPlatformOverride = null;
    }
  }, () => server.controlledClient);
}

Map<String, Object?> _measure(WidgetTester tester) =>
    f.failureMeasure(tester.element(find.byType(ClipbackApp)));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
    await (FontLoader(
      'PretendardDetail',
    )..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'))).load();
  });
  test(
    'fixed HTTP503 fixture roundtrip is real status and preserves no credentials',
    () async {
      final server = preview.FailureServer();
      try {
        final response = await server.controlledClient.post(
          Uri.parse('https://fixture.invalid/api/v1/auth/social/google'),
          body: '{"token":"fixture-only"}',
        );
        expect(response.statusCode, 503);
        expect(server.socialIssuances, 1);
        expect(server.guestIssuances, 0);
      } finally {
        server.controlledClient.close();
        server.client.close();
      }
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final kind in ['http', 'sdk']) {
        testWidgets(
          '${platform.name} width$width $kind A05 actual fonts geometry assets1x',
          (tester) async {
            await _withFailure(
              tester,
              () async {
                final m = _measure(tester),
                    j = f.failureJudgment(m, kind: kind);
                if (j['layoutPassed'] != true) {
                  debugPrint('A05_MEASUREMENT ${jsonEncode(m)}');
                }
                expect(
                  j['stylePassed'],
                  isTrue,
                  reason: '${j['styleFailures']}',
                );
                expect(
                  j['layoutPassed'],
                  isTrue,
                  reason: '${j['layoutFailures']}',
                );
                expect(
                  j['assetPassed'],
                  isTrue,
                  reason: '${j['assetFailures']}',
                );
                expect(tester.takeException(), isNull);
              },
              platform: platform,
              width: width,
              kind: kind,
            );
          },
        );
      }
    }
  }
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '${platform.name} lowviewport scroll exposes full notice24 above fixed footer',
      (tester) async {
        await _withFailure(
          tester,
          () async {
            final m = _measure(tester);
            expect(m['active'], isTrue, reason: 'A05 absent on baseline');
            expect(m['maxScrollExtent'] as num, greaterThan(0));
            final scroll = find.descendant(
              of: find.byKey(const ValueKey('login-failure-scroll')),
              matching: find.byType(Scrollable),
            );
            final state = tester.state<ScrollableState>(scroll);
            state.position.jumpTo(state.position.maxScrollExtent);
            await tester.pump();
            final after = _measure(tester),
                notice = (after['notice'] as Map)['bounds'] as Map,
                body = after['body'] as Map;
            expect(
              notice['bottom'] as num,
              lessThanOrEqualTo((body['bottom'] as num) - 23.9),
            );
            expect((after['footer'] as Map)['top'], body['bottom']);
            expect((after['title'] as Map)['scaledFontSize'], 24);
            expect(tester.takeException(), isNull);
          },
          platform: platform,
          width: 320,
          height: 480,
          kind: 'sdk',
        );
      },
    );
  }
  testWidgets(
    '393 realwindow caps frame375 and keeps entire footer safe once',
    (tester) async {
      await _withFailure(
        tester,
        () async {
          final m = _measure(tester), j = f.failureJudgment(m, kind: 'http');
          expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
          expect((m['frame'] as Map)['width'], 375);
          expect(m['scaffoldColor'], '0xFFF5F5F5');
          expect(tester.takeException(), isNull);
        },
        width: 393,
        height: 852,
      );
    },
  );
}
