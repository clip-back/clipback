import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/actions/account_initialization_action.dart';
import 'package:clipback_frontend/app/app_view_model.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _stored = ApiSession(
  accessToken: 'initial-home-access',
  refreshToken: 'initial-home-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _categories = '/api/v1/categories';
const _feed = '/api/v1/feed';
const _me = '/api/v1/users/me';
const _stats = '/api/v1/users/me/stats';
const _bootstrapPaths = [_categories, _feed, _me, _stats];

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// The semantic baseline must compile before the new getter exists. Its absence
// is a false result, allowing the initial-data tests to show the actual red gap.
bool _loading(AppViewModel model) {
  try {
    return (model as dynamic).showInitialHomeLoading as bool;
  } on NoSuchMethodError {
    return false;
  }
}

class _Storage extends ApiSessionStorage {
  _Storage(this.value);
  ApiSession? value;
  Completer<ApiSession?>? readGate;
  Completer<void>? clearGate;
  bool failClear = false;
  int reads = 0, clears = 0;
  @override
  Future<ApiSession?> read() async {
    reads++;
    return readGate == null ? value : readGate!.future;
  }

  @override
  Future<void> write(ApiSession session) async => value = session;
  @override
  Future<void> clear() async {
    clears++;
    await clearGate?.future;
    if (failClear) throw StateError('fixture clear failed');
    value = null;
  }
}

class _Social extends SocialAuth {
  Completer<SocialCredential?>? authGate;
  Completer<AppleCredentialStatus>? appleGate;
  int authCalls = 0, appleChecks = 0;
  @override
  List<SocialLoginProvider> get supportedProviders => const [
    SocialLoginProvider.google,
  ];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async {
    authCalls++;
    return authGate == null
        ? const SocialCredential(token: 'fixture-social')
        : authGate!.future;
  }

  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async {
    appleChecks++;
    return appleGate == null
        ? AppleCredentialStatus.authorized
        : appleGate!.future;
  }
}

class _Fixture {
  _Fixture({ApiSession? stored = _stored}) : storage = _Storage(stored) {
    client = MockClient((request) async {
      final path = request.url.path;
      paths.add(path);
      if (gates[path] case final gate?) return gate.future;
      if (failures[path] case final status?) {
        return _json({'detail': 'fixture failure'}, status);
      }
      return response(path);
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
    content = RemoteContentRepository(api);
    users = RemoteUserRepository(api: api);
    initialize = AccountInitializationAction(content, users);
    model = AppViewModel(
      session: session,
      users: users,
      initializeAccount: initialize,
    );
  }

  final _Storage storage;
  final social = _Social();
  final paths = <String>[];
  final gates = <String, Completer<http.Response>>{};
  final failures = <String, int>{};
  bool guest = false, newUser = false, apple = false, disposed = false;
  late final MockClient client;
  late final ClipbackApi api;
  late final RemoteSessionRepository session;
  late final RemoteContentRepository content;
  late final RemoteUserRepository users;
  late final AccountInitializationAction initialize;
  late final AppViewModel model;

  http.Response response(String path) {
    if (path == _categories) return _json(<Object>[]);
    if (path == _feed) {
      return _json({'items': <Object>[], 'next_cursor': null});
    }
    if (path == _me) {
      return _json({
        'id': 41,
        'email': null,
        'display_name': '첫 홈 검증',
        'is_guest': guest,
        'created_at': '2026-10-18T00:00:00Z',
        'linked_providers': guest
            ? <String>[]
            : [if (apple) 'apple' else 'google'],
      });
    }
    if (path == _stats) {
      return _json({'saved_count': 0, 'reopened_count': 0});
    }
    if (path == '/api/v1/auth/logout') return http.Response('', 204);
    if (path.startsWith('/api/v1/auth/social/') ||
        path == '/api/v1/auth/guest') {
      return _json({
        'access_token': 'issued-access',
        'refresh_token': 'issued-refresh',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
        'is_new_user': newUser,
      }, 201);
    }
    throw StateError('Unexpected fixture request: $path');
  }

  Completer<http.Response> hold(String path) {
    final gate = Completer<http.Response>();
    gates[path] = gate;
    return gate;
  }

  void release(String path, [http.Response? responseValue]) {
    gates.remove(path)!.complete(responseValue ?? response(path));
  }

  Future<void> waitFor(String path) async {
    for (var i = 0; i < 40 && !paths.contains(path); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      paths,
      contains(path),
      reason: 'The fixture request must be pending',
    );
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    model.dispose();
    initialize.dispose();
    content.dispose();
    users.dispose();
    session.dispose();
    client.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final path in _bootstrapPaths) {
    test(
      'cold restore holds initial loading through $path in request order',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        f.hold(path);
        final restore = f.model.restoreSession();
        await f.waitFor(path);
        expect(_loading(f.model), isTrue);
        expect(f.model.isRestoringSession, isTrue);
        await f.model
            .restoreSession(); // A duplicate retry cannot replace its owner.
        expect(
          f.paths,
          _bootstrapPaths.take(_bootstrapPaths.indexOf(path) + 1),
        );
        f.release(path);
        await restore;
        expect(_loading(f.model), isFalse);
        expect(f.model.route, AppRoute.home);
        expect(f.model.apiConnectionError, isNull);
        expect(f.paths, _bootstrapPaths);
        expect(f.storage.reads, 1);
      },
    );
  }

  test(
    'storage read and empty restore never enter initial-home data loading',
    () async {
      final f = _Fixture(stored: null);
      addTearDown(f.dispose);
      f.storage.readGate = Completer<ApiSession?>();
      final restore = f.model.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(_loading(f.model), isFalse);
      expect(f.paths, isEmpty);
      f.storage.readGate!.complete(null);
      await restore;
      expect(f.model.route, AppRoute.login);
      expect(_loading(f.model), isFalse);
    },
  );

  test(
    'first failure retains session and manual retry reuses initial loading',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      f.failures[_categories] = 503;
      await f.model.restoreSession();
      expect(_loading(f.model), isFalse);
      expect(f.model.apiConnectionError, isNotNull);
      expect(f.session.hasSession, isTrue);
      f.failures.clear();
      f.hold(_feed);
      final retry = f.model.restoreSession();
      await f.waitFor(_feed);
      expect(_loading(f.model), isTrue);
      expect(f.model.apiConnectionError, isNull);
      f.release(_feed);
      await retry;
      expect(f.model.route, AppRoute.home);
      expect(_loading(f.model), isFalse);
      expect(f.storage.reads, 1);
      expect(f.paths.where((p) => p.startsWith('/api/v1/auth/')), isEmpty);
    },
  );

