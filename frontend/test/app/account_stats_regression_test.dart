import 'dart:convert';

import 'package:clipback_frontend/app/actions/account_initialization_action.dart';
import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/app/app_view_model.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/features/account/view_models/account_view_model.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _session = ApiSession(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  expiresIn: 60,
  refreshExpiresIn: 600,
);

class _Storage extends ApiSessionStorage {
  @override
  Future<ApiSession?> read() async => _session;
  @override
  Future<void> write(ApiSession value) async {}
  @override
  Future<void> clear() async {}
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
    return null;
  }

  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.unavailable;
}

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'cancelling account connect preserves recovered stats after bootstrap profile failure',
    () async {
      var profileRequests = 0;
      var statsRequests = 0;
      var authRequests = 0;
      final api = ClipbackApi(
        client: MockClient((request) async {
          if (request.url.path.contains('/auth/')) authRequests++;
          if (request.url.path.endsWith('/categories')) return _json([]);
          if (request.url.path.endsWith('/feed')) {
            return _json({'items': [], 'next_cursor': null});
          }
          if (request.url.path.endsWith('/stats')) {
            statsRequests++;
            return _json({'saved_count': 70, 'reopened_count': 30});
          }
          if (request.url.path.endsWith('/users/me')) {
            profileRequests++;
            if (profileRequests == 1) {
              return _json({'detail': 'temporary failure'}, 500);
            }
            return _json({
              'id': 1,
              'email': null,
              'display_name': 'guest',
              'is_guest': true,
              'created_at': '2026-10-01T00:00:00Z',
              'linked_providers': [],
            });
          }
          fail('Unexpected request: ${request.url}');
        }),
      );
      final social = _Social();
      final session = RemoteSessionRepository(
        api: api,
        storage: _Storage(),
        socialAuth: social,
      );
      final content = RemoteContentRepository(api);
      final users = RemoteUserRepository(api: api);
      final initialize = AccountInitializationAction(content, users);
      final actions = ContentActions(content, users, session);
      final app = AppViewModel(
        session: session,
        users: users,
        initializeAccount: initialize,
      );
      final account = AccountViewModel(users);
      addTearDown(() {
        app.dispose();
        account.dispose();
        actions.dispose();
        initialize.dispose();
        content.dispose();
        users.dispose();
        session.dispose();
      });

      await app.restoreSession();
      expect(app.route, AppRoute.home);
      expect(app.apiConnectionError, isNull);
      expect(app.authenticatedUser, isNull);
      expect(account.user.savedContentCount, 70);
      expect(account.user.revisitedContentCount, 30);

      // A subsequent content refresh recovers the profile and preserves server counts.
      await actions.refresh((_) {});
      expect(account.user.savedContentCount, 70);
      expect(account.user.revisitedContentCount, 30);
      expect(app.authenticatedUser, isNull);

      app.go(AppRoute.account);
      await app.openAccountLogin();
      expect(app.route, AppRoute.login);
      expect(app.linkingGuest, isTrue);
      expect(app.authenticatedUser?.isGuest, isTrue);

      // The login screen's back callback returns without authenticating.
      app.go(AppRoute.account);
      expect(app.route, AppRoute.account);
      expect(account.user.savedContentCount, 70);
      expect(account.user.revisitedContentCount, 30);
      expect(profileRequests, 3);
      expect(statsRequests, 2);
      expect(social.authenticationCount, 0);
      expect(authRequests, 0);
    },
  );
}
