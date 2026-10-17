// Fixed-data native/widget fixture. No production API, OAuth or physical device.
// flutter run --no-pub -t test/support/category_archive_preview.dart
//   --dart-define=CATEGORY_ARCHIVE_PHASE=before|after
// :8767 /ready /state /status /scene?kind=zero|positive&scroll=0|max|<px> /run
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/top_bars.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

const categoryArchivePhase = String.fromEnvironment(
  'CATEGORY_ARCHIVE_PHASE',
  defaultValue: 'before',
);
const categoryArchiveLongName = '소중한 자료와 함께 오래 보존할 아주 긴 카테고리 이름';
List<CategoryItem> categoryArchiveData(String kind) => [
  CategoryItem(
    id: 99,
    name: catUncategorized.name,
    color: catUncategorized.color,
    tint: catUncategorized.tint,
    deep: catUncategorized.deep,
    contentCount: kind == 'positive' ? 2 : 0,
  ),
  for (final id in [112, 104, 102, 108, 101, 106, 110, 103, 111, 105, 109, 107])
    CategoryItem(
      id: id,
      name: id == 101 ? categoryArchiveLongName : '기록 카테고리 $id',
      color: id.isEven ? AppColors.blueDeep : AppColors.main,
      tint: id.isEven ? AppColors.blueSubtle : AppColors.mainSubtle,
      deep: id.isEven ? AppColors.blueDeep : AppColors.mainDeep,
      contentCount: id == 111
          ? 37
          : id == 104
          ? 0
          : id - 90,
      rawLastSavedAt: id >= 111
          ? null
          : DateTime.utc(
              2026,
              10,
              id == 101 || id == 102 ? 17 : 118 - id,
              15,
              30,
            ),
      lastSavedAt: id >= 111
          ? null
          : '2026. 10. ${id == 101 || id == 102 ? '17' : (118 - id).toString().padLeft(2, '0')} 오후 03:30',
    ),
];
List<CategoryItem> categoryArchiveSorted(List<CategoryItem> values) =>
    values.where((c) => c.name != catUncategorized.name).toList()..sort((a, b) {
      final x = a.rawLastSavedAt, y = b.rawLastSavedAt;
      if (x != null && y != null) {
        final d = y.compareTo(x);
        if (d != 0) return d;
      } else if (x != y) {
        return x == null ? 1 : -1;
      }
      if (a.id == null) return b.id == null ? 0 : 1;
      if (b.id == null) return -1;
      return a.id!.compareTo(b.id!);
    });
ContentItem _content(CategoryItem category) => ContentItem(
  id: 'content-${category.id}',
  title: '보존해야 할 실제 대역 콘텐츠',
  summary: '고정 목록은 서버 카테고리 개수와 다릅니다.',
  category: category,
  savedAt: '10.17',
  savedAtFull: '2026.10.17',
  savedAtFullShort: '26.10.17',
  tags: const [],
  source: '웹사이트',
  originalUrl: 'https://example.invalid/archive',
  originalText: '고정 원문',
);

class CategoryArchivePreviewHost extends StatefulWidget {
  const CategoryArchivePreviewHost({
    super.key,
    this.phase = 'after',
    this.initialKind = 'positive',
    this.platform,
  });
  final String phase, initialKind;
  final TargetPlatform? platform;
  @override
  State<CategoryArchivePreviewHost> createState() =>
      CategoryArchivePreviewState();
}

class CategoryArchivePreviewState extends State<CategoryArchivePreviewHost> {
  final navigatorKey = GlobalKey<NavigatorState>();
  final pageStorage = PageStorageBucket();
  late List<CategoryItem> categories;
  late List<ContentItem> contents;
  String kind = 'positive', route = 'archive';
  String? activeCategory;
  int activeTab = 1;
  bool optionalManagementSupported = false;
  final calls = <Map<String, Object?>>[];
  @override
  void initState() {
    super.initState();
    _reset(widget.initialKind);
  }

  void _reset(String value) {
    kind = value;
    categories = categoryArchiveData(value);
    contents = [
      _content(categories.firstWhere((c) => c.id == 101)),
      if (value == 'positive') _content(categories.first),
    ];
    activeTab = 1;
    activeCategory = null;
    route = 'archive';
    calls.clear();
  }

  void reset(String value) => setState(() => _reset(value));
  void record(String action, [Map<String, Object?> data = const {}]) =>
      calls.add({'action': action, ...data});
  void add(CategoryItem value) {
    record('add', {'name': value.name});
    setState(
      () => categories = [
        ...categories,
        CategoryItem(
          id: value.id ?? 900,
          name: value.name,
          color: value.color,
          tint: value.tint,
          deep: value.deep,
          lastSavedAt: value.lastSavedAt,
          rawLastSavedAt: value.rawLastSavedAt,
          contentCount: value.contentCount,
          mutationLabel: value.mutationLabel,
        ),
      ],
    );
  }

  void update(CategoryItem original, CategoryItem value) {
    record('update', {'id': original.id});
    setState(
      () => categories = categories
          .map((c) => c.id == original.id ? value : c)
          .toList(),
    );
  }

  void delete(CategoryItem value) {
    record('delete', {'id': value.id});
    setState(
      () => categories = categories.where((c) => c.id != value.id).toList(),
    );
  }

