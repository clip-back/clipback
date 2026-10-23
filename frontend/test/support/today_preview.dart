// Actual-root fixture: API/session/share are isolated; the URL launcher is real.
// Freeze this source before capturing the baseline. No URL plugin import is
// needed here, so the same fixture compiles on the pre-fix commit.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'archive_all_preview.dart' as isolated;
import 'asset_access_fixture.dart';
import '../fixtures/today_server.dart';

const originalPreviewUrl = 'https://example.com/?clipback=original#source';
const _phase = String.fromEnvironment(
  'TODAY_PHASE',
  defaultValue: 'before',
);
final _rootKey = GlobalKey();
final _frameworkErrors = <String>[];
final _asyncErrors = <String>[];
late TodayServer _api;
int _epoch = 0, _pointer = 900;
String _kind = 'link';
Element get _root => _rootKey.currentContext! as Element;

class OriginalLinkPreviewServer extends isolated.ArchiveAllServer {
  final metrics = <Map<String, dynamic>>[];
  late final previewClient = MockClient((request) async {
    if (request.url.path == '/api/v1/metrics/events') {
      metrics.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
    }
    if (request.url.path == '/api/v1/uploads/assets/901/access') {
      final bytes = await rootBundle.load(Assets.savedPhotoPreview);
      return originalAccessFixture(901, bytes.buffer.asUint8List());
    }
    if (request.url.path == '/api/v1/uploads/assets/901') {
      final bytes = await rootBundle.load(Assets.savedPhotoPreview);
      return http.Response.bytes(
        bytes.buffer.asUint8List(),
        200,
        headers: {'content-type': 'image/png'},
      );
    }
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return client.send(copy).then(http.Response.fromStream);
  });

  void reset(String kind) {
    metrics.clear();
    records[0] = {
      ...records[0],
      'title': '자소서 합격률 UP\n이건 무조건! 적용해야 합니다',
      'summary':
          '자기소개서를 혁신적으로 끝까지 다 읽기는 어렵습니다. 요약 없이 문장이 길게 나열되어 있으면, 읽는 입장에서는 숨부터 막히기 시작하죠.',
      'original_url': kind == 'photo' ? null : originalPreviewUrl,
      'content_type': kind == 'photo' ? 'screenshot' : 'link',
      'source': kind == 'photo' ? 'screenshot' : 'web',
      'is_favorite': false,
      'assets': kind == 'photo'
          ? [
              {
                'id': 901,
                'asset_type': 'screenshot',
                'download_url': '/api/v1/uploads/assets/901',
                'mime_type': 'image/png',
              },
            ]
          : <Object>[],
    };
  }
}

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
  _api.resetToday(kind);
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

Map<String, Object?> _state() {
  final detail = _find<DetailScreen>();
  final button = _key('detail-original-button');
  final v = View.of(_root);
  final originals = _api.metrics
      .where((m) => m['event_type'] == 'original_link_opened')
      .toList();
  return {
    'phase': _phase,
    'kind': _kind,
    'homePresent':_find<HomeScreen>()!=null,
    'sequence':detail==null?null:(detail.widget as DetailScreen).contents.map((c)=>c.apiId).toList(),
    'calls':_api.calls,
    'snackbars':_elements(_root).where((e)=>e.widget is SnackBar).map((e)=>(e.widget as SnackBar).content is Text?((e.widget as SnackBar).content as Text).data:'other').toList(),
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
    'passed':_frameworkErrors.isEmpty && _asyncErrors.isEmpty,
    'layoutPassed':_frameworkErrors.isEmpty,
    'stylePassed':_frameworkErrors.isEmpty,
  };
}

Future<void> main() => http.runWithClient(() async {
  isolated.ArchiveAllFixtureBinding();
  _api = TodayServer();
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
        case '/today':
          await _tap(_text('오늘의 콘텐츠 보기 →')!, settle:false);
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
          _api.mode=req.uri.queryParameters['value']??'normal';
        case '/bookmark':
          final d=_find<DetailScreen>()!.widget as DetailScreen;
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
}, () => _api.todayClient);
