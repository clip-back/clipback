import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// #460 배경 다시 읽기의 요청 소유권: 폐기된 배경 요청은 로그인 갱신·세션 무효화를 하지 않고,
// 사용자 요청이 소유한 401 갱신·실패 처리는 그대로다. 실제 ClipbackApi + 메모리 HTTP.

Map<String, Object?> _item(int id) => {
  'id': id,
  'title': 'item $id',
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
  // 유효한 access token. 바꾸면 이전 토큰의 요청은 401이다.
  String valid = 'a';
  int refreshes = 0, invalidations = 0;
  // 다음 GET /feed 응답을 붙잡는다(응답은 풀린 시점의 토큰 판정).
  Completer<void>? feedGate;
  Completer<void>? refreshGate;
  bool refreshFails = false;
  final feedAuth = <String?>[];

  late final client = MockClient((r) async {
    final path = r.url.path;
    if (path.endsWith('/auth/refresh')) {
      refreshes++;
      await refreshGate?.future;
      if (refreshFails) return _json({'detail': 'expired'}, 401);
      valid = 'b';
      return _json({
        'access_token': 'b',
        'refresh_token': 'refresh-b',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
      });
    }
    if (path.endsWith('/feed')) {
      final auth = r.headers['Authorization'];
      feedAuth.add(auth);
      final gate = feedGate;
      feedGate = null;
      await gate?.future;
      if (auth != 'Bearer $valid') return _json({'detail': 'expired'}, 401);
      return _json({
        'items': [_item(r.url.queryParameters['cursor'] == null ? 1 : 2)],
        'next_cursor': r.url.queryParameters['cursor'] == null ? 'next' : null,
      });
    }
    if (path.endsWith('/categories')) return _json(<Object>[]);
    throw StateError('unexpected ${r.method} $path');
  });

  late final api =
      ClipbackApi(
        client: client,
        onSessionInvalidated: () async => invalidations++,
      )..restoreSession(
        const ApiSession(
          accessToken: 'a',
          refreshToken: 'refresh-a',
          expiresIn: 3600,
          refreshExpiresIn: 86400,
        ),
      );
}

void main() {
  late _Server server;
  late RemoteContentRepository repo;
  List<int> ids(FeedKey key) => repo.feed(key).items.map((x) => x.id).toList();

  setUp(() async {
    server = _Server();
    repo = RemoteContentRepository(server.api);
    await repo.loadNext(FeedKey.home); // [1], cursor next
  });

  test(
    'a discarded background read gets 401 and neither refreshes nor invalidates',
    () async {
      final gate = Completer<void>();
      server.feedGate = gate;
      final bg = repo.refreshInBackground();
      await Future<void>.delayed(Duration.zero);
      await repo.loadNext(FeedKey.home); // 사용자 다음 쪽: 배경을 무효화하고 진행
      expect(ids(FeedKey.home), [1, 2]);
      server.valid = 'b'; // 붙잡힌 배경 GET은 이제 401
      gate.complete();
      expect(await bg, isFalse);
      expect([server.refreshes, server.invalidations], [0, 0]);
      expect(ids(FeedKey.home), [1, 2]);
    },
  );

  test('a user read keeps its own 401 refresh and retry', () async {
    final gate = Completer<void>();
    server.feedGate = gate;
    final bg = repo.refreshInBackground();
    await Future<void>.delayed(Duration.zero);
    server.valid = 'b';
    final next = repo.loadNext(FeedKey.home);
    await next;
    expect(server.refreshes, 1);
    expect(server.invalidations, 0);
    expect(ids(FeedKey.home), [1, 2]);
    gate.complete();
    expect(await bg, isFalse);
    expect([server.refreshes, server.invalidations], [1, 0]);
  });

  test(
    'a refresh a user request joined survives discarding the background read',
    () async {
      final refresh = Completer<void>();
      server
        ..valid = 'b'
        ..refreshGate = refresh;
      final bg = repo.refreshInBackground(); // 배경 GET 401 → 갱신 시작(붙잡힘)
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(server.refreshes, 1);
      // 배경 대상이 아닌 목록의 사용자 읽기가 같은 갱신에 합류한다.
      final bookmark = repo.loadNext(FeedKey.bookmark);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // 사용자 다음 쪽이 배경을 무효화한다. 갱신은 살아 있는 사용자 요청이 소유한다.
      final next = repo.loadNext(FeedKey.home);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      refresh.complete();
      await bookmark;
      await next;
      expect(await bg, isFalse);
      expect(server.refreshes, 1, reason: '갱신은 한 번');
      expect(server.invalidations, 0);
      expect(ids(FeedKey.bookmark), [1]);
      expect(ids(FeedKey.home), [1, 2]);
    },
  );

  test(
    'a user read whose refresh fails still invalidates the session',
    () async {
      server
        ..valid = 'b'
        ..refreshFails = true;
      await repo.loadNext(FeedKey.home);
      expect(server.refreshes, 1);
      expect(server.invalidations, 1);
    },
  );
}
