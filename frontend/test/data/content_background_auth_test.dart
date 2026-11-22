import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// #460 결정 A(2026-11-22 "배경은 401에서 조용히 종료"): 배경 feed·categories·stats·me GET은 현재
// 액세스 토큰으로 한 번만 보내고 401이면 조용히 끝난다. 로그인 갱신·세션 무효화는 0회다.
// 사용자 요청의 401 갱신·실패 처리는 그대로다. 실제 ClipbackApi + 메모리 HTTP.

Map<String, Object?> _item(int id, {String title = 'item'}) => {
  'id': id,
  'title': title,
  'summary': 'summary',
  'categories': <Object>[],
  'tags': <Object>[],
  'assets': <Object>[],
  'content_type': 'link',
  'source': 'web',
  'original_url': 'https://example.invalid/$id',
  'is_favorite': false,
  'saved_at': '2026-11-22T00:00:00Z',
  'last_viewed_at': null,
  'summary_status': 'processing',
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Server {
  // 유효한 access token·refresh token. 갱신은 서버가 회전을 확정한 뒤 응답한다.
  String valid = 'a', refreshValid = 'refresh-a';
  int refreshes = 0, rejections = 0, invalidations = 0, saves = 0;
  int statsValue = 1;
  // 갱신: 서버가 회전을 확정하면 rotated, rotationGate가 있으면 응답을 보류한다.
  final rotated = Completer<void>();
  Completer<void>? rotationGate;
  // 401로 답한 요청(경로 + 토큰).
  final unauthorized = <String>[];
  // 다음 GET(경로별)을 붙잡는다. 응답 판정은 풀린 시점의 토큰으로 한다.
  final gates = <String, Completer<void>>{};
  // 이 경로만 503.
  final failing = <String>{};
  final sent = <String>[];
  String title = 'item';
  // GET /feed 순번(1부터)으로 붙잡기·503.
  int feedCalls = 0;
  final holdFeed = <int, Completer<void>>{};
  final failFeed = <int>{};

  Future<void> _hold(String path) async {
    final gate = gates.remove(path);
    await gate?.future;
  }

  late final client = MockClient((r) async {
    final path = r.url.path.replaceFirst('/api/v1', '');
    if (path == '/auth/refresh') {
      refreshes++;
      if (jsonDecode(r.body)['refresh_token'] != refreshValid) {
        rejections++;
        return _json({'detail': 'expired'}, 401);
      }
      valid = 'b';
      refreshValid = 'refresh-b';
      if (!rotated.isCompleted) rotated.complete();
      await rotationGate?.future;
      return _json({
        'access_token': 'b',
        'refresh_token': 'refresh-b',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
      });
    }
    final auth = r.headers['Authorization'];
    sent.add(
      '${r.method} $path ${r.url.queryParameters['cursor'] ?? ''} $auth',
    );
    if (path == '/feed') {
      final n = ++feedCalls;
      await holdFeed[n]?.future;
      if (failFeed.contains(n)) return _json({'detail': 'down'}, 503);
    }
    await _hold(path);
    if (failing.contains(path)) return _json({'detail': 'down'}, 503);
    if (auth != 'Bearer $valid') {
      unauthorized.add('$path $auth');
      return _json({'detail': 'expired'}, 401);
    }
    switch (path) {
      case '/feed':
        final cursor = r.url.queryParameters['cursor'];
        return _json({
          'items': [_item(cursor == null ? 1 : 2, title: title)],
          'next_cursor': cursor == null ? 'next' : null,
        });
      case '/categories':
        return _json(<Object>[]);
      case '/users/me/stats':
        return _json({
          'saved_count': statsValue,
          'reopened_count': 0,
          'recent_reopened_count': 0,
        });
      case '/users/me':
        return _json({
          'id': 1,
          'email': null,
          'display_name': 'tester',
          'is_guest': true,
          'created_at': '2026-11-01T00:00:00Z',
          'linked_providers': <String>[],
        });
      case '/contents/1':
        return _json(_item(1, title: 'detail'));
    }
    throw StateError('unexpected ${r.method} $path');
  });

  late final api =
      ClipbackApi(
        client: client,
        onSessionChanged: (_) async => saves++,
        onSessionInvalidated: () async => invalidations++,
      )..restoreSession(
        const ApiSession(
          accessToken: 'a',
          refreshToken: 'refresh-a',
          expiresIn: 3600,
          refreshExpiresIn: 86400,
        ),
      );

  List<int> get auth => [refreshes, rejections, invalidations];
}

void main() {
  late _Server server;
  late RemoteContentRepository repo;
  late RemoteUserRepository users;
  List<int> ids(FeedKey key) => repo.feed(key).items.map((x) => x.id).toList();
  List<String> titles(FeedKey key) =>
      repo.feed(key).items.map((x) => x.title).toList();
  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));

  setUp(() async {
    server = _Server();
    repo = RemoteContentRepository(server.api);
    users = RemoteUserRepository(api: server.api);
    await repo.loadNext(FeedKey.home); // [1], cursor next
    await users.loadStats();
  });

  group('each background GET answers 401 once and ends quietly', () {
    test('feed', () async {
      server.valid = 'b';
      expect(await repo.refreshInBackground(), isFalse);
      expect(server.auth, [0, 0, 0]);
      expect(server.sent.where((s) => s.startsWith('GET /feed')), hasLength(2));
      expect(ids(FeedKey.home), [1]);
    });

    test('categories', () async {
      server.title = 'new';
      final gate = Completer<void>();
      server.gates['/categories'] = gate;
      final bg = repo.refreshInBackground();
      await tick();
      server.valid = 'b'; // 목록 응답 뒤, 카테고리 응답만 401
      gate.complete();
      expect(await bg, isFalse);
      expect(server.auth, [0, 0, 0]);
      expect(titles(FeedKey.home), ['item'], reason: '아무것도 반영하지 않는다');
    });

    test('stats', () async {
      server
        ..valid = 'b'
        ..statsValue = 9;
      final status = users.statsStatus;
      await users.refreshInBackground(isCurrent: () => true);
      expect(server.auth, [0, 0, 0]);
      expect(users.stats!.savedCount, 1);
      expect(users.statsStatus, status);
    });

    test('profile (me)', () async {
      final gate = Completer<void>();
      server.gates['/users/me'] = gate;
      final bg = users.refreshInBackground(isCurrent: () => true);
      await tick();
      server.valid = 'b'; // 통계 응답 뒤, 프로필만 401
      gate.complete();
      await bg;
      expect(server.auth, [0, 0, 0]);
      expect(users.user, isNull, reason: '이전 프로필(없음) 유지');
    });
  });

  group('user requests keep their login refresh', () {
    test('a user next page refreshes on 401 and retries', () async {
      server.valid = 'b';
      await repo.loadNext(FeedKey.home);
      expect(server.auth, [1, 0, 0]);
      expect(server.saves, 1);
      expect(ids(FeedKey.home), [1, 2]);
    });

    test('a user stats read refreshes on 401 and retries', () async {
      server
        ..valid = 'b'
        ..statsValue = 7;
      await users.loadStats();
      expect(server.auth, [1, 0, 0]);
      expect(users.stats!.savedCount, 7);
    });

    test(
      'a user read whose refresh fails still invalidates the session',
      () async {
        server
          ..valid = 'b'
          ..refreshValid = 'other';
        await repo.loadNext(FeedKey.home);
        expect(server.auth, [1, 1, 1]);
      },
    );

    // 직전 검수 Spec 1: 배경이 회전을 시작하던 순서. 결정 A에서는 배경이 갱신하지 않으므로
    // 다음 사용자 요청이 한 번 회전하고 새 토큰을 저장한다(소비된 토큰 재사용·세션 유실 없음).
    test(
      'after a background 401 the user next page rotates once and keeps the session',
      () async {
        server.valid = 'b';
        expect(await repo.refreshInBackground(), isFalse);
        await repo.loadNext(FeedKey.home);
        expect(server.auth, [1, 0, 0]);
        expect(server.saves, 1);
        expect(ids(FeedKey.home), [1, 2]);
        await repo.loadNext(FeedKey.home, reset: true);
        expect(server.auth, [1, 0, 0], reason: '새 토큰으로 바로 성공');
      },
    );

    test(
      'a user refresh in flight is neither joined nor cancelled by a background 401',
      () async {
        server.valid = 'b';
        final hold = Completer<void>();
        server.holdFeed[server.feedCalls + 1] = hold;
        final user = repo.loadNext(FeedKey.bookmark); // 사용자 GET: 붙잡힘 → 401 → 갱신
        await tick();
        // 배경 GET은 바로 401로 끝난다(갱신 시작·합류 없음).
        expect(await repo.refreshInBackground(), isFalse);
        expect(server.auth, [0, 0, 0]);
        hold.complete();
        await user;
        expect(server.auth, [1, 0, 0]);
        expect(ids(FeedKey.bookmark), [1]);
      },
    );
  });

  group('discarded or unpublishable batches', () {
    test(
      'a discarded background read gets 401 late: no refresh, no invalidation',
      () async {
        final gate = Completer<void>();
        server.gates['/feed'] = gate;
        final bg = repo.refreshInBackground();
        await tick();
        server.valid = 'b';
        gate.complete();
        // 사용자 다음 쪽은 자기 401을 갱신해 진행한다.
        await repo.loadNext(FeedKey.home);
        expect(await bg, isFalse);
        expect(server.auth, [1, 0, 0], reason: '갱신은 사용자 요청의 1회뿐');
        expect(ids(FeedKey.home), [1, 2]);
      },
    );

    for (final userCategoryRead in [true, false]) {
      test(
        'a batch made unpublishable by ${userCategoryRead ? 'a user category read' : 'a newer detail reply'} gets 401 late: 0 refresh',
        () async {
          final gate = Completer<void>();
          server.gates['/feed'] = gate;
          final bg = repo.refreshInBackground();
          await tick();
          if (userCategoryRead) {
            expect((await repo.readCurrentCategories()).current, isTrue);
          } else {
            final handle = repo.openDetail(
              repo.feed(FeedKey.home).items.single,
            );
            await repo.refreshDetail(handle);
            expect(titles(FeedKey.home), ['detail']);
          }
          server.valid = 'b';
          gate.complete();
          expect(await bg, isFalse);
          expect(server.auth, [0, 0, 0]);
        },
      );
    }

    test(
      'a failed sibling list ends the batch at once; the late 401 sibling starts no refresh',
      () async {
        await repo.loadNext(FeedKey.archive);
        final n = server.feedCalls;
        final hold = Completer<void>();
        server.holdFeed[n + 1] = hold; // 홈 형제: 붙잡힘
        server.failFeed.add(n + 2); // 아카이브 형제: 바로 503
        final bg = repo.refreshInBackground();
        // 붙잡힌 형제를 기다리지 않고 끝난다.
        expect(await bg.timeout(const Duration(seconds: 2)), isFalse);
        server.valid = 'b';
        hold.complete(); // 늦은 401
        await tick();
        expect(server.auth, [0, 0, 0]);
        expect(ids(FeedKey.home), [1]);
      },
    );
  });

  group('stats owners', () {
    test(
      'a user stats read in flight wins: the background sends no stats GET',
      () async {
        final gate = Completer<void>();
        server.gates['/users/me/stats'] = gate;
        final user = users.loadStats();
        await tick();
        final before = server.sent.length;
        await users.refreshInBackground(isCurrent: () => true);
        expect(server.sent.length, before);
        gate.complete();
        await user;
        expect(users.statsStatus, UserStatsStatus.success);
      },
    );

    test(
      'a user stats read started after the background one keeps its own result and 401 refresh',
      () async {
        final gate = Completer<void>();
        server.gates['/users/me/stats'] = gate;
        final bg = users.refreshInBackground(isCurrent: () => true);
        await tick();
        server
          ..valid = 'b'
          ..statsValue = 5;
        await users.loadStats(); // 사용자: 401 → 갱신 → 재시도 → 5
        expect(users.stats!.savedCount, 5);
        expect(server.auth, [1, 0, 0]);
        server.statsValue = 99;
        gate.complete(); // 늦은 배경 응답(이전 토큰 401)은 버려진다
        await bg;
        expect(users.stats!.savedCount, 5);
        expect(users.statsStatus, UserStatsStatus.success);
        expect(server.auth, [1, 0, 0]);
      },
    );

    test(
      'a newer background stats read replaces an older one still waiting',
      () async {
        final gate = Completer<void>();
        server.gates['/users/me/stats'] = gate;
        server.statsValue = 2;
        final older = users.refreshInBackground(isCurrent: () => true);
        await tick();
        server.statsValue = 3;
        await users.refreshInBackground(isCurrent: () => true);
        expect(users.stats!.savedCount, 3);
        gate.complete(); // 늦은 응답도 3이지만, 버려졌는지 값을 바꿔 본다
        server.statsValue = 4;
        await older;
        expect(users.stats!.savedCount, 3);
      },
    );
  });

  // 검수(.utmp/review-460-option-a.md) Standards 1: 실제 HTTP 경계에서 경로·토큰·401 응답 수.
  group('wire', () {
    for (final path in [
      '/feed',
      '/categories',
      '/users/me/stats',
      '/users/me',
    ]) {
      test(
        '$path: sent once with the current token, one 401, no refresh, save or invalidation',
        () async {
          final gate = Completer<void>();
          server.gates[path] = gate;
          final before = server.sent.length;
          final saves = server.saves;
          final Future<Object?> request = path.startsWith('/users')
              ? users.refreshInBackground(isCurrent: () => true)
              : repo.refreshInBackground();
          while (server.gates.containsKey(path)) {
            await Future<void>.delayed(Duration.zero);
          }
          server.valid = 'b';
          gate.complete();
          await request;
          final batch = server.sent.skip(before).toList();
          expect(batch.where((v) => v == 'GET $path  Bearer a'), hasLength(1));
          expect(batch.where((v) => v.startsWith('GET $path ')), hasLength(1));
          expect(server.unauthorized, ['$path Bearer a']);
          expect(server.auth, [0, 0, 0]);
          expect(server.saves, saves);
        },
      );
    }

    test(
      'a user rotation the server already accepted: the background tries once with the old token; the user keeps the new one',
      () async {
        server
          ..valid = 'b'
          ..rotationGate = Completer<void>();
        final saves = server.saves;
        final user = users.loadStats(); // 사용자: 401 → 갱신(서버 회전 확정 뒤 응답 보류)
        await server.rotated.future;
        final before = server.sent.length;
        expect(
          await repo.refreshInBackground().timeout(const Duration(seconds: 1)),
          isFalse,
        );
        expect(server.sent.skip(before), ['GET /feed  Bearer a']);
        expect(server.auth, [1, 0, 0]);
        expect(server.saves, saves);
        server.rotationGate!.complete();
        await user;
        expect(server.sent.last, 'GET /users/me/stats  Bearer b');
        expect(server.saves, saves + 1);
        expect(server.auth, [1, 0, 0]);
      },
    );

    // 검수 Spec 2: 게시할 수 없게 만든 사건에서 배경은 늦은 응답을 기다리지 않고 끝난다.
    for (final cause in [
      'detail',
      'categories',
      'dispose',
      'account',
      'filter',
      'refresh',
    ]) {
      test(
        'an unpublishable batch ends before its held GET is released ($cause)',
        () async {
          final hold = Completer<void>();
          server.gates['/feed'] = hold;
          final bg = repo.refreshInBackground();
          while (server.gates.containsKey('/feed')) {
            await Future<void>.delayed(Duration.zero);
          }
          switch (cause) {
            case 'detail':
              await repo.refreshDetail(
                repo.openDetail(repo.feed(FeedKey.home).items.single),
              );
            case 'categories':
              expect((await repo.readCurrentCategories()).current, isTrue);
            case 'dispose':
              repo.dispose();
            case 'account':
              repo.resetAccount(2);
            case 'filter':
              repo.configureFeed(FeedKey.home, query: 'x');
            case 'refresh':
              repo.beginRefresh();
          }
          final ended = await Future.any([
            bg.then((_) => true),
            Future<bool>.delayed(
              const Duration(milliseconds: 100),
              () => false,
            ),
          ]);
          hold.complete();
          expect(await bg, isFalse);
          expect(ended, isTrue);
          expect(server.auth, [0, 0, 0]);
        },
      );
    }
  });
}
