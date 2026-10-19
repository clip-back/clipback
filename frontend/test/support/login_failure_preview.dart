// A05 actual-root fixture. The first engine bootstrap is share-isolated and
// real A02/B01 authentication creates each HTTP503/SDK-no-status failure.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../fixtures/login_failure_fixture.dart' as f;
import '../fixtures/splash_alignment_fixture.dart' as splash;
import 'archive_all_preview.dart' as isolated;
import 'login_alignment_preview.dart' as login;

const failurePhase = String.fromEnvironment(
  'LOGIN_FAILURE_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
late Directory _output;
late FailureServer _server;
late login.LoginControlledSocial _social;
late splash.SplashMemoryStorage _storage;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
final _kindJudgments = <String, Map<String, Object?>>{};
var _epoch = 0, _pointer = 800, _busy = false, _done = false;
String _kind = 'http';
Element get _root => _capture.currentContext! as Element;

class FailureServer extends login.LoginServer {
  bool failHttp = true;
  final namesOnlyRequests = <String>[];
  late final controlledClient = MockClient((request) async {
    namesOnlyRequests.add('${request.method} ${request.url.path}');
    if (request.url.path == '/api/v1/auth/social/google') {
      socialIssuances++;
      guest = false;
      provider = 'google';
      if (failHttp) return this.json({'detail': '로그인 대역 저장 실패'}, 503);
      return this.json(tokens('social'));
    }
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await client.send(copy));
  });
}

String _route() => f.failureKey(_root, 'login-failure-screen') != null
    ? 'failure'
    : f.failureFind<SplashScreen>(_root) != null
    ? 'splash'
    : f.failureFind<LoginScreen>(_root) != null
    ? 'login'
    : f.failureFind<HomeScreen>(_root) != null
    ? 'home'
    : f.failureFind<OnboardingScreen>(_root) != null
    ? 'onboarding'
    : 'other';
Element? _text(String value) => f
    .failureElements(_root)
    .where((e) => e.widget is Text && (e.widget as Text).data == value)
    .firstOrNull;
Element? get _login => f.failureFind<LoginScreen>(_root);
bool get _loginIdle => _login != null && !(_login!.widget as LoginScreen).busy;
Future<void> _settle([int count = 3]) async {
  for (var i = 0; i < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _wait(bool Function() test, String why) async {
  for (var i = 0; i < 100; i++) {
    if (test()) return;
    await _settle(2);
  }
  throw StateError(why);
}

void _require(bool value, String why) {
  if (!value) throw StateError(why);
}

Future<void> _tapPoint(Offset point) async {
  final view = View.of(_root), pointer = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, viewId: view.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 70));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: pointer, viewId: view.viewId, position: point),
  );
  await _settle();
}

Future<void> _tap(Element element) async {
  await Scrollable.ensureVisible(element);
  await _settle(2);
  await _tapPoint(f.failureBox(element).center);
}

Future<void> _providerTap() async {
  final e =
      f.failureKey(_root, 'login-provider-google') ?? _text('Google로 계속하기');
  _require(e != null, 'Actual Google button missing');
  await _tap(e!);
  await login.loginConfirmPermissionGuide(_root, tap: _tap);
}

Future<void> _hold() async =>
    Future<void>.delayed(const Duration(milliseconds: 1100));

