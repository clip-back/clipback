// Actual root with fixed HTTP/session/share doubles. The scene and capture
// data are shared by BEFORE/AFTER; additional interaction/report controls do
// not change product state or the captured scene data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:http/http.dart' as http;
import 'archive_all_preview.dart' as isolated;
import '../fixtures/weekly_server.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';

const originalPreviewUrl = 'https://example.com/?clipback=original#source';
const _phase = String.fromEnvironment('WEEKLY_PHASE', defaultValue: 'before');
final _rootKey = GlobalKey();
final _frameworkErrors = <String>[];
final _asyncErrors = <String>[];
late WeeklyServer _api;
int _epoch = 0, _pointer = 900;
String _kind = 'link';
Element get _root => _rootKey.currentContext! as Element;

Iterable<Element> _elements(Element node) sync* {
  yield node;
  final children = <Element>[];
  node.visitChildren(children.add);
  for (final child in children) {
    yield* _elements(child);
  }
}

Element? _find<T extends Widget>() =>
    _elements(_root).where((e) => e.widget is T).firstOrNull;
Element? _key(String value) =>
    _elements(_root).where((e) => e.widget.key == ValueKey(value)).firstOrNull;
Element? _text(String value) => _elements(_root)
    .where((e) => e.widget is Text && (e.widget as Text).data == value)
    .firstOrNull;
Rect _rect(Element e) {
  final box = e.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

Map<String, double> _bounds(Rect r) => {
  'left': r.left,
  'top': r.top,
  'width': r.width,
  'height': r.height,
};
ScrollPosition? get _position {
  final detail = _find<DetailScreen>();
  if (detail == null) return null;
  final e = _elements(detail).where((e) => e.widget is Scrollable).firstOrNull;
  return e == null
      ? null
      : ((e as StatefulElement).state as ScrollableState).position;
}

Future<void> _settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 4),
    );
  }
}

Future<void> _tap(Element e, {bool settle = true}) async {
  final p = _rect(e).center, id = ++_pointer, viewId = View.of(_root).viewId;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: viewId, position: p),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: viewId, position: p),
  );
  if (settle) await _settle();
}

Future<void> _scene(String kind) async {
  _kind = kind;
  _api.resetWeekly(kind);
  runApp(
    KeyedSubtree(
      key: ValueKey(++_epoch),
      child: SizedBox(
        key: _rootKey,
        child: ClipbackApp(
          key: ValueKey(_epoch),
          sessionStorage: isolated.ArchiveAllMemoryStorage(),
          socialAuth: isolated.ArchiveAllSocialAuth(),
        ),
      ),
    ),
  );
  await _settle();
  for (var i = 0; i < 100 && _find<HomeScreen>() == null; i++) {
    await _settle();
  }
}

List<Map<String, Object?>> _paragraphs() {
  final rail = _find<WeeklyPickRail>();
  if (rail == null) return [];
  return [
    for (final e in _elements(rail))
      if (e.widget is RichText && e.findRenderObject() is RenderParagraph)
        (() {
          final p = e.findRenderObject()! as RenderParagraph;
          final t = p.text;
          final style = t.style;
          return <String, Object?>{
            'text': t.toPlainText(),
            'rect': _bounds(_rect(e)),
            'fontFamily': style?.fontFamily,
            'fontSize': style?.fontSize,
            'weight': style?.fontWeight?.value,
            'letterSpacing': style?.letterSpacing,
            'height': style?.height,
            'color': style?.color?.toARGB32(),
            'maxLines': p.maxLines,
            'overflow': p.overflow.name,
          };
        })(),
  ];
}

bool _layoutPassed() {
  final cards = [
    for (final e in _elements(_root))
      if (e.widget.key is ValueKey<String> &&
          (e.widget.key as ValueKey<String>).value.startsWith('weekly-card-'))
        _rect(e),
  ];
  if (_phase == 'before') return true;
  return cards.every(
        (r) => (r.width - 133).abs() < 0.01 && (r.height - 120).abs() < 0.01,
      ) &&
      _paragraphs().every((p) {
        final b = p['rect'] as Map;
        final rect = Rect.fromLTWH(
          b['left'] as double,
          b['top'] as double,
          b['width'] as double,
          b['height'] as double,
        );
        return cards.any(
          (c) =>
              c.inflate(0.1).contains(rect.topLeft) &&
              c.inflate(0.1).contains(rect.bottomRight),
        );
      });
}

