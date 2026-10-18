// B02/B03/B04 fixture: real InterestSelectionScreen, pointer-driven selections,
// and a separate actual-root memory-auth flow. Install share isolation first.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../fixtures/interest_alignment_fixture.dart' as f;
import 'archive_all_preview.dart' as isolated;
import 'login_alignment_preview.dart' as login;

const interestPhase = String.fromEnvironment(
  'INTEREST_ALIGNMENT_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
late Directory _output;
login.LoginServer _server = login.LoginServer();
login.LoginMemoryStorage _storage = login.LoginMemoryStorage();
late login.LoginControlledSocial _social;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
bool _busy = false, _done = false, _hasMounted = false;
int _epoch = 0, _pointer = 0, _doneCalls = 0, _backCalls = 0;
String _kind = 'root', _state = 'empty';
List<int> _initialSelectedIndices = <int>[];
Element get _root => _capture.currentContext! as Element;
Element get _interest => f.interestFind<InterestSelectionScreen>(_root)!;
String _route() {
  if (_capture.currentContext == null) return 'mounting';
  return f.interestFind<SplashScreen>(_root) != null
      ? 'splash'
      : f.interestFind<LoginScreen>(_root) != null
      ? 'login'
      : f.interestFind<OnboardingScreen>(_root) != null
      ? 'onboarding'
      : f.interestFind<InterestSelectionScreen>(_root) != null
      ? 'interests'
      : f.interestFind<HomeScreen>(_root) != null
      ? 'home'
      : 'other';
}

Future<void> _settle([int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _wait(bool Function() ready, String why) async {
  for (var i = 0; i < 120; i++) {
    if (ready()) return;
    await _settle(2);
  }
  throw StateError(why);
}

void _require(bool p, String why) {
  if (!p) throw StateError(why);
}

Future<void> _tap(Element e) async {
  final id = ++_pointer, v = View.of(_root), point = f.interestBox(e).center;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: v.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 45));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: v.viewId, position: point),
  );
  await _settle(2);
}

Future<void> _visible(Element e) async {
  await Scrollable.ensureVisible(
    e,
    duration: const Duration(milliseconds: 100),
    alignment: .5,
  );
  await _settle(2);
}

Element _tile(int index) => f
    .interestElements(_interest)
    .where(
      (e) =>
          e.widget is InterestOptionTile &&
          (e.widget as InterestOptionTile).label == mockInterestOptions[index],
    )
    .first;
Future<void> _tileTap(int index) async {
  final tile = _tile(index);
  await _visible(tile);
  await _tap(tile);
}

List<int> _selection() => [
  for (var i = 0; i < mockInterestOptions.length; i++)
    if ((_tile(i).widget as InterestOptionTile).selected) i,
];
Future<void> _normalize() async {
  for (final index in List<int>.from(_selection())) {
    await _tileTap(index);
  }
}

Future<void> _top() async {
  f.interestPosition(_root)?.jumpTo(0);
  await _settle(2);
}

Element _next() =>
    f.interestKey(_interest, 'interest-next') ??
    f.interestText(_interest, '다음') ??
    f.interestText(_interest, '완료')!;
Map<String, Object?> _snapshot() {
  if (_capture.currentContext == null) {
    return {
      'phase': interestPhase,
      'platform': Platform.operatingSystem,
      'kind': _kind,
      'state': _state,
      'route': 'mounting',
      'ready': false,
      'output': _output.path,
      'active': false,
      'stylePassed': false,
      'layoutPassed': false,
      'assetPassed': false,
      'frameworkErrors': List<String>.from(_errors),
      'initialSelectedIndices': List<int>.from(_initialSelectedIndices),
    };
  }
  final v = View.of(_root),
      m = f.interestMeasure(_root),
      share = isolated.archiveAllShareMessenger;
  return {
    'phase': interestPhase,
    'platform': Platform.operatingSystem,
    'kind': _kind,
    'state': _state,
    'route': _route(),
    'ready': true,
    'output': _output.path,
    'logicalSize': '${v.physicalSize / v.devicePixelRatio}',
    'pixelRatio': v.devicePixelRatio,
    'viewPaddingTop': v.viewPadding.top / v.devicePixelRatio,
    'viewPaddingBottom': v.viewPadding.bottom / v.devicePixelRatio,
    'viewInsetsBottom': v.viewInsets.bottom / v.devicePixelRatio,
    ...m,
    ...f.interestJudgment(m),
    'doneCalls': _doneCalls,
    'initialSelectedIndices': List<int>.from(_initialSelectedIndices),
    'backCalls': _backCalls,
    'frameworkErrors': List<String>.from(_errors),
    'auth': {
      'guestIssuances': _server.guestIssuances,
      'socialIssuances': _server.socialIssuances,
      'sessionWrites': _storage.writes,
      'contentWrites': _server.contentWrites,
      'unexpectedRequests': List<String>.from(_server.unexpected),
      'requests': List<Map<String, Object?>>.from(_server.requests),
    },
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
        'Static actual screen uses pointer-driven tiles. Root guest/new-social flow uses memory API/session; no real OAuth, server generation/persistence of interests, production or physical-device proof.',
  };
}

