// Local, device-only fixture; no session, HTTP client, or native share service.
// flutter run --no-pub -t test/support/figma_common_style_preview.dart
// Add --dart-define=FIGMA_COMMON_STYLE_CHECK=true for captures and pointer checks.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/data/sample_categories.dart';
import 'package:clipback_frontend/shared/data/sample_contents.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/section_header.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const _automatic = bool.fromEnvironment('FIGMA_COMMON_STYLE_CHECK');
const _longTitle = '아주 긴 콘텐츠 제목이 들어와도 오른쪽 아이콘과 겹치지 않아요';
final _appKey = GlobalKey<_PreviewState>();
final _captureKey = GlobalKey();
final _headerKey = GlobalKey();
final _defaultButtonKey = GlobalKey();
final _customButtonKey = GlobalKey();
final _measurements = <Map<String, Object?>>[];
final _frameworkErrors = <String>[];
final _frameworkErrorDetails = <Map<String, String>>[];
late Directory _output;
int _pointer = 1500;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final previousErrorHandler = FlutterError.onError;
  if (_automatic) {
    _output = await Directory.systemTemp.createTemp('clipback-common-style-');
    FlutterError.onError = (details) {
      final error = details.exceptionAsString();
      _frameworkErrors.add(error);
      _frameworkErrorDetails.add({
        'scene': _appKey.currentState?.scene.name ?? _Scene.home.name,
        'error': error,
      });
      previousErrorHandler?.call(details);
    };
  }
  runApp(const _PreviewApp());
  if (!_automatic) return;
  Object? failure;
  var checksCompleted = false;
  try {
    await _settle();
    await Future<void>.delayed(const Duration(seconds: 15));
    await _runChecks();
    checksCompleted = true;
    _require(_frameworkErrors.isEmpty, 'Flutter framework errors occurred');
  } catch (error, stack) {
    failure = error;
    debugPrint('FIGMA_COMMON_STYLE FAIL: $error\n$stack');
  } finally {
    FlutterError.onError = previousErrorHandler;
    final componentFrameworkErrors = _frameworkErrorDetails
        .where(
          (details) =>
              details['scene'] == _Scene.components.name ||
              details['scene'] == _Scene.scaled.name,
        )
        .toList();
    await File('${_output.path}/report.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'passed': failure == null,
        'execution':
            'device rendering with in-memory data and synthetic pointers',
        'scope':
            'SectionHeader style, layout, hit area; PrimaryButton behavior',
        'outsideScope':
            'Existing home layout, illustrations, home icons and data policy',
        'platform': Platform.operatingSystem,
        'logicalSize': '${_view.physicalSize / _view.devicePixelRatio}',
        'pixelRatio': _view.devicePixelRatio,
        'topInset': _view.padding.top / _view.devicePixelRatio,
        'bottomInset': _view.padding.bottom / _view.devicePixelRatio,
        'measurements': _measurements,
        'callbackCounts': _appKey.currentState!.counts,
        'checksCompleted': checksCompleted,
        'componentChecksPassed':
            checksCompleted && componentFrameworkErrors.isEmpty,
        'componentFrameworkErrors': componentFrameworkErrors,
        'frameworkErrors': _frameworkErrors,
        'frameworkErrorDetails': _frameworkErrorDetails,
        'failure': failure?.toString(),
      }),
    );
    debugPrint(
      'FIGMA_COMMON_STYLE ${failure == null ? 'PASS' : 'FAIL'} output=${_output.path}',
    );
  }
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    scrollBehavior: const AppScrollBehavior(),
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(maxWidth: phoneWidth),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.main,
        surface: AppColors.bg,
      ),
      fontFamily: 'Pretendard',
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
    ),
    home: _Preview(key: _appKey),
  );
}

enum _Scene { home, empty, components, scaled }

class _Preview extends StatefulWidget {
  const _Preview({super.key});

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  _Scene scene = _Scene.home;
  final counts = <String, int>{};

  void count(String name) =>
      counts.update(name, (value) => value + 1, ifAbsent: () => 1);
  void show(_Scene next) => setState(() => scene = next);

