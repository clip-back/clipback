// Deterministic local DetailScreen host; no backend, OAuth, or physical device.
// flutter run --no-pub -t test/support/detail_preview.dart
//   --dart-define=DETAIL_PREVIEW_PHASE=before|after
// Loopback :8767: /ready /state /status /scene?kind=basic|expanded|empty&scroll=0|half|<px>
// /scroll?offset=<px>|half|max, /run?expandedOffset=<BEFORE concrete half offset>.
// Android forwarding: adb forward tcp:8768 tcp:8767. Only actual text scale 1.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/tag_chip.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const _phase = String.fromEnvironment(
  'DETAIL_PREVIEW_PHASE',
  defaultValue: 'before',
);
const _title = '오래 간직하고 싶은 디자인의 작은 발견과 기록';
const _summary =
    '매일 마주치는 작은 장면에서 새로운 영감을 발견합니다. '
    '눈에 들어온 색과 형태를 차분하게 모으고, 시간이 지난 뒤 다시 읽으며 생각을 정리합니다. '
    '이 요약은 세 줄을 넘는 실제 본문이 끝까지 보이는지 확인하기 위한 고정 데이터입니다. '
    '마지막 문장도 높이 제한이나 말줄임 없이 이어져야 합니다.';
final _original = List.generate(
  12,
  (i) =>
      '${i + 1}. 기록을 다시 꺼내 읽는 시간\n'
      '디자인을 살펴볼 때 화면의 모양과 함께 정보가 이어지는 흐름도 기록합니다. '
      '글의 길이가 늘어나도 실제 문장과 줄바꿈을 그대로 보존합니다. '
      '이 원문은 API에서 얻은 전문이 아닌 프리뷰용 고정 대역 텍스트입니다.',
).join('\n\n');
const _empty = '불러온 목록에 연관 콘텐츠가 없어요.';
const _cat = CategoryItem(
  id: 101,
  name: '콘텐츠 디자인',
  color: AppColors.main,
  tint: AppColors.mainSubtle,
  deep: AppColors.mainDeep,
);
const _second = CategoryItem(
  id: 102,
  name: '다시 읽기',
  color: AppColors.blueDeep,
  tint: AppColors.blueSubtle,
  deep: AppColors.blueDeep,
);
const _other = CategoryItem(
  id: 103,
  name: '다른 주제',
  color: AppColors.subtle,
  tint: AppColors.faint,
  deep: AppColors.middle,
);
final _hostKey = GlobalKey<_HostState>();
final _navKey = GlobalKey<NavigatorState>();
final _captureKey = GlobalKey();
final _errors = <Map<String, Object?>>[];
final _checks = <Map<String, Object?>>[];
final _events = <Map<String, Object?>>[];
late Uint8List _photo;
late Directory _output;
var _kind = 'basic';
var _scene = 'idle';
var _busy = false;
var _complete = false;
var _coveragePassed = false;
var _pointer = 9000;
double? _beforeExpandedHalf;
double? _beforeExpandedMaximum;

ContentItem _item(
  String id, {
  List<CategoryItem> categories = const [_cat],
  String title = _title,
  bool screenshot = false,
}) => ContentItem(
  id: id,
  title: title,
  summary: _summary,
  category: categories.first,
  categories: categories,
  savedAt: '10.17',
  savedAtFull: '2026.10.17',
  savedAtFullShort: '26.10.17',
  tags: const ['디자인', '영감', '기록'],
  source: screenshot ? '사진' : '웹사이트',
  originalUrl: screenshot ? '' : 'https://example.invalid/detail',
  originalText: _original,
  isScreenshot: screenshot,
  assets: screenshot
      ? const [
          ApiAsset(
            id: 9,
            assetType: 'screenshot',
            downloadUrl: '/fixture/photo',
            mimeType: 'image/png',
          ),
        ]
      : const [],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _require(_phase == 'before' || _phase == 'after', 'Unknown phase');
  final asset = await rootBundle.load(Assets.savedPhotoPreview);
  _photo = asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
  _output = await Directory.systemTemp.createTemp('clipback-detail-');
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add({'scene': _scene, 'error': details.exceptionAsString()});
    previous?.call(details);
  };
  runApp(_Host(key: _hostKey));
  await _settle();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'DETAIL_PREVIEW ready phase=$_phase output=${_output.path} port=8767',
  );
  await for (final request in server) {
    final reads = const [
      '/ready',
      '/state',
      '/status',
    ].contains(request.uri.path);
    if (_busy && !reads) {
      request.response.statusCode = HttpStatus.conflict;
      request.response.write('Fixture is busy');
      await request.response.close();
      continue;
    }
    if (!reads) _busy = true;
    try {
      switch (request.uri.path) {
        case '/ready':
        case '/state':
        case '/status':
          break;
        case '/scene':
          await _open(request.uri.queryParameters['kind'] ?? 'basic');
          await _setScroll(request.uri.queryParameters['scroll'] ?? '0');
          await _capture(_captureName());
        case '/scroll':
          await _setScroll(
            request.uri.queryParameters['offset'] ??
                (request.uri.queryParameters['max'] == '1' ? 'max' : 'half'),
          );
          await _capture(_captureName());
        case '/run':
          await _run(
            double.tryParse(
              request.uri.queryParameters['expandedOffset'] ?? '',
            ),
          );
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await _report();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_snapshot()));
    } catch (error, stack) {
      _checks.add({'scenario': _scene, 'passed': false, 'error': '$error'});
      debugPrint('DETAIL_PREVIEW FAIL $error\n$stack');
      await _report();
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!reads) _busy = false;
      await request.response.close();
    }
  }
}

class _Host extends StatefulWidget {
  const _Host({super.key});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  AppRoute route = AppRoute.detail;
  List<ContentItem> contents = [];
  String activeId = 'main';
  final bookmarks = <String>{};
  final calls = <Map<String, Object?>>[];
  int epoch = 0;
  ContentItem get active => contents.firstWhere((item) => item.id == activeId);
  @override
  void initState() {
    super.initState();
    _reset('basic');
  }

  void _record(String action, [Map<String, Object?> data = const {}]) {
    final event = {'action': action, 'scene': _scene, ...data};
    calls.add(event);
    _events.add(event);
  }

