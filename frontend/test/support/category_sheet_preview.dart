// Actual modal routes, fixed 1x data and reactive local callbacks.
// flutter run --no-pub -t test/support/category_sheet_preview.dart
// --dart-define=CATEGORY_SHEETS_PHASE=before|after
// loopback :8767 /ready /state /status /scene?kind=... /run
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

const sheetsPhase = String.fromEnvironment(
  'CATEGORY_SHEETS_PHASE',
  defaultValue: 'before',
);
const sheetKinds = [
  'actions',
  'create-empty',
  'create-filled',
  'edit',
  'delete',
];
const sheetFilledName = '새 카테고리';
const sheetPrimary = CategoryItem(
  id: 101,
  name: '개발 자료',
  color: AppColors.blueDeep,
  tint: AppColors.blueSubtle,
  deep: AppColors.blueDeep,
  contentCount: 37,
  lastSavedAt: '2026. 10. 17 오후 03:30',
);
const sheetSecondary = CategoryItem(
  id: 102,
  name: '여행 아이디어',
  color: AppColors.main,
  tint: AppColors.mainSubtle,
  deep: AppColors.mainDeep,
  contentCount: 2,
);
const sheetUnclassified = CategoryItem(
  id: 99,
  name: '분류가 필요한 콘텐츠',
  color: Color(0xFFB5BDC3),
  tint: Color(0xFFE9ECEF),
  deep: Color(0xFF626C73),
  contentCount: 2,
);
List<CategoryItem> sheetCategories() => [
  sheetPrimary,
  sheetSecondary,
  sheetUnclassified,
];
List<ContentItem> sheetContents() => [
  for (final multiple in [false, true])
    ContentItem(
      id: multiple ? 'multiple' : 'single',
      title: '보존하는 ${multiple ? '복수' : '단일'} 분류 콘텐츠',
      summary: '목록 집계와 별도인 고정 콘텐츠',
      category: sheetPrimary,
      categories: multiple ? [sheetPrimary, sheetSecondary] : [sheetPrimary],
      savedAt: '10.17',
      savedAtFull: '2026. 10. 17',
      savedAtFullShort: '26.10.17',
      tags: const ['유지'],
      source: '웹',
      originalUrl: 'https://example.invalid/category-sheet',
      originalText: '원문 보존',
      bookmarked: multiple,
    ),
];
Map<String, Object?> sheetCategoryData(CategoryItem c) => {
  'id': c.id,
  'name': c.name,
  'color': _hex(c.color),
  'tint': _hex(c.tint),
  'deep': _hex(c.deep),
  'count': c.contentCount,
  'lastSavedAt': c.lastSavedAt,
  'rawTimestamp': c.rawLastSavedAt?.toIso8601String(),
  'mutationLabel': c.mutationLabel,
};
Map<String, Object?> sheetContentData(ContentItem c) => {
  'id': c.id,
  'title': c.title,
  'summary': c.summary,
  'categories': c.categories.map((v) => v.id).toList(),
  'bookmarked': c.bookmarked,
  'originalText': c.originalText,
  'originalUrl': c.originalUrl,
};

class CategorySheetPreviewHost extends StatefulWidget {
  const CategorySheetPreviewHost({
    super.key,
    this.platform,
    this.isolatedFormCapProbe = false,
  });
  final TargetPlatform? platform;
  // Only the short-height unit probe isolates the modal from the unrelated
  // archive background's own keyboard-resize overflow. Native scenes keep
  // the actual ArchiveScreen/CategoryManagementScreen origins below.
  final bool isolatedFormCapProbe;
  @override
  State<CategorySheetPreviewHost> createState() => CategorySheetPreviewState();
}

class CategorySheetPreviewState extends State<CategorySheetPreviewHost> {
  final navigatorKey = GlobalKey<NavigatorState>();
  late List<CategoryItem> categories;
  late List<ContentItem> contents;
  String origin = 'archive';
  int activeTab = 1;
  String kind = 'none';
  final calls = <Map<String, Object?>>[];
  @override
  void initState() {
    super.initState();
    categories = sheetCategories();
    contents = sheetContents();
  }

  void reset() => setState(() {
    categories = sheetCategories();
    contents = sheetContents();
    origin = 'archive';
    activeTab = 1;
    kind = 'none';
    calls.clear();
  });
  void record(String action, Map<String, Object?> data) =>
      calls.add({'action': action, ...data});
  void add(CategoryItem value) {
    final c = CategoryItem(
      id: 900,
      name: value.name,
      color: value.color,
      tint: value.tint,
      deep: value.deep,
      contentCount: value.contentCount,
    );
    record('create', sheetCategoryData(c));
    setState(() => categories = [...categories, c]);
  }

  void update(CategoryItem before, CategoryItem after) {
    record('edit', sheetCategoryData(after));
    setState(() {
      categories = categories
          .map((c) => c.id == before.id ? after : c)
          .toList();
      contents = contents
          .map(
            (c) => c.copyWith(
              categories: c.categories
                  .map((v) => v.id == before.id ? after : v)
                  .toList(),
            ),
          )
          .toList();
    });
  }

  void delete(CategoryItem category) {
    record('delete', sheetCategoryData(category));
    setState(() {
      categories = categories.where((c) => c.id != category.id).toList();
      contents = contents.map((c) {
        final kept = c.categories.where((v) => v.id != category.id).toList();
        return c.copyWith(
          categories: kept.isEmpty ? [sheetUnclassified] : kept,
        );
      }).toList();
    });
  }

  Widget _home() {
    if (widget.isolatedFormCapProbe) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('archive-category-add'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CategoryCreateSheet(onCreate: add),
              ),
              child: const Text('단위 검사용 실제 생성 모달 열기'),
            ),
          ),
        ),
      );
    }
    if (origin == 'management') {
      return CategoryManagementScreen(
        categories: categories,
        contents: contents,
        onBack: () => setState(() {
          record('managementBack', {});
          origin = 'archive';
        }),
        onAddCategory: add,
        onUpdateCategory: update,
        onDeleteCategory: delete,
      );
    }
    return ArchiveScreen(
      activeTab: activeTab,
      contents: contents,
      categories: categories,
      bookmarkedIds: const {'multiple'},
      bookmarkedFirst: false,
      randomViewing: false,
      activeCategoryName: null,
      onTabChanged: (v) => setState(() => activeTab = v),
      onSortChanged: (_) {},
      onOpenRandomView: () {},
      onExitRandomView: () {},
      onClearCategory: () {},
      onSearch: () {},
      onOpenContent: (_) {},
      onToggleBookmark: (_) {},
      onChangeContentCategory: (_, __) {},
      onDeleteContent: (_) {},
      onAddCategory: add,
      onUpdateCategory: update,
      onDeleteCategory: delete,
      onAddLink: ({required String url, CategoryItem? category}) async =>
          contents.first,
      onAddScreenshot:
          ({
            required Uint8List bytes,
            required String filename,
            CategoryItem? category,
          }) async => contents.first,
      onOpenCategory: (_) {},
      onTab: (AppRoute route) {},
      onOpenCategoryManagement: () => setState(() {
        record('managementOpen', {});
        origin = 'management';
      }),
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
    home: _home(),
  );
}

List<Element> _all(Element root) {
  final out = <Element>[];
  void visit(Element e) {
    if (e.widget case Offstage(offstage: true)) {
      return;
    }
    out.add(e);
    e.visitChildren(visit);
  }

  visit(root);
  return out;
}

Element? _find<T extends Widget>(Element root) =>
    _all(root).where((e) => e.widget is T).firstOrNull;
Element? _key(Element root, String name) =>
    _all(root).where((e) => e.widget.key == ValueKey<String>(name)).firstOrNull;
