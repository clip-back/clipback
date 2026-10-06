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

const _preferencesChannel = MethodChannel(
  'plugins.flutter.io/shared_preferences',
);
const _sessionKey = 'flutter.clipback.session';
const _warning = '로그인 정보를 기기에 저장하지 못했어요. 앱을 종료하기 전에 다시 저장해 주세요.';
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
const _third = ApiSession(
  accessToken: 'third-access',
  refreshToken: 'third-refresh',
  expiresIn: 10800,
  refreshExpiresIn: 259200,
);
const _category = {
  'id': 101,
  'name': '공부',
  'color': '#059669',
  'is_default': false,
  'content_count': 0,
  'last_saved_at': null,
};

Map<String, Object> _sessionJson(ApiSession session) => {
  'access_token': session.accessToken,
  'refresh_token': session.refreshToken,
  'expires_in': session.expiresIn,
  'refresh_expires_in': session.refreshExpiresIn,
};

Map<String, Object> _legacy() => {
  'flutter.clipback.access_token': _old.accessToken,
  'flutter.clipback.refresh_token': _old.refreshToken,
  'flutter.clipback.expires_in': _old.expiresIn,
  'flutter.clipback.refresh_expires_in': _old.refreshExpiresIn,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _expectSession(ApiSession? actual, ApiSession expected) {
  expect(actual?.accessToken, expected.accessToken);
  expect(actual?.refreshToken, expected.refreshToken);
  expect(actual?.expiresIn, expected.expiresIn);
  expect(actual?.refreshExpiresIn, expected.refreshExpiresIn);
}

Future<ApiSession?> _readFromDisk() async {
  SharedPreferences.resetStatic();
  return ApiSessionStorage().read();
}

// Keep platform data separate from SharedPreferences' cache, including failed setters.
class _BackingStore {
  _BackingStore(Map<String, Object> initial) : data = Map.of(initial);

  final Map<String, Object> data;
  final calls = <MethodCall>[];
  Future<bool> Function(String, Object)? onSet;
  Future<bool> Function(String)? onRemove;

  void install() {
    SharedPreferences.resetStatic();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_preferencesChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getAll':
        case 'getAllWithParameters':
          return Map<String, Object>.of(data);
        case 'setString':
        case 'setInt':
          final args = Map<String, Object>.from(call.arguments as Map);
          final key = args['key']! as String;
          final value = args['value']!;
          final success = await onSet?.call(key, value) ?? true;
          if (success) data[key] = value;
          return success;
        case 'remove':
          final key = (call.arguments as Map)['key'] as String;
          final success = await onRemove?.call(key) ?? true;
          if (success) data.remove(key);
          return success;
        default:
          throw StateError('Unexpected preferences operation: ${call.method}');
      }
    });
    addTearDown(() {
      SharedPreferences.resetStatic();
      messenger.setMockMethodCallHandler(_preferencesChannel, null);
    });
  }

  List<MethodCall> get setters =>
      calls.where((call) => call.method.startsWith('set')).toList();
  List<String> get removedKeys => calls
      .where((call) => call.method == 'remove')
      .map((call) => (call.arguments as Map)['key'] as String)
      .toList();
}

_BackingStore _store([Map<String, Object>? data]) =>
    _BackingStore(data ?? _legacy())..install();

class _Server {
  _Server({this.respond});

