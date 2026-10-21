// Actual root with isolated API/session/share. Only fixture-prefixed native
// preferences persist across processes; normal user keys are never accessed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'archive_all_preview.dart' as base;

const phase = String.fromEnvironment('HISTORY_PHASE', defaultValue: 'before');
var rootKey = GlobalKey();
final errors = <String>[], asyncErrors = <String>[];
final api = base.ArchiveAllServer();
int epoch = 0, pointer = 900, account = 81001;
bool failSearch = false;
late SharedPreferences prefs;
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
Rect rect(Element e) {
  final b = e.findRenderObject()! as RenderBox;
  return b.localToGlobal(Offset.zero) & b.size;
}

Map<String, double> bounds(Rect r) => {
  'x': r.left,
  'y': r.top,
  'width': r.width,
  'height': r.height,
};
Future<void> settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame;
  }
}

Future<void> tap(Element e) async {
  final p = rect(e).center, id = ++pointer, v = View.of(root).viewId;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: v, position: p),
  );
  await Future<void>.delayed(const Duration(milliseconds: 30));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: v, position: p),
  );
  await settle();
}

SearchScreen get screen => find<SearchScreen>()!.widget as SearchScreen;
TextField get field => find<TextField>()!.widget as TextField;
Future<void> open() async {
  (find<HomeScreen>()!.widget as HomeScreen).onSearch();
  await settle();
  for (final e in elements(
    root,
  ).where((e) => e.widget is IconButton).toList()) {
    final b = e.widget as IconButton;
    if (b.icon is Icon && (b.icon as Icon).semanticLabel == '나중에') {
      b.onPressed?.call();
    }
  }
  await settle();
}

Future<void> clear() async {
  field.controller!.clear();
  field.onChanged!('');
  await settle();
}

Future<void> submit(String term) async {
  field.controller!.text = term;
  field.onChanged!(term);
  field.onSubmitted!(term);
  await settle();
}

Future<void> fresh({bool clearStorage = false}) async {
  if (clearStorage) {
    for (final k in prefs.getKeys().toList()) {
      await prefs.remove(k);
    }
  }
  rootKey = GlobalKey();
  runApp(
    KeyedSubtree(
      key: ValueKey(++epoch),
      child: SizedBox(
        key: rootKey,
        child: ClipbackApp(
          key: ValueKey(epoch),
          sessionStorage: base.ArchiveAllMemoryStorage(),
          socialAuth: base.ArchiveAllSocialAuth(),
        ),
      ),
    ),
  );
  for (var i = 0; i < 60; i++) {
    await settle();
    if (find<HomeScreen>() != null) break;
  }
  if (find<HomeScreen>() == null) throw StateError('home not ready');
  await open();
}

Map<String, Object?> state() {
  final rows = elements(
    root,
  ).where((e) => e.widget is SearchHistoryRow).toList();
  final paragraphs = <Map<String, Object?>>[];
  for (final e in rows) {
    for (final p in elements(e)) {
      if (p.widget is RichText && p.findRenderObject() is RenderParagraph) {
        final r = p.findRenderObject()! as RenderParagraph, s = r.text.style;
        paragraphs.add({
          'text': r.text.toPlainText(),
          'rect': bounds(rect(p)),
          'fontFamily': s?.fontFamily,
          'fontSize': s?.fontSize,
          'weight': s?.fontWeight?.value,
          'spacing': s?.letterSpacing,
          'height': s?.height,
          'color': s?.color?.toARGB32(),
          'maxLines': r.maxLines,
          'overflow': r.overflow.name,
        });
      }
    }
  }
  final style = paragraphs.every(
    (p) =>
        p['fontFamily'] == 'Pretendard' &&
        p['fontSize'] == 14 &&
        p['weight'] == 500 &&
        p['spacing'] == -.35 &&
        p['height'] == null &&
        p['color'] == 0xff767676 &&
        p['maxLines'] == 1 &&
        p['overflow'] == 'ellipsis',
  );
  final layout = rows.every((e) => rect(e).height == 32) && errors.isEmpty;
  final v = View.of(root);
  return {
    'phase': phase,
    'account': account,
    'search': find<SearchScreen>() != null,
    'home': find<HomeScreen>() != null,
    'terms': rows.map((e) => (e.widget as SearchHistoryRow).term).toList(),
    'paragraphs': paragraphs,
    'rows': rows.map((e) => bounds(rect(e))).toList(),
    'calls': api.requests,
    'frameworkErrors': errors,
    'asyncErrors': asyncErrors,
    'stylePassed': style,
    'layoutPassed': layout,
    'passed': style && layout && asyncErrors.isEmpty,
    'window': [
      v.physicalSize.width / v.devicePixelRatio,
      v.physicalSize.height / v.devicePixelRatio,
    ],
    'padding': [
      v.viewPadding.top / v.devicePixelRatio,
      v.viewPadding.bottom / v.devicePixelRatio,
    ],
    'keyboard': v.viewInsets.bottom / v.devicePixelRatio,
    'stored': {for (final k in prefs.getKeys()) k: prefs.get(k)},
  };
}

