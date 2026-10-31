// Local device fixture. Uses real save widgets, a deterministic file picker and
// in-memory save callbacks, with synthetic pointer/text input (no backend/auth).
// flutter run --no-pub -t test/support/save_result_preview.dart
//   --dart-define=SAVE_RESULT_PHASE=before|after
// HTTP loopback :8767: /status, /scene?kind=link-input|photo-empty|photo-selected|link|photo&scale=1|1.5|2, /run,
// /keyboard?scale=1|1.5|2, /error?scale=1|1.5|2&keyboard=1, /keyboard-hide,
// /error?kind=photo&reason=quota|file-limit|paused uses the real API error mapper with
// an in-memory HTTP stand-in. prepared=1 submits an existing selection; offset
// fixes the actual scroll for BEFORE/AFTER comparison. No server quota proof.
// /scroll?max=1, /paste-scene?scale=1|1.5|2&keyboard=0|1, /paste-run.
// /paste-scene?kind=empty|invalid&scale=1&keyboard=0 adds base input states.
// /base-style-scene?kind=empty|valid|invalid|photo-empty|photo-selected|link|photo
// and /base-style-run inspect only text scale 1 for the current typography work.
// /base-style-run?resultsOnly=1 limits behavior checks to link/photo results.
// Add categoryState=classified|uncategorized|processing to a result scene for
// the five screen-level states; photo-processing has no design and is rejected.
// /base-style-run?resultsOnly=1&screenStates=1 runs those five result states.
// /photo-frame-run inspects D07 geometry and photo save behavior at text scale 1.
// D07 routes accept photoCase=default|landscape|tall; default static data is unchanged.
// Clipboard setup runs only through the mobile app plugin. No host clipboard API.
// Android host access: adb forward tcp:8768 tcp:8767.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/content/source_label.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
var _baseStyleMode = false;
var _baseStyleKind = '';
var _baseInputSetupScope = '';
var _resultScreenMode = false;
var _categoryState = 'classified';
var _photoCase = 'default';
late Map<String, Uint8List> _photoCases;
const _screenResultTitle = '기억하고 싶은 하루의 작은 순간들';
const _baseStaticInputScope =
    'Fixed real TextField input/onChanged and deterministic in-memory picker/save callbacks; static base scenes do not use clipboard';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _require(_phase == 'before' || _phase == 'after', 'Unknown phase');
  final photo = await rootBundle.load(Assets.savedPhotoPreview);
  final alternate = await rootBundle.load(Assets.saveLinkPreview);
  _photoCases = {
    'default': photo.buffer.asUint8List(),
    'landscape': await _markerPhoto(800, 400),
    'tall': await _markerPhoto(240, 1600),
  };
  _picker = _Picker(_photoCases['default']!, alternate.buffer.asUint8List());
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
    if (mutates) {
      _baseStyleMode =
          request.uri.path.startsWith('/base-style-') ||
          request.uri.path == '/photo-frame-run';
      _resultScreenMode =
          (request.uri.path == '/base-style-scene' &&
              request.uri.queryParameters.containsKey('categoryState')) ||
          (request.uri.path == '/base-style-run' &&
              request.uri.queryParameters['screenStates'] == '1');
    }
    try {
      switch (request.uri.path) {
        case '/status':
          break;
        case '/scene':
          final kind = request.uri.queryParameters['kind'] ?? 'photo';
          final scale = double.parse(
            request.uri.queryParameters['scale'] ?? '1',
          );
          _require(
            const [
              'link-input',
              'photo-empty',
              'photo-selected',
              'link',
              'photo',
            ].contains(kind),
            'Unknown kind',
          );
          _require(
            scale == 1 || scale == 1.5 || scale == 2,
            'Unsupported scale',
          );
          await _open(kind, scale: scale);
          if (_isResult(kind)) await _save();
          _checkScene(kind, scale);
          await _capture(_sceneName(kind, scale));
        case '/run':
          await _run();
        case '/paste-scene':
          final scale = _requestedScale(request.uri);
          final keyboard = request.uri.queryParameters['keyboard'] == '1';
          final kind = request.uri.queryParameters['kind'] ?? 'valid';
          await _pasteScene(scale: scale, keyboard: keyboard, kind: kind);
          await _capture(_pasteSceneName(scale, keyboard, kind: kind));
        case '/paste-run':
          await _pasteRun();
        case '/base-style-scene':
          final kind = request.uri.queryParameters['kind'] ?? 'empty';
          await _baseStyleScene(
            kind,
            categoryState: request.uri.queryParameters['categoryState'],
            photoCase: request.uri.queryParameters['photoCase'] ?? 'default',
          );
          await _capture(
            _baseStyleSceneName(kind) +
                (_photoCase == 'default' ? '' : '_$_photoCase'),
          );
        case '/base-style-run':
          await _baseStyleRun(
            resultsOnly: request.uri.queryParameters['resultsOnly'] == '1',
            screenStates: request.uri.queryParameters['screenStates'] == '1',
          );
        case '/photo-frame-run':
          await _photoFrameRun();
        case '/keyboard':
          final scale = _requestedScale(request.uri);
          await _open('link-input', scale: scale);
          await _showKeyboard();
          _checkFooter();
          await _capture(_sceneName('keyboard', scale));
        case '/error':
          final scale = _requestedScale(request.uri);
          final reason = request.uri.queryParameters['reason'] ?? 'fail';
          _require(
            ['fail', 'quota', 'file-limit', 'paused'].contains(reason),
            'Unknown failure',
          );
          if (request.uri.queryParameters['prepared'] == '1') {
            _appKey.currentState!.mode = reason;
            _scene = '${_sceneName('photo', scale)}_$reason';
          } else {
            await _open(
              request.uri.queryParameters['kind'] == 'photo'
                  ? 'photo'
                  : 'link-input',
              scale: scale,
              mode: reason,
            );
          }
          if (request.uri.queryParameters['keyboard'] == '1') {
            await _showKeyboard();
          }
          await _save();
          _require(_has<SaveErrorToast>(), 'Failure toast missing');
          final offset = double.tryParse(
            request.uri.queryParameters['offset'] ?? '',
          );
          if (offset != null) {
            _require(
              offset >= 0 && offset <= _bodyPosition.maxScrollExtent,
              'Invalid offset',
            );
            _bodyPosition.jumpTo(offset);
            await _settle(1);
          } else {
            await _scrollToMax();
          }
          _checkFooter(atMaximum: offset == null);
          await _capture(
            _sceneName(
              request.uri.queryParameters['keyboard'] == '1'
                  ? 'error_keyboard'
                  : 'error',
              scale,
            ),
          );
        case '/keyboard-hide':
          FocusManager.instance.primaryFocus?.unfocus();
          await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          await _settle(12);
          await _capture('keyboard_hidden');
        case '/scroll':
          if (request.uri.queryParameters['max'] == '1') {
            await _scrollToMax();
            _checkFooter(atMaximum: true);
          } else {
            await _drag(const Offset(0, -220));
          }
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
      'matchesAlternatePhoto': bytes == null || _same(bytes, _picker.alternate),
    });
    if (mode == 'pending') {
      pending = Completer<ContentItem>();
      return pending!.future;
    }
    if (mode == 'fail') throw StateError('Fixture save failure');
    if (mode == 'quota' || mode == 'file-limit' || mode == 'paused') {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': {
              'code': switch (mode) {
                'quota' => 'image_quota_exceeded',
                'paused' => 'image_uploads_paused',
                _ => 'image_file_too_large',
              },
            },
          }),
          mode == 'file-limit' ? 413 : 409,
          headers: {'content-type': 'application/json'},
        ),
      );
      final api = ClipbackApi(client: client)
        ..restoreSession(
          const ApiSession(
            accessToken: 'local-renderer-access',
            refreshToken: 'local-renderer-refresh',
            expiresIn: 3600,
            refreshExpiresIn: 86400,
          ),
        );
      try {
        await api.uploadScreenshot(bytes: bytes!, filename: filename!);
      } finally {
        client.close();
      }
      throw StateError('An image policy rejection unexpectedly succeeded');
    }
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
  title: _resultScreenMode ? _screenResultTitle : '저장 결과 확인',
  summary: '고정 대역 데이터',
  category: _resultScreenMode && _categoryState != 'classified'
      ? catUncategorized
      : catUncategorized.copyWith(
          name: _resultScreenMode ? '영감을 모아둔 카테고리' : '매일 다시 확인하는 아주 긴 카테고리 이름',
          color: _resultScreenMode ? AppColors.main : catUncategorized.color,
        ),
  savedAt: '10.15',
  savedAtFull: '2026.10.15',
  savedAtFullShort: '26.10.15',
  tags: const [],
  source: _resultScreenMode && _categoryState == 'processing'
      ? sourceLabel('youtube')
      : kind == 'photo'
      ? '사진'
      : '웹사이트',
  originalUrl: kind == 'link' ? _url : '',
  originalText: '',
  isScreenshot: kind == 'photo',
  summaryStatus: _resultScreenMode && _categoryState == 'processing'
      ? 'processing'
      : 'not_requested',
);

Future<Uint8List> _markerPhoto(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF557799));
  final corner = size.shortestSide * .18;
  final markers = <(Rect, Color)>[
    (Rect.fromLTWH(0, 0, corner, corner), const Color(0xFFFF0000)),
    (
      Rect.fromLTWH(size.width - corner, 0, corner, corner),
      const Color(0xFF00FF00),
    ),
    (
      Rect.fromLTWH(0, size.height - corner, corner, corner),
      const Color(0xFF0000FF),
    ),
    (
      Rect.fromLTWH(size.width - corner, size.height - corner, corner, corner),
      const Color(0xFFFFFF00),
    ),
  ];
  for (final (rect, color) in markers) {
    canvas.drawRect(rect, Paint()..color = color);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}

class _Picker extends FilePicker {
  _Picker(this.photo, this.alternate)
    : originalPhoto = photo,
      originalAlternate = alternate;
  Uint8List photo;
  Uint8List alternate;
  final Uint8List originalPhoto;
  final Uint8List originalAlternate;
  void useCase(String value) {
    _require(_photoCases.containsKey(value), 'Unsupported photoCase');
    _photoCase = value;
    photo = _photoCases[value]!;
    alternate = value == 'landscape' ? _photoCases['tall']! : originalAlternate;
  }

