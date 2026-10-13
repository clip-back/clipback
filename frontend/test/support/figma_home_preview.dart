// Device-only, in-memory home fixture. Production main is unchanged.
// flutter run --no-pub -t test/support/figma_home_preview.dart
// --dart-define=FIGMA_HOME_CHECK=true --dart-define=FIGMA_HOME_PHASE=before|after
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/data/sample_categories.dart';
import 'package:clipback_frontend/shared/data/sample_contents.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:clipback_frontend/shared/widgets/section_header.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const _automatic = bool.fromEnvironment('FIGMA_HOME_CHECK');
const _phase = String.fromEnvironment(
  'FIGMA_HOME_PHASE',
  defaultValue: 'before',
);
final _appKey = GlobalKey<_PreviewState>();
final _captureKey = GlobalKey();
final _measurements = <Map<String, Object?>>[];
final _errors = <Map<String, String>>[];
late Directory _output;
int _pointer = 2000;
bool _interactionChecksCompleted = false;
bool _scaledScenesCaptured = false;
const _longCategory = CategoryItem(
  id: 999,
  name: '카테고리 이름이 아주 길어도 저장한 콘텐츠를 보존하고 다시 확인할 수 있어요',
  color: AppColors.main,
  tint: AppColors.mainSubtle,
  deep: AppColors.mainDeep,
);

final _contents = [
  for (final id in [
    'job-cover-letter',
    'bathroom-cleaning',
    'japan-snack',
    'desk-products',
  ])
    initialContents.firstWhere((item) => item.id == id),
];

FeedPage _feed(List<ContentItem> contents) => FeedPage()
  ..initialized = true
  ..hasMore = false
  ..items.addAll(contents);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final previous = FlutterError.onError;
  if (_automatic) {
    _output = await Directory.systemTemp.createTemp('clipback-home-');
    FlutterError.onError = (details) {
      _errors.add({
        'scene': _appKey.currentState?.scene ?? 'home',
        'error': details.exceptionAsString(),
      });
      previous?.call(details);
    };
  }
  runApp(_Preview(key: _appKey));
  if (!_automatic) return;
  Object? failure;
  var baselineCaptured = false;
  var checksCompleted = false;
  try {
    _require(_phase == 'before' || _phase == 'after', 'Unknown phase: $_phase');
    await _settle();
    await Future<void>.delayed(const Duration(seconds: 15));
    for (final scene in [
      ('00_home', false, 1.0, false),
      ('01_empty_home', true, 1.0, false),
      ('02_home_scale_2', false, 2.0, false),
      ('03_empty_home_scale_2', true, 2.0, false),
      ('04_long_empty_home', true, 1.0, true),
      ('05_long_empty_home_scale_2', true, 2.0, true),
    ]) {
      _appKey.currentState!.show(
        empty: scene.$2,
        scale: scene.$3,
        longCategories: scene.$4,
      );
      await _settle();
      await _capture(scene.$1);
    }
    baselineCaptured = true;
    if (_phase == 'after') await _checkInteractions();
    checksCompleted = true;
    _require(_errors.isEmpty, 'Flutter framework errors occurred');
  } catch (error, stack) {
    failure = error;
    debugPrint('FIGMA_HOME FAIL: $error\n$stack');
  } finally {
    FlutterError.onError = previous;
    await File('${_output.path}/report.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'phase': _phase,
        'baselineCaptured': baselineCaptured,
        'passed': failure == null,
        'checksCompleted': checksCompleted,
        'interactionChecksCompleted': _interactionChecksCompleted,
        'normalHomeChecksPassed':
            _interactionChecksCompleted &&
            !_errors.any((error) => error['scene']!.endsWith('_scale_1.0')),
        'scaledScenesCaptured': _scaledScenesCaptured,
        'execution':
            'real HomeScreen, in-memory feed, synthetic pointer input; no HTTP/session/native share',
        'platform': Platform.operatingSystem,
        'logicalSize': '${_view.physicalSize / _view.devicePixelRatio}',
        'pixelRatio': _view.devicePixelRatio,
        'topInset': _view.padding.top / _view.devicePixelRatio,
        'bottomInset': _view.padding.bottom / _view.devicePixelRatio,
        'contentIds': _contents.map((item) => item.id).toList(),
        'categories': initialCategories.map((item) => item.name).toList(),
        'longCategoryName': _longCategory.name,
        'feed': {
          'initialized': true,
          'loading': false,
          'error': null,
          'categoryId': null,
        },
        'baselineTextScales': [1, 2],
        'baselineScrollOffset': 0,
        'callbackCounts': _appKey.currentState!.counts,
        'measurements': _measurements,
        'frameworkErrors': _errors,
        'failure': failure?.toString(),
      }),
    );
    debugPrint(
      'FIGMA_HOME ${failure == null ? 'PASS' : 'FAIL'} captured=$baselineCaptured output=${_output.path}',
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
  var longCategories = false;
  double scale = 1;
  int revision = 0;
  final counts = <String, int>{};
  final normalFeed = _feed(_contents);
  final emptyFeed = _feed([]);
  String get scene =>
      '${longCategories ? 'long_' : ''}${empty ? 'empty' : 'home'}_scale_$scale';
  void count(String key) => counts.update(key, (n) => n + 1, ifAbsent: () => 1);
  void show({
    required bool empty,
    double scale = 1,
    bool longCategories = false,
  }) => setState(() {
    this.empty = empty;
    this.scale = scale;
    this.longCategories = longCategories;
    revision++;
  });

  @override
  Widget build(BuildContext context) {
    final home = HomeScreen(
      key: ValueKey(revision),
      contents: empty ? const [] : _contents,
      feed: empty ? emptyFeed : normalFeed,
      categories: longCategories
          ? [_longCategory, ...initialCategories]
          : initialCategories,
      bookmarkedIds: {
        for (final item in _contents)
          if (item.bookmarked) item.id,
      },
      onSearch: () => count('search'),
      onOpenArchive: () => count('archive'),
      onOpenCategories: () => count('categories'),
      onOpenToday: () => count('today'),
      onOpenContent: (_) => count('content'),
      onToggleBookmark: (_) => count('bookmark'),
      onAddLink: ({required url, category}) =>
          Future<ContentItem>.error(UnsupportedError('Fixture does not save')),
      onAddScreenshot: ({required bytes, required filename, category}) =>
          Future<ContentItem>.error(UnsupportedError('Fixture does not save')),
      onTab: (_) => count('tab'),
    );
    return RepaintBoundary(
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
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: _automatic
            ? home
            : Scaffold(
                body: Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Wrap(
                        children: [
                          for (final isEmpty in [false, true])
                            for (final textScale in [1.0, 2.0])
                              TextButton(
                                onPressed: () =>
                                    show(empty: isEmpty, scale: textScale),
                                child: Text(
                                  '${isEmpty ? 'empty' : 'home'} $textScale',
                                ),
                              ),
                          TextButton(
                            onPressed: () =>
                                show(empty: true, longCategories: true),
                            child: const Text('long category'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: home),
                  ],
                ),
              ),
      ),
    );
  }
}

