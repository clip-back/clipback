import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _old = ApiSession(
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _rotated = ApiSession(
  accessToken: 'rotated-access',
  refreshToken: 'rotated-refresh',
  expiresIn: 7200,
  refreshExpiresIn: 172800,
);
const _replacement = ApiSession(
  accessToken: 'replacement-access',
  refreshToken: 'replacement-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _replacementRotated = ApiSession(
  accessToken: 'replacement-rotated-access',
  refreshToken: 'replacement-rotated-refresh',
  expiresIn: 7200,
  refreshExpiresIn: 172800,
);
const _refreshPath = '/api/v1/auth/refresh';
const _logoutPath = '/api/v1/auth/logout';

Map<String, Object> _tokens(ApiSession session) => {
  'access_token': session.accessToken,
  'refresh_token': session.refreshToken,
  'expires_in': session.expiresIn,
  'refresh_expires_in': session.refreshExpiresIn,
};

http.Response _unauthorized() =>
    _json({'detail': 'Invalid or expired token'}, 401);

http.Response _failedRefresh(String failure) => switch (failure) {
  '401' => _unauthorized(),
  '503' => _json({'detail': 'Temporarily unavailable'}, 503),
  'network' => throw http.ClientException('Offline'),
  'JSON' => http.Response('{broken', 200),
  _ => _json(_tokens(_rotated)),
};

Future<({Object? value, Object? error})> _outcome(
  Future<dynamic> operation,
) async {
  try {
    return (value: await operation, error: null);
  } catch (error) {
    return (value: null, error: error);
  }
}

void _expectCancelled(Object? error) {
  expect(
    error,
    isA<ClipbackApiException>().having(
      (error) => error.statusCode,
      'status',
      isNull,
    ),
  );
}

Future<void> _turn() => Future<void>(() {});

class _Server {
  _Server({this.respond});
  final Future<http.Response?> Function(http.Request)? respond;
  final requests = <http.Request>[];
  late final client = MockClient((request) async {
    requests.add(request);
    final response = await respond?.call(request);
    if (response != null) return response;
    switch (request.url.path) {
      case _refreshPath:
        return _json(_tokens(_rotated));
      case '/api/v1/auth/guest':
      case '/api/v1/auth/social/google':
      case '/api/v1/auth/social/google/upgrade':
        return _json(_tokens(_replacement));
      case _logoutPath:
        return http.Response('', 204);
      case '/api/v1/categories':
      case '/api/v1/categories/recent':
        return _json(<Object>[]);
      case '/api/v1/contents/7':
        return _json({
          'id': 7,
          'categories': <Object>[],
          'tags': <Object>[],
          'assets': <Object>[],
          'content_type': 'link',
          'source': 'web',
          'title': '테스트 콘텐츠',
          'summary': '테스트',
          'original_url': 'https://example.com/saved',
          'is_favorite': false,
          'saved_at': '2026-10-06T00:00:00Z',
          'last_viewed_at': null,
        });
      case '/api/v1/contents/7/view':
      case '/api/v1/metrics/events':
        return _json(<String, Object>{}, 201);
      default:
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
    }
  });

  List<http.Request> calls(String path) =>
      requests.where((request) => request.url.path == path).toList();
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'concurrent detail, view and click 401 responses share one refresh',
    () async {
      final requests = <http.Request>[];
      final changedSessions = <ApiSession>[];
      final allExpiredRequests = Completer<void>();
      var expiredRequests = 0;
      var refreshCalls = 0;
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls++;
          if (refreshCalls > 1) {
            return _json({'detail': 'Invalid or expired refresh token'}, 401);
          }
          await Future<void>(() {});
          return _json({
            'access_token': 'rotated-access',
            'refresh_token': 'rotated-refresh',
            'expires_in': 7200,
            'refresh_expires_in': 172800,
          });
        }
        if (request.headers['Authorization'] == 'Bearer old-access') {
          expiredRequests++;
          if (expiredRequests == 3) allExpiredRequests.complete();
          await allExpiredRequests.future;
          return _json({'detail': 'Invalid or expired access token'}, 401);
        }
        switch (request.url.path) {
          case '/api/v1/contents/7':
            return _json({
              'id': 7,
              'categories': <Object>[],
              'tags': <Object>[],
              'assets': <Object>[],
              'content_type': 'link',
              'source': 'web',
              'title': '동시 갱신 확인 콘텐츠',
              'summary': '테스트 콘텐츠',
              'original_url': 'https://example.com/saved',
              'is_favorite': false,
              'saved_at': '2026-10-06T00:00:00Z',
              'last_viewed_at': null,
            });
          case '/api/v1/contents/7/view':
          case '/api/v1/metrics/events':
            return _json(<String, Object>{}, 201);
          default:
            throw StateError(
              'Unexpected request: ${request.method} ${request.url}',
            );
        }
      });
      addTearDown(client.close);
      final api = ClipbackApi(
        client: client,
        onSessionChanged: (session) async => changedSessions.add(session),
      )..restoreSession(_old);
      var successes = 0;
      final failures = <Object>[];
      Future<void> capture(Future<dynamic> operation) async {
        try {
          await operation;
          successes++;
        } catch (error) {
          failures.add(error);
        }
      }

      await Future.wait([
        capture(api.readContent(7)),
        capture(api.recordContentView(7)),
        capture(api.createCardClickEvent(contentId: 7, categoryId: 101)),
      ]);

      expect(expiredRequests, 3);
      expect(
        refreshCalls,
        1,
        reason: 'A rotating refresh token must be used once.',
      );
      expect(failures, isEmpty);
      expect(successes, 3);
      expect(changedSessions, hasLength(1));
      expect(api.session?.refreshToken, 'rotated-refresh');
      final replayed = requests.where(
        (request) =>
            request.headers['Authorization'] == 'Bearer rotated-access',
      );
      expect(replayed, hasLength(3));
      for (final retried in replayed) {
        final original = requests.singleWhere(
          (request) =>
              request.headers['Authorization'] == 'Bearer old-access' &&
              request.url == retried.url,
        );
        expect(retried.method, original.method);
        expect(retried.body, original.body);
      }
      expect(
        jsonDecode(
          replayed
              .singleWhere(
                (request) => request.url.path == '/api/v1/metrics/events',
              )
              .body,
        ),
        {'event_type': 'card_clicked', 'content_id': 7, 'category_id': 101},
      );
    },
  );

  test(
    'a late old-token 401 reuses tokens from the completed refresh',
    () async {
      final lateResponse = Completer<http.Response?>();
      final sessions = <ApiSession>[];
      final server = _Server(
        respond: (request) async {
          if (request.headers['Authorization'] == 'Bearer old-access') {
            if (request.url.path == '/api/v1/categories/recent') {
              return lateResponse.future;
            }
            return _unauthorized();
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (session) async => sessions.add(session),
      )..restoreSession(_old);
      final detail = _outcome(api.readContent(7));
      final categories = _outcome(api.listRecentCategories(limit: 7));
      expect((await detail).error, isNull);
      lateResponse.complete(_unauthorized());
      expect((await categories).error, isNull);
      expect(server.calls(_refreshPath), hasLength(1));
      expect(sessions, hasLength(1));
      expect(
        server
            .calls('/api/v1/categories/recent')
            .map((request) => request.headers['Authorization']),
        ['Bearer old-access', 'Bearer rotated-access'],
      );
      expect(
        server
            .calls('/api/v1/categories/recent')
            .map((request) => request.url.query),
        ['limit=7', 'limit=7'],
      );
    },
  );

  test(
    '401 while the persistence callback waits joins the same refresh',
    () async {
      final callbackStarted = Completer<void>();
      final saved = Completer<void>();
      var callbacks = 0;
      var categoryCalls = 0;
      var replaySawSaved = false;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == '/api/v1/categories') {
            categoryCalls++;
            if (categoryCalls == 1) return _unauthorized();
            replaySawSaved = saved.isCompleted;
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async {
          callbacks++;
          callbackStarted.complete();
          await saved.future;
        },
      )..restoreSession(_old);
      final refresh = _outcome(api.refreshSession());
      await callbackStarted.future;
      final request = _outcome(api.listCategories());
      await _turn();
      expect(categoryCalls, 1);
      expect(server.calls(_refreshPath), hasLength(1));
      saved.complete();
      expect((await refresh).error, isNull);
      expect((await request).error, isNull);
      expect(callbacks, 1);
      expect(replaySawSaved, isTrue);
    },
  );

  test(
    'direct overlapping refresh calls return the same completed result',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response?>();
      var callbacks = 0;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _refreshPath) {
            started.complete();
            return response.future;
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async => callbacks++,
      )..restoreSession(_old);
      final first = api.refreshSession();
      final second = api.refreshSession();
      final results = [_outcome(first), _outcome(second)];
      await started.future;
      expect(identical(first, second), isTrue);
      expect(server.calls(_refreshPath), hasLength(1));
      response.complete(_json(_tokens(_rotated)));
      final completed = await Future.wait(results);
      expect(completed.every((result) => result.error == null), isTrue);
      expect(callbacks, 1);
    },
  );

  test('a completed refresh leaves room for the next token rotation', () async {
    var calls = 0;
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _refreshPath && ++calls == 2) {
          return _json(_tokens(_replacementRotated));
        }
        return null;
      },
    );
    addTearDown(server.client.close);
    final api = ClipbackApi(client: server.client)..restoreSession(_old);
    await api.refreshSession();
    await api.refreshSession();
    expect(
      server
          .calls(_refreshPath)
          .map((request) => jsonDecode(request.body)['refresh_token']),
      ['old-refresh', 'rotated-refresh'],
    );
    expect(api.session?.refreshToken, 'replacement-rotated-refresh');
  });

  test(
    'the retried 401 terminates each request without another refresh',
    () async {
      final allOld = Completer<void>();
      var oldCalls = 0;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _refreshPath) {
            await _turn();
            return null;
          }
          if (request.headers['Authorization'] == 'Bearer old-access') {
            if (++oldCalls == 3) allOld.complete();
            await allOld.future;
          }
          return _unauthorized();
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      final results = await Future.wait([
        _outcome(api.readContent(7)),
        _outcome(api.recordContentView(7)),
        _outcome(api.createCardClickEvent(contentId: 7)),
      ]);
      expect(
        results.map((result) => result.error),
        everyElement(
          isA<ClipbackApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(server.calls(_refreshPath), hasLength(1));
      for (final path in [
        '/api/v1/contents/7',
        '/api/v1/contents/7/view',
        '/api/v1/metrics/events',
      ]) {
        expect(server.calls(path), hasLength(2));
      }
    },
  );

  for (final failure in ['401', '503', 'network', 'JSON', 'callback']) {
    test(
      'shared refresh $failure reaches all waiters and a later refresh can recover',
      () async {
        final allOld = Completer<void>();
        var oldCalls = 0;
        var fail = true;
        var callbacks = 0;
        final server = _Server(
          respond: (request) async {
            if (request.url.path == _refreshPath) {
              await _turn();
              if (fail) return _failedRefresh(failure);
              return null;
            }
            if (request.headers['Authorization'] == 'Bearer old-access') {
              if (++oldCalls == 2) allOld.complete();
              await allOld.future;
              return _unauthorized();
            }
            return null;
          },
        );
        addTearDown(server.client.close);
        final api = ClipbackApi(
          client: server.client,
          onSessionChanged: (_) async {
            callbacks++;
            if (fail && failure == 'callback') {
              throw StateError('Storage unavailable');
            }
          },
        )..restoreSession(_old);
        final failed = await Future.wait([
          _outcome(api.readContent(7)),
          _outcome(api.listCategories()),
        ]);
        expect(failed.every((result) => result.error != null), isTrue);
        expect(server.calls(_refreshPath), hasLength(1));
        expect(
          api.session?.refreshToken,
          failure == 'callback' ? 'rotated-refresh' : 'old-refresh',
        );
        fail = false;
        expect((await _outcome(api.refreshSession())).error, isNull);
        expect(server.calls(_refreshPath), hasLength(2));
        expect(callbacks, failure == 'callback' ? 2 : 1);
      },
    );
  }

  for (final action in ['restore', 'clear', 'guest', 'social', 'upgrade']) {
    test(
      '$action cancels a pending refresh without reviving its old session',
      () async {
        final started = Completer<void>();
        final response = Completer<http.Response?>();
        final sessions = <ApiSession>[];
        final server = _Server(
          respond: (request) async {
            if (request.url.path == _refreshPath) {
              started.complete();
              return response.future;
            }
            return null;
          },
        );
        addTearDown(server.client.close);
        final api = ClipbackApi(
          client: server.client,
          onSessionChanged: (session) async => sessions.add(session),
        )..restoreSession(_old);
        final oldRefresh = _outcome(api.refreshSession());
        await started.future;
        switch (action) {
          case 'restore':
            api.restoreSession(_replacement);
            break;
          case 'clear':
            api.clearSession();
            break;
          case 'guest':
            await api.createGuestSession();
            break;
          case 'social':
            await api.socialLogin(
              provider: 'google',
              token: 'test-provider-token',
            );
            break;
          case 'upgrade':
            await api.upgradeGuestWithSocial(
              provider: 'google',
              token: 'test-provider-token',
            );
            break;
        }
        response.complete(_json(_tokens(_rotated)));
        _expectCancelled((await oldRefresh).error);
        expect(
          api.session?.refreshToken,
          action == 'clear' ? null : 'replacement-refresh',
        );
        expect(
          sessions.map((session) => session.refreshToken),
          action == 'restore' || action == 'clear'
              ? <String>[]
              : ['replacement-refresh'],
        );
      },
    );
  }

  for (final oldResponse in ['200', '401', 'network']) {
    test(
      'old authenticated $oldResponse cannot cross a session replacement',
      () async {
        final started = Completer<void>();
        final response = Completer<void>();
        final server = _Server(
          respond: (request) async {
            if (request.headers['Authorization'] == 'Bearer old-access') {
              started.complete();
              await response.future;
              if (oldResponse == '401') return _unauthorized();
              if (oldResponse == 'network') {
                throw http.ClientException('Offline');
              }
            }
            return null;
          },
        );
        addTearDown(server.client.close);
        final api = ClipbackApi(client: server.client)..restoreSession(_old);
        final request = _outcome(api.listCategories());
        await started.future;
        api.restoreSession(_replacement);
        response.complete();
        _expectCancelled((await request).error);
        expect(server.calls(_refreshPath), isEmpty);
        expect(server.calls('/api/v1/categories'), hasLength(1));
        expect(api.session?.refreshToken, 'replacement-refresh');
      },
    );
  }

  for (final oldResult in ['success', '401', 'network']) {
    test(
      'old refresh $oldResult cannot clear the replacement refresh slot',
      () async {
        final oldStarted = Completer<void>();
        final newStarted = Completer<void>();
        final oldRelease = Completer<void>();
        final newRelease = Completer<http.Response?>();
        final sessions = <ApiSession>[];
        final server = _Server(
          respond: (request) async {
            if (request.url.path == _refreshPath) {
              if (jsonDecode(request.body)['refresh_token'] == 'old-refresh') {
                oldStarted.complete();
                await oldRelease.future;
                if (oldResult != 'success') {
                  return _failedRefresh(oldResult);
                }
                return _json(_tokens(_rotated));
              }
              newStarted.complete();
              return newRelease.future;
            }
            return null;
          },
        );
        addTearDown(server.client.close);
        final api = ClipbackApi(
          client: server.client,
          onSessionChanged: (session) async => sessions.add(session),
        )..restoreSession(_old);
        final oldFlight = _outcome(api.refreshSession());
        await oldStarted.future;
        api.restoreSession(_replacement);
        final current = api.refreshSession();
        final newFlight = _outcome(current);
        await newStarted.future;
        oldRelease.complete();
        _expectCancelled((await oldFlight).error);
        expect(api.session?.refreshToken, 'replacement-refresh');
        final joined = api.refreshSession();
        expect(identical(joined, current), isTrue);
        final joinedOutcome = _outcome(joined);
        expect(server.calls(_refreshPath), hasLength(2));
        newRelease.complete(_json(_tokens(_replacementRotated)));
        expect((await newFlight).error, isNull);
        expect((await joinedOutcome).error, isNull);
        expect(sessions.map((session) => session.refreshToken), [
          'replacement-rotated-refresh',
        ]);
      },
    );
  }

  for (final action in ['restore', 'clear']) {
    test(
      'session $action during the callback prevents stale completion',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        final server = _Server();
        addTearDown(server.client.close);
        final api = ClipbackApi(
          client: server.client,
          onSessionChanged: (_) async {
            entered.complete();
            await release.future;
          },
        )..restoreSession(_old);
        final refresh = _outcome(api.refreshSession());
        await entered.future;
        if (action == 'restore') {
          api.restoreSession(_replacement);
        } else {
          api.clearSession();
        }
        release.complete();
        _expectCancelled((await refresh).error);
        expect(
          api.session?.refreshToken,
          action == 'clear' ? null : 'replacement-refresh',
        );
      },
    );
  }

  test(
    'logout waits for HTTP and persistence and blocks new authenticated work',
    () async {
      final httpStarted = Completer<void>();
      final httpRelease = Completer<http.Response?>();
      final callbackStarted = Completer<void>();
      final saved = Completer<void>();
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _refreshPath) {
            httpStarted.complete();
            return httpRelease.future;
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async {
          callbackStarted.complete();
          await saved.future;
        },
      )..restoreSession(_old);
      final refresh = _outcome(api.refreshSession());
      await httpStarted.future;
      final logout = _outcome(api.logout());
      await _turn();
      expect(server.calls(_logoutPath), isEmpty);
      httpRelease.complete(_json(_tokens(_rotated)));
      await callbackStarted.future;
      expect(server.calls(_logoutPath), isEmpty);
      final blocked = await Future.wait([
        _outcome(api.listCategories()),
        _outcome(api.refreshSession()),
        _outcome(api.createGuestSession()),
        _outcome(
          api.socialLogin(provider: 'google', token: 'test-provider-token'),
        ),
        _outcome(
          api.upgradeGuestWithSocial(
            provider: 'google',
            token: 'test-provider-token',
          ),
        ),
      ]);
      for (final result in blocked) {
        _expectCancelled(result.error);
      }
      expect(server.requests, hasLength(1));
      saved.complete();
      expect((await refresh).error, isNull);
      expect((await logout).error, isNull);
      expect(
        jsonDecode(server.calls(_logoutPath).single.body)['refresh_token'],
        'rotated-refresh',
      );
      expect(api.hasSession, isFalse);
    },
  );

  for (final failure in ['401', '503', 'network', 'JSON', 'callback']) {
    test(
      'logout still attempts the current token after refresh $failure',
      () async {
        final started = Completer<void>();
        final release = Completer<void>();
        final server = _Server(
          respond: (request) async {
            if (request.url.path == _refreshPath) {
              started.complete();
              await release.future;
              return _failedRefresh(failure);
            }
            return null;
          },
        );
        addTearDown(server.client.close);
        final api = ClipbackApi(
          client: server.client,
          onSessionChanged: (_) async {
            if (failure == 'callback') throw StateError('Storage unavailable');
          },
        )..restoreSession(_old);
        final refresh = _outcome(api.refreshSession());
        await started.future;
        final logout = _outcome(api.logout());
        expect(server.calls(_logoutPath), isEmpty);
        release.complete();
        expect((await refresh).error, isNotNull);
        expect((await logout).error, isNull);
        expect(
          jsonDecode(server.calls(_logoutPath).single.body)['refresh_token'],
          failure == 'callback' ? 'rotated-refresh' : 'old-refresh',
        );
        expect(api.hasSession, isFalse);
      },
    );
  }

  for (final oldResult in ['success', '401']) {
    test(
      'old logout $oldResult preserves a newer session and logout gate',
      () async {
        final oldStarted = Completer<void>();
        final newStarted = Completer<void>();
        final oldRelease = Completer<http.Response?>();
        final newRelease = Completer<http.Response?>();
        final server = _Server(
          respond: (request) async {
            if (request.url.path == _logoutPath) {
              if (jsonDecode(request.body)['refresh_token'] == 'old-refresh') {
                oldStarted.complete();
                return oldRelease.future;
              }
              newStarted.complete();
              return newRelease.future;
            }
            return null;
          },
        );
        addTearDown(server.client.close);
        final api = ClipbackApi(client: server.client)..restoreSession(_old);
        final oldLogout = _outcome(api.logout());
        await oldStarted.future;
        api.restoreSession(_replacement);
        final newLogout = _outcome(api.logout());
        await newStarted.future;
        oldRelease.complete(
          oldResult == 'success' ? http.Response('', 204) : _unauthorized(),
        );
        _expectCancelled((await oldLogout).error);
        expect(api.session?.refreshToken, 'replacement-refresh');
        _expectCancelled((await _outcome(api.createGuestSession())).error);
        expect(server.calls('/api/v1/auth/guest'), isEmpty);
        newRelease.complete(http.Response('', 204));
        expect((await newLogout).error, isNull);
        expect(api.hasSession, isFalse);
      },
    );
  }

  test(
    'logout HTTP failure releases its gate without deleting usable tokens',
    () async {
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _logoutPath) {
            return _json({'detail': 'Unavailable'}, 503);
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      expect((await _outcome(api.logout())).error, isA<ClipbackApiException>());
      expect(api.session?.refreshToken, 'old-refresh');
      expect((await _outcome(api.listCategories())).error, isNull);
    },
  );

  testWidgets(
    'HTTP timeout is shared, retry works, and the late response cannot overwrite it',
    (tester) async {
      final late = Completer<http.Response?>();
      var calls = 0;
      var callbacks = 0;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _refreshPath && ++calls == 1) {
            return late.future;
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async => callbacks++,
      )..restoreSession(_old);
      var completed = false;
      final first = _outcome(api.refreshSession()).then((result) {
        completed = true;
        return result;
      });
      final second = _outcome(api.refreshSession());
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect(completed, isFalse);
      await tester.pump(const Duration(seconds: 1));
      final timedOut = await first;
      _expectCancelled(timedOut.error);
      expect((timedOut.error! as ClipbackApiException).message, contains('지연'));
      _expectCancelled((await second).error);
      expect(server.calls(_refreshPath), hasLength(1));
      expect(callbacks, 0);
      final retry = _outcome(api.refreshSession());
      await tester.pump();
      expect((await retry).error, isNull);
      late.complete(_json(_tokens(_replacement)));
      await tester.pump();
      expect(api.session?.refreshToken, 'rotated-refresh');
      expect(callbacks, 1);
    },
  );

  testWidgets(
    'persistence may take longer than the HTTP timeout and remains shared',
    (tester) async {
      final saved = Completer<void>();
      var callbacks = 0;
      var completed = false;
      final server = _Server();
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async {
          callbacks++;
          await saved.future;
        },
      )..restoreSession(_old);
      final first = _outcome(api.refreshSession()).then((result) {
        completed = true;
        return result;
      });
      await tester.pump();
      final second = _outcome(api.refreshSession());
      await tester.pump(const Duration(seconds: 12));
      expect(completed, isFalse);
      expect(server.calls(_refreshPath), hasLength(1));
      saved.complete();
      await tester.pump();
      expect((await first).error, isNull);
      expect((await second).error, isNull);
      expect(callbacks, 1);
    },
  );

  testWidgets(
    'logout waits for the shared timeout then uses the current token',
    (tester) async {
      final late = Completer<http.Response?>();
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _refreshPath) return late.future;
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      final refresh = _outcome(api.refreshSession());
      final logout = _outcome(api.logout());
      await tester.pump();
      expect(server.calls(_logoutPath), isEmpty);
      await tester.pump(const Duration(seconds: 10));
      _expectCancelled((await refresh).error);
      expect((await logout).error, isNull);
      expect(
        jsonDecode(server.calls(_logoutPath).single.body)['refresh_token'],
        'old-refresh',
      );
      late.complete(_json(_tokens(_rotated)));
      await tester.pump();
      expect(api.hasSession, isFalse);
    },
  );

  test('two API instances keep their refresh work separate', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var refreshCalls = 0;
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _refreshPath) {
          if (++refreshCalls == 2) started.complete();
          await release.future;
          return _json(
            _tokens(
              jsonDecode(request.body)['refresh_token'] == 'old-refresh'
                  ? _rotated
                  : _replacementRotated,
            ),
          );
        }
        return null;
      },
    );
    addTearDown(server.client.close);
    final first = ClipbackApi(client: server.client)..restoreSession(_old);
    final second = ClipbackApi(client: server.client)
      ..restoreSession(_replacement);
    final one = _outcome(first.refreshSession());
    final two = _outcome(second.refreshSession());
    await started.future;
    expect(server.calls(_refreshPath), hasLength(2));
    release.complete();
    expect((await one).error, isNull);
    expect((await two).error, isNull);
    expect(first.session?.refreshToken, 'rotated-refresh');
    expect(second.session?.refreshToken, 'replacement-rotated-refresh');
  });
}
