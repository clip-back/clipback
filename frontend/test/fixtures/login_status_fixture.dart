// Baseline-compatible actual rendered probes for Figma A03/A04.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'splash_alignment_fixture.dart' as b;

Map<String, Object?> statusMeasure(Element root, String kind) {
  final prefix = kind == 'progress' ? 'login-progress' : 'login-cancelled';
  final screen = b.splashKey(root, '$prefix-screen');
  if (screen == null) return {'active': false, 'kind': kind};
  final mq = MediaQuery.of(screen);
  Map<String, double>? box(String key) {
    final e = b.splashKey(screen, key);
    return e == null ? null : b.splashRect(b.splashBox(e));
  }

  Map<String, Object?>? role(String key) {
    final e = b.splashKey(screen, key);
    if (e == null) return null;
    final rich = b.splashFind<RichText>(e);
    if (rich == null) return null;
    final p = rich.findRenderObject()! as RenderParagraph,
        s = (p.text as TextSpan).style!;
    return {
      'text': p.text.toPlainText(),
      'bounds': b.splashRect(b.splashBox(rich)),
      'font': s.fontFamily,
      'size': s.fontSize,
      'weight': s.fontWeight?.value,
      'spacing': s.letterSpacing,
      'height': s.height,
      'color': s.color?.toARGB32(),
      'scaledSize': p.textScaler.scale(s.fontSize!),
      'maxLines': p.maxLines,
      'overflow': p.overflow.name,
      'align': p.textAlign.name,
    };
  }

  Map<String, Object?>? asset(String key) {
    final e = b.splashKey(screen, key);
    if (e == null) return null;
    final image = e.widget is Image ? e : b.splashFind<Image>(e),
        svg = e.widget is SvgPicture ? e : b.splashFind<SvgPicture>(e);
    return {
      'bounds': b.splashRect(b.splashBox(e)),
      if (image != null)
        'asset': ((image.widget as Image).image as AssetImage).assetName,
      if (image != null) 'fit': (image.widget as Image).fit?.name,
      if (svg != null)
        'asset': ((svg.widget as SvgPicture).bytesLoader as SvgAssetLoader)
            .assetName,
    };
  }

  final scroll = b.splashFind<Scrollable>(
    b.splashKey(screen, '$prefix-scroll') ?? screen,
  );
  final pos = scroll is StatefulElement && scroll.state is ScrollableState
      ? (scroll.state as ScrollableState).position
      : null;
  Map<String, Object?>? button(String name) {
    final e = b.splashKey(screen, '$prefix-$name');
    if (e == null) return null;
    final material = b.splashFind<Material>(e)?.widget as Material?;
    final shape = material?.shape;
    return {
      'color': material?.color?.toARGB32(),
      'radius': shape is RoundedRectangleBorder
          ? shape.borderRadius.resolve(TextDirection.ltr).topLeft.x
          : null,
      'borderColor': shape is RoundedRectangleBorder
          ? shape.side.color.toARGB32()
          : null,
      'borderWidth': shape is RoundedRectangleBorder ? shape.side.width : null,
    };
  }

  final scaffold = b.splashFind<Scaffold>(screen)!;
  return {
    'active': true,
    'kind': kind,
    'frame': b.splashRect(b.splashBox(scaffold)),
    'safeTop': mq.viewPadding.top,
    'safeBottom': mq.viewPadding.bottom,
    'textScale': mq.textScaler.scale(16) / 16,
    'background': (scaffold.widget as Scaffold).backgroundColor?.toARGB32(),
    'header': box('login-status-header'),
    'backHit': box('login-status-back'),
    'headerTitle': role('login-status-heading'),
    'backAsset': asset('login-status-back-image'),
    'title': role('$prefix-title'),
    'description': role('$prefix-description'),
    'group': box('$prefix-group'),
    'illustration': asset('$prefix-illustration'),
    'image': asset('$prefix-image'),
    'dots': asset('$prefix-dots'),
    'primaryPaint': button('primary'),
    'guestPaint': button('guest'),
    'primary': box('$prefix-primary'),
    'guest': box('$prefix-guest'),
    'primaryLabel': role('$prefix-primary-label'),
    'guestLabel': role('$prefix-guest-label'),
    'viewport': box('$prefix-scroll'),
    'scrollOffset': pos?.pixels,
    'maxScrollExtent': pos?.maxScrollExtent,
  };
}

