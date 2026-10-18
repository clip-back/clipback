// A02 fixture: actual ClipbackApp with in-memory authentication only.
// Native share drafts and credentials are isolated before the first bootstrap.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/entry_widgets.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'archive_all_preview.dart' as e01;

const loginPhase = String.fromEnvironment(
  'LOGIN_ALIGNMENT_PHASE',
  defaultValue: 'before',
);

List<SocialLoginProvider> loginPlatformProviders(TargetPlatform platform) =>
    platform == TargetPlatform.iOS
    ? const [
        SocialLoginProvider.google,
        SocialLoginProvider.kakao,
        SocialLoginProvider.apple,
      ]
    : platform == TargetPlatform.android
    ? const [SocialLoginProvider.google, SocialLoginProvider.kakao]
    : const [];

ThemeData loginTheme({TargetPlatform? platform}) => ThemeData(
  useMaterial3: true,
  platform: platform,
  fontFamily: 'Pretendard',
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.main,
    surface: AppColors.bg,
  ),
  textTheme: ThemeData().textTheme.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  ),
);

class LoginMemoryStorage extends ApiSessionStorage {
  ApiSession? value;
  int writes = 0, clears = 0;
  @override
  Future<ApiSession?> read() async => value;
  @override
  Future<void> write(ApiSession next) async {
    value = next;
    writes++;
  }

  @override
  Future<void> clear() async {
    value = null;
    clears++;
  }
}

class LoginControlledSocial extends SocialAuth {
  LoginControlledSocial(this.platform);
  final TargetPlatform platform;
  final calls = <String>[];
  final noncePresent = <bool>[];
  Completer<SocialCredential?>? gate;
  bool cancel = true;
  bool fail = false;
  int signOuts = 0;
  @override
  List<SocialLoginProvider> get supportedProviders =>
      loginPlatformProviders(platform);
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async {
    calls.add(provider.name);
    noncePresent.add(nonce != null && nonce.isNotEmpty);
    if (gate != null) return gate!.future;
    if (fail) throw const SocialAuthException('로그인 대역 인증 실패');
    return cancel
        ? null
        : const SocialCredential(
            token: 'fixture-provider',
            authorizationCode: 'fixture-code',
            providerUserId: 'fixture-user',
            displayName: '로그인 검증',
          );
  }

  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {
    signOuts++;
  }

  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.authorized;
}

class LoginServer {
  bool guest = true, newUser = false, failIssuance = false;
  String provider = 'google';
  int challenges = 0, socialIssuances = 0, guestIssuances = 0, logouts = 0;
  final requests = <Map<String, Object?>>[];
  final unexpected = <String>[];
  http.Response json(Object v, [int status = 200]) => http.Response(
    jsonEncode(v),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  Map<String, Object> tokens(String prefix) => {
    'access_token': 'fixture-$prefix',
    'refresh_token': 'fixture-refresh-$prefix',
    'expires_in': 3600,
    'refresh_expires_in': 86400,
    'is_new_user': newUser,
  };
  late final client = MockClient((r) async {
    final path = r.url.path;
    requests.add({'method': r.method, 'path': path});
    if (path == '/api/v1/auth/social/apple/challenge') {
      challenges++;
      return json({
        'challenge_id': 'fixture-challenge-$challenges',
        'nonce': 'fixture-nonce-$challenges',
        'expires_at': '2030-10-18T00:00:00Z',
      });
    }
    if (RegExp(
      r'^/api/v1/auth/social/(google|kakao|apple)(/upgrade)?$',
    ).hasMatch(path)) {
      socialIssuances++;
      if (failIssuance) {
        failIssuance = false;
        return json({'detail': '로그인 대역 저장 실패'}, 503);
      }
      guest = false;
      provider = path.split('/')[5];
      return json(tokens('social'));
    }
    switch (path) {
      case '/api/v1/auth/guest':
        guestIssuances++;
        guest = true;
        return json(tokens('guest'), 201);
      case '/api/v1/auth/logout':
        logouts++;
        return http.Response('', 204);
      case '/api/v1/auth/refresh':
        return json(tokens('refresh'));
      case '/api/v1/users/me':
        return json({
          'id': guest ? 1 : 2,
          'display_name': guest ? '게스트' : '로그인 검증',
          'email': null,
          'is_guest': guest,
          'linked_providers': guest ? <String>[] : [provider],
          'created_at': '2026-10-18T00:00:00Z',
        });
      case '/api/v1/users/me/stats':
        return json({'saved_count': 0, 'reopened_count': 0});
      case '/api/v1/categories':
        return json(<Object>[]);
      case '/api/v1/feed':
        return json({'items': <Object>[], 'next_cursor': null});
      case '/api/v1/auth/share-credential':
        return json({
          'share_token': 'fixture-share',
          'expires_at': '2030-10-18T00:00:00Z',
          'user_id': guest ? 1 : 2,
          'session_id': 1,
        });
      case '/api/v1/metrics/events':
        return json({}, 201);
    }
    unexpected.add('${r.method} $path');
    return json({'detail': 'Unsupported login fixture request'}, 501);
  });
  int get contentWrites => requests
      .where(
        (r) =>
            (r['path'] as String).startsWith('/api/v1/contents') &&
            r['method'] != 'GET',
      )
      .length;
}

List<Element> _elements(Element e) => e01.archiveAllElements(e);
Element? _find<T extends Widget>(Element e) => e01.archiveAllFind<T>(e);
Element? _key(Element e, String key) => e01.archiveAllKey(e, key);
Element? _text(Element e, String text) => e01.archiveAllText(e, text);
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
Map<String, Object?> _paragraph(Element e) {
  final p = e.findRenderObject()! as RenderParagraph,
      s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': _rect(_box(e)),
    'fontFamily': s.fontFamily,
    'fontFamilyFallback': s.fontFamilyFallback,
    'fontSize': s.fontSize,
    'fontWeight': s.fontWeight?.value,
    'letterSpacing': s.letterSpacing,
    'height': s.height,
    'color': _color(s.color),
    'maxLines': p.maxLines,
    'overflow': p.overflow.name,
    'softWrap': p.softWrap,
    'textAlign': p.textAlign.name,
    'scaledFontSize': s.fontSize == null
        ? null
        : p.textScaler.scale(s.fontSize!),
    'didExceedMaxLines': p.didExceedMaxLines,
  };
}

