// Device-only layout check. Run with flutter run -t this file, never as production.
// Navigation uses screen callbacks and one synthetic pointer sequence; it is not
// a manual interaction test or verification of a real backend/OAuth provider.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/top_bars.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'safe_area_preview.dart';

final _captureKey = GlobalKey();
final _measurements = <Map<String, Object?>>[];
final _frameworkErrors = <String>[];
late Directory _output;

Future<void> main() async {
  await runSafeAreaPreview(
    wrapApp: (child) => RepaintBoundary(key: _captureKey, child: child),
    afterRunApp: () async {
      debugPrint('SAFE_AREA_DEVICE stage: afterRunApp');
      _output = await Directory.systemTemp.createTemp('clipback-safe-area-');
      debugPrint('SAFE_AREA_DEVICE stage: output=${_output.path}');
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        _frameworkErrors.add(details.exceptionAsString());
        previousErrorHandler?.call(details);
      };
      Object? failure;
      try {
        await _runChecks();
        if (_frameworkErrors.isNotEmpty) {
          throw StateError('Flutter errors: ${_frameworkErrors.join('; ')}');
        }
      } catch (error, stack) {
        failure = error;
        debugPrint('SAFE_AREA_DEVICE FAIL: $error\n$stack');
      } finally {
        FlutterError.onError = previousErrorHandler;
        final report = {
          'passed': failure == null,
          'execution':
              'device rendering with mocked data and programmatic input',
          'topInset': _topInset,
          'pixelRatio': _view.devicePixelRatio,
          'logicalSize': '${_view.physicalSize / _view.devicePixelRatio}',
          'measurements': _measurements,
          'frameworkErrors': _frameworkErrors,
          'failure': failure?.toString(),
        };
        await File(
          '${_output.path}/report.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
        debugPrint(
          'SAFE_AREA_DEVICE ${failure == null ? 'PASS' : 'FAIL'} '
          'screens=${_measurements.length} output=${_output.path}',
        );
      }
    },
  );
}

ui.FlutterView get _view => View.of(_captureKey.currentContext!);
double get _topInset => _view.padding.top / _view.devicePixelRatio;

List<Element> _elements([Element? root]) {
  final result = <Element>[];
  void visit(Element element) {
    if (element.widget case Offstage(offstage: true)) return;
    result.add(element);
    element.visitChildren(visit);
  }

  visit(root ?? WidgetsBinding.instance.rootElement!);
  return result;
}

Element _first<T extends Widget>({Element? within, bool Function(T)? where}) =>
    _elements(within).firstWhere(
      (element) =>
          element.widget is T && (where == null || where(element.widget as T)),
      orElse: () => throw StateError('Missing visible $T'),
    );

T _widget<T extends Widget>() => _first<T>().widget as T;

Rect _rect(Element element) {
  final render = element.findRenderObject();
  if (render is! RenderBox || !render.hasSize) {
    throw StateError('No laid out RenderBox for ${element.widget.runtimeType}');
  }
  return render.localToGlobal(Offset.zero) & render.size;
}

Future<void> _settle([int frames = 9]) async {
  for (var index = 0; index < frames; index++) {
    await Future<void>.delayed(const Duration(milliseconds: 45));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw StateError(
        'Frame wait timed out: '
        'lifecycle=${WidgetsBinding.instance.lifecycleState} '
        'phase=${WidgetsBinding.instance.schedulerPhase} '
        'scheduled=${WidgetsBinding.instance.hasScheduledFrame} '
        'enabled=${WidgetsBinding.instance.framesEnabled}',
      ),
    );
  }
}

Future<void> _waitFor<T extends Widget>() async {
  debugPrint('SAFE_AREA_DEVICE stage: waiting for $T');
  for (var attempt = 0; attempt < 25; attempt++) {
    await _settle(2);
    if (_elements().any((element) => element.widget is T)) {
      debugPrint('SAFE_AREA_DEVICE stage: found $T');
      return;
    }
  }
  throw StateError('Timed out waiting for $T');
}

Future<void> _capture(String name) async {
  debugPrint('SAFE_AREA_DEVICE stage: capture $name settling');
  await _settle(2);
  final boundary =
      _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  debugPrint('SAFE_AREA_DEVICE stage: capture $name toImage');
  final image = await boundary
      .toImage(pixelRatio: _view.devicePixelRatio)
      .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw StateError('toImage timed out for $name'),
      );
  try {
    debugPrint('SAFE_AREA_DEVICE stage: capture $name PNG encoding');
    final data = await image
        .toByteData(format: ui.ImageByteFormat.png)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw StateError('PNG encoding timed out for $name'),
        );
    if (data == null) throw StateError('PNG encoding failed');
    await File('${_output.path}/$name.png').writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    debugPrint('SAFE_AREA_DEVICE stage: capture $name saved');
  } finally {
    image.dispose();
  }
}

