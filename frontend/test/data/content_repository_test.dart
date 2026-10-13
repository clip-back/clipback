import 'dart:async';
import 'dart:typed_data';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

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
    int limit = 100,
    String? cursor,
  }) {
    final request = (
      query: query,
      categoryId: categoryId,
      favorite: isFavorite,
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

void main() {
  late _Api api;
  late RemoteContentRepository repository;

  setUp(() {
    api = _Api();
    repository = RemoteContentRepository(api);
  });
  tearDown(() => repository.dispose());

  Future<void> seed() async {
    await repository.loadCategories();
    await repository.loadNext(FeedKey.home);
  }

  test(
    'shares the in-flight page request and publishes immutable snapshots',
    () async {
      final response = Completer<ApiFeed>();
      api.onFeed = (_) => response.future;
      final first = repository.loadNext(FeedKey.home);
      final second = repository.loadNext(FeedKey.home);
      expect(identical(first, second), isTrue);
      expect(api.feedRequests.single.limit, 20);
      expect(repository.feed(FeedKey.home).loading, isTrue);
      response.complete(ApiFeed(items: [_item()], nextCursor: 'cursor'));
      await first;
      final snapshot = repository.feed(FeedKey.home);
      expect(snapshot.items.single.id, 1);
      expect(snapshot.nextCursor, 'cursor');
      expect(snapshot.loading, isFalse);
      expect(() => snapshot.items.clear(), throwsUnsupportedError);
      repository.resetFeed(FeedKey.home);
      expect(snapshot.items.single.id, 1);
      expect(repository.feed(FeedKey.home).version, snapshot.version + 1);
    },
  );

  test(
    'filter reset rejects an old result and retains the new cursor owner',
    () async {
      final oldResponse = Completer<ApiFeed>();
      api.onFeed = (request) => request.query == 'new'
          ? Future.value(
              ApiFeed(items: [_item(id: 2)], nextCursor: 'new-cursor'),
            )
          : oldResponse.future;
      final old = repository.loadNext(FeedKey.search);
      repository.configureFeed(FeedKey.search, query: 'new');
      await repository.loadNext(FeedKey.search, reset: true);
      oldResponse.complete(
        ApiFeed(items: [_item(id: 99)], nextCursor: 'old-cursor'),
      );
      await old;
      expect(repository.feed(FeedKey.search).items.single.id, 2);
      expect(repository.feed(FeedKey.search).nextCursor, 'new-cursor');
      expect(repository.feed(FeedKey.search).query, 'new');
    },
  );

  test(
    'empty favorite phase falls through and nonempty pages remain bounded',
    () async {
      repository.configureFeed(FeedKey.archive, bookmarkedFirst: true);
      api.onFeed = (request) async => request.favorite == true
          ? const ApiFeed(items: [])
          : ApiFeed(items: [_item()], nextCursor: 'ordinary-2');
      await repository.loadNext(FeedKey.archive);
      expect(api.feedRequests.map((request) => request.favorite), [
        true,
        false,
      ]);
      expect(repository.feed(FeedKey.archive).hasMore, isTrue);
      expect(repository.feed(FeedKey.archive).nextCursor, 'ordinary-2');
      api.onFeed = (request) async => ApiFeed(items: [_item(id: 2)]);
      await repository.loadNext(FeedKey.archive);
      expect(api.feedRequests.last.cursor, 'ordinary-2');
      expect(api.feedRequests.length, 3);
      expect(repository.feed(FeedKey.archive).items.map((item) => item.id), [
        1,
        2,
      ]);
      expect(repository.feed(FeedKey.archive).hasMore, isFalse);
    },
  );

  test(
    'bookmark failure rolls back only favorite while delayed read keeps fresh text',
    () async {
      await seed();
      final list = Completer<ApiFeed>();
      final write = Completer<ApiContent>();
      api.onFeed = (_) => list.future;
      api.onFavorite = (_, _) => write.future;
      final reading = repository.loadNext(FeedKey.search);
      final handle = repository.beginBookmark(1)!;
      final writing = repository.executeContentMutation(handle);
      list.complete(
        ApiFeed(
          items: [_item(title: 'fresh title', summary: 'fresh summary')],
        ),
      );
      await reading;
      expect(repository.feed(FeedKey.search).items.single.isFavorite, isTrue);
      write.completeError(const ClipbackApiException('failed'));
      expect((await writing).succeeded, isFalse);
      repository.finishContentMutation(handle);
      final updated = repository.feed(FeedKey.search).items.single;
      expect(updated.isFavorite, isFalse);
      expect(updated.title, 'fresh title');
      expect(updated.summary, 'fresh summary');
      expect(repository.contentMutationKind(1), isNull);
    },
  );

  test(
    'successful bookmark overlay outlives its lock until older detail completes',
    () async {
      await seed();
      final delayed = Completer<ApiContent>();
      api.onDetail = (_) => delayed.future;
      final detail = repository.openDetail(repository.currentContent(1)!);
      final reading = repository.refreshDetail(detail);
      final handle = repository.beginBookmark(1)!;
      expect(
        (await repository.executeContentMutation(handle)).succeeded,
        isTrue,
      );
      repository.finishContentMutation(handle);
      delayed.complete(_item(title: 'server title', summary: 'server summary'));
      await reading;
      expect(repository.selectedContent!.isFavorite, isTrue);
      expect(repository.selectedContent!.title, 'server title');
      expect(repository.feed(FeedKey.home).items.single.isFavorite, isTrue);
    },
  );

  test(
    'category failure restores categories without reverting fetched fields',
    () async {
      await seed();
      final write = Completer<ApiContent>();
      api.onContentCategories = (_, _) => write.future;
      final handle = repository.beginContentCategoryChange(1, 2)!;
      final writing = repository.executeContentMutation(handle);
      api.onFeed = (_) async => ApiFeed(
        items: [_item(title: 'new title', summary: 'new summary')],
      );
      await repository.loadNext(FeedKey.search);
      expect(
        repository.feed(FeedKey.search).items.single.categories.single.id,
        2,
      );
      write.completeError(StateError('failed'));
      await writing;
      repository.finishContentMutation(handle);
      final result = repository.feed(FeedKey.search).items.single;
      expect(result.categories.single.id, 1);
      expect(result.title, 'new title');
      expect(result.summary, 'new summary');
    },
  );

  test(
    'delete tombstone prevents an older feed from resurrecting a removed item',
    () async {
      await seed();
      final old = Completer<ApiFeed>();
      api.onFeed = (_) => old.future;
      final reading = repository.loadNext(FeedKey.search);
      final handle = repository.beginContentDelete(1)!;
      expect(
        (await repository.executeContentMutation(handle)).succeeded,
        isTrue,
      );
      repository.finishContentMutation(handle);
      old.complete(ApiFeed(items: [_item()]));
      await reading;
      expect(repository.feed(FeedKey.home).items, isEmpty);
      expect(repository.feed(FeedKey.search).items, isEmpty);
      expect(repository.currentContent(1), isNull);
    },
  );

  test(
    'mutation lock remains held through write-triggered metadata and feed reload',
    () async {
      await seed();
      final handle = repository.beginBookmark(1)!;
      expect(
        (await repository.executeContentMutation(handle)).succeeded,
        isTrue,
      );
      expect(repository.beginContentDelete(1), isNull);
      final categories = Completer<List<ApiCategory>>();
      final list = Completer<ApiFeed>();
      api.onCategories = () => categories.future;
      api.onFeed = (_) => list.future;
      final ticket = repository.beginRefresh();
      final refreshing = repository.refresh(ticket);
      expect(repository.feed(FeedKey.home).loading, isTrue);
      expect(repository.feed(FeedKey.home).items.single.isFavorite, isTrue);
      expect(repository.beginBookmark(1), isNull);
      categories.complete(_categories);
      await Future<void>.delayed(Duration.zero);
      expect(repository.beginBookmark(1), isNull);
      list.complete(ApiFeed(items: [_item(favorite: true)]));
      expect((await refreshing).current, isTrue);
      expect(repository.contentMutationKind(1), ContentMutationKind.bookmark);
      repository.finishContentMutation(handle);
      expect(repository.beginBookmark(1), isNotNull);
    },
  );

  test(
    'successful write is not rolled back when follow-up reads fail',
    () async {
      await seed();
      final handle = repository.beginBookmark(1)!;
      await repository.executeContentMutation(handle);
      api.onCategories = () => Future.error(StateError('metadata unavailable'));
      api.onFeed = (_) => Future.error(StateError('feed unavailable'));
      final result = await repository.refresh(repository.beginRefresh());
      repository.finishContentMutation(handle);
      expect(result.metadataFailed, isTrue);
      expect(repository.currentContent(1)!.isFavorite, isTrue);
      expect(repository.feed(FeedKey.home).error, isA<StateError>());
    },
  );

  test(
    'refresh invalidates older pages before waiting for category metadata',
    () async {
      await seed();
      final old = Completer<ApiFeed>();
      api.onFeed = (_) => old.future;
      final reading = repository.loadNext(FeedKey.search);
      final metadata = Completer<List<ApiCategory>>();
      api.onCategories = () => metadata.future;
      final ticket = repository.beginRefresh();
      final refreshing = repository.refresh(ticket);
      old.complete(ApiFeed(items: [_item(id: 99)]));
      await reading;
      expect(repository.feed(FeedKey.search).items, isEmpty);
      expect(repository.feed(FeedKey.search).loading, isTrue);
      api.onFeed = (_) async => ApiFeed(items: [_item(id: 2)]);
      metadata.complete(_categories);
      await refreshing;
      expect(repository.feed(FeedKey.search).items.single.id, 2);
      expect(repository.feed(FeedKey.home).items.single.id, 2);
    },
  );

  test(
    'category rename overlay retains metadata from concurrent reads',
    () async {
      await seed();
      final write = Completer<ApiCategory>();
      api.onCategoryUpdate = (_, _, _) => write.future;
      final handle = repository.beginCategoryUpdate(
        1,
        name: 'renamed',
        color: '#000000',
      )!;
      final writing = repository.executeCategoryMutation(handle);
      api.onCategories = () async => [
        const ApiCategory(
          id: 1,
          name: 'old',
          color: '#ffffff',
          isDefault: false,
          contentCount: 12,
        ),
        _uncategorized,
      ];
      await repository.loadCategories();
      expect(repository.categories.first.name, 'renamed');
      expect(repository.categories.first.contentCount, 12);
      expect(repository.categoryMutationDeleting(1), isFalse);
      write.completeError(StateError('failed'));
      await writing;
      repository.finishCategoryMutation(handle);
      expect(repository.categories.first.name, '공부');
      expect(
        repository.feed(FeedKey.home).items.single.categories.single.name,
        '공부',
      );
    },
  );

  test(
    'pending category deletion survives concurrent metadata omission and rejects category assignment',
    () async {
      await seed();
      final write = Completer<void>();
      api.onCategoryDelete = (_) => write.future;
      final handle = repository.beginCategoryDelete(1)!;
      final writing = repository.executeCategoryMutation(handle);
      api.onCategories = () async => [_travel, _uncategorized];
      await repository.loadCategories();
      expect(repository.categories.any((item) => item.id == 1), isTrue);
      expect(repository.beginContentCategoryChange(1, 1), isNull);
      write.completeError(StateError('delete failed'));
      await writing;
      repository.finishCategoryMutation(handle);
      expect(repository.categories.any((item) => item.id == 1), isTrue);
      expect(repository.categoryMutationDeleting(1), isNull);
    },
  );

  test(
    'confirmed category deletion normalizes filters and detail and retries failed metadata',
    () async {
      await seed();
      repository.configureFeed(FeedKey.home, categoryId: 1);
      repository.openDetail(repository.currentContent(1)!);
      final handle = repository.beginCategoryDelete(1)!;
      await repository.executeCategoryMutation(handle);
      expect(repository.feed(FeedKey.home).categoryId, isNull);
      expect(repository.selectedContent!.categories.single.id, 3);
      expect(repository.isCategoryDeleted(1), isTrue);
      api.onCategories = () => Future.error(StateError('offline'));
      api.onDetail = (_) => Future.error(StateError('offline'));
      final first = await repository.refresh(repository.beginRefresh());
      expect(first.categoryDetailsRequired, isTrue);
      expect(first.metadataFailed, isTrue);
      repository.finishCategoryMutation(handle);
      expect(repository.beginRefresh().categoryDetailsRequired, isTrue);
      api.onCategories = () async => [_travel, _uncategorized];
      api.onDetail = (_) async => _item(categories: [_uncategorized]);
      final retry = await repository.refresh(repository.beginRefresh());
      expect(retry.metadataFailed, isFalse);
      expect(repository.beginRefresh().categoryDetailsRequired, isFalse);
      expect(repository.categories.any((item) => item.id == 1), isFalse);
    },
  );

  test(
    'account reset ignores old feed, category and mutation results',
    () async {
      await seed();
      final oldFeed = Completer<ApiFeed>();
      final oldCategories = Completer<List<ApiCategory>>();
      final oldWrite = Completer<ApiContent>();
      api.onFeed = (_) => oldFeed.future;
      api.onCategories = () => oldCategories.future;
      api.onFavorite = (_, _) => oldWrite.future;
      final reading = repository.loadNext(FeedKey.search);
      final categories = repository.loadCategories();
      final handle = repository.beginBookmark(1)!;
      final writing = repository.executeContentMutation(handle);
      repository.resetAccount(1);
      oldFeed.complete(ApiFeed(items: [_item()]));
      oldCategories.complete(_categories);
      oldWrite.complete(_item(favorite: true));
      await Future.wait([reading, categories]);
      expect((await writing).stale, isTrue);
      repository.finishContentMutation(handle);
      expect(repository.categories, isEmpty);
      expect(repository.feed(FeedKey.search).items, isEmpty);
      expect(repository.feed(FeedKey.home).items, isEmpty);
      expect(repository.bookmarkedIds, isEmpty);
    },
  );

  test(
    'closing and reopening same detail rejects a previous navigation response',
    () async {
      await seed();
      final old = Completer<ApiContent>();
      api.onDetail = (_) => old.future;
      final first = repository.openDetail(repository.currentContent(1)!);
      final reading = repository.refreshDetail(first);
      repository.closeDetail();
      final second = repository.openDetail(repository.currentContent(1)!);
      expect(repository.isCurrentDetail(first), isFalse);
      expect(repository.isCurrentDetail(second), isTrue);
      old.complete(_item(title: 'stale title'));
      await reading;
      expect(repository.selectedContent!.title, 'original');
      expect(repository.feed(FeedKey.home).items.single.title, 'original');
    },
  );

  test('asset result is rejected after the detail closes', () async {
    await seed();
    final bytes = Completer<Uint8List>();
    api.onAsset = (_) => bytes.future;
    final handle = repository.openDetail(repository.currentContent(1)!);
    final reading = repository.readAsset(handle, 123);
    final assertion = expectLater(
      reading,
      throwsA(isA<ClipbackApiException>()),
    );
    repository.closeDetail();
    bytes.complete(Uint8List.fromList([1, 2]));
    await assertion;
  });

  test(
    'save from a previous account never exposes the result to the new account',
    () async {
      final response = Completer<ApiContent>();
      api.onSave = () => response.future;
      final saving = repository.saveLink(url: 'https://example.com');
      final assertion = expectLater(
        saving,
        throwsA(isA<ClipbackApiException>()),
      );
      repository.resetAccount(1);
      response.complete(_item());
      await assertion;
      expect(repository.feed(FeedKey.home).items, isEmpty);
    },
  );

  test('detail opens record only the existing view and card event', () async {
    await seed();
    repository.recordOpen(repository.currentContent(1)!);
    repository.recordCategoryFilter(2);
    repository.recordOriginalLinkOpened(1);
    await Future<void>.delayed(Duration.zero);
    expect(api.events, ['view:1', 'card:1:1', 'category:2', 'original:1']);
  });

  test('dispose ignores late reads without notifying listeners', () async {
    final response = Completer<ApiFeed>();
    api.onFeed = (_) => response.future;
    var changes = 0;
    repository.addListener(() => changes++);
    final reading = repository.loadNext(FeedKey.home);
    expect(changes, 1);
    repository.dispose();
    // Replace for tearDown; the disposed instance remains owned by this read.
    final disposed = repository;
    repository = RemoteContentRepository(api);
    response.complete(ApiFeed(items: [_item()]));
    await reading;
    expect(changes, 1);
    expect(disposed.feed(FeedKey.home).items, isEmpty);
  });
  test(
    'external receipt refresh preserves viewport and atomically reloads visible pages',
    () async {
      api.onFeed = (request) async => request.cursor == null
          ? ApiFeed(
              items: List.generate(20, (i) => _item(id: i + 1)),
              nextCursor: 'next',
            )
          : ApiFeed(items: List.generate(20, (i) => _item(id: i + 21)));
      await repository.loadNext(FeedKey.search);
      await repository.loadNext(FeedKey.search);
      repository.configureFeed(
        FeedKey.search,
        query: 'kept query',
        categoryId: 1,
      );
      final before = repository.feed(FeedKey.search);
      final second = Completer<ApiFeed>();
      api.onFeed = (request) async => request.cursor == null
          ? ApiFeed(
              items: List.generate(20, (i) => _item(id: i + 100)),
              nextCursor: 'new-next',
            )
          : second.future;
      final ticket = repository.beginRefresh(preserveViewport: true);
      final refresh = repository.refresh(ticket);
      await Future<void>.delayed(Duration.zero);
      expect(
        repository.feed(FeedKey.search).items.map((item) => item.id),
        before.items.map((item) => item.id),
      );
      expect(repository.feed(FeedKey.search).version, before.version);
      second.complete(
        ApiFeed(items: List.generate(20, (i) => _item(id: i + 120))),
      );
      await refresh;
      expect(repository.feed(FeedKey.search).items.length, 40);
      expect(repository.feed(FeedKey.search).version, before.version);
      expect(repository.feed(FeedKey.search).query, 'kept query');
      expect(repository.feed(FeedKey.search).categoryId, 1);
      repository.resetFeed(FeedKey.search);
      expect(
        repository.feed(FeedKey.search).version,
        greaterThan(before.version),
      );
    },
  );
  test('failed external refresh retains previously loaded content', () async {
    api.onFeed = (_) async =>
        ApiFeed(items: [_item()], nextCursor: 'kept-cursor');
    await repository.loadNext(FeedKey.home);
    final before = repository.feed(FeedKey.home);
    api.onFeed = (_) async => throw const ClipbackApiException('offline');
    await repository.refresh(repository.beginRefresh(preserveViewport: true));
    expect(
      repository.feed(FeedKey.home).items.map((item) => item.id),
      before.items.map((item) => item.id),
    );
    expect(repository.feed(FeedKey.home).version, before.version);
    expect(repository.feed(FeedKey.home).error, isNotNull);
    expect(repository.feed(FeedKey.home).initialized, isTrue);
    expect(repository.feed(FeedKey.home).nextCursor, 'kept-cursor');
    api.onFeed = (request) async {
      expect(request.cursor, 'kept-cursor');
      return ApiFeed(items: [_item(id: 2)]);
    };
    await repository.loadNext(FeedKey.home);
    expect(repository.feed(FeedKey.home).items.map((item) => item.id), [1, 2]);
  });
}