Element? _text(Element root, String value) => _all(root)
    .where((e) => e.widget is Text && (e.widget as Text).data == value)
    .firstOrNull;
Element? _ancestor(Element e, bool Function(Widget) predicate) {
  Element? found;
  e.visitAncestorElements((a) {
    if (predicate(a.widget)) {
      found = a;
      return false;
    }
    return true;
  });
  return found;
}

Rect _rect(Element e) {
  final box = e.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

Map<String, double> _r(Rect b) => {
  'left': b.left,
  'top': b.top,
  'right': b.right,
  'bottom': b.bottom,
  'width': b.width,
  'height': b.height,
};
String? _hex(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
bool _near(Object? value, num target) =>
    value is num && (value - target).abs() < .16;
Map<String, Object?> _paragraph(Element e) {
  final p = e.findRenderObject()! as RenderParagraph,
      s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': _r(_rect(e)),
    'fontFamily': s.fontFamily,
    'fontSize': s.fontSize,
    'scaledFontSize': s.fontSize == null
        ? null
        : p.textScaler.scale(s.fontSize!),
    'fontWeight': s.fontWeight?.value,
    'letterSpacing': s.letterSpacing,
    'color': _hex(s.color),
    'height': s.height,
    'maxLines': p.maxLines,
    'overflow': p.overflow.name,
    'didExceedMaxLines': p.didExceedMaxLines,
    'constraintsMaxWidth': p.constraints.maxWidth.isFinite
        ? p.constraints.maxWidth
        : 'unbounded',
    'scope':
        'Actual RenderParagraph layout bounds; not selection-box overhang or glyph ink.',
  };
}

Map<String, Object?> _svg(Element e) {
  final svg = e.widget is SvgPicture ? e : _find<SvgPicture>(e);
  final w = svg?.widget as SvgPicture?, loader = w?.bytesLoader;
  return {
    'bounds': _r(_rect(svg ?? e)),
    'asset': loader is SvgAssetLoader ? loader.assetName : null,
    'isSvg': w != null,
    'unfiltered': w?.colorFilter == null,
    'colorFilter': '${w?.colorFilter}',
    'selectedColor':
        [
              ...FolderColorPicker.colors,
              sheetPrimary.color,
              const Color(0xFFFF6F61),
            ]
            .where(
              (c) => w?.colorFilter == ColorFilter.mode(c, BlendMode.srcIn),
            )
            .map(_hex)
            .firstOrNull,
  };
}

Element? sheetRoot(Element root) =>
    _find<CategoryFormSheet>(root) ??
    _find<CategoryActionSheet>(root) ??
    _find<CategoryDeleteDialog>(root);
String sheetVisibleKind(Element root) {
  if (_find<CategoryEditSheet>(root) != null) return 'edit';
  if (_find<CategoryCreateSheet>(root) != null) {
    final input = _find<EditableText>(root);
    return input != null &&
            (input.widget as EditableText).controller.text.isNotEmpty
        ? 'create-filled'
        : 'create-empty';
  }
  if (_find<CategoryActionSheet>(root) != null) return 'actions';
  if (_find<CategoryDeleteDialog>(root) != null) return 'delete';
  return 'none';
}

Element? sheetAdd(Element root) =>
    _key(root, 'archive-category-add') ?? _key(root, 'management-add');
Element? sheetMore(Element root, int id) =>
    _key(root, 'archive-category-more-$id');
Element? _handle(Element s, String prefix) =>
    _key(s, '$prefix-handle') ??
    _all(s)
        .where(
          (e) =>
              e.widget is Container &&
              (e.widget as Container).constraints?.maxWidth == 50 &&
              (e.widget as Container).constraints?.maxHeight == 5,
        )
        .firstOrNull;
Element? _surface(Element s, String key) =>
    _key(s, key) ??
    _all(s)
        .where(
          (e) =>
              e.widget is Container &&
              (e.widget as Container).decoration is BoxDecoration,
        )
        .firstOrNull;
RenderEditable _editableRender(Element root) {
  RenderEditable? found;
  void visit(RenderObject r) {
    if (r is RenderEditable) {
      found ??= r;
    }
    r.visitChildren(visit);
  }

  visit(root.findRenderObject()!);
  return found!;
}

Map<String, Object?> _style(TextStyle s) => {
  'fontFamily': s.fontFamily,
  'fontSize': s.fontSize,
  'fontWeight': s.fontWeight?.value,
  'letterSpacing': s.letterSpacing,
  'height': s.height,
  'color': _hex(s.color),
};
Element? _hint(Element root) => _all(root)
    .where(
      (e) =>
          e.widget is RichText &&
          e.findRenderObject() is RenderParagraph &&
          (e.findRenderObject() as RenderParagraph).text.toPlainText() ==
              '카테고리명을 입력해주세요',
    )
    .firstOrNull;
Map<String, Object?>? _asset(Element? e) {
  if (e == null) return null;
  final svg = e.widget is SvgPicture ? e : _find<SvgPicture>(e);
  if (svg != null) {
    final out = _svg(svg), loader = (svg.widget as SvgPicture).bytesLoader;
    if (loader is SvgAssetLoader) {
      out['mapperRed'] = _hex(
        loader.colorMapper?.substitute(
          null,
          'path',
          'fill',
          const Color(0xFFFF6277),
        ),
      );
      out['mapperWhite'] = _hex(
        loader.colorMapper?.substitute(null, 'path', 'stroke', Colors.white),
      );
    }
    return out;
  }
  final image = e.widget is Image ? e : _find<Image>(e);
  if (image != null) {
    var provider = (image.widget as Image).image;
    if (provider is ResizeImage) provider = provider.imageProvider;
    return {
      'bounds': _r(_rect(image)),
      'isSvg': false,
      'isImage': true,
      'asset': provider is AssetImage
          ? provider.assetName
          : provider is ExactAssetImage
          ? provider.assetName
          : null,
      'fit': (image.widget as Image).fit?.name,
      'color': _hex((image.widget as Image).color),
    };
  }
  return {'bounds': _r(_rect(e)), 'isSvg': false, 'asset': null};
}

Map<String, Object?> _paint(Element root) {
  // Follow paint order from this role's outer wrapper. A form surface can be
  // SizedBox -> DecoratedBox; its CTA Material is not the surface decoration.
  for (final e in _all(root)) {
    final w = e.widget;
    final BoxDecoration? decoration =
        w is Container && w.decoration is BoxDecoration
        ? w.decoration as BoxDecoration
        : w is DecoratedBox && w.decoration is BoxDecoration
        ? w.decoration as BoxDecoration
        : null;
    if (decoration != null) {
      final radius = decoration.borderRadius?.resolve(TextDirection.ltr);
      return {
        'color': _hex(decoration.color),
        'shape': decoration.shape.name,
        'radiusTopLeft': radius?.topLeft.x,
        'radiusBottomLeft': radius?.bottomLeft.x,
        'borderColor': decoration.border is Border
            ? _hex((decoration.border as Border).top.color)
            : null,
        'borderWidth': decoration.border is Border
            ? (decoration.border as Border).top.width
            : null,
      };
    }
    if (w is ColoredBox) return {'color': _hex(w.color)};
    if (w is Divider) return {'color': _hex(w.color)};
    if (w is! Material) continue;
    final m = w, shape = m.shape;
    final radius = shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(TextDirection.ltr)
        : null;
    return {
      'color': _hex(m.color),
      'shape': '${shape.runtimeType}',
      'radiusTopLeft': radius?.topLeft.x,
      'radiusBottomLeft': radius?.bottomLeft.x,
      'borderColor': shape is OutlinedBorder ? _hex(shape.side.color) : null,
      'borderWidth': shape is OutlinedBorder ? shape.side.width : null,
    };
  }
  return {};
}

Map<String, Object?> sheetMeasurements(
  Element root,
  CategorySheetPreviewState host,
) {
  final visible = sheetRoot(root);
  if (visible == null) return {};
  final kind = sheetVisibleKind(root),
      isForm = kind.startsWith('create') || kind == 'edit';
  final media = MediaQuery.of(_find<Scaffold>(root)!);
  final roles = <String, Object?>{},
      bounds = <String, Object?>{},
      assets = <String, Object?>{},
      geometry = <String, Object?>{};
  final surface = isForm
      ? (_surface(visible, 'category-form-sheet') ?? visible)
      : kind == 'actions'
      ? (_surface(visible, 'category-actions-sheet') ?? visible)
      : (_all(_find<Dialog>(visible)!)
            .where(
              (e) =>
                  e.widget is Material &&
                  (e.widget as Material).type == MaterialType.card,
            )
            .first);
  final sr = _rect(surface);
  bounds['surface'] = _r(sr);
  geometry['surfacePaint'] = _paint(surface);
  final barrier = _find<ModalBarrier>(root);
  geometry['barrierColor'] = barrier == null
      ? null
      : _hex((barrier.widget as ModalBarrier).color);
  geometry['surfaceConstraintsMaxHeight'] =
      (surface.findRenderObject()! as RenderBox).constraints.maxHeight.isFinite
      ? (surface.findRenderObject()! as RenderBox).constraints.maxHeight
      : null;
  if (kind == 'actions') {
    final sheet = visible.widget as CategoryActionSheet, c = sheet.category;
    final name =
            _key(visible, 'category-actions-name') ?? _text(visible, c.name)!,
        count =
            _key(visible, 'category-actions-count') ??
            _text(visible, '저장된 콘텐츠 ${sheet.contentCount}')!;
    final folder =
        _key(visible, 'category-actions-folder') ??
        _find<FolderGlyph>(visible)!;
    final header =
            _key(visible, 'category-actions-header') ?? _find<Row>(visible)!,
        separator =
            _key(visible, 'category-actions-separator') ??
            _find<Divider>(visible)!,
        handle = _handle(visible, 'category-actions')!;
    roles['actionName'] = _paragraph(name);
    roles['actionCount'] = _paragraph(count);
    bounds.addAll({
      'header': _r(_rect(header)),
      'separator': _r(_rect(separator)),
      'handle': _r(_rect(handle)),
    });
    assets['actionFolder'] = _asset(folder);
    geometry['separatorPaint'] = _paint(separator);
    geometry['handlePaint'] = _paint(handle);
    final folderSvg = _find<SvgPicture>(folder);
    geometry['folderMatchesCategoryColor'] =
        folderSvg != null &&
        (folderSvg.widget as SvgPicture).colorFilter ==
            ColorFilter.mode(c.color, BlendMode.srcIn);
    geometry['categoryColor'] = _hex(c.color);
    geometry['serverCount'] = sheet.contentCount;
    for (final role in ['edit', 'delete']) {
      final label = role == 'edit' ? '카테고리 수정' : '카테고리 삭제';
      final row =
          _key(visible, 'category-actions-$role') ??
          _all(visible)
              .where(
                (e) =>
                    e.widget is CategoryActionRow &&
                    (e.widget as CategoryActionRow).title == label,
              )
              .first;
      roles['action:$role'] = _paragraph(_text(row, label)!);
      bounds['action:$role'] = _r(_rect(row));
      assets['action:$role'] = _asset(
        _find<SvgPicture>(row) ?? _find<Icon>(row),
      );
    }
    geometry.addAll({
      'nameToCount': _rect(count).top - _rect(name).bottom,
      'folderToText': _rect(name).left - _rect(folder).right,
      'handleTop': _rect(handle).top - sr.top,
      'handleToHeader': _rect(header).top - _rect(handle).bottom,
      'headerToDivider': _rect(separator).top - _rect(header).bottom,
      'dividerToOptions': 0,
    });
    geometry['dividerToOptions'] =
        _rect(
          _key(visible, 'category-actions-edit') ??
              _all(visible).where((e) => e.widget is CategoryActionRow).first,
        ).top -
        _rect(separator).bottom;
  } else if (isForm) {
    final form = visible.widget as CategoryFormSheet,
        field =
            _key(visible, 'category-form-input') ?? _find<TextField>(visible)!,
        editable = _find<EditableText>(field)!,
        ew = editable.widget as EditableText,
        er = _editableRender(editable);
    final inputRect = er.localToGlobal(Offset.zero) & er.size,
        hint = _hint(visible),
        textRect = ew.controller.text.isEmpty && hint != null
            ? _rect(hint)
            : inputRect;
    final folder =
            _key(visible, 'category-form-folder') ??
            _find<SvgPicture>(visible)!,
        palette =
            _key(visible, 'category-form-palette') ??
            _find<FolderColorPicker>(visible)!,
        button =
            _key(visible, 'category-form-button') ??
            _find<FilledButton>(visible)!,
        handle = _handle(visible, 'category-form')!;
    final borderWidget = _key(visible, 'category-form-underline');
    Rect underline;
    if (borderWidget != null) {
      underline = _rect(borderWidget);
      assets['underline'] = _asset(borderWidget);
    } else {
      final container = InputDecorator.containerOf(editable)!;
      final c = container.localToGlobal(Offset.zero) & container.size;
      final textField = field.widget as TextField;
      final border = (ew.focusNode.hasFocus
          ? textField.decoration?.focusedBorder
          : textField.decoration?.enabledBorder);
      final width = border?.borderSide.width ?? 1;
      underline = Rect.fromLTWH(c.left, c.bottom - width, c.width, width);
      assets['underline'] = {
        'asset': null,
        'isSvg': false,
        'bounds': _r(underline),
        'scope':
            'Existing InputBorder paint edge from actual InputDecorator container and border width.',
      };
    }
    roles['formInput'] = {
      ..._style((er.text as TextSpan).style ?? ew.style),
      'text': ew.controller.text,
      'bounds': _r(inputRect),
      'scaledFontSize': (ew.textScaler ?? MediaQuery.textScalerOf(editable))
          .scale(ew.style.fontSize!),
    };
    if (hint != null) roles['formHint'] = _paragraph(hint);
    roles['formButton'] = _paragraph(_text(button, form.actionLabel)!);
    assets['formFolder'] = _asset(folder);
    geometry['buttonPaint'] = _paint(button);
    geometry['handlePaint'] = _paint(handle);
    bounds.addAll({
      'handle': _r(_rect(handle)),
      'input': _r(_rect(field)),
      'editable': _r(inputRect),
      'visibleText': _r(textRect),
      'underline': _r(underline),
      'palette': _r(_rect(palette)),
      'button': _r(_rect(button)),
    });
    final scroll =
        _key(visible, 'category-form-body-scroll') ??
        _all(visible)
            .where(
              (e) =>
                  e.widget is SingleChildScrollView &&
                  (e.widget as SingleChildScrollView).scrollDirection ==
                      Axis.vertical,
            )
            .firstOrNull;
    bounds['bodyViewport'] = scroll == null ? null : _r(_rect(scroll));
    geometry.addAll({
      'inputText': ew.controller.text,
      'cursorOffset': ew.controller.selection.baseOffset,
      'inputFocused': ew.focusNode.hasFocus,
      'buttonEnabled':
          (button.widget is FilledButton
              ? (button.widget as FilledButton).onPressed
              : _find<FilledButton>(button)?.widget is FilledButton
              ? (_find<FilledButton>(button)!.widget as FilledButton).onPressed
              : null) !=
          null,
      'initialName': form.initialName,
      'initialColor': _hex(form.initialColor),
      'handleTop': _rect(handle).top - sr.top,
      'folderTop': _rect(folder).top - sr.top,
      'folderToInput': textRect.top - _rect(folder).bottom,
      'textToUnderline': underline.top - textRect.bottom,
      'fieldToPalette': _rect(palette).top - underline.bottom,
      'fieldHorizontal': underline.left - sr.left,
      'buttonHorizontal': _rect(button).left - sr.left,
      'buttonBelowKeyboardOrOs':
          media.size.height -
          math.max(media.viewInsets.bottom, media.viewPadding.bottom) -
          _rect(button).bottom,
      'bodyScrollable': scroll != null,
      'bodyClip': scroll?.widget is SingleChildScrollView
          ? (scroll!.widget as SingleChildScrollView).clipBehavior.name
          : null,
      'bodyScrollOffset': scroll == null
          ? 0
          : ((_find<Scrollable>(scroll)! as StatefulElement).state
                    as ScrollableState)
                .position
                .pixels,
      'bodyScrollMaxExtent': scroll == null
          ? 0
          : ((_find<Scrollable>(scroll)! as StatefulElement).state
                    as ScrollableState)
                .position
                .maxScrollExtent,
    });
    final options = <Map<String, Object?>>[];
    for (final color in FolderColorPicker.colors) {
      final key = 'palette-color-${color.toARGB32().toRadixString(16)}';
      final entry =
          _key(palette, key) ??
          _all(palette)
              .where(
                (e) =>
                    e.widget is InkWell && (e.widget as InkWell).onTap != null,
              )
              .elementAt(FolderColorPicker.colors.indexOf(color));
      final colored = _all(entry)
          .where(
            (e) =>
                e.widget is DecoratedBox &&
                ((e.widget as DecoratedBox).decoration as BoxDecoration?)
                        ?.color ==
                    color,
          )
          .lastOrNull;
      final selected = _all(entry)
          .where(
            (e) =>
                (e.widget is Container &&
                    ((e.widget as Container).decoration as BoxDecoration?)
                            ?.border !=
                        null) ||
                (e.widget is DecoratedBox &&
                    ((e.widget as DecoratedBox).decoration as BoxDecoration?)
                            ?.border !=
                        null),
          )
          .firstOrNull;
      options.add({
        'color': _hex(color),
        'hit': _r(_rect(entry)),
        'visual': _find<SvgPicture>(entry) != null
            ? _r(_rect(_find<SvgPicture>(entry)!))
            : colored == null
            ? null
            : _r(_rect(colored)),
        'selectedRing': selected == null ? null : _r(_rect(selected)),
        'selectedAsset': _asset(_find<SvgPicture>(entry)),
      });
    }
    geometry['paletteOptions'] = options;
    geometry['paletteSelectedColor'] = _hex(
      (palette.widget as FolderColorPicker).selectedColor,
    );
    final custom =
        _key(palette, 'palette-custom') ??
        _all(palette)
            .where(
              (e) => e.widget is InkWell && (e.widget as InkWell).onTap != null,
            )
            .last;
    assets['custom'] = _asset(custom);
    bounds['custom'] = _r(_rect(custom));
    geometry['paletteScrollOffset'] =
        ((_find<Scrollable>(palette)! as StatefulElement).state
                as ScrollableState)
            .position
            .pixels;
  } else {
    final dialog = visible.widget as CategoryDeleteDialog,
        widget = _find<Dialog>(visible)!;
    final title =
            _key(visible, 'category-delete-title') ?? _text(visible, '삭제하기')!,
        body =
            _key(visible, 'category-delete-body') ??
            _all(visible)
                .where(
                  (e) =>
                      e.widget is Text &&
                      ((e.widget as Text).data ?? '').contains(
                        '저장된 콘텐츠는 삭제되지 않아요.',
                      ),
                )
                .first;
    final warning =
        _key(visible, 'category-delete-warning') ??
        _all(visible)
            .where(
              (e) =>
                  e.widget is Container &&
                  (e.widget as Container).constraints?.maxWidth == 32,
            )
            .first;
    roles['deleteTitle'] = _paragraph(title);
    roles['deleteBody'] = _paragraph(body);
    bounds.addAll({
      'title': _r(_rect(title)),
      'body': _r(_rect(body)),
      'warning': _r(_rect(warning)),
    });
    assets['warning'] = _asset(warning);
    geometry['warningPaint'] = _paint(warning);
    for (final role in ['cancel', 'confirm']) {
      final label = role == 'cancel' ? '취소' : '삭제',
          text = _text(visible, label)!,
          button =
              _key(visible, 'category-delete-$role') ??
              _ancestor(text, (w) => w is ButtonStyleButton)!;
      roles['delete:$role'] = _paragraph(text);
      bounds['delete:$role'] = _r(_rect(button));
      geometry['delete:$role:paint'] = _paint(button);
    }
    bounds['dialogViewport'] = _r(_rect(_find<Dialog>(visible)!));
    bounds['deleteContent'] = _r(
      _rect(
        _key(visible, 'category-delete-dialog') ??
            _ancestor(title, (w) => w is Padding)!,
      ),
    );
    final deleteScroll = _key(visible, 'category-delete-viewport');
    bounds['deleteViewport'] = deleteScroll == null
        ? null
        : _r(_rect(deleteScroll));
    geometry['deleteScrollClip'] = deleteScroll?.widget is SingleChildScrollView
        ? (deleteScroll!.widget as SingleChildScrollView).clipBehavior.name
        : null;
    geometry['deleteScrollMaxExtent'] = deleteScroll == null
        ? 0
        : ((_find<Scrollable>(deleteScroll)! as StatefulElement).state
                  as ScrollableState)
              .position
              .maxScrollExtent;
    geometry.addAll({
      'categoryName': dialog.category.name,
      'preservationCopy':
          '‘${dialog.category.name}’ 카테고리를 삭제할까요?\n저장된 콘텐츠는 삭제되지 않아요.\n다른 카테고리가 있으면 그대로 유지되고, 남은 카테고리가 없으면 미분류로 이동해요.',
      'dialogInsets': (widget.widget as Dialog).insetPadding.toString(),
      'warningToTitle': _rect(title).top - _rect(warning).bottom,
      'titleToBody': _rect(body).top - _rect(title).bottom,
      'bodyToButtons':
          ((bounds['delete:cancel'] as Map)['top'] as num) - _rect(body).bottom,
    });
  }
  return {
    'visibleKind': kind,
    'actualStyles': roles,
    'bounds': bounds,
    'assetGeometry': assets,
    'geometry': geometry,
    'imeBottom': media.viewInsets.bottom,
    'osBottom': media.viewPadding.bottom,
    'windowHeight': media.size.height,
    'windowWidth': media.size.width,
  };
}

Map<String, Object?> sheetJudgment(Map<String, Object?> m) {
  final styles = <String>[], layout = <String>[];
  if (m.isEmpty) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'styleFindings': styles,
      'layoutFindings': layout,
    };
  }
  final kind = m['visibleKind'] as String,
      roles = m['actualStyles'] as Map,
      b = m['bounds'] as Map,
      a = m['assetGeometry'] as Map,
      g = m['geometry'] as Map,
      s = b['surface'] as Map,
      os = m['osBottom'] as num,
      ime = m['imeBottom'] as num;
  void style(String role, List v) {
    final p = roles[role];
    if (p is! Map) {
      styles.add('Missing $role actual style');
      return;
    }
    if (p['fontFamily'] != 'Pretendard' ||
        p['fontSize'] != v[0] ||
        p['fontWeight'] != v[1] ||
        p['letterSpacing'] != v[2] ||
        p['color'] != v[3] ||
        p['height'] != v[4] ||
        p['scaledFontSize'] != p['fontSize']) {
      styles.add('$role actual font/weight/tracking/color/line-height differs');
    }
  }

  void near(Object? actual, num expected, String label) {
    if (!_near(actual, expected)) {
      layout.add('$label: $actual expected $expected');
    }
  }

  void slot(String role, String path, num w, num h, {bool filtered = false}) {
    final v = a[role];
    if (v is! Map) {
      styles.add('Missing $role exact asset');
      return;
    }
    if (v['asset'] != path ||
        v['isSvg'] != true ||
        v['unfiltered'] == filtered) {
      styles.add('$role exact SVG/filter differs');
    }
    final r = v['bounds'] as Map;
    near(r['width'], w, '$role width');
    near(r['height'], h, '$role height');
  }

  void paint(String role, String color, {num? radius}) {
    final p = g[role] as Map?;
    if (p == null || p['color'] != color) {
      styles.add('$role actual fill differs');
    }
    if (radius != null) near(p?['radiusTopLeft'], radius, '$role radius');
  }

  paint('surfacePaint', '0xFFFFFFFF', radius: 16);

  if (kind == 'actions') {
    style('actionName', [15, 500, -.375, '0xFF1A1A1A', null]);
    style('actionCount', [12, 400, -.3, '0xFFB5BDC3', null]);
    for (final role in ['edit', 'delete']) {
      style('action:$role', [16, 500, -.4, '0xFF1A1A1A', null]);
    }
    final h = b['header'] as Map,
        d = b['separator'] as Map,
        handle = b['handle'] as Map;
    near(
      s['height'],
      223 + os + math.max(0, (h['height'] as num) - 34),
      'Actions natural body + actual OS bottom once',
    );
    near(s['bottom'], m['windowHeight'] as num, 'Actions bottom');
    near(handle['width'], 50, 'Handle width');
    near(handle['height'], 5, 'Handle height');
    near(g['handleTop'], 8, 'Handle top');
    near(g['handleToHeader'], 16, 'Handle/header gap');
    near(
      h['height'],
      math.max(
        34,
        (((roles['actionName'] as Map)['bounds'] as Map)['height'] as num) +
            2 +
            (((roles['actionCount'] as Map)['bounds'] as Map)['height'] as num),
      ),
      'Natural header height',
    );
    near(g['headerToDivider'], 16, 'Header/divider gap');
    near(d['height'], 8, 'Divider height');
    near(d['width'], s['width'] as num, 'Divider full width');
    near(g['dividerToOptions'], 16, 'Divider/options gap');
    near(g['nameToCount'], 2, 'Name/count gap');
    near(g['folderToText'], 12, 'Folder/text gap');
    final nameRole = roles['actionName'] as Map;
    near(nameRole['constraintsMaxWidth'], 156, 'Action text column maximum');
    if (nameRole['maxLines'] != 1 || nameRole['overflow'] != 'ellipsis') {
      layout.add('Action name must retain one-line ellipsis');
    }
    paint('separatorPaint', '0xFFF5F5F5');
    slot(
      'actionFolder',
      'assets/icons/archive-category-folder.svg',
      40,
      34,
      filtered: true,
    );
    if (g['folderMatchesCategoryColor'] != true) {
      styles.add('Folder must match actual category data color');
    }
    for (final role in ['edit', 'delete']) {
      final row = b['action:$role'] as Map;
      near(row['height'], 44, '$role action height');
      slot(
        'action:$role',
        'assets/icons/category-sheet-${role == 'edit' ? 'edit' : 'trash'}.svg',
        20,
        20,
      );
      final icon = (a['action:$role'] as Map)['bounds'] as Map,
          text = (roles['action:$role'] as Map)['bounds'] as Map;
      near((icon['left'] as num) - (s['left'] as num), 16, '$role icon left');
      near(
        (text['left'] as num) - (icon['right'] as num),
        8,
        '$role icon/text gap',
      );
      near(
        ((text['top'] as num) + (text['bottom'] as num)) / 2,
        ((row['top'] as num) + (row['bottom'] as num)) / 2,
        '$role text center',
      );
    }
    near(
      (s['bottom'] as num) - ((b['action:delete'] as Map)['bottom'] as num),
      32 + os,
      'Actions bottom reserve',
    );
  } else if (kind.startsWith('create') || kind == 'edit') {
    style('formInput', [18, 600, -.45, '0xFF1A1A1A', null]);
    if ((g['inputText'] as String).isEmpty) {
      style('formHint', [18, 500, -.45, '0xFFD1D1D1', null]);
    }
    style('formButton', [
      15,
      600,
      -.375,
      g['buttonEnabled'] == true ? '0xFFFFD75C' : '0xFFFFFFFF',
      null,
    ]);
    final reserve = math.max(ime, os),
        available = g['surfaceConstraintsMaxHeight'] as num?;
    near(
      s['height'],
      available == null ? 428 + reserve : math.min(428 + reserve, available),
      'Form capped base428 + max inset once',
    );
    final handle = b['handle'] as Map, button = b['button'] as Map;
    near(handle['width'], 50, 'Handle width');
    near(handle['height'], 5, 'Handle height');
    near(g['handleTop'], 8, 'Handle top');
    near(
      (g['folderTop'] as num) + (g['bodyScrollOffset'] as num),
      60,
      'Folder top in natural content coordinates',
    );
    near(g['folderToInput'], 32, 'Folder/input gap');
    near(g['textToUnderline'], 8, 'Text/underline gap');
    near(g['fieldToPalette'], 32, 'Field/palette gap');
    near(g['fieldHorizontal'], 24, 'Field horizontal');
    near(
      (b['underline'] as Map)['width'],
      (s['width'] as num) - 48,
      'Underline available field width',
    );
    near((b['underline'] as Map)['height'], 1, 'Underline height');
    near(g['buttonHorizontal'], 16, 'Button horizontal');
    near(button['width'], (s['width'] as num) - 32, 'Button available width');
    near(button['height'], 48, 'Button height');
    near(g['buttonBelowKeyboardOrOs'], 32, 'Button below keyboard/OS');
    paint(
      'buttonPaint',
      g['buttonEnabled'] == true ? '0xFF1A1A1A' : '0xFFD1D1D1',
      radius: 8,
    );
    slot(
      'formFolder',
      'assets/icons/folder-create-preview.svg',
      121,
      103,
      filtered: true,
    );
    final folder = a['formFolder'] as Map;
    if (folder['selectedColor'] == null) {
      styles.add('Form folder must use actual selected color');
    }
    slot(
      'underline',
      'assets/icons/category-sheet-underline.svg',
      (s['width'] as num) - 48,
      1,
    );
    if (g['bodyScrollable'] != true || g['bodyClip'] == 'none') {
      layout.add('Form requires a clipped vertical scroll viewport');
    }
    if (b['bodyViewport'] case final Map viewport) {
      if ((viewport['bottom'] as num) > (button['top'] as num) + .16) {
        layout.add('Body viewport overlaps button');
      }
    }
    final options = g['paletteOptions'] as List;
    if (options.length != 8) {
      layout.add('Exact existing eight palette choices required');
    }
    Map? previous;
    for (final entry in options) {
      final v = entry['visual'] as Map?,
          ring = entry['selectedRing'] as Map?,
          asset = entry['selectedAsset'] as Map?;
      if (v == null) {
        layout.add('Missing actual swatch visual');
        continue;
      }
      near(v['width'], 30, 'Swatch visual width');
      near(v['height'], 30, 'Swatch visual height');
      final expectedSelected = entry['color'] == g['paletteSelectedColor'];
      if ((ring != null) != expectedSelected) {
        layout.add('Palette selected ring must match actual selectedColor');
      }
      final spacingBox = ring ?? v;
      if (ring != null) {
        near(ring['width'], 36, 'Selected ring width');
        near(ring['height'], 36, 'Selected ring height');
        if (asset == null ||
            asset['asset'] !=
                'assets/icons/category-sheet-selected-swatch.svg' ||
            asset['mapperRed'] != entry['color'] ||
            asset['mapperWhite'] != '0xFFFFFFFF' ||
            asset['unfiltered'] != true) {
          styles.add(
            'Selected raw SVG must recolor red only and preserve white check',
          );
        }
      }
      if (previous != null) {
        near(
          (spacingBox['left'] as num) - (previous['right'] as num),
          8,
          'Visible swatch gap',
        );
      }
      previous = spacingBox;
    }
    final custom = a['custom'] as Map?;
    if (custom == null ||
        custom['asset'] != 'assets/icons/category-sheet-custom.png' ||
        custom['isImage'] != true) {
      styles.add('Custom control must use original image');
    } else {
      near((custom['bounds'] as Map)['width'], 38, 'Custom width');
      near((custom['bounds'] as Map)['height'], 32, 'Custom height');
    }
  } else if (kind == 'delete') {
    style('deleteTitle', [18, 600, -.45, '0xFF000000', null]);
    style('deleteBody', [14, 500, -.35, '0xFF767676', 1.6]);
    style('delete:cancel', [14, 600, 0, '0xFF1A1A1A', 22 / 14]);
    style('delete:confirm', [14, 600, 0, '0xFFFF0000', 22 / 14]);
    if ((roles['deleteBody'] as Map)['text'] != g['preservationCopy']) {
      styles.add('Exact current content-preservation copy must remain');
    }
    final warning = b['warning'] as Map,
        content = b['deleteContent'] as Map,
        cancel = b['delete:cancel'] as Map,
        confirm = b['delete:confirm'] as Map;
    near(
      s['width'],
      math.min(311, (m['windowWidth'] as num) - 64),
      'Dialog max311/inset32',
    );
    near(warning['width'], 32, 'Warning background width');
    near(warning['height'], 32, 'Warning background height');
    near(
      (warning['top'] as num) - (content['top'] as num),
      32,
      'Dialog top padding',
    );
    near(g['warningToTitle'], 8, 'Warning/title gap');
    near(g['titleToBody'], 8, 'Title/body gap');
    near(g['bodyToButtons'], 36, 'Body/buttons gap');
    near(
      (content['bottom'] as num) - (cancel['bottom'] as num),
      32,
      'Dialog bottom padding',
    );
    near(cancel['height'], 44, 'Cancel height');
    near(confirm['height'], 44, 'Confirm height');
    near(
      (confirm['left'] as num) - (cancel['right'] as num),
      8,
      'Delete button gap',
    );
    near(
      (cancel['left'] as num) - (s['left'] as num),
      16,
      'Dialog inner horizontal',
    );
    near(
      (s['right'] as num) - (confirm['right'] as num),
      16,
      'Dialog inner horizontal',
    );
    slot('warning', 'assets/icons/category-sheet-warning.svg', 24, 24);
    paint('warningPaint', '0xFFFFF3CE');
    final dialogViewport = b['dialogViewport'] as Map;
    near(
      ((s['top'] as num) + (s['bottom'] as num)) / 2,
      ((dialogViewport['top'] as num) + (dialogViewport['bottom'] as num)) / 2,
      'Existing natural dialog vertical center',
    );
    if (g['deleteScrollClip'] == null || g['deleteScrollClip'] == 'none') {
      layout.add('Delete requires a clipped scroll viewport');
    }
    final cancelPaint = g['delete:cancel:paint'] as Map,
        confirmPaint = g['delete:confirm:paint'] as Map;
    if (cancelPaint['color'] != '0xFFFFFFFF' ||
        cancelPaint['borderColor'] != '0xFFD1D1D1' ||
        cancelPaint['borderWidth'] != 1 ||
        confirmPaint['color'] != '0xFFFFDDDD') {
      styles.add('Delete/cancel actual fills or border differ');
    }
    for (final role in ['deleteTitle', 'deleteBody']) {
      final r = (roles[role] as Map)['bounds'] as Map;
      if ((r['left'] as num) < (s['left'] as num) + 15.8 ||
          (r['right'] as num) > (s['right'] as num) - 15.8 ||
          (r['top'] as num) < (content['top'] as num) ||
          (r['bottom'] as num) > (content['bottom'] as num)) {
        layout.add('$role paragraph exceeds actual dialog parent');
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

final _host = GlobalKey<CategorySheetPreviewState>(), _capture = GlobalKey();
late Directory _output;
final _errors = <Map<String, Object?>>[], _records = <Map<String, Object?>>[];
bool _busy = false, _complete = false, _coverage = false;
int _pointer = 18000;
final _pointerClock = Stopwatch()..start();
Duration _lastPointerTime = Duration.zero;
Duration _pointerTime() {
  final elapsed = _pointerClock.elapsed;
  _lastPointerTime = elapsed > _lastPointerTime
      ? elapsed
      : _lastPointerTime + const Duration(microseconds: 1);
  return _lastPointerTime;
}

Element get _root => _capture.currentContext! as Element;
Future<void> _settle([int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

void _require(bool value, String reason) {
  if (!value) throw StateError(reason);
}

Future<void> _tap(Element element) async {
  final point = _rect(element).center,
      v = View.of(_capture.currentContext!),
      id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      viewId: v.viewId,
      position: point,
      timeStamp: _pointerTime(),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 70));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: v.viewId,
      position: point,
      timeStamp: _pointerTime(),
    ),
  );
  await _settle();
}

Future<void> _waitIme(bool shown) async {
  for (var i = 0; i < 40; i++) {
    final inset = MediaQuery.of(_find<Scaffold>(_root)!).viewInsets.bottom;
    if (shown ? inset > 0 : inset == 0) return;
    await _settle(2);
  }
  _require(false, 'Actual keyboard ${shown ? 'show' : 'hide'} not observed');
}

Future<void> _hideIme() async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _waitIme(false);
  await _settle(2);
}

