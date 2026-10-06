import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _asset = '/api/v1/uploads/assets/9';
const _refresh = '/api/v1/auth/refresh';
const _logout = '/api/v1/auth/logout';
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
final _image = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<({Object? value, Object? error})> _outcome(
  Future<dynamic> operation,
) async {
  try {
    return (value: await operation, error: null);
  } catch (error) {
    return (value: null, error: error);
  }
}

Map<String, Object> _tokens(ApiSession session) => {
  'access_token': session.accessToken,
  'refresh_token': session.refreshToken,
  'expires_in': session.expiresIn,
  'refresh_expires_in': session.refreshExpiresIn,
};

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _unauthorized() => _json({'detail': 'expired'}, 401);
http.Response _bytes() =>
    http.Response.bytes(_image, 200, headers: {'content-type': 'image/png'});

bool _expired(http.Request request) =>
    request.headers['Authorization'] == 'Bearer ${_old.accessToken}';

class _Server {
  _Server({this.respond});
  final Future<http.Response?> Function(http.Request)? respond;
  final requests = <http.Request>[];
  late final client = MockClient((request) async {
    requests.add(request);
    final response = await respond?.call(request);
    if (response != null) return response;
    return switch (request.url.path) {
      _asset => _bytes(),
      _refresh => _json(_tokens(_rotated)),
      _logout => http.Response('', 204),
      '/api/v1/categories' => _json(<Object>[]),
      _ => throw StateError('Unexpected request: ${request.url.path}'),
    };
  });
  List<http.Request> calls(String path) =>
      requests.where((request) => request.url.path == path).toList();
}

void _expectCancelled(Object? error) {
  expect(
    error,
    isA<ClipbackApiException>()
        .having((error) => error.statusCode, 'status', isNull)
        .having((error) => error.message, 'message', contains('로그인 상태가 변경')),
  );
}

Future<void> _turn() => Future<void>(() {});