Element? _paragraphElement(Element? e) {
  if (e == null) return null;
  return _elements(e)
      .where(
        (e) =>
            e.findRenderObject() is RenderParagraph && (e.widget is RichText),
      )
      .firstOrNull;
}

Map<String, Object?> _asset(Element? e) {
  if (e == null) return {};
  final svg = e.widget is SvgPicture ? e : _find<SvgPicture>(e);
  if (svg != null) {
    final w = svg.widget as SvgPicture;
    return {
      'asset': w.bytesLoader is SvgAssetLoader
          ? (w.bytesLoader as SvgAssetLoader).assetName
          : null,
      'bounds': _rect(_box(svg)),
      'unfiltered': w.colorFilter == null,
    };
  }
  final image = e.widget is Image ? e : _find<Image>(e);
  if (image != null) {
    final w = image.widget as Image;
    ImageProvider p = w.image;
    if (p is ResizeImage) p = p.imageProvider;
    return {
      'asset': p is AssetImage ? p.assetName : null,
      'bounds': _rect(_box(image)),
      'fit': w.fit?.name,
    };
  }
  return {'asset': null, 'bounds': _rect(_box(e))};
}

ScrollPosition? loginPosition(Element root) {
  final login = _find<LoginScreen>(root);
  if (login == null) return null;
  final e = _elements(login).where((e) => e.widget is Scrollable).firstOrNull;
  if (e == null) return null;
  final state = (e as StatefulElement).state;
  return state is ScrollableState ? state.position : null;
}

Map<String, Object?> loginFontBundle = {
  'available': false,
  'declared': false,
  'faceVerified': false,
};
Future<Map<String, Object?>> loginInspectFontBundle({
  bool loadForTest = false,
}) async {
  try {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final declared = manifest.any(
      (v) =>
          v['family'] == 'RiaSansLogin' &&
          (v['fonts'] as List).any(
            (f) => f['asset'] == 'assets/fonts/RiaSans-Regular.otf',
          ),
    );
    final bytes = await rootBundle.load('assets/fonts/RiaSans-Regular.otf');
    final raw = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    bool contains(List<int> pattern) {
      for (var i = 0; i <= raw.length - pattern.length; i++) {
        var match = true;
        for (var j = 0; j < pattern.length; j++) {
          if (raw[i + j] != pattern[j]) {
            match = false;
            break;
          }
        }
        if (match) return true;
      }
      return false;
    }

    final face = 'RiaSans-Regular'.codeUnits;
    final faceVerified =
        contains(face) ||
        contains([
          for (final c in face) ...[0, c],
        ]);
    final magic = String.fromCharCodes(raw.take(4));
    if (loadForTest) {
      final loader = FontLoader('RiaSansLogin')..addFont(Future.value(bytes));
      await loader.load();
    }
    loginFontBundle = {
      'available': true,
      'declared': declared,
      'faceVerified': faceVerified,
      'size': raw.length,
      'magic': magic,
      'path': 'assets/fonts/RiaSans-Regular.otf',
      'family': 'RiaSansLogin',
      'loadedForTest': loadForTest,
    };
  } catch (_) {
    loginFontBundle = {
      'available': false,
      'declared': false,
      'faceVerified': false,
      'reason':
          'Target font not registered or available in this build; captures remain allowed.',
    };
  }
  return loginFontBundle;
}

Element? _ancestor(Element e, bool Function(Widget) p) {
  Element? found;
  e.visitAncestorElements((v) {
    if (p(v.widget)) {
      found = v;
      return false;
    }
    return true;
  });
  return found;
}

