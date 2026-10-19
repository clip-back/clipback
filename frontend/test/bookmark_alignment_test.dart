import 'dart:math' as math;

import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/shared/content/content_actions.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/feed_status.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
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
  title: '즐겨찾기 콘텐츠의 긴 제목을 한 줄로 표시하고 남는 부분은 말줄임한다',
  summary:
      '실제 원문과 요약을 보존하면서 목록에서 두 줄 안으로 보여 줍니다. 긴 내용이 세 줄 이상을 필요로 해도 말줄임은 표시만 변경하며 실제 저장한 텍스트는 바꾸지 않습니다.',
  category: _category,
  categories: [_category],
  bookmarked: true,
  savedAt: '2026. 10. 17. 오후 3:00',
  savedAtFull: '2026. 10. 17. 오후 3:00',
  savedAtFullShort: '26.10.17',
  tags: [],
  source: '웹',
  originalUrl: 'https://example.invalid/bookmark/901',
  originalText: '보존할 원문',
);
const _nextItem = ContentItem(
  id: 'api-902',
  apiId: 902,
  title: '두 번째 즐겨찾기',
  summary: '간격을 검증하는 다른 콘텐츠',
  category: _category,
  bookmarked: true,
  savedAt: '26.10.16',
  savedAtFull: '2026.10.16',
  savedAtFullShort: '26.10.16',
  tags: [],
  source: '웹',
  originalUrl: 'https://example.invalid/bookmark/902',
  originalText: '',
);

class _Calls {
  int search = 0, settings = 0, archive = 0, body = 0, favorite = 0;
}

FeedPage _page({List<ContentItem> items = const [_item]}) => FeedPage()
  ..isFavorite = true
  ..initialized = true
  ..hasMore = false
  ..items.addAll(items);

