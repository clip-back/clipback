import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/actions/account_initialization_action.dart';
import 'package:clipback_frontend/app/app_view_model.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _stored = ApiSession(
  accessToken: 'failure-fixture-access',
  refreshToken: 'failure-fixture-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// Keep this semantic regression source compilable on the frozen BEFORE commit.
// Missing new state is the intended red result, rather than a compile failure.
dynamic _failure(AppViewModel model) {
  try {
    return (model as dynamic).ordinaryLoginFailure;
  } on NoSuchMethodError {
    return null;
  }
}

bool _dismiss(AppViewModel model, dynamic expected) =>
    (model as dynamic).dismissOrdinaryLoginFailure(expected) as bool;

class _Storage extends ApiSessionStorage {
  ApiSession? value;
  bool failWrite = false, failClear = false;
  int writes = 0, clears = 0;
  @override
  Future<ApiSession?> read() async => value;
  @override
  Future<void> write(ApiSession next) async {
    writes++;
    if (failWrite) throw StateError('fixture device storage unavailable');
    value = next;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (failClear) throw StateError('fixture clear unavailable');
    value = null;
  }
}

class _Social extends SocialAuth {
  int calls = 0, metadataCalls = 0;
  Object? error;
  bool cancel = false, failMetadata = false;
  Completer<SocialCredential?>? gate;
  @override
  List<SocialLoginProvider> get supportedProviders => const [
    SocialLoginProvider.google,
    SocialLoginProvider.kakao,
    SocialLoginProvider.apple,
  ];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async {
    calls++;
    if (gate case final pending?) return pending.future;
    if (error case final failure?) throw failure;
    return cancel
        ? null
        : const SocialCredential(
            token: 'fixture-social-credential',
            authorizationCode: 'fixture-one-use-code',
            providerUserId: 'fixture-social-user',
          );
  }

  @override
  Future<void> rememberAppleUserId(String? userId) async {
    metadataCalls++;
    if (failMetadata) throw StateError('fixture metadata unavailable');
  }

  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.authorized;
}