Future<void> _header(String name, Element element) async {
  final rect = _rect(element);
  _measurements.add({
    'screen': name,
    'top': rect.top,
    'height': rect.height,
    'expectedTop': _topInset,
  });
  if ((rect.top - _topInset).abs() > 0.5 ||
      (rect.height - appHeaderHeight).abs() > 0.5) {
    throw StateError('$name header $rect; expected top=$_topInset height=64');
  }
  debugPrint('SAFE_AREA_DEVICE header $name: $rect inset=$_topInset');
  await _capture(name);
}

Future<void> _runChecks() async {
  await _waitFor<LoginScreen>();
  await _capture('00_login');
  _widget<LoginScreen>().onContinue();
  await _waitFor<OnboardingScreen>();
  _widget<OnboardingScreen>().onDone();
  await _waitFor<InterestSelectionScreen>();
  _widget<InterestSelectionScreen>().onDone();
  await _waitFor<HomeScreen>();
  await _header('01_home', _first<Row>(within: _first<HomeHero>()));

  final scroll =
      _first<Scrollable>(within: _first<HomeScreen>()) as StatefulElement;
  final position = (scroll.state as ScrollableState).position;
  final target = position.maxScrollExtent.clamp(0.0, 100.0).toDouble();
  await position.animateTo(
    target,
    duration: const Duration(milliseconds: 250),
    curve: Curves.linear,
  );
  await _capture('02_home_scrolled');
  final scrolledTop = _rect(_first<Row>(within: _first<HomeHero>())).top;
  if ((scrolledTop - (_topInset - target)).abs() > 0.5) {
    throw StateError('Home header no longer scrolls with its content');
  }
  await position.animateTo(
    0,
    duration: const Duration(milliseconds: 250),
    curve: Curves.linear,
  );

  _widget<HomeScreen>().onTab(AppRoute.archive);
  await _waitFor<ArchiveScreen>();
  await _settle();
  await _header('03_archive', _first<AppTopBar>());
  _widget<ArchiveScreen>().onTab(AppRoute.bookmark);
  await _waitFor<BookmarkScreen>();
  await _header('04_bookmark', _first<AppTopBar>());
  _widget<BookmarkScreen>().onSearch();
  await _waitFor<SearchScreen>();
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle();
  await _header('05_search', _first<Row>(within: _first<SearchScreen>()));
  _widget<SearchScreen>().onClose();
  await _waitFor<BookmarkScreen>();
  _widget<BookmarkScreen>().onTab(AppRoute.home);
  await _waitFor<HomeScreen>();
  final home = _widget<HomeScreen>();
  home.onOpenContent(home.contents.first);
  await _waitFor<DetailScreen>();
  await _header('06_detail', _first<DetailTopBar>());
  await _checkOriginalSheet();
  _widget<DetailScreen>().onTab(AppRoute.my);
  await _waitFor<MyScreen>();
  await _header('07_my', _first<MyPageTopBar>());
  _widget<MyScreen>().onOpenAccount();
  await _waitFor<AccountManagementScreen>();
  await _header(
    '08_account',
    _first<Row>(within: _first<AccountManagementScreen>()),
  );
  _widget<AccountManagementScreen>().onBack();
  await _waitFor<MyScreen>();
  _widget<MyScreen>().onOpenCategoryManagement();
  await _waitFor<CategoryManagementScreen>();
  await _header(
    '09_categories',
    _first<Row>(within: _first<CategoryManagementScreen>()),
  );

  (_first<SvgIconButton>(
            within: _first<CategoryManagementScreen>(),
            where: (button) => button.asset == Assets.folderPlus,
          ).widget
          as SvgIconButton)
      .onPressed();
  await _waitFor<CategoryFormSheet>();
  final editable =
      _first<EditableText>(within: _first<CategoryFormSheet>())
          as StatefulElement;
  (editable.state as EditableTextState).requestKeyboard();
  await _settle(18);
  final sheet = _rect(_first<CategoryFormSheet>());
  _measurements.add({
    'screen': 'category_sheet_keyboard',
    'top': sheet.top,
    'height': sheet.height,
    'keyboardInset': _view.viewInsets.bottom / _view.devicePixelRatio,
  });
  if (sheet.top < _topInset - 0.5) {
    throw StateError('Category sheet overlaps the system top inset');
  }
  await _capture('10_category_sheet_keyboard');
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.of(_first<CategoryFormSheet>()).pop();
  await _settle();
  _widget<CategoryManagementScreen>().onBack();
  await _waitFor<MyScreen>();
  _widget<MyScreen>().onTab(AppRoute.archive);
  await _waitFor<ArchiveScreen>();
  final archive = _widget<ArchiveScreen>();
  archive.onOpenCategory(
    archive.categories.firstWhere((category) => category.name != '미분류'),
  );
  await _settle();
  await _header('11_category_archive', _first<CategoryTopBar>());
  _widget<ArchiveScreen>().onOpenRandomView();
  await _waitFor<CategoryCardReviewScreen>();
  await _header(
    '12_random',
    _first<TextButton>(within: _first<CategoryCardReviewScreen>()),
  );
  await _dragRandomCard();
  _widget<CategoryCardReviewScreen>().onExit();
  await _waitFor<ArchiveScreen>();
  _widget<ArchiveScreen>().onTab(AppRoute.home);
  await _waitFor<HomeScreen>();
  final current = _widget<HomeScreen>();
  unawaited(
    showContentSaveScreen(
      context: _first<HomeScreen>(),
      onAddLink: current.onAddLink,
      onAddScreenshot: current.onAddScreenshot,
    ),
  );
  await _waitFor<AddContentSheet>();
  await _header('14_save', _first<SaveContentTopBar>());
  Navigator.of(_first<AddContentSheet>()).pop();
  await _settle();
}

