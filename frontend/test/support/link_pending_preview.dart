// D04 actual-root and memory API fixture. Sharing isolated before the first engine.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../fixtures/link_pending_fixture.dart' as f;
import '../fixtures/splash_alignment_fixture.dart' as b;
import 'archive_all_preview.dart' as isolated;
import 'login_alignment_preview.dart' as p;

const pendingPhase = String.fromEnvironment(
  'LINK_PENDING_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
late Directory _output;
late f.LinkPendingServer _server;
late p.LoginControlledSocial _social;
late p.LoginMemoryStorage _storage;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
final _judgments = <String, Map<String, Object?>>{};
var _epoch = 0, _pointer = 900, _busy = false, _done = false;
String _kind = 'link-loading';
Element get _root => _capture.currentContext! as Element;
Element? _key(String k) => b.splashKey(_root, k);
Element? _text(String t) => b
    .splashElements(_root)
    .where((e) => e.widget is Text && (e.widget as Text).data == t)
    .firstOrNull;
Element? _find<T extends Widget>() => b.splashFind<T>(_root);
String _route() => _find<SavedContentConfirmation>() != null
    ? 'result'
    : _find<AddContentSheet>() != null
    ? 'save'
    : _find<HomeScreen>() != null
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
  if (_capture.currentContext != null) {
    _server.resolve(success: false);
    runApp(const SizedBox.shrink());
    await _settle();
  }
  _server = f.LinkPendingServer();
  _storage = p.LoginMemoryStorage()..value = f.pendingSession;
  _social = p.LoginControlledSocial(
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
  await _settle();
  await _wait(() => _route() == 'home', 'Actual restored home missing');
  final nav = b
      .splashElements(_root)
      .where((e) => e.widget.runtimeType.toString() == 'NavAddButton')
      .first;
  await _tap(nav);
  await _wait(
    () => _find<LinkSaveBody>() != null,
    'Actual save dialog missing',
  );
}

Future<void> _input(String text) async {
  final editable = _find<EditableText>()! as StatefulElement;
  (editable.state as EditableTextState).updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await _wait(
    () =>
        _find<ValidationMessage>() != null &&
        (_find<ValidationMessage>()!.widget as ValidationMessage).valid,
    'Link validation missing',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _settle(3);
}

Future<void> _scene(String _) async {
  _kind = 'link-loading';
  await _fresh();
  await _input(f.pendingLink);
  await _tap(_find<SaveFlowButton>()!);
  await _wait(
    () => _server.submissions.length == 1 && _server.gate != null,
    'Actual pending POST missing',
  );
  await _settle(3);
  _find<LinkSaveBody>()
      ?.findAncestorStateOfType<ScrollableState>()
      ?.position
      .jumpTo(0);
  await _settle();
  _judgments[_kind] = f.linkPendingJudgment(f.linkPendingMeasure(_root));
}

Future<void> _complete() async {
  _server.resolve();
  await _wait(() => _route() == 'result', 'Actual save result missing');
  await _settle(3);
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
      m = f.linkPendingMeasure(_root);
  return {
    'phase': pendingPhase,
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
    'scrollOffset': (_find<LinkSaveBody>() ?? _find<SavedContentConfirmation>())
        ?.findAncestorStateOfType<ScrollableState>()
        ?.position
        .pixels,
    ...m,
    ...f.linkPendingJudgment(m),
    'frameworkErrors': List<String>.from(_errors),
    'socialCalls': List<String>.from(_social.calls),
    'socialIssuances': _server.socialIssuances,
    'guestIssuances': _server.guestIssuances,
    'sessionWrites': _storage.writes,
    'submissions': List<String>.from(_server.submissions),
    'savedCount': _server.saved == null ? 0 : 1,
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        share,
      ),
      'nativeDelegationCount': share?.nativeDelegationCount,
      'unknownMethods': share?.unknownShareMethods,
    },
    'scope':
        'Actual root/save modal and ContentActions API using memory member session and held POST; includes existing follow-up reads. No real server/provider/physical-device proof.',
  };
}

