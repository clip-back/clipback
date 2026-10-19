// Shared, baseline-compilable measurements. Missing target keys are a red
// target judgment, never a reason to fabricate or block the BEFORE capture.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'splash_alignment_fixture.dart' as base;

List<Element> loadingElements(Element root) => base.splashElements(root);
Element? loadingKey(Element root, String key) => base.splashKey(root, key);
Element? loadingFind<T extends Widget>(Element root) =>
    base.splashFind<T>(root);
Rect loadingBox(Element e) => base.splashBox(e);
Map<String, double> loadingRect(Rect r) => base.splashRect(r);
String? _color(Color? value) => value == null
    ? null
    : '0x${value.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

Map<String, Object?> loadingMeasure(Element root) {
  final screen = loadingKey(root, 'home-initial-loading-screen');
  if (screen == null) return {'active': false};
  final mq = MediaQuery.of(screen);
  final view = View.of(screen);
  final scroll = loadingFind<Scrollable>(screen);
  final position = scroll is StatefulElement && scroll.state is ScrollableState
      ? (scroll.state as ScrollableState).position
      : null;
  final textScalingAncestors = <Element>{};
  for (final name in ['title', 'description']) {
    loadingKey(screen, 'home-initial-loading-$name')?.visitAncestorElements((
      e,
    ) {
      if (identical(e, screen)) return false;
      if (e.widget is FittedBox) textScalingAncestors.add(e);
      return true;
    });
  }
  Map<String, Object?>? role(String name) {
    final e = loadingKey(screen, 'home-initial-loading-$name');
    if (e == null) return null;
    final p = e.widget is RichText ? e : loadingFind<RichText>(e);
    if (p == null) return null;
    final paragraph = p.findRenderObject()! as RenderParagraph;
    final style = (paragraph.text as TextSpan).style!;
    return {
      'text': paragraph.text.toPlainText(),
      'bounds': loadingRect(loadingBox(p)),
      'fontFamily': style.fontFamily,
      'fontSize': style.fontSize,
      'fontWeight': style.fontWeight?.value,
      'letterSpacing': style.letterSpacing,
      'height': style.height,
      'color': _color(style.color),
      'scaledFontSize': paragraph.textScaler.scale(style.fontSize!),
      'maxLines': paragraph.maxLines,
      'overflow': paragraph.overflow.name,
      'textAlign': paragraph.textAlign.name,
    };
  }

  Map<String, Object?>? asset(String name) {
    final e = loadingKey(screen, 'home-initial-loading-$name');
    if (e == null) return null;
    final image = loadingFind<Image>(e);
    final svg = e.widget is SvgPicture ? e : loadingFind<SvgPicture>(e);
    return {
      'bounds': loadingRect(loadingBox(e)),
      if (image != null)
        'asset': ((image.widget as Image).image as AssetImage).assetName,
      if (image != null) 'fit': (image.widget as Image).fit?.name,
      if (svg != null)
        'asset': ((svg.widget as SvgPicture).bytesLoader as SvgAssetLoader)
            .assetName,
      if (svg != null)
        'unfiltered': (svg.widget as SvgPicture).colorFilter == null,
    };
  }

  final group = loadingKey(screen, 'home-initial-loading-group');
  final viewport = loadingKey(screen, 'home-initial-loading-viewport');
  final scaffold = loadingFind<Scaffold>(screen);
  return {
    'active': true,
    'window': {
      'width': view.physicalSize.width / view.devicePixelRatio,
      'height': view.physicalSize.height / view.devicePixelRatio,
    },
    'screen': loadingRect(loadingBox(screen)),
    'frame': scaffold == null ? null : loadingRect(loadingBox(scaffold)),
    'scaffoldColor': scaffold == null
        ? null
        : _color((scaffold.widget as Scaffold).backgroundColor),
    'safeTop': mq.viewPadding.top,
    'safeBottom': mq.viewPadding.bottom,
    'safeCenterY':
        (mq.viewPadding.top +
            view.physicalSize.height / view.devicePixelRatio -
            mq.viewPadding.bottom) /
        2,
    'textScale': mq.textScaler.scale(16) / 16,
    'group': group == null ? null : loadingRect(loadingBox(group)),
    'viewport': viewport == null ? null : loadingRect(loadingBox(viewport)),
    'title': role('title'),
    'description': role('description'),
    'illustration': asset('illustration'),
    'dots': asset('dots'),
    'scrollOffset': position?.pixels ?? 0,
    'maxScrollExtent': position?.maxScrollExtent ?? 0,
    'fittedBoxCount': textScalingAncestors.length,
    'svgInternalFittedBoxCount': loadingElements(screen)
        .where(
          (e) => e.widget is FittedBox && !textScalingAncestors.contains(e),
        )
        .length,
    'safeAreaCount': loadingElements(
      screen,
    ).where((e) => e.widget is SafeArea).length,
  };
}

