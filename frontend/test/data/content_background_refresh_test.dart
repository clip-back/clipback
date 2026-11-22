import 'dart:async';

import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/features/content/view_models/detail_view_model.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

// #460 배경 목록 다시 읽기(refreshInBackground)의 저장소 계약.

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
  bool favorite = false,
}) => ApiContent(
  id: id,
  categories: const [_study],
  tags: const ['tag'],
  assets: const [],
  contentType: 'link',
  source: 'web',
  title: title,
  summary: 'summary',
  originalUrl: 'https://example.com/$id',
  isFavorite: favorite,
  savedAt: DateTime.utc(2026, 10, 12),
  lastViewedAt: null,
);

typedef _FeedRequest = ({String? query, String? cursor});

// 이 시험이 쓰는 목록·카테고리·즐겨찾기·상세 읽기만 답한다. 그 밖의 호출은 전송 단계에서 실패한다.
class _Api extends ClipbackApi {
  _Api()
    : super(
        client: MockClient(
          (_) => throw StateError('Unexpected transport call'),
        ),
      );

  Future<ApiFeed> Function(_FeedRequest)? onFeed;
  Future<List<ApiCategory>> Function()? onCategories;
  Future<ApiContent> Function(int)? onDetail;
  final feedRequests = <_FeedRequest>[];

  Future<ApiFeed> _feed(String? query, String? cursor) {
    final request = (query: query, cursor: cursor);
    feedRequests.add(request);
    return onFeed?.call(request) ?? Future.value(ApiFeed(items: [_item()]));
  }

  @override
  Future<ApiFeed> readFeed({
    String? query,
    int? categoryId,
    bool? isFavorite,
    String? sort,
    int limit = 100,
    String? cursor,
  }) => _feed(query, cursor);

  @override
  Future<ApiFeed> readFeedStrict({
    String? query,
    int? categoryId,
    bool? isFavorite,
    String? sort,
    int limit = 100,
    String? cursor,
  }) => _feed(query, cursor);

  @override
  Future<List<ApiCategory>> listCategories() =>
      onCategories?.call() ?? Future.value(_categories);
  @override
  Future<ApiContent> updateContentFavorite(int contentId, bool favorite) =>
      Future.value(_item(id: contentId, favorite: favorite));
  @override
  Future<ApiContent> readContent(int contentId) =>
      onDetail?.call(contentId) ?? Future.value(_item(id: contentId));
}

