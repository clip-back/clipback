// J02 evidence uses the actual root app and in-memory API/session doubles.
// Native share is isolated before app bootstrap; no provider or production proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
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

const accountPhase = String.fromEnvironment(
  'ACCOUNT_PHASE',
  defaultValue: 'before',
);
const accountAssets = {
  'back': 'assets/icons/detail-back.svg',
  'background': 'assets/icons/account-avatar-background.svg',
  'character': 'assets/figma/my-avatar-character.png',
  'arrow': 'assets/icons/my-menu-chevron.svg',
};
const accountMember = AppUser(
  name: '정지윤',
  providerLabel: 'kakao, apple 계정 연동 중',
  joinedAt: '2026.10.18',
  savedContentCount: 150,
  revisitedContentCount: 231,
  appVersion: 'ver. 1.1',
);
const accountGuest = AppUser(
  name: '게스트',
  providerLabel: '게스트 계정',
  joinedAt: '2026.10.18',
  savedContentCount: 0,
  revisitedContentCount: 0,
  appVersion: 'ver. 1.1',
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
  final e = _find<Scrollable>(root);
  return e is StatefulElement && e.state is ScrollableState
      ? (e.state as ScrollableState).position
      : null;
}

Element? _rich(Element root, String text) => _text(root, text);
Element? _fixedAncestor(Element e, double height) =>
    _ancestor(e, (w) => w is SizedBox && w.height == height);

/// The same actual RenderParagraph and render-box oracle is used by widget
/// checks and native captures. The baseline fallback does not require new keys.
Map<String, Object?> accountMeasure(Element root) {
  final screen = _find<AccountManagementScreen>(root);
  if (screen == null) return {'active': false};
  final w = screen.widget as AccountManagementScreen;
  final title = _rich(screen, '계정 관리')!;
  final header = _key(screen, 'account-header') ?? _fixedAncestor(title, 64)!;
  final name = _rich(screen, w.user.name)!;
  final oldImage = _find<Image>(screen)!;
  final avatar = _key(screen, 'account-avatar') ?? oldImage;
  final viewport =
      _key(screen, 'account-viewport') ?? _find<SingleChildScrollView>(screen);
  final scaffold = _find<Scaffold>(screen)!;
  final back =
      _key(screen, 'account-back-hit') ?? _find<SvgIconButton>(header)!;
  final clip = _key(screen, 'account-avatar-character-clip');
  final p = _position(screen);
  final styles = <String, Object?>{
    'header': _paragraph(title),
    'name': _paragraph(name),
  };
  final bounds = <String, Object?>{
    'screen': _rect(_box(scaffold)),
    'header': _rect(_box(header)),
    'backHit': _rect(_box(back)),
    'avatar': _rect(_box(avatar)),
    if (clip != null) 'avatarClip': _rect(_box(clip)),
    if (viewport != null) 'viewport': _rect(_box(viewport)),
  };
  final sections = <Map<String, Object?>>[];
  for (final pair in const {'연결된 계정': 'connected', '계정': 'actions'}.entries) {
    final t = _rich(screen, pair.key)!;
    final s = _key(screen, 'account-section-${pair.value}');
    sections.add({
      'title': pair.key,
      'bounds': _rect(_box(s ?? t)),
      'style': _paragraph(t),
    });
  }
  final groups = <Map<String, Object?>>[];
  for (final id in ['connected', 'actions']) {
    final group = _key(screen, 'account-$id-group');
    if (group != null) {
      final material = group.widget is Material
          ? group
          : _find<Material>(group);
      final m = material?.widget as Material?;
      groups.add({
        'id': id,
        'bounds': _rect(_box(group)),
        'fill': _color(m?.color),
        'radius': (m?.borderRadius as BorderRadius?)?.topLeft.x,
      });
    }
  }
  final rows = <Map<String, Object?>>[];
  for (final e in _elements(
    screen,
  ).where((e) => e.widget is AccountManagementTile)) {
    final tile = e.widget as AccountManagementTile;
    final body = _key(e, 'account-row-${tile.leading}') ?? e;
    final arrow = _key(e, 'account-arrow-${tile.leading}');
    final ink = _find<InkWell>(e)?.widget as InkWell?;
    rows.add({
      'text': tile.leading,
      'bounds': _rect(_box(body)),
      'style': _paragraph(_rich(e, tile.leading)!),
      'interactive': ink?.onTap != null,
      if (tile.trailing != null)
        'status': _paragraph(_rich(e, tile.trailing!)!),
      if (arrow != null) 'arrowSlot': _rect(_box(arrow)),
      'arrow': _asset(
        _key(e, 'account-arrow-image-${tile.leading}') ?? _find<SvgIcon>(e),
      ),
    });
  }
  final media = MediaQuery.of(screen);
  return {
    'active': true,
    'styles': styles,
    'bounds': bounds,
    'assets': {
      'back': _asset(_key(header, 'account-back-image') ?? back),
      'background': _asset(_key(screen, 'account-avatar-background')),
      'character': _asset(
        _key(screen, 'account-avatar-character-source') ?? oldImage,
      ),
    },
    'sections': sections,
    'groups': groups,
    'rows': rows,
    'user': {
      'name': w.user.name,
      'providerLabel': w.user.providerLabel,
      'savedCount': w.user.savedContentCount,
      'reopenedCount': w.user.revisitedContentCount,
      'appVersion': w.user.appVersion,
    },
    'isGuest': w.isGuest,
    'authBusy': w.busy,
    'scrollOffset': p?.pixels ?? 0,
    'maxScrollExtent': p?.maxScrollExtent ?? 0,
    'textScale': media.textScaler.scale(1),
    'topSafeArea': media.viewPadding.top,
    'bottomSafeArea': media.viewPadding.bottom,
  };
}

