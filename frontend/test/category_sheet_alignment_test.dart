import 'dart:convert';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/category_sheet_preview.dart';

Future<GlobalKey<CategorySheetPreviewState>> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  double? bottom,
  bool isolatedFormCapProbe = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      safe = bottom ?? (platform == TargetPlatform.iOS ? 34.0 : 0.0);
  tester.view.padding = FakeViewPadding(top: top, bottom: safe);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: safe);
  addTearDown(tester.view.reset);
  final key = GlobalKey<CategorySheetPreviewState>();
  await tester.pumpWidget(
    CategorySheetPreviewHost(
      key: key,
      platform: platform,
      isolatedFormCapProbe: isolatedFormCapProbe,
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

Future<void> _open(
  WidgetTester tester,
  String kind, {
  String origin = 'archive',
}) async {
  if (origin == 'management') {
    await tester.tap(find.byKey(const ValueKey('archive-manage-categories')));
    await tester.pumpAndSettle();
  }
  if (kind.startsWith('create')) {
    await tester.tap(
      find.byKey(
        ValueKey(
          origin == 'archive' ? 'archive-category-add' : 'management-add',
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (kind == 'create-filled') {
      await tester.enterText(find.byType(TextField), sheetFilledName);
      await tester.pump();
    }
  } else {
    await tester.tap(find.byKey(const ValueKey('archive-category-more-101')));
    await tester.pumpAndSettle();
    if (kind != 'actions') {
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryActionSheet),
          matching: find.text(kind == 'edit' ? '카테고리 수정' : '카테고리 삭제'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
    }
  }
}

Element _root(WidgetTester tester) =>
    tester.element(find.byType(CategorySheetPreviewHost));
Future<void> _ime(
  WidgetTester tester,
  bool shown,
  TargetPlatform platform,
) async {
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = tester.view.viewPadding.bottom;
  tester.view.viewInsets = FakeViewPadding(bottom: shown ? 300 : 0);
  tester.view.padding = FakeViewPadding(top: top, bottom: shown ? 0 : bottom);
  await tester.pumpAndSettle();
}

Finder _label(Type type, String text) =>
    find.descendant(of: find.byType(type), matching: find.text(text));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await font.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final kind in sheetKinds) {
        testWidgets('sheet 1x $kind $platform width$width', (tester) async {
          final key = await _pump(tester, platform: platform, width: width);
          await _open(tester, kind);
          await _ime(
            tester,
            kind.startsWith('create') || kind == 'edit',
            platform,
          );
          final metrics = sheetMeasurements(_root(tester), key.currentState!),
              judgment = sheetJudgment(metrics);
          expect(metrics['visibleKind'], kind);
          expect(() => jsonEncode(metrics), returnsNormally);
          expect(tester.takeException(), isNull);
          expect(
            judgment['styleFindings'],
            isEmpty,
            reason: 'actual effective style ${judgment['styleFindings']}',
          );
          expect(
            judgment['layoutFindings'],
            isEmpty,
            reason: 'actual geometry ${judgment['layoutFindings']}',
          );
        });
      }
    }
  }
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final bottom in [0.0, 34.0, 48.0]) {
      for (final keyboard in [false, true]) {
        testWidgets('form inset $platform bottom$bottom keyboard$keyboard', (
          tester,
        ) async {
          final key = await _pump(tester, platform: platform, bottom: bottom);
          await _open(tester, 'create-filled');
          await _ime(tester, keyboard, platform);
          final m = sheetMeasurements(_root(tester), key.currentState!),
              j = sheetJudgment(m);
          expect(m['osBottom'], bottom);
          expect(m['imeBottom'], keyboard ? 300 : 0);
          expect((m['geometry'] as Map)['inputText'], sheetFilledName);
          expect(tester.takeException(), isNull);
          expect(
            j['layoutFindings'],
            isEmpty,
            reason: '${j['layoutFindings']}',
          );
        });
      }
    }
    testWidgets('actions inset48 $platform', (tester) async {
      final key = await _pump(tester, platform: platform, bottom: 48);
      await _open(tester, 'actions');
      final m = sheetMeasurements(_root(tester), key.currentState!),
          j = sheetJudgment(m);
      expect(m['osBottom'], 48);
      expect(tester.takeException(), isNull);
      expect(j['layoutFindings'], isEmpty, reason: '${j['layoutFindings']}');
    });
    testWidgets('short capped form scroll $platform preserves input/color', (
      tester,
    ) async {
      // 568px still caps the keyboard-open sheet and leaves enough paint
      // viewport for the entire 36px palette, rather than requiring the
      // impossible full visibility of a 36px child inside a 32px viewport.
      final key = await _pump(
        tester,
        platform: platform,
        height: 568,
        bottom: 48,
        isolatedFormCapProbe: true,
      );
      await _open(tester, 'create-filled');
      await _ime(tester, true, platform);
      final m = sheetMeasurements(_root(tester), key.currentState!),
          g = m['geometry'] as Map,
          s = (m['bounds'] as Map)['surface'] as Map;
      expect(tester.takeException(), isNull);
      expect(s['height'], g['surfaceConstraintsMaxHeight']);
      expect(g['bodyScrollMaxExtent'], greaterThan(0));
      final vertical = find.descendant(
        of: find.byType(CategoryFormSheet),
        matching: find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
        ),
      );
      expect(vertical, findsOneWidget);
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: vertical, matching: find.byType(Scrollable)).first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final after = sheetMeasurements(_root(tester), key.currentState!),
          ag = after['geometry'] as Map,
          bounds = after['bounds'] as Map,
          palette = bounds['palette'] as Map,
          viewport = bounds['bodyViewport'] as Map,
          j = sheetJudgment(after);
      expect(ag['bodyScrollOffset'], ag['bodyScrollMaxExtent']);
      expect(
        palette['bottom'] as num,
        lessThanOrEqualTo((viewport['bottom'] as num) + .16),
      );
      expect(
        palette['top'] as num,
        greaterThanOrEqualTo((viewport['top'] as num) - .16),
      );
      expect(ag['inputText'], sheetFilledName);
      expect(ag['paletteSelectedColor'], '0xFFFF6277');
      expect(j['layoutFindings'], isEmpty, reason: '${j['layoutFindings']}');
      await _ime(tester, false, platform);
      final hidden = sheetMeasurements(_root(tester), key.currentState!);
      expect(hidden['osBottom'], 48);
      expect((hidden['geometry'] as Map)['inputText'], sheetFilledName);
      expect(
        (hidden['geometry'] as Map)['paletteSelectedColor'],
        ag['paletteSelectedColor'],
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('action sheet retains actual server count, not loaded count', (
    tester,
  ) async {
    final key = await _pump(tester);
    await _open(tester, 'actions');
    expect(key.currentState!.contents.length, 2);
    expect(
      tester
          .widget<CategoryActionSheet>(find.byType(CategoryActionSheet))
          .contentCount,
      37,
    );
    expect(find.text('저장된 콘텐츠 37'), findsOneWidget);
  });
  testWidgets(
    'delete copy preserves content and other categories with actual name',
    (tester) async {
      final key = await _pump(tester);
      await _open(tester, 'delete');
      final m = sheetMeasurements(_root(tester), key.currentState!);
      expect(
        (m['actualStyles'] as Map)['deleteBody']['text'],
        (m['geometry'] as Map)['preservationCopy'],
      );
      expect(find.textContaining('저장된 콘텐츠는 삭제되지 않아요.'), findsOneWidget);
      expect(find.textContaining('함께 삭제되며'), findsNothing);
    },
  );
  for (final origin in ['archive', 'management']) {
    testWidgets(
      '$origin empty/space stays disabled and valid input is trimmed',
      (tester) async {
        final key = await _pump(tester);
        await _open(tester, 'create-empty', origin: origin);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.enterText(find.byType(TextField), '  실제 생성 이름  ');
        await tester.pump();
        await tester.tap(_label(CategoryCreateSheet, '생성하기'));
        await tester.pumpAndSettle();
        expect(
          key.currentState!.calls.where((v) => v['action'] == 'create').length,
          1,
        );
        expect(key.currentState!.categories.last.name, '실제 생성 이름');
      },
    );
    testWidgets(
      '$origin input/controller/color survive keyboard hide and show',
      (tester) async {
        final key = await _pump(tester);
        await _open(tester, 'edit', origin: origin);
        await tester.enterText(find.byType(TextField), '수정중 입력');
        await tester.pump();
        final controller = tester
            .widget<TextField>(find.byType(TextField))
            .controller;
        final before = tester
            .widget<FolderColorPicker>(find.byType(FolderColorPicker))
            .selectedColor;
        await _ime(tester, true, TargetPlatform.iOS);
        await _ime(tester, false, TargetPlatform.iOS);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller,
          same(controller),
        );
        expect(controller!.text, '수정중 입력');
        expect(
          tester
              .widget<FolderColorPicker>(find.byType(FolderColorPicker))
              .selectedColor,
          before,
        );
        expect(before, sheetPrimary.color);
        key.currentState!.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(
          key.currentState!.calls.where((v) => v['action'] == 'edit'),
          isEmpty,
        );
      },
    );
    testWidgets('$origin create rapid button plus IME submits once', (
      tester,
    ) async {
      final key = await _pump(tester);
      await _open(tester, 'create-filled', origin: origin);
      final button = tester.widget<FilledButton>(find.byType(FilledButton)),
          field = tester.widget<TextField>(find.byType(TextField));
      button.onPressed!();
      field.onSubmitted!(sheetFilledName);
      await tester.pumpAndSettle();
      expect(
        key.currentState!.calls.where((v) => v['action'] == 'create').length,
        1,
      );
      expect(key.currentState!.categories.where((v) => v.id == 900).length, 1);
    });
    testWidgets(
      '$origin edit rapid button plus IME submits once and preserves metadata',
      (tester) async {
        final key = await _pump(tester);
        await _open(tester, 'edit', origin: origin);
        await tester.enterText(find.byType(TextField), '  수정된 자료  ');
        await tester.pump();
        final button = tester.widget<FilledButton>(find.byType(FilledButton)),
            field = tester.widget<TextField>(find.byType(TextField));
        button.onPressed!();
        field.onSubmitted!('  수정된 자료  ');
        await tester.pumpAndSettle();
        expect(
          key.currentState!.calls.where((v) => v['action'] == 'edit').length,
          1,
        );
        final edited = key.currentState!.categories.firstWhere(
          (c) => c.id == 101,
        );
        expect(edited.name, '수정된 자료');
        expect(edited.contentCount, 37);
        expect(edited.lastSavedAt, sheetPrimary.lastSavedAt);
        expect(edited.color, sheetPrimary.color);
      },
    );
    testWidgets(
      '$origin cancel paths preserve category metadata and all contents',
      (tester) async {
        final key = await _pump(tester);
        final before = jsonEncode(
              key.currentState!.categories.map(sheetCategoryData).toList(),
            ),
            contents = jsonEncode(
              key.currentState!.contents.map(sheetContentData).toList(),
            );
        await _open(tester, 'actions', origin: origin);
        key.currentState!.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('archive-category-more-101')),
        );
        await tester.pumpAndSettle();
        await tester.tap(_label(CategoryActionSheet, '카테고리 삭제'));
        await tester.pumpAndSettle();
        await tester.pump();
        await tester.tap(_label(CategoryDeleteDialog, '취소'));
        await tester.pumpAndSettle();
        expect(
          jsonEncode(
            key.currentState!.categories.map(sheetCategoryData).toList(),
          ),
          before,
        );
        expect(
          jsonEncode(key.currentState!.contents.map(sheetContentData).toList()),
          contents,
        );
        expect(
          key.currentState!.calls.where(
            (v) => ['create', 'edit', 'delete'].contains(v['action']),
          ),
          isEmpty,
        );
      },
    );
    testWidgets(
      '$origin delete preserves content IDs, bookmark, other category and moves last to unclassified',
      (tester) async {
        final key = await _pump(tester);
        await _open(tester, 'delete', origin: origin);
        await tester.tap(_label(CategoryDeleteDialog, '삭제'));
        await tester.pumpAndSettle();
        expect(
          key.currentState!.calls.where((v) => v['action'] == 'delete').length,
          1,
        );
        expect(key.currentState!.contents.map((c) => c.id), [
          'single',
          'multiple',
        ]);
        expect(key.currentState!.contents.first.category.id, 99);
        expect(key.currentState!.contents.last.categories.map((c) => c.id), [
          102,
        ]);
        expect(key.currentState!.contents.last.bookmarked, isTrue);
        expect(key.currentState!.contents.first.originalText, '원문 보존');
      },
    );
  }
  test('exact eight colors and outside-palette initial color are retained', () {
    expect(FolderColorPicker.colors.map((c) => c.toARGB32()), [
      0xFFFF6277,
      0xFFFFA24B,
      0xFFFFD75C,
      0xFF5BD89D,
      0xFF64B5F6,
      0xFFB9AAFF,
      0xFFFFB3C1,
      0xFF1F5E24,
    ]);
    expect(FolderColorPicker.colors.contains(sheetPrimary.color), isFalse);
  });
  testWidgets(
    'outside-palette initial color and fixed custom coral remain selectable',
    (tester) async {
      await _pump(tester);
      await _open(tester, 'edit');
      expect(
        tester
            .widget<FolderColorPicker>(find.byType(FolderColorPicker))
            .selectedColor,
        sheetPrimary.color,
      );
      final custom = find.byKey(const ValueKey('palette-custom'));
      final fallback = find
          .descendant(
            of: find.byType(FolderColorPicker),
            matching: find.byType(InkWell),
          )
          .last;
      await tester.tap(custom.evaluate().isNotEmpty ? custom : fallback);
      await tester.pump();
      expect(
        tester
            .widget<FolderColorPicker>(find.byType(FolderColorPicker))
            .selectedColor,
        const Color(0xFFFF6F61),
      );
    },
  );
  testWidgets('palette responds to actual horizontal drag', (tester) async {
    await _pump(tester, width: 320);
    await _open(tester, 'create-empty');
    final scroll = find.descendant(
      of: find.byType(FolderColorPicker),
      matching: find.byType(SingleChildScrollView),
    );
    final state = tester.state<ScrollableState>(
      find.descendant(of: scroll, matching: find.byType(Scrollable)),
    );
    final before = state.position.pixels;
    await tester.drag(scroll, const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(state.position.pixels, greaterThan(before));
  });
  testWidgets(
    'actual archive settings opens management and existing back returns',
    (tester) async {
      final key = await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('archive-manage-categories')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryManagementScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('management-back')));
      await tester.pumpAndSettle();
      expect(key.currentState!.origin, 'archive');
      expect(key.currentState!.calls.map((v) => v['action']), [
        'managementOpen',
        'managementBack',
      ]);
    },
  );
  testWidgets(
    'action long name and large server count use natural header height',
    (tester) async {
      final key = await _pump(tester, width: 320);
      key.currentState!.categories[0] = CategoryItem(
        id: 101,
        name: List.filled(8, '아주 긴 실제 카테고리 이름').join(' '),
        color: sheetPrimary.color,
        tint: sheetPrimary.tint,
        deep: sheetPrimary.deep,
        contentCount: 9223372036854775807,
      );
      await tester.tap(find.text('전체보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카테고리'));
      await tester.pumpAndSettle();
      await _open(tester, 'actions');
      final m = sheetMeasurements(_root(tester), key.currentState!),
          j = sheetJudgment(m);
      expect((m['actualStyles'] as Map)['actionName']['maxLines'], 1);
      expect((m['actualStyles'] as Map)['actionName']['overflow'], 'ellipsis');
      expect(tester.takeException(), isNull);
      expect(j['layoutFindings'], isEmpty, reason: '${j['layoutFindings']}');
    },
  );
  testWidgets(
    'delete natural dialog clips and scrolls long copy in a short viewport',
    (tester) async {
      final key = await _pump(tester, width: 320, height: 500);
      key.currentState!.categories[0] = sheetPrimary.copyWith(
        name: List.filled(15, '아주 긴 카테고리').join(' '),
      );
      await tester.tap(find.text('전체보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카테고리'));
      await tester.pumpAndSettle();
      await _open(tester, 'delete');
      final m = sheetMeasurements(_root(tester), key.currentState!),
          j = sheetJudgment(m);
      expect(tester.takeException(), isNull);
      expect((m['geometry'] as Map)['deleteScrollClip'], isNot('none'));
      expect((m['bounds'] as Map)['deleteViewport'], isNotNull);
      expect(j['layoutFindings'], isEmpty, reason: '${j['layoutFindings']}');
    },
  );
}
