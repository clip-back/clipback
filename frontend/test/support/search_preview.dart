// Independent H01/H02/H03 actual-app fixture. Memory-only HTTP/session/share
// doubles; no external server, OAuth, persistence or physical-device proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/content_actions.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/paged_content_list.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'archive_all_preview.dart' as e01;
import 'package:clipback_frontend/shared/category/category_sheets.dart';

const searchPhase = String.fromEnvironment(
  'SEARCH_PHASE',
  defaultValue: 'before',
);
const searchQuery = '기억';
const searchEmptyQuery = '존재하지않는검색어';
const searchIds = [
  'api-701',
  'api-702',
  'api-703',
  'api-704',
  'api-705',
  'api-706',
  'api-707',
  'api-708',
];
List<Map<String, Object?>> searchCategoryMaps() => [
  for (final c in e01.archiveAllCategoryMaps) Map<String, Object?>.from(c),
];
List<Map<String, Object?>> searchRecords() {
  final base = e01.archiveAllRecords();
  return [
    for (var i = 0; i < 8; i++)
      {
        ...Map<String, Object?>.from(
          jsonDecode(jsonEncode(base[i % base.length])) as Map,
        ),
        'id': 701 + i,
        'title': '기억 ${i + 1} · ${base[i % base.length]['title']}',
        'summary':
            '올영세일 여름 쇼핑몰 부산 맛집 금리 도쿄역 — 기억할 정보를 원래 순서와 실제 분류를 보존해 확인합니다. ${base[i % base.length]['summary']}',
        'is_favorite': i == 1,
        'saved_at': '2026-10-${17 - i}T12:00:00Z',
        'original_url': 'https://example.invalid/search/${701 + i}',
      },
    {
      ...Map<String, Object?>.from(jsonDecode(jsonEncode(base.first)) as Map),
      'id': 900,
      'title': '검색과 무관한 일반 콘텐츠',
      'summary': '검색 결과0개와 전체 저장0개를 구분합니다.',
      'is_favorite': false,
      'original_url': 'https://example.invalid/search/ordinary/900',
    },
  ];
}

Object? _freeze(Object? value) {
  if (value is double && !value.isFinite) return value.toString();
  if (value is Map) {
    return {for (final e in value.entries) e.key.toString(): _freeze(e.value)};
  }
  if (value is Iterable) return value.map(_freeze).toList(growable: false);
  return value;
}

Map<String, Object?> _copy(Map<String, Object?> v) =>
    Map<String, Object?>.from(_freeze(v)! as Map);

class SearchServer {
  final records = searchRecords();
  final requests = <Map<String, Object?>>[], unexpected = <String>[];
  final heldQueries = <String, List<Completer<void>>>{};
  String? failNextQuery;
  bool failNextFavorite = false,
      failNextCategory = false,
      failNextDelete = false;
  int favoriteAttempts = 0, categoryAttempts = 0, deleteAttempts = 0;
  int favoriteSuccesses = 0, categorySuccesses = 0, deleteSuccesses = 0;
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  List<Map<String, Object?>> matching(Map<String, String> q) =>
      records.where((r) {
        if (q['is_favorite'] != null &&
            r['is_favorite'] != (q['is_favorite'] == 'true')) {
          return false;
        }
        if (q['category_id'] != null &&
            !(r['categories'] as List).any(
              (c) => (c as Map)['id'].toString() == q['category_id'],
            )) {
          return false;
        }
        final query = (q['q'] ?? '').toLowerCase();
        if (query == '지연a') {
          return (r['id'] as int) >= 701 && (r['id'] as int) <= 704;
        }
        if (query == '지연b') {
          return (r['id'] as int) >= 705 && (r['id'] as int) <= 708;
        }
        if (query == '실패재시도') return r['id'] != 900;
        return '${r['title']} ${r['summary']}'.toLowerCase().contains(query);
      }).toList();
  late final client = MockClient((request) async {
    final path = request.url.path, q = request.url.queryParameters;
    final call = <String, Object?>{
      'method': request.method,
      'path': path,
      'query': Map<String, String>.from(q),
    };
    requests.add(call);
    if (path == '/api/v1/auth/refresh' || path == '/api/v1/auth/guest') {
      return json({
        'access_token': 'fixture-access',
        'refresh_token': 'fixture-refresh',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
      }, 201);
    }
    if (path == '/api/v1/users/me') {
      return json({
        'id': 1,
        'email': null,
        'display_name': '검색 화면 검증',
        'is_guest': true,
        'created_at': '2026-10-17T00:00:00Z',
        'linked_providers': <String>[],
      });
    }
    if (path == '/api/v1/users/me/stats') {
      return json({'saved_count': 999, 'reopened_count': 0});
    }
    if (path == '/api/v1/categories') return json(searchCategoryMaps());
    if (path == '/api/v1/feed') {
      final query = q['q'], filtered = matching(q), cursor = q['cursor'];
      final start = cursor == null
          ? 0
          : int.parse(cursor.substring(cursor.lastIndexOf('-') + 1));
      final page = filtered.skip(start).take(4).map((r) => _copy(r)).toList(),
          more = start + 4 < filtered.length;
      final next = more ? 'search-page-${start + 4}' : null;
      call.addAll({
        'returnedIds': page.map((r) => r['id']).toList(),
        'matchingCount': filtered.length,
        'nextCursor': next,
      });
      final holds = heldQueries[query];
      if (holds != null && holds.isNotEmpty) {
        final h = holds.removeAt(0);
        call['held'] = true;
        await h.future;
        call['released'] = true;
      }
      if (query != null && failNextQuery == query) {
        failNextQuery = null;
        call['injectedFailure'] = true;
        return json({'detail': 'Fixture query failed'}, 503);
      }
      return json({'items': page, 'next_cursor': next});
    }
    if (path == '/api/v1/metrics/events' || path.endsWith('/view')) {
      return json({}, 201);
    }
    if (path == '/api/v1/auth/share-credential') {
      return json({
        'share_token': 'fixture-share',
        'expires_at': '2030-10-17T00:00:00Z',
        'user_id': 1,
        'session_id': 1,
      });
    }
    if (path == '/api/v1/auth/logout') return http.Response('', 204);
    final m = RegExp(
      r'^/api/v1/contents/(\d+)(/favorite|/categories)?$',
    ).firstMatch(path);
    if (m != null) {
      final i = records.indexWhere((r) => r['id'] == int.parse(m[1]!));
      if (i < 0) return json({'detail': 'Unknown fixture content'}, 404);
      if (request.method == 'DELETE') {
        deleteAttempts++;
        if (failNextDelete) {
          failNextDelete = false;
          call['injectedFailure'] = true;
          return json({'detail': 'Fixture delete failed'}, 503);
        }
        deleteSuccesses++;
        records.removeAt(i);
        return http.Response('', 204);
      }
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map;
        if (m[2] == '/favorite') {
          favoriteAttempts++;
          call['isFavorite'] = body['is_favorite'];
          if (failNextFavorite) {
            failNextFavorite = false;
            call['injectedFailure'] = true;
            return json({'detail': 'Fixture favorite failed'}, 503);
          }
          favoriteSuccesses++;
          records[i] = {...records[i], 'is_favorite': body['is_favorite']};
        } else if (m[2] == '/categories') {
          categoryAttempts++;
          call['categoryIds'] = body['category_ids'];
          if (failNextCategory) {
            failNextCategory = false;
            call['injectedFailure'] = true;
            return json({'detail': 'Fixture category failed'}, 503);
          }
          categorySuccesses++;
          records[i] = {
            ...records[i],
            'categories': [
              for (final id in body['category_ids'] as List)
                searchCategoryMaps().firstWhere((c) => c['id'] == id),
            ],
          };
        }
      }
      return json(records[i]);
    }
    unexpected.add('${request.method} $path');
    return json({'detail': 'Unsupported memory fixture request'}, 501);
  });
}

List<Element> _elements(Element root) => e01.archiveAllElements(root);
Element? _find<T extends Widget>(Element root) => e01.archiveAllFind<T>(root);
Element? _key(Element root, String key) => e01.archiveAllKey(root, key);
Element? _text(Element root, String text) => e01.archiveAllText(root, text);
Rect _box(Element e) => e01.archiveAllRect(e);
Map<String, double> _rect(Rect r) => {
  'left': r.left,
  'top': r.top,
  'right': r.right,
  'bottom': r.bottom,
  'width': r.width,
  'height': r.height,
};
String? _color(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
Element? _ancestor(Element child, bool Function(Widget) test) {
  Element? result;
  child.visitAncestorElements((e) {
    if (test(e.widget)) {
      result = e;
      return false;
    }
    return true;
  });
  return result;
}

Map<String, Object?> _paragraph(Element e) {
  final p = e.findRenderObject()! as RenderParagraph,
      s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': _rect(_box(e)),
    'fontFamily': s.fontFamily,
    'fontSize': s.fontSize,
    'scaledFontSize': s.fontSize == null
        ? null
        : p.textScaler.scale(s.fontSize!),
    'fontWeight': s.fontWeight?.value,
    'letterSpacing': s.letterSpacing,
    'height': s.height,
    'color': _color(s.color),
    'maxLines': p.maxLines,
    'overflow': p.overflow.name,
    'didExceedMaxLines': p.didExceedMaxLines,
    'constraintsMaxWidth': p.constraints.maxWidth.isFinite
        ? p.constraints.maxWidth
        : 'unbounded',
    'scope':
        'Actual paragraph layout bounds; not glyph ink or selection-box overhang.',
  };
}

