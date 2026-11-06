// #257: the "cleanup pending" record after a withdrawal (R2 details 1–5).

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/account_deletion_cleanup.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Records implements AccountDeletionCleanupStorage {
  List<AccountDeletionCleanupRecord> saved = [];
  bool failRead = false, failWrite = false;
  int writes = 0;

  @override
  Future<List<AccountDeletionCleanupRecord>> read() async {
    if (failRead) throw StateError('read');
    return List.of(saved);
  }

  @override
  Future<void> write(List<AccountDeletionCleanupRecord> records) async {
    writes++;
    if (failWrite) throw StateError('write');
    saved = List.of(records);
  }
}

class _Steps {
  final calls = <String>[];
  final failing = <String>{};
  Future<void> run(String name) async {
    calls.add(name);
    if (failing.contains(name)) throw StateError(name);
  }

  AccountDeletionCleanup cleanup(_Records records) => AccountDeletionCleanup(
    environment: 'env',
    storage: records,
    clearStoredLogin: () => run('login'),
    clearSearchHistory: (environment, userId) =>
        run('search $environment $userId'),
    discardPendingShares: (userId) => run('shares $userId'),
  );
}

Set<AccountDeletionCleanupStep> _remaining(_Records records) =>
    records.saved.single.remaining;

const _session = ApiSession(
  accessToken: 'deleted',
  refreshToken: 'deleted-refresh',
  expiresIn: 60,
  refreshExpiresIn: 600,
);
const _newLogin = ApiSession(
  accessToken: 'new',
  refreshToken: 'new-refresh',
  expiresIn: 60,
  refreshExpiresIn: 600,
);

class _SessionStorage extends ApiSessionStorage {
  ApiSession? stored = _session;
  bool failClear = false;
  int clears = 0;
  @override
  Future<ApiSession?> read() async => stored;
  @override
  Future<void> write(ApiSession session) async => stored = session;
  @override
  Future<void> clear() async {
    clears++;
    if (failClear) throw StateError('clear');
    stored = null;
  }
}

class _Social extends SocialAuth {
  final appleIds = <String?>[];
  int signOuts = 0, disconnects = 0;
  @override
  List<SocialLoginProvider> get supportedProviders => const [];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => null;
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async => signOuts++;
  @override
  Future<void> rememberAppleUserId(String? userId) async =>
      appleIds.add(userId);
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.unavailable;
  @override
  Future<void> disconnectGoogle() async => disconnects++;
}