  void _reset(String kind, {bool photo = false}) {
    route = AppRoute.detail;
    activeId = photo ? 'photo-main' : 'main';
    bookmarks.clear();
    calls.clear();
    epoch++;
    contents = [
      _item(activeId, categories: const [_cat, _second], screenshot: photo),
      if (kind != 'empty') ...[
        _item('related-one', title: '한 가지 카테고리로 다시 보는 콘텐츠'),
        _item(
          'related-many',
          categories: const [_cat, _second],
          title: '여러 카테고리를 가진 연관 콘텐츠 제목',
        ),
      ],
      _item('other', categories: const [_other], title: '다른 주제의 다음 콘텐츠'),
    ];
  }

  void reset(String kind, {bool photo = false}) =>
      setState(() => _reset(kind, photo: photo));
  void open(ContentItem value, String action) => setState(() {
    _record(action, {'id': value.id});
    activeId = value.id;
    route = AppRoute.detail;
  });
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: _captureKey,
    child: MaterialApp(
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: route != AppRoute.detail
          ? Scaffold(body: Center(child: Text('프리뷰 목적지: ${route.name}')))
          : DetailScreen(
              key: ValueKey('detail-host-$epoch'),
              content: active,
              contents: contents,
              categories: const [_cat, _second, _other],
              bookmarked: bookmarks.contains(activeId),
              onReadAsset: (id) async {
                _record('readAsset', {
                  'assetId': id,
                  'byteLength': _photo.length,
                });
                return _photo;
              },
              onBack: () => setState(() {
                _record('back');
                route = AppRoute.archive;
              }),
              onToggleBookmark: (item) => setState(() {
                _record('bookmark', {'id': item.id});
                if (!bookmarks.add(item.id)) bookmarks.remove(item.id);
              }),
              onChangeCategory: (item, category) => setState(() {
                _record('category', {'id': item.id, 'categoryId': category.id});
                contents = contents
                    .map(
                      (value) => value.id == item.id
                          ? value.copyWith(category: category)
                          : value,
                    )
                    .toList();
              }),
              onDeleteContent: (item) => _record('delete', {'id': item.id}),
              onOpenOriginalLink: () =>
                  _record('openOriginalLink', {'id': activeId}),
              onOpenAdjacent: (delta) {
                final index = contents.indexWhere(
                  (item) => item.id == activeId,
                );
                _require(
                  index + delta >= 0 && index + delta < contents.length,
                  'Adjacent callback out of range',
                );
                open(contents[index + delta], 'adjacent$delta');
              },
              onOpenContent: (item) => open(item, 'related'),
              onAddLink: ({required url, category}) async {
                _record('saveLink', {'url': url});
                return _item('saved-link');
              },
              onAddScreenshot:
                  ({required bytes, required filename, category}) async {
                    _record('savePhoto', {
                      'filename': filename,
                      'byteLength': bytes.length,
                    });
                    return _item('saved-photo', screenshot: true);
                  },
              onTab: (next) => setState(() {
                _record('tab', {'route': next.name});
                route = next;
              }),
            ),
    ),
  );
}

void _require(bool value, String message) {
  if (!value) throw StateError(message);
}

List<Element> _elements([Element? root]) {
  final result = <Element>[];
  void visit(Element element) {
    if (element.widget case Offstage(offstage: true)) return;
    result.add(element);
    element.visitChildren(visit);
  }

  visit(root ?? _captureKey.currentContext! as Element);
  return result;
}

Element? _find<T extends Widget>([Element? root]) =>
    _elements(root).where((e) => e.widget is T).firstOrNull;
Element? _key(String name, [Element? root]) => _elements(
  root,
).where((e) => e.widget.key == ValueKey<String>(name)).firstOrNull;
Element? _text(String text, [Element? root]) => _elements(
  root,
).where((e) => e.widget is Text && (e.widget as Text).data == text).firstOrNull;
Element? _ancestor(Element element, bool Function(Widget) predicate) {
  Element? found;
  element.visitAncestorElements((candidate) {
    if (predicate(candidate.widget)) {
      found = candidate;
      return false;
    }
    return true;
  });
  return found;
}

Rect _rect(Element element) {
  final render = element.findRenderObject()! as RenderBox;
  return render.localToGlobal(Offset.zero) & render.size;
}

Map<String, double> _box(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'right': rect.right,
  'bottom': rect.bottom,
  'width': rect.width,
  'height': rect.height,
};
String? _color(Color? color) => color == null
    ? null
    : '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
bool _near(Object? value, double target) =>
    value is num && (value - target).abs() < .15;
ScrollPosition get _position {
  final list = _find<ListView>(_find<DetailScreen>())!;
  return (_find<Scrollable>(list)! as StatefulElement).state is ScrollableState
      ? ((_find<Scrollable>(list)! as StatefulElement).state as ScrollableState)
            .position
      : throw StateError('Detail scroll state missing');
}

Future<void> _settle([int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 60),
    );
  }
}

Future<void> _tap(Element element) async {
  final point = _rect(element).center;
  final pointer = ++_pointer;
  final view = View.of(_captureKey.currentContext!);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, viewId: view.viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 80));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      viewId: view.viewId,
      position: point,
      timeStamp: const Duration(milliseconds: 80),
    ),
  );
  await _settle();
}

Future<void> _tapText(String value) async {
  final target = _text(value);
  _require(target != null, 'Text action missing: $value');
  await Scrollable.ensureVisible(
    target!,
    duration: const Duration(milliseconds: 180),
  );
  await _settle();
  await _tap(target);
}

Element? _icon(String asset, [Element? root]) {
  final role = {
    Assets.back: 'detail-back',
    Assets.more: 'detail-more',
    Assets.link: 'detail-original-button',
  }[asset];
  return (role == null ? null : _key(role, root)) ??
      _elements(root)
          .where(
            (e) =>
                e.widget is SvgIconButton &&
                (e.widget as SvgIconButton).asset == asset,
          )
          .firstOrNull;
}

bool get _expanded =>
    _find<FullContentPreview>() != null ||
    (_hostKey.currentState!.active.isScreenshot &&
        _elements().any(
          (e) => e.widget.runtimeType.toString() == '_ScreenshotAssetView',
        ));