Map<String, Object?> _asset(Element? root) {
  if (root == null) return {};
  final svg = root.widget is SvgPicture ? root : _find<SvgPicture>(root);
  if (svg != null) {
    final w = svg.widget as SvgPicture, loader = w.bytesLoader;
    return {
      'bounds': _rect(_box(svg)),
      'asset': loader is SvgAssetLoader ? loader.assetName : null,
      'unfiltered': w.colorFilter == null,
      'colorFilter': w.colorFilter.toString(),
    };
  }
  final image =
      _key(root, 'search-empty-image-source') ??
      (root.widget is Image ? root : _find<Image>(root));
  if (image != null) {
    final w = image.widget as Image;
    ImageProvider provider = w.image;
    if (provider is ResizeImage) provider = provider.imageProvider;
    return {
      'bounds': _rect(_box(image)),
      'asset': provider is AssetImage
          ? provider.assetName
          : provider is ExactAssetImage
          ? provider.assetName
          : null,
      'fit': w.fit?.name,
      'alignment': w.alignment.toString(),
      'imageProvider': provider.runtimeType.toString(),
    };
  }
  return {'bounds': _rect(_box(root)), 'asset': null};
}

Map<String, Object?> _surface(Element root) {
  Element? owner;
  BoxDecoration? background, foreground;
  Color? fill;
  for (final e in [root, ..._elements(root).skip(1)]) {
    final w = e.widget;
    if (w is Container &&
        (w.decoration is BoxDecoration ||
            w.foregroundDecoration is BoxDecoration)) {
      owner = e;
      background = w.decoration is BoxDecoration
          ? w.decoration as BoxDecoration
          : null;
      foreground = w.foregroundDecoration is BoxDecoration
          ? w.foregroundDecoration as BoxDecoration
          : null;
      fill = foreground?.color ?? background?.color ?? w.color;
      break;
    }
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      owner = e;
      background = w.decoration as BoxDecoration;
      fill = background.color;
      break;
    }
  }
  final bd = foreground?.border ?? background?.border;
  final br = foreground?.borderRadius ?? background?.borderRadius;
  final border = bd is Border ? bd : null,
      radius = br is BorderRadius ? br : null;
  return {
    'bounds': _rect(_box(owner ?? root)),
    'fill': _color(fill),
    'borderColor': _color(border?.top.color),
    'borderWidth': border?.top.width,
    'radius': radius?.topLeft.x,
    'foregroundBorder': foreground?.border != null,
  };
}

ScrollPosition? _position(Element root) {
  final scope = _find<PagedContentList>(root);
  if (scope == null) return null;
  final e = _elements(scope)
      .where(
        (e) =>
            e.widget is Scrollable &&
            ((e as StatefulElement).state as ScrollableState).position.axis ==
                Axis.vertical,
      )
      .firstOrNull;
  return e == null
      ? null
      : ((e as StatefulElement).state as ScrollableState).position;
}

Element? _svgNamed(Element root, String asset) => _elements(root)
    .where(
      (e) =>
          e.widget is SvgIcon && (e.widget as SvgIcon).asset == asset ||
          e.widget is SvgIconButton &&
              (e.widget as SvgIconButton).asset == asset,
    )
    .firstOrNull;
Element? _outerHeader(Element screen) =>
    _key(screen, 'search-header') ??
    _elements(screen)
        .where(
          (e) => e.widget is SizedBox && (e.widget as SizedBox).height == 64,
        )
        .firstOrNull;
Map<String, Object?> _editableMetrics(Element element) {
  final w = element.widget as EditableText,
      r = (element as StatefulElement).state is EditableTextState
          ? ((element).state as EditableTextState).renderEditable
          : throw StateError('EditableTextState absent'),
      s = w.style;
  return {
    'text': w.controller.text,
    'selectionBase': w.controller.selection.baseOffset,
    'selectionExtent': w.controller.selection.extentOffset,
    'focused': w.focusNode.hasFocus,
    'bounds': _rect(r.localToGlobal(Offset.zero) & r.size),
    'fontFamily': s.fontFamily,
    'fontSize': s.fontSize,
    'scaledFontSize': s.fontSize == null
        ? null
        : r.textScaler.scale(s.fontSize!),
    'fontWeight': s.fontWeight?.value,
    'letterSpacing': s.letterSpacing,
    'height': s.height,
    'color': _color(s.color),
    'maxLines': w.maxLines,
  };
}

