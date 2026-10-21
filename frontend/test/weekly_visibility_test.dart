import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const picks = [
  ApiWeeklyRecommendationItem(
    id: 11,
    rank: 1,
    type: WeeklyCardType.mostSaved,
    category: ApiCategory(id: 102, name: '여행', color: null, isDefault: false),
  ),
  ApiWeeklyRecommendationItem(
    id: 12,
    rank: 3,
    type: WeeklyCardType.rediscovery,
    category: ApiCategory(
      id: 101,
      name: '매우 긴 실제 카테고리 이름이 끝까지 이어지는 기록',
      color: null,
      isDefault: false,
    ),
  ),
];
void main() {
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final weight in ['Medium', 'SemiBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await loader.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        'real font white cards and two line ellipsis $platform $width',
        (t) async {
          t.view.physicalSize = Size(width, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          var taps = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: WeeklyPickRail(
                  items: picks,
                  onOpenCategory: () {},
                  onSelected: (_) => taps++,
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          for (final id in [11, 12]) {
            expect(
              t.getSize(find.byKey(ValueKey('weekly-card-$id'))),
              const Size(133, 120),
            );
          }
          expect(find.text('다시 발견'), findsOneWidget);
          expect(find.text('공지사항'), findsNothing);
          final rich = find.descendant(
            of: find.byKey(const ValueKey('weekly-card-12')),
            matching: find.byType(RichText),
          );
          final paragraph = t.renderObject<RenderParagraph>(rich.last);
          expect(paragraph.maxLines, 2);
          expect(paragraph.overflow, TextOverflow.ellipsis);
          expect(paragraph.didExceedMaxLines, isTrue);
          expect(paragraph.text.style!.fontFamily, 'Pretendard');
          expect(paragraph.text.style!.fontSize, 16);
          expect(paragraph.text.style!.fontWeight, FontWeight.w600);
          expect(paragraph.text.style!.height, 1.5);
          final text = t.widget<Text>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('weekly-card-12')),
                  matching: find.byType(Text),
                )
                .last,
          );
          expect(
            (text.textSpan as TextSpan).children!.first.style!.color,
            const Color(0xFFFF0000),
          );
          await t.tap(find.text('다시 발견'));
          expect(taps, 1);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'half-area boundary uses both viewports, scrolling triggers measurement',
    (t) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final exposed = <int>[];
      Widget host(double offset, bool enabled) => MaterialApp(
        home: Scaffold(
          body: ScrollNotificationObserver(
            child: SizedBox(
              width: 375,
              height: 300,
              child: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    SizedBox(height: offset),
                    WeeklyPickRail(
                      items: picks,
                      onOpenCategory: () {},
                      exposureEnabled: enabled,
                      onExposed: exposed.add,
                    ),
                    const SizedBox(height: 500),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpWidget(host(241, false));
      await t.pumpAndSettle();
      expect(exposed, isEmpty);
      await t.pumpWidget(host(241, true));
      await t.pumpAndSettle();
      expect(exposed, isEmpty);
      final box = t.renderObject<RenderBox>(
        find.byKey(const ValueKey('weekly-card-11')),
      );
      expect(weeklyVisibleFraction(box), closeTo(59 / 120, 0.00001));
      controller.jumpTo(1);
      await t.pumpAndSettle();
      expect(exposed, [11, 12]);
      expect(weeklyVisibleFraction(box), 0.5);
      await t.pumpWidget(host(600, true));
      await t.pumpAndSettle();
      exposed.clear();
      expect(weeklyVisibleFraction(box), 0);
      controller.jumpTo(500);
      await t.pumpAndSettle();
      expect(exposed, [11, 12]);
    },
  );
  testWidgets('narrow horizontal viewport excludes less than half a card', (
    t,
  ) async {
    final exposed = <int>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 210,
            child: WeeklyPickRail(
              items: picks,
              onOpenCategory: () {},
              exposureEnabled: true,
              onExposed: exposed.add,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(exposed.toSet(), {11});
    await t.drag(find.byType(ListView), const Offset(-80, 0));
    await t.pumpAndSettle();
    expect(exposed, contains(12));
  });
}