Map<String, Object?> accountJudgment(Map<String, Object?> m) {
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
  final sf = <String>[], lf = <String>[], af = <String>[];
  final s = m['styles'] as Map, b = m['bounds'] as Map, a = m['assets'] as Map;
  bool near(Object? x, num y) => x is num && (x - y).abs() < .18;
  void n(Object? x, num y, String why) {
    if (!near(x, y)) lf.add('$why: $x != $y');
  }

  void style(
    Map? p,
    num size,
    int weight,
    num spacing,
    String color,
    String why,
  ) {
    if (p == null ||
        p['fontFamily'] != 'Pretendard' ||
        !near(p['fontSize'], size) ||
        !near(p['scaledFontSize'], size) ||
        p['fontWeight'] != weight ||
        !near(p['letterSpacing'], spacing) ||
        p['height'] != null ||
        p['color'] != color) {
      sf.add('$why: $p');
    }
  }

  style(s['header'] as Map?, 18, 600, -.45, '0xFF000000', 'header');
  style(s['name'] as Map?, 20, 600, -.5, '0xFF000000', 'name');
  for (final p in [s['name']]) {
    if (p['maxLines'] != null || p['overflow'] == 'ellipsis') {
      sf.add('Name must naturally wrap');
    }
  }
  final screen = b['screen'] as Map,
      header = b['header'] as Map,
      avatar = b['avatar'] as Map;
  final title = s['header'] as Map, name = s['name'] as Map;
  if (name['text'] != (m['user'] as Map)['name']) {
    sf.add('Raw user name changed');
  }
  n(header['height'], 64, 'header height');
  n(header['top'], m['topSafeArea'] as num, 'actual top safety');
  n(b['backHit']['width'], 48, 'back hit width');
  n(b['backHit']['height'], 48, 'back hit height');
  final back = a['back']['bounds'] as Map;
  n((back['left'] as num) - (screen['left'] as num), 16, 'back left');
  n(back['width'], 24, 'back source width');
  n(back['height'], 24, 'back source height');
  n(
    (back['top'] as num) + 12,
    (header['top'] as num) + 32.5,
    'back source center',
  );
  n(
    (title['bounds']['left'] as num) - (back['right'] as num),
    8,
    'back title gap',
  );
  n(
    (title['bounds']['top'] as num) + (title['bounds']['height'] as num) / 2,
    (header['top'] as num) + 32.5,
    'header content center',
  );
  n(avatar['width'], 140, 'avatar width');
  n(avatar['height'], 140, 'avatar height');
  n(
    (avatar['left'] as num) + 70,
    (screen['left'] as num) + (screen['width'] as num) / 2 + .5,
    'avatar center',
  );
  n(
    (name['bounds']['left'] as num) + (name['bounds']['width'] as num) / 2,
    (screen['left'] as num) + (screen['width'] as num) / 2,
    'name center',
  );
  n(
    (name['bounds']['top'] as num) - (avatar['bottom'] as num),
    16,
    'avatar name gap',
  );
  if (near(m['scrollOffset'], 0)) {
    n((avatar['top'] as num) - (header['bottom'] as num), 16, 'body top');
  }
  final clip = b['avatarClip'] as Map?;
  if (clip == null) {
    lf.add('Missing character clip');
  } else {
    n(clip['width'], 88.038, 'clip width');
    n(clip['height'], 97.821, 'clip height');
    n((clip['left'] as num) - (avatar['left'] as num), 24.23, 'clip left');
    n((clip['top'] as num) - (avatar['top'] as num), 18.84, 'clip top');
    final image = a['character']['bounds'] as Map;
    n(image['width'], 88.038 * 1.5323, 'crop width');
    n(image['height'], 97.821 * 1.3621, 'crop height');
    n(
      (image['left'] as num) - (clip['left'] as num),
      88.038 * -.2301,
      'crop left',
    );
    n(
      (image['top'] as num) - (clip['top'] as num),
      97.821 * -.1452,
      'crop top',
    );
  }
  final sections = m['sections'] as List;
  for (final sec in sections) {
    style(sec['style'] as Map, 16, 600, -.4, '0xFF1A1A1A', 'section');
    n(sec['bounds']['height'], 44, 'section height');
    n(
      (sec['style']['bounds']['left'] as num) - (screen['left'] as num),
      16,
      'section left',
    );
  }
  n(
    (sections[0]['bounds']['top'] as num) - (name['bounds']['bottom'] as num),
    16,
    'name section gap',
  );
  final groups = m['groups'] as List;
  if (groups.length != 2) {
    lf.add('Need grouped surfaces');
  } else {
    for (final g in groups) {
      n(g['bounds']['width'], (screen['width'] as num) - 32, 'group width');
      n(
        (g['bounds']['left'] as num) - (screen['left'] as num),
        16,
        'group left',
      );
      n(g['radius'], 8, 'group radius');
      if (g['fill'] != '0xFFFFFFFF') lf.add('Group white');
    }
    n(
      (groups[0]['bounds']['top'] as num) -
          (sections[0]['bounds']['bottom'] as num),
      0,
      'section group gap',
    );
    n(
      (sections[1]['bounds']['top'] as num) -
          (groups[0]['bounds']['bottom'] as num),
      16,
      'group section gap',
    );
    n(
      (groups[1]['bounds']['top'] as num) -
          (sections[1]['bounds']['bottom'] as num),
      0,
      'actions group gap',
    );
  }
  final rows = m['rows'] as List;
  final expected = [
    '${m['user'] is Map ? (m['user'] as Map)['providerLabel'] : ''}',
    if (m['isGuest'] != false) m['isGuest'] == true ? '계정 연결하기' : '계정 정보 다시 확인',
    '로그아웃',
    '회원 탈퇴',
  ];
  if (rows.map((r) => r['text']).join('|') != expected.join('|')) {
    sf.add('Existing row order changed');
  }
  for (final r in rows) {
    final p = r['style'] as Map, row = r['bounds'] as Map;
    style(p, 14, 500, -.35, '0xFF000000', 'row ${r['text']}');
    if (p['maxLines'] != null || p['overflow'] == 'ellipsis') {
      sf.add('Row must wrap ${r['text']}');
    }
    if ((row['height'] as num) < 40.8) lf.add('row below min41');
    n(
      (p['bounds']['left'] as num) - (row['left'] as num),
      16,
      'row inner left',
    );
    n(
      (p['bounds']['top'] as num) + (p['bounds']['height'] as num) / 2,
      (row['top'] as num) + (row['height'] as num) / 2,
      'row text center',
    );
    if ((p['bounds']['top'] as num) < (row['top'] as num) - .18 ||
        (p['bounds']['bottom'] as num) > (row['bottom'] as num) + .18) {
      lf.add('Text outside row');
    }
    final slot = r['arrowSlot'] as Map?;
    if (slot == null) {
      lf.add('Missing arrow slot');
    } else {
      n(slot['width'], 5, 'arrow slot width');
      n(slot['height'], 10, 'arrow slot height');
      n((row['right'] as num) - (slot['right'] as num), 16, 'arrow right');
      if (r['status'] != null) {
        style(
          r['status'] as Map,
          14,
          500,
          -.35,
          '0xFF767676',
          'connected status',
        );
        n(
          (slot['left'] as num) - (r['status']['bounds']['right'] as num),
          16,
          'status arrow gap',
        );
        n(
          (r['status']['bounds']['top'] as num) +
              (r['status']['bounds']['height'] as num) / 2,
          (row['top'] as num) + (row['height'] as num) / 2,
          'status vertical center',
        );
        if ((p['bounds']['right'] as num) >
            (r['status']['bounds']['left'] as num) - 7.8) {
          lf.add('Account and status overlap');
        }
      }
    }
    final arrow = r['arrow'] as Map;
    if (arrow['asset'] != accountAssets['arrow'] ||
        arrow['unfiltered'] != true) {
      af.add('Exact row arrow');
    }
    n(arrow['localWidth'], 6.66667, 'source SVG width');
    n(arrow['localHeight'], 11.6667, 'source SVG height');
  }
  final logout = rows.where((r) => r['text'] == '로그아웃').first;
  final withdraw = rows.where((r) => r['text'] == '회원 탈퇴').first;
  n(
    (withdraw['bounds']['top'] as num) - (logout['bounds']['bottom'] as num),
    10,
    'action row gap',
  );
  for (final role in ['back', 'background', 'character']) {
    final asset = a[role] as Map;
    if (asset['asset'] != accountAssets[role] ||
        role != 'character' && asset['unfiltered'] != true) {
      af.add('Exact unfiltered source $role');
    }
  }
  final vp = b['viewport'] as Map?;
  if (vp == null) {
    lf.add('Scrollable body missing');
  } else {
    n(vp['top'], header['bottom'] as num, 'viewport starts after header');
    n(
      (screen['bottom'] as num) - (vp['bottom'] as num),
      m['bottomSafeArea'] as num,
      'bottom OS safety once',
    );
    if ((m['maxScrollExtent'] as num) > 0 &&
        near(m['scrollOffset'], m['maxScrollExtent'] as num)) {
      n(
        (vp['bottom'] as num) - (withdraw['bounds']['bottom'] as num),
        24,
        'body bottom padding',
      );
    }
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

class AccountServer {
  AccountServer(this.kind);
  final String kind;
  AppUser get expected => kind == 'guest' ? accountGuest : accountMember;
  final requests = <Map<String, Object?>>[], unexpected = <String>[];
  final records = e01.archiveAllRecords();
  int writes = 0, logoutCalls = 0;
  Completer<http.Response>? logoutGate;
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
    if (path == '/api/v1/auth/logout') {
      logoutCalls++;
      return logoutGate == null
          ? http.Response('', 204)
          : await logoutGate!.future;
    }
    unexpected.add('${r.method} $path');
    return json({'detail': 'Unsupported memory fixture request'}, 501);
  });
}