  int calls = 0;
  bool cancelNext = false;
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
    if (cancelNext) {
      cancelNext = false;
      return null;
    }
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
  _scene = '${_sceneName(kind, scale)}_$mode';
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
  if (kind == 'photo' || kind == 'photo-empty' || kind == 'photo-selected') {
    await _tapText('사진 첨부');
    if (kind != 'photo-empty') await _selectPhoto();
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

bool _isResult(String kind) => kind == 'link' || kind == 'photo';

double _requestedScale(Uri uri) {
  final scale = double.parse(uri.queryParameters['scale'] ?? '1');
  _require(scale == 1 || scale == 1.5 || scale == 2, 'Unsupported scale');
  return scale;
}

ScrollPosition get _bodyPosition =>
    (_first<SingleChildScrollView>().widget as SingleChildScrollView)
        .controller!
        .position;

Future<void> _scrollToMax() async {
  _bodyPosition.jumpTo(_bodyPosition.maxScrollExtent);
  await _settle();
}

Future<double> _showKeyboard() async {
  await _tap(_rect(_first<EditableText>()).center);
  var previous = -1.0;
  var stable = 0;
  for (var attempt = 0; attempt < 30; attempt++) {
    await _settle(2);
    final current = MediaQuery.of(_first<AddContentSheet>()).viewInsets.bottom;
    stable = current > 0 && (current - previous).abs() < 0.1 ? stable + 1 : 0;
    previous = current;
    if (stable >= 3) break;
  }
  await _type(_url);
  return MediaQuery.of(_first<AddContentSheet>()).viewInsets.bottom;
}

String _sceneName(String kind, double scale) =>
    '${kind.replaceAll('-', '_')}_scale_${scale.toString().replaceAll('.0', '').replaceAll('.', '_')}';

Element _ancestor(Element element, bool Function(Widget) matches) {
  Element? result;
  element.visitAncestorElements((candidate) {
    if (matches(candidate.widget)) {
      result = candidate;
      return false;
    }
    return true;
  });
  return result!;
}

Element? _keyed(String key, [Element? root]) => _elements(
  root,
).where((e) => e.widget.key == ValueKey<String>(key)).firstOrNull;

Element? _imageIn(Element? root) => root == null
    ? null
    : _elements(root).where((e) => e.widget is Image).firstOrNull;

Map<String, Object?> _paintMetrics(Decoration? decoration, Element element) {
  if (decoration is! BoxDecoration) return {};
  final radius = decoration.borderRadius?.resolve(Directionality.of(element));
  final border = decoration.border;
  return {
    'color': _colorArgb(decoration.color),
    'radius': radius == null
        ? null
        : {
            'topLeft': radius.topLeft.x,
            'topRight': radius.topRight.x,
            'bottomLeft': radius.bottomLeft.x,
            'bottomRight': radius.bottomRight.x,
          },
    'border': border is Border
        ? {
            for (final entry in {
              'top': border.top,
              'right': border.right,
              'bottom': border.bottom,
              'left': border.left,
            }.entries)
              entry.key: {
                'width': entry.value.width,
                'color': _colorArgb(entry.value.color),
                'style': entry.value.style.name,
              },
          }
        : null,
    'isSubtlerOnePixelBorder': border == Border.all(color: AppColors.subtler),
  };
}

Map<String, Object?> _containerPaintMetrics(Element element) {
  final widget = element.widget as Container;
  final padding = widget.padding?.resolve(Directionality.of(element));
  return {
    'bounds': _rectJson(_rect(element)),
    'padding': padding == null
        ? null
        : {
            'left': padding.left,
            'right': padding.right,
            'top': padding.top,
            'bottom': padding.bottom,
          },
    'background': _paintMetrics(widget.decoration, element),
    'foreground': _paintMetrics(widget.foregroundDecoration, element),
  };
}

Map<String, Element> _layoutNodes() {
  final nodes = <String, Element>{};
  if (_has<AddContentSheet>()) {
    nodes['bodyViewport'] = _first<SingleChildScrollView>();
    nodes['button'] = _first<SaveFlowButton>();
    if (_has<SaveErrorToast>()) nodes['toast'] = _first<SaveErrorToast>();
    final body = _has<SavedContentConfirmation>()
        ? _first<SavedContentConfirmation>()
        : _has<PhotoSaveBody>()
        ? _first<PhotoSaveBody>()
        : _first<LinkSaveBody>();
    nodes['bodyContent'] = body;
    if (_has<SavedContentConfirmation>()) {
      nodes['lastBody'] = _elements(body).lastWhere((e) => e.widget is Text);
    } else if (_has<PhotoSaveBody>()) {
      nodes['lastBody'] = _elements(
        body,
      ).firstWhere((e) => e.widget is InkWell);
    } else if (_has<ValidationMessage>()) {
      nodes['lastBody'] = _first<ValidationMessage>();
    } else {
      nodes['lastBody'] = _first<EditableText>();
    }
  }
  if (_has<LinkSaveBody>()) {
    final body = _first<LinkSaveBody>();
    final pasteText = _elements(
      body,
    ).firstWhere((e) => e.widget is Text && (e.widget as Text).data == '붙여넣기');
    final pasteButton = _ancestor(pasteText, (w) => w is TextButton);
    final field = _elements(body).firstWhere((e) => e.widget is TextField);
    nodes['linkInputRow'] = _ancestor(pasteButton, (w) => w is Row);
    nodes['urlInputBox'] = field;
    nodes['urlEditable'] = _first<EditableText>();
    nodes['pasteButton'] = pasteButton;
    nodes['pasteParagraph'] = pasteText;
    nodes['pastePaint'] = _elements(
      pasteButton,
    ).firstWhere((e) => e.widget is Material);
    final validation = _elements(
      body,
    ).where((e) => e.widget is ValidationMessage).firstOrNull;
    if (validation != null) nodes['validationMessage'] = validation;
    final clear = _elements(
      body,
    ).where((e) => e.widget is IconButton).firstOrNull;
    if (clear != null) {
      nodes['clearButton'] = clear;
      final icon = _elements(clear)
          .where((e) => e.widget.runtimeType.toString() == 'SvgPicture')
          .firstOrNull;
      if (icon != null) nodes['clearIcon'] = icon;
    }
  }
  if (_has<PhotoEmptyPrompt>()) {
    final prompt = _first<PhotoEmptyPrompt>();
    final title = _elements(
      prompt,
    ).firstWhere((e) => e.widget is Text && (e.widget as Text).data == '사진 선택');
    nodes['emptyPrompt'] = prompt;
    nodes['emptyTitle'] = title;
    nodes['emptyDescription'] = _elements(prompt).firstWhere(
      (e) =>
          e.widget is Text &&
          (e.widget as Text).data == '앨범에서 선택하거나 스크린샷을 업로드해 주세요.',
    );
    nodes['emptyText'] = _ancestor(title, (w) => w is Column);
    nodes['emptyIcon'] = _elements(prompt).firstWhere(
      (e) =>
          e.widget is SizedBox &&
          (e.widget as SizedBox).width == 40 &&
          (e.widget as SizedBox).height == 40,
    );
  }
  if (_has<SelectedPhotoPreview>()) {
    final preview = _first<SelectedPhotoPreview>();
    final outer = _elements(preview).firstWhere((e) => e.widget is Container);
    final innerWidget = (outer.widget as Container).child!;
    nodes['photoFrameOuter'] = outer;
    nodes['photoFrameInner'] = _elements(
      outer,
    ).firstWhere((e) => identical(e.widget, innerWidget));
    for (final entry in <String, bool Function(Widget)>{
      'photoFrameClip': (w) => w is ClipRect,
      'photoFrameImage': (w) => w is Image,
    }.entries) {
      nodes[entry.key] = _elements(
        preview,
      ).firstWhere((e) => entry.value(e.widget));
    }
  }
  if (_has<SavedContentConfirmation>()) {
    final result = _first<SavedContentConfirmation>();
    final confirmation = result.widget as SavedContentConfirmation;
    final content = confirmation.content;
    final label = confirmation.originalUrl.isEmpty
        ? content.originalUrl
        : confirmation.originalUrl;
    final labelElement = _elements(result)
        .where((e) => e.widget is Text && (e.widget as Text).data == label)
        .firstOrNull;
    final summaryKey = confirmation.photoBytes != null
        ? 'save-result-photo-summary'
        : 'save-result-input-summary';
    nodes['resultInputBox'] =
        _keyed(summaryKey, result) ??
        _ancestor(labelElement!, (w) => w is Container);
    nodes['resultSummary'] = nodes['resultInputBox']!;
    final summaryImage = _imageIn(_keyed('save-result-photo-image', result));
    if (summaryImage != null) nodes['resultSummaryImage'] = summaryImage;
    nodes['previewPrecedingBlock'] = confirmation.photoBytes != null
        ? nodes['resultInputBox']!
        : _elements(result).firstWhere((e) => e.widget is ValidationMessage);
    final image =
        _imageIn(_keyed('save-result-preview-image', result)) ??
        _elements(result).firstWhere((e) => e.widget is Image);
    final title = _elements(result).firstWhere(
      (e) => e.widget is Text && (e.widget as Text).data == content.title,
    );
    nodes['previewCard'] =
        _keyed('save-result-preview-card', result) ??
        _ancestor(image, (w) => w is Container);
    nodes['previewHeading'] = _textElement('미리보기', result);
    nodes['previewImage'] = image;
    nodes['previewTitle'] = title;
    nodes['previewSource'] = _elements(result).firstWhere(
      (e) => e.widget is Text && (e.widget as Text).data == content.source,
    );
    nodes['previewText'] = _ancestor(title, (w) => w is Column);
    final processingLink =
        (content.source == sourceLabel('youtube') ||
            content.source == sourceLabel('instagram')) &&
        (content.summaryStatus == 'queued' ||
            content.summaryStatus == 'processing');
    final categoryMessage = processingLink
        ? '링크 정보를 처리 중이에요. 분류는 나중에 반영될 수 있어요.'
        : content.category.name == catUncategorized.name
        ? '아직 분류되지 않았어요.'
        : '저장된 카테고리';
    nodes['categoryHeading'] = _textElement('카테고리', result);
    nodes['categoryMessage'] = _textElement(categoryMessage, result);
    nodes['categoryName'] = _textElement(content.category.name, result);
    nodes['categoryRow'] =
        _keyed('save-result-category-row', result) ??
        _ancestor(nodes['categoryName']!, (w) => w is Container);
    nodes['categoryFolder'] =
        _keyed('save-result-category-folder', result) ??
        _elements(
          nodes['categoryRow']!,
        ).firstWhere((e) => e.widget is FolderGlyph);
    nodes['categoryText'] =
        _keyed('save-result-category-heading', result) ??
        _ancestor(nodes['categoryHeading']!, (w) => w is Column);
    nodes['categoryEditHint'] = _textElement('분류는 상세 화면에서 변경할 수 있어요.', result);
  }
  return nodes;
}

Map<String, Object?> _geometry() => _layoutNodes().map((name, element) {
  final rect = _rect(element);
  final text = element.widget is Text ? element.widget as Text : null;
  final render = element.findRenderObject();
  return MapEntry(name, {
    'left': rect.left,
    'top': rect.top,
    'right': rect.right,
    'bottom': rect.bottom,
    'width': rect.width,
    'height': rect.height,
    if (text != null) ...{
      'fontSize': text.style?.fontSize,
      'scaledFontSize':
          render is RenderParagraph && text.style?.fontSize != null
          ? render.textScaler.scale(text.style!.fontSize!)
          : null,
      'maxLines': text.maxLines,
      'overflow': text.overflow?.name,
    },
  });
});

bool _inside(Rect inner, Rect outer) =>
    inner.left >= outer.left - 0.1 &&
    inner.top >= outer.top - 0.1 &&
    inner.right <= outer.right + 0.1 &&
    inner.bottom <= outer.bottom + 0.1;

void _checkScene(String kind, double scale) {
  if (!_isResult(kind)) {
    _require(!_has<SavedContentConfirmation>(), 'Input scene became a result');
    _require(_appKey.currentState!.calls == 0, 'Input scene submitted');
    if (kind == 'photo-empty') {
      _require(_has<PhotoEmptyPrompt>(), 'Photo empty prompt missing');
    } else if (kind == 'photo-selected') {
      _require(_has<SelectedPhotoPreview>(), 'Selected photo missing');
      _require(_picker.calls == 1, 'Selected photo picker count changed');
    } else {
      _require(_has<LinkSaveBody>(), 'Link input missing');
      _require(
        (_first<EditableText>().widget as EditableText).controller.text == _url,
        'Link draft changed',
      );
    }
  } else {
    _require(_has<SavedContentConfirmation>(), 'Save result missing');
    _require(
      _text(kind == 'photo' ? '저장할 사진' : '저장할 링크'),
      'Wrong result title',
    );
    _require(_text('유효한 링크예요!') == (kind == 'link'), 'Wrong link validation');
    final result =
        _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
    _require(
      result.originalUrl == (kind == 'photo' ? 'save-result.png' : _url),
      'Result label differs from submission',
    );
    _require(
      (result.photoBytes != null) == (kind == 'photo'),
      'Result kind differs from submission',
    );
    _require(
      _snapshot()['selectedTab'] == (kind == 'photo' ? '사진 첨부' : '링크 첨부'),
      'Wrong selected tab',
    );
  }
  _checkFooter();
  if (_phase != 'after') return;
  final nodes = _layoutNodes();
  if (kind == 'photo-empty') {
    final prompt = _rect(nodes['emptyPrompt']!);
    _require(prompt.height >= 88.9, 'Empty prompt below minimum height');
    if (scale == 1) {
      _require(
        (prompt.height - 89).abs() < 0.1,
        'Base empty prompt height changed',
      );
    }
    final icon = _rect(nodes['emptyIcon']!);
    _require(
      (icon.width - 40).abs() < 0.1 && (icon.height - 40).abs() < 0.1,
      'Empty prompt icon changed',
    );
    for (final name in ['emptyTitle', 'emptyDescription', 'emptyText']) {
      _require(_inside(_rect(nodes[name]!), prompt), '$name clips prompt');
    }
  } else if (_isResult(kind)) {
    final card = _rect(nodes['previewCard']!);
    final image = _rect(nodes['previewImage']!);
    final text = _rect(nodes['previewText']!);
    _require(card.height >= 115.9, 'Preview below minimum height');
    if (scale == 1) {
      _require((card.height - 116).abs() < 0.1, 'Base preview height changed');
    }
    _require(
      (image.width - 164).abs() < 0.1 && (image.height - 100).abs() < 0.1,
      'Preview thumbnail changed',
    );
    _require(
      (image.center.dy - card.center.dy).abs() < 0.1,
      'Preview image is not centered',
    );
    _require(
      (text.center.dy - card.center.dy).abs() < 0.1,
      'Preview text is not centered',
    );
    final inner = card.deflate(8);
    for (final name in ['previewImage', 'previewTitle', 'previewSource']) {
      _require(_inside(_rect(nodes[name]!), inner), '$name clips preview');
    }
  }
}

Map<String, Object?> _footerMetrics() {
  if (!_has<AddContentSheet>()) return {};
  final media = MediaQuery.of(_first<AddContentSheet>());
  final nodes = _layoutNodes();
  final button = _rect(nodes['button']!);
  final viewport = _rect(nodes['bodyViewport']!);
  final last = _rect(nodes['lastBody']!);
  final toast = nodes['toast'] == null ? null : _rect(nodes['toast']!);
  final physicalBottom = _view.physicalSize.height / _view.devicePixelRatio;
  final inset = media.viewInsets.bottom > media.viewPadding.bottom
      ? media.viewInsets.bottom
      : media.viewPadding.bottom;
  return {
    'reservedBottomInset': inset,
    'buttonBottomGap': physicalBottom - button.bottom,
    'expectedButtonBottomGap': 32 + inset,
    'keyboardTop': physicalBottom - media.viewInsets.bottom,
    'buttonCoveredByKeyboard':
        media.viewInsets.bottom > 0 &&
        button.bottom > physicalBottom - media.viewInsets.bottom + 0.1,
    'viewportToButton': button.top - viewport.bottom,
    'viewportToToast': toast == null ? null : toast.top - viewport.bottom,
    'toastToButton': toast == null ? null : button.top - toast.bottom,
    'lastBodyFullyVisible': _inside(last, viewport),
    'lastBodyBottomVisible':
        last.bottom <= viewport.bottom + 0.1 && last.bottom > viewport.top,
    'atMaximumScroll':
        (_bodyPosition.pixels - _bodyPosition.maxScrollExtent).abs() < 0.1,
    'hasAppHomeIndicator': _elements().any(
      (e) => e.widget.runtimeType.toString() == '_SaveHomeIndicator',
    ),
  };
}

List<String> _footerFindings({bool atMaximum = false}) {
  if (!_has<AddContentSheet>()) return [];
  final findings = <String>[];
  final nodes = _layoutNodes();
  final button = _rect(nodes['button']!);
  final viewport = _rect(nodes['bodyViewport']!);
  final metrics = _footerMetrics();
  if (((metrics['buttonBottomGap'] as double) -
              (metrics['expectedButtonBottomGap'] as double))
          .abs() >
      0.5) {
    findings.add(
      'Button bottom differs from 32 + max(viewInsets, viewPadding)',
    );
  }
  if ((button.height - 56).abs() > 0.1 ||
      (button.left - viewport.left - 16).abs() > 0.1 ||
      (viewport.right - button.right - 16).abs() > 0.1) {
    findings.add('Button size/margins changed');
  }
  if (viewport.bottom > button.top + 0.1) {
    findings.add(
      'Body viewport overlaps button by ${viewport.bottom - button.top}px',
    );
  }
  if (metrics['hasAppHomeIndicator'] == true) {
    findings.add('Fake app home indicator remains');
  }
  if (metrics['buttonCoveredByKeyboard'] == true) {
    findings.add('Button is covered by OS keyboard');
  }
  if (nodes['toast'] case final Element toastElement) {
    final toast = _rect(toastElement);
    if ((button.top - toast.bottom - 16).abs() > 0.1 ||
        (toast.left - viewport.left - 40).abs() > 0.1 ||
        (viewport.right - toast.right - 40).abs() > 0.1) {
      findings.add('Toast spacing/margins changed');
    }
    if (viewport.bottom > toast.top + 0.1) {
      findings.add(
        'Body viewport overlaps toast by ${viewport.bottom - toast.top}px',
      );
    }
  }
  if (atMaximum || metrics['atMaximumScroll'] == true) {
    final last = _rect(nodes['lastBody']!);
    if (last.bottom > viewport.bottom - 23.9 || last.bottom < viewport.top) {
      findings.add(
        'Last body does not remain visible above bottom 24px padding',
      );
    }
    if (last.height <= viewport.height - 24 && !_inside(last, viewport)) {
      findings.add('Last body clips at maximum scroll');
    }
  }
  return findings;
}

void _checkFooter({bool atMaximum = false}) {
  final findings = _footerFindings(atMaximum: atMaximum);
  if (_phase == 'after') {
    _require(findings.isEmpty, 'Footer: ${findings.join('; ')}');
  }
}

Map<String, double> _rectJson(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'right': rect.right,
  'bottom': rect.bottom,
  'width': rect.width,
  'height': rect.height,
};

List<Rect> _pasteLineRects() {
  if (!_has<LinkSaveBody>()) return [];
  final element = _layoutNodes()['pasteParagraph']!;
  final render = element.findRenderObject()! as RenderParagraph;
  final length = render.text.toPlainText().length;
  return render
      .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length))
      .map((box) => box.toRect().shift(render.localToGlobal(Offset.zero)))
      .toList();
}

String? _colorArgb(Color? color) => color == null
    ? null
    : '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