  void manage() {
    record('manage');
    route = 'management';
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => CategoryManagementScreen(
          categories: categories,
          contents: contents,
          onBack: () {
            record('manageBack');
            route = 'archive';
            Navigator.pop(context);
          },
          onAddCategory: add,
          onUpdateCategory: update,
          onDeleteCategory: delete,
        ),
      ),
    );
  }

  void search() {
    record('search');
    route = 'search';
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => SearchScreen(
          initialQuery: '',
          contents: contents,
          bookmarkedIds: const {},
          categories: categories,
          onSearch: (q) async => contents,
          onQueryChanged: (_) {},
          onClose: () {
            record('searchBack');
            route = 'archive';
            Navigator.pop(context);
          },
          onOpenContent: (_) {},
          onToggleBookmark: (_) {},
          onChangeContentCategory: (_, _) {},
          onDeleteContent: (_) {},
          onOpenArchive: () {
            route = 'archive';
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _archive() {
    final arguments = <Symbol, dynamic>{
      #activeTab: activeTab,
      #contents: contents,
      #categories: categories,
      #bookmarkedIds: <String>{},
      #bookmarkedFirst: false,
      #randomViewing: false,
      #activeCategoryName: activeCategory,
      #onTabChanged: (int value) => setState(() {
        record('archiveTab', {'value': value});
        activeTab = value;
      }),
      #onSortChanged: (bool value) => record('sort', {'value': value}),
      #onOpenRandomView: () {
        record('random');
      },
      #onExitRandomView: () {},
      #onClearCategory: () => setState(() {
        record('categoryBack');
        activeCategory = null;
        activeTab = 1;
      }),
      #onSearch: search,
      #onOpenContent: (ContentItem item) => record('content', {'id': item.id}),
      #onToggleBookmark: (ContentItem item) {},
      #onChangeContentCategory: (ContentItem item, CategoryItem category) {},
      #onDeleteContent: (ContentItem item) {},
      #onAddCategory: add,
      #onUpdateCategory: update,
      #onDeleteCategory: delete,
      #onAddLink: ({required String url, CategoryItem? category}) async {
        record('saveLink');
        return _content(categories[1]);
      },
      #onAddScreenshot:
          ({
            required Uint8List bytes,
            required String filename,
            CategoryItem? category,
          }) async {
            record('savePhoto');
            return _content(categories[1]);
          },
      #onOpenCategory: (CategoryItem value) => setState(() {
        record('openCategory', {'id': value.id, 'count': value.contentCount});
        activeCategory = value.name;
        activeTab = 0;
      }),
      #onTab: (AppRoute value) {
        record('rootTab', {'route': value.name});
        route = value.name;
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    route = 'archive';
                    Navigator.pop(context);
                  },
                  child: const Text('아카이브로 복귀'),
                ),
              ),
            ),
          ),
        );
      },
    };
    if (widget.phase == 'after') {
      try {
        final result =
            Function.apply(ArchiveScreen.new, [], {
                  ...arguments,
                  #onOpenCategoryManagement: manage,
                })
                as Widget;
        optionalManagementSupported = true;
        return result;
      } on NoSuchMethodError {
        optionalManagementSupported = false;
      }
    }
    return Function.apply(ArchiveScreen.new, [], arguments) as Widget;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      platform: widget.platform,
      scaffoldBackgroundColor: AppColors.bg,
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(maxWidth: phoneWidth),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.main,
        surface: AppColors.bg,
      ),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: child!,
    ),
    home: PageStorage(bucket: pageStorage, child: _archive()),
  );
}

List<Element> _elements(Element root) {
  final out = <Element>[];
  void visit(Element e) {
    if (e.widget case Offstage(offstage: true)) return;
    out.add(e);
    e.visitChildren(visit);
  }

  visit(root);
  return out;
}

Element? _find<T extends Widget>(Element root) =>
    _elements(root).where((e) => e.widget is T).firstOrNull;
Element? _key(Element root, String value) => _elements(root)
    .where(
      (e) =>
          e.widget.key == ValueKey<String>(value) ||
          e.widget.key == PageStorageKey<String>(value),
    )
    .firstOrNull;
Element? _text(Element root, String value) => _elements(root)
    .where((e) => e.widget is Text && (e.widget as Text).data == value)
    .firstOrNull;
Element? _ancestor(Element e, bool Function(Widget) test) {
  Element? out;
  e.visitAncestorElements((a) {
    if (test(a.widget)) {
      out = a;
      return false;
    }
    return true;
  });
  return out;
}

Rect _rect(Element e) {
  final b = e.findRenderObject()! as RenderBox;
  return b.localToGlobal(Offset.zero) & b.size;
}

