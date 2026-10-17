import 'dart:convert';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/content_actions.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/archive_all_preview.dart';

Future<GlobalKey<ArchiveAllStaticState>> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  double width,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final key = GlobalKey<ArchiveAllStaticState>();
  await tester.pumpWidget(ArchiveAllStaticHost(key: key, platform: platform));
  await tester.pumpAndSettle();
  return key;
}

Element _root(WidgetTester tester) =>
    tester.element(find.byType(ArchiveAllStaticHost));
Finder _card(String id) =>
    find.byWidgetPredicate((w) => w is ContentListCard && w.content.id == id);
Future<void> _show(WidgetTester tester, String id) async {
  final p = archiveAllPosition(_root(tester));
  for (
    var attempt = 0;
    attempt < 30 && _card(id).evaluate().isEmpty;
    attempt++
  ) {
    p.jumpTo((p.pixels + 150).clamp(0, p.maxScrollExtent));
    await tester.pumpAndSettle();
  }
  expect(_card(id), findsOneWidget);
  final card = tester.getRect(_card(id));
  final viewport =
      (archiveAllMeasure(_root(tester))['bounds'] as Map)['viewport'] as Map;
  p.jumpTo(
    (p.pixels + card.top - (viewport['top'] as num)).clamp(
      0,
      p.maxScrollExtent,
    ),
  );
  await tester.pumpAndSettle();
}