Map<String, Object?> statusJudgment(Map<String, Object?> m) {
  final style = <String>[], layout = <String>[], assets = <String>[];
  if (m['active'] != true) {
    return {
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': false,
      'styleFailures': ['target absent'],
      'layoutFailures': ['target absent'],
      'assetFailures': ['target absent'],
    };
  }
  final progress = m['kind'] == 'progress';
  Map v(String key) => (m[key] as Map?) ?? {};
  Map rect(String key) => v(key)['bounds'] as Map? ?? v(key);
  double n(Map r, String k) => (r[k] as num?)?.toDouble() ?? double.nan;
  void near(String label, double a, double target, [double tolerance = .15]) {
    if ((a - target).abs() > tolerance || !a.isFinite) {
      layout.add('$label $a != $target');
    }
  }

  void role(
    String key,
    String text,
    String font,
    double size,
    int weight,
    double spacing,
    int color,
    double? height,
  ) {
    final r = v(key);
    if (r['text'] != text ||
        r['font'] != font ||
        r['size'] != size ||
        r['weight'] != weight ||
        r['spacing'] != spacing ||
        r['color'] != color ||
        r['height'] != height ||
        r['scaledSize'] != size) {
      style.add('$key actual=$r');
    }
  }

  role('headerTitle', '처음으로', 'Pretendard', 18, 600, -.45, 0xff000000, null);
  role(
    'title',
    progress ? '로그인하고 있어요' : '로그인이 취소됐어요.',
    'PretendardDetail',
    24,
    700,
    -.6,
    0xff1a1a1a,
    1.6,
  );
  role(
    'description',
    progress ? '인증이 끝날 때까지\n잠시 기다려주세요' : '계속하려면 로그인 방법을 다시 선택해주세요.',
    'Pretendard',
    16,
    500,
    -.4,
    0xff767676,
    1.5,
  );
  final frame = rect('frame'),
      header = rect('header'),
      image = rect('illustration'),
      title = rect('title'),
      description = rect('description');
  final left = n(frame, 'left'),
      top = n(frame, 'top'),
      width = n(frame, 'width'),
      height = n(frame, 'height'),
      safeTop = (m['safeTop'] as num).toDouble(),
      safeBottom = (m['safeBottom'] as num).toDouble();
  near('header top', n(header, 'top'), top + safeTop);
  near('header height', n(header, 'height'), 64);
  if (n(rect('backHit'), 'height') < 48) layout.add('back hit under48');
  if (m['background'] != 0xfff5f5f5) style.add('background');
  if (v('backAsset')['asset'] != 'assets/icons/detail-back.svg') {
    assets.add('back original');
  }
  near('image width', n(image, 'width'), progress ? 224 : 110);
  near('image height', n(image, 'height'), progress ? 224 : 148);
  near(
    'image center',
    n(image, 'left') + n(image, 'width') / 2,
    left + width / 2 + .5,
  );
  near('title to description', n(description, 'top') - n(title, 'bottom'), 8);
  if (progress) {
    final group = rect('group');
    near('group width', n(group, 'width'), 224);
    if ((m['maxScrollExtent'] as num? ?? 0) == 0) {
      near(
        'group safe center',
        n(group, 'top') + n(group, 'height') / 2,
        top + safeTop + (height - safeTop - safeBottom) / 2 - 27,
      );
    }
    near('image to title', n(title, 'top') - n(image, 'bottom'), 0);
    near(
      'description to dots',
      n(rect('dots'), 'top') - n(description, 'bottom'),
      32,
    );
    near('dots width', n(rect('dots'), 'width'), 52);
    near('dots height', n(rect('dots'), 'height'), 12);
    if (v('illustration')['asset'] != 'assets/figma/logout-illustration.png' ||
        v('dots')['asset'] != 'assets/figma/home-initial-loading-dots.svg') {
      assets.add('progress originals');
    }
  } else {
    role(
      'primaryLabel',
      '다른 로그인 방법 선택',
      'Pretendard',
      16,
      600,
      0,
      0xffffd75c,
      22 / 16,
    );
    role(
      'guestLabel',
      '게스트로 시작하기',
      'Pretendard',
      16,
      600,
      0,
      0xff1a1a1a,
      22 / 16,
    );
    final primary = rect('primary'), guest = rect('guest');
    final primaryPaint = v('primaryPaint'), guestPaint = v('guestPaint');
    if (primaryPaint['color'] != 0xff1a1a1a ||
        guestPaint['color'] != 0xffffffff ||
        primaryPaint['radius'] != 8.0 ||
        guestPaint['radius'] != 8.0 ||
        primaryPaint['borderWidth'] != 0.0 ||
        guestPaint['borderWidth'] != 1.0 ||
        guestPaint['borderColor'] != 0xff767676) {
      style.add('button paint');
    }
    final rendered = rect('image');
    near('crop width', n(rendered, 'width'), 110 * 1.7526);
    near('crop height', n(rendered, 'height'), 148 * 1.3031);
    near('crop left', n(rendered, 'left') - n(image, 'left'), -110 * .3763);
    near('crop top', n(rendered, 'top') - n(image, 'top'), -148 * .1386);
    near('title left', n(title, 'left'), left + 16);
    if ((m['scrollOffset'] as num? ?? 0) == 0) {
      near('title top', n(title, 'top'), n(header, 'bottom') + 16);
    }
    near(
      'description to image',
      n(image, 'top') - n(description, 'bottom'),
      80,
    );
    near('button gap', n(guest, 'top') - n(primary, 'bottom'), 8);
    near('footer bottom', n(guest, 'bottom'), top + height - safeBottom - 32);
    near('button left', n(primary, 'left'), left + 16);
    near('button width', n(primary, 'width'), width - 32);
    if (n(primary, 'height') < 48 || n(guest, 'height') < 48) {
      layout.add('button under48');
    }
    if (v('image')['asset'] != 'assets/figma/login-failure-illustration.png' ||
        v('image')['fit'] != 'fill') {
      assets.add('cancel crop original');
    }
  }
  return {
    'stylePassed': style.isEmpty,
    'layoutPassed': layout.isEmpty,
    'assetPassed': assets.isEmpty,
    'styleFailures': style,
    'layoutFailures': layout,
    'assetFailures': assets,
  };
}