String loginLabel(SocialLoginProvider p, {bool legacy = false}) => switch (p) {
  SocialLoginProvider.kakao => '카카오로 계속하기',
  SocialLoginProvider.apple => 'Apple로 계속하기',
  SocialLoginProvider.google => legacy ? '구글로 계속하기' : 'Google로 계속하기',
};
Map<String, Object?> loginMeasure(Element root) {
  final e = _find<LoginScreen>(root);
  if (e == null) return {'active': false};
  final w = e.widget as LoginScreen,
      media = MediaQuery.of(e),
      frame = _find<Scaffold>(e)!;
  final f = _box(frame), position = loginPosition(e);
  final logo =
      _key(e, 'login-logo') ??
      _elements(e).where((v) => v.widget is SvgPicture).firstOrNull;
  final tagline = _key(e, 'login-tagline') ?? _text(e, '저장한 정보를 다시 볼 순간으로');
  final guest =
      _key(e, 'login-guest-label') ??
      _text(e, w.linkingGuest ? '게스트로 계속 사용' : '게스트로 시작하기');
  final or = _key(e, 'login-or') ?? _text(e, '또는');
  final buttons = <Map<String, Object?>>[];
  for (final p in w.providers) {
    final label =
        _key(e, 'login-provider-label-${p.name}') ??
        _text(e, loginLabel(p)) ??
        _text(e, loginLabel(p, legacy: true));
    if (label == null) continue;
    final button =
        _key(e, 'login-provider-${p.name}') ??
        _ancestor(label, (v) => v is SocialButton)!;
    final ink = _find<InkWell>(button),
        mat = _find<Material>(button),
        icon = _key(e, 'login-provider-icon-${p.name}');
    final para = _paragraphElement(label)!;
    final d = _elements(button)
        .where(
          (e) =>
              e.widget is DecoratedBox &&
              (e.widget as DecoratedBox).decoration is BoxDecoration,
        )
        .firstOrNull;
    final decoration = d == null
        ? null
        : (d.widget as DecoratedBox).decoration as BoxDecoration;
    buttons.add({
      'provider': p.name,
      'bounds': _rect(_box(button)),
      'label': _paragraph(para),
      'icon': {
        ..._asset(icon ?? _find<Image>(button) ?? _find<Icon>(button)),
        if (icon != null) 'bounds': _rect(_box(icon)),
        if (_find<Image>(button) != null)
          'sourceBounds': _rect(_box(_find<Image>(button)!)),
        'clipPresent': icon != null && _find<ClipRect>(icon) != null,
      },
      'enabled': ink != null && (ink.widget as InkWell).onTap != null,
      'color': _color(mat == null ? null : (mat.widget as Material).color),
      'radius': mat == null
          ? null
          : ((mat.widget as Material).borderRadius as BorderRadius?)?.topLeft.x,
      'borderWidth': (decoration?.border as Border?)?.top.width,
      'borderColor': _color((decoration?.border as Border?)?.top.color),
    });
  }
  buttons.sort(
    (a, b) =>
        (a['bounds'] as Map)['top'].compareTo((b['bounds'] as Map)['top']),
  );
  final guestHit =
      _key(e, 'login-guest-hit') ??
      (guest == null ? null : _ancestor(guest, (v) => v is TextButton));
  final divider = _key(e, 'login-divider');
  return {
    'active': true,
    'ordinary': !w.linkingGuest && w.onBack == null && w.providers.isNotEmpty,
    'busy': w.busy,
    'linkingGuest': w.linkingGuest,
    'inputProviderOrder': w.providers.map((p) => p.name).toList(),
    'frame': _rect(f),
    'safeTop': media.viewPadding.top,
    'safeBottom': media.viewPadding.bottom,
    'textScale': media.textScaler.scale(16) / 16,
    'scrollOffset': position?.pixels ?? 0,
    'maxScrollExtent': position?.maxScrollExtent ?? 0,
    'viewport': _key(e, 'login-a02-viewport') == null
        ? null
        : _rect(_box(_key(e, 'login-a02-viewport')!)),
    'body': _key(e, 'login-a02-body') == null
        ? null
        : _rect(_box(_key(e, 'login-a02-body')!)),
    'logoGroup': _key(e, 'login-logo-group') == null
        ? null
        : _rect(_box(_key(e, 'login-logo-group')!)),
    'logo': _asset(logo),
    'tagline': tagline == null ? null : _paragraph(_paragraphElement(tagline)!),
    'buttons': buttons,
    'divider': divider == null ? null : _rect(_box(divider)),
    'or': or == null ? null : _paragraph(_paragraphElement(or)!),
    'guest': guest == null ? null : _paragraph(_paragraphElement(guest)!),
    'guestHit': guestHit == null ? null : _rect(_box(guestHit)),
    'dividerLeft': _asset(_key(e, 'login-divider-left')),
    'dividerRight': _asset(_key(e, 'login-divider-right')),
    'fontBundle': Map<String, Object?>.from(loginFontBundle),
    // SVG painters use FittedBox to fit vector artwork. Preserve the total
    // as a diagnostic, and detect shrinking only when actual text is inside.
    'fittedBoxCount': _elements(e).where((e) => e.widget is FittedBox).length,
    'textFittedBoxCount': _elements(e)
        .where(
          (e) =>
              e.widget is FittedBox &&
              _elements(e).any((child) => child.widget is RichText),
        )
        .length,
    'fakeStatusCount': _elements(e)
        .where(
          (e) => e.widget is EntryStatusBar || e.widget is EntryHomeIndicator,
        )
        .length,
  };
}