Future<void> _type(String value, {bool keyboard = true}) async {
  final input = _find<EditableText>(sheetRoot(_root)!)!;
  if (keyboard) {
    // Autofocus already owns the native input connection in static scenes.
    // Retapping text can open iOS selection controls instead of preparing data.
    ((input as StatefulElement).state as EditableTextState).requestKeyboard();
    await _waitIme(true);
  }
  final widget = input.widget as EditableText;
  widget.controller.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
  widget.onChanged?.call(value);
  await _settle(3);
}

Future<void> _dismiss() async {
  await _hideIme();
  final v = View.of(_capture.currentContext!),
      point = Offset(
        v.physicalSize.width / v.devicePixelRatio / 2,
        MediaQuery.of(_find<Scaffold>(_root)!).viewPadding.top + 4,
      ),
      id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      viewId: v.viewId,
      position: point,
      timeStamp: _pointerTime(),
    ),
  );
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: v.viewId,
      position: point,
      timeStamp: _pointerTime(),
    ),
  );
  await _settle();
  _require(sheetRoot(_root) == null, 'Backdrop dismiss failed');
}

Future<void> _origin(String origin) async {
  _host.currentState!.navigatorKey.currentState!.popUntil((r) => r.isFirst);
  await _hideIme();
  _host.currentState!.reset();
  await _settle();
  if (origin == 'management') {
    await _tap(_key(_root, 'archive-manage-categories')!);
    _require(
      _find<CategoryManagementScreen>(_root) != null,
      'Actual settings route missing',
    );
  }
}