Map<String, Object?> searchMeasure(Element root) {
  final screen = _find<SearchScreen>(root);
  if (screen == null) return {'active': false};
  final sw = screen.widget as SearchScreen,
      media = MediaQuery.of(screen),
      styles = <String, Object?>{},
      bounds = <String, Object?>{},
      assets = <String, Object?>{},
      rows = <Map<String, Object?>>[],
      history = <Map<String, Object?>>[];
  final header = _outerHeader(screen)!,
      field = _find<TextField>(screen)!,
      editable = _find<EditableText>(field)!,
      input =
          _key(screen, 'search-input-box') ??
          _ancestor(field, (w) => w is Container)!,
      cancel = _key(screen, 'search-cancel') ?? _text(screen, '취소')!;
  final inputIcon =
          _key(screen, 'search-input-icon') ?? _svgNamed(input, Assets.search),
      clear = _key(screen, 'search-clear') ?? _svgNamed(input, Assets.close);
  final hint = _text(field, '찾고 싶은 정보를 검색해보세요');
  bounds['header'] = _rect(_box(header));
  bounds['inputBox'] = _rect(_box(input));
  bounds['inputSurface'] = _surface(input);
  bounds['cancelHit'] = _rect(
    _box(_ancestor(cancel, (w) => w is TextButton) ?? cancel),
  );
  styles['input'] = _editableMetrics(editable);
  styles['cancel'] = _paragraph(
    cancel.widget is Text ? cancel : _find<Text>(cancel)!,
  );
  if (hint != null) styles['hint'] = _paragraph(hint);
  assets['inputIcon'] = _asset(inputIcon);
  if (clear != null) {
    assets['clear'] = _asset(clear);
    bounds['clearHit'] = _rect(_box(clear));
  }
  final historyTitle =
      _key(screen, 'search-history-title') ?? _text(screen, '최근 검색어');
  if (historyTitle != null) styles['historyTitle'] = _paragraph(historyTitle);
  for (final e in _elements(
    screen,
  ).where((e) => e.widget is SearchHistoryRow)) {
    final w = e.widget as SearchHistoryRow,
        t = _text(e, w.term)!,
        clock =
            _key(e, 'search-history-clock-${w.term}') ??
            _svgNamed(e, Assets.clock),
        remove =
            _key(e, 'search-history-remove-${w.term}') ??
            _svgNamed(e, Assets.close);
    history.add({
      'term': w.term,
      'bounds': _rect(_box(e)),
      'style': _paragraph(t),
      'clock': _asset(clock),
      'remove': _asset(remove),
    });
  }
  final list = _find<PagedContentList>(screen),
      emptyWidget =
          _key(screen, 'search-empty-group') ??
          _find<EmptySearchResult>(screen);
  Element? viewport =
      _key(
        screen,
        emptyWidget != null
            ? 'search-empty-viewport'
            : 'search-results-viewport',
      ) ??
      list;
  if (viewport == null && historyTitle != null) {
    viewport = _ancestor(historyTitle, (w) => w is Scrollable);
  }
  if (viewport != null) bounds['viewport'] = _rect(_box(viewport));
  if (emptyWidget != null) {
    final title =
            _key(screen, 'search-empty-title') ??
            _text(emptyWidget, '검색 결과가 없어요'),
        body =
            _key(screen, 'search-empty-body') ??
            _text(emptyWidget, '핵심 키워드 위주로 검색해 주세요'),
        group =
            _key(screen, 'search-empty-group') ?? _find<Column>(emptyWidget),
        image = _key(screen, 'search-empty-image') ?? _find<Image>(emptyWidget),
        cta =
            _key(screen, 'search-empty-cta') ??
            _find<OutlinedButton>(emptyWidget);
    if (title != null) styles['emptyTitle'] = _paragraph(title);
    if (body != null) styles['emptyBody'] = _paragraph(body);
    if (cta != null) {
      final t = _text(cta, '전체 리스트 보기');
      if (t != null) styles['emptyCta'] = _paragraph(t);
      bounds['emptyCta'] = _rect(_box(cta));
      bounds['emptyCtaSurface'] = _surface(cta);
      assets['emptyCtaIcon'] = _asset(
        _key(screen, 'search-empty-cta-icon') ?? _svgNamed(cta, Assets.archive),
      );
    }
    if (group != null) bounds['emptyGroup'] = _rect(_box(group));
    if (image != null) {
      bounds['emptyImageSlot'] = _rect(_box(image));
      assets['emptyImage'] = _asset(image);
    }
  }
  for (final card in _elements(
    screen,
  ).where((e) => e.widget is ContentListCard)) {
    final c = (card.widget as ContentListCard).content;
    final outer = _key(card, 'archive-all-card-${c.id}') ?? card;
    final wrap = _key(card, 'archive-all-badges-${c.id}');
    final title =
        _key(card, 'archive-all-title-${c.id}') ?? _text(card, c.title)!;
    final summary =
        _key(card, 'archive-all-summary-${c.id}') ?? _text(card, c.summary)!;
    final date =
        _key(card, 'archive-all-date-${c.id}') ?? _text(card, c.savedAt)!;
    final divider =
        _key(card, 'archive-all-divider-${c.id}') ?? _find<Divider>(card)!;
    final bookmark =
        _key(card, 'list-bookmark-${c.title}') ??
        _find<BookmarkActionButton>(card)!;
    final more =
        _key(card, 'archive-all-more-${c.id}') ??
        _elements(card).where((e) => e.widget is SvgIconButton).last;
    final badgeElements = wrap == null
        ? [_find<CategoryBadge>(card)!]
        : _elements(wrap).where((e) => e.widget is Text).toList();
    final badges = <Map<String, Object?>>[];
    for (final e in badgeElements) {
      final text = e.widget is Text ? e : _find<Text>(e)!;
      final t = (text.widget as Text).data!;
      final category = c.categories.firstWhere((v) => v.name == t);
      final box = _ancestor(
        text,
        (w) => w is Container && w.decoration is BoxDecoration,
      )!;
      final decoration = (box.widget as Container).decoration as BoxDecoration;
      badges.add({
        'name': t,
        'categoryId': category.id,
        'bounds': _rect(_box(box)),
        'paragraph': _paragraph(text),
        'fill': _color(decoration.color),
        'expectedFill': _color(category.tint),
        'expectedTextColor': _color(category.deep),
      });
    }
    final cr = _box(outer),
        wr = wrap == null ? _box(badgeElements.first) : _box(wrap);
    rows.add({
      'id': c.id,
      'title': c.title,
      'summary': c.summary,
      'savedAt': c.savedAt,
      'bookmarked': sw.bookmarkedIds.contains(c.id),
      'mutationLabel': c.mutationLabel,
      'bookmarkEnabled': _find<IconButton>(bookmark)?.widget is IconButton
          ? (_find<IconButton>(bookmark)!.widget as IconButton).onPressed !=
                null
          : null,
      'moreEnabled': _find<IconButton>(more)?.widget is IconButton
          ? (_find<IconButton>(more)!.widget as IconButton).onPressed != null
          : null,
      'expectedCategoryIds': c.categories.map((v) => v.id).toList(),
      'card': _rect(cr),
      'wrap': _rect(wr),
      'wrapSpacing': wrap?.widget is Wrap
          ? (wrap!.widget as Wrap).spacing
          : null,
      'wrapRunSpacing': wrap?.widget is Wrap
          ? (wrap!.widget as Wrap).runSpacing
          : null,
      'badges': badges,
      'titleStyle': _paragraph(title),
      'summaryStyle': _paragraph(summary),
      'dateStyle': _paragraph(date),
      'divider': _rect(_box(divider)),
      'dividerAsset': _asset(divider),
      'bookmark': _rect(_box(bookmark)),
      'bookmarkAsset': _asset(bookmark),
      'more': _rect(_box(more)),
      'moreAsset': _asset(more),
      'fullyInsideViewport':
          _box(viewport!).inflate(.16).contains(cr.topLeft) &&
          _box(viewport).inflate(.16).contains(cr.bottomRight),
      'visible':
          cr.bottom > _box(viewport).top && cr.top < _box(viewport).bottom,
    });
  }

  final p = _position(screen), view = View.of(screen), vpi = media.viewPadding;
  return {
    'active': true,
    'input': (editable.widget as EditableText).controller.text,
    'inputFocused': (editable.widget as EditableText).focusNode.hasFocus,
    'history': history,
    'emptyMounted': emptyWidget != null,
    'confirmedEmpty':
        (editable.widget as EditableText).controller.text.trim().isNotEmpty &&
        sw.feed?.query ==
            (editable.widget as EditableText).controller.text.trim() &&
        sw.feed?.categoryId == null &&
        sw.feed?.isFavorite == null &&
        sw.feed?.items.isEmpty == true &&
        sw.feed?.initialized == true &&
        sw.feed?.loading == false &&
        sw.feed?.error == null &&
        sw.feed?.hasMore == false &&
        sw.contents.isEmpty,
    'feedInitialized': sw.feed?.initialized,
    'feedLoading': sw.feed?.loading,
    'feedError': sw.feed?.error?.toString(),
    'feedHasMore': sw.feed?.hasMore,
    'feedVersion': sw.feed?.version,
    'feedQuery': sw.feed?.query,
    'feedCategoryId': sw.feed?.categoryId,
    'feedFavoriteFilter': sw.feed?.isFavorite,
    'feedIds': sw.contents.map((c) => c.id).toList(),
    'bookmarkedIds': sw.bookmarkedIds.toList()..sort(),
    'loadedCountVisible': _elements(screen).any(
      (e) =>
          e.widget is Text &&
          ((e.widget as Text).data ?? '').startsWith('불러온 '),
    ),
    'actualStyles': styles,
    'bounds': bounds,
    'assetGeometry': assets,
    'rows': rows,
    'scrollOffset': p?.pixels ?? 0.0,
    'maxScrollExtent': p?.maxScrollExtent ?? 0.0,
    'scaffoldBackground': _color(
      (_find<Scaffold>(screen)!.widget as Scaffold).backgroundColor ??
          Theme.of(screen).scaffoldBackgroundColor,
    ),
    'textScale': media.textScaler.scale(1),
    'viewPaddingTop': vpi.top,
    'viewPaddingBottom': vpi.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'logicalSize': '${media.size}',
    'pixelRatio': view.devicePixelRatio,
    'scaffoldBounds': _rect(_box(_find<Scaffold>(screen)!)),
  };
}

