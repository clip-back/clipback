// Shared navigation oracle. It compiles on the pre-alignment baseline and reads
// rendered SVG sources from each labelled slot instead of product constants.
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

const navigationTabs = ['home', 'archive', 'bookmark', 'my'];
const navigationLabels = ['홈', '아카이브', '즐겨찾기', '마이'];
// Source names are deliberately strings so BEFORE can compile before new Assets.
const navigationInactiveAssets = [
  'assets/icons/nav-home-outline.svg',
  'assets/icons/nav-archive-outline.svg',
  'assets/icons/nav-bookmark-outline.svg',
  'assets/icons/nav-account-outline.svg',
];
const navigationActiveAssets = [
  'assets/icons/nav-home-filled.svg',
  'assets/icons/nav-archive-filled.svg',
  'assets/icons/nav-bookmark-filled.svg',
  'assets/icons/nav-account-filled.svg',
];
const navigationArchiveBookmarkAsset =
    'assets/icons/nav-bookmark-outline-archive.svg';
const navigationMyInnerAsset = 'assets/icons/nav-account-outline-inner.svg';

List<Element> navigationElements(Element root) {
  final result = <Element>[root];
  root.visitChildren((child) => result.addAll(navigationElements(child)));
  return result;
}

Element? navigationFind<T extends Widget>(Element root) =>
    navigationElements(root).where((e) => e.widget is T).firstOrNull;
Element? navigationText(Element root, String text) => navigationElements(
  root,
).where((e) => e.widget is Text && (e.widget as Text).data == text).firstOrNull;
Element? navigationKey(Element root, String key) => navigationElements(
  root,
).where((e) => e.widget.key == ValueKey(key)).firstOrNull;
Element? navigationAncestor(Element root, bool Function(Widget) match) {
  Element? result;
  root.visitAncestorElements((e) {
    if (match(e.widget)) {
      result = e;
      return false;
    }
    return true;
  });
  return result;
}

Rect navigationBox(Element element) {
  final box = element.findRenderObject()! as RenderBox;
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

Map<String, double> navigationRect(Rect r) => {
  'left': r.left,
  'top': r.top,
  'right': r.right,
  'bottom': r.bottom,
  'width': r.width,
  'height': r.height,
  'centerX': r.center.dx,
  'centerY': r.center.dy,
};
Future<void> navigationLoadFonts() async {
  final loader = FontLoader('Pretendard');
  for (final weight in ['Regular', 'Medium', 'SemiBold']) {
    loader.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
  }
  await loader.load();
}

String? _color(Color? color) => color == null
    ? null
    : '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
Map<String, Object?> navigationMeasure(Element root) {
  final bar = navigationFind<ClipbackNavigationBar>(root);
  if (bar == null) return {'active': false};
  final active = (bar.widget as ClipbackNavigationBar).activeIndex;
  final media = MediaQuery.of(bar);
  final slots = <Map<String, Object?>>[];
  for (var index = 0; index < navigationLabels.length; index++) {
    final label = navigationText(bar, navigationLabels[index])!;
    final slot = navigationAncestor(label, (w) => w is InkWell)!;
    final column = navigationFind<Column>(slot)!;
    final firstWidget = (column.widget as Column).children.first;
    final icon = navigationElements(
      column,
    ).firstWhere((e) => identical(e.widget, firstWidget));
    final rich = navigationFind<RichText>(label)!;
    final paragraph = rich.findRenderObject()! as RenderParagraph;
    final style = (paragraph.text as TextSpan).style!;
    final color = index == active
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFD1D1D1);
    final svgs = navigationElements(icon)
        .where((e) => e.widget is SvgPicture)
        .map((e) {
          final svg = e.widget as SvgPicture;
          return {
            'asset': svg.bytesLoader is SvgAssetLoader
                ? (svg.bytesLoader as SvgAssetLoader).assetName
                : null,
            'bounds': navigationRect(navigationBox(e)),
            'expectedTint': _color(color),
            'tintMatches':
                svg.colorFilter == ColorFilter.mode(color, BlendMode.srcIn),
            'filter': svg.colorFilter?.toString(),
          };
        })
        .toList();
    slots.add({
      'index': index,
      'label': navigationLabels[index],
      'selected': index == active,
      'bounds': navigationRect(navigationBox(slot)),
      'icon': navigationRect(navigationBox(icon)),
      'svgs': svgs,
      'labelBounds': navigationRect(navigationBox(rich)),
      'fontFamily': style.fontFamily,
      'fontSize': style.fontSize,
      'scaledFontSize': paragraph.textScaler.scale(style.fontSize!),
      'fontWeight': style.fontWeight?.value,
      'letterSpacing': style.letterSpacing,
      'color': _color(style.color),
      'maxLines': paragraph.maxLines,
    });
  }
  return {
    'active': true,
    'activeIndex': active,
    'bounds': navigationRect(navigationBox(bar)),
    'slots': slots,
    'addButton': navigationRect(
      navigationBox(navigationFind<NavAddButton>(bar)!),
    ),
    'bottomViewPadding': media.viewPadding.bottom,
    'keyboardInset': media.viewInsets.bottom,
    'textScale': media.textScaler.scale(12) / 12,
  };
}