Future<void> _actions([int id = 101]) async {
  await _tap(sheetMore(_root, id)!);
  _require(
    _find<CategoryActionSheet>(_root) != null,
    'Actual action sheet missing',
  );
}

Future<void> _action(String label) async {
  final sheet = _find<CategoryActionSheet>(_root)!;
  await _tap(_text(sheet, label)!);
}

Future<void> _stage(String kind, {String origin = 'archive'}) async {
  _require(sheetKinds.contains(kind), 'Unknown sheet kind');
  await _origin(origin);
  _host.currentState!.kind = kind;
  if (kind.startsWith('create')) {
    await _tap(sheetAdd(_root)!);
    await _waitIme(true);
    if (kind == 'create-filled') {
      await _type(sheetFilledName);
    } else {
      await _type('');
    }
  } else {
    await _actions();
    if (kind == 'edit') {
      await _action('카테고리 수정');
      await _waitIme(true);
    }
    if (kind == 'delete') {
      await _action('카테고리 삭제');
      await _hideIme();
    }
  }
  if (kind == 'actions' || kind == 'delete') await _waitIme(false);
  await _settle(3);
}

Map<String, Object?> _snapshot() {
  final host = _host.currentState!,
      v = View.of(_capture.currentContext!),
      media = MediaQuery.of(_find<Scaffold>(_root)!),
      m = sheetMeasurements(_root, host),
      j = sheetJudgment(m);
  return {
    'phase': sheetsPhase,
    'platform': Platform.operatingSystem,
    'kind': host.kind,
    'origin': host.origin,
    'ready': true,
    'busy': _busy,
    'output': _output.path,
    'logicalSize': '${v.physicalSize / v.devicePixelRatio}',
    'pixelRatio': v.devicePixelRatio,
    'textScale': media.textScaler.scale(1),
    'viewPaddingTop': media.viewPadding.top,
    'viewPaddingBottom': media.viewPadding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'scrollOffset': m.isEmpty
        ? 0
        : (m['geometry'] as Map)['bodyScrollOffset'] ?? 0,
    'maxScrollExtent': m.isEmpty
        ? 0
        : (m['geometry'] as Map)['bodyScrollMaxExtent'] ??
              (m['geometry'] as Map)['deleteScrollMaxExtent'] ??
              0,
    ...m,
    ...j,
    'categoryMetadata': host.categories.map(sheetCategoryData).toList(),
    'contents': host.contents.map(sheetContentData).toList(),
    'contentIds': host.contents.map((c) => c.id).toList(),
    'calls': List.of(host.calls),
    'frameworkErrors': _errors,
    'scope':
        'Actual ArchiveScreen/CategoryManagementScreen modal routes and local reactive callbacks. Synthetic pointer/controller input, real native IME inset, no HTTP/OAuth/physical-device/CI proof.',
  };
}

