import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _first = ApiSession(
  accessToken: 'first',
  refreshToken: 'first-refresh',
  expiresIn: 60,
  refreshExpiresIn: 600,
);
const _second = ApiSession(
  accessToken: 'second',
  refreshToken: 'second-refresh',
  expiresIn: 60,
  refreshExpiresIn: 600,
);

class _Storage extends ApiSessionStorage {
  ApiSession? stored;
  final writes = <ApiSession>[];
  Future<void> Function()? beforeWrite;
  bool failWrite = false;
  bool failClear = false;

  @override
  Future<ApiSession?> read() async => stored;
  @override
  Future<void> write(ApiSession session) async {
    writes.add(session);
    await beforeWrite?.call();
    if (failWrite) throw StateError('write failed');
    stored = session;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('clear failed');
    stored = null;
  }
}

class _Social extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders => [];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => null;
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.unavailable;
}

void main() {
  late _Storage storage;
  late ClipbackApi api;
  late RemoteSessionRepository repository;
  late Future<http.Response> Function(http.Request) respond;

  setUp(() {
    storage = _Storage();
    respond = (request) async => http.Response('', 204);
    api = ClipbackApi(
      client: MockClient((request) => respond(request)),
      onSessionChanged: (_) => repository.persistCurrentSession(),
      onSessionInvalidated: () => repository.invalidate(),
    );
    repository = RemoteSessionRepository(
      api: api,
      storage: storage,
      socialAuth: _Social(),
    );
  });

  tearDown(() => repository.dispose());

  test(
    'queued persistence reads latest session when its turn starts',
    () async {
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      storage.beforeWrite = () async {
        if (storage.writes.length == 1) {
          writeStarted.complete();
          await releaseWrite.future;
        }
      };
      api.restoreSession(_first);
      final firstWrite = repository.persistCurrentSession();
      await writeStarted.future;
      final queuedWrite = repository.persistCurrentSession();
      api.restoreSession(_second);
      releaseWrite.complete();
      await Future.wait([firstWrite, queuedWrite]);
      expect(storage.writes, [_first, _second]);
      expect(storage.stored, same(_second));
      expect(repository.storageBusy, isFalse);
    },
  );

  test(
    'failed token persistence preserves session and can be retried',
    () async {
      api.restoreSession(_first);
      storage.failWrite = true;
      await repository.persistCurrentSession();
      expect(api.session, same(_first));
      expect(repository.needsPersistence, isTrue);
      storage.failWrite = false;
      await repository.persistCurrentSession();
      expect(repository.needsPersistence, isFalse);
      expect(storage.stored, same(_first));
    },
  );

  test(
    'failed invalidation clear blocks access until clear retry succeeds',
    () async {
      api.restoreSession(_first);
      storage.stored = _first;
      storage.failClear = true;
      final events = <SessionInvalidation>[];
      final subscription = repository.invalidations.listen(events.add);
      await repository.invalidate();
      expect(events, [SessionInvalidation.started, SessionInvalidation.failed]);
      expect(repository.pendingSessionClear, isTrue);
      expect(api.session, same(_first));
      storage.failClear = false;
      await repository.retryPendingClear();
      expect(repository.pendingSessionClear, isFalse);
      expect(api.hasSession, isFalse);
      expect(storage.stored, isNull);
      await subscription.cancel();
    },
  );

  test(
    'logout waits for refresh persistence without storage queue deadlock',
    () async {
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      final paths = <String>[];
      respond = (request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/refresh')) {
          refreshStarted.complete();
          await releaseRefresh.future;
          return http.Response(
            jsonEncode({
              'access_token': _second.accessToken,
              'refresh_token': _second.refreshToken,
              'expires_in': _second.expiresIn,
              'refresh_expires_in': _second.refreshExpiresIn,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(jsonDecode(request.body)['refresh_token'], _second.refreshToken);
        return http.Response('', 204);
      };
      storage.beforeWrite = () async {
        writeStarted.complete();
        await releaseWrite.future;
      };
      api.restoreSession(_first);
      final refresh = api.refreshSession();
      await refreshStarted.future;
      final logout = repository.logout(isCurrent: () => true);
      releaseRefresh.complete();
      await writeStarted.future;
      expect(paths, ['/api/v1/auth/refresh']);
      releaseWrite.complete();
      await refresh;
      expect(await logout.timeout(const Duration(seconds: 2)), isTrue);
      expect(paths, ['/api/v1/auth/refresh', '/api/v1/auth/logout']);
      expect(api.hasSession, isFalse);
      expect(storage.stored, isNull);
      expect(repository.storageBusy, isFalse);
    },
  );
}
