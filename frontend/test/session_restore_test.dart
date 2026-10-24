import 'support/app_startup.dart';
import 'auth_navigation.dart';

import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
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
  Completer<void>? readGate;
  bool failWrite = false;
  bool failClear = false;

  @override
  Future<ApiSession?> read() async {
    reads++;
    await readGate?.future;
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
    if (request.url.path == '/api/v1/recommendations/weekly') {
      return _json({
        'period_start': '2026-10-19T00:00:00Z',
        'period_end': '2026-10-26T00:00:00Z',
        'batch_id': null,
        'generated_at': null,
        'items': <Object>[],
      });
    }
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
      await completeAppStartup(tester, settle: settle);
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
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

  for (final refresh in [false, true]) {
    testWidgets('홈 최초 불러오기는 조회 단계와 인증 갱신 시간을 합산한다 (refresh=$refresh)', (
      tester,
    ) async {
      final category = Completer<http.Response?>();
      final refreshResponse = Completer<http.Response?>();
      final feed = Completer<http.Response?>();
      var first = true;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _categories && first) {
            first = false;
            return category.future;
          }
          if (request.url.path == _refresh) return refreshResponse.future;
          if (request.url.path == _feed) return feed.future;
          return null;
        },
      );
      await _runApp(tester, server, (storage) async {
        await tester.pump(const Duration(milliseconds: 7100));
        category.complete(refresh ? _failure('401') : _json([_category]));
        await tester.pump();
        if (refresh) {
          await tester.pump(const Duration(seconds: 4));
          refreshResponse.complete(_tokens('current'));
          await tester.pump();
        }
        expect(server.calls(_feed), hasLength(1));
        await tester.pump(Duration(milliseconds: refresh ? 2999 : 6999));
        expect(find.text('다시 시도'), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        _expectError();
        expect(storage.clears, 0);
        expect(server.calls(_guest), isEmpty);
        feed.complete(_json({'items': <Object>[], 'next_cursor': null}));
        await tester.pumpAndSettle();
        _expectError();
        expect(
          (await ApiSessionStorage().read())?.accessToken,
          refresh ? 'current-access' : 'test-access',
        );
      }, settle: false);
    });
  }

  testWidgets('홈 불러오기 재시도는 연속 입력에도 하나의 새로운15초를 사용한다', (tester) async {
    final pending = [Completer<http.Response?>(), Completer<http.Response?>()];
    var categories = 0;
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _categories && categories++ < 2) {
          return pending[categories - 1].future;
        }
        return null;
      },
    );
    await _runApp(tester, server, (storage) async {
      await tester.pump(const Duration(milliseconds: 14100));
      await tester.pump();
      _expectError();
      await tester.tap(find.text('다시 시도'));
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      expect(server.calls(_categories), hasLength(2));
      await tester.pump(const Duration(milliseconds: 14999));
      expect(
        find.byKey(const ValueKey('home-initial-loading-screen')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      _expectError();
      await _retry(tester);
      _expectLoaded(tester);
      for (final response in pending) {
        response.complete(_failure('401'));
      }
      await tester.pumpAndSettle();
      _expectLoaded(tester);
      expect(server.calls(_categories), hasLength(3));
      expect(server.calls(_refresh), isEmpty);
      expect(storage.clears, 0);
    }, settle: false);
  });

  for (final path in [_categories, _feed]) {
    for (final status in [200, 503, 401]) {
      testWidgets('끝난 홈 시도의 $path 늦은$status 응답은 새 홈과 계정을 바꾸지 않는다', (
        tester,
      ) async {
        final old = Completer<http.Response?>();
        var first = true;
        final server = _Server(
          respond: (request) async {
            if (request.url.path == path && first) {
              first = false;
              return old.future;
            }
            return null;
          },
        );
        await _runApp(tester, server, (storage) async {
          await tester.pump(const Duration(milliseconds: 14100));
          await tester.pump();
          _expectError();
          await _retry(tester);
          _expectLoaded(tester);
          old.complete(
            status == 200
                ? _json(
                    path == _categories
                        ? [_category]
                        : {'items': <Object>[], 'next_cursor': null},
                  )
                : _failure('$status'),
          );
          await tester.pumpAndSettle();
          _expectLoaded(tester);
          expect(server.calls(path), hasLength(2));
          expect(server.calls(_refresh), isEmpty);
          expect(server.calls(_guest), isEmpty);
          expect(storage.clears, 0);
          expect(
            (await ApiSessionStorage().read())?.accessToken,
            'test-access',
          );
        }, settle: false);
      });
    }
  }

  for (final status in [200, 401]) {
    testWidgets('끝난 홈 시도의 늦은refresh$status 응답은 새 인증을 되돌리지 않는다', (tester) async {
      final category = Completer<http.Response?>();
      final oldRefresh = Completer<http.Response?>();
      var first = true;
      var refreshes = 0;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _categories) {
            if (first) {
              first = false;
              return category.future;
            }
            if (request.headers['Authorization'] == 'Bearer test-access') {
              return _failure('401');
            }
          }
          if (request.url.path == _refresh) {
            return ++refreshes == 1 ? oldRefresh.future : _tokens('retry');
          }
          return null;
        },
      );
      await _runApp(tester, server, (storage) async {
        await tester.pump(const Duration(milliseconds: 7100));
        category.complete(_failure('401'));
        await tester.pump();
        expect(server.calls(_refresh), hasLength(1));
        await tester.pump(const Duration(seconds: 7));
        await tester.pump();
        _expectError();
        await _retry(tester);
        _expectLoaded(tester);
        expect(server.calls(_refresh), hasLength(2));
        expect((await ApiSessionStorage().read())?.accessToken, 'retry-access');
        oldRefresh.complete(status == 200 ? _tokens('old') : _failure('401'));
        await tester.pumpAndSettle();
        _expectLoaded(tester);
        expect((await ApiSessionStorage().read())?.accessToken, 'retry-access');
        expect(storage.writes, 1);
        expect(storage.clears, 0);
      }, settle: false);
    });
  }

  testWidgets('14초에 열린 홈의 부가 조회는 최초15초 제한 뒤에도 유효하다', (tester) async {
    final categories = Completer<http.Response?>();
    final profile = Completer<http.Response?>();
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _categories) return categories.future;
        if (request.url.path == _me) return profile.future;
        return null;
      },
    );
    await _runApp(tester, server, (storage) async {
      await tester.pump(const Duration(milliseconds: 13100));
      categories.complete(_json([_category]));
      await tester.pump();
      await tester.pump();
      _expectLoaded(tester);
      await tester.pump(const Duration(seconds: 2));
      profile.complete(
        _json({
          'id': 1,
          'email': null,
          'display_name': '나중에 확인된 계정',
          'is_guest': true,
          'created_at': '2026-10-05T00:00:00Z',
          'linked_providers': <String>[],
        }),
      );
      await tester.pumpAndSettle();
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MyScreen>(find.byType(MyScreen)).user.name,
        '나중에 확인된 계정',
      );
      expect(storage.clears, 0);
    }, settle: false);
  });

  testWidgets('토큰 저장소를 기다린 시간은 홈 최초 불러오기15초에 포함하지 않는다', (tester) async {
    final read = Completer<void>();
    final storage = _Storage()..readGate = read;
    final categories = Completer<http.Response?>();
    final server = _Server(
      respond: (request) async =>
          request.url.path == _categories ? categories.future : null,
    );
    await _runApp(
      tester,
      server,
      (_) async {
        await tester.pump(const Duration(seconds: 20));
        expect(server.requests, isEmpty);
        expect(find.text('다시 시도'), findsNothing);
        read.complete();
        await tester.pump();
        expect(server.calls(_categories), hasLength(1));
        await tester.pump(const Duration(milliseconds: 14999));
        expect(find.text('다시 시도'), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        _expectError();
        expect(storage.clears, 0);
      },
      storage: storage,
      settle: false,
    );
  });

  testWidgets('홈 최초 불러오기는 전체15초에 복구하고 수동 재시도만 새 시도를 연다', (tester) async {
    final first = Completer<http.Response?>();
    var categories = 0;
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _categories && ++categories == 1) {
          return first.future;
        }
        return null;
      },
    );
    await _runApp(tester, server, (storage) async {
      await tester.pump(const Duration(milliseconds: 14099));
      expect(find.text('다시 시도'), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      _expectError();
      await tester.pump(const Duration(seconds: 20));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      _expectError();
      expect(server.calls(_categories), hasLength(1));
      expect(storage.clears, 0);
      expect(server.calls(_guest), isEmpty);
      await _retry(tester);
      _expectLoaded(tester);
      first.complete(_json([_category]));
      await tester.pumpAndSettle();
      _expectLoaded(tester);
      expect(server.calls(_feed), hasLength(1));
      expect((await ApiSessionStorage().read())?.accessToken, 'test-access');
    }, settle: false);
  });

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
        '$path final 401 waits for a new guest choice (refresh=$refreshSucceeds)',
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
            expect(find.byType(LoginScreen), findsOneWidget);
            expect(server.calls(_guest), isEmpty);
            await startGuestAndFinishOnboarding(tester);
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
    testWidgets('$path 지연 중에도 홈 최초 불러오기를 마치고 유효한 후속 정보를 반영한다', (tester) async {
      final metadata = Completer<http.Response?>();
      final server = _Server(
        respond: (request) async =>
            request.url.path == path ? metadata.future : null,
      );
      await _runApp(tester, server, (storage) async {
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump();
        _expectLoaded(tester);
        tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
        await tester.pumpAndSettle();
        final before = tester.widget<MyScreen>(find.byType(MyScreen)).user;
        if (path == _me) {
          expect(before.name, '계정 정보 확인 중');
        } else {
          expect(before.name, '테스트 계정');
          expect(before.savedContentCount, 0);
        }
        metadata.complete(
          path == _me ? null : _json({'saved_count': 9, 'reopened_count': 3}),
        );
        await tester.pumpAndSettle();
        final after = tester.widget<MyScreen>(find.byType(MyScreen)).user;
        expect(after.name, '테스트 계정');
        expect(after.savedContentCount, path == _me ? 1 : 9);
        expect(storage.clears, 0);
        expect(server.calls(_guest), isEmpty);
      }, settle: false);
    });
  }

  testWidgets('홈 최초 불러오기는 정상적인 빈 첫 목록도 준비 완료로 본다', (tester) async {
    final server = _Server(
      respond: (request) async => request.url.path == _feed
          ? _json({'items': <Object>[], 'next_cursor': null})
          : null,
    );
    await _runApp(tester, server, (storage) async {
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        tester.widget<HomeScreen>(find.byType(HomeScreen)).contents,
        isEmpty,
      );
      expect(server.calls(_feed), hasLength(1));
      expect(storage.clears, 0);
    });
  });

  testWidgets('홈 불러오기 재시도는 필수 목록이 즉시 와도 최소900ms 표시한다', (tester) async {
    var fail = true;
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _categories && fail) return _failure('503');
        return null;
      },
    );
    await _runApp(tester, server, (storage) async {
      _expectError();
      fail = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 899));
      expect(
        find.byKey(const ValueKey('home-initial-loading-screen')),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      _expectLoaded(tester);
    });
  });

  for (final bootstrapPath in [_me, _stats]) {
    testWidgets('$bootstrapPath 늦은 최초 홈 응답은 콘텐츠 변경 뒤 최신 계정과 집계 값을 되돌리지 않는다', (
      tester,
    ) async {
      final bootstrapResponse = Completer<http.Response?>();
      var statsReads = 0;
      var changed = false;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _stats) {
            if (bootstrapPath == _stats && ++statsReads == 1) {
              return bootstrapResponse.future;
            }
            return _json({'saved_count': 9, 'reopened_count': 3});
          }
          if (request.url.path == '/api/v1/contents/7/favorite') {
            changed = true;
            return _json({
              'id': 7,
              'categories': [_category],
              'tags': <Object>[],
              'assets': <Object>[],
              'content_type': 'link',
              'source': 'web',
              'title': '사용자가 저장한 링크',
              'summary': '서버에서 조회한 콘텐츠',
              'original_url': 'https://example.com/saved',
              'is_favorite': true,
              'saved_at': '2026-10-05T00:00:00Z',
              'last_viewed_at': null,
            });
          }
          if (request.url.path == _me && bootstrapPath == _me && !changed) {
            return bootstrapResponse.future;
          }
          if (request.url.path == _me && changed) {
            return _json({
              'id': 1,
              'email': null,
              'display_name': '최신 계정',
              'is_guest': true,
              'created_at': '2026-10-05T00:00:00Z',
              'linked_providers': <String>[],
            });
          }
          return null;
        },
      );
      await _runApp(tester, server, (storage) async {
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump();
        _expectLoaded(tester);
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        home.onToggleBookmark(home.contents.single);
        await tester.pumpAndSettle();
        tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
        await tester.pumpAndSettle();
        final updated = tester.widget<MyScreen>(find.byType(MyScreen)).user;
        expect(updated.name, '최신 계정');
        expect(updated.savedContentCount, 9);
        expect(updated.revisitedContentCount, 3);
        bootstrapResponse.complete(
          _json(
            bootstrapPath == _me
                ? {
                    'id': 1,
                    'email': null,
                    'display_name': '예전 계정',
                    'is_guest': true,
                    'created_at': '2026-10-05T00:00:00Z',
                    'linked_providers': <String>[],
                  }
                : {'saved_count': 1, 'reopened_count': 0},
          ),
        );
        await tester.pumpAndSettle();
        final afterLateBootstrap = tester
            .widget<MyScreen>(find.byType(MyScreen))
            .user;
        expect(afterLateBootstrap.name, '최신 계정');
        expect(afterLateBootstrap.savedContentCount, 9);
        expect(afterLateBootstrap.revisitedContentCount, 3);
        expect(storage.clears, 0);
      }, settle: false);
    });
  }

  testWidgets('종료된 홈 부가 조회의 늦은 사용자 정보는 현재 계정에 반영하지 않는다', (tester) async {
    final profile = Completer<http.Response?>();
    final server = _Server(
      respond: (request) async =>
          request.url.path == _me ? profile.future : null,
    );
    await _runApp(tester, server, (storage) async {
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      _expectLoaded(tester);
      await tester.pump(const Duration(seconds: 11));
      profile.complete(
        _json({
          'id': 1,
          'email': null,
          'display_name': '종료 뒤 도착한 계정',
          'is_guest': true,
          'created_at': '2026-10-05T00:00:00Z',
          'linked_providers': <String>[],
        }),
      );
      await tester.pumpAndSettle();
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MyScreen>(find.byType(MyScreen)).user.name,
        '계정 정보 확인 중',
      );
      expect(storage.clears, 0);
    }, settle: false);
  });

  testWidgets('종료된 부가 조회의 늦은401은 세션을 갱신하거나 삭제하지 않는다', (tester) async {
    final profile = Completer<http.Response?>();
    final server = _Server(
      respond: (request) async =>
          request.url.path == _me ? profile.future : null,
    );
    await _runApp(tester, server, (storage) async {
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      _expectLoaded(tester);
      await tester.pump(const Duration(seconds: 11));
      profile.complete(_failure('401'));
      await tester.pumpAndSettle();
      _expectLoaded(tester);
      expect(server.calls(_refresh), isEmpty);
      expect(storage.clears, 0);
      expect((await ApiSessionStorage().read())?.accessToken, 'test-access');
    }, settle: false);
  });

  testWidgets('종료된 부가 조회가 단독 시작한 늦은 갱신은 토큰을 저장하지 않는다', (tester) async {
    final profile = Completer<http.Response?>();
    final refresh = Completer<http.Response?>();
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _me) return profile.future;
        if (request.url.path == _refresh) return refresh.future;
        return null;
      },
    );
    await _runApp(tester, server, (storage) async {
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      _expectLoaded(tester);
      await tester.pump(const Duration(seconds: 7));
      profile.complete(_failure('401'));
      await tester.pump();
      expect(server.calls(_refresh), hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      refresh.complete(_tokens('expired'));
      await tester.pumpAndSettle();
      _expectLoaded(tester);
      expect(storage.writes, 0);
      expect(storage.clears, 0);
      expect((await ApiSessionStorage().read())?.accessToken, 'test-access');
    }, settle: false);
  });

  testWidgets('부가 조회가 종료돼도 현재 검색이 공유한 인증 갱신은 완료한다', (tester) async {
    final profile = Completer<http.Response?>();
    final refresh = Completer<http.Response?>();
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _me &&
            request.headers['Authorization'] == 'Bearer test-access') {
          return profile.future;
        }
        if (request.url.path == _refresh) return refresh.future;
        if (request.url.path == _feed &&
            request.url.queryParameters['q'] != null &&
            request.headers['Authorization'] == 'Bearer test-access') {
          return _failure('401');
        }
        return null;
      },
    );
    await _runApp(tester, server, (storage) async {
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      _expectLoaded(tester);
      await tester.pump(const Duration(seconds: 7));
      profile.complete(_failure('401'));
      await tester.pump();
      expect(server.calls(_refresh), hasLength(1));
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onSearch();
      await tester.pumpAndSettle();
      final search = tester
          .widget<SearchScreen>(find.byType(SearchScreen))
          .onSearch('현재 검색');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      refresh.complete(_tokens('shared'));
      await tester.pumpAndSettle();
      expect((await search).map((item) => item.apiId), [7]);
      expect(storage.clears, 0);
      expect(server.calls(_refresh), hasLength(1));
      expect((await ApiSessionStorage().read())?.accessToken, 'shared-access');
    }, settle: false);
  });

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
      'failed invalid-session clear blocks access until retry (refresh=$refreshSucceeds)',
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
          storage.failClear = false;
          await _retry(tester);
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(await ApiSessionStorage().read(), isNull);
          expect(storage.reads, 1);
          expect(server.calls(_guest), isEmpty);
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
        'new guest lookup $failure follows recovery policy (stored=$hasStoredSession)',
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
            expect(find.byType(LoginScreen), findsOneWidget);
            await performLoginChoice(
              tester,
              () => tester
                  .widget<LoginScreen>(find.byType(LoginScreen))
                  .onContinue(),
            );
            await tester.pumpAndSettle();
            if (failure == '401') {
              expect(find.byType(LoginScreen), findsOneWidget);
              expect(server.calls(_guest), hasLength(1));
              expect(await ApiSessionStorage().read(), isNull);
              return;
            }
            _expectError();
            expect(server.calls(_guest), hasLength(1));
            expect(storage.clears, hasStoredSession ? 1 : 0);
            expect(await ApiSessionStorage().read(), isNull);
            rejectGuest = false;
            await _retry(tester);
            tester
                .widget<OnboardingScreen>(find.byType(OnboardingScreen))
                .onDone();
            await tester.pumpAndSettle();
            tester
                .widget<InterestSelectionScreen>(
                  find.byType(InterestSelectionScreen),
                )
                .onDone();
            await tester.pumpAndSettle();
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
        expect(server.requests, isEmpty);
        await performLoginChoice(
          tester,
          () =>
              tester.widget<LoginScreen>(find.byType(LoginScreen)).onContinue(),
        );
        await tester.pumpAndSettle();
        _expectError();
        expect(server.calls(_guest), hasLength(1));
        final persisted = await ApiSessionStorage().read();
        expect(persisted?.accessToken, 'guest-access');
        expect(persisted?.refreshToken, 'guest-refresh');
        expect(storage.clears, 0);

        await _retry(tester);
        tester.widget<OnboardingScreen>(find.byType(OnboardingScreen)).onDone();
        await tester.pumpAndSettle();
        tester
            .widget<InterestSelectionScreen>(
              find.byType(InterestSelectionScreen),
            )
            .onDone();
        await tester.pumpAndSettle();
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
        expect(
          find.byKey(const ValueKey('home-initial-loading-screen')),
          findsOneWidget,
        );
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
        expect(
          find.byKey(const ValueKey('home-initial-loading-screen')),
          findsOneWidget,
        );
        expect(find.byType(HomeScreen), findsNothing);
        expect(categoryCalls, 2);
        retry.complete(_json([_category]));
        await tester.pump(const Duration(milliseconds: 900));
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
