// C03: actual root app and memory session/API, native sharing isolated before
// bootstrap. Same frozen source runs the old Home modal and the new notification route.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/notification_sheet.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/share/pending_share_prompt.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:http/http.dart' as http;
import '../fixtures/notification_alignment_fixture.dart' as f;
import 'archive_all_preview.dart' as isolated;

const notificationPhase = String.fromEnvironment(
  'NOTIFICATION_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
f.NotificationServer _server = f.NotificationServer('member');
f.NotificationMemoryStorage _storage = f.NotificationMemoryStorage();
f.NotificationSocial _social = f.NotificationSocial();
final _sessions = <f.NotificationServer>[],
    _checks = <Map<String, Object?>>[],
    _errors = <String>[];
late Directory _output;
Map<String, Object?> _fonts = {};
String _kind = 'list';
bool _busy = false, _done = false, _coverage = false;
int _epoch = 0, _pointer = 68000;
double _openingHomeOffset = 0, _openingRecentOffset = 0;
String _sessionKind = 'member';
Widget Function(VoidCallback onBack, VoidCallback onOpenSettings)?
_emptyBuilder;
bool _emptyScene = false;
Element get _root => _capture.currentContext! as Element;
Element get _home => f.notificationFind<HomeScreen>(_root)!;
Element get _notification =>
    f.notificationScreen(_root) ??
    f.notificationFind<NotificationSheet>(_root)!;
PendingSharePrompt? _sharePrompt() =>
    f.notificationFind<PendingSharePrompt>(_root)?.widget
        as PendingSharePrompt?;
void _requireShareUnblocked() {
  final prompt = _sharePrompt();
  _require(
    prompt != null &&
        !prompt.busy &&
        prompt.error == null &&
        prompt.drafts.isEmpty,
    'Unexpected native share recovery prompt blocks the evidence scene',
  );
}

String _route() {
  if (_capture.currentContext == null) return 'mounting';
  if (f.notificationFind<SaveContentTopBar>(_root) != null) return 'save';
  if (f.notificationFind<ReminderSheet>(_root) != null) return 'reminderSheet';
  if (f.notificationScreen(_root) != null) return 'notificationList';
  if (f.notificationFind<NotificationSheet>(_root) != null) {
    return 'notificationSheet';
  }
  if (f.notificationFind<PermissionSheet>(_root) != null) {
    return 'permissionSheet';
  }
  if (f.notificationFind<ContactSheet>(_root) != null) return 'contactSheet';
  if (f.notificationFind<AppVersionSheet>(_root) != null) return 'versionSheet';
  if (f.notificationFind<AccountManagementScreen>(_root) != null) {
    return 'account';
  }
  if (f.notificationFind<CategoryManagementScreen>(_root) != null) {
    return 'categoryManagement';
  }
  if (f.notificationFind<MyScreen>(_root) != null) return 'my';
  if (f.notificationFind<ArchiveScreen>(_root) != null) return 'archive';
  if (f.notificationFind<BookmarkScreen>(_root) != null) return 'bookmark';
  if (f.notificationFind<HomeScreen>(_root) != null) return 'home';
  if (f.notificationFind<LoginScreen>(_root) != null) return 'login';
  return 'other';
}

void _require(bool yes, String why) {
  if (!yes) throw StateError(why);
}

Future<void> _settle([int n = 4]) async {
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
  final point = f.notificationBox(e).center,
      id = ++_pointer,
      v = View.of(_root);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: v.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 60));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: v.viewId, position: point),
  );
  await _settle(3);
}

Future<void> _show(Element e) async {
  await Scrollable.ensureVisible(
    e,
    duration: const Duration(milliseconds: 160),
    alignment: .5,
  );
  await _settle(5);
}

Future<void> _hideKeyboard() async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _wait(
    () => View.of(_root).viewInsets.bottom == 0,
    'Keyboard did not hide',
  );
}

