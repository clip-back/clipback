// Actual root app; only API/session/history/share are isolated. Native IME and
// Android Back remain real. Freeze this harness before the product change.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/data/services/search_history_storage.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/logout_confirmation_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/home/notification_list_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'archive_all_preview.dart' as base;

class BackMemoryHistory implements SearchHistoryStorage {
  @override
  Future<List<String>> read(String environment, int userId) async => [];
  @override
  Future<void> write(
    String environment,
    int userId,
    List<String> terms,
  ) async {}
}

const phase = String.fromEnvironment('BACK_PHASE', defaultValue: 'before');
final api = base.ArchiveAllServer();
final errors = <String>[], asyncErrors = <String>[];
var rootKey = GlobalKey();
var epoch = 0, pointer = 900;
Element get root => rootKey.currentContext! as Element;
Iterable<Element> elements(Element n) sync* {
  yield n;
  final children = <Element>[];
  n.visitChildren(children.add);
  for (final c in children) {
    yield* elements(c);
  }
}

Element? find<T extends Widget>() =>
    elements(root).where((e) => e.widget is T).firstOrNull;
Element? key(String value) =>
    elements(root).where((e) => e.widget.key == ValueKey(value)).firstOrNull;
Rect rect(Element e) {
  final b = e.findRenderObject()! as RenderBox;
  return b.localToGlobal(Offset.zero) & b.size;
}

Future<void> settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 4),
    );
  }
}

Future<void> tap(Element e) async {
  final p = rect(e).center, id = ++pointer, v = View.of(root).viewId;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: v, position: p),
  );
  await Future<void>.delayed(const Duration(milliseconds: 40));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: v, position: p),
  );
  await settle();
}

String screen() {
  for (final t in [
    AddContentSheet,
    DetailScreen,
    SearchScreen,
    AccountManagementScreen,
    CategoryCardReviewScreen,
    CategoryManagementScreen,
    NotificationListScreen,
    LogoutConfirmationScreen,
    ArchiveScreen,
    BookmarkScreen,
    MyScreen,
    LoginScreen,
    HomeScreen,
  ]) {
    if (elements(root).any((e) => e.widget.runtimeType == t)) {
      return t.toString();
    }
  }
  return 'other';
}

Future<void> scene(String kind) async {
  rootKey = GlobalKey();
  final storage = base.ArchiveAllMemoryStorage();
  if (kind == 'login') storage.value = null;
  runApp(
    KeyedSubtree(
      key: ValueKey(++epoch),
      child: SizedBox(
        key: rootKey,
        child: ClipbackApp(
          key: ValueKey(epoch),
          sessionStorage: storage,
          socialAuth: base.ArchiveAllSocialAuth(),
          searchHistoryStorage: BackMemoryHistory(),
        ),
      ),
    ),
  );
  await settle();
  for (
    var i = 0;
    i < 40 && find<HomeScreen>() == null && find<LoginScreen>() == null;
    i++
  ) {
    await settle();
  }
  if (kind == 'login') return;
  final home = find<HomeScreen>()!.widget as HomeScreen;
  if (['archive', 'category', 'review'].contains(kind)) {
    home.onTab(AppRoute.archive);
    await settle();
    if (kind != 'archive') {
      final a = find<ArchiveScreen>()!.widget as ArchiveScreen;
      a.onOpenCategory(a.categories.first);
      await settle();
      if (kind == 'review') {
        (find<ArchiveScreen>()!.widget as ArchiveScreen).onOpenRandomView();
        await settle();
      }
    }
  } else if (kind == 'bookmark') {
    home.onTab(AppRoute.bookmark);
    await settle();
  } else if (kind == 'search') {
    home.onSearch();
    await settle();
  } else if (kind == 'detail') {
    home.onOpenContent(home.contents.first);
    await settle();
  } else if (kind == 'notifications') {
    home.onOpenNotifications!();
    await settle();
  } else if (['my', 'account', 'management', 'logout'].contains(kind)) {
    home.onTab(AppRoute.my);
    await settle();
    final my = find<MyScreen>()!.widget as MyScreen;
    if (kind == 'management') {
      my.onOpenCategoryManagement();
      await settle();
    } else if (kind != 'my') {
      my.onOpenAccount();
      await settle();
      if (kind == 'logout') {
        await (find<AccountManagementScreen>()!.widget
                as AccountManagementScreen)
            .onLogout();
        await settle();
      }
    }
  }
}