Map<String, Object?> searchJudgment(Map<String, Object?> m) {
  final styles = <String>[], layout = <String>[];
  if (m['active'] != true) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'styleFindings': styles,
      'layoutFindings': layout,
    };
  }
  final roles = m['actualStyles'] as Map,
      b = m['bounds'] as Map,
      a = m['assetGeometry'] as Map;
  void near(Object? v, num n, String name) {
    if (v is! num || (v - n).abs() > .2) layout.add('$name: $v expected $n');
  }

  void style(Object? raw, List<Object?> expected, String name) {
    final p = raw as Map?;
    if (p == null ||
        p['fontFamily'] != 'Pretendard' ||
        p['fontSize'] != expected[0] ||
        p['scaledFontSize'] != expected[0] ||
        p['fontWeight'] != expected[1] ||
        p['letterSpacing'] != expected[2] ||
        p['color'] != expected[3] ||
        p['height'] != expected[4]) {
      styles.add('$name effective typography differs');
    }
  }

  void asset(Object? raw, String path, num width, num height, String role) {
    final v = raw as Map?, r = v?['bounds'] as Map?;
    if (v?['asset'] != path || v?['unfiltered'] != true) {
      styles.add('$role exact asset/filter differs');
    }
    near(r?['width'], width, '$role width');
    near(r?['height'], height, '$role height');
  }

  final h = b['header'] as Map,
      ib = b['inputBox'] as Map,
      can = b['cancelHit'] as Map,
      l = h['left'] as num,
      r = h['right'] as num,
      top = h['top'] as num;
  near(h['height'], 76, 'Search header');
  near(top, m['viewPaddingTop'] as num, 'SafeArea header top');
  near(ib['top'], top + 16, 'Input top16');
  near(ib['height'], 44, 'Input height');
  near(ib['left'], l + 16, 'Input left16');
  near(can['right'], r - 16, 'Cancel right16');
  near(can['width'], 44, 'Cancel hit44');
  near((can['left'] as num) - (ib['right'] as num), 8, 'Input cancel gap8');
  style(roles['input'], [14, 500, -.35, '0xFF1A1A1A', 1.4], 'Input');
  style(roles['cancel'], [15, 500, -.375, '0xFF595959', null], 'Cancel');
  if ((m['input'] as String).trim().isEmpty && roles['hint'] == null) {
    styles.add('Empty input requires actual hint paragraph');
  }
  if (roles['hint'] != null) {
    style(roles['hint'], [14, 500, -.35, '0xFFB5BDC3', 1.4], 'Hint');
  }
  asset(
    a['inputIcon'],
    (m['input'] as String).trim().isEmpty
        ? 'assets/icons/search-hint-original.svg'
        : 'assets/icons/search-input-original.svg',
    16,
    16,
    'Input icon',
  );
  final ir = (a['inputIcon'] as Map?)?['bounds'] as Map;
  if (ir.isNotEmpty) {
    near(ir['left'], (ib['left'] as num) + 8, 'Input icon left');
    near(
      (ir['top'] as num) + (ir['height'] as num) / 2,
      (ib['top'] as num) + 22,
      'Input icon center',
    );
  }
  if ((m['input'] as String).trim().isNotEmpty) {
    asset(a['clear'], 'assets/icons/x-circle.svg', 18, 18, 'Clear');
  }
  final inputParagraph = roles['input'] as Map,
      er = inputParagraph['bounds'] as Map;
  near(
    (er['top'] as num) + (er['height'] as num) / 2,
    (ib['top'] as num) + 22,
    'Editable text vertical center',
  );
  if (inputParagraph['maxLines'] != 1 ||
      (er['top'] as num) < (ib['top'] as num) - .2 ||
      (er['bottom'] as num) > (ib['bottom'] as num) + .2) {
    layout.add('Single-line input exceeds input box');
  }
  if (ir.isNotEmpty) {
    near((er['left'] as num) - (ir['right'] as num), 8, 'Input icon text gap8');
  }
  final clear = (a['clear'] as Map?)?['bounds'] as Map?;
  if (clear != null) {
    near(clear['right'], (ib['right'] as num) - 8, 'Clear right8');
    near(
      (clear['top'] as num) + (clear['height'] as num) / 2,
      (ib['top'] as num) + 22,
      'Clear vertical center',
    );
  }
  final surface = b['inputSurface'] as Map;
  near(surface['radius'], 4, 'Input radius');
  if (surface['fill'] != '0xFFFFFFFF') styles.add('Input white fill');
  if (m['scaffoldBackground'] != '0xFFF5F5F5') {
    styles.add('Search background differs');
  }
  if (m['loadedCountVisible'] != false) {
    layout.add('Search loaded count must be hidden');
  }
  final history = m['history'] as List;
  if (history.isNotEmpty) {
    style(roles['historyTitle'], [
      15,
      600,
      -.375,
      '0xFF121212',
      null,
    ], 'History heading');
    final ht = (roles['historyTitle'] as Map)['bounds'] as Map;
    near((ht['top'] as num) - (h['bottom'] as num), 16, 'Header to history16');
    near(ht['left'], l + 16, 'History left16');
    Map? previous;
    for (final row in history) {
      final hr = row['bounds'] as Map, ts = row['style'] as Map;
      style(ts, [14, 500, -.35, '0xFF767676', null], 'History ${row['term']}');
      near(hr['height'], 32, 'History row32');
      if (previous == null) {
        near(
          (hr['top'] as num) - (ht['bottom'] as num),
          16,
          'History heading rowgap16',
        );
      } else {
        near(
          (hr['top'] as num) - (previous['bottom'] as num),
          4,
          'History rows gap4',
        );
      }
      previous = hr;
      asset(
        row['clock'],
        'assets/icons/search-history-clock.svg',
        18,
        18,
        'History clock',
      );
      asset(
        row['remove'],
        'assets/icons/search-history-remove.svg',
        18,
        18,
        'History remove',
      );
      final cr = (row['clock'] as Map)['bounds'] as Map?;
      if (cr != null) {
        near(
          ((ts['bounds'] as Map)['left'] as num) - (cr['right'] as num),
          9.542,
          'Clock text gap',
        );
      }
      final pr = ts['bounds'] as Map;
      if ((pr['top'] as num) < (hr['top'] as num) - .2 ||
          (pr['bottom'] as num) > (hr['bottom'] as num) + .2) {
        layout.add('History paragraph exceeds row');
      }
    }
  }
  final vp = b['viewport'] as Map?;
  if (m['emptyMounted'] == true) {
    if (m['confirmedEmpty'] != true) {
      layout.add(
        'New empty must be confirmed successful current query exhausted0',
      );
    }
    style(roles['emptyTitle'], [
      16,
      500,
      -.4,
      '0xFF484848',
      null,
    ], 'Empty title');
    style(roles['emptyBody'], [14, 500, -.35, '0xFF767676', 1.6], 'Empty body');
    style(roles['emptyCta'], [16, 500, -.4, '0xFF1A1A1A', null], 'Empty CTA');
    if ((roles['emptyTitle'] as Map?)?['text'] != '검색 결과가 없어요' ||
        (roles['emptyBody'] as Map?)?['text'] != '핵심 키워드 위주로 검색해 주세요') {
      styles.add('Empty copy differs');
    }
    final g = b['emptyGroup'] as Map?,
        img = b['emptyImageSlot'] as Map?,
        cta = b['emptyCta'] as Map?,
        et = (roles['emptyTitle'] as Map?)?['bounds'] as Map?,
        eb = (roles['emptyBody'] as Map?)?['bounds'] as Map?,
        ct = (roles['emptyCta'] as Map?)?['bounds'] as Map?;
    if (g == null ||
        img == null ||
        cta == null ||
        et == null ||
        eb == null ||
        vp == null ||
        ct == null) {
      layout.add('Empty actual group measurements missing');
    } else {
      final width = math.min(260, (h['width'] as num) - 32),
          gh = g['height'] as num,
          vpt = vp['top'] as num,
          vpb = vp['bottom'] as num;
      near(vpt, h['bottom'] as num, 'Empty viewport directly afterheader');
      near(g['width'], width, 'Empty group column max260');
      near(
        (g['left'] as num) + (g['width'] as num) / 2,
        l + (h['width'] as num) / 2,
        'Empty horizontal center',
      );
      near(
        g['top'],
        ((vpt + vpb) / 2 - 92.5 - gh / 2).clamp(vpt, math.max(vpt, vpb - gh)),
        'Empty body center minus92.5 clamp',
      );
      near(img['width'], 81, 'Empty image81');
      near(img['height'], 123, 'Empty image123');
      near((et['top'] as num) - (img['bottom'] as num), 16, 'Image titlegap16');
      near((eb['top'] as num) - (et['bottom'] as num), 8, 'Empty textgap8');
      near((cta['top'] as num) - (eb['bottom'] as num), 16, 'Body CTAgap16');
      for (final role in ['emptyTitle', 'emptyBody']) {
        final p = roles[role] as Map, pr = p['bounds'] as Map;
        near(p['constraintsMaxWidth'], width, '$role parent maxwidth');
        if ((pr['width'] as num) > width + .2 ||
            (pr['left'] as num) < (g['left'] as num) - .2 ||
            (pr['right'] as num) > (g['right'] as num) + .2) {
          layout.add('$role natural paragraph exceeds column');
        }
      }
      final image = a['emptyImage'] as Map?;
      if (image?['asset'] != 'assets/figma/search-empty-original.png' ||
          image?['fit'] != 'cover') {
        styles.add('Empty original PNG/cover differs');
      }
      near((image?['bounds'] as Map?)?['width'], 81, 'Empty source width81');
      near(
        (image?['bounds'] as Map?)?['height'],
        123,
        'Empty source height123',
      );
      asset(
        a['emptyCtaIcon'],
        'assets/icons/bookmark-book-open.svg',
        18,
        18,
        'Empty book18',
      );
      final icon = (a['emptyCtaIcon'] as Map?)?['bounds'] as Map?;
      if (icon != null) {
        near((ct['left'] as num) - (icon['right'] as num), 4, 'Book labelgap4');
      }
      final sf = b['emptyCtaSurface'] as Map?;
      if (sf?['fill'] != '0xFFFFFFFF' ||
          sf?['borderColor'] != '0xFFD1D1D1' ||
          sf?['borderWidth'] != 1 ||
          sf?['radius'] != 4) {
        styles.add('Empty CTA white/D1border1/radius4 differs');
      }
      if ((cta['height'] as num) < 35 - .2) layout.add('CTA min35 missing');
      near(
        (cta['bottom'] as num) -
            math.max(ct['bottom'] as num, icon?['bottom'] as num? ?? 0),
        8,
        'CTA bottom8',
      );
      near(
        math.min(
              ct['left'] as num,
              icon?['left'] as num? ?? ct['left'] as num,
            ) -
            (cta['left'] as num),
        16,
        'CTA left16',
      );
    }
  } else if ((m['rows'] as List).isNotEmpty && vp != null) {
    near(vp['top'], h['bottom'] as num, 'Results viewport starts afterheader');
    if ((m['scrollOffset'] as num).abs() < .2) {
      final first = (m['rows'] as List)
          .where((v) => v['id'] == (m['feedIds'] as List).first)
          .firstOrNull;
      if (first != null) {
        near(
          (first['card'] as Map)['top'],
          h['bottom'] as num,
          'First card starts afterheader/inputbottom16',
        );
      }
    }
  }
  for (final row in m['rows'] as List) {
    final r = row as Map,
        cr = r['card'] as Map,
        wr = r['wrap'] as Map,
        badges = r['badges'] as List;
    final delta = math.max(0, (wr['height'] as num) - 22), id = r['id'];
    near(cr['height'], 173 + delta, '$id card natural height');
    near((wr['top'] as num) - (cr['top'] as num), 16, '$id badge top');
    near((wr['left'] as num) - (cr['left'] as num), 16, '$id badge left');
    near(wr['width'], (cr['width'] as num) - 116, '$id reserved badge width');
    near(r['wrapSpacing'], 8, '$id wrap spacing');
    near(r['wrapRunSpacing'], 8, '$id wrap run spacing');
    if (jsonEncode(badges.map((v) => v['categoryId']).toList()) !=
        jsonEncode(r['expectedCategoryIds'])) {
      layout.add('$id must expose all categories in actual order');
    }
    for (final badge in badges) {
      style(badge['paragraph'], [
        12,
        500,
        -.3,
        badge['expectedTextColor'],
        null,
      ], '$id badge ${badge['name']}');
      final p = badge['paragraph'] as Map, br = badge['bounds'] as Map;
      if (badge['fill'] != badge['expectedFill']) {
        styles.add('$id badge fill differs from actual data');
      }
      if (p['maxLines'] != 1 || p['overflow'] != 'ellipsis') {
        layout.add('$id badge requires one-line ellipsis');
      }
      if ((br['width'] as num) > (wr['width'] as num) + .17 ||
          (br['right'] as num) > (wr['right'] as num) + .17) {
        layout.add('$id long badge exceeds reserved width');
      }
    }
    final title = r['titleStyle'] as Map,
        summary = r['summaryStyle'] as Map,
        date = r['dateStyle'] as Map;
    style(title, [16, 600, -.4, '0xFF1A1A1A', 1.4], '$id title');
    style(summary, [15, 400, -.375, '0xFF484848', 1.6], '$id summary');
    style(date, [14, 400, -.35, '0xFFA9A9A9', null], '$id date');
    if (title['maxLines'] != 1 ||
        title['overflow'] != 'ellipsis' ||
        summary['maxLines'] != 2 ||
        summary['overflow'] != 'ellipsis') {
      layout.add('$id title/summary limits differ');
    }
    near(
      title['constraintsMaxWidth'],
      math.min(311, (cr['width'] as num) - 40),
      '$id title maximum width',
    );
    near(
      ((title['bounds'] as Map)['top'] as num) - (cr['top'] as num),
      46 + delta,
      '$id title shifted once',
    );
    near(
      ((summary['bounds'] as Map)['top'] as num) - (cr['top'] as num),
      72.4 + delta,
      '$id summary shifted once',
    );
    near(
      (r['divider'] as Map)['top'],
      (cr['top'] as num) + 127.5 + delta,
      '$id exact divider top',
    );
    near((r['divider'] as Map)['height'], .5, '$id exact divider height');
    near(
      (cr['bottom'] as num) - ((date['bounds'] as Map)['bottom'] as num),
      16,
      '$id date bottom',
    );
    near(
      (r['bookmark'] as Map)['top'],
      (cr['top'] as num) + 13,
      '$id bookmark first line',
    );
    near(
      (r['more'] as Map)['top'],
      (cr['top'] as num) + 13,
      '$id more first line',
    );
    near((r['bookmark'] as Map)['width'], 28, '$id bookmark hit');
    near((r['more'] as Map)['width'], 28, '$id more hit');
    asset(
      r['bookmarkAsset'] as Map,
      r['bookmarked'] == true
          ? 'assets/icons/archive-all-star-filled.svg'
          : 'assets/icons/category-card-star.svg',
      28,
      28,
      '$id bookmark',
    );
    asset(
      r['moreAsset'] as Map,
      'assets/icons/archive-all-more.svg',
      24,
      24,
      '$id more',
    );
    asset(
      r['dividerAsset'] as Map,
      'assets/icons/archive-all-divider.svg',
      (cr['width'] as num) - 40,
      .5,
      '$id divider',
    );
    final more = (r['moreAsset'] as Map)['bounds'] as Map?,
        star = (r['bookmarkAsset'] as Map)['bounds'] as Map?;
    near(more?['right'], (cr['right'] as num) - 16, '$id more visual right');
    if (more != null && star != null) {
      near(
        (more['left'] as num) - (star['right'] as num),
        16,
        '$id icon visual gap',
      );
    }
    if (((title['bounds'] as Map)['bottom'] as num) >
        ((summary['bounds'] as Map)['top'] as num) + .17) {
      layout.add('$id title and summary overlap');
    }
    if (((summary['bounds'] as Map)['bottom'] as num) >
        ((r['divider'] as Map)['top'] as num) + .17) {
      layout.add('$id summary exceeds body');
    }
    if ((r['moreAsset'] as Map)['asset'] !=
        'assets/icons/archive-all-more.svg') {
      styles.add('$id more exact original asset missing');
    }
    if ((r['dividerAsset'] as Map)['asset'] !=
            'assets/icons/archive-all-divider.svg' ||
        (r['dividerAsset'] as Map)['unfiltered'] != true) {
      styles.add('$id divider original asset/filter differs');
    }
  }

  return {
    'stylePassed': styles.isEmpty,
    'layoutPassed': layout.isEmpty,
    'styleFindings': styles,
    'layoutFindings': layout,
  };
}

