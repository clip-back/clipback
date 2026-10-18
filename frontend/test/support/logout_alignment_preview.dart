// J03: actual ClipbackApp + memory API/session. Native sharing is isolated
// before first bootstrap. Runtime discovery also compiles on c06e990 BEFORE.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/session_restore_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../fixtures/logout_alignment_fixture.dart' as f;
import 'archive_all_preview.dart' as isolated;

const logoutPhase = String.fromEnvironment(
  'LOGOUT_ALIGNMENT_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
f.LogoutServer _server = f.LogoutServer('member');
f.LogoutMemoryStorage _storage = f.LogoutMemoryStorage();
final _sessions = <f.LogoutServer>[],
    _errors = <String>[],
    _checks = <Map<String, Object?>>[];
late Directory _output;
Map<String, Object?> _fontBundle = {};
String _kind = 'member';
bool _busy = false, _done = false, _coverage = false;
int _epoch = 0, _pointer = 21000;
Element get _root => _capture.currentContext! as Element;
Element get _account => f.logoutFind<AccountManagementScreen>(_root)!;
Element get _confirmation => f.logoutScreen(_root)!;
String _route() {
  if (_capture.currentContext == null) return 'mounting';
  if (f.logoutScreen(_root) != null) return 'logoutConfirmation';
  if (f.logoutFind<SessionRestoreScreen>(_root) != null) {
    return 'sessionRestore';
  }
  if (f.logoutFind<AccountManagementScreen>(_root) != null) return 'account';
  if (f.logoutFind<MyScreen>(_root) != null) return 'my';
  if (f.logoutFind<HomeScreen>(_root) != null) return 'home';
  if (f.logoutFind<LoginScreen>(_root) != null) return 'login';
  return 'other';
}

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
  for (var i = 0; i < 120; i++) {
    if (yes()) return;
    await _settle(2);
  }
  throw StateError(why);
}

Future<void> _tap(Element e) async {
  final point = f.logoutBox(e).center, id = ++_pointer, v = View.of(_root);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: v.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 60));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: v.viewId, position: point),
  );
  await _settle(2);
}

Future<void> _show(Element e) async {
  await Scrollable.ensureVisible(
    e,
    duration: const Duration(milliseconds: 120),
    alignment: .5,
  );
  await _settle(3);
}

Future<void> _open() async {
  final e = f.logoutText(_account, '로그아웃')!;
  await _show(e);
  await _tap(e);
  await _wait(
    () => _route() == 'logoutConfirmation',
    'Logout did not open J03',
  );
}

Future<void> _fresh(String kind, {bool confirmation = true}) async {
  _kind = kind;
  _server = f.LogoutServer(kind);
  _sessions.add(_server);
  _storage = f.LogoutMemoryStorage();
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: ValueKey(++_epoch),
        sessionStorage: _storage,
        socialAuth: isolated.ArchiveAllSocialAuth(),
      ),
    ),
  );
  await _settle(2);
  await _wait(() => _route() == 'home', 'Memory home startup missing');
  await _tap(f.logoutText(f.logoutFind<ClipbackNavigationBar>(_root)!, '마이')!);
  await _wait(
    () =>
        _route() == 'my' &&
        (f.logoutFind<MyScreen>(_root)!.widget as MyScreen).user.name ==
            _server.expected.name &&
        (f.logoutFind<MyScreen>(_root)!.widget as MyScreen)
                .user
                .revisitedContentCount ==
            _server.expected.revisitedContentCount,
    'Memory My mapping missing',
  );
  await _tap(f.logoutFind<MyProfileRow>(_root)!);
  await _wait(() => _route() == 'account', 'Account entry missing');
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _wait(
    () => View.of(_root).viewInsets.bottom == 0,
    'Keyboard hide failed',
  );
  if (confirmation && logoutPhase != 'before') await _open();
  f.logoutPosition(_root)?.jumpTo(0);
  await _settle(3);
}

