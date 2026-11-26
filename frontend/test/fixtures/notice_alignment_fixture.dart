// K01 render oracle (Figma 423:4464, #420) and memory dependencies.
// No production requests.
import 'dart:async';
import 'dart:math' as math;
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/notices.dart';
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
const noticeArrowAsset = 'assets/icons/chevron-right.svg';
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

ScrollPosition? noticePosition(Element root) => _position(noticeScreen(root));
ScrollPosition? noticeMyPosition(Element root) =>
    _position(noticeFind<MyScreen>(root));
Map<String, Object?> noticeMeasure(Element root) {
  final target = noticeScreen(root);
  if (target == null) return {'active': false};
  final media = MediaQuery.of(target), position = noticePosition(root);
  final header = noticeKey(target, 'notice-header'),
      viewport = noticeKey(target, 'notice-viewport'),
      back = noticeKey(target, 'notice-back-hit');
  final scaffold = noticeFind<Scaffold>(target);
  final listed = List<Notice>.from((target.widget as dynamic).notices as List);
  final titles = [for (final notice in listed) notice.title];
  final rows = <Map<String, Object?>>[];
  for (var i = 0; i < titles.length; i++) {
    final text = noticeKey(target, 'notice-title-$i'),
        row = noticeKey(target, 'notice-row-$i'),
        date = noticeKey(target, 'notice-date-$i'),
        pin = noticeKey(target, 'notice-pin-$i'),
        arrow = noticeKey(target, 'notice-arrow-$i');
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
      'published': listed[i].publishedLabel,
      'pinned': listed[i].pinned,
      'bounds': row == null ? null : noticeRect(noticeBox(row)),
      'style': _paragraph(text),
      'dateStyle': _paragraph(date),
      'pinStyle': _paragraph(pin),
      'arrow': _asset(arrow),
      'fill': _color(fill),
      'svgCount': row == null
          ? 0
          : noticeElements(row).where((e) => e.widget is SvgPicture).length,
      // InkWell builds its own GestureDetector, so only buttons are counted.
      'buttons': row == null
          ? null
          : noticeElements(row)
                .where(
                  (e) =>
                      (e.widget is InkWell &&
                          (e.widget as InkWell).onTap != null) ||
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
    'presentation': 'fullScreen',
    'titles': titles,
    'headerStyle': _paragraph(noticeText(target, '공지사항')),
    'bounds': {
      'screen': scaffold == null ? null : noticeRect(noticeBox(scaffold)),
      'header': header == null ? null : noticeRect(noticeBox(header)),
      'viewport': viewport == null ? null : noticeRect(noticeBox(viewport)),
      'backHit': back == null ? null : noticeRect(noticeBox(back)),
    },
    'assets': {'back': _asset(noticeKey(target, 'notice-back-image'))},
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

  final scale = (m['textScale'] as num?) ?? 1;
  void style(
    Map p,
    int weight,
    String color,
    String why, {
    num size = 19,
    num spacing = -.475,
  }) {
    if (p['fontFamily'] != 'Pretendard' ||
        !near(p['fontSize'], size) ||
        !near(p['scaledFontSize'], size * scale) ||
        p['fontWeight'] != weight ||
        !near(p['letterSpacing'], spacing) ||
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
      final d = row['dateStyle'] as Map, pin = row['pinStyle'] as Map;
      style(d, 500, '0xFF767676', 'notice date', size: 16, spacing: -.4);
      if (d['text'] != row['published']) sf.add('Published date text: $d');
      if (row['fill'] != '0xFFFFFFFF') lf.add('White notice row');
      if (row['svgCount'] != 1 || row['buttons'] != 1) {
        lf.add('Row is one button with one arrow');
      }
      if (r == null || d['bounds'] == null) {
        lf.add('Missing notice row');
        continue;
      }
      final pb = p['bounds'] as Map, db = d['bounds'] as Map;
      if ((r['height'] as num) < 81.8) lf.add('Row min82');
      n(
        r['height'],
        math.max(82, (db['height'] as num) + 8 + (pb['height'] as num) + 32),
        'row = date + 8 + title + 32',
      );
      n((r['left'] as num) - (frame['left'] as num), 0, 'row full width');
      n(r['width'], frame['width'] as num, 'row full width');
      var textLeft = (r['left'] as num) + 16;
      if (row['pinned'] == true) {
        final pinBounds = pin['bounds'] as Map?;
        if (pin['text'] != '📌' || pinBounds == null) {
          sf.add('Pinned notice shows 📌');
        } else {
          if (!near(pin['fontSize'], 19) || pin['fontWeight'] != 500) {
            sf.add('📌 19 Medium: $pin');
          }
          n((pinBounds['left'] as num) - (r['left'] as num), 16, 'pin left16');
          textLeft = (pinBounds['right'] as num) + 16;
        }
      }
      n(pb['left'], textLeft, 'title after pin gap16');
      n(db['left'], textLeft, 'date after pin gap16');
      n((pb['top'] as num) - (db['bottom'] as num), 8, 'date above title 8');
      n((db['top'] as num) - (r['top'] as num), 16, 'row inner top16');
      n((r['bottom'] as num) - (pb['bottom'] as num), 16, 'row inner bottom16');
      final arrow = row['arrow'] as Map, ab = arrow['bounds'] as Map?;
      if (arrow['asset'] != noticeArrowAsset || ab == null) {
        af.add('Row chevron-right SVG');
      } else {
        n(ab['width'], 24, 'arrow24');
        n(ab['height'], 24, 'arrow24');
        n((r['right'] as num) - (ab['right'] as num), 16, 'arrow right16');
        if ((pb['right'] as num) > (ab['left'] as num) - 7.8) {
          lf.add('Title stays left of the arrow');
        }
      }
      if (i == 0 && near(m['scrollOffset'], 0)) {
        n(r['top'], header['bottom'] as num, 'first row starts after header');
      }
      if (i > 0) {
        n(
          (r['top'] as num) - (rows[i - 1]['bounds']['bottom'] as num),
          5,
          'row gap5',
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
  if ((m['headerStyle'] as Map)['text'] != '공지사항') sf.add('Header title');
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

/// [list] as a `GET /api/v1/notices` answer (#486).
Map<String, Object?> noticesJson(List<Notice> list) => {
  'notices': [
    for (final n in list)
      {
        'title': n.title,
        'published_on': n.publishedLabel.replaceAll('. ', '-'),
        'pinned': n.pinned,
        'intro_title': n.introTitle,
        'intro': n.intro,
        'steps': [
          for (final s in n.steps)
            {'title': s.title, 'body': s.body, 'note': s.note},
        ],
        'closing_title': n.closingTitle,
        'closing': n.closing,
      },
  ],
};

/// A server-only example: not pinned and no steps, like a policy revision notice.
const revisionNotice = Notice(
  title: '개인정보 처리방침 개정 안내',
  publishedLabel: '2026. 12. 02',
  pinned: false,
  introTitle: '개인정보 처리방침이 바뀌어요.',
  intro:
      '2027년 1월 1일부터 개정된 개인정보 처리방침이 시행돼요. '
      '바뀌는 내용을 미리 확인해 주세요.',
  steps: [],
  closingTitle: '자세한 내용은 처리방침에서 확인해 주세요.',
  closing: '마이의 개인정보 처리방침에서 개정된 전문을 볼 수 있어요.',
);

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

  /// `GET /api/v1/notices`: 'same' (the in-app two), 'added' (plus
  /// [revisionNotice]) or 'fail' (503 for this path only).
  String noticeMode = 'same';
  late final client = MockClient((r) async {
    final path = r.url.path;
    if (r.method == 'GET' && path == '/api/v1/notices') {
      base.requests.add({
        'method': r.method,
        'path': path,
        'query': r.url.queryParameters,
      });
      return switch (noticeMode) {
        'fail' => json({'detail': 'controlled'}, 503),
        'added' => json(noticesJson([...notices, revisionNotice])),
        _ => json(noticesJson(notices)),
      };
    }
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
              'recent_reopened_count': expected.revisitedContentCount,
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
