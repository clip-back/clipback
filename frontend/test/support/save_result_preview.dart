// Local device fixture. Uses real save widgets, a deterministic file picker and
// in-memory save callbacks, with synthetic pointer/text input (no backend/auth).
// flutter run --no-pub -t test/support/save_result_preview.dart
//   --dart-define=SAVE_RESULT_PHASE=before|after
// HTTP loopback :8767: /status, /scene?kind=photo|link&scale=1|2, /run,
// /keyboard, /scroll. Android host access: adb forward tcp:8767 tcp:8767.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const _phase = String.fromEnvironment(
  'SAVE_RESULT_PHASE',
  defaultValue: 'before',
);
const _url = 'https://example.invalid/save-result';
final _appKey = GlobalKey<_PreviewState>();
final _navigatorKey = GlobalKey<NavigatorState>();
final _captureKey = GlobalKey();
final _errors = <Map<String, String>>[];
final _checks = <Map<String, Object?>>[];
late Directory _output;
late _Picker _picker;
var _busy = false;
var _checksCompleted = false;
var _scene = 'idle';
var _pointer = 7000;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _require(_phase == 'before' || _phase == 'after', 'Unknown phase');
  final photo = await rootBundle.load(Assets.savedPhotoPreview);
  final alternate = await rootBundle.load(Assets.saveLinkPreview);
  _picker = _Picker(photo.buffer.asUint8List(), alternate.buffer.asUint8List());
  FilePicker.platform = _picker;
  _output = await Directory.systemTemp.createTemp('clipback-save-result-');
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add({'scene': _scene, 'error': details.exceptionAsString()});
    previous?.call(details);
  };
  runApp(_Preview(key: _appKey));
  await _settle();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'SAVE_RESULT ready phase=$_phase output=${_output.path} port=8767',
  );
  await for (final request in server) {
    if (_busy && request.uri.path != '/status') {
      request.response.statusCode = HttpStatus.conflict;
      request.response.write('Fixture is busy');
      await request.response.close();
      continue;
    }
    final mutates = request.uri.path != '/status';
    if (mutates) _busy = true;
    try {
      switch (request.uri.path) {
        case '/status':
          break;
        case '/scene':
          final kind = request.uri.queryParameters['kind'] ?? 'photo';
          final scale = double.parse(
            request.uri.queryParameters['scale'] ?? '1',
          );
          _require(kind == 'link' || kind == 'photo', 'Unknown kind');
          _require(scale == 1 || scale == 2, 'Unsupported scale');
          await _open(kind, scale: scale);
          await _save();
          await _capture('${kind}_scale_${scale.toInt()}');
        case '/run':
          await _run();
        case '/keyboard':
          await _open('link');
          await _tap(_rect(_first<EditableText>()).center);
          await Future<void>.delayed(const Duration(seconds: 2));
          await _type(_url);
          await _capture('keyboard');
        case '/scroll':
          await _drag(const Offset(0, -220));
          await _capture('scrolled');
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await _report();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_status()));
    } catch (error, stack) {
      _checks.add({'scenario': _scene, 'passed': false, 'error': '$error'});
      debugPrint('SAVE_RESULT FAIL $error\n$stack');
      await _report();
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': '$error', ..._status()}));
    } finally {
      if (mutates) _busy = false;
      await request.response.close();
    }
  }
}

class _Preview extends StatefulWidget {
  const _Preview({super.key});
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  double scale = 1;
  String mode = 'success';
  int calls = 0;
  Completer<ContentItem>? pending;
  final submissions = <Map<String, Object?>>[];

  void setScale(double value) => setState(() => scale = value);

  Future<ContentItem> save({
    required String kind,
    String? url,
    Uint8List? bytes,
    String? filename,
  }) async {
    calls++;
    submissions.add({
      'kind': kind,
      'url': url,
      'filename': filename,
      'byteLength': bytes?.length,
      'matchesOriginalPhoto': bytes == null || _same(bytes, _picker.photo),
    });
    if (mode == 'pending') {
      pending = Completer<ContentItem>();
      return pending!.future;
    }
    if (mode == 'fail') throw StateError('Fixture save failure');
    return _content(kind);
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _captureKey,
    child: MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.main),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const Scaffold(body: Center(child: Text('저장 결과 검증'))),
    ),
  );
}

ContentItem _content(String kind) => ContentItem(
  id: 'save-result-$kind',
  title: '저장 결과 확인',
  summary: '고정 대역 데이터',
  category: catUncategorized,
  savedAt: '10.15',
  savedAtFull: '2026.10.15',
  savedAtFullShort: '26.10.15',
  tags: const [],
  source: kind == 'photo' ? '사진' : '웹사이트',
  originalUrl: kind == 'link' ? _url : '',
  originalText: '',
  isScreenshot: kind == 'photo',
);

class _Picker extends FilePicker {
  _Picker(this.photo, this.alternate);
  final Uint8List photo;
  final Uint8List alternate;
  int calls = 0;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final next = calls++ == 0 ? photo : alternate;
    return FilePickerResult([
      PlatformFile(
        name: calls == 1 ? 'save-result.png' : 'other-photo.png',
        size: next.length,
        bytes: next,
      ),
    ]);
  }
}

