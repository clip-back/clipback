import 'support/app_startup.dart';
import 'dart:async';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/entry_widgets.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/login_alignment_preview.dart' as fixture;

Size? _legacyMetricBefore;
Size _legacyMetric() {
  final p = TextPainter(
    text: const TextSpan(
      text: '저장한 정보를 다시 볼 순간으로',
      style: TextStyle(
        fontFamily: 'RiaSans',
        fontFamilyFallback: ['Pretendard'],
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 23 / 16,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return p.size;
}

class _Calls {
  final providers = <SocialLoginProvider>[];
  int guests = 0, backs = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  bool busy = false,
  bool linking = false,
  bool back = false,
  List<SocialLoginProvider>? providers,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: fixture.loginTheme(platform: platform),
      home: LoginScreen(
        onContinue: () async {
          calls.guests++;
        },
        onSocialLogin: (p) async {
          calls.providers.add(p);
        },
        providers: providers ?? fixture.loginPlatformProviders(platform),
        busy: busy,
        linkingGuest: linking,
        onBack: back ? () => calls.backs++ : null,
      ),
    ),
  );
  // A pending spinner must not make pumpAndSettle wait forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return calls;
}

Map<String, Object?> _measure(WidgetTester tester) =>
    fixture.loginMeasure(tester.element(find.byType(LoginScreen)));
Finder _provider(SocialLoginProvider p) =>
    find.text(fixture.loginLabel(p)).evaluate().isNotEmpty
    ? find.text(fixture.loginLabel(p))
    : find.text(fixture.loginLabel(p, legacy: true));
Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await font.load();
    _legacyMetricBefore = _legacyMetric();
    await fixture.loginInspectFontBundle(loadForTest: true);
  });
  test(
    'A02 font is registered exact real RiaSans binary rather than fallback family name',
    () {
      final f = fixture.loginFontBundle;
      expect(
        f['available'],
        isTrue,
        reason:
            'BEFORE missing target font is an expected target failure; capture remains available.',
      );
      expect(f['declared'], isTrue);
      expect(f['faceVerified'], isTrue);
      expect(f['size'], 535616);
      expect(f['magic'], 'OTTO');
      expect(f['loadedForTest'], isTrue);
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width 1x A02 actual font styles geometry assets',
        (tester) async {
          await _pump(tester, platform: platform, width: width);
          final m = _measure(tester), j = fixture.loginJudgment(m);
          expect(j['stylePassed'], isTrue, reason: '${j['styleFailures']}');
          expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
          expect(j['assetPassed'], isTrue, reason: '${j['assetFailures']}');
          expect(m['textScale'], 1.0);
          expect(m['fakeStatusCount'], 0);
          expect(m['textFittedBoxCount'], 0);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        '${platform.name} $width 1x low viewport scroll reaches every provider and guest',
        (tester) async {
          final calls = await _pump(
            tester,
            platform: platform,
            width: width,
            height: 500,
          );
          final m = _measure(tester);
          expect(m['maxScrollExtent'] as num, greaterThan(0));
          for (final p in fixture.loginPlatformProviders(platform)) {
            await _show(tester, _provider(p));
            await tester.tap(_provider(p));
            await tester.pump();
          }
          final guest = find.text('게스트로 시작하기');
          await _show(tester, guest);
          await tester.tap(guest);
          await tester.pump();
          expect(calls.providers, fixture.loginPlatformProviders(platform));
          expect(calls.guests, 1);
          final finalM = _measure(tester),
              viewport = finalM['viewport'] as Map?,
              hit = finalM['guestHit'] as Map;
          expect(finalM['scrollOffset'] as num, greaterThan(0));
          if (viewport != null) {
            expect(
              hit['bottom'] as num,
              lessThanOrEqualTo((viewport['bottom'] as num) + .2),
            );
          }
          final position = fixture.loginPosition(
            tester.element(find.byType(LoginScreen)),
          )!;
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
          final last = _measure(tester),
              body = last['body'] as Map?,
              vp = last['viewport'] as Map?;
          if (body != null && vp != null) {
            expect(
              (vp['bottom'] as num) - (last['guestHit'] as Map)['bottom'],
              closeTo(24, .2),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        '${platform.name} $width provider availability order callbacks and busy locks',
        (tester) async {
          final input = fixture.loginPlatformProviders(platform).toList(),
              original = List<SocialLoginProvider>.from(
                fixture.loginPlatformProviders(platform),
              );
          final calls = await _pump(
            tester,
            platform: platform,
            width: width,
            providers: input,
          );
          final m = _measure(tester),
              buttons = (m['buttons'] as List).cast<Map>();
          expect(
            buttons.map((b) => b['provider']).toList(),
            platform == TargetPlatform.iOS
                ? ['kakao', 'apple', 'google']
                : ['kakao', 'google'],
          );
          expect(input, original);
          for (final p in input) {
            await _show(tester, _provider(p));
            await tester.tap(_provider(p));
            await tester.pump();
          }
          expect(calls.providers, input);
          await _show(tester, find.text('게스트로 시작하기'));
          await tester.tap(find.text('게스트로 시작하기'));
          await tester.pump();
          expect(calls.guests, 1);
          final blocked = await _pump(
            tester,
            platform: platform,
            width: width,
            busy: true,
            providers: input,
          );
          for (final p in input) {
            await _show(tester, _provider(p));
            await tester.tap(_provider(p));
            await tester.pump();
          }
          await _show(tester, find.text('게스트로 시작하기'));
          await tester.tap(find.text('게스트로 시작하기'));
          await tester.pump();
          expect(blocked.providers, isEmpty);
          expect(blocked.guests, 0);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test(
    'isolated RiaSansLogin registration preserves existing shared EntryTagline face metrics',
    () {
      expect(_legacyMetric(), _legacyMetricBefore);
    },
  );
  testWidgets(
    '393px actual window measures inner375 frame at9 and real SafeArea once',
    (tester) async {
      await _pump(tester, width: 393, height: 852);
      final m = _measure(tester), frame = m['frame'] as Map;
      expect(frame['width'], 375);
      expect(frame['left'], 9);
      expect(frame['right'], 384);
      expect(frame['top'], 0);
      expect(frame['height'], 852);
      expect(m['safeTop'], 59);
      expect(m['safeBottom'], 34);
      final viewport = m['viewport'] as Map?;
      if (viewport != null) {
        expect(viewport['left'], 9);
        expect(viewport['width'], 375);
        expect(viewport['top'], 59);
        expect(viewport['bottom'] as num, lessThanOrEqualTo(818));
        expect(viewport['bottom'] as num, greaterThan(viewport['top'] as num));
        final guestHit = m['guestHit'] as Map;
        expect(
          guestHit['top'] as num,
          greaterThanOrEqualTo(viewport['top'] as num),
        );
        expect(
          guestHit['bottom'] as num,
          lessThanOrEqualTo(viewport['bottom'] as num),
        );
      }
      expect((m['logo'] as Map)['bounds']['top'], greaterThanOrEqualTo(59));
      expect(tester.takeException(), isNull);
    },
  );
  for (final variant in ['linking', 'back', 'empty']) {
    testWidgets(
      'legacy $variant keeps prior labels entry widgets order and public callbacks',
      (tester) async {
        final calls = await _pump(
          tester,
          linking: variant == 'linking',
          back: variant != 'empty',
          providers: variant == 'empty' ? const [] : SocialLoginProvider.values,
        );
        expect(find.byType(EntryTagline), findsOneWidget);
        expect(
          _measure(tester)['textFittedBoxCount'] as num,
          greaterThan(0),
          reason:
              'The existing text FittedBox must still be detected; SVG exclusion must not weaken the font-shrink oracle.',
        );
        expect(find.text('또는'), findsNothing);
        if (variant != 'empty') {
          expect(find.text('구글로 계속하기'), findsOneWidget);
          expect(find.text('Google로 계속하기'), findsNothing);
          final buttons = tester
              .widgetList<SocialButton>(find.byType(SocialButton))
              .toList();
          expect(buttons.map((b) => b.label), [
            '구글로 계속하기',
            '카카오로 계속하기',
            'Apple로 계속하기',
          ]);
          if (variant == 'linking') {
            expect(find.text('게스트의 저장 데이터를 계정에 연결해요.'), findsOneWidget);
          }
          await _show(tester, find.text('뒤로'));
          await tester.tap(find.text('뒤로'));
          await tester.pump();
          expect(calls.backs, 1);
        }
        final label = variant == 'linking' ? '게스트로 계속 사용' : '게스트로 시작하기';
        await _show(tester, find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
        expect(calls.guests, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'ordinary custom subset sorts a copy without unsupported provider or input mutation',
    (tester) async {
      final values = [SocialLoginProvider.google, SocialLoginProvider.kakao];
      await _pump(tester, providers: values);
      expect(values, [SocialLoginProvider.google, SocialLoginProvider.kakao]);
      expect((_measure(tester)['buttons'] as List).map((b) => b['provider']), [
        'kakao',
        'google',
      ]);
      expect(find.text('Apple로 계속하기'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual root empty session cancellation busy duplicate failure retry and new flow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      final server = fixture.LoginServer(),
          social = fixture.LoginControlledSocial(TargetPlatform.iOS),
          storage = fixture.LoginMemoryStorage();
      addTearDown(server.client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          ClipbackApp(
            key: UniqueKey(),
            sessionStorage: storage,
            socialAuth: social,
          ),
        );
        await completeAppStartup(tester);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(server.requests, isEmpty);
        expect(storage.value, isNull);
        for (final p in social.supportedProviders) {
          await tester
              .widget<LoginScreen>(find.byType(LoginScreen))
              .onSocialLogin(p);
          await tester.pumpAndSettle();
          expect(storage.value, isNull);
          expect(server.socialIssuances, 0);
          expect(storage.writes, 0);
        }
        expect(server.challenges, 1);
        social.gate = Completer<SocialCredential?>();
        final pending = tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pump();
        final count = social.calls.length;
        await tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.kakao);
        await tester.widget<LoginScreen>(find.byType(LoginScreen)).onContinue();
        expect(social.calls.length, count);
        expect(server.guestIssuances, 0);
        social.gate!.complete(null);
        await pending;
        await tester.pumpAndSettle();
        social.gate = null;
        social.cancel = false;
        server.failIssuance = true;
        await tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(storage.value, isNull);
        expect(server.socialIssuances, 1);
        await tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(server.socialIssuances, 2);
        expect(storage.writes, 1);
        expect(server.unexpected, isEmpty);
        expect(server.contentWrites, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => server.client);
      final next = fixture.LoginServer()..newUser = true,
          auth = fixture.LoginControlledSocial(TargetPlatform.iOS)
            ..cancel = false,
          empty = fixture.LoginMemoryStorage();
      addTearDown(next.client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          ClipbackApp(
            key: UniqueKey(),
            sessionStorage: empty,
            socialAuth: auth,
          ),
        );
        await completeAppStartup(tester);
        await tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(next.socialIssuances, 1);
        expect(next.guestIssuances, 0);
        expect(next.unexpected, isEmpty);
        expect(next.contentWrites, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => next.client);
      expect(tester.takeException(), isNull);
    },
  );
}
