// Baseline-compatible A05 probes. An absent target is a red judgment, not a
// substitute screen or a reason to block actual A02+SnackBar capture.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'splash_alignment_fixture.dart' as base;

List<Element> failureElements(Element e) => base.splashElements(e);
Element? failureKey(Element e, String key) => base.splashKey(e, key);
Element? failureFind<T extends Widget>(Element e) => base.splashFind<T>(e);
Rect failureBox(Element e) => base.splashBox(e);
Map<String, double> failureRect(Rect r) => base.splashRect(r);
String? _color(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

Map<String, Object?> failureMeasure(Element root) {
  final screen = failureKey(root, 'login-failure-screen');
  if (screen == null) return {'active': false};
  final mq = MediaQuery.of(screen), view = View.of(screen);
  Map<String, Object?>? paragraph(String name) {
    final e = failureKey(screen, 'login-failure-$name');
    if (e == null) return null;
    final text = e.widget is RichText ? e : failureFind<RichText>(e);
    if (text == null) return null;
    final p = text.findRenderObject()! as RenderParagraph,
        style = (p.text as TextSpan).style!;
    final scaleAncestors = <Element>[];
    text.visitAncestorElements((a) {
      if (identical(a, screen)) return false;
      if (a.widget is FittedBox) scaleAncestors.add(a);
      return true;
    });
    return {
      'text': p.text.toPlainText(),
      'bounds': failureRect(failureBox(text)),
      'fontFamily': style.fontFamily,
      'fontSize': style.fontSize,
      'fontWeight': style.fontWeight?.value,
      'letterSpacing': style.letterSpacing,
      'height': style.height,
      'color': _color(style.color),
      'scaledFontSize': style.fontSize == null
          ? null
          : p.textScaler.scale(style.fontSize!),
      'textAlign': p.textAlign.name,
      'maxLines': p.maxLines,
      'overflow': p.overflow.name,
      'textScalingFittedBoxAncestors': scaleAncestors.length,
    };
  }

  Map<String, Object?>? asset(String name) {
    final e = failureKey(screen, 'login-failure-$name');
    if (e == null) return null;
    final image = e.widget is Image ? e : failureFind<Image>(e),
        svg = e.widget is SvgPicture ? e : failureFind<SvgPicture>(e);
    return {
      'bounds': failureRect(failureBox(e)),
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

  final scroll = failureFind<Scrollable>(
    failureKey(screen, 'login-failure-scroll') ?? screen,
  );
  final position = scroll is StatefulElement && scroll.state is ScrollableState
      ? (scroll.state as ScrollableState).position
      : null;

  Map<String, Object?>? materialButton(String name) {
    final key = failureKey(screen, 'login-failure-$name');
    if (key == null) return null;
    final b = failureFind<FilledButton>(key),
        material = failureFind<Material>(key);
    if (b == null || material == null) return null;
    final widget = b.widget as FilledButton,
        paint = material.widget as Material,
        shape = paint.shape;
    final padding = widget.style?.padding
        ?.resolve(<WidgetState>{})
        ?.resolve(TextDirection.ltr);
    return {
      'background': _color(paint.color),
      'borderColor': shape is RoundedRectangleBorder
          ? _color(shape.side.color)
          : null,
      'borderWidth': shape is RoundedRectangleBorder ? shape.side.width : null,
      'radius': shape is RoundedRectangleBorder
          ? shape.borderRadius.resolve(TextDirection.ltr).topLeft.x
          : null,
      'padding': padding == null
          ? null
          : {
              'left': padding.left,
              'top': padding.top,
              'right': padding.right,
              'bottom': padding.bottom,
            },
      'onPressedPresent': widget.onPressed != null,
    };
  }

  final cardElement = failureKey(screen, 'login-failure-error-card');
  final cardContainer = cardElement?.widget is Container
      ? cardElement!.widget as Container
      : null;
  final cardDecoration = cardContainer?.decoration,
      cardPadding = cardContainer?.padding?.resolve(TextDirection.ltr);
  final scaffold = failureFind<Scaffold>(screen);
  return {
    'active': true,
    'window': {
      'width': view.physicalSize.width / view.devicePixelRatio,
      'height': view.physicalSize.height / view.devicePixelRatio,
    },
    'frame': failureRect(failureBox(scaffold ?? screen)),
    'safeTop': mq.viewPadding.top,
    'safeBottom': mq.viewPadding.bottom,
    'textScale': mq.textScaler.scale(16) / 16,
    'scrollOffset': position?.pixels ?? 0,
    'maxScrollExtent': position?.maxScrollExtent ?? 0,
    'safeAreaCount': failureElements(
      screen,
    ).where((e) => e.widget is SafeArea).length,
    for (final name in [
      'header',
      'back-hit',
      'body',
      'scroll',
      'illustration-clip',
      'error-card',
      'footer',
      'methods',
      'guest',
      'contact-hit',
    ])
      name: failureKey(screen, 'login-failure-$name') == null
          ? null
          : failureRect(failureBox(failureKey(screen, 'login-failure-$name')!)),
    for (final name in [
      'header-title',
      'title',
      'description',
      'status',
      'notice',
      'contact-prefix',
      'contact-label',
    ])
      name: paragraph(name),
    'methods-label': paragraph('methods'),
    'guest-label': paragraph('guest'),
    for (final name in ['back-image', 'illustration-image', 'warning'])
      name: asset(name),
    'cardDecoration': {
      'background': cardDecoration is BoxDecoration
          ? _color(cardDecoration.color)
          : null,
      'radius': cardDecoration is BoxDecoration
          ? cardDecoration.borderRadius?.resolve(TextDirection.ltr).topLeft.x
          : null,
      'padding': cardPadding == null
          ? null
          : {
              'left': cardPadding.left,
              'top': cardPadding.top,
              'right': cardPadding.right,
              'bottom': cardPadding.bottom,
            },
    },
    'buttonDecorations': {
      'methods': materialButton('methods'),
      'guest': materialButton('guest'),
    },
    'fakeOSWidgetCount': failureElements(screen)
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
    'illustrationClipBehavior':
        failureFind<Stack>(
              failureKey(screen, 'login-failure-illustration-clip')!,
            )?.widget
            is Stack
        ? (failureFind<Stack>(
                    failureKey(screen, 'login-failure-illustration-clip')!,
                  )!.widget
                  as Stack)
              .clipBehavior
              .name
        : null,
    'scaffoldColor': scaffold == null
        ? null
        : _color((scaffold.widget as Scaffold).backgroundColor),
  };
}

Map<String, Object?> failureJudgment(
  Map<String, Object?> m, {
  required String kind,
}) {
  final styles = <String>[], layout = <String>[], assets = <String>[];
  if (m['active'] != true) {
    return {
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': false,
      'styleFailures': ['A05 absent on baseline'],
      'layoutFailures': ['A05 absent on baseline'],
      'assetFailures': ['A05 absent on baseline'],
    };
  }
  void check(bool ok, String why, List<String> errors) {
    if (!ok) errors.add(why);
  }

  bool near(num? a, num b, [double tolerance = .8]) =>
      a != null && (a - b).abs() < tolerance;
  final specs =
      <String, (String, String, double, int, double, double?, String)>{
        'header-title': (
          '처음으로',
          'Pretendard',
          18,
          600,
          -.45,
          null,
          '0xFF000000',
        ),
        'title': (
          '로그인하지 못했어요.',
          'PretendardDetail',
          24,
          700,
          -.6,
          1.6,
          '0xFF1A1A1A',
        ),
        'description': (
          '연결 상태를 확인한 뒤 다시 시도해주세요.',
          'Pretendard',
          16,
          500,
          -.4,
          1.5,
          '0xFF767676',
        ),
        'status': (
          kind == 'http' ? '응답 상태 : HTTP 503' : '응답 상태를 확인할 수 없어요',
          'Pretendard',
          14,
          500,
          -.35,
          1.5,
          '0xFF767676',
        ),
        'notice': (
          '계속해서 로그인이 되지 않으면 문의해주세요.',
          'Pretendard',
          14,
          500,
          -.35,
          1.5,
          '0xFF767676',
        ),
        'methods-label': (
          '다른 로그인 방법 선택',
          'Pretendard',
          16,
          600,
          0,
          22 / 16,
          '0xFFFFD75C',
        ),
        'guest-label': (
          '게스트로 시작하기',
          'Pretendard',
          16,
          600,
          0,
          22 / 16,
          '0xFF1A1A1A',
        ),
        'contact-prefix': (
          '계속 로그인에 실패한다면?',
          'Pretendard',
          15,
          500,
          0,
          null,
          '0xFF767676',
        ),
        'contact-label': ('문의하기', 'Pretendard', 15, 600, 0, null, '0xFF484848'),
      };
  for (final entry in specs.entries) {
    final p = m[entry.key] as Map?, s = entry.value;
    check(
      p != null &&
          p['text'] == s.$1 &&
          p['fontFamily'] == s.$2 &&
          p['fontSize'] == s.$3 &&
          p['fontWeight'] == s.$4 &&
          near(p['letterSpacing'] as num?, s.$5) &&
          p['height'] == s.$6 &&
          p['color'] == s.$7 &&
          p['scaledFontSize'] == s.$3 &&
          p['textScalingFittedBoxAncestors'] == 0,
      '${entry.key} actual RenderParagraph style/content',
      styles,
    );
  }
  final frame = m['frame'] as Map,
      header = m['header'] as Map?,
      body = m['body'] as Map?,
      title = (m['title'] as Map?)?['bounds'] as Map?,
      desc = (m['description'] as Map?)?['bounds'] as Map?,
      clip = m['illustration-clip'] as Map?,
      image = (m['illustration-image'] as Map?)?['bounds'] as Map?,
      card = m['error-card'] as Map?,
      footer = m['footer'] as Map?,
      methods = m['methods'] as Map?,
      guest = m['guest'] as Map?,
      contact = m['contact-hit'] as Map?;
  check(
    m['safeAreaCount'] == 1 && m['textScale'] == 1,
    'one actual SafeArea/1x',
    layout,
  );
  check(
    header != null &&
        near(header['height'] as num?, 64) &&
        near(header['top'] as num?, m['safeTop'] as num),
    'header64 after actual top safe area',
    layout,
  );
  if (header != null && title != null && desc != null) {
    check(
      near(title['left'] as num?, (frame['left'] as num) + 16),
      'title left16',
      layout,
    );
    check(
      near((desc['top'] as num) - (title['bottom'] as num), 8),
      'title/description8',
      layout,
    );
    if (near(m['scrollOffset'] as num?, 0)) {
      check(
        near((title['top'] as num) - (header['bottom'] as num), 16),
        'title start16 atscroll0',
        layout,
      );
    }
  }
  if (clip != null && desc != null) {
    check(
      near(clip['width'] as num?, 110) && near(clip['height'] as num?, 148),
      'image slot110x148',
      layout,
    );
    check(
      near(
        (clip['left'] as num) + 55,
        (frame['left'] as num) + (frame['width'] as num) / 2 + .5,
      ),
      'image center+.5',
      layout,
    );
    check(
      near((clip['top'] as num) - (desc['bottom'] as num), 80),
      'description→image80',
      layout,
    );
  }
  if (clip != null && image != null) {
    check(
      near(image['width'] as num?, 110 * 1.7526) &&
          near(image['height'] as num?, 148 * 1.3031) &&
          near(image['left'] as num?, (clip['left'] as num) - 110 * .3763) &&
          near(image['top'] as num?, (clip['top'] as num) - 148 * .1386),
      'exact original image crop coefficients',
      layout,
    );
  }
  if (card != null && clip != null) {
    check(
      near((card['top'] as num) - (clip['bottom'] as num), 25) &&
          near(card['left'] as num?, (frame['left'] as num) + 24) &&
          near(card['width'] as num?, (frame['width'] as num) - 48) &&
          (card['height'] as num) >= 102.9,
      'card gap25/x24/width/min103',
      layout,
    );
  }
  if (footer != null && methods != null && guest != null && contact != null) {
    check(
      near(methods['height'] as num?, 48) &&
          near(guest['height'] as num?, 48) &&
          near((guest['top'] as num) - (methods['bottom'] as num), 8),
      'button48 and gap8',
      layout,
    );
    check(
      near(methods['left'] as num?, (frame['left'] as num) + 16) &&
          near(methods['width'] as num?, (frame['width'] as num) - 32),
      'buttons side16',
      layout,
    );
    check(
      near(contact['height'] as num?, 44) &&
          near((contact['top'] as num) - (guest['bottom'] as num), 3),
      'contact44 after gap3',
      layout,
    );
    check(
      near(
        (frame['bottom'] as num) - (contact['bottom'] as num),
        19 + (m['safeBottom'] as num),
      ),
      'footer19 + OS once',
      layout,
    );
    check(
      body != null && near(body['bottom'] as num?, footer['top'] as num),
      'body ends above fixedfooter',
      layout,
    );
  }

  check(
    m['illustrationClipBehavior'] == 'hardEdge',
    'actual image clipped to110x148',
    layout,
  );
  final cardPaint = m['cardDecoration'] as Map,
      cardPad = cardPaint['padding'] as Map?,
      buttons = m['buttonDecorations'] as Map;
  check(
    m['scaffoldColor'] == '0xFFF5F5F5' && m['fakeOSWidgetCount'] == 0,
    'background F5F5F5/no fake OS',
    styles,
  );
  check(
    cardPaint['background'] == '0xFFE4E4E4' &&
        cardPaint['radius'] == 8 &&
        cardPad?['left'] == 16 &&
        cardPad?['right'] == 18 &&
        cardPad?['top'] == 16 &&
        cardPad?['bottom'] == 16,
    'errorcard actual background radius padding',
    styles,
  );
  for (final name in ['methods', 'guest']) {
    final b = buttons[name] as Map?;
    check(
      b != null &&
          b['background'] ==
              (name == 'methods' ? '0xFF1A1A1A' : '0xFFFFFFFF') &&
          b['radius'] == 8 &&
          b['onPressedPresent'] == true &&
          (name == 'methods' ||
              (b['borderColor'] == '0xFF767676' && b['borderWidth'] == 1)),
      '$name actual Material paint',
      styles,
    );
  }
  final back = (m['back-image'] as Map?), warning = (m['warning'] as Map?);
  if (back != null && header != null) {
    final b = back['bounds'] as Map,
        h = m['back-hit'] as Map,
        t = (m['header-title'] as Map)['bounds'] as Map;
    check(
      near(b['width'] as num?, 24) &&
          near(b['height'] as num?, 24) &&
          near(b['left'] as num?, (frame['left'] as num) + 16) &&
          near((b['top'] as num) + 12, (header['top'] as num) + 32.5) &&
          near((t['left'] as num) - (b['right'] as num), 8) &&
          (h['width'] as num) >= 48 &&
          near(h['height'] as num?, 48),
      'header exact icon/gap/hit48',
      layout,
    );
  }
  if (warning != null && card != null) {
    final b = warning['bounds'] as Map,
        status = (m['status'] as Map)['bounds'] as Map,
        notice = (m['notice'] as Map)['bounds'] as Map;
    check(
      near(b['width'] as num?, 18) &&
          near(b['height'] as num?, 18) &&
          near(b['left'] as num?, (card['left'] as num) + 16) &&
          near((status['left'] as num) - (b['right'] as num), 4) &&
          near((notice['top'] as num) - (status['bottom'] as num), 8) &&
          near(notice['left'] as num?, (card['left'] as num) + 16) &&
          (card['bottom'] as num) - (notice['bottom'] as num) >= 15.9,
      'warning18/statusgap4/noticegap8/padding',
      layout,
    );
  }
  if (guest != null) {
    final label = (m['contact-label'] as Map)['bounds'] as Map,
        prefix = (m['contact-prefix'] as Map)['bounds'] as Map;
    check(
      near((label['top'] as num) - (guest['bottom'] as num), 16) &&
          near(
            (frame['bottom'] as num) -
                (m['safeBottom'] as num) -
                (label['bottom'] as num),
            32,
          ) &&
          near((label['left'] as num) - (prefix['right'] as num), 8),
      'contact actual glyph gaps16/32/8',
      layout,
    );
  }
  check(
    back?['asset'] == 'assets/icons/detail-back.svg' &&
        back?['unfiltered'] == true,
    'exact unchanged back SVG',
    assets,
  );
  check(
    (m['illustration-image'] as Map?)?['asset'] ==
        'assets/figma/login-failure-illustration.png',
    'exact original illustration PNG',
    assets,
  );
  check(
    warning?['asset'] == 'assets/figma/login-failure-alert.svg' &&
        warning?['unfiltered'] == true,
    'exact original alert SVG',
    assets,
  );
  return {
    'stylePassed': styles.isEmpty,
    'layoutPassed': layout.isEmpty,
    'assetPassed': assets.isEmpty,
    'styleFailures': styles,
    'layoutFailures': layout,
    'assetFailures': assets,
  };
}