Map<String, double> _bounds(Rect r) => {
  'left': r.left,
  'top': r.top,
  'right': r.right,
  'bottom': r.bottom,
  'width': r.width,
  'height': r.height,
};
String? _color(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
bool _near(Object? n, double target) => n is num && (n - target).abs() < .15;
Map<String, Object?> _paragraph(Element e) {
  final r = e.findRenderObject()! as RenderParagraph;
  final s = (r.text as TextSpan).style!;
  return {
    'text': r.text.toPlainText(),
    'bounds': _bounds(_rect(e)),
    'fontFamily': s.fontFamily,
    'fontSize': s.fontSize,
    'scaledFontSize': s.fontSize == null
        ? null
        : r.textScaler.scale(s.fontSize!),
    'fontWeight': s.fontWeight?.value,
    'color': _color(s.color),
    'letterSpacing': s.letterSpacing,
    'height': s.height,
    'declaredHeight': (e.widget as Text).style?.height,
    'maxLines': r.maxLines,
    'overflow': r.overflow.name,
    'didExceedMaxLines': r.didExceedMaxLines,
    'constraintsMaxWidth': r.constraints.maxWidth.isFinite
        ? r.constraints.maxWidth
        : 'unbounded',
    'selectionBoxScope':
        'Paragraph layout, not font-selection overhang or glyph ink.',
  };
}

Map<String, Object?> _asset(Element e) {
  final w = e.widget;
  final svg = w is SvgPicture ? w : _find<SvgPicture>(e)?.widget as SvgPicture?;
  final loader = svg?.bytesLoader;
  return {
    'bounds': _bounds(_rect(e)),
    'asset': w is SvgIcon
        ? w.asset
        : loader is SvgAssetLoader
        ? loader.assetName
        : null,
    'colorFilter': svg?.colorFilter.toString(),
    'unfiltered': svg?.colorFilter == null,
    'isSvg': svg != null,
    'legacyFolder': w is FolderGlyph,
  };
}

Element? categoryArchiveList(Element root) =>
    _key(root, 'archive-category-list') ??
    (_find<CategoryArchiveView>(root) == null
        ? null
        : _find<ListView>(_find<CategoryArchiveView>(root)!));
ScrollPosition categoryArchivePosition(Element root) {
  final list = categoryArchiveList(root)!;
  return ((_find<Scrollable>(list)! as StatefulElement).state
          as ScrollableState)
      .position;
}

Map<String, Object?> categoryArchiveMeasurements(
  Element root,
  CategoryArchivePreviewState host,
) {
  final archive = _find<ArchiveScreen>(root);
  if (archive == null ||
      host.route != 'archive' ||
      host.activeTab != 1 ||
      host.activeCategory != null) {
    return {};
  }
  final view = _find<CategoryArchiveView>(archive)!;
  final header =
      _key(archive, 'archive-category-header') ?? _find<AppTopBar>(archive)!;
  final tabs =
      _key(archive, 'archive-category-tabs') ?? _find<ArchiveTabs>(archive)!;
  final toolbar =
      _key(view, 'archive-category-toolbar') ??
      _find<CategoryArchiveToolbar>(view)!;
  final list = categoryArchiveList(archive)!;
  final banner =
      _key(view, 'archive-unclassified-banner') ??
      _find<UnclassifiedCategoryRow>(view);
  final bannerMaterial = banner == null ? null : _find<Material>(banner);
  final bannerBox = bannerMaterial ?? banner;
  final sort = _key(view, 'archive-category-sort') ?? _text(toolbar, '최신순')!;
  final roles = <String, Map<String, Object?>>{
    'header': _paragraph(_text(header, '아카이브')!),
    'sort': _paragraph(sort),
  };
  final tabMetrics = <String, Object?>{};
  for (final label in ['카테고리', '전체보기']) {
    final text = _text(tabs, label)!;
    roles['tab:$label'] = _paragraph(text);
    final material = _ancestor(text, (w) => w is Material)!;
    tabMetrics[label] = {
      'bounds': _bounds(_rect(material)),
      'color': _color((material.widget as Material).color),
    };
  }
  final rows = <Map<String, Object?>>[];
  final viewport = _rect(list);
  final tabInner = _elements(
    tabs,
  ).where((e) => e.widget is DecoratedBox).firstOrNull;
  for (final element in _elements(view).where((e) => e.widget is CategoryRow)) {
    final c = (element.widget as CategoryRow).category;
    final name =
        _key(element, 'archive-category-name-${c.id}') ??
        _text(element, c.name)!;
    final date =
        _key(element, 'archive-category-date-${c.id}') ??
        _text(element, c.mutationLabel ?? c.lastSavedAt ?? '저장된 콘텐츠 없음')!;
    final folder =
        _key(element, 'archive-category-folder-${c.id}') ??
        _find<FolderGlyph>(element)!;
    final more =
        _key(element, 'archive-category-more-${c.id}') ??
        _elements(element)
            .where(
              (e) =>
                  e.widget is GestureDetector &&
                  _near(_rect(e).width, 44) &&
                  _near(_rect(e).height, 44),
            )
            .last;
    final circle = _elements(more)
        .where(
          (e) =>
              e.widget is Container &&
              (e.widget as Container).decoration is BoxDecoration,
        )
        .firstOrNull;
    final icon = _find<SvgIcon>(more) ?? _find<SvgPicture>(more);
    final count = _text(element, '${c.contentCount}');
    rows.add({
      'id': c.id,
      'name': c.name,
      'serverCount': c.contentCount,
      'rawTimestamp': c.rawLastSavedAt?.toIso8601String(),
      'displayDate': c.lastSavedAt,
      'mutationLabel': c.mutationLabel,
      'bounds': _bounds(_rect(element)),
      'nameStyle': _paragraph(name),
      'dateStyle': _paragraph(date),
      'folder': {
        ..._asset(folder),
        'matchesCategoryColor':
            (_find<SvgPicture>(folder)?.widget as SvgPicture?)?.colorFilter ==
            ColorFilter.mode(c.color, BlendMode.srcIn),
        'categoryColor': _color(c.color),
      },
      'moreHit': _bounds(_rect(more)),
      'moreCircle': circle == null ? null : _bounds(_rect(circle)),
      'moreAsset': icon == null ? null : _asset(icon),
      'countVisuallyPresent': count != null,
      'folderToText': _rect(name).left - _rect(folder).right,
      'textGap': _rect(date).top - _rect(name).bottom,
      'nameWidth': _rect(name).width,
      'rowLeftPadding': _rect(folder).left - _rect(element).left,
      'rowRightPadding': _rect(element).right - _rect(more).right,
      'textCenterOffset':
          ((_rect(name).top + _rect(date).bottom) / 2) -
          _rect(element).center.dy,
      'fullyInsideViewport':
          _rect(element).top >= viewport.top - .1 &&
          _rect(element).bottom <= viewport.bottom + .1,
      'horizontallyInsideViewport':
          _rect(element).left >= viewport.left - .1 &&
          _rect(element).right <= viewport.right + .1,
    });
  }
  final unclassified = host.categories
      .where((c) => c.name == catUncategorized.name)
      .firstOrNull;
  final assets = _elements(
    archive,
  ).where((e) => e.widget is SvgPicture).map(_asset).toList();
  final add =
      _key(view, 'archive-category-add') ?? _find<SvgIconButton>(toolbar);
  final settings = _key(archive, 'archive-manage-categories');
  final search =
      _key(archive, 'archive-category-search') ?? _find<SvgIconButton>(header);
  if (banner != null) {
    roles['bannerTitle'] = _paragraph(_text(banner, '분류가 필요한 콘텐츠')!);
    roles['bannerCount'] = _paragraph(
      _text(banner, '${unclassified?.contentCount ?? 0}')!,
    );
  }
  Map<String, Object?>? icon(Element? e) {
    if (e == null) return null;
    final svg = e.widget is SvgPicture ? e : _find<SvgPicture>(e);
    return svg == null ? null : _asset(svg);
  }

  final bannerSvgs = banner == null
      ? <Element>[]
      : _elements(banner).where((e) => e.widget is SvgPicture).toList();
  final bannerLeading = bannerSvgs.firstOrNull;
  final bannerChevron = bannerSvgs.lastOrNull;
  final listWidget = list.widget as ListView;
  return {
    'actualStyles': roles,
    'rows': rows,
    'assetGeometry': assets,
    'bounds': {
      'header': _bounds(_rect(header)),
      'tabs': _bounds(_rect(tabs)),
      'toolbar': _bounds(_rect(toolbar)),
      'list': _bounds(_rect(list)),
      'banner': bannerBox == null ? null : _bounds(_rect(bannerBox)),
      'bannerOuter': banner == null ? null : _bounds(_rect(banner)),
      'add': add == null ? null : _bounds(_rect(add)),
      'settings': settings == null ? null : _bounds(_rect(settings)),
      'search': search == null ? null : _bounds(_rect(search)),
    },
    'tabs': tabMetrics,
    'tabInnerBounds': tabInner == null ? null : _bounds(_rect(tabInner)),
    'roleAssets': {
      'settings': icon(settings),
      'search': icon(search),
      'add': icon(add),
      'unclassified': icon(bannerLeading),
      'chevron': icon(bannerChevron),
    },
    'listClipBehavior': listWidget.clipBehavior.name,
    'scrollOffset': categoryArchivePosition(root).pixels,
    'headerTitleBounds': roles['header']!['bounds'],
    'bannerPresent': banner != null,
    'bannerColor': banner == null
        ? null
        : _color((_find<Material>(banner)?.widget as Material?)?.color),
    'bannerHorizontalInset': banner == null
        ? null
        : _rect(bannerBox!).left - _rect(header).left,
    'actualUnclassifiedId': unclassified?.id,
    'actualUnclassifiedCount': unclassified?.contentCount,
    'bannerMetadataKnown': unclassified != null,
    'expectedSortedIds': categoryArchiveSorted(
      host.categories,
    ).map((c) => c.id).toList(),
    'loadedContentIds': host.contents.map((c) => c.id).toList(),
    'managementCallbackSupported': host.optionalManagementSupported,
    'visibleRows': rows.map((r) => r['id']).toList(),
  };
}

Map<String, Object?> categoryArchiveJudgment(Map<String, Object?> m) {
  if (m.isEmpty) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'styleFindings': <String>[],
      'layoutFindings': <String>[],
    };
  }
  final styles = <String>[], layout = <String>[];
  void style(String role, Map actual, List expected) {
    if (actual['fontFamily'] != 'Pretendard' ||
        actual['fontSize'] != expected[0] ||
        actual['fontWeight'] != expected[1] ||
        actual['letterSpacing'] != expected[2] ||
        actual['color'] != expected[3] ||
        actual['declaredHeight'] != null ||
        actual['height'] != null ||
        actual['scaledFontSize'] != actual['fontSize']) {
      styles.add('$role effective font/weight/tracking/color/AUTO differs');
    }
  }

  final roles = m['actualStyles'] as Map;
  style('header', roles['header'] as Map, [18, 600, -.45, '0xFF000000']);
  style('sort', roles['sort'] as Map, [14, 500, -.35, '0xFF767676']);
  style('category tab', roles['tab:카테고리'] as Map, [16, 600, -.4, '0xFF1A1A1A']);
  style('all tab', roles['tab:전체보기'] as Map, [16, 600, -.4, '0xFF767676']);
  final b = m['bounds'] as Map,
      header = b['header'] as Map,
      tabs = b['tabs'] as Map,
      toolbar = b['toolbar'] as Map,
      list = b['list'] as Map;
  if (!_near(header['height'], 64) ||
      !_near(tabs['height'], 64) ||
      !_near(toolbar['height'], 52) ||
      !_near((tabs['top'] as num) - (header['bottom'] as num), 0) ||
      !_near((toolbar['top'] as num) - (tabs['bottom'] as num), 0)) {
    layout.add('Header64/tab64/toolbar52 and consecutive placement differ');
  }
  if (m['managementCallbackSupported'] != true || b['settings'] == null) {
    layout.add(
      'Settings must reach category management through optional callback',
    );
  }
  final title = m['headerTitleBounds'] as Map;
  if (!_near((title['left'] as num) - (header['left'] as num), 16)) {
    layout.add('Header horizontal inset16 differs');
  }
  if (m['tabInnerBounds'] case final Map inner) {
    if (!_near(inner['height'], 52)) {
      layout.add('Tab inner52 differs');
    }
  } else {
    layout.add('Missing tab inner bounds');
  }
  final tabMetrics = m['tabs'] as Map;
  for (final value in tabMetrics.values) {
    if (!_near((value['bounds'] as Map)['height'], 46)) {
      layout.add('Tab active/unselected area46 differs');
    }
  }
  final count = m['actualUnclassifiedCount'] as int?;
  if (m['bannerPresent'] !=
      (m['bannerMetadataKnown'] == true && (count ?? 0) > 0)) {
    layout.add('Unclassified banner requires an actual positive metadata item');
  }
  if (b['banner'] case final Map banner) {
    style('banner title', roles['bannerTitle'] as Map, [
      16,
      500,
      -.4,
      '0xFFFFD75C',
    ]);
    style('banner count', roles['bannerCount'] as Map, [
      14,
      400,
      -.35,
      '0xFF1A1A1A',
    ]);
    if (m['bannerColor'] != '0xFF1A1A1A' ||
        !_near(m['bannerHorizontalInset'], 16) ||
        !_near(banner['height'], 48) ||
        !_near((list['top'] as num) - (banner['bottom'] as num), 16) ||
        !_near((banner['top'] as num) - (toolbar['bottom'] as num), 0)) {
      layout.add('Banner48/after-gap16 differs');
    }
  } else if (!_near((list['top'] as num) - (toolbar['bottom'] as num), 0)) {
    layout.add('Zero state first row starts immediately after toolbar');
  }
  if (m['listClipBehavior'] == 'none') {
    layout.add('List must clip cached/offscreen rows to its viewport');
  }
  final assets = m['roleAssets'] as Map;
  const specs = {
    'settings': ['assets/icons/archive-settings.svg', 24.0, 24.0],
    'search': ['assets/icons/archive-search.svg', 24.0, 24.0],
    'add': ['assets/icons/archive-folder-plus.svg', 24.0, 24.0],
    'unclassified': ['assets/icons/archive-unclassified.svg', 20.0, 20.0],
    'chevron': ['assets/icons/archive-chevron-right.svg', 24.0, 24.0],
  };
  for (final entry in specs.entries) {
    if (b['banner'] == null &&
        (entry.key == 'unclassified' || entry.key == 'chevron')) {
      continue;
    }
    final actual = assets[entry.key];
    if (actual is! Map) {
      styles.add('Missing ${entry.key} exact asset');
      continue;
    }
    if (actual['asset'] != entry.value[0] || actual['unfiltered'] != true) {
      styles.add('${entry.key} exact unfiltered SVG differs');
    }
    final r = actual['bounds'] as Map;
    if (!_near(r['width'], entry.value[1] as double) ||
        !_near(r['height'], entry.value[2] as double)) {
      layout.add('${entry.key} SVG slot differs');
    }
  }
  if (assets['settings'] case final Map settings) {
    if (assets['search'] case final Map search) {
      final a = settings['bounds'] as Map, c = search['bounds'] as Map;
      if (!_near((a['left'] as num) - (c['right'] as num), 16) ||
          !_near((header['right'] as num) - (a['right'] as num), 16)) {
        layout.add('Header icon gap/right inset16 differs');
      }
    }
  }
  final rows = m['rows'] as List;
  final sortedIds = m['expectedSortedIds'] as List;
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index] as Map;
    style('name ${row['id']}', row['nameStyle'] as Map, [
      15,
      500,
      -.375,
      '0xFF1A1A1A',
    ]);
    style('date ${row['id']}', row['dateStyle'] as Map, [
      12,
      400,
      -.3,
      '0xFFB5BDC3',
    ]);
    if (row['countVisuallyPresent'] == true) {
      layout.add('Archive row hides count but retains server metadata');
    }
    final r = row['bounds'] as Map,
        folder = row['folder'] as Map,
        folderRect = folder['bounds'] as Map,
        more = row['moreHit'] as Map;
    if (!_near(r['height'], 44) ||
        !_near(folderRect['width'], 40) ||
        !_near(folderRect['height'], 34) ||
        !_near(row['folderToText'], 12) ||
        !_near(row['textGap'], 2) ||
        !_near(row['rowLeftPadding'], 16) ||
        !_near(row['rowRightPadding'], 6) ||
        !_near(row['textCenterOffset'], 0) ||
        row['horizontallyInsideViewport'] != true ||
        (row['nameWidth'] as num) > 156.1) {
      layout.add(
        'Row ${row['id']} height/folder/text/center/viewport geometry differs',
      );
    }
    if (folder['asset'] != 'assets/icons/archive-category-folder.svg' ||
        folder['isSvg'] != true ||
        folder['matchesCategoryColor'] != true) {
      styles.add('Folder ${row['id']} exact SVG/category color differs');
    }
    if (!_near(more['width'], 44) || !_near(more['height'], 44)) {
      layout.add('More hit area44 differs');
    }
    if (row['moreCircle'] case final Map circle) {
      if (!_near(circle['width'], 24) || !_near(circle['height'], 24)) {
        layout.add('More circle24 differs');
      }
    } else {
      layout.add('Missing more circle');
    }
    if (row['moreAsset'] case final Map asset) {
      final a = asset['bounds'] as Map, circle = row['moreCircle'] as Map?;
      if (asset['asset'] != 'assets/icons/archive-category-more.svg' ||
          asset['unfiltered'] != true) {
        styles.add('More exact unfiltered SVG differs');
      }
      if (!_near(a['width'], 19.2) ||
          !_near(a['height'], 18.4) ||
          circle == null ||
          !_near((a['left'] as num) - (circle['left'] as num), 2.4) ||
          !_near((a['top'] as num) - (circle['top'] as num), 2.4)) {
        layout.add('More SVG19.2x18.4 slot offset differs');
      }
    } else {
      styles.add('Missing more exact SVG');
    }
    for (final key in ['nameStyle', 'dateStyle']) {
      final p = row[key] as Map, bounds = p['bounds'] as Map;
      if (p['maxLines'] != 1 ||
          p['overflow'] != 'ellipsis' ||
          (bounds['right'] as num) > (more['left'] as num) + .1) {
        layout.add('$key line/ellipsis/remaining-width differs');
      }
    }
    if (index > 0) {
      final previous = rows[index - 1] as Map;
      if (!_near(
            (r['top'] as num) - ((previous['bounds'] as Map)['bottom'] as num),
            16,
          ) ||
          sortedIds.indexOf(row['id']) !=
              sortedIds.indexOf(previous['id']) + 1) {
        layout.add('Visible sorted row sequence/gap16 differs');
      }
    }
  }
  return {
    'stylePassed': styles.isEmpty,
    'layoutPassed': layout.isEmpty,
    'styleFindings': styles,
    'layoutFindings': layout,
  };
}

