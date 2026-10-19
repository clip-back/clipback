// D08 actual-root/memory upload fixture. Sharing isolated before first bootstrap.
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
import 'package:file_picker/file_picker.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import '../fixtures/photo_pending_fixture.dart' as f;
import '../fixtures/splash_alignment_fixture.dart' as b;
import 'archive_all_preview.dart' as isolated;
import 'login_alignment_preview.dart' as p;

const photoPhase = String.fromEnvironment(
  'PHOTO_PENDING_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
late Directory _output;
late f.PhotoPendingServer _server;
late p.LoginControlledSocial _social;
late p.LoginMemoryStorage _storage;
late f.PendingPhotoPicker _picker;
late Uint8List _originalBytes, _alternateBytes;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
final _judgments = <String, Map<String, Object?>>{};
var _epoch = 0, _pointer = 900, _busy = false, _done = false;
String _kind = 'photo-loading';
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
  _server = f.PhotoPendingServer(_originalBytes);
  _picker = f.PendingPhotoPicker([
    f.PendingPhoto(f.photoName, _originalBytes),
    f.PendingPhoto('alternate-photo.png', _alternateBytes),
  ]);
  FilePicker.platform = _picker;
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
  await _tap(_text('사진 첨부')!);
  await _tap(_text('사진 선택')!);
  await _wait(
    () => _find<SelectedPhotoPreview>() != null,
    'Actual photo selection missing',
  );
  await _settle(3);
}

