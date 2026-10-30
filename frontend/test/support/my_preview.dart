// J01 fixture: actual ClipbackApp with in-process HTTP/session doubles. No
// OAuth, production persistence, real permissions or physical-device proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/models/app_info.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'archive_all_preview.dart' as e01;

const myPhase = String.fromEnvironment('MY_PHASE', defaultValue: 'before');
const myAssets = {
  'settings': 'assets/icons/archive-settings.svg',
  'background': 'assets/icons/my-avatar-background.svg',
  'character': 'assets/figma/my-avatar-character.png',
  'profileArrow': 'assets/icons/chevron-right.svg',
  'divider': 'assets/icons/my-stats-divider.svg',
  'menuArrow': 'assets/icons/my-menu-chevron.svg',
};
const myAppInfo = AppInfo(version: '0.2.0', buildNumber: '6');
const myMember = AppUser(
  name: '정지윤',
  providerLabel: 'kakao, apple 계정 연동 중',
  joinedAt: '2026.10.18',
  savedContentCount: 150,
  revisitedContentCount: 231,
);
const myGuest = AppUser(
  name: '게스트',
  providerLabel: '게스트 계정',
  joinedAt: '2026.10.18',
  savedContentCount: 0,
  revisitedContentCount: 0,
);

List<Element> _elements(Element e) => e01.archiveAllElements(e);
Element? _find<T extends Widget>(Element e) => e01.archiveAllFind<T>(e);
Element? _key(Element e, String k) => e01.archiveAllKey(e, k);
Element? _text(Element e, String t) => e01.archiveAllText(e, t);
Rect _box(Element e) {
  final r = e.findRenderObject()! as RenderBox;
  return MatrixUtils.transformRect(
    r.getTransformTo(null),
    Offset.zero & r.size,
  );
}

Map<String, double> _rect(Rect r) => {
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
Element? _ancestor(Element e, bool Function(Widget) predicate) {
  Element? found;
  e.visitAncestorElements((v) {
    if (predicate(v.widget)) {
      found = v;
      return false;
    }
    return true;
  });
  return found;
}

Map<String, Object?> _paragraph(Element e) {
  final p = e.findRenderObject()! as RenderParagraph;
  final s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': _rect(_box(e)),
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
    'overflow': p.overflow.name,
    'didExceedMaxLines': p.didExceedMaxLines,
  };
}

Map<String, Object?> _asset(Element? root) {
  if (root == null) return {};
  final svg = root.widget is SvgPicture ? root : _find<SvgPicture>(root);
  if (svg != null) {
    final w = svg.widget as SvgPicture;
    return {
      'bounds': _rect(_box(svg)),
      'asset': w.bytesLoader is SvgAssetLoader
          ? (w.bytesLoader as SvgAssetLoader).assetName
          : null,
      'unfiltered': w.colorFilter == null,
      'localWidth': (svg.findRenderObject()! as RenderBox).size.width,
      'localHeight': (svg.findRenderObject()! as RenderBox).size.height,
    };
  }
  final image = root.widget is Image ? root : _find<Image>(root);
  if (image != null) {
    final w = image.widget as Image;
    ImageProvider p = w.image;
    if (p is ResizeImage) p = p.imageProvider;
    return {
      'bounds': _rect(_box(image)),
      'asset': p is AssetImage ? p.assetName : null,
      'fit': w.fit?.name,
    };
  }
  return {'bounds': _rect(_box(root)), 'asset': null};
}

ScrollPosition? _position(Element root) {
  final list = _find<ListView>(root);
  final e = list == null ? null : _find<Scrollable>(list);
  return e == null
      ? null
      : (e as StatefulElement).state is ScrollableState
      ? ((e).state as ScrollableState).position
      : null;
}

Map<String, Object?> _surface(Element root) {
  final e = _elements(root)
      .where(
        (e) =>
            e.widget is Container &&
            (e.widget as Container).decoration is BoxDecoration,
      )
      .firstOrNull;
  if (e == null) {
    final material = _find<Material>(root);
    final w = material?.widget as Material?;
    return {
      'bounds': _rect(_box(material ?? root)),
      'fill': _color(w?.color),
      'radius': (w?.borderRadius as BorderRadius?)?.topLeft.x,
    };
  }
  final d = (e.widget as Container).decoration! as BoxDecoration;
  return {
    'bounds': _rect(_box(e)),
    'fill': _color(d.color),
    'radius': (d.borderRadius as BorderRadius?)?.topLeft.x,
  };
}