Map<String, Object?> navigationJudgment(Map<String, Object?> measure) {
  final style = <String>[], layout = <String>[], asset = <String>[];
  if (measure['active'] != true) {
    return {
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': false,
      'styleFailures': ['Navigation missing'],
      'layoutFailures': ['Navigation missing'],
      'assetFailures': ['Navigation missing'],
    };
  }
  bool near(Object? n, num target) => n is num && (n - target).abs() < .18;
  void number(Object? n, num target, String name) {
    if (!near(n, target)) layout.add('$name: $n != $target');
  }

  final active = measure['activeIndex'] as int;
  final bar = measure['bounds'] as Map, add = measure['addButton'] as Map;
  number(
    bar['height'],
    64 + (measure['bottomViewPadding'] as num),
    'bar height',
  );
  number(add['width'], 72, 'add width');
  number(add['height'], 72, 'add height');
  number(add['top'], (bar['top'] as num) - 22, 'add protrusion');
  number(add['centerX'], bar['centerX'] as num, 'add centered');
  num? firstIconTop;
  for (final entry in measure['slots'] as List) {
    final s = entry as Map, index = s['index'] as int;
    final icon = s['icon'] as Map,
        bounds = s['bounds'] as Map,
        label = s['labelBounds'] as Map;
    final expectedColor = index == active ? '0xFF1A1A1A' : '0xFFD1D1D1';
    if (s['fontFamily'] != 'Pretendard' ||
        s['fontSize'] != 12 ||
        s['scaledFontSize'] != 12 ||
        s['fontWeight'] != 500 ||
        s['letterSpacing'] != -.3 ||
        s['color'] != expectedColor ||
        s['maxLines'] != 2) {
      style.add('slot $index label style mismatch');
    }
    number(bounds['width'], 56, 'slot $index width');
    number(bounds['height'], 56, 'slot $index height');
    number(icon['width'], 28, 'slot $index icon width');
    number(icon['height'], 28, 'slot $index icon height');
    number(
      icon['centerX'],
      bounds['centerX'] as num,
      'slot $index icon center',
    );
    firstIconTop ??= icon['top'] as num;
    number(icon['top'], firstIconTop, 'slot $index common icon top');
    number(
      (label['top'] as num) - (icon['bottom'] as num),
      3,
      'slot $index label gap',
    );
    for (final child in [icon, label]) {
      if ((child['left'] as num) < (bounds['left'] as num) - .18 ||
          (child['right'] as num) > (bounds['right'] as num) + .18 ||
          (child['top'] as num) < (bounds['top'] as num) - .18 ||
          (child['bottom'] as num) > (bounds['bottom'] as num) + .18) {
        layout.add('slot $index child outside touch slot');
      }
    }
    final svgs = s['svgs'] as List;
    final expected = index == active
        ? navigationActiveAssets[index]
        : index == 2 && active == 1
        ? navigationArchiveBookmarkAsset
        : navigationInactiveAssets[index];
    final expectedSources = [
      expected,
      if (index == 3 && index != active) navigationMyInnerAsset,
    ];
    if (svgs.length != expectedSources.length) {
      asset.add(
        'slot $index layer count ${svgs.length} != ${expectedSources.length}',
      );
    }
    for (var layer = 0; layer < svgs.length; layer++) {
      final svg = svgs[layer] as Map;
      if (layer >= expectedSources.length ||
          svg['asset'] != expectedSources[layer] ||
          svg['tintMatches'] != true) {
        asset.add(
          'slot $index layer $layer source/tint mismatch ${svg['asset']}',
        );
      }
      final b = svg['bounds'] as Map;
      final size = layer == 0 ? 28.0 : 23.3333;
      number(b['width'], size, 'slot $index layer $layer width');
      number(b['height'], size, 'slot $index layer $layer height');
      number(
        b['centerX'],
        icon['centerX'] as num,
        'slot $index layer $layer centerX',
      );
      number(
        b['centerY'],
        icon['centerY'] as num,
        'slot $index layer $layer centerY',
      );
    }
  }
  return {
    'stylePassed': style.isEmpty,
    'layoutPassed': layout.isEmpty,
    'assetPassed': asset.isEmpty,
    'styleFailures': style,
    'layoutFailures': layout,
    'assetFailures': asset,
  };
}