Future<void> _open(String kind, {bool photo = false}) async {
  _require(
    const ['basic', 'expanded', 'empty'].contains(kind),
    'Unknown detail scene',
  );
  _navKey.currentState!.popUntil((route) => route.isFirst);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  _kind = kind;
  _scene = 'detail_$kind';
  _hostKey.currentState!.reset(kind, photo: photo);
  await _settle();
  _position.jumpTo(0);
  await _settle();
  if (kind == 'expanded') await _toggleOriginal();
  _position.jumpTo(0);
  await _settle();
  if (kind == 'expanded') {
    await _setScroll('max');
    _beforeExpandedMaximum ??= _position.maxScrollExtent;
    _beforeExpandedHalf ??= _position.maxScrollExtent / 2;
    _position.jumpTo(0);
    await _settle();
  }
}

Future<void> _toggleOriginal() async {
  var target = _text(
    _hostKey.currentState!.active.isScreenshot ? '원본 이미지 보기' : '전문 보기',
  );
  for (var i = 0; target == null && i < 15; i++) {
    _position.jumpTo(
      (_position.pixels + 220).clamp(0, _position.maxScrollExtent),
    );
    await _settle(2);
    target = _text(
      _hostKey.currentState!.active.isScreenshot ? '원본 이미지 보기' : '전문 보기',
    );
  }
  _require(target != null, 'Original toggle missing');
  await Scrollable.ensureVisible(
    target!,
    duration: const Duration(milliseconds: 180),
  );
  await _settle();
  await _tap(target);
}

Future<void> _setScroll(String value) async {
  if (value == 'max') {
    for (var attempt = 0; attempt < 8; attempt++) {
      _position.jumpTo(_position.maxScrollExtent);
      await _settle(2);
      if ((_position.pixels - _position.maxScrollExtent).abs() < .1) return;
    }
    _require(
      (_position.pixels - _position.maxScrollExtent).abs() < .1,
      'Detail maximum scroll extent did not settle',
    );
    return;
  }
  final target = value == 'max'
      ? _position.maxScrollExtent
      : value == 'half'
      ? _position.maxScrollExtent / 2
      : double.parse(value);
  _require(
    target >= 0 && target <= _position.maxScrollExtent + .1,
    'Requested concrete scroll exceeds actual range',
  );
  _position.jumpTo(target.clamp(0, _position.maxScrollExtent));
  await _settle();
}

String _captureName() =>
    'detail_${_kind}_scale_1${_position.pixels.abs() < .01 ? '' : '_scroll_${_position.pixels.toStringAsFixed(3).replaceAll('.', '_')}'}';

Map<String, Element> _roles() {
  final detail = _find<DetailScreen>();
  if (detail == null) return {};
  final item = _hostKey.currentState!.active;
  final list = _find<ListView>(detail)!;
  final out = <String, Element>{};
  void add(String role, Element? element) {
    if (element != null) out[role] = element;
  }

  add('title', _key('detail-title', detail) ?? _text(item.title, list));
  add('summary', _key('detail-summary', detail) ?? _text(item.summary, list));
  add('summaryHeading', _text('요약', list));
  add(
    'originalHeading',
    _text(item.isScreenshot ? '원본 이미지 보기' : '전문 보기', list),
  );
  add('tagHeading', _text('태그', list));
  add(
    'relatedHeading',
    _key('detail-related-heading', detail) ??
        _text('함께 보면 좋은 콘텐츠', list) ??
        _text('비슷한 태그를 가진 정보', list),
  );
  add('empty', _key('detail-related-empty', detail) ?? _text(_empty, list));
  add(
    'originalText',
    _key('detail-original-text', detail) ??
        _text(item.originalText, _find<FullContentPreview>(list)),
  );
  final date = _elements(list)
      .where(
        (e) =>
            e.widget is Text &&
            ((e.widget as Text).data ?? '').startsWith(item.savedAtFull),
      )
      .firstOrNull;
  add('date', _key('detail-saved-date', detail) ?? date);
  for (var i = 0; i < item.tags.length; i++) {
    add('tag$i', _text('#${item.tags[i]}', list));
  }
  final pager = _find<DetailPager>(detail);
  add('pager', pager == null ? null : _find<Text>(pager));
  return out;
}

Map<String, Object?> _paragraph(Element element) {
  final render = element.findRenderObject()! as RenderParagraph;
  final style = (render.text as TextSpan).style!;
  final bounds = _rect(element);
  final boxes = render.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: render.text.toPlainText().length,
    ),
  );
  final rows = <double>[];
  for (final box in boxes) {
    if (rows.every((top) => (top - box.top).abs() > .1)) rows.add(box.top);
  }
  return {
    'text': render.text.toPlainText(),
    'bounds': _box(bounds),
    'fontFamily': style.fontFamily,
    'fontSize': style.fontSize,
    'scaledFontSize': style.fontSize == null
        ? null
        : render.textScaler.scale(style.fontSize!),
    'fontWeight': style.fontWeight?.value,
    'color': _color(style.color),
    'letterSpacing': style.letterSpacing,
    'height': style.height,
    'declaredHeight': (element.widget as Text).style?.height,
    'maxLines': render.maxLines,
    'overflow': render.overflow.name,
    'textAlign': render.textAlign.name,
    'didExceedMaxLines': render.didExceedMaxLines,
    'constraintsMaxWidth': render.constraints.maxWidth.isFinite
        ? render.constraints.maxWidth
        : 'unbounded',
    'visibleLineCount': rows.length,
    'selectionBoxes': boxes
        .map((b) => _box(b.toRect().shift(render.localToGlobal(Offset.zero))))
        .toList(),
    'selectionBoxScope':
        'Diagnostic font selection extents, not glyph ink or clipping bounds. Intentional ellipsis is retained.',
  };
}

List<Element> _badges(Element root) {
  final names = _hostKey.currentState!.contents
      .expand((e) => e.categories)
      .map((c) => c.name)
      .toSet();
  return _elements(root)
      .where((e) => e.widget is Text && names.contains((e.widget as Text).data))
      .toList();
}

