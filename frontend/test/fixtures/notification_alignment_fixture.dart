// C03 oracle. Runtime discovery compiles on 220f313's legacy notification sheet.
// No notification endpoint is invented: root data are the original three examples.
import 'dart:ui' as ui;
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/notification_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'notice_alignment_fixture.dart' as common;
import 'home_base_alignment_fixture.dart' as home;

const notificationExamples = <({String title, String time})>[
  (title: '오늘의 콘텐츠가 준비됐어요', time: '방금 전'),
  (title: '저장한 링크 요약이 완료됐어요', time: '10분 전'),
  (title: '다시 볼 콘텐츠를 추천해드려요', time: '어제'),
];
const notificationEmptyTitle = '아직 받은 알림이 없어요';
const notificationEmptyBody = '저장한 콘텐츠를\n다시 볼 때 알려드릴게요';
const notificationBackAsset = 'assets/icons/detail-back.svg';

List<Element> notificationElements(Element root) => common.noticeElements(root);
Element? notificationFind<T extends Widget>(Element root) =>
    common.noticeFind<T>(root);
Element? notificationText(Element root, String text) =>
    common.noticeText(root, text);
Element? notificationKey(Element root, String key) =>
    common.noticeKey(root, key);
Element? notificationScreen(Element root) => notificationElements(root)
    .where((e) => e.widget.runtimeType.toString() == 'NotificationListScreen')
    .firstOrNull;
Rect notificationBox(Element e) => common.noticeBox(e);
Map<String, double> notificationRect(Rect r) => common.noticeRect(r);
ScrollPosition? notificationHomePosition(Element root, {bool recent = false}) =>
    home.homeBasePosition(root, recent: recent);

String? _color(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
Map<String, Object?> _paragraph(Element? e) {
  if (e == null) return {};
  final rich = e.widget is RichText ? e : notificationFind<RichText>(e);
  if (rich == null) return {};
  final p = rich.findRenderObject()! as RenderParagraph,
      s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': notificationRect(notificationBox(rich)),
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
    'softWrap': p.softWrap,
    'overflow': p.overflow.name,
    'didExceedMaxLines': p.didExceedMaxLines,
  };
}

Map<String, Object?> _asset(Element? e) {
  if (e == null) return {};
  final svg = e.widget is SvgPicture ? e : notificationFind<SvgPicture>(e);
  if (svg != null) {
    final w = svg.widget as SvgPicture;
    return {
      'asset': w.bytesLoader is SvgAssetLoader
          ? (w.bytesLoader as SvgAssetLoader).assetName
          : null,
      'bounds': notificationRect(notificationBox(svg)),
      'unfiltered': w.colorFilter == null,
    };
  }
  final image = e.widget is Image ? e : notificationFind<Image>(e);
  if (image == null) return {};
  final w = image.widget as Image;
  ImageProvider p = w.image;
  if (p is ResizeImage) p = p.imageProvider;
  return {
    'asset': p is AssetImage ? p.assetName : null,
    'bounds': notificationRect(notificationBox(image)),
    'fit': w.fit?.name,
  };
}

ScrollPosition? notificationPosition(Element root) {
  final target =
      notificationScreen(root) ?? notificationFind<NotificationSheet>(root);
  if (target == null) return null;
  final e = notificationFind<Scrollable>(target);
  return e is StatefulElement && e.state is ScrollableState
      ? (e.state as ScrollableState).position
      : null;
}