Map _row(WidgetTester tester, String id) =>
    (archiveAllMeasure(_root(tester))['rows'] as List).firstWhere(
          (r) => r['id'] == id,
        )
        as Map;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets('E01 actual typography and geometry $platform width$width', (
        tester,
      ) async {
        final host = await _pump(tester, platform, width);
        final style = <String>[], layout = <String>[], seen = <String>{};
        for (final id in archiveAllIds) {
          await _show(tester, id);
          final m = archiveAllMeasure(_root(tester)), j = archiveAllJudgment(m);
          expect(
            () => jsonEncode(m),
            returnsNormally,
            reason: 'All diagnostic numbers must be JSON encodable.',
          );
          style.addAll((j['styleFindings'] as List).cast<String>());
          layout.addAll((j['layoutFindings'] as List).cast<String>());
          for (final row in m['rows'] as List) {
            if (row['fullyInsideViewport'] == true) {
              seen.add(row['id'] as String);
            }
          }
        }
        expect(host.currentState!.feed.initialized, isTrue);
        expect(
          seen,
          containsAll(archiveAllIds),
          reason: 'Lazy mounted/cache rows alone do not count as fully viewed.',
        );
        expect(tester.takeException(), isNull);
        expect(
          style.toSet(),
          isEmpty,
          reason: 'Effective role/asset style differences: ${style.toSet()}',
        );
        expect(
          layout.toSet(),
          isEmpty,
          reason: 'Actual geometry differences: ${layout.toSet()}',
        );
      });
      testWidgets(
        'E01 one-row173 and multiple-category growth $platform width$width',
        (tester) async {
          await _pump(tester, platform, width);
          for (final id in archiveAllIds) {
            await _show(tester, id);
            final row = _row(tester, id),
                card = row['card'] as Map,
                wrap = row['wrap'] as Map;
            expect(
              (row['badges'] as List).map((v) => v['categoryId']).toList(),
              row['expectedCategoryIds'],
            );
            final delta = ((wrap['height'] as num) - 22).clamp(
              0,
              double.infinity,
            );
            expect(card['height'] as num, closeTo(173 + delta, .17));
            if (id == 'api-601' ||
                id == 'api-602' ||
                id == 'api-605' ||
                id == 'api-606') {
              expect(card['height'], 173);
            }
            if (id == 'api-603' || id == 'api-604') {
              expect(wrap['height'] as num, greaterThan(22));
            }
            if (id == 'api-604') {
              expect(wrap['height'] as num, greaterThanOrEqualTo(82));
            }
            final title = row['titleStyle'] as Map,
                summary = row['summaryStyle'] as Map,
                date = row['dateStyle'] as Map;
            expect(
              (title['bounds'] as Map)['top'] as num,
              closeTo((card['top'] as num) + 46 + delta, .17),
            );
            expect(
              (summary['bounds'] as Map)['top'] as num,
              closeTo((card['top'] as num) + 72.4 + delta, .17),
            );
            expect(
              (card['bottom'] as num) -
                  ((date['bounds'] as Map)['bottom'] as num),
              closeTo(16, .17),
            );
            expect(
              (row['bookmark'] as Map)['top'] as num,
              closeTo((card['top'] as num) + 13, .17),
            );
            expect(
              (row['more'] as Map)['top'] as num,
              closeTo((card['top'] as num) + 13, .17),
            );
            if (id == 'api-605') {
              final p = (row['badges'] as List).single['paragraph'] as Map;
              expect(p['maxLines'], 1);
              expect(p['overflow'], 'ellipsis');
              expect(p['didExceedMaxLines'], isTrue);
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('E01 loaded count never claims the account total', (
    tester,
  ) async {
    final host = await _pump(tester, TargetPlatform.iOS, 375);
    expect(host.currentState!.feed.items.length, 6);
    expect(find.text('불러온 6개'), findsOneWidget);
    expect(find.text('총 6개'), findsNothing);
    expect(find.text('999'), findsNothing);
  });
  test(
    'source mapper preserves all embedded categories and absent metadata fallback',
    () {
      final raw = archiveAllRecords()[3],
          api = ApiContent.fromJson(Map<String, dynamic>.from(raw));
      final categories = archiveAllCategories(),
          byId = {
            for (final c in categories.where((v) => v.id != 105)) c.id!: c,
          };
      final mapped = contentFromApi(api, byId, uncategorized: categories.last);
      expect(mapped.categories.map((v) => v.id), [
        103,
        104,
        105,
        106,
        101,
        102,
      ]);
      expect(mapped.categories[2].name, archiveAllCategoryMaps[4]['name']);
      expect(mapped.categories[2].color.toARGB32(), 0xFFFFA24B);
      expect(mapped.category.id, 103);
      final empty = contentFromApi(
        ApiContent.fromJson(
          Map<String, dynamic>.from(archiveAllRecords().last),
        ),
        byId,
        uncategorized: categories.last,
      );
      expect(empty.categories.single.id, 99);
      expect(empty.categories.single.name, categories.last.name);
      expect(mapped.summary, raw['summary']);
    },
  );
  test(
    'ContentItem existing empty-list category getter fallback is preserved',
    () {
      final c = archiveAllCategories().first;
      final content = ContentItem(
        id: 'fallback',
        title: '제목',
        summary: '',
        category: c,
        categories: const [],
        savedAt: '10.17',
        savedAtFull: '2026.10.17',
        savedAtFullShort: '26.10.17',
        tags: const [],
        source: '웹',
        originalUrl: '',
        originalText: '',
      );
      expect(content.category, same(c));
      expect(content.categories, [c]);
    },
  );
  testWidgets(
    'E01 actual card bookmark, menu, header and tab taps remain connected',
    (tester) async {
      final host = await _pump(tester, TargetPlatform.iOS, 375);
      await tester.tap(find.byKey(const ValueKey('archive-manage-categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('archive-category-search')));
      await tester.pumpAndSettle();
      final first = archiveAllContents().first;
      await tester.tap(find.byKey(ValueKey('list-bookmark-${first.title}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(first.title));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('archive-all-more-${first.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(ContentActionSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(ContentActionSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ArchiveTabs),
          matching: find.text('카테고리'),
        ),
      );
      await tester.pumpAndSettle();
      expect(host.currentState!.tab, 1);
      await tester.tap(
        find.descendant(
          of: find.byType(ArchiveTabs),
          matching: find.text('전체보기'),
        ),
      );
      await tester.pumpAndSettle();
      expect(host.currentState!.tab, 0);
      expect(
        host.currentState!.calls,
        containsAllInOrder(['management', 'search', 'bookmark', 'detail']),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 375.0]) {
    testWidgets(
      'shared default card appearance and callbacks remain unchanged width$width',
      (tester) async {
        final c = archiveAllContents()[3];
        var taps = 0, bookmarks = 0;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 812);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Pretendard'),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: ContentListCard(
                  content: c,
                  onTap: () => taps++,
                  onToggleBookmark: () => bookmarks++,
                  categories: archiveAllCategories(),
                  onChangeCategory: (_) {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(ContentListCard)).height, 173);
        expect(find.byType(CategoryBadge), findsOneWidget);
        expect(find.byType(BookmarkActionButton), findsOneWidget);
        expect(tester.widget<Text>(find.text(c.title)).maxLines, 1);
        expect(tester.widget<Text>(find.text(c.summary)).maxLines, 2);
        await tester.tap(find.byKey(ValueKey('list-bookmark-${c.title}')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(c.title));
        await tester.pumpAndSettle();
        expect(bookmarks, 1);
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
