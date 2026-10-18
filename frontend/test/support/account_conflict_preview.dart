// A05-1 actual-root guest upgrade409 evidence; no real OAuth/production data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../fixtures/account_conflict_fixture.dart' as f;
import '../fixtures/splash_alignment_fixture.dart' as splash;
import 'archive_all_preview.dart' as isolated;
import 'login_alignment_preview.dart' as login;

const conflictPhase = String.fromEnvironment(
  'ACCOUNT_CONFLICT_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
late Directory _output;
late ConflictServer _server;
late ConflictSocial _social;
late splash.SplashMemoryStorage _storage;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
var _epoch = 0, _pointer = 900, _busy = false, _done = false;
Element get _root => _capture.currentContext! as Element;

class ConflictSocial extends login.LoginControlledSocial {
  ConflictSocial(super.platform);
  final nonceFresh = <bool>[];
  final Set<String> _seenNonces = {};
  final credentialFresh = <bool>[];
  final Set<String> _seenCredentials = {};
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async {
    if (provider == SocialLoginProvider.apple) {
      nonceFresh.add(nonce != null && _seenNonces.add(nonce));
    }
    final result = await super.authenticate(provider, nonce: nonce);
    if (result == null) return null;
    final serial = calls.length, code = 'fixture-one-use-code-$serial';
    credentialFresh.add(_seenCredentials.add(code));
    return SocialCredential(
      token: 'fixture-fresh-token-$serial',
      authorizationCode: code,
      providerUserId: 'fixture-user',
      displayName: '연결 충돌 검증',
    );
  }
}

class ConflictServer extends login.LoginServer {
  int upgrades = 0;
  bool failSwitch = false;
  final namesOnlyRequests = <String>[];
  final records = isolated.archiveAllRecords().take(1).toList();
  late final controlledClient = MockClient((r) async {
    final path = r.url.path;
    namesOnlyRequests.add('${r.method} $path');
    if (path.endsWith('/upgrade')) {
      upgrades++;
      return this.json({'detail': '이미 연결된 계정 대역'}, 409);
    }
    if (RegExp(r'^/api/v1/auth/social/(google|kakao|apple)$').hasMatch(path) &&
        failSwitch) {
      socialIssuances++;
      return this.json({'detail': '계정 전환 대역 실패'}, 503);
    }
    if (path == '/api/v1/users/me/stats') {
      return this.json({'saved_count': 17, 'reopened_count': 29});
    }
    if (path == '/api/v1/feed') {
      return this.json({'items': records, 'next_cursor': null});
    }
    if (path == '/api/v1/categories') {
      return this.json(isolated.archiveAllCategoryMaps);
    }
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return http.Response.fromStream(await client.send(copy));
  });
}

Future<void> Function(SocialLoginProvider)? _retainedGoogle;
Map<String, Object?> _guestProfileProof = {};
String _route() => f.conflictKey(_root, 'account-link-conflict-screen') != null
    ? 'conflict'
    : f.conflictFind<AlertDialog>(_root) != null
    ? 'dialog'
    : f.conflictFind<SplashScreen>(_root) != null
    ? 'splash'
    : f.conflictFind<LoginScreen>(_root) != null
    ? 'login'
    : f.conflictFind<AccountManagementScreen>(_root) != null
    ? 'account'
    : f.conflictFind<MyScreen>(_root) != null
    ? 'my'
    : f.conflictFind<HomeScreen>(_root) != null
    ? 'home'
    : 'other';
Element? _text(String t) => f
    .conflictElements(_root)
    .where((e) => e.widget is Text && (e.widget as Text).data == t)
    .firstOrNull;
Element? get _login => f.conflictFind<LoginScreen>(_root);
bool get _idle => _login != null && !(_login!.widget as LoginScreen).busy;
Future<void> _settle([int n = 3]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _wait(bool Function() test, String why) async {
  for (var i = 0; i < 130; i++) {
    if (test()) return;
    await _settle(2);
  }
  throw StateError(why);
}

Future<void> _tapPoint(Offset point) async {
  final view = View.of(_root), id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 70));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await _settle();
}

Future<void> _tap(Element e) async {
  await Scrollable.ensureVisible(e);
  await _settle(2);
  await _tapPoint(f.conflictBox(e).center);
}

Future<void> _hold() async =>
    Future<void>.delayed(const Duration(milliseconds: 1100));
