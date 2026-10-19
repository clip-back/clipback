// B01: this exact source compiles on e2ea948 and AFTER. No new product import.
// Native sharing is isolated before startup; all authentication is in memory.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/share/pending_share_prompt.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../fixtures/permission_guide_alignment_fixture.dart' as f;
import 'archive_all_preview.dart' as isolated;
import 'login_alignment_preview.dart' as login;

const permissionPhase = String.fromEnvironment(
  'PERMISSION_GUIDE_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
login.LoginServer _server = login.LoginServer();
login.LoginMemoryStorage _storage = login.LoginMemoryStorage();
late login.LoginControlledSocial _social;
late Directory _output;
final _checks = <Map<String, Object?>>[],
    _sessions = <Map<String, Object?>>[],
    _errors = <String>[];
Map<String, Object?> _fonts = {};
bool _busy = false, _done = false, _coverage = false;
int _epoch = 0, _pointer = 78000;
Element get _root => _capture.currentContext! as Element;
Element get _login => f.permissionFind<LoginScreen>(_root)!;
Element? get _sheet => f.permissionSheet(_root);
String _route() => f.permissionKey(_root, 'login-progress-screen') != null
    ? 'progress'
    : f.permissionKey(_root, 'login-cancelled-screen') != null
    ? 'cancelled'
    : f.permissionKey(_root, 'login-failure-screen') != null
    ? 'failure'
    : _sheet != null
    ? 'permissionGuide'
    : f.permissionFind<LoginScreen>(_root) != null
    ? 'login'
    : f.permissionFind<OnboardingScreen>(_root) != null
    ? 'onboarding'
    : f.permissionFind<HomeScreen>(_root) != null
    ? 'home'
    : 'other';
void _require(bool yes, String why) {
  if (!yes) {
    throw StateError(why);
  }
}

Future<void> _settle([int count = 4]) async {
  for (var i = 0; i < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _wait(bool Function() yes, String why) async {
  for (var i = 0; i < 120; i++) {
    if (yes()) {
      return;
    }
    await _settle(2);
  }
  throw StateError(why);
}

Future<void> _point(Offset point) async {
  final id = ++_pointer, view = View.of(_root);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await _settle(4);
}

Future<void> _tap(Element e) async {
  await Scrollable.ensureVisible(
    e,
    duration: const Duration(milliseconds: 100),
    alignment: .5,
  );
  await _settle(3);
  await _point(f.permissionBox(e).center);
}

Element _provider(SocialLoginProvider p) =>
    f.permissionKey(_login, 'login-provider-${p.name}')!;
Future<void> _waitGuideStable() async {
  await _wait(
    () =>
        _sheet != null &&
        ModalRoute.of(_sheet!)?.animation?.status == AnimationStatus.completed,
    'B01 appearance transition did not complete before measurement',
  );
  await _settle(2);
}

Future<void> _select(SocialLoginProvider p) async {
  await _tap(_provider(p));
  if (_sheet != null) {
    await _waitGuideStable();
  }
}

Element _guest() =>
    f.permissionKey(_login, 'login-guest-hit') ??
    f.permissionText(_login, '게스트로 시작하기')!;
Future<void> _approve() async {
  _require(_sheet != null, 'Actual B01 sheet required');
  await _tap(f.permissionKey(_sheet!, 'permission-guide-continue-hit')!);
  await _wait(() => _sheet == null, 'B01 route was not fully removed');
  await _settle(5);
}

Map<String, Object?> _auth() => {
  'providerCalls': List<String>.from(_social.calls),
  'noncePresent': List<bool>.from(_social.noncePresent),
  'guestIssuances': _server.guestIssuances,
  'socialIssuances': _server.socialIssuances,
  'challengeRequests': _server.challenges,
  'sessionWrites': _storage.writes,
  'hasSession': _storage.value != null,
  'unexpectedRequests': List<String>.from(_server.unexpected),
  'contentWrites': _server.contentWrites,
  'requests': List<Map<String, Object?>>.from(_server.requests),
};
Future<void> _fresh() async {
  if (_epoch > 0) {
    _sessions.add(_auth());
  }
  runApp(const SizedBox.shrink());
  await _settle(2);
  _server = login.LoginServer();
  _storage = login.LoginMemoryStorage();
  _social = login.LoginControlledSocial(
    Platform.isIOS ? TargetPlatform.iOS : TargetPlatform.android,
  );
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
        f.permissionFind<LoginScreen>(_root) != null &&
        !(_login.widget as LoginScreen).busy,
    'Fresh empty-session login missing',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _settle(5);
  _require(
    _storage.value == null &&
        _server.guestIssuances == 0 &&
        _server.socialIssuances == 0,
    'Session issued before selection',
  );
  await _wait(
    () =>
        (f.permissionFind<PendingSharePrompt>(_root)?.widget
                as PendingSharePrompt?)
            ?.busy ==
        false,
    'Native share preparation did not settle',
  );
  final prompt =
      f.permissionFind<PendingSharePrompt>(_root)?.widget
          as PendingSharePrompt?;
  _require(
    prompt != null &&
        !prompt.busy &&
        prompt.error == null &&
        prompt.drafts.isEmpty,
    'Native-share fixture unexpectedly blocks login',
  );
}

Map<String, Object?> _snapshot() {
  final m = f.permissionMeasure(_root),
      view = View.of(_root),
      share = isolated.archiveAllShareMessenger;
  final prompt =
      f.permissionFind<PendingSharePrompt>(_root)?.widget
          as PendingSharePrompt?;
  return {
    'phase': permissionPhase,
    'platform': Platform.operatingSystem,
    'route': _route(),
    'sheetMounted': _sheet != null,
    'sheetAnimationStatus': _sheet == null
        ? null
        : ModalRoute.of(_sheet!)?.animation?.status.name,
    'textScale': MediaQueryData.fromView(view).textScaler.scale(1),
    'sdkCallCount': _social.calls.length,
    'requests': List<Map<String, Object?>>.from(_server.requests),
    'sharePromptMounted': prompt != null,
    'sharePromptBlocked': prompt?.busy ?? false,
    'sharePromptError': prompt?.error,
    'shareDraftCount': prompt?.drafts.length ?? -1,
    'ready': true,
    'fixtureBusy': _busy,
    'output': _output.path,
    'logicalWidth': view.physicalSize.width / view.devicePixelRatio,
    'logicalHeight': view.physicalSize.height / view.devicePixelRatio,
    'pixelRatio': view.devicePixelRatio,
    'viewPaddingTop': view.viewPadding.top / view.devicePixelRatio,
    'viewPaddingBottom': view.viewPadding.bottom / view.devicePixelRatio,
    'viewInsetsBottom': view.viewInsets.bottom / view.devicePixelRatio,
    ...m,
    ...f.permissionJudgment(m, requireActive: true),
    'auth': _auth(),
    'fonts': _fonts,
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
    'osPermissionRequestPolicy':
        'No OS permission request is implemented; confirm with the separate production diff/static audit, not an invented runtime counter.',
    'scope':
        'Actual ClipbackApp, empty in-memory session, platform providers and mock API. No operating-system permission request; no real OAuth, production, physical device or persistence proof.',
  };
}

void _record(String scenario, [Map<String, Object?> fields = const {}]) {
  final snapshot = _snapshot(),
      judgment = f.permissionJudgment(f.permissionMeasure(_root));
  _checks.add({
    ...snapshot,
    ...judgment,
    'scenario': scenario,
    'passed': true,
    ...fields,
  });
}

Future<Map<String, Object?>> _report() async {
  final s = _snapshot(), share = isolated.archiveAllShareMessenger;
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
  final behavior =
      _done &&
      share != null &&
      share.nativeDelegationCount == 0 &&
      share.unknownShareMethods.isEmpty &&
      !_checks.any((c) => c['passed'] == false) &&
      [..._sessions, _auth()].every(
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
    'sessionSummaries': [..._sessions, _auth()],
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  return result;
}

Future<void> _captureScene() async {
  _require(
    View.of(_root).viewInsets.bottom == 0,
    'Scene requires hidden keyboard',
  );
  final image =
      await (_capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: View.of(_root).devicePixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_output.path}/permission_guide_scale_1_scroll_0.png',
    ).writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _record(
    permissionPhase == 'before'
        ? 'baseline_login_no_corresponding_B01'
        : 'new_B01_sheet_static',
  );
}

Future<void> _scene() async {
  await _fresh();
  if (permissionPhase != 'before') {
    await _select(SocialLoginProvider.kakao);
    await _wait(() => _sheet != null, 'Approved B01 route missing');
    f.permissionPosition(_root)?.jumpTo(0);
    await _settle(6);
  }
  await _captureScene();
}

Future<void> _maxScroll() async {
  final p = f.permissionPosition(_root);
  _require(p != null, 'B01 scroll viewport required');
  p!.jumpTo(p.maxScrollExtent);
  await _settle(5);
  _record('maximum_scroll_last_guide_accessible', {
    'maxScrollExtent': p.maxScrollExtent,
    'scrollOffset': p.pixels,
  });
}

Future<void> _dragDismiss() async {
  final handle = f.permissionKey(_sheet!, 'permission-guide-handle')!,
      start = f.permissionBox(handle).center,
      id = ++_pointer,
      view = View.of(_root);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: view.viewId, position: start),
  );
  for (var i = 1; i <= 12; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 15));
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: id,
        viewId: view.viewId,
        position: start + Offset(0, i * 30),
        delta: const Offset(0, 30),
      ),
    );
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: view.viewId,
      position: start + const Offset(0, 360),
    ),
  );
  await _settle(10);
}