Future<void> _checkOriginalSheet() async {
  if (!_widget<DetailScreen>().content.isScreenshot) {
    throw StateError('Original-image check requires the screenshot fixture');
  }
  (_first<SvgIconButton>(
            within: _first<DetailScreen>(),
            where: (button) => button.asset == Assets.link,
          ).widget
          as SvgIconButton)
      .onPressed();
  await _waitFor<OriginalContentSheet>();
  for (var attempt = 0; attempt < 20; attempt++) {
    final decoded = _elements(_first<OriginalContentSheet>()).any(
      (element) =>
          element.widget is RawImage &&
          (element.widget as RawImage).image != null,
    );
    if (decoded) break;
    await _settle(2);
  }
  final image = _first<RawImage>(
    within: _first<OriginalContentSheet>(),
    where: (image) => image.image != null,
  );
  await _settle();
  final sheet = _rect(_first<OriginalContentSheet>());
  _measurements.add({
    'screen': 'original_image_sheet',
    'top': sheet.top,
    'height': sheet.height,
    'decodedImageHeight': _rect(image).height,
  });
  if (sheet.top < _topInset - 0.5) {
    throw StateError('Original image sheet overlaps the system top inset');
  }
  await _capture('06b_original_image_sheet');
  Navigator.of(_first<OriginalContentSheet>()).pop();
  await _settle();
}

Future<void> _dragRandomCard() async {
  final active = _first<AnimatedSlide>(
    within: _first<CategoryCardReviewScreen>(),
  );
  final start = _rect(active).center;
  final initialKey = active.widget.key;
  var previous = start;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: 901, viewId: _view.viewId, position: start),
  );
  for (var step = 1; step <= 12; step++) {
    final next = start + Offset(0, -step * 40);
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: 901,
        viewId: _view.viewId,
        position: next,
        delta: next - previous,
        timeStamp: Duration(milliseconds: step * 50),
      ),
    );
    previous = next;
    await _settle(1);
  }
  await _capture('13_random_dragged');
  final dragged =
      _first<AnimatedSlide>(within: _first<CategoryCardReviewScreen>()).widget
          as AnimatedSlide;
  final draggedOffset = dragged.offset;
  final clip = _rect(
    _first<ClipRect>(within: _first<CategoryCardReviewScreen>()),
  );
  _measurements.add({
    'screen': 'random_synthetic_drag',
    'clipTop': clip.top,
    'pointerSteps': 12,
    'pointerTravel': 480,
    'draggedOffsetX': draggedOffset.dx,
    'draggedOffsetY': draggedOffset.dy,
    'initialCardKey': initialKey.toString(),
  });
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: 901,
      viewId: _view.viewId,
      position: previous,
      timeStamp: const Duration(milliseconds: 700),
    ),
  );
  await _settle();
  if (draggedOffset == Offset.zero) {
    throw StateError('Synthetic pointer sequence did not drag the active card');
  }
  if ((clip.top - _topInset).abs() > 0.5) {
    throw StateError('Random card clip does not begin at the safe viewport');
  }
  final nextKey = _first<AnimatedSlide>(
    within: _first<CategoryCardReviewScreen>(),
  ).widget.key;
  _measurements.last['nextCardKey'] = nextKey.toString();
  if (initialKey == null || nextKey == initialKey) {
    throw StateError('Random drag did not advance to the next content');
  }
  await _capture('13b_random_advanced');
}