final _capture = GlobalKey();
SearchServer _server = SearchServer();
late Directory _output;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
final _seen = <String>{}, _fullySeen = <String>{};
bool _busy = false, _done = false, _coverage = false, _requireNativeIme = true;
String _kind = 'initial';
int _epoch = 0, _pointer = 71000;
double _requestedOffset = 0;
final _clock = Stopwatch()..start();
Duration _lastTime = Duration.zero;
Duration _time() {
  final t = _clock.elapsed;
  return _lastTime = t > _lastTime
      ? t
      : _lastTime + const Duration(microseconds: 1);
}

Element get _root => _capture.currentContext! as Element;
Future<void> _settle([int n = 3]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

void _require(bool value, String why) {
  if (!value) throw StateError(why);
}

Future<void> _wait(bool Function() check, String why) async {
  for (var i = 0; i < 100; i++) {
    if (check()) return;
    await _settle(2);
  }
  throw StateError(why);
}

Future<void> _tap(Element e) => _tapPoint(_box(e).center);
Future<void> _tapPoint(Offset point) async {
  final v = View.of(_root), id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      viewId: v.viewId,
      position: point,
      timeStamp: _time(),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 70));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: v.viewId,
      position: point,
      timeStamp: _time(),
    ),
  );
  await _settle();
}

Future<void> _hideIme() async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  if (_requireNativeIme) {
    await _wait(
      () => View.of(_root).viewInsets.bottom == 0,
      'Actual native IME did not hide',
    );
  }
  await _settle(2);
}

SearchScreen get _screen => _find<SearchScreen>(_root)!.widget as SearchScreen;
Element get _searchElement => _find<SearchScreen>(_root)!;
Element get _editable => _find<EditableText>(_searchElement)!;
EditableText get _edit => _editable.widget as EditableText;
Future<void> _ensureIme() async {
  if (!_edit.focusNode.hasFocus) _edit.focusNode.requestFocus();
  (_editable as StatefulElement).state is EditableTextState
      ? ((_editable as StatefulElement).state as EditableTextState)
            .requestKeyboard()
      : null;
  await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  if (_requireNativeIme) {
    await _wait(
      () => View.of(_root).viewInsets.bottom > 0,
      'Actual native IME did not show',
    );
  }
  await _settle(3);
}

Future<void> _type(String value, {bool showKeyboard = true}) async {
  if (showKeyboard) await _ensureIme();
  final state = (_editable as StatefulElement).state as EditableTextState;
  state.updateEditingValue(
    TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    ),
  );
  await _settle(2);
  _require(
    _edit.controller.text == value,
    'Actual controller did not receive fixed input',
  );
}

Future<void> _submit(String query, {bool wait = true}) async {
  await _type(query);
  (_editable as StatefulElement).state is EditableTextState
      ? ((_editable as StatefulElement).state as EditableTextState)
            .performAction(TextInputAction.search)
      : null;
  await _settle(2);
  if (wait) {
    await _wait(
      () =>
          _screen.feed?.query == query.trim() &&
          _screen.feed?.initialized == true &&
          _screen.feed?.loading == false,
      'Actual submitted search did not complete',
    );
  }
}

String _route() {
  if (_find<AddContentSheet>(_root) != null) return 'save';
  if (_find<CategoryManagementScreen>(_root) != null) return 'management';
  if (_find<SearchScreen>(_root) != null) return 'search';
  if (_find<DetailScreen>(_root) != null) return 'detail';
  if (_find<ArchiveScreen>(_root) != null) return 'archive';
  if (_find<HomeScreen>(_root) != null) return 'home';
  if (_find<BookmarkScreen>(_root) != null) return 'bookmark';
  if (_find<MyScreen>(_root) != null) return 'my';
  return 'other';
}

Element _searchControl() {
  return _key(_root, 'bookmark-search') ??
      _key(_root, 'archive-category-search') ??
      _elements(_root).firstWhere(
        (e) =>
            e.widget is SvgIconButton &&
            (e.widget as SvgIconButton).asset == Assets.search,
      );
}

Future<void> _openSearch() async {
  await _tap(_searchControl());
  await _wait(() => _route() == 'search', 'Actual search route did not open');
  await _ensureIme();
}

Future<void> _jump(double value) async {
  final p = _position(_root);
  if (p == null) {
    _require(value == 0, 'No nonzero offset without result list');
    return;
  }
  p.jumpTo(value.clamp(0, p.maxScrollExtent));
  await _settle(2);
}

Future<void> _loadAll() async {
  for (
    var i = 0;
    i < 12 && (_screen.feed?.hasMore == true || _screen.feed?.loading == true);
    i++
  ) {
    final p = _position(_root);
    if (p != null) p.jumpTo(p.maxScrollExtent);
    await _settle(3);
  }
  await _wait(
    () =>
        _screen.feed?.initialized == true &&
        _screen.feed?.loading == false &&
        _screen.feed?.hasMore == false,
    'Actual search pagination did not exhaust',
  );
}

