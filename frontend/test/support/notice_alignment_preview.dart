// K01: actual root app and memory session/API, native sharing isolated before
// bootstrap. Same frozen source runs the old My modal and the new notice route.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
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
import 'package:http/http.dart' as http;
import '../fixtures/notice_alignment_fixture.dart' as f;
import 'archive_all_preview.dart' as isolated;

const noticePhase = String.fromEnvironment(
  'NOTICE_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
f.NoticeServer _server = f.NoticeServer('member');
f.NoticeMemoryStorage _storage = f.NoticeMemoryStorage();
f.NoticeSocial _social = f.NoticeSocial();
final _sessions = <f.NoticeServer>[],
    _checks = <Map<String, Object?>>[],
    _errors = <String>[];
late Directory _output;
Map<String, Object?> _fonts = {};
String _kind = 'member';
bool _busy = false, _done = false, _coverage = false;
int _epoch = 0, _pointer = 68000;
double _openingMyOffset = 0;
Element get _root => _capture.currentContext! as Element;
Element get _my => f.noticeFind<MyScreen>(_root)!;
Element get _notice =>
    f.noticeScreen(_root) ?? f.noticeFind<NoticeSheet>(_root)!;
PendingSharePrompt? _sharePrompt() =>
    f.noticeFind<PendingSharePrompt>(_root)?.widget as PendingSharePrompt?;
void _requireShareUnblocked() {
  final prompt = _sharePrompt();
  _require(
    prompt != null && prompt.error == null && prompt.drafts.isEmpty,
    'Unexpected native share recovery prompt blocks the evidence scene',
  );
}

String _route() {
  if (_capture.currentContext == null) return 'mounting';
  if (f.noticeFind<SaveContentTopBar>(_root) != null) return 'save';
  if (f.noticeScreen(_root) != null) return 'noticeList';
  if (f.noticeFind<NoticeSheet>(_root) != null) return 'noticeSheet';
  if (f.noticeFind<ReminderSheet>(_root) != null) return 'reminderSheet';
  if (f.noticeFind<PermissionSheet>(_root) != null) return 'permissionSheet';
  if (f.noticeFind<ContactSheet>(_root) != null) return 'contactSheet';
  if (f.noticeFind<AppVersionSheet>(_root) != null) return 'versionSheet';
  if (f.noticeFind<AccountManagementScreen>(_root) != null) return 'account';
  if (f.noticeFind<CategoryManagementScreen>(_root) != null) {
    return 'categoryManagement';
  }
  if (f.noticeFind<MyScreen>(_root) != null) return 'my';
  if (f.noticeFind<ArchiveScreen>(_root) != null) return 'archive';
  if (f.noticeFind<BookmarkScreen>(_root) != null) return 'bookmark';
  if (f.noticeFind<HomeScreen>(_root) != null) return 'home';
  if (f.noticeFind<LoginScreen>(_root) != null) return 'login';
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
  final point = f.noticeBox(e).center, id = ++_pointer, v = View.of(_root);
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

Future<void> _myTab() async {
  await _tap(f.noticeText(f.noticeFind<ClipbackNavigationBar>(_root)!, '마이')!);
  await _wait(() => _route() == 'my', 'My tab did not open');
  await _settle(5);
}

Future<void> _open() async {
  final text = f.noticeText(_my, '공지사항')!;
  await _show(text);
  _openingMyOffset = f.noticeMyPosition(_root)?.pixels ?? 0;
  await _tap(text);
  await _wait(
    () => ['noticeList', 'noticeSheet'].contains(_route()),
    'Actual notice entry missing',
  );
  await _settle(8);
  f.noticePosition(_root)?.jumpTo(0);
  await _settle(3);
}

Future<void> _close({bool header = false}) async {
  if (header && f.noticeScreen(_root) != null) {
    await _tap(f.noticeKey(_notice, 'notice-back-hit')!);
  } else {
    await WidgetsBinding.instance.handlePopRoute();
  }
  await _wait(() => _route() == 'my', 'Notice back did not return My');
  await _settle(5);
}

Future<void> _fresh(String kind, {bool open = true}) async {
  _kind = kind;
  _server = f.NoticeServer(kind);
  _sessions.add(_server);
  _storage = f.NoticeMemoryStorage();
  _social = f.NoticeSocial();
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
  await _wait(() => _route() == 'home', 'Memory home startup missing');
  await _myTab();
  await _wait(
    () =>
        (f.noticeFind<MyScreen>(_root)!.widget as MyScreen).user.name ==
            _server.expected.name &&
        (f.noticeFind<MyScreen>(_root)!.widget as MyScreen)
                .user
                .revisitedContentCount ==
            _server.expected.revisitedContentCount,
    'Actual user/stats mapping missing',
  );
  await _hideKeyboard();
  if (open) await _open();
  await _wait(
    () => _sharePrompt()?.busy == false,
    'Native share preparation did not settle',
  );
  _requireShareUnblocked();
}

Map<String, Object?> _snapshot() {
  if (_capture.currentContext == null) {
    return {
      'ready': false,
      'route': 'mounting',
      'phase': noticePhase,
      'platform': Platform.operatingSystem,
    };
  }
  final m = f.noticeMeasure(_root),
      v = View.of(_root),
      messenger = isolated.archiveAllShareMessenger;
  return {
    'ready': true,
    'phase': noticePhase,
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
    'scrollOffset': 0.0,
    ...m,
    ...f.noticeJudgment(m),
    'myScrollOffset': f.noticeMyPosition(_root)?.pixels,
    'openingMyOffset': _openingMyOffset,
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
      '${_output.path}/notice_${_kind}_scale_1_scroll_0.png',
    ).writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  await File(
    '${_output.path}/notice_${_kind}_state.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(_snapshot()));
}

Future<void> _maxScroll() async {
  final p = f.noticePosition(_root)!;
  p.jumpTo(p.maxScrollExtent);
  await _settle(5);
  final last = f.noticeText(_notice, mockNotices.last)!;
  final viewport = f.noticeMeasure(_root)['bounds'] as Map;
  _require(
    f.noticeBox(last).bottom <= (viewport['viewport']['bottom'] as num) + .18,
    'Last notice is not visible',
  );
  _record('maximum_scroll', {
    'maximum': p.maxScrollExtent,
    'noScroll': p.maxScrollExtent == 0,
    'lastNoticeVisible': true,
  });
}

Future<void> _run() async {
  _checks.clear();
  _sessions.clear();
  _done = false;
  _coverage = false;
  for (final kind in ['member', 'guest']) {
    await _fresh(kind);
    _record('${kind}_notice_entry');
    final count = _server.requests.length, records = _server.records.length;
    for (final title in mockNotices) {
      final e = f.noticeText(_notice, title)!;
      await _show(e);
      await _tap(e);
      _require(
        ['noticeList', 'noticeSheet'].contains(_route()),
        'Readonly title opened a destination',
      );
    }
    _require(
      _server.requests.length == count &&
          _server.records.length == records &&
          _server.writes == 0,
      'Readonly titles changed HTTP or content',
    );
    _record('${kind}_three_titles_readonly_no_requests');
    await _maxScroll();
    final headerAvailable = f.noticeScreen(_root) != null,
        offset = _openingMyOffset;
    await _close(header: true);
    _require(
      (f.noticeMyPosition(_root)!.pixels - offset).abs() < .2,
      'Header/modal back did not preserve My position',
    );
    _record('${kind}_header_or_existing_modal_return', {
      'headerAvailable': headerAvailable,
      'expectedMyOffset': offset,
    });
    await _open();
    final osOffset = _openingMyOffset;
    await _close();
    _require(
      (f.noticeMyPosition(_root)!.pixels - osOffset).abs() < .2,
      'OS back did not preserve My position',
    );
    _record('${kind}_os_back_preserves_my');
  }
  await _fresh('member', open: false);
  for (final pair in const {
    '리마인드 설정': 'reminderSheet',
    '앱 권한': 'permissionSheet',
    '문의하기': 'contactSheet',
    '앱 버전': 'versionSheet',
  }.entries) {
    final text = f.noticeText(_my, pair.key)!;
    await _show(text);
    await _tap(text);
    await _wait(() => _route() == pair.value, 'Existing ${pair.value} missing');
    await _settle(8);
    _record('existing_${pair.value}_open');
    await WidgetsBinding.instance.handlePopRoute();
    await _wait(() => _route() == 'my', 'Existing sheet close missing');
    await _settle(8);
    _record('existing_${pair.value}_close');
  }
  await _tap(f.noticeKey(_my, 'my-header-settings')!);
  await _wait(() => _route() == 'account', 'Settings account entry missing');
  _record('existing_account_entry');
  await _tap(f.noticeKey(_root, 'account-back-hit')!);
  await _wait(() => _route() == 'my', 'Account return missing');
  await _settle(5);
  _require(
    f.noticeMyPosition(_root)!.pixels.abs() < .2,
    'Unrelated account route retained notice-only My position',
  );
  _record('account_return_resets_my');
  final category = f.noticeText(_my, '카테고리 관리')!;
  await _show(category);
  await _tap(category);
  await _wait(
    () => _route() == 'categoryManagement',
    'Category management missing',
  );
  _record('existing_category_management');
  await _tap(f.noticeKey(_root, 'management-back')!);
  await _wait(() => _route() == 'my', 'Category return missing');
  await _settle(5);
  _require(
    f.noticeMyPosition(_root)!.pixels.abs() < .2,
    'Category route retained notice-only My position',
  );
  _record('category_return_resets_my');
  for (final pair in const {
    '홈': 'home',
    '아카이브': 'archive',
    '즐겨찾기': 'bookmark',
    '마이': 'my',
  }.entries) {
    final nav = f.noticeFind<ClipbackNavigationBar>(_root)!;
    await _tap(f.noticeText(nav, pair.key)!);
    await _wait(() => _route() == pair.value, 'Root ${pair.value} tab failed');
    await _settle(5);
    _record('root_tab_${pair.value}');
  }
  await _tap(f.noticeFind<NavAddButton>(_root)!);
  await _wait(() => _route() == 'save', 'Existing save entry missing');
  _record('existing_save_entry');
  await _settle(8);
  await _tap(
    f.noticeFind<SvgIconButton>(f.noticeFind<SaveContentTopBar>(_root)!)!,
  );
  await _wait(() => _route() == 'my', 'Save close missing');
  _require(_server.writes == 0, 'Save close wrote content');
  _record('save_close_without_write');
  await _open();
  if (f.noticeScreen(_root) != null) {
    final VoidCallback staleBack =
        (f.noticeScreen(_root)!.widget as dynamic).onBack;
    _social.revoked = true;
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await _wait(
      () => _route() == 'login',
      'Revoked member session did not show Login',
    );
    _require(_storage.value == null, 'Revoked session storage not cleared');
    final requests = _server.requests.length;
    staleBack();
    await _settle(5);
    _require(
      _route() == 'login' && _server.requests.length == requests,
      'Stale notice back escaped session guard',
    );
    _record('session_invalidation_blocks_stale_notice_back');
  }
  await _fresh('member');
  _record('final_member_notice_scroll_zero');
  _coverage = true;
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-notice-');
  _fonts = await f.noticeLoadFonts();
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _fresh('member');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('NOTICE ready phase=$noticePhase output=${_output.path}');
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
      debugPrint('NOTICE FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