final _capture = GlobalKey();
AccountServer _server = AccountServer('member');
final _sessions = <AccountServer>[];
late Directory _output;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
bool _busy = false, _done = false, _coverage = false;
String _kind = 'member';
int _epoch = 0, _pointer = 91000;
final _clock = Stopwatch()..start();
Duration _last = Duration.zero;
Duration _time() {
  final t = _clock.elapsed;
  return _last = t > _last ? t : _last + const Duration(microseconds: 1);
}

Element get _root => _capture.currentContext! as Element;
Element get _account => _find<AccountManagementScreen>(_root)!;
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
Element? get _logoutConfirmation {
  for (final element in _elements(_root)) {
    if (element.widget.runtimeType.toString() == 'LogoutConfirmationScreen') {
      return element;
    }
  }
  return null;
}

String _route() {
  if (_logoutConfirmation != null) return 'logoutConfirmation';
  if (_find<AccountManagementScreen>(_root) != null) return 'account';
  if (_find<LoginScreen>(_root) != null) return 'login';
  if (_find<MyScreen>(_root) != null) return 'my';
  if (_find<HomeScreen>(_root) != null) return 'home';
  return 'other';
}

Future<void> _fresh(String kind, {bool openAccount = true}) async {
  _kind = kind;
  _server = AccountServer(kind);
  _sessions.add(_server);
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
        (_find<MyScreen>(_root)!.widget as MyScreen).user.name ==
            _server.expected.name &&
        (_find<MyScreen>(_root)!.widget as MyScreen).user.savedContentCount ==
            _server.expected.savedContentCount &&
        (_find<MyScreen>(_root)!.widget as MyScreen)
                .user
                .revisitedContentCount ==
            _server.expected.revisitedContentCount,
    'Actual user mapping missing',
  );
  if (openAccount) {
    await _tap(_find<MyProfileRow>(_root)!);
    await _wait(() => _route() == 'account', 'Profile account entry missing');
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _wait(
    () => View.of(_root).viewInsets.bottom == 0,
    'Keyboard did not hide',
  );
  if (openAccount) _position(_account)?.jumpTo(0);
  await _settle(3);
}

