// C01/C02 actual-root memory fixture. Production HTTP, OAuth, and retained
// native share state are isolated before the first bootstrap.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/notification_sheet.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../fixtures/home_base_alignment_fixture.dart' as f;
import '../fixtures/logout_alignment_fixture.dart' as common;
import 'archive_all_preview.dart' as isolated;

const homeBasePhase = String.fromEnvironment(
  'HOME_BASE_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
f.HomeBaseServer _server = f.HomeBaseServer('normal');
final _sessions = <f.HomeBaseServer>[],
    _errors = <String>[],
    _checks = <Map<String, Object?>>[];
late Directory _output;
Map<String, Object?> _fonts = {};
String _kind = 'normal';
bool _busy = false, _done = false, _coverage = false;
int _epoch = 0, _pointer = 52000;
Element get _root => _capture.currentContext! as Element;
Element get _home => f.homeBaseFind<HomeScreen>(_root)!;
String _route() {
  if (_capture.currentContext == null) return 'mounting';
  if (f.homeBaseFind<SaveContentTopBar>(_root) != null) return 'save';
  if (f.homeBaseFind<NotificationSheet>(_root) != null ||
      f
          .homeBaseElements(_root)
          .any(
            (e) => e.widget.runtimeType.toString() == 'NotificationListScreen',
          )) {
    return 'notifications';
  }
  if (f.homeBaseFind<SearchScreen>(_root) != null) return 'search';
  if (f.homeBaseFind<DetailScreen>(_root) != null) return 'detail';
  if (f.homeBaseFind<ArchiveScreen>(_root) != null) return 'archive';
  if (f.homeBaseFind<HomeScreen>(_root) != null) return 'home';
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

Future<void> _point(Offset point) async {
  final id = ++_pointer, v = View.of(_root);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: v.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 60));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: v.viewId, position: point),
  );
  await _settle(2);
}

Future<void> _tap(Element e) => _point(f.homeBaseBox(e).center);
Future<void> _show(Element e) async {
  await Scrollable.ensureVisible(
    e,
    duration: const Duration(milliseconds: 130),
    alignment: .5,
  );
  await _settle(3);
}

Future<void> _drag(Element e, Offset delta) async {
  final v = View.of(_root), start = f.homeBaseBox(e).center, id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: v.viewId, position: start),
  );
  for (var i = 1; i <= 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 35));
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: id,
        viewId: v.viewId,
        position: start + delta * (i / 10),
        delta: delta / 10,
      ),
    );
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: v.viewId, position: start + delta),
  );
  await _settle(8);
}

Future<void> _hideKeyboard() async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _wait(
    () => View.of(_root).viewInsets.bottom == 0,
    'Keyboard hide failed',
  );
}

Future<void> _fresh(String kind) async {
  _kind = kind;
  _server = f.HomeBaseServer(kind);
  _sessions.add(_server);
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: ValueKey(++_epoch),
        sessionStorage: isolated.ArchiveAllMemoryStorage(),
        socialAuth: isolated.ArchiveAllSocialAuth(),
      ),
    ),
  );
  await _settle(2);
  await _wait(
    () =>
        _route() == 'home' &&
        (_home.widget as HomeScreen).feed?.initialized == true &&
        (_home.widget as HomeScreen).feed?.loading == false &&
        (kind == 'empty'
            ? (_home.widget as HomeScreen).contents.isEmpty
            : (_home.widget as HomeScreen).contents.length == 4),
    'Memory home load failed',
  );
  await _hideKeyboard();
  f.homeBasePosition(_root)?.jumpTo(0);
  f.homeBasePosition(_root, recent: true)?.jumpTo(0);
  await _settle(3);
}

