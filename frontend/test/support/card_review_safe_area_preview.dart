// Device-only, deterministic card review fixture; production main is unchanged.
// flutter run --no-pub -t test/support/card_review_safe_area_preview.dart
// --dart-define=CARD_REVIEW_PHASE=before|after
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/shared/data/sample_contents.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const _phase = String.fromEnvironment(
  'CARD_REVIEW_PHASE',
  defaultValue: 'before',
);
final _appKey = GlobalKey<_PreviewState>();
final _captureKey = GlobalKey();
final _errors = <Map<String, String>>[];
final _measurements = <Map<String, Object?>>[];
final _contents = initialContents.take(4).toList();
late Directory _output;
int _pointer = 4000;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _output = await Directory.systemTemp.createTemp('clipback-card-review-');
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add({
      'scene': _appKey.currentState?.scene ?? 'normal',
      'error': details.exceptionAsString(),
      'stack': details.stack?.toString() ?? '',
    });
    previous?.call(details);
  };
  runApp(_Preview(key: _appKey));
  Object? failure;
  var checksCompleted = false;
  try {
    _require(_phase == 'before' || _phase == 'after', 'Unknown phase');
    await _settle();
    await Future<void>.delayed(const Duration(seconds: 15));
    await _runChecks();
    checksCompleted = true;
    _require(_errors.isEmpty, 'Flutter framework errors occurred');
  } catch (error, stack) {
    failure = error;
    debugPrint('CARD_REVIEW FAIL: $error\n$stack');
  } finally {
    FlutterError.onError = previous;
    await File('${_output.path}/report.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'phase': _phase,
        'passed': failure == null,
        'checksCompleted': checksCompleted,
        'scope':
            'Real card review normal/empty/drag at text scale 1; memory data and synthetic pointer input',
        'safeAreaCriterion':
            'after: clip bottom equals logical screen height minus OS viewPadding.bottom',
        'platform': Platform.operatingSystem,
        'logicalSize': '${_view.physicalSize / _view.devicePixelRatio}',
        'pixelRatio': _view.devicePixelRatio,
        'contentIds': _contents.map((item) => item.id).toList(),
        'categoryName': '일상',
        'callbackCounts': _appKey.currentState!.counts,
        'measurements': _measurements,
        'frameworkErrors': _errors,
        'failure': failure?.toString(),
      }),
    );
    debugPrint(
      'CARD_REVIEW ${failure == null ? 'PASS' : 'FAIL'} output=${_output.path}',
    );
  }
}