Future<void> _run() async {
  _checks.clear();
  _sessions.clear();
  _done = false;
  _coverage = false;
  await _fresh();
  _record('empty_session_ordinary_login_no_auth');
  if (permissionPhase == 'before') {
    await _select(SocialLoginProvider.kakao);
    await _wait(
      () => _social.calls.length == 1,
      'Baseline selection did not call SDK directly',
    );
    _require(
      _sheet == null && _storage.value == null,
      'Baseline SDK cancel must leave login',
    );
    _record('baseline_selection_immediately_authenticates_without_B01', {
      'provider': 'kakao',
    });
    await _fresh();
    await _captureScene();
    _coverage = true;
    _done = true;
    return;
  }
  await _select(SocialLoginProvider.kakao);
  await _wait(() => _sheet != null, 'First choice must show B01');
  _require(
    _social.calls.isEmpty &&
        _server.guestIssuances == 0 &&
        _server.socialIssuances == 0,
    'Guide must precede SDK and issuance',
  );
  _record('first_social_choice_guide_before_auth');
  final panel = f.permissionBox(
    f.permissionKey(_sheet!, 'permission-guide-panel')!,
  );
  await _point(
    Offset(
      View.of(_root).physicalSize.width / View.of(_root).devicePixelRatio / 2,
      (panel.top +
              View.of(_root).viewPadding.top /
                  View.of(_root).devicePixelRatio) /
          2,
    ),
  );
  await _wait(() => _sheet == null, 'Barrier should cancel');
  _require(_social.calls.isEmpty, 'Barrier cancellation authenticated');
  _record('barrier_cancel_no_auth');
  await _select(SocialLoginProvider.kakao);
  await _wait(() => _sheet != null, 'Cancel must not remember approval');
  await WidgetsBinding.instance.handlePopRoute();
  await _wait(() => _sheet == null, 'OS back should dismiss only guide');
  _require(_social.calls.isEmpty, 'OS back authenticated');
  _record('os_back_cancel_no_auth');
  await _select(SocialLoginProvider.kakao);
  await _wait(() => _sheet != null, 'Guide missing before drag');
  await _dragDismiss();
  await _wait(() => _sheet == null, 'Downward drag should cancel');
  _require(_social.calls.isEmpty, 'Drag cancellation authenticated');
  _record('drag_cancel_no_auth');
  _social.gate = Completer<SocialCredential?>();
  final screen = _login.widget as LoginScreen;
  await _select(SocialLoginProvider.kakao);
  await _wait(() => _sheet != null, 'Guide missing before approval');
  await _approve();
  await _wait(
    () => _social.calls.length == 1,
    'Approved action must call captured provider once',
  );
  _require(
    _social.calls.single == 'kakao' &&
        (_route() == 'progress' ||
            (_route() == 'login' && (_login.widget as LoginScreen).busy)),
    'Wrong selected provider or missing auth busy',
  );
  _record('approve_removes_route_then_selected_sdk_once');
  unawaited(screen.onContinue());
  unawaited(screen.onSocialLogin(SocialLoginProvider.google));
  await _settle(5);
  _require(
    _social.calls.length == 1 && _server.guestIssuances == 0,
    'Busy duplicates must be blocked',
  );
  _record('auth_pending_duplicate_social_guest_blocked');
  _social.gate!.complete(null);
  _social.gate = null;
  await _wait(
    () =>
        _route() == 'cancelled' ||
        (_route() == 'login' && !(_login.widget as LoginScreen).busy),
    'SDK cancel should unlock login',
  );
  await login.loginReturnFromFailureIfPresent(_root, tap: _tap);
  _require(_storage.value == null, 'Cancelled SDK issued session');
  _record('sdk_cancel_preserves_empty_session');
  await _select(SocialLoginProvider.google);
  await _wait(
    () => _social.calls.length == 2,
    'Remembered approval must permit another provider',
  );
  _require(
    _sheet == null && _social.calls.last == 'google',
    'Same login re-prompted after approved cancel',
  );
  _record('same_login_other_provider_skips_guide');
  await _wait(
    () =>
        _route() == 'cancelled' ||
        (_route() == 'login' && !(_login.widget as LoginScreen).busy),
    'Second SDK cancellation missing',
  );
  await login.loginReturnFromFailureIfPresent(_root, tap: _tap);
  _social.fail = true;
  await _select(SocialLoginProvider.kakao);
  await _wait(() => _social.calls.length == 3, 'SDK failure missing');
  await _wait(
    () =>
        _route() == 'failure' ||
        (_route() == 'login' && !(_login.widget as LoginScreen).busy),
    'Failed SDK did not unlock',
  );
  await login.loginReturnFromFailureIfPresent(_root, tap: _tap);
  _require(
    _sheet == null && _storage.value == null,
    'Failed SDK should not re-prompt or issue session',
  );
  _record('sdk_failure_no_new_guide_no_session');
  _social.fail = false;
  await _select(SocialLoginProvider.google);
  await _wait(() => _social.calls.length == 4, 'Retry must call SDK');
  _require(_sheet == null, 'Retry must preserve entry approval');
  _record('manual_retry_reuses_login_entry_approval');
  await _fresh();
  await _select(SocialLoginProvider.kakao);
  await _wait(() => _sheet != null, 'Fresh login must re-prompt');
  _require(_social.calls.isEmpty, 'New entry called SDK before approval');
  _record('new_login_entry_resets_approval');
  await WidgetsBinding.instance.handlePopRoute();
  await _wait(() => _sheet == null, 'Guide back missing');
  _server.newUser = true;
  await _tap(_guest());
  await _wait(() => _sheet != null, 'Guest first selection should show B01');
  await _waitGuideStable();
  _require(_server.guestIssuances == 0, 'Guest issuance before continue');
  _record('guest_guide_before_issuance');
  await _approve();
  await _wait(
    () => _server.guestIssuances == 1 && _storage.value != null,
    'Approved guest session missing',
  );
  await _wait(
    () => ['onboarding', 'home'].contains(_route()),
    'Guest existing route missing',
  );
  _record('approved_guest_issuance_once_existing_destination');
  await _scene();
  await _maxScroll();
  f.permissionPosition(_root)?.jumpTo(0);
  await _settle(5);
  _record('final_fresh_B01_scroll_zero');
  _coverage = true;
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-permission-guide-');
  _fonts = await f.permissionLoadFonts();
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add(details.exceptionAsString());
    old?.call(details);
  };
  await _fresh();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'PERMISSION_GUIDE ready phase=$permissionPhase output=${_output.path}',
  );
  await for (final request in server) {
    final read = ['/status', '/state', '/ready'].contains(request.uri.path);
    if (_busy && !read) {
      request.response.statusCode = 409;
      await request.response.close();
      continue;
    }
    if (!read) {
      _busy = true;
    }
    try {
      switch (request.uri.path) {
        case '/status':
        case '/state':
        case '/ready':
          break;
        case '/scene':
          await _scene();
        case '/max-scroll':
          await _maxScroll();
        case '/run':
          await _run();
        default:
          request.response.statusCode = 404;
      }
      final result = await _report();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(result));
    } catch (error, stack) {
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$error',
      });
      debugPrint('PERMISSION_GUIDE FAIL $error\n$stack');
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'error': '$error', ...await _report()}),
      );
    } finally {
      if (!read) {
        _busy = false;
      }
      await request.response.close();
    }
  }
}, () => _server.client);
