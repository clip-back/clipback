// Independent I01/I02 actual-app fixture. Memory-only HTTP/session/share
// doubles; no external server, OAuth, persistence or physical-device proof.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'archive_all_preview.dart' as e01;

import 'package:clipback_frontend/shared/widgets/top_bars.dart';

const bookmarkPhase = String.fromEnvironment(
  'BOOKMARK_PHASE',
  defaultValue: 'before',
);
const bookmarkIds = [
  'api-801',
  'api-802',
  'api-803',
  'api-804',
  'api-805',
  'api-806',
  'api-807',
  'api-808',
];

List<Map<String, Object?>> bookmarkCategoryMaps() => [
  for (final c in e01.archiveAllCategoryMaps) Map<String, Object?>.from(c),
];
List<Map<String, Object?>> bookmarkRecords({bool lastOnly = false}) {
  final base = e01.archiveAllRecords();
  return [
    for (var i = 0; i < (lastOnly ? 1 : 8); i++)
      {
        ...Map<String, Object?>.from(
          jsonDecode(jsonEncode(base[i % base.length])) as Map,
        ),
        'id': 801 + i,
        'title': i < base.length
            ? base[i]['title']
            : i == 6
            ? '북마크로 간직할 중요한 기록'
            : '마지막까지 확인할 즐겨찾기 콘텐츠',
        'saved_at': '2026-10-${17 - i}T12:00:00Z',
        'is_favorite': true,
        'original_url': 'https://example.invalid/bookmark/${801 + i}',
      },
    {
      ...Map<String, Object?>.from(jsonDecode(jsonEncode(base.first)) as Map),
      'id': 900,
      'title': '즐겨찾기하지 않은 일반 콘텐츠',
      'summary': '즐겨찾기0개가 전체 저장 콘텐츠0개를 의미하지 않습니다.',
      'is_favorite': false,
      'original_url': 'https://example.invalid/bookmark/ordinary/900',
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

Map<String, Object?> _copy(Map<String, Object?> value) =>
    Map<String, Object?>.from(_freeze(value)! as Map);

class BookmarkServer {
  BookmarkServer({bool lastOnly = false})
    : records = bookmarkRecords(lastOnly: lastOnly);
  final List<Map<String, Object?>> records;
  final requests = <Map<String, Object?>>[], unexpected = <String>[];
  Completer<void>? heldFavorite;
  bool failNextFavorite = false;
  int favoriteAttempts = 0, favoriteSuccesses = 0;
  int get favoriteCount =>
      records.where((r) => r['is_favorite'] == true).length;
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
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
        'display_name': '즐겨찾기 화면 검증',
        'is_guest': true,
        'created_at': '2026-10-17T00:00:00Z',
        'linked_providers': <String>[],
      });
    }
    if (path == '/api/v1/users/me/stats') {
      return json({'saved_count': 999, 'reopened_count': 0});
    }
    if (path == '/api/v1/categories') return json(bookmarkCategoryMaps());
    if (path == '/api/v1/feed') {
      final filtered = records.where((r) {
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
        return '${r['title']} ${r['summary']}'.toLowerCase().contains(
          (q['q'] ?? '').toLowerCase(),
        );
      }).toList();
      final cursor = q['cursor'],
          start = cursor == null
              ? 0
              : int.parse(cursor.substring(cursor.lastIndexOf('-') + 1));
      final page = filtered.skip(start).take(4).toList(),
          more = start + 4 < filtered.length;
      final next = more ? 'bookmark-page-${start + 4}' : null;
      call.addAll({
        'returnedIds': page.map((r) => r['id']).toList(),
        'matchingCount': filtered.length,
        'nextCursor': next,
      });
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
    final m = RegExp(r'^/api/v1/contents/(\d+)(/favorite)?$').firstMatch(path);
    if (m != null) {
      final i = records.indexWhere((r) => r['id'] == int.parse(m[1]!));
      if (i < 0) return json({'detail': 'Unknown fixture content'}, 404);
      if (m[2] != null && request.method == 'PUT') {
        favoriteAttempts++;
        final body = jsonDecode(request.body) as Map;
        call['isFavorite'] = body['is_favorite'];
        final hold = heldFavorite;
        if (hold != null) {
          call['held'] = true;
          await hold.future;
          heldFavorite = null;
        }
        if (failNextFavorite) {
          failNextFavorite = false;
          call['injectedFailure'] = true;
          return json({'detail': 'Fixture favorite write failed'}, 503);
        }
        favoriteSuccesses++;
        records[i] = {...records[i], 'is_favorite': body['is_favorite']};
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
      _key(root, 'bookmark-empty-image-source') ??
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

ScrollPosition? _position(Element root) {
  final list = _find<PagedContentList>(root);
  if (list == null) return null;
  final e = _elements(list)
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

Element? _headerControl(Element root, String role) {
  final keyed = _key(root, 'bookmark-$role');
  if (keyed != null) return keyed;
  final h = _find<AppTopBar>(root);
  if (h == null) return null;
  return _elements(h)
      .where(
        (e) =>
            e.widget is SvgIconButton &&
            (e.widget as SvgIconButton).asset ==
                (role == 'search' ? Assets.search : Assets.more),
      )
      .firstOrNull;
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

Map<String, Object?> bookmarkMeasure(Element root) {
  final screen = _find<BookmarkScreen>(root);
  if (screen == null) return {'active': false};
  final sw = screen.widget as BookmarkScreen,
      media = MediaQuery.of(screen),
      styles = <String, Object?>{},
      bounds = <String, Object?>{},
      assets = <String, Object?>{},
      rows = <Map<String, Object?>>[];
  final header = _key(screen, 'bookmark-header') ?? _find<AppTopBar>(screen)!;
  final title =
      _key(header, 'bookmark-title') ??
      _text(header, '즐겨찾기') ??
      _text(header, '북마크')!;
  bounds['header'] = _rect(_box(header));
  styles['header'] = _paragraph(title);
  for (final role in ['search', 'settings']) {
    final e = _headerControl(screen, role);
    assets[role] = _asset(e);
    if (e != null) bounds['${role}Hit'] = _rect(_box(e));
  }
  final back = _elements(header)
      .where(
        (e) =>
            e.widget is SvgIconButton &&
            (e.widget as SvgIconButton).asset == Assets.back,
      )
      .length;
  final count =
      _key(screen, 'bookmark-count') ??
      _elements(screen)
          .where(
            (e) =>
                e.widget is Text &&
                ((e.widget as Text).data ?? '').startsWith('불러온 '),
          )
          .firstOrNull;
  final toolbar =
      _key(screen, 'bookmark-toolbar') ??
      (count == null ? null : _ancestor(count, (w) => w is Padding));
  final sort = _key(screen, 'bookmark-sort') ?? _text(screen, '최신순');
  if (count != null) styles['count'] = _paragraph(count);
  if (sort != null) styles['sort'] = _paragraph(sort);
  if (toolbar != null) bounds['toolbar'] = _rect(_box(toolbar));
  final nav = _find<ClipbackNavigationBar>(screen)!,
      list = _find<PagedContentList>(screen)!;
  bounds['navigation'] = _rect(_box(nav));
  bounds['viewport'] = _rect(
    _box(_key(screen, 'bookmark-empty-viewport') ?? list),
  );
  final viewport = list;
  final empty = sw.contents.isEmpty;
  if (empty) {
    final old = _find<EmptyStatePanel>(screen);
    final et =
        _key(screen, 'bookmark-empty-title') ??
        (old == null ? null : _text(old, '즐겨찾기한 콘텐츠가 없어요'));
    final eb =
        _key(screen, 'bookmark-empty-body') ??
        (old == null ? null : _text(old, '중요한 콘텐츠의 별 아이콘을 누르면 이곳에 모아둘 수 있어요.'));
    final group =
        _key(screen, 'bookmark-empty-group') ??
        (old == null ? null : _find<Column>(old));
    final image =
        _key(screen, 'bookmark-empty-image') ??
        (old == null ? null : _find<Image>(old));
    final cta =
        _key(screen, 'bookmark-empty-cta') ??
        (old == null ? null : _find<OutlinedButton>(old));
    final ct = cta == null
        ? null
        : _text(cta, '전체 리스트 보기') ?? _text(cta, '아카이브 보러가기');
    if (et != null) styles['emptyTitle'] = _paragraph(et);
    if (eb != null) styles['emptyBody'] = _paragraph(eb);
    if (ct != null) styles['emptyCta'] = _paragraph(ct);
    if (group != null) bounds['emptyGroup'] = _rect(_box(group));
    if (image != null) {
      bounds['emptyImageSlot'] = _rect(_box(image));
      assets['emptyImage'] = _asset(image);
    }
    if (cta != null) {
      bounds['emptyCta'] = _rect(_box(cta));
      bounds['emptyCtaSurface'] = _surface(cta);
    }
    assets['emptyCtaIcon'] = _asset(_key(screen, 'bookmark-empty-cta-icon'));
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
          _box(viewport).inflate(.16).contains(cr.topLeft) &&
          _box(viewport).inflate(.16).contains(cr.bottomRight),
      'visible':
          cr.bottom > _box(viewport).top && cr.top < _box(viewport).bottom,
    });
  }
  final position = _position(screen);
  return {
    'active': true,
    'empty': empty,
    'feedInitialized': sw.feed?.initialized,
    'feedLoading': sw.feed?.loading,
    'feedError': sw.feed?.error?.toString(),
    'feedHasMore': sw.feed?.hasMore,
    'feedVersion': sw.feed?.version,
    'feedFavoriteFilter': sw.feed?.isFavorite,
    'feedCategoryId': sw.feed?.categoryId,
    'feedQuery': sw.feed?.query,
    'bookmarkedFirst': sw.feed?.bookmarkedFirst,
    'feedIds': sw.contents.map((c) => c.id).toList(),
    'bookmarkedIds': sw.bookmarkedIds.toList()..sort(),
    'backControlCount': back,
    'toolbarPresent': toolbar != null,
    'sortPresent': sort != null,
    'sortArrowCount': toolbar == null
        ? 0
        : _elements(toolbar).where((e) => e.widget is SvgPicture).length,
    'actualStyles': styles,
    'bounds': bounds,
    'assetGeometry': assets,
    'rows': rows,
    'scrollOffset': position?.pixels ?? 0.0,
    'maxScrollExtent': position?.maxScrollExtent ?? 0.0,
    'scaffoldBackground': _color(
      (_find<Scaffold>(screen)!.widget as Scaffold).backgroundColor ??
          Theme.of(screen).scaffoldBackgroundColor,
    ),
    'textScale': media.textScaler.scale(1),
    'viewPaddingTop': media.viewPadding.top,
    'viewPaddingBottom': media.viewPadding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'logicalSize': '${media.size}',
    'pixelRatio': View.of(screen).devicePixelRatio,
  };
}

Map<String, Object?> bookmarkJudgment(Map<String, Object?> m) {
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
  void near(Object? value, num expected, String name) {
    if (value is! num || (value - expected).abs() > .18) {
      layout.add('$name: $value expected $expected');
    }
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

  void asset(Object? raw, String path, num width, num height, String name) {
    final v = raw as Map?, r = v?['bounds'] as Map?;
    if (v == null || v['asset'] != path || v['unfiltered'] != true) {
      styles.add('$name exact asset/filter differs');
    }
    near(r?['width'], width, '$name actual asset width');
    near(r?['height'], height, '$name actual asset height');
  }

  final header = b['header'] as Map,
      nav = b['navigation'] as Map,
      vp = b['viewport'] as Map;
  final left = header['left'] as num,
      right = header['right'] as num,
      top = header['top'] as num,
      width = header['width'] as num;
  style(roles['header'], [18, 600, -.45, '0xFF000000', null], 'header');
  if ((roles['header'] as Map)['text'] != '즐겨찾기') {
    styles.add('Header title must use 즐겨찾기');
  }
  near(header['height'], 64, 'Header height');
  near(
    top,
    m['viewPaddingTop'] as num,
    'Header directly after actual OS top inset',
  );
  final title = (roles['header'] as Map)['bounds'] as Map;
  near(title['left'], left + 16, 'Header title left');
  near(
    (title['top'] as num) + (title['height'] as num) / 2,
    top + 32.5,
    'Header title center',
  );
  near(m['backControlCount'], 0, 'Header has no back control');
  for (final role in ['search', 'settings']) {
    asset(a[role], 'assets/icons/archive-$role.svg', 24, 24, role);
    final r = (a[role] as Map)['bounds'] as Map?;
    if (r != null) {
      near(
        (r['top'] as num) + (r['height'] as num) / 2,
        top + 32.5,
        '$role vertical center',
      );
    }
  }
  final search = (a['search'] as Map)['bounds'] as Map?,
      gear = (a['settings'] as Map)['bounds'] as Map?;
  if (gear != null) near(gear['right'], right - 16, 'Settings visual right');
  if (search != null && gear != null) {
    near(
      (gear['left'] as num) - (search['right'] as num),
      16,
      'Search settings visual gap',
    );
  }
  near(
    vp['bottom'],
    nav['top'] as num,
    'Body ends above actual bottom navigation',
  );
  if (m['feedFavoriteFilter'] != true ||
      m['feedCategoryId'] != null ||
      m['feedQuery'] != null ||
      m['bookmarkedFirst'] != false) {
    layout.add(
      'Bookmark feed query must remain favorite=true/categorynull/querynull without sorting phases',
    );
  }
  if (m['scaffoldBackground'] != '0xFFF5F5F5') {
    styles.add('Bookmark scaffold background differs');
  }
  if (m['empty'] == true) {
    if (m['toolbarPresent'] != false) {
      layout.add('Confirmed empty has no loaded-count toolbar');
    }
    near(
      vp['top'],
      header['bottom'] as num,
      'Empty body starts directly after header',
    );
    style(roles['emptyTitle'], [
      16,
      500,
      -.4,
      '0xFF484848',
      null,
    ], 'Empty title');
    style(roles['emptyBody'], [14, 500, -.35, '0xFF767676', 1.6], 'Empty body');
    style(roles['emptyCta'], [16, 500, -.4, '0xFF1A1A1A', null], 'Empty CTA');
    if ((roles['emptyTitle'] as Map?)?['text'] != '북마크한 콘텐츠가 없어요' ||
        (roles['emptyBody'] as Map?)?['text'] != '중요한 정보는 북마크를 통해 저장하세요!' ||
        (roles['emptyCta'] as Map?)?['text'] != '전체 리스트 보기') {
      styles.add('Empty copy differs from the approved original');
    }
    final group = b['emptyGroup'] as Map?,
        image = b['emptyImageSlot'] as Map?,
        cta = b['emptyCta'] as Map?,
        surface = b['emptyCtaSurface'] as Map?;
    final et = (roles['emptyTitle'] as Map?)?['bounds'] as Map?,
        eb = (roles['emptyBody'] as Map?)?['bounds'] as Map?,
        ct = (roles['emptyCta'] as Map?)?['bounds'] as Map?;
    if (group == null ||
        image == null ||
        cta == null ||
        et == null ||
        eb == null ||
        ct == null) {
      layout.add('Empty actual group/image/text/CTA measurements missing');
    } else {
      final maxWidth = math.min(260, width - 32),
          groupCenter = (group['left'] as num) + (group['width'] as num) / 2;
      near(group['width'], maxWidth, 'Empty group maximum width');
      near(groupCenter, left + width / 2, 'Empty group horizontal center');
      near(image['width'], 40, 'Empty image slot width');
      near(image['height'], 46, 'Empty image slot height');
      near(
        (et['top'] as num) - (image['bottom'] as num),
        16,
        'Image to text gap',
      );
      near(
        (eb['top'] as num) - (et['bottom'] as num),
        8,
        'Empty title to body gap',
      );
      near((cta['top'] as num) - (eb['bottom'] as num), 16, 'Text to CTA gap');
      for (final name in ['emptyTitle', 'emptyBody']) {
        final p = roles[name] as Map, r = p['bounds'] as Map;
        near(p['constraintsMaxWidth'], maxWidth, '$name parent maximum width');
        if ((r['width'] as num) > maxWidth + .18 ||
            (r['left'] as num) < (group['left'] as num) - .18 ||
            (r['right'] as num) > (group['right'] as num) + .18) {
          layout.add('$name natural paragraph exceeds its260px parent column');
        }
      }
      final gh = group['height'] as num,
          vpt = vp['top'] as num,
          vpb = vp['bottom'] as num;
      final expected = ((vpt + vpb) / 2 - 43.5 - gh / 2).clamp(
        vpt,
        math.max(vpt, vpb - gh),
      );
      near(
        group['top'],
        expected,
        'Natural empty group body-center minus43.5 clamped',
      );
      if (gh <= vpb - vpt &&
          ((group['top'] as num) < vpt - .18 ||
              (group['bottom'] as num) > vpb + .18)) {
        layout.add('Natural empty group exceeds body viewport');
      }
      final raw = a['emptyImage'] as Map?, ir = raw?['bounds'] as Map?;
      if (raw?['asset'] != 'assets/figma/unclassified-empty.png') {
        styles.add('Empty exact source PNG differs');
      }
      if (ir != null) {
        near(ir['width'], 40 * 1.6118, 'Image raw crop width');
        near(ir['height'], 46 * 1.3918, 'Image raw crop height');
        near(
          (ir['left'] as num) - (image['left'] as num),
          40 * -.3072,
          'Image raw crop left',
        );
        near(
          (ir['top'] as num) - (image['top'] as num),
          46 * -.172,
          'Image raw crop top',
        );
      }
      asset(
        a['emptyCtaIcon'],
        'assets/icons/bookmark-book-open.svg',
        18,
        18,
        'Empty CTA book',
      );
      final icon = (a['emptyCtaIcon'] as Map)['bounds'] as Map?;
      if (icon != null) {
        near(
          (ct['left'] as num) - (icon['right'] as num),
          4,
          'CTA icon text gap',
        );
        near(
          (icon['left'] as num) - (cta['left'] as num),
          16,
          'CTA left padding',
        );
        near(
          (cta['right'] as num) - (ct['right'] as num),
          16,
          'CTA right padding',
        );
        near(
          cta['height'],
          math.max(35, 16 + math.max(18, ct['height'] as num)),
          'CTA natural height without additional border inset',
        );
        near(
          cta['width'],
          32 + 18 + 4 + (ct['width'] as num),
          'CTA natural width without additional border inset',
        );
        near(
          (ct['top'] as num) + (ct['height'] as num) / 2,
          (cta['top'] as num) + (cta['height'] as num) / 2,
          'CTA text center',
        );
      }
      if (surface == null ||
          surface['fill'] != '0xFFFFFFFF' ||
          surface['borderColor'] != '0xFFD1D1D1') {
        styles.add('CTA actual surface fill/border differs');
      }
      near(surface?['borderWidth'], 1, 'CTA border width');
      near(surface?['radius'], 4, 'CTA corner radius');
    }
    if (m['feedInitialized'] != true ||
        m['feedLoading'] != false ||
        m['feedHasMore'] != false ||
        m['feedError'] != null) {
      layout.add(
        'Empty requires confirmed initialized exhausted favorite query without loading/error',
      );
    }
  } else {
    if (m['toolbarPresent'] != true || m['sortPresent'] != true) {
      layout.add('List toolbar/sort static label missing');
    }
    style(roles['sort'], [
      14,
      500,
      -.35,
      '0xFF767676',
      null,
    ], 'Static latest label');
    style(roles['count'], [14, 500, -.35, '0xFF767676', null], 'Loaded count');
    if ((roles['sort'] as Map?)?['text'] != '최신순' ||
        (roles['count'] as Map?)?['text'] !=
            '불러온 ${(m['feedIds'] as List).length}개') {
      styles.add('Latest/loaded count must use actual loaded favorite data');
    }
    near((b['toolbar'] as Map?)?['height'], 52, 'Toolbar height');
    near(
      (b['toolbar'] as Map?)?['top'],
      header['bottom'] as num,
      'Toolbar after header',
    );
    near(vp['top'], (header['bottom'] as num) + 52, 'List body after toolbar');
    near(m['sortArrowCount'], 0, 'Static latest label has no arrow/menu');
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
      style(badge['paragraph'] as Map, [
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
BookmarkServer _server = BookmarkServer();
late Directory _output;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
final _seen = <String>{}, _fullySeen = <String>{};
bool _busy = false, _done = false, _coverage = false;
String _kind = 'list';
int _epoch = 0, _pointer = 61000;
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
Future<void> _settle([int n = 5]) async {
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
  final v = View.of(_capture.currentContext!), id = ++_pointer;
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
  await _wait(
    () => View.of(_capture.currentContext!).viewInsets.bottom == 0,
    'Native IME did not hide',
  );
  await _settle(2);
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

BookmarkScreen get _screen =>
    _find<BookmarkScreen>(_root)!.widget as BookmarkScreen;
Future<void> _enterBookmarks() async {
  final nav = _find<ClipbackNavigationBar>(_root)!;
  await _tap(_text(nav, '즐겨찾기')!);
  await _wait(
    () =>
        _find<BookmarkScreen>(_root) != null &&
        _screen.feed?.initialized == true &&
        _screen.feed?.loading == false,
    'Actual favorite feed did not initialize',
  );
  _require(
    _screen.feed?.isFavorite == true &&
        _screen.feed?.categoryId == null &&
        _screen.feed?.query == null,
    'Actual favorite feed query scope changed',
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
Future<void> _jump(double value) async {
  final p = _position(_root);
  if (p == null) {
    _require(value == 0, 'Empty favorite list has no nonzero list offset');
    return;
  }
  p.jumpTo(value.clamp(0, p.maxScrollExtent));
  await _settle(3);
}

Future<void> _fresh(String kind, double offset) async {
  _kind = kind;
  _requestedOffset = offset;
  _server = BookmarkServer(lastOnly: kind == 'empty');
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
    () => _find<HomeScreen>(_root) != null,
    'Actual app session/home did not initialize',
  );
  await _enterBookmarks();
  await _hideIme();
  if (kind == 'empty') {
    await _tap(_bookmark(_card('api-801')));
    await _wait(
      () =>
          _screen.feed?.initialized == true &&
          _screen.feed?.loading == false &&
          _screen.feed?.hasMore == false &&
          _screen.contents.isEmpty,
      'Last successful unbookmark did not produce confirmed favorite0',
    );
    _require(
      _server.favoriteCount == 0 &&
          _server.favoriteAttempts == 1 &&
          _server.favoriteSuccesses == 1 &&
          _server.records.length == 2 &&
          _server.records.any((r) => r['id'] == 900),
      'Confirmed empty must follow actual favorite write and preserve general saved content',
    );
    _require(offset == 0, 'Empty only supports offset0');
  } else {
    for (var i = 0; i < 8 && _screen.contents.length < 8; i++) {
      final p = _position(_root);
      if (p != null) p.jumpTo(p.maxScrollExtent);
      await _settle();
    }
    await _wait(
      () => _screen.contents.length == 8 && _screen.feed?.loading == false,
      'Four-plus-four favorite pagination did not finish',
    );
    final p = _position(_root)!;
    _require(
      p.maxScrollExtent >= offset,
      'Frozen concrete offset exceeds actual favorite maximum',
    );
    p.jumpTo(offset);
    await _settle(3);
    _require(
      (p.pixels - offset).abs() < .2,
      'Frozen concrete favorite offset not retained',
    );
  }
}

Map<String, Object?> _snapshot() {
  final m = bookmarkMeasure(_root),
      j = bookmarkJudgment(m),
      view = View.of(_capture.currentContext!),
      messenger = e01.archiveAllShareMessenger;
  for (final row in m['rows'] as List? ?? []) {
    if (row['visible'] == true) _seen.add(row['id'] as String);
    if (row['fullyInsideViewport'] == true) _fullySeen.add(row['id'] as String);
  }
  return _copy({
    'phase': bookmarkPhase,
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
    'fixedOriginalIds': bookmarkIds,
    'serverAccountSavedCount': 999,
    'serverFavoriteCount': _server.favoriteCount,
    'serverRecords': _server.records,
    'requests': _server.requests,
    'unexpectedRequests': _server.unexpected,
    'favoriteAttempts': _server.favoriteAttempts,
    'favoriteSuccesses': _server.favoriteSuccesses,
    'favoriteRequestHeld':
        _server.heldFavorite != null && !_server.heldFavorite!.isCompleted,
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
    'frameworkErrors': _errors,
    'visibleCoverage': _seen.toList()..sort(),
    'fullyVisibleCoverage': _fullySeen.toList()..sort(),
    'scope':
        'Actual ClipbackApp favorite FeedPage/routing/callbacks over in-process MockClient, memory session and isolated share channel. Synthetic pointers/native IME observation. Controlled request delay/failure is a local double. No external API/OAuth/provider/persistence/physical-device/CI proof.',
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
      !_checks.any((c) => c['stylePassed'] == false);
  final layout =
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
          .toImage(
            pixelRatio: View.of(_capture.currentContext!).devicePixelRatio,
          );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_output.path}/bookmark_${_kind}_scale_1_scroll_${_requestedOffset.toInt()}.png',
    ).writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _record('static_${_kind}_scroll_${_requestedOffset.toInt()}');
}

Future<void> _dragList() async {
  final p = _position(_root)!,
      before = p.pixels,
      viewport = _box(_find<PagedContentList>(_root)!);
  final start = Offset(viewport.center.dx, viewport.bottom - 50),
      view = View.of(_capture.currentContext!),
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
  _require(
    p.pixels > before + 1,
    'Real pointer drag did not scroll actual selected feed',
  );
  _record('list_pointer_drag', {
    'offsetBefore': before,
    'offsetAfter': p.pixels,
    'pointerMoves': 8,
  });
}

Future<void> _dismissContentActions() async {
  final sheet = _find<ContentActionSheet>(_root)!;
  final top = _box(sheet).top, view = View.of(_capture.currentContext!);
  final safe = view.viewPadding.top / view.devicePixelRatio;
  _require(top > safe + 4, 'No actual modal backdrop point');
  await _tapPoint(
    Offset(
      view.physicalSize.width / view.devicePixelRatio / 2,
      (safe + top) / 2,
    ),
  );
  _require(
    _find<ContentActionSheet>(_root) == null,
    'Content management did not dismiss',
  );
}

Future<void> _run() async {
  _done = false;
  _coverage = false;
  _checks.clear();
  _seen.clear();
  _fullySeen.clear();
  await _fresh('list', 0);
  final pages = _server.requests
      .where(
        (r) =>
            r['path'] == '/api/v1/feed' &&
            (r['query'] as Map)['is_favorite'] == 'true',
      )
      .toList();
  _require(
    pages.any(
          (r) =>
              (r['query'] as Map)['cursor'] == null &&
              jsonEncode(r['returnedIds']) == '[801,802,803,804]',
        ) &&
        pages.any(
          (r) =>
              (r['query'] as Map)['cursor'] == 'bookmark-page-4' &&
              jsonEncode(r['returnedIds']) == '[805,806,807,808]',
        ),
    'Actual favorite query must paginate4+4 without ordinary content',
  );
  _require(
    jsonEncode(_screen.contents.map((c) => c.id).toList()) ==
        jsonEncode(bookmarkIds),
    'Favorite initial IDs/order differ',
  );
  _record('favorite_query_pagination_4_plus_4', {
    'pageRequests': pages,
    'ordinaryIdExcluded': 'api-900',
    'accountSavedCount': 999,
    'loadedFavoriteCount': 8,
  });
  final sort = _key(_root, 'bookmark-sort')!;
  final requestCount = _server.requests.length;
  await _tap(sort);
  _require(
    _route() == 'bookmark' &&
        _find<SortSheet>(_root) == null &&
        _server.requests.length == requestCount,
    'Latest label must remain static without sort menu/query',
  );
  _record('static_latest_label_no_action');
  for (final offset in [0.0, 300.0]) {
    await _jump(offset);
    _record('coverage_scroll_${offset.toInt()}');
  }
  var maximum = _position(_root)!.maxScrollExtent;
  for (var offset = 0.0; offset < maximum; offset += 100) {
    await _jump(offset);
    _record('coverage_step_${offset.toInt()}');
    maximum = _position(_root)!.maxScrollExtent;
  }
  for (var i = 0; i < 4; i++) {
    final extent = _position(_root)!.maxScrollExtent;
    await _jump(extent);
    if ((_position(_root)!.maxScrollExtent - extent).abs() < .18) break;
  }
  _record('maximum_scroll');
  _coverage = bookmarkIds.every(_fullySeen.contains);
  _require(
    _coverage,
    'All8 favorite rows must actually be fully visible across viewport scroll union',
  );
  _record('required_row_coverage', {
    'expectedIds': bookmarkIds,
    'observedFullyVisibleIds': _fullySeen.toList()..sort(),
  });
  await _jump(0);
  await _dragList();
  await _jump(300);
  final feed = _screen.feed!,
      version = feed.version,
      ids = _screen.contents.map((c) => c.id).toList(),
      savedOffset = _position(_root)!.pixels;
  await _tap(_headerControl(_root, 'settings')!);
  _require(
    _route() == 'management',
    'Bookmark gear did not open actual category management',
  );
  _record('management_open');
  await _tap(_key(_root, 'management-back')!);
  _require(
    _route() == 'bookmark' &&
        identical(_screen.feed, feed) &&
        feed.version == version &&
        jsonEncode(_screen.contents.map((c) => c.id).toList()) ==
            jsonEncode(ids) &&
        (_position(_root)!.pixels - savedOffset).abs() < .2,
    'Management return changed actual favorite feed/version/order/offset',
  );
  _record('management_return_favorite_offset300', {
    'sameFeedIdentity': true,
    'sameFeedVersion': true,
    'savedOffset': savedOffset,
    'returnedOffset': _position(_root)!.pixels,
  });
  await _tap(_headerControl(_root, 'search')!);
  _require(_route() == 'search', 'Bookmark search did not open actual screen');
  _record('search_open');
  await _tap(_text(_find<SearchScreen>(_root)!, '취소')!);
  await _hideIme();
  _require(
    _route() == 'bookmark' &&
        _screen.feed?.isFavorite == true &&
        (_position(_root)!.pixels - savedOffset).abs() < .2,
    'Search return changed favorite scope/offset',
  );
  _record('search_return_favorite_offset300');
  final visible = _elements(_root)
      .where(
        (e) =>
            e.widget is ContentListCard &&
            _box(e).top >= _box(_find<PagedContentList>(_root)!).top &&
            _box(e).bottom <= _box(_find<PagedContentList>(_root)!).bottom,
      )
      .first;
  final content = (visible.widget as ContentListCard).content;
  await _tap(_text(visible, content.title)!);
  _require(
    _route() == 'detail' &&
        (_find<DetailScreen>(_root)!.widget as DetailScreen).content.id ==
            content.id,
    'Favorite card did not open matching detail',
  );
  _record('detail_open', {'selectedId': content.id});
  await _tap(_key(_root, 'detail-back')!);
  _require(
    _route() == 'bookmark' &&
        (_position(_root)!.pixels - savedOffset).abs() < .2,
    'Detail return changed favorite offset',
  );
  _record('detail_return_favorite_offset300');
  await _jump(0);
  final original = jsonEncode(_server.records);
  await _tap(_more(_card('api-801')));
  _require(
    _find<ContentActionSheet>(_root) != null,
    'Actual content management missing',
  );
  _record('more_open');
  await _dismissContentActions();
  _require(
    jsonEncode(_server.records) == original,
    'Content sheet cancellation changed records',
  );
  _record('more_cancel_preserves_data');
  _server.heldFavorite = Completer<void>();
  _server.failNextFavorite = true;
  final before = _server.favoriteAttempts;
  await _tap(_bookmark(_card('api-801')));
  await _wait(
    () =>
        _server.favoriteAttempts == before + 1 &&
        _screen.contents.any(
          (c) => c.id == 'api-801' && c.mutationLabel != null,
        ),
    'Held unbookmark request did not expose actual pending state',
  );
  final pendingRow =
      (bookmarkMeasure(_root)['rows'] as List).firstWhere(
            (r) => r['id'] == 'api-801',
          )
          as Map;
  _require(
    _server.favoriteCount == 8 &&
        _server.favoriteSuccesses == 0 &&
        pendingRow['mutationLabel'] != null &&
        pendingRow['bookmarkEnabled'] == false &&
        pendingRow['moreEnabled'] == false,
    'Pending unbookmark must retain row/data and lock controls',
  );
  _record('unbookmark_request_pending', {
    'heldRequest': true,
    'pendingRowRetained': true,
    'bookmarkAndMoreDisabled': true,
    'duplicateProtectionScope':
        'Observed actual disabled controls here; repeated-tap callback policy also has separate App/widget regression tests.',
  });
  _server.heldFavorite!.complete();
  await _wait(
    () =>
        _server.heldFavorite == null &&
        _screen.contents.any(
          (c) => c.id == 'api-801' && c.mutationLabel == null,
        ) &&
        _screen.bookmarkedIds.contains('api-801'),
    'Failed unbookmark did not restore original actual UI',
  );
  _require(
    _server.favoriteAttempts == before + 1 &&
        _server.favoriteSuccesses == 0 &&
        _server.favoriteCount == 8 &&
        jsonEncode(_server.records) == original,
    'Failed favorite write must preserve original records and membership',
  );
  _record('unbookmark_failure_restores_data', {
    'callbackAttempts': 1,
    'injectedFailure': 'Memory MockClient503, not an external server failure.',
  });
  await _tap(_bookmark(_card('api-801')));
  await _wait(
    () =>
        !_screen.contents.any((c) => c.id == 'api-801') &&
        _screen.feed?.loading == false,
    'Successful retry did not remove item from favorite feed',
  );
  _require(
    _server.favoriteAttempts == before + 2 &&
        _server.favoriteSuccesses == 1 &&
        _server.favoriteCount == 7 &&
        _server.records.first['is_favorite'] == false &&
        _server.records.length == 9,
    'Unbookmark retry must commit once and retain saved records',
  );
  _record('unbookmark_retry_success', {
    'callbackAttempts': 2,
    'successfulWrites': 1,
    'remainingFavoriteCount': 7,
    'savedRecordsRetained': 9,
  });
  await _fresh('empty', 0);
  final emptyReads = _server.requests
      .where(
        (r) =>
            r['path'] == '/api/v1/feed' &&
            (r['query'] as Map)['is_favorite'] == 'true' &&
            r['matchingCount'] == 0,
      )
      .toList();
  _require(
    emptyReads.isNotEmpty &&
        _screen.feed?.isFavorite == true &&
        _screen.feed?.hasMore == false,
    'Empty must follow an actual exhausted favorite0 response',
  );
  _record('last_favorite_removed_confirmed_empty', {
    'unbookmarkSuccesses': 1,
    'zeroFavoriteReads': emptyReads,
    'ordinaryIdPreserved': 900,
    'allSavedRecordsRetained': 2,
  });
  await _tap(_headerControl(_root, 'settings')!);
  _require(_route() == 'management', 'Empty gear destination changed');
  await _tap(_key(_root, 'management-back')!);
  _require(
    _route() == 'bookmark' &&
        _screen.contents.isEmpty &&
        _screen.feed?.isFavorite == true,
    'Empty management return lost favorite scope',
  );
  _record('empty_management_return');
  await _tap(_key(_root, 'bookmark-empty-cta')!);
  _require(_route() == 'archive', 'Empty CTA did not open actual archive');
  final archive = _find<ArchiveScreen>(_root)!.widget as ArchiveScreen;
  _require(
    archive.activeTab == 0 &&
        archive.activeCategoryName == null &&
        archive.feed?.categoryId == null &&
        archive.feed?.isFavorite == null &&
        archive.feed?.query == null &&
        archive.bookmarkedFirst == false,
    'Empty CTA must enter actual archive tab0 with category/favorite filters cleared and retain this fixture existing default sort',
  );
  _record('empty_cta_archive_all_tab0_unfiltered', {
    'archiveTab': archive.activeTab,
    'categoryName': archive.activeCategoryName,
    'categoryId': archive.feed?.categoryId,
    'favoriteFilter': archive.feed?.isFavorite,
    'bookmarkedFirst': archive.bookmarkedFirst,
    'query': archive.feed?.query,
    'sortPolicyScope':
        'This fixture began with the existing default bookmarkedFirst=false and observes it preserved. This is not a reset policy; true-sort preservation is checked separately by the real App regression.',
  });
  for (final item in {
    '홈': 'home',
    '아카이브': 'archive',
    '즐겨찾기': 'bookmark',
    '마이': 'my',
  }.entries) {
    final routeBefore = _route();
    await _tap(_text(_find<ClipbackNavigationBar>(_root)!, item.key)!);
    _require(
      _route() == item.value,
      'Root tab opened wrong actual destination',
    );
    _record('root_tab_${item.value}', {
      'routeBefore': routeBefore,
      'routeAfter': _route(),
      'expectedRoute': item.value,
    });
  }
  await _tap(_text(_find<ClipbackNavigationBar>(_root)!, '즐겨찾기')!);
  _require(_route() == 'bookmark', 'Bookmark root return failed');
  final writesBefore = _server.requests
      .where((r) => r['method'] != 'GET')
      .length;
  await _tap(_find<NavAddButton>(_find<ClipbackNavigationBar>(_root)!)!);
  _require(_route() == 'save', 'Actual save sheet missing');
  _record('save_open');
  final close = _elements(_find<AddContentSheet>(_root)!)
      .where(
        (e) =>
            e.widget is SvgIconButton &&
            (e.widget as SvgIconButton).asset == Assets.close,
      )
      .first;
  await _tap(close);
  await _hideIme();
  _require(
    _route() == 'bookmark' &&
        _server.requests.where((r) => r['method'] != 'GET').length ==
            writesBefore,
    'Save close must return without another save/write',
  );
  _record('save_close_no_additional_write', {
    'writeCountBefore': writesBefore,
    'writeCountAfter': _server.requests
        .where((r) => r['method'] != 'GET')
        .length,
  });
  _require(
    _errors.isEmpty &&
        _server.unexpected.isEmpty &&
        _checks.every((c) => (c['unexpectedRequests'] as List).isEmpty),
    'Unexpected HTTP/framework error',
  );
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  e01.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-bookmark-');
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add(details.exceptionAsString());
    old?.call(details);
  };
  await _fresh('list', 0);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('BOOKMARK ready phase=$bookmarkPhase output=${_output.path}');
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
          final kind = request.uri.queryParameters['kind'] ?? 'list',
              offset = double.parse(
                request.uri.queryParameters['offset'] ?? '0',
              );
          _require(
            (kind == 'list' && (offset == 0 || offset == 300)) ||
                (kind == 'empty' && offset == 0),
            'Only frozen list0/list300/empty0 supported',
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
      debugPrint('BOOKMARK FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