/// Shared oracle used by real-font widget tests and the native actual-app run.
/// It measures laid-out paragraphs and transformed SVG rectangles, not guessed
/// font metrics, selection bounds, or painted glyph-ink overhang.
Map<String, Object?> myMeasure(Element root) {
  final screen = _find<MyScreen>(root);
  if (screen == null) return {'active': false};
  final user = (screen.widget as MyScreen).user;
  final appInfo = (screen.widget as MyScreen).appInfo;
  final header = _find<MyPageTopBar>(screen)!,
      profile = _find<MyProfileRow>(screen)!;
  final stats = _find<MyStatsStrip>(screen)!, list = _find<ListView>(screen)!;
  final styles = <String, Object?>{},
      bounds = <String, Object?>{},
      assets = <String, Object?>{};
  styles['header'] = _paragraph(_text(header, '마이페이지')!);
  styles['name'] = _paragraph(_text(profile, user.name)!);
  styles['account'] = _paragraph(_text(profile, user.providerLabel)!);
  final settings =
      _key(header, 'my-header-settings') ?? _find<SvgIconButton>(header)!;
  // PhoneFrame may center a 375px scaffold inside a wider native window. The
  // header/card insets are relative to that scaffold, not the outer window.
  bounds['screen'] = _rect(_box(_find<Scaffold>(screen)!));
  bounds['header'] = _rect(_box(header));
  bounds['settingsHit'] = _rect(_box(settings));
  bounds['viewport'] = _rect(_box(list));
  final material = _find<Material>(profile)!;
  bounds['profile'] = _rect(_box(material));
  final profileMaterial = material.widget as Material;
  bounds['profileSurface'] = {
    'bounds': _rect(_box(material)),
    'fill': _color(profileMaterial.color),
    'radius': (profileMaterial.borderRadius as BorderRadius?)?.topLeft.x,
  };
  bounds['stats'] = _surface(stats);
  assets['settings'] = _asset(
    _key(header, 'my-header-settings-image') ?? settings,
  );
  final oldImage = _find<Image>(profile)!;
  final avatar =
      _key(profile, 'my-avatar') ??
      _ancestor(
        oldImage,
        (w) => w is Container && w.constraints?.maxWidth == 46,
      )!;
  bounds['avatar'] = _rect(_box(avatar));
  final clip =
      _key(profile, 'my-avatar-character-clip') ?? _find<ClipOval>(profile);
  if (clip != null) bounds['avatarClip'] = _rect(_box(clip));
  assets['background'] = _asset(_key(profile, 'my-avatar-background'));
  assets['character'] = _asset(
    _key(profile, 'my-avatar-character-source') ?? oldImage,
  );
  assets['profileArrow'] = _asset(
    _key(profile, 'my-profile-arrow') ??
        _elements(profile).where((e) => e.widget is SvgIcon).lastOrNull,
  );
  assets['divider'] = _asset(_key(stats, 'my-stats-divider-source'));
  if (_key(stats, 'my-stats-divider') case final divider?) {
    bounds['divider'] = _rect(_box(divider));
  }
  final sections = <Map<String, Object?>>[];
  for (final e in _elements(screen).where((e) => e.widget is MySectionHeader)) {
    final w = e.widget as MySectionHeader;
    sections.add({
      'title': w.title,
      'bounds': _rect(_box(e)),
      'style': _paragraph(_text(e, w.title)!),
    });
  }
  final metrics = <Map<String, Object?>>[];
  for (final (label, value) in [
    ('저장한 콘텐츠', user.savedContentCount?.toString() ?? '—'),
    ('다시 본 콘텐츠', user.revisitedContentCount?.toString() ?? '—'),
  ]) {
    final labelElement = _text(stats, label)!;
    final values =
        _elements(stats)
            .where(
              (element) =>
                  element.widget is Text &&
                  (element.widget as Text).data == value,
            )
            .toList()
          ..sort(
            (a, b) => (_box(a).center.dx - _box(labelElement).center.dx)
                .abs()
                .compareTo(
                  (_box(b).center.dx - _box(labelElement).center.dx).abs(),
                ),
          );
    metrics.add({
      'bounds': _rect(_box(labelElement)),
      'label': _paragraph(labelElement),
      'value': _paragraph(values.first),
    });
  }
  final groups = <Map<String, Object?>>[];
  for (final g in _elements(screen).where((e) => e.widget is MyListGroup)) {
    final rows = <Map<String, Object?>>[];
    for (final e in _elements(g).where((e) => e.widget is MyListTile)) {
      final w = e.widget as MyListTile;
      final arrow = _key(e, 'my-menu-arrow-${w.title}');
      rows.add({
        'title': w.title,
        'bounds': _rect(_box(e)),
        'style': _paragraph(_text(e, w.title)!),
        if (w.trailingText != null)
          'version': _paragraph(_text(e, w.trailingText!)!),
        if (w.trailingText == null)
          'arrow': _asset(
            _key(e, 'my-menu-arrow-image-${w.title}') ?? _find<SvgIcon>(e),
          ),
        if (arrow != null) 'arrowSlot': _rect(_box(arrow)),
      });
    }
    groups.add({'surface': _surface(g), 'rows': rows});
  }
  final p = _position(screen), media = MediaQuery.of(screen);
  return {
    'active': true,
    'styles': styles,
    'bounds': bounds,
    'assets': assets,
    'sections': sections,
    'metrics': metrics,
    'groups': groups,
    'user': {
      'name': user.name,
      'providerLabel': user.providerLabel,
      'savedCount': user.savedContentCount,
      'reopenedCount': user.revisitedContentCount,
      'appVersion': appInfo == null ? '-' : 'ver. ${appInfo.version}',
    },
    'scrollOffset': p?.pixels ?? 0,
    'maxScrollExtent': p?.maxScrollExtent ?? 0,
    'bodyPadding': {
      'top': ((list.widget as ListView).padding! as EdgeInsets).top,
      'bottom': ((list.widget as ListView).padding! as EdgeInsets).bottom,
    },
    'actualBodyPadding': (list.widget as ListView).padding.toString(),
    'topSafeArea': media.viewPadding.top,
    'textScale': media.textScaler.scale(1),
  };
}

