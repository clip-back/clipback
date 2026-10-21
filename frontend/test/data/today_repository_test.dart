import 'dart:async';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../fixtures/today_server.dart';

void main() {
  late TodayServer server;
  late ClipbackApi api;
  late RemoteContentRepository repository;
  setUp(() {
    server = TodayServer();
    api = ClipbackApi(client: server.todayClient)
      ..restoreSession(
        const ApiSession(
          accessToken: 'test',
          refreshToken: 'test-refresh',
          expiresIn: 3600,
          refreshExpiresIn: 86400,
        ),
      );
    repository = RemoteContentRepository(api);
  });
  tearDown(() => repository.dispose());
  Future<ApiTodayRecommendation?> load() =>
      repository.loadToday(isCurrent: () => true);
  test(
    'typed metadata preserves dates, nullable stage0 and gapped rank',
    () async {
      server.ids = [606, 604];
      server.ranks = [5, 1];
      final response = await api.readTodayRecommendation();
      expect(response.date, '2026-10-21');
      expect(response.batchId, 71);
      expect(response.generatedAt, DateTime.utc(2026, 10, 21, 10));
      expect(response.items.map((i) => i.rank), [1, 5]);
      expect(response.items.map((i) => i.id), [1304, 1306]);
      server.mode = 'stage0';
      final empty = await api.readTodayRecommendation();
      expect(empty.stage, 0);
      expect(empty.items, isEmpty);
      expect(empty.batchId, isNull);
      expect(empty.generatedAt, isNull);
    },
  );
  test(
    'Today lives outside feeds and query is independent of category',
    () async {
      await repository.loadCategories();
      repository.configureFeed(FeedKey.home, categoryId: 101);
      await repository.loadNext(FeedKey.home);
      final before = repository.feed(FeedKey.home);
      await load();
      final after = repository.feed(FeedKey.home);
      expect(after.items.map((i) => i.id), before.items.map((i) => i.id));
      expect(after.categoryId, 101);
      expect(repository.currentContent(606), isNotNull);
      expect(
        server.calls
            .where((r) => r['path'] == '/api/v1/recommendations/today')
            .single['query'],
        isEmpty,
      );
      expect(
        server.calls.where(
          (r) =>
              (r['path'] as String).endsWith('/view') ||
              (r['path'] as String).contains('/exposures'),
        ),
        isEmpty,
      );
    },
  );
  test('late query cannot repopulate new account', () async {
    server.pending = Completer<void>();
    final pending = load();
    repository.resetAccount(8);
    server.pending!.complete();
    expect(await pending, isNull);
    expect(repository.today, isNull);
    expect(repository.currentContent(606), isNull);
  });
  test(
    'request ownership cancellation does not publish recommendation data',
    () async {
      var current = true;
      server.pending = Completer<void>();
      final pending = repository.loadToday(isCurrent: () => current);
      current = false;
      server.pending!.complete();
      expect(await pending, isNull);
      expect(repository.today, isNull);
    },
  );
  test(
    'bookmark optimistic update and rollback include recommendation-only items',
    () async {
      await load();
      final change = repository.beginBookmark(606)!;
      expect(repository.today!.items.first.content.isFavorite, isTrue);
      final result = await repository.executeContentMutation(change);
      expect(result.succeeded, isTrue);
      repository.finishContentMutation(change);
      expect(repository.currentContent(606)!.isFavorite, isTrue);
      expect(repository.feed(FeedKey.home).items, isEmpty);
    },
  );
  test(
    'explicit removal does not fill gap or renumber remaining ranks',
    () async {
      await load();
      repository.removeTodayContent(604);
      expect(repository.today!.items.map((i) => i.rank), [1, 3, 4, 5]);
      expect(repository.currentContent(604), isNull);
    },
  );
  test(
    'recommendation view carries UUID and item; retry reuses the same body',
    () async {
      await load();
      repository.recordRecommendationOpen(
        repository.currentContent(606)!,
        1306,
      );
      await Future<void>.delayed(Duration.zero);
      final view = server.calls.singleWhere(
        (r) => r['path'] == '/api/v1/contents/606/view',
      );
      final body = view['body'] as Map;
      expect(body['recommendation_item_id'], 1306);
      await api.recordRecommendationView(
        606,
        clientEventId: body['client_event_id'] as String,
        recommendationItemId: 1306,
      );
      expect(
        server.calls
            .where((r) => r['path'] == '/api/v1/contents/606/view')
            .last['body'],
        body,
      );
      expect(
        server.metrics.where((m) => m['event_type'] == 'card_clicked'),
        hasLength(1),
      );
    },
  );
  test('preflight response is ignored after account reset', () async {
    final pending = Completer<http.Response>();
    final client = MockClient(
      (r) async => r.url.path.endsWith('/606')
          ? pending.future
          : server.json(server.response()),
    );
    final otherApi = ClipbackApi(client: client)
      ..restoreSession(
        const ApiSession(
          accessToken: 't',
          refreshToken: 'r',
          expiresIn: 3600,
          refreshExpiresIn: 86400,
        ),
      );
    final other = RemoteContentRepository(otherApi);
    addTearDown(other.dispose);
    await other.loadToday(isCurrent: () => true);
    final read = other.readTodayContent(606, isCurrent: () => true);
    other.resetAccount(7);
    pending.complete(server.json(server.records.last));
    expect(await read, isNull);
    expect(other.currentContent(606), isNull);
  });

  test('overlapping selection cannot roll back a committed bookmark', () async {
    await load();
    server.pending = Completer<void>();
    final pending = load();
    await Future<void>.delayed(Duration.zero);
    final change = repository.beginBookmark(606)!;
    await repository.executeContentMutation(change);
    repository.finishContentMutation(change);
    server.pending!.complete();
    await pending;
    expect(repository.today!.items.first.content.isFavorite, isTrue);
  });
  test(
    'overlapping selection cannot resurrect a deleted recommendation',
    () async {
      await load();
      server.pending = Completer<void>();
      final pending = load();
      await Future<void>.delayed(Duration.zero);
      final change = repository.beginContentDelete(606)!;
      await repository.executeContentMutation(change);
      repository.finishContentMutation(change);
      server.records.removeWhere((item) => item['id'] == 606);
      server.pending!.complete();
      await pending;
      expect(repository.today!.items.any((i) => i.content.id == 606), isFalse);
      expect(repository.currentContent(606), isNull);
    },
  );
  test('newer selection wins even when older response arrives last', () async {
    final first = Completer<void>(), second = Completer<void>();
    server.pending = first;
    final old = load();
    await Future<void>.delayed(Duration.zero);
    server.ids = [605];
    server.ranks = [4];
    server.pending = second;
    final newer = load();
    await Future<void>.delayed(Duration.zero);
    second.complete();
    await newer;
    first.complete();
    expect(await old, isNull);
    expect(repository.today!.items.single.content.id, 605);
  });
}