Map<String, Object?> loginJudgment(Map<String, Object?> m) {
  if (m['active'] != true || m['ordinary'] != true || m['busy'] == true) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'assetPassed': true,
      'scope':
          'Stable ordinary A02 only; busy spinner, legacy and other routes use behavior/framework checks. Final ordinary Login must pass all targets.',
    };
  }
  final sf = <String>[], lf = <String>[], af = <String>[];
  bool near(Object? a, double b, [double t = .15]) =>
      a is num && (a - b).abs() <= t;
  void check(List<String> failures, bool p, String why) {
    if (!p) failures.add(why);
  }

  void style(
    Object? v,
    String role,
    String family,
    double size,
    int weight,
    double tracking,
    String color,
  ) {
    final p = v is Map ? v : const {};
    check(
      sf,
      p['fontFamily'] == family &&
          near(p['fontSize'], size) &&
          p['fontWeight'] == weight &&
          near(p['letterSpacing'] ?? 0, tracking) &&
          p['height'] == null &&
          p['color'] == color &&
          near(p['scaledFontSize'], size),
      '$role font/family/weight/tracking/color/AUTO/scale',
    );
  }

  style(m['tagline'], 'tagline', 'RiaSansLogin', 16, 400, 0, '0xFF767676');
  style(m['or'], 'divider', 'Pretendard', 14, 500, 0, '0xFFD1D1D1');
  style(m['guest'], 'guest', 'Pretendard', 15, 600, 0, '0xFF484848');
  final frame = m['frame'] as Map,
      safeTop = (m['safeTop'] as num).toDouble(),
      scroll = (m['scrollOffset'] as num).toDouble(),
      left = (frame['left'] as num).toDouble(),
      width = (frame['width'] as num).toDouble();
  final origin = (frame['top'] as num).toDouble() + safeTop - scroll;
  final logo = m['logo'] as Map,
      lb = logo['bounds'] is Map ? logo['bounds'] as Map : const {},
      group = m['logoGroup'] is Map ? m['logoGroup'] as Map : const {},
      tag = m['tagline'] is Map ? m['tagline'] as Map : const {},
      tb = tag['bounds'] is Map ? tag['bounds'] as Map : const {};
  check(
    lf,
    near(lb['width'], 178.525) &&
        near(lb['height'], 60) &&
        near(lb['top'], origin + 129) &&
        near(
          (lb['left'] is num && lb['width'] is num)
              ? (lb['left'] as num) + (lb['width'] as num) / 2
              : null,
          left + width / 2 + .5,
        ),
    'logo slot/position',
  );
  check(
    lf,
    near(group['width'], 232) &&
        near(group['height'], 99) &&
        near(tb['top'], origin + 205) &&
        near(tb['height'], 23),
    'logo group/tagline natural metrics/gap16',
  );
  final buttons = (m['buttons'] as List).cast<Map<String, Object?>>();
  final expected = (m['inputProviderOrder'] as List).contains('apple')
      ? ['kakao', 'apple', 'google']
      : ['kakao', 'google'];
  final actual = buttons.map((b) => b['provider']).toList();
  check(
    lf,
    actual.join(',') == expected.join(','),
    'provider order/availability',
  );
  for (var i = 0; i < buttons.length; i++) {
    final b = buttons[i],
        p = b['provider'] as String,
        r = b['bounds'] as Map,
        label = b['label'] as Map,
        pr = label['bounds'] as Map;
    style(
      label,
      'social $p',
      'Pretendard',
      15,
      600,
      -.375,
      p == 'apple' ? '0xFFFFFFFF' : '0xFF1A1A1A',
    );
    check(
      lf,
      near(r['left'], left + 16) &&
          near(r['width'], width - 32) &&
          near(r['height'], 52) &&
          near(r['top'], origin + 387 + i * 60),
      '$p button width/52/top/gap8',
    );
    check(
      lf,
      near(
        (pr['left'] as num) + (pr['width'] as num) / 2,
        left + width / 2 + (p == 'kakao' ? 1 : 1.5),
      ),
      '$p label independent center',
    );
    final icon = b['icon'] as Map,
        ir = icon['bounds'] is Map ? icon['bounds'] as Map : const {};
    final iw = p == 'kakao'
            ? 24.0
            : p == 'apple'
            ? 21.0
            : 18.0,
        ih = p == 'apple' ? 20.0 : iw,
        il = p == 'google' ? 18.0 : 16.0;
    check(
      lf,
      near(ir['width'], iw) &&
          near(ir['height'], ih) &&
          near(ir['left'], left + 16 + il) &&
          near(
            (ir['top'] is num && ir['height'] is num)
                ? (ir['top'] as num) + (ir['height'] as num) / 2
                : null,
            (r['top'] as num) + 26,
          ),
      '$p icon slot/center',
    );
    check(
      lf,
      b['radius'] == 8.0 &&
          b['color'] ==
              (p == 'kakao'
                  ? '0xFFFDDC3F'
                  : p == 'apple'
                  ? '0xFF000000'
                  : '0xFFFFFFFF'),
      '$p surface/radius',
    );
    if (p == 'google') {
      check(
        lf,
        near(b['borderWidth'], .5) && b['borderColor'] == '0xFFD1D1D1',
        'google border .5',
      );
    }
    final expectedAsset = p == 'kakao'
        ? 'assets/figma/kakao-login.png'
        : p == 'apple'
        ? 'assets/figma/login-a02-apple.png'
        : 'assets/figma/google-login.png';
    check(
      af,
      icon['asset'] == expectedAsset &&
          icon['fit'] == 'fill' &&
          icon['clipPresent'] == true,
      '$p exact original bitmap asset and clipped fill',
    );
    final source = icon['sourceBounds'] is Map
        ? icon['sourceBounds'] as Map
        : const {};
    final sx = p == 'kakao'
            ? 1.5833
            : p == 'apple'
            ? 1.3894
            : 1.0,
        sy = p == 'kakao'
            ? 1.5833
            : p == 'apple'
            ? 1.2377
            : 1.0,
        dx = p == 'kakao'
            ? -.2917
            : p == 'apple'
            ? -.1947
            : 0.0,
        dy = p == 'kakao'
            ? -.2917
            : p == 'apple'
            ? -.1189
            : 0.0;
    check(
      lf,
      near(source['width'], iw * sx) &&
          near(source['height'], ih * sy) &&
          near(
            source['left'],
            (ir['left'] is num ? (ir['left'] as num).toDouble() : 0) + iw * dx,
          ) &&
          near(
            source['top'],
            (ir['top'] is num ? (ir['top'] as num).toDouble() : 0) + ih * dy,
          ),
      '$p original source crop coefficients',
    );
  }
  final lastBottom =
      origin + 387 + expected.length * 52 + (expected.length - 1) * 8;
  final divider = m['divider'] is Map ? m['divider'] as Map : const {},
      or = m['or'] is Map ? m['or'] as Map : const {},
      ob = or['bounds'] is Map ? or['bounds'] as Map : const {},
      hit = m['guestHit'] is Map ? m['guestHit'] as Map : const {};
  check(
    lf,
    near(divider['top'], lastBottom + 24) &&
        near(divider['height'], 17) &&
        near(ob['height'], 17),
    'divider24/natural17',
  );
  check(
    lf,
    near(hit['height'], 44) && near(hit['top'], lastBottom + 24 + 17 + 11),
    'guest hit44/gap11',
  );
  check(
    lf,
    m['textFittedBoxCount'] == 0 && m['fakeStatusCount'] == 0,
    'no font shrinking or app OS replicas',
  );
  final font = m['fontBundle'] as Map;
  check(
    af,
    font['available'] == true &&
        font['declared'] == true &&
        font['faceVerified'] == true &&
        font['size'] == 535616 &&
        font['magic'] == 'OTTO',
    'actual registered RiaSans-Regular font binary',
  );
  check(
    af,
    logo['asset'] == 'assets/figma/login-a02-logo.svg' &&
        logo['unfiltered'] == true,
    'exact original logo SVG',
  );
  for (final side in ['dividerLeft', 'dividerRight']) {
    final a = m[side] is Map ? m[side] as Map : const {};
    check(
      af,
      a['asset'] == 'assets/icons/login-a02-divider.svg' &&
          a['unfiltered'] == true,
      'exact original $side SVG',
    );
  }
  final guest = m['guest'] is Map ? m['guest'] as Map : const {},
      gb = guest['bounds'] is Map ? guest['bounds'] as Map : const {};
  check(
    lf,
    near(gb['height'], 18) &&
        near(
          (gb['top'] is num && ob['bottom'] is num)
              ? (gb['top'] as num) - (ob['bottom'] as num)
              : null,
          24,
        ),
    'guest natural18 and paragraph gap24',
  );
  final dl = m['dividerLeft'] is Map ? m['dividerLeft'] as Map : const {},
      dr = m['dividerRight'] is Map ? m['dividerRight'] as Map : const {},
      dlb = dl['bounds'] is Map ? dl['bounds'] as Map : const {},
      drb = dr['bounds'] is Map ? dr['bounds'] as Map : const {};
  check(
    lf,
    near(dlb['height'], 1) &&
        near(drb['height'], 1) &&
        near(dlb['left'], left + 24) &&
        near(drb['right'], left + width - 24),
    'divider 1px painted bounds and insets8',
  );
  check(
    lf,
    near(
      (dlb['bottom'] is num && ob['top'] is num && ob['height'] is num)
          ? (dlb['bottom'] as num) -
                .5 -
                ((ob['top'] as num) + (ob['height'] as num) / 2)
          : null,
      -1,
    ),
    'divider painted center offset -1',
  );
  check(
    lf,
    near(
          (ob['left'] is num && dlb['right'] is num)
              ? (ob['left'] as num) - (dlb['right'] as num)
              : null,
          8,
        ) &&
        near(
          (drb['left'] is num && ob['right'] is num)
              ? (drb['left'] as num) - (ob['right'] as num)
              : null,
          8,
        ),
    'divider text gap8',
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

final _capture = GlobalKey();
late Directory _output;
LoginServer _server = LoginServer();
late LoginControlledSocial _social;
LoginMemoryStorage _storage = LoginMemoryStorage();
final _sessions = <Map<String, Object?>>[],
    _checks = <Map<String, Object?>>[],
    _errors = <String>[];
bool _requestBusy = false, _done = false, _coverage = false;
int _epoch = 0, _pointer = 0;
Element get _root => _capture.currentContext! as Element;
Element get _login => _find<LoginScreen>(_root)!;
void _require(bool value, String why) {
  if (!value) throw StateError(why);
}

Future<void> _settle([int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _wait(bool Function() p, String why) async {
  for (var i = 0; i < 100; i++) {
    if (p()) return;
    await _settle(2);
  }
  throw StateError(why);
}

String _route() => _find<LoginScreen>(_root) != null
    ? 'login'
    : _find<AccountManagementScreen>(_root) != null
    ? 'account'
    : _find<MyScreen>(_root) != null
    ? 'my'
    : _find<InterestSelectionScreen>(_root) != null
    ? 'interests'
    : _find<OnboardingScreen>(_root) != null
    ? 'onboarding'
    : _find<HomeScreen>(_root) != null
    ? 'home'
    : 'other';
Future<void> _tap(Element e) async {
  final id = ++_pointer, view = View.of(_root), point = _box(e).center;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 70));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await _settle();
}

Future<void> _visible(Element e) async {
  await Scrollable.ensureVisible(
    e,
    duration: const Duration(milliseconds: 150),
    alignment: .5,
  );
  await _settle(4);
}

Element _providerElement(SocialLoginProvider p) =>
    _key(_login, 'login-provider-${p.name}') ??
    _text(_login, loginLabel(p)) ??
    _text(_login, loginLabel(p, legacy: true))!;

/// The ordinary login gate is optional on the frozen BEFORE source. This
/// helper is used only after an explicit choice that intends to authenticate;
/// B01 cancellation/pending/duplicate scenarios must not call it.
Future<void> loginConfirmPermissionGuide(
  Element root, {
  required Future<void> Function(Element) tap,
}) async {
  await _settle(2);
  final guide = _elements(root)
      .where(
        (element) =>
            element.widget.runtimeType.toString() == 'PermissionGuideSheet',
      )
      .firstOrNull;
  if (guide == null) return;
  final button = _key(guide, 'permission-guide-continue-hit');
  _require(button != null, 'B01 continuation button missing');
  await Scrollable.ensureVisible(button!);
  await tap(button);
  await _settle(8);
}

Future<void> _providerTap(SocialLoginProvider p) async {
  final e = _providerElement(p);
  await _visible(e);
  await _tap(e);
  await loginConfirmPermissionGuide(_root, tap: _tap);
}

Map<String, Object?> _sessionSummary() => {
  'providerCalls': List<String>.from(_social.calls),
  'noncePresent': List<bool>.from(_social.noncePresent),
  'challengeRequests': _server.challenges,
  'socialIssuances': _server.socialIssuances,
  'guestIssuances': _server.guestIssuances,
  'logoutRequests': _server.logouts,
  'sessionWrites': _storage.writes,
  'sessionClears': _storage.clears,
  'hasSession': _storage.value != null,
  'unexpectedRequests': List<String>.from(_server.unexpected),
  'contentWrites': _server.contentWrites,
  'requests': List<Map<String, Object?>>.from(_server.requests),
};
Future<void> _fresh({bool newUser = false}) async {
  if (_epoch > 0) _sessions.add(_sessionSummary());
  runApp(const SizedBox.shrink());
  await _settle(2);
  _server = LoginServer()..newUser = newUser;
  final platform = Platform.isIOS ? TargetPlatform.iOS : TargetPlatform.android;
  _social = LoginControlledSocial(platform);
  _storage = LoginMemoryStorage();
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: ValueKey(++_epoch),
        sessionStorage: _storage,
        socialAuth: _social,
      ),
    ),
  );
  await _settle(2);
  await _wait(
    () =>
        _find<LoginScreen>(_root) != null &&
        !(_login.widget as LoginScreen).busy,
    'Fresh root login missing or busy',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  loginPosition(_root)?.jumpTo(0);
  await _settle(3);
  _require(
    _server.socialIssuances == 0 &&
        _server.guestIssuances == 0 &&
        _storage.value == null,
    'Fresh root issued a session before user choice',
  );
}