Map<String, Object?> _badgeParagraph(Element element) {
  final container = _ancestor(element, (w) => w is Container);
  final decoration = container == null
      ? null
      : (container.widget as Container).decoration;
  return {
    ..._paragraph(element),
    'background': decoration is BoxDecoration ? _color(decoration.color) : null,
  };
}

Map<String, Object?> _metrics() {
  final detail = _find<DetailScreen>();
  if (detail == null) return {};
  final roles = _roles();
  final list = _find<ListView>(detail)!;
  final viewport = _rect(list);
  final top = _find<DetailTopBar>(detail)!;
  final pager = _find<DetailPager>(detail)!;
  final nav = _find<ClipbackNavigationBar>(detail)!;
  final badgeRoot =
      _key('detail-category-badges', detail) ?? _find<CategoryBadge>(list);
  final badgeTexts = badgeRoot == null ? <Element>[] : _badges(badgeRoot);
  final scaffold = _find<Scaffold>(detail)!;
  final scaffoldWidget = scaffold.widget as Scaffold;
  final topBack = _icon(Assets.back, top)!;
  final cards = <Map<String, Object?>>[];
  for (final related in _hostKey.currentState!.contents.where(
    (e) =>
        e.id != _hostKey.currentState!.activeId &&
        e.category.name == _hostKey.currentState!.active.category.name,
  )) {
    final title = _text(related.title, list);
    final root =
        _key('detail-related-card-${related.id}', detail) ??
        (title == null
            ? null
            : _ancestor(title, (w) => w is RelatedContentTile));
    if (root == null || title == null) continue;
    final container = _elements(root)
        .where(
          (e) =>
              e.widget is Container &&
              (e.widget as Container).decoration is BoxDecoration,
        )
        .firstOrNull;
    final decoration = container == null
        ? null
        : (container.widget as Container).decoration as BoxDecoration;
    final foreground = container == null
        ? null
        : (container.widget as Container).foregroundDecoration
              as BoxDecoration?;
    final card = _rect(root);
    final badges = _badges(root);
    final badgeRects = badges
        .map((e) => _rect(_ancestor(e, (w) => w is Container)!))
        .toList();
    final lastBadgeBottom = badgeRects.isEmpty
        ? null
        : badgeRects.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
    final padding = container == null
        ? null
        : (container.widget as Container).padding?.resolve(
            Directionality.of(container),
          );
    cards.add({
      'id': related.id,
      'bounds': _box(card),
      'title': _paragraph(title),
      'badges': badges.map(_badgeParagraph).toList(),
      'badgeBounds': badgeRects.map(_box).toList(),
      'expectedCategoryCount': related.categories.length,
      'background': _color(decoration?.color),
      'borderIsFaint1':
          (foreground?.border ?? decoration?.border) ==
          Border.all(color: AppColors.faint),
      'radiusIs8':
          (foreground?.borderRadius ?? decoration?.borderRadius) ==
          BorderRadius.circular(8),
      'padding': padding == null
          ? null
          : {
              'left': padding.left,
              'right': padding.right,
              'top': padding.top,
              'bottom': padding.bottom,
            },
      'multiCategoryTitleBelowGap': lastBadgeBottom == null
          ? null
          : _rect(title).top - lastBadgeBottom,
      'badgeWrapSpacing': (_find<Wrap>(root)?.widget as Wrap?)?.spacing,
      'badgeWrapRunSpacing': (_find<Wrap>(root)?.widget as Wrap?)?.runSpacing,
      'singleCategoryInline':
          badgeRects.length == 1 &&
          (_rect(title).center.dy - badgeRects.single.center.dy).abs() < .15,
    });
  }
  final headerChildren = _elements(top)
      .where(
        (e) => e.widget is Container && (e.widget as Container).color != null,
      )
      .toList();
  return {
    'roles': roles.map((name, element) => MapEntry(name, _paragraph(element))),
    'layout': {
      'viewport': _box(viewport),
      'topBar': _box(_rect(top)),
      'pager': _box(_rect(pager)),
      'navigation': _box(_rect(nav)),
      'pagerNavigationGap': _rect(nav).top - _rect(pager).bottom,
      'pagerActions': _elements(pager)
          .where((e) => e.widget is RoundIconButton)
          .map(
            (e) => {
              'hit': _box(_rect(e)),
              'icon': _box(_rect(_find<SvgIcon>(e)!)),
              'asset': (_find<SvgIcon>(e)!.widget as SvgIcon).asset,
              'enabled': (e.widget as RoundIconButton).onPressed != null,
            },
          )
          .toList(),
      'background': _color(
        scaffoldWidget.backgroundColor ??
            Theme.of(scaffold).scaffoldBackgroundColor,
      ),
      'topBarColors': headerChildren
          .map((e) => _color((e.widget as Container).color))
          .toList(),
      'headerControlCenterFromTop': _rect(topBack).center.dy - _rect(top).top,
      'bodyBottomPadding': (list.widget as ListView).padding
          ?.resolve(Directionality.of(list))
          .bottom,
      'badgeGroup': badgeRoot == null ? null : _box(_rect(badgeRoot)),
      'badgeWrapSpacing': badgeRoot == null
          ? null
          : (_find<Wrap>(badgeRoot)?.widget as Wrap?)?.spacing,
      'badgeWrapRunSpacing': badgeRoot == null
          ? null
          : (_find<Wrap>(badgeRoot)?.widget as Wrap?)?.runSpacing,
      'badges': badgeTexts.map(_badgeParagraph).toList(),
      'icons': _elements(detail)
          .where((e) => e.widget is SvgIcon)
          .map(
            (e) => {
              'asset': (e.widget as SvgIcon).asset,
              'color': _color((e.widget as SvgIcon).color),
              'bounds': _box(_rect(e)),
            },
          )
          .toList(),
      'expectedMainCategoryCount':
          _hostKey.currentState!.active.categories.length,
      'relatedCards': cards,
      'tagsArePaintedChips': _find<TagChip>(list) != null,
      'tagGaps': [
        for (var i = 1; i < _hostKey.currentState!.active.tags.length; i++)
          if (roles['tag$i'] != null && roles['tag${i - 1}'] != null)
            _rect(roles['tag$i']!).left - _rect(roles['tag${i - 1}']!).right,
      ],
      'emptyExpected': _kind == 'empty',
      'emptyPresent': roles.containsKey('empty'),
      'relatedArrowPresent': roles['relatedHeading'] == null
          ? null
          : _elements(
              _ancestor(roles['relatedHeading']!, (w) => w is InkWell) ??
                  roles['relatedHeading'],
            ).any(
              (e) =>
                  e.widget is SvgIcon &&
                  (e.widget as SvgIcon).asset == Assets.chevronRight,
            ),
    },
    'mountedRoleCoverage': roles.keys.toList(),
    'originalTextScope':
        'Long fixed mock text. The production mapper and remote original/summary contract are unchanged.',
  };
}

