// Actual root application + memory HTTP/session. No production/provider/device
// persistence claim. Native share is isolated by the first installed binding.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../fixtures/navigation_alignment_fixture.dart' as f;
import 'archive_all_preview.dart' as archive;
import 'my_preview.dart' as my;

const navigationPhase = String.fromEnvironment(
  'NAVIGATION_ALIGNMENT_PHASE',
  defaultValue: 'before',
);

class NavigationServer {
  final base = my.MyServer('member');
  final detailRequests = <String>[];
  late final client = MockClient((request) async {
    final match = RegExp(
      r'^/api/v1/contents/(\d+)$',
    ).firstMatch(request.url.path);
    if (request.method == 'GET' && match != null) {
      detailRequests.add(request.url.path);
      final id = int.parse(match[1]!);
      final record = base.records.firstWhere((v) => v['id'] == id);
      return base.json({
        ...record,
        'original_text': '실제 메모리 콘텐츠의 상세 본문을 확인합니다.',
      });
    }
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await base.client.send(forwarded));
  });
}

final _capture = GlobalKey();
NavigationServer _server = NavigationServer();
late Directory _output;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
int _epoch = 0, _pointer = 160000;
bool _busy = false, _done = false;
final _clock = Stopwatch()..start();
Duration _last = Duration.zero;
Duration _time() {
  final next = _clock.elapsed;
  return _last = next > _last ? next : _last + const Duration(microseconds: 1);
}

Element? get _maybeRoot => _capture.currentContext as Element?;
Element get _root => _maybeRoot!;
String _route() {
  if (_maybeRoot == null) return 'mounting';
  if (f.navigationFind<AddContentSheet>(_root) != null) return 'save';
  if (f.navigationFind<DetailScreen>(_root) != null) return 'detail';
  if (f.navigationFind<MyScreen>(_root) != null) return 'my';
  if (f.navigationFind<BookmarkScreen>(_root) != null) return 'bookmark';
  if (f.navigationFind<ArchiveScreen>(_root) != null) return 'archive';
  if (f.navigationFind<HomeScreen>(_root) != null) return 'home';
  return 'other';
}

void _require(bool yes, String reason) {
  if (!yes) throw StateError(reason);
}

Future<void> _settle([int frames = 3]) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 35));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _wait(bool Function() ready, String reason) async {
  for (var i = 0; i < 150; i++) {
    if (ready()) return;
    await _settle(2);
  }
  throw StateError(reason);
}

Future<void> _tapPoint(Offset point) async {
  final pointer = ++_pointer, view = View.of(_root);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: pointer,
      viewId: view.viewId,
      position: point,
      timeStamp: _time(),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 70));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      viewId: view.viewId,
      position: point,
      timeStamp: _time(),
    ),
  );
  await _settle();
}

Future<void> _tap(Element element) =>
    _tapPoint(f.navigationBox(element).center);
Future<void> _drag(Offset from, Offset to) async {
  final pointer = ++_pointer, view = View.of(_root);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: pointer,
      viewId: view.viewId,
      position: from,
      timeStamp: _time(),
    ),
  );
  for (var i = 1; i <= 16; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final point = Offset.lerp(from, to, i / 16)!;
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: pointer,
        viewId: view.viewId,
        position: point,
        delta: (to - from) / 16,
        timeStamp: _time(),
      ),
    );
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      viewId: view.viewId,
      position: to,
      timeStamp: _time(),
    ),
  );
  await _settle(6);
}

Element _screen() => switch (_route()) {
  'home' => f.navigationFind<HomeScreen>(_root)!,
  'archive' => f.navigationFind<ArchiveScreen>(_root)!,
  'bookmark' => f.navigationFind<BookmarkScreen>(_root)!,
  'my' => f.navigationFind<MyScreen>(_root)!,
  'detail' => f.navigationFind<DetailScreen>(_root)!,
  _ => _root,
};
List<ScrollPosition> _positions() => f
    .navigationElements(_screen())
    .whereType<StatefulElement>()
    .where((e) => e.state is ScrollableState)
    .map((e) => (e.state as ScrollableState).position)
    .where((p) => axisDirectionToAxis(p.axisDirection) == Axis.vertical)
    .toList();
