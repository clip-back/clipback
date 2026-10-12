import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen,
  double topInset,
) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(
          size: const Size(375, 812),
          padding: EdgeInsets.only(top: topInset),
          viewPadding: EdgeInsets.only(top: topInset),
        ),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final inset in [0.0, 59.0, 62.0]) {
    testWidgets('login retains its safe layout and callbacks at inset $inset', (
      tester,
    ) async {
      var backCalls = 0;
      var guestCalls = 0;
      final providers = <SocialLoginProvider>[];
      await _pumpScreen(
        tester,
        LoginScreen(
          onContinue: () async => guestCalls++,
          onSocialLogin: (provider) async => providers.add(provider),
          providers: const [SocialLoginProvider.google],
          linkingGuest: true,
          onBack: () => backCalls++,
        ),
        inset,
      );

      final logo = tester.getRect(find.byType(SvgPicture).first);
      final back = tester.getRect(find.widgetWithText(TextButton, '뒤로'));
      expect(back.top, inset + 40);
      expect(logo.top - back.bottom, 70);
      expect(logo.height, 60);

      await tester.tap(find.text('뒤로'));
      await tester.tap(find.text('구글로 계속하기'));
      await tester.tap(find.text('게스트로 계속 사용'));
      await tester.pumpAndSettle();
      expect(backCalls, 1);
      expect(providers, [SocialLoginProvider.google]);
      expect(guestCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding keeps its spacing and page flow at inset $inset', (
      tester,
    ) async {
      var doneCalls = 0;
      await _pumpScreen(
        tester,
        OnboardingScreen(onDone: () => doneCalls++),
        inset,
      );

      final title = tester.getRect(find.text('저장한 정보,\n다시 보고 있나요?'));
      expect(title.top, inset + 104);
      final next = tester.getRect(find.widgetWithText(PrimaryButton, '다음'));
      expect(next.bottom, 812 - 40);

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('흩어진 정보를\n허투루 넘기지 않도록,'), findsOneWidget);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      expect(doneCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'interests keeps its back and done buttons safe at inset $inset',
      (tester) async {
        var backCalls = 0;
        var doneCalls = 0;
        await _pumpScreen(
          tester,
          InterestSelectionScreen(
            onBack: () => backCalls++,
            onDone: () => doneCalls++,
          ),
          inset,
        );

        final backFinder = find.byWidgetPredicate(
          (widget) => widget is SvgIconButton && widget.asset == Assets.back,
        );
        final back = tester.getRect(backFinder);
        final title = tester.getRect(find.text('주로 어떤 정보를\n저장하고 싶으신가요?'));
        expect(back.top, inset + 8);
        expect(title.top, inset + 80);
        expect(back.bottom, lessThanOrEqualTo(title.top));
        final done = tester.getRect(find.widgetWithText(PrimaryButton, '완료'));
        expect(done.bottom, 812 - 16);

        await tester.tap(backFinder);
        await tester.tap(find.text('완료'));
        await tester.pumpAndSettle();
        expect(backCalls, 1);
        expect(doneCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
