// D04: real root/API fixtures and baseline-compatible rendered measurements.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../support/login_alignment_preview.dart' as login;
import 'splash_alignment_fixture.dart' as b;

const pendingLink = 'https://example.com/submitted-link';
const pendingSession = ApiSession(
  accessToken: 'fixture-d04-access',
  refreshToken: 'fixture-d04-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);

class LinkPendingServer extends login.LoginServer {
  LinkPendingServer() {
    guest = false;
  }
  Completer<http.Response>? gate;
  final submissions = <String>[];
  Map<String, Object?>? saved;
  Map<String, Object?> content(String url) => {
    'id': 201,
    'content_type': 'link',
    'source': 'web',
    'title': '저장 결과 확인',
    'summary': '요청한 링크의 저장 결과입니다.',
    'original_url': url,
    'categories': <Object>[],
    'tags': <Object>[],
    'assets': <Object>[],
    'is_favorite': false,
    'saved_at': '2026-10-19T00:00:00Z',
    'last_viewed_at': null,
    'summary_status': 'not_requested',
  };
  void resolve({bool success = true}) {
    final pending = gate;
    if (pending == null || pending.isCompleted) return;
    if (success) {
      saved = content(submissions.last);
      pending.complete(this.json(saved!, 201));
    } else {
      pending.complete(this.json({'detail': '검증 요청 실패'}, 503));
    }
  }

  late final controlledClient = MockClient((r) async {
    final path = r.url.path;
    if (path == '/api/v1/contents' && r.method == 'POST') {
      final url = (jsonDecode(r.body) as Map)['original_url'] as String;
      submissions.add(url);
      gate = Completer<http.Response>();
      return gate!.future;
    }
    if (path == '/api/v1/feed') {
      return this.json({
        'items': saved == null ? <Object>[] : [saved!],
        'next_cursor': null,
      });
    }
    if (path == '/api/v1/users/me/stats') {
      return this.json({
        'saved_count': saved == null ? 0 : 1,
        'reopened_count': 0,
      });
    }
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return http.Response.fromStream(await client.send(copy));
  });
  void close() {
    resolve(success: false);
    controlledClient.close();
    client.close();
  }
}

Map<String, Object?> linkPendingMeasure(Element root) {
  final target = b.splashKey(root, 'link-pending-skeleton');
  if (target == null) return {'active': false};
  Map<String, double>? box(String k) {
    final e = b.splashKey(root, k);
    return e == null ? null : b.splashRect(b.splashBox(e));
  }

  Map<String, Object?>? role(String k) {
    final e = b.splashKey(root, k);
    if (e == null) return null;
    final rich = b.splashFind<RichText>(e)!;
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
    };
  }

  Map<String, Object?>? paint(String key) {
    final e = b.splashKey(root, key);
    if (e == null) return null;
    final w = e.widget;
    final decoration = w is DecoratedBox
        ? w.decoration
        : w is Container
        ? w.decoration
        : null;
    return {
      'bounds': box(key),
      'color': decoration is BoxDecoration
          ? decoration.color?.toARGB32()
          : null,
      'radius': decoration is BoxDecoration
          ? (decoration.borderRadius as BorderRadius?)?.topLeft.x
          : null,
    };
  }

  final button = b.splashFind<SaveFlowButton>(root)!,
      w = button.widget as SaveFlowButton,
      dec = b.splashFind<DecoratedBox>(button)!.widget as DecoratedBox,
      shape = dec.decoration as BoxDecoration;
  final validation = b.splashFind<ValidationMessage>(root)!;
  final position = target.findAncestorStateOfType<ScrollableState>()?.position;
  Map<String, double>? viewport;
  target.visitAncestorElements((e) {
    if (e.widget is SingleChildScrollView) {
      viewport = b.splashRect(b.splashBox(e));
      return false;
    }
    return true;
  });
  return {
    'active': true,
    'viewport': viewport,
    'previewHeading': role('link-pending-preview-heading'),
    'categoryHeading': role('link-pending-category-heading'),
    'categoryStatus': role('link-pending-category-status'),
    'status': role('link-pending-status'),
    'preview': paint('link-pending-preview'),
    'thumbnail': paint('link-pending-thumbnail'),
    'bar1': paint('link-pending-bar-1'),
    'bar2': paint('link-pending-bar-2'),
    'bar3': paint('link-pending-bar-3'),
    'category': paint('link-pending-category'),
    'categoryBar': paint('link-pending-category-bar'),
    'categoryRow': box('link-pending-category-row'),
    'validation': b.splashRect(b.splashBox(validation)),
    'button': {
      'bounds': b.splashRect(b.splashBox(button)),
      'label': w.label,
      'loading': w.loading,
      'enabled': w.enabled,
      'color': shape.color?.toARGB32(),
    },
    'scrollOffset': position?.pixels,
    'maxScrollExtent': position?.maxScrollExtent,
  };
}

