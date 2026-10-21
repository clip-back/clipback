// Independent E01 fixture. All HTTP is intercepted in-process; no provider,
// persistence or production-server success is claimed.
// flutter run -t test/support/archive_all_preview.dart
// --dart-define=ARCHIVE_ALL_PHASE=before|after
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/content_actions.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/paged_content_list.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Isolate retained native share data in this fixture only. IME and the other
// platform channels retain their real messenger and native behavior.
class ArchiveAllShareMessenger extends BinaryMessenger {
  ArchiveAllShareMessenger(this.delegate);
  final BinaryMessenger delegate;
  static const shareChannel = 'com.huturu.app/share';
  static const codec = StandardMethodCodec();
  final namesOnlyCalls = <String>[];
  final unknownShareMethods = <String>[];
  final delegatedChannels = <String>[];
  int revision = 0;
  int get nativeDelegationCount =>
      delegatedChannels.where((channel) => channel == shareChannel).length;

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    if (channel != shareChannel) {
      delegatedChannels.add(channel);
      return delegate.send(channel, message);
    }
    final call = codec.decodeMethodCall(message!);
    namesOnlyCalls.add(call.method);
    final Object? result;
    switch (call.method) {
      case 'getState':
        result = {
          'revision': revision,
          'drafts': <Object>[],
          'receipts': <Object>[],
        };
      case 'blockCredential':
        result = ++revision;
      case 'publishCredential':
        result = (call.arguments as Map)['revision'] == revision;
      case 'presentDraft':
      case 'acknowledgeReceipts':
        result = null;
      default:
        unknownShareMethods.add(call.method);
        return Future.value(
          codec.encodeErrorEnvelope(
            code: 'unsupported_fixture_share_method',
            message: call.method,
          ),
        );
    }
    return Future.value(codec.encodeSuccessEnvelope(result));
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) =>
      delegate.setMessageHandler(channel, handler);

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) async {
    ServicesBinding.instance.channelBuffers.push(
      channel,
      data,
      callback ?? (_) {},
    );
  }
}

ArchiveAllShareMessenger? archiveAllShareMessenger;

class ArchiveAllFixtureBinding extends WidgetsFlutterBinding {
  @override
  BinaryMessenger createBinaryMessenger() {
    final messenger = ArchiveAllShareMessenger(super.createBinaryMessenger());
    archiveAllShareMessenger = messenger;
    return messenger;
  }
}

const archiveAllPhase = String.fromEnvironment(
  'ARCHIVE_ALL_PHASE',
  defaultValue: 'before',
);
const archiveAllIds = [
  'api-601',
  'api-602',
  'api-603',
  'api-604',
  'api-605',
  'api-606',
];
const archiveAllCategoryMaps = <Map<String, Object?>>[
  {
    'id': 101,
    'name': '일상',
    'color': '#5BD89D',
    'is_default': false,
    'content_count': 37,
  },
  {
    'id': 102,
    'name': '여행',
    'color': '#FF6277',
    'is_default': false,
    'content_count': 19,
  },
  {
    'id': 103,
    'name': '개발과 기술의 참고자료',
    'color': '#64B5F6',
    'is_default': false,
    'content_count': 8,
  },
  {
    'id': 104,
    'name': '오래 간직할 공부 기록',
    'color': '#B9AAFF',
    'is_default': false,
    'content_count': 11,
  },
  {
    'id': 105,
    'name': '아주 긴 카테고리 이름도 한 줄 말줄임으로 보존하는 기록',
    'color': '#FFA24B',
    'is_default': false,
    'content_count': 9,
  },
  {
    'id': 106,
    'name': '생각과 새로운 아이디어',
    'color': '#1F5E24',
    'is_default': false,
    'content_count': 4,
  },
  {
    'id': 99,
    'name': '미분류',
    'color': '#B5BDC3',
    'is_default': true,
    'content_count': 2,
  },
];
List<Map<String, Object?>> archiveAllRecords() {
  const membership = [
    [101],
    [101, 102],
    [103, 104, 101],
    [103, 104, 105, 106, 101, 102],
    [105],
    <int>[],
  ];
  const titles = [
    '하루를 정리하는 작은 습관',
    '함께 간직한 두 가지 이야기',
    '두 줄로 감싸는 분류를 모두 보존해요',
    '분류가 많아져도 본문과 날짜가 겹치지 않는 아주 긴 제목을 한 줄로 확인해요',
    '긴 카테고리 이름을 확인해요',
    '아직 분류하지 않은 콘텐츠',
  ];
  return [
    for (var i = 0; i < 6; i++)
      {
        'id': 601 + i,
        'title': titles[i],
        'summary': i == 0
            ? '매일 다시 꺼내 볼 짧은 기록입니다.'
            : '내용을 임의로 바꾸지 않고 전달받은 요약을 보존합니다. 두 줄을 넘어가는 긴 문장도 정해진 공간 안에서 말줄임으로 표시하며 전체 내용은 상세에서 확인합니다.',
        'categories': [
          for (final id in membership[i])
            archiveAllCategoryMaps.firstWhere((c) => c['id'] == id),
        ],
        'tags': [
          {'name': '화면검증'},
        ],
        'assets': <Object>[],
        'content_type': 'link',
        'source': 'web',
        'original_url': 'https://example.invalid/archive-all/${601 + i}',
        'is_favorite': i == 1,
        'saved_at': '2026-10-${17 - i}T12:00:00Z',
        'last_viewed_at': null,
        'summary_status': 'completed',
      },
  ];
}

