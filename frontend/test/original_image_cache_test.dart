import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/original_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _session = ApiSession(
  accessToken: 'cache-test-access',
  refreshToken: 'cache-test-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
final _image = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
const _digest =
    'c414cd0e204de974f73753c7e28d7638e7b3691bb8b1a2bab6b25bb7fed7ce77';

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

class _Server {
  int userId = 7;
  int accessStatus = 200;
  bool direct = false;
  Completer<void>? bodyWait;
  void Function()? onBody;
  final requests = <String>[];
  final methods = <String>[];
  late final client = MockClient((request) async {
    requests.add(request.url.path);
    methods.add(request.method);
    final descriptor = RegExp(
      r'/assets/(\d+)/access$',
    ).firstMatch(request.url.path);
    if (descriptor != null) {
      final id = int.parse(descriptor.group(1)!);
      return accessStatus == 200
          ? _json({
              'asset_id': id,
              'mode': direct ? 'direct' : 'proxy',
              'url': direct
                  ? 'https://bucket.example.test/original.png?signature=unpersisted'
                  : '/api/v1/uploads/assets/$id',
              'expires_at': direct ? '2099-01-01T00:00:00Z' : null,
              'mime_type': 'image/png',
              'size_bytes': 70,
              'sha256': _digest,
            })
          : _json({'detail': 'unavailable'}, accessStatus);
    }
    if (RegExp(r'/assets/\d+$').hasMatch(request.url.path)) {
      await bodyWait?.future;
      onBody?.call();
      return http.Response.bytes(
        _image,
        200,
        headers: {'content-type': 'image/png'},
      );
    }
    return switch (request.url.path) {
      '/api/v1/users/me' => _json({
        'id': userId,
        'is_guest': true,
        'email': null,
        'display_name': 'Cache Guest',
        'created_at': '2026-10-23T00:00:00Z',
        'linked_providers': <String>[],
      }),
      '/api/v1/auth/refresh' => _json({'detail': 'invalid refresh'}, 401),
      _ => throw StateError('Unexpected request: ${request.url.path}'),
    };
  });
}

Future<void> _waitForEmpty(Directory directory) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (await directory.list().isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(await directory.list().toList(), isEmpty);
}

void main() {
  test(
    'direct original cache reauthorizes without another Bucket body or persisted credentials',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipback-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = _Server()..direct = true;
      addTearDown(server.client.close);
      final requests = <http.Request>[];
      final bucket = MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
          _image,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      addTearDown(bucket.close);
      final api = ClipbackApi(
        client: server.client,
        bucketClient: bucket,
        originalImageCache: OriginalImageCache(
          directory: () async => directory,
        ),
      )..restoreSession(_session);
      expect(await api.readAsset(9), orderedEquals(_image));
      expect(await api.readAsset(9), orderedEquals(_image));
      expect(server.requests.where((p) => p.endsWith('/access')), hasLength(2));
      expect(requests, hasLength(1));
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      expect(requests.single.headers.containsKey('Cookie'), isFalse);
      final file = (await directory.list().toList()).whereType<File>().single;
      expect(await file.readAsBytes(), orderedEquals(_image));
      expect(file.path, isNot(contains('unpersisted')));
      expect(file.path, isNot(contains(_session.accessToken)));
    },
  );

  test(
    'reopening an original authorizes online but reuses its body on disk',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipback-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = _Server();
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        originalImageCache: OriginalImageCache(
          directory: () async => directory,
        ),
      )..restoreSession(_session);

      expect(await api.readAsset(9), orderedEquals(_image));
      expect(await api.readAsset(9), orderedEquals(_image));
      expect(server.requests.where((p) => p.endsWith('/access')), hasLength(2));
      expect(
        server.requests.where((p) => p.endsWith('/assets/9')),
        hasLength(1),
      );
    },
  );

  test(
    'cached originals are never opened after deletion or while offline',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipback-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = _Server();
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        originalImageCache: OriginalImageCache(
          directory: () async => directory,
        ),
      )..restoreSession(_session);
      await api.readAsset(9);
      server.accessStatus = 404;
      await expectLater(api.readAsset(9), throwsA(isA<ClipbackApiException>()));
      server.accessStatus = 503;
      await expectLater(api.readAsset(9), throwsA(isA<ClipbackApiException>()));
      expect(server.requests.where((p) => p.endsWith('/access')), hasLength(3));
      expect(
        server.requests.where((p) => p.endsWith('/assets/9')),
        hasLength(1),
      );
    },
  );

  test(
    'the same account reuses bytes after app restart; another account does not',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipback-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = _Server();
      addTearDown(server.client.close);
      ClipbackApi openApp() => ClipbackApi(
        client: server.client,
        originalImageCache: OriginalImageCache(
          directory: () async => directory,
        ),
      )..restoreSession(_session);
      await openApp().readAsset(9);
      await openApp().readAsset(9);
      expect(
        server.requests.where((p) => p.endsWith('/assets/9')),
        hasLength(1),
      );
      server.userId = 8;
      await openApp().readAsset(9);
      expect(
        server.requests.where((p) => p.endsWith('/assets/9')),
        hasLength(2),
      );
      expect(server.requests.where((p) => p.endsWith('/access')), hasLength(3));
    },
  );

  test('partial and corrupt cached originals are downloaded again', () async {
    final directory = await Directory.systemTemp.createTemp('clipback-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final server = _Server();
    addTearDown(server.client.close);
    final api = ClipbackApi(
      client: server.client,
      originalImageCache: OriginalImageCache(directory: () async => directory),
    )..restoreSession(_session);
    await api.readAsset(9);
    final file = (await directory.list().toList()).whereType<File>().single;
    await file.writeAsBytes([0]);
    expect(await api.readAsset(9), orderedEquals(_image));
    await file.writeAsBytes(List<int>.filled(_image.length, 0));
    expect(await api.readAsset(9), orderedEquals(_image));
    expect(server.requests.where((p) => p.endsWith('/assets/9')), hasLength(3));
  });

  test(
    'a late original download cannot recreate disk bytes after session clear',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipback-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = _Server();
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        originalImageCache: OriginalImageCache(
          directory: () async => directory,
        ),
      )..restoreSession(_session);
      await api.readAsset(9);
      server.bodyWait = Completer<void>();
      // Force a miss while the same original is in flight.
      await for (final file in directory.list()) {
        await file.delete();
      }
      final pending = expectLater(
        api.readAsset(9),
        throwsA(isA<ClipbackApiException>()),
      );
      while (server.requests.where((p) => p.endsWith('/assets/9')).length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      api.clearSession();
      server.bodyWait!.complete();
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test('session clear removes already cached originals', () async {
    final directory = await Directory.systemTemp.createTemp('clipback-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final server = _Server();
    addTearDown(server.client.close);
    final api = ClipbackApi(
      client: server.client,
      originalImageCache: OriginalImageCache(directory: () async => directory),
    )..restoreSession(_session);
    await api.readAsset(9);
    api.clearSession();
    await _waitForEmpty(directory);
  });

  test(
    'seven unused days evict originals but a recent open extends their life',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipback-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = _Server();
      addTearDown(server.client.close);
      var now = DateTime.utc(2026, 10, 1);
      final api = ClipbackApi(
        client: server.client,
        originalImageCache: OriginalImageCache(
          directory: () async => directory,
          now: () => now,
        ),
      )..restoreSession(_session);
      await api.readAsset(9);
      now = now.add(const Duration(days: 6));
      await api.readAsset(9);
      now = now.add(const Duration(days: 6));
      await api.readAsset(9);
      expect(
        server.requests.where((p) => p.endsWith('/assets/9')),
        hasLength(1),
      );
      now = now.add(const Duration(days: 7));
      await api.readAsset(9);
      expect(
        server.requests.where((p) => p.endsWith('/assets/9')),
        hasLength(2),
      );
    },
  );

  test(
    'the byte budget evicts the least recently opened original without cloud mutation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipback-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = _Server();
      addTearDown(server.client.close);
      var now = DateTime.utc(2026, 10, 1);
      final api = ClipbackApi(
        client: server.client,
        originalImageCache: OriginalImageCache(
          directory: () async => directory,
          now: () => now,
          maxBytes: 140,
        ),
      )..restoreSession(_session);
      await api.readAsset(9);
      now = now.add(const Duration(seconds: 1));
      await api.readAsset(10);
      now = now.add(const Duration(seconds: 1));
      await api.readAsset(9);
      now = now.add(const Duration(seconds: 1));
      await api.readAsset(11);
      await api.readAsset(9);
      expect(
        server.requests.where((p) => p.endsWith('/assets/9')),
        hasLength(1),
      );
      await api.readAsset(10);
      expect(
        server.requests.where((p) => p.endsWith('/assets/10')),
        hasLength(2),
      );
      expect(server.methods.toSet(), {'GET'});
      final total = await directory
          .list()
          .where((e) => e is File)
          .asyncMap((e) => File(e.path).length())
          .fold<int>(0, (a, b) => a + b);
      expect(total, lessThanOrEqualTo(140));
      expect(
        server.requests.every(
          (p) => p.contains('/assets/') || p.endsWith('/users/me'),
        ),
        isTrue,
      );
    },
  );

  test(
    'account switch during cache I/O discards old bytes before the new account opens',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipback-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = _Server();
      addTearDown(server.client.close);
      final writing = Completer<void>();
      final release = Completer<void>();
      var bodyReceived = false;
      server.onBody = () => bodyReceived = true;
      final api = ClipbackApi(
        client: server.client,
        originalImageCache: OriginalImageCache(
          directory: () async {
            if (bodyReceived && !release.isCompleted) {
              if (!writing.isCompleted) writing.complete();
              await release.future;
            }
            return directory;
          },
        ),
      )..restoreSession(_session);
      final pending = expectLater(
        api.readAsset(9),
        throwsA(isA<ClipbackApiException>()),
      );
      await writing.future;
      server.userId = 8;
      api.restoreSession(
        const ApiSession(
          accessToken: 'second-account-access',
          refreshToken: 'second-account-refresh',
          expiresIn: 3600,
          refreshExpiresIn: 86400,
        ),
      );
      release.complete();
      await pending;
      expect(await api.readAsset(10), orderedEquals(_image));
      expect((await directory.list().toList()).whereType<File>(), hasLength(1));
      expect(
        server.requests.where((p) => p.endsWith('/users/me')),
        hasLength(2),
      );
    },
  );

  test(
    'invalid session purges cached bytes even when session persistence fails',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipback-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = _Server();
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        originalImageCache: OriginalImageCache(
          directory: () async => directory,
        ),
        onSessionInvalidated: () async =>
            throw StateError('Synthetic persistence failure'),
      )..restoreSession(_session);
      await api.readAsset(9);
      server.accessStatus = 401;
      await expectLater(api.readAsset(9), throwsStateError);
      await _waitForEmpty(directory);
      expect(
        server.requests.where((p) => p.endsWith('/assets/9')),
        hasLength(1),
      );
    },
  );

  test(
    'unavailable device cache preserves verified online original viewing',
    () async {
      final server = _Server();
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        originalImageCache: OriginalImageCache(
          directory: () async {
            throw const FileSystemException('Synthetic cache unavailable');
          },
        ),
      )..restoreSession(_session);
      expect(await api.readAsset(9), orderedEquals(_image));
      expect(await api.readAsset(9), orderedEquals(_image));
      expect(server.requests.where((p) => p.endsWith('/access')), hasLength(2));
      expect(
        server.requests.where((p) => p.endsWith('/assets/9')),
        hasLength(2),
      );
    },
  );
}