  for (final optionalFailure in [_me, _stats]) {
    test(
      '$optionalFailure optional failure completes initialization once',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        f.failures[optionalFailure] = 503;
        await f.model.restoreSession();
        expect(f.model.route, AppRoute.home);
        expect(f.model.apiConnectionError, isNull);
        expect(_loading(f.model), isFalse);
        f.failures.clear();
        f.hold(_categories);
        final again = f.model.restoreSession();
        await Future<void>.delayed(Duration.zero);
        expect(_loading(f.model), isFalse);
        f.release(_categories);
        await again;
      },
    );
  }

  test(
    'completed account refresh filters pagination and route changes do not replay loader',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.model.restoreSession();
      f.hold(_categories);
      final refresh = f.model.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(_loading(f.model), isFalse);
      f.release(_categories);
      await refresh;
      f.hold(_feed);
      f.content.configureFeed(FeedKey.home, categoryId: 71);
      final filtered = f.content.loadNext(FeedKey.home, reset: true);
      await Future<void>.delayed(Duration.zero);
      expect(_loading(f.model), isFalse);
      f.release(_feed);
      await filtered;
      for (final route in [
        AppRoute.archive,
        AppRoute.bookmark,
        AppRoute.my,
        AppRoute.home,
      ]) {
        f.model.go(route);
        expect(_loading(f.model), isFalse);
      }
    },
  );

  test(
    'existing-account social login excludes OAuth and holds only issued-session bootstrap',
    () async {
      final f = _Fixture(stored: null);
      addTearDown(f.dispose);
      await f.model.restoreSession();
      f.social.authGate = Completer<SocialCredential?>();
      f.hold(_categories);
      final login = f.model.authenticateSocial(SocialLoginProvider.google);
      await Future<void>.delayed(Duration.zero);
      expect(f.social.authCalls, 1);
      expect(_loading(f.model), isFalse);
      expect(f.paths, isEmpty);
      f.social.authGate!.complete(const SocialCredential(token: 'approved'));
      await f.waitFor(_categories);
      expect(_loading(f.model), isTrue);
      expect(f.model.route, AppRoute.login);
      f.release(_categories);
      await login;
      expect(f.model.route, AppRoute.home);
      expect(_loading(f.model), isFalse);
      expect(f.social.authCalls, 1);
    },
  );

  test(
    'issued-account bootstrap failure retries without social authentication',
    () async {
      final f = _Fixture(stored: null);
      addTearDown(f.dispose);
      await f.model.restoreSession();
      f.failures[_feed] = 503;
      await f.model.authenticateSocial(SocialLoginProvider.google);
      expect(f.model.apiConnectionError, isNotNull);
      expect(_loading(f.model), isFalse);
      f.failures.clear();
      f.hold(_stats);
      final retry = f.model.restoreSession();
      await f.waitFor(_stats);
      expect(_loading(f.model), isTrue);
      f.release(_stats);
      await retry;
      expect(f.model.route, AppRoute.home);
      expect(f.social.authCalls, 1);
      expect(
        f.paths.where((p) => p == '/api/v1/auth/social/google'),
        hasLength(1),
      );
    },
  );

  for (final kind in ['guest', 'new-social', 'guest-link']) {
    test(
      '$kind initialization is excluded and its successful data is already ready',
      () async {
        final f = _Fixture(stored: kind == 'guest-link' ? _stored : null)
          ..guest = kind != 'new-social';
        addTearDown(f.dispose);
        await f.model.restoreSession();
        if (kind == 'guest-link') await f.model.openAccountLogin();
        if (kind == 'new-social') f.newUser = true;
        f.hold(_categories);
        final operation = kind == 'guest'
            ? f.model.continueAsGuest()
            : f.model.authenticateSocial(SocialLoginProvider.google);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(_loading(f.model), isFalse);
        f.release(_categories);
        await operation;
        expect(
          f.model.route,
          kind == 'guest-link' ? AppRoute.home : AppRoute.onboarding,
        );
        f.hold(_categories);
        final reload = f.model.restoreSession();
        await Future<void>.delayed(Duration.zero);
        expect(_loading(f.model), isFalse);
        f.release(_categories);
        await reload;
      },
    );
  }

  test(
    'Apple credential verification retains loader until its existing completion boundary',
    () async {
      final f = _Fixture()..apple = true;
      addTearDown(f.dispose);
      f.social.appleGate = Completer<AppleCredentialStatus>();
      final restore = f.model.restoreSession();
      for (var i = 0; i < 30 && f.social.appleChecks == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(f.paths, _bootstrapPaths);
      expect(f.social.appleChecks, 1);
      expect(_loading(f.model), isTrue);
      expect(f.model.isRestoringSession, isTrue);
      f.social.appleGate!.complete(AppleCredentialStatus.authorized);
      await restore;
      expect(_loading(f.model), isFalse);
      expect(f.model.route, AppRoute.home);
    },
  );

  test(
    'Apple revocation immediately overrides loading and never exposes home',
    () async {
      final f = _Fixture()..apple = true;
      addTearDown(f.dispose);
      f.social.appleGate = Completer<AppleCredentialStatus>();
      final restore = f.model.restoreSession();
      for (var i = 0; i < 30 && f.social.appleChecks == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(_loading(f.model), isTrue);
      f.storage.clearGate = Completer<void>();
      f.social.appleGate!.complete(AppleCredentialStatus.revoked);
      for (var i = 0; i < 30 && !f.session.pendingSessionClear; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(f.session.pendingSessionClear, isTrue);
      expect(_loading(f.model), isFalse);
      f.storage.clearGate!.complete();
      await restore;
      expect(f.model.route, AppRoute.login);
      expect(f.session.hasSession, isFalse);
    },
  );

  test(
    'invalidation and late old bootstrap cannot restore loading or ready the next account',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      f.hold(_categories);
      final oldRestore = f.model.restoreSession();
      await f.waitFor(_categories);
      expect(_loading(f.model), isTrue);
      await f.session.invalidate();
      expect(_loading(f.model), isFalse);
      expect(f.model.route, AppRoute.login);
      f.release(_categories);
      await oldRestore;
      expect(_loading(f.model), isFalse);
      f.hold(_categories);
      final login = f.model.authenticateSocial(SocialLoginProvider.google);
      for (var i = 0; i < 30 && !f.session.hasSession; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);
      expect(_loading(f.model), isTrue);
      f.release(_categories);
      await login;
      expect(f.model.route, AppRoute.home);
      expect(_loading(f.model), isFalse);
    },
  );

  test(
    'pending session deletion failure takes priority and retry does not show home loader',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      f.hold(_categories);
      final restore = f.model.restoreSession();
      await f.waitFor(_categories);
      f.storage.failClear = true;
      await f.session.invalidate();
      expect(f.session.pendingSessionClear, isTrue);
      expect(_loading(f.model), isFalse);
      f.release(_categories);
      await restore;
      expect(f.model.apiConnectionError, isNotNull);
      f.storage.failClear = false;
      f.storage.clearGate = Completer<void>();
      final retry = f.model.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(_loading(f.model), isFalse);
      f.storage.clearGate!.complete();
      await retry;
      expect(f.model.route, AppRoute.login);
      expect(f.session.hasSession, isFalse);
    },
  );

  test(
    'disposed owner ignores late bootstrap and produces no notifications',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      f.hold(_categories);
      final restore = f.model.restoreSession();
      await f.waitFor(_categories);
      expect(_loading(f.model), isTrue);
      var notifications = 0;
      f.model.addListener(() => notifications++);
      f.model.dispose();
      final before = notifications;
      f.release(_categories);
      await restore;
      expect(_loading(f.model), isFalse);
      expect(notifications, before);
      // Avoid disposing the model twice while still cleaning the repositories.
      f.initialize.dispose();
      f.content.dispose();
      f.users.dispose();
      f.session.dispose();
      f.client.close();
      f.disposed = true;
    },
  );
}