class _Preview extends StatefulWidget {
  const _Preview({super.key});
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  var empty = false;
  var exited = false;
  var dragging = false;
  final counts = <String, int>{};
  final bookmarkedIds = <String>{};
  String get scene => exited
      ? 'exited'
      : empty
      ? 'empty'
      : dragging
      ? 'dragging'
      : 'normal';
  void count(String name) =>
      counts.update(name, (n) => n + 1, ifAbsent: () => 1);
  void showEmpty() => setState(() {
    empty = true;
    exited = false;
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _captureKey,
    child: MaterialApp(
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: PhoneFrame(
        child: exited
            ? const Scaffold(body: Center(child: Text('카드 다시보기 종료')))
            : CategoryCardReviewScreen(
                key: ValueKey(empty),
                contents: empty ? const [] : _contents,
                categoryName: '일상',
                bookmarkedIds: bookmarkedIds,
                onExit: () => setState(() {
                  count(empty ? 'exitEmpty' : 'exitNormal');
                  exited = true;
                }),
                onOpenContent: (_) => count('openContent'),
                onToggleBookmark: (item) => setState(() {
                  count('bookmark');
                  if (!bookmarkedIds.add(item.id)) {
                    bookmarkedIds.remove(item.id);
                  }
                }),
              ),
      ),
    ),
  );
}

ui.FlutterView get _view => View.of(_captureKey.currentContext!);
Element get _root => _captureKey.currentContext! as Element;
void _require(bool value, String message) {
  if (!value) throw StateError(message);
}

List<Element> _all(Element root) {
  final result = <Element>[];
  void visit(Element e) {
    if (e.widget case Offstage(offstage: true)) return;
    result.add(e);
    e.visitChildren(visit);
  }

  visit(root);
  return result;
}

Element _first<T extends Widget>([Element? root]) =>
    _all(root ?? _root).firstWhere((e) => e.widget is T);
Rect _rect(Element e) {
  final box = e.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
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

Future<void> _capture(String name) async {
  await _settle();
  final screen = _first<CategoryCardReviewScreen>();
  final media = MediaQuery.of(screen);
  final viewport = _rect(
    _appKey.currentState!.empty
        ? _first<EmptyStatePanel>()
        : _first<ClipRect>(screen),
  );
  final logicalHeight = _view.physicalSize.height / _view.devicePixelRatio;
  final safeBottom = logicalHeight - media.viewPadding.bottom;
  if (_phase == 'after') {
    _require(
      (viewport.bottom - safeBottom).abs() < .5,
      'Review viewport must end at OS bottom safe area',
    );
  }
  final measurement = <String, Object?>{
    'capture': name,
    'scene': _appKey.currentState!.scene,
    'viewportTop': viewport.top,
    'viewportBottom': viewport.bottom,
    'safeBottom': safeBottom,
    'paddingBottom': media.padding.bottom,
    'viewPaddingBottom': media.viewPadding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
  };
  if (!_appKey.currentState!.empty) {
    final active = _first<AnimatedSlide>(screen);
    final card = _rect(active);
    measurement.addAll({
      'activeCardKey': active.widget.key.toString(),
      'cardTop': card.top,
      'cardBottom': card.bottom,
      'dragOffsetY': (active.widget as AnimatedSlide).offset.dy,
      'activeIndex':
          (_first<CardPagerProgress>().widget as CardPagerProgress).activeIndex,
    });
  }
  _measurements.add(measurement);
  final image =
      await (_captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: _view.devicePixelRatio);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    _require(bytes != null, 'PNG encoding failed');
    await File('${_output.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  debugPrint('CARD_REVIEW capture=$name output=${_output.path}');
  await Future<void>.delayed(const Duration(seconds: 8));
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

Future<void> _runChecks() async {
  final state = _appKey.currentState!;
  await _capture('00_normal');
  final card = _first<CategoryReviewCard>(_first<AnimatedSlide>());
  final bookmark = _all(card).firstWhere(
    (e) =>
        e.widget is InkWell &&
        (e.widget as InkWell).onTap ==
            (card.widget as CategoryReviewCard).onToggleBookmark,
  );
  await _tap(_rect(bookmark).center);
  _require(
    state.counts['bookmark'] == 1 && state.counts['openContent'] == null,
    'Bookmark must fire once without opening',
  );
  await _tap(_rect(card).center);
  _require(state.counts['openContent'] == 1, 'Card must open once');
  final active = _first<AnimatedSlide>();
  final start = _rect(active).center;
  final pointer = ++_pointer;
  state.dragging = true;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, viewId: _view.viewId, position: start),
  );
  var previous = start;
  for (var step = 1; step <= 12; step++) {
    final next = start + Offset(0, step * 30);
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
  _require(
    (_first<AnimatedSlide>().widget as AnimatedSlide).offset.dy > .1,
    'Pointer input must drag the card',
  );
  await _capture('01_dragging');
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      viewId: _view.viewId,
      position: previous,
      timeStamp: const Duration(seconds: 9),
    ),
  );
  state.dragging = false;
  await _settle(12);
  _require(
    (_first<CardPagerProgress>().widget as CardPagerProgress).activeIndex == 1,
    'Drag must advance to next card',
  );
  await _capture('02_advanced');
  await _tap(_rect(_first<TextButton>()).center);
  _require(
    state.counts['exitNormal'] == 1 &&
        state.exited &&
        !_all(_root).any((e) => e.widget is CategoryCardReviewScreen),
    'Normal exit must fire once and close review',
  );
  _measurements.add({'scenario': 'normalExit', 'closed': true});
  await Future<void>.delayed(const Duration(seconds: 2));
  state.showEmpty();
  await _settle();
  await _capture('03_empty');
  await _tap(_rect(_first<OutlinedButton>()).center);
  _require(
    state.counts['exitEmpty'] == 1 &&
        state.exited &&
        !_all(_root).any((e) => e.widget is CategoryCardReviewScreen),
    'Empty exit must fire once and close review',
  );
  _measurements.add({'scenario': 'emptyExit', 'closed': true});
  await Future<void>.delayed(const Duration(seconds: 2));
}