List<String> _styleFindings(Map<String, Object?> metrics) {
  if (metrics.isEmpty) return [];
  final findings = <String>[];
  final roles = metrics['roles']! as Map<String, Map<String, Object?>>;
  final specs = <String, List<Object?>>{
    'title': [24, 700, -.6, '0xFF1A1A1A', 1.5, 'PretendardDetail'],
    'summary': [15, 400, -.375, '0xFF1A1A1A', 1.6, 'Pretendard'],
    'date': [14, 400, -.35, '0xFFB5BDC3', null, 'Pretendard'],
    'summaryHeading': [16, 600, -.4, '0xFF1A1A1A', null, 'Pretendard'],
    'originalHeading': [16, 600, -.4, '0xFF1A1A1A', null, 'Pretendard'],
    'relatedHeading': [16, 600, -.4, '0xFF1A1A1A', null, 'Pretendard'],
    'originalText': [16, 400, -.4, '0xFF1A1A1A', 1.6, 'Pretendard'],
    'tagHeading': [16, 500, -.4, '0xFF767676', 1.6, 'Pretendard'],
    'empty': [15, 600, -.375, '0xFF484848', null, 'Pretendard'],
    'pager': [16, 500, -.4, '0xFF767676', null, 'Pretendard'],
  };
  void check(String role, Map<String, Object?> actual, List<Object?> expected) {
    if (actual['fontSize'] != expected[0] ||
        actual['fontWeight'] != expected[1] ||
        actual['letterSpacing'] != expected[2] ||
        actual['color'] != expected[3] ||
        actual['fontFamily'] != expected[5] ||
        (expected[4] != null
            ? actual['height'] != expected[4]
            : actual['declaredHeight'] != null)) {
      findings.add(
        '$role actual font/weight/color/tracking/line height differs',
      );
    }
    if (actual['scaledFontSize'] != actual['fontSize']) {
      findings.add('$role must remain actual scale1');
    }
  }

  for (final entry in roles.entries) {
    final spec = entry.key.startsWith('tag') && entry.key != 'tagHeading'
        ? <Object?>[14, 500, -.35, '0xFF767676', 1.6, 'Pretendard']
        : specs[entry.key];
    if (spec != null) check(entry.key, entry.value, spec);
  }
  final layout = metrics['layout']! as Map<String, Object?>;
  for (final b in layout['badges']! as List) {
    final actual = b as Map<String, Object?>;
    final colors = _hostKey.currentState!.active.categories
        .where((c) => c.name == actual['text'])
        .toList();
    check('badge:${actual['text']}', actual, [
      12,
      500,
      -.3,
      _color(colors.first.deep),
      null,
      'Pretendard',
    ]);
    if (actual['background'] != _color(colors.first.tint)) {
      findings.add('Badge actual category background differs');
    }
  }
  if (layout['tagsArePaintedChips'] == true) {
    findings.add('Detail tags must be plain text rather than painted TagChip');
  }
  if (layout['relatedArrowPresent'] == true) {
    findings.add('Related heading must not paint a trailing arrow');
  }
  if (roles['relatedHeading'] case final Map<String, Object?> role) {
    if (role['text'] != '함께 보면 좋은 콘텐츠') {
      findings.add('Related heading copy differs');
    }
  }
  for (final card in layout['relatedCards']! as List) {
    check(
      'related title:${card['id']}',
      card['title'] as Map<String, Object?>,
      [14, 500, -.35, '0xFF000000', 1.5, 'Pretendard'],
    );
    if (card['background'] != '0xFFFFFFFF' ||
        card['borderIsFaint1'] != true ||
        card['radiusIs8'] != true) {
      findings.add('Related card ${card['id']} white/border/R8 differs');
    }
    final content = _hostKey.currentState!.contents.firstWhere(
      (c) => c.id == card['id'],
    );
    for (final badge in card['badges'] as List) {
      final actual = badge as Map<String, Object?>;
      final category = content.categories.firstWhere(
        (c) => c.name == actual['text'],
      );
      check('related badge:${actual['text']}', actual, [
        12,
        500,
        -.3,
        _color(category.deep),
        null,
        'Pretendard',
      ]);
      if (actual['background'] != _color(category.tint)) {
        findings.add('Related badge actual category background differs');
      }
    }
  }
  return findings;
}