Future<void> _scene(String _) async {
  _kind = 'photo-loading';
  await _fresh();
  await _tap(_find<SaveFlowButton>()!);
  await _wait(
    () => _server.uploads.length == 1 && _server.gate != null,
    'Actual pending multipart POST missing',
  );
  await _settle(3);
  (_find<PhotoSaveBody>() ?? _key('photo-pending-skeleton'))
      ?.findAncestorStateOfType<ScrollableState>()
      ?.position
      .jumpTo(0);
  await _settle();
  _judgments[_kind] = f.photoPendingJudgment(
    f.photoPendingMeasure(_root, expectedBytes: _originalBytes),
  );
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
      m = f.photoPendingMeasure(_root, expectedBytes: _originalBytes);
  return {
    'phase': photoPhase,
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
    'scrollOffset':
        (_find<PhotoSaveBody>() ??
                _key('photo-pending-skeleton') ??
                _find<SavedContentConfirmation>())
            ?.findAncestorStateOfType<ScrollableState>()
            ?.position
            .pixels,
    ...m,
    ...f.photoPendingJudgment(m),
    'frameworkErrors': List<String>.from(_errors),
    'socialCalls': List<String>.from(_social.calls),
    'socialIssuances': _server.socialIssuances,
    'guestIssuances': _server.guestIssuances,
    'sessionWrites': _storage.writes,
    'submissions': List<String>.from(_server.submissions),
    'uploads': List<Map<String, Object?>>.from(_server.uploads),
    'pickerCalls': _picker.calls,
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
        'Actual root/save modal, fake photo picker and held multipart upload with original fixture bytes. Includes existing follow-up reads; no physical picker/production/OCR-provider proof.',
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
  await _scene('photo-loading');
  _record(
    'actual multipart and target geometry',
    _server.submissions.single == f.photoName &&
        _server.uploads.single['originalBytesContained'] == true &&
        _judgments[_kind]!['stylePassed'] == true &&
        _judgments[_kind]!['layoutPassed'] == true,
  );
  final position = _key(
    'photo-pending-skeleton',
  )!.findAncestorStateOfType<ScrollableState>()!.position;
  position.jumpTo(position.maxScrollExtent);
  await _settle();
  final end = f.photoPendingMeasure(_root, expectedBytes: _originalBytes);
  final category = (end['category'] as Map)['bounds'] as Map;
  final viewport = end['viewport'] as Map;
  final remaining = (viewport['bottom'] as num) - (category['bottom'] as num);
  _record(
    'maximum scroll exposes final category and body padding',
    remaining >= 23.9 &&
        (position.maxScrollExtent == 0 || (remaining - 24).abs() <= .2),
    {'maxScrollExtent': position.maxScrollExtent, 'remaining': remaining},
  );
  position.jumpTo(0);
  await _settle();
  final button = _find<SaveFlowButton>()!.widget as SaveFlowButton;
  button.onPressed();
  button.onPressed();
  await _tap(_find<SaveFlowButton>()!);
  _record(
    'duplicate callbacks and disabled close guarded',
    _route() == 'save' && _server.uploads.length == 1,
  );
  await _tap(_text('링크 첨부')!);
  _record(
    'tab change preserves existing link input',
    _find<LinkSaveBody>() != null && _key('photo-pending-skeleton') == null,
  );
  await _tap(_text('사진 첨부')!);
  _record(
    'same submitted photo restores D08',
    _key('photo-pending-skeleton') != null,
  );
  _picker.cancelNext = true;
  await _tap(_key('photo-pending-reselect')!);
  _record(
    'picker cancellation retains current upload',
    _key('photo-pending-skeleton') != null && _server.uploads.length == 1,
  );
  await _tap(_key('photo-pending-reselect')!);
  await _wait(() => _find<PhotoSaveBody>() != null, 'Reselection missing');
  _record(
    'reselection preserves new editable D07 input',
    identical(
          (_find<PhotoSaveBody>()!.widget as PhotoSaveBody).photoBytes,
          _alternateBytes,
        ) &&
        _key('photo-pending-skeleton') == null,
  );
  await _complete();
  final result =
      _find<SavedContentConfirmation>()!.widget as SavedContentConfirmation;
  await _tap(_text('링크 첨부')!);
  _record(
    'completion uses original submitted bytes filename and pinned photo tab',
    identical(result.photoBytes, _originalBytes) &&
        result.originalUrl == f.photoName &&
        _find<LinkSaveBody>() == null &&
        _server.uploads.single['originalBytesContained'] == true,
  );
  await _tap(_find<SaveFlowButton>()!);
  await _wait(
    () => _find<AddContentSheet>() == null,
    'Completed close missing',
  );
  _record('completed close writes no new photo', _server.uploads.length == 1);
  await _scene('photo-loading');
  _server.resolve(success: false);
  await _wait(
    () => _find<SaveErrorToast>() != null,
    'Existing upload failure missing',
  );
  _record(
    'failure preserves selected photo and retry',
    _find<PhotoSaveBody>() != null &&
        identical(
          (_find<PhotoSaveBody>()!.widget as PhotoSaveBody).photoBytes,
          _originalBytes,
        ),
  );
  await _tap(_find<SaveFlowButton>()!);
  await _wait(() => _server.uploads.length == 2, 'Manual retry missing');
  await _complete();
  _record(
    'manual retry submits identical original bytes',
    _server.uploads.length == 2 &&
        _server.uploads.every((x) => x['originalBytesContained'] == true),
  );
  await _scene('photo-loading');
  await _tap(b.splashFind<SvgIconButton>(_find<SaveContentTopBar>()!)!);
  await _wait(() => _find<AddContentSheet>() == null, 'Pending close missing');
  _server.resolve();
  await _settle(5);
  _record(
    'late upload result does not reopen modal',
    _find<AddContentSheet>() == null &&
        _find<SavedContentConfirmation>() == null &&
        _server.uploads.length == 1,
  );
  _record(
    'framework and share remain isolated',
    _errors.isEmpty &&
        _server.unexpected.isEmpty &&
        _social.calls.isEmpty &&
        isolated.archiveAllShareMessenger?.nativeDelegationCount == 0 &&
        (isolated.archiveAllShareMessenger?.unknownShareMethods.isEmpty ??
            false),
  );
  await _scene('photo-loading');
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  final original = await rootBundle.load(Assets.savedPhotoPreview),
      alternate = await rootBundle.load(Assets.homeInitialLoadingIllustration);
  _originalBytes = original.buffer.asUint8List(
    original.offsetInBytes,
    original.lengthInBytes,
  );
  _alternateBytes = alternate.buffer.asUint8List(
    alternate.offsetInBytes,
    alternate.lengthInBytes,
  );
  _output = await Directory.systemTemp.createTemp('clipback-photo-pending-');
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
      debugPrint('PHOTO_PENDING $e\n$st');
      request.response.statusCode = 500;
      _record('request_failure', false, {'error': '$e'});
      request.response.write(jsonEncode({'error': '$e', ...await _report()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.photoClient);
