// Fresh F01 native evidence. The baseline and AFTER use identical fixture code.
// All API/session/share data is isolated in process, beginning at app launch.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import '../fixtures/category_content_fixture.dart';
import 'archive_all_preview.dart' as base;

const phase = String.fromEnvironment(
  'CATEGORY_CONTENT_PHASE',
  defaultValue: 'before',
);
final _capture = GlobalKey();
late CategoryContentServer _server;
final _servers = <CategoryContentServer>[];
late Directory _output;
final _errors = <String>[];
final _checks = <Map<String, Object?>>[];
bool _busy = false, _done = false;
int _epoch = 0, _pointer = 900;
Element get _root => _capture.currentContext! as Element;
ArchiveScreen get _archive =>
    f01Find<ArchiveScreen>(_root)!.widget as ArchiveScreen;
Future<void> settle([int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 60),
    );
  }
}

void require(bool value, String reason) {
  if (!value) throw StateError(reason);
}

Future<void> wait(bool Function() check, String reason) async {
  for (var i = 0; i < 150; i++) {
    if (check()) return;
    await settle(2);
  }
  throw StateError(reason);
}

Future<void> tap(Element e) async {
  final point = f01Box(e).center, id = ++_pointer, view = View.of(_root);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 75));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: view.viewId, position: point),
  );
  await settle();
}

Future<void> tapText(String value) async {
  final e = f01Elements(_root)
      .where((e) => e.widget is Text && (e.widget as Text).data == value)
      .lastOrNull;
  require(e != null, 'Missing text target: $value');
  await tap(e!);
}

Future<void> tapKey(String key) async {
  final e = f01Key(_root, key);
  require(e != null, 'Missing key: $key');
  await tap(e!);
}

Future<void> hideIme() async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await wait(() => View.of(_root).viewInsets.bottom == 0, 'IME still visible');
}

Future<void> fresh() async {
  _server = CategoryContentServer();
  _servers.add(_server);
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: ValueKey(++_epoch),
        sessionStorage: base.ArchiveAllMemoryStorage(),
        socialAuth: base.ArchiveAllSocialAuth(),
      ),
    ),
  );
  await settle(2);
  await wait(() => f01Find<HomeScreen>(_root) != null, 'Home not initialized');
  (f01Find<HomeScreen>(_root)!.widget as HomeScreen).onOpenCategories();
  await wait(
    () => f01Find<ArchiveScreen>(_root) != null,
    'Archive not initialized',
  );
  _archive.onOpenCategory(
    _archive.categories.firstWhere((c) => c.id == categoryContentId),
  );
  await wait(
    () =>
        _archive.feed?.categoryId == categoryContentId &&
        _archive.feed!.initialized &&
        !_archive.feed!.loading,
    'Category query not ready',
  );
  await hideIme();
  await settle();
  base.archiveAllPosition(_root).jumpTo(0);
  await settle();
}

Map<String, Object?> snapshot() {
  final m = f01Measure(_root),
      j = f01Judge(m),
      isolation = base.archiveAllShareMessenger;
  return {
    ...m,
    ...j,
    'phase': phase,
    'platform': Theme.of(_root).platform.name,
    'output': _output.path,
    'checksCompleted': _done,
    'frameworkErrors': List.of(_errors),
    'requests': [for (final s in _servers) ...s.requests],
    'unexpected': [for (final s in _servers) ...s.unexpected],
    'nativeShareIsolation': {
      'installed': isolation != null,
      'nativeDelegationCount': isolation?.nativeDelegationCount,
      'unknownMethods': isolation?.unknownShareMethods,
    },
    'checks': List.of(_checks),
  };
}

Future<Map<String, Object?>> report() async {
  final s = snapshot(),
      j = f01Judge(s),
      isolation = base.archiveAllShareMessenger;
  final behavior =
      _done &&
      _checks.every((x) => x['passed'] == true) &&
      _servers.every((s) => s.unexpected.isEmpty) &&
      isolation != null &&
      isolation.nativeDelegationCount == 0 &&
      isolation.unknownShareMethods.isEmpty;
  final out = {
    ...s,
    'behaviorPassed': behavior,
    'layoutPassed': j['layoutPassed'] == true && _errors.isEmpty,
    'passed': behavior && j['passed'] == true && _errors.isEmpty,
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(out));
  return out;
}