void _record(String name, [Map<String, Object?> data = const {}]) =>
    _records.add({'scenario': name, 'passed': true, ..._snapshot(), ...data});
Future<void> _captureScene() async {
  await _settle(2);
  final name = 'category_sheets_${_host.currentState!.kind}_scale_1',
      b = _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary,
      image = await b.toImage(
        pixelRatio: View.of(_capture.currentContext!).devicePixelRatio,
      );
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${_output.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _records.add({'capture': name, ..._snapshot()});
}

Future<void> _report() async {
  final current = _snapshot();
  await File('${_output.path}/report.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      ...current,
      'checksCompleted': _complete,
      'coveragePassed': _coverage,
      'behaviorPassed': _complete && !_records.any((v) => v['passed'] == false),
      'stylePassed':
          current['stylePassed'] == true &&
          !_records.any((v) => v['stylePassed'] == false),
      'layoutPassed':
          current['layoutPassed'] == true &&
          _errors.isEmpty &&
          !_records.any((v) => v['layoutPassed'] == false),
      'passed':
          _complete &&
          _coverage &&
          current['stylePassed'] == true &&
          current['layoutPassed'] == true &&
          _errors.isEmpty &&
          !_records.any(
            (v) =>
                v['passed'] == false ||
                v['stylePassed'] == false ||
                v['layoutPassed'] == false,
          ),
      'checks': _records,
    }),
  );
}