ui.FlutterView get _view => View.of(_captureKey.currentContext!);
void _require(bool value, String message) {
  if (!value) throw StateError(message);
}

Element get _root => _captureKey.currentContext! as Element;
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
Rect _rect(Element element) {
  final box = element.findRenderObject()! as RenderBox;
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
  if (_phase == 'after' && name != '07_empty_save_keyboard') {
    final bar = _first<ClipbackNavigationBar>();
    final nav = _rect(bar);
    final add = _rect(_first<NavAddButton>(bar));
    _require(
      (add.width - 72).abs() < .5 && (add.height - 72).abs() < .5,
      'Add button must render at 72 x 72',
    );
    _require(
      (add.top - (nav.top - 22)).abs() < .5,
      'Add button must keep its -22px offset',
    );
    _measurements.add({
      'scenario': 'navigationGeometry',
      'capture': name,
      'navHeight': nav.height,
      'addWidth': add.width,
      'addHeight': add.height,
      'addOffset': add.top - nav.top,
    });
  }
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: _view.devicePixelRatio);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    _require(bytes != null, 'PNG encoding failed');
    await File('${_output.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  debugPrint('FIGMA_HOME capture=$name output=${_output.path}');
  // BEFORE and AFTER hold identical scenes long enough for native screenshots.
  await Future<void>.delayed(const Duration(seconds: 8));
}

Future<void> _gesture(Offset start, Offset delta) async {
  final pointer = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, viewId: _view.viewId, position: start),
  );
  var previous = start;
  const steps = 12;
  for (var step = 1; step <= steps; step++) {
    final point = start + delta * (step / steps);
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: pointer,
        viewId: _view.viewId,
        position: point,
        delta: point - previous,
        timeStamp: Duration(milliseconds: step * 65),
      ),
    );
    previous = point;
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

ScrollableState get _vertical =>
    (_first<Scrollable>(_first<HomeScreen>()) as StatefulElement).state
        as ScrollableState;
Future<void> _verticalScroll() async {
  final state = _vertical;
  final before = state.position.pixels;
  final rect = _rect(state.context as Element);
  await _gesture(
    Offset(rect.left + 8, rect.bottom - 60),
    const Offset(0, -180),
  );
  _require(
    state.position.pixels > before + 20,
    'Home did not scroll from actual pointer input',
  );
  _measurements.add({
    'scenario': 'verticalScroll',
    'before': before,
    'after': state.position.pixels,
  });
}

