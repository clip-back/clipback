import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/feed_status.dart';
import 'package:clipback_frontend/shared/content/paged_content_list.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/widgets/skeleton_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _category = CategoryItem(
  id: 101,
  name: '개발 자료',
  color: Color(0xFF059669),
  tint: Color(0x33059669),
  deep: Color(0xFF027548),
);

ContentItem _item({List<CategoryItem>? categories}) => ContentItem(
  id: 'api-1',
  apiId: 1,
  title: '실제 카드 제목',
  summary: '실제 카드 요약',
  category: categories?.first ?? _category,
  categories: categories,
  savedAt: '26.10.18',
  savedAtFull: '2026.10.18',
  savedAtFullShort: '26.10.18',
  tags: const [],
  source: '웹',
  originalUrl: 'https://example.invalid/1',
  originalText: '',
);

Widget _frame(Widget child, {double textScale = 1, double width = 375}) =>
    MaterialApp(
      theme: ThemeData(fontFamily: 'Pretendard'),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 812),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: width, height: 700, child: child),
          ),
        ),
      ),
    );

PagedContentList _list({
  FeedPage? feed,
  List<ContentItem> contents = const [],
}) => PagedContentList(
  feed: feed,
  contents: contents,
  empty: const Text('빈 상태'),
  onRetry: () {},
  itemBuilder: (content) => Text('카드 ${content.title}'),
);

ContentListCard _realCard(List<CategoryItem> categories, {bool e06 = false}) =>
    ContentListCard(
      archiveAllStyle: !e06,
      unclassifiedStyle: e06,
      content: _item(categories: categories),
      onTap: () {},
      onToggleBookmark: () {},
      categories: categories,
      onChangeCategory: (_) {},
      onDelete: () {},
    );

Widget _top(Widget card) => Align(alignment: Alignment.topCenter, child: card);