List<CategoryItem> archiveAllCategories() => archiveAllCategoryMaps
    .map(
      (v) =>
          categoryFromApi(ApiCategory.fromJson(Map<String, dynamic>.from(v))),
    )
    .toList();
List<ContentItem> archiveAllContents() {
  final categories = archiveAllCategories();
  return archiveAllRecords()
      .map(
        (r) => contentFromApi(
          ApiContent.fromJson(Map<String, dynamic>.from(r)),
          {for (final c in categories) c.id!: c},
          uncategorized: categories.last,
        ),
      )
      .toList();
}

class ArchiveAllMemoryStorage extends ApiSessionStorage {
  ApiSession? value = const ApiSession(
    accessToken: 'fixture-access',
    refreshToken: 'fixture-refresh',
    expiresIn: 3600,
    refreshExpiresIn: 86400,
  );
  @override
  Future<ApiSession?> read() async => value;
  @override
  Future<void> write(ApiSession next) async => value = next;
  @override
  Future<void> clear() async => value = null;
}

class ArchiveAllSocialAuth extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders => const [];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => null;
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.authorized;
}

class ArchiveAllServer {
  final records = archiveAllRecords();
  final requests = <Map<String, Object?>>[];
  final unexpected = <String>[];
  int feedVersion = 0;
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  late final client = MockClient((request) async {
    final path = request.url.path;

    requests.add({
      'method': request.method,
      'path': path,
      'query': request.url.queryParameters,
    });
    if (path == '/api/v1/recommendations/weekly') {
      return json({
        'period_start': '2026-10-19T00:00:00Z',
        'period_end': '2026-10-26T00:00:00Z',
        'batch_id': null,
        'generated_at': null,
        'items': <Object>[],
      });
    }
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
        'display_name': '아카이브 화면 검증',
        'is_guest': true,
        'created_at': '2026-10-17T00:00:00Z',
        'linked_providers': <String>[],
      });
    }
    if (path == '/api/v1/users/me/stats') {
      return json({'saved_count': 999, 'reopened_count': 0});
    }
    if (path == '/api/v1/categories') return json(archiveAllCategoryMaps);
    if (path == '/api/v1/feed') {
      final q = request.url.queryParameters;
      final list = records.where((r) {
        if (q['is_favorite'] case final favorite?) {
          if (r['is_favorite'] != (favorite == 'true')) return false;
        }
        if (q['category_id'] case final cat?) {
          if (!(r['categories'] as List).any(
            (c) => (c as Map)['id'].toString() == cat,
          )) {
            return false;
          }
        }
        return '${r['title']} ${r['summary']}'.toLowerCase().contains(
          (q['q'] ?? '').toLowerCase(),
        );
      }).toList();
      return json({'items': list, 'next_cursor': null});
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
        final body = jsonDecode(request.body) as Map;
        records[i] = {...records[i], 'is_favorite': body['is_favorite']};
      }
      return json(records[i]);
    }
    unexpected.add('${request.method} $path');
    return json({'detail': 'Unsupported in-process fixture request'}, 501);
  });
}

// Only the widget matrix uses this direct screen host. Native uses ClipbackApp
// and ArchiveAllServer above, including its real routing/view models.
class ArchiveAllStaticHost extends StatefulWidget {
  const ArchiveAllStaticHost({
    super.key,
    required this.platform,
    this.categoryName,
  });
  final TargetPlatform platform;
  final String? categoryName;
  @override
  State<ArchiveAllStaticHost> createState() => ArchiveAllStaticState();
}

class ArchiveAllStaticState extends State<ArchiveAllStaticHost> {
  late final feed = FeedPage()
    ..initialized = true
    ..hasMore = false
    ..items.addAll(archiveAllContents());
  int tab = 0;
  final calls = <String>[];
  @override
  Widget build(BuildContext context) => MaterialApp(
    scrollBehavior: const AppScrollBehavior(),
    theme: ThemeData(
      useMaterial3: true,
      platform: widget.platform,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.main,
        surface: AppColors.bg,
      ),
      fontFamily: 'Pretendard',
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(maxWidth: phoneWidth),
      ),
    ),
    home: ArchiveScreen(
      activeTab: tab,
      contents: feed.items,
      feed: feed,
      categories: archiveAllCategories(),
      bookmarkedIds: const {'api-602'},
      bookmarkedFirst: false,
      randomViewing: false,
      activeCategoryName: widget.categoryName,
      onTabChanged: (v) => setState(() => tab = v),
      onSortChanged: (_) => calls.add('sort'),
      onOpenRandomView: () {},
      onExitRandomView: () {},
      onClearCategory: () {},
      onSearch: () => calls.add('search'),
      onOpenCategoryManagement: () => calls.add('management'),
      onOpenContent: (_) => calls.add('detail'),
      onToggleBookmark: (_) => calls.add('bookmark'),
      onChangeContentCategory: (_, __) => calls.add('category'),
      onDeleteContent: (_) => calls.add('delete'),
      onAddCategory: (_) {},
      onUpdateCategory: (_, __) {},
      onDeleteCategory: (_) {},
      onAddLink: ({required String url, CategoryItem? category}) async =>
          feed.items.first,
      onAddScreenshot:
          ({
            required Uint8List bytes,
            required String filename,
            CategoryItem? category,
          }) async => feed.items.first,
      onOpenCategory: (_) {},
      onTab: (_) {},
    ),
  );
}