Future<void> main() => http.runWithClient(
  () async {
    base.ArchiveAllFixtureBinding();
    SharedPreferences.setPrefix('clipback_history_verification_20261022.');
    prefs = await SharedPreferences.getInstance();
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      errors.add(d.exceptionAsString());
      old?.call(d);
    };
    ui.PlatformDispatcher.instance.onError = (e, s) {
      asyncErrors.add('$e');
      return true;
    };
    await fresh();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8777);
    debugPrint('HISTORY ready $phase');
    await for (final req in server) {
      try {
        switch (req.uri.path) {
          case '/state':
            break;
          case '/fresh':
            account = int.parse(req.uri.queryParameters['account'] ?? '81001');
            await fresh(clearStorage: req.uri.queryParameters['clear'] == '1');
            break;
          case '/open':
            await open();
            break;
          case '/close':
            screen.onClose();
            await settle();
            break;
          case '/clear':
            await clear();
            break;
          case '/submit':
            await submit(req.uri.queryParameters['q'] ?? '');
            break;
          case '/remove':
            final term = req.uri.queryParameters['q'];
            await tap(
              elements(root).firstWhere(
                (e) => e.widget.key == ValueKey('search-history-remove-$term'),
              ),
            );
          case '/select':
            final row = elements(root).firstWhere(
              (e) =>
                  e.widget is SearchHistoryRow &&
                  (e.widget as SearchHistoryRow).term ==
                      req.uri.queryParameters['q'],
            );
            await tap(row);
          case '/type':
            final value = req.uri.queryParameters['q'] ?? '';
            field.controller!.text = value;
            field.onChanged!(value);
            await settle();
          case '/show-keyboard':
            await tap(find<TextField>()!);
          case '/fail':
            failSearch = req.uri.queryParameters['value'] == '1';
            break;
          case '/keyboard':
            FocusScope.of(root).unfocus();
            await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
            await settle();
            break;
          default:
            req.response.statusCode = 404;
        }
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(state()));
      } catch (e, s) {
        req.response.statusCode = 500;
        req.response.write(jsonEncode({'error': '$e', 'stack': '$s'}));
      }
      await req.response.close();
    }
  },
  () => MockClient((r) async {
    if (r.url.path == '/api/v1/auth/share-credential') {
      return api.json({
        'share_token': 'fixture-share',
        'expires_at': '2030-10-17T00:00:00Z',
        'user_id': account,
        'session_id': 1,
      });
    }
    if (r.url.path == '/api/v1/users/me') {
      return api.json({
        'id': account,
        'email': null,
        'display_name': '검색 기록 검증',
        'is_guest': true,
        'created_at': '2026-10-22T00:00:00Z',
        'linked_providers': <String>[],
      });
    }
    if (failSearch &&
        r.url.path == '/api/v1/feed' &&
        r.url.queryParameters['q'] != null) {
      api.requests.add({
        'method': r.method,
        'path': r.url.path,
        'query': r.url.queryParameters,
      });
      return api.json({'detail': 'fixture failure'}, 503);
    }
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return api.client.send(copy).then(http.Response.fromStream);
  }),
);