void main() {
  test(
    'asset returns exact bytes through an authenticated image request',
    () async {
      final server = _Server();
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      expect(await api.readAsset(9), orderedEquals(_image));
      final request = server.calls(_asset).single;
      expect(request.method, 'GET');
      expect(request.url.query, isEmpty);
      expect(request.headers['Authorization'], 'Bearer ${_old.accessToken}');
      expect(request.headers['Accept'], 'image/png, image/jpeg, image/webp');
      expect(request.bodyBytes, isEmpty);
    },
  );

  test('asset without a session does not send a request', () async {
    final server = _Server();
    addTearDown(server.client.close);
    final api = ClipbackApi(client: server.client);
    expect(
      (await _outcome(api.readAsset(9))).error,
      isA<ClipbackApiException>(),
    );
    expect(server.requests, isEmpty);
  });

  testWidgets('asset and JSON 401 share refresh and wait for persistence', (
    tester,
  ) async {
    final saved = Completer<void>();
    var callbacks = 0;
    final server = _Server(
      respond: (request) async {
        if (_expired(request)) return _unauthorized();
        return null;
      },
    );
    addTearDown(server.client.close);
    final api = ClipbackApi(
      client: server.client,
      onSessionChanged: (_) async {
        callbacks++;
        await saved.future;
      },
    )..restoreSession(_old);
    var settled = false;
    final image = _outcome(api.readAsset(9)).then((result) {
      settled = true;
      return result;
    });
    final categories = _outcome(api.listCategories());
    await tester.pump();
    expect(server.calls(_refresh), hasLength(1));
    expect(callbacks, 1);
    expect(api.session?.accessToken, _rotated.accessToken);
    await tester.pump(const Duration(seconds: 12));
    expect(settled, isFalse);
    expect(server.calls(_asset), hasLength(1));
    expect(server.calls('/api/v1/categories'), hasLength(1));
    saved.complete();
    await tester.pump();
    expect((await image).value, orderedEquals(_image));
    expect((await categories).error, isNull);
    expect(server.calls(_asset), hasLength(2));
    expect(
      server.calls(_asset).last.headers['Authorization'],
      'Bearer ${_rotated.accessToken}',
    );
    expect(server.calls(_refresh), hasLength(1));
  });

  test('late asset 401 reuses the refresh already completed by JSON', () async {
    final firstAsset = Completer<http.Response?>();
    final started = Completer<void>();
    var callbacks = 0;
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _asset && _expired(request)) {
          started.complete();
          return firstAsset.future;
        }
        if (_expired(request)) return _unauthorized();
        return null;
      },
    );
    addTearDown(server.client.close);
    final api = ClipbackApi(
      client: server.client,
      onSessionChanged: (_) async {
        callbacks++;
      },
    )..restoreSession(_old);
    final image = api.readAsset(9);
    await started.future;
    await api.listCategories();
    firstAsset.complete(_unauthorized());
    expect(await image, orderedEquals(_image));
    expect(server.calls(_refresh), hasLength(1));
    expect(server.calls(_asset), hasLength(2));
    expect(callbacks, 1);
  });

  test(
    'handled persistence failure keeps new memory tokens for asset retry',
    () async {
      var storageFailures = 0;
      final server = _Server(
        respond: (request) async => _expired(request) ? _unauthorized() : null,
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async {
          // The app handles storage failures and displays its persistence banner.
          try {
            await Future<void>.error(StateError('Device storage unavailable'));
          } catch (_) {
            storageFailures++;
          }
        },
      )..restoreSession(_old);
      expect(await api.readAsset(9), orderedEquals(_image));
      expect(storageFailures, 1);
      expect(api.session?.refreshToken, _rotated.refreshToken);
      expect(server.calls(_asset), hasLength(2));
      expect(server.calls(_refresh), hasLength(1));
    },
  );

  test(
    'final asset 401 is returned after one refresh without clearing account',
    () async {
      final server = _Server(
        respond: (request) async =>
            request.url.path == _asset ? _unauthorized() : null,
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      expect(
        (await _outcome(api.readAsset(9))).error,
        isA<ClipbackApiException>().having(
          (error) => error.statusCode,
          'status',
          401,
        ),
      );
      expect(server.calls(_asset), hasLength(2));
      expect(server.calls(_refresh), hasLength(1));
      expect(api.session?.refreshToken, _rotated.refreshToken);
    },
  );

  for (final status in [403, 404, 503]) {
    test('asset $status does not refresh or retry', () async {
      final server = _Server(
        respond: (_) async => _json({'detail': 'Unavailable'}, status),
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      expect(
        (await _outcome(api.readAsset(9))).error,
        isA<ClipbackApiException>().having(
          (error) => error.statusCode,
          'status',
          status,
        ),
      );
      expect(server.requests, hasLength(1));
      expect(api.session, same(_old));
    });
  }

  for (final failure in ['401', '503', 'network', 'JSON']) {
    test(
      'asset refresh $failure fails without replay and later refresh can succeed',
      () async {
        var shouldFail = true;
        final server = _Server(
          respond: (request) async {
            if (_expired(request)) return _unauthorized();
            if (request.url.path == _refresh && shouldFail) {
              return switch (failure) {
                'network' => throw http.ClientException('Offline'),
                'JSON' => http.Response('{broken', 200),
                _ => _json({'detail': 'Refresh failed'}, int.parse(failure)),
              };
            }
            return null;
          },
        );
        addTearDown(server.client.close);
        final api = ClipbackApi(client: server.client)..restoreSession(_old);
        expect((await _outcome(api.readAsset(9))).error, isNotNull);
        expect(server.calls(_asset), hasLength(1));
        expect(server.calls(_refresh), hasLength(1));
        expect(api.session, same(_old));
        shouldFail = false;
        expect(await api.readAsset(9), orderedEquals(_image));
        expect(server.calls(_asset), hasLength(3));
        expect(server.calls(_refresh), hasLength(2));
        expect(api.session?.refreshToken, _rotated.refreshToken);
      },
    );
  }

  for (final phase in ['send', 'body']) {
    test(
      'asset $phase connection failure is translated without retry',
      () async {
        var calls = 0;
        final client = MockClient.streaming((request, stream) async {
          await stream.drain<void>();
          calls++;
          if (phase == 'send') throw http.ClientException('Offline');
          return http.StreamedResponse(
            Stream.error(http.ClientException('Disconnected')),
            200,
          );
        });
        addTearDown(client.close);
        final api = ClipbackApi(client: client)..restoreSession(_old);
        expect(
          (await _outcome(api.readAsset(9))).error,
          isA<ClipbackApiException>().having(
            (error) => error.message,
            'message',
            '서버에 연결하지 못했어요.',
          ),
        );
        expect(calls, 1);
        expect(api.session, same(_old));
      },
    );
  }

  for (final transition in ['restore', 'clear']) {
    for (final response in ['200', '401', 'network']) {
      test(
        'asset late $response after $transition cannot affect the next session',
        () async {
          final pending = Completer<http.Response?>();
          final started = Completer<void>();
          final server = _Server(
            respond: (request) async {
              if (request.url.path == _asset) {
                started.complete();
                return pending.future;
              }
              return null;
            },
          );
          addTearDown(server.client.close);
          final api = ClipbackApi(client: server.client)..restoreSession(_old);
          final image = _outcome(api.readAsset(9));
          await started.future;
          if (transition == 'restore') {
            api.restoreSession(_replacement);
          } else {
            api.clearSession();
          }
          if (response == 'network') {
            pending.completeError(http.ClientException('Old request failed'));
          } else {
            pending.complete(response == '401' ? _unauthorized() : _bytes());
          }
          _expectCancelled((await image).error);
          expect(server.requests, hasLength(1));
          expect(
            api.session,
            transition == 'restore' ? same(_replacement) : isNull,
          );
        },
      );
    }
  }

  test('logout waits for asset refresh storage and prevents replay', () async {
    final saving = Completer<void>();
    final saved = Completer<void>();
    final server = _Server(
      respond: (request) async => _expired(request) ? _unauthorized() : null,
    );
    addTearDown(server.client.close);
    final api = ClipbackApi(
      client: server.client,
      onSessionChanged: (_) async {
        saving.complete();
        await saved.future;
      },
    )..restoreSession(_old);
    final image = _outcome(api.readAsset(9));
    await saving.future;
    final logout = _outcome(api.logout());
    await _turn();
    expect(server.calls(_logout), isEmpty);
    _expectCancelled((await _outcome(api.readAsset(9))).error);
    expect(server.calls(_asset), hasLength(1));
    saved.complete();
    expect((await logout).error, isNull);
    _expectCancelled((await image).error);
    expect(server.calls(_asset), hasLength(1));
    expect(jsonDecode(server.calls(_logout).single.body), {
      'refresh_token': _rotated.refreshToken,
    });
    expect(api.hasSession, isFalse);
  });

  test('late asset success during logout is discarded', () async {
    final pendingAsset = Completer<http.Response?>();
    final pendingLogout = Completer<http.Response?>();
    final assetStarted = Completer<void>();
    final logoutStarted = Completer<void>();
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _asset) {
          assetStarted.complete();
          return pendingAsset.future;
        }
        if (request.url.path == _logout) {
          logoutStarted.complete();
          return pendingLogout.future;
        }
        return null;
      },
    );
    addTearDown(server.client.close);
    final api = ClipbackApi(client: server.client)..restoreSession(_old);
    final image = _outcome(api.readAsset(9));
    await assetStarted.future;
    final logout = _outcome(api.logout());
    await logoutStarted.future;
    pendingAsset.complete(_bytes());
    _expectCancelled((await image).error);
    expect(server.calls(_refresh), isEmpty);
    pendingLogout.complete(http.Response('', 204));
    expect((await logout).error, isNull);
    expect(api.hasSession, isFalse);
  });

  testWidgets('asset send and body each receive their own ten second budget', (
    tester,
  ) async {
    final sent = Completer<http.StreamedResponse>();
    final body = StreamController<List<int>>();
    final client = MockClient.streaming((request, stream) async {
      await stream.drain<void>();
      return sent.future;
    });
    addTearDown(client.close);
    final api = ClipbackApi(client: client)..restoreSession(_old);
    var settled = false;
    final image = _outcome(api.readAsset(9)).then((result) {
      settled = true;
      return result;
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    sent.complete(http.StreamedResponse(body.stream, 200));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    expect(settled, isFalse);
    body.add(_image);
    await body.close();
    await tester.pump();
    expect((await image).value, orderedEquals(_image));
  });

  testWidgets('asset download timeout does not change JSON request policy', (
    tester,
  ) async {
    final pending = Completer<http.Response?>();
    final server = _Server(respond: (_) async => pending.future);
    addTearDown(server.client.close);
    final api = ClipbackApi(client: server.client)..restoreSession(_old);
    var settled = false;
    final categories = _outcome(api.listCategories()).then((result) {
      settled = true;
      return result;
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    expect(settled, isFalse);
    pending.complete(_json(<Object>[]));
    await tester.pump();
    expect((await categories).error, isNull);
  });

  testWidgets('asset refresh times out without adopting its late tokens', (
    tester,
  ) async {
    final pending = Completer<http.Response?>();
    var callbacks = 0;
    final server = _Server(
      respond: (request) async {
        if (request.url.path == _refresh) return pending.future;
        if (_expired(request)) return _unauthorized();
        return null;
      },
    );
    addTearDown(server.client.close);
    final api = ClipbackApi(
      client: server.client,
      onSessionChanged: (_) async {
        callbacks++;
      },
    )..restoreSession(_old);
    final image = _outcome(api.readAsset(9));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(
      (await image).error,
      isA<ClipbackApiException>().having(
        (error) => error.message,
        'message',
        contains('지연'),
      ),
    );
    expect(server.calls(_asset), hasLength(1));
    expect(server.calls(_refresh), hasLength(1));
    expect(api.session, same(_old));
    pending.complete(_json(_tokens(_rotated)));
    await tester.pump();
    expect(callbacks, 0);
    expect(api.session, same(_old));
    expect(server.calls(_asset), hasLength(1));
  });

  test(
    'session replacement during asset refresh rejects its tokens and replay',
    () async {
      final pending = Completer<http.Response?>();
      final started = Completer<void>();
      var callbacks = 0;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _refresh) {
            started.complete();
            return pending.future;
          }
          if (_expired(request)) return _unauthorized();
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async {
          callbacks++;
        },
      )..restoreSession(_old);
      final image = _outcome(api.readAsset(9));
      await started.future;
      api.restoreSession(_replacement);
      pending.complete(_json(_tokens(_rotated)));
      _expectCancelled((await image).error);
      expect(api.session, same(_replacement));
      expect(callbacks, 0);
      expect(server.calls(_asset), hasLength(1));
      expect(server.calls(_refresh), hasLength(1));
    },
  );

  for (final phase in ['send', 'body']) {
    testWidgets('asset $phase times out after ten seconds without retry', (
      tester,
    ) async {
      final pendingSend = Completer<http.StreamedResponse>();
      final pendingBody = StreamController<List<int>>();
      final requests = <http.BaseRequest>[];
      final client = MockClient.streaming((request, stream) async {
        await stream.drain<void>();
        requests.add(request);
        if (phase == 'send') return pendingSend.future;
        return http.StreamedResponse(pendingBody.stream, 200);
      });
      addTearDown(client.close);
      final api = ClipbackApi(client: client)..restoreSession(_old);
      var settled = false;
      final result = _outcome(api.readAsset(9)).then((result) {
        settled = true;
        return result;
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect(settled, isFalse);
      await tester.pump(const Duration(seconds: 1));
      final timedOutBeforeLateResponse = settled;
      if (phase == 'send') {
        pendingSend.complete(http.StreamedResponse(Stream.value(_image), 200));
      } else {
        pendingBody.add(_image);
        await pendingBody.close();
      }
      await tester.pump();
      expect(timedOutBeforeLateResponse, isTrue);
      expect(
        (await result).error,
        isA<ClipbackApiException>().having(
          (error) => error.message,
          'message',
          '서버 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.',
        ),
      );
      expect(requests, hasLength(1));
      expect(requests.single.url.path, _asset);
      expect(api.session, same(_old));
    });
  }
}