ui.FlutterView get _view => View.of(_captureKey.currentContext!);
List<Element> _elements([Element? root]) {
  final result = <Element>[];
  void visit(Element element) {
    if (element.widget case Offstage(offstage: true)) return;
    result.add(element);
    element.visitChildren(visit);
  }

  visit(root ?? _captureKey.currentContext! as Element);
  return result;
}

Element _first<T extends Widget>() =>
    _elements().firstWhere((e) => e.widget is T);
bool _has<T extends Widget>() => _elements().any((e) => e.widget is T);
bool _text(String text) =>
    _elements().any((e) => e.widget is Text && (e.widget as Text).data == text);
Rect _rect(Element element) {
  final box = element.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<void> _settle([int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _tap(Offset point) async {
  final pointer = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, viewId: _view.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 80));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      viewId: _view.viewId,
      position: point,
      timeStamp: const Duration(milliseconds: 80),
    ),
  );
  await _settle();
}

Future<void> _tapText(String text) => _tap(
  _rect(
    _elements().firstWhere(
      (e) => e.widget is Text && (e.widget as Text).data == text,
    ),
  ).center,
);

Future<void> _type(String text) async {
  final editable = _first<EditableText>().widget as EditableText;
  // Equivalent to a text-input update, without a platform test driver.
  editable.controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  editable.onChanged?.call(text);
  await _settle(9); // Includes the real 350ms link validation debounce.
}

Future<void> _open(
  String kind, {
  double scale = 1,
  String mode = 'success',
}) async {
  final navigator = _navigatorKey.currentState!;
  navigator.popUntil((route) => route.isFirst);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  final state = _appKey.currentState!;
  state.setScale(scale);
  state.mode = mode;
  state.calls = 0;
  state.pending = null;
  state.submissions.clear();
  _picker.calls = 0;
  _scene = '${kind}_scale_${scale.toInt()}_$mode';
  await _settle();
  unawaited(
    showContentSaveScreen(
      context: navigator.context,
      onAddLink: ({required url, category}) =>
          state.save(kind: 'link', url: url),
      onAddScreenshot: ({required bytes, required filename, category}) =>
          state.save(kind: 'photo', bytes: bytes, filename: filename),
    ),
  );
  await _settle();
  if (kind == 'photo') {
    await _tapText('사진 첨부');
    await _selectPhoto();
  } else {
    await _type(_url);
  }
}

Future<void> _selectPhoto() async {
  final body = _first<PhotoSaveBody>();
  final select = _elements(body).firstWhere((e) => e.widget is InkWell);
  await _tap(_rect(select).center);
}

Future<void> _save() => _tap(_rect(_first<SaveFlowButton>()).center);

Future<void> _drag(Offset delta) async {
  final scroll = _first<SingleChildScrollView>();
  final start = _rect(scroll).center;
  final pointer = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, viewId: _view.viewId, position: start),
  );
  var previous = start;
  for (var i = 1; i <= 10; i++) {
    final next = start + delta * (i / 10);
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: pointer,
        viewId: _view.viewId,
        position: next,
        delta: next - previous,
        timeStamp: Duration(milliseconds: i * 60),
      ),
    );
    previous = next;
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      viewId: _view.viewId,
      position: previous,
      timeStamp: const Duration(milliseconds: 600),
    ),
  );
  await _settle();
}

Map<String, Object?> _snapshot() {
  final confirmation = _has<SavedContentConfirmation>()
      ? _first<SavedContentConfirmation>().widget as SavedContentConfirmation
      : null;
  final context = _has<AddContentSheet>()
      ? _first<AddContentSheet>()
      : _navigatorKey.currentContext!;
  final media = MediaQuery.of(context);
  final selectedTab = _elements()
      .where(
        (e) =>
            e.widget is Text &&
            (e.widget as Text).style?.fontWeight == FontWeight.w600,
      )
      .map((e) => (e.widget as Text).data)
      .where((s) => s == '링크 첨부' || s == '사진 첨부')
      .firstOrNull;
  return {
    'scene': _scene,
    'selectedTab': selectedTab,
    'confirmation': confirmation != null,
    'label': confirmation?.originalUrl,
    'hasPhotoBytes': confirmation?.photoBytes != null,
    'matchesOriginalPhoto': confirmation?.photoBytes == null
        ? null
        : _same(confirmation!.photoBytes!, _picker.photo),
    'hasPhotoTitle': _text('저장할 사진'),
    'hasLinkTitle': _text('저장할 링크'),
    'hasLinkValidation': _text('유효한 링크예요!'),
    'logicalSize': '${_view.physicalSize / _view.devicePixelRatio}',
    'pixelRatio': _view.devicePixelRatio,
    'textScale': media.textScaler.scale(1),
    'viewPaddingTop': media.viewPadding.top,
    'paddingBottom': media.padding.bottom,
    'viewPaddingBottom': media.viewPadding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'scrollOffset': _has<SingleChildScrollView>()
        ? (_first<SingleChildScrollView>().widget as SingleChildScrollView)
              .controller
              ?.offset
        : null,
    'calls': _appKey.currentState!.calls,
    'submissions': List.of(_appKey.currentState!.submissions),
  };
}