Future<void> _provider(SocialLoginProvider provider) async {
  final label = provider == SocialLoginProvider.google
      ? '구글로 계속하기'
      : provider == SocialLoginProvider.apple
      ? 'Apple로 계속하기'
      : '카카오로 계속하기';
  await _tap(_text(label)!);
  await login.loginConfirmPermissionGuide(_root, tap: _tap);
}

Future<void> _fresh() async {
  if (_capture.currentContext != null) {
    runApp(const SizedBox.shrink());
    await _settle(2);
    _server.controlledClient.close();
    _server.client.close();
  }
  _server = ConflictServer();
  _storage = splash.SplashMemoryStorage()..value = splash.splashStoredSession;
  _social = ConflictSocial(
    Platform.isIOS ? TargetPlatform.iOS : TargetPlatform.android,
  )..cancel = false;
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
  await _wait(() => _route() == 'home', 'Initial guest home missing');
  (f.conflictFind<HomeScreen>(_root)!.widget as HomeScreen).onTab(AppRoute.my);
  await _wait(() => _route() == 'my', 'Guest my missing');
  await _tap(f.conflictFind<MyProfileRow>(_root)!);
  await _wait(() => _route() == 'account', 'Guest account missing');
  final user =
      (f.conflictFind<AccountManagementScreen>(_root)!.widget
              as AccountManagementScreen)
          .user;
  _guestProfileProof = {
    'name': user.name,
    'providerLabel': user.providerLabel,
    'savedCount': user.savedContentCount,
    'reopenedCount': user.revisitedContentCount,
  };
  await _tap(_text('계정 연결하기')!);
  await _wait(
    () =>
        _route() == 'login' &&
        _idle &&
        (_login!.widget as LoginScreen).linkingGuest,
    'Guest link choice missing',
  );
  _retainedGoogle = (_login!.widget as LoginScreen).onSocialLogin;
}

Future<void> _scene({
  SocialLoginProvider provider = SocialLoginProvider.google,
}) async {
  await _fresh();
  await _provider(provider);
  await _wait(
    () => conflictPhase == 'before'
        ? _route() == 'dialog'
        : _route() == 'conflict',
    'Actual guest409 confirmation missing',
  );
  await _settle(5);
}

void _record(
  String name,
  bool passed, [
  Map<String, Object?> detail = const {},
]) {
  _checks.add({
    'scenario': name,
    'passed': passed,
    'route': _route(),
    'upgrades': _server.upgrades,
    'socialCalls': List<String>.from(_social.calls),
    'issuances': _server.socialIssuances,
    'guestIssuances': _server.guestIssuances,
    'challenges': _server.challenges,
    'nonceFresh': List<bool>.from(_social.nonceFresh),
    'credentialFresh': List<bool>.from(_social.credentialFresh),
    'sessionWrites': _storage.writes,
    'sessionClears': _storage.clears,
    'records': _server.records.map((r) => r['id']).toList(),
    ...detail,
  });
}

bool get _preserved =>
    identical(_storage.value, splash.splashStoredSession) &&
    _storage.writes == 0 &&
    _storage.clears == 0 &&
    _server.guest &&
    _server.guestIssuances == 0 &&
    _server.records.length == 1;