Map<String, Object?> myJudgment(Map<String, Object?> m) {
  if (m['active'] != true) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'assetPassed': true,
      'styleFailures': <String>[],
      'layoutFailures': <String>[],
      'assetFailures': <String>[],
    };
  }
  final style = <String>[], layout = <String>[], asset = <String>[];
  final s = m['styles'] as Map, b = m['bounds'] as Map, a = m['assets'] as Map;
  bool near(Object? x, num y) => x is num && (x - y).abs() < .18;
  void n(Object? x, num y, String why) {
    if (!near(x, y)) layout.add('$why: $x != $y');
  }

  void p(Map? t, num size, int weight, num spacing, String color, String name) {
    if (t == null ||
        t['fontFamily'] != 'Pretendard' ||
        !near(t['fontSize'], size) ||
        !near(t['scaledFontSize'], size) ||
        t['fontWeight'] != weight ||
        !near(t['letterSpacing'], spacing) ||
        t['color'] != color ||
        t['height'] != null) {
      style.add('$name style: $t');
    }
  }

  p(s['header'] as Map?, 18, 600, -.45, '0xFF000000', 'header');
  p(s['name'] as Map?, 16, 600, -.4, '0xFF000000', 'name');
  final user = m['user'] as Map;
  final ac = s['account'] as Map;
  if (ac['text'] != user['providerLabel'] ||
      ac['fontSize'] != 12 ||
      ac['maxLines'] != 1 ||
      ac['overflow'] != 'ellipsis') {
    style.add('account raw text/style changed');
  }
  for (final sec in m['sections'] as List) {
    p(
      sec['style'] as Map,
      16,
      600,
      -.4,
      '0xFF1A1A1A',
      'section ${sec['title']}',
    );
    n(sec['bounds']['height'], 44, 'section height');
  }
  final metrics = m['metrics'] as List;
  for (final v in metrics) {
    p(v['label'] as Map, 14, 500, -.35, '0xFFFFF3CE', 'metric label');
    p(v['value'] as Map, 18, 500, -.45, '0xFFFFD75C', 'metric value');
    n(
      (v['value']['bounds']['top'] as num) -
          (v['label']['bounds']['bottom'] as num),
      8,
      'metric gap',
    );
    n(
      (v['label']['bounds']['left'] as num) +
          (v['label']['bounds']['width'] as num) / 2,
      (v['bounds']['left'] as num) + (v['bounds']['width'] as num) / 2,
      'metric label center',
    );
  }
  if (metrics.length == 2) {
    n(
      metrics[0]['bounds']['width'],
      metrics[1]['bounds']['width'],
      'equal metric columns',
    );
  }
  final groups = m['groups'] as List, names = <String>[];
  for (final g in groups) {
    n(g['surface']['radius'], 8, 'menu radius');
    for (final r in g['rows']) {
      names.add(r['title'] as String);
      p(r['style'] as Map, 14, 500, -.35, '0xFF000000', 'menu ${r['title']}');
      n(r['bounds']['height'], 41, 'menu row height');
      n(
        (r['style']['bounds']['left'] as num) - (r['bounds']['left'] as num),
        16,
        'menu left pad',
      );
      if (r['version'] != null) {
        p(r['version'] as Map, 14, 400, -.35, '0xFF767676', 'version');
        if (r['version']['text'] != user['appVersion'] || r['arrow'] != null) {
          style.add('version data or arrow');
        }
      } else {
        final slot = r['arrowSlot'] as Map?;
        if (slot == null) {
          layout.add('missing menu logical slot');
        } else {
          n(slot['width'], 5, 'menu slot width');
          n(slot['height'], 10, 'menu slot height');
          n(
            (r['bounds']['right'] as num) - (slot['right'] as num),
            16,
            'menu right pad',
          );
        }
        final image = r['arrow'] as Map;
        if (image['asset'] != myAssets['menuArrow'] ||
            image['unfiltered'] != true) {
          asset.add('menu original ${r['title']}');
        }
        n(image['localWidth'], 6.66667, 'menu original SVG width');
        n(image['localHeight'], 11.6667, 'menu original SVG height');
      }
    }
  }
  if (names.join('|') != '리마인드 설정|카테고리 관리|앱 권한|공지사항|문의하기|앱 버전') {
    style.add('approved menu order: $names');
  }
  final header = b['header'] as Map,
      screen = b['screen'] as Map,
      hit = b['settingsHit'] as Map,
      profile = b['profile'] as Map,
      avatar = b['avatar'] as Map,
      clip = b['avatarClip'] as Map?,
      stats = b['stats'] as Map;
  n(header['height'], 64, 'header height');
  n(
    (s['header']['bounds']['left'] as num) - (screen['left'] as num),
    16,
    'header title left',
  );
  n(
    (s['header']['bounds']['top'] as num) +
        (s['header']['bounds']['height'] as num) / 2,
    (header['top'] as num) + 32.5,
    'header title center',
  );
  n(hit['width'], 44, 'settings hit width');
  n(hit['height'], 44, 'settings hit height');
  n(
    (screen['right'] as num) - (a['settings']['bounds']['right'] as num),
    16,
    'settings image right',
  );
  n(a['settings']['bounds']['width'], 24, 'settings SVG width');
  n(a['settings']['bounds']['height'], 24, 'settings SVG height');
  n(
    (a['settings']['bounds']['top'] as num) + 12,
    (header['top'] as num) + 32.5,
    'settings center',
  );
  n(profile['height'], 78, 'profile height');
  n(b['profileSurface']['radius'], 8, 'profile radius');
  n((m['bodyPadding'] as Map)['top'], 8, 'body padding top');
  n((m['bodyPadding'] as Map)['bottom'], 24, 'body padding bottom');
  n((profile['left'] as num) - (screen['left'] as num), 16, 'profile left');
  n(profile['width'], (screen['width'] as num) - 32, 'profile width');
  if (near(m['scrollOffset'], 0)) {
    n(
      (profile['top'] as num) - (header['bottom'] as num),
      8,
      'body top padding',
    );
  }
  n(avatar['width'], 46, 'avatar width');
  n(avatar['height'], 46, 'avatar height');
  n(
    (avatar['left'] as num) - (profile['left'] as num),
    16,
    'profile inner left',
  );
  n(
    (s['name']['bounds']['left'] as num) - (avatar['right'] as num),
    8,
    'avatar text gap',
  );
  n(
    (ac['bounds']['top'] as num) - (s['name']['bounds']['bottom'] as num),
    4,
    'account gap',
  );
  if (clip == null) {
    layout.add('missing character clip');
  } else {
    n(clip['width'], 28.927, 'character clip width');
    n(clip['height'], 32.141, 'character clip height');
    n(
      (clip['left'] as num) - (avatar['left'] as num),
      7.96,
      'character clip left',
    );
    n(
      (clip['top'] as num) - (avatar['top'] as num),
      6.19,
      'character clip top',
    );
    final image = a['character']['bounds'] as Map;
    n(image['width'], 28.927 * 1.5323, 'character crop width');
    n(image['height'], 32.141 * 1.3621, 'character crop height');
    n(
      (image['left'] as num) - (clip['left'] as num),
      28.927 * -.2301,
      'character crop left',
    );
    n(
      (image['top'] as num) - (clip['top'] as num),
      32.141 * -.1452,
      'character crop top',
    );
  }
  n(stats['bounds']['height'], 80, 'stats height');
  n(stats['radius'], 8, 'stats radius');
  n(a['profileArrow']['bounds']['width'], 24, 'profile arrow width');
  n(a['profileArrow']['bounds']['height'], 24, 'profile arrow height');
  n(
    (profile['right'] as num) - (a['profileArrow']['bounds']['right'] as num),
    8,
    'profile inner right',
  );
  final div = b['divider'] as Map?;
  if (div == null) {
    layout.add('missing stats SVG divider');
  } else {
    n(div['width'], 1, 'divider painted width');
    n(div['height'], 48, 'divider painted height');
  }
  n(a['divider']['localWidth'], 48, 'divider source width');
  n(a['divider']['localHeight'], 1, 'divider source height');
  for (final role in [
    'settings',
    'background',
    'character',
    'profileArrow',
    'divider',
  ]) {
    final actual = a[role] as Map;
    if (actual['asset'] != myAssets[role] ||
        role != 'character' && actual['unfiltered'] != true) {
      asset.add('$role exact local source missing/filtered');
    }
  }
  final lastRows = (groups.last as Map)['rows'] as List;
  if (near(m['scrollOffset'], m['maxScrollExtent'] as num)) {
    n(
      (b['viewport']['bottom'] as num) -
          (lastRows.last['bounds']['bottom'] as num),
      (m['maxScrollExtent'] as num) > 0
          ? 24
          : (b['viewport']['bottom'] as num) -
                (lastRows.last['bounds']['bottom'] as num),
      'body bottom padding',
    );
  }
  // Only content intersecting the viewport is compared with its row. Offscreen
  // scroll content is not a clipping failure; one-line ellipsis is intentional.
  for (final g in groups) {
    for (final r in g['rows']) {
      final t = r['style']['bounds'] as Map, row = r['bounds'] as Map;
      if ((row['bottom'] as num) > (b['viewport']['top'] as num) &&
          (row['top'] as num) < (b['viewport']['bottom'] as num) &&
          ((t['top'] as num) < (row['top'] as num) - .18 ||
              (t['bottom'] as num) > (row['bottom'] as num) + .18)) {
        layout.add('menu text outside row');
      }
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

class MyServer {
  MyServer(this.kind);
  final String kind;
  AppUser get expected => kind == 'guest' ? myGuest : myMember;
  final requests = <Map<String, Object?>>[], unexpected = <String>[];
  final records = e01.archiveAllRecords();
  int writes = 0;
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  late final client = MockClient((r) async {
    final path = r.url.path, q = r.url.queryParameters;
    requests.add({
      'method': r.method,
      'path': path,
      'query': Map<String, String>.from(q),
    });
    if (r.method != 'GET' &&
        !path.contains('/metrics/') &&
        !path.contains('/auth/') &&
        !path.endsWith('/view')) {
      writes++;
    }
    if (path == '/api/v1/auth/refresh' || path == '/api/v1/auth/guest') {
      return json({
        'access_token': 'fixture-access',
        'refresh_token': 'fixture-refresh',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
      }, 201);
    }
    if (path == '/api/v1/users/me') {
      return json({
        'id': 1,
        'email': null,
        'display_name': expected.name,
        'is_guest': kind == 'guest',
        'created_at': '2026-10-18T00:00:00Z',
        'linked_providers': kind == 'guest' ? <String>[] : ['kakao', 'apple'],
      });
    }
    if (path == '/api/v1/users/me/stats') {
      return json({
        'saved_count': expected.savedContentCount,
        'reopened_count': expected.revisitedContentCount,
      });
    }
    if (path == '/api/v1/categories') return json(e01.archiveAllCategoryMaps);
    if (path == '/api/v1/feed') {
      var rows = records
          .where(
            (v) =>
                q['is_favorite'] == null ||
                v['is_favorite'] == (q['is_favorite'] == 'true'),
          )
          .toList();
      if (q['category_id'] != null) {
        rows = rows
            .where(
              (v) => (v['categories'] as List).any(
                (c) => (c as Map)['id'].toString() == q['category_id'],
              ),
            )
            .toList();
      }
      return json({'items': rows, 'next_cursor': null});
    }
    if (path == '/api/v1/metrics/events' || path.endsWith('/view')) {
      return json({}, 201);
    }
    if (path == '/api/v1/auth/share-credential') {
      return json({
        'share_token': 'fixture-share',
        'expires_at': '2030-10-18T00:00:00Z',
        'user_id': 1,
        'session_id': 1,
      });
    }
    if (path == '/api/v1/auth/logout') return http.Response('', 204);
    unexpected.add('${r.method} $path');
    return json({'detail': 'Unsupported memory fixture request'}, 501);
  });
}

final _capture = GlobalKey();
MyServer _server = MyServer('member');
late Directory _output;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
bool _busy = false, _done = false, _coverage = false;
String _kind = 'member';
int _epoch = 0, _pointer = 81000;
final _clock = Stopwatch()..start();
Duration _last = Duration.zero;
Duration _time() {
  final t = _clock.elapsed;
  return _last = t > _last ? t : _last + const Duration(microseconds: 1);
}

Element get _root => _capture.currentContext! as Element;
Element get _my => _find<MyScreen>(_root)!;
void _require(bool yes, String why) {
  if (!yes) throw StateError(why);
}

Future<void> _settle([int n = 3]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _wait(bool Function() yes, String why) async {
  for (var i = 0; i < 100; i++) {
    if (yes()) return;
    await _settle(2);
  }
  throw StateError(why);
}

Future<void> _tapPoint(Offset p) async {
  final id = ++_pointer, v = View.of(_root);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      viewId: v.viewId,
      position: p,
      timeStamp: _time(),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 70));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: v.viewId,
      position: p,
      timeStamp: _time(),
    ),
  );
  await _settle();
}

