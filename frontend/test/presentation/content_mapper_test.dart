import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ApiContent _content({
  List<ApiCategory> categories = const [],
  String title = '서버 제목',
  DateTime? savedAt,
  String contentType = 'link',
  String source = 'web',
  List<ApiAsset> assets = const [],
}) => ApiContent(
  id: 7,
  categories: categories,
  tags: const ['태그'],
  assets: assets,
  contentType: contentType,
  source: source,
  title: title,
  summary: '서버 요약',
  originalUrl: null,
  isFavorite: true,
  savedAt: savedAt ?? DateTime.utc(2026, 10, 12, 15, 6),
  lastViewedAt: null,
  summaryStatus: 'processing',
);

void main() {
  FeedSnapshot snapshot({int version = 0, Object? error}) => FeedSnapshot(
    items: [_content()],
    categoryId: 2,
    query: 'Flutter',
    isFavorite: true,
    bookmarkedFirst: false,
    nextCursor: 'opaque-cursor',
    initialized: true,
    loading: false,
    hasMore: true,
    error: error,
    version: version,
  );

  test('feed projection retains scroll across data and mutation updates', () {
    final page = FeedPage()..scrollOffset = 325;
    final contents = [contentFromApi(_content(), {})];
    final originalItems = page.items;

    page.project(snapshot(), contents);

    expect(page.items, same(originalItems));
    expect(page.items, contents);
    expect(page.scrollOffset, 325);
    expect(page.categoryId, 2);
    expect(page.query, 'Flutter');
    expect(page.isFavorite, isTrue);
    expect(page.nextCursor, 'opaque-cursor');
    expect(page.initialized, isTrue);
    expect(page.loading, isFalse);
    expect(page.hasMore, isTrue);
  });

  test(
    'feed projection resets scroll once when the repository query resets',
    () {
      final page = FeedPage()..scrollOffset = 325;
      final contents = [contentFromApi(_content(), {})];

      page.project(snapshot(version: 1), contents);
      expect(page.version, 1);
      expect(page.scrollOffset, 0);
      page.scrollOffset = 120;
      page.project(snapshot(version: 1), contents);
      expect(page.scrollOffset, 120);
    },
  );

  test('feed projection carries retry errors and reset remains compatible', () {
    final page = FeedPage();
    const error = ClipbackApiException('Invalid cursor', statusCode: 422);

    page.project(snapshot(version: 3, error: error), []);
    expect(page.error, same(error));
    expect(page.invalidCursor, isTrue);
    page.reset();
    expect(page.version, 4);
    expect(page.items, isEmpty);
    expect(page.error, isNull);
    expect(page.initialized, isFalse);
    expect(page.categoryId, 2);
    expect(page.query, 'Flutter');
  });

  test('category projection preserves default label and server metadata', () {
    final savedAt = DateTime.utc(2026, 10, 12, 12, 3);
    final category = categoryFromApi(
      ApiCategory(
        id: 3,
        name: '미분류',
        color: '#B5BDC3',
        isDefault: true,
        contentCount: 42,
        lastSavedAt: savedAt,
      ),
      mutationLabel: '삭제 중…',
    );

    expect(category.id, 3);
    expect(category.name, catUncategorized.name);
    expect(category.color, const Color(0xFFB5BDC3));
    expect(category.contentCount, 42);
    expect(category.rawLastSavedAt, savedAt);
    expect(category.lastSavedAt, '2026. 10. 12 오후 12:03');
    expect(category.isDeleting, isTrue);
  });

  for (final color in <String?>[null, '#bad', 'nothex']) {
    test('invalid category color $color retains the existing fallback', () {
      final category = categoryFromApi(
        ApiCategory(id: 1, name: '분류', color: color, isDefault: false),
      );

      expect(category.color, AppColors.subSubtle);
      expect(category.lastSavedAt, isNull);
    });
  }

  test('content projection uses reconciled categories and explicit status', () {
    const remote = ApiCategory(
      id: 2,
      name: '이전 분류',
      color: '#123456',
      isDefault: false,
    );
    final current = categoryFromApi(remote).copyWith(name: '변경한 분류');
    final content = contentFromApi(_content(categories: [remote]), {
      2: current,
    }, mutationLabel: '변경 중…');

    expect(content.category, same(current));
    expect(content.categories, [current]);
    expect(content.title, '서버 제목');
    expect(content.summary, '서버 요약');
    expect(content.originalText, '서버 요약');
    expect(content.tags, ['태그']);
    expect(content.bookmarked, isTrue);
    expect(content.summaryStatus, 'processing');
    expect(content.mutationLabel, '변경 중…');
    expect(content.source, '웹 링크');
    expect(content.originalUrl, '');
    expect(content.savedAt, '26.10.12');
    expect(content.savedAtFull, '2026. 10. 12 오후 03:06');
    expect(content.savedAtFullShort, '2026. 10. 12 15:06');
  });

  test('uncategorized fallback and empty title retain display defaults', () {
    const remote = ApiCategory(
      id: 3,
      name: '미분류',
      color: '#B5BDC3',
      isDefault: true,
    );
    final uncategorized = categoryFromApi(remote);
    final content = contentFromApi(
      _content(title: '', savedAt: DateTime.utc(2026, 1, 2, 0, 4)),
      {},
      uncategorized: uncategorized,
    );

    expect(content.category, same(uncategorized));
    expect(content.title, '제목을 추출하지 못한 링크');
    expect(content.savedAt, '26.01.02');
    expect(content.savedAtFull, '2026. 01. 02 오전 12:04');
    expect(contentFromApi(_content(), {}).category, catUncategorized);
  });

  test('screenshot projection preserves assets and summary status', () {
    const asset = ApiAsset(
      id: 4,
      assetType: 'original',
      downloadUrl: '/api/v1/assets/4',
    );
    final assets = [asset];
    final content = contentFromApi(
      _content(contentType: 'screenshot', source: 'screenshot', assets: assets),
      {},
    );
    assets.clear();

    expect(content.isScreenshot, isTrue);
    expect(content.assets, [asset]);
    expect(content.source, '스크린샷');
    expect(content.summaryStatus, 'processing');
  });

  for (final (isGuest, providers, label) in [
    (true, <String>[], '게스트 계정'),
    (false, <String>[], '연동된 계정 없음'),
    (false, ['google', 'apple'], 'google, apple 계정 연동 중'),
  ]) {
    test('user projection keeps provider label $label and server totals', () {
      final user = userFromApi(
        ApiUser(
          id: 1,
          email: null,
          displayName: '사용자',
          isGuest: isGuest,
          createdAt: DateTime.utc(2026, 1, 2),
          linkedProviders: providers,
        ),
        const ApiUserStats(savedCount: 42, reopenedCount: 17),
      );

      expect(user.name, '사용자');
      expect(user.providerLabel, label);
      expect(user.joinedAt, '2026. 01. 02');
      expect(user.savedContentCount, 42);
      expect(user.revisitedContentCount, 17);
      expect(user.appVersion, 'ver. 1.1');
    });
  }

  test('category write color stays lowercase RGB without alpha', () {
    expect(hexFromColor(const Color(0x33059A0F)), '#059a0f');
  });
}
