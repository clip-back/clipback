// Independent E06/142:5097 fixture. Real ClipbackApp routing with in-process
// HTTP/session/share-channel doubles. No external API or persistence proof.
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
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/paged_content_list.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
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
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'archive_all_preview.dart' as e01;

const unclassifiedPhase = String.fromEnvironment(
  'UNCLASSIFIED_PHASE',
  defaultValue: 'before',
);
const unclassifiedIds = [
  'api-701',
  'api-702',
  'api-703',
  'api-704',
  'api-705',
  'api-706',
  'api-707',
  'api-708',
];
const unclassifiedApiId = 99;
const unclassifiedEmptyTitle = '분류가 필요한\n콘텐츠가 없어요';
const unclassifiedEmptyBody = '저장한 콘텐츠가\n모두 정리되어있어요';

List<Map<String, Object?>> unclassifiedCategoryMaps({int count = 8}) => [
  {
    'id': 101,
    'name': '일상',
    'color': '#5BD89D',
    'is_default': false,
    'content_count': 37,
    'last_saved_at': '2026-10-17T09:00:00Z',
  },
  {
    'id': 102,
    'name': '여행',
    'color': '#FF6277',
    'is_default': false,
    'content_count': 19,
    'last_saved_at': '2026-10-16T09:00:00Z',
  },
  {
    'id': 99,
    'name': '미분류',
    'color': '#B5BDC3',
    'is_default': true,
    'content_count': count,
    'last_saved_at': '2026-10-17T08:00:00Z',
  },
];
List<Map<String, Object?>> unclassifiedRecords({bool lastOnly = false}) {
  const titles = [
    '일본 여행 갈 때 참고 사항',
    '일본 여행 가면 꼭 사야하는 쇼핑 리스트',
    '분류하기 전에 다시 읽고 싶은 기록',
    '아주 긴 콘텐츠 제목은 한 줄 안에서 말줄임해도 실제 데이터는 보존합니다',
    '저장해 둔 개발 참고자료',
    '다음 여행을 위한 아이디어',
    '다시 꺼내 볼 공부 기록',
    '마지막까지 빠짐없이 확인할 콘텐츠',
  ];
  return [
    for (var i = 0; i < (lastOnly ? 1 : 8); i++)
      {
        'id': 701 + i,
        'title': titles[i],
        'summary': i == 0
            ? '자소서 쓸 때, 소제목은 필수다. 수백 번의 멘토링을 하며 다양한 이력서를 검토해 왔습니다.'
            : '저장할 때 받은 제목과 요약을 그대로 보존합니다. 두 줄이 넘는 긴 요약도 목록의 정해진 공간 안에서 말줄임으로 표시하고 전체 내용은 상세 화면에서 확인합니다.',
        'categories': <Object>[],
        'tags': [
          {'name': '검증자료'},
        ],
        'assets': <Object>[],
        'content_type': 'link',
        'source': 'web',
        'original_url': 'https://example.invalid/unclassified/${701 + i}',
        'is_favorite': i == 1,
        'saved_at': '2026-10-${17 - i}T12:00:00Z',
        'last_viewed_at': null,
        'summary_status': 'completed',
      },
    {
      'id': 800,
      'title': '이미 분류한 콘텐츠',
      'summary': '빈 미분류는 전체 저장 콘텐츠가 0개라는 의미가 아닙니다.',
      'categories': [unclassifiedCategoryMaps().first],
      'tags': <Object>[],
      'assets': <Object>[],
      'content_type': 'link',
      'source': 'web',
      'original_url': 'https://example.invalid/classified/800',
      'is_favorite': false,
      'saved_at': '2026-10-01T12:00:00Z',
      'last_viewed_at': null,
      'summary_status': 'completed',
    },
  ];
}

// Immutable JSON copy at each observation: later memory writes never rewrite
// earlier report/check evidence. Nonfinite diagnostic numbers remain explicit.
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