Map<String, Object?> notificationMeasure(Element root) {
  final screen = notificationScreen(root),
      sheet = notificationFind<NotificationSheet>(root),
      target = screen ?? sheet;
  if (target == null) return {'active': false};
  final full = screen != null,
      media = MediaQuery.of(target),
      pos = notificationPosition(root);
  final List<({String title, String time})> items = full
      ? [
          for (final dynamic x in (screen.widget as dynamic).items as List)
            (title: x.title as String, time: x.time as String),
        ]
      : notificationExamples;
  final bounds = <String, Object?>{};
  for (final entry in {
    'screen': full ? notificationFind<Scaffold>(target) : null,
    'header': notificationKey(target, 'notification-header'),
    'viewport': full
        ? notificationKey(target, 'notification-viewport')
        : notificationFind<SingleChildScrollView>(target),
    'backHit': notificationKey(target, 'notification-back-hit'),
    'settingsHit': notificationKey(target, 'notification-settings-hit'),
    'emptyGroup': notificationKey(target, 'notification-empty-group'),
    'emptyImage': notificationKey(target, 'notification-empty-image'),
    'emptyClip': notificationKey(target, 'notification-empty-clip'),
    'emptySource': notificationKey(target, 'notification-empty-source'),
  }.entries) {
    bounds[entry.key] = entry.value == null
        ? null
        : notificationRect(notificationBox(entry.value!));
  }
  final rows = <Map<String, Object?>>[];
  final legacyRows = notificationElements(
    target,
  ).where((e) => e.widget is NotificationRow).toList();
  for (var i = 0; i < items.length; i++) {
    final row = full
            ? notificationKey(target, 'notification-row-$i')
            : (i < legacyRows.length ? legacyRows[i] : null),
        title = full
            ? notificationKey(target, 'notification-title-$i')
            : notificationText(target, items[i].title),
        time = full
            ? notificationKey(target, 'notification-time-$i')
            : notificationText(target, items[i].time);
    final box = row == null
        ? null
        : notificationElements(row)
              .where(
                (e) =>
                    e.widget is DecoratedBox &&
                    (e.widget as DecoratedBox).decoration is BoxDecoration,
              )
              .firstOrNull;
    final decoration = box == null
        ? null
        : (box.widget as DecoratedBox).decoration as BoxDecoration;
    final container = row?.widget is Container
        ? row!.widget as Container
        : null;
    final colored = row == null ? null : notificationFind<ColoredBox>(row);
    rows.add({
      'index': i,
      'title': items[i].title,
      'time': items[i].time,
      'bounds': row == null ? null : notificationRect(notificationBox(row)),
      'titleStyle': _paragraph(title),
      'timeStyle': _paragraph(time),
      'fill': _color(
        container?.color ??
            decoration?.color ??
            (colored?.widget as ColoredBox?)?.color,
      ),
      'radius': decoration?.borderRadius
          ?.resolve(Directionality.of(target))
          .topLeft
          .x,
      'marker': _asset(notificationKey(target, 'notification-marker-$i')),
      'textCount': row == null
          ? 0
          : notificationElements(row).where((e) => e.widget is Text).length,
      'svgCount': row == null
          ? 0
          : notificationElements(
              row,
            ).where((e) => e.widget is SvgPicture).length,
      'interactiveChildren': row == null
          ? null
          : notificationElements(row)
                .where(
                  (e) =>
                      (e.widget is InkWell &&
                          (e.widget as InkWell).onTap != null) ||
                      (e.widget is GestureDetector &&
                          (e.widget as GestureDetector).onTap != null) ||
                      (e.widget is ButtonStyleButton &&
                          (e.widget as ButtonStyleButton).onPressed != null),
                )
                .length,
    });
  }
  final list = notificationFind<ListView>(target),
      padding = list == null
          ? null
          : (list.widget as ListView).padding?.resolve(Directionality.of(list));
  final emptyImage = notificationKey(target, 'notification-empty-image');
  final shadowElement = emptyImage == null
      ? null
      : notificationElements(emptyImage)
            .where(
              (e) =>
                  e.widget is DecoratedBox &&
                  (e.widget as DecoratedBox).decoration is BoxDecoration,
            )
            .firstOrNull;
  final shadows = shadowElement == null
      ? null
      : ((shadowElement.widget as DecoratedBox).decoration as BoxDecoration)
            .boxShadow;
  final shadowRoot = notificationKey(target, 'notification-empty-shadow'),
      translated = shadowRoot == null
          ? null
          : notificationFind<Transform>(shadowRoot),
      blurred = shadowRoot == null
          ? null
          : notificationFind<ImageFiltered>(shadowRoot),
      filtered = shadowRoot == null
          ? null
          : notificationFind<ColorFiltered>(shadowRoot);
  final transform = translated?.widget as Transform?,
      blur = blurred?.widget as ImageFiltered?,
      filter = filtered?.widget as ColorFiltered?;
  return {
    'active': true,
    'emptyShadowLayer': {
      'present': shadowRoot != null,
      'translationX': transform?.transform.storage[12],
      'translationY': transform?.transform.storage[13],
      'blur': blur?.imageFilter.toString(),
      'blurEnabled': blur?.enabled,
      'blurMatchesSigma1':
          blur?.imageFilter == ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
      'colorFilter': filter?.colorFilter.toString(),
      'black12SrcIn':
          filter?.colorFilter ==
          const ColorFilter.mode(Color(0x1F000000), BlendMode.srcIn),
      'asset': shadowRoot == null ? null : _asset(shadowRoot),
    },
    'emptyShadows': [
      for (final shadow in shadows ?? <BoxShadow>[])
        {
          'color': _color(shadow.color),
          'dx': shadow.offset.dx,
          'dy': shadow.offset.dy,
          'blur': shadow.blurRadius,
          'spread': shadow.spreadRadius,
        },
    ],
    'presentation': full ? 'fullScreen' : 'legacySheet',
    'empty': full && items.isEmpty,
    'items': [
      for (final item in items) {'title': item.title, 'time': item.time},
    ],
    'headerStyle': _paragraph(notificationText(target, '알림')),
    'bounds': bounds,
    'assets': {
      'back': _asset(notificationKey(target, 'notification-back-image')),
      'settings': _asset(
        notificationKey(target, 'notification-settings-image'),
      ),
      'empty': _asset(notificationKey(target, 'notification-empty-image')),
      'emptySource': _asset(
        notificationKey(target, 'notification-empty-source'),
      ),
    },
    'emptyTitleStyle': _paragraph(
      notificationKey(target, 'notification-empty-title'),
    ),
    'emptyBodyStyle': _paragraph(
      notificationKey(target, 'notification-empty-body'),
    ),
    'rows': rows,
    'bottomNavigationCount': notificationElements(
      target,
    ).where((e) => e.widget is ClipbackNavigationBar).length,
    'listPadding': padding == null
        ? null
        : {
            'left': padding.left,
            'top': padding.top,
            'right': padding.right,
            'bottom': padding.bottom,
          },
    'topSafeArea': media.viewPadding.top,
    'bottomSafeArea': media.viewPadding.bottom,
    'scrollOffset': pos?.pixels ?? 0,
    'maxScrollExtent': pos?.maxScrollExtent ?? 0,
    'textScale': media.textScaler.scale(1),
  };
}