Map<String, Object?> _pasteStyleMetrics() {
  if (!_has<LinkSaveBody>()) return {};
  final nodes = _layoutNodes();
  final buttonElement = nodes['pasteButton']!;
  final button = buttonElement.widget as TextButton;
  final ink = _elements(
    buttonElement,
  ).where((e) => e.widget is InkWell).firstOrNull;
  final states = Set<WidgetState>.of(
    (ink?.widget as InkWell?)?.statesController?.value ??
        button.statesController?.value ??
        {if (button.onPressed == null) WidgetState.disabled},
  );
  final widgetStyle = button.style;
  final themeStyle = TextButtonTheme.of(buttonElement).style;
  T? resolve<T>(WidgetStateProperty<T?>? own, WidgetStateProperty<T?>? theme) =>
      own?.resolve(states) ?? theme?.resolve(states);
  final materialElement = nodes['pastePaint']!;
  final material = materialElement.widget as Material;
  final paragraph =
      nodes['pasteParagraph']!.findRenderObject()! as RenderParagraph;
  final effectiveText = (paragraph.text as TextSpan).style!;
  final shape = material.shape;
  final side =
      resolve<BorderSide>(widgetStyle?.side, themeStyle?.side) ??
      (shape is OutlinedBorder ? shape.side : null);
  final radius = shape is RoundedRectangleBorder
      ? shape.borderRadius.resolve(Directionality.of(materialElement))
      : null;
  final paintBox = materialElement.findRenderObject()! as RenderBox;
  final localPaint = Offset.zero & paintBox.size;
  final offset = paintBox.localToGlobal(Offset.zero);
  final outer = shape
      ?.getOuterPath(
        localPaint,
        textDirection: Directionality.of(materialElement),
      )
      .getBounds()
      .shift(offset);
  final inner = shape
      ?.getInnerPath(
        localPaint,
        textDirection: Directionality.of(materialElement),
      )
      .getBounds()
      .shift(offset);
  final resolvedText = resolve<TextStyle>(
    widgetStyle?.textStyle,
    themeStyle?.textStyle,
  );
  return {
    'widgetStates': states.map((state) => state.name).toList()..sort(),
    'enabled': button.onPressed != null,
    'backgroundColor': _colorArgb(
      resolve<Color>(
            widgetStyle?.backgroundColor,
            themeStyle?.backgroundColor,
          ) ??
          material.color,
    ),
    'foregroundColor': _colorArgb(
      resolve<Color>(
            widgetStyle?.foregroundColor,
            themeStyle?.foregroundColor,
          ) ??
          effectiveText.color,
    ),
    'paintBackgroundColor': _colorArgb(material.color),
    'paintForegroundColor': _colorArgb(effectiveText.color),
    'sideWidth': side?.width,
    'sideColor': _colorArgb(side?.color),
    'sideStyle': side?.style.name,
    'shapeType': shape.runtimeType.toString(),
    'radius': {
      'topLeft': radius?.topLeft.x,
      'topRight': radius?.topRight.x,
      'bottomLeft': radius?.bottomLeft.x,
      'bottomRight': radius?.bottomRight.x,
    },
    'fontFamily': effectiveText.fontFamily,
    'resolvedTextStyleFontFamily': resolvedText?.fontFamily,
    'fontSize': effectiveText.fontSize,
    'fontWeight': effectiveText.fontWeight?.value,
    'letterSpacing': effectiveText.letterSpacing,
    'paintArea': _rectJson(_rect(materialElement)),
    'paintBounds': outer == null ? null : _rectJson(outer),
    'innerPaintBounds': inner == null ? null : _rectJson(inner),
    'resolutionScope':
        'Widget/theme ButtonStyle resolved with live InkWell states; actual Material paint and RenderParagraph effective style recorded separately',
  };
}

List<String> _pasteStyleFindings() {
  if (!_has<LinkSaveBody>()) return [];
  final findings = <String>[];
  final style = _pasteStyleMetrics();
  if (style['backgroundColor'] != '0xFFFFFFFF' ||
      style['paintBackgroundColor'] != '0xFFFFFFFF') {
    findings.add('Paste background must resolve and paint surface #FFFFFFFF');
  }
  if (style['foregroundColor'] != '0xFF767676' ||
      style['paintForegroundColor'] != '0xFF767676') {
    findings.add('Paste foreground must resolve and paint subtle #FF767676');
  }
  if (style['sideWidth'] != 1 ||
      style['sideColor'] != '0xFFD1D1D1' ||
      style['sideStyle'] != 'solid') {
    findings.add('Paste border must be 1px solid subtler #FFD1D1D1');
  }
  final radius = style['radius'] as Map<String, Object?>;
  if (radius.values.any((value) => value != 4)) {
    findings.add('Paste border radii must remain 4px');
  }
  if (style['fontFamily'] != 'Pretendard' ||
      style['fontSize'] != 14 ||
      style['fontWeight'] != 500 ||
      style['letterSpacing'] != -0.35) {
    findings.add(
      'Paste effective text must be Pretendard 14px Medium with -0.35px spacing',
    );
  }
  if (style['enabled'] != true) {
    findings.add(
      'Paste action must remain enabled in empty/invalid/valid states',
    );
  }
  return findings;
}

Map<String, Object?> _pasteMetrics() {
  if (!_has<LinkSaveBody>()) return {};
  final nodes = _layoutNodes();
  final render =
      nodes['pasteParagraph']!.findRenderObject()! as RenderParagraph;
  final style = (render.text as TextSpan).style!;
  final lines = _pasteLineRects();
  final editable = _first<EditableText>().widget as EditableText;
  final controller = editable.controller;
  return {
    'fullText': render.text.toPlainText(),
    'style': _pasteStyleMetrics(),
    'fontFamily': style.fontFamily,
    'fontSize': style.fontSize,
    'scaledFontSize': render.textScaler.scale(style.fontSize!),
    'fontWeight': style.fontWeight?.value,
    'letterSpacing': style.letterSpacing,
    'maxLines': render.maxLines,
    'didExceedMaxLines': render.didExceedMaxLines,
    'lineCount': lines.length,
    'lineBoxes': lines.map(_rectJson).toList(),
    'paragraphCenterDelta':
        _rect(nodes['pasteParagraph']!).center.dy -
        _rect(nodes['pasteButton']!).center.dy,
    'editableMaxLines': editable.maxLines,
    'editableFontSize': editable.style.fontSize,
    'editableScaledFontSize': MediaQuery.of(
      nodes['urlEditable']!,
    ).textScaler.scale(editable.style.fontSize!),
    'editableCenterDelta':
        _rect(nodes['urlEditable']!).center.dy -
        _rect(nodes['urlInputBox']!).center.dy,
    'inputRowCenterDelta':
        _rect(nodes['urlInputBox']!).center.dy -
        _rect(nodes['linkInputRow']!).center.dy,
    'clearCenterDelta': nodes['clearButton'] == null
        ? null
        : _rect(nodes['clearButton']!).center.dy -
              _rect(nodes['urlInputBox']!).center.dy,
    'draft': controller.text,
    'stage': (_first<LinkSaveBody>().widget as LinkSaveBody).stage.name,
    'validationGap': nodes['validationMessage'] == null
        ? null
        : _rect(nodes['validationMessage']!).top -
              _rect(nodes['linkInputRow']!).bottom,
    'selectionBase': controller.selection.baseOffset,
    'selectionExtent': controller.selection.extentOffset,
    'clipboardSetupScope': _baseStyleMode
        ? _baseInputSetupScope
        : 'Mobile app Clipboard.setData only; no host clipboard API',
  };
}

List<String> _pasteFindings() {
  if (!_has<LinkSaveBody>()) return [];
  final findings = <String>[];
  final nodes = _layoutNodes();
  final metrics = _pasteMetrics();
  final button = _rect(nodes['pasteButton']!);
  final row = _rect(nodes['linkInputRow']!);
  final field = _rect(nodes['urlInputBox']!);
  final paragraph = _rect(nodes['pasteParagraph']!);
  final scale = MediaQuery.of(nodes['pasteParagraph']!).textScaler.scale(1);
  if (metrics['fullText'] != '붙여넣기' || metrics['didExceedMaxLines'] == true) {
    findings.add('Paste label is incomplete or exceeds maxLines');
  }
  if (metrics['fontSize'] != 14 ||
      metrics['fontWeight'] != 500 ||
      metrics['letterSpacing'] != -0.35 ||
      ((metrics['scaledFontSize'] as double) - 14 * scale).abs() > 0.1) {
    findings.add('Paste font or actual text scale changed');
  }
  final lines = _pasteLineRects();
  if (lines.isEmpty || lines.length > 2) {
    findings.add('Paste label must use one or two actual rendered lines');
  }
  for (var i = 0; i < lines.length; i++) {
    if (!_inside(lines[i], button)) {
      findings.add('Paste actual line ${i + 1} clips button');
    }
  }
  if (!_inside(paragraph, button) ||
      (paragraph.center.dy - button.center.dy).abs() > 0.1) {
    findings.add('Paste paragraph is clipped or not vertically centered');
  }
  if ((button.width - 64).abs() > 0.1 ||
      button.height < 43.9 ||
      (scale == 1 && (button.height - 44).abs() > 0.1)) {
    findings.add('Paste width/minimum/base height changed');
  }
  if (field.height < 43.9 ||
      (field.height - button.height).abs() > 0.1 ||
      (scale == 1 && (field.height - 44).abs() > 0.1) ||
      (field.center.dy - row.center.dy).abs() > 0.1 ||
      (button.center.dy - row.center.dy).abs() > 0.1 ||
      (button.left - field.right - 8).abs() > 0.1) {
    findings.add(
      'URL/paste common natural height, base/minimum, row center, or 8px gap changed',
    );
  }
  if (!_inside(_rect(nodes['urlEditable']!), field) ||
      (_rect(nodes['urlEditable']!).center.dy - field.center.dy).abs() > 0.1 ||
      metrics['editableMaxLines'] != 1 ||
      metrics['editableFontSize'] != 14 ||
      ((metrics['editableScaledFontSize'] as double) - 14 * scale).abs() >
          0.1) {
    findings.add(
      'URL EditableText clips input, loses center/one line, or changes font scale',
    );
  }
  if (nodes['clearButton'] case final Element clear) {
    if ((_rect(clear).width - 48).abs() > 0.1 ||
        (_rect(clear).height - 44).abs() > 0.1 ||
        !_inside(_rect(clear), field) ||
        (_rect(clear).center.dy - field.center.dy).abs() > 0.1) {
      findings.add('Clear button clips input or is not centered');
    }
  }
  if (nodes['clearIcon'] case final Element icon) {
    if ((_rect(icon).width - 18).abs() > 0.1 ||
        (_rect(icon).height - 18).abs() > 0.1 ||
        !_inside(_rect(icon), field)) {
      findings.add('Clear icon size or input containment changed');
    }
  }
  if (nodes['validationMessage'] != null &&
      ((metrics['validationGap'] as double) - 5).abs() > 0.1) {
    findings.add('Validation message must remain 5px below input row');
  }
  if (metrics['maxLines'] != 2) {
    findings.add('Paste label must explicitly allow at most two lines');
  }
  final paint = _rect(nodes['pastePaint']!);
  if (!_inside(paint, button) ||
      (paint.width - button.width).abs() > 0.1 ||
      (paint.height - button.height).abs() > 0.1) {
    findings.add('Paste painted area must match the button bounds');
  }
  return findings;
}

void _checkPaste() {
  if (_phase == 'after') {
    final findings = _pasteFindings();
    _require(findings.isEmpty, 'Paste layout: ${findings.join('; ')}');
    final styleFindings = _pasteStyleFindings();
    _require(styleFindings.isEmpty, 'Paste style: ${styleFindings.join('; ')}');
  }
}

String _pasteSceneName(double scale, bool keyboard, {String kind = 'valid'}) =>
    'paste_${kind == 'valid' ? '' : '${kind}_'}scale_${scale.toString().replaceAll('.0', '').replaceAll('.', '_')}_keyboard_${keyboard ? 1 : 0}';

Future<void> _pasteFromMobileClipboard(
  String text, {
  bool waitForAndroidPreview = false,
}) async {
  _require(
    Platform.isIOS || Platform.isAndroid,
    'Clipboard fixture is restricted to mobile simulators/emulators',
  );
  await Clipboard.setData(ClipboardData(text: text));
  if (waitForAndroidPreview && Platform.isAndroid) {
    // The native Android 13 clipboard overlay can temporarily own focus. Let
    // it expire naturally before the single base-style behavior paste tap.
    await Future<void>.delayed(const Duration(seconds: 8));
  }
  await _tap(_rect(_layoutNodes()['pasteButton']!).center);
  await _settle(9);
}

Future<void> _pasteScene({
  required double scale,
  required bool keyboard,
  String kind = 'valid',
}) async {
  _require(
    const ['valid', 'empty', 'invalid'].contains(kind),
    'Unsupported paste input kind',
  );
  _require(
    kind == 'valid' || (scale == 1 && !keyboard),
    'Empty/invalid comparison scenes use base scale without keyboard',
  );
  await _open('link-input', scale: scale);
  if (keyboard) {
    final shown = await _showKeyboard();
    _require(shown > 0, 'Paste scene did not measure an OS keyboard inset');
  }
  await _type('');
  final draft = kind == 'valid'
      ? _url
      : kind == 'invalid'
      ? 'invalid-link'
      : '';
  await _pasteFromMobileClipboard(draft);
  final controller = (_first<EditableText>().widget as EditableText).controller;
  _require(
    controller.text == draft,
    'Actual paste button did not retain the mobile clipboard state',
  );
  // Pin the comparison cursor after the real paste; this does not validate or
  // change product selection policy. Both phases use the same end position.
  controller.selection = TextSelection.collapsed(offset: draft.length);
  _bodyPosition.jumpTo(0);
  await _settle();
  _scene = _pasteSceneName(scale, keyboard, kind: kind);
  if (kind == 'valid') {
    _require(_text('유효한 링크예요!'), 'Pasted URL did not validate');
  } else if (kind == 'invalid') {
    _require(_text('유효하지 않은 링크예요.'), 'Invalid paste did not validate');
  } else {
    _require(!_has<ValidationMessage>(), 'Empty draft unexpectedly validated');
  }
  _require(
    (_first<SaveFlowButton>().widget as SaveFlowButton).enabled ==
        (kind == 'valid'),
    'Save enabled state differs from input kind',
  );
  _require(_appKey.currentState!.calls == 0, 'Paste unexpectedly submitted');
  _checkFooter();
  _checkPaste();
}

Future<void> _pasteRun() async {
  _checksCompleted = false;
  for (final scale in [1.0, 1.5, 2.0]) {
    for (final keyboard in [false, true]) {
      await _pasteScene(scale: scale, keyboard: keyboard);
      await _capture(_pasteSceneName(scale, keyboard));
      final controller =
          (_first<EditableText>().widget as EditableText).controller;
      await _type('invalid-link');
      _require(_text('유효하지 않은 링크예요.'), 'Typing did not run invalid validation');
      _checkPaste();
      await _tap(_rect(_layoutNodes()['clearButton']!).center);
      _require(
        controller.text.isEmpty && !_has<ValidationMessage>(),
        'Clear did not restore empty editing state',
      );
      _require(
        !(_first<SaveFlowButton>().widget as SaveFlowButton).enabled,
        'Cleared input still enables save',
      );
      await _pasteFromMobileClipboard('   $_url   ');
      _require(
        controller.text == _url && _text('유효한 링크예요!'),
        'Paste did not trim and validate URL',
      );
      await _scrollToMax();
      _checkFooter(atMaximum: true);
      _checkPaste();
      _appKey.currentState!.mode = 'fail';
      await _save();
      _require(
        _has<SaveErrorToast>() &&
            !_has<SavedContentConfirmation>() &&
            identical(
              (_first<EditableText>().widget as EditableText).controller,
              controller,
            ) &&
            controller.text == _url,
        'Paste failure replaced input/controller',
      );
      _checkFooter();
      _checkPaste();
      _checks.add({
        'scenario': '${_pasteSceneName(scale, keyboard)}_failure',
        'passed': true,
        ..._snapshot(),
      });
      _appKey.currentState!.mode = 'success';
      await _save();
      _require(
        _has<SavedContentConfirmation>() &&
            _appKey.currentState!.calls == 2 &&
            _appKey.currentState!.submissions.every((s) => s['url'] == _url),
        'Paste retry did not submit original trimmed URL',
      );
      await _tapText('사진 첨부');
      _require(
        _snapshot()['selectedTab'] == '링크 첨부',
        'Paste result tab is not pinned',
      );
      if (_bodyPosition.maxScrollExtent > 0) {
        await _drag(const Offset(0, -180));
        _require(
          _bodyPosition.pixels > 0,
          'Pasted result did not respond to drag',
        );
      }
      await _scrollToMax();
      _checkFooter(atMaximum: true);
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await _settle(12);
      _require(
        MediaQuery.of(_first<AddContentSheet>()).viewInsets.bottom == 0,
        'Paste flow keyboard did not hide',
      );
      await _tapText('닫기');
      _require(!_has<AddContentSheet>(), 'Paste flow close failed');
      _checks.add({
        'scenario':
            '${_pasteSceneName(scale, keyboard)}_type_clear_retry_close',
        'passed': true,
      });
    }
  }
  for (final kind in ['empty', 'invalid']) {
    await _pasteScene(scale: 1, keyboard: false, kind: kind);
    await _capture(_pasteSceneName(1, false, kind: kind));
    _checks.add({
      'scenario': 'paste_${kind}_base_state',
      'passed': true,
      ..._snapshot(),
    });
  }
  _checksCompleted = true;
}

