import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'dart:async';
import 'dart:typed_data';

const _study = ApiCategory(
  id: 1,
  name: '공부',
  color: '#059669',
  isDefault: false,
);
const _travel = ApiCategory(
  id: 2,
  name: '여행',
  color: '#FB7185',
  isDefault: false,
);
const _uncategorized = ApiCategory(
  id: 3,
  name: '미분류',
  color: null,
  isDefault: true,
);
const _categories = [_study, _travel, _uncategorized];

ApiContent _item({
  int id = 1,
  String title = 'original',
  String summary = 'summary',
  bool favorite = false,
  List<ApiCategory> categories = const [_study],
}) => ApiContent(
  id: id,
  categories: categories,
  tags: const ['tag'],
  assets: const [],
  contentType: 'link',
  source: 'web',
  title: title,
  summary: summary,
  originalUrl: 'https://example.com/$id',
  isFavorite: favorite,
  savedAt: DateTime.utc(2026, 10, 12),
  lastViewedAt: null,
);

typedef _FeedRequest = ({
  String? query,
  int? categoryId,
  bool? favorite,
  String? sort,
  String? cursor,
  int limit,
});

class _Api extends ClipbackApi {
  _Api()
    : super(
        client: MockClient(
          (_) => throw StateError('Unexpected transport call'),
        ),
      );

  Future<ApiFeed> Function(_FeedRequest)? onFeed;
  Future<List<ApiCategory>> Function()? onCategories;
  Future<ApiContent> Function(int, bool)? onFavorite;
  Future<ApiContent> Function(int, List<int>)? onContentCategories;
  Future<void> Function(int)? onDelete;
  Future<ApiCategory> Function(int, String?, String?)? onCategoryUpdate;
  Future<void> Function(int)? onCategoryDelete;
  Future<ApiContent> Function(int)? onDetail;
  Future<Uint8List> Function(int)? onAsset;
  Future<ApiContent> Function()? onSave;
  final feedRequests = <_FeedRequest>[];
  final events = <String>[];

  @override
  Future<ApiFeed> readFeed({
    String? query,
    int? categoryId,
    bool? isFavorite,
    String? sort,
    int limit = 100,
    String? cursor,
  }) {
    final request = (
      query: query,
      categoryId: categoryId,
      favorite: isFavorite,
      sort: sort,
      cursor: cursor,
      limit: limit,
    );
    feedRequests.add(request);
    return onFeed?.call(request) ?? Future.value(ApiFeed(items: [_item()]));
  }

  @override
  Future<List<ApiCategory>> listCategories() =>
      onCategories?.call() ?? Future.value(_categories);
  @override
  Future<ApiContent> updateContentFavorite(int contentId, bool favorite) =>
      onFavorite?.call(contentId, favorite) ??
      Future.value(_item(id: contentId, favorite: favorite));
  @override
  Future<ApiContent> updateContentCategories(
    int contentId,
    List<int> categoryIds,
  ) =>
      onContentCategories?.call(contentId, categoryIds) ??
      Future.value(
        _item(
          id: contentId,
          categories: _categories
              .where((item) => categoryIds.contains(item.id))
              .toList(),
        ),
      );
  @override
  Future<void> deleteContent(int contentId) =>
      onDelete?.call(contentId) ?? Future.value();
  @override
  Future<ApiCategory> updateCategory({
    required int categoryId,
    String? name,
    String? color,
    String? submissionKey,
  }) =>
      onCategoryUpdate?.call(categoryId, name, color) ??
      Future.value(
        ApiCategory(
          id: categoryId,
          name: name!,
          color: color,
          isDefault: false,
        ),
      );
  @override
  Future<void> deleteCategory(int categoryId) =>
      onCategoryDelete?.call(categoryId) ?? Future.value();
  @override
  Future<ApiContent> readContent(int contentId) =>
      onDetail?.call(contentId) ?? Future.value(_item(id: contentId));
  @override
  Future<Uint8List> readAsset(int assetId) =>
      onAsset?.call(assetId) ?? Future.value(Uint8List.fromList([1, 2, 3]));
  @override
  Future<ApiContent> createContent({
    required String originalUrl,
    List<int> categoryIds = const [],
    String? title,
    String? summary,
    List<String> tagNames = const [],
    bool isFavorite = false,
    String? submissionKey,
  }) => onSave?.call() ?? Future.value(_item());
  @override
  Future<void> recordContentView(int contentId) async =>
      events.add('view:$contentId');
  @override
  Future<void> createCardClickEvent({
    required int contentId,
    int? categoryId,
  }) async => events.add('card:$contentId:$categoryId');
  @override
  Future<void> createCategoryFilterEvent(int categoryId) async =>
      events.add('category:$categoryId');
  @override
  Future<void> createOriginalLinkOpenedEvent(int contentId) async =>
      events.add('original:$contentId');
}