Map<String, Object?> notificationJudgment(Map<String, Object?> m) {
  final sf = <String>[], lf = <String>[], af = <String>[];
  Map<String, Object?> result() => {
    'stylePassed': sf.isEmpty,
    'layoutPassed': lf.isEmpty,
    'assetPassed': af.isEmpty,
    'styleFailures': sf,
    'layoutFailures': lf,
    'assetFailures': af,
  };
  if (m['active'] != true) return result();
  if (m['presentation'] != 'fullScreen') {
    sf.add('C03 roles absent in baseline sheet');
    lf.add('Legacy modal lacks C03 fixed header/list');
    af.add('Legacy modal lacks C03 header assets');
    return result();
  }
  bool near(Object? x, num y) => x is num && (x - y).abs() < .22;
  void n(Object? x, num y, String why) {
    if (!near(x, y)) lf.add('$why: $x != $y');
  }

  void style(
    Map p,
    double size,
    int weight,
    double spacing,
    String color,
    String why, {
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
      sf.add('$why style: $p');
    }
  }

  final b = m['bounds'] as Map,
      header = b['header'] as Map?,
      viewport = b['viewport'] as Map?,
      frame = b['screen'] as Map?,
      back = (m['assets'] as Map)['back'] as Map,
      settings = (m['assets'] as Map)['settings'] as Map;
  if (header == null || viewport == null || frame == null) {
    lf.add('Missing C03 layout keys');
    return result();
  }
  n(header['height'], 64, 'header64');
  n(header['top'], m['topSafeArea'] as num, 'top safety once');
  n(viewport['top'], header['bottom'] as num, 'viewport starts after header');
  n(
    (frame['bottom'] as num) - (viewport['bottom'] as num),
    m['bottomSafeArea'] as num,
    'bottom safety once',
  );
  style(m['headerStyle'] as Map, 18, 600, -.45, '0xFF000000', 'header');
  final ht = (m['headerStyle'] as Map)['bounds'] as Map;
  n(
    (ht['top'] as num) + (ht['height'] as num) / 2,
    (header['top'] as num) + 32.5,
    'header center+.5',
  );
  for (final entry in {'back': back, 'settings': settings}.entries) {
    final r = entry.value['bounds'] as Map?;
    if (r == null) {
      af.add('Missing ${entry.key} SVG');
      continue;
    }
    n(r['width'], 24, '${entry.key}24');
    n(r['height'], 24, '${entry.key}24');
    n(
      (r['top'] as num) + 12,
      (header['top'] as num) + 32.5,
      '${entry.key} center+.5',
    );
  }
  if (back['asset'] != notificationBackAsset || back['unfiltered'] != true) {
    af.add('Original back SVG');
  }
  if (settings['asset'] != 'assets/figma/notification-settings.svg' ||
      settings['unfiltered'] != true) {
    af.add('Original notification settings SVG');
  }
  final br = back['bounds'] as Map?;
  if (br != null) {
    n((br['left'] as num) - (frame['left'] as num), 16, 'back left16');
    n((ht['left'] as num) - (br['right'] as num), 8, 'title gap8');
  }
  final sr = settings['bounds'] as Map?;
  if (sr != null) {
    n((frame['right'] as num) - (sr['right'] as num), 16, 'settings right16');
  }
  for (final pair in {'backHit': 48, 'settingsHit': 44}.entries) {
    final r = b[pair.key] as Map?;
    if (r == null) {
      lf.add('Missing ${pair.key}');
      continue;
    }
    n(r['width'], pair.value, '${pair.key}width');
    n(r['height'], pair.value, '${pair.key}height');
  }
  if (m['bottomNavigationCount'] != 0) lf.add('C03 has no bottom tabs');
  if (m['empty'] == true) {
    style(
      m['emptyTitleStyle'] as Map,
      24,
      700,
      -.6,
      '0xFF1A1A1A',
      'empty title',
      height: 1.6,
      family: 'PretendardDetail',
    );
    style(
      m['emptyBodyStyle'] as Map,
      16,
      500,
      -.4,
      '0xFF767676',
      'empty body',
      height: 1.5,
    );
    if ((m['emptyTitleStyle'] as Map)['text'] != notificationEmptyTitle ||
        (m['emptyBodyStyle'] as Map)['text'] != notificationEmptyBody) {
      sf.add('Exact empty copy');
    }
    final group = b['emptyGroup'] as Map?,
        image = b['emptyImage'] as Map?,
        title = (m['emptyTitleStyle'] as Map)['bounds'] as Map?,
        body = (m['emptyBodyStyle'] as Map)['bounds'] as Map?;
    if (group == null || image == null || title == null || body == null) {
      lf.add('Empty group boundary keys');
      return result();
    }
    if ((group['width'] as num) > 224.22) lf.add('Empty group max224');
    n(
      (group['left'] as num) + (group['width'] as num) / 2,
      (frame['left'] as num) + (frame['width'] as num) / 2 + .5,
      'empty center+.5',
    );
    final boxShadows = m['emptyShadows'] as List,
        shadow = m['emptyShadowLayer'] as Map;
    if (boxShadows.isNotEmpty) {
      af.add(
        'Transparent original must not get a filled rectangular box shadow',
      );
    }
    if (shadow['present'] != true) {
      af.add('Original alpha image shadow missing');
    } else {
      n(shadow['translationX'], 0, 'alpha shadow dx0');
      n(shadow['translationY'], 2, 'alpha shadow dy2');
      if (shadow['blurEnabled'] != true ||
          shadow['blurMatchesSigma1'] != true) {
        af.add('Original alpha shadow blur2 corresponds to sigma1');
      }
      if (shadow['black12SrcIn'] != true) {
        af.add('Original alpha shadow black12% srcIn');
      }
      if ((shadow['asset'] as Map?)?['asset'] !=
          'assets/figma/notification-empty-original.png') {
        af.add('Shadow uses exact original alpha image');
      }
    }
    final clip = b['emptyClip'] as Map?, source = b['emptySource'] as Map?;
    if (clip == null || source == null) {
      af.add('Missing exact empty crop clip/source');
    } else {
      n(clip['width'], 86, 'empty clip86');
      n(clip['height'], 100, 'empty clip100');
      n(source['width'], 86 * 1.6118, 'empty source crop width');
      n(source['height'], 100 * 1.3918, 'empty source crop height');
      n(
        (source['left'] as num) - (clip['left'] as num),
        86 * -.3072,
        'empty crop left',
      );
      n(
        (source['top'] as num) - (clip['top'] as num),
        100 * -.172,
        'empty crop top',
      );
    }
    n(image['width'], 86, 'empty86');
    n(image['height'], 100, 'empty100');
    n((title['top'] as num) - (image['bottom'] as num), 16, 'image-title16');
    n((body['top'] as num) - (title['bottom'] as num), 8, 'title-body8');
    if ((body['width'] as num) > 192.22) lf.add('Empty body max192');
    final offset = m['scrollOffset'] as num;
    final wanted = ((viewport['height'] as num) / 2 - 240).clamp(
      16,
      double.infinity,
    );
    n(
      (group['top'] as num) - (viewport['top'] as num) + offset,
      wanted,
      'empty top max16 V/2-240',
    );
    if (((m['assets'] as Map)['empty'] as Map)['asset'] !=
        'assets/figma/notification-empty-original.png') {
      af.add('Empty original asset missing');
    }
    if ((group['bottom'] as num) > (viewport['bottom'] as num) + .22 &&
        near(m['scrollOffset'], m['maxScrollExtent'] as num)) {
      lf.add('Empty group clipped at max scroll');
    }
  } else {
    final p = m['listPadding'] as Map?;
    if (p == null) {
      lf.add('List padding absent');
    } else {
      for (final side in ['left', 'top', 'right']) {
        n(p[side], 16, 'list ${side}16');
      }
      n(p['bottom'], 24, 'list bottom24');
    }
    final rows = m['rows'] as List;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i] as Map,
          r = row['bounds'] as Map?,
          title = row['titleStyle'] as Map,
          time = row['timeStyle'] as Map;
      style(title, 16, 500, -.4, '0xFF1A1A1A', 'row title');
      style(time, 12, 500, -.3, '0xFFB5BDC3', 'row time');
      if (title['maxLines'] != null ||
          title['softWrap'] != true ||
          title['overflow'] == 'ellipsis' ||
          title['didExceedMaxLines'] == true) {
        sf.add('Full title wraps');
      }
      if (time['maxLines'] != null ||
          time['softWrap'] != true ||
          time['overflow'] == 'ellipsis' ||
          time['didExceedMaxLines'] == true) {
        sf.add('Full time wraps');
      }
      if (row['fill'] != '0xFFFFFFFF' || !near(row['radius'], 8)) {
        lf.add('White rounded row8');
      }
      if (row['interactiveChildren'] != 0) lf.add('Read-only rows');
      if (row['textCount'] != 2 || row['svgCount'] != 1) {
        lf.add('Only original title/time/marker in row');
      }
      if (r == null) {
        lf.add('Missing row$i');
        continue;
      }
      if ((r['height'] as num) < 75.78) lf.add('Row min76');
      n((r['left'] as num) - (frame['left'] as num), 16, 'row outer16');
      n(r['width'], (frame['width'] as num) - 32, 'row available width');
      if (i == 0 && near(m['scrollOffset'], 0)) {
        n((r['top'] as num) - (viewport['top'] as num), 16, 'first row top16');
      }
      if (i > 0 && rows[i - 1]['bounds'] != null) {
        n(
          (r['top'] as num) - (rows[i - 1]['bounds']['bottom'] as num),
          8,
          'row gap8',
        );
      }
      final tr = title['bounds'] as Map?, tm = time['bounds'] as Map?;
      if (tr == null || tm == null) {
        lf.add('Missing title/time');
        continue;
      }
      n((tr['top'] as num) - (r['top'] as num), 16, 'title top16');
      n((tm['top'] as num) - (r['top'] as num), 16, 'time top16');
      n((r['right'] as num) - (tm['right'] as num), 16, 'time right16');
      if ((tm['width'] as num) > 64.22) lf.add('Time max64');
      if ((tr['right'] as num) > (tm['left'] as num) - 7.78 ||
          (tr['bottom'] as num) > (r['bottom'] as num) - 15.78 ||
          (tm['bottom'] as num) > (r['bottom'] as num) - 15.78) {
        lf.add('Row content inside padded bounds');
      }
      final marker = row['marker'] as Map, mr = marker['bounds'] as Map?;
      if (marker['asset'] != 'assets/figma/notification-marker.svg' ||
          marker['unfiltered'] != true) {
        af.add('Original yellow marker SVG');
      }
      if (mr == null) {
        af.add('Original yellow circle missing');
      } else {
        n(mr['width'], 19, 'circle19');
        n(mr['height'], 19, 'circle19');
        n((mr['left'] as num) - (r['left'] as num), 16, 'marker left16');
        n((mr['top'] as num) - (r['top'] as num), 16, 'marker top16');
        n((tr['left'] as num) - (mr['right'] as num), 16, 'circle-title16');
      }
      if (i == rows.length - 1 &&
          (m['maxScrollExtent'] as num) > 0 &&
          near(m['scrollOffset'], m['maxScrollExtent'] as num)) {
        n((viewport['bottom'] as num) - (r['bottom'] as num), 24, 'end24');
      }
    }
  }
  return result();
}

Future<Map<String, Object?>> notificationLoadFonts({
  bool loadForTest = false,
}) => common.noticeLoadFonts(loadForTest: loadForTest);

class NotificationMemoryStorage extends common.NoticeMemoryStorage {}

class NotificationSocial extends common.NoticeSocial {}

class NotificationServer extends common.NoticeServer {
  NotificationServer(super.kind);
}