Map<String, Object?> _snapshot() {
  final m = accountMeasure(_root),
      v = View.of(_root),
      messenger = e01.archiveAllShareMessenger;
  return {
    'phase': accountPhase,
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
    'textScale': 1.0,
    'scrollOffset': 0.0,
    'maxScrollExtent': 0.0,
    ...m,
    ...accountJudgment(m),
    'requests': List<Map<String, Object?>>.from(_server.requests),
    'unexpectedRequests': List<String>.from(_server.unexpected),
    'writeRequests': _server.writes,
    'logoutRequests': _server.logoutCalls,
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
        for (final n in messenger?.namesOnlyCalls.toSet() ?? <String>{})
          n: messenger!.namesOnlyCalls.where((v) => v == n).length,
      },
      'nativeDelegationCount': messenger?.nativeDelegationCount,
      'unknownMethods': messenger?.unknownShareMethods ?? <String>[],
      'argumentsOrCredentialsRecorded': false,
    },
    'frameworkErrors': List<String>.from(_errors),
    'scope':
        'Actual ClipbackApp; memory HTTP/session/logout only. Native OS with synthetic pointer interactions; no external OAuth, production, physical-device or remote CI proof.',
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
      !_sessions.any((s) => s.unexpected.isNotEmpty || s.writes != 0) &&
      !_checks.any((c) => c['passed'] == false);
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
      'sessionSummaries': [
        for (final s in _sessions)
          {
            'kind': s.kind,
            'logoutRequests': s.logoutCalls,
            'writeRequests': s.writes,
            'unexpectedRequests': s.unexpected,
            'serverRecordCount': s.records.length,
          },
      ],
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
    final d = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_output.path}/account_${_kind}_scale_1_scroll_0.png',
    ).writeAsBytes(d!.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
  } finally {
    image.dispose();
  }
  _record('static_$_kind');
}

