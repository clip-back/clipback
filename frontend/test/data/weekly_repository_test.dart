import 'dart:async';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../fixtures/weekly_server.dart';

const session = ApiSession(
  accessToken: 'test',
  refreshToken: 'test-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
void main() {
  late WeeklyServer server;
  late ClipbackApi api;
  late RemoteContentRepository repo;
  setUp(() {
    server = WeeklyServer();
    api = ClipbackApi(client: server.weeklyClient)..restoreSession(session);
    repo = RemoteContentRepository(api);
  });
  tearDown(() => repo.dispose());
  test(
    'Weekly preserves server sequence, IDs, gapped rank, type and period',
    () async {
      final response = await api.readWeeklyRecommendation();
      expect(response.items.map((v) => v.category.id), [102, 101]);
      expect(response.items.map((v) => v.rank), [1, 3]);
      expect(response.items.first.id, 8011);
      expect(response.items.first.type, WeeklyCardType.mostSaved);
      expect(response.periodStart, '2026-10-19');
      expect(response.periodEnd, '2026-10-25');
      expect(response.batchId, 801);
      expect(response.generatedAt, DateTime.utc(2026, 10, 21, 12));
      server.weeklyMode = 'rediscovery';
      expect(
        (await api.readWeeklyRecommendation()).items.first.type,
        WeeklyCardType.rediscovery,
      );
      server.weeklyMode = 'empty';
      expect((await api.readWeeklyRecommendation()).items, isEmpty);
    },
  );
  test(
    'independent snapshot: no feeds, Today, view or exposure on GET',
    () async {
      repo.configureFeed(FeedKey.home, categoryId: 101);
      await repo.loadNext(FeedKey.home);
      final ids = repo.feed(FeedKey.home).items.map((c) => c.id).toList();
      final visit = repo.beginWeeklyVisit();
      await repo.loadWeekly(visit);
      expect(repo.feed(FeedKey.home).items.map((c) => c.id), ids);
      expect(repo.feed(FeedKey.home).categoryId, 101);
      expect(repo.today, isNull);
      expect(repo.weekly!.items, hasLength(2));
      expect(
        server.calls.where(
          (c) =>
              c['path'] == '/api/v1/recommendations/exposures' ||
              (c['path'] as String).endsWith('/view'),
        ),
        isEmpty,
      );
    },
  );
  test(
    'duplicate pending query and late response after visit/account change',
    () async {
      server.weeklyPending = Completer<void>();
      final visit = repo.beginWeeklyVisit();
      final a = repo.loadWeekly(visit), b = repo.loadWeekly(visit);
      expect(identical(a, b), isTrue);
      repo.endWeeklyVisit(visit);
      server.weeklyPending!.complete();
      await a;
      expect(repo.weekly, isNull);
      expect(
        server.calls.where(
          (c) => c['path'] == '/api/v1/recommendations/weekly',
        ),
        hasLength(1),
      );
      server.weeklyPending = Completer<void>();
      final next = repo.beginWeeklyVisit();
      final pending = repo.loadWeekly(next);
      repo.resetAccount(3);
      server.weeklyPending!.complete();
      await pending;
      expect(repo.weekly, isNull);
    },
  );
  test('one exposure per visit/item, no view, new visit new UUID', () async {
    var visit = repo.beginWeeklyVisit();
    await repo.loadWeekly(visit);
    final item = repo.weekly!.items.first.id;
    repo.recordWeeklyExposure(visit, item);
    repo.recordWeeklyExposure(visit, item);
    repo.recordWeeklyExposure(visit, 123);
    await Future<void>.delayed(Duration.zero);
    final calls = server.calls.where(
      (c) => c['path'] == '/api/v1/recommendations/exposures',
    );
    expect(calls, hasLength(1));
    final first = Map.of(calls.single['body'] as Map);
    expect(first['client_event_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(first['recommendation_item_id'], item);
    repo.endWeeklyVisit(visit);
    repo.recordWeeklyExposure(visit, item);
    server.batch = 800;
    visit = repo.beginWeeklyVisit();
    await repo.loadWeekly(visit);
    repo.recordWeeklyExposure(visit, repo.weekly!.items.first.id);
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(2));
    expect(
      (calls.last['body'] as Map)['client_event_id'],
      isNot(first['client_event_id']),
    );
    expect(
      server.calls.where((c) => (c['path'] as String).endsWith('/view')),
      isEmpty,
    );
  });
  test(
    'category rename reconciles Weekly; confirmed deletion removes without refill',
    () async {
      await repo.loadCategories();
      final visit = repo.beginWeeklyVisit();
      await repo.loadWeekly(visit);
      final change = repo.beginCategoryUpdate(
        102,
        name: '새 카테고리',
        color: '#123456',
      )!;
      expect(repo.weekly!.items.first.category.name, '새 카테고리');
      // Failed API update rolls the optimistic label back.
      final result = await repo.executeCategoryMutation(change);
      expect(result.succeeded, isFalse);
      repo.finishCategoryMutation(change);
      expect(repo.weekly!.items.first.category.name, '여행');
      final fake = MockClient((r) async {
        if (r.method == 'DELETE') return server.json({}, 204);
        final c = http.Request(r.method, r.url)
          ..headers.addAll(r.headers)
          ..bodyBytes = r.bodyBytes;
        return server.weeklyClient.send(c).then(http.Response.fromStream);
      });
      final other = RemoteContentRepository(
        ClipbackApi(client: fake)..restoreSession(session),
      );
      addTearDown(other.dispose);
      await other.loadCategories();
      final v = other.beginWeeklyVisit();
      await other.loadWeekly(v);
      final deletion = other.beginCategoryDelete(102)!;
      expect(other.weekly!.items, hasLength(2));
      expect((await other.executeCategoryMutation(deletion)).succeeded, isTrue);
      expect(other.weekly!.items.map((c) => c.category.id), [101]);
      expect(other.weekly!.items.single.rank, 3);
    },
  );
  test(
    'auth refresh retries an exposure with exactly the same UUID/body',
    () async {
      final bodies = <String>[];
      var posts = 0;
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/exposures')) {
          bodies.add(r.body);
          return server.json(
            posts++ == 0 ? {'detail': 'expired'} : {},
            posts == 1 ? 401 : 201,
          );
        }
        final copy = http.Request(r.method, r.url)
          ..headers.addAll(r.headers)
          ..bodyBytes = r.bodyBytes;
        return server.weeklyClient.send(copy).then(http.Response.fromStream);
      });
      final a = ClipbackApi(client: client)..restoreSession(session);
      await a.recordRecommendationExposure(
        clientEventId: 'f7dc84da-70d0-4aa5-a25a-969a605ca421',
        recommendationItemId: 8011,
      );
      expect(bodies, hasLength(2));
      expect(bodies[0], bodies[1]);
    },
  );
  test('one-item result and immutable API metadata', () {
    final raw = server.weeklyResponse();
    raw['items'] = (raw['items'] as List).take(1).toList();
    final result = ApiWeeklyRecommendation.fromJson(raw);
    expect(result.items, hasLength(1));
    expect(() => result.items.clear(), throwsUnsupportedError);
  });
}