  final Future<http.Response?> Function(http.Request)? respond;
  final requests = <http.Request>[];
  int rotations = 0;
  int creations = 0;
  bool rotateAgain = false;
  late final client = MockClient((request) async {
    requests.add(request);
    final response = await respond?.call(request);
    if (response != null) return response;
    if (request.url.path == '/api/v1/auth/refresh') {
      rotations++;
      return _json(_sessionJson(rotations == 1 ? _rotated : _third));
    }
    if (request.url.path == '/api/v1/categories' && request.method == 'POST') {
      final authorization = request.headers['Authorization'];
      if (authorization == 'Bearer old-access' ||
          (rotateAgain && authorization == 'Bearer rotated-access')) {
        return _json({'detail': 'Invalid or expired access token'}, 401);
      }
      creations++;
      return _json({
        ..._category,
        'id': 101 + creations,
        'name': jsonDecode(request.body)['name'],
      }, 201);
    }
    switch (request.url.path) {
      case '/api/v1/auth/guest':
        return _json(_sessionJson(_rotated), 201);
      case '/api/v1/auth/logout':
        return http.Response('', 204);
      case '/api/v1/categories':
        return _json([_category]);
      case '/api/v1/feed':
        return _json({'items': <Object>[], 'next_cursor': null});
      case '/api/v1/users/me':
        return _json({
          'id': 1,
          'email': null,
          'display_name': '테스트 계정',
          'is_guest': true,
          'created_at': '2026-10-05T00:00:00Z',
          'linked_providers': <String>[],
        });
      case '/api/v1/users/me/stats':
        return _json({'saved_count': 0, 'reopened_count': 0});
      default:
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
    }
  });

  List<http.Request> calls(String path) =>
      requests.where((request) => request.url.path == path).toList();
}

Widget _app() => Theme(
  data: ThemeData(fontFamily: 'Pretendard'),
  child: const ClipbackApp(),
);

