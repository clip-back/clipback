import 'package:clipback_frontend/features/auth/entry_widgets.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/splash_alignment_fixture.dart' as fixture;

Future<void> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  double top = 50,
  double bottom = 34,
  VoidCallback? onDone,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: fixture.splashTheme(platform: platform),
      home: SplashScreen(onDone: onDone ?? () {}),
    ),
  );
  await tester.pump();
}

Map<String, Object?> _measure(WidgetTester tester) =>
    fixture.splashMeasure(tester.element(find.byType(SplashScreen)));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
    await fixture.splashInspectFontBundle(loadForTest: true);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width A01 real font geometry assets at1x',
        (tester) async {
          await _pump(tester, platform: platform, width: width);
          final m = _measure(tester), j = fixture.splashJudgment(m);
          expect(j['stylePassed'], isTrue, reason: '${j['styleFailures']}');
          expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
          expect(j['assetPassed'], isTrue, reason: '${j['assetFailures']}');
          expect(m['textScale'], 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 900));
        },
      );
    }
  }
  testWidgets(
    '375x812 original frame group232x89 starts346 and logo148.771x50',
    (tester) async {
      await _pump(tester);
      final m = _measure(tester), g = m['group'] as Map;
      expect(g['left'], closeTo(72, .2));
      expect(g['top'], closeTo(346, .2));
      expect(g['height'], closeTo(89, .2));
      expect(g['width'], 232);
      expect(find.byType(EntryHomeIndicator), findsNothing);
      expect(find.byType(EntryStatusBar), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 900));
    },
  );
  testWidgets('transient zero viewport never creates negative constraints', (
    tester,
  ) async {
    await _pump(tester, width: 0);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(375, 812);
    await tester.pump();
    final judgment = fixture.splashJudgment(_measure(tester));
    expect(judgment['layoutPassed'], isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 900));
  });
  testWidgets(
    '393 wide window has yellow outer surface and capped content no gray gutters',
    (tester) async {
      await _pump(tester, width: 393, height: 852, top: 59, bottom: 34);
      final m = _measure(tester), j = fixture.splashJudgment(m);
      expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
      expect(((m['group'] as Map)['left'] as num) + 116, 197);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 900));
    },
  );
  testWidgets(
    'low safe viewport retains natural font and content accessible by scrolling',
    (tester) async {
      await _pump(tester, width: 320, height: 160, top: 50, bottom: 34);
      final m = _measure(tester);
      expect(m['maxScrollExtent'] as num, greaterThan(0));
      expect(m['textFittedBoxCount'], 0);
      expect((m['tagline'] as Map)['scaledFontSize'], 16);
      await tester.ensureVisible(find.text('저장한 정보를 다시 볼 순간으로'));
      await tester.pump();
      final r = tester.getRect(find.text('저장한 정보를 다시 볼 순간으로'));
      expect(r.bottom, lessThanOrEqualTo(126.2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 900));
    },
  );
  testWidgets('callback fires at900 once no restart on rebuild', (
    tester,
  ) async {
    var done = 0;
    await _pump(tester, onDone: () => done++);
    await tester.pump(const Duration(milliseconds: 899));
    expect(done, 0);
    await tester.pumpWidget(
      MaterialApp(
        theme: fixture.splashTheme(platform: TargetPlatform.iOS),
        home: SplashScreen(onDone: () => done++),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(done, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);
  });
  testWidgets('dispose before900 suppresses late onDone', (tester) async {
    var done = 0;
    await _pump(tester, onDone: () => done++);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(done, 0);
    expect(tester.takeException(), isNull);
  });
}
