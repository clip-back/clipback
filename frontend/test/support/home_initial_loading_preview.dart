// The very first engine bootstrap is share-isolated. Actual root startup and
// controlled in-memory API gates are shared unchanged by BEFORE and AFTER.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/session_restore_screen.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../fixtures/home_initial_loading_fixture.dart' as f;
import '../fixtures/splash_alignment_fixture.dart' as splash;
import 'archive_all_preview.dart' as isolated;
import 'login_alignment_preview.dart' as login;

const phase = String.fromEnvironment(
  'HOME_LOADING_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
late Directory _output;
late ControlledServer _server;
late login.LoginControlledSocial _social;
late splash.SplashMemoryStorage _storage;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
var _epoch = 0, _pointer = 300, _busy = false, _done = false;
Stopwatch? _runClock;
Element get _root => _capture.currentContext! as Element;

class ControlledServer extends login.LoginServer {
  ControlledServer() {
    guest = false;
  }
  Completer<void>? categoryGate = Completer<void>();
  bool failCategory = false, empty = false;
  final loadingRequests = <String>[];
  late final controlledClient = MockClient((r) async {
    loadingRequests.add('${r.method} ${r.url.path}');
    if (r.url.path == '/api/v1/categories') {
      if (categoryGate != null) await categoryGate!.future;
      if (failCategory) return this.json({'detail': '최초 조회 대역 실패'}, 503);
      return this.json(isolated.archiveAllCategoryMaps);
    }
    if (r.url.path == '/api/v1/feed') {
      return this.json({
        'items': empty
            ? <Object>[]
            : isolated.archiveAllRecords().take(2).toList(),
        'next_cursor': null,
      });
    }
    // MockClient supplies a finalized Request. Delegate an exact byte/header
    // copy, rather than attempting to finalize that consumed Request twice.
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return http.Response.fromStream(await client.send(copy));
  });
  void release({bool fail = false}) {
    failCategory = fail;
    final gate = categoryGate;
    categoryGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

String _route() => f.loadingKey(_root, 'home-initial-loading-screen') != null
    ? 'home-loading'
    : f.loadingFind<SplashScreen>(_root) != null
    ? 'splash'
    : f.loadingFind<SessionRestoreScreen>(_root) != null
    ? 'restore'
    : f.loadingFind<LoginScreen>(_root) != null
    ? 'login'
    : f.loadingFind<HomeScreen>(_root) != null
    ? 'home'
    : 'other';
bool get _waiting => _route() == 'home-loading' || _route() == 'restore';
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
  for (var i = 0; i < 100; i++) {
    if (test()) return;
    await _settle(2);
  }
  throw StateError(why);
}

void _require(bool pass, String why) {
  if (!pass) throw StateError(why);
}

void _record(
  String scenario,
  bool passed, [
  Map<String, Object?> extra = const {},
]) {
  _checks.add({
    'scenario': scenario,
    'passed': passed,
    'route': _route(),
    'elapsedMs': _runClock?.elapsedMilliseconds,
    'requests': List<String>.from(_server.loadingRequests),
    ...extra,
  });
}

Future<void> _tap(Element element) async {
  final position = f.loadingBox(element).center,
      view = View.of(_root),
      pointer = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, viewId: view.viewId, position: position),
  );
  await Future<void>.delayed(const Duration(milliseconds: 70));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: pointer, viewId: view.viewId, position: position),
  );
  await _settle();
}

Element? _text(String text) => f
    .loadingElements(_root)
    .where((e) => e.widget is Text && (e.widget as Text).data == text)
    .firstOrNull;
Future<void> _fresh({
  bool stored = true,
  bool empty = false,
  bool gated = true,
}) async {
  if (_capture.currentContext != null) {
    _server.release();
    runApp(const SizedBox.shrink());
    await _settle(2);
  }
  _server = ControlledServer()..empty = empty;
  if (!gated) _server.release();
  _storage = splash.SplashMemoryStorage();
  if (stored) _storage.value = splash.splashStoredSession;
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
}

Map<String, Object?> _snapshot() {
  final m = f.loadingMeasure(_root),
      view = View.of(_root),
      share = isolated.archiveAllShareMessenger;
  return {
    'phase': phase,
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
    ...f.loadingJudgment(m),
    'frameworkErrors': List<String>.from(_errors),
    'requests': List<String>.from(_server.loadingRequests),
    'socialCalls': List<String>.from(_social.calls),
    'storageReads': _storage.reads,
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
        'Actual root with controlled in-memory API/session/OAuth and first-bootstrap share isolation. No production/OAuth/physical-device proof.',
  };
}

