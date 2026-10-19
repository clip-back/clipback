import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
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

const _uncategorized = CategoryItem(
  id: 99,
  name: '분류가 필요한 콘텐츠',
  color: Color(0xFFB5BDC3),
  tint: Color(0xFFE9ECEF),
  deep: Color(0xFF626C73),
  contentCount: 99,
);
const _other = CategoryItem(
  id: 101,
  name: '개발 자료',
  color: Color(0xFF059669),
  tint: Color(0x33059669),
  deep: Color(0xFF059669),
);
const _item = ContentItem(
  id: 'api-901',
  apiId: 901,
  title: '분류할 콘텐츠의 긴 제목을 실제 한 줄에 표시하고 남는 부분은 말줄임한다',
  summary:
      '원문과 요약을 보존하면서 두 줄 안에서 표시한다. 긴 요약은 세 번째 줄을 만들지 않고 말줄임한다. 저장 내용은 변경하지 않는다.',
  category: _uncategorized,
  categories: [_uncategorized],
  savedAt: '2026. 10. 17. 오후 3:00',
  savedAtFull: '2026. 10. 17. 오후 3:00',
  savedAtFullShort: '26. 10. 17.',
  tags: [],
  source: '웹',
  originalUrl: 'https://example.com/unclassified/901',
  originalText: '보존할 원문',
);

class _Calls {
  int back = 0;
  int search = 0;
  int settings = 0;
  int open = 0;
  int bookmark = 0;
  int category = 0;
  int delete = 0;
}

FeedPage _page({List<ContentItem> items = const [_item]}) => FeedPage()
  ..categoryId = 99
  ..initialized = true
  ..hasMore = false
  ..items.addAll(items);

Future<_Calls> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  FeedPage? page,
  bool filtered = true,
  String? categoryName,
  List<ContentItem>? contents,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final calls = _Calls();
  final feed = page ?? _page();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
        fontFamily: 'Pretendard',
      ),
      home: ArchiveScreen(
        activeTab: 0,
        contents: contents ?? feed.items,
        feed: feed,
        onLoadMore: () async {},
        onRetry: () {},
        categories: const [_other, _uncategorized],
        bookmarkedIds: const {},
        bookmarkedFirst: false,
        randomViewing: false,
        activeCategoryName: filtered
            ? categoryName ?? _uncategorized.name
            : null,
        onTabChanged: (_) {},
        onSortChanged: (_) {},
        onOpenRandomView: () {},
        onExitRandomView: () {},
        onClearCategory: () => calls.back++,
        onSearch: () => calls.search++,
        onOpenCategoryManagement: () => calls.settings++,
        onOpenContent: (_) => calls.open++,
        onToggleBookmark: (_) => calls.bookmark++,
        onChangeContentCategory: (_, _) => calls.category++,
        onDeleteContent: (_) => calls.delete++,
        onAddCategory: (_) {},
        onUpdateCategory: (_, _) {},
        onDeleteCategory: (_) {},
        onAddLink: ({required url, category}) async => _item,
        onAddScreenshot:
            ({required bytes, required filename, category}) async => _item,
        onOpenCategory: (_) {},
        onTab: (_) {},
      ),
    ),
  );
  // Loading states deliberately retain an animating progress indicator.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return calls;
}

Finder _key(String value) => find.byKey(ValueKey(value));

RenderParagraph _paragraph(WidgetTester tester, Finder text) {
  final rich = find.descendant(of: text, matching: find.byType(RichText));
  expect(rich, findsOneWidget);
  return tester.renderObject<RenderParagraph>(rich);
}

void _style(
  WidgetTester tester,
  Finder text, {
  required double size,
  required FontWeight weight,
  required double tracking,
  required Color color,
  double? height,
  String family = 'Pretendard',
}) {
  final paragraph = _paragraph(tester, text);
  final actual = (paragraph.text as TextSpan).style!;
  expect(actual.fontFamily, family);
  expect(actual.fontSize, size);
  expect(actual.fontWeight, weight);
  expect(actual.letterSpacing, tracking);
  expect(actual.color, color);
  expect(actual.height, height);
}

