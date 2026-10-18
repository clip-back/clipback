// B01 oracle intentionally compiles before the production sheet exists.
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'notification_alignment_fixture.dart' as common;

const permissionGuideTitle = '허투루를 더 편하게 이용하려면\n다음 권한이 필요해요';
const permissionGuideDescription = '허용하지 않아도 기본 서비스 이용은 가능해요.';
const permissionGuideNames = ['알림 권한', '사진 권한'];
const permissionGuideDetails = [
  '콘텐츠를 다시 볼 수 있도록 알림을 보내드려요.',
  '스크린샷이나 이미지를 첨부할 때 필요해요.',
];
const permissionGuideAssets = [
  'assets/figma/permission-b01-notification.png',
  'assets/figma/permission-b01-photo.png',
];
List<Element> permissionElements(Element root) =>
    common.notificationElements(root);
Element? permissionFind<T extends Widget>(Element root) =>
    common.notificationFind<T>(root);
Element? permissionKey(Element root, String key) =>
    common.notificationKey(root, key);
Element? permissionText(Element root, String text) =>
    common.notificationText(root, text);
Element? permissionSheet(Element root) => permissionElements(root)
    .where((e) => e.widget.runtimeType.toString() == 'PermissionGuideSheet')
    .firstOrNull;
Rect permissionBox(Element e) => common.notificationBox(e);
Map<String, double> permissionRect(Rect r) => common.notificationRect(r);
String? _color(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
Map<String, Object?> _paragraph(Element? e) {
  if (e == null) {
    return {};
  }
  final rich = e.widget is RichText ? e : permissionFind<RichText>(e);
  if (rich == null) {
    return {};
  }
  final p = rich.findRenderObject()! as RenderParagraph;
  final s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': permissionRect(permissionBox(rich)),
    'fontFamily': s.fontFamily,
    'fontSize': s.fontSize,
    'fontWeight': s.fontWeight?.value,
    'letterSpacing': s.letterSpacing,
    'height': s.height,
    'color': _color(s.color),
    'scaledFontSize': s.fontSize == null
        ? null
        : p.textScaler.scale(s.fontSize!),
    'maxLines': p.maxLines,
    'overflow': p.overflow.name,
    'softWrap': p.softWrap,
    'didExceedMaxLines': p.didExceedMaxLines,
  };
}

ScrollPosition? permissionPosition(Element root) {
  final sheet = permissionSheet(root);
  if (sheet == null) {
    return null;
  }
  final e = permissionFind<Scrollable>(sheet);
  return e is StatefulElement && e.state is ScrollableState
      ? (e.state as ScrollableState).position
      : null;
}

Map<String, Object?> permissionMeasure(Element root) {
  final target = permissionSheet(root);
  if (target == null) {
    return {'active': false, 'presentation': 'noB01InBaseline'};
  }
  final media = MediaQuery.of(target);
  final pos = permissionPosition(root);
  final bounds = <String, Object?>{};
  for (final key in [
    'panel',
    'handle',
    'scroll',
    'title',
    'description',
    'row-0',
    'row-1',
    'icon-0',
    'icon-1',
    'icon-0-clip',
    'icon-1-clip',
    'icon-0-source',
    'icon-1-source',
    'continue-hit',
    'continue-label',
  ]) {
    final e = permissionKey(target, 'permission-guide-$key');
    bounds[key] = e == null ? null : permissionRect(permissionBox(e));
  }
  final panel = permissionKey(target, 'permission-guide-panel')?.widget;
  BoxDecoration? decoration;
  if (panel is Container && panel.decoration is BoxDecoration) {
    decoration = panel.decoration! as BoxDecoration;
  }
  if (panel is DecoratedBox && panel.decoration is BoxDecoration) {
    decoration = panel.decoration as BoxDecoration;
  }
  final images = <Map<String, Object?>>[];
  for (var i = 0; i < 2; i++) {
    final e = permissionKey(target, 'permission-guide-icon-$i-source');
    final imageElement = e == null
        ? null
        : (e.widget is Image ? e : permissionFind<Image>(e));
    final image = imageElement?.widget as Image?;
    ImageProvider? provider = image?.image;
    if (provider is ResizeImage) {
      provider = provider.imageProvider;
    }
    images.add({
      'asset': provider is AssetImage ? provider.assetName : null,
      'fit': image?.fit?.name,
      'name': _paragraph(permissionKey(target, 'permission-guide-name-$i')),
      'optional': _paragraph(
        permissionKey(target, 'permission-guide-optional-$i'),
      ),
      'detail': _paragraph(permissionKey(target, 'permission-guide-detail-$i')),
    });
  }
  final filters = permissionElements(root)
      .where((e) => e.widget is BackdropFilter)
      .map((e) => e.widget as BackdropFilter)
      .toList();
  final barriers = permissionElements(root)
      .where((e) => e.widget is ModalBarrier)
      .map((e) => e.widget as ModalBarrier)
      .toList();
  return {
    'active': true,
    'presentation': 'permissionGuideSheet',
    'bounds': bounds,
    'title': _paragraph(permissionKey(target, 'permission-guide-title')),
    'description': _paragraph(
      permissionKey(target, 'permission-guide-description'),
    ),
    'button': _paragraph(
      permissionKey(target, 'permission-guide-continue-label'),
    ),
    'rows': images,
    'panelColor': _color(decoration?.color),
    'panelRadius': decoration?.borderRadius
        ?.resolve(TextDirection.ltr)
        .topLeft
        .x,
    'blur2Count': filters
        .where((b) => b.filter == ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2))
        .length,
    'black50BarrierCount': barriers
        .where((b) => b.color == Colors.black.withValues(alpha: .5))
        .length,
    'barrierColors': barriers.map((b) => _color(b.color)).toList(),
    'topSafeArea': media.viewPadding.top,
    'bottomSafeArea': media.viewPadding.bottom,
    'windowWidth': media.size.width,
    'windowHeight': media.size.height,
    'scrollOffset': pos?.pixels ?? 0,
    'maxScrollExtent': pos?.maxScrollExtent ?? 0,
    'textScale': media.textScaler.scale(1),
  };
}