final _host = GlobalKey<CategoryArchivePreviewState>();
final _capture = GlobalKey();
final _errors = <Map<String, Object?>>[], _records = <Map<String, Object?>>[];
late Directory _output;
bool _busy = false, _complete = false, _coverage = false;
int _pointer = 12000;
Element get _root => _capture.currentContext! as Element;
Future<void> _settle([int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

void _require(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> _tap(Element e) async {
  final p = _rect(e).center,
      id = ++_pointer,
      v = View.of(_capture.currentContext!);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: v.viewId, position: p),
  );
  await Future<void>.delayed(const Duration(milliseconds: 80));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: v.viewId,
      position: p,
      timeStamp: const Duration(milliseconds: 80),
    ),
  );
  await _settle();
}

Future<void> _dragList() async {
  final list = categoryArchiveList(_root)!,
      rect = _rect(list),
      view = View.of(_capture.currentContext!),
      id = ++_pointer;
  final before = categoryArchivePosition(_root).pixels;
  final start = Offset(rect.center.dx, rect.bottom - 70);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: view.viewId, position: start),
  );
  for (var i = 1; i <= 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final position = start - Offset(0, 20.0 * i);
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: id,
        viewId: view.viewId,
        position: position,
        delta: const Offset(0, -20),
        timeStamp: Duration(milliseconds: 30 * i),
      ),
    );
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: view.viewId,
      position: start - const Offset(0, 160),
      timeStamp: const Duration(milliseconds: 260),
    ),
  );
  await _settle(12);
  final after = categoryArchivePosition(_root).pixels;
  _require(
    after > before + 1 &&
        _host.currentState!.activeTab == 1 &&
        _host.currentState!.activeCategory == null,
    'Actual list drag did not scroll',
  );
  _record('list_pointer_drag', {
    'scrollBefore': before,
    'scrollAfter': after,
    'pointerMoveCount': 8,
    'actualPointerDrag': true,
  });
}

