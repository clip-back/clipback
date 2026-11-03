import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:clipback_frontend/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(
  WidgetTester tester, {
  required Widget child,
  double width = 375,
  double textScale = 1,
  TargetPlatform platform = TargetPlatform.android,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        textTheme: ThemeData.fallback().textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

const _category = CategoryItem(
  id: 1,
  name: '생활',
  color: AppColors.main,
  tint: AppColors.mainSubtle,
  deep: AppColors.mainDeep,
);
const _secondCategory = CategoryItem(
  id: 2,
  name: '여행',
  color: AppColors.blueSubtle,
  tint: AppColors.blueSubtle,
  deep: AppColors.blueDeep,
);
const _unclassifiedCategory = CategoryItem(
  id: 3,
  name: '분류가 필요한 콘텐츠',
  color: AppColors.subSubtle,
  tint: AppColors.subSubtle,
  deep: AppColors.middle,
);
const _longTitle = '자기소개서를 끝까지 읽게 만드는 첫 문장과 경험 정리 방법을 알아봐요';
const _longSummary =
    '길고 다양한 경험을 정리할 때 핵심 내용을 찾기 쉽도록 문장을 나누고 구체적인 사례를 덧붙여요. '
    '어떤 내용을 먼저 보여줄지 충분히 고민하고 읽는 사람이 이해할 수 있게 설명하면 도움이 됩니다. '
    '두 번째 문단도 길어져도 카드 아래쪽과 버튼을 가리지 않아야 합니다.';

ContentItem _content(int index, {bool long = false}) => ContentItem(
  id: 'content-$index',
  title: long ? _longTitle : '콘텐츠 $index',
  summary: long ? _longSummary : '다시 읽을 내용 $index',
  category: _category,
  savedAt: '26.10.13',
  savedAtFull: '2026. 10. 13',
  savedAtFullShort: '2026. 10. 13',
  tags: const [],
  source: 'Instagram',
  originalUrl: 'https://example.com/content/$index',
  originalText: '원문 $index',
);

FeedPage _feed(List<ContentItem> contents) => FeedPage()
  ..initialized = true
  ..hasMore = false
  ..items.addAll(contents);

Widget _home({
  required List<ContentItem> contents,
  FeedPage? feed,
  int? categoryId,
  VoidCallback? onOpenToday,
  List<ApiWeeklyRecommendationItem> weeklyItems = const [],
}) => HomeScreen(
  weeklyItems: weeklyItems,
  feed: feed,
  activeCategoryId: categoryId,
  contents: contents,
  categories: const [_category, _secondCategory],
  bookmarkedIds: const {},
  onSearch: () {},
  onOpenArchive: () {},
  onOpenCategories: () {},
  onOpenToday: onOpenToday ?? () {},
  onOpenContent: (_) {},
  onToggleBookmark: (_) {},
  onAddLink: ({required url, category}) async => _content(0),
  onAddScreenshot: ({required bytes, required filename, category}) async =>
      _content(0),
  onTab: (_) {},
);

Widget _panel({
  required List<ContentItem> contents,
  FeedPage? feed,
  int? categoryId,
  Set<String> bookmarkedIds = const {},
  ValueChanged<ContentItem>? onOpenContent,
  ValueChanged<ContentItem>? onToggleBookmark,
  ValueChanged<CategoryItem?>? onCategorySelected,
  VoidCallback? onOpenArchive,
  VoidCallback? onOpenCategories,
  List<CategoryItem> categories = const [_category, _secondCategory],
}) => SingleChildScrollView(
  child: HomeContentPanel(
    weeklyItems: _weeklyTestItems,
    feed: feed,
    activeCategoryId: categoryId,
    contents: contents,
    categories: categories,
    bookmarkedIds: bookmarkedIds,
    onOpenArchive: onOpenArchive ?? () {},
    onOpenCategories: onOpenCategories ?? () {},
    onOpenContent: onOpenContent ?? (_) {},
    onToggleBookmark: onToggleBookmark ?? (_) {},
    onCategorySelected: onCategorySelected,
  ),
);

Finder _recentRail() => find
    .ancestor(
      of: find.byType(HomeContentCard).first,
      matching: find.byType(ListView),
    )
    .first;

ScrollPosition _recentPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(of: _recentRail(), matching: find.byType(Scrollable))
          .first,
    )
    .position;

Future<void> _dragRecent(WidgetTester tester, double distance) async {
  final gesture = await tester.startGesture(tester.getCenter(_recentRail()));
  await gesture.moveBy(const Offset(-30, 0));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveBy(Offset(-(distance - 30), 0));
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await tester.pumpAndSettle();
}

int _activeDot(WidgetTester tester) =>
    tester.widget<PageDots>(find.byType(PageDots)).activeIndex;

void _expectContained(Rect child, Rect parent) {
  expect(child.left, greaterThanOrEqualTo(parent.left));
  expect(child.top, greaterThanOrEqualTo(parent.top));
  expect(child.right, lessThanOrEqualTo(parent.right));
  expect(child.bottom, lessThanOrEqualTo(parent.bottom));
}

Finder _asset(String name) => find.byWidgetPredicate((widget) {
  if (widget is Image && widget.image is AssetImage) {
    return (widget.image as AssetImage).assetName == name;
  }
  return false;
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  testWidgets('Android Weekly cards fit their normal 120px rail', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await _render(
      tester,
      child: WeeklyPickRail(items: _weeklyTestItems, onOpenCategory: () {}),
    );
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Weekly and long recent cards fit at $platform $width scale $scale',
          (tester) async {
            addTearDown(tester.view.reset);
            var weeklyTaps = 0;
            var contentTaps = 0;
            var bookmarkTaps = 0;
            await _render(
              tester,
              platform: platform,
              width: width,
              textScale: scale,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WeeklyPickRail(
                      items: _weeklyTestItems,
                      onOpenCategory: () => weeklyTaps++,
                    ),
                    const SizedBox(height: 24),
                    HomeContentCard(
                      content: _content(0, long: true),
                      bookmarked: false,
                      onTap: () => contentTaps++,
                      onToggleBookmark: () => bookmarkTaps++,
                    ),
                  ],
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            final weeklyRect = tester.getRect(find.byType(WeeklyPickRail));
            final contentRect = tester.getRect(find.byType(HomeContentCard));
            if (scale == 1) {
              expect(weeklyRect.height, 120);
              expect(contentRect.size, const Size(298, 186));
            } else {
              expect(weeklyRect.height, greaterThan(120));
              expect(contentRect.height, greaterThan(186));
            }
            final title = tester.renderObject<RenderParagraph>(
              find.text(_longTitle),
            );
            final summary = tester.renderObject<RenderParagraph>(
              find.text(_longSummary),
            );
            expect(title.maxLines, 2);
            expect(title.overflow, TextOverflow.ellipsis);
            expect(summary.maxLines, 3);
            expect(summary.overflow, TextOverflow.ellipsis);
            expect(summary.didExceedMaxLines, isTrue);
            _expectContained(
              tester.getRect(find.text(_longTitle)),
              contentRect,
            );
            _expectContained(
              tester.getRect(find.text(_longSummary)),
              contentRect,
            );

            await tester.tap(find.text('많이 저장한'));
            await tester.pumpAndSettle();
            expect(weeklyTaps, 1);
            await tester.tap(find.text(_longTitle));
            await tester.pumpAndSettle();
            expect(contentTaps, 1);
            await tester.tap(find.byType(BookmarkActionButton));
            await tester.pumpAndSettle();
            expect(bookmarkTaps, 1);
            expect(
              contentTaps,
              1,
              reason: 'Bookmark tap must not open content',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('entire bookmark hit area handles taps without opening card', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    var contentTaps = 0;
    var bookmarkTaps = 0;
    await _render(
      tester,
      child: HomeContentCard(
        content: _content(0, long: true),
        bookmarked: false,
        onTap: () => contentTaps++,
        onToggleBookmark: () => bookmarkTaps++,
      ),
    );
    final cardRect = tester.getRect(find.byType(HomeContentCard));
    final bookmarkRect = tester.getRect(find.byType(BookmarkActionButton));
    expect(bookmarkRect.size, const Size(44, 44));
    _expectContained(bookmarkRect, cardRect);
    for (final point in [
      bookmarkRect.topLeft + const Offset(1, 1),
      bookmarkRect.topRight + const Offset(-1, 1),
      bookmarkRect.bottomLeft + const Offset(1, -1),
      bookmarkRect.bottomRight + const Offset(-1, -1),
    ]) {
      final before = bookmarkTaps;
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(bookmarkTaps, before + 1);
      expect(contentTaps, 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed empty home shows C02 and opens existing save screen', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    var todayTaps = 0;
    await _render(
      tester,
      child: _home(
        contents: const [],
        feed: _feed(const []),
        onOpenToday: () => todayTaps++,
      ),
    );
    expect(find.text('아직 저장한 콘텐츠가 없어요.'), findsOneWidget);
    expect(find.text('지금 하나만 저장해볼까요?'), findsOneWidget);
    expect(find.text('첫 콘텐츠 저장하기'), findsOneWidget);
    expect(find.text('저장한 정보가 없어요.'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(EmptyHomeContent),
        matching: _asset(Assets.homeEmptyIllustration),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('첫 콘텐츠 저장하기'));
    await tester.pumpAndSettle();
    expect(find.byType(AddContentSheet), findsOneWidget);
    expect(find.text('콘텐츠 저장하기'), findsOneWidget);
    expect(todayTaps, 0);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 375.0]) {
    for (final hasContent in [false, true]) {
      testWidgets('home intro fits Figma at $width, saved=$hasContent', (
        tester,
      ) async {
        addTearDown(tester.view.reset);
        await _render(
          tester,
          width: width,
          child: HomeHero(
            hasSavedContent: hasContent,
            confirmedEmpty: !hasContent,
            onSearch: () {},
            onOpenToday: () {},
          ),
        );
        final heroRect = tester.getRect(find.byType(HomeHero));
        final headerRow = find
            .descendant(of: find.byType(HomeHero), matching: find.byType(Row))
            .first;
        final headerRect = tester.getRect(headerRow);
        if (width == 320 && !hasContent) {
          expect(heroRect.height, greaterThanOrEqualTo(204));
        } else {
          expect(heroRect.height, 204);
        }
        expect(headerRect.top - heroRect.top, 8.5);
        expect(headerRect.height, 56);
        final headline = find.text(
          hasContent ? '나중에 보려던 것들,' : '아직 저장한 콘텐츠가 없어요.',
        );
        expect(tester.getRect(headline).left - heroRect.left, 16);
        final character = find.descendant(
          of: find.byType(HomeHero),
          matching: _asset(Assets.homeHeroIllustration),
        );
        expect(tester.getSize(character), const Size(99, 123));
        _expectContained(tester.getRect(character), heroRect);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final hasContent in [false, true]) {
    testWidgets('scaled home intro grows without shrinking saved=$hasContent', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      Widget buildHero() => HomeHero(
        hasSavedContent: hasContent,
        confirmedEmpty: !hasContent,
        onSearch: () {},
        onOpenToday: () {},
      );
      await _render(tester, width: 320, child: buildHero());
      final normalHeight = tester.getSize(find.byType(HomeHero)).height;
      await _render(tester, width: 320, textScale: 2, child: buildHero());
      final hero = find.byType(HomeHero);
      final heroRect = tester.getRect(hero);
      expect(heroRect.height, greaterThan(normalHeight));
      for (final text in [
        hasContent ? '나중에 보려던 것들,' : '아직 저장한 콘텐츠가 없어요.',
        hasContent ? '지금 하나만 꺼내볼까요?' : '지금 하나만 저장해볼까요?',
        hasContent ? '오늘의 콘텐츠 보기 →' : '첫 콘텐츠 저장하기',
      ]) {
        expect(
          find.ancestor(of: find.text(text), matching: find.byType(FittedBox)),
          findsNothing,
        );
        _expectContained(tester.getRect(find.text(text)), heroRect);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in [
    'missing feed',
    'uninitialized',
    'loading',
    'error',
    'active category',
    'feed category',
    'stale feed items',
  ]) {
    testWidgets('unconfirmed empty $state preserves legacy entry copy', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final feed = _feed(const []);
      switch (state) {
        case 'uninitialized':
          feed.initialized = false;
        case 'loading':
          feed.loading = true;
        case 'error':
          feed.error = StateError('Fixture cannot load');
        case 'feed category':
          feed.categoryId = 2;
        case 'stale feed items':
          feed.items.add(_content(0));
      }
      await _render(
        tester,
        settle: state != 'loading',
        child: _home(
          contents: const [],
          feed: state == 'missing feed' ? null : feed,
          categoryId: state == 'active category' ? 2 : null,
        ),
      );
      expect(find.text('저장한 정보가 없어요.'), findsOneWidget);
      expect(find.text('지금 하나만 저장할까요?'), findsOneWidget);
      expect(find.text('저장 방법 보기 →'), findsOneWidget);
      expect(find.text('첫 콘텐츠 저장하기'), findsNothing);
      final heroImage = tester.widget<Image>(
        find.descendant(
          of: find.byType(HomeHero),
          matching: find.byType(Image),
        ),
      );
      expect((heroImage.image as AssetImage).assetName, Assets.character2Png);
      if (state == 'active category') {
        expect(find.byType(HomeFilteredEmptyContent), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final (categoryId, copy) in [
    (_unclassifiedCategory.id, '분류가 필요한 콘텐츠가 없어요'),
    (_secondCategory.id, '여행 콘텐츠가 없어요'),
  ]) {
    testWidgets('filtered empty category $categoryId shows "$copy"', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      await _render(
        tester,
        child: _panel(
          contents: const [],
          feed: _feed(const []),
          categoryId: categoryId,
          categories: const [_category, _secondCategory, _unclassifiedCategory],
        ),
      );
      final empty = find.byType(HomeFilteredEmptyContent);
      expect(
        find.descendant(of: empty, matching: find.text(copy)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: empty,
          matching: find.text('SNS에서 발견한 유용한 게시물을 저장하면 이곳에서 다시 확인할 수 있어요.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: empty,
          matching: _asset(Assets.homeEmptyIllustration),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: empty, matching: find.text('전체보기')),
        findsNothing,
      );
      expect(
        find.descendant(of: empty, matching: find.byType(TextButton)),
        findsNothing,
      );
      expect(find.textContaining('콘텐츠 콘텐츠'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  final longName = '가' * 40;
  for (final textScale in [1.0, 1.15, 1.3]) {
    for (final (name, copy, lines) in [
      (longName, '$longName 콘텐츠가 없어요', 2),
      (_unclassifiedCategory.name, '분류가 필요한 콘텐츠가 없어요', 1),
    ]) {
      testWidgets(
        'filtered empty ${name.length}-char "${name.substring(0, 2)}" '
        'fits at text scale $textScale',
        (tester) async {
          addTearDown(tester.view.reset);
          final category = CategoryItem(
            id: 9,
            name: name,
            color: AppColors.main,
            tint: AppColors.mainSubtle,
            deep: AppColors.mainDeep,
          );
          await _render(
            tester,
            textScale: textScale,
            child: _panel(
              contents: const [],
              feed: _feed(const []),
              categoryId: category.id,
              categories: [_category, category],
            ),
          );
          final empty = find.byType(HomeFilteredEmptyContent);
          final emptyRect = tester.getRect(empty);
          expect(
            emptyRect.height,
            closeTo(
              HomeContentPanel.recentAreaHeight(tester.element(empty)),
              0.001,
            ),
          );
          final title = find.descendant(of: empty, matching: find.text(copy));
          expect(title, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(title);
          final lineTops = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: copy.length),
              )
              .map((box) => box.top.round())
              .toSet();
          expect(lineTops.length, lines);
          final imageTop =
              tester
                  .getRect(
                    find.descendant(
                      of: empty,
                      matching: _asset(Assets.homeEmptyIllustration),
                    ),
                  )
                  .top -
              emptyRect.top;
          if (lines == 1) {
            expect(imageTop, 16, reason: 'one-line title keeps C02 16px');
          } else {
            expect(imageTop, inInclusiveRange(0, 16));
          }
          final message = find.descendant(
            of: empty,
            matching: find.byType(Column),
          );
          _expectContained(tester.getRect(message.first), emptyRect);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final textScale in [1.0, 1.15, 1.3]) {
    testWidgets(
      'chip switch keeps the recent area height at text scale $textScale',
      (tester) async {
        addTearDown(tester.view.reset);
        final cards = [_content(0, long: true), _content(1)];
        var contents = <ContentItem>[...cards];
        var feed = _feed(contents)..categoryId = _category.id;
        int? categoryId = _category.id;
        final reloads = <int?>[];
        late StateSetter setHarness;
        await _render(
          tester,
          textScale: textScale,
          child: StatefulBuilder(
            builder: (context, setState) {
              setHarness = setState;
              return _panel(
                contents: contents,
                feed: feed,
                categoryId: categoryId,
                onCategorySelected: (category) => setState(() {
                  // Mirrors the repository reset: items clear while loading.
                  reloads.add(category?.id);
                  categoryId = category?.id;
                  contents = const [];
                  feed = _feed(const [])
                    ..categoryId = category?.id
                    ..loading = true;
                }),
              );
            },
          ),
        );
        double panelHeight() =>
            tester.getSize(find.byType(HomeContentPanel)).height;
        void respond(List<ContentItem> items) => setHarness(() {
          contents = items;
          feed.items.addAll(items);
          feed.loading = false;
        });
        final chips = find.byType(CategoryChips);
        Finder chip(String label) =>
            find.descendant(of: chips, matching: find.text(label));

        expect(find.byType(HomeContentCard), findsNWidgets(2));
        expect(find.byType(PageDots), findsOneWidget);
        final cardsHeight = panelHeight();

        await tester.tap(chip('여행'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(panelHeight(), cardsHeight, reason: 'loading after switch');

        respond(cards);
        await tester.pump();
        expect(find.byType(HomeContentCard), findsNWidgets(2));
        expect(panelHeight(), cardsHeight);

        await tester.tap(chip('여행'));
        await tester.pump();
        expect(reloads, [_secondCategory.id, _secondCategory.id]);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(panelHeight(), cardsHeight, reason: 'loading after re-tap');

        respond(const []);
        await tester.pump();
        expect(find.byType(HomeFilteredEmptyContent), findsOneWidget);
        expect(panelHeight(), cardsHeight, reason: 'empty category');

        await tester.tap(chip('생활'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(panelHeight(), cardsHeight, reason: 'loading after empty');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final state in [
    'saved content',
    'no saved content',
    'empty chip',
    'loading',
    'error',
  ]) {
    testWidgets('$state home has no recent categories and keeps its blocks', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final contents = state == 'saved content'
          ? [_content(0), _content(1)]
          : const <ContentItem>[];
      final feed = _feed(contents);
      switch (state) {
        case 'loading':
          feed.loading = true;
        case 'error':
          feed.error = StateError('Fixture cannot load');
      }
      await _render(
        tester,
        settle: state != 'loading',
        child: _home(
          contents: contents,
          feed: feed,
          categoryId: state == 'empty chip' ? _secondCategory.id : null,
          weeklyItems: _weeklyTestItems,
        ),
      );
      expect(find.text('최근 카테고리'), findsNothing);
      expect(find.text('2020. 3. 10. 오후 11:56'), findsNothing);

      expect(find.byType(HomeHero), findsOneWidget);
      expect(find.text('이번주 허투루 픽 🎯'), findsOneWidget);
      expect(find.text('최근 저장한 콘텐츠'), findsOneWidget);
      expect(find.byType(CategoryChips), findsOneWidget);
      switch (state) {
        case 'saved content':
          expect(find.text('나중에 보려던 것들,'), findsOneWidget);
          expect(find.byType(HomeContentCard), findsNWidgets(2));
          expect(find.byType(PageDots), findsOneWidget);
        case 'no saved content':
          expect(find.text('아직 저장한 콘텐츠가 없어요.'), findsOneWidget);
          expect(find.byType(EmptyHomeContent), findsOneWidget);
          expect(find.text('저장한 콘텐츠가 없어요'), findsOneWidget);
        case 'empty chip':
          expect(find.text('여행 콘텐츠가 없어요'), findsOneWidget);
        case 'loading':
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        case 'error':
          expect(find.text('콘텐츠를 불러오지 못했어요.'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Weekly header hides chevron while recent header stays tappable',
    (tester) async {
      addTearDown(tester.view.reset);
      var archiveTaps = 0;
      var categoryTaps = 0;
      final contents = [_content(0)];
      await _render(
        tester,
        child: _panel(
          contents: contents,
          feed: _feed(contents),
          onOpenArchive: () => archiveTaps++,
          onOpenCategories: () => categoryTaps++,
        ),
      );
      final weeklyHeader = find.ancestor(
        of: find.text('이번주 허투루 픽 🎯'),
        matching: find.byType(SectionHeader),
      );
      final recentHeader = find.ancestor(
        of: find.text('최근 저장한 콘텐츠'),
        matching: find.byType(SectionHeader),
      );
      expect(
        find.descendant(of: weeklyHeader, matching: find.byType(SvgIcon)),
        findsNothing,
      );
      expect(
        find.descendant(of: recentHeader, matching: find.byType(SvgIcon)),
        findsOneWidget,
      );
      await tester.tap(find.text('최근 저장한 콘텐츠'));
      await tester.pumpAndSettle();
      expect(archiveTaps, 1);
      expect(categoryTaps, 0);
      await tester.tap(find.text('이번주 허투루 픽 🎯'));
      await tester.pumpAndSettle();
      expect(categoryTaps, 1);
      expect(archiveTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home category chips preserve selection with a 32px hit area', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    CategoryItem? selected;
    var calls = 0;
    final contents = [_content(0)];
    await _render(
      tester,
      child: _panel(
        contents: contents,
        feed: _feed(contents),
        onCategorySelected: (category) {
          selected = category;
          calls++;
        },
      ),
    );
    final chips = find.byType(CategoryChips);
    expect(tester.getSize(chips).height, 32);
    final inactive = find.descendant(of: chips, matching: find.text('여행'));
    final paragraph = tester.renderObject<RenderParagraph>(inactive);
    expect(paragraph.text.style?.color, AppColors.subtler);
    await tester.tap(inactive);
    await tester.pumpAndSettle();
    expect(selected?.id, 2);
    expect(calls, 1);
    await tester.tap(find.descendant(of: chips, matching: find.text('전체보기')));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero and one recent contents keep valid dots', (tester) async {
    addTearDown(tester.view.reset);
    await _render(
      tester,
      child: _panel(contents: const [], feed: _feed(const [])),
    );
    expect(find.byType(PageDots), findsNothing);
    final contents = [_content(0)];
    await _render(
      tester,
      child: _panel(contents: contents, feed: _feed(contents)),
    );
    expect(tester.widget<PageDots>(find.byType(PageDots)).count, 1);
    await _dragRecent(tester, 500);
    expect(_activeDot(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recent dots follow horizontal drag and clamp at fourth content',
    (tester) async {
      addTearDown(tester.view.reset);
      final contents = List.generate(6, _content);
      await _render(
        tester,
        child: _panel(contents: contents, feed: _feed(contents)),
      );
      expect(tester.widget<PageDots>(find.byType(PageDots)).count, 4);
      expect(_activeDot(tester), 0);
      await _dragRecent(tester, 306);
      expect(_activeDot(tester), 1);
      await _dragRecent(tester, 1500);
      expect(_activeDot(tester), 3);
      expect(
        _recentPosition(tester).pixels,
        _recentPosition(tester).maxScrollExtent,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in [
    'category',
    'feed category',
    'version',
    'ID order',
    'mutable items',
  ]) {
    testWidgets('recent scroll resets after $change changes', (tester) async {
      addTearDown(tester.view.reset);
      var contents = List.generate(4, _content);
      final feed = _feed(contents);
      if (change == 'mutable items') contents = feed.items;
      await _render(
        tester,
        child: _panel(contents: contents, feed: feed),
      );
      await _dragRecent(tester, 306);
      expect(_activeDot(tester), 1);
      int? categoryId;
      switch (change) {
        case 'category':
          categoryId = 2;
        case 'feed category':
          feed.categoryId = 2;
        case 'version':
          feed.version++;
        case 'ID order':
          contents = contents.reversed.toList();
        case 'mutable items':
          feed.items
            ..removeAt(0)
            ..add(_content(99));
      }
      await _render(
        tester,
        child: _panel(contents: contents, feed: feed, categoryId: categoryId),
      );
      expect(_activeDot(tester), 0);
      expect(_recentPosition(tester).pixels, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bookmark-only content copies preserve recent scroll and dot', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    var contents = List.generate(4, _content);
    final feed = _feed(contents);
    await _render(
      tester,
      child: _panel(contents: contents, feed: feed),
    );
    await _dragRecent(tester, 306);
    expect(_activeDot(tester), 1);
    final before = _recentPosition(tester).pixels;
    contents = contents.map((item) => item.copyWith(bookmarked: true)).toList();
    await _render(
      tester,
      child: _panel(
        contents: contents,
        feed: feed,
        bookmarkedIds: contents.map((item) => item.id).toSet(),
      ),
    );
    expect(_activeDot(tester), 1);
    expect(_recentPosition(tester).pixels, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shrinking recent contents clears stale last-dot selection', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    var contents = List.generate(4, _content);
    final feed = _feed(contents);
    await _render(
      tester,
      child: _panel(contents: contents, feed: feed),
    );
    await _dragRecent(tester, 1500);
    expect(_activeDot(tester), 3);
    contents = [contents.first];
    await _render(
      tester,
      child: _panel(contents: contents, feed: feed),
    );
    expect(tester.widget<PageDots>(find.byType(PageDots)).count, 1);
    expect(_activeDot(tester), 0);
    expect(_recentPosition(tester).pixels, 0);
    contents = [];
    feed.items.clear();
    await _render(
      tester,
      child: _panel(contents: contents, feed: feed),
    );
    expect(find.byType(PageDots), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _weeklyTestItems = [
  ApiWeeklyRecommendationItem(
    id: 1,
    rank: 1,
    type: WeeklyCardType.mostSaved,
    category: ApiCategory(
      id: 1,
      name: "아주 긴 카테고리 이름",
      color: null,
      isDefault: false,
    ),
  ),
  ApiWeeklyRecommendationItem(
    id: 2,
    rank: 3,
    type: WeeklyCardType.mostViewed,
    category: ApiCategory(id: 2, name: "다이어트", color: null, isDefault: false),
  ),
];