Element _palette() => _find<FolderColorPicker>(sheetRoot(_root)!)!;
Element _choice(int index) =>
    _key(
      _palette(),
      'palette-color-${FolderColorPicker.colors[index].toARGB32().toRadixString(16)}',
    ) ??
    _all(_palette())
        .where(
          (e) => e.widget is InkWell && (e.widget as InkWell).onTap != null,
        )
        .elementAt(index);
Element _custom() =>
    _key(_palette(), 'palette-custom') ??
    _all(_palette())
        .where(
          (e) => e.widget is InkWell && (e.widget as InkWell).onTap != null,
        )
        .last;
Future<void> _paletteDrag() async {
  final scroll =
          (_find<Scrollable>(_palette())! as StatefulElement).state
              as ScrollableState,
      p = scroll.position;
  final before = p.pixels,
      rect = _rect(_find<Scrollable>(_palette())!),
      start = Offset(rect.right - 25, rect.center.dy),
      view = View.of(_capture.currentContext!),
      id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      viewId: view.viewId,
      position: start,
      timeStamp: _pointerTime(),
    ),
  );
  for (var i = 1; i <= 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: id,
        viewId: view.viewId,
        position: start - Offset(i * 12.0, 0),
        delta: const Offset(-12, 0),
        timeStamp: _pointerTime(),
      ),
    );
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: view.viewId,
      position: start - const Offset(96, 0),
      timeStamp: _pointerTime(),
    ),
  );
  await _settle();
  _require(p.pixels > before + 1, 'Actual palette drag did not change offset');
  _record('${_host.currentState!.origin}_palette_pointer_drag', {
    'beforeOffset': before,
    'afterOffset': p.pixels,
    'pointerMoveCount': 8,
  });
  p.jumpTo(0);
  await _settle(2);
}

