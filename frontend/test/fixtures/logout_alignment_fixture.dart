// J03 shared render oracle. Runtime discovery keeps the frozen fixture runnable
// on the baseline where no confirmation screen exists. No production requests.
import 'dart:convert';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../support/account_preview.dart' as account;

const logoutImageAsset = 'assets/figma/logout-illustration.png';
const logoutBackAsset = 'assets/icons/detail-back.svg';
const logoutTitle = '정말 로그아웃 하시겠어요?';
const logoutDescription = '기기에 저장된 로그인 정보가 삭제됩니다.';
List<Element> logoutElements(Element root) {
  final result = <Element>[root];
  root.visitChildren((e) => result.addAll(logoutElements(e)));
  return result;
}

Element? logoutScreen(Element root) => logoutElements(root)
    .where((e) => e.widget.runtimeType.toString() == 'LogoutConfirmationScreen')
    .firstOrNull;
Element? logoutKey(Element root, String key) => logoutElements(
  root,
).where((e) => e.widget.key == ValueKey(key)).firstOrNull;
Element? logoutFind<T extends Widget>(Element root) =>
    logoutElements(root).where((e) => e.widget is T).firstOrNull;
Element? logoutText(Element root, String text) => logoutElements(root)
    .where(
      (e) =>
          e.findRenderObject() is RenderParagraph &&
          (e.findRenderObject() as RenderParagraph).text.toPlainText() ==
              text &&
          e.widget is RichText,
    )
    .firstOrNull;
Rect logoutBox(Element e) {
  final r = e.findRenderObject()! as RenderBox;
  return MatrixUtils.transformRect(
    r.getTransformTo(null),
    Offset.zero & r.size,
  );
}

Map<String, double> logoutRect(Rect r) => {
  'left': r.left,
  'top': r.top,
  'right': r.right,
  'bottom': r.bottom,
  'width': r.width,
  'height': r.height,
};
String? _color(Color? color) => color == null
    ? null
    : '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
Map<String, Object?> _paragraph(Element? element) {
  if (element == null) return {};
  final e = element.widget is RichText
      ? element
      : logoutFind<RichText>(element);
  if (e == null) return {};
  final p = e.findRenderObject()! as RenderParagraph,
      s = ((e.findRenderObject()! as RenderParagraph).text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': logoutRect(logoutBox(e)),
    'fontFamily': s.fontFamily,
    'fontSize': s.fontSize,
    'scaledFontSize': s.fontSize == null
        ? null
        : p.textScaler.scale(s.fontSize!),
    'fontWeight': s.fontWeight?.value,
    'letterSpacing': s.letterSpacing,
    'height': s.height,
    'color': _color(s.color),
    'maxLines': p.maxLines,
    'didExceedMaxLines': p.didExceedMaxLines,
    'overflow': p.overflow.name,
  };
}

Map<String, Object?> _asset(Element? e) {
  if (e == null) return {};
  final svg = e.widget is SvgPicture ? e : logoutFind<SvgPicture>(e);
  if (svg != null) {
    final w = svg.widget as SvgPicture;
    return {
      'asset': w.bytesLoader is SvgAssetLoader
          ? (w.bytesLoader as SvgAssetLoader).assetName
          : null,
      'bounds': logoutRect(logoutBox(svg)),
      'unfiltered': w.colorFilter == null,
    };
  }
  final image = e.widget is Image ? e : logoutFind<Image>(e);
  if (image == null) return {};
  final w = image.widget as Image;
  ImageProvider p = w.image;
  if (p is ResizeImage) p = p.imageProvider;
  return {
    'asset': p is AssetImage ? p.assetName : null,
    'bounds': logoutRect(logoutBox(image)),
    'fit': w.fit?.name,
  };
}

Map<String, Object?> _button(Element? root) {
  if (root == null) return {};
  final node = root.widget is ButtonStyleButton
      ? root
      : logoutFind<ButtonStyleButton>(root);
  final w = node?.widget as ButtonStyleButton?;
  final style = w?.style;
  final ink = logoutFind<InkWell>(root)?.widget as InkWell?;
  final gesture = logoutFind<GestureDetector>(root)?.widget as GestureDetector?;
  final enabled = w != null
      ? w.onPressed != null
      : ink != null
      ? ink.onTap != null
      : gesture?.onTap != null;
  final material = logoutFind<Material>(root)?.widget as Material?;
  final bg = style?.backgroundColor?.resolve({}) ?? material?.color;
  final shape = style?.shape?.resolve({});
  final border = style?.side?.resolve({});
  return {
    'bounds': logoutRect(logoutBox(root)),
    'enabled': enabled,
    'background': _color(bg),
    'borderColor': _color(border?.color),
    'borderWidth': border?.width,
    'radius': shape is RoundedRectangleBorder
        ? (shape.borderRadius as BorderRadius).topLeft.x
        : null,
  };
}