List<Element> archiveAllElements(Element root) {
  final out = <Element>[];
  void visit(Element e) {
    if (e.widget case Offstage(offstage: true)) return;
    out.add(e);
    e.visitChildren(visit);
  }

  visit(root);
  return out;
}

Element? archiveAllFind<T extends Widget>(Element root) =>
    archiveAllElements(root).where((e) => e.widget is T).firstOrNull;
Element? archiveAllKey(Element root, String key) => archiveAllElements(
  root,
).where((e) => e.widget.key == ValueKey<String>(key)).firstOrNull;
Element? archiveAllText(Element root, String text) => archiveAllElements(
  root,
).where((e) => e.widget is Text && (e.widget as Text).data == text).firstOrNull;
Rect archiveAllRect(Element e) {
  final r = e.findRenderObject()! as RenderBox;
  return r.localToGlobal(Offset.zero) & r.size;
}

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
Map<String, Object?> _paragraph(Element e) {
  final p = e.findRenderObject()! as RenderParagraph,
      s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': _rect(archiveAllRect(e)),
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
  final e = root.widget is SvgPicture ? root : archiveAllFind<SvgPicture>(root);
  if (e == null) return {'bounds': _rect(archiveAllRect(root)), 'asset': null};
  final w = e.widget as SvgPicture, loader = w.bytesLoader;
  return {
    'bounds': _rect(archiveAllRect(e)),
    'asset': loader is SvgAssetLoader ? loader.assetName : null,
    'colorFilter': w.colorFilter.toString(),
    'unfiltered': w.colorFilter == null,
  };
}

ScrollPosition archiveAllPosition(Element root) {
  final list = archiveAllFind<PagedContentList>(root)!;
  final e = archiveAllElements(list)
      .where(
        (e) =>
            e.widget is Scrollable &&
            ((e as StatefulElement).state as ScrollableState).position.axis ==
                Axis.vertical,
      )
      .first;
  return ((e as StatefulElement).state as ScrollableState).position;
}

Element? _ancestor(Element child, bool Function(Widget) predicate) {
  Element? result;
  child.visitAncestorElements((e) {
    if (predicate(e.widget)) {
      result = e;
      return false;
    }
    return true;
  });
  return result;
}