Future<void> _withApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check,
) async {
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await check();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _openCategories(WidgetTester tester) async {
  tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenCategories();
  await tester.pumpAndSettle();
}

Future<void> _createCategory(
  WidgetTester tester, {
  String name = '추가 분류',
  bool settle = true,
}) async {
  tester
      .widget<ArchiveScreen>(find.byType(ArchiveScreen))
      .onAddCategory(
        CategoryItem(
          name: name,
          color: Colors.green,
          tint: Colors.green,
          deep: Colors.green,
        ),
      );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
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

  for (final stringExpiry in [false, true]) {
    test(
      'legacy session remains readable (string expiry=$stringExpiry)',
      () async {
        final data = _legacy();
        if (stringExpiry) {
          data['flutter.clipback.expires_in'] = '3600';
          data['flutter.clipback.refresh_expires_in'] = '86400';
        }
        final backing = _store(data);
        _expectSession(await ApiSessionStorage().read(), _old);
        expect(backing.setters, isEmpty);
        expect(backing.removedKeys, isEmpty);
      },
    );
  }

  test(
    'canonical session takes priority over legacy and restores all fields',
    () async {
      _store({..._legacy(), _sessionKey: jsonEncode(_sessionJson(_rotated))});
      _expectSession(await _readFromDisk(), _rotated);
    },
  );

  for (final malformed in ['{broken', '[]', '{"access_token":7}']) {
    test(
      'malformed canonical data does not restore stale legacy tokens: $malformed',
      () async {
        final backing = _store({..._legacy(), _sessionKey: malformed});
        await expectLater(ApiSessionStorage().read(), throwsA(anything));
        expect(backing.data[_sessionKey], malformed);
        expect(backing.setters, isEmpty);
        expect(backing.removedKeys, isEmpty);
      },
    );
  }

  test('session write persists one complete record beyond the cache', () async {
    final backing = _store();
    await ApiSessionStorage().write(_rotated);
    _expectSession(await _readFromDisk(), _rotated);
    expect(backing.setters, hasLength(1));
    expect(
      jsonDecode(backing.data[_sessionKey]! as String),
      _sessionJson(_rotated),
    );
  });

  for (final failedPath in [
    '/api/v1/feed',
    '/api/v1/users/me',
    '/api/v1/users/me/stats',
  ]) {
    testWidgets('refresh remains persisted when $failedPath fails afterward', (
      tester,
    ) async {
      final backing = _store();
      final server = _Server(
        respond: (request) async {
          if (request.url.path == '/api/v1/categories' &&
              request.method == 'GET' &&
              request.headers['Authorization'] == 'Bearer old-access') {
            return _json({'detail': 'Invalid or expired access token'}, 401);
          }
          if (request.url.path == failedPath) {
            return _json({'detail': 'Temporary upstream failure'}, 503);
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        expect(server.rotations, 1);
        expect(server.calls(failedPath), hasLength(1));
        expect(server.calls('/api/v1/auth/guest'), isEmpty);
        expect(
          jsonDecode(backing.data[_sessionKey]! as String),
          _sessionJson(_rotated),
        );
        _expectSession(await _readFromDisk(), _rotated);
        if (failedPath == '/api/v1/feed') {
          expect(find.text('저장한 콘텐츠를 불러오지 못했어요.'), findsOneWidget);
          expect(find.byType(HomeScreen), findsNothing);
        } else {
          expect(find.byType(HomeScreen), findsOneWidget);
        }
      });
    });
  }

  for (final failure in ['false', 'throw']) {
    test(
      'platform setter $failure is a failed write after cache reset',
      () async {
        final backing = _store({_sessionKey: jsonEncode(_sessionJson(_old))});
        backing.onSet = (_, _) async {
          if (failure == 'throw') throw PlatformException(code: 'unavailable');
          return false;
        };
        await expectLater(
          ApiSessionStorage().write(_rotated),
          throwsA(anything),
        );
        _expectSession(await _readFromDisk(), _old);
      },
    );

    test('legacy removal $failure preserves canonical credentials', () async {
      final backing = _store({
        ..._legacy(),
        _sessionKey: jsonEncode(_sessionJson(_rotated)),
      });
      backing.onRemove = (key) async {
        if (key == 'flutter.clipback.refresh_token') {
          if (failure == 'throw') throw PlatformException(code: 'unavailable');
          return false;
        }
        return true;
      };
      await expectLater(ApiSessionStorage().clear(), throwsA(anything));
      expect(backing.removedKeys, isNot(contains(_sessionKey)));
      _expectSession(await _readFromDisk(), _rotated);
    });

    test(
      'canonical removal $failure reports failure and remains restorable',
      () async {
        final backing = _store({
          ..._legacy(),
          _sessionKey: jsonEncode(_sessionJson(_rotated)),
        });
        backing.onRemove = (key) async {
          if (key == _sessionKey) {
            if (failure == 'throw') {
              throw PlatformException(code: 'unavailable');
            }
            return false;
          }
          return true;
        };
        await expectLater(ApiSessionStorage().clear(), throwsA(anything));
        expect(backing.removedKeys.last, _sessionKey);
        _expectSession(await _readFromDisk(), _rotated);
      },
    );
  }

  test(
    'successful clear removes legacy first and prevents fallback after restart',
    () async {
      final backing = _store({
        ..._legacy(),
        _sessionKey: jsonEncode(_sessionJson(_rotated)),
      });
      await ApiSessionStorage().clear();
      expect(backing.removedKeys, hasLength(5));
      expect(backing.removedKeys.last, _sessionKey);
      expect(await _readFromDisk(), isNull);
    },
  );

  for (final action in ['guest', 'refresh', 'social', 'upgrade']) {
    test('$action publishes its session and awaits persistence', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final events = <ApiSession>[];
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _json(_sessionJson(_rotated));
      });
      addTearDown(client.close);
      final api = ClipbackApi(
        client: client,
        onSessionChanged: (session) async {
          events.add(session);
          entered.complete();
          await release.future;
        },
      )..restoreSession(_old);
      expect(
        events,
        isEmpty,
        reason: 'Restoring a session is not a new-token event.',
      );
      var completed = false;
      final operation = switch (action) {
        'guest' => api.createGuestSession(),
        'refresh' => api.refreshSession(),
        'social' => api.socialLogin(
          provider: 'google',
          token: 'test-provider-token',
        ),
        'upgrade' => api.upgradeGuestWithSocial(
          provider: 'google',
          token: 'test-provider-token',
        ),
        _ => throw StateError('Unknown action'),
      };
      final result = operation.then((session) {
        completed = true;
        return session;
      });
      await entered.future;
      _expectSession(api.session, _rotated);
      expect(completed, isFalse);
      release.complete();
      _expectSession(await result, _rotated);
      expect(events, hasLength(1));
      expect(requests, hasLength(1));
    });
  }

  test(
    'callback failure is reported while the new memory session survives',
    () async {
      final client = MockClient((_) async => _json(_sessionJson(_rotated)));
      addTearDown(client.close);
      final api = ClipbackApi(
        client: client,
        onSessionChanged: (_) async => throw StateError('Disk unavailable'),
      );
      await expectLater(api.createGuestSession(), throwsStateError);
      _expectSession(api.session, _rotated);
    },
  );

  test(
    'authenticated retry waits until refreshed tokens reach the backing store',
    () async {
      final backing = _store();
      final started = Completer<void>();
      final release = Completer<bool>();
      backing.onSet = (_, _) async {
        started.complete();
        return release.future;
      };
      final server = _Server();
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: ApiSessionStorage().write,
      )..restoreSession(_old);
      final creation = api.createCategory(name: '추가 분류');
      await started.future;
      expect(server.calls('/api/v1/categories'), hasLength(1));
      expect(server.creations, 0);
      _expectSession(api.session, _rotated);
      release.complete(true);
      expect((await creation).id, 102);
      expect(
        server.calls('/api/v1/categories').last.headers['Authorization'],
        'Bearer rotated-access',
      );
      _expectSession(await _readFromDisk(), _rotated);
    },
  );

  testWidgets(
    'category creation persists rotated tokens and a new app restores them',
    (tester) async {
      final backing = _store();
      final server = _Server();
      await _withApp(tester, server, () async {
        await _openCategories(tester);
        await _createCategory(tester);
        expect(find.text('추가 분류'), findsWidgets);
        expect(server.rotations, 1);
        expect(server.creations, 1);
        expect(server.calls('/api/v1/feed'), hasLength(1));
        expect(
          jsonDecode(
            server.calls('/api/v1/auth/refresh').single.body,
          )['refresh_token'],
          'old-refresh',
        );
        _expectSession(await _readFromDisk(), _rotated);
        expect(
          backing.calls.where((call) => call.method == 'getAll').length,
          2,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        SharedPreferences.resetStatic();
        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(
          server.calls('/api/v1/categories').last.headers['Authorization'],
          'Bearer rotated-access',
        );
        expect(server.rotations, 1);
        expect(server.calls('/api/v1/auth/guest'), isEmpty);
      });
    },
  );

  for (final failure in ['false', 'throw']) {
    testWidgets(
      'persistence $failure keeps the operation working and retry removes the warning',
      (tester) async {
        final backing = _store();
        var fail = true;
        backing.onSet = (_, _) async {
          if (fail) {
            if (failure == 'throw') {
              throw PlatformException(code: 'unavailable');
            }
            return false;
          }
          return true;
        };
        final server = _Server();
        await _withApp(tester, server, () async {
          await _openCategories(tester);
          await _createCategory(tester);
          expect(server.creations, 1);
          expect(find.text('추가 분류'), findsWidgets);
          expect(find.text(_warning), findsOneWidget);
          _expectSession(await _readFromDisk(), _old);
          List<int> networkCounts() => [
            server.calls('/api/v1/auth/refresh').length,
            server
                .calls('/api/v1/categories')
                .where((request) => request.method == 'POST')
                .length,
            server.calls('/api/v1/auth/guest').length,
          ];
          expect(networkCounts(), [1, 2, 0]);
          final initialWrites = backing.setters.length;
          for (var attempt = 1; attempt <= 2; attempt++) {
            await tester.tap(find.text('다시 저장'));
            await tester.pumpAndSettle();
            expect(find.text(_warning), findsOneWidget);
            expect(backing.setters, hasLength(initialWrites + attempt));
            _expectSession(await _readFromDisk(), _old);
            expect(networkCounts(), [1, 2, 0]);
          }
          fail = false;
          await tester.tap(find.text('다시 저장'));
          await tester.pumpAndSettle();
          expect(find.text(_warning), findsNothing);
          _expectSession(await _readFromDisk(), _rotated);
          expect(networkCounts(), [1, 2, 0]);
        });
      },
    );
  }

  testWidgets(
    'a failed clear does not block guest persistence on the next restore attempt',
    (tester) async {
      final backing = _store();
      var canClear = false;
      backing.onRemove = (key) async =>
          key != 'flutter.clipback.refresh_token' || canClear;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == '/api/v1/auth/refresh' ||
              (request.url.path == '/api/v1/categories' &&
                  request.headers['Authorization'] == 'Bearer old-access')) {
            return _json({'detail': 'Invalid or expired token'}, 401);
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        expect(find.text('저장한 콘텐츠를 불러오지 못했어요.'), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        expect(server.calls('/api/v1/auth/guest'), isEmpty);
        expect(backing.removedKeys, isNot(contains(_sessionKey)));
        canClear = true;
        await tester.tap(find.text('다시 시도'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(server.calls('/api/v1/auth/guest'), hasLength(1));
        expect(server.calls('/api/v1/auth/refresh'), hasLength(2));
        expect(backing.setters, hasLength(1));
        expect(backing.removedKeys.last, _sessionKey);
        _expectSession(await _readFromDisk(), _rotated);
      });
    },
  );

  testWidgets(
    'retry serializes writes and preserves a newer failure until the latest session is saved',
    (tester) async {
      final backing = _store();
      final release = Completer<bool>();
      var retrying = false;
      var failThird = true;
      final writes = <String>[];
      backing.onSet = (_, value) async {
        final access = jsonDecode(value as String)['access_token'] as String;
        writes.add(access);
        if (access == 'rotated-access') {
          return retrying ? release.future : false;
        }
        return !failThird;
      };
      addTearDown(() {
        if (!release.isCompleted) release.complete(true);
      });
      final server = _Server();
      await _withApp(tester, server, () async {
        await _openCategories(tester);
        await _createCategory(tester);
        expect(find.text(_warning), findsOneWidget);
        retrying = true;
        final action = tester
            .widget<TextButton>(find.widgetWithText(TextButton, '다시 저장'))
            .onPressed!;
        action();
        action();
        await tester.pump();
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '다시 저장'))
              .onPressed,
          isNull,
        );

        server.rotateAgain = true;
        await _createCategory(tester, name: '두 번째 분류', settle: false);
        expect(server.rotations, 2);
        expect(writes, ['rotated-access', 'rotated-access']);
        release.complete(true);
        await tester.pumpAndSettle();
        expect(server.creations, 2);
        expect(find.text(_warning), findsOneWidget);
        _expectSession(await _readFromDisk(), _rotated);
        failThird = false;
        await tester.tap(find.text('다시 저장'));
        await tester.pumpAndSettle();
        expect(find.text(_warning), findsNothing);
        _expectSession(await _readFromDisk(), _third);
        expect(writes, [
          'rotated-access',
          'rotated-access',
          'third-access',
          'third-access',
        ]);
      });
    },
  );

  testWidgets(
    'logout waits for pending writes and prevents queued credentials from returning',
    (tester) async {
      final backing = _store();
      final release = Completer<bool>();
      final writes = <String>[];
      backing.onSet = (_, value) async {
        writes.add(jsonDecode(value as String)['access_token'] as String);
        return release.future;
      };
      addTearDown(() {
        if (!release.isCompleted) release.complete(true);
      });
      final server = _Server();
      await _withApp(tester, server, () async {
        await _openCategories(tester);
        await _createCategory(tester, settle: false);
        expect(writes, ['rotated-access']);
        server.rotateAgain = true;
        await _createCategory(tester, name: '두 번째 분류', settle: false);
        expect(server.rotations, 2);
        tester
            .widget<ArchiveScreen>(find.byType(ArchiveScreen))
            .onTab(AppRoute.my);
        await tester.pump();
        tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
        await tester.pump();
        final logout = tester
            .widget<AccountManagementScreen>(
              find.byType(AccountManagementScreen),
            )
            .onLogout();
        await tester.pump();
        expect(server.calls('/api/v1/auth/logout'), hasLength(1));
        expect(
          backing.removedKeys,
          isEmpty,
          reason: 'Clear must wait for the active writer.',
        );
        release.complete(true);
        await tester.pumpAndSettle();
        await logout;
        expect(await _readFromDisk(), isNull);
        expect(
          writes,
          ['rotated-access'],
          reason: 'A queued writer must observe the cleared memory session.',
        );
        expect(backing.removedKeys.last, _sessionKey);
        expect(
          jsonDecode(
            server.calls('/api/v1/auth/logout').single.body,
          )['refresh_token'],
          'third-refresh',
        );
        expect(find.text(_warning), findsNothing);
      });
    },
  );
}
