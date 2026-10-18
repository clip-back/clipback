// B02/B03/B04 shared target measurements. Baseline target failures never block
// capture, and native runs use real widget/pointer state rather than a repaint.
import 'dart:convert';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../support/login_alignment_preview.dart' as login;

ThemeData interestTheme({TargetPlatform? platform}) =>
    login.loginTheme(platform: platform);
List<Element> interestElements(Element root) {
  final result = <Element>[root];
  root.visitChildren((e) => result.addAll(interestElements(e)));
  return result;
}

Element? interestFind<T extends Widget>(Element root) =>
    interestElements(root).where((e) => e.widget is T).firstOrNull;
Element? interestKey(Element root, String key) => interestElements(
  root,
).where((e) => e.widget.key == ValueKey(key)).firstOrNull;
Element? interestText(Element root, String text) => interestElements(root)
    .where(
      (e) =>
          e.widget is RichText &&
          (e.findRenderObject() as RenderParagraph).text.toPlainText() == text,
    )
    .firstOrNull;
Rect interestBox(Element e) {
  final r = e.findRenderObject()! as RenderBox;
  return MatrixUtils.transformRect(
    r.getTransformTo(null),
    Offset.zero & r.size,
  );
}

Map<String, double> interestRect(Rect r) => {
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
Map<String, Object?> _paragraph(Element? e) {
  if (e == null) return {};
  final p = (e.widget is RichText ? e : interestFind<RichText>(e))
      ?.findRenderObject();
  if (p is! RenderParagraph) return {};
  final s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': interestRect(
      MatrixUtils.transformRect(p.getTransformTo(null), Offset.zero & p.size),
    ),
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
    'didExceedMaxLines': p.didExceedMaxLines,
    'textAlign': p.textAlign.name,
  };
}

Map<String, Object?> _asset(Element? e) {
  if (e == null) return {};
  final svg = e.widget is SvgPicture ? e : interestFind<SvgPicture>(e);
  if (svg == null) {
    return {'bounds': interestRect(interestBox(e)), 'asset': null};
  }
  final w = svg.widget as SvgPicture;
  return {
    'bounds': interestRect(interestBox(svg)),
    'asset': w.bytesLoader is SvgAssetLoader
        ? (w.bytesLoader as SvgAssetLoader).assetName
        : null,
    'unfiltered': w.colorFilter == null,
  };
}

Element? _decorated(Element root, bool Function(BoxDecoration) predicate) =>
    interestElements(root)
        .where(
          (e) =>
              e.widget is DecoratedBox &&
              (e.widget as DecoratedBox).decoration is BoxDecoration &&
              predicate((e.widget as DecoratedBox).decoration as BoxDecoration),
        )
        .firstOrNull;
Map<String, Object?> _decoration(Element? e) {
  if (e == null) return {};
  final d = (e.widget as DecoratedBox).decoration as BoxDecoration;
  return {
    'bounds': interestRect(interestBox(e)),
    'color': _color(d.color),
    'radius': d.borderRadius is BorderRadius
        ? (d.borderRadius as BorderRadius).topLeft.x
        : null,
    'shape': d.shape.name,
    'borderWidth': d.border is Border ? (d.border as Border).top.width : null,
  };
}

Element? _ancestor(Element e, bool Function(Widget) predicate) {
  Element? result;
  e.visitAncestorElements((a) {
    if (predicate(a.widget)) {
      result = a;
      return false;
    }
    return true;
  });
  return result;
}

ScrollPosition? interestPosition(Element root) {
  final screen = interestFind<InterestSelectionScreen>(root);
  if (screen == null) return null;
  final e = interestFind<Scrollable>(screen);
  if (e is! StatefulElement || e.state is! ScrollableState) return null;
  return (e.state as ScrollableState).position;
}

Map<String, Object?> interestFontBundle = {
  'available': false,
  'declared': false,
};
Future<Map<String, Object?>> interestInspectFonts({
  bool loadForTest = false,
}) async {
  try {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final declared = manifest.any(
      (v) =>
          v['family'] == 'PretendardDetail' &&
          (v['fonts'] as List).any(
            (f) =>
                f['asset'] == 'assets/fonts/Pretendard-Bold.otf' &&
                f['weight'] == 700,
          ),
    );
    final bytes = await rootBundle.load('assets/fonts/Pretendard-Bold.otf');
    if (loadForTest) {
      await (FontLoader(
        'PretendardDetail',
      )..addFont(Future.value(bytes))).load();
      final base = FontLoader('Pretendard');
      for (final w in ['Regular', 'Medium', 'SemiBold']) {
        base.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
      }
      await base.load();
    }
    interestFontBundle = {
      'available': true,
      'declared': declared,
      'bytes': bytes.lengthInBytes,
      'family': 'PretendardDetail',
      'path': 'assets/fonts/Pretendard-Bold.otf',
      'loadedForTest': loadForTest,
    };
  } catch (_) {
    interestFontBundle = {'available': false, 'declared': false};
  }
  return interestFontBundle;
}

