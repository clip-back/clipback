import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
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
const bodyByType = {
  WeeklyCardType.mostSaved: '장소 카테고리를 다시 볼까요?',
  WeeklyCardType.mostViewed: '내가 관심 있던 장소',
  WeeklyCardType.rediscovery: '장소 카테고리를 다시 볼까요?',
};
const labelByType = {
  WeeklyCardType.mostSaved: '많이 저장한',
  WeeklyCardType.mostViewed: '자주 본',
  WeeklyCardType.rediscovery: '다시 발견',
};

Future<RenderParagraph> pumpPick(
  WidgetTester t,
  WeeklyCardType type, {
  String name = '장소',
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double scale = 1,
}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: WeeklyPickRail(
          items: [
            ApiWeeklyRecommendationItem(
              id: 231,
              rank: 1,
              type: type,
              category: ApiCategory(
                id: 102,
                name: name,
                color: null,
                isDefault: false,
              ),
            ),
          ],
          onOpenCategory: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return t.renderObject<RenderParagraph>(
    find
        .descendant(
          of: find.byKey(const ValueKey('weekly-card-231')),
          matching: find.byType(RichText),
        )
        .last,
  );
}

// Resolve inherited styles from the rendered paragraph, including every body
// segment: a null child color alone does not prove its actual displayed color.
void expectUniformBody(RenderParagraph paragraph) {
  void visit(InlineSpan span, TextStyle inherited) {
    final effective = inherited.merge(span.style);
    if (span is TextSpan) {
      if (span.text?.isNotEmpty ?? false) {
        expect(effective.color, AppColors.text, reason: span.text);
        expect(effective.fontFamily, 'Pretendard');
        expect(effective.fontSize, 16);
        expect(effective.fontWeight, FontWeight.w600);
        expect(effective.height, 1.5);
        expect(effective.letterSpacing, -0.4);
        expect(effective.fontStyle ?? FontStyle.normal, FontStyle.normal);
        expect(
          effective.decoration ?? TextDecoration.none,
          TextDecoration.none,
        );
        expect(effective.foreground, isNull);
        expect(effective.background, isNull);
        expect(effective.shadows, isNull);
      }
      for (final child in span.children ?? <InlineSpan>[]) {
        visit(child, effective);
      }
    }
  }

  expect(AppColors.text, const Color(0xFF1A1A1A));
  visit(paragraph.text, const TextStyle());
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final weight in ['Medium', 'SemiBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await loader.load();
  });
  for (final type in WeeklyCardType.values) {
    testWidgets('weekly effective body color $type', (t) async {
      final paragraph = await pumpPick(t, type);
      expectUniformBody(paragraph);
    });
    testWidgets('weekly complete body wording $type', (t) async {
      final paragraph = await pumpPick(t, type);
      expect(paragraph.text.toPlainText(), bodyByType[type]);
      expect(find.text(labelByType[type]!), findsOneWidget);
    });
  }
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
          expectUniformBody(paragraph);
          await t.tap(find.text('다시 발견'));
          expect(taps, 1);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  const names = {
    'short': '장소',
    'spaced': '매우 긴 실제 카테고리 이름이 끝까지 이어지는 기록',
    'ko40': '가나다라마바사아자차카타파하가나다라마바사아자차카타파하가나다라마바사아자차카타',
    'en40': 'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMN',
  };
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final type in WeeklyCardType.values) {
        for (final entry in names.entries) {
          for (final scale in [1.0, 1.15, 1.3]) {
            testWidgets(
              'weekly layout $platform $width $type ${entry.key} scale $scale',
              (t) async {
                if (entry.key.endsWith('40')) {
                  expect(entry.value.runes.length, 40);
                  expect(entry.value.length, 40);
                }
                final paragraph = await pumpPick(
                  t,
                  type,
                  name: entry.value,
                  platform: platform,
                  width: width,
                  scale: scale,
                );
                expectUniformBody(paragraph);
                final card = find.byKey(const ValueKey('weekly-card-231'));
                final cardSize = t.getSize(card);
                expect(cardSize.width, 133);
                final label = find
                    .descendant(of: card, matching: find.byType(RichText))
                    .first;
                // Pretendard line metrics are rounded by the engine; keep the
                // current measured rail heights rather than a fixed 120px.
                expect(
                  cardSize.height,
                  {1.0: 120.0, 1.15: 128.0, 1.3: 136.0}[scale],
                );
                expect(find.text(labelByType[type]!), findsOneWidget);
                final expectedBody = type == WeeklyCardType.mostViewed
                    ? '내가 관심 있던 ${entry.value}'
                    : '${entry.value} 카테고리를 다시 볼까요?';
                expect(paragraph.text.toPlainText(), expectedBody);
                expect(paragraph.maxLines, 2);
                expect(paragraph.overflow, TextOverflow.ellipsis);
                expect(paragraph.size.width, 96);
                expect(
                  paragraph.size.height,
                  {1.0: 48.0, 1.15: 56.0, 1.3: 62.0}[scale],
                );
                if (entry.key != 'short') {
                  expect(paragraph.didExceedMaxLines, isTrue);
                }
                final boxes = paragraph.getBoxesForSelection(
                  TextSelection(
                    baseOffset: 0,
                    extentOffset: expectedBody.length,
                  ),
                );
                expect(boxes, isNotEmpty);
                // Inspect actual laid-out glyph boxes, not only maxLines.
                final lines = boxes.map((box) => box.top).toSet();
                expect(lines.length, 2);
                for (final box in boxes) {
                  // Negative letter spacing extends selection boxes by half
                  // of the scaled spacing (at most 0.26px), within padding.
                  expect(box.left, greaterThanOrEqualTo(-0.27));
                  expect(box.right, lessThanOrEqualTo(96.01));
                  expect(box.top, greaterThanOrEqualTo(-0.01));
                  expect(
                    box.bottom,
                    lessThanOrEqualTo(paragraph.size.height + 0.01),
                  );
                }
                final cardRect = t.getRect(card);
                final bodyOrigin = paragraph.localToGlobal(Offset.zero);
                expect(bodyOrigin.dx - cardRect.left, closeTo(16, 0.01));
                expect(
                  cardRect.right - bodyOrigin.dx - paragraph.size.width,
                  closeTo(21, 0.01),
                );
                expect(
                  cardRect.bottom - bodyOrigin.dy - paragraph.size.height,
                  closeTo(16, 0.01),
                );
                expect(
                  bodyOrigin.dy,
                  greaterThanOrEqualTo(t.getRect(label).bottom),
                );
                expect(t.takeException(), isNull);
              },
            );
          }
        }
      }
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
