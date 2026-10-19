// Actual-root A03/A04 fixture. Native sharing isolated before the first engine.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../fixtures/login_status_fixture.dart' as f;
import '../fixtures/splash_alignment_fixture.dart' as b;
import 'archive_all_preview.dart' as isolated;
import 'login_alignment_preview.dart' as p;

const statusPhase = String.fromEnvironment(
  'LOGIN_STATUS_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
late Directory _output;
late p.LoginServer _server;
late p.LoginControlledSocial _social;
late p.LoginMemoryStorage _storage;
Completer<SocialCredential?>? _gate;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
final _judgments = <String, Map<String, Object?>>{};
var _epoch = 0, _pointer = 900, _busy = false, _done = false;
String _kind = 'progress';
Element get _root => _capture.currentContext! as Element;
Element? _key(String k) => b.splashKey(_root, k);
Element? _text(String t) => b
    .splashElements(_root)
    .where((e) => e.widget is Text && (e.widget as Text).data == t)
    .firstOrNull;
String _route() => _key('login-progress-screen') != null
    ? 'progress'
    : _key('login-cancelled-screen') != null
    ? 'cancelled'
    : b.splashFind<LoginScreen>(_root) != null
    ? 'login'
    : b.splashFind<OnboardingScreen>(_root) != null
    ? 'onboarding'
    : b.splashFind<HomeScreen>(_root) != null
    ? 'home'
    : 'other';
Future<void> _settle([int count = 2]) async {
  for (var i = 0; i < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 70));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 60),
    );
  }
}

Future<void> _wait(bool Function() check, String why) async {
  for (var i = 0; i < 100; i++) {
    if (check()) return;
    await _settle();
  }
  throw StateError(why);
}

Future<void> _tap(Element e) async {
  await Scrollable.ensureVisible(e);
  await _settle();
  final point = b.splashBox(e).center, view = View.of(_root), id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await _settle();
}

Future<void> _fresh() async {
  final oldGate = _gate;
  if (oldGate != null && !oldGate.isCompleted) oldGate.complete(null);
  if (_capture.currentContext != null) {
    runApp(const SizedBox.shrink());
    await _settle();
  }
  _server = p.LoginServer();
  _social = p.LoginControlledSocial(
    Platform.isIOS ? TargetPlatform.iOS : TargetPlatform.android,
  );
  _storage = p.LoginMemoryStorage();
  _gate = null;
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
  await _wait(() => _route() == 'login', 'Actual initial A02 missing');
  await _settle();
}

Future<void> _choose() async {
  await _tap(_key('login-provider-google') ?? _text('Google로 계속하기')!);
  await p.loginConfirmPermissionGuide(_root, tap: _tap);
}

Future<void> _scene(String kind) async {
  _kind = kind;
  await _fresh();
  _gate = Completer<SocialCredential?>();
  _social.gate = _gate;
  await _choose();
  await _wait(() => _social.calls.length == 1, 'SDK did not start');
  if (kind == 'cancelled') {
    _gate!.complete(null);
    await _wait(
      () => statusPhase == 'before'
          ? _route() == 'login' &&
                !(b.splashFind<LoginScreen>(_root)!.widget as LoginScreen).busy
          : _route() == 'cancelled',
      'SDK cancel missing',
    );
  } else {
    await _wait(
      () => statusPhase == 'before'
          ? _route() == 'login' &&
                (b.splashFind<LoginScreen>(_root)!.widget as LoginScreen).busy
          : _route() == 'progress',
      'Actual pending missing',
    );
  }
  await _settle(4);
  _judgments[kind] = f.statusJudgment(f.statusMeasure(_root, kind));
}

void _record(String name, bool pass, [Map<String, Object?> extra = const {}]) {
  _checks.add({
    'scenario': name,
    'passed': pass,
    'route': _route(),
    'calls': List<String>.from(_social.calls),
    'socialIssuances': _server.socialIssuances,
    'guestIssuances': _server.guestIssuances,
    'writes': _storage.writes,
    ...extra,
  });
}

Map<String, Object?> _snapshot() {
  final view = View.of(_root),
      share = isolated.archiveAllShareMessenger,
      m = f.statusMeasure(_root, _kind);
  return {
    'phase': statusPhase,
    'platform': Platform.operatingSystem,
    'kind': _kind,
    'route': _route(),
    'output': _output.path,
    'ready': true,
    'logicalSize': {
      'width': view.physicalSize.width / view.devicePixelRatio,
      'height': view.physicalSize.height / view.devicePixelRatio,
    },
    'pixelRatio': view.devicePixelRatio,
    'textScale': MediaQueryData.fromView(view).textScaler.scale(16) / 16,
    'viewPaddingTop': view.viewPadding.top / view.devicePixelRatio,
    'viewPaddingBottom': view.viewPadding.bottom / view.devicePixelRatio,
    'viewInsetsBottom': view.viewInsets.bottom / view.devicePixelRatio,
    ...m,
    ...f.statusJudgment(m),
    'frameworkErrors': List<String>.from(_errors),
    'socialCalls': List<String>.from(_social.calls),
    'socialIssuances': _server.socialIssuances,
    'guestIssuances': _server.guestIssuances,
    'sessionWrites': _storage.writes,
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        share,
      ),
      'nativeDelegationCount': share?.nativeDelegationCount,
      'unknownMethods': share?.unknownShareMethods,
    },
    'scope':
        'Actual root with memory HTTP/SDK/session; first bootstrap native sharing isolated; no real provider/production/physical-device proof.',
  };
}