Future<Map<String, Object?>> _report() async {
  final s = _snapshot(), share = isolated.archiveAllShareMessenger;
  final behavior =
      _done &&
      _checks.every((c) => c['passed'] == true) &&
      share?.nativeDelegationCount == 0 &&
      (share?.unknownShareMethods.isEmpty ?? false);
  final report = {
    ...s,
    'checksCompleted': _done,
    'checks': List<Map<String, Object?>>.from(_checks),
    'behaviorPassed': behavior,
    'passed':
        behavior &&
        s['stylePassed'] == true &&
        s['layoutPassed'] == true &&
        s['assetPassed'] == true &&
        _errors.isEmpty,
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  return report;
}

Future<void> _scene() async {
  await _fresh();
  await _wait(() => _waiting, 'Initial category wait missing');
  await _settle(4);
}

Future<void> _run() async {
  _checks.clear();
  _done = false;
  _runClock = Stopwatch()..start();
  await _fresh();
  _record(
    'cold_restore_begins_under_existing_splash',
    _route() == 'splash' && _storage.reads == 1,
  );
  await _wait(() => _waiting, 'Cold initial wait missing');
  _record(
    'cold_initial_categories_held_until_release',
    _waiting &&
        _server.loadingRequests
                .where((p) => p.endsWith('/api/v1/categories'))
                .length ==
            1 &&
        !_server.loadingRequests.any((p) => p.endsWith('/api/v1/feed')),
  );
  await Future<void>.delayed(const Duration(milliseconds: 700));
  _server.release();
  await _wait(() => _route() == 'home', 'Cold initial normal home missing');
  _record(
    'cold_restore_normal_home_only_after_existing_sequence',
    _route() == 'home' &&
        _server.loadingRequests.contains('GET /api/v1/users/me/stats'),
  );
  await Future<void>.delayed(const Duration(milliseconds: 700));
  await _fresh(empty: true);
  await _wait(() => _waiting, 'Empty first load missing');
  _server.release();
  await _wait(() => _route() == 'home', 'Empty home missing');
  _record(
    'zero_content_reaches_existing_empty_home',
    _route() == 'home' && _text('아직 저장한 콘텐츠가 없어요.') != null,
  );
  await Future<void>.delayed(const Duration(milliseconds: 700));
  await _fresh(gated: false);
  await _wait(() => _route() == 'home', 'Fast root home missing');
  _record(
    'fast_restore_not_held_for_minimum_loading_time',
    _route() == 'home' && _storage.reads == 1,
  );
  await _fresh(stored: false);
  await _wait(() => _route() == 'login', 'Existing account login missing');
  _record(
    'no_session_uses_existing_login_not_home_loading',
    _route() == 'login',
  );
  final provider = f.loadingKey(_root, 'login-provider-google');
  _require(provider != null, 'Actual Google button missing');
  await Scrollable.ensureVisible(provider!);
  await _tap(provider);
  await login.loginConfirmPermissionGuide(_root, tap: _tap);
  await _wait(
    () => _server.loadingRequests.contains('GET /api/v1/categories'),
    'Authenticated existing account data query missing',
  );
  _record(
    'existing_social_enters_loading_only_after_authentication',
    (phase == 'before' ? _route() == 'login' : _route() == 'home-loading') &&
        _social.calls.length == 1 &&
        _server.socialIssuances == 1,
  );
  await Future<void>.delayed(const Duration(milliseconds: 700));
  _server.release(fail: true);
  await _wait(
    () =>
        _route() == 'restore' &&
        (f.loadingFind<SessionRestoreScreen>(_root)!.widget
                    as SessionRestoreScreen)
                .errorMessage !=
            null,
    'Existing error screen missing',
  );
  _record(
    'first_initialization_failure_uses_existing_error',
    _route() == 'restore' &&
        (f.loadingFind<SessionRestoreScreen>(_root)!.widget
                    as SessionRestoreScreen)
                .errorMessage !=
            null,
  );
  await Future<void>.delayed(const Duration(milliseconds: 700));
  _server.failCategory = false;
  _server.categoryGate = Completer<void>();
  final retry = _text('다시 시도');
  _require(retry != null, 'Actual retry missing');
  await _tap(retry!);
  await _settle(3);
  _record(
    'manual_retry_reuses_initial_loading_without_reauthentication',
    _waiting && _social.calls.length == 1 && _server.socialIssuances == 1,
  );
  await Future<void>.delayed(const Duration(milliseconds: 700));
  _server.release();
  await _wait(() => _route() == 'home', 'Retry home missing');
  _record(
    'manual_retry_success_reaches_home_once',
    _route() == 'home' &&
        _social.calls.length == 1 &&
        _server.socialIssuances == 1,
  );
  await Future<void>.delayed(const Duration(milliseconds: 700));
  WidgetsBinding.instance.handleAppLifecycleStateChanged(
    AppLifecycleState.inactive,
  );
  WidgetsBinding.instance.handleAppLifecycleStateChanged(
    AppLifecycleState.resumed,
  );
  await _settle(3);
  _record('resume_does_not_replay_initial_loading', _route() == 'home');
  final share = isolated.archiveAllShareMessenger;
  _record(
    'first_bootstrap_native_share_isolated',
    share?.nativeDelegationCount == 0 &&
        (share?.unknownShareMethods.isEmpty ?? false),
  );
  _record('framework_errors_zero', _errors.isEmpty);
  await _scene();
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-home-loading-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _fresh();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('HOME_LOADING ready phase=$phase output=${_output.path}');
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
          await _scene();
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
      debugPrint('HOME_LOADING failure $e\n$st');
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
