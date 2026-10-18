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

class _Storage extends ApiSessionStorage {
  ApiSession? value;
  @override
  Future<ApiSession?> read() async => value;
  @override
  Future<void> write(ApiSession session) async => value = session;
  @override
  Future<void> clear() async => value = null;
}

class _Social extends SocialAuth {
  int authenticationCount = 0;
  @override
  List<SocialLoginProvider> get supportedProviders => [
    SocialLoginProvider.google,
  ];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async {
    authenticationCount++;
    return const SocialCredential(token: 'fresh-credential');
  }

  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.unavailable;
}

class _Initialization implements AccountInitializationAction {
  _Initialization(this.users);
  @override
  final UserRepository users;
  @override
  ContentRepository get content =>
      throw UnimplementedError('Unused by this fake');
  Future<void> Function()? loadData;
  int loads = 0;
  @override
  void dispose() {}
  @override
  void reset(int generation) => users.resetAccount(generation);
  @override
  Future<void> load() async {
    loads++;
    await loadData?.call();
  }
}

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

const _tokens = {
  'access_token': 'guest-access',
  'refresh_token': 'guest-refresh',
  'expires_in': 60,
  'refresh_expires_in': 600,
};

void main() {
  late ClipbackApi api;
  late RemoteSessionRepository session;
  late RemoteUserRepository users;
  late _Initialization initialize;
  late AppViewModel model;
  late _Social social;
  late Future<http.Response> Function(http.Request) respond;
  var modelDisposed = false;

  setUp(() {
    modelDisposed = false;
    respond = (_) async => _json(_tokens, 201);
    social = _Social();
    api = ClipbackApi(
      client: MockClient((request) => respond(request)),
      onSessionChanged: (_) => session.persistCurrentSession(),
      onSessionInvalidated: () => session.invalidate(),
    );
    session = RemoteSessionRepository(
      api: api,
      storage: _Storage(),
      socialAuth: social,
    );
    users = RemoteUserRepository(api: api);
    initialize = _Initialization(users);
    model = AppViewModel(
      session: session,
      users: users,
      initializeAccount: initialize,
    );
  });

  tearDown(() {
    if (!modelDisposed) model.dispose();
    users.dispose();
    session.dispose();
  });

  test(
    'issued guest session retries bootstrap without issuing another token',
    () async {
      var guestRequests = 0;
      respond = (_) async {
        guestRequests++;
        return _json(_tokens, 201);
      };
      var failLoad = true;
      initialize.loadData = () async {
        if (failLoad) throw StateError('feed unavailable');
      };
      await model.restoreSession();
      await model.continueAsGuest();
      expect(guestRequests, 1);
      expect(session.hasSession, isTrue);
      expect(model.apiConnectionError, isNotNull);
      expect(model.authBusy, isFalse);
      failLoad = false;
      await model.restoreSession();
      expect(guestRequests, 1);
      expect(initialize.loads, 2);
      expect(model.route, AppRoute.onboarding);
      expect(model.apiConnectionError, isNull);
    },
  );

  test(
    'bootstrap identity is visible while its stats request is pending',
    () async {
      respond = (request) async {
        if (request.url.path.endsWith('/users/me')) {
          return _json({
            'id': 1,
            'email': null,
            'display_name': 'guest',
            'is_guest': true,
            'created_at': '2026-10-01T00:00:00Z',
            'linked_providers': [],
          });
        }
        return _json(_tokens, 201);
      };
      final userLoaded = Completer<void>();
      final finishStats = Completer<void>();
      initialize.loadData = () async {
        await users.loadMe();
        userLoaded.complete();
        await finishStats.future;
      };
      await model.restoreSession();
      final authentication = model.continueAsGuest();
      await userLoaded.future;
      expect(model.authenticatedUser?.displayName, 'guest');
      expect(model.authBusy, isTrue);
      finishStats.complete();
      await authentication;
      expect(model.authBusy, isFalse);
    },
  );

  test(
    'disposed model ignores an in-flight authentication completion',
    () async {
      final response = Completer<http.Response>();
      respond = (_) => response.future;
      await model.restoreSession();
      model.drainEffects();
      final generation = model.accountGeneration;
      final authentication = model.continueAsGuest();
      model.dispose();
      modelDisposed = true;
      response.complete(_json(_tokens, 201));
      await authentication;
      expect(initialize.loads, 0);
      expect(model.accountGeneration, generation);
      expect(model.drainEffects(), isEmpty);
    },
  );

  test(
    'a conflict owner from an older authentication cannot switch accounts',
    () async {
      respond = (request) async {
        if (request.url.path.endsWith('/upgrade')) {
          return _json({'detail': 'Existing account'}, 409);
        }
        if (request.url.path.endsWith('/users/me')) {
          return _json({
            'id': 1,
            'email': null,
            'display_name': 'guest',
            'is_guest': true,
            'created_at': '2026-10-01T00:00:00Z',
            'linked_providers': [],
          });
        }
        if (request.url.path.endsWith('/logout')) return http.Response('', 204);
        return _json(_tokens, 201);
      };
      initialize.loadData = () async {
        await users.loadMe();
      };
      await model.restoreSession();
      await model.continueAsGuest();
      await model.openAccountLogin();
      model.drainEffects();
      await model.authenticateSocial(SocialLoginProvider.google);
      final conflict = model.accountLinkConflict!;
      expect(model.drainEffects(), isEmpty);
      expect(social.authenticationCount, 1);
      await model.logout();
      await model.confirmAccountSwitch(conflict.authEpoch, conflict.provider);
      expect(social.authenticationCount, 1);
      expect(model.route, AppRoute.login);
      expect(session.hasSession, isFalse);
    },
  );
  for (final action in ['guest', 'social', 'logout']) {
    test(
      '$action waits for durable share block before authentication work',
      () async {
        model.dispose();
        final barrier = Completer<void>();
        model = AppViewModel(
          session: session,
          users: users,
          initializeAccount: initialize,
          beforeSessionChange: () => barrier.future,
        );
        var requests = 0;
        respond = (_) async {
          requests++;
          return _json(_tokens, 201);
        };
        if (action == 'logout') {
          api.restoreSession(ApiSession.fromJson(_tokens));
          respond = (_) async {
            requests++;
            return http.Response('', 204);
          };
        }
        final operation = switch (action) {
          'guest' => model.continueAsGuest(),
          'social' => model.authenticateSocial(SocialLoginProvider.google),
          _ => model.logout(),
        };
        await Future<void>.delayed(Duration.zero);
        expect(requests, 0);
        expect(social.authenticationCount, 0);
        expect(model.authBusy, isTrue);
        barrier.completeError(StateError('native storage unavailable'));
        await operation;
        expect(requests, 0);
        expect(social.authenticationCount, 0);
        expect(model.authBusy, isFalse);
        expect(model.drainEffects().whereType<MessageEffect>(), isNotEmpty);
      },
    );
  }
}
