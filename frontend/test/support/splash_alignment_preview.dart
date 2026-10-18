// A01 static captures and actual-root startup behavior; native share isolation
// is installed before the first engine bootstrap, not after app creation.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/session_restore_screen.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../fixtures/splash_alignment_fixture.dart' as f;
import 'archive_all_preview.dart' as isolated;
import 'login_alignment_preview.dart' as login;

const splashPhase = String.fromEnvironment(
  'SPLASH_ALIGNMENT_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
late Directory _output;
login.LoginServer _server = login.LoginServer();
f.SplashMemoryStorage _storage = f.SplashMemoryStorage();
final _errors = <String>[], _checks = <Map<String, Object?>>[];
final _startupEvents = <Map<String, Object?>>[];
Stopwatch? _startupClock;
bool _busy = false, _done = false, _hasMounted = false;
int _epoch = 0, _doneCalls = 0;
String _kind = 'isolated';
Element get _root => _capture.currentContext! as Element;
String _route() => f.splashFind<SplashScreen>(_root) != null
    ? 'splash'
    : f.splashFind<LoginScreen>(_root) != null
    ? 'login'
    : f.splashFind<HomeScreen>(_root) != null
    ? 'home'
    : f.splashFind<SessionRestoreScreen>(_root) != null
    ? 'restore'
    : 'other';
Future<void> _settle([int n = 3]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _wait(bool Function() ready, String why) async {
  for (var i = 0; i < 100; i++) {
    if (ready()) return;
    await _settle(2);
  }
  throw StateError(why);
}

void _require(bool p, String why) {
  if (!p) throw StateError(why);
}

Map<String, Object?> _snapshot() {
  final m = f.splashMeasure(_root),
      v = View.of(_root),
      share = isolated.archiveAllShareMessenger;
  return {
    'phase': splashPhase,
    'kind': _kind,
    'platform': Platform.operatingSystem,
    'ready': true,
    'output': _output.path,
    'route': _route(),
    'doneCalls': _doneCalls,
    'logicalSize': '${v.physicalSize / v.devicePixelRatio}',
    'pixelRatio': v.devicePixelRatio,
    'viewPaddingTop': v.viewPadding.top / v.devicePixelRatio,
    'viewPaddingBottom': v.viewPadding.bottom / v.devicePixelRatio,
    'viewInsetsBottom': v.viewInsets.bottom / v.devicePixelRatio,
    ...m,
    ...f.splashJudgment(m),
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
    'storageReads': _storage.reads,
    'startupEvents': List<Map<String, Object?>>.from(_startupEvents),
    'contentWrites': _server.contentWrites,
    'guestIssuances': _server.guestIssuances,
    'unexpectedRequests': _server.unexpected,
    'scope':
        'Static actual SplashScreen held after existing onDone, independently from actual-root startup. In-memory API/session only; no production/OAuth/physical-device proof.',
  };
}

Future<Map<String, Object?>> _report() async {
  final s = _snapshot(), share = isolated.archiveAllShareMessenger;
  final behavior =
      _done &&
      _checks.every((c) => c['passed'] == true) &&
      share?.nativeDelegationCount == 0 &&
      (share?.unknownShareMethods.isEmpty ?? false) &&
      _server.unexpected.isEmpty &&
      _server.contentWrites == 0;
  final result = {
    ...s,
    'checksCompleted': _done,
    'checks': _checks,
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
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  return result;
}

Future<void> _isolated({bool capture = true}) async {
  _kind = 'isolated';
  _doneCalls = 0;
  runApp(
    RepaintBoundary(
      key: _capture,
      child: MaterialApp(
        key: ValueKey(++_epoch),
        theme: f.splashTheme(),
        home: SplashScreen(onDone: () => _doneCalls++),
      ),
    ),
  );
  await _settle(5);
  if (capture) {
    final v = View.of(_root),
        image =
            await (_capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: v.devicePixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${_output.path}/splash_a01_scale_1_scroll_0.png',
      ).writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  }
}

Future<void> _freshRoot({String mode = 'empty'}) async {
  _kind = 'root-$mode';
  _startupEvents.clear();
  _startupClock = Stopwatch()..start();
  if (_hasMounted) {
    runApp(const SizedBox.shrink());
    await _settle(2);
  }
  _hasMounted = true;
  _server = login.LoginServer();
  _storage = f.SplashMemoryStorage();
  if (mode == 'existing' || mode == 'slow-existing') {
    _storage.value = f.splashStoredSession;
  }
  if (mode.startsWith('slow')) _storage.pendingRead = Completer<ApiSession?>();
  if (mode == 'error') _storage.failRead = true;
  final platform = Platform.isIOS ? TargetPlatform.iOS : TargetPlatform.android;
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: ValueKey(++_epoch),
        sessionStorage: _storage,
        socialAuth: login.LoginControlledSocial(platform),
      ),
    ),
  );
  final rootEpoch = _epoch;
  void recordFirstFrames(Duration _) {
    if (rootEpoch != _epoch || _capture.currentContext == null) return;
    final route = _route();
    if (_startupEvents.isEmpty || _startupEvents.last['route'] != route) {
      _startupEvents.add({
        'elapsedMs': _startupClock!.elapsedMilliseconds,
        'route': route,
        'storageReads': _storage.reads,
      });
    }
    if (route == 'splash' || route == 'restore') {
      WidgetsBinding.instance.addPostFrameCallback(recordFirstFrames);
    }
  }

  WidgetsBinding.instance.addPostFrameCallback(recordFirstFrames);
  await _settle(2);
}

