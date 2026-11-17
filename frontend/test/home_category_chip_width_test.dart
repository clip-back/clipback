// #415 (sheet 122): home category chips keep 8 on each side of the label.
// Chip width = max(70, label width + 16), at most screen width - 32, where the
// label ends with an ellipsis. Measured with the bundled Pretendard faces the
// chip label names explicitly (Medium 500, SemiBold 600 when selected).
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/theme_font_app.dart';

CategoryItem _category(int id, String name) => CategoryItem(
  id: id,
  name: name,
  color: AppColors.main,
  tint: AppColors.mainSubtle,
  deep: AppColors.mainDeep,
);

final _examples = [
  _category(1, '생활 꿀팁'),
  _category(2, '제품 추천'),
  _category(3, '다이어트식단'),
  _category(4, '맛집 리스트'),
];

// Maximum category name length (40).
final _veryLong = ('아주긴카테고리이름' * 5).substring(0, 40);

Future<List<CategoryItem?>> _home(
  WidgetTester tester, {
  required double width,
  required double scale,
  required List<CategoryItem> categories,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  final selected = <CategoryItem?>[];
  int? activeId;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: HomeContentPanel(
                weeklyItems: const [],
                activeCategoryId: activeId,
                contents: const [],
                categories: categories,
                bookmarkedIds: const {},
                onOpenArchive: () {},
                onOpenCategories: () {},
                onOpenContent: (_) {},
                onToggleBookmark: (_) {},
                onCategorySelected: (category) {
                  selected.add(category);
                  setState(() => activeId = category?.id);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return selected;
}

// Chips past the screen edge are built but offstage; measure them too.
Finder _label(String name) => find.descendant(
  of: find.byType(CategoryChips),
  matching: find.text(name, skipOffstage: false),
  skipOffstage: false,
);

Rect _chip(WidgetTester tester, String name) => tester.getRect(
  find
      .ancestor(
        of: _label(name),
        matching: find.byType(Material, skipOffstage: false),
      )
      .first,
);

double _labelWidth(String name, double scale, {required bool active}) {
  final painter = TextPainter(
    text: TextSpan(
      text: name,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 15,
        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: -0.375,
      ),
    ),
    textScaler: TextScaler.linear(scale),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final value = painter.width;
  painter.dispose();
  return value;
}

void main() {
  setUpAll(loadPretendard);

  for (final width in [320.0, 375.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('chips widen with 8 inside at width $width x$scale', (
        tester,
      ) async {
        expect(pretendardLoaded(), isTrue);
        await _home(tester, width: width, scale: scale, categories: _examples);
        final names = ['전체보기', ..._examples.map((c) => c.name)];
        final chips = [for (final name in names) _chip(tester, name)];
        // ④ first chip starts at 16, chips 4 apart.
        expect(chips.first.left, moreOrLessEquals(16, epsilon: .01));
        for (var i = 1; i < chips.length; i++) {
          expect(
            chips[i].left - chips[i - 1].right,
            moreOrLessEquals(4, epsilon: .01),
            reason: names[i],
          );
        }
        for (var i = 0; i < names.length; i++) {
          final name = names[i], chip = chips[i];
          final text = tester.getRect(_label(name));
          final labelWidth = _labelWidth(name, scale, active: i == 0);
          // ② widened chips show the whole label 8 from each chip edge.
          if (labelWidth + 16 > 70) {
            expect(
              text.width,
              moreOrLessEquals(labelWidth, epsilon: .5),
              reason: '$name label',
            );
            expect(
              text.left - chip.left,
              moreOrLessEquals(8, epsilon: .5),
              reason: '$name left',
            );
            expect(
              chip.right - text.right,
              moreOrLessEquals(8, epsilon: .5),
              reason: '$name right',
            );
          }
          // ① short names keep the 70 chip at 1.0.
          if (scale == 1 && ['전체보기', '생활 꿀팁', '제품 추천'].contains(name)) {
            expect(
              chip.width,
              moreOrLessEquals(70, epsilon: .01),
              reason: name,
            );
          }
          final expected = labelWidth + 16 > 70 ? labelWidth + 16 : 70.0;
          expect(chip.width, moreOrLessEquals(expected, epsilon: .5));
          expect(
            tester
                .renderObject<RenderParagraph>(_label(name))
                .didExceedMaxLines,
            isFalse,
            reason: name,
          );
        }
        // Issue #415 position table (width 375; 320 shares the same chip
        // starts and widths).
        final table = scale == 1
            ? {'다이어트식단': (238.0, 91.5), '맛집 리스트': (333.5, 82.2)}
            : {
                '전체보기': (16.0, 81.9),
                '생활 꿀팁': (101.9, 86.3),
                '제품 추천': (192.2, 86.3),
                '다이어트식단': (282.5, 114.9),
                '맛집 리스트': (401.4, 102.8),
              };
        for (final MapEntry(key: name, value: (left, w)) in table.entries) {
          final chip = _chip(tester, name);
          expect(chip.left, moreOrLessEquals(left, epsilon: .15), reason: name);
          expect(chip.width, moreOrLessEquals(w, epsilon: .15), reason: name);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('a 40 letter name stops at width - 32 at $width x$scale', (
        tester,
      ) async {
        expect(pretendardLoaded(), isTrue);
        expect(_veryLong.length, 40);
        await _home(
          tester,
          width: width,
          scale: scale,
          categories: [_category(9, _veryLong)],
        );
        // ③ the chip stops at the visible row width and the label ellipsizes.
        final chip = _chip(tester, _veryLong);
        expect(chip.width, moreOrLessEquals(width - 32, epsilon: .01));
        expect(
          chip.left - _chip(tester, '전체보기').right,
          moreOrLessEquals(4, epsilon: .01),
        );
        final text = tester.getRect(_label(_veryLong));
        expect(text.left - chip.left, moreOrLessEquals(8, epsilon: .5));
        expect(chip.right - text.right, moreOrLessEquals(8, epsilon: .5));
        final paragraph = tester.renderObject<RenderParagraph>(
          _label(_veryLong),
        );
        expect(paragraph.overflow, TextOverflow.ellipsis);
        expect(paragraph.didExceedMaxLines, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('tapping a widened chip selects it with the full gray fill', (
    tester,
  ) async {
    expect(pretendardLoaded(), isTrue);
    final selected = await _home(
      tester,
      width: 375,
      scale: 1,
      categories: _examples,
    );
    const name = '다이어트식단';
    expect(_chip(tester, name).width, greaterThan(70));
    await tester.tap(_label(name));
    await tester.pumpAndSettle();
    // ⑤ the tapped category is selected and its gray fill spans the chip.
    expect(selected.single?.id, 3);
    final material = tester.widget<Material>(
      find
          .ancestor(
            of: _label(name),
            matching: find.byType(Material, skipOffstage: false),
          )
          .first,
    );
    expect(material.color, AppColors.faint);
    final chip = _chip(tester, name), text = tester.getRect(_label(name));
    expect(chip.height, 32);
    expect(text.left - chip.left, moreOrLessEquals(8, epsilon: .5));
    expect(chip.right - text.right, moreOrLessEquals(8, epsilon: .5));
    expect(
      tester.renderObject<RenderParagraph>(_label(name)).text.style?.fontWeight,
      FontWeight.w600,
    );
    expect(tester.takeException(), isNull);
  });
}