Future<void> _tap(Element e) => _tapPoint(_box(e).center);
String _route() {
  if (_find<AddContentSheet>(_root) != null) return 'save';
  if (_find<AccountManagementScreen>(_root) != null) return 'account';
  if (_find<CategoryManagementScreen>(_root) != null) return 'management';
  if (_runtime('NoticeListScreen') != null) return 'noticeList';
  if (_find<MyScreen>(_root) != null) return 'my';
  if (_find<ArchiveScreen>(_root) != null) return 'archive';
  if (_find<BookmarkScreen>(_root) != null) return 'bookmark';
  if (_find<HomeScreen>(_root) != null) return 'home';
  return 'other';
}

Future<void> _fresh(String kind) async {
  _kind = kind;
  _server = MyServer(kind);
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: ValueKey(++_epoch),
        sessionStorage: e01.ArchiveAllMemoryStorage(),
        socialAuth: e01.ArchiveAllSocialAuth(),
      ),
    ),
  );
  await _settle(2);
  await _wait(
    () => _route() == 'home',
    'Memory session/home did not initialize',
  );
  await _tap(_text(_find<ClipbackNavigationBar>(_root)!, '마이')!);
  await _wait(
    () =>
        _route() == 'my' &&
        (_my.widget as MyScreen).user.savedContentCount ==
            _server.expected.savedContentCount &&
        (_my.widget as MyScreen).user.name == _server.expected.name,
    'Actual mapped My data missing',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _wait(
    () => View.of(_root).viewInsets.bottom == 0,
    'Keyboard did not hide',
  );
  _position(_my)?.jumpTo(0);
  await _settle(3);
}