String _baseStyleSceneName(String kind) => _resultScreenMode && _isResult(kind)
    ? 'base_${kind}_${_categoryState}_scale_1'
    : 'base_${kind}_scale_1';

Element _textElement(String text, [Element? root]) => _elements(
  root,
).firstWhere((e) => e.widget is Text && (e.widget as Text).data == text);

Element _tabContainer(Element label) => _ancestor(label, (widget) {
  if (widget is! Container || widget.decoration is! BoxDecoration) return false;
  return (widget.decoration! as BoxDecoration).border is Border;
});

Map<String, Object?> _tabMetrics(String label) {
  final text = _textElement(label);
  final container = _tabContainer(text);
  final border =
      ((container.widget as Container).decoration! as BoxDecoration).border!
          as Border;
  return {
    ..._rectJson(_rect(container)),
    'active': border.bottom.width == 2,
    'underlineWidth': border.bottom.width,
    'underlineColor': _colorArgb(border.bottom.color),
    'textBounds': _rectJson(_rect(text)),
    'contentCenterY': _rect(container).center.dy - border.bottom.width / 2,
    'textCenterDeltaToContent':
        _rect(text).center.dy -
        (_rect(container).center.dy - border.bottom.width / 2),
  };
}

String? _selectedTabFromUnderline() {
  if (!_has<AddContentSheet>()) return null;
  for (final label in ['링크 첨부', '사진 첨부']) {
    if (_tabMetrics(label)['active'] == true) return label;
  }
  return null;
}

Map<String, Element> _baseStyleTextNodes() {
  if (!_has<AddContentSheet>()) return {};
  final nodes = <String, Element>{
    'headerTitle': _textElement('콘텐츠 저장하기', _first<SaveContentTopBar>()),
    'linkTab': _textElement('링크 첨부'),
    'photoTab': _textElement('사진 첨부'),
  };
  final body = _has<SavedContentConfirmation>()
      ? _first<SavedContentConfirmation>()
      : _has<PhotoSaveBody>()
      ? _first<PhotoSaveBody>()
      : _first<LinkSaveBody>();
  nodes['heading'] = _elements(body).firstWhere(
    (e) =>
        e.widget is Text &&
        ['저장할 링크', '저장할 사진'].contains((e.widget as Text).data),
  );
  if (_has<SavedContentConfirmation>()) {
    final preview = _layoutNodes();
    for (final role in [
      'previewHeading',
      'previewTitle',
      'previewSource',
      'categoryHeading',
      'categoryMessage',
      'categoryName',
    ]) {
      nodes[role] = preview[role]!;
    }
  }
  if (_has<EditableText>()) {
    nodes['urlOrFilename'] = _first<EditableText>();
  } else if (_has<SavedContentConfirmation>()) {
    final result = body.widget as SavedContentConfirmation;
    final label = result.originalUrl.isEmpty
        ? result.content.originalUrl
        : result.originalUrl;
    final visibleLabel = _elements(body)
        .where((e) => e.widget is Text && (e.widget as Text).data == label)
        .firstOrNull;
    if (visibleLabel != null) nodes['urlOrFilename'] = visibleLabel;
  }
  if (_has<PhotoEmptyPrompt>()) {
    nodes['photoPromptTitle'] = _textElement(
      '사진 선택',
      _first<PhotoEmptyPrompt>(),
    );
    nodes['photoPromptDescription'] = _textElement(
      '앨범에서 선택하거나 스크린샷을 업로드해 주세요.',
      _first<PhotoEmptyPrompt>(),
    );
  }
  if (_has<ValidationMessage>()) {
    nodes['validation'] = _elements(
      _first<ValidationMessage>(),
    ).firstWhere((e) => e.widget is Text);
  }
  final button = _first<SaveFlowButton>();
  if (!(button.widget as SaveFlowButton).loading) {
    nodes['cta'] = _elements(button).firstWhere((e) => e.widget is Text);
  }
  return nodes;
}

Map<String, Object?> _baseTextMetrics(Element element) {
  final render = element.findRenderObject()!;
  late TextStyle style;
  late String text;
  late List<Rect> lines;
  late int? maxLines;
  late bool? exceeded;
  late TextScaler scaler;
  double? declaredHeight;
  if (render is RenderParagraph) {
    style = (render.text as TextSpan).style!;
    text = render.text.toPlainText();
    scaler = render.textScaler;
    maxLines = render.maxLines;
    exceeded = render.didExceedMaxLines;
    lines = render
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        )
        .map((box) => box.toRect().shift(render.localToGlobal(Offset.zero)))
        .toList();
    declaredHeight = (element.widget as Text).style?.height;
  } else {
    final editable = element.widget as EditableText;
    final editableRender =
        ((element as StatefulElement).state as EditableTextState)
            .renderEditable;
    style = editable.style;
    text = editable.controller.text;
    scaler = MediaQuery.textScalerOf(element);
    maxLines = editable.maxLines;
    exceeded = null;
    lines = editableRender
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        )
        .map(
          (box) =>
              box.toRect().shift(editableRender.localToGlobal(Offset.zero)),
        )
        .toList();
    final field = _ancestor(element, (w) => w is TextField).widget as TextField;
    declaredHeight = field.style?.height;
  }
  return {
    'text': text,
    'bounds': _rectJson(_rect(element)),
    'fontFamily': style.fontFamily,
    'fontSize': style.fontSize,
    'scaledFontSize': style.fontSize == null
        ? null
        : scaler.scale(style.fontSize!),
    'fontWeight': style.fontWeight?.value,
    'letterSpacing': style.letterSpacing,
    'height': style.height,
    'declaredHeight': declaredHeight,
    'color': _colorArgb(style.color),
    'maxLines': maxLines,
    'didExceedMaxLines': exceeded,
    'overflow': render is RenderParagraph ? render.overflow.name : null,
    'lineBoxes': lines.map(_rectJson).toList(),
    'selectionBoxScope':
        'Selection boxes are diagnostic font-selection extents, not glyph ink bounds; intentional ellipsis and selection overhang beyond the paragraph are not clipping failures.',
  };
}

Map<String, Object?> _photoFrameMetrics() {
  if (!_has<SelectedPhotoPreview>()) return {};
  final nodes = _layoutNodes();
  final outerElement = nodes['photoFrameOuter']!;
  final outerWidget = outerElement.widget as Container;
  final outer = _rect(outerElement);
  final inner = _rect(nodes['photoFrameInner']!);
  final clip = _rect(nodes['photoFrameClip']!);
  final image = _rect(nodes['photoFrameImage']!);
  final imageWidget = nodes['photoFrameImage']!.widget as Image;
  final render = _elements(
    nodes['photoFrameImage']!,
  ).map((e) => e.findRenderObject()).whereType<RenderImage>().first;
  final raw = render.image;
  final imageBox = render.localToGlobal(Offset.zero) & render.size;
  final original = raw == null
      ? Size.zero
      : Size(raw.width.toDouble(), raw.height.toDouble());
  final fitted = original.isEmpty
      ? null
      : applyBoxFit(
          render.fit ?? BoxFit.scaleDown,
          original / render.scale,
          render.size,
        );
  final alignment = imageWidget.alignment.resolve(
    Directionality.of(outerElement),
  );
  final source = fitted == null
      ? Rect.zero
      : alignment.inscribe(
          fitted.source * render.scale,
          Offset.zero & original,
        );
  final destination = fitted == null
      ? Rect.zero
      : alignment.inscribe(fitted.destination, imageBox);
  final visible = destination.intersect(clip);
  final scaleX = source.width == 0 ? 0.0 : destination.width / source.width;
  final scaleY = source.height == 0 ? 0.0 : destination.height / source.height;
  final clipWidget = nodes['photoFrameClip']!.widget as ClipRect;
  final selected =
      _first<SelectedPhotoPreview>().widget as SelectedPhotoPreview;
  final outerDecoration = outerWidget.decoration as BoxDecoration?;
  final foreground = outerWidget.foregroundDecoration as BoxDecoration?;
  final padding = outerWidget.padding!.resolve(Directionality.of(outerElement));
  Map<String, Object?>? decorationMetrics(BoxDecoration? decoration) =>
      decoration == null
      ? null
      : {
          'color': decoration.color == null
              ? null
              : _colorArgb(decoration.color!),
          'borderRadius': decoration.borderRadius?.toString(),
          'border': decoration.border?.toString(),
          'borderPadding': decoration.padding.toString(),
        };
  return {
    'outer': _rectJson(outer),
    'inner': _rectJson(inner),
    'clip': _rectJson(clip),
    'photoCase': _photoCase,
    'decodedOriginal': {'width': original.width, 'height': original.height},
    'renderImageBox': _rectJson(imageBox),
    'paintedSource': _rectJson(source),
    'paintedDestination': _rectJson(destination),
    'visiblePaintedDestination': _rectJson(visible),
    'uniformScale': {'x': scaleX, 'y': scaleY},
    'letterbox': {
      'left': destination.left - inner.left,
      'top': destination.top - inner.top,
      'right': inner.right - destination.right,
      'bottom': inner.bottom - destination.bottom,
    },
    'wholeSource':
        original.width > 0 &&
        (source.width - original.width).abs() < .01 &&
        (source.height - original.height).abs() < .01 &&
        destination.intersect(clip) == destination,
    'image': _rectJson(image),
    'sideInsets': {
      'left': inner.left - outer.left,
      'top': inner.top - outer.top,
      'right': outer.right - inner.right,
      'bottom': outer.bottom - inner.bottom,
    },
    'explicitPadding': {
      'left': padding.left,
      'top': padding.top,
      'right': padding.right,
      'bottom': padding.bottom,
    },
    'expectedInnerWidth': outer.width - 32,
    'expectedOuterHeight': 437,
    'expectedInnerHeight': 405,
    'decoration': decorationMetrics(outerDecoration),
    'foregroundDecoration': decorationMetrics(foreground),
    'innerDecoration': decorationMetrics(
      (nodes['photoFrameInner']!.widget as DecoratedBox).decoration
          as BoxDecoration,
    ),
    'imageProvider': imageWidget.image.runtimeType.toString(),
    'photoByteLength': selected.photoBytes?.length,
    'photoMatchesOriginal': selected.photoBytes == null
        ? null
        : _same(selected.photoBytes!, _picker.photo),
    'photoMatchesAlternate': selected.photoBytes == null
        ? null
        : _same(selected.photoBytes!, _picker.alternate),
    'imageFit': imageWidget.fit?.name,
    'imageAlignment': alignment.toString(),
    'clipBehavior': clipWidget.clipBehavior.name,

    'boundaryScope':
        'Actual RenderImage decoded dimensions, paintImage applyBoxFit source/destination and clip visibility, independently of removed Stack/LayoutBuilder. Uniform scaling and all source pixels visible are required; viewport scrolling is diagnosed separately from image clipping. Actual native outer width is retained.',
  };
}

List<String> _photoFrameStyleFindings() {
  if (!_has<SelectedPhotoPreview>()) return [];
  final findings = <String>[];
  final outerWidget = _layoutNodes()['photoFrameOuter']!.widget as Container;
  final background = outerWidget.decoration! as BoxDecoration;
  final foreground = outerWidget.foregroundDecoration as BoxDecoration?;
  final outline = foreground ?? background;
  final border = outline.border;
  if (background.color != AppColors.surface ||
      background.borderRadius != BorderRadius.circular(8) ||
      outline.borderRadius != BorderRadius.circular(8) ||
      border is! Border ||
      border.top.width != 1 ||
      border.right.width != 1 ||
      border.bottom.width != 1 ||
      border.left.width != 1 ||
      border.top.color != AppColors.subtler ||
      border.right.color != AppColors.subtler ||
      border.bottom.color != AppColors.subtler ||
      border.left.color != AppColors.subtler) {
    findings.add('Photo outer background/radius/1px border/color changed');
  }
  return findings;
}

List<String> _photoFrameLayoutFindings() {
  if (!_has<SelectedPhotoPreview>()) return [];
  final findings = <String>[];
  final nodes = _layoutNodes();
  final metrics = _photoFrameMetrics();
  final outer = _rect(nodes['photoFrameOuter']!);
  final inner = _rect(nodes['photoFrameInner']!);
  final image = _rect(nodes['photoFrameImage']!);
  bool near(num actual, num expected) => (actual - expected).abs() < 0.1;
  final insets = metrics['sideInsets']! as Map<String, double>;
  if (!near(outer.height, 437) ||
      !near(inner.height, 405) ||
      !near(inner.width, outer.width - 32) ||
      insets.values.any((value) => !near(value, 16))) {
    findings.add(
      'Photo frame must retain outer height 437px, inner height 405px, inner width outer-minus-32px and four 16px insets',
    );
  }
  final padding = metrics['explicitPadding']! as Map<String, double>;
  if (padding.values.any((value) => !near(value, 16))) {
    findings.add('Photo frame explicit padding must remain 16px per side');
  }
  final clip = _rect(nodes['photoFrameClip']!);
  for (final rect in [clip, image]) {
    if (!near(rect.left, inner.left) ||
        !near(rect.top, inner.top) ||
        !near(rect.width, inner.width) ||
        !near(rect.height, inner.height)) {
      findings.add('Photo clip/image box must match the actual inner frame');
    }
  }
  final innerBorder =
      ((nodes['photoFrameInner']!.widget as DecoratedBox).decoration
              as BoxDecoration)
          .border;
  if (innerBorder != Border.all(color: AppColors.subtler) ||
      metrics['clipBehavior'] != 'hardEdge' ||
      metrics['imageFit'] != 'contain' ||
      metrics['imageAlignment'] != Alignment.center.toString()) {
    findings.add(
      'Photo must retain inner border/hard clip and use centered contain',
    );
  }
  final original = metrics['decodedOriginal']! as Map<String, double>;
  final scaling = metrics['uniformScale']! as Map<String, double>;
  final letterbox = metrics['letterbox']! as Map<String, double>;
  if (original.values.any((v) => v <= 0) ||
      metrics['wholeSource'] != true ||
      (scaling['x']! - scaling['y']!).abs() > .000001 ||
      letterbox.values.any((v) => v < -.01) ||
      (letterbox['left']! - letterbox['right']!).abs() > .1 ||
      (letterbox['top']! - letterbox['bottom']!).abs() > .1) {
    findings.add(
      'Decoded original must be fully visible with equal scale and centered nonnegative letterbox',
    );
  }
  return findings;
}

void _checkPhotoFrame() {
  if (_phase != 'after') return;
  final findings = [
    ..._photoFrameStyleFindings(),
    ..._photoFrameLayoutFindings(),
  ];
  _require(findings.isEmpty, 'Photo frame: ${findings.join('; ')}');
}