Map<String, Object?> _snapshot() {
  if (_capture.currentContext == null) {
    return {
      'ready': false,
      'route': 'mounting',
      'phase': logoutPhase,
      'platform': Platform.operatingSystem,
    };
  }
  final m = f.logoutMeasure(_root),
      v = View.of(_root),
      messenger = isolated.archiveAllShareMessenger;
  final j = f.logoutJudgment(
    m,
    requireScreen:
        _route() == 'logoutConfirmation' ||
        (_route() == 'account' && logoutPhase == 'before'),
  );
  return {
    'ready': true,
    'phase': logoutPhase,
    'kind': _kind,
    'platform': Platform.operatingSystem,
    'route': _route(),
    'busy': _busy,
    'output': _output.path,
    'logicalSize': '${v.physicalSize / v.devicePixelRatio}',
    'pixelRatio': v.devicePixelRatio,
    'viewPaddingTop': v.viewPadding.top / v.devicePixelRatio,
    'viewPaddingBottom': v.viewPadding.bottom / v.devicePixelRatio,
    'viewInsetsBottom': v.viewInsets.bottom / v.devicePixelRatio,
    'textScale': 1.0,
    ...m,
    ...j,
    'requests': List<Map<String, Object?>>.from(_server.requests),
    'unexpectedRequests': List<String>.from(_server.unexpected),
    'writeRequests': _server.writes,
    'logoutRequests': _server.logoutCalls,
    'serverRecordCount': _server.records.length,
    'storageClears': _storage.clears,
    'sessionPresent': _storage.value != null,
    'fontBundle': _fontBundle,
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        messenger,
      ),
      'nativeDelegationCount': messenger?.nativeDelegationCount,
      'unknownMethods': messenger?.unknownShareMethods ?? <String>[],
      'methodCounts': {
        for (final n in messenger?.namesOnlyCalls.toSet() ?? <String>{})
          n: messenger!.namesOnlyCalls.where((v) => v == n).length,
      },
      'argumentsOrCredentialsRecorded': false,
    },
    'frameworkErrors': List<String>.from(_errors),
    'scope':
        'Actual ClipbackApp, memory HTTP/session; real native window and pointer actions. No live OAuth, production server, physical device, or remote CI proof.',
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
  final s = _snapshot(), messenger = isolated.archiveAllShareMessenger;
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
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_output.path}/logout_${_kind}_scale_1_scroll_0.png',
    ).writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  final s = _snapshot();
  await File(
    '${_output.path}/logout_${_kind}_state.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(s));
}

Future<void> _baselineRun() async {
  _checks.clear();
  _sessions.clear();
  _done = false;
  _coverage = false;
  await _fresh('member', confirmation: false);
  _record('baseline_account_before_logout', {'directJ03BeforeExists': false});
  _server.logoutGate = Completer<http.Response>();
  final row = f.logoutText(_account, '로그아웃')!;
  await _show(row);
  await _tap(row);
  await _wait(
    () => _server.logoutCalls == 1,
    'Baseline immediate request missing',
  );
  _require(
    _route() == 'account' && _storage.value != null,
    'Baseline account pending unexpected',
  );
  _record('baseline_immediate_logout_without_confirmation');
  _server.logoutGate!.complete(http.Response('', 204));
  await _wait(() => _route() == 'login', 'Baseline logout success failed');
  _require(_storage.value == null, 'Baseline clear missing');
  _record('baseline_success_login');
  await _fresh('member', confirmation: false);
  _done = true;
  _coverage = true;
}

