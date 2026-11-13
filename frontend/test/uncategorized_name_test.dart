// Issue #358: unclassified content shows the category name '미분류'
// everywhere except the five kept '분류가 필요한' phrases.

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _uncategorized = categoryFromApi(
  ApiCategory.fromJson({
    'id': 900,
    'name': '미분류',
    'color': '#B5BDC3',
    'is_default': true,
  }),
);
const _classified = CategoryItem(
  id: 901,
  name: '여행',
  color: Color(0xFF4A90E2),
  tint: Color(0x334A90E2),
  deep: Color(0xFF1F5FA8),
);

ContentItem _content(String id, CategoryItem category) => ContentItem(
  id: id,
  apiId: id.hashCode,
  title: '제목 $id',
  summary: '요약 $id',
  category: category,
  categories: [category],
  savedAt: '26.11.14',
  savedAtFull: '2026년 11월 14일',
  savedAtFullShort: '2026. 11. 14 10:00',
  tags: const ['태그'],
  source: '웹 링크',
  originalUrl: 'https://example.invalid/$id',
  originalText: '원문 $id',
);

Future<void> _render(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  double width = 320,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Pretendard'),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectNoOldName() {
  expect(find.textContaining('분류가 필요한'), findsNothing);
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

  test('server 미분류 maps to the app unclassified name 미분류', () {
    expect(catUncategorized.name, '미분류');
    expect(_uncategorized.name, '미분류');
    expect(_uncategorized.name, catUncategorized.name);
  });

  for (final textScale in [1.0, 1.3]) {
    testWidgets('home card badge (#1) at $textScale', (tester) async {
      await _render(
        tester,
        textScale: textScale,
        SingleChildScrollView(
          child: Column(
            children: [
              for (final item in [
                _content('a', _uncategorized),
                _content('b', _classified),
              ])
                HomeContentCard(
                  content: item,
                  bookmarked: false,
                  onTap: () {},
                  onToggleBookmark: () {},
                ),
            ],
          ),
        ),
      );
      expect(find.text('미분류'), findsOneWidget);
      expect(find.text('여행'), findsOneWidget);
      _expectNoOldName();
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail and related badges (#2) at $textScale', (tester) async {
      final current = _content('a', _uncategorized);
      final related = _content('b', _uncategorized);
      await _render(
        tester,
        textScale: textScale,
        width: 375,
        DetailScreen(
          onReadAsset: (_) async => Uint8List(0),
          content: current,
          contents: [current, related],
          categories: [_classified, _uncategorized],
          bookmarked: false,
          onBack: () {},
          onToggleBookmark: (_) {},
          onChangeCategory: (_, __) {},
          onDeleteContent: (_) {},
          onOpenOriginalLink: () {},
          onOpenAdjacent: (_) {},
          onOpenContent: (_) {},
          onAddLink: ({required url, submissionKey, category}) async => current,
          onAddScreenshot:
              ({
                required bytes,
                required filename,
                String? submissionKey,
                category,
              }) async => current,
          onTab: (_) {},
        ),
      );
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('제목 b'),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('미분류', skipOffstage: false), findsNWidgets(2));
      _expectNoOldName();
      expect(tester.takeException(), isNull);
    });

    testWidgets('random review card badge (#3) at $textScale', (tester) async {
      await _render(
        tester,
        textScale: textScale,
        width: 375,
        Column(
          children: [
            for (final item in [
              _content('a', _uncategorized),
              _content('b', _classified),
            ])
              Expanded(
                child: CategoryReviewCard(
                  content: item,
                  bookmarked: false,
                  compact: true,
                  onOpenContent: () {},
                  onToggleBookmark: () {},
                ),
              ),
          ],
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('review-badge-a'))).data,
        '미분류',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('review-badge-b'))).data,
        '여행',
      );
      _expectNoOldName();
      expect(tester.takeException(), isNull);
    });

    testWidgets('archive/bookmark/search card badge (#4) at $textScale', (
      tester,
    ) async {
      await _render(
        tester,
        textScale: textScale,
        Column(
          children: [
            for (final item in [
              _content('a', _uncategorized),
              _content('b', _classified),
            ])
              ContentListCard(
                content: item,
                archiveAllStyle: true,
                categories: [_classified, _uncategorized],
                onTap: () {},
                onToggleBookmark: () {},
                onChangeCategory: (_) {},
                onDelete: () {},
              ),
          ],
        ),
      );
      expect(find.text('미분류'), findsOneWidget);
      expect(find.text('여행'), findsOneWidget);
      // Only E06 uses the grey fixed-width unclassified badge.
      expect(find.byKey(const ValueKey('unclassified-badge-a')), findsNothing);
      final badge = tester.widget<Container>(
        find
            .ancestor(of: find.text('미분류'), matching: find.byType(Container))
            .first,
      );
      expect((badge.decoration! as BoxDecoration).color, _uncategorized.tint);
      _expectNoOldName();
      expect(tester.takeException(), isNull);
    });

    testWidgets('save result category name (#5) at $textScale', (tester) async {
      await _render(
        tester,
        textScale: textScale,
        SingleChildScrollView(
          child: SavedContentConfirmation(
            content: _content('a', _uncategorized),
            originalUrl: 'https://example.invalid/a',
            photoBytes: null,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('save-result-category-row')),
          matching: find.text('미분류'),
        ),
        findsOneWidget,
      );
      expect(find.text('아직 분류되지 않았어요.'), findsOneWidget);
      _expectNoOldName();
      expect(tester.takeException(), isNull);
    });

    testWidgets('category change tile (#6) at $textScale', (tester) async {
      await _render(
        tester,
        textScale: textScale,
        Column(
          children: [
            for (final category in [_classified, _uncategorized])
              CategoryChangeTile(
                category: category,
                selected: category == _uncategorized,
                onTap: () {},
              ),
          ],
        ),
      );
      expect(find.text('미분류'), findsOneWidget);
      expect(find.text('여행'), findsOneWidget);
      _expectNoOldName();
      expect(tester.takeException(), isNull);
    });
  }

  Widget panel({
    required FeedPage feed,
    required List<ContentItem> contents,
    int? activeCategoryId,
    ValueChanged<CategoryItem?>? onSelected,
  }) => SingleChildScrollView(
    child: HomeContentPanel(
      weeklyItems: const [],
      feed: feed,
      activeCategoryId: activeCategoryId,
      contents: contents,
      categories: [_classified, _uncategorized],
      bookmarkedIds: const {},
      onOpenArchive: () {},
      onOpenCategories: () {},
      onOpenContent: (_) {},
      onToggleBookmark: (_) {},
      onCategorySelected: onSelected,
    ),
  );

  for (final textScale in [1.0, 1.15, 1.3]) {
    testWidgets('home chip (#7) is 미분류 and fits at $textScale', (tester) async {
      final selected = <CategoryItem?>[];
      final contents = [_content('a', _uncategorized)];
      await _render(
        tester,
        textScale: textScale,
        panel(
          feed: FeedPage()
            ..initialized = true
            ..hasMore = false
            ..items.addAll(contents),
          contents: contents,
          onSelected: selected.add,
        ),
      );
      final chip = find.descendant(
        of: find.byType(CategoryChips),
        matching: find.text('미분류'),
      );
      expect(chip, findsOneWidget);
      _expectNoOldName();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(selected.single, same(_uncategorized));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home 미분류 chip with no result keeps the empty sentence', (
    tester,
  ) async {
    await _render(
      tester,
      panel(
        feed: FeedPage()
          ..initialized = true
          ..hasMore = false
          ..categoryId = _uncategorized.id,
        contents: const [],
        activeCategoryId: _uncategorized.id,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(CategoryChips),
        matching: find.text('미분류'),
      ),
      findsOneWidget,
    );
    expect(find.text('분류가 필요한 콘텐츠가 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