Future<Map<String, Object?>> _report() async {
  final s = _snapshot(),
      style =
          _judgments.length == 2 &&
          _judgments.values.every((j) => j['stylePassed'] == true),
      layout =
          _judgments.length == 2 &&
          _judgments.values.every((j) => j['layoutPassed'] == true),
      asset =
          _judgments.length == 2 &&
          _judgments.values.every((j) => j['assetPassed'] == true),
      behavior = _done && _checks.every((c) => c['passed'] == true);
  final report = {
    ...s,
    'sceneJudgments': _judgments,
    'stylePassed': style,
    'layoutPassed': layout,
    'assetPassed': asset,
    'behaviorPassed': behavior,
    'checksCompleted': _done,
    'passed': style && layout && asset && behavior && _errors.isEmpty,
    'checks': _checks,
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  return report;
}

Future<void> _run() async {
  _checks.clear();
  _done = false;
  await _scene('progress');
  _record(
    'A03 actual SDK pending owns no issued session',
    _route() == 'progress' && _social.calls.length == 1 && _storage.writes == 0,
  );
  final pendingSnapshot = _snapshot();
  _record(
    'pending geometry styles assets',
    pendingSnapshot['stylePassed'] == true &&
        pendingSnapshot['layoutPassed'] == true &&
        pendingSnapshot['assetPassed'] == true,
  );
  await _tap(_key('login-status-back')!);
  await WidgetsBinding.instance.handlePopRoute();
  await _settle();
  _record(
    'pending header and OS back preserve busy lock without duplicate request',
    _route() == 'progress' &&
        _social.calls.length == 1 &&
        _server.socialIssuances == 0,
  );
  _gate!.complete(null);
  _kind = 'cancelled';
  await _wait(() => _route() == 'cancelled', 'actual SDK null not A04');
  await _settle();
  _judgments['cancelled'] = f.statusJudgment(
    f.statusMeasure(_root, 'cancelled'),
  );
  _record(
    'SDK cancellation without session write or server issuance',
    _route() == 'cancelled' &&
        _storage.writes == 0 &&
        _server.socialIssuances == 0,
  );
  await _tap(_key('login-cancelled-primary')!);
  await _wait(() => _route() == 'login', 'methods missing');
  _record(
    'methods callback requests no authentication',
    _social.calls.length == 1 && _server.socialIssuances == 0,
  );
  _gate = Completer<SocialCredential?>();
  _social.gate = _gate;
  await _choose();
  await _wait(() => _route() == 'progress', 'retry missing');
  _record(
    'same visit does not repeat B01',
    _social.calls.length == 2 && _key('permission-guide-continue-hit') == null,
  );
  _gate!.complete(null);
  await _wait(() => _route() == 'cancelled', 'cancelled retry missing');
  await WidgetsBinding.instance.handlePopRoute();
  await _wait(() => _route() == 'login', 'OS back did not return A02');
  _record(
    'idle OS back returns methods with no issuance',
    _server.socialIssuances == 0 && _social.calls.length == 2,
  );
  await _scene('cancelled');
  await _tap(_key('login-status-back')!);
  await _wait(() => _route() == 'login', 'header methods missing');
  _record(
    'idle header returns methods with no issuance',
    _social.calls.length == 1 && _storage.writes == 0,
  );
  await _scene('cancelled');
  await _tap(_key('login-cancelled-guest')!);
  await p.loginConfirmPermissionGuide(_root, tap: _tap);
  await _wait(
    () => _route() == 'onboarding',
    'existing guest onboarding missing',
  );
  _record(
    'guest retains existing issuance and onboarding',
    _server.guestIssuances == 1 &&
        _server.socialIssuances == 0 &&
        _storage.writes == 1,
  );
  _record(
    'native share isolation and framework errors',
    _errors.isEmpty &&
        isolated.archiveAllShareMessenger?.nativeDelegationCount == 0 &&
        (isolated.archiveAllShareMessenger?.unknownShareMethods.isEmpty ??
            false),
  );
  await _scene('cancelled');
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-auth-status-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _fresh();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  await for (final request in server) {
    final read = request.uri.path == '/status';
    if (_busy && !read) {
      request.response.statusCode = 409;
      await request.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (request.uri.path) {
        case '/scene':
          await _scene(
            request.uri.queryParameters['kind'] == 'cancelled'
                ? 'cancelled'
                : 'progress',
          );
        case '/run':
          await _run();
        case '/status':
          break;
        default:
          request.response.statusCode = 404;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(await _report()));
    } catch (e, st) {
      debugPrint('LOGIN_STATUS $e\n$st');
      request.response.statusCode = 500;
      _record('request_failure', false, {'error': '$e'});
      request.response.write(jsonEncode({'error': '$e', ...await _report()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