Element _card(String id) => _elements(_root).firstWhere(
  (e) =>
      e.widget is ContentListCard &&
      (e.widget as ContentListCard).content.id == id,
);
Element _bookmark(Element card) => _key(
  card,
  'list-bookmark-${(card.widget as ContentListCard).content.title}',
)!;
Element _more(Element card) =>
    _key(
      card,
      'archive-all-more-${(card.widget as ContentListCard).content.id}',
    ) ??
    _elements(card).where((e) => e.widget is SvgIconButton).last;
Future<void> _fresh(String kind, double offset) async {
  _kind = kind;
  _requestedOffset = offset;
  _server = SearchServer();
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: ValueKey(++_epoch),
        sessionStorage: e01.ArchiveAllMemoryStorage(),
        socialAuth: e01.ArchiveAllSocialAuth(),
      ),
    ),
  );
  await _settle(2);
  await _wait(
    () => _route() == 'home',
    'Actual memory app session/home did not initialize',
  );
  await _openSearch();
  if (kind != 'initial') {
    await _submit(kind == 'empty' ? searchEmptyQuery : searchQuery);
    if (kind == 'results') {
      await _loadAll();
      _require(
        _screen.contents.length == 8,
        'Search must load independent eight results',
      );
      await _jump(offset);
      // IME action may dismiss on either OS. Restoring it is capture preparation,
      // not a new production submit/focus policy or a second search request.
      final requestsBefore = _server.requests
          .where((r) => r['path'] == '/api/v1/feed')
          .length;
      await _ensureIme();
      _require(
        requestsBefore ==
            _server.requests.where((r) => r['path'] == '/api/v1/feed').length,
        'Keyboard preparation submitted another search',
      );
    } else {
      await _hideIme();
      _require(
        _screen.contents.isEmpty &&
            _screen.feed?.hasMore == false &&
            _screen.feed?.error == null &&
            _server.records.length == 9,
        'Empty must be actual current successful query0 while all9 saved records remain',
      );
    }
  } else {
    _require(offset == 0, 'Initial has no nonzero list offset');
    await _ensureIme();
  }
  await _settle(3);
}

Map<String, Object?> _snapshot() {
  final m = searchMeasure(_root),
      j = searchJudgment(m),
      view = View.of(_root),
      messenger = e01.archiveAllShareMessenger;
  for (final r in m['rows'] as List? ?? []) {
    if (r['visible'] == true) _seen.add(r['id'] as String);
    if (r['fullyInsideViewport'] == true) _fullySeen.add(r['id'] as String);
  }
  return _copy({
    'phase': searchPhase,
    'platform': Platform.operatingSystem,
    'kind': _kind,
    'route': _route(),
    'ready': true,
    'busy': _busy,
    'output': _output.path,
    'logicalSize': '${view.physicalSize / view.devicePixelRatio}',
    'pixelRatio': view.devicePixelRatio,
    'textScale': MediaQuery.textScalerOf(_find<Scaffold>(_root)!).scale(1),
    'viewPaddingTop': view.viewPadding.top / view.devicePixelRatio,
    'viewPaddingBottom': view.viewPadding.bottom / view.devicePixelRatio,
    'viewInsetsBottom': view.viewInsets.bottom / view.devicePixelRatio,
    'scrollOffset': 0.0,
    'maxScrollExtent': 0.0,
    ...m,
    ...j,
    'requestedOffset': _requestedOffset,
    'fixedOriginalIds': searchIds,
    'serverAccountSavedCount': 999,
    'serverRecords': _server.records,
    'requests': _server.requests,
    'unexpectedRequests': _server.unexpected,
    'favoriteAttempts': _server.favoriteAttempts,
    'favoriteSuccesses': _server.favoriteSuccesses,
    'categoryAttempts': _server.categoryAttempts,
    'categorySuccesses': _server.categorySuccesses,
    'deleteAttempts': _server.deleteAttempts,
    'deleteSuccesses': _server.deleteSuccesses,
    'nativeKeyboardRequired': _requireNativeIme,
    'sceneKeyboardPreparation': _kind == 'results'
        ? 'Focus/requestKeyboard after actual submission if needed; no extra API submit.'
        : 'Initial autofocus/requestKeyboard; empty explicitly hides IME.',
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        messenger,
      ),
      'state':
          'In-memory empty drafts/receipts; retained native queue is untouched.',
      'methodCounts': {
        for (final name in messenger?.namesOnlyCalls.toSet() ?? <String>{})
          name: messenger!.namesOnlyCalls.where((v) => v == name).length,
      },
      'nativeDelegationCount': messenger?.nativeDelegationCount,
      'unknownMethods': messenger?.unknownShareMethods ?? <String>[],
      'argumentsOrCredentialsRecorded': false,
    },
    'visibleCoverage': _seen.toList()..sort(),
    'fullyVisibleCoverage': _fullySeen.toList()..sort(),
    'frameworkErrors': _errors,
    'scope':
        'Actual ClipbackApp/SearchScreen/FeedPage over in-process MockClient, memory session and isolated share queue. Native IME and synthetic pointers on device; controlled delays/failures are local doubles. No external API/OAuth/provider/persistence/physical-device/CI proof.',
  });
}

void _record(String scenario, [Map<String, Object?> fields = const {}]) =>
    _checks.add(
      _copy({'scenario': scenario, 'passed': true, ..._snapshot(), ...fields}),
    );
Future<void> _report() async {
  final s = _snapshot(), messenger = e01.archiveAllShareMessenger;
  final style =
          s['stylePassed'] == true &&
          !_checks.any((c) => c['stylePassed'] == false),
      layout =
          s['layoutPassed'] == true &&
          _errors.isEmpty &&
          !_checks.any((c) => c['layoutPassed'] == false);
  final behavior =
      _done &&
      messenger != null &&
      messenger.nativeDelegationCount == 0 &&
      messenger.unknownShareMethods.isEmpty &&
      _server.unexpected.isEmpty &&
      !_checks.any(
        (c) =>
            c['passed'] == false ||
            (c['unexpectedRequests'] is List &&
                (c['unexpectedRequests'] as List).isNotEmpty),
      );
  await File('${_output.path}/report.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(
      _freeze({
        ...s,
        'checksCompleted': _done,
        'coveragePassed': _coverage,
        'stylePassed': style,
        'layoutPassed': layout,
        'behaviorPassed': behavior,
        'passed': _done && _coverage && style && layout && behavior,
        'checks': _checks,
      }),
    ),
  );
}

Future<void> _captureScene() async {
  await _settle(2);
  final image =
      await (_capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: View.of(_root).devicePixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_output.path}/search_${_kind}_scale_1_scroll_${_requestedOffset.toInt()}.png',
    ).writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _record('static_${_kind}_scroll_${_requestedOffset.toInt()}');
}

// Wait for actual modal transition completion before reading a moving target's
// coordinates; closing is verified by actual disposal, not a fixed sleep.
Future<Element> _readyModal<T extends Widget>(String why) async {
  await _wait(() {
    final element = _find<T>(_root);
    if (element == null) return false;
    final route = ModalRoute.of(element);
    return route != null &&
        route.animation?.status == AnimationStatus.completed;
  }, why);
  return _find<T>(_root)!;
}

Future<void> _dismissActions() async {
  final sheet = await _readyModal<ContentActionSheet>(
    'Content action modal did not finish entering',
  );
  await _tapPoint(
    Offset(
      _box(sheet).center.dx,
      (View.of(_root).viewPadding.top / View.of(_root).devicePixelRatio +
              _box(sheet).top) /
          2,
    ),
  );
  await _wait(
    () => _find<ContentActionSheet>(_root) == null,
    'Content action modal did not dismiss',
  );
}

Future<void> _changeCategory(String id) async {
  await _tap(_more(_card(id)));
  final sheet = await _readyModal<ContentActionSheet>(
    'Category action modal did not finish entering',
  );
  await _tap(_text(sheet, '카테고리 변경')!);
  final change = await _readyModal<CategoryChangeSheet>(
    'Category selection modal did not finish entering',
  );
  final tile = _elements(change).firstWhere(
    (e) =>
        e.widget is CategoryChangeTile &&
        (e.widget as CategoryChangeTile).category.id == 102,
  );
  await _tap(tile);
  await _wait(
    () => _find<CategoryChangeSheet>(_root) == null,
    'Category selection modal did not dismiss',
  );
}

Future<void> _delete(String id) async {
  await _tap(_more(_card(id)));
  final sheet = await _readyModal<ContentActionSheet>(
    'Delete action modal did not finish entering',
  );
  await _tap(_text(sheet, '삭제')!);
  await _wait(
    () => _find<ContentActionSheet>(_root) == null,
    'Delete action modal did not dismiss',
  );
}