Future<void> _tapText(String value) async {
  final e = _text(_root, value);
  _require(e != null, 'Missing action: $value');
  await Scrollable.ensureVisible(
    e!,
    duration: const Duration(milliseconds: 150),
  );
  await _settle();
  await _tap(e);
}

Future<void> _open(String kind) async {
  _require(kind == 'zero' || kind == 'positive', 'Unknown kind');
  _host.currentState!.navigatorKey.currentState!.popUntil((r) => r.isFirst);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  _host.currentState!.reset(kind);
  await _settle();
  categoryArchivePosition(_root).jumpTo(0);
  await _settle();
}

Future<void> _scroll(String value) async {
  for (var i = 0; i < 8; i++) {
    final p = categoryArchivePosition(_root);
    final target = value == 'max' ? p.maxScrollExtent : double.parse(value);
    _require(
      target >= 0 && target <= p.maxScrollExtent + .1,
      'Invalid concrete scroll',
    );
    p.jumpTo(target.clamp(0, p.maxScrollExtent));
    await _settle(2);
    if (value != 'max' || (p.pixels - p.maxScrollExtent).abs() < .1) return;
  }
}

Map<String, Object?> _snapshot() {
  final h = _host.currentState!,
      v = View.of(_capture.currentContext!),
      media = MediaQuery.of(_find<Scaffold>(_root)!),
      m = categoryArchiveMeasurements(_root, h),
      judgment = categoryArchiveJudgment(m);
  final list = categoryArchiveList(_root);
  return {
    'phase': categoryArchivePhase,
    'platform': Platform.operatingSystem,
    'ready': true,
    'busy': _busy,
    'output': _output.path,
    'kind': h.kind,
    'route': h.route,
    'activeTab': h.activeTab,
    'activeCategoryName': h.activeCategory,
    'textScale': media.textScaler.scale(1),
    'logicalSize': '${v.physicalSize / v.devicePixelRatio}',
    'pixelRatio': v.devicePixelRatio,
    'viewPaddingTop': media.viewPadding.top,
    'viewPaddingBottom': media.viewPadding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'scrollOffset': list == null ? null : categoryArchivePosition(_root).pixels,
    'maxScrollExtent': list == null
        ? null
        : categoryArchivePosition(_root).maxScrollExtent,
    ...m,
    ...judgment,
    'calls': List.of(h.calls),
    'categoryMetadata': [
      for (final c in h.categories)
        {
          'id': c.id,
          'name': c.name,
          'count': c.contentCount,
          'rawLastSavedAt': c.rawLastSavedAt?.toIso8601String(),
          'lastSavedAt': c.lastSavedAt,
        },
    ],
    'contentIds': h.contents.map((c) => c.id).toList(),
    'frameworkErrors': _errors,
    'scope':
        'Actual widgets with in-memory category/feed metadata and synthetic pointer/text input; not backend/OAuth/physical-device proof.',
  };
}