Map<String, Object?> _snapshot() {
  final m = loginMeasure(_root),
      v = View.of(_root),
      share = e01.archiveAllShareMessenger;
  return {
    'phase': loginPhase,
    'kind': 'ordinary',
    'platform': Platform.operatingSystem,
    'route': _route(),
    'ready': true,
    'fixtureBusy': _requestBusy,
    'output': _output.path,
    'logicalSize': '${v.physicalSize / v.devicePixelRatio}',
    'pixelRatio': v.devicePixelRatio,
    'viewPaddingTop': v.viewPadding.top / v.devicePixelRatio,
    'viewPaddingBottom': v.viewPadding.bottom / v.devicePixelRatio,
    'viewInsetsBottom': v.viewInsets.bottom / v.devicePixelRatio,
    ...m,
    ...loginJudgment(m),
    'auth': _sessionSummary(),
    'frameworkErrors': List<String>.from(_errors),
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        share,
      ),
      'nativeDelegationCount': share?.nativeDelegationCount,
      'unknownMethods': share?.unknownShareMethods ?? <String>[],
      'argumentsOrCredentialsRecorded': false,
    },
    'scope':
        'Actual ClipbackApp with empty memory sessions, platform-provider SocialAuth and in-process API. No real OAuth/provider/production/physical-device proof.',
  };
}

