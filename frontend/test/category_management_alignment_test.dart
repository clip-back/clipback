import 'dart:convert';

import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/category_management_preview.dart';

Future<GlobalKey<CategoryManagementPreviewState>> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double bottom = 34,
  int count = 12,
  List<CategoryItem>? categories,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final key = GlobalKey<CategoryManagementPreviewState>();
  await tester.pumpWidget(
    CategoryManagementPreviewHost(
      key: key,
      platform: platform,
      initialCount: count,
      initialCategories: categories,
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

Element _root(WidgetTester tester) =>
    tester.element(find.byType(CategoryManagementScreen));
Finder _row(int id) =>
    find.byWidgetPredicate((w) => w is CategoryRow && w.category.id == id);
Finder _more(WidgetTester tester, int id) {
  final keyed = find.byKey(ValueKey('archive-category-more-$id'));
  if (keyed.evaluate().isNotEmpty) return keyed;
  return find
      .descendant(of: _row(id), matching: find.byType(GestureDetector))
      .last;
}

Finder _add(WidgetTester tester) {
  final keyed = find.byKey(const ValueKey('management-add'));
  if (keyed.evaluate().isNotEmpty) return keyed;
  return find.byWidgetPredicate(
    (w) => w is SvgIconButton && w.asset == 'assets/icons/folder-plus.svg',
  );
}

Future<List<String>> _allRows(
  WidgetTester tester,
  GlobalKey<CategoryManagementPreviewState> key,
) async {
  final findings = <String>[], seen = <int>{};
  for (var step = 0; step < 15; step++) {
    final m = managementMeasurements(_root(tester), key.currentState!),
        j = managementJudgment(m);
    findings.addAll((j['styleFindings'] as List).cast<String>());
    findings.addAll((j['layoutFindings'] as List).cast<String>());
    seen.addAll(
      (m['rows'] as List)
          .where((r) => r['fullyInsideViewport'] == true)
          .map((r) => r['id'] as int),
    );
    final p = managementPosition(_root(tester));
    if ((p.pixels - p.maxScrollExtent).abs() < .1) break;
    p.jumpTo((p.pixels + 220).clamp(0, p.maxScrollExtent));
    await tester.pumpAndSettle();
  }
  final expected = key.currentState!.categories
      .where((c) => c.name != catUncategorized.name)
      .map((c) => c.id!)
      .toSet();
  if (!seen.containsAll(expected) || seen.length != expected.length) {
    findings.add('Full category coverage differs');
  }
  return findings.toSet().toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final bottom in [0.0, 34.0, 48.0]) {
        for (final count in [0, 1, 12]) {
          testWidgets(
            'management 1x $platform width$width safe$bottom count$count',
            (tester) async {
              final key = await _pump(
                tester,
                platform: platform,
                width: width,
                bottom: bottom,
                count: count,
              );
              final findings = await _allRows(tester, key);
              expect(tester.takeException(), isNull);
              expect(findings, isEmpty, reason: findings.join('\n'));
            },
          );
        }
      }
    }
  }
  test('fixed data preserves caller input order and independent metadata', () {
    final categories = managementData();
    expect(categories.skip(1).map((c) => c.id), [
      112,
      104,
      102,
      108,
      101,
      106,
      110,
      103,
      111,
      105,
      109,
      107,
    ]);
    expect(categories.first.id, 99);
    expect(categories.first.contentCount, 2);
    expect(categories.firstWhere((c) => c.id == 111).contentCount, 37);
    expect(categories.firstWhere((c) => c.id == 111).rawLastSavedAt, isNull);
    expect(categories.firstWhere((c) => c.id == 104).contentCount, 0);
    expect(categories.firstWhere((c) => c.id == 104).rawLastSavedAt, isNotNull);
  });
  testWidgets(
    'count excludes uncategorized and is independent of loaded contents',
    (tester) async {
      final key = await _pump(tester);
      expect(find.text('총 12개'), findsOneWidget);
      expect(key.currentState!.contents.length, 2);
      expect(find.text(catUncategorized.name), findsNothing);
      expect(
        tester
            .widgetList<CategoryRow>(find.byType(CategoryRow))
            .map((r) => r.category.id)
            .first,
        112,
      );
    },
  );
  testWidgets('missing uncategorized metadata does not synthesize a row', (
    tester,
  ) async {
    final data = managementData().skip(1).take(1).toList();
    await _pump(tester, categories: data);
    expect(find.text('총 1개'), findsOneWidget);
    expect(find.byType(CategoryRow), findsOneWidget);
    expect(find.text(catUncategorized.name), findsNothing);
  });
  testWidgets('management row has no opening action', (tester) async {
    final key = await _pump(tester);
    expect(tester.widget<CategoryRow>(_row(112)).onTap, isNull);
    await tester.tap(
      find.descendant(of: _row(112), matching: find.text('기록 카테고리 112')),
    );
    await tester.pumpAndSettle();
    expect(key.currentState!.calls, isEmpty);
    expect(key.currentState!.route, 'management');
  });
  testWidgets('mutation keeps its label and blocks the more action', (
    tester,
  ) async {
    final values = managementData();
    values[1] = values[1].copyWith(mutationLabel: '삭제 중…');
    final key = await _pump(tester, categories: values);
    expect(find.text('삭제 중…'), findsOneWidget);
    await tester.tap(_more(tester, 112));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryActionSheet), findsNothing);
    expect(key.currentState!.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'more sheet uses server count; delete cancel preserves all metadata',
    (tester) async {
      final key = await _pump(tester);
      final before = jsonEncode(
        key.currentState!.categories.map(managementMetadata).toList(),
      );
      await tester.tap(_more(tester, 112));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CategoryActionSheet>(find.byType(CategoryActionSheet))
            .contentCount,
        22,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryActionSheet),
          matching: find.text('카테고리 삭제'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.byType(CategoryDeleteDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryDeleteDialog),
          matching: find.text('취소'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        jsonEncode(
          key.currentState!.categories.map(managementMetadata).toList(),
        ),
        before,
      );
      expect(key.currentState!.calls, isEmpty);
    },
  );
  testWidgets(
    'edit cancel preserves input order, date/count and original content IDs',
    (tester) async {
      final key = await _pump(tester);
      final before = jsonEncode(
            key.currentState!.categories.map(managementMetadata).toList(),
          ),
          ids = key.currentState!.contents.map((c) => c.id).toList();
      await tester.tap(_more(tester, 112));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryActionSheet),
          matching: find.text('카테고리 수정'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.byType(CategoryEditSheet), findsOneWidget);
      await tester.enterText(find.byType(TextField), '취소할 편집');
      key.currentState!.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        jsonEncode(
          key.currentState!.categories.map(managementMetadata).toList(),
        ),
        before,
      );
      expect(key.currentState!.contents.map((c) => c.id), ids);
      expect(key.currentState!.calls, isEmpty);
    },
  );
  testWidgets(
    'create input/controller and list position survive keyboard show/hide',
    (tester) async {
      final key = await _pump(tester);
      final p = managementPosition(_root(tester));
      p.jumpTo(p.maxScrollExtent.clamp(0, 120));
      await tester.pumpAndSettle();
      final saved = p.pixels;
      await tester.tap(_add(tester));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '보존할 입력');
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding(top: 59);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(controller),
      );
      expect(controller!.text, '보존할 입력');
      tester.view.viewInsets = const FakeViewPadding();
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      await tester.pumpAndSettle();
      expect(controller.text, '보존할 입력');
      key.currentState!.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(managementPosition(_root(tester)).pixels, closeTo(saved, .1));
      expect(key.currentState!.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'local create/edit/delete rerenders total, name and color then restores data',
    (tester) async {
      final key = await _pump(tester);
      final before = jsonEncode(
            key.currentState!.categories.map(managementMetadata).toList(),
          ),
          ids = key.currentState!.contents.map((c) => c.id).toList();
      await tester.tap(_add(tester));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '로컬 생성 검사');
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryCreateSheet),
          matching: find.text('생성하기'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('총 13개'), findsOneWidget);
      var p = managementPosition(_root(tester));
      p.jumpTo(p.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('로컬 생성 검사'), findsOneWidget);
      await tester.tap(_more(tester, 900));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryActionSheet),
          matching: find.text('카테고리 수정'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '로컬 수정 검사');
      final colors = find.descendant(
        of: find.byType(FolderColorPicker),
        matching: find.byType(InkWell),
      );
      await tester.tap(colors.at(1));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryEditSheet),
          matching: find.text('수정하기'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('총 13개'), findsOneWidget);
      p = managementPosition(_root(tester));
      p.jumpTo(p.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('로컬 수정 검사'), findsOneWidget);
      expect(
        tester.widget<CategoryRow>(_row(900)).category.color,
        FolderColorPicker.colors[1],
      );
      await tester.tap(_more(tester, 900));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryActionSheet),
          matching: find.text('카테고리 삭제'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryDeleteDialog),
          matching: find.text('삭제'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('총 12개'), findsOneWidget);
      expect(_row(900), findsNothing);
      expect(
        jsonEncode(
          key.currentState!.categories.map(managementMetadata).toList(),
        ),
        before,
      );
      expect(key.currentState!.contents.map((c) => c.id), ids);
      expect(key.currentState!.calls.map((c) => c['action']), [
        'add',
        'update',
        'delete',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'back callback uses actual pointer and the local host can reopen',
    (tester) async {
      final key = await _pump(tester);
      final keyed = find.byKey(const ValueKey('management-back'));
      final back = keyed.evaluate().isNotEmpty
          ? keyed
          : find.byWidgetPredicate(
              (w) => w is SvgIconButton && w.asset == 'assets/icons/back.svg',
            );
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(key.currentState!.route, 'returned');
      expect(key.currentState!.calls.single['action'], 'back');
      await tester.tap(find.byKey(const ValueKey('management-reopen')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryManagementScreen), findsOneWidget);
      expect(find.text('총 12개'), findsOneWidget);
    },
  );
  testWidgets('fixture matches actual ClipbackApp body color theme', (
    tester,
  ) async {
    await _pump(tester);
    expect(Theme.of(_root(tester)).textTheme.bodyMedium!.color, AppColors.text);
  });
}