Future<void> _drag() async {
  final p = _position(_root)!,
      before = p.pixels,
      vp = _box(_find<PagedContentList>(_root)!),
      start = Offset(vp.center.dx, vp.bottom - 40),
      view = View.of(_root),
      id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      viewId: view.viewId,
      position: start,
      timeStamp: _time(),
    ),
  );
  for (var i = 1; i <= 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: id,
        viewId: view.viewId,
        position: start - Offset(0, i * 18.0),
        delta: const Offset(0, -18),
        timeStamp: _time(),
      ),
    );
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: view.viewId,
      position: start - const Offset(0, 144),
      timeStamp: _time(),
    ),
  );
  await _settle();
  _require(p.pixels > before + 1, 'Actual pointer did not scroll search list');
  _record('list_pointer_drag', {
    'offsetBefore': before,
    'offsetAfter': p.pixels,
    'pointerMoves': 8,
  });
}

Future<void> _cancel() async {
  await _tap(_key(_root, 'search-cancel') ?? _text(_searchElement, '취소')!);
  await _hideIme();
}

Future<void> _clear() async {
  final control =
      _key(_searchElement, 'search-clear') ??
      _svgNamed(_searchElement, Assets.close);
  _require(control != null, 'Actual clear control missing');
  await _tap(control!);
  await _wait(
    () => _edit.controller.text.isEmpty && _screen.feed?.query == null,
    'Actual clear did not reset query/results',
  );
}

Future<void> _run() async {
  _done = false;
  _coverage = false;
  _checks.clear();
  _seen.clear();
  _fullySeen.clear();
  await _fresh('initial', 0);
  _require(
    jsonEncode(
          (searchMeasure(_root)['history'] as List)
              .map((r) => r['term'])
              .toList(),
        ) ==
        jsonEncode(recentSearches),
    'Original five recent examples changed',
  );
  _record('initial_five_recent_examples_native_ime');
  final recent = _elements(_searchElement).firstWhere(
    (e) =>
        e.widget is SearchHistoryRow &&
        (e.widget as SearchHistoryRow).term == recentSearches.first,
  );
  await _tap(recent);
  await _wait(
    () =>
        _screen.feed?.query == recentSearches.first &&
        _screen.feed?.initialized == true &&
        _screen.feed?.loading == false,
    'Recent row did not submit actual query',
  );
  _record('recent_term_actual_submit');
  await _clear();
  for (var i = 0; i < 2; i++) {
    await _submit(searchQuery);
    await _clear();
  }
  var history = searchMeasure(_root)['history'] as List;
  _require(
    history.length == 5 &&
        history.first['term'] == searchQuery &&
        history.where((r) => r['term'] == searchQuery).length == 1,
    'Recent terms must dedupe/front/max5',
  );
  _record('recent_dedupe_front_max5');
  final removable = _elements(_searchElement).firstWhere(
    (e) =>
        e.widget is SearchHistoryRow &&
        (e.widget as SearchHistoryRow).term == searchQuery,
  );
  await _tap(
    _key(removable, 'search-history-remove-$searchQuery') ??
        _svgNamed(removable, Assets.close)!,
  );
  history = searchMeasure(_root)['history'] as List;
  _require(
    history.length == 4 && !history.any((r) => r['term'] == searchQuery),
    'Recent remove changed wrong row',
  );
  _record('recent_remove_scoped');
  final beforeWhitespace = _server.requests
      .where(
        (r) => r['path'] == '/api/v1/feed' && (r['query'] as Map)['q'] != null,
      )
      .length;
  await _type('   ');
  ((_editable as StatefulElement).state as EditableTextState).performAction(
    TextInputAction.search,
  );
  await _settle(3);
  _require(
    _screen.feed?.query == null &&
        beforeWhitespace ==
            _server.requests
                .where(
                  (r) =>
                      r['path'] == '/api/v1/feed' &&
                      (r['query'] as Map)['q'] != null,
                )
                .length,
    'Whitespace must not submit API',
  );
  await _type('');
  _record('whitespace_no_query_and_input_preserved', {
    'queryRequestsBefore': beforeWhitespace,
    'queryRequestsAfter': beforeWhitespace,
  });
  await _submit(searchQuery);
  await _loadAll();
  await _jump(0);
  _require(
    jsonEncode(_screen.contents.map((c) => c.id).toList()) ==
        jsonEncode(searchIds),
    'Actual independent query IDs/order differ',
  );
  final pages = _server.requests
      .where(
        (r) =>
            r['path'] == '/api/v1/feed' &&
            (r['query'] as Map)['q'] == searchQuery,
      )
      .toList();
  _require(
    pages.any(
      (r) =>
          (r['query'] as Map)['cursor'] == 'search-page-4' &&
          jsonEncode(r['returnedIds']) == '[705,706,707,708]',
    ),
    'Actual query did not request cursor4',
  );
  _record('query_pagination_4_plus_4_independent_total', {
    'pageRequests': pages,
    'loadedSearchCount': 8,
    'accountSavedCount': 999,
    'ordinary900Excluded': true,
  });
  await _hideIme();
  var maximum = _position(_root)!.maxScrollExtent;
  for (var offset = 0.0; offset < maximum; offset += 140) {
    await _jump(offset);
    _record('coverage_step_${offset.toInt()}');
    maximum = _position(_root)!.maxScrollExtent;
  }
  for (var i = 0; i < 4; i++) {
    final extent = _position(_root)!.maxScrollExtent;
    await _jump(extent);
    if ((_position(_root)!.maxScrollExtent - extent).abs() < .2) break;
  }
  _record('maximum_scroll');
  _coverage = searchIds.every(_fullySeen.contains);
  _require(_coverage, 'Every frozen search row must actually be fully visible');
  _record('required_row_coverage', {
    'expectedIds': searchIds,
    'observedFullyVisibleIds': _fullySeen.toList()..sort(),
  });
  await _jump(0);
  await _drag();
  await _jump(300);
  final offsetBefore = _position(_root)!.pixels,
      feed = _screen.feed!,
      version = feed.version;
  final visible = _elements(_searchElement)
      .where(
        (e) =>
            e.widget is ContentListCard &&
            _box(e).top >= _box(_find<PagedContentList>(_root)!).top &&
            _box(e).bottom <= _box(_find<PagedContentList>(_root)!).bottom,
      )
      .first;
  final content = (visible.widget as ContentListCard).content;
  await _tap(_text(visible, content.title)!);
  _require(_route() == 'detail', 'Search card did not open detail');
  _record('detail_open', {'selectedId': content.id});
  await _tap(_key(_root, 'detail-back')!);
  _require(
    _route() == 'search' &&
        identical(_screen.feed, feed) &&
        feed.version == version &&
        _edit.controller.text == searchQuery &&
        (_position(_root)!.pixels - offsetBefore).abs() < .2,
    'Detail return did not preserve search query/feed/offset',
  );
  _record('detail_return_preserves_query_offset', {
    'savedOffset': offsetBefore,
    'returnedOffset': _position(_root)!.pixels,
  });
  await _jump(0);
  await _tap(_more(_card('api-701')));
  _require(
    _find<ContentActionSheet>(_root) != null,
    'Search more modal missing',
  );
  _record('more_open');
  final original = jsonEncode(_server.records);
  await _dismissActions();
  _require(
    jsonEncode(_server.records) == original,
    'More cancellation changed saved records',
  );
  _record('more_cancel_preserves_data');
  _server.failNextFavorite = true;
  await _tap(_bookmark(_card('api-701')));
  await _wait(
    () =>
        _server.favoriteAttempts == 1 &&
        _screen.contents.any(
          (c) => c.id == 'api-701' && c.mutationLabel == null,
        ),
    'Favorite failure did not settle',
  );
  _require(
    _server.favoriteSuccesses == 0 &&
        _server.records.first['is_favorite'] == false &&
        !_screen.bookmarkedIds.contains('api-701'),
    'Favorite failure did not restore data',
  );
  _record('bookmark_failure_restores_data');
  await _tap(_bookmark(_card('api-701')));
  await _wait(
    () =>
        _server.favoriteSuccesses == 1 &&
        _screen.bookmarkedIds.contains('api-701') &&
        _screen.feed?.loading == false,
    'Favorite retry did not commit',
  );
  _require(
    _server.favoriteAttempts == 2,
    'Favorite retry callback count changed',
  );
  _record('bookmark_retry_success_once');
  await _jump(0);
  _server.failNextCategory = true;
  await _changeCategory('api-701');
  await _wait(
    () =>
        _server.categoryAttempts == 1 &&
        _screen.contents.any(
          (c) => c.id == 'api-701' && c.mutationLabel == null,
        ),
    'Category failure did not settle',
  );
  _require(
    _server.categorySuccesses == 0 &&
        jsonEncode(
              (_server.records.first['categories'] as List)
                  .map((c) => c['id'])
                  .toList(),
            ) ==
            '[101]',
    'Category failure did not preserve original membership',
  );
  _record('category_failure_preserves_membership');
  await _changeCategory('api-701');
  await _wait(
    () =>
        _server.categorySuccesses == 1 &&
        _screen.feed?.loading == false &&
        _screen.contents.any(
          (c) => c.id == 'api-701' && c.categories.single.id == 102,
        ),
    'Category retry did not update actual search',
  );
  _require(
    _server.categoryAttempts == 2,
    'Category retry callback count changed',
  );
  _record('category_retry_success_once');
  await _jump(0);
  _server.failNextDelete = true;
  await _delete('api-701');
  await _wait(
    () =>
        _server.deleteAttempts == 1 &&
        _screen.contents.any(
          (c) => c.id == 'api-701' && c.mutationLabel == null,
        ),
    'Delete failure did not settle',
  );
  _require(
    _server.deleteSuccesses == 0 && _server.records.any((r) => r['id'] == 701),
    'Delete failure did not restore original record',
  );
  _record('delete_failure_restores_record');
  await _delete('api-701');
  await _wait(
    () =>
        _server.deleteSuccesses == 1 &&
        !_screen.contents.any((c) => c.id == 'api-701') &&
        _screen.feed?.loading == false,
    'Delete retry did not remove item',
  );
  _require(
    _server.deleteAttempts == 2 &&
        _server.records.length == 8 &&
        _server.records.any((r) => r['id'] == 900),
    'Delete must commit once and preserve ordinary records',
  );
  _record('delete_retry_success_once');
  final hold = Completer<void>();
  _server.heldQueries['지연A'] = [hold];
  await _submit('지연A', wait: false);
  await _wait(
    () => _server.requests.any(
      (r) => (r['query'] as Map)['q'] == '지연A' && r['held'] == true,
    ),
    'Old A request not actually held',
  );
  await _submit('지연B');
  await _submit('지연A');
  final newestIds = _screen.contents.map((c) => c.id).toList();
  final latestVersion = _screen.feed!.version;
  hold.complete();
  await _settle(5);
  _require(
    _edit.controller.text == '지연A' &&
        _screen.feed?.query == '지연A' &&
        _screen.feed?.version == latestVersion &&
        jsonEncode(_screen.contents.map((c) => c.id).toList()) ==
            jsonEncode(newestIds),
    'Late firstA overwrote latestA',
  );
  _record('late_A_B_A_old_response_ignored', {
    'latestIdsBeforeRelease': newestIds,
    'latestVersion': latestVersion,
    'controlledDelay':
        'Local MockClient completer; real repository generation and widget requestVersion.',
  });
  _server.failNextQuery = '실패재시도';
  await _submit('실패재시도', wait: false);
  await _wait(
    () => _screen.feed?.error != null && _screen.feed?.loading == false,
    'Injected query error did not render existing failure',
  );
  _require(
    _find<EmptySearchResult>(_searchElement) == null &&
        _key(_searchElement, 'search-empty-group') == null,
    'Failed query must not show confirmed empty',
  );
  _record('query_error_keeps_existing_retry');
  final retry = _text(_searchElement, '다시 시도');
  _require(retry != null, 'Existing retry action missing');
  await _tap(retry!);
  await _wait(
    () =>
        _screen.feed?.error == null &&
        _screen.feed?.initialized == true &&
        _screen.feed?.loading == false,
    'Actual query retry failed',
  );
  _record('query_error_retry_success');
  // Each cancel returns through the real app route; no new search→management route.
  await _cancel();
  _require(_route() == 'home', 'Home search cancel returned wrong origin');
  _record('cancel_from_home');
  for (final origin in ['아카이브', '즐겨찾기']) {
    await _tap(_text(_find<ClipbackNavigationBar>(_root)!, origin)!);
    await _settle(3);
    final originRoute = origin == '아카이브' ? 'archive' : 'bookmark';
    final sourcePos = _position(_root);
    if (sourcePos != null && sourcePos.maxScrollExtent >= 300) {
      sourcePos.jumpTo(300);
      await _settle(2);
    }
    final saved = sourcePos?.pixels ?? 0;
    await _openSearch();
    await _type('귀환 입력 보존');
    await _cancel();
    _require(
      _route() == originRoute &&
          ((_position(_root)?.pixels ?? 0) - saved).abs() < .2,
      'Cancel changed source route/offset',
    );
    _record('cancel_from_$originRoute', {
      'savedOffset': saved,
      'returnedOffset': _position(_root)?.pixels ?? 0,
    });
    final gear = _key(
      _root,
      originRoute == 'archive'
          ? 'archive-manage-categories'
          : 'bookmark-settings',
    );
    if (gear != null) {
      await _tap(gear);
      _require(
        _route() == 'management',
        'Existing gear failed to open management',
      );
      await _tap(_key(_root, 'management-back')!);
      _require(_route() == originRoute, 'Management returned wrong source');
      _record('source_${originRoute}_management_roundtrip');
    }
  }
  // Final H03 is a current successful empty query, never a fabricated cleared feed.
  await _openSearch();
  await _submit(searchEmptyQuery);
  await _hideIme();
  _kind = 'empty';
  _require(
    _screen.feed?.query == searchEmptyQuery &&
        _screen.feed?.initialized == true &&
        _screen.feed?.hasMore == false &&
        _screen.feed?.error == null &&
        _screen.contents.isEmpty &&
        _server.records.any((r) => r['id'] == 900),
    'Confirmed query0 must preserve ordinary saved data',
  );
  _record('current_successful_query_zero_empty');
  final archiveBefore = _server.requests.length;
  await _tap(
    _key(_root, 'search-empty-cta') ??
        _find<OutlinedButton>(_find<EmptySearchResult>(_root)!)!,
  );
  _require(_route() == 'archive', 'Empty CTA did not open archive');
  final archive = _find<ArchiveScreen>(_root)!.widget as ArchiveScreen;
  _require(
    archive.activeTab == 0 &&
        archive.activeCategoryName == null &&
        archive.feed?.categoryId == null &&
        archive.feed?.query == null &&
        archive.feed?.isFavorite == null &&
        archive.bookmarkedFirst == false,
    'Empty CTA must open archive0 without category/query/favorite filters and preserve this fixture existing false sort',
  );
  _record('empty_cta_archive_all_tab0_filters_cleared_sort_preserved', {
    'archiveTab': archive.activeTab,
    'categoryId': archive.feed?.categoryId,
    'query': archive.feed?.query,
    'favoriteFilter': archive.feed?.isFavorite,
    'bookmarkedFirst': archive.bookmarkedFirst,
    'requestsBeforeCta': archiveBefore,
    'sortPolicyScope':
        'This fixture observes its initial default false sort preserved; true-sort preservation is covered by separate actual App regression. No new reset policy.',
  });
  for (final item in {
    '홈': 'home',
    '아카이브': 'archive',
    '즐겨찾기': 'bookmark',
    '마이': 'my',
  }.entries) {
    final before = _route();
    await _tap(_text(_find<ClipbackNavigationBar>(_root)!, item.key)!);
    _require(_route() == item.value, 'Root tab destination changed');
    _record('root_tab_${item.value}', {
      'routeBefore': before,
      'routeAfter': _route(),
    });
  }
  final writesBefore = _server.requests
      .where((r) => r['method'] != 'GET')
      .length;
  await _tap(_find<NavAddButton>(_find<ClipbackNavigationBar>(_root)!)!);
  _require(_route() == 'save', 'Actual save sheet missing');
  _record('save_open');
  final saveSheet = await _readyModal<AddContentSheet>(
    'Save modal did not finish entering',
  );
  final close = _elements(saveSheet).firstWhere(
    (e) =>
        e.widget is SvgIconButton &&
        (e.widget as SvgIconButton).asset == Assets.close,
  );
  await _tap(close);
  await _wait(
    () => _find<AddContentSheet>(_root) == null,
    'Save modal did not dismiss',
  );
  await _hideIme();
  _require(
    _route() == 'my' &&
        writesBefore ==
            _server.requests.where((r) => r['method'] != 'GET').length,
    'Save close made extra write or changed returnroute',
  );
  _record('save_close_no_additional_write');
  _require(
    _errors.isEmpty && _server.unexpected.isEmpty,
    'Unexpected framework/HTTP error',
  );
  _done = true;
}

