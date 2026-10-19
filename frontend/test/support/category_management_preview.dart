// Fixed 1x actual management widget fixture with local metadata and callbacks.
// flutter run --no-pub -t test/support/category_management_preview.dart
// --dart-define=CATEGORY_MANAGEMENT_PHASE=before|after
// :8767 /ready /state /status /scene?scroll=0|max|<px> /run
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'category_archive_preview.dart' show categoryArchiveData;

const managementPhase = String.fromEnvironment(
  'CATEGORY_MANAGEMENT_PHASE',
  defaultValue: 'before',
);
List<CategoryItem> managementData([int count = 12]) {
  final data = categoryArchiveData('positive');
  return [data.first, ...data.skip(1).take(count)];
}

ContentItem _content(CategoryItem category) => ContentItem(
  id: 'management-content-${category.id}',
  title: '보존할 로컬 대역 콘텐츠',
  summary: '서버 집계와 별개인 현재 조회 목록입니다.',
  category: category,
  savedAt: '10.17',
  savedAtFull: '2026. 10. 17',
  savedAtFullShort: '26.10.17',
  tags: const [],
  source: '웹',
  originalUrl: 'https://example.invalid/category-management',
  originalText: '고정 원문',
);

class CategoryManagementPreviewHost extends StatefulWidget {
  const CategoryManagementPreviewHost({
    super.key,
    this.platform,
    this.initialCount = 12,
    this.initialCategories,
  });
  final TargetPlatform? platform;
  final int initialCount;
  final List<CategoryItem>? initialCategories;
  @override
  State<CategoryManagementPreviewHost> createState() =>
      CategoryManagementPreviewState();
}

class CategoryManagementPreviewState
    extends State<CategoryManagementPreviewHost> {
  final navigatorKey = GlobalKey<NavigatorState>();
  final bucket = PageStorageBucket();
  late List<CategoryItem> categories;
  late List<ContentItem> contents;
  String route = 'management';
  final calls = <Map<String, Object?>>[];
  @override
  void initState() {
    super.initState();
    categories =
        widget.initialCategories ?? managementData(widget.initialCount);
    contents = [
      _content(categoryArchiveData('positive').first),
      _content(categoryArchiveData('positive').firstWhere((c) => c.id == 101)),
    ];
  }

  void reset() => setState(() {
    categories = managementData();
    route = 'management';
    calls.clear();
  });
  void replace(List<CategoryItem> values) =>
      setState(() => categories = values);
  void record(String action, Map<String, Object?> data) =>
      calls.add({'action': action, ...data});
  void add(CategoryItem value) {
    final category = CategoryItem(
      id: value.id ?? 900,
      name: value.name,
      color: value.color,
      tint: value.tint,
      deep: value.deep,
      contentCount: value.contentCount,
      lastSavedAt: value.lastSavedAt,
      rawLastSavedAt: value.rawLastSavedAt,
    );
    record('add', {
      'id': category.id,
      'name': category.name,
      'color': _color(category.color),
    });
    setState(() => categories = [...categories, category]);
  }

  void update(CategoryItem before, CategoryItem after) {
    record('update', {
      'id': before.id,
      'name': after.name,
      'color': _color(after.color),
      'count': after.contentCount,
      'rawTimestamp': after.rawLastSavedAt?.toIso8601String(),
    });
    setState(
      () => categories = categories
          .map((c) => c.id == before.id ? after : c)
          .toList(),
    );
  }

  void delete(CategoryItem value) {
    record('delete', {
      'id': value.id,
      'name': value.name,
      'count': value.contentCount,
    });
    setState(
      () => categories = categories.where((c) => c.id != value.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    scrollBehavior: const AppScrollBehavior(),
    theme: ThemeData(
      useMaterial3: true,
      platform: widget.platform,
      scaffoldBackgroundColor: AppColors.bg,
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(maxWidth: phoneWidth),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.main,
        surface: AppColors.bg,
      ),
      fontFamily: 'Pretendard',
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: child!,
    ),
    home: PageStorage(
      bucket: bucket,
      child: route == 'management'
          ? CategoryManagementScreen(
              categories: categories,
              contents: contents,
              onBack: () => setState(() {
                record('back', {});
                route = 'returned';
              }),
              onAddCategory: add,
              onUpdateCategory: update,
              onDeleteCategory: delete,
            )
          : Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('management-reopen'),
                  onPressed: () => setState(() => route = 'management'),
                  child: const Text('관리 화면으로 복귀'),
                ),
              ),
            ),
    ),
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