Map<String, Object?> archiveAllMeasure(Element root) {
  final screen = archiveAllFind<ArchiveScreen>(root);
  if (screen == null) return {'active': false};
  final sw = screen.widget as ArchiveScreen;
  if (sw.activeTab != 0 || sw.activeCategoryName != null) {
    return {
      'active': false,
      'tab': sw.activeTab,
      'category': sw.activeCategoryName,
    };
  }
  final media = MediaQuery.of(screen),
      rows = <Map<String, Object?>>[],
      styles = <String, Object?>{},
      bounds = <String, Object?>{},
      assets = <String, Object?>{};
  final header =
      archiveAllKey(screen, 'archive-category-header') ??
      archiveAllText(screen, '아카이브')!;
  final headerBox =
      archiveAllKey(screen, 'archive-category-header') ??
      _ancestor(header, (w) => w is SizedBox)!;
  bounds['header'] = _rect(archiveAllRect(headerBox));
  styles['header'] = _paragraph(archiveAllText(headerBox, '아카이브')!);
  final tabs = archiveAllFind<ArchiveTabs>(screen)!,
      tabsOuter = archiveAllKey(screen, 'archive-all-tabs') ?? tabs;
  bounds['tabs'] = _rect(archiveAllRect(tabsOuter));
  bounds['tabsInner'] = _rect(archiveAllRect(tabs));
  for (final name in ['전체보기', '카테고리']) {
    styles['tab:$name'] = _paragraph(archiveAllText(tabs, name)!);
  }
  final toolbar =
      archiveAllKey(screen, 'archive-all-toolbar') ??
      archiveAllFind<ArchiveToolbar>(screen)!;
  bounds['toolbar'] = _rect(archiveAllRect(toolbar));
  final sort = archiveAllFind<ArchiveSortButton>(toolbar)!;
  styles['sort'] = _paragraph(
    archiveAllText(sort, sw.bookmarkedFirst ? '북마크 우선' : '최신순')!,
  );
  styles['count'] = _paragraph(
    archiveAllText(
      toolbar,
      sw.feed == null
          ? '총 ${sw.contents.length}개'
          : '불러온 ${sw.contents.length}개',
    )!,
  );
  assets['sort'] = _asset(sort);
  assets['search'] = _asset(archiveAllKey(screen, 'archive-category-search'));
  assets['settings'] = _asset(
    archiveAllKey(screen, 'archive-manage-categories'),
  );
  final position = archiveAllPosition(screen),
      viewport = archiveAllFind<PagedContentList>(screen)!;
  bounds['viewport'] = _rect(archiveAllRect(viewport));
  for (final card in archiveAllElements(
    screen,
  ).where((e) => e.widget is ContentListCard)) {
    final c = (card.widget as ContentListCard).content;
    final outer = archiveAllKey(card, 'archive-all-card-${c.id}') ?? card;
    final wrap = archiveAllKey(card, 'archive-all-badges-${c.id}');
    final title =
        archiveAllKey(card, 'archive-all-title-${c.id}') ??
        archiveAllText(card, c.title)!;
    final summary =
        archiveAllKey(card, 'archive-all-summary-${c.id}') ??
        archiveAllText(card, c.summary)!;
    final date =
        archiveAllKey(card, 'archive-all-date-${c.id}') ??
        archiveAllText(card, c.savedAt)!;
    final divider =
        archiveAllKey(card, 'archive-all-divider-${c.id}') ??
        archiveAllFind<Divider>(card)!;
    final bookmark =
        archiveAllKey(card, 'list-bookmark-${c.title}') ??
        archiveAllFind<BookmarkActionButton>(card)!;
    final more =
        archiveAllKey(card, 'archive-all-more-${c.id}') ??
        archiveAllElements(card).where((e) => e.widget is SvgIconButton).last;
    final badgeElements = wrap == null
        ? [archiveAllFind<CategoryBadge>(card)!]
        : archiveAllElements(wrap).where((e) => e.widget is Text).toList();
    final badges = <Map<String, Object?>>[];
    for (final e in badgeElements) {
      final text = e.widget is Text ? e : archiveAllFind<Text>(e)!;
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
        'bounds': _rect(archiveAllRect(box)),
        'paragraph': _paragraph(text),
        'fill': _color(decoration.color),
        'expectedFill': _color(category.tint),
        'expectedTextColor': _color(category.deep),
      });
    }
    final cr = archiveAllRect(outer),
        wr = wrap == null
            ? archiveAllRect(badgeElements.first)
            : archiveAllRect(wrap);
    rows.add({
      'id': c.id,
      'title': c.title,
      'summary': c.summary,
      'savedAt': c.savedAt,
      'bookmarked': sw.bookmarkedIds.contains(c.id),
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
      'divider': _rect(archiveAllRect(divider)),
      'dividerAsset': _asset(divider),
      'bookmark': _rect(archiveAllRect(bookmark)),
      'bookmarkAsset': _asset(bookmark),
      'more': _rect(archiveAllRect(more)),
      'moreAsset': _asset(more),
      'fullyInsideViewport':
          archiveAllRect(viewport).inflate(.16).contains(cr.topLeft) &&
          archiveAllRect(viewport).inflate(.16).contains(cr.bottomRight),
      'visible':
          cr.bottom > archiveAllRect(viewport).top &&
          cr.top < archiveAllRect(viewport).bottom,
    });
  }
  return {
    'active': true,
    'tab': sw.activeTab,
    'category': sw.activeCategoryName,
    'feedInitialized': sw.feed?.initialized,
    'feedHasMore': sw.feed?.hasMore,
    'feedVersion': sw.feed?.version,
    'feedIds': sw.contents.map((c) => c.id).toList(),
    'bookmarkedIds': sw.bookmarkedIds.toList()..sort(),
    'bookmarkedFirst': sw.bookmarkedFirst,
    'scrollOffset': position.pixels,
    'maxScrollExtent': position.maxScrollExtent,
    'actualStyles': styles,
    'bounds': bounds,
    'assetGeometry': assets,
    'rows': rows,
    'textScale': media.textScaler.scale(1),
    'viewPaddingTop': media.viewPadding.top,
    'viewPaddingBottom': media.viewPadding.bottom,
    'viewInsetsBottom': media.viewInsets.bottom,
    'logicalSize': '${media.size}',
    'pixelRatio': View.of(screen).devicePixelRatio,
  };
}