void _record(
  String name,
  bool passed, [
  Map<String, Object?> extra = const {},
]) {
  _checks.add({
    'scenario': name,
    'passed': passed,
    'route': _route(),
    'storageReads': _storage.reads,
    'guestIssuances': _server.guestIssuances,
    'unexpectedRequests': List<String>.from(_server.unexpected),
    ...extra,
  });
}

Future<void> _run() async {
  _checks.clear();
  _done = false;
  await _freshRoot();
  _record(
    'fast_empty_parallel_restore_under_initial_splash',
    _route() == 'splash' && _storage.reads == 1,
  );
  await _wait(
    () => _route() == 'login',
    'Empty session login missing after splash',
  );
  _record(
    'fast_empty_to_login_no_guest',
    _server.guestIssuances == 0 && _storage.value == null,
  );
  await _freshRoot(mode: 'existing');
  _record(
    'fast_existing_initial_splash',
    _route() == 'splash' && _storage.reads == 1,
  );
  await _wait(
    () => _route() == 'home',
    'Existing session home missing after splash',
  );
  _record(
    'fast_existing_to_home_no_guest',
    _server.guestIssuances == 0 && _storage.value != null,
  );
  await _freshRoot(mode: 'slow-existing');
  _record(
    'slow_existing_restore_started_under_splash',
    _route() == 'splash' && _storage.reads == 1,
  );
  await _wait(
    () => _route() == 'restore',
    'Slow restore screen missing after splash',
  );
  _record(
    'slow_existing_after900_existing_restore',
    f.splashFind<SessionRestoreScreen>(_root) != null,
  );
  _storage.pendingRead!.complete(f.splashStoredSession);
  await _wait(
    () => _route() == 'home',
    'Released slow restore did not reach home',
  );
  _record(
    'slow_existing_release_home',
    _storage.reads == 1 && _server.guestIssuances == 0,
  );
  await _freshRoot(mode: 'error');
  await _wait(
    () => _route() == 'restore',
    'Storage failure missing existing restore screen',
  );
  final screen =
      f.splashFind<SessionRestoreScreen>(_root)!.widget as SessionRestoreScreen;
  _record(
    'error_uses_existing_retry',
    screen.errorMessage != null && _storage.reads == 1,
  );
  _storage.failRead = false;
  screen.onRetry();
  await _wait(() => _route() == 'login', 'Retry empty session missing login');
  _record(
    'retry_without_replaying_splash',
    _storage.reads == 2 && _server.guestIssuances == 0,
  );
  WidgetsBinding.instance.handleAppLifecycleStateChanged(
    AppLifecycleState.inactive,
  );
  WidgetsBinding.instance.handleAppLifecycleStateChanged(
    AppLifecycleState.resumed,
  );
  await _settle();
  _record(
    'resume_does_not_replay_splash',
    _route() == 'login' && _storage.reads == 2,
  );
  await _isolated(capture: false);
  await Future<void>.delayed(const Duration(milliseconds: 1000));
  await _settle(2);
  _record('isolated_timer_once_held_for_measurement', _doneCalls == 1);
  _require(_errors.isEmpty, 'Framework errors during startup');
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-splash-alignment-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await f.splashInspectFontBundle();
  // The first actual root starts before HTTP setup, so a cold native video can
  // record the actual native->Flutter->route transition without a hold screen.
  await _freshRoot();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'SPLASH_ALIGNMENT ready phase=$splashPhase output=${_output.path}',
  );
  await for (final request in server) {
    final read = [
      '/ready',
      '/state',
      '/status',
      '/export',
    ].contains(request.uri.path);
    if (_busy && !read) {
      request.response.statusCode = 409;
      request.response.write('{"error":"fixture busy"}');
      await request.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (request.uri.path) {
        case '/scene':
          await _isolated();
        case '/run':
          await _run();
        case '/root':
          await _freshRoot(
            mode: request.uri.queryParameters['mode'] ?? 'empty',
          );
        case '/ready':
        case '/state':
        case '/status':
        case '/export':
          break;
        default:
          request.response.statusCode = 404;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(await _report()));
    } catch (e, st) {
      debugPrint('SPLASH FAIL $e\n$st');
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$e',
      });
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': '$e', ...await _report()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
