import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _user(String name) => {
  'id': 1,
  'email': null,
  'display_name': name,
  'is_guest': true,
  'created_at': '2026-10-01T00:00:00Z',
  'linked_providers': [],
};

ClipbackApi _api(MockClient client) =>
    ClipbackApi(client: client)..restoreSession(
      const ApiSession(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        expiresIn: 60,
        refreshExpiresIn: 600,
      ),
    );

void main() {
  test('stale refresh does not start a server request', () async {
    var requests = 0;
    final repository = RemoteUserRepository(
      api: _api(
        MockClient((_) async {
          requests++;
          return _json({});
        }),
      ),
    );
    addTearDown(repository.dispose);
    await repository.refresh(isCurrent: () => false);
    expect(requests, 0);
  });

  test(
    'account reset while stats loads prevents the subsequent profile request',
    () async {
      final statsResponse = Completer<http.Response>();
      final statsRequested = Completer<void>();
      var profileRequests = 0;
      final repository = RemoteUserRepository(
        api: _api(
          MockClient((request) async {
            if (request.url.path.endsWith('/stats')) {
              statsRequested.complete();
              return statsResponse.future;
            }
            profileRequests++;
            return _json(_user('new account'));
          }),
        ),
      );
      addTearDown(repository.dispose);
      final request = repository.refresh(isCurrent: () => true);
      await statsRequested.future;
      repository.resetAccount(1);
      statsResponse.complete(_json({'saved_count': 20, 'reopened_count': 10}));
      await request;
      expect(profileRequests, 0);
      expect(repository.user, isNull);
      expect(repository.stats, isNull);
    },
  );

  test(
    'late old-account user read cannot replace reset account data',
    () async {
      final response = Completer<http.Response>();
      final api = _api(MockClient((_) => response.future));
      final repository = RemoteUserRepository(api: api);
      addTearDown(repository.dispose);
      final request = repository.loadMe();
      repository.resetAccount(1);
      final cancelled = expectLater(request, throwsStateError);
      response.complete(_json(_user('previous account')));
      await cancelled;
      expect(repository.user, isNull);
      expect(repository.stats, isNull);
    },
  );

  test(
    'refresh publishes server counts before the independent profile completes',
    () async {
      final userResponse = Completer<http.Response>();
      final userRequested = Completer<void>();
      final api = _api(
        MockClient((request) async {
          if (request.url.path.endsWith('/stats')) {
            return _json({'saved_count': 700, 'reopened_count': 900});
          }
          userRequested.complete();
          return userResponse.future;
        }),
      );
      final repository = RemoteUserRepository(api: api);
      addTearDown(repository.dispose);
      final request = repository.refresh(isCurrent: () => true);
      await userRequested.future;
      expect(repository.user, isNull);
      expect(repository.stats?.savedCount, 700);
      expect(repository.stats?.reopenedCount, 900);
      userResponse.complete(_json(_user('server user')));
      await request;
      expect(repository.user?.displayName, 'server user');
      expect(repository.stats?.savedCount, 700);
      expect(repository.stats?.reopenedCount, 900);
    },
  );

  test('superseded content refresh cannot publish old stats', () async {
    final response = Completer<http.Response>();
    final api = _api(
      MockClient(
        (request) async => request.url.path.endsWith('/stats')
            ? _json({'saved_count': 20, 'reopened_count': 10})
            : response.future,
      ),
    );
    final repository = RemoteUserRepository(api: api);
    addTearDown(repository.dispose);
    var current = true;
    final request = repository.refresh(isCurrent: () => current);
    current = false;
    response.complete(_json(_user('old refresh')));
    await request;
    expect(repository.user, isNull);
    expect(repository.stats, isNull);
  });

  test(
    'profile lookup preserves statistics already read from the server',
    () async {
      var profileName = 'original name';
      var statsRequests = 0;
      final repository = RemoteUserRepository(
        api: _api(
          MockClient((request) async {
            if (request.url.path.endsWith('/stats')) {
              statsRequests++;
              return _json({'saved_count': 70, 'reopened_count': 30});
            }
            return _json(_user(profileName));
          }),
        ),
      );
      addTearDown(repository.dispose);
      await repository.refresh(isCurrent: () => true);

      profileName = 'updated name';
      await repository.loadMe();

      expect(repository.user?.displayName, 'updated name');
      expect(repository.stats?.savedCount, 70);
      expect(repository.stats?.reopenedCount, 30);
      expect(statsRequests, 1);
    },
  );

  test(
    'account reset clears statistics before the new profile is loaded',
    () async {
      var profileName = 'previous account';
      final repository = RemoteUserRepository(
        api: _api(
          MockClient(
            (request) async => request.url.path.endsWith('/stats')
                ? _json({'saved_count': 70, 'reopened_count': 30})
                : _json(_user(profileName)),
          ),
        ),
      );
      addTearDown(repository.dispose);
      await repository.refresh(isCurrent: () => true);

      repository.resetAccount(1);
      expect(repository.user, isNull);
      expect(repository.stats, isNull);
      profileName = 'new account';
      await repository.loadMe();

      expect(repository.user?.displayName, 'new account');
      expect(repository.stats, isNull);
    },
  );
}