void _record(String scenario, [Map<String, Object?> details = const {}]) =>
    _records.add({
      'scenario': scenario,
      'passed': true,
      ..._snapshot(),
      ...details,
    });
String _name() =>
    'category_archive_${_host.currentState!.kind}_scale_1${categoryArchivePosition(_root).pixels.abs() < .01 ? '' : '_scroll_${categoryArchivePosition(_root).pixels.toStringAsFixed(3).replaceAll('.', '_')}'}';
Future<void> _captureScene() async {
  await _settle();
  final name = _name(),
      boundary =
          _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary,
      image = await boundary.toImage(
        pixelRatio: View.of(_capture.currentContext!).devicePixelRatio,
      );
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${_output.path}/$name.png').writeAsBytes(
      png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _records.add({'capture': name, ..._snapshot()});
}

Future<void> _report() => File('${_output.path}/report.json').writeAsString(
  const JsonEncoder.withIndent('  ').convert({
    ..._snapshot(),
    'checksCompleted': _complete,
    'coveragePassed': _coverage,
    'behaviorPassed': _complete && !_records.any((r) => r['passed'] == false),
    'stylePassed': !_records.any((r) => r['stylePassed'] == false),
    'layoutPassed':
        _errors.isEmpty && !_records.any((r) => r['layoutPassed'] == false),
    'passed':
        _complete &&
        _coverage &&
        _errors.isEmpty &&
        !_records.any(
          (r) =>
              r['passed'] == false ||
              r['stylePassed'] == false ||
              r['layoutPassed'] == false,
        ),
    'checks': _records,
  }),
);

