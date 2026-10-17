import 'dart:async';
import 'dart:math' as math;

import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/feed_status.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _category = CategoryItem(
  id: 101,
  name: '개발 자료',
  color: Color(0xFF059669),
  tint: Color(0x33059669),
  deep: Color(0xFF027548),
);
const _second = CategoryItem(
  id: 202,
  name: '여행을 위한 참고자료',
  color: Color(0xFFFF6277),
  tint: Color(0x33FF6277),
  deep: Color(0xFFB83748),
);
const _third = CategoryItem(
  id: 303,
  name: '다시 읽을 긴 이름의 카테고리',
  color: Color(0xFFFFA24B),
  tint: Color(0x33FFA24B),
  deep: Color(0xFFA65516),
);
const _item = ContentItem(
  id: 'api-901',
  apiId: 901,
  title: '검색한 콘텐츠의 긴 제목을 한 줄로 표시하고 남는 부분은 말줄임한다',
  summary:
      '실제 원문과 요약을 보존하면서 두 줄 안으로 보여 줍니다. 긴 요약은 세 번째 줄을 필요로 해도 말줄임으로만 표시하고 저장한 내용을 임의로 바꾸지 않습니다.',
  category: _category,
  savedAt: '26.10.18',
  savedAtFull: '2026.10.18',
  savedAtFullShort: '26.10.18',
  tags: [],
  source: '웹',
  originalUrl: 'https://example.invalid/search/901',
  originalText: '원문',
);
const _nextItem = ContentItem(
  id: 'api-902',
  apiId: 902,
  title: '두 번째 검색 결과',
  summary: '다른 콘텐츠',
  category: _category,
  savedAt: '26.10.17',
  savedAtFull: '2026.10.17',
  savedAtFullShort: '26.10.17',
  tags: [],
  source: '웹',
  originalUrl: 'https://example.invalid/search/902',
  originalText: '',
);

class _Calls {
  final searches = <String>[], changes = <String>[];
  int close = 0, archive = 0, open = 0, bookmark = 0;
}

FeedPage _page({
  String? query = '검증',
  List<ContentItem> items = const [_item],
}) => FeedPage()
  ..query = query
  ..initialized = true
  ..hasMore = false
  ..items.addAll(items);

Future<_Calls> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  String query = '검증',
  FeedPage? page,
  List<ContentItem>? contents,
  bool attachFeed = true,
  Future<List<ContentItem>> Function(String)? search,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final calls = _Calls(), feed = page ?? _page();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
      ),
      home: SearchScreen(
        initialQuery: query,
        contents: contents ?? feed.items,
        feed: attachFeed ? feed : null,
        onLoadMore: () async {},
        onRetry: () {},
        bookmarkedIds: const {},
        categories: const [_category, _second, _third],
        onSearch: (value) {
          calls.searches.add(value);
          return search?.call(value) ?? Future.value(const []);
        },
        onQueryChanged: calls.changes.add,
        onClose: () => calls.close++,
        onOpenContent: (_) => calls.open++,
        onToggleBookmark: (_) => calls.bookmark++,
        onChangeContentCategory: (_, _) {},
        onDeleteContent: (_) {},
        onOpenArchive: () => calls.archive++,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return calls;
}

Finder _key(String name) => find.byKey(ValueKey(name));
RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
void _style(
  WidgetTester tester,
  Finder text, {
  required double size,
  required FontWeight weight,
  required double spacing,
  required Color color,
  double? height,
}) {
  final p = _paragraph(tester, text), s = (p.text as TextSpan).style!;
  expect(s.fontFamily, 'Pretendard');
  expect(s.fontSize, size);
  expect(p.textScaler.scale(size), size);
  expect(s.fontWeight, weight);
  expect(s.letterSpacing, spacing);
  expect(s.color, color);
  expect(s.height, height);
}

bool _inside(Rect child, Rect parent) =>
    child.left >= parent.left - .2 &&
    child.right <= parent.right + .2 &&
    child.top >= parent.top - .2 &&
    child.bottom <= parent.bottom + .2;
Future<void> _clear(WidgetTester tester) async {
  final key = _key('search-clear');
  await tester.tap(
    key.evaluate().isNotEmpty
        ? key
        : find.byWidgetPredicate(
            (w) => w is SvgIcon && w.asset == Assets.close,
          ),
  );
  await tester.pump();
}