Future<void> _submitBurst(String label) async {
  final target = _text(sheetRoot(_root)!, label)!,
      point = _rect(target).center,
      view = View.of(_capture.currentContext!);
  for (var tap = 0; tap < 2; tap++) {
    final id = ++_pointer;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        pointer: id,
        viewId: view.viewId,
        position: point,
        timeStamp: _pointerTime(),
      ),
    );
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(
        pointer: id,
        viewId: view.viewId,
        position: point,
        timeStamp: _pointerTime(),
      ),
    );
  }
  await _settle();
}

Future<void> _run() async {
  _complete = false;
  _coverage = false;
  final covered = <String>[];
  for (final kind in sheetKinds) {
    await _stage(kind);
    final m = sheetMeasurements(_root, _host.currentState!);
    _require(
      m['visibleKind'] == kind,
      'Scene does not expose expected actual modal',
    );
    final roles = m['actualStyles'] as Map;
    final expected = kind == 'actions'
        ? ['actionName', 'actionCount', 'action:edit', 'action:delete']
        : kind == 'delete'
        ? ['deleteTitle', 'deleteBody', 'delete:cancel', 'delete:confirm']
        : kind == 'create-empty'
        ? ['formInput', 'formHint', 'formButton']
        : ['formInput', 'formButton'];
    _require(expected.every(roles.containsKey), 'Missing actual role coverage');
    covered.add(kind);
    _record('scene_coverage_$kind', {'requiredRoles': expected});
  }
  _coverage = covered.toSet().containsAll(sheetKinds);
  _records.add({
    'scenario': 'required_scene_coverage',
    'passed': _coverage,
    'coveredKinds': covered,
    'expectedKinds': sheetKinds,
  });
  for (final origin in ['archive', 'management']) {
    await _stage('actions', origin: origin);
    final h = _host.currentState!,
        beforeCategories = jsonEncode(
          h.categories.map(sheetCategoryData).toList(),
        ),
        beforeContents = jsonEncode(h.contents.map(sheetContentData).toList());
    _require(
      (_find<CategoryActionSheet>(_root)!.widget as CategoryActionSheet)
              .contentCount ==
          37,
      'Server count changed to loaded count',
    );
    _record('${origin}_server_count');
    await _dismiss();
    _require(
      h.calls
          .where((c) => ['create', 'edit', 'delete'].contains(c['action']))
          .isEmpty,
      'Dismiss actions mutated data',
    );
    _record('${origin}_actions_cancel');
    await _tap(sheetAdd(_root)!);
    h.kind = 'create-empty';
    await _waitIme(true);
    await _type('   ');
    final form = sheetRoot(_root)!, button = _find<FilledButton>(form)!;
    _require(
      (button.widget as FilledButton).onPressed == null,
      'Whitespace must stay invalid',
    );
    _record('${origin}_empty_trim_validation');
    await _type('보존할 입력');
    final controller =
        (_find<EditableText>(form)!.widget as EditableText).controller;
    await _tap(_choice(1));
    await _hideIme();
    _require(controller.text == '보존할 입력', 'Keyboard hide lost input');
    final selected =
        ((sheetMeasurements(_root, h)['assetGeometry'] as Map)['formFolder']
            as Map)['selectedColor'];
    _require(
      selected == _hex(FolderColorPicker.colors[1]),
      'Palette selected color lost',
    );
    _record('${origin}_keyboard_hide_preserves_input_color', {
      'controllerText': controller.text,
      'selectedColor': selected,
      'keyboardInsetZero': true,
    });
    await _tap(_find<EditableText>(form)!);
    await _waitIme(true);
    _require(controller.text == '보존할 입력', 'Keyboard show lost input');
    _record('${origin}_keyboard_show_preserves_input_color', {
      'controllerText': controller.text,
      'keyboardInsetPositive': true,
    });
    await _paletteDrag();
    await _tap(_custom());
    final coral =
        ((sheetMeasurements(_root, h)['assetGeometry'] as Map)['formFolder']
            as Map)['selectedColor'];
    _require(coral == '0xFFFF6F61', 'Existing custom control coral changed');
    _record('${origin}_custom_coral_preserved', {'selectedColor': coral});
    await _dismiss();
    _require(
      jsonEncode(h.categories.map(sheetCategoryData).toList()) ==
          beforeCategories,
      'Create cancel changed metadata',
    );
    _record('${origin}_create_cancel');
    await _tap(sheetAdd(_root)!);
    h.kind = 'create-filled';
    await _waitIme(true);
    await _type('  로컬 생성  ');
    await _hideIme();
    await _submitBurst('생성하기');
    _require(
      h.calls.where((c) => c['action'] == 'create').length == 1 &&
          h.categories.any((c) => c.id == 900 && c.name == '로컬 생성'),
      'Create trim/one-shot callback failed',
    );
    _record('${origin}_create_trim_one_shot', {
      'callbackCount': 1,
      'name': '로컬 생성',
    });
    await _actions(101);
    await _action('카테고리 수정');
    h.kind = 'edit';
    await _waitIme(true);
    final metrics = sheetMeasurements(_root, h);
    _require(
      (metrics['geometry'] as Map)['paletteSelectedColor'] ==
              _hex(sheetPrimary.color) &&
          !FolderColorPicker.colors.contains(sheetPrimary.color),
      'Outside-palette initial color not preserved',
    );
    _record('${origin}_outside_palette_initial_color');
    await _type('취소할 수정');
    await _dismiss();
    _require(
      h.categories.firstWhere((c) => c.id == 101).name == sheetPrimary.name,
      'Edit cancel changed name',
    );
    _record('${origin}_edit_cancel');
    await _actions(101);
    await _action('카테고리 수정');
    h.kind = 'edit';
    await _waitIme(true);
    await _type('  수정된 자료  ');
    await _tap(_choice(2));
    await _hideIme();
    await _submitBurst('수정하기');
    final edited = h.categories.firstWhere((c) => c.id == 101);
    _require(
      h.calls.where((c) => c['action'] == 'edit').length == 1 &&
          edited.name == '수정된 자료' &&
          edited.contentCount == 37 &&
          edited.lastSavedAt == sheetPrimary.lastSavedAt &&
          edited.color == FolderColorPicker.colors[2],
      'Edit callback/trim/metadata failed',
    );
    _record('${origin}_edit_trim_one_shot_metadata', {'callbackCount': 1});
    await _actions(101);
    await _action('카테고리 삭제');
    h.kind = 'delete';
    await _hideIme();
    await _tap(_text(sheetRoot(_root)!, '취소')!);
    _require(
      h.categories.any((c) => c.id == 101) &&
          h.calls.where((c) => c['action'] == 'delete').isEmpty,
      'Delete cancel mutated data',
    );
    _record('${origin}_delete_cancel');
    await _actions(101);
    await _action('카테고리 삭제');
    h.kind = 'delete';
    await _hideIme();
    await _tap(_text(sheetRoot(_root)!, '삭제')!);
    _require(
      h.calls.where((c) => c['action'] == 'delete').length == 1 &&
          h.contents.length == 2 &&
          h.contents.firstWhere((c) => c.id == 'single').category.id == 99 &&
          h.contents
                  .firstWhere((c) => c.id == 'multiple')
                  .categories
                  .single
                  .id ==
              102 &&
          h.contents.firstWhere((c) => c.id == 'multiple').bookmarked,
      'Delete preservation/one-shot failed',
    );
    _record('${origin}_delete_preserves_content_categories', {
      'callbackCount': 1,
      'contentIdsPreserved': true,
      'otherCategoryPreserved': true,
      'lastCategoryMovesToUnclassified': true,
    });
    if (origin == 'management') {
      await _tap(_key(_root, 'management-back')!);
      _require(h.origin == 'archive', 'Management return callback failed');
      _record('management_return_to_archive');
    }
    h.reset();
    await _settle();
    _require(
      jsonEncode(h.categories.map(sheetCategoryData).toList()) ==
              beforeCategories &&
          jsonEncode(h.contents.map(sheetContentData).toList()) ==
              beforeContents,
      'Local fixture restoration failed',
    );
    _record('${origin}_local_data_restored', {
      'categoriesRestored': true,
      'contentsRestored': true,
      'scope': 'Explicit local fixture reset; not server rollback proof.',
    });
  }
  _complete = true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _output = await Directory.systemTemp.createTemp('clipback-category-sheets-');
  final old = FlutterError.onError;
  FlutterError.onError = (e) {
    _errors.add({'error': e.exceptionAsString()});
    old?.call(e);
  };
  runApp(
    RepaintBoundary(
      key: _capture,
      child: CategorySheetPreviewHost(key: _host),
    ),
  );
  await _settle();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('CATEGORY_SHEETS ready phase=$sheetsPhase output=${_output.path}');
  await for (final request in server) {
    final read = const [
      '/ready',
      '/state',
      '/status',
    ].contains(request.uri.path);
    if (_busy && !read) {
      request.response.statusCode = 409;
      await request.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (request.uri.path) {
        case '/ready':
        case '/state':
        case '/status':
          break;
        case '/scene':
          await _stage(request.uri.queryParameters['kind'] ?? 'actions');
          await _captureScene();
        case '/run':
          await _run();
        default:
          request.response.statusCode = 404;
      }
      await _report();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_snapshot()));
    } catch (error, stack) {
      _records.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$error',
      });
      debugPrint('CATEGORY_SHEETS FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}