bool _painted(Element? element) {
  if (element == null) return false;
  var painted = true;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if ((widget is Visibility && !widget.visible) ||
        (widget is Offstage && widget.offstage)) {
      painted = false;
      return false;
    }
    return true;
  });
  return painted;
}

Map<String, Object?> interestMeasure(Element root) {
  final screen = interestFind<InterestSelectionScreen>(root);
  if (screen == null) return {'active': false};
  final media = MediaQuery.of(screen), frame = interestFind<Scaffold>(screen)!;
  final title =
      interestKey(screen, 'interest-title') ??
      interestText(screen, '주로 어떤 정보를\n저장하고 싶으신가요?');
  final desc =
      interestKey(screen, 'interest-description') ??
      interestText(screen, '최대 3개까지 선택해 주세요.');
  final label = interestText(screen, '다음') ?? interestText(screen, '완료');
  final next =
      interestKey(screen, 'interest-next') ??
      (label == null ? null : _ancestor(label, (w) => w is PrimaryButton));
  final toast =
      interestKey(screen, 'interest-limit-message') ??
      interestText(screen, '최대 3개까지만 선택 가능해요');
  final footer = interestKey(screen, 'interest-footer');
  final tiles = <Map<String, Object?>>[];
  for (var i = 0; i < mockInterestOptions.length; i++) {
    final tile = interestElements(screen)
        .where(
          (e) =>
              e.widget is InterestOptionTile &&
              (e.widget as InterestOptionTile).label == mockInterestOptions[i],
        )
        .firstOrNull;
    if (tile == null) continue;
    final w = tile.widget as InterestOptionTile;
    final card = _decorated(tile, (d) => d.shape != BoxShape.circle),
        circle = _decorated(tile, (d) => d.shape == BoxShape.circle);
    final row = interestKey(screen, 'interest-option-$i') ?? card ?? tile;
    final circleSlot = interestKey(screen, 'interest-circle-$i') ?? circle;
    final check = interestKey(screen, 'interest-check-$i');
    final l = interestText(tile, w.label);
    tiles.add({
      'index': i,
      'label': w.label,
      'selected': w.selected,
      'bounds': interestRect(interestBox(row)),
      'labelStyle': _paragraph(l),
      'card': _decoration(card),
      'circle': _decoration(circle),
      'circleSlot': circleSlot == null
          ? null
          : interestRect(interestBox(circleSlot)),
      'check': _asset(check),
      'inkEnabled':
          (interestFind<InkWell>(tile)?.widget as InkWell?)?.onTap != null,
    });
  }
  final button = next == null ? null : interestFind<ButtonStyleButton>(next);
  Color? buttonColor, buttonForeground;
  bool? enabled;
  if (button != null) {
    final w = button.widget as ButtonStyleButton;
    enabled = w.onPressed != null;
    final states = <WidgetState>{if (!enabled) WidgetState.disabled};
    buttonColor = w.style?.backgroundColor?.resolve(states);
    buttonForeground = w.style?.foregroundColor?.resolve(states);
  }
  final position = interestPosition(screen);
  final slot = interestKey(screen, 'interest-limit-slot'),
      icon = interestKey(screen, 'interest-limit-icon');
  final end = interestKey(screen, 'interest-body');
  return {
    'active': true,
    'frame': interestRect(interestBox(frame)),
    'safeTop': media.viewPadding.top,
    'safeBottom': media.viewPadding.bottom,
    'textScale': media.textScaler.scale(16) / 16,
    'title': _paragraph(title),
    'description': _paragraph(desc),
    'tiles': tiles,
    'selectedIndices': [
      for (final t in tiles)
        if (t['selected'] == true) t['index'],
    ],
    'next': next == null ? null : interestRect(interestBox(next)),
    'nextLabel': _paragraph(label),
    'nextEnabled': enabled,
    'nextBackground': _color(buttonColor),
    'nextForeground': _color(buttonForeground),
    'footer': footer == null ? null : interestRect(interestBox(footer)),
    'limitSlot': slot == null ? null : interestRect(interestBox(slot)),
    'limitMessage': _painted(toast) ? _paragraph(toast) : null,
    'limitIcon': _painted(icon) ? _asset(icon) : <String, Object?>{},
    'body': end == null ? null : interestRect(interestBox(end)),
    'scrollOffset': position?.pixels ?? 0,
    'maxScrollExtent': position?.maxScrollExtent ?? 0,
    'viewport': interestKey(screen, 'interest-scroll') == null
        ? null
        : interestRect(interestBox(interestKey(screen, 'interest-scroll')!)),
    'backButtonCount': interestElements(
      screen,
    ).where((e) => e.widget is SvgIconButton).length,
    'textFittedBoxCount': interestElements(screen)
        .where(
          (e) => e.widget is FittedBox && interestFind<RichText>(e) != null,
        )
        .length,
    'fontBundle': Map<String, Object?>.from(interestFontBundle),
  };
}