Map<String, Object?> _previewGeometryMetrics() {
  if (!_has<SavedContentConfirmation>()) return {};
  final nodes = _layoutNodes();
  final cardElement = nodes['previewCard']!;
  final cardWidget = cardElement.widget as Container;
  final card = _rect(cardElement);
  final image = _rect(nodes['previewImage']!);
  final text = _rect(nodes['previewText']!);
  final title = _rect(nodes['previewTitle']!);
  final source = _rect(nodes['previewSource']!);
  final heading = _rect(nodes['previewHeading']!);
  final preceding = _rect(nodes['previewPrecedingBlock']!);
  final isPhoto =
      (_first<SavedContentConfirmation>().widget as SavedContentConfirmation)
          .photoBytes !=
      null;
  final padding = cardWidget.padding!.resolve(Directionality.of(cardElement));
  final columnRender = nodes['previewText']!.findRenderObject()! as RenderBox;
  final titleRender =
      nodes['previewTitle']!.findRenderObject()! as RenderParagraph;
  final sourceRender =
      nodes['previewSource']!.findRenderObject()! as RenderParagraph;
  final columnMaxWidth = columnRender.constraints.maxWidth;
  final titleMaxWidth = titleRender.constraints.maxWidth;
  final sourceMaxWidth = sourceRender.constraints.maxWidth;
  Map<String, Object?> paragraphLines(Element element) {
    final render = element.findRenderObject()! as RenderParagraph;
    final boxes = render.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: render.text.toPlainText().length,
      ),
    );
    final lineTops = <double>[];
    for (final box in boxes) {
      if (lineTops.every((top) => (top - box.top).abs() > 0.1)) {
        lineTops.add(box.top);
      }
    }
    return {
      'visibleLineCount': lineTops.length,
      'maxLines': render.maxLines,
      'didExceedMaxLines': render.didExceedMaxLines,
      'lineCountScope':
          'Distinct visible selection-box rows from the actual RenderParagraph; bidi runs on the same row count once. Selection extents are not glyph ink or clipping bounds.',
    };
  }

  return {
    'heading': _rectJson(heading),
    'headingTop': heading.top,
    'precedingBlock': _rectJson(preceding),
    'precedingBlockKind': isPhoto
        ? nodes.containsKey('resultSummaryImage')
              ? 'photoImageSummary'
              : 'photoFilenameBox'
        : 'linkValidationMessage',
    'precedingBlockBottom': preceding.bottom,
    'precedingToHeadingGap': heading.top - preceding.bottom,
    'expectedPrecedingToHeadingGap': isPhoto ? 16 : 32,
    'previewStartGapScope':
        'Measured from the actual preceding result block: link ValidationMessage or photo summary. Before-phase falls back to the original filename box; the after-phase photo summary must expose its exact image role. Relative block gaps do not assert equality of device/OS absolute coordinates.',
    'card': _rectJson(card),
    'image': _rectJson(image),
    'text': _rectJson(text),
    'innerCard': _rectJson(padding.deflateRect(card)),
    'cardMinHeight': cardWidget.constraints?.minHeight,
    'cardPadding': {
      'left': padding.left,
      'top': padding.top,
      'right': padding.right,
      'bottom': padding.bottom,
    },
    'imageToTextGap': text.left - image.right,
    'textGap': source.top - title.bottom,
    'expectedTextGap': 14,
    'textConstraintsMaxWidth': columnMaxWidth,
    'textColumnWidth': text.width,
    'titleConstraintsMaxWidth': titleMaxWidth,
    'titleParagraphWidth': title.width,
    'titleParagraphBounds': _rectJson(title),
    'sourceConstraintsMaxWidth': sourceMaxWidth,
    'sourceParagraphWidth': source.width,
    'sourceParagraphBounds': _rectJson(source),
    'titleWidthReduction': columnMaxWidth - titleMaxWidth,
    'sourceWidthReduction': columnMaxWidth - sourceMaxWidth,
    'expectedTitleMaxWidth': columnMaxWidth - 8,
    'expectedSourceMaxWidth': columnMaxWidth,
    'columnToInnerRightGap': padding.deflateRect(card).right - text.right,
    'titleLines': paragraphLines(nodes['previewTitle']!),
    'sourceLines': paragraphLines(nodes['previewSource']!),
    'textHeight': text.height,
    'paragraphHeightSum': title.height + source.height,
    'imageCenterDelta': image.center.dy - card.center.dy,
    'textCenterDelta': text.center.dy - card.center.dy,
    'headingToCardGap': card.top - heading.bottom,
    'boundaryScope':
        'The actual RenderParagraph maximum constraints reserve 8px only for the title; source keeps the full text-column maximum. Short paragraph widths may be smaller than their maximum constraints. Paragraph layout bounds are checked against the actual padded card. Selection boxes are diagnostic rather than pixel paint bounds; intentional ellipsis is retained.',
  };
}

List<String> _previewLayoutFindings() {
  if (!_has<SavedContentConfirmation>()) return [];
  final findings = <String>[];
  final nodes = _layoutNodes();
  final metrics = _previewGeometryMetrics();
  final card = _rect(nodes['previewCard']!);
  final image = _rect(nodes['previewImage']!);
  final scale = MediaQuery.textScalerOf(nodes['previewCard']!).scale(1);
  bool near(Object? value, double target) =>
      value is num && (value - target).abs() < 0.1;
  final expectedStartGap = (metrics['expectedPrecedingToHeadingGap']! as num)
      .toDouble();
  if (!near(metrics['precedingToHeadingGap'], expectedStartGap)) {
    findings.add(
      '${metrics['precedingBlockKind']} to preview heading gap must be ${expectedStartGap.toInt()}px',
    );
  }
  if (!near(metrics['cardMinHeight'], 116) ||
      card.height < 115.9 ||
      (scale == 1 && !near(card.height, 116))) {
    findings.add(
      'Preview card must retain minimum 116px and base height 116px',
    );
  }
  final padding = metrics['cardPadding']! as Map<String, double>;
  if (padding.values.any((value) => !near(value, 8))) {
    findings.add('Preview card padding must remain 8px on each side');
  }
  if (!near(image.width, 164) || !near(image.height, 100)) {
    findings.add('Preview image must remain 164x100px');
  }
  if (!near(metrics['imageToTextGap'], 16) ||
      !near(metrics['textGap'], 14) ||
      !near(metrics['headingToCardGap'], 16)) {
    findings.add(
      'Preview must retain horizontal/heading gaps 16px and title-to-source gap 14px',
    );
  }
  final columnMaxWidth = (metrics['textConstraintsMaxWidth']! as num)
      .toDouble();
  if (!near(metrics['textColumnWidth'], columnMaxWidth) ||
      !near(metrics['titleConstraintsMaxWidth'], columnMaxWidth - 8) ||
      !near(metrics['sourceConstraintsMaxWidth'], columnMaxWidth) ||
      !near(metrics['titleWidthReduction'], 8) ||
      !near(metrics['sourceWidthReduction'], 0) ||
      !near(metrics['columnToInnerRightGap'], 0)) {
    findings.add(
      'Preview title maximum width must reserve 8px within the unchanged full-width source column',
    );
  }
  final text = _rect(nodes['previewText']!);
  for (final role in ['previewTitle', 'previewSource']) {
    final paragraph = nodes[role]!.findRenderObject()! as RenderParagraph;
    final bounds = _rect(nodes[role]!);
    if (!near(bounds.left, text.left) ||
        bounds.width > paragraph.constraints.maxWidth + 0.1 ||
        !_inside(bounds, text)) {
      findings.add(
        '$role layout exceeds its actual paragraph constraint/column',
      );
    }
  }
  if (!near(
    metrics['textHeight'],
    (metrics['paragraphHeightSum']! as num).toDouble() + 14,
  )) {
    findings.add('Preview text block must retain its natural paragraph height');
  }
  for (final role in ['title', 'source']) {
    final lines = metrics['${role}Lines']! as Map<String, Object?>;
    final count = lines['visibleLineCount']! as int;
    final maxLines = role == 'title' ? 2 : 1;
    if (count < 1 || count > maxLines || lines['maxLines'] != maxLines) {
      findings.add('Preview $role visible lines exceed the retained limit');
    }
  }
  if (!near(metrics['imageCenterDelta'], 0) ||
      !near(metrics['textCenterDelta'], 0)) {
    findings.add('Preview image/text block must remain vertically centered');
  }
  final cardWidget = nodes['previewCard']!.widget as Container;
  final inner = cardWidget.padding!
      .resolve(Directionality.of(nodes['previewCard']!))
      .deflateRect(card);
  for (final role in ['previewImage', 'previewTitle', 'previewSource']) {
    if (!_inside(_rect(nodes[role]!), inner)) {
      findings.add('$role paragraph/image layout clips padded preview card');
    }
  }
  for (final role in ['previewTitle', 'previewSource']) {
    final paragraph = nodes[role]!.findRenderObject()! as RenderParagraph;
    if (paragraph.maxLines != (role == 'previewTitle' ? 2 : 1) ||
        paragraph.overflow != TextOverflow.ellipsis) {
      findings.add('$role must retain its line limit and ellipsis');
    }
  }
  return findings;
}

Map<String, Object?> _resultSummaryMetrics() {
  if (!_has<SavedContentConfirmation>()) return {};
  final result = _first<SavedContentConfirmation>();
  final confirmation = result.widget as SavedContentConfirmation;
  final nodes = _layoutNodes();
  final summary = nodes['resultSummary']!;
  final imageElement = nodes['resultSummaryImage'];
  final image = imageElement?.widget as Image?;
  final innerElement = imageElement == null
      ? null
      : _ancestor(imageElement, (w) => w is Container);
  final clip = imageElement == null
      ? null
      : _ancestor(imageElement, (w) => w is ClipRect);
  final summaryRect = _rect(summary);
  final clipRect = clip == null ? null : _rect(clip);
  final semantics = _elements(summary)
      .where((e) => e.widget is Semantics)
      .map((e) => (e.widget as Semantics).properties.label)
      .whereType<String>()
      .toList();
  if (image?.semanticLabel case final String label) semantics.add(label);
  return {
    'isPhoto': confirmation.photoBytes != null,
    'summary': _containerPaintMetrics(summary),
    'submittedLabel': confirmation.originalUrl,
    'filenameVisuallyPresent': _text(confirmation.originalUrl),
    'semanticLabels': semantics,
    'filenameSemanticallyPresent': semantics.any(
      (label) => label.contains(confirmation.originalUrl),
    ),
    'image': imageElement == null ? null : _rectJson(_rect(imageElement)),
    'imageFit': image?.fit?.name,
    'imageAlignment': image?.alignment.toString(),
    'imageIsMemory': image?.image is MemoryImage,
    'imageMatchesSubmittedBytes':
        image?.image is MemoryImage &&
        identical((image!.image as MemoryImage).bytes, confirmation.photoBytes),
    'clip': clipRect == null ? null : _rectJson(clipRect),
    'inner': innerElement == null ? null : _containerPaintMetrics(innerElement),
    'explicitClipInsets': clipRect == null
        ? null
        : {
            'left': clipRect.left - summaryRect.left,
            'top': clipRect.top - summaryRect.top,
            'right': summaryRect.right - clipRect.right,
            'bottom': summaryRect.bottom - clipRect.bottom,
          },
    'requiredRoleKeys': {
      for (final key in [
        if (confirmation.photoBytes != null) ...[
          'save-result-photo-summary',
          'save-result-photo-image',
        ] else
          'save-result-input-summary',
        'save-result-preview-card',
        'save-result-preview-image',
        'save-result-category-heading',
        'save-result-category-folder',
        'save-result-category-row',
      ])
        key: _keyed(key, result) != null,
    },
    'scope':
        'Before-phase uses original visible filename geometry. After-phase requires keyed roles, a semantic filename, submitted original image bytes, and foreground borders that do not shrink content.',
  };
}

Map<String, Object?> _resultThumbnailMetrics() {
  if (!_has<SavedContentConfirmation>()) return {};
  final nodes = _layoutNodes();
  final element = nodes['previewImage']!;
  final image = element.widget as Image;
  final container = _ancestor(element, (w) => w is Container);
  final confirmation =
      _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
  return {
    'image': _rectJson(_rect(element)),
    'container': _containerPaintMetrics(container),
    'fit': image.fit?.name,
    'alignment': image.alignment.toString(),
    'isMemory': image.image is MemoryImage,
    'matchesSubmittedBytes':
        image.image is MemoryImage &&
        identical((image.image as MemoryImage).bytes, confirmation.photoBytes),
  };
}

List<String> _resultScreenStyleFindings() {
  if (!_has<SavedContentConfirmation>()) return [];
  final findings = <String>[];
  final summary = _resultSummaryMetrics();
  final isPhoto = summary['isPhoto'] == true;
  final keys = summary['requiredRoleKeys']! as Map<String, bool>;
  if (keys.values.any((present) => !present)) {
    findings.add('Result screen must expose every required keyed role');
  }
  bool radius(Object? value, double expected) =>
      value is Map &&
      value.values.every((v) => v is num && (v - expected).abs() < .1);
  final outer = summary['summary']! as Map<String, Object?>;
  final background = outer['background']! as Map<String, Object?>;
  final foreground = outer['foreground']! as Map<String, Object?>;
  if (isPhoto) {
    if (background['color'] != _colorArgb(AppColors.surface) ||
        !radius(background['radius'], 8) ||
        !radius(foreground['radius'], 8) ||
        foreground['isSubtlerOnePixelBorder'] != true) {
      findings.add(
        'Photo summary must use surface/R8 and a subtler 1px foreground border',
      );
    }
    final inner = summary['inner'] as Map<String, Object?>?;
    final innerForeground = inner?['foreground'] as Map<String, Object?>?;
    final innerBackground = inner?['background'] as Map<String, Object?>?;
    final innerPaint = innerForeground?.isNotEmpty == true
        ? innerForeground!
        : innerBackground;
    if (innerPaint?['isSubtlerOnePixelBorder'] != true ||
        innerPaint?['radius'] != null ||
        summary['imageFit'] != 'cover' ||
        summary['imageAlignment'] != Alignment.center.toString() ||
        summary['imageMatchesSubmittedBytes'] != true ||
        summary['filenameVisuallyPresent'] != false ||
        summary['filenameSemanticallyPresent'] != true) {
      findings.add(
        'Photo summary must retain square 1px inner border, centered cover submitted image and semantic-only filename',
      );
    }
  }
  final thumb = _resultThumbnailMetrics();
  final thumbContainer = thumb['container']! as Map<String, Object?>;
  final thumbForeground = thumbContainer['foreground']! as Map<String, Object?>;
  if (thumb['fit'] != 'cover' ||
      thumb['alignment'] != Alignment.center.toString() ||
      (isPhoto &&
          (thumbForeground['isSubtlerOnePixelBorder'] != true ||
              !radius(thumbForeground['radius'], 4) ||
              thumb['matchesSubmittedBytes'] != true)) ||
      (!isPhoto && thumbForeground['border'] != null)) {
    findings.add(
      'Result thumbnail must retain cover/center and photo-only R4 subtler 1px foreground border',
    );
  }
  final category = _categoryGeometryMetrics();
  final folder = category['folderVisual']! as Map<String, Object?>;
  if (folder['isSvg'] != true ||
      folder['asset'] != 'assets/icons/save-result-folder.svg' ||
      folder['matchesActualCategoryColor'] != true) {
    findings.add(
      'Result folder must use the exact SVG with the actual category color',
    );
  }
  return findings;
}