ScrollPosition? logoutPosition(Element root) {
  final s = logoutScreen(root);
  if (s == null) return null;
  final e = logoutFind<Scrollable>(s);
  return e is StatefulElement && e.state is ScrollableState
      ? (e.state as ScrollableState).position
      : null;
}

Future<Map<String, Object?>> logoutInspectFonts({
  bool loadForTest = false,
}) async {
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
    await (FontLoader('PretendardDetail')..addFont(Future.value(bytes))).load();
    final base = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      base.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await base.load();
  }
  return {
    'available': bytes.lengthInBytes > 0,
    'declared': declared,
    'bytes': bytes.lengthInBytes,
    'family': 'PretendardDetail',
    'path': 'assets/fonts/Pretendard-Bold.otf',
  };
}

Map<String, Object?> logoutMeasure(Element root) {
  final screen = logoutScreen(root);
  if (screen == null) return {'active': false, 'missingConfirmation': true};
  final media = MediaQuery.of(screen), scaffold = logoutFind<Scaffold>(screen)!;
  final styles = <String, Object?>{};
  for (final role in {
    'header': '계정 관리',
    'title': logoutTitle,
    'description': logoutDescription,
    'confirm': '확인',
    'cancel': '취소',
  }.entries) {
    styles[role.key] = _paragraph(logoutText(screen, role.value));
  }
  final bounds = <String, Object?>{'screen': logoutRect(logoutBox(scaffold))};
  for (final pair in {
    'header': 'logout-header',
    'backHit': 'logout-back-hit',
    'body': 'logout-body',
    'footer': 'logout-footer',
  }.entries) {
    final e = logoutKey(screen, pair.value);
    if (e != null) bounds[pair.key] = logoutRect(logoutBox(e));
  }
  final busy = (screen.widget as dynamic).busy as bool;
  final position = logoutPosition(root);
  return {
    'active': true,
    'styles': styles,
    'bounds': bounds,
    'assets': {
      'back': _asset(logoutKey(screen, 'logout-back-image')),
      'illustration': _asset(logoutKey(screen, 'logout-illustration')),
    },
    'buttons': {
      'confirm': _button(logoutKey(screen, 'logout-confirm')),
      'cancel': _button(logoutKey(screen, 'logout-cancel')),
    },
    'authBusy': busy,
    'topSafeArea': media.viewPadding.top,
    'bottomSafeArea': media.viewPadding.bottom,
    'textScale': media.textScaler.scale(1),
    'scrollOffset': position?.pixels ?? 0,
    'maxScrollExtent': position?.maxScrollExtent ?? 0,
  };
}