Future<void> _tab(String tab) async {
  final index = f.navigationTabs.indexOf(tab);
  _require(index >= 0, 'Unknown tab $tab');
  final bar = f.navigationFind<ClipbackNavigationBar>(_root)!;
  await _tap(f.navigationText(bar, f.navigationLabels[index])!);
  await _wait(() => _route() == tab, 'Actual tab did not open $tab');
  await _settle(4);
}

// runApp schedules replacement for a later frame. The previous root may still
// be Home now, so readiness must identify the newly mounted application before
// accepting its route or data. This also leaves the real 900ms A01 untouched.
bool navigationPreviewHomeReady(Element? root, Key expectedKey) {
  if (root == null) return false;
  final app = f.navigationFind<ClipbackApp>(root);
  if (app?.widget.key != expectedKey) return false;
  final home = f.navigationFind<HomeScreen>(app!);
  if (home == null) return false;
  final screen = home.widget as HomeScreen;
  return screen.feed?.initialized == true &&
      screen.feed?.loading == false &&
      screen.feed?.error == null &&
      screen.contents.length == 6 &&
      screen.categories.isNotEmpty &&
      f.navigationFind<ClipbackNavigationBar>(home) != null;
}

Future<void> _fresh(String tab) async {
  _server = NavigationServer();
  final expectedKey = ValueKey(++_epoch);
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: expectedKey,
        sessionStorage: archive.ArchiveAllMemoryStorage(),
        socialAuth: archive.ArchiveAllSocialAuth(),
      ),
    ),
  );
  await _wait(
    () => navigationPreviewHomeReady(_maybeRoot, expectedKey),
    'Fresh root key/memory session/home data did not initialize',
  );
  await _settle(4);
  if (tab != 'home') await _tab(tab);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _wait(
    () => View.of(_root).viewInsets.bottom == 0,
    'Keyboard did not hide',
  );
  for (final position in _positions()) {
    position.jumpTo(0);
  }
  await _settle(4);
}

Map<String, Object?> _snapshot() {
  final view = View.of(_root), messenger = archive.archiveAllShareMessenger;
  final measure = f.navigationMeasure(_root);
  return {
    'phase': navigationPhase,
    'route': _route(),
    'platform': Platform.operatingSystem,
    'ready': _maybeRoot != null,
    'busy': _busy,
    'output': _output.path,
    'logicalWidth': view.physicalSize.width / view.devicePixelRatio,
    'logicalHeight': view.physicalSize.height / view.devicePixelRatio,
    'pixelRatio': view.devicePixelRatio,
    'viewPaddingTop': view.viewPadding.top / view.devicePixelRatio,
    'viewPaddingBottom': view.viewPadding.bottom / view.devicePixelRatio,
    'viewInsetsBottom': view.viewInsets.bottom / view.devicePixelRatio,
    'scrollPositions': [
      for (final p in _positions())
        {
          'offset': p.pixels,
          'max': p.maxScrollExtent,
          'viewport': p.viewportDimension,
          'isScrolling': p.isScrollingNotifier.value,
          'activity': p.activity?.runtimeType.toString(),
        },
    ],
    'navigation': measure,
    ...f.navigationJudgment(measure),
    'requests': _server.base.requests,
    'detailRequests': _server.detailRequests,
    'unexpectedRequests': _server.base.unexpected,
    'writes': _server.base.writes,
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        messenger,
      ),
      'nativeDelegationCount': messenger?.nativeDelegationCount,
      'unknownMethods': messenger?.unknownShareMethods ?? <String>[],
      'argumentsOrCredentialsRecorded': false,
    },
    'frameworkErrors': List<String>.from(_errors),
    'scope':
        'Actual ClipbackApp, member memory HTTP/session, first-binding share isolation, native OS and synthetic pointers; no production, OAuth or physical-device proof.',
  };
}

