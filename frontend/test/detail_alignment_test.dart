import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/tag_chip.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _primary = CategoryItem(
  id: 10,
  name: '실제 첫 분류',
  color: Colors.green,
  tint: Color(0xFFE3F5E9),
  deep: Color(0xFF127342),
);
const _secondary = CategoryItem(
  id: 20,
  name: '실제 두 번째 분류',
  color: Colors.purple,
  tint: Color(0xFFF2E6FA),
  deep: Color(0xFF763B91),
);
const _title = '하나씩 오래 기억하고 싶은 콘텐츠 이야기';
const _summary = '서버에서 받은 실제 요약을 두 문장으로 보존합니다. 두 번째 문장도 그대로 표시합니다.';
const _original =
    '별도로 전달한 전문 대역입니다. 보이는 문구와 원문 펼침 동작을 확인합니다. '
    '내용을 임의로 요약하거나 교체하지 않고 제공된 문자열 전체를 표시합니다.';
const _date = '2026. 10. 17 오후 03:40';
const _relatedHeading = '함께 보면 좋은 콘텐츠';
const _emptyRelated = '불러온 목록에 연관 콘텐츠가 없어요.';
bool _boldAvailable = false;

ContentItem _content(
  String id, {
  String title = _title,
  String summary = _summary,
  List<CategoryItem> categories = const [_primary],
  List<String> tags = const ['첫태그', '다른태그', '마지막태그'],
}) => ContentItem(
  id: id,
  apiId: id.hashCode,
  title: title,
  summary: summary,
  category: categories.first,
  categories: categories,
  savedAt: '26.10.17',
  savedAtFull: _date,
  savedAtFullShort: '2026. 10. 17 15:40',
  tags: tags,
  source: '웹 링크',
  originalUrl: 'https://example.invalid/detail/$id',
  originalText: _original,
);

class _Scene {
  const _Scene(this.name, this.current, this.contents, {this.expanded = false});
  final String name;
  final ContentItem current;
  final List<ContentItem> contents;
  final bool expanded;
  List<ContentItem> get related => contents
      .where(
        (item) =>
            item.id != current.id &&
            item.category.name == current.category.name,
      )
      .toList();
}

List<_Scene> _scenes() {
  final current = _content('current');
  final related = _content('related', title: '실제로 연관된 한 항목');
  final multi = _content(
    'multi',
    categories: const [_primary, _secondary],
    tags: const ['긴태그이름을보존하는항목', '두번째긴태그이름도그대로', '짧은태그', '네번째태그', '다섯번째태그'],
  );
  final multiRelated = _content(
    'multi-related',
    title: '복수 분류가 있는 연관 항목',
    categories: const [_primary, _secondary],
  );
  final unrelated = _content(
    'unrelated',
    title: '태그만 같아서 제외할 항목',
    categories: const [_secondary],
  );
  final secondaryOnly = _content(
    'secondary-only',
    title: '두 번째 분류만 같아서 제외할 항목',
    categories: const [_secondary, _primary],
  );
  final long = _content(
    'long',
    title: List.filled(6, '줄임 없이 표시해야 하는 긴 콘텐츠 제목').join(' '),
    summary: List.filled(6, '요약이 세 줄을 넘어가더라도 전달한 내용을 그대로 보존합니다.').join(' '),
    categories: [
      _primary.copyWith(name: '한 줄보다 길어도 실제 이름을 보존하는 아주 긴 첫 카테고리'),
      _secondary.copyWith(name: '두 번째 카테고리 이름도 줄바꿈 영역에서 보존합니다'),
    ],
    tags: const [],
  );
  return [
    _Scene('expanded', current, [current, related], expanded: true),
    _Scene('empty-related-long-content', long, [long]),
    _Scene('multiple-categories', multi, [
      multiRelated,
      multi,
      unrelated,
      related,
      secondaryOnly,
    ]),
  ];
}

