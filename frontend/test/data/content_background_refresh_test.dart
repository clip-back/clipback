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

  // 배경 다시 읽기가 쓰는 한 번만 보내는 읽기(결정 A). 같은 응답을 준다.
  @override
  Future<List<ApiCategory>> listCategoriesOnce() => listCategories();
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
        // 배경은 먼저 시작한 사용자 읽기의 게시를 기다린다(그 요청을 취소·대체하지 않는다).
        await Future<void>.delayed(Duration.zero);
        expect(reads, 2);
        gate.complete(_study);
        expect((await user).categories.single.id, 1);
        expect(await bg, isTrue);
        expect(repo.categories.single.id, 2, reason: '나중 묶음이 뒤에 게시');
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

    // 최종 재검수 Spec 4: 두 커서가 번갈아 나와도 이미 쓴 커서면 멈춘다.
    test('alternating cursors A, B, A end the background read', () async {
      final cursors = <String?>[];
      api.onFeed = (r) async {
        cursors.add(r.cursor);
        if (cursors.length == 6) throw StateError('test fuse');
        return ApiFeed(items: [], nextCursor: r.cursor == 'A' ? 'B' : 'A');
      };
      expect(await repo.refreshInBackground(), isFalse);
      expect(cursors, [null, 'A', 'B']);
      expect(titles(FeedKey.home), ['original']);
    });

    // 최종 재검수 Spec 3: 먼저 시작한 사용자 카테고리 읽기가 게시된 뒤 배경 묶음이 게시된다.
    // 검수 원본은 배경 완료를 먼저 기다린 뒤 사용자 응답을 풀었다. 이 설계에서는 배경이 사용자
    // 응답 게시를 기다리므로, 배경이 응답을 다 받은 뒤 사용자 응답을 풀어 최종 상태를 본다.
    test(
      'an earlier user category read publishes first; the newer batch follows',
      () async {
        ApiCategory counted(int n) => ApiCategory(
          id: 3,
          name: '미분류',
          color: null,
          isDefault: true,
          contentCount: n,
        );
        final gate = Completer<List<ApiCategory>>();
        var calls = 0;
        api.onCategories = () =>
            ++calls == 1 ? gate.future : Future.value([counted(1)]);
        final user = repo.readCurrentCategories();
        api.onFeed = (_) async => ApiFeed(items: [_item(title: 'done')]);
        final bg = repo.refreshInBackground();
        await Future<void>.delayed(Duration.zero);
        expect(calls, 2, reason: '배경도 카테고리를 읽었다');
        expect(titles(FeedKey.home), ['original'], reason: '사용자 읽기 게시 전');
        gate.complete([counted(2)]);
        expect((await user).current, isTrue);
        expect(await bg, isTrue);
        expect(repo.categories.single.contentCount, 1);
        expect(titles(FeedKey.home), ['done']);
      },
    );

    // 최종 재검수 Standards 1: 첫 알림에서 모든 대상 목록과 카테고리가 함께 바뀌어 있다.
    test(
      'every target list and the categories change at the single notification',
      () async {
        await repo.loadNext(FeedKey.archive);
        final categoriesBefore = repo.categories.length;
        api.onFeed = (_) async => ApiFeed(items: [_item(title: 'done')]);
        api.onCategories = () async => const [_travel];
        final seen = <List<Object>>[];
        repo.addListener(
          () => seen.add([
            titles(FeedKey.home).single,
            titles(FeedKey.archive).single,
            repo.categories.map((c) => c.id).toList(),
          ]),
        );
        expect(await repo.refreshInBackground(), isTrue);
        expect(categoriesBefore, 0);
        expect(seen, [
          [
            'done',
            'done',
            [2],
          ],
        ]);
      },
    );

    // 직전 검수 Spec 4: 명시적으로 취소된 배경 묶음은 사용자 카테고리 응답을 기다리지 않고 끝난다.
    test(
      'a cancelled batch stops waiting for an earlier user category read',
      () async {
        final first = Completer<List<ApiCategory>>();
        final second = Completer<void>();
        var reads = 0;
        api.onCategories = () {
          if (++reads == 1) return first.future;
          second.complete();
          return Future.value(_categories);
        };
        final user = repo.readCurrentCategories();
        final bg = repo.refreshInBackground();
        await second.future;
        await Future<void>.delayed(Duration.zero);
        await repo.loadNext(FeedKey.home, reset: true); // 사용자 읽기가 배경을 취소
        var finished = false;
        unawaited(bg.then((_) => finished = true));
        await Future<void>.delayed(Duration.zero);
        expect(finished, isTrue, reason: '사용자 카테고리 응답 전에 끝남');
        expect(await bg, isFalse);
        first.complete(_categories);
        expect((await user).current, isTrue);
      },
    );

    // 검수 Spec 2: 사용자 카테고리 응답만 기다리던 배경도 상세 교체로 바로 끝난다.
    test(
      'a batch waiting for an earlier user category read ends when a detail reply replaces a shown card',
      () async {
        final first = Completer<List<ApiCategory>>();
        final second = Completer<void>();
        var reads = 0;
        api.onCategories = () {
          if (++reads == 1) return first.future;
          second.complete();
          return Future.value(_categories);
        };
        final user = repo.readCurrentCategories();
        final bg = repo.refreshInBackground();
        await second.future;
        await Future<void>.delayed(Duration.zero);
        api.onDetail = (_) async => _item(title: 'detail');
        await repo.refreshDetail(
          repo.openDetail(repo.feed(FeedKey.home).items.single),
        );
        var finished = false;
        unawaited(bg.then((_) => finished = true));
        await Future<void>.delayed(Duration.zero);
        expect(finished, isTrue, reason: '사용자 응답 전에 끝남');
        first.complete(_categories);
        expect((await user).current, isTrue);
        expect(await bg, isFalse);
        expect(titles(FeedKey.home), ['detail']);
      },
    );
  });
}