class UnclassifiedServer {
  UnclassifiedServer({bool lastOnly = false})
    : records = unclassifiedRecords(lastOnly: lastOnly);
  final List<Map<String, Object?>> records;
  final requests = <Map<String, Object?>>[];
  final unexpected = <String>[];
  bool failNextCategoryWrite = false;
  int categoryAttempts = 0, categorySuccesses = 0;
  int get unclassifiedCount => records.where(_isUnclassified).length;
  bool _isUnclassified(Map<String, Object?> r) =>
      (r['categories'] as List).isEmpty ||
      (r['categories'] as List).every((v) => (v as Map)['id'] == 99);
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
        'display_name': '미분류 화면 검증',
        'is_guest': true,
        'created_at': '2026-10-17T00:00:00Z',
        'linked_providers': <String>[],
      });
    }
    if (path == '/api/v1/users/me/stats') {
      return json({'saved_count': 999, 'reopened_count': 0});
    }
    if (path == '/api/v1/categories') {
      return json(unclassifiedCategoryMaps(count: unclassifiedCount));
    }
    if (path == '/api/v1/feed') {
      final filtered = records.where((r) {
        if (q['category_id'] == '99' && !_isUnclassified(r)) return false;
        if (q['category_id'] != null &&
            q['category_id'] != '99' &&
            !(r['categories'] as List).any(
              (v) => (v as Map)['id'].toString() == q['category_id'],
            )) {
          return false;
        }
        if (q['is_favorite'] != null &&
            r['is_favorite'] != (q['is_favorite'] == 'true')) {
          return false;
        }
        return '${r['title']} ${r['summary']}'.toLowerCase().contains(
          (q['q'] ?? '').toLowerCase(),
        );
      }).toList();
      final cursor = q['cursor'];
      final start = cursor == 'unc-page-2'
          ? 4
          : cursor?.startsWith('all-page-') == true
          ? int.parse(cursor!.substring(9))
          : 0;
      final page = filtered.skip(start).take(4).toList();
      final more = start + page.length < filtered.length;
      final next = more
          ? (q['category_id'] == '99'
                ? 'unc-page-2'
                : 'all-page-${start + page.length}')
          : null;
      call.addAll({
        'returnedIds': page.map((r) => r['id']).toList(),
        'matchingCount': filtered.length,
        'nextCursor': next,
      });
      return json({'items': page, 'next_cursor': more ? 'unc-page-2' : null});
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
      r'^/api/v1/contents/(\d+)(/(favorite|categories))?$',
    ).firstMatch(path);
    if (m != null) {
      final i = records.indexWhere((r) => r['id'] == int.parse(m[1]!));
      if (i < 0) return json({'detail': 'Unknown fixture content'}, 404);
      if (m[3] == 'favorite' && request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map;
        records[i] = {...records[i], 'is_favorite': body['is_favorite']};
      }
      if (m[3] == 'categories' && request.method == 'PUT') {
        categoryAttempts++;
        final body = jsonDecode(request.body) as Map;
        call['categoryIds'] = List.of(body['category_ids'] as List);
        if (failNextCategoryWrite) {
          failNextCategoryWrite = false;
          call['injectedFailure'] = true;
          return json({'detail': 'Fixture category write failed'}, 503);
        }
        categorySuccesses++;
        records[i] = {
          ...records[i],
          'categories': [
            for (final id in body['category_ids'] as List)
              unclassifiedCategoryMaps(
                count: unclassifiedCount,
              ).firstWhere((c) => c['id'] == id),
          ],
        };
      }
      return json(records[i]);
    }
    unexpected.add('${request.method} $path');
    return json({'detail': 'Unsupported in-process fixture request'}, 501);
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
      _key(root, 'unclassified-empty-image-source') ??
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
  final keyed = _key(root, 'unclassified-$role');
  if (keyed != null) return keyed;
  final header = _find<CategoryTopBar>(root);
  if (header == null) return null;
  final old = role == 'back'
      ? Assets.back
      : role == 'search'
      ? Assets.search
      : Assets.more;
  return _elements(header)
      .where(
        (e) =>
            e.widget is SvgIconButton &&
            (e.widget as SvgIconButton).asset == old,
      )
      .firstOrNull;
}

