// Key-only A05-1 probes compile on the baseline with its existing AlertDialog.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'splash_alignment_fixture.dart' as base;

List<Element> conflictElements(Element e) => base.splashElements(e);
Element? conflictKey(Element e, String k) => base.splashKey(e, k);
Element? conflictFind<T extends Widget>(Element e) => base.splashFind<T>(e);
Rect conflictBox(Element e) => base.splashBox(e);
Map<String, double> _rect(Rect r) => base.splashRect(r);
String? _color(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
const conflictWarning =
    '기존 계정으로 전환하면 현재 게스트의 저장 데이터는 합쳐지지 않으며, 이 기기에서 다시 접근하지 못할 수 있어요. 기존 계정으로 로그인할까요?';
Map<String, Object?> conflictMeasure(Element root) {
  final screen = conflictKey(root, 'account-link-conflict-screen');
  if (screen == null) return {'active': false};
  final mq = MediaQuery.of(screen), view = View.of(screen);
  Element? key(String n) => conflictKey(screen, 'account-link-conflict-$n');
  Map<String, Object?>? para(String name) {
    final e = key(name);
    if (e == null) return null;
    final rich = e.widget is RichText ? e : conflictFind<RichText>(e);
    if (rich == null) return null;
    final p = rich.findRenderObject()! as RenderParagraph,
        s = (p.text as TextSpan).style!;
    var fitted = 0;
    rich.visitAncestorElements((e) {
      if (identical(e, screen)) return false;
      if (e.widget is FittedBox) fitted++;
      return true;
    });
    return {
      'text': p.text.toPlainText(),
      'bounds': _rect(conflictBox(rich)),
      'fontFamily': s.fontFamily,
      'fontSize': s.fontSize,
      'fontWeight': s.fontWeight?.value,
      'letterSpacing': s.letterSpacing,
      'height': s.height,
      'color': _color(s.color),
      'scaledFontSize': p.textScaler.scale(s.fontSize!),
      'maxLines': p.maxLines,
      'overflow': p.overflow.name,
      'didExceedMaxLines': p.didExceedMaxLines,
      'fittedBoxAncestors': fitted,
    };
  }

  Map<String, Object?>? button(String name) {
    final e = key(name);
    if (e == null) return null;
    final b = conflictFind<OutlinedButton>(e), m = conflictFind<Material>(e);
    if (b == null || m == null) return null;
    final w = b.widget as OutlinedButton,
        paint = m.widget as Material,
        shape = paint.shape,
        padding = w.style?.padding?.resolve({})?.resolve(TextDirection.ltr);
    return {
      'color': _color(paint.color),
      'radius': shape is RoundedRectangleBorder
          ? shape.borderRadius.resolve(TextDirection.ltr).topLeft.x
          : null,
      'borderColor': shape is RoundedRectangleBorder
          ? _color(shape.side.color)
          : null,
      'borderWidth': shape is RoundedRectangleBorder ? shape.side.width : null,
      'enabled': w.onPressed != null,
      'padding': padding == null
          ? null
          : {
              'left': padding.left,
              'top': padding.top,
              'right': padding.right,
              'bottom': padding.bottom,
            },
    };
  }

  final scroll = conflictFind<Scrollable>(key('scroll') ?? screen);
  final pos = scroll is StatefulElement && scroll.state is ScrollableState
      ? (scroll.state as ScrollableState).position
      : null;
  final back = key('back-image');
  final svg = back?.widget is SvgPicture
      ? back
      : back == null
      ? null
      : conflictFind<SvgPicture>(back);
  final scaffold = screen.widget is Scaffold
      ? screen
      : conflictFind<Scaffold>(screen)!;
  return {
    'active': true,
    'frame': _rect(conflictBox(scaffold)),
    'window': {
      'width': view.physicalSize.width / view.devicePixelRatio,
      'height': view.physicalSize.height / view.devicePixelRatio,
    },
    'safeTop': mq.viewPadding.top,
    'safeBottom': mq.viewPadding.bottom,
    'textScale': mq.textScaler.scale(16) / 16,
    'scrollOffset': pos?.pixels ?? 0,
    'maxScrollExtent': pos?.maxScrollExtent ?? 0,
    'safeAreaCount': conflictElements(
      screen,
    ).where((e) => e.widget is SafeArea).length,
    'imageCount': conflictElements(
      screen,
    ).where((e) => e.widget is Image).length,
    'svgCount': conflictElements(
      screen,
    ).where((e) => e.widget is SvgPicture).length,
    'background': _color((scaffold.widget as Scaffold).backgroundColor),
    'fakeOSCount': conflictElements(screen)
        .where(
          (e) => [
            'DesignStatusBar',
            'DesignHomeIndicator',
            'EntryHomeIndicator',
            'EntryStatusBar',
            'NavigationHomeIndicator',
          ].contains(e.widget.runtimeType.toString()),
        )
        .length,
    for (final n in [
      'header',
      'back-hit',
      'body',
      'scroll',
      'footer',
      'confirm',
      'keep',
    ])
      n: key(n) == null ? null : _rect(conflictBox(key(n)!)),
    for (final n in ['header-title', 'title', 'warning']) n: para(n),
    'confirm-label': para('confirm'),
    'keep-label': para('keep'),
    'buttons': {'confirm': button('confirm'), 'keep': button('keep')},
    'back': svg == null
        ? null
        : {
            'bounds': _rect(conflictBox(svg)),
            'asset': ((svg.widget as SvgPicture).bytesLoader as SvgAssetLoader)
                .assetName,
            'unfiltered': (svg.widget as SvgPicture).colorFilter == null,
          },
  };
}

Map<String, Object?> conflictJudgment(Map<String, Object?> m) {
  final styles = <String>[], layouts = <String>[], assets = <String>[];
  if (m['active'] != true) {
    return {
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': false,
      'styleFailures': ['A05-1 absent on baseline'],
      'layoutFailures': ['A05-1 absent on baseline'],
      'assetFailures': ['A05-1 absent on baseline'],
    };
  }
  void check(bool ok, String why, List<String> out) {
    if (!ok) out.add(why);
  }

  bool near(num? a, num b) => a != null && (a - b).abs() < .8;
  final specs = {
    'header-title': ['처음으로', 'Pretendard', 18, 600, -.45, '0xFF000000', null],
    'title': [
      '계정 연결을 확인해 주세요.',
      'PretendardDetail',
      24,
      700,
      -.6,
      '0xFF1A1A1A',
      1.6,
    ],
    'warning': [conflictWarning, 'Pretendard', 16, 500, -.4, '0xFF767676', 1.5],
    'confirm-label': [
      '기존 계정으로 전환',
      'Pretendard',
      16,
      600,
      0.0,
      '0xFFFFD75C',
      22 / 16,
    ],
    'keep-label': ['게스트 유지', 'Pretendard', 16, 600, 0.0, '0xFF1A1A1A', 22 / 16],
  };
  for (final e in specs.entries) {
    final p = m[e.key] as Map?, v = e.value;
    check(
      p != null &&
          p['text'] == v[0] &&
          p['fontFamily'] == v[1] &&
          p['fontSize'] == v[2] &&
          p['fontWeight'] == v[3] &&
          near(p['letterSpacing'] as num?, v[4] as num) &&
          p['color'] == v[5] &&
          (v[6] == null
              ? p['height'] == null
              : near(p['height'] as num?, v[6] as num)) &&
          p['scaledFontSize'] == v[2] &&
          p['fittedBoxAncestors'] == 0,
      '${e.key} explicit actual font style1x',
      styles,
    );
    if (e.key == 'warning' || e.key == 'title') {
      check(
        p?['maxLines'] == null && p?['didExceedMaxLines'] == false,
        '${e.key} natural complete text',
        layouts,
      );
    }
  }
  final frame = m['frame'] as Map,
      header = m['header'] as Map,
      body = m['body'] as Map,
      footer = m['footer'] as Map,
      title = (m['title'] as Map)['bounds'] as Map,
      warning = (m['warning'] as Map)['bounds'] as Map,
      confirm = m['confirm'] as Map,
      keep = m['keep'] as Map,
      back = m['back'] as Map,
      b = back['bounds'] as Map,
      hit = m['back-hit'] as Map,
      ht = (m['header-title'] as Map)['bounds'] as Map;
  check(
    m['background'] == '0xFFF5F5F5' &&
        m['imageCount'] == 0 &&
        m['svgCount'] == 1 &&
        m['fakeOSCount'] == 0,
    'neutral background/no image targetcard fakeOS',
    styles,
  );
  check(
    m['safeAreaCount'] == 1 &&
        near(header['top'] as num?, m['safeTop'] as num) &&
        near(header['height'] as num?, 64),
    'safe area once/header64',
    layouts,
  );
  check(
    near(b['left'] as num?, (frame['left'] as num) + 16) &&
        near(b['width'] as num?, 24) &&
        near(b['height'] as num?, 24) &&
        near((b['top'] as num) + 12, (header['top'] as num) + 32.5) &&
        near((ht['left'] as num) - (b['right'] as num), 8) &&
        near(hit['height'] as num?, 48) &&
        (hit['width'] as num) >= 48,
    'back24/x16/titlegap8/center+.5/hit48',
    layouts,
  );
  if (near(m['scrollOffset'] as num?, 0)) {
    check(
      near((title['top'] as num) - (header['bottom'] as num), 16),
      'scroll0 title top16',
      layouts,
    );
  }
  check(
    near(title['left'] as num?, (frame['left'] as num) + 16) &&
        near((warning['top'] as num) - (title['bottom'] as num), 8) &&
        near(warning['width'] as num?, (frame['width'] as num) - 32),
    'body side16/titlewarning8/full warning',
    layouts,
  );
  check(
    near(confirm['height'] as num?, 48) &&
        near(keep['height'] as num?, 48) &&
        near((keep['top'] as num) - (confirm['bottom'] as num), 8) &&
        near(confirm['left'] as num?, (frame['left'] as num) + 16) &&
        near(confirm['width'] as num?, (frame['width'] as num) - 32),
    'buttons48/gap8/sides16',
    layouts,
  );
  check(
    near(
          (frame['bottom'] as num) - (keep['bottom'] as num),
          32 + (m['safeBottom'] as num),
        ) &&
        near(body['bottom'] as num?, footer['top'] as num) &&
        near(footer['height'] as num?, 136),
    'footer32+actualOS/body separated136',
    layouts,
  );
  for (final name in ['confirm', 'keep']) {
    final button = (m['buttons'] as Map)[name] as Map?,
        pad = button?['padding'] as Map?;
    check(
      button != null &&
          button['color'] ==
              (name == 'confirm' ? '0xFF1A1A1A' : '0xFFFFFFFF') &&
          button['radius'] == 8 &&
          button['enabled'] == true &&
          button['borderWidth'] == (name == 'confirm' ? 0 : 1) &&
          (name == 'confirm' || button['borderColor'] == '0xFF767676') &&
          pad?['left'] == 16 &&
          pad?['right'] == 16 &&
          pad?['top'] == 13 &&
          pad?['bottom'] == 13,
      '$name actual Material color border radius padding',
      styles,
    );
  }
  check(
    back['asset'] == 'assets/icons/detail-back.svg' &&
        back['unfiltered'] == true,
    'exact unchanged back SVG',
    assets,
  );
  return {
    'stylePassed': styles.isEmpty,
    'layoutPassed': layouts.isEmpty,
    'assetPassed': assets.isEmpty,
    'styleFailures': styles,
    'layoutFailures': layouts,
    'assetFailures': assets,
  };
}