Future<Map<String, Object?>> _report() async {
  final s = _snapshot(),
      style =
          _judgments.length == 1 &&
          _judgments.values.every((j) => j['stylePassed'] == true),
      layout =
          _judgments.length == 1 &&
          _judgments.values.every((j) => j['layoutPassed'] == true),
      asset =
          _judgments.length == 1 &&
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
  await _scene('link-loading');
  _record(
    'submitted URL and original target geometry',
    _server.submissions.single == f.pendingLink &&
        _judgments[_kind]!['stylePassed'] == true &&
        _judgments[_kind]!['layoutPassed'] == true,
  );
  final button = _find<SaveFlowButton>()!.widget as SaveFlowButton;
  button.onPressed();
  button.onPressed();
  await _tap(_find<SaveFlowButton>()!);
  _record(
    'disabled close and retained callbacks prevent duplicate',
    _route() == 'save' && _server.submissions.length == 1,
  );
  await _tap(_text('사진 첨부')!);
  _record(
    'tab change preserves legacy photo body',
    _find<PhotoSaveBody>() != null &&
        _key('link-pending-skeleton') == null &&
        (_find<SaveFlowButton>()!.widget as SaveFlowButton).loading,
  );
  await _tap(_text('링크 첨부')!);
  _record(
    'submitted link tab restores D04',
    _key('link-pending-skeleton') != null &&
        (_find<LinkSaveBody>()!.widget as LinkSaveBody).controller.text ==
            f.pendingLink,
  );
  await _input('https://example.com/edited');
  _record(
    'edited input preserves actual submitted URL',
    _key('link-pending-skeleton') == null &&
        _server.submissions.single == f.pendingLink,
  );
  await _complete();
  final result =
      _find<SavedContentConfirmation>()!.widget as SavedContentConfirmation;
  await _tap(_text('사진 첨부')!);
  _record(
    'completed result and tab use submitted input',
    result.originalUrl == f.pendingLink &&
        _find<SavedContentConfirmation>() != null &&
        _find<PhotoSaveBody>() == null,
  );
  await _tap(_find<SaveFlowButton>()!);
  await _wait(
    () => _find<AddContentSheet>() == null,
    'Completed close missing',
  );
  _record(
    'close performs no additional save',
    _server.submissions.length == 1 && _server.saved != null,
  );
  await _scene('link-loading');
  _server.resolve(success: false);
  await _wait(
    () => _find<SaveErrorToast>() != null,
    'Existing save failure missing',
  );
  _record(
    'failure preserves input without false completion',
    _find<SavedContentConfirmation>() == null &&
        (_find<LinkSaveBody>()!.widget as LinkSaveBody).controller.text ==
            f.pendingLink,
  );
  await _tap(_find<SaveFlowButton>()!);
  await _wait(() => _server.submissions.length == 2, 'Manual retry missing');
  await _complete();
  _record(
    'manual retry creates one successful result',
    _server.submissions.length == 2 && _server.saved != null,
  );
  await _scene('link-loading');
  final header = _find<SaveContentTopBar>()!;
  await _tap(b.splashFind<SvgIconButton>(header)!);
  await _wait(() => _find<AddContentSheet>() == null, 'Pending close missing');
  _server.resolve();
  await _settle(5);
  _record(
    'late response does not reopen closed save modal',
    _find<AddContentSheet>() == null &&
        _find<SavedContentConfirmation>() == null &&
        _server.submissions.length == 1,
  );
  _record(
    'framework errors and sharing isolated',
    _errors.isEmpty &&
        isolated.archiveAllShareMessenger?.nativeDelegationCount == 0 &&
        (isolated.archiveAllShareMessenger?.unknownShareMethods.isEmpty ??
            false),
  );
  await _scene('link-loading');
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-link-pending-');
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
        case '/complete':
          await _complete();
        case '/status':
          break;
        default:
          request.response.statusCode = 404;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(await _report()));
    } catch (e, st) {
      debugPrint('LINK_PENDING $e\n$st');
      request.response.statusCode = 500;
      _record('request_failure', false, {'error': '$e'});
      request.response.write(jsonEncode({'error': '$e', ...await _report()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.controlledClient);