Future<void> _open() async {
  final hero = f.notificationFind<HomeHero>(_home)!;
  final bell = f
      .notificationElements(hero)
      .where(
        (e) =>
            e.widget is SvgIconButton &&
            (e.widget as SvgIconButton).asset == Assets.bell,
      )
      .first;
  final bellBounds = f.notificationBox(bell), view = View.of(_root);
  if (bellBounds.top < view.viewPadding.top / view.devicePixelRatio ||
      bellBounds.bottom >
          (view.physicalSize.height - view.viewPadding.bottom) /
              view.devicePixelRatio) {
    await _show(bell);
  }
  _openingHomeOffset = f.notificationHomePosition(_root)?.pixels ?? 0;
  _openingRecentOffset =
      f.notificationHomePosition(_root, recent: true)?.pixels ?? 0;
  await _tap(bell);
  await _wait(
    () => ['notificationList', 'notificationSheet'].contains(_route()),
    'Actual notification entry missing',
  );
  await _settle(8);
  f.notificationPosition(_root)?.jumpTo(0);
  await _settle(3);
}

Future<void> _close({bool header = false}) async {
  if (header && f.notificationScreen(_root) != null) {
    await _tap(f.notificationKey(_notification, 'notification-back-hit')!);
  } else {
    await WidgetsBinding.instance.handlePopRoute();
  }
  await _wait(
    () => _route() == 'home',
    'Notification back did not return Home',
  );
  _emptyScene = false;
  _kind = 'list';
  await _settle(5);
}

Future<void> _fresh(String sessionKind, {bool open = true}) async {
  _kind = 'list';
  _sessionKind = sessionKind;
  _emptyScene = false;
  _server = f.NotificationServer(sessionKind);
  _sessions.add(_server);
  _storage = f.NotificationMemoryStorage();
  _social = f.NotificationSocial();
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
  await _wait(() => _route() == 'home', 'Memory Home startup missing');
  await _wait(
    () =>
        (f.notificationFind<HomeScreen>(_root)!.widget as HomeScreen)
            .feed
            ?.initialized ==
        true,
    'Actual root Home feed missing',
  );
  await _hideKeyboard();
  if (open) await _open();
  await _wait(
    () => _sharePrompt()?.busy == false,
    'Native share preparation did not settle',
  );
  _requireShareUnblocked();
}

Future<void> _openEmpty() async {
  _require(
    _emptyBuilder != null,
    'No empty screen existed in baseline; only AFTER adapter supplies explicit []',
  );
  if (_route() != 'home') await _fresh('member', open: false);
  final navigator = f.notificationFind<Navigator>(_root)! as StatefulElement,
      state = navigator.state as NavigatorState;
  _kind = 'empty';
  _emptyScene = true;
  unawaited(
    state.push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _emptyBuilder!(
          () => Navigator.of(context).pop(),
          () => showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const ReminderSheet(),
          ),
        ),
      ),
    ),
  );
  await _wait(
    () => f.notificationScreen(_root) != null,
    'Explicit [] NotificationListScreen missing',
  );
  await _settle(8);
}

Map<String, Object?> _snapshot() {
  if (_capture.currentContext == null) {
    return {
      'ready': false,
      'route': 'mounting',
      'phase': notificationPhase,
      'platform': Platform.operatingSystem,
    };
  }
  final m = f.notificationMeasure(_root),
      v = View.of(_root),
      messenger = isolated.archiveAllShareMessenger;
  return {
    'ready': true,
    'phase': notificationPhase,
    'kind': _kind,
    'sessionKind': _sessionKind,
    'sceneSource': _emptyScene
        ? 'explicit_empty_widget_not_root_api'
        : 'actual_root_original_three_examples',
    'emptySceneSupported': _emptyBuilder != null,
    'emptyBeforeUnavailable': notificationPhase == 'before',
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
    'scrollOffset': 0.0,
    ...m,
    ...f.notificationJudgment(m),
    'homeScrollOffset': f.notificationHomePosition(_root)?.pixels,
    'recentScrollOffset': f
        .notificationHomePosition(_root, recent: true)
        ?.pixels,
    'activeRecentDot':
        (f.notificationFind<PageDots>(_root)?.widget as PageDots?)?.activeIndex,
    'openingHomeOffset': _openingHomeOffset,
    'openingRecentOffset': _openingRecentOffset,
    'fontBundle': _fonts,
    'requests': List<Map<String, Object?>>.from(_server.requests),
    'unexpectedRequests': List<String>.from(_server.unexpected),
    'writeRequests': _server.writes,
    'logoutRequests': _server.logoutCalls,
    'serverRecordCount': _server.records.length,
    'sessionPresent': _storage.value != null,
    'sharePromptMounted': _sharePrompt() != null,
    'sharePromptError': _sharePrompt()?.error,
    'sharePromptBlocked':
        _sharePrompt() == null ||
        _sharePrompt()!.error != null ||
        _sharePrompt()!.drafts.isNotEmpty,
    'sharePromptDraftCount': _sharePrompt()?.drafts.length,
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
        'Actual root app and pointer input on native OS; memory API/session only. No live provider, production server, physical device, or remote CI proof.',
  };
}

