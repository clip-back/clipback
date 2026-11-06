// #257: the "cleanup pending" record after a withdrawal (R2 details 1–5).

import 'dart:async';

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
  Future<void> write(AccountDeletionCleanupRecord record) async {
    writes++;
    if (failWrite) throw StateError('write');
    saved = [
      for (final r in saved)
        if (r.environment != record.environment || r.userId != record.userId) r,
      if (record.remaining.isNotEmpty) record,
    ];
  }
}

class _Steps {
  final calls = <String>[];
  final failing = <String>{};
  final logins = <Set<String>>[];
  Future<void> run(String name) async {
    calls.add(name);
    if (failing.contains(name)) throw StateError(name);
  }

  AccountDeletionCleanup cleanup(_Records records) => AccountDeletionCleanup(
    environment: 'env',
    storage: records,
    clearStoredLogin: (deleted) {
      logins.add(deleted);
      return run('login');
    },
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
  Completer<void>? writeStarted, writeGate;
  @override
  Future<ApiSession?> read() async => stored;
  @override
  Future<void> write(ApiSession session) async {
    writeStarted?.complete();
    await writeGate?.future;
    stored = session;
  }

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
    await steps.cleanup(records).start(7, logins: const {'deleted'});
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
    await steps.cleanup(records).start(7, logins: const {'deleted'});
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
      await steps.cleanup(records).start(7, logins: const {'deleted'});
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
      await steps.cleanup(records).start(7, logins: const {'deleted'});
      expect(steps.calls, [
        'login',
        'search env 7',
        'shares 7',
        'search old 3',
      ]);
      expect(_remaining(records), {AccountDeletionCleanupStep.pendingShares});
      expect(records.saved.single.userId, 7);
    },
  );

  test('the stored login step gets the deleted logins on every run', () async {
    steps.failing.addAll(['login', 'shares 7']);
    await steps.cleanup(records).start(7, logins: const {'deleted'});
    expect(records.saved.single.logins, {'deleted'});
    steps.calls.clear();
    steps.failing.clear();
    await steps.cleanup(records).resume();
    expect(steps.calls, ['login', 'shares 7']);
    expect(steps.logins, [
      {'deleted'},
      {'deleted'},
    ]);
    expect(records.saved, isEmpty);
  });

  test(
    'preferences keep the record across launches and drop it when done',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PreferencesAccountDeletionCleanupStorage();
      final record = AccountDeletionCleanupRecord(
        environment: 'env',
        userId: 7,
        remaining: {AccountDeletionCleanupStep.storedLogin},
        logins: {'deleted-login'},
      );
      final other = AccountDeletionCleanupRecord(
        environment: 'env',
        userId: 8,
        remaining: {AccountDeletionCleanupStep.searchHistory},
      );
      await storage.write(record);
      await storage.write(other);
      final read = await PreferencesAccountDeletionCleanupStorage().read();
      expect([
        for (final r in read) r.toJson(),
      ], unorderedEquals([record.toJson(), other.toJson()]));
      await storage.write(record.without(record.remaining));
      expect((await SharedPreferences.getInstance()).getKeys(), {
        'clipback.account_deletion_cleanup.v1.env.8',
      });
      // Malformed values are ignored, as before, and never throw.
      SharedPreferences.setMockInitialValues({
        'clipback.account_deletion_cleanup.v1.env.7':
            '{"environment":"env","user_id":"7","remaining":[]}',
        'clipback.account_deletion_cleanup.v1.env.9': '{not json',
        'clipback.account_deletion_cleanup.v1.env.10': 5,
        'clipback.account_deletion_cleanup.v1.env.11': '[1]',
      });
      expect(await PreferencesAccountDeletionCleanupStorage().read(), isEmpty);
    },
  );

  test('a deletion whose record read fails keeps the earlier record', () async {
    records.saved = [
      AccountDeletionCleanupRecord(
        environment: 'old',
        userId: 3,
        remaining: {AccountDeletionCleanupStep.searchHistory},
      ),
    ];
    records.failRead = true;
    steps.failing.add('shares 7');
    await steps.cleanup(records).start(7, logins: const {'deleted'});
    expect(steps.calls, ['login', 'search env 7', 'shares 7']);
    records.failRead = false;
    expect(
      {for (final r in records.saved) r.userId: r.remaining},
      {
        3: {AccountDeletionCleanupStep.searchHistory},
        7: {AccountDeletionCleanupStep.pendingShares},
      },
    );
    steps
      ..calls.clear()
      ..failing.clear();
    await steps.cleanup(records).resume();
    expect(steps.calls, unorderedEquals(['search old 3', 'shares 7']));
    expect(records.saved, isEmpty);
  });

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

    // Review P1: the deleted account's own write, started before the 204,
    // finishes after the record is saved and before the stored clear fails.
    test(
      'an old session write finishing after 204 keeps the stored login cleanup',
      () async {
        storage
          ..failClear = true
          ..writeStarted = Completer()
          ..writeGate = Completer();
        final write = repository.persistCurrentSession();
        await storage.writeStarted!.future;
        final deletion = repository.clearAfterAccountDeletion(userId: 7);
        for (var i = 0; i < 20 && records.saved.isEmpty; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(records.saved, isNotEmpty);
        storage.writeGate!.complete();
        await write;
        await deletion;
        expect(storage.stored, same(_session));
        expect(_remaining(records), {AccountDeletionCleanupStep.storedLogin});

        storage
          ..failClear = false
          ..writeStarted = null
          ..writeGate = null;
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
      },
    );

    // Review P1: only a write of the session that is still current counts as
    // a newer login; a write that finishes after memory moved on does not.
    test(
      'a session write that is no longer current keeps the record',
      () async {
        records.saved = [
          AccountDeletionCleanupRecord(
            environment: api.baseUrl,
            userId: 7,
            remaining: {AccountDeletionCleanupStep.storedLogin},
          ),
        ];
        storage
          ..writeStarted = Completer()
          ..writeGate = Completer();
        final write = repository.persistCurrentSession();
        await storage.writeStarted!.future;
        api.clearSession();
        storage.writeGate!.complete();
        await write;
        expect(_remaining(records), {AccountDeletionCleanupStep.storedLogin});
      },
    );

    // Review P2: a launch whose record read fails, then a newer login.
    test(
      'a transient record read failure does not let an old cleanup remove a newer login',
      () async {
        records.saved = [
          AccountDeletionCleanupRecord(
            environment: api.baseUrl,
            userId: 7,
            remaining: {AccountDeletionCleanupStep.storedLogin},
          ),
        ];
        api.clearSession();
        records.failRead = true;
        await repository.resumeAccountDeletionCleanup();
        records.failRead = false;
        api.restoreSession(_newLogin);
        await repository.persistCurrentSession();
        expect(storage.stored, same(_newLogin));
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
        expect(social.appleIds, isEmpty);
      },
    );

    // The deleted account's stored session can differ from memory (an older
    // token after a failed write, or one still being written): both count.
    test(
      'a stored older token of the deleted account is still cleared',
      () async {
        const older = ApiSession(
          accessToken: 'older',
          refreshToken: 'older-refresh',
          expiresIn: 60,
          refreshExpiresIn: 600,
        );
        storage
          ..stored = older
          ..failClear = true;
        await repository.clearAfterAccountDeletion(userId: 7);
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
        expect(storage.stored, isNull);
        expect(records.saved, isEmpty);
      },
    );

    test('a session still being written at 204 is cleared later', () async {
      const refreshed = ApiSession(
        accessToken: 'refreshed',
        refreshToken: 'refreshed-refresh',
        expiresIn: 60,
        refreshExpiresIn: 600,
      );
      storage
        ..stored = null
        ..failClear = true
        ..writeStarted = Completer()
        ..writeGate = Completer();
      final write = repository.persistCurrentSession();
      await storage.writeStarted!.future;
      api.restoreSession(refreshed);
      final deletion = repository.clearAfterAccountDeletion(userId: 7);
      for (var i = 0; i < 20 && records.saved.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      storage.writeGate!.complete();
      await write;
      await deletion;
      expect(storage.stored, same(_session));
      storage
        ..failClear = false
        ..writeStarted = null
        ..writeGate = null;
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
      expect(storage.stored, isNull);
      expect(records.saved, isEmpty);
    });

    // Re-review P1: the record read fails at launch and again at the newer
    // login; the record is readable only on the launch after that.
    test(
      'a newer login survives when record reads fail at launch and at login',
      () async {
        records.saved = [
          AccountDeletionCleanupRecord(
            environment: api.baseUrl,
            userId: 7,
            remaining: {AccountDeletionCleanupStep.storedLogin},
          ),
        ];
        api.clearSession();
        records.failRead = true;
        await repository.resumeAccountDeletionCleanup();
        api.restoreSession(_newLogin);
        await repository.persistCurrentSession();
        expect(storage.stored, same(_newLogin));
        records.failRead = false;
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
        expect(social.appleIds, isEmpty);
      },
    );

    // Re-review C1 (repository level; the app blocks logins while auth work
    // runs): a newer login persisted while the deletion's cleanup is still
    // running must survive the next launch.
    test(
      'a newer login persisted while cleanup runs survives the next launch',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        final slow = RemoteSessionRepository(
          api: api,
          storage: storage..failClear = true,
          socialAuth: social,
          clearSearchHistory: (_, _) async {
            entered.complete();
            await release.future;
          },
          deletionCleanupStorage: records,
        );
        addTearDown(slow.dispose);
        final deletion = slow.clearAfterAccountDeletion(userId: 7);
        await entered.future;
        storage.failClear = false;
        api.restoreSession(_newLogin);
        await slow.persistCurrentSession();
        release.complete();
        await deletion;
        expect(storage.stored, same(_newLogin));
        social.appleIds.clear();
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
        expect(social.appleIds, isEmpty);
        expect(records.saved, isEmpty);
      },
    );
  });
}