Future<void> _run() async {
  _checks.clear();
  _sessions.clear();
  _done = false;
  _coverage = false;
  for (final kind in ['member', 'guest']) {
    await _fresh(kind);
    _require(_server.logoutCalls == 0, 'Entry sent logout');
    final initialUser = _server.expected, initialCount = _server.records.length;
    _record('${kind}_confirmation_no_request');
    await _tap(f.logoutKey(_confirmation, 'logout-cancel')!);
    await _wait(() => _route() == 'account', 'Cancel did not return account');
    final user = (_account.widget as AccountManagementScreen).user;
    _require(
      _server.logoutCalls == 0 &&
          _storage.value != null &&
          user.name == initialUser.name &&
          user.savedContentCount == initialUser.savedContentCount &&
          user.revisitedContentCount == initialUser.revisitedContentCount &&
          _server.records.length == initialCount,
      'Cancel mutated session/user/stats/content',
    );
    _record('${kind}_cancel_preserved');
    await _open();
    await _tap(f.logoutKey(_confirmation, 'logout-back-hit')!);
    await _wait(() => _route() == 'account', 'Header back did not return');
    _require(_server.logoutCalls == 0, 'Header back sent request');
    _record('${kind}_header_back_no_request');
    await _open();
    await WidgetsBinding.instance.handlePopRoute();
    await _settle(3);
    _require(
      _route() == 'account' && _server.logoutCalls == 0,
      'OS back idle failed',
    );
    _record('${kind}_os_back_no_request');
    await _open();
    _server.logoutGate = Completer<http.Response>();
    await _tap(f.logoutKey(_confirmation, 'logout-confirm')!);
    await _wait(
      () =>
          _server.logoutCalls == 1 &&
          f.logoutMeasure(_root)['authBusy'] == true,
      'Confirm pending missing',
    );
    _record('${kind}_request_pending');
    for (final key in ['logout-confirm', 'logout-cancel', 'logout-back-hit']) {
      await _tap(f.logoutKey(_confirmation, key)!);
    }
    await WidgetsBinding.instance.handlePopRoute();
    await _settle(3);
    _require(
      _route() == 'logoutConfirmation' &&
          _server.logoutCalls == 1 &&
          _storage.value != null,
      'Pending lock failed',
    );
    _record('${kind}_all_pending_locks');
    _server.logoutGate!.complete(
      _server.json({'detail': '로그아웃 대역 요청 실패'}, 503),
    );
    await _wait(
      () =>
          _route() == 'logoutConfirmation' &&
          f.logoutMeasure(_root)['authBusy'] == false,
      'Failed request did not unlock J03',
    );
    _require(
      _storage.value != null && _server.records.length == initialCount,
      'Failure lost session/content',
    );
    _record('${kind}_failure_preserved_retry_available');
    ScaffoldMessenger.of(_confirmation).hideCurrentSnackBar();
    await _settle(6);
    _server.logoutGate = null;
    await _tap(f.logoutKey(_confirmation, 'logout-confirm')!);
    await _wait(
      () => _route() == 'login',
      'Retry success did not select login',
    );
    _require(
      _server.logoutCalls == 2 && _storage.value == null,
      'Retry count/session mismatch',
    );
    _record('${kind}_retry_success_login');
  }
  await _fresh('member');
  _storage.failClear = true;
  await _tap(f.logoutKey(_confirmation, 'logout-confirm')!);
  await _wait(
    () => _route() == 'sessionRestore',
    'Local session clear failure must prioritize recovery',
  );
  _require(
    _server.logoutCalls == 1 && _storage.value != null,
    'Recovery branch missing memory session',
  );
  _record('local_clear_failure_recovery_priority');
  await _fresh('member');
  final p = f.logoutPosition(_root);
  if (p != null) p.jumpTo(p.maxScrollExtent);
  await _settle(2);
  _record('maximum_scroll', {
    'maximum': p?.maxScrollExtent ?? 0,
    'noScroll': p == null || p.maxScrollExtent == 0,
  });
  p?.jumpTo(0);
  await _settle(2);
  _record('final_member_confirmation_scroll_zero');
  _done = true;
  _coverage = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-logout-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  _fontBundle = await f.logoutInspectFonts();
  await _fresh('member');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('LOGOUT ready phase=$logoutPhase output=${_output.path}');
  await for (final request in server) {
    final read = ['/status', '/state', '/ready'].contains(request.uri.path);
    if (_busy && !read) {
      request.response.statusCode = 409;
      await request.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (request.uri.path) {
        case '/status':
        case '/state':
        case '/ready':
          break;
        case '/scene':
          final kind = request.uri.queryParameters['kind'] ?? 'member';
          _require(
            ['member', 'guest'].contains(kind),
            'kind member|guest required',
          );
          await _fresh(kind);
          await _captureScene();
        case '/baseline-run':
          _require(logoutPhase == 'before', 'baseline-run only before');
          await _baselineRun();
        case '/run':
          _require(logoutPhase != 'before', 'run requires after phase');
          await _run();
        default:
          request.response.statusCode = 404;
      }
      await _report();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        await File('${_output.path}/report.json').readAsString(),
      );
    } catch (error, stack) {
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$error',
      });
      debugPrint('LOGOUT FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
