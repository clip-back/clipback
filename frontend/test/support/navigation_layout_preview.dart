// Device-only regression fixture: six real screens at scale 1, and a separate
// navigation component at scales 1.5/2. No HTTP, session, or native share service.
// flutter run --no-pub -t test/support/navigation_layout_preview.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/placeholder_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/data/sample_categories.dart';
import 'package:clipback_frontend/shared/data/sample_contents.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const _phase = String.fromEnvironment(
  'NAV_LAYOUT_PHASE',
  defaultValue: 'before',
);
final _appKey = GlobalKey<_PreviewState>();
final _navigatorKey = GlobalKey<NavigatorState>();
final _captureKey = GlobalKey();
final _errors = <Map<String, String>>[];
final _measurements = <Map<String, Object?>>[];
late Directory _output;
int _pointer = 3000;
final _contents = initialContents.take(4).toList();
final _feed = FeedPage()
  ..initialized = true
  ..hasMore = false
  ..items.addAll(_contents);
const _routes = {
  '홈': AppRoute.home,
  '아카이브': AppRoute.archive,
  '즐겨찾기': AppRoute.bookmark,
  '마이': AppRoute.my,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _output = await Directory.systemTemp.createTemp('clipback-navigation-');
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add({
      'scene': _appKey.currentState?.scene ?? 'home',
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
    debugPrint('NAV_LAYOUT FAIL: $error\n$stack');
  } finally {
    FlutterError.onError = previous;
    await File('${_output.path}/report.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'phase': _phase,
        'passed': failure == null,
        'checksCompleted': checksCompleted,
        'scope':
            'Real Home/Archive/Bookmark/My/Detail/Placeholder at scale 1; isolated shared nav 1.5/2 at 375/320px',
        'screenBodyScale': 1,
        'safeAreaCriterion': 'after: 64 + fontExtra + viewPadding.bottom',
        'outsideScope':
            'My/Detail body at text scale 2; tested bodies remain scale 1',
        'platform': Platform.operatingSystem,
        'logicalSize': '${_view.physicalSize / _view.devicePixelRatio}',
        'pixelRatio': _view.devicePixelRatio,
        'callbackCounts': _appKey.currentState!.counts,
        'measurements': _measurements,
        'frameworkErrors': _errors,
        'failure': failure?.toString(),
      }),
    );
    debugPrint(
      'NAV_LAYOUT ${failure == null ? 'PASS' : 'FAIL'} output=${_output.path}',
    );
  }
}

Future<ContentItem> _saveLink({required String url, CategoryItem? category}) =>
    Future.error(UnsupportedError('Fixture does not save'));
Future<ContentItem> _savePhoto({
  required Uint8List bytes,
  required String filename,
  CategoryItem? category,
}) => Future.error(UnsupportedError('Fixture does not save'));
void _noop() {}
void _ignore<T>(T value) {}

class _Preview extends StatefulWidget {
  const _Preview({super.key});
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  var route = AppRoute.home;
  var index = 0;
  double? componentScale;
  double componentWidth = 375;
  int activeIndex = 0;
  bool placeholder = false;
  bool placeholderPopped = false;
  final counts = <String, int>{};
  String get scene => placeholder
      ? 'placeholder'
      : componentScale == null
      ? route.name
      : 'nav_${componentWidth}_scale_$componentScale';
  Set<String> get bookmarks => {
    for (final item in _contents)
      if (item.bookmarked) item.id,
  };
  void count(String key) => counts.update(key, (n) => n + 1, ifAbsent: () => 1);
  void go(AppRoute next) => setState(() {
    count('tab_${next.name}');
    if (componentScale == null) {
      route = next;
    } else {
      activeIndex = _routes.values.toList().indexOf(next);
    }
  });
  void open(ContentItem item) => setState(() {
    count('openContent');
    index = _contents.indexOf(item);
    route = AppRoute.detail;
  });
  void adjacent(int delta) => setState(() {
    count(delta > 0 ? 'next' : 'previous');
    index += delta;
  });
  void component(double scale, double width) => setState(() {
    componentScale = scale;
    componentWidth = width;
    activeIndex = 0;
  });

