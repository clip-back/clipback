import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const session = ApiSession(
  accessToken: 'only-for-clipback',
  refreshToken: 'refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
final original = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
Map<String, Object?> access({String mode = 'direct', String? url}) => {
  'asset_id': 9,
  'mode': mode,
  'url':
      url ??
      (mode == 'direct'
          ? 'https://images.example.com/original?signature=private'
          : '/api/v1/uploads/assets/9'),
  'expires_at': mode == 'direct'
      ? DateTime.now()
            .add(const Duration(seconds: 120))
            .toUtc()
            .toIso8601String()
      : null,
  'mime_type': 'image/png',
  'size_bytes': 70,
  'sha256': 'c414cd0e204de974f73753c7e28d7638e7b3691bb8b1a2bab6b25bb7fed7ce77',
};
http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);
http.Response bytes() =>
    http.Response.bytes(original, 200, headers: {'content-type': 'image/png'});

void main() {
  testWidgets(
    'Bucket body deadline cancels stalled stream without clearing login',
    (tester) async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final app = MockClient((_) async => json(access()));
      final bucket = MockClient.streaming((request, stream) async {
        await stream.drain<void>();
        return http.StreamedResponse(
          body.stream,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      addTearDown(app.close);
      addTearDown(bucket.close);
      final api = ClipbackApi(client: app, bucketClient: bucket)
        ..restoreSession(session);
      final rejected = expectLater(
        api.readAsset(9),
        throwsA(
          isA<ClipbackApiException>().having(
            (error) => error.message,
            'message',
            contains('지연'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await rejected;
      expect(cancelled, isTrue);
      expect(api.session, same(session));
      unawaited(body.close());
    },
  );

  test(
    'expired Bucket signature gets one fresh access without refreshing login',
    () async {
      var accesses = 0, downloads = 0, invalidations = 0;
      final app = MockClient((request) async {
        expect(request.url.path, '/api/v1/uploads/assets/9/access');
        accesses++;
        return json(
          access(
            url: 'https://images.example.com/original?signature=$accesses',
          ),
        );
      });
      final bucket = MockClient((request) async {
        downloads++;
        expect(request.url.queryParameters['signature'], '$downloads');
        return downloads == 1 ? http.Response('RequestExpired', 403) : bytes();
      });
      addTearDown(app.close);
      addTearDown(bucket.close);
      final api = ClipbackApi(
        client: app,
        bucketClient: bucket,
        onSessionInvalidated: () async {
          invalidations++;
        },
      )..restoreSession(session);
      expect(await api.readAsset(9), orderedEquals(original));
      expect(accesses, 2);
      expect(downloads, 2);
      expect(invalidations, 0);
      expect(api.session, same(session));
    },
  );

  for (final status in [401, 403, 404, 503, 302]) {
    test(
      'Bucket $status never invalidates login or exposes signed URL in error',
      () async {
        var accesses = 0, downloads = 0, invalidations = 0;
        final app = MockClient((_) async {
          accesses++;
          return json(access());
        });
        final bucket = MockClient((request) async {
          downloads++;
          return http.Response(
            'Secret error: ${request.url}',
            status,
            headers: {'location': 'https://other.example.com'},
          );
        });
        addTearDown(app.close);
        addTearDown(bucket.close);
        final api = ClipbackApi(
          client: app,
          bucketClient: bucket,
          onSessionInvalidated: () async {
            invalidations++;
          },
        )..restoreSession(session);
        await expectLater(
          api.readAsset(9),
          throwsA(
            isA<ClipbackApiException>()
                .having((error) => error.statusCode, 'status', status)
                .having(
                  (error) => error.toString(),
                  'safe message',
                  isNot(contains('signature')),
                ),
          ),
        );
        expect(accesses, status == 403 ? 2 : 1);
        expect(downloads, status == 403 ? 2 : 1);
        expect(invalidations, 0);
        expect(api.session, same(session));
      },
    );
  }

  for (final failure in ['hash', 'short body', 'oversize', 'mime']) {
    test('rejects $failure before displaying original bytes', () async {
      final app = MockClient((_) async => json(access()));
      final bucket = MockClient(
        (_) async => http.Response.bytes(
          switch (failure) {
            'hash' => [...original.take(69), 1],
            'short body' => original.take(69).toList(),
            'oversize' => [...original, 1],
            _ => original,
          },
          200,
          headers: {
            'content-type': failure == 'mime' ? 'text/html' : 'image/png',
          },
        ),
      );
      addTearDown(app.close);
      addTearDown(bucket.close);
      final api = ClipbackApi(client: app, bucketClient: bucket)
        ..restoreSession(session);
      await expectLater(api.readAsset(9), throwsA(isA<ClipbackApiException>()));
      expect(api.session, same(session));
    });
  }

  for (final field in [
    'http url',
    'proxy origin',
    'size',
    'digest',
    'asset',
    'expiry',
    'json',
  ]) {
    test('invalid $field access never downloads from Bucket', () async {
      var downloads = 0;
      final data = access();
      switch (field) {
        case 'http url':
          data['url'] = 'http://images.example.com/private';
        case 'proxy origin':
          data['mode'] = 'proxy';
          data['url'] = 'https://other.example.com/private';
        case 'size':
          data['size_bytes'] = 10 * 1024 * 1024 + 1;
        case 'digest':
          data['sha256'] = 'unknown';
        case 'asset':
          data['asset_id'] = 10;
        case 'expiry':
          data['expires_at'] = null;
      }
      final app = MockClient(
        (_) async => field == 'json' ? http.Response('[]', 200) : json(data),
      );
      final bucket = MockClient((_) async {
        downloads++;
        return bytes();
      });
      addTearDown(app.close);
      addTearDown(bucket.close);
      final api = ClipbackApi(client: app, bucketClient: bucket)
        ..restoreSession(session);
      await expectLater(api.readAsset(9), throwsA(isA<ClipbackApiException>()));
      expect(downloads, 0);
    });
  }

  test('late Bucket response is cancelled after account replacement', () async {
    final pending = Completer<http.StreamedResponse>();
    final started = Completer<void>();
    var cancelled = false;
    final body = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final app = MockClient((_) async => json(access()));
    final bucket = MockClient.streaming((request, stream) async {
      await stream.drain<void>();
      started.complete();
      return pending.future;
    });
    addTearDown(app.close);
    addTearDown(bucket.close);
    final api = ClipbackApi(client: app, bucketClient: bucket)
      ..restoreSession(session);
    final rejected = expectLater(
      api.readAsset(9),
      throwsA(
        isA<ClipbackApiException>().having(
          (error) => error.message,
          'message',
          contains('로그인 상태가 변경'),
        ),
      ),
    );
    await started.future;
    api.restoreSession(session);
    pending.complete(
      http.StreamedResponse(
        body.stream,
        200,
        headers: {'content-type': 'image/png'},
      ),
    );
    await rejected;
    expect(cancelled, isTrue);
    await body.close();
  });

  test(
    'unknown-length oversized stream is cancelled before collecting its remainder',
    () async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final app = MockClient((_) async => json(access()));
      final bucket = MockClient.streaming((request, stream) async {
        await stream.drain<void>();
        return http.StreamedResponse(
          body.stream,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      addTearDown(app.close);
      addTearDown(bucket.close);
      final api = ClipbackApi(client: app, bucketClient: bucket)
        ..restoreSession(session);
      final rejected = expectLater(
        api.readAsset(9),
        throwsA(isA<ClipbackApiException>()),
      );
      body.add(List.filled(71, 0));
      await rejected;
      expect(cancelled, isTrue);
      await body.close();
    },
  );

  test(
    'access issued before account replacement cannot download an old original',
    () async {
      var bucketCalls = 0;
      final app = MockClient((_) async => json(access()));
      final bucket = MockClient((_) async {
        bucketCalls++;
        return bytes();
      });
      addTearDown(app.close);
      addTearDown(bucket.close);
      final api = ClipbackApi(client: app, bucketClient: bucket)
        ..restoreSession(session);
      final oldAccess = await api.readAssetAccess(9);
      api.clearSession();
      api.restoreSession(session);
      await expectLater(
        api.downloadAsset(oldAccess),
        throwsA(isA<ClipbackApiException>()),
      );
      expect(bucketCalls, 0);
    },
  );

  test(
    'owner downloads verified original directly without sending app credentials',
    () async {
      final app = MockClient((request) async {
        expect(request.url.path, '/api/v1/uploads/assets/9/access');
        expect(request.headers['authorization'], 'Bearer only-for-clipback');
        return json(access());
      });
      final bucket = MockClient((request) async {
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(request.headers.containsKey('cookie'), isFalse);
        expect(request.followRedirects, isFalse);
        return bytes();
      });
      addTearDown(app.close);
      addTearDown(bucket.close);
      final api = ClipbackApi(client: app, bucketClient: bucket)
        ..restoreSession(session);
      expect(await api.readAsset(9), orderedEquals(original));
    },
  );
}
