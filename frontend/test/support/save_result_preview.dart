// Local device fixture. Uses real save widgets, a deterministic file picker and
// in-memory save callbacks, with synthetic pointer/text input (no backend/auth).
// flutter run --no-pub -t test/support/save_result_preview.dart
//   --dart-define=SAVE_RESULT_PHASE=before|after
// HTTP loopback :8767: /status, /scene?kind=link-input|photo-empty|photo-selected|link|photo&scale=1|1.5|2, /run,
// /keyboard?scale=1|1.5|2, /error?scale=1|1.5|2&keyboard=1, /keyboard-hide,
// /scroll?max=1. Android host access: adb forward tcp:8768 tcp:8767.
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
        case '/keyboard':
          final scale = _requestedScale(request.uri);
          await _open('link-input', scale: scale);
          await _showKeyboard();
          _checkFooter();
          await _capture(_sceneName('keyboard', scale));
        case '/error':
          final scale = _requestedScale(request.uri);
          await _open('link-input', scale: scale, mode: 'fail');
          if (request.uri.queryParameters['keyboard'] == '1') {
            await _showKeyboard();
          }
          await _save();
          _require(_has<SaveErrorToast>(), 'Failure toast missing');
          await _scrollToMax();
          _checkFooter(atMaximum: true);
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
  category: catUncategorized.copyWith(name: '매일 다시 확인하는 아주 긴 카테고리 이름'),
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
  if (_has<SavedContentConfirmation>()) {
    final result = _first<SavedContentConfirmation>();
    final content = (result.widget as SavedContentConfirmation).content;
    final image = _elements(result).firstWhere((e) => e.widget is Image);
    final title = _elements(result).firstWhere(
      (e) => e.widget is Text && (e.widget as Text).data == content.title,
    );
    nodes['previewCard'] = _ancestor(image, (w) => w is Container);
    nodes['previewImage'] = image;
    nodes['previewTitle'] = title;
    nodes['previewSource'] = _elements(result).firstWhere(
      (e) => e.widget is Text && (e.widget as Text).data == content.source,
    );
    nodes['previewText'] = _ancestor(title, (w) => w is Column);
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
    'maxScrollExtent': _has<SingleChildScrollView>()
        ? _bodyPosition.maxScrollExtent
        : null,
    'footerMetrics': _footerMetrics(),
    'targetLayoutFindings': _footerFindings(),
    'targetLayoutPassed': _footerFindings().isEmpty,
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
  ..._snapshot(),
};

Future<void> _report() => File('${_output.path}/report.json').writeAsString(
  const JsonEncoder.withIndent('  ').convert({
    ..._status(),
    'passed':
        _checksCompleted &&
        !_checks.any((c) => c['passed'] == false) &&
        _errors.isEmpty &&
        !_checks.any((c) => c['targetLayoutPassed'] == false),
    'checksCompleted': _checksCompleted,
    'behaviorPassed':
        _checksCompleted && !_checks.any((c) => c['passed'] == false),
    'layoutPassed':
        _errors.isEmpty &&
        !_checks.any((c) => c['targetLayoutPassed'] == false),
    'scope':
        'Real dialog; in-memory callbacks and picker; synthetic pointer/text input. Framework layout errors are recorded separately from behavior checks.',
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