  Widget screen() => switch (route) {
    AppRoute.home => HomeScreen(
      contents: _contents,
      feed: _feed,
      categories: initialCategories,
      bookmarkedIds: bookmarks,
      onSearch: _noop,
      onOpenArchive: () => go(AppRoute.archive),
      onOpenCategories: _noop,
      onOpenToday: _noop,
      onOpenContent: open,
      onToggleBookmark: _ignore,
      onAddLink: _saveLink,
      onAddScreenshot: _savePhoto,
      onTab: go,
    ),
    AppRoute.archive => ArchiveScreen(
      activeTab: 0,
      contents: _contents,
      feed: _feed,
      categories: initialCategories,
      bookmarkedIds: bookmarks,
      bookmarkedFirst: false,
      randomViewing: false,
      activeCategoryName: null,
      onTabChanged: _ignore,
      onSortChanged: _ignore,
      onOpenRandomView: _noop,
      onExitRandomView: _noop,
      onClearCategory: _noop,
      onSearch: _noop,
      onOpenContent: open,
      onToggleBookmark: _ignore,
      onChangeContentCategory: (_, _) {},
      onDeleteContent: _ignore,
      onAddCategory: _ignore,
      onUpdateCategory: (_, _) {},
      onDeleteCategory: _ignore,
      onOpenCategory: _ignore,
      onAddLink: _saveLink,
      onAddScreenshot: _savePhoto,
      onTab: go,
    ),
    AppRoute.bookmark => BookmarkScreen(
      contents: _contents,
      feed: _feed,
      categories: initialCategories,
      bookmarkedIds: bookmarks,
      onSearch: _noop,
      onOpenContent: open,
      onToggleBookmark: _ignore,
      onChangeContentCategory: (_, _) {},
      onDeleteContent: _ignore,
      onAddLink: _saveLink,
      onAddScreenshot: _savePhoto,
      onTab: go,
    ),
    AppRoute.my => MyScreen(
      user: defaultUser,
      onOpenAccount: _noop,
      onOpenCategoryManagement: _noop,
      onAddLink: _saveLink,
      onAddScreenshot: _savePhoto,
      onTab: go,
    ),
    AppRoute.detail => DetailScreen(
      content: _contents[index],
      contents: _contents,
      categories: initialCategories,
      bookmarked: false,
      feed: _feed,
      onReadAsset: (_) async => Uint8List(0),
      onBack: () => go(AppRoute.home),
      onToggleBookmark: _ignore,
      onChangeCategory: (_, _) {},
      onDeleteContent: _ignore,
      onOpenOriginalLink: _noop,
      onOpenAdjacent: adjacent,
      onOpenContent: open,
      onAddLink: _saveLink,
      onAddScreenshot: _savePhoto,
      onTab: go,
    ),
    _ => throw StateError('Unsupported fixture route: $route'),
  };

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _captureKey,
    child: MaterialApp(
      navigatorKey: _navigatorKey,
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
        ).copyWith(textScaler: TextScaler.linear(componentScale ?? 1)),
        child: child!,
      ),
      home: componentScale == null
          ? screen()
          : PhoneFrame(
              child: Scaffold(
                body: const Center(child: Text('공통 내비게이션 검증')),
                bottomNavigationBar: Align(
                  heightFactor: 1,
                  child: SizedBox(
                    width: componentWidth,
                    child: ClipbackNavigationBar(
                      activeIndex: activeIndex,
                      onTap: go,
                      onAdd: () => count('add'),
                    ),
                  ),
                ),
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

Element get _bar => _first<ClipbackNavigationBar>(
  _appKey.currentState!.placeholder ? _first<PlaceholderScreen>() : null,
);
Element _label(String title) => _all(
  _bar,
).firstWhere((e) => e.widget is Text && (e.widget as Text).data == title);
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

Future<void> _tapTab(String title) async {
  final state = _appKey.currentState!;
  final expected = _routes[title]!;
  final before = state.counts['tab_${expected.name}'] ?? 0;
  await _tap(_rect(_label(title)).center);
  _require(
    state.counts['tab_${expected.name}'] == before + 1,
    '$title tap must fire once',
  );
  if (state.componentScale == null) {
    _require(state.route == expected, '$title did not navigate');
  }
}

void _measureNavigation() {
  final bar = _bar;
  final rect = _rect(bar);
  final scale = _appKey.currentState!.componentScale ?? 1;
  final media = MediaQuery.of(bar);
  final items = <Map<String, Object?>>[];
  double? iconTop;
  for (final title in _routes.keys) {
    final text = _label(title);
    Element? ink;
    text.visitAncestorElements((e) {
      if (e.widget is InkWell) {
        ink = e;
        return false;
      }
      return true;
    });
    final hit = _rect(ink!);
    final label = _rect(text);
    final icon = _rect(_first<SvgIcon>(ink!));
    _require(hit.width >= 55.5 && hit.height >= 55.5, '$title hit area shrank');
    _require(
      label.left >= hit.left - .5 &&
          label.right <= hit.right + .5 &&
          label.top >= hit.top - .5 &&
          label.bottom <= hit.bottom + .5,
      '$title label escapes hit area',
    );
    _require(
      (icon.width - 28).abs() < .5 && (icon.height - 28).abs() < .5,
      '$title icon size changed',
    );
    iconTop ??= icon.top;
    _require(
      (icon.top - iconTop).abs() < .5,
      'Navigation icons must share the same top coordinate',
    );
    items.add({
      'title': title,
      'hitWidth': hit.width,
      'hitHeight': hit.height,
      'labelHeight': label.height,
      'labelTop': label.top,
      'labelBottom': label.bottom,
      'iconTop': icon.top,
      'iconLeft': icon.left,
      'iconWidth': icon.width,
      'iconHeight': icon.height,
    });
  }
  final fontExtra = (items.first['hitHeight']! as double) - 56;
  final contentHeight = 64 + fontExtra;
  if (_phase == 'after') {
    _require(
      (rect.height - contentHeight - media.viewPadding.bottom).abs() < .5,
      'Navigation must use actual OS bottom viewPadding',
    );
  }
  final add = _rect(_first<NavAddButton>(bar));
  _require(
    (add.width - 72).abs() < .5 && (add.height - 72).abs() < .5,
    'Add button size changed',
  );
  _measurements.add({
    'scene': _appKey.currentState!.scene,
    'textScale': scale,
    'navHeight': rect.height,
    'contentHeight': contentHeight,
    'fontExtra': fontExtra,
    'paddingBottom': media.padding.bottom,
    'viewPaddingBottom': media.viewPadding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'navTop': rect.top,
    'navBottom': rect.bottom,
    'addTop': add.top,
    'items': items,
  });
}

Future<void> _capture(String name) async {
  await _settle();
  _measureNavigation();
  final image =
      await (_captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: _view.devicePixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    _require(data != null, 'PNG encoding failed');
    await File('${_output.path}/$name.png').writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  debugPrint('NAV_LAYOUT capture=$name output=${_output.path}');
  await Future<void>.delayed(const Duration(seconds: 8));
}

Future<void> _runChecks() async {
  final state = _appKey.currentState!;
  await _capture('00_home');
  await _tapTab('아카이브');
  await _capture('01_archive');
  await _tapTab('즐겨찾기');
  await _capture('02_bookmark');
  await _tapTab('마이');
  await _capture('03_my');
  await _tapTab('홈');
  await _tap(_rect(_first<HomeContentCard>()).center);
  _require(
    state.route == AppRoute.detail && state.counts['openContent'] == 1,
    'Real card tap must open detail once',
  );
  final pager = _first<DetailPager>();
  final previous = _all(pager).firstWhere(
    (e) => e.widget is RoundIconButton && (e.widget as RoundIconButton).rotate,
  );
  final next = _all(pager).firstWhere(
    (e) => e.widget is RoundIconButton && !(e.widget as RoundIconButton).rotate,
  );
  final navRect = _rect(_first<ClipbackNavigationBar>());
  _require(
    _rect(previous).bottom <= navRect.top && _rect(next).bottom <= navRect.top,
    'Detail pager buttons overlap navigation',
  );
  await _tap(_rect(next).center);
  _require(state.index == 1 && state.counts['next'] == 1, 'Detail next failed');
  await _tap(
    _rect(
      _all(_first<DetailPager>()).firstWhere(
        (e) =>
            e.widget is RoundIconButton && (e.widget as RoundIconButton).rotate,
      ),
    ).center,
  );
  _require(
    state.index == 0 && state.counts['previous'] == 1,
    'Detail previous failed',
  );
  _measurements.add({
    'scene': 'detailPager',
    'nextCalls': 1,
    'previousCalls': 1,
    'navTop': navRect.top,
    'previousBottom': _rect(previous).bottom,
    'nextBottom': _rect(next).bottom,
  });
  await _capture('04_detail');
  await _tapTab('홈');
  state.placeholder = true;
  state.placeholderPopped = false;
  unawaited(
    _navigatorKey.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const PlaceholderScreen(title: '준비 중 화면', activeIndex: 0),
          ),
        )
        .then((_) => state.placeholderPopped = true),
  );
  await _settle();
  await _capture('05_placeholder');
  await _tap(_rect(_label('홈')).center);
  final popDeadline = DateTime.now().add(const Duration(seconds: 3));
  while (!state.placeholderPopped && DateTime.now().isBefore(popDeadline)) {
    await _settle(2);
  }
  _require(
    state.placeholderPopped && !_navigatorKey.currentState!.canPop(),
    'Placeholder nav tap must pop the route',
  );
  state.placeholder = false;
  _measurements.add({'scene': 'placeholder', 'navTapPopped': true});
  for (final spec in [(1.5, 375.0), (2.0, 375.0), (2.0, 320.0)]) {
    state.component(spec.$1, spec.$2);
    await _settle();
    for (final title in _routes.keys) {
      await _tapTab(title);
    }
    final before = state.counts['add'] ?? 0;
    final add = _rect(_first<NavAddButton>());
    await _tap(add.center);
    _require(state.counts['add'] == before + 1, 'Add center must fire once');
    await _tap(add.bottomCenter - const Offset(0, 2));
    _require(
      state.counts['add'] == before + 2,
      'Add lower edge must fire once',
    );
    _measurements.add({
      'scene': state.scene,
      'addCenterCalls': 1,
      'addLowerEdgeCalls': 1,
      'addLowerEdgeY': add.bottom - 2,
    });
    await _capture('06_nav_${spec.$2.toInt()}_scale_${spec.$1}');
  }
}