void _record(String scenario, [Map<String, Object?> values = const {}]) {
  _requireShareUnblocked();
  _checks.add({
    'scenario': scenario,
    'passed': true,
    ..._snapshot(),
    ...values,
  });
}

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
          s['sharePromptBlocked'] == false &&
          !_checks.any((c) => c['sharePromptBlocked'] != false) &&
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
            'writeRequests': s.writes,
            'logoutRequests': s.logoutCalls,
            'unexpectedRequests': s.unexpected,
            'serverRecordCount': s.records.length,
          },
      ],
    }),
  );
}

Future<void> _captureScene() async {
  _requireShareUnblocked();
  await _settle(2);
  final image =
      await (_capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: View.of(_root).devicePixelRatio);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_output.path}/notification_${_kind}_${_sessionKind}_scale_1_scroll_0.png',
    ).writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  await File(
    '${_output.path}/notification_${_kind}_${_sessionKind}_state.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(_snapshot()));
}

Future<void> _maxScroll() async {
  final p = f.notificationPosition(_root)!;
  p.jumpTo(p.maxScrollExtent);
  await _settle(5);
  final measure = f.notificationMeasure(_root),
      bounds = measure['bounds'] as Map,
      viewport = bounds['viewport'] as Map;
  final last = _emptyScene
      ? f.notificationKey(_notification, 'notification-empty-body')!
      : f.notificationText(_notification, f.notificationExamples.last.title)!;
  _require(
    f.notificationBox(last).bottom <= (viewport['bottom'] as num) + .22,
    'Last notification content not visible',
  );
  _record('maximum_scroll', {
    'maximum': p.maxScrollExtent,
    'noScroll': p.maxScrollExtent == 0,
    'lastItemVisible': true,
  });
}

Future<void> _settings() async {
  final requests = _server.requests.length;
  if (f.notificationScreen(_root) == null) return;
  await _tap(f.notificationKey(_notification, 'notification-settings-hit')!);
  await _wait(
    () => _route() == 'reminderSheet',
    'Existing ReminderSheet missing',
  );
  await _settle(8);
  _record('existing_reminder_settings_open');
  await WidgetsBinding.instance.handlePopRoute();
  await _wait(
    () => _route() == 'notificationList',
    'Settings dismiss did not retain list',
  );
  await _settle(8);
  _require(
    _server.requests.length == requests,
    'Settings open/dismiss unexpectedly requested HTTP',
  );
  _record('existing_reminder_settings_close_no_requests');
}

