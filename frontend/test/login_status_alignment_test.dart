import 'dart:async';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_navigation.dart';
import 'fixtures/login_status_fixture.dart' as f;
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await loader.load();
    await (FontLoader(
      'PretendardDetail',
    )..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'))).load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final height in [812.0, 520.0]) {
        testWidgets(
          '${platform.name} ${width}x$height actual-root A03 to A04 unchanged credentials',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, height);
            final top = platform == TargetPlatform.iOS ? 50.0 : 24.0,
                bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
            tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
            tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
            debugDefaultTargetPlatformOverride = platform;
            final server = p.LoginServer(),
                social = p.LoginControlledSocial(platform),
                storage = p.LoginMemoryStorage();
            final gate = Completer<SocialCredential?>();
            social.gate = gate;
            Future<void>? pending;
            try {
              await http.runWithClient(() async {
                await tester.pumpWidget(
                  ClipbackApp(sessionStorage: storage, socialAuth: social),
                );
                await completeAppStartup(tester);
                final login = tester.widget<LoginScreen>(
                  find.byType(LoginScreen),
                );
                final attempt = await startLoginChoice(
                  tester,
                  () => login.onSocialLogin(SocialLoginProvider.google),
                );
                pending = attempt.completion;
                await tester.pump(const Duration(milliseconds: 300));
                final root = tester.element(find.byType(ClipbackApp));
                for (final kind in ['progress', 'cancelled']) {
                  if (kind == 'cancelled') {
                    gate.complete(null);
                    await pending;
                    await tester.pumpAndSettle();
                  }
                  final m = f.statusMeasure(root, kind),
                      j = f.statusJudgment(m);
                  expect(
                    j['stylePassed'],
                    isTrue,
                    reason: '$m ${j['styleFailures']}',
                  );
                  expect(
                    j['layoutPassed'],
                    isTrue,
                    reason: '$m ${j['layoutFailures']}',
                  );
                  expect(
                    j['assetPassed'],
                    isTrue,
                    reason: '$m ${j['assetFailures']}',
                  );
                  expect(tester.takeException(), isNull);
                  if (kind == 'cancelled') {
                    await login.onSocialLogin(SocialLoginProvider.google);
                    await login.onContinue();
                    await tester.pump();
                    expect(social.calls, ['google']);
                    expect(server.guestIssuances, 0);
                    expect(
                      find.byKey(const ValueKey('login-cancelled-screen')),
                      findsOneWidget,
                    );
                  }
                  final actualScroll = find.byKey(
                    ValueKey('login-$kind-scroll'),
                  );
                  final scrollable = find
                      .descendant(
                        of: actualScroll,
                        matching: find.byType(Scrollable),
                      )
                      .first;
                  final state = tester.state<ScrollableState>(scrollable);
                  state.position.jumpTo(state.position.maxScrollExtent);
                  await tester.pump();
                  final end = f.statusMeasure(root, kind);
                  if (kind == 'cancelled') {
                    final viewport = end['viewport'] as Map,
                        image = (end['illustration'] as Map)['bounds'] as Map;
                    expect(
                      image['bottom'],
                      lessThanOrEqualTo((viewport['bottom'] as num) - 23.9),
                    );
                  }
                }
                expect(social.calls, ['google']);
                expect(server.socialIssuances, 0);
                expect(storage.writes, 0);
                await tester.tap(
                  find.byKey(const ValueKey('login-cancelled-primary')),
                );
                await tester.pumpAndSettle();
                expect(find.byType(LoginScreen), findsOneWidget);
                expect(server.socialIssuances, 0);
                expect(
                  find.byWidgetPredicate(
                    (w) => w.runtimeType.toString() == 'PermissionGuideSheet',
                  ),
                  findsNothing,
                );
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump(const Duration(seconds: 1));
              }, () => server.client);
            } finally {
              if (!gate.isCompleted) gate.complete(null);
              await pending;
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(seconds: 1));
              server.client.close();
              tester.view.reset();
              debugDefaultTargetPlatformOverride = null;
            }
          },
        );
      }
    }
  }
}
