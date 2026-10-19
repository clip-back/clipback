// AFTER-only public constructor cases; this file is not part of baseline target runs.
import 'package:clipback_frontend/features/home/notification_list_screen.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/notification_alignment_fixture.dart' as fixture;

Future<void> _show(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double width,
  required List<({String title, String time})> items,
  double height = 480,
  VoidCallback? onBack,
  VoidCallback? onOpenSettings,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
      ),
      home: NotificationListScreen(
        items: items,
        onBack: onBack ?? () {},
        onOpenSettings: onOpenSettings ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectOracle(WidgetTester tester) {
  final m = fixture.notificationMeasure(
        tester.element(find.byType(NotificationListScreen)),
      ),
      j = fixture.notificationJudgment(m);
  for (final pair in {
    'stylePassed': 'styleFailures',
    'layoutPassed': 'layoutFailures',
    'assetPassed': 'assetFailures',
  }.entries) {
    expect(j[pair.key], isTrue, reason: '${j[pair.value]}');
  }
}

Future<void> _max(WidgetTester tester) async {
  final position = fixture.notificationPosition(
    tester.element(find.byType(NotificationListScreen)),
  )!;
  for (
    var i = 0;
    i < 25 && (position.pixels - position.maxScrollExtent).abs() > .2;
    i++
  ) {
    await tester.drag(
      find.byKey(const ValueKey('notification-viewport')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
  }
  expect(position.pixels, closeTo(position.maxScrollExtent, .22));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await fixture.notificationLoadFonts(loadForTest: true);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width long supplied title and time wrap naturally at unchanged font sizes',
        (tester) async {
          final title = List.filled(
                14,
                '긴 알림 제목도 원문을 보존하고 필요한 높이만큼 자연스럽게 늘어납니다.',
              ).join(' '),
              time = '오래 전에 받은 알림의 실제 시간 문구';
          final items = [(title: title, time: time)];
          await _show(tester, platform: platform, width: width, items: items);
          for (final role in ['title', 'time']) {
            final e = find.byKey(ValueKey('notification-$role-0')),
                rich = find.descendant(of: e, matching: find.byType(RichText));
            final p = tester.renderObject<RenderParagraph>(rich),
                style = (p.text as TextSpan).style!;
            expect(p.maxLines, isNull);
            expect(p.softWrap, isTrue);
            expect(p.overflow, isNot(TextOverflow.ellipsis));
            expect(p.didExceedMaxLines, isFalse);
            expect(p.text.toPlainText(), role == 'title' ? title : time);
            expect(style.fontSize, role == 'title' ? 16 : 12);
            expect(p.textScaler.scale(style.fontSize!), style.fontSize);
          }
          expect(
            tester
                .getSize(find.byKey(const ValueKey('notification-row-0')))
                .height,
            greaterThan(76),
          );
          final p = fixture.notificationPosition(
            tester.element(find.byType(NotificationListScreen)),
          )!;
          expect(p.maxScrollExtent, greaterThan(0));
          await _max(tester);
          _expectOracle(tester);
          expect(items, [(title: title, time: time)]);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        '${platform.name} $width explicit empty widget matches original crop typography and low viewport scroll',
        (tester) async {
          for (final height in [812.0, 300.0]) {
            await _show(
              tester,
              platform: platform,
              width: width,
              items: const [],
              height: height,
            );
            _expectOracle(tester);
            final pos = fixture.notificationPosition(
              tester.element(find.byType(NotificationListScreen)),
            )!;
            if (height == 300) expect(pos.maxScrollExtent, greaterThan(0));
            await _max(tester);
            _expectOracle(tester);
            expect(
              find.text(fixture.notificationEmptyBody).hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
  testWidgets(
    'explicit [] header settings and OS back only invoke supplied callbacks',
    (tester) async {
      var backs = 0, settings = 0;
      await _show(
        tester,
        platform: TargetPlatform.iOS,
        width: 375,
        items: const [],
        height: 812,
        onBack: () => backs++,
        onOpenSettings: () => settings++,
      );
      await tester.tap(find.byKey(const ValueKey('notification-settings-hit')));
      await tester.pumpAndSettle();
      expect(settings, 1);
      expect(backs, 0);
      await tester.tap(find.byKey(const ValueKey('notification-back-hit')));
      await tester.pumpAndSettle();
      expect(backs, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(backs, 2);
      expect(settings, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