void _record(String scenario, [Map<String, Object?> fields = const {}]) =>
    _checks.add({
      'scenario': scenario,
      'passed': true,
      ..._snapshot(),
      ...fields,
    });
Future<Map<String, Object?>> _report() async {
  final s = _snapshot(), share = e01.archiveAllShareMessenger;
  final style =
          s['stylePassed'] == true &&
          !_checks.any((c) => c['stylePassed'] == false),
      layout =
          s['layoutPassed'] == true &&
          _errors.isEmpty &&
          !_checks.any((c) => c['layoutPassed'] == false),
      asset =
          s['assetPassed'] == true &&
          !_checks.any((c) => c['assetPassed'] == false);
  final summaries = [..._sessions, _sessionSummary()];
  final behavior =
      _done &&
      share != null &&
      share.nativeDelegationCount == 0 &&
      share.unknownShareMethods.isEmpty &&
      !_checks.any((c) => c['passed'] == false) &&
      summaries.every(
        (s) =>
            (s['unexpectedRequests'] as List).isEmpty &&
            s['contentWrites'] == 0,
      );
  final result = {
    ...s,
    'checksCompleted': _done,
    'coveragePassed': _coverage,
    'stylePassed': style,
    'layoutPassed': layout,
    'assetPassed': asset,
    'behaviorPassed': behavior,
    'passed': _done && _coverage && style && layout && asset && behavior,
    'checks': _checks,
    'sessionSummaries': summaries,
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  return result;
}

Future<void> _captureScene() async {
  _require(
    _route() == 'login' && !(_login.widget as LoginScreen).busy,
    'Static capture requires non-busy ordinary Login',
  );
  await _settle(2);
  final view = View.of(_root);
  _require(
    view.viewInsets.bottom == 0,
    'Static capture requires hidden keyboard',
  );
  final image =
      await (_capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: view.devicePixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_output.path}/login_ordinary_scale_1_scroll_0.png',
    ).writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _record('static_ordinary_login');
}