class _Calls {
  int back = 0;
  int bookmark = 0;
  int original = 0;
  final opened = <ContentItem>[];
  final adjacent = <int>[];
  final tabs = <AppRoute>[];
}

Future<_Calls> _pump(
  WidgetTester tester,
  _Scene scene,
  TargetPlatform platform,
  double width,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1)),
        child: child!,
      ),
      home: DetailScreen(
        content: scene.current,
        contents: scene.contents,
        categories: const [_primary, _secondary],
        bookmarked: false,
        onReadAsset: (_) async => Uint8List(0),
        onBack: () => calls.back++,
        onToggleBookmark: (_) => calls.bookmark++,
        onChangeCategory: (_, _) {},
        onDeleteContent: (_) {},
        onOpenOriginalLink: () => calls.original++,
        onOpenAdjacent: calls.adjacent.add,
        onOpenContent: calls.opened.add,
        onAddLink: ({required url, category}) async => scene.current,
        onAddScreenshot:
            ({required bytes, required filename, category}) async =>
                scene.current,
        onTab: calls.tabs.add,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

Finder _role(String key, Finder fallback) {
  final keyed = find.byKey(ValueKey(key));
  return keyed.evaluate().isEmpty ? fallback : keyed;
}

Finder _textRole(String key, String fallback, {String? legacy}) {
  final role = _role(
    key,
    find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data == fallback ||
              (legacy != null && widget.data == legacy)),
    ),
  );
  if (role.evaluate().isEmpty || role.evaluate().single.widget is Text) {
    return role;
  }
  return find.descendant(of: role, matching: find.byType(Text)).first;
}

Finder _mainList() => find
    .descendant(of: find.byType(DetailScreen), matching: find.byType(ListView))
    .first;
Finder _scrollable() =>
    find.descendant(of: _mainList(), matching: find.byType(Scrollable)).first;
ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(_scrollable()).position;

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 160, scrollable: _scrollable());
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    final old = _position(tester).pixels;
    _position(tester).jumpTo(_position(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    if ((_position(tester).pixels - old).abs() < .1) break;
  }
}

void _same(
  List<String> failures,
  String role,
  Object? actual,
  Object? expected,
) {
  if (actual != expected) failures.add('$role: $actual instead of $expected');
}

void _near(List<String> failures, String role, double actual, double expected) {
  if ((actual - expected).abs() > .1) {
    failures.add('$role: $actual instead of $expected');
  }
}

void _style(
  WidgetTester tester,
  List<String> failures,
  String role,
  Finder finder, {
  required double size,
  required FontWeight weight,
  required double tracking,
  required Color color,
  double? height,
  String family = 'Pretendard',
}) {
  if (finder.evaluate().length != 1) {
    failures.add('$role actual text role missing');
    return;
  }
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final style = (paragraph.text as TextSpan).style!;
  _same(failures, '$role font', style.fontFamily, family);
  _same(failures, '$role size', style.fontSize, size);
  _same(failures, '$role weight', style.fontWeight, weight);
  _same(failures, '$role tracking', style.letterSpacing, tracking);
  _same(failures, '$role color', style.color, color);
  _same(failures, '$role height', style.height, height);
  _near(
    failures,
    '$role actual text scale',
    paragraph.textScaler.scale(size),
    size,
  );
}

void _fullParagraph(
  WidgetTester tester,
  List<String> failures,
  String role,
  Finder finder,
) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  _same(failures, '$role maxLines', paragraph.maxLines, null);
  _same(
    failures,
    '$role ellipsis',
    paragraph.overflow == TextOverflow.ellipsis,
    false,
  );
  final natural = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: paragraph.constraints.maxWidth);
  _near(
    failures,
    '$role full natural height',
    paragraph.size.height,
    natural.height,
  );
  natural.dispose();
}