Map<String, Object?> linkPendingJudgment(Map<String, Object?> m) {
  final style = <String>[], layout = <String>[];
  if (m['active'] != true) {
    return {
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': true,
      'styleFailures': ['target absent'],
      'layoutFailures': ['target absent'],
    };
  }
  Map val(String k) => (m[k] as Map?) ?? {};
  Map rect(String k) => val(k)['bounds'] as Map? ?? val(k);
  double n(Map x, String k) => (x[k] as num?)?.toDouble() ?? double.nan;
  void near(String key, double a, double v) {
    if (!a.isFinite || (a - v).abs() > .2) {
      layout.add('$key $a != $v');
    }
  }

  for (final entry in {
    'previewHeading': ['미리보기', 16.0, 600, -.4, 0xff000000],
    'categoryHeading': ['카테고리', 16.0, 600, -.4, 0xff000000],
    'categoryStatus': ['허투루가 분류하고 있어요.', 14.0, 500, -.35, 0xff767676],
    'status': ['허투루가 정보를 추출 중입니다...', 14.0, 500, -.35, 0xff767676],
  }.entries) {
    final s = val(entry.key), v = entry.value;
    if (s['text'] != v[0] ||
        s['font'] != 'Pretendard' ||
        s['size'] != v[1] ||
        s['weight'] != v[2] ||
        s['spacing'] != v[3] ||
        s['color'] != v[4] ||
        s['height'] != null ||
        s['scaledSize'] != v[1]) {
      style.add(entry.key);
    }
  }
  final preview = rect('preview'),
      image = rect('thumbnail'),
      heading = rect('previewHeading'),
      category = rect('category'),
      row = rect('categoryRow'),
      button = rect('button'),
      status = rect('status');
  near(
    'validation to preview',
    n(heading, 'top') - n(rect('validation'), 'bottom'),
    32,
  );
  near('heading to card', n(preview, 'top') - n(heading, 'bottom'), 16);
  near('card height', n(preview, 'height'), 116);
  near('thumbnail width', n(image, 'width'), 164);
  near('thumbnail height', n(image, 'height'), 100);
  near('card padding x', n(image, 'left') - n(preview, 'left'), 8);
  near('card padding y', n(image, 'top') - n(preview, 'top'), 8);
  near('text column gap', n(rect('bar1'), 'left') - n(image, 'right'), 16);
  near(
    'bar1 width',
    n(rect('bar1'), 'width'),
    math.min(139, n(preview, 'width') - 196),
  );
  near('bar2 gap', n(rect('bar2'), 'top') - n(rect('bar1'), 'bottom'), 4);
  near('bar3 top', n(rect('bar3'), 'top') - n(preview, 'top'), 85);
  for (final key in ['bar1', 'bar2', 'bar3']) {
    near('$key height', n(rect(key), 'height'), 15);
  }
  near('preview to category row', n(row, 'top') - n(preview, 'bottom'), 32);
  near('row to category', n(category, 'top') - n(row, 'bottom'), 16);
  near('category height', n(category, 'height'), 55);
  near('category bar height', n(rect('categoryBar'), 'height'), 24);
  near('category bar width', n(rect('categoryBar'), 'width'), 164);
  near('status to button', n(button, 'top') - n(status, 'bottom'), 8);
  near('button height', n(button, 'height'), 56);
  if (val('button')['label'] != '닫기' ||
      val('button')['loading'] != false ||
      val('button')['enabled'] != false ||
      val('button')['color'] != 0xffd1d1d1) {
    style.add('disabled close');
  }
  for (final key in ['preview', 'category']) {
    if (val(key)['color'] != 0xffffffff || val(key)['radius'] != 4.0) {
      style.add(key);
    }
  }
  for (final key in ['thumbnail', 'bar1', 'bar2', 'bar3', 'categoryBar']) {
    if (val(key)['color'] != 0xffe4e4e4 || val(key)['radius'] != 4.0) {
      style.add(key);
    }
  }
  return {
    'stylePassed': style.isEmpty,
    'layoutPassed': layout.isEmpty,
    'assetPassed': true,
    'styleFailures': style,
    'layoutFailures': layout,
  };
}