Map<String, Object?> interestJudgment(Map<String, Object?> m) {
  if (m['active'] != true) {
    return {
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': false,
      'styleFailures': ['Interest screen missing'],
      'layoutFailures': ['Interest screen missing'],
      'assetFailures': ['Interest screen missing'],
    };
  }
  final sf = <String>[], lf = <String>[], af = <String>[];
  bool near(Object? v, num t, [double d = .25]) =>
      v is num && (v - t).abs() <= d;
  void check(List<String> f, bool p, String why) {
    if (!p) f.add(why);
  }

  void style(
    Object? value,
    String name,
    String family,
    num size,
    int weight,
    num tracking,
    String color,
    num? height,
  ) {
    final p = value is Map ? value : const {};
    check(
      sf,
      p['fontFamily'] == family &&
          near(p['fontSize'], size) &&
          p['fontWeight'] == weight &&
          near(p['letterSpacing'] ?? 0, tracking) &&
          p['color'] == color &&
          (height == null ? p['height'] == null : near(p['height'], height)) &&
          near(p['scaledFontSize'], size),
      '$name actual font/weight/tracking/color/height',
    );
  }

  style(
    m['title'],
    'title',
    'PretendardDetail',
    24,
    700,
    -.6,
    '0xFF1A1A1A',
    1.6,
  );
  style(
    m['description'],
    'description',
    'Pretendard',
    16,
    500,
    -.4,
    '0xFF767676',
    1.5,
  );
  final selected = (m['selectedIndices'] as List).isNotEmpty;
  style(
    m['nextLabel'],
    'next',
    'Pretendard',
    16,
    600,
    0,
    selected ? '0xFFFFD75C' : '0xFFFFFFFF',
    22 / 16,
  );
  final frame = m['frame'] as Map,
      left = frame['left'] as num,
      width = frame['width'] as num,
      top = (frame['top'] as num) + (m['safeTop'] as num),
      bottom = (frame['bottom'] as num) - (m['safeBottom'] as num),
      scroll = m['scrollOffset'] as num;
  final title = (m['title'] as Map)['bounds'] as Map,
      desc = (m['description'] as Map)['bounds'] as Map,
      tiles = (m['tiles'] as List).cast<Map>();
  check(
    lf,
    near(title['top'], top + 80 - scroll) && near(title['left'], left + 16),
    'title safeTop+80 and16 horizontal',
  );
  check(
    lf,
    near((desc['top'] as num) - (title['bottom'] as num), 8),
    'title-description gap8',
  );
  for (var i = 0; i < tiles.length; i++) {
    final t = tiles[i],
        b = t['bounds'] as Map,
        c = t['circle'] as Map,
        cs = t['circleSlot'] is Map ? t['circleSlot'] as Map : const {},
        card = t['card'] as Map,
        l = t['labelStyle'] as Map,
        lb = l['bounds'] as Map,
        ch = t['check'] as Map,
        chb = ch['bounds'] is Map ? ch['bounds'] as Map : const {};
    style(l, 'option$i', 'Pretendard', 16, 500, -.4, '0xFF1A1A1A', null);
    check(
      lf,
      near(b['width'], width - 32) &&
          near(b['height'], 44) &&
          near(b['left'], left + 16),
      'option$i row width/padding/height44',
    );
    check(
      lf,
      near((lb['left'] as num) - (b['left'] as num), 16) &&
          near(
            (cs['right'] is num
                ? (b['right'] as num) - (cs['right'] as num)
                : null),
            16,
          ),
      'option$i padding16',
    );
    check(
      lf,
      near(cs['width'], 24) &&
          near(cs['height'], 24) &&
          near(chb['width'], 14) &&
          near(chb['height'], 14),
      'option$i circle24 check14 slots',
    );
    check(
      sf,
      card['color'] == '0xFFFFFFFF' &&
          near(card['radius'], 4) &&
          c['color'] == (t['selected'] == true ? '0xFF1A1A1A' : '0xFFD1D1D1'),
      'option$i white corner4 selected circle fills',
    );
    check(
      lf,
      near(
            (lb['top'] as num) + (lb['height'] as num) / 2,
            (b['top'] as num) + (b['height'] as num) / 2,
          ) &&
          near(
            cs['top'] is num
                ? (cs['top'] as num) + (cs['height'] as num) / 2
                : null,
            (b['top'] as num) + (b['height'] as num) / 2,
          ) &&
          near(
            chb['top'] is num
                ? (chb['top'] as num) + (chb['height'] as num) / 2
                : null,
            (b['top'] as num) + (b['height'] as num) / 2,
          ),
      'option$i label/circle/check vertical center',
    );
    check(
      af,
      ch['asset'] ==
              (t['selected'] == true
                  ? 'assets/figma/interest-check-selected.svg'
                  : 'assets/figma/interest-check-unselected.svg') &&
          ch['unfiltered'] == true,
      'option$i exact check asset',
    );
    if (i == 0) {
      check(
        lf,
        near((b['top'] as num) - (desc['bottom'] as num), 31.2),
        'description-list gap31.2',
      );
    }
    if (i > 0) {
      check(
        lf,
        near((b['top'] as num) - (tiles[i - 1]['bounds']['bottom'] as num), 8),
        'option$i row gap8',
      );
    }
  }
  final next = m['next'] is Map ? m['next'] as Map : const {},
      slot = m['limitSlot'] is Map ? m['limitSlot'] as Map : const {},
      vp = m['viewport'] is Map ? m['viewport'] as Map : const {};
  check(
    lf,
    near(next['width'], width - 32) &&
        near(next['height'], 56) &&
        near(next['left'], left + 16) &&
        near(next['bottom'], bottom - 32),
    'next width/height56/bottom32+safeBottom',
  );
  check(
    lf,
    near(slot['height'], 37) && near(slot['bottom'], next['top']),
    'always reserved toast21+gap16 slot37',
  );
  check(
    lf,
    m['backButtonCount'] == 0 && m['textFittedBoxCount'] == 0,
    'no visual back or text shrinking',
  );
  check(
    sf,
    m['nextEnabled'] == selected &&
        m['nextBackground'] == (selected ? '0xFF1A1A1A' : '0xFFD1D1D1') &&
        (m['nextLabel'] as Map)['text'] == '다음',
    'real enabled condition/next label/color',
  );
  check(
    lf,
    vp['bottom'] is num &&
        next['top'] is num &&
        (vp['bottom'] as num) <= (next['top'] as num) - 37 + .25,
    'scroll viewport ends above reserved footer',
  );
  if (m['limitMessage'] is Map) {
    final message = m['limitMessage'] as Map,
        mb = message['bounds'] as Map,
        icon = m['limitIcon'] as Map,
        ib = icon['bounds'] is Map ? icon['bounds'] as Map : const {};
    style(message, 'limit', 'Pretendard', 14, 500, -.35, '0xFFFF3C40', 1.5);
    check(
      lf,
      near(ib['width'], 18) &&
          near(ib['height'], 18) &&
          near(
            (mb['left'] as num) - (ib['right'] is num ? ib['right'] as num : 0),
            4,
          ),
      'toast icon18 gap4',
    );
    check(
      af,
      icon['asset'] == 'assets/figma/interest-alert.svg' &&
          icon['unfiltered'] == true,
      'toast exact alert asset',
    );
  }
  check(
    af,
    (m['fontBundle'] as Map)['available'] == true &&
        (m['fontBundle'] as Map)['declared'] == true,
    'actual Pretendard Bold file/registration',
  );
  return {
    'stylePassed': sf.isEmpty,
    'layoutPassed': lf.isEmpty,
    'assetPassed': af.isEmpty,
    'styleFailures': sf,
    'layoutFailures': lf,
    'assetFailures': af,
  };
}
