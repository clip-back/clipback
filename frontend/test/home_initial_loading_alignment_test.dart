import 'dart:convert';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'fixtures/home_initial_loading_fixture.dart' as geometry;
import 'fixtures/splash_alignment_fixture.dart' as splash;
import 'support/home_initial_loading_preview.dart' as preview;
import 'support/login_alignment_preview.dart' as login;

Future<void> _withLoading(
  WidgetTester tester,
  Future<void> Function() body, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 50.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() {
    tester.view.reset();
    debugDefaultTargetPlatformOverride = null;
  });
  final server = preview.ControlledServer();
  final storage = splash.SplashMemoryStorage()
    ..value = splash.splashStoredSession;
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(
          sessionStorage: storage,
          socialAuth: login.LoginControlledSocial(platform),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 900));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await body();
    } finally {
      server.release();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      debugDefaultTargetPlatformOverride = null;
    }
  }, () => server.controlledClient);
}

Map<String, Object?> _measure(WidgetTester tester) =>
    geometry.loadingMeasure(tester.element(find.byType(ClipbackApp)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native fixture delegates existing social session response', () async {
    final server = preview.ControlledServer();
    final response = await server.controlledClient.post(
      Uri.parse('https://fixture.invalid/api/v1/auth/social/google'),
      body: '{"token":"fixture-only"}',
    );
    expect(response.statusCode, 200);
    expect(server.socialIssuances, 1);
  });
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
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width first home loading actual fonts styles geometry assets',
        (tester) async {
          await _withLoading(
            tester,
            () async {
              final m = _measure(tester),
                  judgment = geometry.loadingJudgment(m);
              if (judgment['layoutPassed'] != true) {
                debugPrint('HOME_LOAD_MEASUREMENT ${jsonEncode(m)}');
              }
              expect(
                judgment['stylePassed'],
                isTrue,
                reason: '${judgment['styleFailures']}',
              );
              expect(
                judgment['layoutPassed'],
                isTrue,
                reason: '${judgment['layoutFailures']}',
              );
              expect(
                judgment['assetPassed'],
                isTrue,
                reason: '${judgment['assetFailures']}',
              );
              expect(
                (m['illustration'] as Map)['asset'],
                'assets/figma/logout-illustration.png',
              );
              expect(
                (m['dots'] as Map)['asset'],
                'assets/figma/home-initial-loading-dots.svg',
              );
              final group = m['group'] as Map;
              expect(group['height'], closeTo(338.4, .8));
              expect(tester.takeException(), isNull);
            },
            platform: platform,
            width: width,
          );
        },
      );
    }
  }
  testWidgets(
    '375 original safe frame keeps192 title and natural description width without wrapping',
    (tester) async {
      await _withLoading(tester, () async {
        final m = _measure(tester),
            title = m['title'] as Map?,
            description = m['description'] as Map?;
        expect(
          title,
          isNotNull,
          reason: 'Target actual paragraph absent on baseline',
        );
        expect((title!['bounds'] as Map)['height'], closeTo(38.4, .5));
        expect((description!['bounds'] as Map)['height'], closeTo(24, .5));
        expect(
          (description['bounds'] as Map)['width'] as num,
          greaterThan(192),
        );
        expect(
          (description['bounds'] as Map)['width'] as num,
          lessThanOrEqualTo(224),
        );
        expect(tester.takeException(), isNull);
      });
    },
  );
  testWidgets('393 window keeps375 frame background and safe group center', (
    tester,
  ) async {
    await _withLoading(
      tester,
      () async {
        final m = _measure(tester), j = geometry.loadingJudgment(m);
        expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
        expect((m['frame'] as Map)['width'], 375);
        expect(m['scaffoldColor'], '0xFFF5F5F5');
        expect(tester.takeException(), isNull);
      },
      width: 393,
      height: 852,
    );
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '${platform.name} low viewport natural type scroll reaches dots with bottom24',
      (tester) async {
        await _withLoading(
          tester,
          () async {
            final m = _measure(tester);
            expect(
              m['active'],
              isTrue,
              reason: 'Target home loading absent on baseline',
            );
            expect(m['maxScrollExtent'] as num, greaterThan(0));
            expect(m['fittedBoxCount'], 0);
            await tester.ensureVisible(
              find.byKey(const ValueKey('home-initial-loading-dots')),
            );
            await tester.pump();
            final after = _measure(tester),
                dots = (after['dots'] as Map)['bounds'] as Map;
            final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
            expect(dots['bottom'] as num, lessThanOrEqualTo(200 - bottom + .5));
            expect(((after['title'] as Map)['scaledFontSize']), 24);
            expect(tester.takeException(), isNull);
          },
          platform: platform,
          width: 320,
          height: 200,
        );
      },
    );
  }
}
