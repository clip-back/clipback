import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _categories = '/api/v1/categories';
const _feed = '/api/v1/feed';
const _me = '/api/v1/users/me';
const _stats = '/api/v1/users/me/stats';
const _guest = '/api/v1/auth/guest';
const _refresh = '/api/v1/auth/refresh';
const _storedSession = ApiSession(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _category = {
  'id': 101,
  'name': '공부',
  'color': '#059669',
  'is_default': false,
  'content_count': 1,
  'last_saved_at': null,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _tokens(String prefix) => _json({
  'access_token': '$prefix-access',
  'refresh_token': '$prefix-refresh',
  'expires_in': 3600,
  'refresh_expires_in': 86400,
});

http.Response _failure(String kind) => switch (kind) {
  '503' => _json({'detail': 'Temporary upstream failure'}, 503),
  '403' => _json({'detail': 'Forbidden'}, 403),
  '401' => _json({'detail': 'Invalid or expired token'}, 401),
  'invalid JSON' => http.Response('{broken', 200),
  'network' => throw http.ClientException('Offline'),
  _ => throw StateError('Unknown failure: $kind'),
};

void _seedSession([ApiSession? session = _storedSession]) {
  SharedPreferences.setMockInitialValues({
    if (session != null) ...{
      'clipback.access_token': session.accessToken,
      'clipback.refresh_token': session.refreshToken,
      'clipback.expires_in': session.expiresIn,
      'clipback.refresh_expires_in': session.refreshExpiresIn,
    },
  });
}

class _Storage extends ApiSessionStorage {
  int reads = 0;
  int writes = 0;
  int clears = 0;
  int failingReads = 0;
  bool failWrite = false;
  bool failClear = false;

  @override
  Future<ApiSession?> read() async {
    reads++;
    if (failingReads > 0) {
      failingReads--;
      throw StateError('Storage read unavailable');
    }
    return super.read();
  }

  @override
  Future<void> write(ApiSession session) async {
    writes++;
    if (failWrite) throw StateError('Storage write unavailable');
    await super.write(session);
  }

  @override
  Future<void> clear() async {
    clears++;
    if (failClear) throw StateError('Storage clear unavailable');
    await super.clear();
  }
}

class _Server {
  _Server({this.respond});

  final Future<http.Response?> Function(http.Request)? respond;
  final requests = <http.Request>[];
  late final client = MockClient((request) async {
    requests.add(request);
    final response = await respond?.call(request);
    if (response != null) return response;
    switch (request.url.path) {
      case _guest:
        return _tokens('guest');
      case _refresh:
        return _tokens('rotated');
      case _categories:
        return _json([_category]);
      case _feed:
        return _json({
          'items': [
            {
              'id': 7,
              'categories': [_category],
              'tags': <Object>[],
              'assets': <Object>[],
              'content_type': 'link',
              'source': 'web',
              'title': '사용자가 저장한 링크',
              'summary': '서버에서 조회한 콘텐츠',
              'original_url': 'https://example.com/saved',
              'is_favorite': false,
              'saved_at': '2026-10-05T00:00:00Z',
              'last_viewed_at': null,
            },
          ],
          'next_cursor': null,
        });
      case _me:
        return _json({
          'id': 1,
          'email': null,
          'display_name': '테스트 계정',
          'is_guest': true,
          'created_at': '2026-10-05T00:00:00Z',
          'linked_providers': <String>[],
        });
      case _stats:
        return _json({'saved_count': 1, 'reopened_count': 0});
      default:
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
    }
  });

  List<http.Request> calls(String path) =>
      requests.where((request) => request.url.path == path).toList();
}

Future<void> _runApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function(_Storage) check, {
  _Storage? storage,
  bool settle = true,
}) async {
  final sessionStorage = storage ?? _Storage();
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        Theme(
          data: ThemeData(fontFamily: 'Pretendard'),
          child: ClipbackApp(sessionStorage: sessionStorage),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
      await check(sessionStorage);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

void _expectError() {
  expect(find.text('저장한 콘텐츠를 불러오지 못했어요.'), findsOneWidget);
  expect(find.text('다시 시도'), findsOneWidget);
  expect(find.byType(HomeScreen), findsNothing);
  expect(find.byType(AddContentSheet), findsNothing);
}

void _expectLoaded(WidgetTester tester) {
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.text('다시 시도'), findsNothing);
  expect(find.text('저장한 콘텐츠를 불러오지 못했어요.'), findsNothing);
  expect(find.text('사용자가 저장한 링크'), findsWidgets);
  final contents = tester.widget<HomeScreen>(find.byType(HomeScreen)).contents;
  expect(contents.map((content) => content.apiId), [7]);
  expect(contents.single.title, '사용자가 저장한 링크');
}

Future<void> _retry(WidgetTester tester) async {
  await tester.tap(find.text('다시 시도'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });
  setUp(_seedSession);

  for (final path in [_categories, _feed]) {
    for (final failure in ['503', '403', 'network', 'invalid JSON']) {
      testWidgets('$path $failure preserves the session and retries', (
        tester,
      ) async {
        var failOnce = true;
        final server = _Server(
          respond: (request) async {
            if (request.url.path == path && failOnce) {
              failOnce = false;
              return _failure(failure);
            }
            return null;
          },
        );
        await _runApp(tester, server, (storage) async {
          _expectError();
          final persisted = await ApiSessionStorage().read();
          expect(server.calls(_guest), isEmpty);
          expect(storage.clears, 0);
          expect(persisted?.accessToken, _storedSession.accessToken);
          expect(persisted?.refreshToken, _storedSession.refreshToken);

          await _retry(tester);

          _expectLoaded(tester);
          expect(storage.reads, 1);
          expect(server.calls(_guest), isEmpty);
          expect(server.calls(_refresh), isEmpty);
          expect(
            server
                .calls(path)
                .map((request) => request.headers['Authorization']),
            ['Bearer test-access', 'Bearer test-access'],
          );
        });
      });
    }
  }

  for (final failure in ['503', '403', 'network', 'invalid JSON']) {
    testWidgets('refresh $failure preserves the session until retry succeeds', (
      tester,
    ) async {
      var failRefreshOnce = true;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _categories &&
              request.headers['Authorization'] == 'Bearer test-access') {
            return _failure('401');
          }
          if (request.url.path == _refresh && failRefreshOnce) {
            failRefreshOnce = false;
            return _failure(failure);
          }
          return null;
        },
      );
      await _runApp(tester, server, (storage) async {
        _expectError();
        expect(storage.clears, 0);
        expect(server.calls(_guest), isEmpty);
        expect(
          (await ApiSessionStorage().read())?.refreshToken,
          'test-refresh',
        );
        await _retry(tester);
        _expectLoaded(tester);
        expect(storage.reads, 1);
        expect(storage.clears, 0);
        expect(server.calls(_guest), isEmpty);
        expect(server.calls(_refresh), hasLength(2));
        expect(
          server.calls(_categories).last.headers['Authorization'],
          'Bearer rotated-access',
        );
      });
    });
  }

  testWidgets('retry uses rotated memory tokens after the feed fails', (
    tester,
  ) async {
    var failFeedOnce = true;
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _categories &&
            request.headers['Authorization'] == 'Bearer test-access') {
          return _failure('401');
        }
        if (request.url.path == _feed && failFeedOnce) {
          failFeedOnce = false;
          return _failure('503');
        }
        return null;
      },
    );
    await _runApp(tester, server, (storage) async {
      _expectError();
      expect(
        jsonDecode(server.calls(_refresh).single.body)['refresh_token'],
        'test-refresh',
      );
      await _retry(tester);
      _expectLoaded(tester);
      expect(storage.reads, 1);
      expect(storage.clears, 0);
      expect(server.calls(_guest), isEmpty);
      expect(server.calls(_refresh), hasLength(1));
      expect(
        server.calls(_feed).map((request) => request.headers['Authorization']),
        ['Bearer rotated-access', 'Bearer rotated-access'],
      );
      expect(
        server.calls(_categories).last.headers['Authorization'],
        'Bearer rotated-access',
      );
    });
  });

  for (final path in [_categories, _feed, _me, _stats]) {
    for (final refreshSucceeds in [false, true]) {
      testWidgets(
        '$path final 401 replaces the guest once (refresh=$refreshSucceeds)',
        (tester) async {
          final server = _Server(
            respond: (request) async {
              if (request.url.path == _refresh && !refreshSucceeds) {
                return _failure('401');
              }
              if (request.url.path == path &&
                  request.headers['Authorization'] != 'Bearer guest-access') {
                return _failure('401');
              }
              return null;
            },
          );
          await _runApp(tester, server, (storage) async {
            _expectLoaded(tester);
            expect(server.calls(_refresh), hasLength(1));
            expect(server.calls(_guest), hasLength(1));
            expect(storage.clears, 1);
            expect(
              server.calls(path).last.headers['Authorization'],
              'Bearer guest-access',
            );
            expect(
              (await ApiSessionStorage().read())?.refreshToken,
              'guest-refresh',
            );
            if (refreshSucceeds) {
              expect(
                server
                    .calls(path)
                    .map((request) => request.headers['Authorization']),
                [
                  'Bearer test-access',
                  'Bearer rotated-access',
                  'Bearer guest-access',
                ],
              );
            }
          });
        },
      );
    }
  }

  for (final path in [_me, _stats]) {
    testWidgets(
      '$path 503 still shows the saved feed without replacing the account',
      (tester) async {
        final server = _Server(
          respond: (request) async {
            if (request.url.path == path) return _failure('503');
            return null;
          },
        );
        await _runApp(tester, server, (storage) async {
          _expectLoaded(tester);
          expect(server.calls(path), hasLength(1));
          expect(server.calls(_guest), isEmpty);
          expect(server.calls(_refresh), isEmpty);
          expect(storage.clears, 0);
          expect(
            (await ApiSessionStorage().read())?.refreshToken,
            'test-refresh',
          );
        });
      },
    );
  }

  testWidgets('storage read failure waits for retry without creating a guest', (
    tester,
  ) async {
    final storage = _Storage()..failingReads = 1;
    final server = _Server();
    await _runApp(tester, server, (_) async {
      _expectError();
      expect(server.requests, isEmpty);
      expect(storage.clears, 0);
      await _retry(tester);
      _expectLoaded(tester);
      expect(storage.reads, 2);
      expect(server.calls(_guest), isEmpty);
      expect(
        server.calls(_categories).single.headers['Authorization'],
        'Bearer test-access',
      );
    }, storage: storage);
  });

  for (final refreshSucceeds in [false, true]) {
    testWidgets(
      'failed storage clear preserves memory for retry (refresh=$refreshSucceeds)',
      (tester) async {
        var rejectSession = true;
        final storage = _Storage()..failClear = true;
        final server = _Server(
          respond: (request) async {
            if (request.url.path == _categories && rejectSession) {
              return _failure('401');
            }
            if (request.url.path == _refresh && !refreshSucceeds) {
              return _failure('401');
            }
            return null;
          },
        );
        await _runApp(tester, server, (_) async {
          _expectError();
          expect(storage.clears, 1);
          expect(server.calls(_guest), isEmpty);
          expect(
            (await ApiSessionStorage().read())?.refreshToken,
            refreshSucceeds ? 'rotated-refresh' : 'test-refresh',
          );
          rejectSession = false;
          await _retry(tester);
          _expectLoaded(tester);
          expect(storage.reads, 1);
          expect(server.calls(_guest), isEmpty);
          expect(
            server.calls(_categories).last.headers['Authorization'],
            refreshSucceeds ? 'Bearer rotated-access' : 'Bearer test-access',
          );
        }, storage: storage);
      },
    );
  }

  testWidgets('restoring a persisted session does not rewrite credentials', (
    tester,
  ) async {
    final storage = _Storage()..failWrite = true;
    final server = _Server();
    await _runApp(tester, server, (_) async {
      _expectLoaded(tester);
      expect(storage.writes, 0);
      expect(storage.clears, 0);
      expect(server.calls(_guest), isEmpty);
      expect((await ApiSessionStorage().read())?.refreshToken, 'test-refresh');
    }, storage: storage);
  });

  for (final hasStoredSession in [false, true]) {
    for (final failure in ['503', '401']) {
      testWidgets(
        'new guest lookup $failure keeps memory (stored=$hasStoredSession)',
        (tester) async {
          if (!hasStoredSession) _seedSession(null);
          var rejectGuest = true;
          final storage = _Storage()..failWrite = true;
          final server = _Server(
            respond: (request) async {
              if (request.url.path == _refresh) return _failure('401');
              if (request.url.path == _categories) {
                if (request.headers['Authorization'] == 'Bearer test-access') {
                  return _failure('401');
                }
                if (rejectGuest) return _failure(failure);
              }
              return null;
            },
          );
          await _runApp(tester, server, (_) async {
            _expectError();
            expect(server.calls(_guest), hasLength(1));
            expect(storage.clears, hasStoredSession ? 1 : 0);
            expect(await ApiSessionStorage().read(), isNull);
            rejectGuest = false;
            await _retry(tester);
            _expectLoaded(tester);
            expect(storage.reads, 1);
            expect(server.calls(_guest), hasLength(1));
            expect(
              server.calls(_categories).last.headers['Authorization'],
              'Bearer guest-access',
            );
            expect(storage.writes, greaterThan(0));
          }, storage: storage);
        },
      );
    }
  }

  testWidgets(
    'first launch persists one guest across a feed failure and retry',
    (tester) async {
      _seedSession(null);
      var failFeedOnce = true;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _feed && failFeedOnce) {
            failFeedOnce = false;
            return _failure('503');
          }
          return null;
        },
      );
      await _runApp(tester, server, (storage) async {
        _expectError();
        expect(server.calls(_guest), hasLength(1));
        final persisted = await ApiSessionStorage().read();
        expect(persisted?.accessToken, 'guest-access');
        expect(persisted?.refreshToken, 'guest-refresh');
        expect(storage.clears, 0);

        await _retry(tester);

        _expectLoaded(tester);
        expect(storage.reads, 1);
        expect(server.calls(_guest), hasLength(1));
        expect(
          server
              .calls(_feed)
              .map((request) => request.headers['Authorization']),
          ['Bearer guest-access', 'Bearer guest-access'],
        );
      });
    },
  );

  testWidgets(
    'loading and errors hide sample Home; duplicate retry starts one request',
    (tester) async {
      final first = Completer<http.Response?>();
      final retry = Completer<http.Response?>();
      var categoryCalls = 0;
      final server = _Server(
        respond: (request) async {
          if (request.url.path != _categories) return null;
          categoryCalls++;
          return categoryCalls == 1 ? first.future : retry.future;
        },
      );
      addTearDown(() {
        if (!first.isCompleted) first.complete(_failure('503'));
        if (!retry.isCompleted) retry.complete(_json([_category]));
      });
      await _runApp(tester, server, (storage) async {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        expect(find.byType(AddContentSheet), findsNothing);
        first.complete(_failure('503'));
        await tester.pumpAndSettle();
        _expectError();

        final retryButton = tester.widget<PrimaryButton>(
          find.byWidgetPredicate(
            (widget) => widget is PrimaryButton && widget.label == '다시 시도',
          ),
        );
        retryButton.onPressed();
        retryButton.onPressed();
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        expect(categoryCalls, 2);
        retry.complete(_json([_category]));
        await tester.pumpAndSettle();
        _expectLoaded(tester);
        expect(storage.reads, 1);
        expect(
          server.requests.every((request) => request.method == 'GET'),
          isTrue,
        );
      }, settle: false);
    },
  );
}