void _badge(
  WidgetTester tester,
  List<String> failures,
  CategoryItem category,
  Finder root,
) {
  final name = find.descendant(of: root, matching: find.text(category.name));
  _style(
    tester,
    failures,
    'badge ${category.id}',
    name,
    size: 12,
    weight: FontWeight.w500,
    tracking: -.3,
    color: category.deep,
  );
  if (name.evaluate().isEmpty) return;
  final boxes = find.ancestor(of: name, matching: find.byType(Container));
  if (boxes.evaluate().isEmpty) {
    failures.add('badge ${category.id} painted background missing');
    return;
  }
  final box = tester.widget<Container>(boxes.first);
  final decoration = box.decoration as BoxDecoration?;
  _same(
    failures,
    'badge ${category.id} actual tint',
    decoration?.color,
    category.tint,
  );
  final rect = tester.getRect(name);
  final viewport = tester.getRect(_mainList());
  if (rect.left < viewport.left - .1 || rect.right > viewport.right + .1) {
    failures.add('badge ${category.id} exceeds body width');
  }
}

Future<void> _checkScreen(
  WidgetTester tester,
  _Scene scene,
  List<String> failures,
) async {
  if (!_boldAvailable) {
    failures.add('actual Pretendard Bold font asset/alias missing');
  }
  final scaffoldElement = find.byType(Scaffold).evaluate().single;
  final scaffold = scaffoldElement.widget as Scaffold;
  _same(
    failures,
    'detail white background',
    scaffold.backgroundColor ??
        Theme.of(scaffoldElement).scaffoldBackgroundColor,
    Colors.white,
  );
  final header = find.byType(DetailTopBar);
  final headerRect = tester.getRect(header);
  _near(failures, 'detail top total height', headerRect.height, 64);
  final headerRow = find
      .descendant(of: header, matching: find.byType(Row))
      .first;
  _near(
    failures,
    'detail top inner height',
    tester.getRect(headerRow).height,
    56,
  );
  _near(
    failures,
    'detail top inner inset',
    tester.getRect(headerRow).top - headerRect.top,
    8,
  );

  final title = _textRole('detail-title', scene.current.title);
  _style(
    tester,
    failures,
    'title',
    title,
    size: 24,
    weight: FontWeight.w700,
    tracking: -.6,
    color: AppColors.text,
    height: 1.5,
    family: 'PretendardDetail',
  );
  _fullParagraph(tester, failures, 'title', title);
  final categories = _role(
    'detail-category-badges',
    find
        .ancestor(
          of: find.text(scene.current.category.name).first,
          matching: find.byType(Align),
        )
        .first,
  );
  final wrap = categories.evaluate().single.widget is Wrap
      ? categories
      : find.descendant(of: categories, matching: find.byType(Wrap));
  if (wrap.evaluate().length == 1) {
    final widget = tester.widget<Wrap>(wrap);
    _near(failures, 'category wrap spacing', widget.spacing, 8);
    _near(failures, 'category wrap runs', widget.runSpacing, 8);
  } else {
    failures.add('all current categories must use Wrap');
  }
  for (final category in scene.current.categories) {
    _badge(tester, failures, category, categories);
  }

  final date = _textRole('detail-saved-date', _date, legacy: '$_date 저장');
  await _show(tester, date);
  _same(
    failures,
    'date preserves actual savedAtFull without suffix',
    tester.widget<Text>(date).data,
    _date,
  );
  _style(
    tester,
    failures,
    'date',
    date,
    size: 14,
    weight: FontWeight.w400,
    tracking: -.35,
    color: AppColors.subSubtle,
  );
  await _show(tester, find.text('요약'));
  _style(
    tester,
    failures,
    'summary heading',
    find.text('요약'),
    size: 16,
    weight: FontWeight.w600,
    tracking: -.4,
    color: AppColors.text,
  );
  final summary = _textRole('detail-summary', scene.current.summary);
  await _show(tester, summary);
  _style(
    tester,
    failures,
    'summary',
    summary,
    size: 15,
    weight: FontWeight.w400,
    tracking: -.375,
    color: AppColors.text,
    height: 1.6,
  );
  _fullParagraph(tester, failures, 'summary', summary);

  await _show(tester, find.text('전문 보기'));
  _style(
    tester,
    failures,
    'original toggle heading',
    find.text('전문 보기'),
    size: 16,
    weight: FontWeight.w600,
    tracking: -.4,
    color: AppColors.text,
  );
  if (scene.expanded) {
    await tester.tap(find.text('전문 보기'));
    await tester.pumpAndSettle();
    final original = _textRole('detail-original-text', _original);
    await _show(tester, original);
    _style(
      tester,
      failures,
      'expanded original',
      original,
      size: 16,
      weight: FontWeight.w400,
      tracking: -.4,
      color: AppColors.text,
      height: 1.6,
    );
    _fullParagraph(tester, failures, 'expanded original', original);
  }
  await _show(tester, find.text('태그'));
  _style(
    tester,
    failures,
    'tag label',
    find.text('태그'),
    size: 16,
    weight: FontWeight.w500,
    tracking: -.4,
    color: AppColors.subtle,
    height: 1.6,
  );
  final tags = _role(
    'detail-tags',
    find.ancestor(of: find.text('태그'), matching: find.byType(Row)).first,
  );
  if (find
      .descendant(of: tags, matching: find.byType(TagChip))
      .evaluate()
      .isNotEmpty) {
    failures.add('tags must not use filled TagChip');
  }
  if (scene.current.tags.isNotEmpty) {
    final tagWrap = tags.evaluate().single.widget is Wrap
        ? tags
        : find.descendant(of: tags, matching: find.byType(Wrap)).first;
    _near(
      failures,
      'plain tags horizontal gap',
      tester.widget<Wrap>(tagWrap).spacing,
      16,
    );
  }
  for (final tag in scene.current.tags) {
    final finder = find.descendant(of: tags, matching: find.text('#$tag'));
    _style(
      tester,
      failures,
      'tag $tag',
      finder,
      size: 14,
      weight: FontWeight.w500,
      tracking: -.35,
      color: AppColors.subtle,
      height: 1.6,
    );
  }
  await _end(tester);
  final relatedHeading = _textRole(
    'detail-related-heading',
    _relatedHeading,
    legacy: '비슷한 태그를 가진 정보',
  );
  _same(
    failures,
    'related heading wording',
    tester.widget<Text>(relatedHeading).data,
    _relatedHeading,
  );
  _style(
    tester,
    failures,
    'related heading',
    relatedHeading,
    size: 16,
    weight: FontWeight.w600,
    tracking: -.4,
    color: AppColors.text,
  );
  final headingTap = find
      .ancestor(of: relatedHeading, matching: find.byType(InkWell))
      .first;
  _same(
    failures,
    'related heading keeps tap',
    tester.widget<InkWell>(headingTap).onTap != null,
    true,
  );
  final arrow = find.descendant(
    of: headingTap,
    matching: find.byWidgetPredicate(
      (w) => w is SvgIcon && w.asset == Assets.chevronRight,
    ),
  );
  _same(failures, 'related heading arrow absent', arrow.evaluate().length, 0);
  if (scene.related.isEmpty) {
    final empty = _textRole('detail-related-empty', _emptyRelated);
    if (empty.evaluate().isEmpty) {
      failures.add('loaded-list empty message missing');
    } else {
      _style(
        tester,
        failures,
        'related empty',
        empty,
        size: 15,
        weight: FontWeight.w600,
        tracking: -.375,
        color: AppColors.middle,
      );
      _same(
        failures,
        'related empty center text',
        tester.widget<Text>(empty).textAlign,
        TextAlign.center,
      );
      _near(
        failures,
        'related empty horizontal center',
        tester.getCenter(empty).dx,
        tester.getCenter(_mainList()).dx,
      );
    }
  } else {
    for (final related in scene.related) {
      await _checkCard(tester, failures, related);
    }
  }
  final footer = find.byType(DetailPager);
  final nav = find.byType(ClipbackNavigationBar);
  _near(
    failures,
    'pager/navigation state gap',
    tester.getTopLeft(nav).dy - tester.getBottomLeft(footer).dy,
    scene.expanded ? 8 : 16,
  );
  final actions = find.descendant(
    of: footer,
    matching: find.byType(RoundIconButton),
  );
  final icons = find.descendant(of: footer, matching: find.byType(SvgIcon));
  for (var i = 0; i < 2; i++) {
    _near(
      failures,
      'pager hit width $i',
      tester.getSize(actions.at(i)).width,
      56,
    );
    _near(
      failures,
      'pager hit height $i',
      tester.getSize(actions.at(i)).height,
      56,
    );
    _near(
      failures,
      'pager original icon $i',
      tester.getSize(icons.at(i)).width,
      i == 0 ? 28 : 32,
    );
    _same(
      failures,
      'pager asset $i',
      tester.widget<SvgIcon>(icons.at(i)).asset,
      i == 0
          ? 'assets/icons/detail-previous.svg'
          : 'assets/icons/detail-next.svg',
    );
  }
  final pager = find.descendant(
    of: find.byType(DetailPager),
    matching: find.byType(Text),
  );
  final currentIndex = scene.contents.indexWhere(
    (item) => item.id == scene.current.id,
  );
  _same(
    failures,
    'pager loaded-list meaning',
    tester.widget<Text>(pager).data,
    '${currentIndex + 1} / 불러온 ${scene.contents.length}개',
  );
  _style(
    tester,
    failures,
    'pager',
    pager,
    size: 16,
    weight: FontWeight.w500,
    tracking: -.4,
    color: AppColors.subtle,
  );
}