Future<void> _submit(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  tester.widget<TextField>(find.byType(TextField)).onSubmitted!(query);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets('H01 input and recent-history1x $platform width$width', (
        tester,
      ) async {
        final calls = await _pump(
          tester,
          platform: platform,
          width: width,
          query: '',
          page: _page(query: null, items: []),
        );
        final header = _key('search-header'),
            row = _key('search-row'),
            box = _key('search-input-box');
        expect(header, findsOneWidget);
        final h = tester.getRect(header), input = tester.getRect(box);
        expect(h.height, 76);
        expect(tester.getSize(row).height, 44);
        expect(input.height, 44);
        expect(input.top - h.top, 16);
        expect(input.left - h.left, 16);
        final title = find.text('최근 검색어');
        expect(tester.getRect(title).top - h.bottom, closeTo(16, .2));
        _style(
          tester,
          title,
          size: 15,
          weight: FontWeight.w600,
          spacing: -.375,
          color: const Color(0xFF121212),
        );
        _style(
          tester,
          find.text('취소'),
          size: 15,
          weight: FontWeight.w500,
          spacing: -.375,
          color: const Color(0xFF595959),
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, isEmpty);
        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(editable.style.fontFamily, 'Pretendard');
        expect(editable.style.fontSize, 14);
        expect(editable.style.fontWeight, FontWeight.w500);
        expect(editable.style.letterSpacing, -.35);
        expect(editable.style.height, 1.4);
        expect(editable.style.color, AppColors.text);
        _style(
          tester,
          find.text('찾고 싶은 정보를 검색해보세요'),
          size: 14,
          weight: FontWeight.w500,
          spacing: -.35,
          color: const Color(0xFFB5BDC3),
          height: 1.4,
        );
        expect(tester.getSize(_key('search-input-icon')), const Size(16, 16));
        expect(_key('search-clear'), findsNothing);
        final history = find.byType(SearchHistoryRow);
        expect(history, findsNWidgets(5));
        final rows = tester.widgetList<SearchHistoryRow>(history).toList();
        expect(rows.map((r) => r.term), recentSearches);
        expect(
          tester.getRect(history.first).top - tester.getRect(title).bottom,
          closeTo(16, .2),
        );
        for (var i = 0; i < rows.length; i++) {
          final f = history.at(i), r = tester.getRect(f);
          expect(r.height, 32);
          _style(
            tester,
            find.descendant(of: f, matching: find.text(rows[i].term)),
            size: 14,
            weight: FontWeight.w500,
            spacing: -.35,
            color: AppColors.subtle,
          );
          final clock = _key('search-history-clock-${rows[i].term}');
          expect(tester.getSize(clock), const Size(18, 18));
          expect(
            tester.getRect(find.text(rows[i].term)).left -
                tester.getRect(clock).right,
            closeTo(9.542, .2),
          );
          expect(
            tester.getSize(_key('search-history-remove-${rows[i].term}')),
            const Size(18, 18),
          );
          if (i > 0) {
            expect(r.top - tester.getRect(history.at(i - 1)).bottom, 4);
          }
        }
        expect(calls.searches, isEmpty);
        await tester.tap(find.text('취소'));
        await tester.pump();
        expect(calls.close, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'H02 callback results use base aligned cards and clear input $platform width$width',
        (tester) async {
          await _pump(
            tester,
            platform: platform,
            width: width,
            attachFeed: false,
            contents: const [],
            search: (_) async => const [_item, _nextItem],
          );
          tester.widget<TextField>(find.byType(TextField)).onSubmitted!('검증');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final cards = find.byType(ContentListCard);
          expect(cards, findsNWidgets(2));
          expect(_key('archive-all-card-${_item.id}'), findsOneWidget);
          expect(tester.getSize(cards.first).height, 173);
          expect(
            tester.getRect(cards.last).top - tester.getRect(cards.first).bottom,
            8,
          );
          expect(
            tester.getRect(cards.first).top -
                tester.getRect(_key('search-row')).bottom,
            closeTo(16, .2),
          );
          expect(tester.getSize(_key('search-clear')), const Size(18, 18));
          final originalController = tester
              .widget<TextField>(find.byType(TextField))
              .controller;
          await _clear(tester);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller,
            same(originalController),
          );
          expect(originalController!.text, isEmpty);
          expect(find.text('최근 검색어'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'H02 aligned result cards preserve memberships $platform width$width',
        (tester) async {
          final item = _item.copyWith(categories: [_second, _category, _third]);
          final calls = await _pump(
            tester,
            platform: platform,
            width: width,
            page: _page(items: [item]),
          );
          final card = _key('archive-all-card-${item.id}'),
              wrap = _key('archive-all-badges-${item.id}');
          expect(card, findsOneWidget);
          expect(find.textContaining('불러온 '), findsNothing);
          expect(
            tester.getRect(card).top -
                tester.getRect(_key('search-row')).bottom,
            closeTo(16, .2),
          );
          final delta = math.max(0, tester.getSize(wrap).height - 22);
          expect(tester.getSize(card).height, closeTo(173 + delta, .2));
          expect(
            tester
                .widgetList<Text>(
                  find.descendant(of: wrap, matching: find.byType(Text)),
                )
                .map((t) => t.data),
            [_second.name, _category.name, _third.name],
          );
          for (final role in ['title', 'summary', 'date']) {
            final text = _key('archive-all-$role-${item.id}');
            expect(_inside(tester.getRect(text), tester.getRect(card)), isTrue);
            expect(
              _paragraph(tester, text).maxLines,
              role == 'summary' ? 2 : 1,
            );
            expect(_paragraph(tester, text).overflow, TextOverflow.ellipsis);
          }
          _style(
            tester,
            _key('archive-all-title-${item.id}'),
            size: 16,
            weight: FontWeight.w600,
            spacing: -.4,
            color: AppColors.text,
            height: 1.4,
          );
          _style(
            tester,
            _key('archive-all-summary-${item.id}'),
            size: 15,
            weight: FontWeight.w400,
            spacing: -.375,
            color: AppColors.middle,
            height: 1.6,
          );
          await tester.tap(find.text(item.title));
          await tester.pump();
          expect(calls.open, 1);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'H03 confirmed search zero natural layout $platform width$width',
        (tester) async {
          final calls = await _pump(
            tester,
            platform: platform,
            width: width,
            page: _page(items: []),
          );
          final viewport = _key('search-empty-viewport'),
              group = _key('search-empty-group');
          expect(group, findsOneWidget);
          final vp = tester.getRect(viewport), g = tester.getRect(group);
          expect(g.width, lessThanOrEqualTo(260));
          expect(_inside(g, vp), isTrue);
          expect(g.center.dx, closeTo(vp.center.dx, .2));
          expect(
            g.top,
            closeTo(
              (vp.center.dy - 92.5 - g.height / 2).clamp(
                vp.top,
                math.max(vp.top, vp.bottom - g.height),
              ),
              .2,
            ),
          );
          expect(
            tester.getSize(_key('search-empty-image')),
            const Size(81, 123),
          );
          expect(
            tester.widget<Image>(_key('search-empty-image-source')).fit,
            BoxFit.cover,
          );
          final title = _key('search-empty-title'),
              body = _key('search-empty-body');
          _style(
            tester,
            title,
            size: 16,
            weight: FontWeight.w500,
            spacing: -.4,
            color: AppColors.middle,
          );
          _style(
            tester,
            body,
            size: 14,
            weight: FontWeight.w500,
            spacing: -.35,
            color: AppColors.subtle,
            height: 1.6,
          );
          for (final text in [title, body]) {
            expect(
              _paragraph(tester, text).constraints.maxWidth,
              lessThanOrEqualTo(260),
            );
            expect(_inside(tester.getRect(text), g), isTrue);
            expect(tester.getRect(text).center.dx, closeTo(g.center.dx, .2));
          }
          expect(
            tester.getRect(title).top -
                tester.getRect(_key('search-empty-image')).bottom,
            closeTo(16, .2),
          );
          expect(
            tester.getRect(body).top - tester.getRect(title).bottom,
            closeTo(8, .2),
          );
          final cta = _key('search-empty-cta');
          expect(
            tester.getRect(cta).top - tester.getRect(body).bottom,
            closeTo(16, .2),
          );
          final label = find.descendant(
            of: cta,
            matching: find.text('전체 리스트 보기'),
          );
          _style(
            tester,
            label,
            size: 16,
            weight: FontWeight.w500,
            spacing: -.4,
            color: AppColors.text,
          );
          final icon = find.descendant(
            of: cta,
            matching: find.byType(SvgPicture),
          );
          expect(tester.getSize(icon), const Size(18, 18));
          expect(
            tester.getRect(label).left - tester.getRect(icon).right,
            closeTo(4, .2),
          );
          final container = tester.widget<Container>(cta),
              background =
                  tester.widget<Container>(cta).decoration! as BoxDecoration;
          final border = container.foregroundDecoration! as BoxDecoration;
          expect(background.color, Colors.white);
          expect(background.borderRadius, BorderRadius.circular(4));
          expect(border.border, Border.all(color: const Color(0xFFD1D1D1)));
          expect(
            tester.getSize(cta).height,
            closeTo(
              math.max(35, math.max(18, tester.getSize(label).height) + 16),
              .2,
            ),
          );
          await tester.tap(cta);
          await tester.pump();
          expect(calls.archive, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('H03 short viewport scroll reveals the natural CTA $platform', (
      tester,
    ) async {
      await _pump(
        tester,
        platform: platform,
        height: 300,
        page: _page(items: []),
      );
      final viewport = _key('search-empty-viewport');
      expect(_key('search-empty-group'), findsOneWidget);
      final scrollable = find.descendant(
        of: viewport,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(
        _inside(
          tester.getRect(_key('search-empty-cta')),
          tester.getRect(viewport),
        ),
        isTrue,
      );
      expect(
        _inside(
          tester.getRect(_key('search-empty-body')),
          tester.getRect(viewport),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in [
    'missing-query',
    'other-query',
    'favorite',
    'category',
    'unqueried',
    'loading',
    'error',
    'has-more',
    'actual-items',
  ]) {
    testWidgets('H03 guard preserves unconfirmed state $state', (tester) async {
      final p = _page(items: []);
      switch (state) {
        case 'missing-query':
          p.query = null;
        case 'other-query':
          p.query = '다른 검색';
        case 'favorite':
          p.isFavorite = true;
        case 'category':
          p.categoryId = 101;
        case 'unqueried':
          p.initialized = false;
        case 'loading':
          p.loading = true;
        case 'error':
          p.error = StateError('검색 실패');
        case 'has-more':
          p.hasMore = true;
        case 'actual-items':
          p.items.add(_item);
      }
      await _pump(tester, page: p, contents: const []);
      expect(_key('search-empty-group'), findsNothing);
      if (['unqueried', 'loading', 'error'].contains(state)) {
        expect(find.byType(FeedStatus), findsOneWidget);
      }
      if (state == 'error') expect(find.text('다시 시도'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'H01 preserves current example five and in-screen history policy',
    (tester) async {
      await _pump(tester, query: '', attachFeed: false, contents: const []);
      expect(
        tester
            .widgetList<SearchHistoryRow>(find.byType(SearchHistoryRow))
            .map((r) => r.term),
        recentSearches,
      );
      for (final term in ['새 검색1', '새 검색2', '새 검색1']) {
        await _submit(tester, term);
        await tester.pump();
        await _clear(tester);
      }
      final rows = tester
          .widgetList<SearchHistoryRow>(find.byType(SearchHistoryRow))
          .toList();
      expect(rows, hasLength(5));
      expect(rows.take(2).map((r) => r.term), ['새 검색1', '새 검색2']);
      rows.first.onRemove();
      await tester.pump();
      expect(
        tester
            .widgetList<SearchHistoryRow>(find.byType(SearchHistoryRow))
            .map((r) => r.term),
        isNot(contains('새 검색1')),
      );
    },
  );
  testWidgets(
    'H01 typing and whitespace do not submit while nonempty submit trims',
    (tester) async {
      final calls = await _pump(
        tester,
        query: '',
        attachFeed: false,
        contents: const [],
      );
      await tester.enterText(find.byType(TextField), '  키워드  ');
      expect(calls.searches, isEmpty);
      expect(calls.changes.last, '  키워드  ');
      tester.widget<TextField>(find.byType(TextField)).onSubmitted!('  키워드  ');
      await tester.pump();
      expect(calls.searches, ['키워드']);
      await _submit(tester, '   ');
      expect(calls.searches, ['키워드']);
      expect(tester.takeException(), isNull);
    },
  );
  for (final outcome in ['success', 'failure']) {
    testWidgets(
      'H03 callback-only $outcome requires completed current request',
      (tester) async {
        final gate = Completer<List<ContentItem>>();
        await _pump(
          tester,
          query: '검증',
          attachFeed: false,
          contents: const [],
          search: (_) => gate.future,
        );
        expect(_key('search-empty-group'), findsNothing);
        tester.widget<TextField>(find.byType(TextField)).onSubmitted!('검증');
        await tester.pump();
        expect(_key('search-empty-group'), findsNothing);
        if (outcome == 'success') {
          gate.complete(const []);
        } else {
          gate.completeError(StateError('검색 실패'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          _key('search-empty-group'),
          outcome == 'success' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('H03 late callback cannot make another edited query empty', (
    tester,
  ) async {
    final gate = Completer<List<ContentItem>>();
    await _pump(
      tester,
      query: '처음',
      attachFeed: false,
      contents: const [],
      search: (_) => gate.future,
    );
    tester.widget<TextField>(find.byType(TextField)).onSubmitted!('처음');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '나중');
    gate.complete(const []);
    await tester.pump();
    expect(_key('search-empty-group'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final state in ['loading', 'error']) {
    testWidgets('H02 retains existing rows during $state', (tester) async {
      final p = _page();
      if (state == 'loading') {
        p.loading = true;
      } else {
        p.error = StateError('추가 조회 실패');
      }
      await _pump(tester, page: p);
      expect(find.byType(ContentListCard), findsOneWidget);
      expect(find.byType(FeedStatus), findsOneWidget);
      expect(_key('search-empty-group'), findsNothing);
      if (state == 'error') expect(find.text('다시 시도'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
