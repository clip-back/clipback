import 'dart:convert';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'auth_navigation.dart';
import 'fixtures/account_conflict_fixture.dart' as f;
import 'fixtures/splash_alignment_fixture.dart' as splash;
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as login;
import 'support/account_conflict_preview.dart' as preview;

Future<void> _withConflict(
  WidgetTester tester,
  Future<void> Function() body, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height < 500 ? 812 : height);
  final top = platform == TargetPlatform.iOS ? 50.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() {
    tester.view.reset();
    debugDefaultTargetPlatformOverride = null;
  });
  final server = preview.ConflictServer(),
      storage = splash.SplashMemoryStorage()
        ..value = splash.splashStoredSession,
      social = login.LoginControlledSocial(platform)
        ..cancel = false
        ..fail = false;
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(sessionStorage: storage, socialAuth: social),
      );
      await completeAppStartup(tester);
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MyProfileRow));
      await tester.pumpAndSettle();
      await tester
          .widget<AccountManagementScreen>(find.byType(AccountManagementScreen))
          .onConnect();
      await tester.pumpAndSettle();
      final attempt = await startLoginChoice(
        tester,
        () => tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google),
      );
      await attempt.completion;
      await tester.pumpAndSettle();
      if (height < 500) {
        tester.view.physicalSize = Size(width, height);
        await tester.pumpAndSettle();
      }
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
    f.conflictMeasure(tester.element(find.byType(ClipbackApp)));
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
    'fixed upgrade409 fixture and guest data preserve real status',
    () async {
      final server = preview.ConflictServer();
      try {
        final response = await server.controlledClient.post(
          Uri.parse(
            'https://fixture.invalid/api/v1/auth/social/google/upgrade',
          ),
        );
        expect(response.statusCode, 409);
        expect(server.upgrades, 1);
        expect(server.socialIssuances, 0);
        expect(server.guest, isTrue);
        expect(server.records, hasLength(1));
      } finally {
        server.controlledClient.close();
        server.client.close();
      }
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final kind in ['standard']) {
        testWidgets(
          '${platform.name} width$width $kind A05-1 actual fonts geometry assets1x',
          (tester) async {
            await _withConflict(
              tester,
              () async {
                final m = _measure(tester), j = f.conflictJudgment(m);
                if (j['layoutPassed'] != true) {
                  debugPrint('A051_MEASUREMENT ${jsonEncode(m)}');
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
        await _withConflict(
          tester,
          () async {
            final m = _measure(tester);
            expect(m['active'], isTrue, reason: 'A05-1 absent on baseline');
            expect(m['maxScrollExtent'] as num, greaterThan(0));
            final scroll = find.descendant(
              of: find.byKey(const ValueKey('account-link-conflict-scroll')),
              matching: find.byType(Scrollable),
            );
            final state = tester.state<ScrollableState>(scroll);
            state.position.jumpTo(state.position.maxScrollExtent);
            await tester.pump();
            final after = _measure(tester),
                notice = (after['warning'] as Map)['bounds'] as Map,
                body = after['body'] as Map;
            expect(
              notice['bottom'] as num,
              lessThanOrEqualTo((body['bottom'] as num) - 23.9),
            );
            final rich = find.descendant(
              of: find.byKey(const ValueKey('account-link-conflict-warning')),
              matching: find.byType(RichText),
            );
            final paragraph = tester.renderObject<RenderParagraph>(rich),
                text = tester.widget<RichText>(rich).text.toPlainText();
            final lastBox = paragraph
                .getBoxesForSelection(
                  TextSelection(baseOffset: 0, extentOffset: text.length),
                )
                .last
                .toRect();
            final actualLastLine = MatrixUtils.transformRect(
              paragraph.getTransformTo(null),
              lastBox,
            );
            expect(
              actualLastLine.top,
              greaterThanOrEqualTo((body['top'] as num) - .1),
            );
            expect(
              actualLastLine.bottom,
              lessThanOrEqualTo((body['bottom'] as num) - 23.9),
            );
            expect(
              actualLastLine.left,
              greaterThanOrEqualTo((body['left'] as num) - .1),
            );
            expect(
              actualLastLine.right,
              lessThanOrEqualTo((body['right'] as num) + .1),
            );
            expect((after['footer'] as Map)['top'], body['bottom']);
            expect((after['title'] as Map)['scaledFontSize'], 24);
            expect(tester.takeException(), isNull);
          },
          platform: platform,
          width: 320,
          height: 400,
        );
      },
    );
  }
  testWidgets(
    '393 realwindow caps frame375 and keeps entire footer safe once',
    (tester) async {
      await _withConflict(
        tester,
        () async {
          final m = _measure(tester), j = f.conflictJudgment(m);
          expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
          expect((m['frame'] as Map)['width'], 375);
          expect(m['background'], '0xFFF5F5F5');
          expect(tester.takeException(), isNull);
        },
        width: 393,
        height: 852,
      );
    },
  );
}