Future<void> _checkCard(
  WidgetTester tester,
  List<String> failures,
  ContentItem related,
) async {
  final title = find.text(related.title);
  await _show(tester, title);
  final tap = find.ancestor(of: title, matching: find.byType(InkWell)).first;
  final card = _role('detail-related-card-${related.id}', tap);
  final bounds = tester.getRect(card);
  if (bounds.height < 47.9) failures.add('related card minimum height48');
  final containers = <Element>[
    ...find.descendant(of: card, matching: find.byType(Container)).evaluate(),
    ...card.evaluate(),
  ];
  final painted = containers
      .where(
        (e) =>
            e.widget is Container &&
            ((e.widget as Container).decoration is BoxDecoration ||
                (e.widget as Container).foregroundDecoration is BoxDecoration),
      )
      .where((e) {
        final widget = e.widget as Container;
        final decoration = widget.foregroundDecoration ?? widget.decoration;
        return decoration is BoxDecoration && decoration.border != null;
      })
      .firstOrNull;
  if (painted == null) {
    failures.add('related card surface border missing');
  } else {
    final widget = painted.widget as Container;
    final background = widget.decoration as BoxDecoration?;
    final border =
        (widget.foregroundDecoration ?? widget.decoration) as BoxDecoration;
    _same(failures, 'related card white', background?.color, Colors.white);
    _same(
      failures,
      'related card border',
      border.border,
      Border.all(color: AppColors.faint),
    );
    _same(
      failures,
      'related card corner',
      border.borderRadius,
      BorderRadius.circular(8),
    );
    _same(
      failures,
      'related card padding',
      widget.padding,
      const EdgeInsets.all(8),
    );
  }
  _style(
    tester,
    failures,
    'related title',
    title,
    size: 14,
    weight: FontWeight.w500,
    tracking: -.35,
    color: Colors.black,
    height: 1.5,
  );
  final paragraph = tester.renderObject<RenderParagraph>(title);
  _same(failures, 'related title single line', paragraph.maxLines, 1);
  _same(
    failures,
    'related title ellipsis',
    paragraph.overflow,
    TextOverflow.ellipsis,
  );
  for (final category in related.categories) {
    _badge(tester, failures, category, card);
  }
  final first = find.descendant(
    of: card,
    matching: find.text(related.category.name),
  );
  if (first.evaluate().isEmpty) return;
  final firstBounds = tester.getRect(first);
  final titleBounds = tester.getRect(title);
  final badgeBox = tester.getRect(
    find.ancestor(of: first, matching: find.byType(Container)).first,
  );
  _near(
    failures,
    'related badge exact left inset',
    badgeBox.left - bounds.left,
    8,
  );
  if (related.categories.length == 1) {
    _near(
      failures,
      'single-category title gap',
      titleBounds.left - badgeBox.right,
      8,
    );
    _near(
      failures,
      'single-category title center',
      titleBounds.center.dy,
      badgeBox.center.dy,
    );
  } else {
    final wraps = find.ancestor(of: first, matching: find.byType(Wrap));
    if (wraps.evaluate().isEmpty) {
      failures.add('multiple related categories must use Wrap');
    } else {
      final group = tester.getRect(wraps.first);
      _near(
        failures,
        'multi-category title below gap',
        titleBounds.top - group.bottom,
        8,
      );
      _near(
        failures,
        'multi-category group top inset',
        group.top - bounds.top,
        8,
      );
      _near(
        failures,
        'multi-category title left inset',
        titleBounds.left - bounds.left,
        8,
      );
      _near(
        failures,
        'multi-category wrap spacing',
        tester.widget<Wrap>(wraps.first).spacing,
        8,
      );
    }
  }
  if (firstBounds.left < bounds.left || titleBounds.right > bounds.right + .1) {
    failures.add('related content exceeds card bounds');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    try {
      final bold = await rootBundle.load('assets/fonts/Pretendard-Bold.otf');
      final detail = FontLoader('PretendardDetail')
        ..addFont(Future.value(bold));
      await detail.load();
      _boldAvailable = true;
    } catch (_) {
      _boldAvailable = false;
    }
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final scene in _scenes()) {
        testWidgets('detail 1x ${scene.name} $platform width $width', (
          tester,
        ) async {
          await _pump(tester, scene, platform, width);
          final failures = <String>[];
          await _checkScreen(tester, scene, failures);
          expect(tester.takeException(), isNull);
          expect(failures, isEmpty, reason: failures.join('\n'));
        });
      }
      testWidgets(
        'detail callbacks and loaded-order membership $platform width $width',
        (tester) async {
          final scene = _scenes().singleWhere(
            (s) => s.name == 'multiple-categories',
          );
          final calls = await _pump(tester, scene, platform, width);
          await tester.tap(find.byType(BookmarkActionButton));
          await tester.pump();
          expect(calls.bookmark, 1);
          final pagerButtons = find.descendant(
            of: find.byType(DetailPager),
            matching: find.byType(RoundIconButton),
          );
          await tester.tap(pagerButtons.first);
          await tester.tap(pagerButtons.last);
          await tester.pump();
          expect(calls.adjacent, [-1, 1]);
          final positions = <double>[];
          for (final related in scene.related) {
            await _show(tester, find.text(related.title));
            positions.add(
              tester.getTopLeft(find.text(related.title)).dy +
                  _position(tester).pixels,
            );
            await tester.tap(find.text(related.title));
            await tester.pump();
          }
          expect(positions[0], lessThan(positions[1]));
          expect(calls.opened, orderedEquals(scene.related));
          expect(find.text('태그만 같아서 제외할 항목'), findsNothing);
          expect(find.text('두 번째 분류만 같아서 제외할 항목'), findsNothing);
          final back = _role(
            'detail-back',
            find.descendant(
              of: find.byType(DetailTopBar),
              matching: find.byWidgetPredicate(
                (w) => w is SvgIconButton && w.asset == Assets.back,
              ),
            ),
          );
          await tester.tap(back);
          await tester.pump();
          expect(calls.back, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