void _record(
  String name,
  bool passed, [
  Map<String, Object?> extra = const {},
]) {
  final m = f.interestMeasure(_root), j = f.interestJudgment(m);
  _checks.add({
    'scenario': name,
    'passed': passed,
    'route': _route(),
    'state': _state,
    'selectedIndices': m['selectedIndices'],
    'initialSelectedIndices': List<int>.from(_initialSelectedIndices),
    'limitVisible': m['limitMessage'] != null,
    'scrollOffset': m['scrollOffset'],
    'doneCalls': _doneCalls,
    ...(m['active'] == true ? j : const <String, Object?>{}),
    ...extra,
  });
}

Future<Map<String, Object?>> _report() async {
  final s = _snapshot(), share = isolated.archiveAllShareMessenger;
  bool all(String key) =>
      s[key] == true && !_checks.any((c) => c[key] == false);
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
    'stylePassed': all('stylePassed'),
    'layoutPassed': all('layoutPassed') && _errors.isEmpty,
    'assetPassed': all('assetPassed'),
    'behaviorPassed': behavior,
    'passed':
        behavior &&
        all('stylePassed') &&
        all('layoutPassed') &&
        all('assetPassed') &&
        _errors.isEmpty,
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  return result;
}

Future<void> _static() async {
  _kind = 'isolated';
  _doneCalls = 0;
  _backCalls = 0;
  _hasMounted = true;
  runApp(
    RepaintBoundary(
      key: _capture,
      child: MaterialApp(
        key: ValueKey(++_epoch),
        theme: f.interestTheme(),
        home: InterestSelectionScreen(
          onBack: () => _backCalls++,
          onDone: () => _doneCalls++,
        ),
      ),
    ),
  );
  await _settle(3);
  await _wait(
    () => _route() == 'interests',
    'Static interest screen has not mounted',
  );
  _initialSelectedIndices = List<int>.from(_selection());
  await _normalize();
}

