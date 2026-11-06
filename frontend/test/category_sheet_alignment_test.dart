import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
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
  double textScale = 1,
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
      textScale: textScale,
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
  for (final width in [320.0, 375.0, 393.0, 411.43]) {
    for (final scale in [1.0, 1.3]) {
      for (final origin in ['archive', 'management']) {
        for (final kind in ['create', 'edit', 'outside']) {
          testWidgets('distributed palette $width scale$scale $origin $kind', (
            tester,
          ) async {
            final key = await _pump(tester, width: width, textScale: scale);
            final selectedIndex = kind == 'create'
                ? 0
                : kind == 'edit'
                ? 4
                : -1;
            final initial = kind == 'outside'
                ? const Color(0xFFFF6F61)
                : const Color(0xFF64B5F6);
            if (kind != 'create') {
              key.currentState!.categories[0] = sheetPrimary.copyWith(
                color: initial,
              );
              await tester.tap(find.text('전체보기'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('카테고리'));
              await tester.pumpAndSettle();
            }
            await _open(
              tester,
              kind == 'create' ? 'create-filled' : 'edit',
              origin: origin,
            );
            final palette = find.byType(FolderColorPicker);
            final choices = find.descendant(
              of: palette,
              matching: find.byType(InkWell),
            );
            expect(choices, findsNWidgets(8));
            expect(
              MediaQuery.textScalerOf(
                tester.element(find.byType(TextField)),
              ).scale(10),
              scale * 10,
            );
            final available = width - 48;
            final contentWidth = width == 320
                ? (kind == 'outside' ? 296.0 : 302.0)
                : available;
            final gap = width == 320
                ? 8.0
                : (available - (kind == 'outside' ? 240 : 246)) / 7;
            expect(tester.getSize(palette).width, closeTo(available, .001));
            var expectedLeft = 24.0;
            final top = tester.getRect(choices.first).top;
            const rgb = [
              0xFFFF6277,
              0xFFFFA24B,
              0xFFFFD75C,
              0xFF5BD89D,
              0xFF64B5F6,
              0xFFB9AAFF,
              0xFFFFB3C1,
              0xFF1F5E24,
            ];
            for (var i = 0; i < 8; i++) {
              final choice = choices.at(i);
              expect(
                tester.widget<InkWell>(choice).key,
                ValueKey('palette-color-${rgb[i].toRadixString(16)}'),
              );
              final box = tester.getRect(choice);
              final size = selectedIndex == i ? 36.0 : 30.0;
              expect(box.left, closeTo(expectedLeft, .001));
              expect(box.width, closeTo(size, .001));
              expect(box.height, 36);
              expect(box.top, top);
              expectedLeft += size + gap;
            }
            expect(
              tester.getRect(choices.last).right,
              closeTo(24 + contentWidth, .001),
            );
            expect(
              find.descendant(of: palette, matching: find.byType(SvgPicture)),
              kind == 'outside' ? findsNothing : findsOneWidget,
            );
            if (width == 320) {
              final scroll = find.descendant(
                of: palette,
                matching: find.byType(Scrollable),
              );
              final state = tester.state<ScrollableState>(scroll);
              expect(state.position.pixels, 0);
              await tester.drag(palette, const Offset(-120, 0));
              await tester.pumpAndSettle();
              expect(state.position.pixels, greaterThan(0));
              expect(
                tester.getRect(choices.last).right,
                closeTo(width - 24, .001),
              );
            }
            if (kind == 'outside') {
              await tester.enterText(find.byType(TextField), '이름만 수정');
              await tester.pump();
            } else {
              await tester.tap(
                find.byKey(const ValueKey('palette-color-ff1f5e24')),
              );
              await tester.pump();
            }
            final expectedColor = kind == 'outside'
                ? initial
                : const Color(0xFF1F5E24);
            expect(
              tester.widget<FolderColorPicker>(palette).selectedColor,
              expectedColor,
            );
            expect(
              tester
                  .widget<SvgPicture>(
                    find.byKey(const ValueKey('category-form-folder')),
                  )
                  .colorFilter,
              ColorFilter.mode(expectedColor, BlendMode.srcIn),
            );
            await tester.tap(
              find.widgetWithText(
                FilledButton,
                kind == 'create' ? '생성하기' : '수정하기',
              ),
            );
            await tester.pumpAndSettle();
            final saved = key.currentState!.categories.firstWhere(
              (v) => v.id == (kind == 'create' ? 900 : 101),
            );
            expect(saved.color, expectedColor);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
  for (final origin in ['archive', 'management']) {
    for (final kind in ['create-empty', 'edit']) {
      testWidgets('$origin $kind has only eight solid color targets', (
        tester,
      ) async {
        await _pump(tester);
        await _open(tester, kind, origin: origin);
        expect(find.byType(CategoryFormSheet), findsOneWidget);
        expect(find.byKey(const ValueKey('palette-custom')), findsNothing);
        final palette = find.byType(FolderColorPicker);
        expect(
          find.descendant(of: palette, matching: find.byType(Image)),
          findsNothing,
        );
        expect(
          find.descendant(of: palette, matching: find.byType(InkWell)),
          findsNWidgets(8),
        );
      });
    }
  }
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
  for (final origin in ['archive', 'management']) {
    for (final color in [const Color(0xFFFF6F61), const Color(0xFF123456)]) {
      for (final action in ['rename', 'select', 'cancel']) {
        testWidgets(
          '$origin outside $color $action preserves until solid selection',
          (tester) async {
            final key = await _pump(tester);
            key.currentState!.categories[0] = sheetPrimary.copyWith(
              color: color,
            );
            await tester.tap(find.text('전체보기'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('카테고리'));
            await tester.pumpAndSettle();
            await _open(tester, 'edit', origin: origin);
            final palette = find.byType(FolderColorPicker);
            expect(
              tester.widget<FolderColorPicker>(palette).selectedColor,
              color,
            );
            expect(
              find.descendant(of: palette, matching: find.byType(SvgPicture)),
              findsNothing,
            );
            expect(
              tester
                  .widget<SvgPicture>(
                    find.byKey(const ValueKey('category-form-folder')),
                  )
                  .colorFilter,
              ColorFilter.mode(color, BlendMode.srcIn),
            );
            await tester.enterText(find.byType(TextField), '이름 변경');
            if (action != 'rename') {
              await tester.tap(
                find.byKey(const ValueKey('palette-color-ffffa24b')),
              );
              await tester.pump();
              expect(
                tester.widget<FolderColorPicker>(palette).selectedColor,
                const Color(0xFFFFA24B),
              );
              expect(
                tester
                    .widget<SvgPicture>(
                      find.byKey(const ValueKey('category-form-folder')),
                    )
                    .colorFilter,
                const ColorFilter.mode(Color(0xFFFFA24B), BlendMode.srcIn),
              );
            }
            if (action == 'cancel') {
              key.currentState!.navigatorKey.currentState!.pop();
            } else {
              await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
            }
            await tester.pumpAndSettle();
            expect(
              key.currentState!.categories.first.color,
              action == 'select' ? const Color(0xFFFFA24B) : color,
            );
            expect(
              key.currentState!.calls
                  .where((v) => v['action'] == 'edit')
                  .length,
              action == 'cancel' ? 0 : 1,
            );
          },
        );
      }
    }
  }
  for (final color in FolderColorPicker.colors) {
    testWidgets(
      'solid $color distributes across 375px and submits selected color',
      (tester) async {
        final key = await _pump(tester);
        await _open(tester, 'create-filled');
        final palette = find.byType(FolderColorPicker);
        final choices = find.descendant(
          of: palette,
          matching: find.byType(InkWell),
        );
        expect(choices, findsNWidgets(8));
        expect(
          tester.getRect(choices.first).left,
          tester.getRect(palette).left,
        );
        expect(tester.getSize(palette).width, 327);
        for (var i = 0; i < 8; i++) {
          final box = tester.getRect(choices.at(i));
          expect(box.height, 36);
          expect(box.width, i == 0 ? 36 : 30);
          expect(box.top, tester.getRect(choices.first).top);
          if (i > 0) {
            expect(
              box.left - tester.getRect(choices.at(i - 1)).right,
              closeTo(81 / 7, .001),
            );
          }
        }
        await tester.tap(
          find.byKey(
            ValueKey('palette-color-${color.toARGB32().toRadixString(16)}'),
          ),
        );
        await tester.pump();
        expect(tester.widget<FolderColorPicker>(palette).selectedColor, color);
        expect(
          find.descendant(of: palette, matching: find.byType(SvgPicture)),
          findsOneWidget,
        );
        expect(
          tester
              .widget<SvgPicture>(
                find.byKey(const ValueKey('category-form-folder')),
              )
              .colorFilter,
          ColorFilter.mode(color, BlendMode.srcIn),
        );
        await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
        await tester.pumpAndSettle();
        expect(key.currentState!.categories.last.color, color);
        expect(
          key.currentState!.calls.where((v) => v['action'] == 'create'),
          hasLength(1),
        );
      },
    );
  }
  testWidgets('palette responds to actual horizontal drag', (tester) async {
    final key = await _pump(tester, width: 320);
    await _open(tester, 'create-empty');
    expect(
      tester
          .widget<FolderColorPicker>(find.byType(FolderColorPicker))
          .selectedColor,
      const Color(0xFFFF6277),
    );
    await tester.enterText(find.byType(TextField), '끝 색 저장');
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
    await tester.tap(find.byKey(const ValueKey('palette-color-ff1f5e24')));
    await tester.pump();
    expect(
      tester
          .widget<SvgPicture>(
            find.byKey(const ValueKey('category-form-folder')),
          )
          .colorFilter,
      const ColorFilter.mode(Color(0xFF1F5E24), BlendMode.srcIn),
    );
    await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
    await tester.pumpAndSettle();
    expect(key.currentState!.categories.last.color, const Color(0xFF1F5E24));
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