Map<String, Object?> unclassifiedMeasure(Element root) {
  final screen = _find<ArchiveScreen>(root);
  if (screen == null) return {'active': false};
  final sw = screen.widget as ArchiveScreen;
  if (sw.activeCategoryName != catUncategorized.name) {
    return {
      'active': false,
      'category': sw.activeCategoryName,
      'tab': sw.activeTab,
    };
  }
  final media = MediaQuery.of(screen),
      styles = <String, Object?>{},
      bounds = <String, Object?>{},
      assets = <String, Object?>{},
      rows = <Map<String, Object?>>[];
  final header =
      _key(screen, 'unclassified-header') ?? _find<CategoryTopBar>(screen)!;
  final headerText = _text(header, catUncategorized.name)!;
  bounds['header'] = _rect(_box(header));
  styles['header'] = _paragraph(headerText);
  for (final role in ['back', 'search', 'settings']) {
    final control = _headerControl(screen, role);
    assets[role] = _asset(control);
    if (control != null) bounds['${role}Hit'] = _rect(_box(control));
  }
  final nav = _find<ClipbackNavigationBar>(screen)!;
  bounds['navigation'] = _rect(_box(nav));
  final list = _find<PagedContentList>(screen)!;
  bounds['viewport'] = _rect(
    _box(_key(screen, 'unclassified-empty-viewport') ?? list),
  );
  final isEmpty = sw.contents.isEmpty;
  if (isEmpty) {
    final oldPanel = _find<EmptyStatePanel>(screen);
    final title =
        _key(screen, 'unclassified-empty-title') ??
        _elements(screen)
            .where(
              (e) =>
                  e.widget is Text &&
                  (e.widget as Text).data?.contains('분류가 필요한') == true &&
                  e != headerText,
            )
            .firstOrNull;
    final body =
        _key(screen, 'unclassified-empty-body') ??
        (oldPanel == null
            ? null
            : _elements(oldPanel)
                  .where(
                    (e) =>
                        e.widget is Text &&
                        (e.widget as Text).data?.contains('다른 카테고리') == true,
                  )
                  .firstOrNull);
    final group =
        _key(screen, 'unclassified-empty-group') ??
        (oldPanel == null ? null : _find<Column>(oldPanel));
    final image =
        _key(screen, 'unclassified-empty-image') ??
        (oldPanel == null ? null : _find<Image>(oldPanel));
    if (title != null) styles['emptyTitle'] = _paragraph(title);
    if (body != null) styles['emptyBody'] = _paragraph(body);
    if (group != null) bounds['emptyGroup'] = _rect(_box(group));
    if (image != null) {
      bounds['emptyImageSlot'] = _rect(_box(image));
      assets['emptyImage'] = _asset(image);
    }
    bounds['emptyCtaCount'] = oldPanel == null
        ? 0
        : _elements(oldPanel)
              .where(
                (e) => e.widget is OutlinedButton || e.widget is FilledButton,
              )
              .length;
  }
  for (final card in _elements(
    screen,
  ).where((e) => e.widget is ContentListCard)) {
    final c = (card.widget as ContentListCard).content;
    final outer = _key(card, 'archive-all-card-${c.id}') ?? card;
    final title =
        _key(card, 'archive-all-title-${c.id}') ?? _text(card, c.title)!;
    final summary =
        _key(card, 'archive-all-summary-${c.id}') ?? _text(card, c.summary)!;
    final date =
        _key(card, 'archive-all-date-${c.id}') ?? _text(card, c.savedAt)!;
    final divider =
        _key(card, 'archive-all-divider-${c.id}') ?? _find<Divider>(card)!;
    final bookmark = _key(card, 'list-bookmark-${c.title}')!;
    final more =
        _key(card, 'archive-all-more-${c.id}') ??
        _elements(card).where((e) => e.widget is SvgIconButton).last;
    final badge =
        _key(card, 'unclassified-badge-${c.id}') ?? _find<CategoryBadge>(card)!;
    final bt = badge.widget is Text ? badge : _find<Text>(badge)!;
    final badgeBox = badge.widget is Container
        ? badge
        : _ancestor(
            bt,
            (w) => w is Container && w.decoration is BoxDecoration,
          )!;
    final decor = (badgeBox.widget as Container).decoration as BoxDecoration;
    final cr = _box(outer), vp = _box(list);
    rows.add({
      'id': c.id,
      'title': c.title,
      'summary': c.summary,
      'savedAt': c.savedAt,
      'bookmarked': sw.bookmarkedIds.contains(c.id),
      'actualCategoryIds': c.categories.map((v) => v.id).toList(),
      'actualCategoryNames': c.categories.map((v) => v.name).toList(),
      'card': _rect(cr),
      'badge': _rect(_box(badgeBox)),
      'badgeStyle': _paragraph(bt),
      'badgeFill': _color(decor.color),
      'titleStyle': _paragraph(title),
      'summaryStyle': _paragraph(summary),
      'dateStyle': _paragraph(date),
      'divider': _rect(_box(divider)),
      'dividerAsset': _asset(divider),
      'bookmark': _rect(_box(bookmark)),
      'bookmarkAsset': _asset(bookmark),
      'more': _rect(_box(more)),
      'moreAsset': _asset(more),
      'visible': cr.bottom > vp.top && cr.top < vp.bottom,
      'fullyInsideViewport':
          vp.inflate(.17).contains(cr.topLeft) &&
          vp.inflate(.17).contains(cr.bottomRight),
    });
  }
  final position = _position(screen);
  return {
    'active': true,
    'category': sw.activeCategoryName,
    'categoryId': sw.feed?.categoryId,
    'tab': sw.activeTab,
    'empty': isEmpty,
    'feedInitialized': sw.feed?.initialized,
    'feedLoading': sw.feed?.loading,
    'feedError': sw.feed?.error?.toString(),
    'feedHasMore': sw.feed?.hasMore,
    'feedVersion': sw.feed?.version,
    'feedIds': sw.contents.map((c) => c.id).toList(),
    'metadataCategories': [
      for (final c in sw.categories)
        {'id': c.id, 'name': c.name, 'contentCount': c.contentCount},
    ],
    'bookmarkedFirst': sw.bookmarkedFirst,
    'scrollOffset': position?.pixels ?? 0.0,
    'maxScrollExtent': position?.maxScrollExtent ?? 0.0,
    'toolbarCount': _elements(
      screen,
    ).where((e) => e.widget is ArchiveToolbar).length,
    'randomReviewCount': _elements(
      screen,
    ).where((e) => e.widget is RandomReviewButton).length,
    'actualStyles': styles,
    'bounds': bounds,
    'assetGeometry': assets,
    'rows': rows,
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

Map<String, Object?> unclassifiedJudgment(Map<String, Object?> m) {
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
  void near(Object? actual, num expected, String name) {
    if (actual is! num || (actual - expected).abs() > .18) {
      layout.add('$name: $actual expected $expected');
    }
  }

  void style(
    Object? raw,
    List<Object?> v,
    String role, {
    String family = 'Pretendard',
  }) {
    final p = raw as Map?;
    if (p == null ||
        p['fontFamily'] != family ||
        p['fontSize'] != v[0] ||
        p['scaledFontSize'] != v[0] ||
        p['fontWeight'] != v[1] ||
        p['letterSpacing'] != v[2] ||
        p['color'] != v[3] ||
        p['height'] != v[4]) {
      styles.add('$role effective typography differs');
    }
  }

  void asset(Object? raw, String path, num width, num height, String role) {
    final v = raw as Map?;
    if (v == null || v['asset'] != path || v['unfiltered'] != true) {
      styles.add('$role exact source asset/filter differs');
    }
    final r = v?['bounds'] as Map?;
    near(r?['width'], width, '$role rendered slot width');
    near(r?['height'], height, '$role rendered slot height');
  }

  style(roles['header'], [18, 600, -.45, '0xFF000000', null], 'header');
  near((b['header'] as Map)['height'], 64, 'header height');
  near(
    (b['header'] as Map)['top'],
    m['viewPaddingTop'] as num,
    'header OS top',
  );
  asset(a['back'], 'assets/icons/detail-back.svg', 24, 24, 'back');
  asset(a['search'], 'assets/icons/archive-search.svg', 24, 24, 'search');
  asset(a['settings'], 'assets/icons/archive-settings.svg', 24, 24, 'settings');
  final headerLeft = (b['header'] as Map)['left'] as num;
  final backBounds = (a['back'] as Map)['bounds'] as Map?;
  if (backBounds != null) {
    near((backBounds['left'] as num) - headerLeft, 16, 'back visual left');
  }
  final headerTop = (b['header'] as Map)['top'] as num;
  final titleBounds = (roles['header'] as Map)['bounds'] as Map;
  near(
    (titleBounds['top'] as num) + (titleBounds['height'] as num) / 2,
    headerTop + 32.5,
    'header title vertical center',
  );
  for (final role in ['back', 'search', 'settings']) {
    final r = (a[role] as Map)['bounds'] as Map?;
    if (r != null) {
      near(
        (r['top'] as num) + (r['height'] as num) / 2,
        headerTop + 32.5,
        '$role visual vertical center',
      );
    }
  }
  final width = (b['header'] as Map)['width'] as num;
  near(
    ((a['settings'] as Map)['bounds'] as Map?)?['right'],
    headerLeft + width - 16,
    'settings visual right',
  );
  final sr = (a['search'] as Map)['bounds'] as Map?,
      gr = (a['settings'] as Map)['bounds'] as Map?;
  if (sr != null && gr != null) {
    near((gr['left'] as num) - (sr['right'] as num), 16, 'search settings gap');
  }
  near(m['toolbarCount'], 0, 'sort/count toolbar hidden');
  near(m['randomReviewCount'], 0, 'random review hidden');
  final vp = b['viewport'] as Map,
      header = b['header'] as Map,
      nav = b['navigation'] as Map;
  near(
    vp['top'],
    (header['bottom'] as num) + (m['empty'] == true ? 0 : 12),
    'body start',
  );
  near(vp['bottom'], nav['top'] as num, 'body bottom above actual navigation');
  if (m['scaffoldBackground'] != '0xFFF5F5F5') {
    styles.add('Actual scaffold background must retain F5');
  }
  if (m['categoryId'] != 99) {
    layout.add('Actual selected feed must use default-category ID99');
  }
  if (m['empty'] == true) {
    style(
      roles['emptyTitle'],
      [24, 700, -.6, '0xFF1A1A1A', 1.6],
      'empty title',
      family: 'PretendardDetail',
    );
    style(roles['emptyBody'], [16, 500, -.4, '0xFF767676', 1.5], 'empty body');
    if ((roles['emptyTitle'] as Map?)?['text'] != unclassifiedEmptyTitle) {
      styles.add('Empty title must preserve the approved two-line copy');
    }
    if ((roles['emptyBody'] as Map?)?['text'] != unclassifiedEmptyBody) {
      styles.add('Empty body must preserve the approved two-line copy');
    }
    final group = b['emptyGroup'] as Map?,
        image = b['emptyImageSlot'] as Map?,
        title = (roles['emptyTitle'] as Map?)?['bounds'] as Map?,
        body = (roles['emptyBody'] as Map?)?['bounds'] as Map?;
    if (group == null || image == null || title == null || body == null) {
      layout.add('Empty group/image/title/body measurement missing');
    } else {
      near(group['width'], math.min(224, width), 'empty group maximum width');
      if ((group['height'] as num) < 249.8) {
        layout.add('Empty group must retain a250px minimum natural height');
      }
      near(
        (group['left'] as num) + (group['width'] as num) / 2,
        headerLeft + width / 2,
        'empty group horizontal center',
      );
      near(image['width'], 86, 'empty image slot width');
      near(image['height'], 100, 'empty image slot height');
      near(
        (title['top'] as num) - (image['bottom'] as num),
        16,
        'image to title gap',
      );
      near(
        (body['top'] as num) - (title['bottom'] as num),
        8,
        'empty title to body gap',
      );
      // The192px column constrains centered natural-width paragraphs;
      // their actual paragraph bounds need not stretch to192px.
      final textColumnWidth = math.min(192, width);
      final textColumnLeft =
          (group['left'] as num) +
          (group['width'] as num) / 2 -
          textColumnWidth / 2;
      for (final entry in [
        ['title', roles['emptyTitle'] as Map, title],
        ['body', roles['emptyBody'] as Map, body],
      ]) {
        final paragraph = entry[1] as Map, paragraphBounds = entry[2] as Map;
        near(
          paragraph['constraintsMaxWidth'],
          textColumnWidth,
          'empty ${entry[0]} text column maximum width',
        );
        if ((paragraphBounds['width'] as num) > textColumnWidth + .18 ||
            (paragraphBounds['left'] as num) < textColumnLeft - .18 ||
            (paragraphBounds['right'] as num) >
                textColumnLeft + textColumnWidth + .18) {
          layout.add(
            'Empty ${entry[0]} natural paragraph exceeds its actual column',
          );
        }
      }
      final gh = group['height'] as num,
          vpt = vp['top'] as num,
          vpb = vp['bottom'] as num;
      final expected = ((vpt + vpb) / 2 - 84 - gh / 2).clamp(
        vpt,
        math.max(vpt, vpb - gh),
      );
      near(group['top'], expected, 'empty body-center minus84 clamped top');
      if (gh <= vpb - vpt &&
          ((group['top'] as num) < vpt - .18 ||
              (group['bottom'] as num) > vpb + .18)) {
        layout.add('Empty natural group must stay inside actual body viewport');
      }
      final imageData = a['emptyImage'] as Map?,
          r = imageData?['bounds'] as Map?;
      if (imageData?['asset'] != 'assets/figma/unclassified-empty.png') {
        styles.add('Empty exact source PNG missing');
      }
      if (r != null) {
        near(r['width'], 86 * 1.6118, 'empty image raw crop width');
        near(r['height'], 100 * 1.3918, 'empty image raw crop height');
        near(
          (r['left'] as num) - (image['left'] as num),
          86 * -.3072,
          'empty image crop left',
        );
        near(
          (r['top'] as num) - (image['top'] as num),
          100 * -.172,
          'empty image crop top',
        );
      }
    }
    near(b['emptyCtaCount'], 0, 'empty has no CTA');
    if (m['feedInitialized'] != true ||
        m['feedLoading'] != false ||
        m['feedHasMore'] != false ||
        m['feedError'] != null) {
      layout.add(
        'Empty requires confirmed initialized selected-feed zero without loading/error',
      );
    }
  }
  for (final raw in m['rows'] as List) {
    final r = raw as Map,
        id = r['id'],
        cr = r['card'] as Map,
        br = r['badge'] as Map;
    near(cr['height'], 173, '$id base card height');
    near((br['top'] as num) - (cr['top'] as num), 16, '$id badge top');
    near((br['left'] as num) - (cr['left'] as num), 16, '$id badge left');
    near(br['width'], 57, '$id badge width');
    near(br['height'], 22, '$id badge height');
    style(r['badgeStyle'], [12, 500, -.3, '0xFF767676', null], '$id badge');
    if ((r['badgeStyle'] as Map)['text'] != '미분류' ||
        r['badgeFill'] != '0xFFD1D1D1') {
      styles.add(
        '$id visual badge must show 미분류/D1 without changing actual category data',
      );
    }
    if (jsonEncode(r['actualCategoryIds']) != '[99]') {
      layout.add('$id actual model membership99 must remain preserved');
    }
    style(r['titleStyle'], [16, 600, -.4, '0xFF1A1A1A', 1.4], '$id title');
    style(r['summaryStyle'], [
      15,
      400,
      -.375,
      '0xFF484848',
      1.6,
    ], '$id summary');
    style(r['dateStyle'], [14, 400, -.35, '0xFFA9A9A9', null], '$id date');
    final title = r['titleStyle'] as Map,
        summary = r['summaryStyle'] as Map,
        date = r['dateStyle'] as Map;
    if (title['maxLines'] != 1 ||
        title['overflow'] != 'ellipsis' ||
        summary['maxLines'] != 2 ||
        summary['overflow'] != 'ellipsis') {
      layout.add('$id title/summary line policy differs');
    }
    near(
      title['constraintsMaxWidth'],
      math.min(311, (cr['width'] as num) - 40),
      '$id title width',
    );
    near(
      ((title['bounds'] as Map)['top'] as num) - (cr['top'] as num),
      46,
      '$id title top',
    );
    near(
      ((summary['bounds'] as Map)['top'] as num) - (cr['top'] as num),
      72.4,
      '$id summary top',
    );
    near(
      (r['divider'] as Map)['top'],
      (cr['top'] as num) + 127.5,
      '$id divider top',
    );
    near((r['divider'] as Map)['height'], .5, '$id divider height');
    near(
      (cr['bottom'] as num) - ((date['bounds'] as Map)['bottom'] as num),
      16,
      '$id date bottom',
    );
    asset(
      r['dividerAsset'],
      'assets/icons/archive-all-divider.svg',
      (cr['width'] as num) - 40,
      .5,
      '$id divider',
    );
    asset(
      r['moreAsset'],
      'assets/icons/archive-all-more.svg',
      24,
      24,
      '$id more',
    );
    asset(
      r['bookmarkAsset'],
      r['bookmarked'] == true
          ? 'assets/icons/archive-all-star-filled.svg'
          : 'assets/icons/category-card-star.svg',
      28,
      28,
      '$id bookmark',
    );
    near((r['bookmark'] as Map)['height'], 28, '$id bookmark hit28');
    near((r['more'] as Map)['height'], 28, '$id more hit28');
    near(
      (r['bookmark'] as Map)['top'],
      (cr['top'] as num) + 13,
      '$id bookmark top',
    );
    near((r['more'] as Map)['top'], (cr['top'] as num) + 13, '$id more top');
    final mr = (r['moreAsset'] as Map)['bounds'] as Map?,
        star = (r['bookmarkAsset'] as Map)['bounds'] as Map?;
    if (mr != null && star != null) {
      near(mr['right'], (cr['right'] as num) - 16, '$id more right');
      near(
        (mr['left'] as num) - (star['right'] as num),
        16,
        '$id star more gap',
      );
    }
    if (((summary['bounds'] as Map)['bottom'] as num) >
        (r['divider'] as Map)['top'] + .18) {
      layout.add('$id summary overlaps divider');
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
UnclassifiedServer _server = UnclassifiedServer();
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

ArchiveScreen get _screen =>
    _find<ArchiveScreen>(_root)!.widget as ArchiveScreen;
Future<void> _enterFromBanner() async {
  final home = _find<HomeScreen>(_root);
  if (home != null) {
    (home.widget as HomeScreen).onOpenCategories();
    await _settle();
  } else {
    final nav = _find<ClipbackNavigationBar>(_root)!;
    await _tap(_text(nav, '아카이브')!);
    await _wait(
      () => _find<ArchiveScreen>(_root) != null,
      'Archive root did not open',
    );
    await _tap(_text(_find<ArchiveTabs>(_root)!, '카테고리')!);
  }
  await _wait(
    () => _find<UnclassifiedCategoryRow>(_root) != null,
    'Actual positive99 banner missing',
  );
  final banner = _find<UnclassifiedCategoryRow>(_root)!;
  _require(
    (banner.widget as UnclassifiedCategoryRow).count ==
        _server.unclassifiedCount,
    'Actual banner count differs from default-ID99 metadata',
  );
  await _tap(banner);
  await _wait(
    () =>
        _find<ArchiveScreen>(_root) != null &&
        _screen.activeCategoryName == catUncategorized.name &&
        _screen.feed?.initialized == true &&
        _screen.feed?.loading == false,
    'Selected default-category feed did not finish',
  );
  _require(
    _screen.feed?.categoryId == 99,
    'Banner must use actual ID99 rather than fallback null/name',
  );
}

Element _card(String id) => _elements(_root).firstWhere(
  (e) =>
      e.widget is ContentListCard &&
      (e.widget as ContentListCard).content.id == id,
);
Element _more(Element card) =>
    _key(
      card,
      'archive-all-more-${(card.widget as ContentListCard).content.id}',
    ) ??
    _elements(card).where((e) => e.widget is SvgIconButton).last;
Future<void> _changeCategory(String id) async {
  final card = _card(id);
  await _tap(_more(card));
  final actions = _find<ContentActionSheet>(_root)!;
  await _tap(_text(actions, '카테고리 변경')!);
  final sheet = _find<CategoryChangeSheet>(_root)!;
  final tile = _elements(sheet).firstWhere(
    (e) =>
        e.widget is CategoryChangeTile &&
        (e.widget as CategoryChangeTile).category.id == 101,
  );
  await _tap(tile);
  await _wait(
    () =>
        _find<CategoryChangeSheet>(_root) == null &&
        _screen.contents.every((c) => c.mutationLabel == null) &&
        _screen.feed?.loading == false,
    'Category mutation did not settle',
  );
  await _settle(2);
}

Future<void> _jump(double value) async {
  final p = _position(_root);
  if (p == null) {
    _require(value == 0, 'Empty body cannot use nonzero list offset');
    return;
  }
  p.jumpTo(value.clamp(0, p.maxScrollExtent));
  await _settle(3);
}

Future<void> _fresh(String kind, double offset) async {
  _kind = kind;
  _requestedOffset = offset;
  _server = UnclassifiedServer(lastOnly: kind == 'empty');
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
    'Actual session/home did not initialize',
  );
  await _enterFromBanner();
  await _hideIme();
  if (kind == 'empty') {
    await _changeCategory('api-701');
    await _wait(
      () =>
          _screen.feed?.initialized == true &&
          _screen.feed?.loading == false &&
          _screen.contents.isEmpty,
      'Last successful classification did not produce confirmed0 selected feed',
    );
    _require(
      _server.unclassifiedCount == 0 &&
          _server.records.length == 2 &&
          _server.categorySuccesses == 1,
      'Empty must follow one real memory API category success while whole account is nonempty',
    );
    _require(offset == 0, 'Empty only supports offset0');
  } else {
    // Eight records are frozen for both static offsets. Initial first page has
    // four records; actual PagedContentList loading obtains the second page.
    for (var i = 0; i < 8 && _screen.contents.length < 8; i++) {
      final p = _position(_root);
      if (p != null) p.jumpTo(p.maxScrollExtent);
      await _settle();
    }
    await _wait(
      () => _screen.contents.length == 8 && _screen.feed?.loading == false,
      'Four-plus-four real pagination did not finish',
    );
    final p = _position(_root)!;
    _require(
      p.maxScrollExtent >= offset,
      'Frozen concrete offset exceeds actual maximum',
    );
    p.jumpTo(offset);
    await _settle(3);
    _require((p.pixels - offset).abs() < .2, 'Frozen offset not retained');
  }
}

Map<String, Object?> _snapshot() {
  final m = unclassifiedMeasure(_root),
      j = unclassifiedJudgment(m),
      view = View.of(_capture.currentContext!);
  for (final row in m['rows'] as List? ?? []) {
    if (row['visible'] == true) _seen.add(row['id'] as String);
    if (row['fullyInsideViewport'] == true) _fullySeen.add(row['id'] as String);
  }
  final messenger = e01.archiveAllShareMessenger;
  return _copy({
    'phase': unclassifiedPhase,
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
    'fixedOriginalIds': unclassifiedIds,
    'selectedDefaultCategoryId': 99,
    'serverAccountSavedCount': 999,
    'serverUnclassifiedCount': _server.unclassifiedCount,
    'serverRecords': _server.records,
    'requests': _server.requests,
    'unexpectedRequests': _server.unexpected,
    'categoryAttempts': _server.categoryAttempts,
    'categorySuccesses': _server.categorySuccesses,
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        messenger,
      ),
      'state':
          'In-memory empty drafts/receipts; retained native queue is untouched.',
      'methodCounts': {
        for (final name in messenger?.namesOnlyCalls.toSet() ?? <String>{})
          name: messenger!.namesOnlyCalls.where((m) => m == name).length,
      },
      'nativeDelegationCount': messenger?.nativeDelegationCount,
      'unknownMethods': messenger?.unknownShareMethods ?? <String>[],
      'argumentsOrCredentialsRecorded': false,
    },
    'frameworkErrors': _errors,
    'visibleCoverage': _seen.toList()..sort(),
    'fullyVisibleCoverage': _fullySeen.toList()..sort(),
    'scope':
        'Actual ClipbackApp, initialized selected FeedPage ID99, real widget routing and callbacks over in-process MockClient/memory-only session/share isolation. Synthetic pointer actions; native IME remains delegated. No external API, real OAuth/provider, persistence, physical-device or CI proof.',
  });
}

void _record(String scenario, [Map<String, Object?> fields = const {}]) =>
    _checks.add(
      _copy({'scenario': scenario, 'passed': true, ..._snapshot(), ...fields}),
    );
Future<void> _report() async {
  final s = _snapshot();
  final style =
      s['stylePassed'] == true &&
      !_checks.any((c) => c['stylePassed'] == false);
  final layout =
      s['layoutPassed'] == true &&
      _errors.isEmpty &&
      !_checks.any((c) => c['layoutPassed'] == false);
  final messenger = e01.archiveAllShareMessenger;
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
        'stylePassed': style,
        'layoutPassed': layout,
        'behaviorPassed': behavior,
        'coveragePassed': _coverage,
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
      '${_output.path}/unclassified_${_kind}_scale_1_scroll_${_requestedOffset.toInt()}.png',
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
  _seen.clear();
  _fullySeen.clear();
  _checks.clear();
  await _fresh('list', 0);
  final firstRequests = _server.requests
      .where(
        (r) =>
            r['path'] == '/api/v1/feed' &&
            (r['query'] as Map)['category_id'] == '99',
      )
      .toList();
  _require(
    firstRequests.any(
          (r) =>
              (r['query'] as Map)['cursor'] == null &&
              jsonEncode(r['returnedIds']) == '[701,702,703,704]',
        ) &&
        firstRequests.any(
          (r) =>
              (r['query'] as Map)['cursor'] == 'unc-page-2' &&
              jsonEncode(r['returnedIds']) == '[705,706,707,708]',
        ),
    'DefaultID99 must use actual ordered4+4 page queries',
  );
  _require(
    jsonEncode(_screen.contents.map((c) => c.id).toList()) ==
        jsonEncode(unclassifiedIds),
    'Actual selected feed order/membership changed',
  );
  _record('banner_actual_id99_pagination_4_plus_4', {
    'entry': 'Actual positive metadata banner pointer tap',
    'expectedDefaultCategoryId': 99,
    'pageRequests': firstRequests,
  });
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
  _coverage = unclassifiedIds.every(_fullySeen.contains);
  _require(
    _coverage,
    'Every fixed selected-feed row must be fully observed across actual viewport scroll union',
  );
  _record('required_row_coverage', {
    'expectedIds': unclassifiedIds,
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
    'Gear must open actual existing category management',
  );
  _record('management_open');
  await _tap(_key(_root, 'management-back')!);
  _require(
    _route() == 'archive' &&
        _screen.feed?.categoryId == 99 &&
        identical(_screen.feed, feed) &&
        feed.version == version &&
        jsonEncode(_screen.contents.map((c) => c.id).toList()) ==
            jsonEncode(ids) &&
        (_position(_root)!.pixels - savedOffset).abs() < .2,
    'Management return changed defaultID99/feed identity/version/order/offset',
  );
  _record('management_return_selected_feed_offset300', {
    'savedOffset': savedOffset,
    'returnedOffset': _position(_root)!.pixels,
    'sameFeedIdentity': true,
    'sameFeedVersion': true,
  });
  await _tap(_headerControl(_root, 'search')!);
  _require(_route() == 'search', 'Header search did not open actual screen');
  _record('search_open');
  await _tap(_text(_find<SearchScreen>(_root)!, '취소')!);
  await _hideIme();
  _require(
    _route() == 'archive' &&
        _screen.feed?.categoryId == 99 &&
        (_position(_root)!.pixels - savedOffset).abs() < .2,
    'Search return changed selected feed/offset',
  );
  _record('search_return_selected_feed_offset300');
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
    'Card pointer did not open matching detail',
  );
  _record('detail_open', {'selectedId': content.id});
  await _tap(_key(_root, 'detail-back')!);
  _require(
    _route() == 'archive' &&
        _screen.feed?.categoryId == 99 &&
        (_position(_root)!.pixels - savedOffset).abs() < .2,
    'Detail return changed selected feed/offset',
  );
  _record('detail_return_selected_feed_offset300');
  await _jump(0);
  final favoriteBefore = _server.records.first['is_favorite'],
      favoriteCalls = _server.requests
          .where(
            (r) =>
                r['method'] == 'PUT' &&
                r['path'] == '/api/v1/contents/701/favorite',
          )
          .length;
  await _tap(
    _key(
      _card('api-701'),
      'list-bookmark-${(_card('api-701').widget as ContentListCard).content.title}',
    )!,
  );
  await _wait(
    () =>
        _server.records.first['is_favorite'] != favoriteBefore &&
        _screen.contents.every((c) => c.mutationLabel == null),
    'Bookmark write did not finish',
  );
  _require(
    _server.requests
            .where(
              (r) =>
                  r['method'] == 'PUT' &&
                  r['path'] == '/api/v1/contents/701/favorite',
            )
            .length ==
        favoriteCalls + 1,
    'Bookmark pointer must dispatch exactly one API callback',
  );
  _record('bookmark_api_toggle_once');
  await _tap(
    _key(
      _card('api-701'),
      'list-bookmark-${(_card('api-701').widget as ContentListCard).content.title}',
    )!,
  );
  await _wait(
    () =>
        _server.records.first['is_favorite'] == favoriteBefore &&
        _screen.contents.every((c) => c.mutationLabel == null),
    'Bookmark restoration did not finish',
  );
  _require(
    _server.requests
            .where(
              (r) =>
                  r['method'] == 'PUT' &&
                  r['path'] == '/api/v1/contents/701/favorite',
            )
            .length ==
        favoriteCalls + 2,
    'Bookmark restoration must dispatch one callback',
  );
  _record('bookmark_api_restore_once');
  final beforeCancel = jsonEncode(_server.records);
  await _tap(_more(_card('api-701')));
  _require(
    _find<ContentActionSheet>(_root) != null,
    'Actual content action sheet missing',
  );
  _record('more_open');
  await _dismissContentActions();
  _require(
    jsonEncode(_server.records) == beforeCancel,
    'More cancellation changed content metadata',
  );
  _record('more_cancel_preserves_records');
  _server.failNextCategoryWrite = true;
  final attemptBefore = _server.categoryAttempts;
  await _changeCategory('api-701');
  _require(
    _server.categoryAttempts == attemptBefore + 1 &&
        _server.categorySuccesses == 0 &&
        _server.unclassifiedCount == 8 &&
        _screen.contents.any((c) => c.id == 'api-701' && c.category.id == 99) &&
        jsonEncode(_server.records) == beforeCancel,
    'Failed classification must preserve original membership/data and remain on selected list',
  );
  _record('classification_failure_preserves_membership', {
    'injectedFailure':
        'Memory MockClient503; no real server failure was induced.',
    'callbackAttempts': 1,
  });
  await _changeCategory('api-701');
  await _wait(
    () =>
        !_screen.contents.any((c) => c.id == 'api-701') &&
        _screen.feed?.loading == false,
    'Successful classification did not leave default feed',
  );
  _require(
    _server.categoryAttempts == attemptBefore + 2 &&
        _server.categorySuccesses == 1 &&
        _server.unclassifiedCount == 7 &&
        (_server.records.first['categories'] as List).single['id'] == 101,
    'Retry must commit actual selected category once',
  );
  _record('classification_retry_success_removes_row', {
    'callbackAttempts': 2,
    'successfulWrites': 1,
    'remainingUnclassified': 7,
  });
  // Independent last-one seed deliberately ends in a confirmed selected-feed0;
  // saved account records remain nonempty. Earlier checks own deep snapshots.
  await _fresh('empty', 0);
  _record('last_one_classified_confirmed_empty', {
    'lastWriteSuccessCount': _server.categorySuccesses,
    'accountRecordsRemain': _server.records.length,
    'selectedFeedConfirmedZero': true,
  });
  await _tap(_headerControl(_root, 'settings')!);
  _require(
    _route() == 'management',
    'Empty gear must keep existing management destination',
  );
  await _tap(_key(_root, 'management-back')!);
  _require(
    _route() == 'archive' &&
        _screen.contents.isEmpty &&
        _screen.feed?.categoryId == 99,
    'Empty management return lost confirmed selected zero',
  );
  _record('empty_management_return');
  await _tap(_headerControl(_root, 'back')!);
  _require(
    _route() == 'archive' &&
        _screen.activeCategoryName == null &&
        _screen.activeTab == 1 &&
        _find<UnclassifiedCategoryRow>(_root) == null,
    'Confirmed0 must return to categories without positive banner',
  );
  _record('empty_back_to_categories_banner_absent', {
    'metadataDefaultCount': _server.unclassifiedCount,
    'actualPositiveBannerCount': _elements(
      _root,
    ).where((e) => e.widget is UnclassifiedCategoryRow).length,
    'actualDefaultCategoryContentCount': _screen.categories
        .firstWhere((c) => c.id == 99)
        .contentCount,
  });
  final expectedRoutes = {
    '홈': 'home',
    '아카이브': 'archive',
    '즐겨찾기': 'bookmark',
    '마이': 'my',
  };
  for (final item in expectedRoutes.entries) {
    final nav = _find<ClipbackNavigationBar>(_root)!;
    final before = _route();
    await _tap(_text(nav, item.key)!);
    _require(
      _route() == item.value,
      'Root tab ${item.key} opened wrong actual destination',
    );
    _record('root_tab_${item.value}', {
      'routeBefore': before,
      'routeAfter': _route(),
      'expectedRoute': item.value,
    });
  }
  await _tap(_text(_find<ClipbackNavigationBar>(_root)!, '아카이브')!);
  _require(_route() == 'archive', 'Root archive did not return');
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
  _require(_route() == 'archive', 'Save close did not return actual archive');
  _record('save_close');
  _require(
    _server.unexpected.isEmpty &&
        _errors.isEmpty &&
        _checks.every((c) => (c['unexpectedRequests'] as List).isEmpty),
    'Unexpected API/framework error observed',
  );
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  e01.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-unclassified-');
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add(details.exceptionAsString());
    old?.call(details);
  };
  await _fresh('list', 0);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'UNCLASSIFIED ready phase=$unclassifiedPhase output=${_output.path}',
  );
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
          final raw = request.uri.queryParameters['kind'] ?? 'list';
          final kind = raw == 'normal' ? 'list' : raw;
          final offset = double.parse(
            request.uri.queryParameters['offset'] ??
                request.uri.queryParameters['scroll'] ??
                '0',
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
      debugPrint('UNCLASSIFIED FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