bool _inside(Rect inner, Rect outer) =>
    inner.left >= outer.left - .2 &&
    inner.right <= outer.right + .2 &&
    inner.top >= outer.top - .2 &&
    inner.bottom <= outer.bottom + .2;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final regular = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      regular.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    final bold = FontLoader('PretendardDetail')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'));
    await regular.load();
    await bold.load();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        'E06 header and only existing callbacks $platform width$width',
        (tester) async {
          final calls = await _pump(tester, platform: platform, width: width);
          final header = _key('unclassified-header');
          expect(header, findsOneWidget);
          final box = tester.getRect(header);
          expect(box.height, 64);
          final title = find.descendant(
            of: header,
            matching: find.text(_uncategorized.name),
          );
          _style(
            tester,
            title,
            size: 18,
            weight: FontWeight.w600,
            tracking: -.45,
            color: Colors.black,
          );
          expect(tester.getRect(title).left, closeTo(box.left + 48, .2));
          // E06 positions the inner row at calc(50% + 0.5px).
          final visualCenter = box.top + 32.5;
          expect(tester.getRect(title).center.dy, closeTo(visualCenter, .2));
          for (final role in ['back', 'search', 'settings']) {
            final control = _key('unclassified-$role');
            final svg = find.descendant(
              of: control,
              matching: find.byType(SvgPicture),
            );
            expect(svg, findsOneWidget);
            expect(tester.getSize(svg), const Size(24, 24));
            expect(tester.getRect(svg).center.dy, closeTo(visualCenter, .2));
            await tester.tap(control);
            await tester.pump();
          }
          expect([calls.back, calls.search, calls.settings], [1, 1, 1]);
          expect(find.byType(ArchiveToolbar), findsNothing);
          expect(find.byType(RandomReviewButton), findsNothing);
          expect(find.textContaining('불러온'), findsNothing);
          expect(
            tester.getRect(find.byType(ContentListCard).first).top,
            closeTo(box.bottom + 12, .2),
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('E06 E01 body and dedicated badge $platform width$width', (
        tester,
      ) async {
        await _pump(tester, platform: platform, width: width);
        final card = _key('archive-all-card-${_item.id}');
        expect(card, findsOneWidget);
        expect(tester.getSize(card).height, 173);
        final badge = _key('unclassified-badge-${_item.id}');
        expect(badge, findsOneWidget);
        expect(tester.getSize(badge), const Size(57, 22));
        final surface = tester
            .widgetList<DecoratedBox>(
              find.descendant(of: badge, matching: find.byType(DecoratedBox)),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .first;
        expect(surface.color, const Color(0xFFD1D1D1));
        _style(
          tester,
          find.descendant(of: badge, matching: find.text('미분류')),
          size: 12,
          weight: FontWeight.w500,
          tracking: -.3,
          color: const Color(0xFF767676),
        );
        for (final role in ['title', 'summary', 'date']) {
          final text = _key('archive-all-$role-${_item.id}');
          expect(text, findsOneWidget);
          expect(_inside(tester.getRect(text), tester.getRect(card)), isTrue);
          final paragraph = _paragraph(tester, text);
          expect(paragraph.maxLines, role == 'summary' ? 2 : 1);
          expect(paragraph.overflow, TextOverflow.ellipsis);
        }
        _style(
          tester,
          _key('archive-all-title-${_item.id}'),
          size: 16,
          weight: FontWeight.w600,
          tracking: -.4,
          color: AppColors.text,
          height: 1.4,
        );
        _style(
          tester,
          _key('archive-all-summary-${_item.id}'),
          size: 15,
          weight: FontWeight.w400,
          tracking: -.375,
          color: AppColors.middle,
          height: 1.6,
        );
        _style(
          tester,
          _key('archive-all-date-${_item.id}'),
          size: 14,
          weight: FontWeight.w400,
          tracking: -.35,
          color: const Color(0xFFA9A9A9),
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
      });

      testWidgets(
        'E06 completed empty natural paragraphs $platform width$width',
        (tester) async {
          await _pump(
            tester,
            platform: platform,
            width: width,
            page: _page(items: []),
          );
          final viewport = _key('unclassified-empty-viewport');
          final group = _key('unclassified-empty-group');
          expect(group, findsOneWidget);
          final outer = tester.getRect(viewport), inner = tester.getRect(group);
          expect(inner.width, 224);
          expect(inner.height, greaterThanOrEqualTo(250));
          expect(_inside(inner, outer), isTrue);
          expect(inner.center.dx, closeTo(outer.center.dx, .2));
          final expectedTop = (outer.center.dy - 84 - inner.height / 2).clamp(
            outer.top,
            (outer.bottom - inner.height).clamp(outer.top, double.infinity),
          );
          expect(inner.top, closeTo(expectedTop, .2));
          expect(
            tester.getSize(_key('unclassified-empty-image')),
            const Size(86, 100),
          );
          final title = _key('unclassified-empty-title');
          final body = _key('unclassified-empty-body');
          expect(tester.widget<Text>(title).data, '분류가 필요한\n콘텐츠가 없어요');
          expect(tester.widget<Text>(body).data, '저장한 콘텐츠가\n모두 정리되어있어요');
          expect(tester.getSize(title).width, lessThanOrEqualTo(192));
          expect(tester.getSize(body).width, lessThanOrEqualTo(192));
          expect(
            tester.getRect(title).top -
                tester.getRect(_key('unclassified-empty-image')).bottom,
            closeTo(16, .2),
          );
          expect(
            tester.getRect(body).top - tester.getRect(title).bottom,
            closeTo(8, .2),
          );
          _style(
            tester,
            title,
            family: 'PretendardDetail',
            size: 24,
            weight: FontWeight.w700,
            tracking: -.6,
            color: AppColors.text,
            height: 1.6,
          );
          _style(
            tester,
            body,
            size: 16,
            weight: FontWeight.w500,
            tracking: -.4,
            color: const Color(0xFF767676),
            height: 1.5,
          );
          for (final text in [title, body]) {
            final paragraph = _paragraph(tester, text);
            final painter = TextPainter(
              text: paragraph.text,
              textDirection: TextDirection.ltr,
              textScaler: paragraph.textScaler,
            )..layout(maxWidth: paragraph.size.width);
            expect(painter.computeLineMetrics(), hasLength(2));
            painter.dispose();
            expect(_inside(tester.getRect(text), inner), isTrue);
            expect(tester.widget<Text>(text).textAlign, TextAlign.center);
          }
          expect(find.byType(TextButton), findsNothing);
          expect(find.byType(OutlinedButton), findsNothing);
          expect(find.byType(ElevatedButton), findsNothing);
          expect(find.byType(RandomReviewButton), findsNothing);
          expect(find.byType(ArchiveToolbar), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'E06 pending card keeps body but blocks nested writes $platform width$width',
        (tester) async {
          final item = _item.copyWith(mutationLabel: '변경 중…');
          final calls = await _pump(
            tester,
            platform: platform,
            width: width,
            page: _page(items: [item]),
          );
          final bookmark = _key('list-bookmark-${item.title}');
          final more = _key('archive-all-more-${item.id}');
          for (final control in [bookmark, more]) {
            expect(control, findsOneWidget);
            expect(tester.getSize(control), const Size(28, 28));
            final rect = tester.getRect(control);
            for (final y in [rect.top + 1, rect.center.dy, rect.bottom - 1]) {
              await tester.tapAt(Offset(rect.center.dx, y));
              await tester.pump();
            }
          }
          expect([calls.bookmark, calls.category, calls.delete], [0, 0, 0]);
          expect(find.byType(ContentActionSheet), findsNothing);
          final before = calls.open;
          await tester.tap(find.text(item.title));
          await tester.pump();
          expect(calls.open - before, 1);
          expect(find.text('변경 중…'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final state in [
    'unqueried',
    'loading',
    'error',
    'has-more',
    'wrong-id',
    'no-filter-id',
  ]) {
    testWidgets('E06 zero items alone do not confirm empty: $state', (
      tester,
    ) async {
      final page = _page(items: []);
      switch (state) {
        case 'unqueried':
          page.initialized = false;
        case 'loading':
          page.loading = true;
        case 'error':
          page.error = StateError('조회 실패');
        case 'has-more':
          page.hasMore = true;
        case 'wrong-id':
          page.categoryId = 101;
        case 'no-filter-id':
          page.categoryId = null;
      }
      await _pump(tester, page: page);
      expect(_key('unclassified-empty-group'), findsNothing);
      if (['unqueried', 'loading', 'error'].contains(state)) {
        expect(find.byType(FeedStatus), findsOneWidget);
      }
      if (state == 'error') {
        expect(find.text('다시 시도'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('E06 remains separate from aligned F01 toolbar/card/random', (
    tester,
  ) async {
    final page = _page(items: [_item.copyWith(category: _other)])
      ..categoryId = 101;
    await _pump(tester, page: page, categoryName: _other.name);
    expect(find.byType(ArchiveToolbar), findsOneWidget);
    expect(find.byType(RandomReviewButton), findsOneWidget);
    expect(_key('unclassified-header'), findsNothing);
    expect(_key('unclassified-empty-group'), findsNothing);
    expect(_key('category-content-header'), findsOneWidget);
    expect(tester.getSize(find.byType(ArchiveToolbar)).height, 52);
    expect(_key('archive-all-card-${_item.id}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