Map<String, Object?> _snapshot() {
  final m = myMeasure(_root),
      v = View.of(_root),
      messenger = e01.archiveAllShareMessenger;
  return {
    'phase': myPhase,
    'kind': _kind,
    'platform': Platform.operatingSystem,
    'route': _route(),
    'ready': true,
    'busy': _busy,
    'output': _output.path,
    'logicalSize': '${v.physicalSize / v.devicePixelRatio}',
    'pixelRatio': v.devicePixelRatio,
    'viewPaddingTop': v.viewPadding.top / v.devicePixelRatio,
    'viewPaddingBottom': v.viewPadding.bottom / v.devicePixelRatio,
    'viewInsetsBottom': v.viewInsets.bottom / v.devicePixelRatio,
    'scrollOffset': 0.0,
    'maxScrollExtent': 0.0,
    'textScale': 1.0,
    ...m,
    ...myJudgment(m),
    'requests': _server.requests,
    'unexpectedRequests': _server.unexpected,
    'writeRequests': _server.writes,
    'serverRecordCount': _server.records.length,
    'expectedUser': {
      'name': _server.expected.name,
      'providerLabel': _server.expected.providerLabel,
      'savedCount': _server.expected.savedContentCount,
      'reopenedCount': _server.expected.revisitedContentCount,
    },
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        messenger,
      ),
      'state':
          'In-memory empty drafts/receipts; retained native queue untouched.',
      'methodCounts': {
        for (final name in messenger?.namesOnlyCalls.toSet() ?? <String>{})
          name: messenger!.namesOnlyCalls.where((v) => v == name).length,
      },
      'nativeDelegationCount': messenger?.nativeDelegationCount,
      'unknownMethods': messenger?.unknownShareMethods ?? <String>[],
      'argumentsOrCredentialsRecorded': false,
    },
    'frameworkErrors': _errors,
    'scope':
        'Actual ClipbackApp, memory-only HTTP/session and isolated native share. Real device OS/native IME with synthetic pointers; no external OAuth/production/persistence/physical-device/CI proof.',
  };
}