Future<void> _run() async {
  _checks.clear();
  _sessions.clear();
  _done = false;
  _coverage = false;
  for (final kind in ['member', 'guest']) {
    await _fresh(kind);
    _record('${kind}_original_three_examples_entry');
    final count = _server.requests.length, records = _server.records.length;
    for (final item in f.notificationExamples) {
      final e = f.notificationText(_notification, item.title)!;
      await _show(e);
      await _tap(e);
      _require(
        ['notificationList', 'notificationSheet'].contains(_route()),
        'Readonly row opened a destination',
      );
    }
    _require(
      _server.requests.length == count &&
          _server.records.length == records &&
          _server.writes == 0,
      'Readonly notifications changed HTTP/content',
    );
    _record('${kind}_readonly_no_requests');
    await _maxScroll();
    await _settings();
    final offset = _openingHomeOffset, recent = _openingRecentOffset;
    await _close(header: true);
    _require(
      (f.notificationHomePosition(_root)!.pixels - offset).abs() < .22,
      'Notification header back lost Home offset',
    );
    _require(
      (f.notificationHomePosition(_root, recent: true)!.pixels - recent).abs() <
          .22,
      'Notification header back lost recent rail offset',
    );
    _record('${kind}_header_or_legacy_modal_home_return');
    await _open();
    await _close();
    _record('${kind}_os_back_home_return');
  }
  await _fresh('member', open: false);
  final recent = f.notificationHomePosition(_root, recent: true)!;
  recent.jumpTo(recent.maxScrollExtent.clamp(0, 320));
  final vertical = f.notificationHomePosition(_root)!;
  vertical.jumpTo(vertical.maxScrollExtent.clamp(0, 16));
  await _settle(5);
  final horizontal = recent.pixels,
      homeOffset = vertical.pixels,
      dot =
          (f.notificationFind<PageDots>(_root)!.widget as PageDots).activeIndex;
  await _open();
  await _close(header: true);
  _require(
    (f.notificationHomePosition(_root, recent: true)!.pixels - horizontal)
            .abs() <
        .22,
    'Recent card position reset across notifications',
  );
  _require(
    (f.notificationHomePosition(_root)!.pixels - homeOffset).abs() < .22,
    'Nonzero Home offset reset',
  );
  _require(
    (f.notificationFind<PageDots>(_root)!.widget as PageDots).activeIndex ==
        dot,
    'Recent page dot reset',
  );
  _record('nonzero_recent_rail_roundtrip_preserved', {
    'expectedRecentOffset': horizontal,
    'expectedHomeOffset': homeOffset,
    'expectedActiveDot': dot,
  });
  if (_emptyBuilder != null) {
    await _openEmpty();
    _record('explicit_empty_widget_scene_not_root_feed');
    await _maxScroll();
    await _settings();
    await _close(header: true);
    _record('explicit_empty_widget_back');
  }
  for (final pair in const {
    '아카이브': 'archive',
    '즐겨찾기': 'bookmark',
    '마이': 'my',
    '홈': 'home',
  }.entries) {
    await _tap(
      f.notificationText(
        f.notificationFind<ClipbackNavigationBar>(_root)!,
        pair.key,
      )!,
    );
    await _wait(() => _route() == pair.value, 'Root ${pair.value} tab failed');
    await _settle(5);
    _record('root_tab_${pair.value}');
  }
  await _tap(f.notificationFind<NavAddButton>(_root)!);
  await _wait(() => _route() == 'save', 'Existing save entry missing');
  await _settle(8);
  _record('existing_save_entry');
  await _tap(
    f.notificationFind<SvgIconButton>(
      f.notificationFind<SaveContentTopBar>(_root)!,
    )!,
  );
  await _wait(() => _route() == 'home', 'Save close missing');
  _require(_server.writes == 0, 'Save close wrote content');
  _record('save_close_without_write');
  await _open();
  if (f.notificationScreen(_root) != null) {
    final VoidCallback staleBack =
            (f.notificationScreen(_root)!.widget as dynamic).onBack,
        staleSettings =
            (f.notificationScreen(_root)!.widget as dynamic).onOpenSettings;
    _social.revoked = true;
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await _wait(() => _route() == 'login', 'Revoked member did not show Login');
    _require(_storage.value == null, 'Revoked session storage not cleared');
    final requests = _server.requests.length;
    staleBack();
    staleSettings();
    await _settle(5);
    _require(
      _route() == 'login' && _server.requests.length == requests,
      'Stale notification callback escaped session guard',
    );
    _record('session_invalidation_blocks_stale_back_and_settings');
  }
  await _fresh('member');
  _record('final_member_list_scroll_zero');
  _coverage = true;
  _done = true;
}

Future<void> main() => startNotificationPreview();
Future<void> startNotificationPreview({
  Widget Function(VoidCallback onBack, VoidCallback onOpenSettings)?
  emptyBuilder,
}) => http.runWithClient(() async {
  _emptyBuilder = emptyBuilder;
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-notification-');
  _fonts = await f.notificationLoadFonts();
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _fresh('member');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'NOTIFICATION ready phase=$notificationPhase output=${_output.path}',
  );
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
          final kind = request.uri.queryParameters['kind'] ?? 'list',
              session = request.uri.queryParameters['session'] ?? 'member';
          _require(
            ['list', 'empty'].contains(kind),
            'kind list|empty required',
          );
          _require(
            ['member', 'guest'].contains(session),
            'session member|guest required',
          );
          await _fresh(session, open: kind == 'list');
          if (kind == 'empty') await _openEmpty();
          await _captureScene();
        case '/empty-scene':
          await _fresh('member', open: false);
          await _openEmpty();
          await _captureScene();
        case '/max-scroll':
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
      debugPrint('NOTIFICATION FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