Future<void> _onboardingToHome() async {
  for (var i = 0; i < 3; i++) {
    await _tap(_text(_find<OnboardingScreen>(_root)!, i == 2 ? '시작하기' : '다음')!);
    await _settle(7);
  }
  await _wait(
    () => _route() == 'interests',
    'Guest onboarding did not reach interests',
  );
  final interests = _find<InterestSelectionScreen>(_root)!;
  final tiles = _elements(
    interests,
  ).where((e) => e.widget is InterestOptionTile).toList();
  if (!tiles.any((e) => (e.widget as InterestOptionTile).selected)) {
    await _tap(tiles.first);
    await _settle();
  }
  await _tap(_text(interests, '다음') ?? _text(interests, '완료')!);
  await _wait(() => _route() == 'home', 'Guest interests did not reach Home');
}

Future<void> _run() async {
  _checks.clear();
  _sessions.clear();
  _done = false;
  _coverage = false;
  await _fresh();
  _sessions.clear();
  _record('initial_empty_session_choice');
  for (final p in List<SocialLoginProvider>.from(_social.supportedProviders)) {
    await _fresh();
    await _providerTap(p);
    await _wait(
      () => !(_login.widget as LoginScreen).busy,
      'Cancellation did not release busy',
    );
    _require(
      _route() == 'login' &&
          _social.calls.length == 1 &&
          _social.calls.single == p.name &&
          _server.socialIssuances == 0 &&
          _server.guestIssuances == 0 &&
          _storage.writes == 0 &&
          _storage.value == null,
      'Cancellation issued or persisted a session',
    );
    _require(
      _server.challenges == (p == SocialLoginProvider.apple ? 1 : 0),
      'Cancellation challenge count differs',
    );
    _record('cancel_${p.name}', {
      'challengeAllowed': p == SocialLoginProvider.apple,
      'sessionIssuanceCount': 0,
    });
  }
  await _fresh();
  final pendingProvider = _social.supportedProviders.first;
  _social.gate = Completer<SocialCredential?>();
  await _providerTap(pendingProvider);
  await _wait(
    () => _social.calls.length == 1 && (_login.widget as LoginScreen).busy,
    'Pending authentication not busy',
  );
  _record('social_pending_busy');
  for (final p in _social.supportedProviders) {
    await _providerTap(p);
  }
  final guest = _key(_login, 'login-guest-hit') ?? _text(_login, '게스트로 시작하기')!;
  await _visible(guest);
  await _tap(guest);
  _require(
    _social.calls.length == 1 &&
        _server.socialIssuances == 0 &&
        _server.guestIssuances == 0 &&
        _storage.writes == 0,
    'Busy allowed duplicate social or guest',
  );
  _record('busy_social_guest_duplicates_blocked');
  _social.gate!.complete(null);
  await _wait(
    () => !(_login.widget as LoginScreen).busy,
    'Pending cancel did not return',
  );
  _record('pending_cancel_restored');
  await _fresh();
  _social.cancel = false;
  _server.failIssuance = true;
  final retryProvider = _social.supportedProviders.first;
  await _providerTap(retryProvider);
  await _wait(
    () =>
        _route() == 'login' &&
        !(_login.widget as LoginScreen).busy &&
        _server.socialIssuances == 1,
    'Failed issuance did not stay on Login',
  );
  _require(
    _storage.value == null && _storage.writes == 0,
    'Failed issuance persisted session',
  );
  _record('social_api_failure_no_session');
  ScaffoldMessenger.of(_login).hideCurrentSnackBar();
  await _settle(6);
  await _providerTap(retryProvider);
  await _wait(
    () => _route() == 'home',
    'Existing social retry did not reach Home',
  );
  _require(
    _server.socialIssuances == 2 &&
        _social.calls.length == 2 &&
        _server.guestIssuances == 0 &&
        _storage.writes == 1,
    'Retry auth issuance/persistence differs',
  );
  _record('social_retry_existing_home');
  await _fresh(newUser: true);
  _social.cancel = false;
  await _providerTap(_social.supportedProviders.first);
  await _wait(
    () => _route() == 'onboarding',
    'New social did not reach Onboarding',
  );
  _require(
    _server.socialIssuances == 1 &&
        _server.guestIssuances == 0 &&
        _storage.value != null,
    'New social issuance differs',
  );
  _record('new_social_onboarding');
  await _fresh();
  final guestChoice =
      _key(_login, 'login-guest-hit') ?? _text(_login, '게스트로 시작하기')!;
  await _visible(guestChoice);
  await _tap(guestChoice);
  await loginConfirmPermissionGuide(_root, tap: _tap);
  await _wait(() => _route() == 'onboarding', 'Guest did not reach Onboarding');
  _require(
    _server.guestIssuances == 1 && _server.socialIssuances == 0,
    'Guest issuance differs',
  );
  _record('guest_onboarding');
  await _onboardingToHome();
  _record('guest_interests_home');
  // Navigate the actual root app; callbacks and data remain owned by production.
  (_find<HomeScreen>(_root)!.widget as HomeScreen).onTab(AppRoute.my);
  await _wait(() => _route() == 'my', 'My missing');
  await _tap(_find<MyProfileRow>(_root)!);
  await _wait(() => _route() == 'account', 'Guest account missing');
  final user =
      (_find<AccountManagementScreen>(_root)!.widget as AccountManagementScreen)
          .user;
  await _tap(_text(_find<AccountManagementScreen>(_root)!, '계정 연결하기')!);
  await _wait(
    () => _route() == 'login' && (_login.widget as LoginScreen).linkingGuest,
    'Legacy guest-link missing',
  );
  _require(
    (_login.widget as LoginScreen).onBack != null,
    'Legacy back missing',
  );
  _record('legacy_guest_link_login');
  await _tap(_text(_login, '뒤로')!);
  await _wait(
    () => _route() == 'account',
    'Legacy cancel did not return account',
  );
  final restored =
      (_find<AccountManagementScreen>(_root)!.widget as AccountManagementScreen)
          .user;
  _require(
    user.name == restored.name &&
        user.providerLabel == restored.providerLabel &&
        _server.guestIssuances == 1 &&
        _server.socialIssuances == 0,
    'Legacy cancellation changed data/session',
  );
  _record('legacy_cancel_preserved');
  final logout = _text(_find<AccountManagementScreen>(_root)!, '로그아웃')!;
  await _visible(logout);
  await _tap(logout);
  // A baseline without J03 logs out immediately; the aligned route requires an
  // explicit confirmation. Runtime lookup keeps this evidence harness portable.
  final confirmation = _elements(_root).where(
    (element) =>
        element.widget.runtimeType.toString() == 'LogoutConfirmationScreen',
  );
  if (confirmation.isNotEmpty) {
    _require(_server.logouts == 0, 'Confirmation entry issued logout');
    await _tap(_key(confirmation.first, 'logout-confirm')!);
  }
  await _wait(
    () => _route() == 'login' && !(_login.widget as LoginScreen).linkingGuest,
    'Logout did not restore ordinary Login',
  );
  _require(
    _storage.value == null && _server.logouts == 1,
    'Logout session clear differs',
  );
  _record('guest_logout_ordinary_login');
  await _fresh();
  _record('final_empty_session_ordinary_login');
  _coverage = true;
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  e01.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-login-alignment-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await loginInspectFontBundle();
  await _fresh();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('LOGIN_ALIGNMENT ready phase=$loginPhase output=${_output.path}');
  await for (final request in server) {
    final read = [
      '/ready',
      '/state',
      '/status',
      '/export',
    ].contains(request.uri.path);
    if (_requestBusy && !read) {
      request.response.statusCode = 409;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': 'fixture busy'}));
      await request.response.close();
      continue;
    }
    if (!read) _requestBusy = true;
    try {
      switch (request.uri.path) {
        case '/ready':
        case '/state':
        case '/status':
          break;
        case '/scene':
          await _fresh();
          await _captureScene();
        case '/run':
          await _run();
        case '/export':
          break;
        default:
          request.response.statusCode = 404;
      }
      final result = await _report();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/export') {
        request.response.write(
          jsonEncode({
            ...result,
            'files': await _output
                .list()
                .where((e) => e is File)
                .map((e) => e.path.split('/').last)
                .toList(),
          }),
        );
      } else {
        request.response.write(jsonEncode(result));
      }
    } catch (error, stack) {
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$error',
      });
      debugPrint('LOGIN FAIL $error\n$stack');
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      try {
        final report = await _report();
        request.response.write(jsonEncode({...report, 'error': '$error'}));
      } catch (reportError) {
        final failed = {
          'phase': loginPhase,
          'platform': Platform.operatingSystem,
          'output': _output.path,
          'ready': false,
          'route': 'unavailable',
          'error': '$error',
          'reportError': '$reportError',
          'checksCompleted': false,
          'stylePassed': false,
          'layoutPassed': false,
          'assetPassed': false,
          'behaviorPassed': false,
          'coveragePassed': false,
          'passed': false,
          'frameworkErrors': _errors,
          'checks': _checks,
        };
        final encoded = jsonEncode(failed);
        await File('${_output.path}/report.json').writeAsString(encoded);
        request.response.write(encoded);
      }
    } finally {
      if (!read) _requestBusy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