List<String> _resultSummaryLayoutFindings() {
  if (!_has<SavedContentConfirmation>()) return [];
  final findings = <String>[];
  final metrics = _resultSummaryMetrics();
  final nodes = _layoutNodes();
  final summary = _rect(nodes['resultSummary']!);
  final viewport = _rect(nodes['bodyViewport']!);
  bool near(Object? value, double target) =>
      value is num && (value - target).abs() < .1;
  if (!near(summary.width, viewport.width - 32)) {
    findings.add('Result summary must retain the full body width');
  }
  if (metrics['isPhoto'] == true) {
    final outer = metrics['summary']! as Map<String, Object?>;
    final padding = outer['padding'];
    final insets = metrics['explicitClipInsets'];
    final clip = metrics['clip'];
    if (!near(summary.height, 89) ||
        padding is! Map ||
        padding.values.any((v) => !near(v, 16)) ||
        insets is! Map ||
        insets.values.any((v) => !near(v, 16)) ||
        clip is! Map ||
        !near(clip['height'], 57) ||
        !near(clip['width'], summary.width - 32)) {
      findings.add(
        'Photo summary must retain height89/padding16 and full-width inner clip height57',
      );
    }
    final image = metrics['image'];
    if (image is! Map ||
        clip is! Map ||
        !near(image['width'], (clip['width'] as num).toDouble()) ||
        !near(image['height'], 57) ||
        !near(image['left'], (clip['left'] as num).toDouble()) ||
        !near(image['top'], (clip['top'] as num).toDouble())) {
      findings.add(
        'Photo summary image must fill its actual clipped inner box',
      );
    }
  } else if (!near(summary.height, 44)) {
    findings.add('Link summary must retain height44');
  }
  if (_resultScreenMode) {
    final preview = _previewGeometryMetrics();
    final titleLines = preview['titleLines']! as Map<String, Object?>;
    if (titleLines['visibleLineCount'] != 2 ||
        titleLines['didExceedMaxLines'] != false) {
      findings.add(
        'Screen-state fixed title must show two natural lines without ellipsis',
      );
    }
  }
  return findings;
}

Map<String, Object?> _categoryGeometryMetrics() {
  if (!_has<SavedContentConfirmation>()) return {};
  final nodes = _layoutNodes();
  final rowElement = nodes['categoryRow']!;
  final rowWidget = rowElement.widget as Container;
  final row = _rect(rowElement);
  final previewCard = _rect(nodes['previewCard']!);
  final heading = _rect(nodes['categoryHeading']!);
  final message = _rect(nodes['categoryMessage']!);
  final name = _rect(nodes['categoryName']!);
  final folder = _rect(nodes['categoryFolder']!);
  final hint = _rect(nodes['categoryEditHint']!);
  final groupElement = nodes['categoryText']!;
  final group = _rect(groupElement);
  final groupWidget = groupElement.widget;
  final messageParagraph =
      nodes['categoryMessage']!.findRenderObject()! as RenderParagraph;
  final naturalMessage = TextPainter(
    text: messageParagraph.text,
    textDirection: messageParagraph.textDirection,
    textScaler: messageParagraph.textScaler,
  )..layout();
  final messageNaturalWidth = naturalMessage.width;
  naturalMessage.dispose();
  final folderWidget = nodes['categoryFolder']!.widget;
  final content =
      (_first<SavedContentConfirmation>().widget as SavedContentConfirmation)
          .content;
  final folderLoader = folderWidget is SvgPicture
      ? folderWidget.bytesLoader
      : null;
  final padding = rowWidget.padding!.resolve(Directionality.of(rowElement));
  return {
    'row': _rectJson(row),
    'innerRow': _rectJson(padding.deflateRect(row)),
    'heading': _rectJson(heading),
    'message': _rectJson(message),
    'name': _rectJson(name),
    'folder': _rectJson(folder),
    'editHint': _rectJson(hint),
    'headingGroup': _rectJson(group),
    'isWrap': groupWidget is Wrap,
    'wrapSpacing': groupWidget is Wrap ? groupWidget.spacing : null,
    'wrapRunSpacing': groupWidget is Wrap ? groupWidget.runSpacing : null,
    'wrapCrossAxisAlignment': groupWidget is Wrap
        ? groupWidget.crossAxisAlignment.name
        : null,
    'messageNaturalWidth': messageNaturalWidth,
    'expectedInline': heading.width + 8 + messageNaturalWidth <= row.width + .1,
    'actualInline': (message.center.dy - heading.center.dy).abs() < .1,
    'inlineGap': message.left - heading.right,
    'inlineCenterDelta': message.center.dy - heading.center.dy,
    'headingGroupToRowGap': row.top - group.bottom,
    'folderVisual': {
      'isSvg': folderWidget is SvgPicture,
      'asset': folderLoader is SvgAssetLoader ? folderLoader.assetName : null,
      'colorFilter': folderWidget is SvgPicture
          ? folderWidget.colorFilter.toString()
          : null,
      'expectedCategoryColor': _colorArgb(content.category.color),
      'matchesActualCategoryColor': folderWidget is SvgPicture
          ? folderWidget.colorFilter ==
                ColorFilter.mode(content.category.color, BlendMode.srcIn)
          : folderWidget is FolderGlyph &&
                folderWidget.color == content.category.color,
    },
    'editHintMetrics': _baseTextMetrics(nodes['categoryEditHint']!),
    'previewCardBottom': previewCard.bottom,
    'categoryHeadingTop': heading.top,
    'previewToHeadingGap': heading.top - previewCard.bottom,
    'expectedPreviewToHeadingGap': 32,
    'rowPadding': {
      'left': padding.left,
      'top': padding.top,
      'right': padding.right,
      'bottom': padding.bottom,
    },
    'headingToMessageGap': message.top - heading.bottom,
    'messageToRowGap': row.top - message.bottom,
    'folderToNameGap': name.left - folder.right,
    'rowToHintGap': hint.top - row.bottom,
    'folderCenterDelta': folder.center.dy - row.center.dy,
    'nameCenterDelta': name.center.dy - row.center.dy,
    'boundaryScope':
        'Category paragraph layout is checked against the actual row and body width, not the visible scroll position. Selection boxes and intentional ellipsis are diagnostic rather than clipping failures.',
  };
}

List<String> _categoryLayoutFindings() {
  if (!_has<SavedContentConfirmation>()) return [];
  final findings = <String>[];
  final nodes = _layoutNodes();
  final metrics = _categoryGeometryMetrics();
  final rowElement = nodes['categoryRow']!;
  final row = _rect(rowElement);
  final padding = (rowElement.widget as Container).padding!.resolve(
    Directionality.of(rowElement),
  );
  final inner = padding.deflateRect(row);
  final viewport = _rect(nodes['bodyViewport']!);
  bool near(Object? value, double target) =>
      value is num && (value - target).abs() < 0.1;
  if (!near(metrics['previewToHeadingGap'], 32)) {
    findings.add('Preview card to category heading gap must be 32px');
  }
  if (!near(row.height, 55) ||
      !near(padding.left, 16) ||
      !near(padding.right, 16) ||
      !near(padding.top, 0) ||
      !near(padding.bottom, 0)) {
    findings.add('Category row must retain 55px height and 16px side padding');
  }
  final folder = _rect(nodes['categoryFolder']!);
  if (!near(folder.width, 28.1942) ||
      !near(folder.height, 23.965) ||
      !near(metrics['folderToNameGap'], 8) ||
      !near(metrics['folderCenterDelta'], 0) ||
      !near(metrics['nameCenterDelta'], 0)) {
    findings.add(
      'Category folder/name size, 8px gap or vertical center changed',
    );
  }
  if (metrics['isWrap'] != true ||
      !near(metrics['wrapSpacing'], 8) ||
      !near(metrics['wrapRunSpacing'], 8) ||
      metrics['wrapCrossAxisAlignment'] != 'center' ||
      !near(metrics['headingGroupToRowGap'], 16) ||
      !near(metrics['rowToHintGap'], 8)) {
    findings.add(
      'Category group must use natural Wrap spacing8/run8/center, group-to-row16 and row-to-hint8',
    );
  }
  if (metrics['expectedInline'] == true) {
    if (!near(metrics['inlineGap'], 8) ||
        !near(metrics['inlineCenterDelta'], 0)) {
      findings.add(
        'Short category message must sit inline with 8px gap and vertical center',
      );
    }
  } else if (!near(metrics['headingToMessageGap'], 8) ||
      !near(
        (_rect(nodes['categoryMessage']!).left),
        _rect(nodes['categoryHeading']!).left,
      )) {
    findings.add(
      'Long category message must use the next Wrap run with 8px gap',
    );
  }
  for (final role in ['categoryFolder', 'categoryName']) {
    if (!_inside(_rect(nodes[role]!), inner)) {
      findings.add('$role layout clips the padded category row');
    }
  }
  for (final role in ['categoryHeading', 'categoryMessage']) {
    final rect = _rect(nodes[role]!);
    if (!_inside(rect, _rect(nodes['categoryText']!)) ||
        rect.left < viewport.left - 0.1 ||
        rect.right > viewport.right + 0.1) {
      findings.add('$role clips its parent or exceeds body viewport width');
    }
  }
  final paragraph =
      nodes['categoryName']!.findRenderObject()! as RenderParagraph;
  final content =
      (_first<SavedContentConfirmation>().widget as SavedContentConfirmation)
          .content;
  if (paragraph.maxLines != 1 ||
      paragraph.overflow != TextOverflow.ellipsis ||
      paragraph.text.toPlainText() != content.category.name) {
    findings.add('Category name must retain actual data and one-line ellipsis');
  }
  return findings;
}

Map<String, Object?> _baseStyleMetrics() {
  if (!_has<AddContentSheet>()) return {};
  final top = _first<SaveContentTopBar>();
  final close = _elements(top).firstWhere((e) => e.widget is IconButton);
  final icon = _elements(
    close,
  ).firstWhere((e) => e.widget.runtimeType.toString() == 'SvgIcon');
  final title = _textElement('콘텐츠 저장하기', top);
  final button = _first<SaveFlowButton>();
  final scrollElement = _first<SingleChildScrollView>();
  final scrollWidget = scrollElement.widget as SingleChildScrollView;
  final viewport = _rect(scrollElement);
  final padding = scrollWidget.padding!.resolve(
    Directionality.of(scrollElement),
  );
  final roles = _baseStyleTextNodes();
  final heading = _rect(roles['heading']!);
  final tabs = _rect(_tabContainer(roles['linkTab']!));
  final scrollOffset = _bodyPosition.pixels;
  final atScrollZero = scrollOffset.abs() < 0.1;
  final validation = _has<ValidationMessage>()
      ? _rect(_first<ValidationMessage>())
      : null;
  Rect? validationPrevious;
  if (validation != null) {
    if (_has<LinkSaveBody>()) {
      validationPrevious = _rect(_layoutNodes()['linkInputRow']!);
    } else {
      final label = _baseStyleTextNodes()['urlOrFilename']!;
      validationPrevious = _rect(_ancestor(label, (w) => w is Container));
    }
  }
  return {
    'roles': roles.map(
      (name, element) => MapEntry(name, _baseTextMetrics(element)),
    ),
    'layout': {
      'header': _rectJson(_rect(top)),
      'closeHit': _rectJson(_rect(close)),
      'closeIcon': _rectJson(_rect(icon)),
      'headerLeftMargin': _rect(close).left - _rect(top).left,
      'headerRightPadding':
          (_elements(top).firstWhere((e) => e.widget is Padding).widget
                  as Padding)
              .padding
              .resolve(Directionality.of(top))
              .right,
      'titleGap': _rect(title).left - _rect(close).right,
      'titleCenterDelta': _rect(title).center.dy - _rect(top).center.dy,
      'linkTab': _tabMetrics('링크 첨부'),
      'photoTab': _tabMetrics('사진 첨부'),
      'bodyViewport': _rectJson(viewport),
      'bodyHeading': _rectJson(heading),
      'tabsBottom': tabs.bottom,
      'viewportToTabsGap': viewport.top - tabs.bottom,
      'bodyPadding': {
        'left': padding.left,
        'top': padding.top,
        'right': padding.right,
        'bottom': padding.bottom,
      },
      'scrollOffset': scrollOffset,
      'maxScrollExtent': _bodyPosition.maxScrollExtent,
      'startGap': heading.top - viewport.top,
      'startGapFromTabs': heading.top - tabs.bottom,
      'expectedStartGap': 32,
      'startGapChecked': atScrollZero,
      'startGapScope':
          'The raw heading-to-viewport and heading-to-tabs gaps are judged only at scroll zero. Scrolled heading positions are recorded without resetting or compensating the scroll offset.',
      'cta': _rectJson(_rect(button)),
      'validationGap': validation == null || validationPrevious == null
          ? null
          : validation.top - validationPrevious.bottom,
      if (_has<SavedContentConfirmation>())
        'preview': _previewGeometryMetrics(),
      if (_has<SavedContentConfirmation>())
        'category': _categoryGeometryMetrics(),
      if (_has<SavedContentConfirmation>())
        'resultSummary': _resultSummaryMetrics(),
      if (_has<SavedContentConfirmation>())
        'resultThumbnail': _resultThumbnailMetrics(),
    },
    'ctaEnabled': (button.widget as SaveFlowButton).enabled,
    'ctaLoading': (button.widget as SaveFlowButton).loading,
    'selectedTabSource':
        'Actual tab container bottom border width: active=2px, inactive=1px',
    'scope':
        'Actual effective paragraph styles and bounds, submitted-photo summary89/padding16/inner57/foreground borders/cover-center image, semantic filename, photo-only thumbnail border, natural category Wrap and exact SVG with actual category color. Retained preview constraints, paragraph limits/ellipsis, internal gaps, body32 and footer are included. Before-phase target findings diagnose differences without blocking capture; no photo-processing design or category editing behavior is invented.',
  };
}

List<String> _baseStyleFindings() {
  if (!_baseStyleMode || !_has<AddContentSheet>()) return [];
  final findings = <String>[];
  final metrics = _baseStyleMetrics();
  final roles = metrics['roles']! as Map<String, Map<String, Object?>>;
  final selected = _selectedTabFromUnderline();
  final enabled = metrics['ctaEnabled'] == true;
  final specs = <String, List<Object?>>{
    'headerTitle': [18, 600, -0.45, '0xFF000000'],
    'linkTab': [
      16,
      selected == '링크 첨부' ? 600 : 500,
      -0.4,
      selected == '링크 첨부' ? '0xFF1A1A1A' : '0xFFD1D1D1',
    ],
    'photoTab': [
      16,
      selected == '사진 첨부' ? 600 : 500,
      -0.4,
      selected == '사진 첨부' ? '0xFF1A1A1A' : '0xFFD1D1D1',
    ],
    'heading': [16, 600, -0.4, '0xFF000000'],
    'urlOrFilename': [14, 500, -0.35, null],
    'photoPromptTitle': [15, 600, -0.375, '0xFF767676'],
    'photoPromptDescription': [14, 500, -0.35, '0xFFB5BDC3'],
    'validation': [14, 500, -0.35, '0xFFB5BDC3'],
    'previewHeading': [16, 600, -0.4, '0xFF000000'],
    'previewTitle': [15, 500, -0.375, '0xFF000000'],
    'previewSource': [14, 400, -0.35, '0xFF767676'],
    'categoryHeading': [16, 600, -0.4, '0xFF000000'],
    'categoryMessage': [14, 500, -0.35, '0xFF767676'],
    'categoryName': [16, 500, 0, '0xFF000000'],
    'cta': [16, 600, 0, enabled ? '0xFFFFD75C' : '0xFFFFFFFF'],
  };
  for (final entry in roles.entries) {
    final role = entry.key;
    final actual = entry.value;
    final expected = specs[role]!;
    if (actual['fontFamily'] != 'Pretendard' ||
        actual['fontSize'] != expected[0] ||
        actual['fontWeight'] != expected[1] ||
        actual['letterSpacing'] != expected[2] ||
        (expected[3] != null && actual['color'] != expected[3])) {
      findings.add(
        '$role effective font/weight/spacing/color differs from Figma role',
      );
    }
    if (actual['scaledFontSize'] != actual['fontSize']) {
      findings.add('$role is not at actual text scale 1');
    }
    final expectedHeight = role == 'cta'
        ? 1.375
        : role == 'previewTitle' || role == 'previewSource'
        ? 1.6
        : role == 'categoryName'
        ? 22 / 16
        : null;
    if (expectedHeight != null) {
      if (actual['height'] != expectedHeight) {
        findings.add('$role line height must remain $expectedHeight');
      }
    } else if (actual['declaredHeight'] != null) {
      findings.add(
        '$role AUTO line height was replaced with an explicit height',
      );
    }
  }
  findings.addAll(_resultScreenStyleFindings());
  return findings;
}