Future<_Calls> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  FeedPage? page,
  bool attachFeed = true,
  List<ContentItem>? contents,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final calls = _Calls(), feed = page ?? _page();
  final entries = contents ?? feed.items;
  final named = <Symbol, dynamic>{
    #contents: entries,
    #feed: attachFeed ? feed : null,
    #onLoadMore: () async {},
    #onRetry: () {},
    #bookmarkedIds: entries.where((c) => c.bookmarked).map((c) => c.id).toSet(),
    #categories: const [_category, _second, _third],
    #onSearch: () => calls.search++,
    #onOpenContent: (ContentItem _) => calls.body++,
    #onToggleBookmark: (ContentItem _) => calls.favorite++,
    #onChangeContentCategory: (ContentItem _, CategoryItem _) {},
    #onDeleteContent: (ContentItem _) {},
    #onAddLink: ({required String url, CategoryItem? category}) async => _item,
    #onAddScreenshot:
        ({
          required Uint8List bytes,
          required String filename,
          CategoryItem? category,
        }) async => _item,
    #onTab: (dynamic _) {},
    #onOpenCategoryManagement: () => calls.settings++,
    #onOpenArchiveAll: () => calls.archive++,
  };
  late BookmarkScreen screen;
  try {
    screen =
        Function.apply(BookmarkScreen.new, const [], named) as BookmarkScreen;
  } on NoSuchMethodError {
    // BEFORE remains compilable without either newly optional callback.
    named.remove(#onOpenCategoryManagement);
    named.remove(#onOpenArchiveAll);
    screen =
        Function.apply(BookmarkScreen.new, const [], named) as BookmarkScreen;
  }
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
      home: screen,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return calls;
}

Finder _key(String value) => find.byKey(ValueKey(value));
RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
void _style(
  WidgetTester tester,
  Finder text, {
  required double size,
  required FontWeight weight,
  required double tracking,
  required Color color,
  double? height,
}) {
  final p = _paragraph(tester, text), s = (p.text as TextSpan).style!;
  expect(s.fontFamily, 'Pretendard');
  expect(s.fontSize, size);
  expect(p.textScaler.scale(size), size);
  expect(s.fontWeight, weight);
  expect(s.letterSpacing, tracking);
  expect(s.color, color);
  expect(s.height, height);
}

bool _inside(Rect child, Rect parent) =>
    child.left >= parent.left - .2 &&
    child.right <= parent.right + .2 &&
    child.top >= parent.top - .2 &&
    child.bottom <= parent.bottom + .2;

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
      testWidgets(
        'I01 header and read-only loaded toolbar $platform width$width',
        (tester) async {
          final calls = await _pump(tester, platform: platform, width: width);
          final header = _key('bookmark-header');
          expect(header, findsOneWidget);
          final h = tester.getRect(header);
          expect(h.height, 64);
          final title = find.descendant(
            of: header,
            matching: find.text('즐겨찾기'),
          );
          _style(
            tester,
            title,
            size: 18,
            weight: FontWeight.w600,
            tracking: -.45,
            color: Colors.black,
          );
          expect(tester.getRect(title).left, closeTo(h.left + 16, .2));
          expect(tester.getRect(title).center.dy, closeTo(h.top + 32.5, .2));
          final search = _key('bookmark-search'),
              settings = _key('bookmark-settings');
          final searchSvg = find.descendant(
            of: search,
            matching: find.byType(SvgPicture),
          );
          final settingsSvg = find.descendant(
            of: settings,
            matching: find.byType(SvgPicture),
          );
          for (final svg in [searchSvg, settingsSvg]) {
            expect(tester.getSize(svg), const Size(24, 24));
            expect(
              tester.getRect(svg).center.dy,
              closeTo(tester.getRect(title).center.dy, .2),
            );
          }
          expect(tester.getRect(settingsSvg).right, closeTo(h.right - 16, .2));
          expect(
            tester.getRect(settingsSvg).left - tester.getRect(searchSvg).right,
            16,
          );
          expect(_key('bookmark-back'), findsNothing);
          expect(
            find.descendant(of: header, matching: find.byType(SvgPicture)),
            findsNWidgets(2),
          );
          final toolbar = _key('bookmark-toolbar');
          expect(tester.getSize(toolbar).height, 52);
          expect(tester.getRect(toolbar).top, h.bottom);
          for (final text in [find.text('불러온 1개'), find.text('최신순')]) {
            _style(
              tester,
              text,
              size: 14,
              weight: FontWeight.w500,
              tracking: -.35,
              color: AppColors.subtle,
            );
            expect(
              tester.getRect(text).center.dy,
              closeTo(tester.getRect(toolbar).center.dy, .2),
            );
          }
          expect(
            find.descendant(of: toolbar, matching: find.byType(SvgPicture)),
            findsNothing,
          );
          expect(
            find.descendant(
              of: toolbar,
              matching: find.byType(PopupMenuButton<bool>),
            ),
            findsNothing,
          );
          await tester.tap(find.text('최신순'));
          await tester.pump();
          expect(find.byType(PopupMenuItem<bool>), findsNothing);
          await tester.tap(search);
          await tester.tap(settings);
          await tester.pump();
          expect([calls.search, calls.settings], [1, 1]);
          expect(
            tester.getRect(find.byType(ContentListCard)).top,
            tester.getRect(toolbar).bottom,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'I01 reuses E01 body and original content $platform width$width',
        (tester) async {
          await _pump(tester, platform: platform, width: width);
          final card = _key('archive-all-card-${_item.id}');
          expect(card, findsOneWidget);
          expect(tester.getSize(card).height, 173);
          final specifications = {
            'title': (16.0, FontWeight.w600, -.4, AppColors.text, 1.4),
            'summary': (15.0, FontWeight.w400, -.375, AppColors.middle, 1.6),
            'date': (
              14.0,
              FontWeight.w400,
              -.35,
              const Color(0xFFA9A9A9),
              null,
            ),
          };
          for (final spec in specifications.entries) {
            final text = _key('archive-all-${spec.key}-${_item.id}'),
                s = spec.value;
            _style(
              tester,
              text,
              size: s.$1,
              weight: s.$2,
              tracking: s.$3,
              color: s.$4,
              height: s.$5,
            );
            expect(
              _paragraph(tester, text).maxLines,
              spec.key == 'summary' ? 2 : 1,
            );
            expect(_paragraph(tester, text).overflow, TextOverflow.ellipsis);
            expect(_inside(tester.getRect(text), tester.getRect(card)), isTrue);
          }
          expect(
            tester
                .widget<ContentListCard>(find.byType(ContentListCard))
                .content,
            same(_item),
          );
          expect(
            _paragraph(
              tester,
              _key('archive-all-title-${_item.id}'),
            ).didExceedMaxLines,
            isTrue,
          );
          expect(
            _paragraph(
              tester,
              _key('archive-all-summary-${_item.id}'),
            ).didExceedMaxLines,
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'I01 actual multiple categories grow naturally $platform width$width',
        (tester) async {
          final item = _item.copyWith(categories: [_second, _category, _third]);
          await _pump(
            tester,
            platform: platform,
            width: width,
            page: _page(items: [item, _nextItem]),
          );
          final cards = find.byType(ContentListCard);
          final first = cards.first, second = cards.last;
          final wrap = _key('archive-all-badges-${item.id}');
          // The leading row has several real memberships; the next has a
          // distinct ID and is used only to verify the original8px separation.
          final firstWrap = find.descendant(of: first, matching: wrap).first;
          final names = tester
              .widgetList<Text>(
                find.descendant(of: firstWrap, matching: find.byType(Text)),
              )
              .map((t) => t.data)
              .toList();
          expect(names, [_second.name, _category.name, _third.name]);
          final extra = math.max(0, tester.getSize(firstWrap).height - 22);
          expect(tester.getSize(first).height, closeTo(173 + extra, .2));
          expect(extra, greaterThan(0));
          expect(tester.getRect(second).top - tester.getRect(first).bottom, 8);
          expect(
            tester
                .widget<ContentListCard>(first)
                .content
                .categories
                .map((c) => c.id),
            [202, 101, 303],
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'I01 nested hit targets and pending guard $platform width$width',
        (tester) async {
          var calls = await _pump(tester, platform: platform, width: width);
          final bookmark = _key('list-bookmark-${_item.title}'),
              more = _key('archive-all-more-${_item.id}');
          for (final control in [bookmark, more]) {
            expect(tester.getSize(control), const Size(28, 28));
          }
          await tester.tap(bookmark);
          await tester.pump();
          expect(calls.favorite, 1);
          await tester.tap(more);
          await tester.pumpAndSettle();
          expect(find.byType(ContentActionSheet), findsOneWidget);
          expect(
            tester
                .widget<ContentActionSheet>(find.byType(ContentActionSheet))
                .content,
            same(_item),
          );
          Navigator.of(tester.element(find.byType(ContentActionSheet))).pop();
          await tester.pumpAndSettle();
          calls = await _pump(
            tester,
            platform: platform,
            width: width,
            page: _page(items: [_item.copyWith(mutationLabel: '변경 중…')]),
          );
          for (final control in [bookmark, more]) {
            final rect = tester.getRect(control);
            for (final y in [rect.top + 1, rect.center.dy, rect.bottom - 1]) {
              await tester.tapAt(Offset(rect.center.dx, y));
              await tester.pump();
            }
          }
          expect(calls.favorite, 0);
          expect(find.byType(ContentActionSheet), findsNothing);
          final before = calls.body;
          await tester.tap(find.text(_item.title));
          await tester.pump();
          expect(calls.body - before, 1);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'I02 confirmed empty typography geometry and archive callback $platform width$width',
        (tester) async {
          final calls = await _pump(
            tester,
            platform: platform,
            width: width,
            page: _page(items: []),
          );
          final viewport = _key('bookmark-empty-viewport'),
              group = _key('bookmark-empty-group');
          expect(group, findsOneWidget);
          final vp = tester.getRect(viewport), g = tester.getRect(group);
          expect(g.width, lessThanOrEqualTo(260));
          expect(_inside(g, vp), isTrue);
          expect(g.center.dx, closeTo(vp.center.dx, .2));
          expect(
            g.top,
            closeTo(
              (vp.center.dy - 43.5 - g.height / 2).clamp(
                vp.top,
                math.max(vp.top, vp.bottom - g.height),
              ),
              .2,
            ),
          );
          expect(
            tester.getRect(viewport).top,
            tester.getRect(_key('bookmark-header')).bottom,
          );
          expect(
            tester.getSize(_key('bookmark-empty-image')),
            const Size(40, 46),
          );
          final title = _key('bookmark-empty-title'),
              body = _key('bookmark-empty-body');
          expect(tester.widget<Text>(title).data, '북마크한 콘텐츠가 없어요');
          expect(tester.widget<Text>(body).data, '중요한 정보는 북마크를 통해 저장하세요!');
          _style(
            tester,
            title,
            size: 16,
            weight: FontWeight.w500,
            tracking: -.4,
            color: AppColors.middle,
          );
          _style(
            tester,
            body,
            size: 14,
            weight: FontWeight.w500,
            tracking: -.35,
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
                tester.getRect(_key('bookmark-empty-image')).bottom,
            closeTo(16, .2),
          );
          expect(
            tester.getRect(body).top - tester.getRect(title).bottom,
            closeTo(8, .2),
          );
          final cta = _key('bookmark-empty-cta');
          expect(
            tester.getRect(cta).top - tester.getRect(body).bottom,
            closeTo(16, .2),
          );
          final surface = tester.widget<Container>(cta);
          final background = surface.decoration! as BoxDecoration;
          final outline = surface.foregroundDecoration! as BoxDecoration;
          expect(background.color, Colors.white);
          expect(background.borderRadius, BorderRadius.circular(4));
          expect(outline.borderRadius, BorderRadius.circular(4));
          expect(
            outline.border,
            Border.all(color: const Color(0xFFD1D1D1), width: 1),
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
            tracking: -.4,
            color: AppColors.text,
          );
          final icon = find.descendant(
            of: cta,
            matching: find.byType(SvgPicture),
          );
          expect(tester.getSize(icon), const Size(18, 18));
          expect(tester.getSize(cta).height, greaterThanOrEqualTo(35));
          expect(
            tester.getRect(label).left - tester.getRect(icon).right,
            closeTo(4, .2),
          );
          expect(
            tester.getRect(icon).left - tester.getRect(cta).left,
            closeTo(16, .2),
          );
          expect(
            tester.getRect(cta).right - tester.getRect(label).right,
            closeTo(16, .2),
          );
          expect(
            tester.getSize(cta).height,
            closeTo(
              math.max(35, math.max(tester.getSize(label).height, 18) + 16),
              .2,
            ),
          );
          expect(_key('bookmark-toolbar'), findsNothing);
          await tester.tap(cta);
          await tester.pump();
          expect(calls.archive, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('I02 short viewport scroll exposes the natural CTA $platform', (
      tester,
    ) async {
      await _pump(
        tester,
        platform: platform,
        height: 300,
        page: _page(items: []),
      );
      final viewport = _key('bookmark-empty-viewport'),
          group = _key('bookmark-empty-group');
      expect(group, findsOneWidget);
      final scrollable = find.descendant(
        of: viewport,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final vp = tester.getRect(viewport);
      expect(_inside(tester.getRect(_key('bookmark-empty-cta')), vp), isTrue);
      expect(_inside(tester.getRect(_key('bookmark-empty-body')), vp), isTrue);
      _style(
        tester,
        _key('bookmark-empty-title'),
        size: 16,
        weight: FontWeight.w500,
        tracking: -.4,
        color: AppColors.middle,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in [
    'missing-feed',
    'not-favorite',
    'unknown-favorite',
    'query',
    'category',
    'unqueried',
    'loading',
    'error',
    'has-more',
    'actual-items',
  ]) {
    testWidgets('I02 zero guard retains existing state: $state', (
      tester,
    ) async {
      final page = _page(items: []);
      switch (state) {
        case 'not-favorite':
          page.isFavorite = false;
        case 'unknown-favorite':
          page.isFavorite = null;
        case 'query':
          page.query = '검색';
        case 'category':
          page.categoryId = 101;
        case 'unqueried':
          page.initialized = false;
        case 'loading':
          page.loading = true;
        case 'error':
          page.error = StateError('조회 실패');
        case 'has-more':
          page.hasMore = true;
        case 'actual-items':
          page.items.add(_item);
      }
      await _pump(
        tester,
        page: page,
        attachFeed: state != 'missing-feed',
        contents: const [],
      );
      expect(_key('bookmark-empty-group'), findsNothing);
      if (['unqueried', 'loading', 'error'].contains(state)) {
        expect(find.byType(FeedStatus), findsOneWidget);
      }
      if (state == 'error') expect(find.text('다시 시도'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