Map<String, Object?> loadingJudgment(Map<String, Object?> m) {
  final style = <String>[], layout = <String>[], asset = <String>[];
  void check(bool pass, String why, List<String> errors) {
    if (!pass) errors.add(why);
  }

  bool near(num? a, num b, [double e = .65]) => a != null && (a - b).abs() < e;
  if (m['active'] != true) {
    return {
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': false,
      'styleFailures': ['Target screen not present on baseline'],
      'layoutFailures': ['Target screen not present on baseline'],
      'assetFailures': ['Target screen not present on baseline'],
    };
  }
  final title = m['title'] as Map?,
      desc = m['description'] as Map?,
      group = m['group'] as Map?,
      pic = m['illustration'] as Map?,
      dots = m['dots'] as Map?,
      frame = m['frame'] as Map?;
  for (final spec in [
    (
      'title',
      title,
      '홈을 불러오는 중',
      'PretendardDetail',
      24.0,
      700,
      -.6,
      1.6,
      '0xFF1A1A1A',
    ),
    (
      'description',
      desc,
      '저장한 콘텐츠를 준비하고 있어요',
      'Pretendard',
      16.0,
      500,
      -.4,
      1.5,
      '0xFF767676',
    ),
  ]) {
    final p = spec.$2;
    check(
      p != null &&
          p['text'] == spec.$3 &&
          p['fontFamily'] == spec.$4 &&
          p['fontSize'] == spec.$5 &&
          p['fontWeight'] == spec.$6 &&
          near(p['letterSpacing'] as num?, spec.$7) &&
          p['height'] == spec.$8 &&
          p['color'] == spec.$9 &&
          p['scaledFontSize'] == spec.$5 &&
          p['textAlign'] == 'center',
      '${spec.$1} actual RenderParagraph style',
      style,
    );
  }
  check(
    m['fittedBoxCount'] == 0 && m['safeAreaCount'] == 1 && m['textScale'] == 1,
    'Natural 1x content with one SafeArea',
    layout,
  );
  check(
    group != null && near(group['width'] as num?, 224),
    'group width224',
    layout,
  );
  check(
    pic != null &&
        near((pic['bounds'] as Map)['width'] as num?, 224) &&
        near((pic['bounds'] as Map)['height'] as num?, 224) &&
        pic['fit'] == 'cover',
    'illustration224 cover',
    layout,
  );
  check(
    dots != null &&
        near((dots['bounds'] as Map)['width'] as num?, 52) &&
        near((dots['bounds'] as Map)['height'] as num?, 12),
    'dots52x12',
    layout,
  );
  if (group != null && frame != null) {
    check(
      near(
        (group['left'] as num) + 112,
        (frame['left'] as num) + (frame['width'] as num) / 2 + .5,
      ),
      'group center x+.5',
      layout,
    );
  }
  if ((m['maxScrollExtent'] as num? ?? 0) == 0 && group != null) {
    check(
      near(
        (group['top'] as num) + (group['height'] as num) / 2,
        (m['safeCenterY'] as num) - 8,
      ),
      'group safe center−8',
      layout,
    );
  }
  if (pic != null && title != null && desc != null && dots != null) {
    final pb = pic['bounds'] as Map,
        tb = title['bounds'] as Map,
        db = desc['bounds'] as Map,
        dotb = dots['bounds'] as Map;
    check(near(tb['top'] as num?, pb['bottom'] as num), 'image→title0', layout);
    check(
      near(db['top'] as num?, (tb['bottom'] as num) + 8),
      'title→description8',
      layout,
    );
    check(
      near(dotb['top'] as num?, (db['bottom'] as num) + 32),
      'description→dots32',
      layout,
    );
    check(
      near(tb['height'] as num?, 38.4) && near(db['height'] as num?, 24),
      'paragraph natural heights',
      layout,
    );
  }
  check(
    pic?['asset'] == 'assets/figma/logout-illustration.png',
    'exact original illustration PNG path',
    asset,
  );
  check(
    dots?['asset'] == 'assets/figma/home-initial-loading-dots.svg' &&
        dots?['unfiltered'] == true,
    'exact unfiltered original dots SVG path',
    asset,
  );
  return {
    'stylePassed': style.isEmpty,
    'layoutPassed': layout.isEmpty,
    'assetPassed': asset.isEmpty,
    'styleFailures': style,
    'layoutFailures': layout,
    'assetFailures': asset,
  };
}