Future<void> _run() async {
  _complete = false;
  _coverage = false;
  final coverageByKind = <String, Object?>{};
  for (final kind in ['zero', 'positive']) {
    final seen = <int>{};
    await _open(kind);
    await _captureScene();
    final ids = categoryArchiveSorted(
      _host.currentState!.categories,
    ).map((c) => c.id!).toList();
    for (var i = 0; i < 20; i++) {
      final m = categoryArchiveMeasurements(_root, _host.currentState!);
      seen.addAll(
        (m['rows'] as List)
            .where((r) => r['fullyInsideViewport'] == true)
            .map((r) => r['id'] as int),
      );
      _record('${kind}_scroll_coverage_$i');
      final p = categoryArchivePosition(_root);
      if ((p.pixels - p.maxScrollExtent).abs() < .1) {
        break;
      }
      p.jumpTo((p.pixels + 250).clamp(0, p.maxScrollExtent));
      await _settle();
    }
    await _scroll('max');
    final metrics = categoryArchiveMeasurements(_root, _host.currentState!);
    final rows = metrics['rows'] as List;
    final last = rows.where((r) => r['id'] == ids.last).firstOrNull;
    final lastVisible = last != null && last['fullyInsideViewport'] == true;
    final bannerExpected = kind == 'positive';
    final bannerMatches = metrics['bannerPresent'] == bannerExpected;
    _require(
      lastVisible && bannerMatches,
      '$kind maximum last row/banner coverage missing',
    );
    _record('${kind}_maximum_scroll', {
      'lastRowId': ids.last,
      'lastRowFullyInsideViewport': lastVisible,
      'bannerMatchesMetadata': bannerMatches,
    });
    final complete = seen.containsAll(ids);
    coverageByKind[kind] = {
      'passed': complete,
      'seenIds': seen.toList()..sort(),
      'expectedIds': ids,
      'lastRowFullyInsideViewport': lastVisible,
      'bannerMatchesMetadata': bannerMatches,
    };
  }
  _coverage = coverageByKind.values.every((v) => (v as Map)['passed'] == true);
  _records.add({
    'scenario': 'required_row_coverage',
    'passed': _coverage,
    'byKind': coverageByKind,
  });
  _require(_coverage, 'Missing per-scene mounted row coverage');
  await _open('positive');
  await _dragList();
  await _scroll(
    categoryArchivePosition(_root).maxScrollExtent.clamp(0, 180).toString(),
  );
  final saved = categoryArchivePosition(_root).pixels;
  final settings = _key(_root, 'archive-manage-categories');
  _require(settings != null, 'Management entry missing');
  await _tap(settings!);
  _require(
    _find<CategoryManagementScreen>(_root) != null,
    'Management screen missing',
  );
  final back = _find<SvgIconButton>(_find<CategoryManagementScreen>(_root)!)!;
  await _tap(back);
  _require(
    _host.currentState!.activeTab == 1 &&
        _near(categoryArchivePosition(_root).pixels, saved),
    'Management return lost tab/scroll',
  );
  _record('management_return_preserves_scroll', {
    'savedScroll': saved,
    'returnedScroll': categoryArchivePosition(_root).pixels,
    'returnedActiveTab': _host.currentState!.activeTab,
  });
  await _scroll('0');
  final search =
      _key(_root, 'archive-category-search') ??
      _find<SvgIconButton>(_find<AppTopBar>(_root)!);
  await _tap(search!);
  _require(_find<SearchScreen>(_root) != null, 'Search route missing');
  await _tapText('취소');
  _require(_find<SearchScreen>(_root) == null, 'Search close failed');
  _record('search_roundtrip');
  await _tapText('전체보기');
  _require(_host.currentState!.activeTab == 0, 'All tab did not change');
  await _tapText('카테고리');
  _require(_host.currentState!.activeTab == 1, 'Category tab did not restore');
  _record('archive_tabs_roundtrip');
  for (final id in [99, 101]) {
    await _scroll('0');
    final row = id == 99
        ? (_key(_root, 'archive-unclassified-banner') ??
              _find<UnclassifiedCategoryRow>(_root))
        : _key(_root, 'archive-category-row-$id');
    _require(row != null, 'Open category row missing');
    await _tap(row!);
    _require(
      _host.currentState!.activeTab == 0 &&
          _host.currentState!.calls.any(
            (c) => c['action'] == 'openCategory' && c['id'] == id,
          ),
      'Category callback lost actual ID',
    );
    final back = _find<SvgIconButton>(_find<CategoryTopBar>(_root)!)!;
    await _tap(back);
    _record('open_category_$id');
  }
  final h = _host.currentState!,
      beforeIds = h.contents.map((c) => c.id).toList(),
      beforeNames = h.categories.map((c) => c.name).toList();
  final add = _key(_root, 'archive-category-add')!;
  await _tap(add);
  _require(_find<CategoryCreateSheet>(_root) != null, 'Create sheet missing');
  await _typeAndCheckKeyboard('입력만 하고 닫을 이름');
  _record('create_keyboard_input', {
    'inputFocused': true,
    'inputText': '입력만 하고 닫을 이름',
    'keyboardInsetPositive': true,
  });
  await _tapBarrier();
  _require(
    _find<CategoryCreateSheet>(_root) == null &&
        !h.calls.any((c) => c['action'] == 'add'),
    'Dismissed create mutated data',
  );
  _require(
    (_snapshot()['viewInsetsBottom'] as num) == 0,
    'Keyboard remained after create dismiss',
  );
  _record('create_dismissed_without_save', {'keyboardInsetZero': true});
  for (final action in ['카테고리 수정', '카테고리 삭제']) {
    await _scroll('0');
    await _tap(_key(_root, 'archive-category-more-101')!);
    _require(
      (_find<CategoryActionSheet>(_root)!.widget as CategoryActionSheet)
              .contentCount ==
          h.categories.firstWhere((c) => c.id == 101).contentCount,
      'Action sheet lost server count',
    );
    await _tapText(action);
    if (action == '카테고리 삭제') {
      _require(
        _find<CategoryDeleteDialog>(_root) != null,
        'Delete confirmation missing',
      );
      await _tapText('취소');
    } else {
      _require(_find<CategoryEditSheet>(_root) != null, 'Edit sheet missing');
      await _tapBarrier();
    }
    _record('${action}_cancel');
  }
  _require(
    jsonEncode(beforeIds) == jsonEncode(h.contents.map((c) => c.id).toList()) &&
        jsonEncode(beforeNames) ==
            jsonEncode(h.categories.map((c) => c.name).toList()) &&
        !h.calls.any((c) => c['action'] == 'delete' || c['action'] == 'update'),
    'Cancelled actions changed content/category metadata',
  );
  // Exercise real forms and callbacks with one temporary local category, then
  // restore the frozen metadata. This is not a server persistence check.
  await _tap(_key(_root, 'archive-category-add')!);
  await _typeAndCheckKeyboard('로컬 생성 검사');
  await _hideKeyboard();
  await _tapText('생성하기');
  _require(
    h.categories.any((c) => c.id == 900 && c.name == '로컬 생성 검사') &&
        h.calls.where((c) => c['action'] == 'add').length == 1,
    'Local create callback/data missing',
  );
  await _scroll('max');
  _record('local_create_submitted', {
    'localCategoryId': 900,
    'callbackCounts': {
      for (final action in ['add', 'update', 'delete'])
        action: h.calls.where((c) => c['action'] == action).length,
    },
    'persistenceScope': 'in-memory callback only',
  });
  await _tap(_key(_root, 'archive-category-more-900')!);
  await _tapText('카테고리 수정');
  await _typeAndCheckKeyboard('로컬 수정 검사');
  await _hideKeyboard();
  await _tapText('수정하기');
  _require(
    h.categories.any((c) => c.id == 900 && c.name == '로컬 수정 검사') &&
        h.calls.where((c) => c['action'] == 'update').length == 1,
    'Local edit callback/data missing',
  );
  await _scroll('max');
  _record('local_edit_submitted', {
    'localCategoryId': 900,
    'callbackCounts': {
      for (final action in ['add', 'update', 'delete'])
        action: h.calls.where((c) => c['action'] == action).length,
    },
    'persistenceScope': 'in-memory callback only',
  });
  await _tap(_key(_root, 'archive-category-more-900')!);
  await _tapText('카테고리 삭제');
  await _tapText('삭제');
  _require(
    !h.categories.any((c) => c.id == 900) &&
        h.calls.where((c) => c['action'] == 'delete').length == 1 &&
        jsonEncode(beforeIds) ==
            jsonEncode(h.contents.map((c) => c.id).toList()) &&
        jsonEncode(beforeNames) ==
            jsonEncode(h.categories.map((c) => c.name).toList()),
    'Local delete failed to restore fixed categories/content',
  );
  await _scroll('0');
  _record('local_delete_submitted_and_restored', {
    'localCategoryId': 900,
    'callbackCounts': {
      for (final action in ['add', 'update', 'delete'])
        action: h.calls.where((c) => c['action'] == action).length,
    },
    'persistenceScope': 'in-memory callback only',
  });
  await _tap(_find<NavAddButton>(_root)!);
  _require(_find<AddContentSheet>(_root) != null, 'Save entry missing');
  await _tap(_find<IconButton>(_find<SaveContentTopBar>(_root)!)!);
  _require(
    _find<AddContentSheet>(_root) == null &&
        !h.calls.any(
          (c) => c['action'] == 'saveLink' || c['action'] == 'savePhoto',
        ),
    'Save close submitted data',
  );
  _record('save_entry_closed');
  for (final label in ['홈', '아카이브', '즐겨찾기', '마이']) {
    await _tap(_text(_find<ClipbackNavigationBar>(_root)!, label)!);
    final expected = {
      '홈': 'home',
      '아카이브': 'archive',
      '즐겨찾기': 'bookmark',
      '마이': 'my',
    }[label];
    _require(
      h.calls.last['action'] == 'rootTab' && h.calls.last['route'] == expected,
      'Root tab callback route missing',
    );
    final routeAfter = h.route;
    await _tapText('아카이브로 복귀');
    _require(h.route == 'archive', 'Root return route failed');
    _record('root_tab_$label', {
      'destination': expected,
      'routeAfterTap': routeAfter,
      'returnedRoute': h.route,
    });
  }
  _complete = true;
}