Map<String, Object?> archiveAllJudgment(Map<String, Object?> m) {
  final styles = <String>[], layout = <String>[];
  if (m['active'] != true) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'styleFindings': styles,
      'layoutFindings': layout,
    };
  }
  final roles = m['actualStyles'] as Map, b = m['bounds'] as Map;
  void near(Object? actual, num expected, String name) {
    if (actual is! num || (actual - expected).abs() > .17) {
      layout.add('$name: $actual expected $expected');
    }
  }

  void style(Map p, List v, String name) {
    if (p['fontFamily'] != 'Pretendard' ||
        p['fontSize'] != v[0] ||
        p['scaledFontSize'] != v[0] ||
        p['fontWeight'] != v[1] ||
        p['letterSpacing'] != v[2] ||
        p['color'] != v[3] ||
        p['height'] != v[4]) {
      styles.add('$name effective typography differs');
    }
  }

  void asset(Map a, String path, num width, num height, String name) {
    if (a['asset'] != path || a['unfiltered'] != true) {
      styles.add('$name exact asset/filter differs');
    }
    final bounds = a['bounds'] as Map?;
    near(bounds?['width'], width, '$name actual asset width');
    near(bounds?['height'], height, '$name actual asset height');
  }

  final a = m['assetGeometry'] as Map;
  asset(
    a['search'] as Map,
    'assets/icons/archive-search.svg',
    24,
    24,
    'search',
  );
  asset(
    a['settings'] as Map,
    'assets/icons/archive-settings.svg',
    24,
    24,
    'settings',
  );
  asset(
    a['sort'] as Map,
    'assets/icons/archive-all-chevron-down.svg',
    16,
    16,
    'sort chevron',
  );
  style(roles['header'] as Map, [18, 600, -.45, '0xFF000000', null], 'header');
  style(roles['tab:전체보기'] as Map, [
    16,
    600,
    -.4,
    '0xFF1A1A1A',
    null,
  ], 'selected tab');
  style(roles['tab:카테고리'] as Map, [
    16,
    600,
    -.4,
    '0xFF767676',
    null,
  ], 'inactive tab');
  for (final role in ['sort', 'count']) {
    style(roles[role] as Map, [14, 500, -.35, '0xFF767676', null], role);
  }
  near((b['header'] as Map)['height'], 64, 'Header height');
  near((b['tabs'] as Map)['height'], 64, 'Tabs outer height');
  near((b['tabsInner'] as Map)['height'], 52, 'Tabs inner height');
  near((b['toolbar'] as Map)['height'], 52, 'Toolbar height');
  near(
    (b['viewport'] as Map)['top'],
    (m['viewPaddingTop'] as num) + 180,
    'Viewport top after OS/header/tabs/toolbar',
  );
  if (!(roles['count'] as Map)['text'].toString().startsWith('불러온 ')) {
    styles.add('Loaded count must not claim entire account total');
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
ArchiveAllServer _server = ArchiveAllServer();
late Directory _output;
final _errors = <String>[], _checks = <Map<String, Object?>>[];
final _seen = <String>{}, _fullySeen = <String>{};
bool _busy = false, _done = false, _coverage = false;
int _epoch = 0, _pointer = 31000;
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
Future<void> _settle([int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

void _require(bool value, String reason) {
  if (!value) throw StateError(reason);
}

Future<void> _wait(bool Function() check, String why) async {
  for (var i = 0; i < 100; i++) {
    if (check()) return;
    await _settle(2);
  }
  throw StateError(why);
}

Future<void> _tap(Element e) => _tapPoint(archiveAllRect(e).center);

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
  if (archiveAllFind<AddContentSheet>(_root) != null) return 'save';
  if (archiveAllFind<CategoryManagementScreen>(_root) != null) {
    return 'management';
  }
  if (archiveAllFind<SearchScreen>(_root) != null) return 'search';
  if (archiveAllFind<DetailScreen>(_root) != null) return 'detail';
  if (archiveAllFind<ArchiveScreen>(_root) != null) return 'archive';
  if (archiveAllFind<HomeScreen>(_root) != null) return 'home';
  return 'other';
}

Future<void> _fresh(double offset) async {
  _server = ArchiveAllServer();
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: ValueKey(++_epoch),
        sessionStorage: ArchiveAllMemoryStorage(),
        socialAuth: ArchiveAllSocialAuth(),
      ),
    ),
  );
  await _settle(2);
  await _wait(
    () => archiveAllFind<HomeScreen>(_root) != null,
    'Actual app session/home did not initialize',
  );
  (archiveAllFind<HomeScreen>(_root)!.widget as HomeScreen).onOpenArchive();
  await _wait(
    () =>
        archiveAllFind<ArchiveScreen>(_root) != null &&
        (archiveAllFind<ArchiveScreen>(_root)!.widget as ArchiveScreen)
                .feed
                ?.initialized ==
            true,
    'Actual archive feed did not initialize',
  );
  await _hideIme();
  await _settle();
  _requestedOffset = offset;
  final p = archiveAllPosition(_root);
  _require(
    p.maxScrollExtent >= offset,
    'Concrete offset $offset exceeds actual maximum ${p.maxScrollExtent}',
  );
  p.jumpTo(offset);
  await _settle(3);
  _require(
    (p.pixels - offset).abs() < .2,
    'Static concrete offset was not retained',
  );
}