List<String> _layoutFindings(Map<String, Object?> metrics) {
  if (metrics.isEmpty) return [];
  final findings = <String>[];
  final roles = metrics['roles']! as Map<String, Map<String, Object?>>;
  final layout = metrics['layout']! as Map<String, Object?>;
  final viewport = layout['viewport']! as Map<String, double>;
  final pager = layout['pager']! as Map<String, double>;
  final expanded = _expanded;
  if (!_near(layout['pagerNavigationGap'], expanded ? 8 : 16)) {
    findings.add('Pager/navigation gap must be 8 expanded / 16 collapsed');
  }
  final actions = layout['pagerActions']! as List;
  for (var i = 0; i < actions.length; i++) {
    final action = actions[i] as Map;
    final hit = action['hit'] as Map;
    final icon = action['icon'] as Map;
    final expectedAsset = i == 0
        ? 'assets/icons/detail-previous.svg'
        : 'assets/icons/detail-next.svg';
    if (action['asset'] != expectedAsset ||
        !_near(icon['width'], i == 0 ? 28 : 32) ||
        !_near(hit['width'], 56) ||
        !_near(hit['height'], 56)) {
      findings.add('Pager original asset/geometry $i differs');
    }
  }
  if (layout['background'] != '0xFFFFFFFF') {
    findings.add('Detail background must be white');
  }
  if (!_near((layout['topBar']! as Map)['height'], 64) ||
      !_near(layout['headerControlCenterFromTop'], 36)) {
    findings.add('Header must retain64 with8top+56content');
  }
  if (viewport['bottom']! > pager['top']! + .15) {
    findings.add('Detail body viewport overlaps pager');
  }
  for (final entry in roles.entries) {
    if (entry.key == 'pager') continue;
    final bounds = entry.value['bounds']! as Map<String, double>;
    if (bounds['left']! < viewport['left']! - .15 ||
        bounds['right']! > viewport['right']! + .15) {
      findings.add('${entry.key} paragraph exceeds body horizontal bounds');
    }
  }
  for (final role in ['title', 'summary']) {
    final actual = roles[role];
    if (actual != null &&
        (actual['maxLines'] != null || actual['didExceedMaxLines'] == true)) {
      findings.add('$role must preserve all actual lines');
    }
  }
  if (roles['date'] case final Map<String, Object?> date) {
    if (date['text'] != _hostKey.currentState!.active.savedAtFull) {
      findings.add('Saved date must use actual value without extra suffix');
    }
  }
  final badgeGroup = layout['badgeGroup'];
  if (badgeGroup != null &&
      (layout['badges']! as List).length !=
          layout['expectedMainCategoryCount']) {
    findings.add('Main badges must display every actual category');
  }
  if (badgeGroup != null &&
      (!_near(layout['badgeWrapSpacing'], 8) ||
          !_near(layout['badgeWrapRunSpacing'], 8))) {
    findings.add('Main category badges must retain natural Wrap8/8');
  }
  for (final gap in layout['tagGaps']! as List) {
    if (!_near(gap, 16)) findings.add('Detail tags must retain16px gaps');
  }
  if (_kind == 'empty' &&
      roles.containsKey('relatedHeading') &&
      layout['emptyPresent'] != true) {
    findings.add('Loaded related-empty message missing');
  }
  if (roles['empty'] case final Map<String, Object?> empty) {
    final bounds = empty['bounds']! as Map<String, double>;
    if (empty['textAlign'] != 'center' ||
        !_near(
          (bounds['left']! + bounds['right']!) / 2,
          (viewport['left']! + viewport['right']!) / 2,
        )) {
      findings.add('Related empty text must be centered');
    }
  }
  for (final card in layout['relatedCards']! as List) {
    final bounds = card['bounds'] as Map<String, double>;
    if (bounds['height']! < 47.85) {
      findings.add('Related card minimum48 is lost');
    }
    final padding = card['padding'];
    if (padding is! Map || padding.values.any((v) => !_near(v, 8))) {
      findings.add('Related card ${card['id']} padding8 differs');
    }
    if ((card['badges']! as List).length != card['expectedCategoryCount']) {
      findings.add('Related card ${card['id']} loses categories');
    }
    if (card['expectedCategoryCount'] == 1
        ? card['singleCategoryInline'] != true
        : !_near(card['multiCategoryTitleBelowGap'], 8)) {
      findings.add(
        'Related card ${card['id']} badge/title arrangement differs',
      );
    }
    if ((card['expectedCategoryCount'] as int) > 1 &&
        (!_near(card['badgeWrapSpacing'], 8) ||
            !_near(card['badgeWrapRunSpacing'], 8))) {
      findings.add('Multi-category related badges must retain Wrap8/8');
    }
    final title = card['title'] as Map<String, Object?>;
    if (title['maxLines'] != 1 || title['overflow'] != 'ellipsis') {
      findings.add('Related card title must keep one-line ellipsis');
    }
  }
  return findings;
}

Map<String, Object?> _snapshot() {
  final host = _hostKey.currentState!;
  final context = _find<DetailScreen>() ?? _navKey.currentContext!;
  final media = MediaQuery.of(context);
  final metrics = _metrics();
  final styles = _styleFindings(metrics);
  final layout = _layoutFindings(metrics);
  final view = View.of(_captureKey.currentContext!);
  final detail = _find<DetailScreen>();
  final viewport = detail == null ? null : _rect(_find<ListView>(detail)!);
  final visible = viewport == null
      ? <Map<String, Object?>>[]
      : _elements(detail)
            .where(
              (e) =>
                  e.widget is Text && e.findRenderObject() is RenderParagraph,
            )
            .where((e) => _rect(e).overlaps(viewport))
            .map(
              (e) => {
                'text': (e.widget as Text).data,
                'bounds': _box(_rect(e)),
                'fullyInsideViewport':
                    viewport.contains(_rect(e).topLeft) &&
                    viewport.contains(_rect(e).bottomRight),
              },
            )
            .toList();
  return {
    'phase': _phase,
    'platform': Platform.operatingSystem,
    'ready': true,
    'busy': _busy,
    'scene': _scene,
    'kind': _kind,
    'output': _output.path,
    'route': host.route.name,
    'activeContentId': host.activeId,
    'bookmarked': host.bookmarks.contains(host.activeId),
    'categories': host.active.categories
        .map((c) => {'id': c.id, 'name': c.name})
        .toList(),
    'loadedContentIds': host.contents.map((c) => c.id).toList(),
    'originalExpanded': detail == null ? false : _expanded,
    'textScale': media.textScaler.scale(1),
    'logicalSize': '${view.physicalSize / view.devicePixelRatio}',
    'pixelRatio': view.devicePixelRatio,
    'viewPaddingTop': media.viewPadding.top,
    'viewPaddingBottom': media.viewPadding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'scrollOffset': detail == null ? null : _position.pixels,
    'maxScrollExtent': detail == null ? null : _position.maxScrollExtent,
    'scrollPlan': {
      'expandedBeforeMaximum': _beforeExpandedMaximum,
      'expandedBeforeHalf': _beforeExpandedHalf,
      'measuredInPhase': _phase,
      'measurementScope':
          'Legacy before-named fields measure this build phase; external BEFORE concrete offsets must be explicitly supplied to AFTER.',
    },
    'metrics': metrics,
    'wholeVisibleContent': visible,
    'styleFindings': styles,
    'stylePassed': styles.isEmpty,
    'layoutFindings': layout,
    'layoutPassed': layout.isEmpty,
    'frameworkErrors': List.of(_errors),
    'hostCalls': List.of(host.calls),
    'mockScope':
        'Real DetailScreen with deterministic in-memory data/callbacks and synthetic pointer input. Long originalText is fixture data, not a production mapper/API/provider/physical-device result.',
  };
}