Element _heroAction() {
  final hero = _first<HomeHero>();
  final callback = (hero.widget as HomeHero).onOpenToday;
  return _all(hero).firstWhere(
    (element) => switch (element.widget) {
      GestureDetector(:final onTap) => onTap == callback,
      InkWell(:final onTap) => onTap == callback,
      ButtonStyleButton(:final onPressed) => onPressed == callback,
      _ => false,
    },
  );
}

Future<void> _revealScaledCard() async {
  for (var attempt = 0; attempt < 12; attempt++) {
    final viewport = _rect(_vertical.context as Element);
    final card = _rect(_first<HomeContentCard>());
    if (card.top >= viewport.top && card.bottom <= viewport.bottom) {
      _measurements.add({
        'scenario': 'scaledCardVisible',
        'scrollOffset': _vertical.position.pixels,
        'cardTop': card.top,
        'cardBottom': card.bottom,
        'viewportTop': viewport.top,
        'viewportBottom': viewport.bottom,
      });
      return;
    }
    final distance = (card.bottom - viewport.bottom + 24).clamp(60.0, 300.0);
    await _gesture(
      Offset(viewport.left + 8, viewport.bottom - 40),
      Offset(0, -distance),
    );
  }
  throw StateError(
    'Scaled recent card could not be fully revealed by scrolling',
  );
}

Future<void> _checkInteractions() async {
  final state = _appKey.currentState!;
  state.show(empty: false);
  await _settle();
  final cta = _heroAction();
  await _tap(_rect(cta).center);
  _require(state.counts['today'] == 1, 'Today CTA must fire once');
  await _verticalScroll();
  final header = _all(_first<HomeScreen>()).firstWhere(
    (e) =>
        e.widget is SectionHeader &&
        (e.widget as SectionHeader).title == '최근 저장한 콘텐츠',
  );
  await _tap(_rect(header).center);
  _require(state.counts['archive'] == 1, 'Recent title must fire once');
  final card = _first<HomeContentCard>();
  await _tap(_rect(card).center);
  _require(state.counts['content'] == 1, 'Content card must fire once');
  await _tap(_rect(_first<BookmarkActionButton>(card)).center);
  _require(
    state.counts['bookmark'] == 1 && state.counts['content'] == 1,
    'Bookmark must fire once without opening card',
  );
  final horizontal = card.findAncestorStateOfType<ScrollableState>()!;
  for (var i = 0; i < 5; i++) {
    final dots = _first<PageDots>().widget as PageDots;
    if (dots.activeIndex == 3) break;
    final rect = _rect(horizontal.context as Element);
    await _gesture(
      Offset(rect.right - 25, rect.center.dy),
      Offset(-rect.width + 50, 0),
    );
  }
  final dots = _first<PageDots>().widget as PageDots;
  _require(
    dots.count == 4 && dots.activeIndex == 3,
    'Horizontal swipe must activate final page dot',
  );
  _measurements.add({
    'scenario': 'horizontalScroll',
    'activeIndex': dots.activeIndex,
    'count': dots.count,
  });
  await _capture('06_home_last_card');
  state.show(empty: true);
  await _settle();
  await _tap(_rect(_heroAction()).center);
  final sheet = _first<AddContentSheet>();
  await _tap(_rect(_first<TextField>(sheet)).center);
  final keyboardDeadline = DateTime.now().add(const Duration(seconds: 15));
  while (_view.viewInsets.bottom == 0 &&
      DateTime.now().isBefore(keyboardDeadline)) {
    await _settle(2);
  }
  final keyboard = _view.viewInsets.bottom / _view.devicePixelRatio;
  _require(keyboard > 0, 'Save input must show keyboard');
  await _capture('07_empty_save_keyboard');
  final close = _all(_first<SaveContentTopBar>()).firstWhere(
    (e) =>
        e.widget is SvgIconButton &&
        (e.widget as SvgIconButton).asset == Assets.close,
  );
  await _tap(_rect(close).center);
  _require(
    !_all(_root).any((e) => e.widget is AddContentSheet),
    'Save close must dismiss sheet',
  );
  _measurements.add({
    'scenario': 'emptySave',
    'opened': true,
    'keyboardInset': keyboard,
    'closed': true,
  });
  _interactionChecksCompleted = true;
  state.show(empty: false, scale: 2);
  await _settle();
  await _capture('08_home_scale_2');
  await _verticalScroll();
  await _revealScaledCard();
  await _capture('09_home_scale_2_scrolled');
  state.show(empty: true, scale: 2);
  await _settle();
  await _capture('10_empty_home_scale_2');
  _scaledScenesCaptured = true;
}
