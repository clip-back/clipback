// K01 render oracle and memory dependencies. Runtime discovery also compiles
// on 56721f9, where My opens the legacy NoticeSheet. No production requests.
import 'dart:async';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'logout_alignment_fixture.dart' as common;
import '../support/account_preview.dart' as account;
import '../support/archive_all_preview.dart' as isolated;

const noticeBackAsset = 'assets/icons/detail-back.svg';
List<Element> noticeElements(Element root) => common.logoutElements(root);
Element? noticeFind<T extends Widget>(Element root) =>
    common.logoutFind<T>(root);
Element? noticeText(Element root, String text) => common.logoutText(root, text);
Element? noticeKey(Element root, String key) => common.logoutKey(root, key);
Element? noticeScreen(Element root) => noticeElements(root)
    .where((e) => e.widget.runtimeType.toString() == 'NoticeListScreen')
    .firstOrNull;
Rect noticeBox(Element e) => common.logoutBox(e);
Map<String, double> noticeRect(Rect r) => common.logoutRect(r);
String? _color(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
Map<String, Object?> _paragraph(Element? e) {
  if (e == null) return {};
  final rich = e.widget is RichText ? e : noticeFind<RichText>(e);
  if (rich == null) return {};
  final p = rich.findRenderObject()! as RenderParagraph,
      s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': noticeRect(noticeBox(rich)),
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
  final svg = e.widget is SvgPicture ? e : noticeFind<SvgPicture>(e);
  if (svg == null) return {};
  final w = svg.widget as SvgPicture;
  return {
    'asset': w.bytesLoader is SvgAssetLoader
        ? (w.bytesLoader as SvgAssetLoader).assetName
        : null,
    'bounds': noticeRect(noticeBox(svg)),
    'unfiltered': w.colorFilter == null,
  };
}

ScrollPosition? _position(Element? root) {
  if (root == null) return null;
  final e = noticeFind<Scrollable>(root);
  return e is StatefulElement && e.state is ScrollableState
      ? (e.state as ScrollableState).position
      : null;
}

ScrollPosition? noticePosition(Element root) =>
    _position(noticeScreen(root) ?? noticeFind<NoticeSheet>(root));
ScrollPosition? noticeMyPosition(Element root) =>
    _position(noticeFind<MyScreen>(root));
Map<String, Object?> noticeMeasure(Element root) {
  final screen = noticeScreen(root),
      sheet = noticeFind<NoticeSheet>(root),
      target = screen ?? sheet;
  if (target == null) return {'active': false};
  final isScreen = screen != null,
      media = MediaQuery.of(target),
      position = noticePosition(root);
  final header = isScreen ? noticeKey(target, 'notice-header') : null,
      viewport = isScreen
          ? noticeKey(target, 'notice-viewport')
          : noticeFind<SingleChildScrollView>(target),
      back = isScreen ? noticeKey(target, 'notice-back-hit') : null;
  final scaffold = isScreen ? noticeFind<Scaffold>(target) : null;
  final titles = isScreen
      ? List<String>.from((screen.widget as dynamic).titles as List)
      : List<String>.from(mockNotices);
  final rows = <Map<String, Object?>>[];
  for (var i = 0; i < titles.length; i++) {
    final text = noticeText(target, titles[i]),
        row = isScreen ? noticeKey(target, 'notice-row-$i') : text;
    final surface = row == null ? null : noticeFind<Material>(row);
    final decorated = row == null
        ? null
        : noticeElements(row)
              .where(
                (e) =>
                    e.widget is DecoratedBox &&
                    (e.widget as DecoratedBox).decoration is BoxDecoration,
              )
              .firstOrNull;
    final decoration = decorated == null
        ? null
        : (decorated.widget as DecoratedBox).decoration as BoxDecoration;
    final colored = row == null ? null : noticeFind<ColoredBox>(row);
    final fill = row?.widget is Container
        ? (row!.widget as Container).color ?? decoration?.color
        : surface != null
        ? (surface.widget as Material).color
        : colored != null
        ? (colored.widget as ColoredBox).color
        : decoration?.color;
    rows.add({
      'index': i,
      'title': titles[i],
      'bounds': row == null ? null : noticeRect(noticeBox(row)),
      'style': _paragraph(text),
      'fill': _color(fill),
      'svgCount': row == null
          ? 0
          : noticeElements(row).where((e) => e.widget is SvgPicture).length,
      'interactiveChildren': row == null
          ? null
          : noticeElements(row)
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
  EdgeInsets? padding;
  final list = noticeFind<ListView>(target);
  if (list != null) {
    padding = (list.widget as ListView).padding?.resolve(
      Directionality.of(list),
    );
  }
  return {
    'active': true,
    'presentation': isScreen ? 'fullScreen' : 'legacySheet',
    'titles': titles,
    'headerStyle': _paragraph(noticeText(target, '공지사항')),
    'bounds': {
      'screen': scaffold == null ? null : noticeRect(noticeBox(scaffold)),
      'header': header == null ? null : noticeRect(noticeBox(header)),
      'viewport': viewport == null ? null : noticeRect(noticeBox(viewport)),
      'backHit': back == null ? null : noticeRect(noticeBox(back)),
    },
    'assets': {
      'back': _asset(isScreen ? noticeKey(target, 'notice-back-image') : null),
    },
    'rows': rows,
    'bottomNavigationCount': noticeElements(
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
    'scrollOffset': position?.pixels ?? 0,
    'maxScrollExtent': position?.maxScrollExtent ?? 0,
    'textScale': media.textScaler.scale(1),
  };
}

Map<String, Object?> noticeJudgment(Map<String, Object?> m) {
  final sf = <String>[], lf = <String>[], af = <String>[];
  if (m['active'] != true) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'assetPassed': true,
      'styleFailures': sf,
      'layoutFailures': lf,
      'assetFailures': af,
    };
  }
  if (m['presentation'] != 'fullScreen') {
    return {
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': false,
      'styleFailures': ['K01 full-screen roles absent in baseline sheet'],
      'layoutFailures': ['Legacy modal has no K01 fixed header/list viewport'],
      'assetFailures': ['Legacy sheet has no K01 back header'],
    };
  }
  bool near(Object? x, num y) => x is num && (x - y).abs() < .18;
  void n(Object? x, num y, String why) {
    if (!near(x, y)) lf.add('$why: $x != $y');
  }

  void style(Map p, int weight, String color, String why) {
    if (p['fontFamily'] != 'Pretendard' ||
        !near(p['fontSize'], 18) ||
        !near(p['scaledFontSize'], 18) ||
        p['fontWeight'] != weight ||
        !near(p['letterSpacing'], -.45) ||
        p['color'] != color ||
        p['height'] != null) {
      sf.add('$why: $p');
    }
  }

  final b = m['bounds'] as Map,
      frame = b['screen'] as Map?,
      header = b['header'] as Map?,
      viewport = b['viewport'] as Map?,
      hit = b['backHit'] as Map?,
      back = (m['assets'] as Map)['back'] as Map;
  if (frame == null || header == null || viewport == null || hit == null) {
    lf.add('Missing full-screen layout keys');
  } else {
    n(header['height'], 64, 'header64');
    n(header['top'], m['topSafeArea'] as num, 'top safety once');
    n(hit['width'], 48, 'back hit48');
    n(hit['height'], 48, 'back hit48');
    n(viewport['top'], header['bottom'] as num, 'list starts after header');
    n(
      (frame['bottom'] as num) - (viewport['bottom'] as num),
      m['bottomSafeArea'] as num,
      'bottom safe once',
    );
    final source = back['bounds'] as Map?;
    if (source != null) {
      n(source['width'], 24, 'back24');
      n(source['height'], 24, 'back24');
      n((source['left'] as num) - (frame['left'] as num), 16, 'back left16');
      n(
        (source['top'] as num) + 12,
        (header['top'] as num) + 32.5,
        'back center+.5',
      );
      n(
        ((m['headerStyle'] as Map)['bounds']['left'] as num) -
            (source['right'] as num),
        8,
        'header gap8',
      );
    }
    n(
      ((m['headerStyle'] as Map)['bounds']['top'] as num) +
          ((m['headerStyle'] as Map)['bounds']['height'] as num) / 2,
      (header['top'] as num) + 32.5,
      'header title center+.5',
    );
    final rows = m['rows'] as List;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i] as Map,
          r = row['bounds'] as Map?,
          p = row['style'] as Map;
      style(p, 500, '0xFF1A1A1A', 'notice title');
      if (p['maxLines'] != null ||
          p['overflow'] == 'ellipsis' ||
          p['softWrap'] != true ||
          p['didExceedMaxLines'] == true) {
        sf.add('Full title wraps naturally');
      }
      if (row['fill'] != '0xFFFFFFFF') lf.add('White notice row');
      if (row['svgCount'] != 0 || row['interactiveChildren'] != 0) {
        lf.add('Read-only title row must have no extra icons/actions');
      }
      if (r == null) {
        lf.add('Missing notice row');
        continue;
      }
      if ((r['height'] as num) < 78.8) lf.add('Row min79');
      n((r['left'] as num) - (frame['left'] as num), 0, 'row full width');
      n(r['width'], frame['width'] as num, 'row full width');
      n(
        (p['bounds']['left'] as num) - (r['left'] as num),
        16,
        'row inner left16',
      );
      if ((p['bounds']['right'] as num) > (r['right'] as num) - 15.8 ||
          (p['bounds']['top'] as num) < (r['top'] as num) + 15.8 ||
          (p['bounds']['bottom'] as num) > (r['bottom'] as num) - 15.8) {
        lf.add('Title inside16 padding');
      }
      if (i == 0 && near(m['scrollOffset'], 0)) {
        n(r['top'], header['bottom'] as num, 'first row starts after header');
      }
      if (i > 0) {
        n(
          (r['top'] as num) - (rows[i - 1]['bounds']['bottom'] as num),
          8,
          'row gap8',
        );
      }
      if (i == rows.length - 1 &&
          (m['maxScrollExtent'] as num) > 0 &&
          near(m['scrollOffset'], m['maxScrollExtent'] as num)) {
        n(
          (viewport['bottom'] as num) - (r['bottom'] as num),
          24,
          'last row bottom24',
        );
      }
    }
  }
  style(m['headerStyle'] as Map, 600, '0xFF000000', 'header');
  if (back['asset'] != noticeBackAsset || back['unfiltered'] != true) {
    af.add('Exact unfiltered original back SVG');
  }
  final padding = m['listPadding'] as Map?;
  if (padding == null) {
    lf.add('Scrollable list padding missing');
  } else {
    n(padding['top'], 0, 'list top0');
    n(padding['bottom'], 24, 'list bottom24');
    n(padding['left'], 0, 'list left0');
    n(padding['right'], 0, 'list right0');
  }
  if (m['bottomNavigationCount'] != 0) lf.add('K01 has no bottom tab bar');
  return {
    'stylePassed': sf.isEmpty,
    'layoutPassed': lf.isEmpty,
    'assetPassed': af.isEmpty,
    'styleFailures': sf,
    'layoutFailures': lf,
    'assetFailures': af,
  };
}

Future<Map<String, Object?>> noticeLoadFonts({bool loadForTest = false}) =>
    common.logoutInspectFonts(loadForTest: loadForTest);

class NoticeMemoryStorage extends common.LogoutMemoryStorage {
  Completer<void>? clearGate;
  int clearStarted = 0;
  @override
  Future<void> clear() async {
    clearStarted++;
    await clearGate?.future;
    await super.clear();
  }
}

class NoticeSocial extends isolated.ArchiveAllSocialAuth {
  bool revoked = false;
  int credentialChecks = 0;
  @override
  Future<AppleCredentialStatus> appleCredentialState() async {
    credentialChecks++;
    return revoked
        ? AppleCredentialStatus.revoked
        : AppleCredentialStatus.authorized;
  }
}

class NoticeServer {
  NoticeServer(String kind) : kind = kind, base = account.AccountServer(kind);
  String kind;
  final account.AccountServer base;
  get expected =>
      kind == 'guest' ? account.accountGuest : account.accountMember;
  get requests => base.requests;
  get unexpected => base.unexpected;
  get records => base.records;
  int get writes => base.writes;
  int get currentUserId => kind == 'guest' ? 2 : 1;
  int get logoutCalls => base.logoutCalls;
  Completer<http.Response>? get logoutGate => base.logoutGate;
  set logoutGate(Completer<http.Response>? value) => base.logoutGate = value;
  http.Response json(Object v, [int status = 200]) => base.json(v, status);
  late final client = MockClient((r) async {
    final path = r.url.path;
    if (path == '/api/v1/auth/guest') {
      kind = 'guest';
      base.records.clear();
    }
    if (path == '/api/v1/auth/share-credential') {
      base.requests.add({
        'method': r.method,
        'path': path,
        'query': r.url.queryParameters,
      });
      return json({
        'share_token': 'fixture-share',
        'expires_at': '2030-10-18T00:00:00Z',
        'user_id': currentUserId,
        'session_id': 1,
      });
    }
    if (path == '/api/v1/users/me' || path == '/api/v1/users/me/stats') {
      base.requests.add({
        'method': r.method,
        'path': path,
        'query': r.url.queryParameters,
      });
      return path.endsWith('/stats')
          ? json({
              'saved_count': expected.savedContentCount,
              'reopened_count': expected.revisitedContentCount,
            })
          : json({
              'id': currentUserId,
              'email': null,
              'display_name': expected.name,
              'is_guest': kind == 'guest',
              'created_at': '2026-10-18T00:00:00Z',
              'linked_providers': kind == 'guest'
                  ? <String>[]
                  : ['kakao', 'apple'],
            });
    }
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return http.Response.fromStream(await base.client.send(copy));
  });
}
