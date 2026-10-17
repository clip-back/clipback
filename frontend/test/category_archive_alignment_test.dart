import 'dart:convert';

import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/category_archive_preview.dart';

Future<GlobalKey<CategoryArchivePreviewState>> _pump(
  WidgetTester tester, {
  String kind = 'positive',
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final key = GlobalKey<CategoryArchivePreviewState>();
  await tester.pumpWidget(
    CategoryArchivePreviewHost(
      key: key,
      phase: 'after',
      initialKind: kind,
      platform: platform,
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

Element _root(WidgetTester tester) =>
    tester.element(find.byType(ArchiveScreen));

Future<List<String>> _allRows(
  WidgetTester tester,
  GlobalKey<CategoryArchivePreviewState> key,
) async {
  final findings = <String>[];
  final seen = <int>{};
  for (var step = 0; step < 12; step++) {
    final root = _root(tester);
    final metrics = categoryArchiveMeasurements(root, key.currentState!);
    final judgment = categoryArchiveJudgment(metrics);
    seen.addAll(
      (metrics['rows'] as List)
          .where((r) => r['fullyInsideViewport'] == true)
          .map((r) => r['id'] as int),
    );
    findings.addAll((judgment['styleFindings'] as List).cast<String>());
    findings.addAll((judgment['layoutFindings'] as List).cast<String>());
    final position = categoryArchivePosition(root);
    if ((position.pixels - position.maxScrollExtent).abs() < .1) break;
    position.jumpTo((position.pixels + 200).clamp(0, position.maxScrollExtent));
    await tester.pumpAndSettle();
  }
  final expected = categoryArchiveSorted(
    key.currentState!.categories,
  ).map((category) => category.id!).toSet();
  if (!seen.containsAll(expected)) findings.add('Missing full list coverage');
  final metrics = categoryArchiveMeasurements(_root(tester), key.currentState!);
  final last = (metrics['rows'] as List)
      .where((row) => row['id'] == expected.last)
      .firstOrNull;
  if (last == null || last['fullyInsideViewport'] != true) {
    findings.add(
      'Last sorted category must be fully visible at maximum scroll',
    );
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
      for (final kind in ['zero', 'positive']) {
        testWidgets('archive category 1x $kind $platform width $width', (
          tester,
        ) async {
          final key = await _pump(
            tester,
            platform: platform,
            width: width,
            kind: kind,
          );
          final failures = await _allRows(tester, key);
          expect(tester.takeException(), isNull);
          expect(failures, isEmpty, reason: failures.join('\n'));
        });
      }
    }
  }

  test(
    'fixed metadata preserves server counts independent of loaded content',
    () {
      final categories = categoryArchiveData('positive');
      expect(categories.first.contentCount, 2);
      expect(categories.firstWhere((c) => c.id == 111).contentCount, 37);
      expect(categories.firstWhere((c) => c.id == 111).rawLastSavedAt, isNull);
      expect(categories.firstWhere((c) => c.id == 104).contentCount, 0);
      expect(
        categories.firstWhere((c) => c.id == 104).rawLastSavedAt,
        isNotNull,
      );
      expect(categoryArchiveData('zero').first.contentCount, 0);
    },
  );

  test(
    'raw timestamp descending, ID ties and null dates last are preserved',
    () {
      expect(
        categoryArchiveSorted(categoryArchiveData('positive')).map((c) => c.id),
        [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112],
      );
    },
  );

  test('editing category preserves count and raw/display timestamps', () {
    final before = categoryArchiveData(
      'positive',
    ).firstWhere((c) => c.id == 101);
    final after = before.copyWith(name: '이름만 변경', color: AppColors.blueDeep);
    expect(after.id, before.id);
    expect(after.contentCount, before.contentCount);
    expect(after.rawLastSavedAt, before.rawLastSavedAt);
    expect(after.lastSavedAt, before.lastSavedAt);
  });

  testWidgets('missing uncategorized metadata is not a positive banner', (
    tester,
  ) async {
    final key = await _pump(tester);
    // Rebuild using the actual list without synthesizing a known zero item.
    key.currentState!.categories = key.currentState!.categories
        .where((c) => c.name != catUncategorized.name)
        .toList();
    // A harmless tab change uses the production callback to rebuild the host.
    await tester.tap(find.text('전체보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카테고리'));
    await tester.pumpAndSettle();
    final m = categoryArchiveMeasurements(_root(tester), key.currentState!);
    expect(m['bannerMetadataKnown'], isFalse);
    expect(m['actualUnclassifiedCount'], isNull);
    expect(m['bannerPresent'], isFalse);
  });

  testWidgets('archive row opens actual category ID and server count', (
    tester,
  ) async {
    final key = await _pump(tester);
    final first = find.byWidgetPredicate(
      (w) => w is CategoryRow && w.category.id == 101,
    );
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(key.currentState!.activeCategory, categoryArchiveLongName);
    expect(key.currentState!.activeTab, 0);
    expect(key.currentState!.calls.last, {
      'action': 'openCategory',
      'id': 101,
      'count': 11,
    });
  });

  testWidgets(
    'more action sheet retains server count and cancel preserves data',
    (tester) async {
      final key = await _pump(tester);
      final before = jsonEncode(
        key.currentState!.categories
            .map((c) => [c.id, c.name, c.contentCount])
            .toList(),
      );
      final row = tester.widget<CategoryRow>(
        find.byWidgetPredicate((w) => w is CategoryRow && w.category.id == 101),
      );
      row.onMore!();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CategoryActionSheet>(find.byType(CategoryActionSheet))
            .contentCount,
        11,
      );
      await tester.tap(find.text('카테고리 삭제'));
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.byType(CategoryDeleteDialog), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(
        jsonEncode(
          key.currentState!.categories
              .map((c) => [c.id, c.name, c.contentCount])
              .toList(),
        ),
        before,
      );
      expect(
        key.currentState!.calls.where((c) => c['action'] == 'delete'),
        isEmpty,
      );
    },
  );

  testWidgets('management callback returns to category tab and list offset', (
    tester,
  ) async {
    final key = await _pump(tester);
    final position = categoryArchivePosition(_root(tester));
    position.jumpTo(position.maxScrollExtent.clamp(0, 120));
    await tester.pumpAndSettle();
    final saved = position.pixels;
    expect(key.currentState!.optionalManagementSupported, isTrue);
    final settings = find.byKey(const ValueKey('archive-manage-categories'));
    expect(settings, findsOneWidget);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryManagementScreen), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(CategoryManagementScreen),
            matching: find.byType(SvgIconButton),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(key.currentState!.activeTab, 1);
    expect(categoryArchivePosition(_root(tester)).pixels, closeTo(saved, .1));
  });

  testWidgets('shared management row keeps default count and mutation policy', (
    tester,
  ) async {
    final category = categoryArchiveData(
      'positive',
    ).firstWhere((c) => c.id == 111);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryRow(
            category: category.copyWith(mutationLabel: '삭제 중…'),
            onMore: () => opened++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('37'), findsOneWidget);
    expect(find.text('삭제 중…'), findsOneWidget);
    final gestures = tester.widgetList<GestureDetector>(
      find.descendant(
        of: find.byType(CategoryRow),
        matching: find.byType(GestureDetector),
      ),
    );
    expect(gestures.any((gesture) => gesture.onTap != null), isFalse);
    expect(opened, 0);
  });

  testWidgets('input and controller survive keyboard change then dismiss', (
    tester,
  ) async {
    final key = await _pump(tester);
    final toolbar = find.byType(CategoryArchiveToolbar);
    final keyedAdd = find.byKey(const ValueKey('archive-category-add'));
    final add = keyedAdd.evaluate().isNotEmpty
        ? keyedAdd
        : find.descendant(of: toolbar, matching: find.byType(SvgIconButton));
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCreateSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField), '보존하는 입력');
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller,
      same(controller),
    );
    expect(controller!.text, '보존하는 입력');
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    key.currentState!.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(key.currentState!.calls.where((c) => c['action'] == 'add'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