Future<void> _capture(String name) async {
  await _settle();
  _scene = name;
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(
    pixelRatio: View.of(_captureKey.currentContext!).devicePixelRatio,
  );
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${_output.path}/$name.png').writeAsBytes(
      png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _checks.add({'capture': name, ..._snapshot()});
}

void _record(String scenario) {
  _checks.add({'scenario': scenario, 'passed': true, ..._snapshot()});
}

Future<void> _report() => File('${_output.path}/report.json').writeAsString(
  const JsonEncoder.withIndent('  ').convert({
    ..._snapshot(),
    'checksCompleted': _complete,
    'coveragePassed': _coveragePassed,
    'behaviorPassed': _complete && !_checks.any((c) => c['passed'] == false),
    'stylePassed': !_checks.any((c) => c['stylePassed'] == false),
    'layoutPassed':
        _errors.isEmpty && !_checks.any((c) => c['layoutPassed'] == false),
    'passed':
        _complete &&
        _coveragePassed &&
        _errors.isEmpty &&
        !_checks.any(
          (c) =>
              c['passed'] == false ||
              c['stylePassed'] == false ||
              c['layoutPassed'] == false,
        ),
    'checks': _checks,
    'allHostCalls': _events,
    'scope':
        'Style/layout findings diagnose BEFORE target differences without stopping captures. AFTER overall success requires all recorded style/layout/behavior flags, required union role/category/card-order coverage, and zero framework errors. Lazy offscreen roles are inspected at scroll0/intermediate/maximum; partial viewport visibility is not paragraph clipping. Photo sharing verifies a deterministic local callback cache, not an HTTP GET.',
  }),
);

Map<String, Object?> _requiredCoverage(List<Map<String, Object?>> records) {
  const common = {
    'title',
    'summary',
    'date',
    'summaryHeading',
    'originalHeading',
    'tagHeading',
    'tag0',
    'tag1',
    'tag2',
    'relatedHeading',
    'pager',
  };
  const cardOrder = ['related-one', 'related-many'];
  final byKind = <String, Object?>{};
  final failures = <String>[];
  for (final kind in ['basic', 'expanded', 'empty']) {
    final roles = <String>{};
    final badgeNames = <String>{};
    final cards = <String>{};
    final orders = <Map<String, Object?>>[];
    final matching = records.where(
      (record) => record['kind'] == kind && record['activeContentId'] == 'main',
    );
    for (final record in matching) {
      final metrics = record['metrics'] as Map;
      roles.addAll((metrics['roles'] as Map).keys.cast<String>());
      final layout = metrics['layout'] as Map;
      for (final badge in layout['badges'] as List) {
        badgeNames.add((badge as Map)['text'] as String);
      }
      final mounted = (layout['relatedCards'] as List).cast<Map>();
      cards.addAll(mounted.map((card) => card['id'] as String));
      if (cardOrder.every((id) => mounted.any((card) => card['id'] == id))) {
        final actual =
            mounted.where((card) => cardOrder.contains(card['id'])).toList()
              ..sort(
                (a, b) => ((a['bounds'] as Map)['top'] as num).compareTo(
                  (b['bounds'] as Map)['top'] as num,
                ),
              );
        orders.add({
          'scrollOffset': record['scrollOffset'],
          'idsByActualTop': actual.map((card) => card['id']).toList(),
          'actualTops': actual
              .map((card) => (card['bounds'] as Map)['top'])
              .toList(),
          'matchesLoadedOrder':
              actual[0]['id'] == cardOrder[0] &&
              actual[1]['id'] == cardOrder[1] &&
              ((actual[0]['bounds'] as Map)['top'] as num) <
                  ((actual[1]['bounds'] as Map)['top'] as num),
        });
      }
    }
    final expectedRoles = {
      ...common,
      if (kind == 'expanded') 'originalText',
      if (kind == 'empty') 'empty',
    };
    final missingRoles = expectedRoles.difference(roles).toList()..sort();
    final missingBadges = {
      _cat.name,
      _second.name,
    }.difference(badgeNames).toList()..sort();
    final missingCards = kind == 'empty'
        ? <String>[]
        : cardOrder.where((id) => !cards.contains(id)).toList();
    final orderPassed =
        kind == 'empty' ||
        (orders.isNotEmpty &&
            orders.every((order) => order['matchesLoadedOrder'] == true));
    if (matching.isEmpty ||
        missingRoles.isNotEmpty ||
        missingBadges.isNotEmpty ||
        missingCards.isNotEmpty ||
        !orderPassed) {
      failures.add(
        '$kind missing roles=$missingRoles badges=$missingBadges cards=$missingCards or card order=$orderPassed',
      );
    }
    byKind[kind] = {
      'activeContentId': 'main',
      'recordCount': matching.length,
      'roles': roles.toList()..sort(),
      'missingRoles': missingRoles,
      'mainBadgeNames': badgeNames.toList()..sort(),
      'missingMainBadges': missingBadges,
      'relatedCardIds': cards.toList()..sort(),
      'missingRelatedCards': missingCards,
      'actualCardOrderObservations': orders,
      'cardOrderPassed': orderPassed,
    };
  }
  return {
    'passed': failures.isEmpty,
    'findings': failures,
    'states': byKind,
    'scope':
        'Union of main-content records at scroll0/half/maximum. Missing lazy-mounted roles, actual category names, either related card, or measured card order fail coverage. Individual offscreen snapshots do not require every role.',
  };
}