// External widget preflight only: native keyboard evidence still requires /scene
// on both OSes. This does not replace the real native text-input channel.
Future<void> searchPreviewPrepareForProbe(String kind) async {
  _requireNativeIme = false;
  _output = await Directory.systemTemp.createTemp('clipback-search-probe-');
  await _fresh(kind, 0);
}

Map<String, Object?> searchPreviewSnapshot() => _snapshot();
SearchServer get searchPreviewServer => _server;

Future<void> main() => http.runWithClient(() async {
  e01.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-search-');
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add(details.exceptionAsString());
    old?.call(details);
  };
  await _fresh('initial', 0);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('SEARCH ready phase=$searchPhase output=${_output.path}');
  await for (final request in server) {
    final read = ['/ready', '/state', '/status'].contains(request.uri.path);
    if (_busy && !read) {
      request.response.statusCode = 409;
      await request.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (request.uri.path) {
        case '/ready':
        case '/state':
        case '/status':
          break;
        case '/scene':
          final kind = request.uri.queryParameters['kind'] ?? 'initial',
              offset = double.parse(
                request.uri.queryParameters['offset'] ?? '0',
              );
          _require(
            ['initial', 'results', 'empty'].contains(kind) &&
                offset >= 0 &&
                (kind == 'results' || offset == 0),
            'Only initial0/results nonnegative/empty0 supported',
          );
          await _fresh(kind, offset);
          await _captureScene();
        case '/run':
          await _run();
        default:
          request.response.statusCode = 404;
      }
      await _report();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_snapshot()));
    } catch (error, stack) {
      _checks.add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$error',
      });
      debugPrint('SEARCH FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