class _Actions extends Fake implements ContentActions {}

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

  group('settled lists', () {
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
      'an explicit next page during the background read cancels it and continues at once',
      () async {
        api.onFeed = (_) async => ApiFeed(items: [_item()], nextCursor: 'more');
        await repo.loadNext(FeedKey.archive);
        final gate = Completer<ApiFeed>();
        api.onFeed = (r) async {
          if (r.cursor == 'more') return ApiFeed(items: [_item(id: 2)]);
          return gate.future;
        };
        final bg = repo.refreshInBackground();
        await Future<void>.delayed(Duration.zero);
        await repo.loadNext(FeedKey.archive);
        expect(api.feedRequests.where((r) => r.cursor == 'more'), hasLength(1));
        expect(ids(FeedKey.archive), [1, 2]);
        gate.complete(ApiFeed(items: [_item(title: 'new')]));
        expect(await bg, isFalse);
        expect(ids(FeedKey.archive), [1, 2]);
        expect(titles(FeedKey.archive).first, 'original');
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
      await bg;
      final item = repo.feed(FeedKey.home).items.single;
      expect(item.isFavorite, isTrue);
    });
  });

  // 최종 검수(.utmp/review-460-final.md) 재현. 원본: .utmp/review-460-final-check/race_test.dart 등.
  group('final review', () {
    setUp(() async => repo.loadNext(FeedKey.home));

    // Spec 1: 배경 조회끼리는 최신 진입이 이전 조회를 대체한다.
    test(
      'a newer background read replaces an older one still waiting',
      () async {
        final gates = <Completer<ApiFeed>>[];
        api.onFeed = (_) {
          final gate = Completer<ApiFeed>();
          gates.add(gate);
          return gate.future;
        };
        final older = repo.refreshInBackground();
        await Future<void>.delayed(Duration.zero);
        final newer = repo.refreshInBackground();
        await Future<void>.delayed(Duration.zero);
        expect(gates, hasLength(2), reason: '진입마다 GET');
        gates[1].complete(ApiFeed(items: [_item(title: 'done')]));
        expect(await newer, isTrue);
        gates[0].complete(ApiFeed(items: [_item(title: 'pending')]));
        expect(await older, isFalse);
        expect(titles(FeedKey.home), ['done']);
      },
    );

    // Spec 2(D4): 검수 원본 'old loadNext must not initialize a new account'의 reads==1 단언은
    // 대기 구조를 전제한다. D1에서는 사용자 GET이 계정 교체 전에 나가므로 같은 보호를 X1로 본다.
    test(
      'X1 nothing from before an account reset reaches the new account',
      () async {
        api.onFeed = (_) async => ApiFeed(items: [_item()], nextCursor: 'more');
        await repo.loadNext(FeedKey.home, reset: true);
        final gate = Completer<ApiFeed>();
        var afterReset = false;
        final sentAfterReset = <String?>[];
        api.onFeed = (r) {
          if (afterReset) sentAfterReset.add(r.cursor);
          return r.cursor == null && !afterReset
              ? gate.future
              : Future.value(ApiFeed(items: [_item(id: 200)]));
        };
        final bg = repo.refreshInBackground();
        final next = repo.loadNext(FeedKey.home);
        repo.resetAccount(10);
        afterReset = true;
        gate.complete(ApiFeed(items: [_item()], nextCursor: 'more'));
        await bg;
        await next;
        await Future<void>.delayed(Duration.zero);
        expect(sentAfterReset, isEmpty);
        expect(repo.feed(FeedKey.home).items, isEmpty);
      },
    );

    test(
      'old account must not send a continuation with the old cursor',
      () async {
        api.onFeed = (_) async => ApiFeed(items: [_item(), _item(id: 2)]);
        await repo.loadNext(FeedKey.home, reset: true);
        final gate = Completer<ApiFeed>();
        final cursors = <String?>[];
        api.onFeed = (r) {
          cursors.add(r.cursor);
          return r.cursor == null
              ? gate.future
              : Future.value(ApiFeed(items: [_item(id: 200)]));
        };
        final bg = repo.refreshInBackground();
        repo.resetAccount(20);
        gate.complete(ApiFeed(items: [_item()], nextCursor: 'old-cursor'));
        expect(await bg, isFalse);
        expect(cursors, [null]);
      },
    );

    test(
      'resetting filter must not combine new query with old cursor',
      () async {
        repo.configureFeed(FeedKey.search, query: 'old');
        api.onFeed = (_) async => ApiFeed(items: [_item(), _item(id: 2)]);
        await repo.loadNext(FeedKey.search);
        final wait = Completer<ApiFeed>();
        final crossed = <String>[];
        api.onFeed = (r) async {
          if (r.query == 'old') return wait.future;
          if (r.query == 'new' && r.cursor != null) crossed.add(r.cursor!);
          return ApiFeed(items: [_item()]);
        };
        final bg = repo.refreshInBackground();
        repo.configureFeed(FeedKey.search, query: 'new');
        await repo.loadNext(FeedKey.search, reset: true);
        wait.complete(ApiFeed(items: [_item()], nextCursor: 'old-cursor'));
        expect(await bg, isFalse);
        expect(crossed, isEmpty);
      },
    );

    // Spec 3: 상세 다음 이동이 배경 조회와 겹쳐도 다음 콘텐츠를 연다.
    test(
      'next from the last detail after the background page gains a new first row',
      () async {
        api.onFeed = (_) async => ApiFeed(
          items: [for (var i = 1; i <= 20; i++) _item(id: i)],
          nextCursor: 'more',
        );
        await repo.loadNext(FeedKey.archive);
        final list = FeedViewModel(repo, FeedKey.archive);
        final detail = DetailViewModel(repo, _Actions());
        final gate = Completer<ApiFeed>();
        api.onFeed = (r) => r.cursor == null
            ? gate.future
            : Future.value(ApiFeed(items: [_item(id: 20), _item(id: 21)]));
        final bg = repo.refreshInBackground();
        detail.open(
          list.page.items.last,
          source: FeedKey.archive,
          sourcePage: list.page,
          recordView: false,
        );
        final next = detail.move(1);
        expect(detail.moving, isTrue);
        gate.complete(
          ApiFeed(
            items: [
              _item(id: 99),
              for (var i = 1; i <= 19; i++) _item(id: i),
            ],
            nextCursor: 'new',
          ),
        );
        await bg;
        await next;
        expect(detail.content?.apiId, 21);
      },
    );

    // Spec 4
    test(
      'background categories must not supersede a user category read',
      () async {
        final gate = Completer<ApiCategory>();
        var reads = 0;
        api.onCategories = () async =>
            ++reads == 1 ? [await gate.future] : [_travel];
        final user = repo.readCurrentCategories();
        final bg = repo.refreshInBackground();
        expect(await bg, isTrue);
        gate.complete(_study);
        expect((await user).categories.single.id, 1);
      },
    );

    test(
      'a user category read started during the background read wins',
      () async {
        final gate = Completer<List<ApiCategory>>();
        var reads = 0;
        api.onCategories = () =>
            ++reads == 1 ? gate.future : Future.value(const [_travel]);
        final bg = repo.refreshInBackground();
        await Future<void>.delayed(Duration.zero);
        final user = repo.readCurrentCategories();
        expect((await user).categories.single.id, 2);
        gate.complete(_categories);
        expect(await bg, isFalse);
        expect(repo.categories.map((c) => c.id), [2]);
      },
    );

    // Spec 5
    test('categories and feed are published together to listeners', () async {
      final seen = <String>[];
      api.onFeed = (_) async => ApiFeed(items: [_item(title: 'done')]);
      repo.addListener(() {
        if (repo.categories.isNotEmpty) {
          seen.add(repo.feed(FeedKey.home).items.single.title);
        }
      });
      expect(await repo.refreshInBackground(), isTrue);
      expect(seen, isNotEmpty);
      expect(seen, everyElement('done'));
    });

    test('a superseded batch must not leave only its categories', () async {
      await repo.loadNext(FeedKey.archive);
      api.onFeed = (_) async => ApiFeed(items: [_item(title: 'done')]);
      api.onCategories = () async {
        // 목록·카테고리 응답이 다 온 뒤 게시 전에 사용자가 필터를 바꾼다.
        repo.resetFeed(FeedKey.archive);
        return _categories;
      };
      expect(await repo.refreshInBackground(), isFalse);
      expect(repo.categories, isEmpty);
      expect(titles(FeedKey.home), ['original']);
    });

    // Spec 6(D3)
    test(
      'older background reply must not revert detail reply on the list',
      () async {
        final gate = Completer<ApiFeed>();
        api.onFeed = (_) => gate.future;
        final bg = repo.refreshInBackground();
        final handle = repo.openDetail(repo.feed(FeedKey.home).items.single);
        api.onDetail = (_) async => _item(title: 'done');
        await repo.refreshDetail(handle);
        expect(titles(FeedKey.home), ['done']);
        gate.complete(ApiFeed(items: [_item(title: 'pending')]));
        expect(await bg, isFalse);
        expect(titles(FeedKey.home), ['done']);
      },
    );

    // Spec 8(D5)
    test('repeating an empty cursor page ends without another fetch', () async {
      final cursors = <String?>[];
      api.onFeed = (r) async {
        cursors.add(r.cursor);
        if (cursors.length == 4) throw StateError('test fuse');
        return ApiFeed(items: [], nextCursor: 'same');
      };
      expect(await repo.refreshInBackground(), isFalse);
      expect(cursors, [null, 'same']);
      expect(titles(FeedKey.home), ['original']);
    });
  });
}