Future<void> _scene(String state, {bool capture = true}) async {
  _state = state;
  await _static();
  if (state != 'empty') {
    for (final i in [0, 2, 3]) {
      await _tileTap(i);
    }
  }
  await _top();
  if (state == 'limit') {
    await _tileTap(1);
    await _top();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _settle(1);
  if (capture) {
    final v = View.of(_root);
    _require(v.viewInsets.bottom == 0, 'Scene keyboard must be hidden');
    final image =
        await (_capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: v.devicePixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${_output.path}/interest_${state}_scale_1_scroll_0.png',
      ).writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  }
}

Future<void> _freshRoot() async {
  _kind = 'root';
  _state = 'root';
  if (_hasMounted) {
    runApp(const SizedBox.shrink());
    await _settle(2);
  }
  _hasMounted = true;
  _server = login.LoginServer()..newUser = true;
  _storage = login.LoginMemoryStorage();
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
  await _wait(
    () => _route() == 'login',
    'Actual root login missing after startup',
  );
}

Future<void> _introToInterests() async {
  for (var i = 0; i < 3; i++) {
    final intro = f.interestFind<OnboardingScreen>(_root)!;
    await _tap(f.interestText(intro, i == 2 ? '시작하기' : '다음')!);
    await _settle(8);
  }
  await _wait(
    () => _route() == 'interests',
    'Existing onboarding did not reach interests',
  );
}

Future<void> _rootFlow({required bool social}) async {
  await _freshRoot();
  final screen = f.interestFind<LoginScreen>(_root)!;
  final target = social
      ? f.interestKey(
          screen,
          'login-provider-${_social.supportedProviders.first.name}',
        )!
      : f.interestKey(screen, 'login-guest-hit')!;
  await _visible(target);
  await _tap(target);
  await _wait(
    () => _route() == 'onboarding',
    'Actual authentication did not reach intro',
  );
  await _introToInterests();
  _initialSelectedIndices = List<int>.from(_selection());
  await _normalize();
  _record(
    social ? 'new_social_root_interests_empty' : 'guest_root_interests_empty',
    _selection().isEmpty,
  );
  await _tileTap(0);
  await _top();
  final mutationsBefore = _server.requests
      .where((r) => r['method'] != 'GET')
      .length;
  await _tap(_next());
  await _wait(() => _route() == 'home', 'Actual next did not reach home');
  final categoryMutations = _server.requests
      .where(
        (r) =>
            (r['path'] as String).startsWith('/api/v1/categories') &&
            r['method'] != 'GET',
      )
      .length;
  _record(
    social ? 'new_social_next_existing_home' : 'guest_next_existing_home',
    categoryMutations == 0 &&
        _server.contentWrites == 0 &&
        _server.guestIssuances == (social ? 0 : 1) &&
        _server.socialIssuances == (social ? 1 : 0),
    {
      'categoryMutations': categoryMutations,
      'nonGetBeforeNext': mutationsBefore,
      'sessionWrites': _storage.writes,
    },
  );
}

Future<void> _run() async {
  _checks.clear();
  _done = false;
  await _rootFlow(social: false);
  await _rootFlow(social: true);
  await _scene('empty', capture: false);
  _record('B02_normalized_empty', _selection().isEmpty);
  await _tap(_next());
  _record('empty_next_truly_disabled', _doneCalls == 0);
  await _scene('selected', capture: false);
  _record('B03_selected_0_2_3', _selection().join(',') == '0,2,3');
  final before = f.interestMeasure(_root), buttonBefore = before['next'] as Map;
  await _tileTap(1);
  final limit = f.interestMeasure(_root);
  _record(
    'B04_fourth_rejected_and_alert',
    _selection().join(',') == '0,2,3' && limit['limitMessage'] != null,
    {
      'buttonBefore': buttonBefore,
      'buttonAfter': limit['next'],
      'footerUnchanged': jsonEncode(buttonBefore) == jsonEncode(limit['next']),
    },
  );
  await Future<void>.delayed(const Duration(milliseconds: 1800));
  await _tileTap(1);
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  await _settle(2);
  _record(
    'limit_timer_restarts_on_repeat',
    f.interestMeasure(_root)['limitMessage'] != null,
  );
  await Future<void>.delayed(const Duration(milliseconds: 1700));
  await _settle(2);
  _record(
    'limit_hides_after3seconds',
    f.interestMeasure(_root)['limitMessage'] == null,
  );
  await _tileTap(1);
  await _tileTap(2);
  _record(
    'normal_deselection_hides_limit',
    f.interestMeasure(_root)['limitMessage'] == null &&
        _selection().join(',') == '0,3',
  );
  await _tileTap(1);
  _record(
    'replacement_selection_retains_max3',
    _selection().join(',') == '0,1,3',
  );
  final position = f.interestPosition(_root);
  if (position != null) {
    position.jumpTo(position.maxScrollExtent);
    await _settle(2);
    final m = f.interestMeasure(_root),
        vp = m['viewport'] as Map?,
        tiles = m['tiles'] as List;
    _record(
      'scroll_last_row_accessible',
      vp != null &&
          (tiles.last['bounds']['bottom'] as num) <=
              (vp['bottom'] as num) + .25,
      {'maxScrollExtent': position.maxScrollExtent},
    );
  } else {
    _record('scroll_viewport_present', false);
  }
  await _tap(_next());
  _record('selected_next_once', _doneCalls == 1);
  await _scene('limit', capture: false);
  await _static();
  await Future<void>.delayed(const Duration(milliseconds: 3200));
  await _settle(2);
  _record(
    'dispose_cancels_limit_late_work',
    _errors.isEmpty && f.interestMeasure(_root)['limitMessage'] == null,
  );
  await _scene('selected', capture: false);
  _record('final_B03_selected', _selection().join(',') == '0,2,3');
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp(
    'clipback-interest-alignment-',
  );
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await f.interestInspectFonts();
  await _freshRoot();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'INTEREST_ALIGNMENT ready phase=$interestPhase output=${_output.path}',
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
          final state = request.uri.queryParameters['state'] ?? 'empty';
          _require(
            ['empty', 'selected', 'limit'].contains(state),
            'Unknown scene state',
          );
          await _scene(state);
        case '/run':
          await _run();
        case '/root':
          await _freshRoot();
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
      debugPrint('INTEREST FAIL $e\n$st');
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
