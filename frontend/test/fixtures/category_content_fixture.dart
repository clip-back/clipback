// F01 probes compile against the unchanged baseline. Native evidence uses the
// real root app; the direct host is only for the platform/width widget matrix.
import 'dart:convert';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../support/archive_all_preview.dart' as base;

const categoryContentId = 101;
const categoryContentName = '취업준비';
List<Map<String, Object?>> categoryContentCategories() => [
  for (final c in base.archiveAllCategoryMaps)
    if (c['id'] == categoryContentId)
      {...c, 'name': categoryContentName, 'color': '#64B5F6'}
    else
      {...c},
];
List<Map<String, Object?>> categoryContentRecords() {
  final cats = categoryContentCategories();
  return [
    for (final record in base.archiveAllRecords())
      {
        ...record,
        'categories': [
          cats.first,
          for (final c in record['categories']! as List)
            if ((c as Map)['id'] != categoryContentId)
              cats.firstWhere((x) => x['id'] == c['id']),
        ],
      },
  ];
}

class CategoryContentServer {
  final records = categoryContentRecords();
  final requests = <Map<String, Object?>>[];
  final unexpected = <String>[];
  bool failNextFavorite = false;
  bool failNextFeed = false;
  int writes = 0;
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  late final client = MockClient((r) async {
    final p = r.url.path, q = r.url.queryParameters;
    requests.add({'method': r.method, 'path': p, 'query': q});
    if (p == '/api/v1/auth/refresh') {
      return json({
        'access_token': 'fixture-access',
        'refresh_token': 'fixture-refresh',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
      }, 201);
    }
    if (p == '/api/v1/users/me') {
      return json({
        'id': 1,
        'display_name': 'F01 화면 검증',
        'is_guest': true,
        'email': null,
        'created_at': '2026-10-19T00:00:00Z',
        'linked_providers': <String>[],
      });
    }
    if (p == '/api/v1/users/me/stats') {
      return json({'saved_count': 999, 'reopened_count': 17});
    }
    if (p == '/api/v1/categories') return json(categoryContentCategories());
    if (p == '/api/v1/feed') {
      if (failNextFeed) {
        failNextFeed = false;
        return json({'detail': 'fixture feed failure'}, 503);
      }
      final selected = records.where((r) {
        if (q['category_id'] case final id?) {
          if (!(r['categories']! as List).any(
            (c) => (c as Map)['id'].toString() == id,
          )) {
            return false;
          }
        }
        if (q['is_favorite'] case final favorite?) {
          if (r['is_favorite'] != (favorite == 'true')) {
            return false;
          }
        }
        return '${r['title']} ${r['summary']}'.contains(q['q'] ?? '');
      }).toList();
      if (q['sort'] == 'bookmarked') {
        selected.sort(
          (a, b) => (b['is_favorite'] == true ? 1 : 0).compareTo(
            a['is_favorite'] == true ? 1 : 0,
          ),
        );
      }
      final start = int.tryParse(q['cursor'] ?? '') ?? 0;
      final end = (start + 5).clamp(0, selected.length);
      return json({
        'items': selected.sublist(start, end),
        'next_cursor': end < selected.length ? '$end' : null,
      });
    }
    if (p == '/api/v1/auth/share-credential') {
      return json({
        'share_token': 'fixture-share',
        'expires_at': '2030-10-19T00:00:00Z',
        'user_id': 1,
        'session_id': 1,
      });
    }
    if (p == '/api/v1/metrics/events' || p.endsWith('/view')) {
      return json({}, 201);
    }
    final match = RegExp(
      r'^/api/v1/contents/(\d+)(/favorite|/categories)?$',
    ).firstMatch(p);
    if (match != null) {
      final index = records.indexWhere((r) => r['id'] == int.parse(match[1]!));
      if (index < 0) return json({'detail': 'missing fixture record'}, 404);
      if (r.method == 'DELETE') {
        records.removeAt(index);
        writes++;
        return http.Response('', 204);
      }
      if (r.method == 'PUT' || r.method == 'PATCH') {
        if (failNextFavorite && match[2] == '/favorite') {
          failNextFavorite = false;
          return json({'detail': 'fixture bookmark failure'}, 503);
        }
        final body = jsonDecode(r.body) as Map;
        if (body['is_favorite'] != null) {
          records[index]['is_favorite'] = body['is_favorite'];
        }
        final id = body['category_id'];
        if (id != null) {
          records[index]['categories'] = [
            categoryContentCategories().firstWhere((c) => c['id'] == id),
          ];
        }
        if (body['category_ids'] case final List ids) {
          records[index]['categories'] = [
            for (final id in ids)
              categoryContentCategories().firstWhere((c) => c['id'] == id),
          ];
        }
        writes++;
      }
      return json(records[index]);
    }
    unexpected.add('${r.method} $p');
    return json({'detail': 'unsupported F01 fixture request'}, 501);
  });
}

class CategoryContentHost extends StatefulWidget {
  const CategoryContentHost({
    super.key,
    required this.platform,
    this.name = categoryContentName,
  });
  final TargetPlatform platform;
  final String name;
  @override
  State<CategoryContentHost> createState() => CategoryContentHostState();
}