Future<void> _capture(String name) async {
  await _settle();
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: _view.devicePixelRatio);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${_output.path}/$name.png').writeAsBytes(
      png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _checks.add({'capture': name, ..._snapshot()});
  debugPrint('SAVE_RESULT capture=$name output=${_output.path}');
}

Map<String, Object?> _status() => {
  'phase': _phase,
  'busy': _busy,
  'platform': Platform.operatingSystem,
  'output': _output.path,
  ..._snapshot(),
};

Future<void> _report() => File('${_output.path}/report.json').writeAsString(
  const JsonEncoder.withIndent('  ').convert({
    ..._status(),
    'passed':
        _checksCompleted &&
        !_checks.any((c) => c['passed'] == false) &&
        _errors.isEmpty,
    'checksCompleted': _checksCompleted,
    'behaviorPassed':
        _checksCompleted && !_checks.any((c) => c['passed'] == false),
    'layoutPassed': _errors.isEmpty,
    'scope':
        'Real dialog; in-memory callbacks and picker; synthetic pointer/text input. Framework layout errors are recorded separately from behavior checks.',
    'checks': _checks,
    'frameworkErrors': _errors,
  }),
);

Future<void> _run() async {
  _checksCompleted = false;
  for (final kind in ['link', 'photo']) {
    for (final scale in [1.0, 2.0]) {
      await _open(kind, scale: scale);
      await _save();
      _require(_has<SavedContentConfirmation>(), 'Save result missing');
      if (_phase == 'after') {
        _require(
          _text(kind == 'photo' ? '저장할 사진' : '저장할 링크'),
          'Wrong result title',
        );
        _require(
          _text('유효한 링크예요!') == (kind == 'link'),
          'Wrong link validation',
        );
      }
      await _capture('${kind}_scale_${scale.toInt()}');
      await _tapText('닫기');
      _require(!_has<AddContentSheet>(), 'Close did not dismiss dialog');
    }
  }
  for (final kind in ['photo', 'link']) {
    await _open(kind, mode: 'pending');
    final state = _appKey.currentState!;
    await _save();
    _require(state.calls == 1 && state.pending != null, 'Pending save missing');
    await _save();
    _require(state.calls == 1, 'Duplicate save was submitted');
    if (kind == 'photo') {
      await _tapText('링크 첨부');
      await _type('https://example.invalid/changed');
      await _tapText('사진 첨부');
      await _selectPhoto();
      await _tapText('링크 첨부');
    } else {
      await _type('https://example.invalid/changed');
      await _tapText('사진 첨부');
      await _selectPhoto();
    }
    state.pending!.complete(_content(kind));
    await _settle();
    final result =
        _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
    if (_phase == 'after') {
      _require(
        result.originalUrl == (kind == 'photo' ? 'save-result.png' : _url),
        'Submitted label changed',
      );
      _require(
        (result.photoBytes != null) == (kind == 'photo'),
        'Submitted kind changed',
      );
      if (kind == 'photo') {
        _require(
          _same(result.photoBytes!, _picker.photo),
          'Submitted photo changed',
        );
      }
      await _tapText(kind == 'photo' ? '링크 첨부' : '사진 첨부');
      _require(
        _snapshot()['selectedTab'] == (kind == 'photo' ? '사진 첨부' : '링크 첨부'),
        'Completed tab is not pinned',
      );
    }
    await _capture('${kind}_pending_switch');
    _checks.add({
      'scenario': '${kind}_pending_switch',
      'passed': true,
      ..._snapshot(),
    });
  }
  await _open('photo', mode: 'fail');
  await _save();
  _require(
    !_has<SavedContentConfirmation>() && _has<SaveErrorToast>(),
    'Failed save did not retain input/error',
  );
  _appKey.currentState!.mode = 'success';
  await _save();
  _require(
    _has<SavedContentConfirmation>() &&
        _appKey.currentState!.calls == 2 &&
        _picker.calls == 1,
    'Manual retry did not reuse selected photo',
  );
  await _capture('photo_retry');
  _checks.add({'scenario': 'photo_retry', 'passed': true});
  await _open('link', mode: 'pending');
  await _save();
  final pending = _appKey.currentState!.pending!;
  final top = _first<SaveContentTopBar>();
  final close = _elements(
    top,
  ).firstWhere((e) => e.widget is InkWell || e.widget is IconButton);
  await _tap(_rect(close).center);
  _require(!_has<AddContentSheet>(), 'Top close did not dismiss dialog');
  pending.complete(_content('link'));
  await _settle();
  _require(!_has<AddContentSheet>(), 'Late completion reopened result');
  _checks.add({'scenario': 'pending_close_late_completion', 'passed': true});
  _checksCompleted = true;
}