Map<String, Object?> state() {
  final v = View.of(root);
  final paragraphs = <Map<String, Object?>>[];
  final popup = key('exit-confirmation-dialog');
  if (popup != null) {
    for (final e in elements(popup)) {
      if (e.widget is RichText && e.findRenderObject() is RenderParagraph) {
        final p = e.findRenderObject()! as RenderParagraph, s = p.text.style;
        final r = rect(e);
        paragraphs.add({
          'text': p.text.toPlainText(),
          'x': r.left,
          'y': r.top,
          'width': r.width,
          'height': r.height,
          'font': s?.fontFamily,
          'size': s?.fontSize,
          'weight': s?.fontWeight?.value,
          'color': s?.color?.toARGB32(),
          'overflow': p.didExceedMaxLines,
        });
      }
    }
  }
  return {
    'phase': phase,
    'screen': screen(),
    'dialog': popup != null,
    'paragraphs': paragraphs,
    'window': [
      v.physicalSize.width / v.devicePixelRatio,
      v.physicalSize.height / v.devicePixelRatio,
    ],
    'safe': [
      v.viewPadding.top / v.devicePixelRatio,
      v.viewPadding.bottom / v.devicePixelRatio,
    ],
    'keyboard': v.viewInsets.bottom / v.devicePixelRatio,
    'input': find<TextField>() == null
        ? null
        : (find<TextField>()!.widget as TextField).controller?.text,
    'frameworkErrors': errors,
    'asyncErrors': asyncErrors,
    'unexpectedApi': api.unexpected,
    'requests': api.requests,
    'nativeShareDelegations':
        base.archiveAllShareMessenger?.nativeDelegationCount,
    'passed': errors.isEmpty && asyncErrors.isEmpty && api.unexpected.isEmpty,
  };
}

Future<void> main() => http.runWithClient(() async {
  base.ArchiveAllFixtureBinding();
  final previous = FlutterError.onError;
  FlutterError.onError = (d) {
    errors.add(d.exceptionAsString());
    previous?.call(d);
  };
  ui.PlatformDispatcher.instance.onError = (e, s) {
    asyncErrors.add('$e');
    return true;
  };
  await scene('account');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8778);
  debugPrint('SYSTEM_BACK ready $phase');
  await for (final request in server) {
    try {
      switch (request.uri.path) {
        case '/state':
          break;
        case '/scene':
          await scene(request.uri.queryParameters['kind'] ?? 'account');
          break;
        case '/back':
          await WidgetsBinding.instance.handlePopRoute();
          await settle();
          break;
        case '/save':
          (find<ClipbackNavigationBar>()!.widget as ClipbackNavigationBar)
              .onAdd!();
          await settle();
          break;
        case '/tap':
          await tap(key(request.uri.queryParameters['key']!)!);
          break;
        case '/input':
          final f = find<TextField>()!.widget as TextField;
          final value = request.uri.queryParameters['value'] ?? '입력 보존 확인';
          f.controller!.text = value;
          f.onChanged?.call(value);
          await settle();
          break;
        case '/focus':
          await tap(find<TextField>()!);
          break;
        case '/unfocus':
          FocusManager.instance.primaryFocus?.unfocus();
          await settle();
          break;
        case '/header':
          if (find<AccountManagementScreen>() != null) {
            (find<AccountManagementScreen>()!.widget as AccountManagementScreen)
                .onBack();
          } else if (find<DetailScreen>() != null) {
            (find<DetailScreen>()!.widget as DetailScreen).onBack();
          } else if (find<SearchScreen>() != null) {
            (find<SearchScreen>()!.widget as SearchScreen).onClose();
          }
          await settle();
          break;
        default:
          request.response.statusCode = 404;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(state()));
    } catch (e, s) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$e', 'stack': '$s'}));
    }
    await request.response.close();
  }
}, () => api.client);
