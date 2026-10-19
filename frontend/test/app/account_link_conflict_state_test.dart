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
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _guest = ApiSession(
  accessToken: 'conflict-guest-access',
  refreshToken: 'conflict-guest-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// Baseline compilation is intentional: absent owned state is the red result.
dynamic _conflict(AppViewModel app) {
  try {
    return (app as dynamic).accountLinkConflict;
  } on NoSuchMethodError {
    return null;
  }
}

bool _cancel(AppViewModel app, dynamic expected) =>
    (app as dynamic).cancelAccountLinkConflict(expected) as bool;

class _Storage extends ApiSessionStorage {
  ApiSession? value = _guest;
  bool failWrite = false, failClear = false;
  int writes = 0, clears = 0;
  @override
  Future<ApiSession?> read() async => value;
  @override
  Future<void> write(ApiSession next) async {
    writes++;
    if (failWrite) throw StateError('fixture write failed');
    value = next;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (failClear) throw StateError('fixture clear failed');
    value = null;
  }
}

class _Social extends SocialAuth {
  final calls = <SocialLoginProvider>[];
  final nonces = <String?>[];
  Completer<SocialCredential?>? gate;
  bool cancel = false, failMetadata = false;
  Object? error;
  @override
  List<SocialLoginProvider> get supportedProviders =>
      SocialLoginProvider.values;
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async {
    calls.add(provider);
    nonces.add(nonce);
    if (gate case final pending?) return pending.future;
    if (error case final failure?) throw failure;
    if (cancel) return null;
    return SocialCredential(
      token: 'fixture-credential-${calls.length}',
      authorizationCode: 'fixture-code-${calls.length}',
      providerUserId: 'fixture-user',
    );
  }

  @override
  Future<void> rememberAppleUserId(String? userId) async {
    if (failMetadata) throw StateError('fixture metadata failed');
  }

  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.authorized;
}

class _Fixture {
  _Fixture({Future<void> Function()? beforeSessionChange}) {
    client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path.endsWith('/apple/challenge')) {
        challenges++;
        if (challengeStatus case final status?) {
          return _json({'detail': 'fixture current linking conflict'}, status);
        }
        return _json({
          'challenge_id': 'challenge-$challenges',
          'nonce': 'nonce-$challenges',
          'expires_at': '2030-10-19T00:00:00Z',
        }, 201);
      }
      if (path.startsWith('/api/v1/auth/social/')) {
        if (path.endsWith('/upgrade')) {
          if (upgradeGate case final pending?) return pending.future;
          return _json({
            'detail': 'Social account is already linked',
          }, upgradeStatus);
        }
        if (switchStatus case final status?) {
          return _json({'detail': 'switch fixture failed'}, status);
        }
        isGuest = false;
        return _json({
          'access_token': 'switched-access',
          'refresh_token': 'switched-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
          'is_new_user': isNewUser,
        });
      }
      if (path == '/api/v1/auth/logout') return http.Response('', 204);
      if (path == '/api/v1/categories') {
        if (failBootstrap) {
          return _json({'detail': 'bootstrap unavailable'}, 503);
        }
        return _json(<Object>[]);
      }
      if (path == '/api/v1/feed') {
        return _json({
          'items': [
            {
              'id': isGuest ? 7 : 19,
              'categories': <Object>[],
              'tags': <Object>[],
              'assets': <Object>[],
              'content_type': 'link',
              'source': 'web',
              'title': isGuest ? '게스트 콘텐츠' : '새 계정 콘텐츠',
              'summary': '보존 확인',
              'original_url': 'https://example.invalid/saved',
              'is_favorite': false,
              'saved_at': '2026-10-01T00:00:00Z',
              'last_viewed_at': null,
            },
          ],
          'next_cursor': null,
        });
      }
      if (path == '/api/v1/users/me') {
        return _json({
          'id': isGuest ? 1 : 2,
          'email': null,
          'display_name': isGuest ? '게스트' : '새 계정',
          'is_guest': isGuest,
          'created_at': '2026-10-01T00:00:00Z',
          'linked_providers': isGuest ? <String>[] : ['google'],
        });
      }
      if (path == '/api/v1/users/me/stats') {
        return _json({
          'saved_count': isGuest ? 73 : 21,
          'reopened_count': isGuest ? 201 : 55,
        });
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
    content = RemoteContentRepository(api);
    users = RemoteUserRepository(api: api);
    initialize = AccountInitializationAction(content, users);
    app = AppViewModel(
      session: session,
      users: users,
      initializeAccount: initialize,
      beforeSessionChange: beforeSessionChange,
    );
  }
  final storage = _Storage();
  final social = _Social();
  final requests = <http.Request>[];
  int upgradeStatus = 409, challenges = 0;
  int? switchStatus, challengeStatus;
  bool isGuest = true,
      isNewUser = false,
      failBootstrap = false,
      modelDisposed = false;
  Completer<http.Response>? upgradeGate;
  late final MockClient client;
  late final ClipbackApi api;
  late final RemoteSessionRepository session;
  late final RemoteContentRepository content;
  late final RemoteUserRepository users;
  late final AccountInitializationAction initialize;
  late final AppViewModel app;
  Future<void> ready() async {
    await app.restoreSession();
    app.go(AppRoute.account);
    await app.openAccountLogin();
    expect(app.linkingGuest, isTrue);
    expect(app.route, AppRoute.login);
    app.drainEffects();
  }

  Future<dynamic> conflict([
    SocialLoginProvider provider = SocialLoginProvider.google,
  ]) async {
    await ready();
    await app.authenticateSocial(provider);
    final result = _conflict(app);
    expect(
      result,
      isNotNull,
      reason: 'A current upgrade409 must own A05-1 state',
    );
    return result;
  }

  List<http.Request> calls(String suffix) =>
      requests.where((r) => r.url.path.endsWith(suffix)).toList();
  void expectGuest() {
    expect(api.session?.accessToken, _guest.accessToken);
    expect(storage.value?.accessToken, _guest.accessToken);
    expect(content.feed(FeedKey.home).items.map((c) => c.id), [7]);
    expect(users.stats?.savedCount, 73);
    expect(users.stats?.reopenedCount, 201);
    expect(app.authenticatedUser?.isGuest, isTrue);
  }

  void dispose() {
    if (!modelDisposed) app.dispose();
    initialize.dispose();
    content.dispose();
    users.dispose();
    session.dispose();
    client.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'only current guest upgrade409 owns conflict without legacy dialog effect',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final c = await f.conflict();
      expect(c.provider, SocialLoginProvider.google);
      expect(c.authEpoch, f.app.authEpoch);
      expect(c.accountGeneration, f.app.accountGeneration);
      expect(f.app.ordinaryLoginFailure, isNull);
      expect(f.app.drainEffects(), isEmpty);
      expect(f.app.authBusy, isFalse);
      f.expectGuest();
      expect(f.calls('/auth/social/google/upgrade'), hasLength(1));
      expect(f.calls('/auth/social/google'), isEmpty);
    },
  );
  test(
    'cancel consumes once with no auth request, epoch or guest data change',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final c = await f.conflict(),
          epoch = f.app.authEpoch,
          count = f.requests.length;
      expect(_cancel(f.app, c), isTrue);
      expect(_cancel(f.app, c), isFalse);
      expect(_conflict(f.app), isNull);
      expect(f.requests, hasLength(count));
      expect(f.app.authEpoch, epoch);
      expect(f.app.route, AppRoute.login);
      expect(f.app.linkingGuest, isTrue);
      f.expectGuest();
    },
  );
  test(
    'pending conflict blocks retained linking social guest and back callbacks',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final c = await f.conflict(),
          count = f.requests.length,
          epoch = f.app.authEpoch;
      await f.app.authenticateSocial(SocialLoginProvider.kakao);
      await f.app.continueAsGuest();
      f.app.go(AppRoute.account);
      f.app.openSearch();
      f.app.openDetail();
      f.app.backFromDetail();
      expect(identical(_conflict(f.app), c), isTrue);
      expect(f.requests, hasLength(count));
      expect(f.social.calls, hasLength(1));
      expect(f.app.route, AppRoute.login);
      expect(f.app.authEpoch, epoch);
      f.expectGuest();
    },
  );
  test(
    'owned conflict is published atomically before unlocking retained callbacks',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.ready();
      var attempted = false;
      f.app.addListener(() {
        if (!f.app.authBusy && !attempted) {
          attempted = true;
          unawaited(f.app.authenticateSocial(SocialLoginProvider.kakao));
          unawaited(f.app.continueAsGuest());
          f.app.go(AppRoute.account);
        }
      });
      await f.app.authenticateSocial(SocialLoginProvider.google);
      expect(attempted, isTrue);
      expect(_conflict(f.app), isNotNull);
      expect(f.social.calls, [SocialLoginProvider.google]);
      expect(f.app.route, AppRoute.login);
      f.expectGuest();
    },
  );
  test(
    'confirm consumes before one fresh SDK attempt and duplicate confirm is ignored',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final c = await f.conflict();
      f.social.gate = Completer<SocialCredential?>();
      final first = f.app.confirmAccountSwitch(
        c.authEpoch as int,
        c.provider as SocialLoginProvider,
      );
      await Future<void>.delayed(Duration.zero);
      await f.app.confirmAccountSwitch(
        c.authEpoch as int,
        c.provider as SocialLoginProvider,
      );
      expect(f.app.authBusy, isTrue);
      expect(_conflict(f.app), isNull);
      expect(f.social.calls, hasLength(2));
      expect(_cancel(f.app, c), isFalse);
      f.social.gate!.complete(null);
      await first;
      expect(f.app.authBusy, isFalse);
      expect(f.app.linkingGuest, isTrue);
      expect(f.app.ordinaryLoginFailure, isNull);
      f.expectGuest();
      expect(f.calls('/auth/social/google'), isEmpty);
    },
  );
  test(
    'Apple switch uses new login challenge nonce code and an unauthenticated endpoint',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final c = await f.conflict(SocialLoginProvider.apple);
      await f.app.confirmAccountSwitch(
        c.authEpoch as int,
        c.provider as SocialLoginProvider,
      );
      expect(f.social.nonces, ['nonce-1', 'nonce-2']);
      final challenges = f.calls('/auth/social/apple/challenge');
      expect(jsonDecode(challenges[0].body), {'purpose': 'upgrade'});
      expect(jsonDecode(challenges[1].body), {'purpose': 'login'});
      expect(
        challenges[0].headers['Authorization'],
        'Bearer ${_guest.accessToken}',
      );
      expect(challenges[1].headers['Authorization'], isNull);
      final login = f.calls('/auth/social/apple').single;
      expect(jsonDecode(login.body)['challenge_id'], 'challenge-2');
      expect(jsonDecode(login.body)['authorization_code'], 'fixture-code-2');
      expect(login.headers['Authorization'], isNull);
      expect(_conflict(f.app), isNull);
      expect(f.app.route, AppRoute.home);
    },
  );
  for (final isNew in [false, true]) {
    test('successful switch respects server isNewUser=$isNew', () async {
      final f = _Fixture()..isNewUser = isNew;
      addTearDown(f.dispose);
      final c = await f.conflict();
      await f.app.confirmAccountSwitch(
        c.authEpoch as int,
        c.provider as SocialLoginProvider,
      );
      expect(f.app.route, isNew ? AppRoute.onboarding : AppRoute.home);
      expect(f.storage.value?.accessToken, 'switched-access');
      expect(_conflict(f.app), isNull);
      expect(f.app.ordinaryLoginFailure, isNull);
      expect(f.content.feed(FeedKey.home).items.single.id, 19);
    });
  }
  for (final kind in ['sdk', 'http']) {
    test(
      'switch $kind failure keeps guest and existing message without A05',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        final c = await f.conflict();
        if (kind == 'sdk') {
          f.social.error = const SocialAuthException('switch SDK unavailable');
        } else {
          f.switchStatus = 503;
        }
        await f.app.confirmAccountSwitch(
          c.authEpoch as int,
          c.provider as SocialLoginProvider,
        );
        expect(_conflict(f.app), isNull);
        expect(f.app.ordinaryLoginFailure, isNull);
        expect(f.app.drainEffects().whereType<MessageEffect>(), hasLength(1));
        expect(f.app.route, AppRoute.login);
        expect(f.app.linkingGuest, isTrue);
        f.expectGuest();
      },
    );
  }
  test(
    'issued switch bootstrap failure retries data without another SDK or switch',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final c = await f.conflict();
      f.failBootstrap = true;
      await f.app.confirmAccountSwitch(
        c.authEpoch as int,
        c.provider as SocialLoginProvider,
      );
      expect(_conflict(f.app), isNull);
      expect(f.app.ordinaryLoginFailure, isNull);
      expect(f.app.apiConnectionError, isNotNull);
      expect(f.api.session?.accessToken, 'switched-access');
      f.failBootstrap = false;
      await f.app.restoreSession();
      expect(f.app.route, AppRoute.home);
      expect(f.social.calls, hasLength(2));
      expect(f.calls('/auth/social/google'), hasLength(1));
    },
  );
  test(
    'issued switch device persistence or metadata warning cannot resurrect conflict',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final c = await f.conflict(SocialLoginProvider.apple);
      f.storage.failWrite = true;
      f.social.failMetadata = true;
      await f.app.confirmAccountSwitch(
        c.authEpoch as int,
        c.provider as SocialLoginProvider,
      );
      expect(f.api.session?.accessToken, 'switched-access');
      expect(f.session.needsPersistence, isTrue);
      expect(f.app.route, AppRoute.home);
      expect(_conflict(f.app), isNull);
      expect(f.app.drainEffects().whereType<MessageEffect>(), hasLength(1));
    },
  );
  test(
    'sharing barrier error cannot become an unperformed upgrade conflict',
    () async {
      final f = _Fixture(
        beforeSessionChange: () async {
          throw const ClipbackApiException(
            'fixture barrier conflict',
            statusCode: 409,
          );
        },
      );
      addTearDown(f.dispose);
      await f.ready();
      await f.app.authenticateSocial(SocialLoginProvider.google);
      expect(_conflict(f.app), isNull);
      expect(f.app.ordinaryLoginFailure, isNull);
      expect(f.social.calls, isEmpty);
      expect(f.calls('/auth/social/google/upgrade'), isEmpty);
      expect(f.app.drainEffects().whereType<MessageEffect>(), hasLength(1));
      f.expectGuest();
    },
  );
  test(
    'current Apple challenge409 has neutral ownership without inferring target account',
    () async {
      final f = _Fixture()..challengeStatus = 409;
      addTearDown(f.dispose);
      await f.ready();
      await f.app.authenticateSocial(SocialLoginProvider.apple);
      final c = _conflict(f.app);
      expect(c, isNotNull);
      expect(c.provider, SocialLoginProvider.apple);
      expect(f.social.calls, isEmpty);
      expect(f.calls('/auth/social/apple/upgrade'), isEmpty);
      expect(f.app.drainEffects(), isEmpty);
      f.expectGuest();
      f.challengeStatus = null;
      await f.app.confirmAccountSwitch(
        c.authEpoch as int,
        c.provider as SocialLoginProvider,
      );
      expect(f.challenges, 2);
      expect(f.social.nonces, ['nonce-2']);
      expect(f.calls('/auth/social/apple'), hasLength(1));
      expect(f.app.route, AppRoute.home);
    },
  );
  for (final status in [401, 403, 503]) {
    test('upgrade$status keeps existing non-conflict error handling', () async {
      final f = _Fixture()..upgradeStatus = status;
      addTearDown(f.dispose);
      await f.ready();
      await f.app.authenticateSocial(SocialLoginProvider.google);
      expect(_conflict(f.app), isNull);
      expect(f.app.ordinaryLoginFailure, isNull);
      expect(f.app.drainEffects().whereType<MessageEffect>(), hasLength(1));
      f.expectGuest();
      if (status == 401) {
        expect(f.calls('/users/me'), hasLength(2));
      }
    });
  }
  test(
    'ordinary login409 remains A05 and cannot become account link conflict',
    () async {
      final f = _Fixture()..switchStatus = 409;
      addTearDown(f.dispose);
      f.storage.value = null;
      await f.app.restoreSession();
      f.app.drainEffects();
      await f.app.authenticateSocial(SocialLoginProvider.google);
      expect(_conflict(f.app), isNull);
      expect(f.app.ordinaryLoginFailure, isNotNull);
      expect(f.app.ordinaryLoginFailure?.statusCode, 409);
    },
  );
  test(
    'wrong provider and stale consumed epoch cannot confirm a newer conflict',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final old = await f.conflict();
      await f.app.confirmAccountSwitch(
        old.authEpoch as int,
        SocialLoginProvider.kakao,
      );
      expect(identical(_conflict(f.app), old), isTrue);
      expect(f.social.calls, hasLength(1));
      expect(_cancel(f.app, old), isTrue);
      await f.app.authenticateSocial(SocialLoginProvider.google);
      final next = _conflict(f.app);
      expect(next, isNotNull);
      await f.app.confirmAccountSwitch(
        old.authEpoch as int,
        old.provider as SocialLoginProvider,
      );
      expect(_cancel(f.app, old), isFalse);
      expect(identical(_conflict(f.app), next), isTrue);
      expect(f.social.calls, hasLength(2));
    },
  );
  test(
    'security invalidation and failed session deletion dominate owned conflict',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final c = await f.conflict();
      f.storage.failClear = true;
      await f.session.invalidate();
      expect(_conflict(f.app), isNull);
      expect(_cancel(f.app, c), isFalse);
      await f.app.confirmAccountSwitch(
        c.authEpoch as int,
        c.provider as SocialLoginProvider,
      );
      expect(f.social.calls, hasLength(1));
      expect(f.session.pendingSessionClear, isTrue);
      expect(f.app.apiConnectionError, isNotNull);
      f.storage.failClear = false;
      await f.app.restoreSession();
      expect(f.app.route, AppRoute.login);
      expect(f.session.hasSession, isFalse);
    },
  );
  for (final exit in ['navigate', 'invalidate']) {
    test('late upgrade409 after $exit cannot create a conflict', () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.ready();
      f.upgradeGate = Completer<http.Response>();
      final attempt = f.app.authenticateSocial(SocialLoginProvider.google);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      if (exit == 'navigate') {
        f.app.go(AppRoute.account);
      } else {
        await f.session.invalidate();
      }
      f.app.drainEffects();
      f.upgradeGate!.complete(_json({'detail': 'late upgrade409'}, 409));
      await attempt;
      expect(_conflict(f.app), isNull);
      expect(f.app.drainEffects(), isEmpty);
      expect(
        f.app.route,
        exit == 'navigate' ? AppRoute.account : AppRoute.login,
      );
    });
  }
  test(
    'disposed conflict ignores old cancel confirm and late notifications',
    () async {
      final f = _Fixture();
      addTearDown(f.dispose);
      final c = await f.conflict();
      var notifications = 0;
      f.app.addListener(() => notifications++);
      f.app.dispose();
      f.modelDisposed = true;
      final before = notifications;
      expect(_conflict(f.app), isNull);
      expect(_cancel(f.app, c), isFalse);
      await f.app.confirmAccountSwitch(
        c.authEpoch as int,
        c.provider as SocialLoginProvider,
      );
      expect(notifications, before);
      expect(f.social.calls, hasLength(1));
    },
  );
}