void _record(String scenario, [Map<String, Object?> fields = const {}]) =>
    _checks.add({
      'scenario': scenario,
      'passed': true,
      ..._snapshot(),
      ...fields,
    });
Future<void> _report() async {
  final s = _snapshot(), messenger = e01.archiveAllShareMessenger;
  final style =
      s['stylePassed'] == true &&
      !_checks.any((c) => c['stylePassed'] == false);
  final layout =
      s['layoutPassed'] == true &&
      _errors.isEmpty &&
      !_checks.any((c) => c['layoutPassed'] == false);
  final asset =
      s['assetPassed'] == true &&
      !_checks.any((c) => c['assetPassed'] == false);
  final behavior =
      _done &&
      messenger != null &&
      messenger.nativeDelegationCount == 0 &&
      messenger.unknownShareMethods.isEmpty &&
      _server.unexpected.isEmpty &&
      _server.writes == 0 &&
      !_checks.any(
        (c) =>
            c['passed'] == false ||
            (c['unexpectedRequests'] is List &&
                (c['unexpectedRequests'] as List).isNotEmpty),
      );
  await File('${_output.path}/report.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      ...s,
      'checksCompleted': _done,
      'coveragePassed': _coverage,
      'stylePassed': style,
      'layoutPassed': layout,
      'assetPassed': asset,
      'behaviorPassed': behavior,
      'passed': _done && _coverage && style && layout && asset && behavior,
      'checks': _checks,
    }),
  );
}