class CategoryContentHostState extends State<CategoryContentHost> {
  final calls = <String>[];
  late final categories = categoryContentCategories()
      .map(
        (c) =>
            categoryFromApi(ApiCategory.fromJson(Map<String, dynamic>.from(c))),
      )
      .toList();
  late final feed = FeedPage()
    ..initialized = true
    ..hasMore = false
    ..categoryId = categoryContentId
    ..items.addAll(
      categoryContentRecords().map(
        (r) => contentFromApi(
          ApiContent.fromJson(Map<String, dynamic>.from(r)),
          {for (final c in categories) c.id!: c},
          uncategorized: categories.last,
        ),
      ),
    );
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      platform: widget.platform,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    ),
    home: ArchiveScreen(
      activeTab: 0,
      contents: feed.items,
      feed: feed,
      categories: categories,
      bookmarkedIds: const {'api-602'},
      bookmarkedFirst: false,
      randomViewing: false,
      activeCategoryName: widget.name,
      onTabChanged: (_) {},
      onSortChanged: (_) => calls.add('sort'),
      onOpenRandomView: () => calls.add('random'),
      onExitRandomView: () {},
      onClearCategory: () => calls.add('back'),
      onSearch: () => calls.add('search'),
      onOpenCategoryManagement: () => calls.add('management'),
      onOpenContent: (_) => calls.add('detail'),
      onToggleBookmark: (_) => calls.add('bookmark'),
      onChangeContentCategory: (_, __) => calls.add('category'),
      onDeleteContent: (_) => calls.add('delete'),
      onAddCategory: (_) {},
      onUpdateCategory: (_, __) {},
      onDeleteCategory: (_) {},
      onOpenCategory: (_) {},
      onAddLink: ({required String url, category}) async => feed.items.first,
      onAddScreenshot:
          ({required bytes, required String filename, category}) async =>
              feed.items.first,
      onTab: (_) => calls.add('tab'),
    ),
  );
}

List<Element> f01Elements(Element e) => base.archiveAllElements(e);
Element? f01Find<T extends Widget>(Element e) => base.archiveAllFind<T>(e);
Element? f01Key(Element e, String k) =>
    f01Elements(e).where((e) => e.widget.key == ValueKey(k)).firstOrNull;
Rect f01Box(Element e) => base.archiveAllRect(e);
Map<String, double> f01Rect(Rect r) => {
  'left': r.left,
  'top': r.top,
  'right': r.right,
  'bottom': r.bottom,
  'width': r.width,
  'height': r.height,
};
Map<String, Object?>? f01Paragraph(Element root, String text) {
  final e = f01Elements(root)
      .where(
        (e) =>
            e.widget is RichText &&
            ((e.findRenderObject() as RenderParagraph).text.toPlainText() ==
                text),
      )
      .firstOrNull;
  if (e == null) return null;
  final p = e.findRenderObject()! as RenderParagraph,
      s = (p.text as TextSpan).style!;
  return {
    'text': text,
    'bounds': f01Rect(f01Box(e)),
    'fontFamily': s.fontFamily,
    'fontSize': s.fontSize,
    'fontWeight': s.fontWeight?.value,
    'letterSpacing': s.letterSpacing,
    'height': s.height,
    'color': s.color?.toARGB32(),
    'scaledFontSize': p.textScaler.scale(s.fontSize!),
    'maxLines': p.maxLines,
    'overflow': p.overflow.name,
    'didExceedMaxLines': p.didExceedMaxLines,
  };
}

Map<String, Object?> f01Svg(Element e) {
  final w = e.widget as SvgPicture, loader = w.bytesLoader;
  return {
    'asset': loader is SvgAssetLoader ? loader.assetName : null,
    'bounds': f01Rect(f01Box(e)),
    'colorFilter': w.colorFilter.toString(),
  };
}