Map<String, Object?> _state() {
  final detail = _find<DetailScreen>();
  final button = _key('detail-original-button');
  final v = View.of(_root);
  final originals = _api.metrics
      .where((m) => m['event_type'] == 'original_link_opened')
      .toList();
  return {
    'phase': _phase,
    'paragraphs': _paragraphs(),
    'weeklyCards': [
      for (final e in _elements(_root))
        if (e.widget.key is ValueKey<String> &&
            ((e.widget.key as ValueKey<String>).value).startsWith(
              'weekly-card-',
            ))
          {
            'key': (e.widget.key as ValueKey<String>).value,
            'rect': _bounds(_rect(e)),
          },
    ],
    'kind': _kind,
    'homePresent': _find<HomeScreen>() != null,
    'archivePresent': _find<ArchiveScreen>() != null,
    'category':
        (_find<ArchiveScreen>()?.widget as ArchiveScreen?)?.activeCategoryName,
    'weeklyTexts': _find<WeeklyPickRail>() == null
        ? []
        : _elements(
            _find<WeeklyPickRail>()!,
          ).where((e) => e.widget is Text).map((e) {
            final t = e.widget as Text;
            return t.data ?? t.textSpan?.toPlainText();
          }).toList(),
    'sequence': detail == null
        ? null
        : (detail.widget as DetailScreen).contents.map((c) => c.apiId).toList(),
    'calls': _api.calls,
    'snackbars': _elements(_root)
        .where((e) => e.widget is SnackBar)
        .map(
          (e) => (e.widget as SnackBar).content is Text
              ? ((e.widget as SnackBar).content as Text).data
              : 'other',
        )
        .toList(),
    'ready': true,
    'platform': Platform.operatingSystem,
    'logicalSize': {
      'width': v.physicalSize.width / v.devicePixelRatio,
      'height': v.physicalSize.height / v.devicePixelRatio,
    },
    'viewPadding': {
      'top': v.viewPadding.top / v.devicePixelRatio,
      'bottom': v.viewPadding.bottom / v.devicePixelRatio,
    },
    'detailPresent': detail != null,
    'sheetPresent': _find<OriginalContentSheet>() != null,
    'expanded': _key('detail-original-text') != null,
    'scroll': _position?.pixels,
    'maxScroll': _position?.maxScrollExtent,
    'button': button == null ? null : _bounds(_rect(button)),
    'contentId': detail == null
        ? null
        : (detail.widget as DetailScreen).content.apiId,
    'originalEvents': originals,
    'frameworkErrors': _frameworkErrors,
    'asyncErrors': _asyncErrors,
    'unknownShareMethods':
        isolated.archiveAllShareMessenger?.unknownShareMethods,
    'nativeShareDelegations':
        isolated.archiveAllShareMessenger?.nativeDelegationCount,
    'passed': _frameworkErrors.isEmpty && _asyncErrors.isEmpty,
    'layoutPassed': _frameworkErrors.isEmpty && _layoutPassed(),
    'stylePassed': _paragraphs().every(
      (p) =>
          p['fontFamily'] == 'Pretendard' &&
          (p['fontSize'] == 14 || p['fontSize'] == 16) &&
          p['maxLines'] != null,
    ),
  };
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _api = WeeklyServer();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _frameworkErrors.add(details.exceptionAsString());
    previous?.call(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    _asyncErrors.add('$error');
    debugPrint('ORIGINAL_LINK async: $error');
    return true;
  };
  await _scene('link');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8775);
  debugPrint('TODAY ready phase=$_phase port=8775');
  await for (final req in server) {
    try {
      switch (req.uri.path) {
        case '/ready':
        case '/state':
          break;
        case '/scene':
          await _scene(req.uri.queryParameters['kind'] ?? 'link');
        case '/archive':
          (_find<HomeScreen>()!.widget as HomeScreen).onOpenCategories();
          await _settle();
        case '/sort':
          (_find<ArchiveScreen>()!.widget as ArchiveScreen).onSortChanged(true);
          await _settle();
        case '/modal':
          (_find<ClipbackNavigationBar>()!.widget as ClipbackNavigationBar)
              .onAdd!();
          await _settle();
        case '/close-modal':
          Navigator.of(_find<AddContentSheet>()!).pop();
          await _settle();
        case '/retry':
          (_find<SnackBarAction>()!.widget as SnackBarAction).onPressed();
          await _settle();
        case '/pick':
          final rail = _find<WeeklyPickRail>()!;
          final target = _elements(
            rail,
          ).where((e) => e.widget is InkWell).first;
          await _tap(target);
        case '/archive-back':
          (_find<ArchiveScreen>()!.widget as ArchiveScreen).onClearCategory();
          await _settle();
        case '/content':
          final a = _find<ArchiveScreen>()!.widget as ArchiveScreen;
          a.onOpenContent(a.contents.first);
          await _settle();
        case '/home':
          final a = _find<ArchiveScreen>();
          if (a != null) (a.widget as ArchiveScreen).onTab(AppRoute.home);
          await _settle();
        case '/home-scroll':
          final e = _key('home-scroll')!;
          final scroll =
              _elements(e).where((e) => e.widget is Scrollable).first
                  as StatefulElement;
          final p = (scroll.state as ScrollableState).position;
          p.jumpTo(
            req.uri.queryParameters['offset'] == 'max' ? p.maxScrollExtent : 0,
          );
          await _settle();
        case '/today':
          await _tap(_text('오늘의 콘텐츠 보기 →')!, settle: false);
          await _settle();
        case '/next':
          (_find<DetailScreen>()!.widget as DetailScreen).onOpenAdjacent(1);
          await _settle();
        case '/previous':
          (_find<DetailScreen>()!.widget as DetailScreen).onOpenAdjacent(-1);
          await _settle();
        case '/back':
          (_find<DetailScreen>()!.widget as DetailScreen).onBack();
          await _settle();
        case '/mode':
          _api.weeklyMode = req.uri.queryParameters['value'] ?? 'normal';
        case '/bookmark':
          final d = _find<DetailScreen>()!.widget as DetailScreen;
          d.onToggleBookmark(d.content);
          await _settle();
        case '/original':
          await _tap(_key('detail-original-button')!, settle: false);
        case '/toggle':
          await _tap(_text(_kind == 'photo' ? '원본 이미지 보기' : '전문 보기')!);
        case '/scroll':
          final pos = _position!;
          pos.jumpTo(
            req.uri.queryParameters['offset'] == 'max'
                ? pos.maxScrollExtent
                : double.parse(
                    req.uri.queryParameters['offset'] ?? '0',
                  ).clamp(0, pos.maxScrollExtent),
          );
          await _settle();
        case '/close-sheet':
          Navigator.of(_find<OriginalContentSheet>()!).pop();
          await _settle();
        default:
          req.response.statusCode = 404;
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(_state()));
    } catch (error, stack) {
      req.response.statusCode = 500;
      req.response.write(jsonEncode({'error': '$error', 'stack': '$stack'}));
    }
    await req.response.close();
  }
}, () => _api.weeklyClient);