Map<String, Object?> _snapshot() {
  if (_capture.currentContext == null) {
    return {
      'ready': false,
      'route': 'mounting',
      'phase': homeBasePhase,
      'platform': Platform.operatingSystem,
    };
  }
  final m = f.homeBaseMeasure(_root),
      v = View.of(_root),
      messenger = isolated.archiveAllShareMessenger;
  return {
    'ready': true,
    'phase': homeBasePhase,
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
    ...f.homeBaseJudgment(m),
    'fontBundle': _fonts,
    'requests': List<Map<String, Object?>>.from(_server.requests),
    'unexpectedRequests': List<String>.from(_server.unexpected),
    'writeRequests': _server.writeCalls,
    'bookmarkRequests': _server.bookmarkCalls,
    'feedRequests': _server.feedCalls,
    'viewRequests': _server.viewCalls,
    'serverRecordCount': _server.records.length,
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
        'Actual root app, memory API/session, real native window and pointer input. No live provider, production server, physical device, or remote CI proof.',
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
          !_checks.any((c) => c['stylePassed'] == false),
      layout =
          s['layoutPassed'] == true &&
          _errors.isEmpty &&
          !_checks.any((c) => c['layoutPassed'] == false),
      asset =
          s['assetPassed'] == true &&
          !_checks.any((c) => c['assetPassed'] == false),
      behavior =
          _done &&
          messenger != null &&
          messenger.nativeDelegationCount == 0 &&
          messenger.unknownShareMethods.isEmpty &&
          !_sessions.any((s) => s.unexpected.isNotEmpty || s.writeCalls != 0) &&
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
            'bookmarkRequests': s.bookmarkCalls,
            'feedRequests': s.feedCalls,
            'viewRequests': s.viewCalls,
            'unexpectedRequests': s.unexpected,
            'writeRequests': s.writeCalls,
            'recordIds': s.records.map((v) => v['id']).toList(),
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
      '${_output.path}/home_${_kind}_scale_1_scroll_0.png',
    ).writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  await File(
    '${_output.path}/home_${_kind}_state.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(_snapshot()));
}

Future<void> _homeTab() async {
  await _tap(
    f.homeBaseText(f.homeBaseFind<ClipbackNavigationBar>(_root)!, '홈')!,
  );
  await _wait(() => _route() == 'home', 'Home tab missing');
  await _settle(3);
}

Element _closestCard() {
  final rail = f.homeBaseBox(f.homeBaseRecentRail(_root)!);
  final cards =
      f
          .homeBaseElements(_home)
          .where((e) => e.widget is HomeContentCard)
          .toList()
        ..sort(
          (a, b) => (f.homeBaseBox(a).center.dx - rail.center.dx)
              .abs()
              .compareTo((f.homeBaseBox(b).center.dx - rail.center.dx).abs()),
        );
  return cards.first;
}

Future<void> _closeSave() async {
  await _tap(
    f.homeBaseFind<SvgIconButton>(f.homeBaseFind<SaveContentTopBar>(_root)!)!,
  );
  await _wait(() => _route() == 'home', 'Save close missing');
}

Future<void> _maxScroll() async {
  final p = f.homeBasePosition(_root)!;
  final viewport = f.homeBaseFind<SingleChildScrollView>(_home)!;
  await _drag(viewport, const Offset(0, -360));
  p.jumpTo(p.maxScrollExtent);
  await _settle(3);
  final m = f.homeBaseMeasure(_root), vp = (m['bounds'] as Map)['body'] as Map;
  final marker = _kind == 'empty'
      ? f
            .homeBaseElements(_home)
            .where((e) => e.widget is CategoryHomeRow)
            .lastOrNull
      : f.homeBaseFind<PageDots>(_home);
  if (marker != null) {
    _require(
      f.homeBaseBox(marker).bottom <= (vp['bottom'] as num) + .18,
      'Last home block not reachable',
    );
  }
  _record('${_kind}_maximum_scroll', {
    'maximum': p.maxScrollExtent,
    'noScroll': p.maxScrollExtent == 0,
    'lastBlockVisible': marker != null,
  });
}

// This preexisting defect is deliberately separate from the uninterrupted
// pending/failure rail test: a disabled child star passes its tap to the card.
// Observe the detail navigation and return reset without calling them a lock
// or scroll-preservation success. Product behavior is outside this commit.
Future<void> _existingPendingParentTap() async {
  await _fresh('normal');
  await _show(f.homeBaseRecentRail(_root)!);
  await _drag(f.homeBaseRecentRail(_root)!, const Offset(-290, 0));
  final before = f.homeBasePosition(_root, recent: true)!.pixels;
  final card = _closestCard(),
      id = (card.widget as HomeContentCard).content.apiId!;
  _server.bookmarkGate = Completer<bool>();
  await _tap(f.homeBaseFind<BookmarkActionButton>(card)!);
  await _wait(
    () =>
        _server.bookmarkCalls == 1 &&
        (_home.widget as HomeScreen).contents.any(
          (v) => v.apiId == id && v.mutationLabel != null,
        ),
    'Separate pending parent-tap setup failed',
  );
  await _tap(f.homeBaseFind<BookmarkActionButton>(_closestCard())!);
  await _settle(3);
  final observedRoute = _route(), openedDetail = observedRoute == 'detail';
  _require(
    observedRoute == 'detail' || observedRoute == 'home',
    'Unexpected pending-star destination',
  );
  _require(
    _server.bookmarkCalls == 1,
    'Disabled duplicate star sent extra API',
  );
  _record('pending_disabled_star_api_lock_and_route_observation', {
    'knownExistingIssue': openedDetail,
    'targetId': id,
    'requestsRemainOne': true,
    'observedRoute': observedRoute,
    'parentDetailOpened': openedDetail,
    'navigationLockPassed': !openedDetail,
    'offsetBeforeParentNavigation': before,
  });
  if (openedDetail) {
    await _tap(common.logoutKey(_root, 'detail-back')!);
    await _wait(
      () => _route() == 'home',
      'Pending parent detail return failed',
    );
  }
  final after = f.homeBasePosition(_root, recent: true)!.pixels;
  _record('pending_star_followup_rail_observation', {
    'knownExistingIssue': openedDetail,
    'offsetBeforeParentNavigation': before,
    'offsetAfterObservedReturn': after,
    'railPreservedAcrossObservedRoute': (after - before).abs() < .18,
    'detailReturnWasRequired': openedDetail,
  });
  _server.bookmarkGate!.complete(false);
  await _wait(
    () => (_home.widget as HomeScreen).contents.every(
      (v) => v.mutationLabel == null,
    ),
    'Separate parent-tap cleanup failed',
  );
  ScaffoldMessenger.of(_home).hideCurrentSnackBar();
  await _settle(7);
}

Future<void> _run() async {
  _checks.clear();
  _sessions.clear();
  _done = false;
  _coverage = false;
  await _fresh('normal');
  _record('normal_static_scroll_zero');
  var icons = f
      .homeBaseElements(f.homeBaseFind<HomeHero>(_home)!)
      .where((e) => e.widget is SvgIconButton)
      .toList();
  await _tap(icons.first);
  await _wait(() => _route() == 'search', 'Search entry missing');
  _record('search_entry');
  await _tap(f.homeBaseText(_root, '취소')!);
  await _wait(() => _route() == 'home', 'Search cancel missing');
  await _hideKeyboard();
  _record('search_cancel');
  icons = f
      .homeBaseElements(f.homeBaseFind<HomeHero>(_home)!)
      .where((e) => e.widget is SvgIconButton)
      .toList();
  await _tap(icons.last);
  await _wait(() => _route() == 'notifications', 'Notification entry missing');
  _record('notification_entry_and_existing_home_behavior');
  await WidgetsBinding.instance.handlePopRoute();
  await _settle(6);
  _require(_route() == 'home', 'Notification close missing');
  await _tap(f.homeBaseText(_home, '오늘의 콘텐츠 보기 →')!);
  await _wait(() => _route() == 'detail', 'Today detail entry missing');
  _require(_server.viewCalls > 0, 'Today did not retain view tracking');
  _record('today_existing_detail_destination');
  await _tap(common.logoutKey(_root, 'detail-back')!);
  await _wait(() => _route() == 'home', 'Detail return missing');
  await _show(f.homeBaseText(_home, '이번주 허투루 픽 🎯')!);
  await _tap(f.homeBaseText(_home, '이번주 허투루 픽 🎯')!);
  await _wait(() => _route() == 'archive', 'Weekly title destination missing');
  _require(
    (f.homeBaseFind<ArchiveScreen>(_root)!.widget as ArchiveScreen).activeTab ==
        1,
    'Weekly title must retain category destination',
  );
  _record('weekly_title_category_destination');
  await _homeTab();
  final weekly = f.homeBaseFind<WeeklyPickRail>(_home)!;
  await _show(weekly);
  final pick = f.homeBaseFind<InkWell>(weekly)!;
  await _tap(pick);
  await _wait(() => _route() == 'archive', 'Weekly card destination missing');
  _require(
    (f.homeBaseFind<ArchiveScreen>(_root)!.widget as ArchiveScreen).activeTab ==
        1,
    'Weekly card category contract changed',
  );
  _record('weekly_card_category_destination');
  await _homeTab();
  await _show(f.homeBaseText(_home, '최근 저장한 콘텐츠')!);
  await _tap(f.homeBaseText(_home, '최근 저장한 콘텐츠')!);
  await _wait(
    () => _route() == 'archive',
    'Recent title archive entry missing',
  );
  _require(
    (f.homeBaseFind<ArchiveScreen>(_root)!.widget as ArchiveScreen).activeTab ==
        0,
    'Recent title must retain all archive',
  );
  _record('recent_title_all_archive');
  await _homeTab();
  await _show(f.homeBaseRecentRail(_root)!);
  await _drag(f.homeBaseRecentRail(_root)!, const Offset(-290, 0));
  final before = f.homeBaseMeasure(_root);
  _require(
    (before['recentOffset'] as num) > 100 &&
        (before['dots'] as Map)['activeIndex'] > 0,
    'Recent drag/dot did not advance',
  );
  _record('recent_rail_and_dot_move');
  final card = _closestCard(),
      cw = card.widget as HomeContentCard,
      target = cw.content.apiId!;
  final oldFavorite = _server.records.firstWhere(
    (v) => v['id'] == target,
  )['is_favorite'];
  final offset = f.homeBasePosition(_root, recent: true)!.pixels,
      feedBefore = _server.feedCalls;
  _server.bookmarkGate = Completer<bool>();
  await _tap(f.homeBaseFind<BookmarkActionButton>(card)!);
  await _wait(
    () =>
        _server.bookmarkCalls == 1 &&
        (_home.widget as HomeScreen).contents.any(
          (v) => v.apiId == target && v.mutationLabel != null,
        ),
    'Bookmark pending missing',
  );
  _require(
    (f.homeBasePosition(_root, recent: true)!.pixels - offset).abs() < .18,
    'Pending moved rail',
  );
  _record('bookmark_pending_position_preserved', {'targetId': target});
  _server.bookmarkGate!.complete(false);
  await _wait(
    () => (_home.widget as HomeScreen).contents.every(
      (v) => v.mutationLabel == null,
    ),
    'Bookmark failure did not release lock',
  );
  _require(
    _server.records.firstWhere((v) => v['id'] == target)['is_favorite'] ==
            oldFavorite &&
        (f.homeBasePosition(_root, recent: true)!.pixels - offset).abs() <
            .18 &&
        _server.feedCalls == feedBefore,
    'Failure changed data, position, or refetched',
  );
  _record('bookmark_failure_preserved_manual_retry');
  ScaffoldMessenger.of(_home).hideCurrentSnackBar();
  await _settle(7);
  _server.bookmarkGate = null;
  await _tap(f.homeBaseFind<BookmarkActionButton>(_closestCard())!);
  await _wait(
    () =>
        _server.bookmarkCalls == 2 &&
        _server.feedCalls > feedBefore &&
        (_home.widget as HomeScreen).feed?.loading == false &&
        (_home.widget as HomeScreen).contents.every(
          (v) => v.mutationLabel == null,
        ),
    'Bookmark successful retry/refetch missing',
  );
  _require(
    _server.records.firstWhere((v) => v['id'] == target)['is_favorite'] !=
        oldFavorite,
    'Successful retry missing actual change',
  );
  await _settle(4);
  _require(
    f.homeBasePosition(_root, recent: true)!.pixels.abs() < .18 &&
        (f.homeBaseMeasure(_root)['dots'] as Map)['activeIndex'] == 0,
    'Successful refresh did not retain reset policy',
  );
  _record('bookmark_retry_refetch_reset');
  await _show(f.homeBaseRecentRail(_root)!);
  await _drag(f.homeBaseRecentRail(_root)!, const Offset(-290, 0));
  final chips = f.homeBaseFind<CategoryChips>(_home)!;
  await _show(chips);
  await _tap(f.homeBaseText(chips, '일상')!);
  await _wait(
    () =>
        (_home.widget as HomeScreen).activeCategoryId == 101 &&
        (_home.widget as HomeScreen).feed?.loading == false,
    'Home category filter missing',
  );
  // Measure the settled 180ms dot animation, after the feed has completed.
  await _settle(6);
  _require(
    f.homeBasePosition(_root, recent: true)!.pixels.abs() < .18 &&
        (f.homeBaseMeasure(_root)['dots'] as Map)['activeIndex'] == 0,
    'Category did not reset rail',
  );
  _record('category_filter_reset');
  await _tap(f.homeBaseText(f.homeBaseFind<CategoryChips>(_home)!, '전체보기')!);
  await _wait(
    () =>
        (_home.widget as HomeScreen).activeCategoryId == null &&
        (_home.widget as HomeScreen).contents.length == 4,
    'Category reset missing',
  );
  await _show(f.homeBaseRecentRail(_root)!);
  final content = _closestCard();
  await _tap(content);
  await _wait(() => _route() == 'detail', 'Recent card detail missing');
  _record('recent_card_detail');
  await _tap(common.logoutKey(_root, 'detail-back')!);
  await _wait(() => _route() == 'home', 'Recent detail return missing');
  await _maxScroll();
  await _existingPendingParentTap();
  await _fresh('empty');
  _require(
    (f.homeBaseFind<HomeHero>(_home)!.widget as HomeHero).confirmedEmpty,
    'Strict C02 not selected',
  );
  _record('empty_static_strict_global_feed');
  await _tap(f.homeBaseText(_home, '첫 콘텐츠 저장하기')!);
  await _wait(() => _route() == 'save', 'Empty save entry missing');
  _record('empty_existing_save_entry');
  await _closeSave();
  _require(_server.writeCalls == 0, 'Close created content');
  _record('empty_save_close_no_write');
  await _maxScroll();
  final recentCategory = f
      .homeBaseElements(_home)
      .where((e) => e.widget is CategoryHomeRow)
      .first;
  await _show(recentCategory);
  await _tap(recentCategory);
  await _wait(
    () => _route() == 'archive',
    'Empty recent category destination missing',
  );
  _require(
    (f.homeBaseFind<ArchiveScreen>(_root)!.widget as ArchiveScreen).activeTab ==
        1,
    'Existing recent category contract changed',
  );
  _record('empty_recent_category_existing_category_list');
  await _fresh('normal');
  _record('final_normal_scroll_zero');
  _coverage = true;
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-home-base-');
  _fonts = await f.homeBaseLoadFonts();
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _fresh('normal');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('HOME_BASE ready phase=$homeBasePhase output=${_output.path}');
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
          final kind = request.uri.queryParameters['kind'] ?? 'normal';
          _require(
            ['normal', 'empty'].contains(kind),
            'kind normal|empty required',
          );
          await _fresh(kind);
          await _captureScene();
        case '/max-scroll':
          final kind = request.uri.queryParameters['kind'] ?? 'normal';
          await _fresh(kind);
          await _maxScroll();
        case '/run':
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
      debugPrint('HOME_BASE FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