Future<void> _fresh() async {
  if (_capture.currentContext != null) {
    runApp(const SizedBox.shrink());
    await _settle(2);
  }
  _server = FailureServer();
  _storage = splash.SplashMemoryStorage();
  _social = login.LoginControlledSocial(
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
  await _wait(
    () => _route() == 'login' && _loginIdle,
    'Initial actual A02 missing',
  );
}

Future<void> _scene(String kind) async {
  _kind = kind;
  await _fresh();
  _social.fail = kind == 'sdk';
  await _providerTap();
  await _wait(
    () => failurePhase == 'before'
        ? _loginIdle && f.failureFind<SnackBar>(_root) != null
        : _route() == 'failure',
    'Actual authentication failure missing',
  );
  await _settle(5);
  final metrics = f.failureMeasure(_root);
  _kindJudgments[kind] = f.failureJudgment(metrics, kind: kind);
}

void _record(
  String scenario,
  bool passed, [
  Map<String, Object?> extra = const {},
]) {
  _checks.add({
    'scenario': scenario,
    'passed': passed,
    'kind': _kind,
    'route': _route(),
    'socialCalls': List<String>.from(_social.calls),
    'socialIssuances': _server.socialIssuances,
    'guestIssuances': _server.guestIssuances,
    'sessionWrites': _storage.writes,
    'requests': List<String>.from(_server.namesOnlyRequests),
    ...extra,
  });
}

Map<String, Object?> _snapshot() {
  final metrics = f.failureMeasure(_root),
      view = View.of(_root),
      share = isolated.archiveAllShareMessenger;
  final snackbar = f.failureFind<SnackBar>(_root);
  return {
    'phase': failurePhase,
    'platform': Platform.operatingSystem,
    'kind': _kind,
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
    ...metrics,
    ...f.failureJudgment(metrics, kind: _kind),
    'baselineSnackBarVisible': snackbar != null,
    'baselineSnackBarText': snackbar == null
        ? null
        : f
              .failureElements(snackbar)
              .where((e) => e.widget is Text)
              .map((e) => (e.widget as Text).data)
              .whereType<String>()
              .toList(),
    'frameworkErrors': List<String>.from(_errors),
    'requests': List<String>.from(_server.namesOnlyRequests),
    'socialCalls': List<String>.from(_social.calls),
    'socialIssuances': _server.socialIssuances,
    'guestIssuances': _server.guestIssuances,
    'sessionWrites': _storage.writes,
    'sessionExists': _storage.value != null,
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
        'Actual ClipbackApp/A02/B01 with fixed in-memory HTTP503 and SDK-no-status failure. Native share isolated at first bootstrap. No real OAuth/production/physical-device proof.',
  };
}

Future<Map<String, Object?>> _report() async {
  final s = _snapshot(), share = isolated.archiveAllShareMessenger;
  final style =
          s['stylePassed'] == true &&
          _kindJudgments.length == 2 &&
          _kindJudgments.values.every((j) => j['stylePassed'] == true),
      layout =
          s['layoutPassed'] == true &&
          _kindJudgments.length == 2 &&
          _kindJudgments.values.every((j) => j['layoutPassed'] == true),
      asset =
          s['assetPassed'] == true &&
          _kindJudgments.length == 2 &&
          _kindJudgments.values.every((j) => j['assetPassed'] == true);
  final behavior =
      _done &&
      _checks.every((c) => c['passed'] == true) &&
      share?.nativeDelegationCount == 0 &&
      (share?.unknownShareMethods.isEmpty ?? false);
  final result = {
    ...s,
    'checksCompleted': _done,
    'checks': List<Map<String, Object?>>.from(_checks),
    'kindJudgments': _kindJudgments,
    'targetStylePassed': s['stylePassed'],
    'targetLayoutPassed': s['layoutPassed'],
    'targetAssetPassed': s['assetPassed'],
    'stylePassed': style,
    'layoutPassed': layout,
    'assetPassed': asset,
    'behaviorPassed': behavior,
    'passed': style && layout && asset && behavior && _errors.isEmpty,
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  return result;
}

Future<void> _run() async {
  _checks.clear();
  _kindJudgments.clear();
  _done = false;
  for (final kind in ['http', 'sdk']) {
    await _scene(kind);
    final calls = _social.calls.length, issues = _server.socialIssuances;
    _record(
      '${kind}_failure_keeps_no_session',
      _storage.value == null &&
          _storage.writes == 0 &&
          _server.guestIssuances == 0 &&
          calls == 1 &&
          issues == (kind == 'http' ? 1 : 0),
    );
    await _hold();
    if (failurePhase == 'after') {
      _record(
        '${kind}_actual_status_matches_source',
        _text(kind == 'http' ? '응답 상태 : HTTP 503' : '응답 상태를 확인할 수 없어요') != null,
      );
      await _tap(f.failureKey(_root, 'login-failure-contact-hit')!);
      await _wait(
        () => f.failureFind<ContactSheet>(_root) != null,
        'Existing contact sheet missing',
      );
      await _settle(8);
      _record(
        '${kind}_contact_opens_existing_sheet_no_auth',
        f.failureFind<ContactSheet>(_root) != null &&
            _social.calls.length == calls &&
            _server.socialIssuances == issues,
      );
      await _hold();
      await _tapPoint(
        Offset(
          View.of(_root).physicalSize.width /
              View.of(_root).devicePixelRatio /
              2,
          View.of(_root).viewPadding.top / View.of(_root).devicePixelRatio + 80,
        ),
      );
      await _wait(
        () => f.failureFind<ContactSheet>(_root) == null,
        'Contact barrier close failed',
      );
      await _settle(8);
      _record(
        '${kind}_contact_close_preserves_failure',
        _route() == 'failure' &&
            _text(kind == 'http' ? '응답 상태 : HTTP 503' : '응답 상태를 확인할 수 없어요') !=
                null,
      );
      await _hold();
      await _tap(
        f.failureKey(
          _root,
          kind == 'http' ? 'login-failure-methods' : 'login-failure-back-hit',
        )!,
      );
      await _wait(
        () => _route() == 'login' && _loginIdle,
        'Methods did not return A02',
      );
    } else {
      ScaffoldMessenger.of(_login!).hideCurrentSnackBar();
      await _settle(7);
    }
    _record(
      '${kind}_methods_or_existing_choice_no_auto_retry',
      _route() == 'login' &&
          _social.calls.length == calls &&
          _server.socialIssuances == issues,
    );
    await _hold();
    _social.fail = false;
    _social.cancel = true;
    _server.failHttp = false;
    await _providerTap();
    await _wait(() => _loginIdle, 'SDK cancel did not restore A02');
    _record(
      '${kind}_sdk_cancel_does_not_show_failure_or_issue',
      _route() == 'login' &&
          _server.socialIssuances == issues &&
          _storage.writes == 0,
    );
    await _hold();
    _social.cancel = false;
    await _providerTap();
    await _wait(() => _route() == 'home', 'Manual retry success missing home');
    _record(
      '${kind}_manual_retry_success_uses_new_auth_once',
      _route() == 'home' &&
          _server.socialIssuances == issues + 1 &&
          _storage.value != null,
    );
    await _hold();
  }
  await _scene('sdk');
  final guest =
      f.failureKey(_root, 'login-failure-guest') ??
      f.failureKey(_root, 'login-guest-hit') ??
      _text('게스트로 시작하기');
  _require(guest != null, 'Actual guest button missing');
  await _tap(guest!);
  await login.loginConfirmPermissionGuide(_root, tap: _tap);
  await _wait(
    () => _route() == 'onboarding',
    'Guest did not reach existing onboarding',
  );
  _record(
    'guest_uses_existing_onboarding_and_single_guest_session',
    _server.guestIssuances == 1 &&
        _server.socialIssuances == 0 &&
        _storage.value != null,
  );
  await _hold();
  _record(
    'first_bootstrap_share_isolated_and_framework_errors_zero',
    _errors.isEmpty &&
        isolated.archiveAllShareMessenger?.nativeDelegationCount == 0 &&
        (isolated.archiveAllShareMessenger?.unknownShareMethods.isEmpty ??
            false),
  );
  await _scene('http');
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-login-failure-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _fresh();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('LOGIN_FAILURE ready phase=$failurePhase output=${_output.path}');
  await for (final request in server) {
    final read = [
      '/status',
      '/state',
      '/ready',
      '/export',
    ].contains(request.uri.path);
    if (_busy && !read) {
      request.response.statusCode = 409;
      request.response.write('{"error":"busy"}');
      await request.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (request.uri.path) {
        case '/scene':
          await _scene(
            request.uri.queryParameters['kind'] == 'sdk' ? 'sdk' : 'http',
          );
        case '/run':
          await _run();
        case '/status':
        case '/state':
        case '/ready':
        case '/export':
          break;
        default:
          request.response.statusCode = 404;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(await _report()));
    } catch (e, st) {
      debugPrint('LOGIN_FAILURE failure $e\n$st');
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$e',
      });
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$e', ...await _report()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.controlledClient);