Future<void> _run(double? referenceOffset) async {
  _complete = false;
  _coveragePassed = false;
  final coverageStart = _checks.length;
  for (final kind in ['basic', 'expanded', 'empty']) {
    await _open(kind);
    await _capture(_captureName());
    if (kind == 'expanded') {
      final half = referenceOffset ?? _position.maxScrollExtent / 2;
      await _setScroll('$half');
      await _capture(_captureName());
    }
    await _setScroll('max');
    _record('${kind}_maximum_scroll');
  }
  final coverage = _requiredCoverage(_checks.sublist(coverageStart));
  _coveragePassed = coverage['passed'] == true;
  _checks.add({
    'scenario': 'required_role_coverage',
    'passed': _coveragePassed,
    'coveragePassed': _coveragePassed,
    'coverage': coverage,
  });
  _require(
    _coveragePassed,
    'Required detail coverage: ${coverage['findings']}',
  );
  await _open('basic');
  await _toggleOriginal();
  _require(_expanded, 'Original did not expand');
  _record('original_expanded');
  _position.jumpTo(0);
  await _settle();
  await _toggleOriginal();
  _require(!_expanded, 'Original did not collapse');
  _record('original_collapsed');
  final host = _hostKey.currentState!;
  _position.jumpTo(0);
  await _settle();
  await _tap(_key('detail-original-button', _find<DetailScreen>())!);
  _require(
    _find<OriginalContentSheet>() == null &&
        host.calls.where((c) => c['action'] == 'openOriginalLink').length == 1,
    'Original link action must call the host without opening a legacy sheet',
  );
  _record('original_link_callback_without_legacy_sheet');
  await _tap(_find<BookmarkActionButton>(_find<DetailTopBar>())!);
  _require(
    host.bookmarks.contains('main') &&
        host.calls.any((c) => c['action'] == 'bookmark'),
    'Bookmark host state did not change',
  );
  _record('bookmark_state_changed');
  await _tap(_icon(Assets.more, _find<DetailTopBar>())!);
  await _tapText('카테고리 변경');
  final tile = _elements(_find<CategoryChangeSheet>()).firstWhere(
    (e) =>
        e.widget is CategoryChangeTile &&
        (e.widget as CategoryChangeTile).category.id == _second.id,
  );
  await _tap(tile);
  _require(
    host.active.category.id == _second.id &&
        host.calls.any((c) => c['action'] == 'category'),
    'Category host data did not change',
  );
  _record('category_changed');
  await _open('basic');
  await _setScroll('max');
  final related = _text('함께 보면 좋은 콘텐츠') ?? _text('비슷한 태그를 가진 정보');
  _require(related != null, 'Related heading missing');
  await _tap(related!);
  await _settle(8);
  _record('related_heading_scroll');
  final relatedTile = _text('한 가지 카테고리로 다시 보는 콘텐츠');
  _require(relatedTile != null, 'Related item missing');
  await _tap(relatedTile!);
  _require(
    host.activeId == 'related-one' &&
        host.calls.any((c) => c['action'] == 'related'),
    'Related destination did not change',
  );
  _record('related_content_opened');
  await _open('basic');
  var pager = _find<DetailPager>()!;
  var buttons = _elements(
    pager,
  ).where((e) => e.widget is RoundIconButton).toList();
  await _tap(buttons.last);
  _require(host.activeId == 'related-one', 'Next content did not change');
  pager = _find<DetailPager>()!;
  buttons = _elements(pager).where((e) => e.widget is RoundIconButton).toList();
  await _tap(buttons.first);
  _require(host.activeId == 'main', 'Previous content did not restore');
  _record('previous_next_active_content');
  await _tap(_find<NavAddButton>()!);
  _require(_find<AddContentSheet>() != null, 'Save entry missing');
  await _tap(_find<IconButton>(_find<SaveContentTopBar>())!);
  _require(
    _find<AddContentSheet>() == null &&
        !host.calls.any(
          (c) => c['action'] == 'saveLink' || c['action'] == 'savePhoto',
        ),
    'Save entry close submitted unexpectedly',
  );
  _record('save_entry_closed');
  await _open('basic', photo: true);
  await _toggleOriginal();
  for (
    var i = 0;
    i < 30 &&
        _elements()
            .where(
              (e) =>
                  e.widget is Image && (e.widget as Image).image is MemoryImage,
            )
            .isEmpty;
    i++
  ) {
    await _settle(2);
  }
  final image = _elements()
      .where(
        (e) => e.widget is Image && (e.widget as Image).image is MemoryImage,
      )
      .firstOrNull;
  _require(
    image != null &&
        identical(((image.widget as Image).image as MemoryImage).bytes, _photo),
    'Original photo bytes changed',
  );
  _require(
    host.calls.where((c) => c['action'] == 'readAsset').length == 1,
    'Original photo loaded more than once',
  );
  _record('photo_original_bytes_preserved');
  _position.jumpTo(0);
  await _settle();
  await _tap(_icon(Assets.link, _find<DetailScreen>())!);
  final photoSheet = _find<OriginalContentSheet>();
  _require(photoSheet != null, 'Original photo sheet missing');
  final sheetImage = _elements(photoSheet)
      .where(
        (e) => e.widget is Image && (e.widget as Image).image is MemoryImage,
      )
      .firstOrNull;
  _require(
    sheetImage != null &&
        identical(
          ((sheetImage.widget as Image).image as MemoryImage).bytes,
          _photo,
        ) &&
        (sheetImage.widget as Image).fit == BoxFit.contain &&
        host.calls.where((c) => c['action'] == 'readAsset').length == 1,
    'Original photo sheet must share one local read callback and contain identical bytes',
  );
  await _tapText('확인');
  _require(
    _find<OriginalContentSheet>() == null,
    'Original photo sheet did not close',
  );
  _record('photo_original_sheet_local_cache_shared');
  for (final label in ['홈', '아카이브', '즐겨찾기', '마이']) {
    await _open('basic');
    await _tapText(label);
    _require(
      host.route != AppRoute.detail &&
          host.calls.any((c) => c['action'] == 'tab'),
      'Tab callback did not change host route',
    );
    _record('tab_$label');
  }
  await _open('basic');
  await _tap(_icon(Assets.back, _find<DetailTopBar>())!);
  _require(
    host.route == AppRoute.archive &&
        host.calls.any((c) => c['action'] == 'back'),
    'Back destination did not change',
  );
  _record('back_destination');
  _complete = true;
}