List<String> _baseLayoutFindings() {
  if (!_baseStyleMode || !_has<AddContentSheet>()) return [];
  final findings = <String>[];
  final metrics = _baseStyleMetrics();
  final layout = metrics['layout']! as Map<String, Object?>;
  final roles = _baseStyleTextNodes();
  final header = _rect(_first<SaveContentTopBar>());
  bool near(Object? value, double target) =>
      value is num && (value - target).abs() < 0.1;
  if (!near((layout['header']! as Map)['height'], 64) ||
      !near(layout['headerLeftMargin'], 16) ||
      !near(layout['titleGap'], 8) ||
      !near(layout['titleCenterDelta'], 0)) {
    findings.add('Header 64px/16px inset/8px gap/vertical center changed');
  }
  for (final key in ['closeHit', 'closeIcon']) {
    final rect = layout[key]! as Map;
    if (!near(rect['width'], 24) || !near(rect['height'], 24)) {
      findings.add('$key must remain 24x24');
    }
  }
  if (!_inside(_rect(roles['headerTitle']!), header)) {
    findings.add('Header title clips header');
  }
  for (final entry in {'linkTab': '링크 첨부', 'photoTab': '사진 첨부'}.entries) {
    final tab = layout[entry.key]! as Map;
    final element = roles[entry.key]!;
    final outer = _rect(_tabContainer(element));
    if (!near(tab['height'], 56) ||
        !near(tab['underlineWidth'], tab['active'] == true ? 2 : 1) ||
        tab['underlineColor'] !=
            (tab['active'] == true ? '0xFF1A1A1A' : '0xFFD1D1D1') ||
        !_inside(_rect(element), outer) ||
        (_rect(element).center.dx - outer.center.dx).abs() > 0.1 ||
        !near(tab['textCenterDeltaToContent'], 0)) {
      findings.add(
        '${entry.key} 56px height/underline/text center/containment changed',
      );
    }
  }
  final viewport = _rect(_first<SingleChildScrollView>());
  if (!near(layout['viewportToTabsGap'], 0)) {
    findings.add('Body viewport must start at the tabs bottom');
  }
  final padding = layout['bodyPadding']! as Map;
  if (!near(padding['left'], 16) ||
      !near(padding['right'], 16) ||
      !near(padding['bottom'], 24)) {
    findings.add('Body must retain 16px side and 24px bottom padding');
  }
  if (layout['startGapChecked'] == true &&
      (!near(padding['top'], 32) ||
          !near(layout['startGap'], 32) ||
          !near(layout['startGapFromTabs'], 32))) {
    findings.add('Body heading must start 32px below the tabs at scroll zero');
  }
  for (final role in ['heading', 'urlOrFilename', 'validation']) {
    if (roles[role] case final Element element) {
      final rect = _rect(element);
      if (rect.left < viewport.left - 0.1 ||
          rect.right > viewport.right + 0.1) {
        findings.add('$role exceeds body viewport width');
      }
    }
  }
  if (roles['cta'] case final Element text) {
    final button = _rect(_first<SaveFlowButton>());
    if (!_inside(_rect(text), button) ||
        (_rect(text).center - button.center).distance > 0.1) {
      findings.add('CTA text clips button or loses center');
    }
  }
  if (_has<PhotoEmptyPrompt>()) {
    final outer = _rect(_first<PhotoEmptyPrompt>());
    for (final role in ['photoPromptTitle', 'photoPromptDescription']) {
      if (!_inside(_rect(roles[role]!), outer)) {
        findings.add('$role clips photo prompt');
      }
    }
  }
  if (roles.containsKey('validation') && !near(layout['validationGap'], 5)) {
    findings.add('Validation must retain 5px preceding gap');
  }
  if (roles['previewHeading'] case final Element heading) {
    final rect = _rect(heading);
    if (rect.left < viewport.left - 0.1 || rect.right > viewport.right + 0.1) {
      findings.add('Preview heading exceeds body viewport width');
    }
  }
  findings.addAll(_previewLayoutFindings());
  findings.addAll(_categoryLayoutFindings());
  findings.addAll(_resultSummaryLayoutFindings());
  return findings;
}

void _checkBaseStyle() {
  if (_phase != 'after') return;
  final styles = _baseStyleFindings();
  final layout = _baseLayoutFindings();
  _require(styles.isEmpty, 'Base typography: ${styles.join('; ')}');
  _require(layout.isEmpty, 'Base geometry: ${layout.join('; ')}');
  _checkPhotoFrame();
}