class _Fixture {
  _Fixture({bool stored = false}) {
    if (stored) storage.value = _stored;
    client = MockClient((request) async {
      final path = request.url.path;
      paths.add(path);
      if (path == '/api/v1/auth/social/apple/challenge') {
        return _json({
          'challenge_id': 'fixture-challenge',
          'nonce': 'fixture-unique-nonce',
          'expires_at': '2030-10-19T00:00:00Z',
        }, 201);
      }
      if (path.startsWith('/api/v1/auth/social/')) {
        if (authGate case final pending?) return pending.future;
        if (authError case final failure?) throw failure;
        if (authResponse case final response?) return response;
        guest = false;
        return _json({
          'access_token': 'issued-fixture-access',
          'refresh_token': 'issued-fixture-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
          'is_new_user': false,
        });
      }
      if (path == '/api/v1/auth/guest') {
        guest = true;
        return _json({
          'access_token': 'guest-fixture-access',
          'refresh_token': 'guest-fixture-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        }, 201);
      }
      if (path == '/api/v1/categories') {
        if (failBootstrap) {
          return _json({'detail': 'bootstrap unavailable'}, 503);
        }
        return _json(<Object>[]);
      }
      if (path == '/api/v1/feed') {
        return _json({'items': <Object>[], 'next_cursor': null});
      }
      if (path == '/api/v1/users/me') {
        return _json({
          'id': 41,
          'email': null,
          'display_name': '로그인 실패 검증',
          'is_guest': guest,
          'created_at': '2026-10-19T00:00:00Z',
          'linked_providers': guest ? <String>[] : ['google'],
        });
      }
      if (path == '/api/v1/users/me/stats') {
        return _json({'saved_count': 0, 'reopened_count': 0});
      }
      throw StateError('Unexpected fixture request: $path');
    });
    api = ClipbackApi(
      client: client,
      onSessionChanged: (_) => session.persistCurrentSession(),
      onSessionInvalidated: () => session.invalidate(),
    );
    session = RemoteSessionRepository(
      api: api,
      storage: storage,
      socialAuth: social,
    );
    users = RemoteUserRepository(api: api);
    content = RemoteContentRepository(api);
    initialize = AccountInitializationAction(content, users);
    model = AppViewModel(
      session: session,
      users: users,
      initializeAccount: initialize,
      beforeSessionChange: () async {
        if (barrierError case final failure?) throw failure;
      },
    );
  }

  final storage = _Storage();
  final social = _Social();
  final paths = <String>[];
  bool guest = false, failBootstrap = false, modelDisposed = false;
  Object? barrierError, authError;
  http.Response? authResponse;
  Completer<http.Response>? authGate;
  late final MockClient client;
  late final ClipbackApi api;
  late final RemoteSessionRepository session;
  late final RemoteContentRepository content;
  late final RemoteUserRepository users;
  late final AccountInitializationAction initialize;
  late final AppViewModel model;

  Future<void> loginChoice() async {
    await model.restoreSession();
    expect(model.route, AppRoute.login);
    model.drainEffects();
  }

  Future<void> failOrdinary([int status = 503]) async {
    authResponse = _json({'detail': 'ordinary auth failure'}, status);
    await model.authenticateSocial(SocialLoginProvider.google);
  }

  void dispose() {
    if (!modelDisposed) model.dispose();
    initialize.dispose();
    content.dispose();
    users.dispose();
    session.dispose();
    client.close();
  }
}

dynamic _status(AppViewModel model) {
  try {
    return (model as dynamic).ordinaryLoginStatus;
  } on NoSuchMethodError {
    return null;
  }
}

bool _dismissStatus(AppViewModel model, dynamic expected) {
  try {
    return (model as dynamic).dismissOrdinaryLoginStatus(expected) as bool;
  } on NoSuchMethodError {
    return false;
  }
}

Future<void> _flushStatus() => Future<void>.delayed(Duration.zero);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final provider in SocialLoginProvider.values) {
    test(
      'ordinary $provider pending and actual SDK cancel own one status',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        await f.loginChoice();
        final gate = Completer<SocialCredential?>();
        f.social.gate = gate;
        final pending = f.model.authenticateSocial(provider);
        addTearDown(() async {
          if (!gate.isCompleted) gate.complete(null);
          await pending;
        });
        await _flushStatus();
        final progress = _status(f.model);
        expect(progress, isNotNull);
        expect((progress.phase as Enum).name, 'authenticating');
        expect(progress.provider, provider);
        expect(progress.authEpoch, f.model.authEpoch);
        expect(f.model.authBusy, isTrue);
        expect(_dismissStatus(f.model, progress), isFalse);
        gate.complete(null);
        await pending;
        final cancelled = _status(f.model);
        expect(cancelled, isNotNull);
        expect((cancelled.phase as Enum).name, 'cancelled');
        expect(cancelled.provider, provider);
        expect(f.model.authBusy, isFalse);
        expect(_failure(f.model), isNull);
        expect(f.session.hasSession, isFalse);
        expect(f.storage.writes, 0);
        expect(
          f.paths.where(
            (p) =>
                p.endsWith('/google') ||
                p.endsWith('/kakao') ||
                p == '/api/v1/auth/social/apple',
          ),
          isEmpty,
        );
        expect(_dismissStatus(f.model, progress), isFalse);
        expect(_dismissStatus(f.model, cancelled), isTrue);
        expect(_dismissStatus(f.model, cancelled), isFalse);
        expect(_status(f.model), isNull);
      },
    );
  }
  test('HTTP pending becomes existing A05 rather than cancellation', () async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.loginChoice();
    final gate = Completer<http.Response>();
    f.authGate = gate;
    final pending = f.model.authenticateSocial(SocialLoginProvider.google);
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete(_json({'detail': 'offline'}, 503));
      await pending;
    });
    await _flushStatus();
    expect((_status(f.model)?.phase as Enum?)?.name, 'authenticating');
    gate.complete(_json({'detail': 'offline'}, 503));
    await pending;
    expect(_status(f.model), isNull);
    final failure = _failure(f.model);
    expect(failure.statusCode, 503);
    expect(_dismiss(f.model, failure), isTrue);
    expect(f.storage.writes, 0);
  });
  test('security barrier failure never becomes A03/A04', () async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.loginChoice();
    f.barrierError = StateError('fixture barrier unavailable');
    await f.model.authenticateSocial(SocialLoginProvider.google);
    expect(_status(f.model), isNull);
    expect(_failure(f.model), isNull);
    expect(f.social.calls, 0);
  });
  test(
    'new authentication clears stale cancellation without stale dismissal',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      f.social.cancel = true;
      await f.model.authenticateSocial(SocialLoginProvider.google);
      final stale = _status(f.model);
      expect(stale, isNotNull);
      f.social.cancel = false;
      await f.failOrdinary();
      expect(_status(f.model), isNull);
      final failure = _failure(f.model);
      expect(failure, isNotNull);
      expect(_dismissStatus(f.model, stale), isFalse);
      expect(identical(_failure(f.model), failure), isTrue);
    },
  );
  test(
    'successful issuance and bootstrap failure never present cancellation',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      f.failBootstrap = true;
      await f.model.authenticateSocial(SocialLoginProvider.google);
      expect(f.session.hasSession, isTrue);
      expect(_status(f.model), isNull);
      expect(_failure(f.model), isNull);
    },
  );
  test('route exit invalidates presentation and late SDK null', () async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.loginChoice();
    final gate = Completer<SocialCredential?>();
    f.social.gate = gate;
    final pending = f.model.authenticateSocial(SocialLoginProvider.google);
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete(null);
      await pending;
    });
    await _flushStatus();
    expect(_status(f.model), isNotNull);
    f.model.go(AppRoute.home);
    expect(_status(f.model), isNull);
    gate.complete(null);
    await pending;
    expect(_status(f.model), isNull);
  });
}