Element? managementList(Element root) =>
    _key(root, 'category-management-list') ??
    _key(root, 'management-list') ??
    (_find<CategoryManagementScreen>(root) == null
        ? null
        : _find<ListView>(_find<CategoryManagementScreen>(root)!));
ScrollPosition managementPosition(Element root) =>
    ((_find<Scrollable>(managementList(root)!)! as StatefulElement).state
            as ScrollableState)
        .position;
Element? _back(Element root) =>
    _key(root, 'management-back') ??
    _elements(root)
        .where(
          (e) =>
              e.widget is SvgIconButton &&
              [
                'assets/icons/back.svg',
                'assets/icons/detail-back.svg',
              ].contains((e.widget as SvgIconButton).asset),
        )
        .firstOrNull;
Element? _add(Element root) =>
    _key(root, 'management-add') ??
    _elements(root)
        .where(
          (e) =>
              e.widget is SvgIconButton &&
              (e.widget as SvgIconButton).asset ==
                  'assets/icons/folder-plus.svg',
        )
        .firstOrNull;
Element? _svg(Element? root) => root == null
    ? null
    : root.widget is SvgPicture
    ? root
    : _find<SvgPicture>(root);
Map<String, Object?> managementMeasurements(
  Element root,
  CategoryManagementPreviewState host,
) {
  final screen = _find<CategoryManagementScreen>(root);
  if (screen == null || host.route != 'management') {
    return {};
  }
  final header =
      _key(screen, 'management-header') ??
      _elements(screen)
          .where(
            (e) => e.widget is SizedBox && (e.widget as SizedBox).height == 64,
          )
          .first;
  final count =
      _key(screen, 'management-count') ??
      _elements(screen)
          .where(
            (e) =>
                e.widget is Text &&
                ((e.widget as Text).data ?? '').startsWith('총 '),
          )
          .first;
  final toolbar =
      _key(screen, 'management-toolbar') ??
      _ancestor(count, (w) => w is Padding)!;
  final list = managementList(screen)!,
      back = _back(screen)!,
      add = _add(screen)!;
  final title = _text(header, '카테고리 관리')!,
      backSvg = _svg(back)!,
      addSvg = _svg(add)!;
  final scaffold = _find<Scaffold>(screen)!,
      media = MediaQuery.of(screen),
      viewport = _rect(list);
  final rows = <Map<String, Object?>>[];
  for (final element in _elements(
    screen,
  ).where((e) => e.widget is CategoryRow)) {
    final category = (element.widget as CategoryRow).category,
        id = category.id ?? category.name;
    final name =
        _key(element, 'archive-category-name-$id') ??
        _text(element, category.name)!;
    final date =
        _key(element, 'archive-category-date-$id') ??
        _text(
          element,
          category.mutationLabel ?? category.lastSavedAt ?? '저장된 콘텐츠 없음',
        )!;
    final folder =
        _key(element, 'archive-category-folder-$id') ??
        _find<FolderGlyph>(element)!;
    final more =
        _key(element, 'archive-category-more-$id') ??
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
    final folderSvg = _svg(folder),
        moreSvg = _svg(more),
        rowRect = _rect(element),
        nameRect = _rect(name),
        dateRect = _rect(date);
    rows.add({
      'id': category.id,
      'name': category.name,
      'serverCount': category.contentCount,
      'displayDate': category.lastSavedAt,
      'rawTimestamp': category.rawLastSavedAt?.toIso8601String(),
      'mutationLabel': category.mutationLabel,
      'bounds': _bounds(rowRect),
      'nameStyle': _paragraph(name),
      'dateStyle': _paragraph(date),
      'folder': {
        ..._asset(folder),
        'categoryColor': _color(category.color),
        'matchesCategoryColor':
            folderSvg != null &&
            (folderSvg.widget as SvgPicture).colorFilter ==
                ColorFilter.mode(category.color, BlendMode.srcIn),
      },
      'moreHit': _bounds(_rect(more)),
      'moreCircle': circle == null ? null : _bounds(_rect(circle)),
      'moreAsset': moreSvg == null ? null : _asset(moreSvg),
      'countVisuallyPresent':
          _text(element, '${category.contentCount}') != null,
      'onRowTapIsNull': (element.widget as CategoryRow).onTap == null,
      'moreLocked': !_elements(more).any(
        (e) =>
            e.widget is GestureDetector &&
            (e.widget as GestureDetector).onTap != null,
      ),
      'folderToText': nameRect.left - _rect(folder).right,
      'textGap': dateRect.top - nameRect.bottom,
      'rowLeftPadding': _rect(folder).left - rowRect.left,
      'rowRightPadding': rowRect.right - _rect(more).right,
      'textCenterOffset':
          (nameRect.top + dateRect.bottom) / 2 - rowRect.center.dy,
      'fullyInsideViewport':
          rowRect.top >= viewport.top - .1 &&
          rowRect.bottom <= viewport.bottom + .1,
      'horizontallyInsideViewport':
          rowRect.left >= viewport.left - .1 &&
          rowRect.right <= viewport.right + .1,
    });
  }
  final visible = host.categories
      .where((c) => c.name != catUncategorized.name)
      .toList();
  return {
    'actualStyles': {'title': _paragraph(title), 'count': _paragraph(count)},
    'bounds': {
      'header': _bounds(_rect(header)),
      'title': _bounds(_rect(title)),
      'toolbar': _bounds(_rect(toolbar)),
      'count': _bounds(_rect(count)),
      'backHit': _bounds(_rect(back)),
      'addHit': _bounds(_rect(add)),
      'list': _bounds(viewport),
      'scaffold': _bounds(_rect(scaffold)),
    },
    'assetGeometry': {'back': _asset(backSvg), 'add': _asset(addSvg)},
    'rows': rows,
    'visibleRowIds': rows.map((r) => r['id']).toList(),
    'expectedInputOrderIds': visible.map((c) => c.id).toList(),
    'expectedVisibleCategoryCount': visible.length,
    'actualCountText': (count.widget as Text).data,
    'scrollOffset': managementPosition(root).pixels,
    'maxScrollExtent': managementPosition(root).maxScrollExtent,
    'viewPaddingTop': media.viewPadding.top,
    'viewPaddingBottom': media.viewPadding.bottom,
    'paddingBottom': media.padding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'bottomSafeGap': _rect(scaffold).bottom - viewport.bottom,
    'expectedBottomSafeGap': media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom,
    'listClipBehavior': (list.widget as ListView).clipBehavior.name,
    'safeAreaCount': _elements(
      screen,
    ).where((e) => e.widget is SafeArea).length,
    'safeAreaBottomFlags': _elements(screen)
        .where((e) => e.widget is SafeArea)
        .map((e) => (e.widget as SafeArea).bottom)
        .toList(),
  };
}