Future<void> _visible(Element e) async {
  if (_position(_account) != null) {
    await Scrollable.ensureVisible(
      e,
      duration: const Duration(milliseconds: 150),
      alignment: .5,
    );
    await _settle(4);
  }
}

Future<void> _back() async {
  await _tap(
    _key(_account, 'account-back-hit') ?? _find<SvgIconButton>(_account)!,
  );
  await _wait(() => _route() == 'my', 'Header did not return to My');
}

Future<void> _run() async {
  _checks.clear();
  _sessions.clear();
  _done = false;
  _coverage = false;
  await _fresh('member', openAccount: false);
  _record('member_my_initial');
  final header = _find<MyPageTopBar>(_root)!;
  await _tap(_key(header, 'my-header-settings')!);
  await _wait(() => _route() == 'account', 'My settings entry missing');
  _record('settings_account_open');
  await _back();
  _record('settings_header_return');
  await _tap(_find<MyProfileRow>(_root)!);
  await _wait(() => _route() == 'account', 'My profile entry missing');
  _record('profile_account_open');
  final member = (_account.widget as AccountManagementScreen).user;
  _require(
    member.providerLabel == accountMember.providerLabel &&
        member.revisitedContentCount == 231 &&
        member.savedContentCount == 150,
    'Raw provider/cumulative stats changed',
  );
  final row = _elements(_account).firstWhere(
    (e) =>
        e.widget is AccountManagementTile &&
        (e.widget as AccountManagementTile).leading == member.providerLabel,
  );
  final readonly = (_find<InkWell>(row)?.widget as InkWell?)?.onTap == null;
  _require(readonly, 'Linked row became interactive');
  await _tap(row);
  _require(_route() == 'account', 'Read-only row opened route');
  _record('member_read_only_account');
  final withdraw = _text(_account, '회원 탈퇴')!;
  await _visible(withdraw);
  await _tap(withdraw);
  await _wait(
    () => _text(_root, '회원 탈퇴 API는 아직 제공되지 않습니다.') != null,
    'Withdrawal notice missing',
  );
  _record('withdraw_notice');
  ScaffoldMessenger.of(_account).hideCurrentSnackBar();
  await _settle(6);
  final p = _position(_account);
  if (p != null) p.jumpTo(p.maxScrollExtent);
  await _settle(3);
  final m = accountMeasure(_root),
      rows = m['rows'] as List,
      vp = (m['bounds'] as Map)['viewport'] as Map?;
  if (vp != null) {
    _require(
      (rows.last['bounds']['bottom'] as num) <= (vp['bottom'] as num) - 23.8,
      'Final row/body 24px inaccessible',
    );
  }
  _record('maximum_scroll', {
    'maximum': p?.maxScrollExtent ?? 0,
    'noScroll': p == null || p.maxScrollExtent == 0,
    'lastRowVisible': vp == null ? null : true,
  });
  await _back();
  _record('profile_header_return');
  await _fresh('guest');
  _record('guest_initial');
  final initial = (_account.widget as AccountManagementScreen).user;
  await _tap(_text(_account, '계정 연결하기')!);
  await _wait(() => _route() == 'login', 'Guest connect did not open Login');
  _require(
    (_find<LoginScreen>(_root)!.widget as LoginScreen).linkingGuest,
    'Guest link contract lost',
  );
  _record('guest_connect_login');
  await _tap(_text(_find<LoginScreen>(_root)!, '뒤로')!);
  await _wait(() => _route() == 'account', 'Cancel did not return account');
  final restored = (_account.widget as AccountManagementScreen).user;
  _require(
    restored.name == initial.name &&
        restored.providerLabel == initial.providerLabel &&
        restored.savedContentCount == initial.savedContentCount &&
        restored.revisitedContentCount == initial.revisitedContentCount,
    'Cancel changed guest account/stats',
  );
  _record('guest_connect_cancel_preserved');
  _server.logoutGate = Completer<http.Response>();
  await _visible(_text(_account, '로그아웃')!);
  await _tap(_text(_account, '로그아웃')!);
  if (_logoutConfirmation != null) {
    _require(_server.logoutCalls == 0, 'Opening confirmation issued logout');
    _record('logout_confirmation_open');
    await _tap(_key(_logoutConfirmation!, 'logout-confirm')!);
  }
  await _wait(
    () =>
        _server.logoutCalls == 1 &&
        (_logoutConfirmation != null
            ? (_logoutConfirmation!.widget as dynamic).busy == true
            : (_account.widget as AccountManagementScreen).busy),
    'Logout did not enter pending state',
  );
  _record('logout_pending_busy');
  if (_logoutConfirmation != null) {
    await _tap(_key(_logoutConfirmation!, 'logout-confirm')!);
    await _tap(_key(_logoutConfirmation!, 'logout-cancel')!);
  } else {
    await _tap(_text(_account, '로그아웃')!);
    await _tap(_text(_account, '계정 연결하기')!);
  }
  _require(
    _server.logoutCalls == 1 &&
        (_route() == 'account' || _route() == 'logoutConfirmation'),
    'Busy duplicate or route change was not blocked',
  );
  _record('logout_duplicate_and_connect_blocked');
  _server.logoutGate!.complete(
    _server.json({'detail': '계정 관리 대역 로그아웃 실패'}, 503),
  );
  await _wait(
    () => (_logoutConfirmation != null
        ? (_logoutConfirmation!.widget as dynamic).busy == false
        : _route() == 'account' &&
              !(_account.widget as AccountManagementScreen).busy),
    'Failed logout did not release request lock',
  );
  if (_logoutConfirmation != null) {
    _record('logout_failure_confirmation_preserved');
    ScaffoldMessenger.of(_logoutConfirmation!).hideCurrentSnackBar();
    await _settle(6);
    await _tap(_key(_logoutConfirmation!, 'logout-cancel')!);
    await _wait(() => _route() == 'account', 'Failure cancel lost account');
  }
  _require(
    (_account.widget as AccountManagementScreen).user.providerLabel ==
        initial.providerLabel,
    'Failure lost account',
  );
  _record('logout_failure_preserved');
  ScaffoldMessenger.of(_account).hideCurrentSnackBar();
  await _settle(6);
  _server.logoutGate = null;
  await _tap(_text(_account, '로그아웃')!);
  if (_logoutConfirmation != null) {
    await _tap(_key(_logoutConfirmation!, 'logout-confirm')!);
  }
  await _wait(() => _route() == 'login', 'Retry logout did not open Login');
  _require(
    _server.logoutCalls == 2 &&
        !(_find<LoginScreen>(_root)!.widget as LoginScreen).linkingGuest,
    'Retry count/session clearing differs',
  );
  _record('logout_retry_success_login');
  await _fresh('member');
  _record('final_member_scroll_zero');
  _coverage = true;
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  e01.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-account-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _fresh('member');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('ACCOUNT ready phase=$accountPhase output=${_output.path}');
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
      debugPrint('ACCOUNT FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