// #460 배경 목록 다시 읽기(refreshInBackground)의 저장소 계약.
void main() {
  late _Api api;
  late RemoteContentRepository repo;
  List<int> ids(FeedKey key) => repo.feed(key).items.map((x) => x.id).toList();
  List<String> titles(FeedKey key) =>
      repo.feed(key).items.map((x) => x.title).toList();

  setUp(() {
    api = _Api();
    repo = RemoteContentRepository(api);
  });

  test(
    'a pending next page keeps its reply; the background read does not start',
    () async {
      final pending = Completer<ApiFeed>();
      api.onFeed = (r) async => r.cursor == null
          ? ApiFeed(items: [_item()], nextCursor: 'more')
          : pending.future;
      await repo.loadNext(FeedKey.archive);
      final next = repo.loadNext(FeedKey.archive);
      final requests = api.feedRequests.length;
      expect(await repo.refreshInBackground(), isFalse);
      expect(api.feedRequests, hasLength(requests));
      pending.complete(ApiFeed(items: [_item(id: 2)]));
      await next;
      expect(ids(FeedKey.archive), [1, 2]);
    },
  );

  test(
    'an explicit next page during the background read waits and then continues',
    () async {
      await repo.loadNext(FeedKey.archive); // [1], cursor more
      final gate = Completer<ApiFeed>();
      api.onFeed = (r) async {
        if (r.cursor == 'more') return ApiFeed(items: [_item(id: 2)]);
        return gate.future;
      };
      // 첫 쪽 응답에 다음 커서를 남긴다.
      final bg = repo.refreshInBackground();
      await Future<void>.delayed(Duration.zero);
      final next = repo.loadNext(FeedKey.archive);
      await Future<void>.delayed(Duration.zero);
      expect(api.feedRequests.where((r) => r.cursor == 'more'), isEmpty);
      expect(repo.feed(FeedKey.archive).loading, isFalse, reason: '대기 표시 없음');
      gate.complete(
        ApiFeed(
          items: [_item(title: 'new')],
          nextCursor: 'more',
        ),
      );
      expect(await bg, isTrue);
      await next;
      expect(ids(FeedKey.archive), [1, 2]);
      expect(titles(FeedKey.archive).first, 'new');
    },
  );

  test(
    'a category failure applies nothing; the next call applies all',
    () async {
      await repo.loadNext(FeedKey.home);
      api.onFeed = (_) async => ApiFeed(items: [_item(title: 'new')]);
      api.onCategories = () async =>
          throw const ClipbackApiException('down', statusCode: 503);
      expect(await repo.refreshInBackground(), isFalse);
      expect(titles(FeedKey.home), ['original']);
      expect(repo.feed(FeedKey.home).error, isNull);
      expect(repo.feed(FeedKey.home).loading, isFalse);
      api.onCategories = null;
      expect(await repo.refreshInBackground(), isTrue);
      expect(titles(FeedKey.home), ['new']);
      expect(repo.categories.map((c) => c.id), [1, 2, 3]);
    },
  );

  test('one failing list applies nothing to the other lists', () async {
    await repo.loadNext(FeedKey.home);
    await repo.loadNext(FeedKey.archive);
    var call = 0;
    api.onFeed = (_) async {
      if (++call == 2) {
        throw const ClipbackApiException('down', statusCode: 503);
      }
      return ApiFeed(items: [_item(title: 'new')]);
    };
    expect(await repo.refreshInBackground(), isFalse);
    expect(titles(FeedKey.home), ['original']);
    expect(titles(FeedKey.archive), ['original']);
    expect(repo.feed(FeedKey.home).error, isNull);
    expect(repo.feed(FeedKey.archive).error, isNull);
  });

  test('a list showing an error keeps it and is not read', () async {
    await repo.loadNext(FeedKey.home);
    api.onFeed = (r) async =>
        throw const ClipbackApiException('down', statusCode: 503);
    await repo.loadNext(FeedKey.archive);
    final error = repo.feed(FeedKey.archive).error;
    expect(error, isNotNull);
    api.onFeed = (_) async => ApiFeed(items: [_item(title: 'new')]);
    final before = api.feedRequests.length;
    expect(await repo.refreshInBackground(), isTrue);
    expect(api.feedRequests.length, before + 1, reason: '홈만 읽는다');
    expect(repo.feed(FeedKey.archive).error, same(error));
    expect(titles(FeedKey.home), ['new']);
  });

  test(
    'an account change during the read applies nothing to the new account',
    () async {
      await repo.loadNext(FeedKey.home);
      final gate = Completer<ApiFeed>();
      api.onFeed = (_) => gate.future;
      final bg = repo.refreshInBackground();
      await Future<void>.delayed(Duration.zero);
      repo.resetAccount(repo.accountVersion + 1);
      gate.complete(ApiFeed(items: [_item(title: 'old account')]));
      expect(await bg, isFalse);
      expect(repo.feed(FeedKey.home).items, isEmpty);
      expect(repo.feed(FeedKey.home).initialized, isFalse);
    },
  );

  test('a user bookmark change during the read is kept', () async {
    await repo.loadNext(FeedKey.home);
    final gate = Completer<ApiFeed>();
    api.onFeed = (_) => gate.future;
    final bg = repo.refreshInBackground();
    await Future<void>.delayed(Duration.zero);
    final handle = repo.beginBookmark(1)!;
    expect((await repo.executeContentMutation(handle)).succeeded, isTrue);
    repo.finishContentMutation(handle);
    gate.complete(ApiFeed(items: [_item(title: 'new')]));
    expect(await bg, isTrue);
    expect(repo.feed(FeedKey.home).items.single.isFavorite, isTrue);
    expect(titles(FeedKey.home), ['new']);
  });
}