Future<void> _captureScene() async {
  await _settle(2);
  final image =
      await (_capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: View.of(_root).devicePixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${_output.path}/my_${_kind}_scale_1_scroll_0.png').writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _record('static_$_kind');
}

Element? _runtime(String type) => _elements(
  _root,
).where((e) => e.widget.runtimeType.toString() == type).firstOrNull;
Future<Element> _modal(String type) async {
  await _wait(() {
    final e = _runtime(type);
    return e != null &&
        ModalRoute.of(e)?.animation?.status == AnimationStatus.completed;
  }, 'Modal $type did not finish entering');
  return _runtime(type)!;
}

Future<void> _visible(Element e) async {
  await Scrollable.ensureVisible(
    e,
    duration: const Duration(milliseconds: 150),
    alignment: .5,
  );
  await _settle(4);
}

Future<void> _showTile(String title, String type) async {
  final tile = _elements(_my).firstWhere(
    (e) =>
        e.widget is MyListTile &&
        ((e.widget as MyListTile).title == title ||
            title == '앱 권한' && (e.widget as MyListTile).title == '알림 및 앱 권한'),
  );
  await _visible(tile);
  final before = _position(_my)!.pixels;
  await _tap(tile);
  if (type == 'NoticeSheet') {
    // K01's root route replaces only this sheet. Keep the frozen helper runnable
    // on the baseline, which still opens the legacy modal.
    await _wait(
      () => _runtime('NoticeListScreen') != null || _runtime(type) != null,
      'Notice entry did not open',
    );
    final notices = _runtime('NoticeListScreen');
    if (notices != null) {
      _record('notice_list_opened', {'offsetBefore': before});
      await _tap(_key(notices, 'notice-back-hit')!);
      await _wait(() => _route() == 'my', 'Notices did not return to My');
      _require(
        (_position(_my)!.pixels - before).abs() < .18,
        'Notice round trip changed My scroll',
      );
      _record('notice_list_closed', {
        'offsetBefore': before,
        'offsetAfter': _position(_my)!.pixels,
        'noScroll': _position(_my)!.maxScrollExtent == 0,
      });
      return;
    }
  }
  final sheet = await _modal(type), r = _box(sheet);
  _record('sheet_${type}_opened', {
    'modalType': type,
    'offsetBefore': before,
    'modalBounds': _rect(r),
    'transitionCompleted': true,
  });
  await _tapPoint(Offset(_box(_root).center.dx, r.top / 2));
  await _wait(() => _runtime(type) == null, 'Modal $type did not close');
  _require(_route() == 'my', 'Sheet did not return to My');
  _require(
    (_position(_my)!.pixels - before).abs() < .18,
    'Modal round trip changed underlying scroll',
  );
  _record('sheet_${type}_closed', {
    'offsetBefore': before,
    'offsetAfter': _position(_my)!.pixels,
  });
}

Future<void> _back(String route) async {
  if (route == 'management') {
    await _tap(_key(_root, 'management-back')!);
  } else {
    await _tap(
      _elements(_root).firstWhere(
        (e) =>
            e.widget is SvgIconButton &&
            (e.widget as SvgIconButton).asset == Assets.back,
      ),
    );
  }
  await _wait(() => _route() == 'my', 'Route did not return to My');
  _record('${route}_return', {
    'scrollPolicy': 'Existing root replacement; no new My restoration added.',
  });
}

Future<void> _run() async {
  _checks.clear();
  _done = false;
  _coverage = false;
  await _fresh('member');
  _record('member_initial');
  final initial = (_my.widget as MyScreen).user;
  _require(
    initial.providerLabel == myMember.providerLabel &&
        initial.revisitedContentCount! > initial.savedContentCount!,
    'Actual raw mapper/cumulative stats replaced',
  );
  final header = _find<MyPageTopBar>(_my)!;
  await _tap(
    _key(header, 'my-header-settings') ?? _find<SvgIconButton>(header)!,
  );
  await _wait(
    () => _route() == 'account',
    'Settings did not open existing account management',
  );
  _record('settings_account_open');
  await _back('account');
  await _tap(_find<MyProfileRow>(_my)!);
  await _wait(
    () => _route() == 'account',
    'Profile did not open existing account management',
  );
  _record('profile_account_open');
  await _back('account');
  await _tap(_text(_my, '카테고리 관리')!);
  await _wait(
    () => _route() == 'management',
    'Category management did not open',
  );
  _record('category_management_open');
  await _back('management');
  for (final item in const {
    '리마인드 설정': 'ReminderSheet',
    '앱 권한': 'PermissionSheet',
    '공지사항': 'NoticeSheet',
    '문의하기': 'ContactSheet',
    '앱 버전': 'AppVersionSheet',
  }.entries) {
    await _showTile(item.key, item.value);
  }
  final p = _position(_my)!;
  p.jumpTo(p.maxScrollExtent);
  await _settle(3);
  final bottom = myMeasure(_root),
      last = ((bottom['groups'] as List).last['rows'] as List).last;
  final vp = (bottom['bounds'] as Map)['viewport'] as Map;
  _require(
    (last['bounds']['bottom'] as num) <= (vp['bottom'] as num) - 23.8,
    'Last version row/padding not reachable',
  );
  _record('maximum_scroll', {
    'maximum': p.maxScrollExtent,
    'noScroll': p.maxScrollExtent == 0,
    'lastRowVisible': true,
    'lastRowBottom': last['bounds']['bottom'],
    'viewportBottom': vp['bottom'],
  });
  for (final item in const {
    '홈': 'home',
    '아카이브': 'archive',
    '즐겨찾기': 'bookmark',
    '마이': 'my',
  }.entries) {
    final bar = _find<ClipbackNavigationBar>(_root)!;
    await _tap(_text(bar, item.key)!);
    await _wait(
      () => _route() == item.value,
      'Bottom tab ${item.key} did not open',
    );
    _record('tab_${item.value}');
  }
  final beforeWrites = _server.writes;
  await _tap(_find<NavAddButton>(_find<ClipbackNavigationBar>(_root)!)!);
  final save = await _modal('AddContentSheet');
  _record('save_open');
  final close = _elements(save).firstWhere(
    (e) =>
        e.widget is SvgIconButton &&
        (e.widget as SvgIconButton).asset == Assets.close,
  );
  await _tap(close);
  await _wait(
    () => _find<AddContentSheet>(_root) == null,
    'Save did not close',
  );
  _require(
    _route() == 'my' && _server.writes == beforeWrites,
    'Closing save changed data or route',
  );
  _record('save_closed_without_write');
  await _fresh('guest');
  _require(
    (_my.widget as MyScreen).user.providerLabel == '게스트 계정',
    'Guest account text lost',
  );
  _record('guest_initial');
  await _tap(_find<MyProfileRow>(_my)!);
  await _wait(() => _route() == 'account', 'Guest account route missing');
  _record('guest_account_open');
  await _back('account');
  await _fresh('member');
  _record('final_member_scroll_zero');
  _coverage = true;
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  e01.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-my-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _fresh('member');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('MY ready phase=$myPhase output=${_output.path}');
  await for (final request in server) {
    final read = ['/ready', '/state', '/status'].contains(request.uri.path);
    if (_busy && !read) {
      request.response.statusCode = 409;
      await request.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (request.uri.path) {
        case '/ready':
        case '/state':
        case '/status':
          break;
        case '/scene':
          final kind = request.uri.queryParameters['kind'] ?? 'member';
          _require(
            ['member', 'guest'].contains(kind),
            'Only member/guest supported',
          );
          await _fresh(kind);
          await _captureScene();
        case '/run':
          await _run();
        default:
          request.response.statusCode = 404;
      }
      await _report();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_snapshot()));
    } catch (error, stack) {
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$error',
      });
      debugPrint('MY FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