void _record(String name, [Map<String, Object?> fields = const {}]) =>
    _checks.add({'scenario': name, 'passed': true, ..._snapshot(), ...fields});
Future<Map<String, Object?>> _report() async {
  final state = _snapshot();
  final style =
      state['stylePassed'] == true &&
      !_checks.any((e) => e['stylePassed'] == false);
  final layout =
      state['layoutPassed'] == true &&
      !_checks.any((e) => e['layoutPassed'] == false) &&
      _errors.isEmpty;
  final asset =
      state['assetPassed'] == true &&
      !_checks.any((e) => e['assetPassed'] == false);
  final messenger = archive.archiveAllShareMessenger;
  final behavior =
      _done &&
      messenger != null &&
      messenger.nativeDelegationCount == 0 &&
      messenger.unknownShareMethods.isEmpty &&
      _server.base.unexpected.isEmpty &&
      _server.base.writes == 0 &&
      !_checks.any(
        (e) =>
            e['passed'] == false ||
            (e['unexpectedRequests'] as List? ?? []).isNotEmpty ||
            e['writes'] != 0,
      );
  final report = {
    ...state,
    'checksCompleted': _done,
    'stylePassed': style,
    'layoutPassed': layout,
    'assetPassed': asset,
    'behaviorPassed': behavior,
    'passed': style && layout && asset && behavior,
    'checks': _checks,
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  return report;
}

Future<void> _captureScene() async {
  final route = _route();
  final image =
      await (_capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: View.of(_root).devicePixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_output.path}/navigation_${route}_scale_1_scroll_0.png',
    ).writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  final snapshot = _snapshot();
  await File(
    '${_output.path}/navigation_${route}_measurement.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot));
  _record('static_$route');
}

// A native fling can outlive a few rendered frames (especially iOS bouncing
// physics). Record the same settled position that the product actually stores,
// not an intermediate point while the user's gesture is still decelerating.
Future<List<Map<String, Object?>>> _waitForStableScroll(
  ScrollPosition position,
) async {
  final samples = <Map<String, Object?>>[];
  double? previousOffset, previousMax, previousViewport;
  var stableFrames = 0;
  for (var i = 0; i < 180; i++) {
    await _settle(1);
    final scrolling = position.isScrollingNotifier.value;
    final offset = position.pixels;
    final max = position.maxScrollExtent;
    final viewport = position.viewportDimension;
    samples.add({
      'offset': offset,
      'max': max,
      'viewport': viewport,
      'isScrolling': scrolling,
      'activity': position.activity?.runtimeType.toString(),
    });
    if (!scrolling &&
        previousOffset != null &&
        (offset - previousOffset).abs() < .001 &&
        (max - previousMax!).abs() < .18 &&
        (viewport - previousViewport!).abs() < .18) {
      stableFrames++;
    } else {
      stableFrames = 0;
    }
    if (stableFrames >= 3) return samples;
    previousOffset = offset;
    previousMax = max;
    previousViewport = viewport;
  }
  throw StateError(
    'Native scroll never reached idle stable painted frames: $samples',
  );
}

Future<void> _run() async {
  _checks.clear();
  _done = false;
  await _fresh('home');
  _record('member_home_initial');
  for (final tab in ['archive', 'bookmark', 'my', 'home']) {
    await _tab(tab);
    _require(
      (f.navigationMeasure(_root)['activeIndex']) ==
          f.navigationTabs.indexOf(tab),
      'Active index did not match route',
    );
    _record('tab_$tab');
  }
  await _tab('archive');
  final positions = _positions();
  final scrolling = positions.where((p) => p.maxScrollExtent > 0).firstOrNull;
  if (scrolling != null) {
    await _waitForStableScroll(scrolling);
    final old = scrolling.pixels;
    final bar = f.navigationBox(
      f.navigationFind<ClipbackNavigationBar>(_root)!,
    );
    final from = Offset(bar.center.dx, bar.top - 80),
        to = Offset(bar.center.dx, bar.top - 350);
    await _drag(from, to);
    final motionSamples = await _waitForStableScroll(scrolling);
    _require(scrolling.pixels > old, 'Actual drag did not scroll archive');
    final before = scrolling.pixels;
    _record('archive_scroll_before_tab_roundtrip', {
      'offsetBefore': before,
      'isScrolling': scrolling.isScrollingNotifier.value,
      'settlementSamples': motionSamples,
    });
    await _tab('my');
    _record('my_during_archive_roundtrip');
    await _tab('archive');
    final restored = _positions().where((p) => p.maxScrollExtent > 0).first;
    final restoreSamples = await _waitForStableScroll(restored);
    _require(
      (restored.pixels - before).abs() < .18,
      'Existing archive scroll not restored by root',
    );
    _record('archive_scroll_after_tab_roundtrip', {
      'offsetBefore': before,
      'offsetAfter': restored.pixels,
      'isScrolling': restored.isScrollingNotifier.value,
      'settlementSamples': restoreSamples,
    });
    restored.jumpTo(0);
    await _settle(4);
  } else {
    _record('archive_no_scroll', {
      'reason': 'Actual viewport fits data; no scroll movement claimed',
    });
  }
  final card = f.navigationFind<ContentListCard>(_screen())!;
  // Tap title near the card center rather than its bookmark/more controls.
  final bounds = f.navigationBox(card);
  await _tapPoint(Offset(bounds.left + bounds.width / 2, bounds.top + 65));
  await _wait(() => _route() == 'detail', 'Content row did not open detail');
  _require(
    f.navigationMeasure(_root)['activeIndex'] == 1,
    'Detail lost archive active index',
  );
  _record('detail_archive_active');
  await _tap(f.navigationKey(_root, 'detail-back')!);
  await _wait(
    () => _route() == 'archive',
    'Detail back did not return archive',
  );
  _record('detail_return_archive');
  final writes = _server.base.writes;
  await _tap(f.navigationFind<NavAddButton>(_root)!);
  await _wait(() {
    final sheet = f.navigationFind<AddContentSheet>(_root);
    return sheet != null &&
        ModalRoute.of(sheet)?.animation?.status == AnimationStatus.completed;
  }, 'Save modal did not finish entering');
  // The covered navigation remains the archive bar and is still measured.
  _record('save_opened');
  final top = f.navigationFind<SaveContentTopBar>(_root)!;
  await _tap(f.navigationFind<SvgIconButton>(top)!);
  await _wait(
    () =>
        f.navigationFind<AddContentSheet>(_root) == null &&
        _route() == 'archive',
    'Save close did not finish',
  );
  _require(
    _server.base.writes == writes,
    'Save-close unexpectedly submitted content',
  );
  _record('save_closed_without_write');
  await _tab('home');
  for (final position in _positions()) {
    position.jumpTo(0);
  }
  await _settle(4);
  _record('final_home_scroll_zero');
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  archive.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-navigation-');
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add(details.exceptionAsString());
    old?.call(details);
  };
  await _fresh('home');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('NAVIGATION ready phase=$navigationPhase output=${_output.path}');
  await for (final request in server) {
    final read = ['/ready', '/state', '/status'].contains(request.uri.path);
    if (_busy && !read) {
      request.response.statusCode = 409;
      await request.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (request.uri.path) {
        case '/ready':
        case '/state':
        case '/status':
          break;
        case '/scene':
          final tab = request.uri.queryParameters['tab'] ?? 'home';
          _require(
            f.navigationTabs.contains(tab),
            'Only home/archive/bookmark/my supported',
          );
          await _fresh(tab);
          await _captureScene();
        case '/run':
          await _run();
        default:
          request.response.statusCode = 404;
      }
      final report = await _report();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(report));
    } catch (error, stack) {
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$error',
      });
      debugPrint('NAVIGATION FAIL $error\n$stack');
      request.response.statusCode = 500;
      request.response.write(
        jsonEncode({'error': '$error', ...await _report()}),
      );
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
