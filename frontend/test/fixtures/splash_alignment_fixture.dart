// A01 measurements are shared by unit tests and the native preview. These
// target checks intentionally fail on the baseline without blocking capture.
import 'dart:async';
import 'dart:convert';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/auth/entry_widgets.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../support/login_alignment_preview.dart' as login;

ThemeData splashTheme({TargetPlatform? platform}) =>
    login.loginTheme(platform: platform);

class SplashMemoryStorage extends login.LoginMemoryStorage {
  int reads = 0;
  bool failRead = false;
  Completer<ApiSession?>? pendingRead;
  @override
  Future<ApiSession?> read() async {
    reads++;
    if (failRead) throw StateError('Fixture storage read unavailable');
    if (pendingRead != null) return pendingRead!.future;
    return value;
  }
}

const splashStoredSession = ApiSession(
  accessToken: 'fixture-startup-access',
  refreshToken: 'fixture-startup-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);

List<Element> splashElements(Element root) {
  final result = <Element>[root];
  root.visitChildren((child) => result.addAll(splashElements(child)));
  return result;
}

Element? splashFind<T extends Widget>(Element root) =>
    splashElements(root).where((e) => e.widget is T).firstOrNull;
Element? splashKey(Element root, String key) => splashElements(
  root,
).where((e) => e.widget.key == ValueKey(key)).firstOrNull;
Rect splashBox(Element e) {
  final r = e.findRenderObject()! as RenderBox;
  return MatrixUtils.transformRect(
    r.getTransformTo(null),
    Offset.zero & r.size,
  );
}

Map<String, double> splashRect(Rect r) => {
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
Map<String, Object?> splashFontBundle = {
  'available': false,
  'declared': false,
  'faceVerified': false,
};
Future<Map<String, Object?>> splashInspectFontBundle({
  bool loadForTest = false,
}) async {
  try {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final declared = manifest.any(
      (v) =>
          v['family'] == 'RiaSansSplash' &&
          (v['fonts'] as List).any(
            (f) => f['asset'] == 'assets/fonts/RiaSans-Regular.otf',
          ),
    );
    final bytes = await rootBundle.load('assets/fonts/RiaSans-Regular.otf');
    final raw = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    final face = 'RiaSans-Regular'.codeUnits;
    bool contains(List<int> pattern) {
      for (var i = 0; i <= raw.length - pattern.length; i++) {
        var same = true;
        for (var j = 0; j < pattern.length; j++) {
          if (raw[i + j] != pattern[j]) {
            same = false;
            break;
          }
        }
        if (same) return true;
      }
      return false;
    }

    if (loadForTest && declared) {
      await (FontLoader('RiaSansSplash')..addFont(Future.value(bytes))).load();
    }
    splashFontBundle = {
      'available': true,
      'declared': declared,
      'faceVerified':
          contains(face) ||
          contains([
            for (final c in face) ...[0, c],
          ]),
      'size': raw.length,
      'magic': String.fromCharCodes(raw.take(4)),
      'family': 'RiaSansSplash',
      'path': 'assets/fonts/RiaSans-Regular.otf',
      'loadedForTest': loadForTest && declared,
    };
  } catch (_) {
    splashFontBundle = {
      'available': false,
      'declared': false,
      'faceVerified': false,
      'reason':
          'Target alias missing in this baseline; capture remains available.',
    };
  }
  return splashFontBundle;
}

Map<String, Object?> splashMeasure(Element root) {
  final splash = splashFind<SplashScreen>(root);
  if (splash == null) return {'active': false};
  final all = splashElements(splash);
  final logo =
      splashKey(splash, 'splash-a01-logo') ??
      all.where((e) => e.widget is SvgPicture).first;
  final tag =
      splashKey(splash, 'splash-a01-tagline') ??
      all
          .where(
            (e) =>
                e.widget is RichText &&
                (e.findRenderObject() as RenderParagraph).text.toPlainText() ==
                    '저장한 정보를 다시 볼 순간으로',
          )
          .first;
  final para = tag.widget is RichText ? tag : splashFind<RichText>(tag)!;
  final p = para.findRenderObject()! as RenderParagraph;
  final style = (p.text as TextSpan).style!;
  final svg = logo.widget is SvgPicture ? logo : splashFind<SvgPicture>(logo)!;
  final svgWidget = svg.widget as SvgPicture;
  Element? group = splashKey(splash, 'splash-a01-group');
  if (group == null) {
    logo.visitAncestorElements((e) {
      if (e.widget is Column && splashElements(e).contains(tag)) {
        group = e;
        return false;
      }
      return true;
    });
  }
  final scaffold = splashFind<Scaffold>(splash)!;
  final mq = MediaQuery.of(splash), window = MediaQuery.sizeOf(splash);
  final scroll = splashFind<Scrollable>(splash);
  final position = scroll is StatefulElement && scroll.state is ScrollableState
      ? (scroll.state as ScrollableState).position
      : null;
  final outerBoxes = <Map<String, Object?>>[];
  splash.visitAncestorElements((e) {
    if (e.widget is ColoredBox) {
      outerBoxes.add({
        'bounds': splashRect(splashBox(e)),
        'color': _color((e.widget as ColoredBox).color),
      });
    }
    return true;
  });
  for (final e in all.where((e) => e.widget is ColoredBox)) {
    outerBoxes.add({
      'bounds': splashRect(splashBox(e)),
      'color': _color((e.widget as ColoredBox).color),
    });
  }
  final frame = splashRect(splashBox(scaffold));
  return {
    'active': true,
    'window': {'width': window.width, 'height': window.height},
    'frame': frame,
    'safeTop': mq.viewPadding.top,
    'safeBottom': mq.viewPadding.bottom,
    'safeCenterY':
        (mq.viewPadding.top + window.height - mq.viewPadding.bottom) / 2,
    'textScale': mq.textScaler.scale(16) / 16,
    'logo': {
      'asset': svgWidget.bytesLoader is SvgAssetLoader
          ? (svgWidget.bytesLoader as SvgAssetLoader).assetName
          : null,
      'bounds': splashRect(splashBox(svg)),
      'unfiltered': svgWidget.colorFilter == null,
    },
    'group': group == null ? null : splashRect(splashBox(group!)),
    'tagline': {
      'text': p.text.toPlainText(),
      'bounds': splashRect(splashBox(para)),
      'fontFamily': style.fontFamily,
      'fontSize': style.fontSize,
      'fontWeight': style.fontWeight?.value,
      'letterSpacing': style.letterSpacing,
      'height': style.height,
      'color': _color(style.color),
      'scaledFontSize': p.textScaler.scale(style.fontSize!),
      'textAlign': p.textAlign.name,
      'maxLines': p.maxLines,
      'overflow': p.overflow.name,
    },
    'scaffoldColor': _color((scaffold.widget as Scaffold).backgroundColor),
    'outerColoredBoxes': outerBoxes,
    'viewport': splashKey(splash, 'splash-a01-viewport') == null
        ? null
        : splashRect(splashBox(splashKey(splash, 'splash-a01-viewport')!)),
    'scrollOffset': position?.pixels ?? 0,
    'maxScrollExtent': position?.maxScrollExtent ?? 0,
    'textFittedBoxCount': all
        .where(
          (e) =>
              e.widget is FittedBox &&
              splashElements(e).any((e) => e.widget is RichText),
        )
        .length,
    'fakeIndicatorCount': all
        .where(
          (e) => e.widget is EntryHomeIndicator || e.widget is EntryStatusBar,
        )
        .length,
    'fontBundle': Map<String, Object?>.from(splashFontBundle),
  };
}

Map<String, Object?> splashJudgment(Map<String, Object?> m) {
  if (m['active'] != true) {
    return {
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': false,
      'styleFailures': ['A01 not present'],
      'layoutFailures': ['A01 not present'],
      'assetFailures': ['A01 not present'],
    };
  }
  bool near(Object? v, num t, [double d = .2]) =>
      v is num && (v - t).abs() <= d;
  final sf = <String>[], lf = <String>[], af = <String>[];
  void check(List<String> f, bool p, String name) {
    if (!p) f.add(name);
  }

  final t = m['tagline'] as Map,
      g = m['group'] is Map ? m['group'] as Map : const {},
      logo = m['logo'] as Map,
      l = logo['bounds'] as Map,
      b = t['bounds'] as Map,
      window = m['window'] as Map,
      font = m['fontBundle'] as Map;
  check(
    sf,
    t['fontFamily'] == 'RiaSansSplash' &&
        near(t['fontSize'], 16) &&
        t['fontWeight'] == 400 &&
        near(t['letterSpacing'] ?? 0, 0) &&
        t['height'] == null &&
        t['color'] == '0xFFC5A544' &&
        near(t['scaledFontSize'], 16),
    'tagline exact RiaSansSplash16 Regular AUTO tracking0 mainDeep',
  );
  check(
    lf,
    near(l['width'], 148.771) && near(l['height'], 50),
    'logo148.771x50',
  );
  check(
    lf,
    near((b['top'] as num) - (l['bottom'] as num), 16),
    'logo-to-tagline16',
  );
  check(
    lf,
    near(g['width'], 232) && near(g['height'], 89),
    'natural group232x89',
  );
  final scroll = m['scrollOffset'] as num;
  if ((m['maxScrollExtent'] as num) == 0) {
    check(
      lf,
      near(
        g['top'] is num ? (g['top'] as num) + (g['height'] as num) / 2 : null,
        (m['safeCenterY'] as num) - 23.5 - scroll,
      ),
      'safe centerY-23.5',
    );
  }
  check(
    lf,
    near(
      g['left'] is num ? (g['left'] as num) + (g['width'] as num) / 2 : null,
      (window['width'] as num) / 2 + .5,
    ),
    'window centerX+.5',
  );
  check(
    lf,
    m['textFittedBoxCount'] == 0 && m['fakeIndicatorCount'] == 0,
    'no text shrink or fakeOS',
  );
  final fullYellow =
      (m['scaffoldColor'] == '0xFFFFD75C' &&
          near((m['frame'] as Map)['width'], window['width'])) ||
      (m['outerColoredBoxes'] as List).any(
        (v) =>
            v['color'] == '0xFFFFD75C' &&
            near(v['bounds']['width'], window['width']) &&
            near(v['bounds']['height'], window['height']),
      );
  check(lf, fullYellow, 'full window yellow incl393 gutters');
  check(
    af,
    logo['asset'] == 'assets/figma/splash-a01-logo.svg' &&
        logo['unfiltered'] == true,
    'splash-scoped original white-sparkle logo',
  );
  check(
    af,
    font['available'] == true &&
        font['declared'] == true &&
        font['faceVerified'] == true &&
        font['size'] == 535616 &&
        font['magic'] == 'OTTO',
    'registered exact Ria Sans font bytes',
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