Future<void> _hideKeyboard() async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  for (var i = 0; i < 30; i++) {
    await _settle(2);
    if ((_snapshot()['viewInsetsBottom'] as num) == 0) {
      return;
    }
  }
  _require(false, 'Keyboard failed to hide');
}

Future<void> _typeAndCheckKeyboard(String value) async {
  final input = _find<EditableText>(_root)!;
  await _tap(input);
  final editable = input.widget as EditableText;
  editable.controller.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
  editable.onChanged?.call(value);
  for (var i = 0; i < 30; i++) {
    await _settle(2);
    if ((_snapshot()['viewInsetsBottom'] as num) > 0) {
      break;
    }
  }
  _require(
    editable.focusNode.hasFocus &&
        editable.controller.text == value &&
        (_snapshot()['viewInsetsBottom'] as num) > 0,
    'Actual keyboard/focus/input missing',
  );
}

Future<void> _tapBarrier() async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _settle(8);
  final view = View.of(_capture.currentContext!);
  final point = Offset(
    view.physicalSize.width / view.devicePixelRatio / 2,
    MediaQuery.of(_find<Scaffold>(_root)!).viewPadding.top + 8,
  );
  final id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: view.viewId, position: point),
  );
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await _settle();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _output = await Directory.systemTemp.createTemp('clipback-category-archive-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add({'error': d.exceptionAsString()});
    old?.call(d);
  };
  runApp(
    RepaintBoundary(
      key: _capture,
      child: CategoryArchivePreviewHost(
        key: _host,
        phase: categoryArchivePhase,
      ),
    ),
  );
  await _settle();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'CATEGORY_ARCHIVE ready phase=$categoryArchivePhase output=${_output.path}',
  );
  await for (final r in server) {
    final read = const ['/ready', '/state', '/status'].contains(r.uri.path);
    if (_busy && !read) {
      r.response.statusCode = 409;
      await r.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (r.uri.path) {
        case '/ready':
        case '/state':
        case '/status':
          break;
        case '/scene':
          await _open(r.uri.queryParameters['kind'] ?? 'positive');
          await _scroll(r.uri.queryParameters['scroll'] ?? '0');
          await _captureScene();
        case '/run':
          await _run();
        default:
          r.response.statusCode = 404;
      }
      await _report();
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode(_snapshot()));
    } catch (e, s) {
      _records.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$e',
      });
      debugPrint('CATEGORY_ARCHIVE FAIL $e\n$s');
      await _report();
      r.response.statusCode = 500;
      r.response.write(jsonEncode({'error': '$e', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await r.response.close();
    }
  }
}