void record(String name, bool passed, [Map<String, Object?> extra = const {}]) {
  _checks.add({'scenario': name, 'passed': passed, ...extra});
  require(passed, name);
}

Future<void> runChecks() async {
  _checks.clear();
  _done = false;
  await fresh();
  final start = f01Measure(_root),
      firstIds = _archive.contents.map((c) => c.id).toList();
  record(
    'selected category ID and loaded count differ from global999',
    _archive.feed!.categoryId == 101 &&
        _archive.contents.length == 5 &&
        start['countLabel'] != null,
    {'ids': firstIds, 'measure': start},
  );
  // Sort is the actual existing popup and server/bookmark-first query.
  await tapText('최신순');
  await tapText('북마크 우선');
  await wait(() => !_archive.feed!.loading, 'Sort query pending');
  record(
    'sort retains category ID and resets position',
    _archive.bookmarkedFirst &&
        _archive.feed!.categoryId == 101 &&
        base.archiveAllPosition(_root).pixels == 0,
  );
  await tapText('북마크 우선');
  await tapText('최신순');
  await settle();
  await tapKey('category-content-settings-hit');
  await wait(
    () => f01Find<CategoryManagementScreen>(_root) != null,
    'Settings did not open management',
  );
  (f01Find<CategoryManagementScreen>(_root)!.widget as CategoryManagementScreen)
      .onBack();
  await settle();
  record(
    'management returns to selected category',
    _archive.feed!.categoryId == 101,
  );
  await tapKey('category-content-search-hit');
  await wait(() => f01Find<SearchScreen>(_root) != null, 'Search did not open');
  (f01Find<SearchScreen>(_root)!.widget as SearchScreen).onClose();
  await hideIme();
  await settle();
  record(
    'search cancellation returns category',
    _archive.feed!.categoryId == 101,
  );
  await tapText(_archive.contents.first.title);
  await wait(() => f01Find<DetailScreen>(_root) != null, 'Detail did not open');
  (f01Find<DetailScreen>(_root)!.widget as DetailScreen).onBack();
  await settle();
  record(
    'detail preserves category and cursor',
    _archive.feed!.categoryId == 101 && _archive.feed!.nextCursor == '5',
  );
  final star = f01Elements(
    f01Find<ContentListCard>(_root)!,
  ).firstWhere((e) => e.widget.key?.toString().contains('bookmark') == true);
  _server.failNextFavorite = true;
  final old = _archive.contents.first.bookmarked;
  await tap(star);
  await settle(12);
  record(
    'bookmark failure preserves record and value',
    _archive.contents.first.bookmarked == old,
  );
  await tap(star);
  await settle(12);
  record(
    'bookmark manual retry persisted',
    _server.records.first['is_favorite'] != old,
  );
  var p = base.archiveAllPosition(_root);
  p.jumpTo(p.maxScrollExtent);
  await settle(10);
  await wait(
    () => _archive.contents.length == 6 && !_archive.feed!.loading,
    'Additional page missing',
  );
  p = base.archiveAllPosition(_root);
  p.jumpTo(p.maxScrollExtent);
  await settle();
  final max = f01Measure(_root), last = (max['rows'] as List).last as Map;
  record(
    'additional page and last complete card above random',
    last['id'] == 'api-606' &&
        (last['bounds']['bottom'] as num) <=
            (max['randomVisual']! as Map)['top'],
    {'measure': max},
  );
  final offset = p.pixels;
  await tapKey('category-content-settings-hit');
  await settle();
  (f01Find<CategoryManagementScreen>(_root)!.widget as CategoryManagementScreen)
      .onBack();
  await settle();
  record(
    'management preserves scrolled feed',
    (base.archiveAllPosition(_root).pixels - offset).abs() < .2 &&
        _archive.contents.length == 6,
  );
  await tapText('랜덤 보기');
  await wait(
    () => f01Find<CategoryCardReviewScreen>(_root) != null,
    'Review missing',
  );
  final review =
      f01Find<CategoryCardReviewScreen>(_root)!.widget
          as CategoryCardReviewScreen;
  final ids = review.contents.map((c) => c.id).toList();
  review.onExit();
  await settle();
  record(
    'random max5 from loaded selected contents and returns',
    ids.length == 5 &&
        ids.every((id) => _archive.contents.any((c) => c.id == id)),
    {'actualSelectedIds': ids, 'orderRestorationClaimed': false},
  );
  final nav =
      f01Find<ClipbackNavigationBar>(_root)!.widget as ClipbackNavigationBar;
  nav.onAdd!();
  await settle();
  require(f01Find<AddContentSheet>(_root) != null, 'Save missing');
  Navigator.of(f01Find<AddContentSheet>(_root)!).pop();
  await settle();
  record('save closes without writes', _server.writes == 1);
  base.archiveAllPosition(_root).jumpTo(0);
  await settle();
  Future<void> more() async {
    final card = f01Find<ContentListCard>(_root)!;
    final icon = f01Elements(card).firstWhere(
      (e) =>
          e.widget is SvgPicture &&
          ((e.widget as SvgPicture).bytesLoader is SvgAssetLoader) &&
          ((e.widget as SvgPicture).bytesLoader as SvgAssetLoader).assetName ==
              Assets.archiveAllMore,
    );
    await tap(icon);
  }

  await more();
  await tapText('카테고리 변경');
  await tapText('여행');
  await wait(
    () =>
        !_archive.feed!.loading &&
        !_archive.contents.any((c) => c.id == 'api-601'),
    'Moved record remained in category',
  );
  record(
    'category change retains selected filter and removes moved row',
    _archive.feed!.categoryId == 101 &&
        (_server.records.first['categories'] as List).single['id'] == 102,
  );
  await more();
  await tapText('삭제');
  await wait(
    () =>
        !_archive.feed!.loading &&
        !_archive.contents.any((c) => c.id == 'api-602'),
    'Deleted record remained',
  );
  record(
    'delete removes only requested record',
    _server.records.length == 5 && !_server.records.any((r) => r['id'] == 602),
  );
  _server.failNextFeed = true;
  _archive.onSortChanged(true);
  await wait(() => _archive.feed!.error != null, 'Feed failure not reproduced');
  _archive.onRetry!();
  await wait(
    () =>
        _archive.feed!.initialized &&
        !_archive.feed!.loading &&
        _archive.feed!.error == null,
    'Feed retry not complete',
  );
  record(
    'query error manual retry keeps category ID',
    _archive.feed!.categoryId == 101,
  );
  for (final route in [
    AppRoute.home,
    AppRoute.archive,
    AppRoute.bookmark,
    AppRoute.my,
  ]) {
    final bar =
        f01Find<ClipbackNavigationBar>(_root)!.widget as ClipbackNavigationBar;
    bar.onTap(route);
    await settle(10);
    record(
      'bottom tab ${route.name}',
      f01Find<ClipbackNavigationBar>(_root) != null,
    );
  }
  await fresh();
  _done = true;
  await report();
}

Future<void> main() => http.runWithClient(() async {
  base.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-category-content-');
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await fresh();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('F01 ready phase=$phase output=${_output.path}');
  await for (final r in server) {
    final read = ['/status', '/ready'].contains(r.uri.path);
    if (_busy && !read) {
      r.response.statusCode = 409;
      await r.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (r.uri.path) {
        case '/scene':
          await fresh();
        case '/run':
          await runChecks();
        case '/status':
        case '/ready':
          break;
        default:
          r.response.statusCode = 404;
      }
      final out = await report();
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode(out));
    } catch (e, st) {
      debugPrint('F01 FAIL $e\n$st');
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$e',
      });
      r.response.statusCode = 500;
      r.response.write(jsonEncode({'error': '$e', ...await report()}));
    } finally {
      if (!read) _busy = false;
      await r.response.close();
    }
  }
}, () => _server.client);