Map<String, Object?> f01Measure(Element root) {
  final screen = f01Find<ArchiveScreen>(root)!;
  final w = screen.widget as ArchiveScreen;
  final header =
      f01Key(screen, 'category-content-header') ??
      f01Find<CategoryTopBar>(screen)!;
  final toolbar = f01Find<ArchiveToolbar>(screen)!;
  final navigation = f01Find<ClipbackNavigationBar>(screen)!;
  final random = f01Find<RandomReviewButton>(screen)!;
  final visual = f01Key(random, 'category-content-random-visual') ?? random;
  final mq = MediaQuery.of(screen), view = View.of(screen);
  final position = base.archiveAllPosition(screen);
  final cards = f01Elements(
    screen,
  ).where((e) => e.widget is ContentListCard).toList();
  final category = w.categories
      .where((c) => c.id == w.feed?.categoryId)
      .firstOrNull;
  return {
    'frame': f01Rect(f01Box(f01Find<Scaffold>(screen)!)),
    'window': {
      'width': view.physicalSize.width / view.devicePixelRatio,
      'height': view.physicalSize.height / view.devicePixelRatio,
    },
    'textScale': mq.textScaler.scale(16) / 16,
    'safeTop': mq.viewPadding.top,
    'safeBottom': mq.viewPadding.bottom,
    'viewInsetsBottom': mq.viewInsets.bottom,
    'header': f01Rect(f01Box(header)),
    'toolbar': f01Rect(f01Box(toolbar)),
    'navigation': f01Rect(f01Box(navigation)),
    'randomVisual': f01Rect(f01Box(visual)),
    'randomHit': f01Rect(f01Box(random)),
    'headerTitle': f01Paragraph(header, w.activeCategoryName!),
    'randomLabel': f01Paragraph(random, '랜덤 보기'),
    'countLabel': f01Paragraph(toolbar, '불러온 ${w.contents.length}개'),
    'sortLabel': f01Paragraph(toolbar, w.bookmarkedFirst ? '북마크 우선' : '최신순'),
    'headerAssets': [
      for (final e in f01Elements(header))
        if (e.widget is SvgPicture) f01Svg(e),
    ],
    'randomAssets': [
      for (final e in f01Elements(random))
        if (e.widget is SvgPicture) f01Svg(e),
    ],
    'selectedId': w.feed?.categoryId,
    'selectedName': w.activeCategoryName,
    'selectedColor': category?.color.toARGB32(),
    'scrollOffset': position.pixels,
    'maxScrollExtent': position.maxScrollExtent,
    'rows': [
      for (final e in cards)
        {
          'id': (e.widget as ContentListCard).content.id,
          'bounds': f01Rect(f01Box(e)),
          'title': f01Paragraph(e, (e.widget as ContentListCard).content.title),
          'summary': f01Paragraph(
            e,
            (e.widget as ContentListCard).content.summary,
          ),
          'assets': [
            for (final a in f01Elements(e))
              if (a.widget is SvgPicture) f01Svg(a),
          ],
          'categoryNames': (e.widget as ContentListCard).content.categories
              .map((c) => c.name)
              .toList(),
        },
    ],
  };
}

Map<String, Object?> f01Judge(Map<String, Object?> m) {
  final style = <String>[], layout = <String>[], assets = <String>[];
  final header = m['header']! as Map, toolbar = m['toolbar']! as Map;
  void near(Object? a, num b, String name, List<String> list) {
    if (a is! num || (a - b).abs() > .12) list.add('$name: $a != $b');
  }

  void font(
    String key,
    double size,
    int weight,
    double spacing,
    int color,
    double? height,
  ) {
    final p = m[key] as Map?;
    if (p == null) {
      style.add('$key missing');
      return;
    }
    if (p['fontFamily'] != 'Pretendard') style.add('$key fontFamily');
    near(p['fontSize'], size, '$key size', style);
    near(p['scaledFontSize'], size, '$key scaled size', style);
    near(p['fontWeight'], weight, '$key weight', style);
    near(p['letterSpacing'], spacing, '$key spacing', style);
    if (p['height'] != height) {
      style.add('$key height ${p['height']} != $height');
    }
    if (p['color'] != color) style.add('$key color ${p['color']}');
  }

  font('headerTitle', 18, 600, -.45, 0xFF000000, null);
  font('sortLabel', 14, 500, -.35, 0xFF767676, null);
  font('countLabel', 14, 500, -.35, 0xFF767676, null);
  font('randomLabel', 16, 600, -.4, 0xFF1A1A1A, null);
  near(header['height'], 64, 'header height', layout);
  near(toolbar['height'], 52, 'toolbar height', layout);
  near(toolbar['top'], header['bottom'] as num, 'header to toolbar', layout);
  final rows = m['rows']! as List;
  if ((m['scrollOffset']! as num).abs() < .1 && rows.isNotEmpty) {
    near(
      (rows.first as Map)['bounds']['top'],
      toolbar['bottom'] as num,
      'first card start',
      layout,
    );
  }
  final random = m['randomVisual']! as Map, nav = m['navigation']! as Map;
  near(random['right'], (nav['right'] as num) - 16, 'random right', layout);
  near(random['bottom'], (nav['top'] as num) - 16, 'random bottom gap', layout);
  final hit = m['randomHit']! as Map;
  if ((hit['height'] as num) < 44) layout.add('random hit height <44');
  final hs = m['headerAssets']! as List;
  if (!hs.any(
    (a) =>
        (a as Map)['asset'] == Assets.archiveSettings ||
        a['asset'] == 'assets/icons/category-content-settings.svg',
  )) {
    assets.add('header settings original');
  }
  if (!hs.any(
    (a) =>
        (a as Map)['asset'] == Assets.archiveCategoryFolder ||
        a['asset'] == 'assets/icons/category-content-folder.svg',
  )) {
    assets.add('header folder original');
  }
  if ((m['randomAssets']! as List).isEmpty) {
    assets.add('random original SVG missing');
  }
  return {
    'stylePassed': style.isEmpty,
    'layoutPassed': layout.isEmpty,
    'assetPassed': assets.isEmpty,
    'styleFindings': style,
    'layoutFindings': layout,
    'assetFindings': assets,
    'passed': style.isEmpty && layout.isEmpty && assets.isEmpty,
  };
}