Map<String, Object?> _snapshot() {
  final m = archiveAllMeasure(_root),
      j = archiveAllJudgment(m),
      view = View.of(_capture.currentContext!);
  for (final row in (m['rows'] as List? ?? [])) {
    if (row['visible'] == true) _seen.add(row['id'] as String);
    if (row['fullyInsideViewport'] == true) _fullySeen.add(row['id'] as String);
  }
  return {
    'phase': archiveAllPhase,
    'platform': Platform.operatingSystem,
    'kind': 'archive-all',
    'route': _route(),
    'ready': true,
    'busy': _busy,
    'output': _output.path,
    'logicalSize': '${view.physicalSize / view.devicePixelRatio}',
    'pixelRatio': view.devicePixelRatio,
    'textScale': MediaQuery.textScalerOf(
      archiveAllFind<Scaffold>(_root)!,
    ).scale(1),
    'viewPaddingTop': view.viewPadding.top / view.devicePixelRatio,
    'viewPaddingBottom': view.viewPadding.bottom / view.devicePixelRatio,
    'viewInsetsBottom': view.viewInsets.bottom / view.devicePixelRatio,
    'scrollOffset': 0.0,
    'maxScrollExtent': 0.0,
    ...m,
    ...j,
    'requestedOffset': _requestedOffset,
    'fixedOriginalIds': archiveAllIds,
    'serverAccountSavedCount': 999,
    'serverRecords': _server.records,
    'requests': List.of(_server.requests),
    'unexpectedRequests': List.of(_server.unexpected),
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        archiveAllShareMessenger,
      ),
      'state':
          'In-memory empty drafts/receipts; retained native queue is untouched.',
      'methodCounts': {
        for (final method
            in archiveAllShareMessenger?.namesOnlyCalls.toSet() ?? <String>{})
          method: archiveAllShareMessenger!.namesOnlyCalls
              .where((m) => m == method)
              .length,
      },
      'nativeDelegationCount': archiveAllShareMessenger?.nativeDelegationCount,
      'unknownMethods': List.of(
        archiveAllShareMessenger?.unknownShareMethods ?? <String>[],
      ),
      'argumentsOrCredentialsRecorded': false,
    },
    'frameworkErrors': List.of(_errors),
    'visibleCoverage': _seen.toList()..sort(),
    'fullyVisibleCoverage': _fullySeen.toList()..sort(),
    'scope':
        'Actual ClipbackApp/API/FeedPage/routing with an in-process MockClient and memory-only session. Synthetic pointers/controller input and native IME observation. No external HTTP, real OAuth/provider, production persistence, physical-device or CI proof.',
  };
}

void _record(String scenario, [Map<String, Object?> fields = const {}]) =>
    _checks.add({
      'scenario': scenario,
      'passed': true,
      ..._snapshot(),
      ...fields,
    });
Future<void> _report() async {
  final s = _snapshot();
  final style =
      s['stylePassed'] == true &&
      !_checks.any((c) => c['stylePassed'] == false);
  final layout =
      s['layoutPassed'] == true &&
      _errors.isEmpty &&
      !_checks.any((c) => c['layoutPassed'] == false);
  final behavior =
      _done &&
      archiveAllShareMessenger != null &&
      archiveAllShareMessenger!.nativeDelegationCount == 0 &&
      archiveAllShareMessenger!.unknownShareMethods.isEmpty &&
      _server.unexpected.isEmpty &&
      !_checks.any((c) => c['passed'] == false);
  await File('${_output.path}/report.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      ...s,
      'checksCompleted': _done,
      'coveragePassed': _coverage,
      'stylePassed': style,
      'layoutPassed': layout,
      'behaviorPassed': behavior,
      'passed': _done && _coverage && style && layout && behavior,
      'checks': _checks,
    }),
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
      '${_output.path}/archive_all_scale_1_scroll_${_requestedOffset.toInt()}.png',
    ).writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
  _record('static_scroll_${_requestedOffset.toInt()}');
}

Future<void> _jump(double offset) async {
  final p = archiveAllPosition(_root);
  p.jumpTo(offset.clamp(0, p.maxScrollExtent));
  await _settle(3);
}

Future<void> _dragList() async {
  final p = archiveAllPosition(_root),
      before = p.pixels,
      viewport = archiveAllRect(archiveAllFind<PagedContentList>(_root)!);
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
  _require(p.pixels > before + 1, 'Real list pointer drag did not scroll');
  _record('list_pointer_drag', {
    'offsetBefore': before,
    'offsetAfter': p.pixels,
    'pointerMoves': 8,
  });
}