void main() {
  late _Records records;
  late _Steps steps;
  setUp(() {
    records = _Records();
    steps = _Steps();
  });

  test('records first, tries each step once and keeps only failures', () async {
    steps.failing.add('search env 7');
    await steps.cleanup(records).start(7);
    expect(steps.calls, ['login', 'search env 7', 'shares 7']);
    expect(records.saved.single.environment, 'env');
    expect(records.saved.single.userId, 7);
    expect(_remaining(records), {AccountDeletionCleanupStep.searchHistory});
    // The first write already held every retried step (R2 detail 1).
    expect(records.writes, 2);

    // Next launch: only what is left, then the record goes.
    steps
      ..failing.clear()
      ..calls.clear();
    await steps.cleanup(records).resume();
    expect(steps.calls, ['search env 7']);
    expect(records.saved, isEmpty);
  });

  test('one-time cleanup is never recorded for the next launch', () async {
    steps.failing.addAll(['login', 'search env 7', 'shares 7']);
    await steps.cleanup(records).start(7);
    expect(
      records.saved.single.toJson()['remaining'],
      unorderedEquals(['storedLogin', 'searchHistory', 'pendingShares']),
    );
  });

  test(
    'a failed record write still tries every step and never throws',
    () async {
      records.failWrite = true;
      steps.failing.add('login');
      await steps.cleanup(records).start(7);
      expect(steps.calls, ['login', 'search env 7', 'shares 7']);
      expect(records.saved, isEmpty);
    },
  );

  test('an unreadable record does not block launch', () async {
    records.failRead = true;
    await steps.cleanup(records).resume();
    expect(steps.calls, isEmpty);
  });

  test(
    'a record per deleted account is retried with its own environment',
    () async {
      records.saved = [
        AccountDeletionCleanupRecord(
          environment: 'old',
          userId: 3,
          remaining: {AccountDeletionCleanupStep.searchHistory},
        ),
      ];
      steps.failing.add('shares 7');
      await steps.cleanup(records).start(7);
      expect(steps.calls, [
        'search old 3',
        'login',
        'search env 7',
        'shares 7',
      ]);
      expect(_remaining(records), {AccountDeletionCleanupStep.pendingShares});
      expect(records.saved.single.userId, 7);
    },
  );

  test(
    'a newer login written over the stored one is not cleared later',
    () async {
      steps.failing.addAll(['login', 'shares 7']);
      final cleanup = steps.cleanup(records);
      await cleanup.start(7);
      await cleanup.storedLoginReplaced();
      expect(_remaining(records), {AccountDeletionCleanupStep.pendingShares});
      steps.calls.clear();
      steps.failing.clear();
      await steps.cleanup(records).resume();
      expect(steps.calls, ['shares 7']);
      expect(records.saved, isEmpty);
    },
  );

  test(
    'preferences keep the record across launches and drop it when done',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PreferencesAccountDeletionCleanupStorage();
      final record = AccountDeletionCleanupRecord(
        environment: 'env',
        userId: 7,
        remaining: {AccountDeletionCleanupStep.storedLogin},
      );
      await storage.write([record]);
      final read = await PreferencesAccountDeletionCleanupStorage().read();
      expect(read.single.toJson(), record.toJson());
      await storage.write(const []);
      expect(
        (await SharedPreferences.getInstance()).getKeys(),
        isNot(contains('clipback.account_deletion_cleanup.v1')),
      );
      SharedPreferences.setMockInitialValues({
        'clipback.account_deletion_cleanup.v1':
            '[{"environment":"env","user_id":"7","remaining":[]},5,null]',
      });
      expect(await PreferencesAccountDeletionCleanupStorage().read(), isEmpty);
    },
  );

  group('session repository', () {
    late _SessionStorage storage;
    late _Social social;
    late ClipbackApi api;
    late RemoteSessionRepository repository;
    final cleared = <String>[];
    setUp(() {
      cleared.clear();
      storage = _SessionStorage();
      social = _Social();
      api = ClipbackApi(
        client: MockClient((_) async => http.Response('', 204)),
        onSessionChanged: (_) => repository.persistCurrentSession(),
      );
      repository = RemoteSessionRepository(
        api: api,
        storage: storage,
        socialAuth: social,
        clearSearchHistory: (environment, userId) async =>
            cleared.add('search $userId'),
        discardPendingShares: (userId) async => cleared.add('shares $userId'),
        deletionCleanupStorage: records,
      );
      api.restoreSession(_session);
    });
    tearDown(() => repository.dispose());

    test(
      'a stored session clear failure is retried before the next restore',
      () async {
        storage.failClear = true;
        await repository.clearAfterAccountDeletion(userId: 7);
        expect(api.hasSession, isFalse);
        expect(repository.pendingSessionClear, isFalse);
        expect(storage.stored, same(_session));
        expect(social.appleIds, [null]);
        expect(cleared, ['search 7', 'shares 7']);
        expect(_remaining(records), {AccountDeletionCleanupStep.storedLogin});

        storage.failClear = false;
        final next = RemoteSessionRepository(
          api: ClipbackApi(
            client: MockClient((_) async => http.Response('', 500)),
          ),
          storage: storage,
          socialAuth: social,
          deletionCleanupStorage: records,
        );
        addTearDown(next.dispose);
        await next.resumeAccountDeletionCleanup();
        expect(await next.restoreStoredSession(), isFalse);
        expect(records.saved, isEmpty);
        expect(social.appleIds, [null, null]);
        expect(social.signOuts, 1);
      },
    );

    test('only a Google account tries disconnect, once', () async {
      await repository.clearAfterAccountDeletion(
        userId: 7,
        provider: SocialLoginProvider.kakao,
      );
      expect(social.disconnects, 0);
      api.restoreSession(_session);
      await repository.clearAfterAccountDeletion(
        userId: 8,
        provider: SocialLoginProvider.google,
      );
      expect(social.disconnects, 1);
      expect(social.signOuts, 2);
    });

    test(
      'a newer login persisted in the same run is kept on next launch',
      () async {
        storage.failClear = true;
        await repository.clearAfterAccountDeletion(userId: 7);
        expect(_remaining(records), {AccountDeletionCleanupStep.storedLogin});
        api.restoreSession(_newLogin);
        await repository.persistCurrentSession();
        expect(records.saved, isEmpty);
        final next = RemoteSessionRepository(
          api: ClipbackApi(
            client: MockClient((_) async => http.Response('', 500)),
          ),
          storage: storage,
          socialAuth: social,
          deletionCleanupStorage: records,
        );
        addTearDown(next.dispose);
        await next.resumeAccountDeletionCleanup();
        expect(await next.restoreStoredSession(), isTrue);
        expect(storage.stored, same(_newLogin));
      },
    );
  });
}