  @override
  Widget build(BuildContext context) {
    final components = scene == _Scene.components || scene == _Scene.scaled;
    final body = RepaintBoundary(
      key: _captureKey,
      child: components
          ? MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scene == _Scene.scaled ? 2 : 1),
              ),
              child: _components(),
            )
          : HomeScreen(
              key: ValueKey(scene),
              contents: scene == _Scene.home ? initialContents : const [],
              categories: initialCategories,
              bookmarkedIds: {
                for (final item in initialContents)
                  if (item.bookmarked) item.id,
              },
              onSearch: () => count('search'),
              onOpenArchive: () => count('archive'),
              onOpenCategories: () => count('categories'),
              onOpenToday: () => count('today'),
              onOpenContent: (_) => count('content'),
              onToggleBookmark: (_) => count('bookmark'),
              onAddLink: ({required url, category}) =>
                  Future<ContentItem>.error(
                    UnsupportedError('Fixture does not save'),
                  ),
              onAddScreenshot:
                  ({required bytes, required filename, category}) =>
                      Future<ContentItem>.error(
                        UnsupportedError('Fixture does not save'),
                      ),
              onTab: (_) => count('tab'),
            ),
    );
    if (_automatic) return body;
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Wrap(
              children: [
                for (final next in _Scene.values)
                  TextButton(
                    onPressed: () => show(next),
                    child: Text(next.name),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _components() => PhoneFrame(
    child: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              SectionHeader(
                key: _headerKey,
                title: _longTitle,
                onTap: () => count('header'),
              ),
              const SizedBox(height: 16),
              SectionHeader(
                title: '최근 저장한 콘텐츠',
                onTap: () => count('shortHeader'),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    PrimaryButton(
                      key: _defaultButtonKey,
                      label: '기본 버튼',
                      onPressed: () => count('defaultButton'),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      key: _customButtonKey,
                      label: '색상 지정 버튼',
                      height: 52,
                      color: AppColors.main,
                      foreground: AppColors.text,
                      onPressed: () => count('customButton'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

ui.FlutterView get _view => View.of(_captureKey.currentContext!);
void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

List<Element> _elements(Element root) {
  final result = <Element>[];
  void visit(Element element) {
    if (element.widget case Offstage(offstage: true)) return;
    result.add(element);
    element.visitChildren(visit);
  }

  visit(root);
  return result;
}

Element _first<T extends Widget>(Element root) =>
    _elements(root).firstWhere((element) => element.widget is T);
Element _root(GlobalKey key) => key.currentContext! as Element;
Rect _rect(Element element) {
  final box = element.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> _settle([int frames = 6]) async {
  for (var index = 0; index < frames; index++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _capture(String name) async {
  await _settle(2);
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: _view.devicePixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    _require(data != null, 'PNG encoding failed');
    await File('${_output.path}/$name.png').writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  debugPrint('FIGMA_COMMON_STYLE capture=$name output=${_output.path}');
  await Future<void>.delayed(const Duration(seconds: 2));
}

Future<void> _tap(Offset point) async {
  final pointer = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, viewId: _view.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 100));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      viewId: _view.viewId,
      position: point,
      timeStamp: const Duration(milliseconds: 100),
    ),
  );
  await _settle();
}

Future<void> _scrollHome() async {
  final root = _root(_captureKey);
  final scroll =
      _first<Scrollable>(_first<HomeScreen>(root)) as StatefulElement;
  final position = (scroll.state as ScrollableState).position;
  _require(position.maxScrollExtent > 0, 'Home must have scrollable content');
  final before = position.pixels;
  final viewport = _rect(scroll);
  final start = Offset(viewport.left + 8, viewport.bottom - 80);
  final pointer = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, viewId: _view.viewId, position: start),
  );
  var previous = start;
  for (var step = 1; step <= 12; step++) {
    final next = start - Offset(0, step * 10);
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: pointer,
        viewId: _view.viewId,
        position: next,
        delta: next - previous,
        timeStamp: Duration(milliseconds: step * 65),
      ),
    );
    previous = next;
    await Future<void>.delayed(const Duration(milliseconds: 65));
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      viewId: _view.viewId,
      position: previous,
      timeStamp: const Duration(milliseconds: 900),
    ),
  );
  await _settle(12);
  _require(
    position.pixels > before + 20,
    'Synthetic pointer did not scroll home',
  );
  _measurements.add({
    'scene': 'home_scroll',
    'before': before,
    'after': position.pixels,
    'pointerTravel': 120,
  });
}

Future<void> _runChecks() async {
  final state = _appKey.currentState!;
  await _capture('00_home');
  await _scrollHome();
  await _capture('01_home_scrolled');
  final homeHeader = _first<SectionHeader>(
    _first<HomeScreen>(_root(_captureKey)),
  );
  final callback = state.counts['categories'] ?? 0;
  await _tap(_rect(_first<Text>(homeHeader)).center);
  _require(
    state.counts['categories'] == callback + 1,
    'Home title tap must fire once',
  );
  _measurements.add({'scene': 'home_title_tap', 'callbackIncrement': 1});
  state.show(_Scene.empty);
  await _settle();
  await _capture('02_empty_home');
  state.show(_Scene.components);
  await _settle();
  final normalHeight = await _checkComponents(1);
  await _capture('03_components');
  state.show(_Scene.scaled);
  await _settle();
  final scaledHeight = await _checkComponents(2);
  _require(scaledHeight > normalHeight, 'Scaled SectionHeader must grow');
  await _capture('04_components_scale_2');
}

Future<double> _checkComponents(double scale) async {
  final state = _appKey.currentState!;
  final header = _root(_headerKey);
  final rect = _rect(header);
  final title = _first<Text>(header);
  final icon = _rect(_first<SvgIcon>(header));
  final titleRect = _rect(title);
  final text = title.widget as Text;
  _require(
    text.maxLines == 1 && text.overflow == TextOverflow.ellipsis,
    'Long header must use one-line ellipsis',
  );
  _require(titleRect.right <= icon.left + 0.5, 'Title overlaps icon');
  _require(
    (icon.width - 24).abs() < 0.5 && (icon.height - 24).abs() < 0.5,
    'Icon must remain 24px',
  );
  _require(
    scale != 1 || (rect.height - 44).abs() < 0.5,
    'Normal SectionHeader must be 44px',
  );
  final before = state.counts['header'] ?? 0;
  await _tap(Offset(titleRect.left + 20, titleRect.center.dy));
  await _tap(Offset(rect.left + 8, rect.center.dy));
  await _tap(icon.center);
  _require(
    state.counts['header'] == before + 3,
    'Title, padding, icon taps must each fire once',
  );
  final buttonChecks = <Map<String, Object?>>[];
  for (final entry in [
    (_defaultButtonKey, 'defaultButton', 56.0, AppColors.main),
    (_customButtonKey, 'customButton', 52.0, AppColors.text),
  ]) {
    final button = _root(entry.$1);
    final buttonRect = _rect(button);
    final buttonText = _first<Text>(button);
    final foreground = DefaultTextStyle.of(buttonText).style.color;
    _require(
      (buttonRect.height - entry.$3).abs() < 0.5,
      '${entry.$2} height changed',
    );
    _require(foreground == entry.$4, '${entry.$2} foreground changed');
    final count = state.counts[entry.$2] ?? 0;
    await _tap(buttonRect.center);
    _require(state.counts[entry.$2] == count + 1, '${entry.$2} must fire once');
    buttonChecks.add({
      'button': entry.$2,
      'height': buttonRect.height,
      'foreground': foreground?.toARGB32(),
      'callbackIncrement': 1,
    });
  }
  _measurements.add({
    'scene': 'components',
    'textScale': scale,
    'headerHeight': rect.height,
    'titleWidth': titleRect.width,
    'iconWidth': icon.width,
    'iconHeight': icon.height,
    'headerCallbackIncrement': 3,
    'buttons': buttonChecks,
  });
  return rect.height;
}