Future<void> _run() async {
  _done = false;
  _coverage = false;
  _seen.clear();
  _fullySeen.clear();
  await _fresh(0);
  _record('initialized_feed');
  for (final offset in [0.0, 300.0]) {
    await _jump(offset);
    _record('coverage_scroll_${offset.toInt()}');
  }
  // Observe every row fully. Cache-mounted but clipped rows alone do not count.
  final maximum = archiveAllPosition(_root).maxScrollExtent;
  for (var offset = 0.0; offset < maximum; offset += 100) {
    await _jump(offset);
    _record('coverage_step_${offset.toInt()}');
  }
  for (var i = 0; i < 4; i++) {
    final current = archiveAllPosition(_root), extent = current.maxScrollExtent;
    await _jump(extent);
    if ((archiveAllPosition(_root).maxScrollExtent - extent).abs() < .17) break;
  }
  _record('maximum_scroll');
  _coverage = archiveAllIds.every(_fullySeen.contains);
  _require(
    _coverage,
    'Every fixed content row must actually be fully visible across the scroll union',
  );
  _record('required_row_coverage', {
    'expectedIds': archiveAllIds,
    'observedFullyVisibleIds': _fullySeen.toList()..sort(),
  });
  await _jump(0);
  await _dragList();
  await _jump(300);
  final before =
          (archiveAllFind<ArchiveScreen>(_root)!.widget as ArchiveScreen),
      feed = before.feed!,
      ids = before.contents.map((c) => c.id).toList(),
      version = feed.version,
      scroll = archiveAllPosition(_root).pixels;
  final callsBefore = _server.requests
      .where((r) => r['path'] == '/api/v1/feed')
      .length;
  await _tap(archiveAllKey(_root, 'archive-manage-categories')!);
  _require(_route() == 'management', 'Settings must open actual management');
  _record('management_open');
  await _tap(archiveAllKey(_root, 'management-back')!);
  _require(_route() == 'archive', 'Management back must return to archive');
  final returned =
      archiveAllFind<ArchiveScreen>(_root)!.widget as ArchiveScreen;
  _require(
    returned.activeTab == 0 &&
        identical(returned.feed, feed) &&
        feed.version == version &&
        (archiveAllPosition(_root).pixels - scroll).abs() < .2 &&
        jsonEncode(returned.contents.map((c) => c.id).toList()) ==
            jsonEncode(ids),
    'Management return changed actual tab/feed/offset',
  );
  _record('management_return_tab0_offset300', {
    'savedOffset': scroll,
    'returnedOffset': archiveAllPosition(_root).pixels,
    'sameFeedIdentity': true,
    'sameFeedVersion': true,
  });
  await _tap(archiveAllKey(_root, 'archive-category-search')!);
  _require(_route() == 'search', 'Actual search did not open');
  _record('search_open');
  await _tap(archiveAllText(archiveAllFind<SearchScreen>(_root)!, '취소')!);
  await _hideIme();
  _require(
    _route() == 'archive' &&
        (archiveAllPosition(_root).pixels - scroll).abs() < .2,
    'Search return lost archive offset',
  );
  _record('search_return_offset300');
  final visible = archiveAllElements(_root)
      .where(
        (e) =>
            e.widget is ContentListCard &&
            archiveAllRect(e).top >=
                archiveAllRect(archiveAllFind<PagedContentList>(_root)!).top &&
            archiveAllRect(e).bottom <=
                archiveAllRect(archiveAllFind<PagedContentList>(_root)!).bottom,
      )
      .first;
  final selectedId = (visible.widget as ContentListCard).content.id;
  await _tap(
    archiveAllText(visible, (visible.widget as ContentListCard).content.title)!,
  );
  _require(
    _route() == 'detail' &&
        (archiveAllFind<DetailScreen>(_root)!.widget as DetailScreen)
                .content
                .id ==
            selectedId,
    'Card did not open matching actual detail',
  );
  _record('detail_open', {'selectedId': selectedId});
  await _tap(archiveAllKey(_root, 'detail-back')!);
  _require(
    _route() == 'archive' &&
        (archiveAllPosition(_root).pixels - scroll).abs() < .2,
    'Detail return lost archive offset',
  );
  _record('detail_return_offset300');
  final tabs = archiveAllFind<ArchiveTabs>(_root)!;
  await _tap(archiveAllText(tabs, '카테고리')!);
  _require(
    (archiveAllFind<ArchiveScreen>(_root)!.widget as ArchiveScreen).activeTab ==
        1,
    'Category tab failed',
  );
  _record('category_tab');
  await _tap(archiveAllText(archiveAllFind<ArchiveTabs>(_root)!, '전체보기')!);
  _require(
    (archiveAllPosition(_root).pixels - scroll).abs() < .2 &&
        (archiveAllFind<ArchiveScreen>(_root)!.widget as ArchiveScreen)
                .activeTab ==
            0,
    'Tabs return lost offset',
  );
  _record('all_tab_return_offset300');
  _require(
    _server.requests.where((r) => r['path'] == '/api/v1/feed').length ==
        callsBefore,
    'Non-mutating round trips started another feed query',
  );
  await _jump(0);
  var card = archiveAllElements(_root).firstWhere(
    (e) =>
        e.widget is ContentListCard &&
        (e.widget as ContentListCard).content.id == 'api-601',
  );
  final label = (card.widget as ContentListCard).content.title;
  await _tap(archiveAllKey(card, 'list-bookmark-$label')!);
  _require(
    _server.records.first['is_favorite'] == true,
    'Actual bookmark API callback missing',
  );
  _record('bookmark_api_toggle');
  card = archiveAllElements(_root).firstWhere(
    (e) =>
        e.widget is ContentListCard &&
        (e.widget as ContentListCard).content.id == 'api-601',
  );
  await _tap(archiveAllKey(card, 'list-bookmark-$label')!);
  _require(
    _server.records.first['is_favorite'] == false,
    'Bookmark restoration missing',
  );
  _record('bookmark_api_restore');
  card = archiveAllElements(_root).firstWhere(
    (e) =>
        e.widget is ContentListCard &&
        (e.widget as ContentListCard).content.id == 'api-601',
  );
  await _tap(archiveAllKey(card, 'archive-all-more-api-601')!);
  _require(
    archiveAllFind<ContentActionSheet>(_root) != null,
    'Actual content action sheet missing',
  );
  _record('more_open');
  await _hideIme();
  final sheetTop = archiveAllRect(
    archiveAllFind<ContentActionSheet>(_root)!,
  ).top;
  final view = View.of(_capture.currentContext!);
  final safeTop = view.viewPadding.top / view.devicePixelRatio;
  _require(
    sheetTop > safeTop + 4,
    'No safe modal backdrop point for cancellation',
  );
  await _tapPoint(
    Offset(
      view.physicalSize.width / view.devicePixelRatio / 2,
      (safeTop + sheetTop) / 2,
    ),
  );
  _require(
    _route() == 'archive' && _server.records.length == 6,
    'More cancellation changed records',
  );
  _record('more_cancel', {
    'dismissMethod': 'Synthetic pointer tap on the actual modal backdrop.',
  });
  final nav = archiveAllFind<ClipbackNavigationBar>(_root)!;
  final add = archiveAllFind<NavAddButton>(nav)!;
  await _tap(add);
  _require(_route() == 'save', 'Actual save sheet missing');
  _record('save_open');
  final close = archiveAllElements(archiveAllFind<AddContentSheet>(_root)!)
      .where(
        (e) =>
            e.widget is SvgIconButton &&
            (e.widget as SvgIconButton).asset == Assets.close,
      )
      .first;
  await _tap(close);
  await _hideIme();
  _require(_route() == 'archive', 'Save close did not return');
  _record('save_close');
  await _jump(300);
  final sort = archiveAllFind<ArchiveSortButton>(_root)!;
  await _tap(archiveAllText(sort, '최신순')!);
  await _tap(archiveAllText(_root, '북마크 우선')!);
  await _wait(
    () =>
        (archiveAllFind<ArchiveScreen>(_root)!.widget as ArchiveScreen)
            .feed!
            .loading ==
        false,
    'Sort request did not finish',
  );
  await _settle();
  final sorted = archiveAllFind<ArchiveScreen>(_root)!.widget as ArchiveScreen;
  _require(
    sorted.bookmarkedFirst &&
        sorted.contents.first.id == 'api-602' &&
        archiveAllPosition(_root).pixels == 0,
    'Bookmark sort must use server phases and reset scroll',
  );
  final phases = _server.requests
      .where((r) => r['path'] == '/api/v1/feed')
      .map((r) => (r['query'] as Map)['is_favorite'])
      .whereType<String>()
      .toList();
  _require(
    phases.length >= 2 &&
        phases[phases.length - 2] == 'true' &&
        phases.last == 'false',
    'Favorite/non-favorite server phase order changed',
  );
  _record('sort_bookmarked_first_resets_offset', {
    'favoritePhases': phases,
    'resetOffset': archiveAllPosition(_root).pixels,
  });
  await _tap(
    archiveAllText(archiveAllFind<ArchiveSortButton>(_root)!, '북마크 우선')!,
  );
  await _tap(archiveAllText(_root, '최신순')!);
  await _settle();
  _require(
    jsonEncode(
          (archiveAllFind<ArchiveScreen>(_root)!.widget as ArchiveScreen)
              .contents
              .map((c) => c.id)
              .toList(),
        ) ==
        jsonEncode(archiveAllIds),
    'Default server order not restored',
  );
  _record('latest_sort_restores_original_order');
  _require(
    _server.unexpected.isEmpty && _errors.isEmpty,
    'Unexpected API or framework error occurred',
  );
  _done = true;
}

Future<void> main() => http.runWithClient(() async {
  ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp('clipback-archive-all-');
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add(details.exceptionAsString());
    old?.call(details);
  };
  await _fresh(0);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint('ARCHIVE_ALL ready phase=$archiveAllPhase output=${_output.path}');
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
          final offset = double.parse(
            request.uri.queryParameters['offset'] ??
                request.uri.queryParameters['scroll'] ??
                '0',
          );
          _require(
            offset == 0 || offset == 300,
            'Only frozen concrete offsets0/300 supported',
          );
          await _fresh(offset);
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
      debugPrint('ARCHIVE_ALL FAIL $error\n$stack');
      await _report();
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error', ..._snapshot()}));
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