Map<String, Object?> permissionJudgment(
  Map<String, Object?> m, {
  bool requireActive = false,
}) {
  final sf = <String>[], lf = <String>[], af = <String>[];
  Map<String, Object?> result() => {
    'stylePassed': sf.isEmpty,
    'layoutPassed': lf.isEmpty,
    'assetPassed': af.isEmpty,
    'styleFailures': sf,
    'layoutFailures': lf,
    'assetFailures': af,
  };
  if (m['active'] != true) {
    if (requireActive) {
      sf.add('B01 absent before product implementation');
      lf.add('B01 panel absent');
      af.add('B01 original icon crops absent');
    }
    return result();
  }
  bool near(Object? x, num y) => x is num && (x - y).abs() < .26;
  void n(Object? x, num y, String why) {
    if (!near(x, y)) {
      lf.add('$why: $x != $y');
    }
  }

  void style(
    Map p,
    double size,
    int weight,
    double spacing,
    String color,
    String role, {
    double? height,
    String family = 'Pretendard',
  }) {
    if (p['fontFamily'] != family ||
        !near(p['fontSize'], size) ||
        !near(p['scaledFontSize'], size) ||
        p['fontWeight'] != weight ||
        !near(p['letterSpacing'], spacing) ||
        p['color'] != color ||
        (height == null ? p['height'] != null : !near(p['height'], height))) {
      sf.add('$role style: $p');
    }
  }

  style(
    m['title'] as Map,
    18,
    700,
    -.45,
    '0xFF1A1A1A',
    'title',
    height: 1.6,
    family: 'PretendardDetail',
  );
  style(
    m['description'] as Map,
    14,
    500,
    -.35,
    '0xFF767676',
    'description',
    height: 1.5,
  );
  style(
    m['button'] as Map,
    16,
    600,
    0,
    '0xFFFFD75C',
    'button',
    height: 22 / 16,
  );
  if ((m['title'] as Map)['text'] != permissionGuideTitle ||
      (m['description'] as Map)['text'] != permissionGuideDescription ||
      (m['button'] as Map)['text'] != '계속하기') {
    sf.add('Exact B01 primary copy');
  }
  final bounds = m['bounds'] as Map;
  final panel = bounds['panel'] as Map?,
      handle = bounds['handle'] as Map?,
      title = (m['title'] as Map)['bounds'] as Map?,
      button = bounds['continue-hit'] as Map?,
      viewport = bounds['scroll'] as Map?;
  if ([panel, handle, title, button, viewport].any((r) => r == null)) {
    lf.add('Missing keyed B01 geometry');
    return result();
  }
  final width = m['windowWidth'] as num,
      height = m['windowHeight'] as num,
      bottom = m['bottomSafeArea'] as num,
      top = m['topSafeArea'] as num;
  final desiredHeight = (460 + bottom).clamp(0, height - top);
  n(panel!['width'], width.clamp(0, 375), 'panel maximum375');
  n(panel['height'], desiredHeight, 'panel460+OS constrained once');
  n(panel['bottom'], height, 'panel at window bottom');
  n(panel['left'], (width - (panel['width'] as num)) / 2, 'panel center');
  if (m['panelColor'] != '0xFFFFFFFF' || !near(m['panelRadius'], 16)) {
    af.add('Original white panel and top radius16');
  }
  n(handle!['width'], 50, 'handle50');
  n(handle['height'], 5, 'handle5');
  n((handle['top'] as num) - (panel['top'] as num), 8, 'handle top8');
  n(button!['height'], 48, 'button48');
  n((button['left'] as num) - (panel['left'] as num), 24, 'button left24');
  n((panel['right'] as num) - (button['right'] as num), 24, 'button right24');
  n(
    (panel['bottom'] as num) - (button['bottom'] as num),
    32 + bottom,
    'button bottom32+OS',
  );
  final offset = m['scrollOffset'] as num;
  n((title!['left'] as num) - (panel['left'] as num), 24, 'title left24');
  n((title['top'] as num) - (panel['top'] as num) + offset, 60, 'title top60');
  final rows = m['rows'] as List;
  for (var i = 0; i < 2; i++) {
    final row = rows[i] as Map;
    style(row['name'] as Map, 16, 600, -.4, '0xFF1A1A1A', 'name$i');
    style(row['optional'] as Map, 16, 400, -.4, '0xFFC5A544', 'optional$i');
    style(
      row['detail'] as Map,
      14,
      500,
      -.35,
      '0xFF767676',
      'detail$i',
      height: 1.5,
    );
    if ((row['name'] as Map)['text'] != permissionGuideNames[i] ||
        (row['optional'] as Map)['text'] != '(선택)' ||
        (row['detail'] as Map)['text'] != permissionGuideDetails[i]) {
      sf.add('Exact permission copy$i');
    }
    final icon = bounds['icon-$i'] as Map?,
        clip = bounds['icon-$i-clip'] as Map?,
        source = bounds['icon-$i-source'] as Map?,
        rect = bounds['row-$i'] as Map?;
    if ([icon, clip, source, rect].any((r) => r == null)) {
      af.add('Missing exact icon crop$i');
      continue;
    }
    n(icon!['width'], 42, 'icon$i width42');
    n(icon['height'], 42, 'icon$i height42');
    n(clip!['width'], 42, 'clip$i width42');
    n(clip['height'], 42, 'clip$i height42');
    final sx = i == 0 ? 1.0591 : 1.1109,
        sy = i == 0 ? 1.07 : 1.1109,
        dx = i == 0 ? -.0296 : -.0554,
        dy = i == 0 ? -.035 : -.0554;
    n(source!['width'], 42 * sx, 'source$i width');
    n(source['height'], 42 * sy, 'source$i height');
    n(
      (source['left'] as num) - (clip['left'] as num),
      42 * dx,
      'source$i left crop',
    );
    n(
      (source['top'] as num) - (clip['top'] as num),
      42 * dy,
      'source$i top crop',
    );
    if (row['asset'] != permissionGuideAssets[i]) {
      af.add('Exact original icon asset$i');
    }
    n((rect!['left'] as num) - (panel['left'] as num), 24, 'row$i left24');
    if ((rect['top'] as num) - (panel['top'] as num) + offset <
        195 + i * 80 - .26) {
      lf.add('Row$i starts before minimum');
    }
    final nameBounds = (row['name'] as Map)['bounds'] as Map;
    n((nameBounds['left'] as num) - (icon['right'] as num), 8, 'icon-to-name8');
  }
  if (m['blur2Count'] != 1) {
    af.add('Exactly one backdrop Gaussian2');
  }
  if (m['black50BarrierCount'] != 1) {
    af.add('Exactly one black50 modal barrier');
  }
  if ((button['top'] as num) < (viewport!['bottom'] as num) - .26) {
    lf.add('Footer overlaps scroll viewport');
  }
  return result();
}

Future<Map<String, Object?>> permissionLoadFonts({bool loadForTest = false}) =>
    common.notificationLoadFonts(loadForTest: loadForTest);
