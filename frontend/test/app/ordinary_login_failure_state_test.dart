import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/actions/account_initialization_action.dart';
import 'package:clipback_frontend/app/app_view_model.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final status in [400, 401, 403, 409, 422, 429, 500, 502, 503]) {
    test(
      'ordinary HTTP $status owns failure without a duplicate error effect',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        await f.loginChoice();
        final generation = f.model.accountGeneration;
        await f.failOrdinary(status);
        final failure = _failure(f.model);
        expect(failure, isNotNull);
        expect(failure.provider, SocialLoginProvider.google);
        expect(failure.statusCode, status);
        expect(failure.authEpoch, f.model.authEpoch);
        expect(failure.accountGeneration, generation);
        expect(f.model.route, AppRoute.login);
        expect(f.model.authBusy, isFalse);
        expect(f.session.hasSession, isFalse);
        expect(f.model.drainEffects(), isEmpty);
        expect(f.paths, ['/api/v1/auth/social/google']);
        expect(f.storage.writes, 0);
      },
    );
  }

  for (final kind in ['sdk', 'network', 'malformed-success']) {
    test(
      '$kind ordinary failure keeps status absent without guessing a code',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        await f.loginChoice();
        switch (kind) {
          case 'sdk':
            f.social.error = const SocialAuthException(
              'safe SDK fixture error',
            );
          case 'network':
            f.authError = http.ClientException('fixture offline');
          case 'malformed-success':
            f.authResponse = http.Response('{broken', 200);
        }
        await f.model.authenticateSocial(SocialLoginProvider.google);
        final failure = _failure(f.model);
        expect(failure, isNotNull);
        expect(failure.statusCode, isNull);
        expect(f.model.drainEffects(), isEmpty);
        expect(f.storage.writes, 0);
        expect(
          f.paths,
          kind == 'sdk' ? isEmpty : ['/api/v1/auth/social/google'],
        );
      },
    );
  }

  for (final provider in SocialLoginProvider.values) {
    test(
      '${provider.name} SDK cancellation creates no failure or issued session',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        await f.loginChoice();
        f.social.cancel = true;
        await f.model.authenticateSocial(provider);
        expect(_failure(f.model), isNull);
        expect(f.model.drainEffects(), isEmpty);
        expect(f.session.hasSession, isFalse);
        expect(
          f.paths,
          provider == SocialLoginProvider.apple
              ? ['/api/v1/auth/social/apple/challenge']
              : isEmpty,
        );
        expect(f.storage.writes, 0);
      },
    );
  }

  test(
    'failure consumption is once-only and never authenticates or changes the visit epoch',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      await f.failOrdinary();
      final failure = _failure(f.model);
      expect(failure, isNotNull);
      final epoch = f.model.authEpoch, calls = f.social.calls;
      final requests = List<String>.from(f.paths);
      expect(_dismiss(f.model, failure), isTrue);
      expect(_failure(f.model), isNull);
      expect(_dismiss(f.model, failure), isFalse);
      expect(f.model.authEpoch, epoch);
      expect(f.social.calls, calls);
      expect(f.paths, requests);
      expect(f.model.route, AppRoute.login);
    },
  );

  test(
    'new attempt clears failure and duplicate pending choices cannot replace its owner',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      await f.failOrdinary();
      final old = _failure(f.model);
      expect(old, isNotNull);
      f.social.gate = Completer<SocialCredential?>();
      final retry = f.model.authenticateSocial(SocialLoginProvider.kakao);
      await Future<void>.delayed(Duration.zero);
      expect(_failure(f.model), isNull);
      expect(f.model.authBusy, isTrue);
      expect(_dismiss(f.model, old), isFalse);
      await f.model.authenticateSocial(SocialLoginProvider.google);
      expect(f.social.calls, 2);
      f.social.gate!.completeError(const SocialAuthException('retry failed'));
      await retry;
      final next = _failure(f.model);
      expect(next, isNotNull);
      expect(identical(next, old), isFalse);
      expect(next.provider, SocialLoginProvider.kakao);
      expect(_dismiss(f.model, old), isFalse);
      expect(identical(_failure(f.model), next), isTrue);
      expect(_dismiss(f.model, next), isTrue);
    },
  );

  for (final route in [AppRoute.home, AppRoute.account, AppRoute.search]) {
    test(
      'leaving ordinary login for ${route.name} clears failure permanently',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        await f.loginChoice();
        await f.failOrdinary();
        final old = _failure(f.model);
        expect(old, isNotNull);
        f.model.go(route);
        expect(_failure(f.model), isNull);
        f.model.go(AppRoute.login);
        expect(_failure(f.model), isNull);
        expect(_dismiss(f.model, old), isFalse);
      },
    );
  }

  test(
    'pre-auth sharing barrier failure retains legacy message and never enters SDK',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      f.barrierError = StateError('fixture share security failure');
      await f.model.authenticateSocial(SocialLoginProvider.google);
      expect(_failure(f.model), isNull);
      expect(f.social.calls, 0);
      expect(f.paths, isEmpty);
      expect(f.model.drainEffects().whereType<MessageEffect>(), hasLength(1));
    },
  );

  test(
    'session persistence failure preserves issued session and existing warning state',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      f.storage.failWrite = true;
      await f.model.authenticateSocial(SocialLoginProvider.google);
      expect(_failure(f.model), isNull);
      expect(f.session.hasSession, isTrue);
      expect(f.session.needsPersistence, isTrue);
      expect(f.model.route, AppRoute.home);
    },
  );

  test(
    'issued Apple metadata failure keeps its warning and does not become login failure',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      f.social.failMetadata = true;
      await f.model.authenticateSocial(SocialLoginProvider.apple);
      expect(_failure(f.model), isNull);
      expect(f.session.hasSession, isTrue);
      expect(f.model.route, AppRoute.home);
      expect(
        f.model.drainEffects().whereType<MessageEffect>().single.message,
        '기기의 계정 확인 정보를 저장하지 못했어요. 로그인은 완료됐어요.',
      );
    },
  );

  test(
    'issued-session bootstrap failure and retry keep recovery without reauthentication',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      f.failBootstrap = true;
      await f.model.authenticateSocial(SocialLoginProvider.google);
      expect(_failure(f.model), isNull);
      expect(f.session.hasSession, isTrue);
      expect(f.model.apiConnectionError, isNotNull);
      expect(f.social.calls, 1);
      f.failBootstrap = false;
      await f.model.restoreSession();
      expect(_failure(f.model), isNull);
      expect(f.model.route, AppRoute.home);
      expect(f.social.calls, 1);
      expect(
        f.paths.where((p) => p == '/api/v1/auth/social/google'),
        hasLength(1),
      );
    },
  );

  for (final status in [401, 409, 503]) {
    test(
      'guest upgrade HTTP $status keeps its existing verification or conflict behavior',
      () async {
        final f = _Fixture(stored: true)..guest = true;
        addTearDown(f.dispose);
        await f.model.restoreSession();
        await f.model.openAccountLogin();
        f.model.drainEffects();
        f.authResponse = _json({'detail': 'upgrade fixture error'}, status);
        await f.model.authenticateSocial(SocialLoginProvider.google);
        expect(_failure(f.model), isNull);
        expect(f.model.linkingGuest, isTrue);
        expect(f.session.hasSession, isTrue);
        final effects = f.model.drainEffects();
        if (status == 409) {
          expect(effects.whereType<ConfirmAccountSwitchEffect>(), hasLength(1));
          expect(effects.whereType<MessageEffect>(), isEmpty);
        } else {
          expect(effects.whereType<MessageEffect>(), hasLength(1));
        }
        if (status == 401) {
          expect(f.paths.where((p) => p == '/api/v1/users/me'), hasLength(2));
        }
        expect(f.paths.where((p) => p.endsWith('/upgrade')), hasLength(1));
      },
    );
  }

  test(
    'explicit account switch does not use ordinary login failure even on login route',
    () async {
      final f = _Fixture(stored: true)..guest = true;
      addTearDown(f.dispose);
      await f.model.restoreSession();
      await f.model.openAccountLogin();
      f.model.drainEffects();
      f.authResponse = _json({'detail': 'switch fixture error'}, 503);
      await f.model.authenticateSocial(
        SocialLoginProvider.google,
        switchAccount: true,
      );
      expect(_failure(f.model), isNull);
      expect(f.model.drainEffects().whereType<MessageEffect>(), hasLength(1));
    },
  );

  test(
    'security invalidation clears existing failure and dominates pending device deletion',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      await f.failOrdinary();
      final old = _failure(f.model);
      expect(old, isNotNull);
      f.storage.failClear = true;
      await f.session.invalidate();
      expect(_failure(f.model), isNull);
      expect(_dismiss(f.model, old), isFalse);
      expect(f.session.pendingSessionClear, isTrue);
      expect(f.model.apiConnectionError, isNotNull);
      f.storage.failClear = false;
      await f.model.restoreSession();
      expect(_failure(f.model), isNull);
      expect(f.model.route, AppRoute.login);
    },
  );

  for (final kind in ['sdk', 'http']) {
    test(
      '$kind late failure after account invalidation cannot recreate A05',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        await f.loginChoice();
        if (kind == 'sdk') {
          f.social.gate = Completer<SocialCredential?>();
        } else {
          f.authGate = Completer<http.Response>();
        }
        final operation = f.model.authenticateSocial(
          SocialLoginProvider.google,
        );
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        await f.session.invalidate();
        f.model.drainEffects();
        if (kind == 'sdk') {
          f.social.gate!.completeError(
            const SocialAuthException('late SDK failure'),
          );
        } else {
          f.authGate!.complete(_json({'detail': 'late auth failure'}, 503));
        }
        await operation;
        expect(_failure(f.model), isNull);
        expect(f.model.drainEffects(), isEmpty);
        expect(f.model.route, AppRoute.login);
      },
    );
  }

  test(
    'disposed model ignores pending failure and notifies nothing later',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.loginChoice();
      f.social.gate = Completer<SocialCredential?>();
      final pending = f.model.authenticateSocial(SocialLoginProvider.google);
      await Future<void>.delayed(Duration.zero);
      var notifications = 0;
      f.model.addListener(() => notifications++);
      f.model.dispose();
      f.modelDisposed = true;
      final before = notifications;
      f.social.gate!.completeError(
        const SocialAuthException('late disposed failure'),
      );
      await pending;
      expect(_failure(f.model), isNull);
      expect(notifications, before);
    },
  );
}