Future<void> _dismiss(String how) async {
  if (how == 'os') {
    ServicesBinding.instance.channelBuffers.push(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await _settle(8);
  } else {
    await _tap(
      f.conflictKey(
            _root,
            'account-link-conflict-${how == 'header' ? 'back-hit' : 'keep'}',
          ) ??
          _text('게스트 유지')!,
    );
  }
  await _wait(
    () => _route() == 'login' && _idle,
    'Dismiss did not restore guest link choice',
  );
}

Future<void> _confirm() async {
  await _tap(
    f.conflictKey(_root, 'account-link-conflict-confirm') ??
        _text('기존 계정으로 전환')!,
  );
}

Map<String, Object?> _snapshot() {
  final m = f.conflictMeasure(_root),
      view = View.of(_root),
      share = isolated.archiveAllShareMessenger;
  final dialog = f.conflictFind<AlertDialog>(_root);
  return {
    'phase': conflictPhase,
    'platform': Platform.operatingSystem,
    'output': _output.path,
    'route': _route(),
    'ready': true,
    'logicalSize': {
      'width': view.physicalSize.width / view.devicePixelRatio,
      'height': view.physicalSize.height / view.devicePixelRatio,
    },
    'pixelRatio': view.devicePixelRatio,
    'viewPaddingTop': view.viewPadding.top / view.devicePixelRatio,
    'viewPaddingBottom': view.viewPadding.bottom / view.devicePixelRatio,
    'viewInsetsBottom': view.viewInsets.bottom / view.devicePixelRatio,
    ...m,
    ...f.conflictJudgment(m),
    'baselineAlertDialogVisible': dialog != null,
    'baselineDialogText': dialog == null
        ? null
        : f
              .conflictElements(dialog)
              .where((e) => e.widget is Text)
              .map((e) => (e.widget as Text).data)
              .whereType<String>()
              .toList(),
    'frameworkErrors': List<String>.from(_errors),
    'requests': List<String>.from(_server.namesOnlyRequests),
    'upgrades': _server.upgrades,
    'socialCalls': List<String>.from(_social.calls),
    'issuances': _server.socialIssuances,
    'guestIssuances': _server.guestIssuances,
    'challenges': _server.challenges,
    'nonceFresh': List<bool>.from(_social.nonceFresh),
    'credentialFresh': List<bool>.from(_social.credentialFresh),
    'sessionWrites': _storage.writes,
    'sessionClears': _storage.clears,
    'guestPreserved': _preserved,
    'loadedGuestProfile': _guestProfileProof,
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
        'Actual root and guest Google upgrade409 with controlled memory API/storage/social; no real provider/production/device proof.',
  };
}

Future<Map<String, Object?>> _report() async {
  final s = _snapshot(), share = isolated.archiveAllShareMessenger;
  final behavior =
      _done &&
      _checks.every((c) => c['passed'] == true) &&
      share?.nativeDelegationCount == 0 &&
      (share?.unknownShareMethods.isEmpty ?? false);
  final result = {
    ...s,
    'checksCompleted': _done,
    'checks': List<Map<String, Object?>>.from(_checks),
    'behaviorPassed': behavior,
    'passed':
        s['stylePassed'] == true &&
        s['layoutPassed'] == true &&
        s['assetPassed'] == true &&
        behavior &&
        _errors.isEmpty,
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  return result;
}

Future<void> _run() async {
  _checks.clear();
  _done = false;
  for (final how in ['keep', 'header', 'os']) {
    await _scene();
    _record(
      '${how}_conflict409_keeps_guest',
      _preserved &&
          _guestProfileProof['savedCount'] == 17 &&
          _guestProfileProof['reopenedCount'] == 29 &&
          _server.upgrades == 1 &&
          _social.calls.length == 1,
    );
    await _hold();
    await _dismiss(conflictPhase == 'before' ? 'keep' : how);
    _record(
      '${how}_cancel_has_no_new_auth',
      _preserved &&
          _guestProfileProof['savedCount'] == 17 &&
          _guestProfileProof['reopenedCount'] == 29 &&
          _server.upgrades == 1 &&
          _social.calls.length == 1,
    );
    await _hold();
  }
  await _scene();
  await _hold();
  final retainedGoogle = _retainedGoogle;
  final oldButton = f.conflictKey(_root, 'account-link-conflict-confirm');
  final oldConfirm = oldButton == null
      ? null
      : (f.conflictFind<OutlinedButton>(oldButton)!.widget as OutlinedButton)
            .onPressed;
  _social.gate = Completer<SocialCredential?>();
  await _confirm();
  await _wait(
    () => _login != null && (_login!.widget as LoginScreen).busy,
    'Confirm busy missing',
  );
  if (conflictPhase == 'after') {
    oldConfirm?.call();
    oldConfirm?.call();
  }
  if (retainedGoogle != null) await retainedGoogle(SocialLoginProvider.google);
  _record(
    'fresh_confirm_busy_duplicate_guard',
    retainedGoogle != null &&
        (conflictPhase == 'before' || oldConfirm != null) &&
        _social.calls.length == 2 &&
        _server.upgrades == 1 &&
        _server.socialIssuances == 0 &&
        _preserved,
    {
      'retainedNewConfirmProbe': conflictPhase == 'after',
      'oldLoginCallbackAvailable': retainedGoogle != null,
    },
  );
  await _hold();
  _social.gate!.complete(null);
  _social.gate = null;
  await _wait(
    () => _route() == 'login' && _idle,
    'SDK gate cancellation did not restore choice',
  );
  _record(
    'confirm_sdk_cancel_preserves_guest',
    _preserved && _social.calls.length == 2,
  );
  await _hold();
  _social.cancel = false;
  await _provider(SocialLoginProvider.google);
  await _wait(
    () => conflictPhase == 'before'
        ? _route() == 'dialog'
        : _route() == 'conflict',
    'Retry conflict missing',
  );
  await _hold();
  _social.fail = true;
  await _confirm();
  await _wait(
    () => _route() == 'login' && _idle,
    'Fresh SDK failure did not restore choice',
  );
  _record(
    'confirm_sdk_error_preserves_guest',
    _preserved && _social.calls.length == 4 && _server.upgrades == 2,
  );
  await _hold();
  ScaffoldMessenger.of(_login!).hideCurrentSnackBar();
  await _settle(6);
  _social.fail = false;
  await _provider(SocialLoginProvider.google);
  await _wait(
    () => conflictPhase == 'before'
        ? _route() == 'dialog'
        : _route() == 'conflict',
    'Server retry conflict missing',
  );
  await _hold();
  _server.failSwitch = true;
  await _confirm();
  await _wait(
    () => _route() == 'login' && _idle,
    'Fresh server failure did not restore choice',
  );
  _record(
    'confirm_server503_preserves_guest',
    _preserved && _server.socialIssuances == 1 && _social.calls.length == 6,
  );
  await _hold();
  ScaffoldMessenger.of(_login!).hideCurrentSnackBar();
  await _settle(6);
  _server.failSwitch = false;
  await _provider(SocialLoginProvider.google);
  await _wait(
    () => conflictPhase == 'before'
        ? _route() == 'dialog'
        : _route() == 'conflict',
    'Final conflict missing',
  );
  await _hold();
  await _confirm();
  await _wait(
    () => _route() == 'home',
    'Confirmed fresh reauth did not reach home',
  );
  _record(
    'fresh_confirmation_switch_success_once',
    !_server.guest &&
        _server.socialIssuances == 2 &&
        _storage.writes == 1 &&
        _social.calls.length == 8 &&
        _server.upgrades == 4 &&
        _social.credentialFresh.every((v) => v),
  );
  await _hold();
  if (Platform.isIOS) {
    await _scene(provider: SocialLoginProvider.apple);
    await _hold();
    await _confirm();
    await _wait(
      () => _route() == 'home',
      'Apple fresh confirmation home missing',
    );
    _record(
      'apple_confirmation_uses_fresh_challenge_nonce_credential',
      _server.challenges == 2 &&
          _social.calls.length == 2 &&
          _social.nonceFresh.length == 2 &&
          _social.nonceFresh.every((v) => v) &&
          _social.credentialFresh.length == 2 &&
          _social.credentialFresh.every((v) => v) &&
          _server.upgrades == 1 &&
          _server.socialIssuances == 1,
    );
    await _hold();
  }
  _record(
    'first_bootstrap_share_isolation_framework_zero',
    _errors.isEmpty &&
        isolated.archiveAllShareMessenger?.nativeDelegationCount == 0 &&
        (isolated.archiveAllShareMessenger?.unknownShareMethods.isEmpty ??
            false),
  );
  await _scene();
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-account-conflict-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _fresh();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'ACCOUNT_CONFLICT ready phase=$conflictPhase output=${_output.path}',
  );
  await for (final req in server) {
    final read = [
      '/status',
      '/state',
      '/ready',
      '/export',
    ].contains(req.uri.path);
    if (_busy && !read) {
      req.response.statusCode = 409;
      req.response.write('{"error":"busy"}');
      await req.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (req.uri.path) {
        case '/scene':
          await _scene();
        case '/run':
          await _run();
        case '/status':
        case '/state':
        case '/ready':
        case '/export':
          break;
        default:
          req.response.statusCode = 404;
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(await _report()));
    } catch (e, st) {
      debugPrint('ACCOUNT_CONFLICT failure $e\n$st');
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$e',
      });
      req.response.statusCode = 500;
      req.response.write(jsonEncode({'error': '$e', ...await _report()}));
    } finally {
      if (!read) _busy = false;
      await req.response.close();
    }
  }
}, () => _server.controlledClient);