final _skeleton = find.byType(ContentListCardSkeleton);
final _spinner = find.byType(CircularProgressIndicator);

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  group('representative inputs', () {
    testWidgets('no feed, one card: card without a footer', (tester) async {
      await tester.pumpWidget(_frame(_list(contents: [_item()])));
      expect(find.text('카드 실제 카드 제목'), findsOneWidget);
      expect(find.byType(FeedStatus), findsNothing);
      expect(_skeleton, findsNothing);
    });

    testWidgets('no feed, no card: empty widget', (tester) async {
      await tester.pumpWidget(_frame(_list()));
      expect(find.text('빈 상태'), findsOneWidget);
      expect(_skeleton, findsNothing);
    });

    testWidgets('feed loading, one card: card and footer spinner', (
      tester,
    ) async {
      final feed = FeedPage()
        ..initialized = true
        ..loading = true;
      await tester.pumpWidget(_frame(_list(feed: feed, contents: [_item()])));
      expect(find.text('카드 실제 카드 제목'), findsOneWidget);
      expect(_spinner, findsOneWidget);
      expect(_skeleton, findsNothing);
    });

    testWidgets('feed loading, no card: skeleton without a spinner', (
      tester,
    ) async {
      final feed = FeedPage()..loading = true;
      await tester.pumpWidget(_frame(_list(feed: feed)));
      expect(_skeleton, findsWidgets);
      expect(_spinner, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('feed not read yet, no card: skeleton without a spinner', (
      tester,
    ) async {
      await tester.pumpWidget(_frame(_list(feed: FeedPage())));
      expect(_skeleton, findsWidgets);
      expect(_spinner, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('feed error, no card: error text and retry', (tester) async {
      final feed = FeedPage()..error = StateError('실패');
      await tester.pumpWidget(_frame(_list(feed: feed)));
      expect(find.text('콘텐츠를 불러오지 못했어요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(_skeleton, findsNothing);
    });

    testWidgets('feed finished, no card: empty widget', (tester) async {
      final feed = FeedPage()
        ..initialized = true
        ..hasMore = false;
      await tester.pumpWidget(_frame(_list(feed: feed)));
      expect(find.text('빈 상태'), findsOneWidget);
      expect(_skeleton, findsNothing);
    });
  });

  testWidgets('skeleton cards fill the visible height and no more', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(_list(feed: FeedPage()..loading = true)));
    final cards = _skeleton.evaluate().length;
    final height = tester.getSize(_skeleton.first).height;
    expect(cards, ((700 + 8) / (height + 8)).ceil());
    final last = tester.getTopLeft(_skeleton.last).dy;
    expect(last, lessThan(700));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skeleton cards cannot be pressed', (tester) async {
    await tester.pumpWidget(_frame(_list(feed: FeedPage()..loading = true)));
    expect(
      find.descendant(of: _skeleton.first, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _skeleton.first,
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skeleton bars are absent from the semantics tree', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_frame(_list(feed: FeedPage()..loading = true)));
    expect(
      find.descendant(
        of: _skeleton.first,
        matching: find.byWidgetPredicate(
          (widget) => widget is Text,
          skipOffstage: false,
        ),
      ),
      findsWidgets,
    );
    final labels = <String>[];
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.label.isNotEmpty) labels.add(data.label);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tester.getSemantics(find.byType(ContentListSkeleton)));
    expect(labels, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  for (final scale in [1.0, 1.3]) {
    for (final e06 in [false, true]) {
      final shape = e06 ? 'E06' : 'E01';
      testWidgets('$shape skeleton matches a one-line badge card at $scale', (
        tester,
      ) async {
        final categories = e06 ? const [catUncategorized] : const [_category];
        await tester.pumpWidget(
          _frame(_top(_realCard(categories, e06: e06)), textScale: scale),
        );
        final real = tester.getSize(find.byType(ContentListCard));
        await tester.pumpWidget(
          _frame(
            _top(const SkeletonShimmer(child: ContentListCardSkeleton())),
            textScale: scale,
          ),
        );
        final skeleton = tester.getSize(_skeleton);
        expect(skeleton.width, real.width);
        expect(skeleton.height, closeTo(real.height, 0.01));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('skeleton list has no overflow at $scale', (tester) async {
      await tester.pumpWidget(
        _frame(_list(feed: FeedPage()..loading = true), textScale: scale),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('narrow skeleton card has no overflow at $scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _frame(
          _list(feed: FeedPage()..loading = true),
          textScale: scale,
          width: 320,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('first card position after the response at $scale', (
      tester,
    ) async {
      Widget view(FeedPage feed, List<ContentItem> contents, String? active) =>
          _frame(
            ContentListView(
              feed: feed,
              contents: contents,
              archiveAllStyle: active == null,
              bookmarkedIds: const {},
              bookmarkedFirst: false,
              activeCategoryName: active,
              categories: const [catUncategorized],
              onSortChanged: (_) {},
              onClearCategory: () {},
              onOpenContent: (_) {},
              onToggleBookmark: (_) {},
              onChangeContentCategory: (_, _) {},
              onDeleteContent: (_) {},
              onGoHome: () {},
            ),
            textScale: scale,
          );
      final done = FeedPage()
        ..initialized = true
        ..hasMore = false;
      for (final (active, gap) in [
        (null, 0.0),
        (catUncategorized.name, 12.0),
      ]) {
        await tester.pumpWidget(view(FeedPage()..loading = true, [], active));
        final waiting = tester.getTopLeft(_skeleton.first).dy;
        await tester.pumpWidget(
          view(done, [
            _item(categories: const [catUncategorized]),
          ], active),
        );
        final loaded = tester.getTopLeft(find.byType(ContentListCard)).dy;
        expect(loaded - waiting, closeTo(gap, 0.01));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('two-line badge card height difference at $scale', (
      tester,
    ) async {
      final many = [
        for (var index = 0; index < 2; index++)
          CategoryItem(
            id: index,
            name: '두 줄로 나뉘는 긴 카테고리 이름 $index',
            color: _category.color,
            tint: _category.tint,
            deep: _category.deep,
          ),
      ];
      await tester.pumpWidget(_frame(_top(_realCard(many)), textScale: scale));
      final real = tester.getSize(find.byType(ContentListCard)).height;
      await tester.pumpWidget(
        _frame(
          _top(const SkeletonShimmer(child: ContentListCardSkeleton())),
          textScale: scale,
        ),
      );
      final skeleton = tester.getSize(_skeleton).height;
      debugPrint('multi-badge scale=$scale real=$real skeleton=$skeleton');
      // One extra badge row plus the Wrap's 8 run spacing.
      expect(real - skeleton, closeTo(skeleton - 151 + 8, 0.01));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