Map<String, Object?> logoutJudgment(
  Map<String, Object?> m, {
  bool requireScreen = true,
}) {
  final sf = <String>[], lf = <String>[], af = <String>[];
  if (m['active'] != true) {
    return {
      'stylePassed': !requireScreen,
      'layoutPassed': !requireScreen,
      'assetPassed': !requireScreen,
      'styleFailures': [if (requireScreen) 'J03 screen absent'],
      'layoutFailures': <String>[],
      'assetFailures': <String>[],
    };
  }
  bool near(Object? x, num y) => x is num && (x - y).abs() < .18;
  void n(Object? x, num y, String why) {
    if (!near(x, y)) lf.add('$why: $x != $y');
  }

  final s = m['styles'] as Map,
      b = m['bounds'] as Map,
      a = m['assets'] as Map,
      buttons = m['buttons'] as Map;
  void style(
    String role,
    num size,
    int weight,
    num tracking,
    String color, {
    String family = 'Pretendard',
    double? height,
  }) {
    final p = s[role] as Map;
    if (p['fontFamily'] != family ||
        !near(p['fontSize'], size) ||
        !near(p['scaledFontSize'], size) ||
        p['fontWeight'] != weight ||
        !near(p['letterSpacing'], tracking) ||
        p['color'] != color ||
        (height == null ? p['height'] != null : !near(p['height'], height))) {
      sf.add('$role: $p');
    }
  }

  style('header', 18, 600, -.45, '0xFF000000');
  style(
    'title',
    24,
    700,
    -.6,
    '0xFF1A1A1A',
    family: 'PretendardDetail',
    height: 1.6,
  );
  style('description', 16, 500, -.4, '0xFF767676', height: 1.5);
  style('confirm', 16, 600, 0, '0xFFFFD75C', height: 22 / 16);
  style('cancel', 16, 600, 0, '0xFF1A1A1A', height: 22 / 16);
  final frame = b['screen'] as Map,
      header = b['header'] as Map?,
      body = b['body'] as Map?,
      back = b['backHit'] as Map?;
  if (header == null || body == null || back == null) {
    lf.add('Missing header/body/back bounds');
  } else {
    n(header['height'], 64, 'header height');
    n(header['top'], m['topSafeArea'] as num, 'top safe once');
    n(back['width'], 48, 'back tap width');
    n(back['height'], 48, 'back tap height');
    n(body['top'], header['bottom'] as num, 'body follows header');
    final svg = a['back']['bounds'] as Map?;
    if (svg != null) {
      n(svg['width'], 24, 'back width');
      n(svg['height'], 24, 'back height');
      n((svg['left'] as num) - (frame['left'] as num), 16, 'back left');
      n((svg['top'] as num) + 12, (header['top'] as num) + 32.5, 'back center');
      n(
        (s['header']['bounds']['left'] as num) - (svg['right'] as num),
        8,
        'header title gap',
      );
    }
    final title = s['title']['bounds'] as Map,
        desc = s['description']['bounds'] as Map;
    if (near(m['scrollOffset'], 0)) {
      n(
        (title['top'] as num) - (header['bottom'] as num),
        16,
        'body title top',
      );
    }
    n((title['left'] as num) - (frame['left'] as num), 16, 'title left');
    n((desc['top'] as num) - (title['bottom'] as num), 8, 'description gap');
    if (s['title']['maxLines'] != null ||
        s['title']['overflow'] == 'ellipsis') {
      sf.add('Title must wrap naturally');
    }
    for (final role in ['title', 'description']) {
      final p = s[role]['bounds'] as Map;
      if ((p['right'] as num) > (frame['right'] as num) - 15.8) {
        lf.add('$role horizontal overflow');
      }
    }
    final image = a['illustration']['bounds'] as Map?;
    if (image == null) {
      lf.add('Missing illustration');
    } else {
      n(image['width'], 224, 'image width');
      n(image['height'], 224, 'image height');
      n(
        (image['left'] as num) + 112,
        (frame['left'] as num) + (frame['width'] as num) / 2 + .5,
        'image center x',
      );
      if ((frame['height'] as num) >= 700 && near(m['scrollOffset'], 0)) {
        n(
          (image['top'] as num) + 112,
          (m['topSafeArea'] as num) +
              ((frame['height'] as num) -
                      (m['topSafeArea'] as num) -
                      (m['bottomSafeArea'] as num)) /
                  2 -
              8,
          'image safe center',
        );
      }
      if ((image['top'] as num) < (desc['bottom'] as num) + 15.8) {
        lf.add('Description image gap below16');
      }
      if ((m['maxScrollExtent'] as num) > 0 &&
          near(m['scrollOffset'], m['maxScrollExtent'] as num)) {
        n(
          (body['bottom'] as num) - (image['bottom'] as num),
          24,
          'scroll bottom24',
        );
      }
    }
  }
  for (final role in ['confirm', 'cancel']) {
    final button = buttons[role] as Map, rect = button['bounds'] as Map?;
    if (rect == null) {
      lf.add('Missing $role button');
      continue;
    }
    n(rect['height'], 48, '$role height');
    n(rect['width'], (frame['width'] as num) - 32, '$role width');
    n((rect['left'] as num) - (frame['left'] as num), 16, '$role left');
    if (button['enabled'] == (m['authBusy'] == true)) {
      lf.add('$role busy lock mismatch');
    }
  }
  if (buttons['confirm']['bounds'] != null &&
      buttons['cancel']['bounds'] != null) {
    final confirm = buttons['confirm']['bounds'] as Map,
        cancel = buttons['cancel']['bounds'] as Map;
    n((cancel['top'] as num) - (confirm['bottom'] as num), 8, 'button gap');
    n(
      (frame['bottom'] as num) - (cancel['bottom'] as num),
      32 + (m['bottomSafeArea'] as num),
      'OS bottom once plus32',
    );
    if (body != null &&
        (body['bottom'] as num) > (confirm['top'] as num) + .18) {
      lf.add('Body overlaps footer');
    }
  }
  if (a['back']['asset'] != logoutBackAsset ||
      a['back']['unfiltered'] != true) {
    af.add('Exact original back');
  }
  if (a['illustration']['asset'] != logoutImageAsset ||
      a['illustration']['fit'] != 'cover') {
    af.add('Exact original illustration cover');
  }
  return {
    'stylePassed': sf.isEmpty,
    'layoutPassed': lf.isEmpty,
    'assetPassed': af.isEmpty,
    'styleFailures': sf,
    'layoutFailures': lf,
    'assetFailures': af,
  };
}

class LogoutMemoryStorage extends ApiSessionStorage {
  ApiSession? value = const ApiSession(
    accessToken: 'fixture-access',
    refreshToken: 'fixture-refresh',
    expiresIn: 3600,
    refreshExpiresIn: 86400,
  );
  int clears = 0, writes = 0;
  bool failClear = false;
  @override
  Future<ApiSession?> read() async => value;
  @override
  Future<void> write(ApiSession next) async {
    value = next;
    writes++;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (failClear) throw StateError('Fixture session clear failure');
    value = null;
  }
}

class LogoutServer extends account.AccountServer {
  LogoutServer(super.kind);
}