Future<void> _baseStyleScene(
  String kind, {
  String? categoryState,
  String photoCase = 'default',
}) async {
  _picker.useCase(photoCase);
  if (categoryState != null) {
    _require(_isResult(kind), 'Category states apply only to result screens');
    _require(
      const [
        'classified',
        'uncategorized',
        'processing',
      ].contains(categoryState),
      'Unsupported category state',
    );
    _require(
      kind != 'photo' || categoryState != 'processing',
      'Photo-processing has no confirmed design',
    );
    _categoryState = categoryState;
  } else {
    _categoryState = 'classified';
  }
  _require(
    const [
      'empty',
      'valid',
      'invalid',
      'photo-empty',
      'photo-selected',
      'link',
      'photo',
    ].contains(kind),
    'Unsupported base style kind',
  );
  _baseStyleKind = kind;
  _baseInputSetupScope = _baseStaticInputScope;
  if (const ['empty', 'valid', 'invalid'].contains(kind)) {
    await _open('link-input', scale: 1);
    final draft = kind == 'valid'
        ? _url
        : kind == 'invalid'
        ? 'invalid-link'
        : '';
    await _type(draft);
    final controller =
        (_first<EditableText>().widget as EditableText).controller;
    controller.selection = TextSelection.collapsed(offset: draft.length);
    _require(controller.text == draft, 'Base fixed TextField draft changed');
    _require(
      _text('유효한 링크예요!') == (kind == 'valid'),
      'Base valid message differs from input',
    );
    _require(
      _text('유효하지 않은 링크예요.') == (kind == 'invalid'),
      'Base invalid message differs from input',
    );
    _require(
      (_first<SaveFlowButton>().widget as SaveFlowButton).enabled ==
          (kind == 'valid'),
      'Base save enabled state differs from input',
    );
    _require(
      _appKey.currentState!.calls == 0,
      'Base input unexpectedly submitted',
    );
    _checkFooter();
    _checkPaste();
  } else {
    await _open(kind, scale: 1);
    if (_isResult(kind)) await _save();
    _checkScene(kind, 1);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  _bodyPosition.jumpTo(0);
  await _settle();
  _scene = _baseStyleSceneName(kind);
  _require(
    MediaQuery.of(_first<AddContentSheet>()).viewInsets.bottom == 0,
    'Base scene keyboard remains visible',
  );
  _require(
    MediaQuery.textScalerOf(_first<AddContentSheet>()).scale(1) == 1,
    'Base scene text scale changed',
  );
  _checkBaseStyle();
}

Future<void> _resultScreenRun() async {
  for (final scene in const [
    ('link', 'classified'),
    ('link', 'uncategorized'),
    ('link', 'processing'),
    ('photo', 'classified'),
    ('photo', 'uncategorized'),
  ]) {
    final (kind, category) = scene;
    await _baseStyleScene(kind, categoryState: category);
    final name = _baseStyleSceneName(kind);
    await _capture(name);
    final state = _appKey.currentState!;
    final submitted =
        _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
    final content = submitted.content;
    final label = submitted.originalUrl;
    final bytes = submitted.photoBytes;
    _require(
      state.calls == 1 && state.submissions.length == 1,
      'Screen-state result must submit exactly once',
    );
    _require(
      content.title == _screenResultTitle,
      'Screen-state fixed two-line title changed',
    );
    await _tapText(kind == 'photo' ? '링크 첨부' : '사진 첨부');
    final pinned =
        _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
    _require(
      _selectedTabFromUnderline() == (kind == 'photo' ? '사진 첨부' : '링크 첨부') &&
          identical(pinned.content, content) &&
          pinned.originalUrl == label &&
          identical(pinned.photoBytes, bytes) &&
          state.calls == 1 &&
          state.submissions.length == 1,
      'Screen-state tab tap changed the result or submitted again',
    );
    _checkBaseStyle();
    _checks.add({
      'scenario': '${name}_result_tab_pinned',
      'passed': true,
      ..._snapshot(),
    });
    final hasScrollableBody = _bodyPosition.maxScrollExtent > .1;
    if (hasScrollableBody) {
      await _drag(const Offset(0, -180));
      _require(
        _bodyPosition.pixels > .1,
        'Screen-state body did not respond to actual drag',
      );
    }
    await _scrollToMax();
    _checkFooter(atMaximum: true);
    _checkBaseStyle();
    _checks.add({
      'scenario': '${name}_maximum_scroll',
      'passed': true,
      'actualDragChecked': hasScrollableBody,
      'scrollVerificationScope': hasScrollableBody
          ? 'Actual pointer drag followed by maximum-scroll visibility check'
          : 'No scroll extent; last item and footer visibility checked without claiming a successful drag',
      ..._snapshot(),
    });
    await _tapText('닫기');
    _require(
      !_has<AddContentSheet>() &&
          state.calls == 1 &&
          state.submissions.length == 1,
      'Screen-state close did not dismiss without another save',
    );
    _checks.add({
      'scenario': '${name}_result_close',
      'passed': true,
      ..._snapshot(),
    });
  }
  _checksCompleted = true;
}

Future<void> _baseStyleRun({
  bool resultsOnly = false,
  bool screenStates = false,
}) async {
  _checksCompleted = false;
  if (screenStates) {
    _require(resultsOnly, 'Screen-state runner is result-only');
    await _resultScreenRun();
    return;
  }
  final kinds = resultsOnly
      ? ['link', 'photo']
      : [
          'empty',
          'valid',
          'invalid',
          'photo-empty',
          'photo-selected',
          'link',
          'photo',
        ];
  for (final kind in kinds) {
    await _baseStyleScene(kind);
    await _capture(_baseStyleSceneName(kind));
    if (resultsOnly) {
      final selectedTab = kind == 'photo' ? '사진 첨부' : '링크 첨부';
      final submitted =
          _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
      final submittedLabel = submitted.originalUrl;
      final submittedBytes = submitted.photoBytes;
      _require(
        _appKey.currentState!.calls == 1,
        'Result-only save count changed',
      );
      await _tapText(kind == 'photo' ? '링크 첨부' : '사진 첨부');
      final pinned =
          _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
      _require(
        _selectedTabFromUnderline() == selectedTab &&
            pinned.originalUrl == submittedLabel &&
            identical(pinned.photoBytes, submittedBytes) &&
            _appKey.currentState!.calls == 1,
        'Result-only tab tap changed result or submitted again',
      );
      _checkBaseStyle();
      _checks.add({
        'scenario': '${_baseStyleSceneName(kind)}_result_tab_pinned',
        'passed': true,
        ..._snapshot(),
      });
      if (_bodyPosition.maxScrollExtent > 0) {
        await _drag(const Offset(0, -180));
        _require(
          _bodyPosition.pixels > 0,
          'Result-only body did not respond to drag',
        );
      }
    }
    await _scrollToMax();
    _checkFooter(atMaximum: true);
    _checkBaseStyle();
    _checks.add({
      'scenario': '${_baseStyleSceneName(kind)}_maximum_scroll',
      'passed': true,
      ..._snapshot(),
    });
    if (resultsOnly) {
      await _tapText('닫기');
      _require(
        !_has<AddContentSheet>() && _appKey.currentState!.calls == 1,
        'Result-only close did not dismiss without another save',
      );
      _checks.add({
        'scenario': '${_baseStyleSceneName(kind)}_result_close',
        'passed': true,
      });
    }
  }
  if (resultsOnly) {
    _checksCompleted = true;
    return;
  }
  await _baseStyleScene('valid');
  await _type('');
  await _pasteFromMobileClipboard(_url, waitForAndroidPreview: true);
  _require(
    (_first<EditableText>().widget as EditableText).controller.text == _url &&
        _text('유효한 링크예요!'),
    'Base mobile clipboard paste did not populate/validate URL',
  );
  _checkBaseStyle();
  _checks.add({
    'scenario': 'base_mobile_clipboard_paste',
    'passed': true,
    'clipboardVerified': true,
    'clipboardActionScope':
        'Mobile app Clipboard.setData then actual paste tap once; no host clipboard API',
    'androidClipboardPreviewWaitSeconds': Platform.isAndroid ? 8 : 0,
    ..._snapshot(),
  });
  final controller = (_first<EditableText>().widget as EditableText).controller;
  await _tapText('사진 첨부');
  await _selectPhoto();
  await _tapText('링크 첨부');
  _require(
    identical(
          (_first<EditableText>().widget as EditableText).controller,
          controller,
        ) &&
        controller.text == _url,
    'Tab switch replaced link controller/input',
  );
  final shown = await _showKeyboard();
  _require(shown > 0, 'Base run OS keyboard inset was not measured');
  _checkFooter();
  _checkBaseStyle();
  _appKey.currentState!.mode = 'fail';
  await _save();
  // Check the real three-second toast immediately after the save tap settles;
  // do not spend additional screenshot/keyboard waits before observing it.
  _require(
    _has<SaveErrorToast>() && !_has<SavedContentConfirmation>(),
    'Base retry failure toast missing',
  );
  _require(
    identical(
          (_first<EditableText>().widget as EditableText).controller,
          controller,
        ) &&
        controller.text == _url,
    'Failure replaced link controller/input',
  );
  _checkFooter();
  _checks.add({
    'scenario': 'base_link_keyboard_failure',
    'passed': true,
    'shownInset': shown,
    ..._snapshot(),
  });
  _appKey.currentState!.mode = 'success';
  final button = _rect(_first<SaveFlowButton>());
  await _tap(Offset(button.center.dx, button.bottom - 2));
  _require(
    _has<SavedContentConfirmation>() && _appKey.currentState!.calls == 2,
    'Base keyboard retry did not save',
  );
  await _tapText('사진 첨부');
  _require(
    _selectedTabFromUnderline() == '링크 첨부',
    'Base link completed tab is not pinned',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _settle(12);
  _require(
    MediaQuery.of(_first<AddContentSheet>()).viewInsets.bottom == 0,
    'Base run keyboard did not hide',
  );
  await _scrollToMax();
  _checkFooter(atMaximum: true);
  _checkBaseStyle();
  _checks.add({
    'scenario': 'base_link_retry_keyboard_hide_pinned',
    'passed': true,
    ..._snapshot(),
  });
  await _tapText('닫기');
  _require(!_has<AddContentSheet>(), 'Base result close did not dismiss');
  _checks.add({'scenario': 'base_result_close', 'passed': true});

  await _baseStyleScene('photo-selected');
  await _selectPhoto();
  _require(_picker.calls == 2, 'Base photo reselection not invoked');
  await _save();
  final result =
      _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
  _require(
    result.originalUrl == 'other-photo.png' &&
        result.photoBytes != null &&
        _same(result.photoBytes!, _picker.alternate),
    'Base reselected photo did not submit',
  );
  await _tapText('링크 첨부');
  _require(
    _selectedTabFromUnderline() == '사진 첨부',
    'Base photo completed tab is not pinned',
  );
  _checkBaseStyle();
  _checks.add({
    'scenario': 'base_photo_reselect_save_pinned',
    'passed': true,
    ..._snapshot(),
  });
  await _tapText('닫기');
  _require(!_has<AddContentSheet>(), 'Base photo close did not dismiss');

  await _open('link', scale: 1, mode: 'pending');
  await _save();
  final state = _appKey.currentState!;
  _require(
    state.calls == 1 && state.pending != null,
    'Base pending save missing',
  );
  await _save();
  _require(state.calls == 1, 'Base duplicate save not blocked');
  await _tapText('사진 첨부');
  await _selectPhoto();
  state.pending!.complete(_content('link'));
  await _settle();
  final pendingResult =
      _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
  _require(
    pendingResult.originalUrl == _url &&
        pendingResult.photoBytes == null &&
        _selectedTabFromUnderline() == '링크 첨부',
    'Base pending switch changed submitted input/result',
  );
  _checkBaseStyle();
  _checks.add({
    'scenario': 'base_pending_tab_switch_input_snapshot',
    'passed': true,
    ..._snapshot(),
  });
  await _open('link', scale: 1, mode: 'pending');
  await _save();
  final late = state.pending!;
  final close = _elements(
    _first<SaveContentTopBar>(),
  ).firstWhere((e) => e.widget is IconButton);
  await _tap(_rect(close).center);
  _require(!_has<AddContentSheet>(), 'Base top close did not dismiss');
  late.complete(_content('link'));
  await _settle();
  _require(!_has<AddContentSheet>(), 'Base late completion reopened dialog');
  _checks.add({'scenario': 'base_pending_close_late_response', 'passed': true});
  _checksCompleted = true;
}

Future<void> _photoFrameRun() async {
  _checksCompleted = false;
  await _baseStyleScene('photo-selected', photoCase: 'landscape');
  _require(_picker.calls == 1, 'Photo-frame initial selection missing');
  _require(
    _photoFrameMetrics()['photoMatchesOriginal'] == true &&
        _selectedTabFromUnderline() == '사진 첨부',
    'Photo-frame initial bytes/tab changed',
  );
  await _capture('photo_frame_selected_scale_1');
  _picker.cancelNext = true;
  await _selectPhoto();
  _require(
    _picker.calls == 1 && _photoFrameMetrics()['photoMatchesOriginal'] == true,
    'Photo selection cancel changed existing bytes',
  );
  _checks.add({
    'scenario': 'photo_frame_selection_cancel_preserves_bytes',
    'passed': true,
    ..._snapshot(),
  });

  await _tapText('링크 첨부');
  await _type(_url);
  final controller = (_first<EditableText>().widget as EditableText).controller;
  await _tapText('사진 첨부');
  _require(
    _picker.calls == 1 &&
        _photoFrameMetrics()['photoMatchesOriginal'] == true &&
        _appKey.currentState!.calls == 0,
    'Photo-frame tab round trip changed selected bytes or submitted',
  );
  _checkBaseStyle();
  _checks.add({
    'scenario': 'photo_frame_tab_round_trip_preserves_photo',
    'passed': true,
    ..._snapshot(),
  });

  await _selectPhoto();
  _require(
    _picker.calls == 2 && _photoFrameMetrics()['photoMatchesAlternate'] == true,
    'Photo-frame reselection did not replace bytes',
  );
  await _capture('photo_frame_reselected_tall_scale_1');
  await _tapText('링크 첨부');
  _require(
    identical(
          (_first<EditableText>().widget as EditableText).controller,
          controller,
        ) &&
        controller.text == _url,
    'Photo-frame tab round trip replaced link controller/draft',
  );
  await _tapText('사진 첨부');
  _require(
    _picker.calls == 2 && _photoFrameMetrics()['photoMatchesAlternate'] == true,
    'Photo-frame tab return changed reselected bytes',
  );
  _checkBaseStyle();
  _checks.add({
    'scenario': 'photo_frame_reselect_and_link_draft_preserved',
    'passed': true,
    ..._snapshot(),
  });

  if (_bodyPosition.maxScrollExtent > 0) {
    await _drag(const Offset(0, -180));
    _require(_bodyPosition.pixels > 0, 'Photo frame did not respond to drag');
  }
  await _scrollToMax();
  _checkFooter(atMaximum: true);
  _checkBaseStyle();
  _checks.add({
    'scenario': 'photo_frame_maximum_scroll',
    'passed': true,
    ..._snapshot(),
  });
  _bodyPosition.jumpTo(0);
  await _settle();
  final state = _appKey.currentState!;
  state.mode = 'fail';
  await _save();
  _require(
    _has<SaveErrorToast>() &&
        !_has<SavedContentConfirmation>() &&
        _photoFrameMetrics()['photoMatchesAlternate'] == true,
    'Failed photo save did not preserve selected bytes',
  );
  _checks.add({
    'scenario': 'photo_frame_save_failure_preserves_tall_bytes',
    'passed': true,
    ..._snapshot(),
  });
  state.mode = 'success';
  await _save();
  final result =
      _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
  _require(
    state.calls == 2 &&
        state.submissions.length == 2 &&
        state.submissions.every(
          (s) =>
              s['kind'] == 'photo' &&
              s['filename'] == 'other-photo.png' &&
              s['byteLength'] == _picker.alternate.length &&
              s['matchesAlternatePhoto'] == true,
        ) &&
        result.originalUrl == 'other-photo.png' &&
        result.photoBytes != null &&
        _same(result.photoBytes!, _picker.alternate),
    'Photo-frame failed/retry attempts must use exact same original selected bytes and filename',
  );
  _checkBaseStyle();
  _checks.add({
    'scenario': 'photo_frame_reselected_submission',
    'passed': true,
    'submittedBytesMatchAlternate': true,
    ..._snapshot(),
  });
  await _tapText('링크 첨부');
  final pinned =
      _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
  _require(
    _selectedTabFromUnderline() == '사진 첨부' &&
        pinned.originalUrl == result.originalUrl &&
        identical(pinned.photoBytes, result.photoBytes) &&
        state.calls == 2,
    'Photo-frame completion tab/result changed or resubmitted',
  );
  await _scrollToMax();
  _checkFooter(atMaximum: true);
  _checkBaseStyle();
  _checks.add({
    'scenario': 'photo_frame_result_pinned_maximum_scroll',
    'passed': true,
    ..._snapshot(),
  });
  await _tapText('닫기');
  _require(
    !_has<AddContentSheet>() && state.calls == 2,
    'Photo-frame close failed or submitted again',
  );
  _checks.add({'scenario': 'photo_frame_close', 'passed': true});
  _checksCompleted = true;
}

Map<String, Object?> _snapshot() {
  final confirmation = _has<SavedContentConfirmation>()
      ? _first<SavedContentConfirmation>().widget as SavedContentConfirmation
      : null;
  final context = _has<AddContentSheet>()
      ? _first<AddContentSheet>()
      : _navigatorKey.currentContext!;
  final media = MediaQuery.of(context);
  final selectedTab = _selectedTabFromUnderline();
  return {
    'scene': _scene,
    'photoCase': _photoCase,
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
    'maxScrollExtent': _has<SingleChildScrollView>()
        ? _bodyPosition.maxScrollExtent
        : null,
    'footerMetrics': _footerMetrics(),
    'pasteMetrics': _pasteMetrics(),
    'pasteLayoutFindings': _pasteFindings(),
    'pasteLayoutPassed': _pasteFindings().isEmpty,
    'pasteStyleFindings': _pasteStyleFindings(),
    'pasteStylePassed': _pasteStyleFindings().isEmpty,
    'baseStyleKind': _baseStyleMode ? _baseStyleKind : null,
    'resultScreenMode': _resultScreenMode,
    'categoryState': _resultScreenMode ? _categoryState : null,
    'baseInputSetupScope': _baseStyleMode ? _baseInputSetupScope : null,
    'baseStyleMetrics': _baseStyleMode ? _baseStyleMetrics() : null,
    'baseStyleFindings': _baseStyleFindings(),
    'baseStylePassed': _baseStyleFindings().isEmpty,
    'baseLayoutFindings': _baseLayoutFindings(),
    'baseLayoutPassed': _baseLayoutFindings().isEmpty,
    'resultScreenStyleFindings': _resultScreenStyleFindings(),
    'resultScreenStylePassed': _resultScreenStyleFindings().isEmpty,
    'resultSummaryLayoutFindings': _resultSummaryLayoutFindings(),
    'resultSummaryLayoutPassed': _resultSummaryLayoutFindings().isEmpty,
    'photoFrameMetrics': _photoFrameMetrics(),
    'photoFrameFindings': [
      ..._photoFrameStyleFindings(),
      ..._photoFrameLayoutFindings(),
    ],
    'photoFramePassed':
        _photoFrameStyleFindings().isEmpty &&
        _photoFrameLayoutFindings().isEmpty,
    'photoFrameStyleFindings': _photoFrameStyleFindings(),
    'photoFrameStylePassed': _photoFrameStyleFindings().isEmpty,
    'photoFrameLayoutFindings': _photoFrameLayoutFindings(),
    'photoFrameLayoutPassed': _photoFrameLayoutFindings().isEmpty,
    'targetStyleFindings': [
      ..._pasteStyleFindings(),
      ..._baseStyleFindings(),
      ..._photoFrameStyleFindings(),
    ],
    'targetStylePassed':
        _pasteStyleFindings().isEmpty &&
        _baseStyleFindings().isEmpty &&
        _photoFrameStyleFindings().isEmpty,
    'targetLayoutFindings': [
      ..._footerFindings(),
      ..._pasteFindings(),
      ..._baseLayoutFindings(),
      ..._photoFrameLayoutFindings(),
    ],
    'targetLayoutPassed':
        _footerFindings().isEmpty &&
        _pasteFindings().isEmpty &&
        _baseLayoutFindings().isEmpty &&
        _photoFrameLayoutFindings().isEmpty,
    'geometry': _geometry(),
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
  'frameworkErrors': _errors,
  'checksCompleted': _checksCompleted,
  'checks': _checks,
  'behaviorPassed':
      _checksCompleted && !_checks.any((c) => c['passed'] == false),
  'stylePassed': !_checks.any((c) => c['targetStylePassed'] == false),
  'layoutPassed':
      _errors.isEmpty && !_checks.any((c) => c['targetLayoutPassed'] == false),
  'passed':
      _checksCompleted &&
      !_checks.any((c) => c['passed'] == false) &&
      _errors.isEmpty &&
      !_checks.any((c) => c['targetLayoutPassed'] == false) &&
      !_checks.any((c) => c['targetStylePassed'] == false),
  ..._snapshot(),
};

Future<void> _report() => File('${_output.path}/report.json').writeAsString(
  const JsonEncoder.withIndent('  ').convert({
    ..._status(),
    'passed':
        _checksCompleted &&
        !_checks.any((c) => c['passed'] == false) &&
        _errors.isEmpty &&
        !_checks.any((c) => c['targetLayoutPassed'] == false) &&
        !_checks.any((c) => c['targetStylePassed'] == false),
    'checksCompleted': _checksCompleted,
    'behaviorPassed':
        _checksCompleted && !_checks.any((c) => c['passed'] == false),
    'layoutPassed':
        _errors.isEmpty &&
        !_checks.any((c) => c['targetLayoutPassed'] == false),
    'stylePassed': !_checks.any((c) => c['targetStylePassed'] == false),
    'scope':
        'Style and geometry judgments remain separate. Five screen-level result states include photo summary/image/semantic filename, photo-only thumbnail border, natural category Wrap and exact colored SVG; all target findings contribute to style/layout/overall passed. Before-phase target differences are diagnostic and do not stop capture. Legacy seven-state and expanded-scale routes remain. Real dialog, deterministic memory callbacks/picker, synthetic input; API/auth/physical-device verification is not claimed.',
    'checks': _checks,
    'frameworkErrors': _errors,
  }),
);

Future<void> _run() async {
  _checksCompleted = false;
  for (final kind in [
    'link-input',
    'photo-empty',
    'photo-selected',
    'link',
    'photo',
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      await _open(kind, scale: scale);
      if (_isResult(kind)) await _save();
      _checkScene(kind, scale);
      await _capture(_sceneName(kind, scale));
      await _scrollToMax();
      _checkFooter(atMaximum: true);
      _checks.add({
        'scenario': '${_sceneName(kind, scale)}_maximum_scroll',
        'passed': true,
        ..._snapshot(),
      });
      if (kind == 'photo-empty') {
        final button = _first<SaveFlowButton>().widget as SaveFlowButton;
        _require(!button.enabled, 'Empty photo unexpectedly enables saving');
      } else if (_isResult(kind)) {
        await _tapText('닫기');
        _require(!_has<AddContentSheet>(), 'Close did not dismiss dialog');
      }
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
  await _open('photo', scale: 2);
  await _save();
  await _drag(const Offset(0, -220));
  _require(
    ((_snapshot()['scrollOffset'] as double?) ?? 0) > 0,
    'Expanded result did not scroll',
  );
  await _capture('photo_scale_2_scrolled');
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
  await _open('photo');
  await _selectPhoto();
  _require(_picker.calls == 2, 'Photo reselection was not invoked');
  await _save();
  final reselected =
      _first<SavedContentConfirmation>().widget as SavedContentConfirmation;
  _require(
    reselected.originalUrl == 'other-photo.png' &&
        reselected.photoBytes != null &&
        _same(reselected.photoBytes!, _picker.alternate),
    'Reselected photo was not submitted/displayed',
  );
  _checks.add({'scenario': 'photo_reselection', 'passed': true});
  for (final scale in [1.0, 1.5, 2.0]) {
    await _open('link-input', scale: scale, mode: 'fail');
    final controller =
        (_first<EditableText>().widget as EditableText).controller;
    final shown = await _showKeyboard();
    await _capture(_sceneName('keyboard', scale));
    _checkFooter();
    final covered = _footerMetrics()['buttonCoveredByKeyboard'] == true;
    if (_phase == 'after') {
      _require(shown > 0, 'Actual OS keyboard inset was not measured');
    }
    if (_phase == 'before' && covered) {
      // Flutter synthetic pointer dispatch could bypass the OS IME window. Do
      // not report such a tap as proof that an obscured CTA is accessible.
      _checks.add({
        'scenario': 'keyboard_save_unavailable_scale_$scale',
        'passed': true,
        'expectedBaselineFailure': true,
        'reason':
            'CTA is below OS keyboard top; retry checked after hiding IME',
        ..._snapshot(),
      });
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await _settle(12);
    }
    await _save();
    _require(
      _has<SaveErrorToast>() && !_has<SavedContentConfirmation>(),
      'Keyboard failure did not retain input/error',
    );
    _require(
      identical(
            (_first<EditableText>().widget as EditableText).controller,
            controller,
          ) &&
          controller.text == _url,
      'Failure replaced controller/draft',
    );
    await _scrollToMax();
    _checkFooter(atMaximum: true);
    await _capture(_sceneName('error_keyboard', scale));
    _appKey.currentState!.mode = 'success';
    // Verify the lower part of the CTA remains an active tap target.
    final button = _rect(_first<SaveFlowButton>());
    await _tap(Offset(button.center.dx, button.bottom - 2));
    _require(
      _has<SavedContentConfirmation>() && _appKey.currentState!.calls == 2,
      'Keyboard manual retry did not save',
    );
    _require(_snapshot()['selectedTab'] == '링크 첨부', 'Retry tab changed');
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await _settle(12);
    _require(
      MediaQuery.of(_first<AddContentSheet>()).viewInsets.bottom == 0,
      'Keyboard inset was not cleared',
    );
    await _scrollToMax();
    _checkFooter(atMaximum: true);
    await _capture(_sceneName('keyboard_hidden_result', scale));
    await _tapText('닫기');
    _require(!_has<AddContentSheet>(), 'Keyboard flow close failed');
    _checks.add({
      'scenario': 'keyboard_fail_retry_close_scale_$scale',
      'passed': true,
      'shownInset': shown,
      'keyboardVisibilityMeasured': shown > 0,
      'baselineHadCoveredCta': covered,
    });
  }
  _checksCompleted = true;
}