Map<String, Object?> managementJudgment(Map<String, Object?> metrics) {
  final styles = <String>[], layout = <String>[];
  if (metrics.isEmpty) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'styleFindings': styles,
      'layoutFindings': layout,
    };
  }
  void style(String role, Map p, List expected) {
    if (p['fontFamily'] != 'Pretendard' ||
        p['fontSize'] != expected[0] ||
        p['fontWeight'] != expected[1] ||
        p['letterSpacing'] != expected[2] ||
        p['color'] != expected[3] ||
        p['height'] != null ||
        p['declaredHeight'] != null ||
        p['scaledFontSize'] != p['fontSize']) {
      styles.add('$role actual font/weight/tracking/color/AUTO differs');
    }
  }

  final roles = metrics['actualStyles'] as Map,
      b = metrics['bounds'] as Map,
      assets = metrics['assetGeometry'] as Map;
  style('title', roles['title'] as Map, [18, 600, -.45, '0xFF000000']);
  style('count', roles['count'] as Map, [14, 500, -.35, '0xFF767676']);
  final h = b['header'] as Map,
      t = b['toolbar'] as Map,
      count = b['count'] as Map,
      title = b['title'] as Map,
      list = b['list'] as Map,
      backHit = b['backHit'] as Map;
  if (!_near(h['height'], 64) ||
      !_near(t['height'], 52) ||
      !_near((t['top'] as num) - (h['bottom'] as num), 0) ||
      !_near((list['top'] as num) - (t['bottom'] as num), 0)) {
    layout.add('Header64/toolbar52/list consecutive placement differs');
  }
  if (!_near((count['left'] as num) - (h['left'] as num), 16) ||
      !_near((title['left'] as num) - (h['left'] as num), 48) ||
      !_near(backHit['width'], 48) ||
      !_near(backHit['height'], 48)) {
    layout.add('Title48/count16/back hit48 differs');
  }
  for (final role in ['back', 'add']) {
    final a = assets[role] as Map, r = a['bounds'] as Map;
    final expected = role == 'back'
        ? 'assets/icons/detail-back.svg'
        : 'assets/icons/archive-folder-plus.svg';
    if (a['asset'] != expected || a['unfiltered'] != true) {
      styles.add('$role exact unfiltered SVG differs');
    }
    if (!_near(r['width'], 24) || !_near(r['height'], 24)) {
      layout.add('$role visible SVG24 differs');
    }
  }
  final backRect = (assets['back'] as Map)['bounds'] as Map,
      addRect = (assets['add'] as Map)['bounds'] as Map;
  if (!_near((backRect['left'] as num) - (h['left'] as num), 16) ||
      !_near((title['left'] as num) - (backRect['right'] as num), 8) ||
      !_near(
        ((backRect['top'] as num) + (backRect['bottom'] as num)) / 2,
        ((h['top'] as num) + (h['bottom'] as num)) / 2,
      ) ||
      !_near((h['right'] as num) - (addRect['right'] as num), 16) ||
      !_near(
        ((addRect['top'] as num) + (addRect['bottom'] as num)) / 2,
        ((t['top'] as num) + (t['bottom'] as num)) / 2,
      )) {
    layout.add(
      'Header icon/title gap8 or toolbar add24/right16 alignment differs',
    );
  }
  if (!_near(
        ((title['top'] as num) + (title['bottom'] as num)) / 2,
        ((h['top'] as num) + (h['bottom'] as num)) / 2,
      ) ||
      !_near(
        ((count['top'] as num) + (count['bottom'] as num)) / 2,
        ((t['top'] as num) + (t['bottom'] as num)) / 2,
      )) {
    layout.add(
      'Header title / toolbar count paragraph vertical center differs',
    );
  }
  final addHit = b['addHit'] as Map;
  if (!_near((backHit['left'] as num) - (h['left'] as num), 4) ||
      !_near((backHit['top'] as num) - (h['top'] as num), 8) ||
      !_near(addHit['width'], 48) ||
      !_near(addHit['height'], 48) ||
      !_near((t['right'] as num) - (addHit['right'] as num), 4) ||
      !_near((addHit['top'] as num) - (t['top'] as num), 2)) {
    layout.add('Back/add preserved 48px hit geometry differs');
  }
  if (metrics['actualCountText'] !=
      '총 ${metrics['expectedVisibleCategoryCount']}개') {
    layout.add(
      'Total must count ordinary metadata items, not loaded content or server count',
    );
  }
  if (metrics['safeAreaCount'] != 1 ||
      !(metrics['safeAreaBottomFlags'] as List).every((v) => v == true) ||
      !_near(
        metrics['bottomSafeGap'],
        (metrics['expectedBottomSafeGap'] as num).toDouble(),
      )) {
    layout.add('Exactly one actual bottom safe area differs');
  }
  if (metrics['listClipBehavior'] == 'none') {
    layout.add('List must clip cached rows to viewport');
  }
  final expected = metrics['expectedInputOrderIds'] as List,
      rows = metrics['rows'] as List;
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i] as Map,
        box = r['bounds'] as Map,
        folder = r['folder'] as Map,
        fr = folder['bounds'] as Map,
        more = r['moreHit'] as Map;
    style('name ${r['id']}', r['nameStyle'] as Map, [
      15,
      500,
      -.375,
      '0xFF1A1A1A',
    ]);
    style('date ${r['id']}', r['dateStyle'] as Map, [
      12,
      400,
      -.3,
      '0xFFB5BDC3',
    ]);
    if (r['countVisuallyPresent'] != false ||
        r['onRowTapIsNull'] != true ||
        r['moreLocked'] != (r['mutationLabel'] != null)) {
      layout.add('Row ${r['id']} count visibility/tap/mutation policy differs');
    }
    if (!_near(box['height'], 44) ||
        !_near(fr['width'], 40) ||
        !_near(fr['height'], 34) ||
        !_near(r['folderToText'], 12) ||
        !_near(r['textGap'], 2) ||
        !_near(r['rowLeftPadding'], 16) ||
        !_near(r['rowRightPadding'], 6) ||
        !_near(r['textCenterOffset'], 0) ||
        r['horizontallyInsideViewport'] != true ||
        !_near(more['width'], 44) ||
        !_near(more['height'], 44)) {
      layout.add('Row ${r['id']} visible geometry differs');
    }
    if (folder['asset'] != 'assets/icons/archive-category-folder.svg' ||
        folder['matchesCategoryColor'] != true) {
      styles.add('Row ${r['id']} exact folder/data color differs');
    }
    final circle = r['moreCircle'] as Map?, a = r['moreAsset'] as Map?;
    if (circle == null ||
        !_near(circle['width'], 24) ||
        !_near(circle['height'], 24) ||
        a == null) {
      layout.add('Row more circle24/SVG missing');
    } else {
      final ab = a['bounds'] as Map;
      if (a['asset'] != 'assets/icons/archive-category-more.svg' ||
          a['unfiltered'] != true) {
        styles.add('More exact unfiltered SVG differs');
      }
      if (!_near(ab['width'], 19.2) ||
          !_near(ab['height'], 18.4) ||
          !_near((ab['left'] as num) - (circle['left'] as num), 2.4) ||
          !_near((ab['top'] as num) - (circle['top'] as num), 2.4)) {
        layout.add('More19.2x18.4 slot offset differs');
      }
    }
    for (final role in ['nameStyle', 'dateStyle']) {
      final p = r[role] as Map, rect = p['bounds'] as Map;
      if ((rect['top'] as num) < (box['top'] as num) - .1 ||
          (rect['bottom'] as num) > (box['bottom'] as num) + .1 ||
          (rect['left'] as num) < (fr['right'] as num) + 11.9) {
        layout.add('$role paragraph exceeds actual row bounds');
      }
      if (p['maxLines'] != 1 ||
          p['overflow'] != 'ellipsis' ||
          (rect['right'] as num) > (more['left'] as num) + .1 ||
          (p['constraintsMaxWidth'] as num) > 156.1) {
        layout.add('$role max156/ellipsis/remaining width differs');
      }
    }
    if (i > 0) {
      final prev = rows[i - 1] as Map;
      if (!_near(
            (box['top'] as num) - ((prev['bounds'] as Map)['bottom'] as num),
            16,
          ) ||
          expected.indexOf(r['id']) != expected.indexOf(prev['id']) + 1) {
        layout.add('Input order or row gap16 differs');
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

final _host = GlobalKey<CategoryManagementPreviewState>();
final _capture = GlobalKey();
final _errors = <Map<String, Object?>>[], _records = <Map<String, Object?>>[];
late Directory _output;
bool _busy = false, _complete = false, _coverage = false;
int _pointer = 15000;
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
  final list = managementList(_root)!,
      rect = _rect(list),
      view = View.of(_capture.currentContext!),
      id = ++_pointer;
  final before = managementPosition(_root).pixels;
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
  final after = managementPosition(_root).pixels;
  _require(
    after > before + 1 && _host.currentState!.route == 'management',
    'Actual list drag did not scroll',
  );
  _record('list_pointer_drag', {
    'scrollBefore': before,
    'scrollAfter': after,
    'pointerMoveCount': 8,
    'actualPointerDrag': true,
  });
}

Future<void> _open() async {
  _host.currentState!.navigatorKey.currentState!.popUntil((r) => r.isFirst);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  _host.currentState!.reset();
  await _settle();
  managementPosition(_root).jumpTo(0);
  await _settle();
}

Future<void> _scroll(String value) async {
  for (var i = 0; i < 8; i++) {
    final p = managementPosition(_root),
        target = value == 'max' ? p.maxScrollExtent : double.parse(value);
    _require(
      target >= 0 && target <= p.maxScrollExtent + .1,
      'Invalid concrete scroll',
    );
    p.jumpTo(target.clamp(0, p.maxScrollExtent));
    await _settle(2);
    if (value != 'max' || (p.pixels - p.maxScrollExtent).abs() < .1) {
      return;
    }
  }
}

Map<String, Object?> managementMetadata(CategoryItem c) => {
  'id': c.id,
  'name': c.name,
  'color': _color(c.color),
  'tint': _color(c.tint),
  'deep': _color(c.deep),
  'count': c.contentCount,
  'lastSavedAt': c.lastSavedAt,
  'rawTimestamp': c.rawLastSavedAt?.toIso8601String(),
  'mutationLabel': c.mutationLabel,
};
Map<String, Object?> _snapshot() {
  final h = _host.currentState!,
      v = View.of(_capture.currentContext!),
      media = MediaQuery.of(_find<Scaffold>(_root)!),
      m = managementMeasurements(_root, h),
      judgment = managementJudgment(m);
  return {
    'phase': managementPhase,
    'platform': Platform.operatingSystem,
    'ready': true,
    'busy': _busy,
    'output': _output.path,
    'kind': 'management',
    'route': h.route,
    'origin': 'archive-local-host',
    'textScale': media.textScaler.scale(1),
    'logicalSize': '${v.physicalSize / v.devicePixelRatio}',
    'pixelRatio': v.devicePixelRatio,
    'viewPaddingTop': media.viewPadding.top,
    'viewPaddingBottom': media.viewPadding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'scrollOffset': managementList(_root) == null
        ? null
        : managementPosition(_root).pixels,
    'maxScrollExtent': managementList(_root) == null
        ? null
        : managementPosition(_root).maxScrollExtent,
    ...m,
    ...judgment,
    'categoryMetadata': h.categories.map(managementMetadata).toList(),
    'contentIds': h.contents.map((c) => c.id).toList(),
    'calls': List.of(h.calls),
    'frameworkErrors': _errors,
    'scope':
        'Actual management widget, synthetic pointer/TextField input and reactive local callbacks. Origin/back placeholder is a local host; actual ClipbackApp route-origin regression is tested separately. No HTTP persistence/OAuth/physical device/CI proof.',
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
    'category_management_scale_1${managementPosition(_root).pixels.abs() < .01 ? '' : '_scroll_${managementPosition(_root).pixels.toStringAsFixed(3).replaceAll('.', '_')}'}';
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

Future<void> _report() async {
  final snapshot = _snapshot();
  await File('${_output.path}/report.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      ...snapshot,
      'checksCompleted': _complete,
      'coveragePassed': _coverage,
      'behaviorPassed': _complete && !_records.any((r) => r['passed'] == false),
      'stylePassed':
          snapshot['stylePassed'] == true &&
          !_records.any((r) => r['stylePassed'] == false),
      'layoutPassed':
          snapshot['layoutPassed'] == true &&
          _errors.isEmpty &&
          !_records.any((r) => r['layoutPassed'] == false),
      'passed':
          _complete &&
          _coverage &&
          snapshot['stylePassed'] == true &&
          snapshot['layoutPassed'] == true &&
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
}

Future<void> _more(int id) async {
  await _scroll(id == 900 ? 'max' : '0');
  final row =
      _key(_root, 'management-category-row-$id') ??
      _key(_root, 'management-row-$id') ??
      _elements(_root)
          .where(
            (e) =>
                e.widget is CategoryRow &&
                (e.widget as CategoryRow).category.id == id,
          )
          .first;
  final more =
      _key(row, 'archive-category-more-$id') ??
      _elements(row)
          .where(
            (e) =>
                e.widget is GestureDetector &&
                _near(_rect(e).width, 44) &&
                _near(_rect(e).height, 44),
          )
          .last;
  await _tap(more);
  final sheet = _find<CategoryActionSheet>(_root);
  _require(sheet != null, 'Action sheet missing');
  _require(
    (sheet!.widget as CategoryActionSheet).contentCount ==
        _host.currentState!.categories
            .firstWhere((c) => c.id == id)
            .contentCount,
    'Action sheet lost actual server count',
  );
}

Future<void> _formText(String value) async {
  await _typeAndCheckKeyboard(value);
}

Future<void> _run() async {
  _complete = false;
  _coverage = false;
  await _open();
  await _captureScene();
  final h = _host.currentState!,
      expected = h.categories
          .where((c) => c.name != catUncategorized.name)
          .map((c) => c.id!)
          .toList(),
      seen = <int>{};
  for (var step = 0; step < 20; step++) {
    final metrics = managementMeasurements(_root, h);
    seen.addAll(
      (metrics['rows'] as List)
          .where((r) => r['fullyInsideViewport'] == true)
          .map((r) => r['id'] as int),
    );
    _record('scroll_coverage_$step');
    final p = managementPosition(_root);
    if ((p.pixels - p.maxScrollExtent).abs() < .1) {
      break;
    }
    p.jumpTo((p.pixels + 220).clamp(0, p.maxScrollExtent));
    await _settle();
  }
  await _scroll('max');
  final metrics = managementMeasurements(_root, h),
      last = (metrics['rows'] as List)
          .where((r) => r['id'] == expected.last)
          .firstOrNull;
  _coverage =
      seen.length == expected.length &&
      seen.containsAll(expected) &&
      last != null &&
      last['fullyInsideViewport'] == true;
  _require(_coverage, 'Full input-order category coverage/last row failed');
  _record('maximum_scroll', {
    'seenIds': seen.toList(),
    'expectedInputOrderIds': expected,
    'lastRowId': expected.last,
    'lastRowFullyInsideViewport': true,
    'bottomSafeGap': metrics['bottomSafeGap'],
  });
  _records.add({
    'scenario': 'required_row_coverage',
    'passed': _coverage,
    'seenIds': seen.toList(),
    'expectedIds': expected,
  });
  await _scroll('0');
  await _dragList();
  await _scroll('0');
  final callCount = h.calls.length;
  final firstRow = _elements(_root)
      .where(
        (e) =>
            e.widget is CategoryRow &&
            (e.widget as CategoryRow).category.id == expected.first,
      )
      .first;
  await _tap(
    _text(
      firstRow,
      h.categories.firstWhere((c) => c.id == expected.first).name,
    )!,
  );
  _require(
    h.calls.length == callCount && h.route == 'management',
    'Management row tap must have no open action',
  );
  _record('row_tap_noop');
  final before = jsonEncode(h.categories.map(managementMetadata).toList()),
      beforeIds = jsonEncode(h.contents.map((c) => c.id).toList());
  await _tap(_add(_root)!);
  _require(_find<CategoryCreateSheet>(_root) != null, 'Create sheet missing');
  await _formText('보존할 입력');
  _record('create_keyboard_input', {
    'inputText': '보존할 입력',
    'inputFocused': true,
    'keyboardInsetPositive': true,
  });
  final controller =
      (_find<EditableText>(_root)!.widget as EditableText).controller;
  await _hideKeyboard();
  _require(controller.text == '보존할 입력', 'Keyboard hide lost input');
  _record('keyboard_hidden_preserves_input', {
    'controllerText': controller.text,
    'keyboardInsetZero': true,
  });
  await _tapBarrier();
  _require(
    _find<CategoryCreateSheet>(_root) == null &&
        h.calls.where((c) => c['action'] == 'add').isEmpty,
    'Create cancel mutated data',
  );
  _record('create_cancel_preserves_data');
  final mainId = expected.first;
  for (final action in ['카테고리 수정', '카테고리 삭제']) {
    await _more(mainId);
    _record(action == '카테고리 수정' ? 'edit_server_count' : 'delete_server_count', {
      'actionSheetServerCount': h.categories
          .firstWhere((c) => c.id == mainId)
          .contentCount,
    });
    await _tap(_text(_find<CategoryActionSheet>(_root)!, action)!);
    if (action == '카테고리 수정') {
      _require(_find<CategoryEditSheet>(_root) != null, 'Edit sheet missing');
      await _tapBarrier();
    } else {
      _require(
        _find<CategoryDeleteDialog>(_root) != null,
        'Delete dialog missing',
      );
      await _tap(_text(_find<CategoryDeleteDialog>(_root)!, '취소')!);
    }
    _require(
      jsonEncode(h.categories.map(managementMetadata).toList()) == before &&
          jsonEncode(h.contents.map((c) => c.id).toList()) == beforeIds,
      'Cancel changed metadata/content',
    );
    _record(
      action == '카테고리 수정'
          ? 'edit_cancel_preserves_data'
          : 'delete_cancel_preserves_data',
    );
  }
  await _tap(_add(_root)!);
  await _formText('로컬 생성 검사');
  await _hideKeyboard();
  await _tap(_text(_find<CategoryCreateSheet>(_root)!, '생성하기')!);
  _require(
    h.categories.any((c) => c.id == 900 && c.name == '로컬 생성 검사'),
    'Reactive create missing',
  );
  await _scroll('max');
  _require(
    _text(_root, '총 13개') != null && _text(_root, '로컬 생성 검사') != null,
    'Create total/row did not rerender',
  );
  final beforeColor = h.categories.firstWhere((c) => c.id == 900).color;
  _record('local_create_submitted', {
    'localCategoryId': 900,
    'callbackCount': h.calls.where((c) => c['action'] == 'add').length,
  });
  await _more(900);
  await _tap(_text(_find<CategoryActionSheet>(_root)!, '카테고리 수정')!);
  await _formText('로컬 수정 검사');
  final picker = _find<FolderColorPicker>(_root)!;
  final choices = _elements(picker)
      .where((e) => e.widget is InkWell && (e.widget as InkWell).onTap != null)
      .toList();
  _require(choices.length > 1, 'Color picker choices missing');
  await _tap(choices[1]);
  await _hideKeyboard();
  await _tap(_text(_find<CategoryEditSheet>(_root)!, '수정하기')!);
  await _scroll('max');
  final edited = h.categories.firstWhere((c) => c.id == 900);
  _require(
    edited.name == '로컬 수정 검사' &&
        edited.color != beforeColor &&
        _text(_root, '로컬 수정 검사') != null &&
        _text(_root, '총 13개') != null,
    'Reactive edit name/color/total missing',
  );
  _record('local_edit_submitted', {
    'localCategoryId': 900,
    'colorBefore': _color(beforeColor),
    'colorAfter': _color(edited.color),
    'callbackCount': h.calls.where((c) => c['action'] == 'update').length,
  });
  await _more(900);
  await _tap(_text(_find<CategoryActionSheet>(_root)!, '카테고리 삭제')!);
  await _tap(_text(_find<CategoryDeleteDialog>(_root)!, '삭제')!);
  _require(
    jsonEncode(h.categories.map(managementMetadata).toList()) == before &&
        jsonEncode(h.contents.map((c) => c.id).toList()) == beforeIds,
    'Delete failed to restore original metadata/content',
  );
  await _scroll('0');
  _require(
    _text(_root, '총 12개') != null &&
        !_elements(_root).any(
          (e) =>
              e.widget is CategoryRow &&
              (e.widget as CategoryRow).category.id == 900,
        ),
    'Reactive delete total/row missing',
  );
  _record('local_delete_submitted_and_restored', {
    'localCategoryId': 900,
    'callbackCount': h.calls.where((c) => c['action'] == 'delete').length,
    'metadataRestored': true,
    'contentIdsRestored': true,
    'persistenceScope': 'local reactive callbacks only',
  });
  await _tap(_back(_root)!);
  _require(
    h.route == 'returned' &&
        h.calls.where((c) => c['action'] == 'back').length == 1,
    'Back callback missing',
  );
  _record('back_callback', {'returnedTo': 'archive-local-host'});
  await _tap(_key(_root, 'management-reopen')!);
  _require(
    h.route == 'management' && _find<CategoryManagementScreen>(_root) != null,
    'Local reopen failed',
  );
  await _scroll('0');
  _record('local_host_reopen');
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
  _output = await Directory.systemTemp.createTemp(
    'clipback-category-management-',
  );
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add({'error': d.exceptionAsString()});
    old?.call(d);
  };
  runApp(
    RepaintBoundary(
      key: _capture,
      child: CategoryManagementPreviewHost(key: _host),
    ),
  );
  await _settle();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'CATEGORY_MANAGEMENT ready phase=$managementPhase output=${_output.path}',
  );
  await for (final r in server) {
    final read = const ['/ready', '/state', '/status'].contains(r.uri.path);
    if (_busy && !read) {
      r.response.statusCode = 409;
      await r.response.close();
      continue;
    }
    if (!read) {
      _busy = true;
    }
    try {
      switch (r.uri.path) {
        case '/ready':
        case '/state':
        case '/status':
          break;
        case '/scene':
          await _open();
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
    } catch (e, stack) {
      _records.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$e',
      });
      debugPrint('CATEGORY_MANAGEMENT FAIL $e\n$stack');
      await _report();
      r.response.statusCode = 500;
      r.response.write(jsonEncode({'error': '$e', ..._snapshot()}));
    } finally {
      if (!read) {
        _busy = false;
      }
      await r.response.close();
    }
  }
}
