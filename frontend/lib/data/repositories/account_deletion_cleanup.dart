import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What a confirmed withdrawal (204) must remove from the device and retries
/// on the next launch until it succeeds (R2). One-time cleanup (original image
/// cache, social SDK sign-out, Google disconnect) is not recorded.
enum AccountDeletionCleanupStep { storedLogin, searchHistory, pendingShares }

class AccountDeletionCleanupRecord {
  const AccountDeletionCleanupRecord({
    required this.environment,
    required this.userId,
    required this.remaining,
  });

  final String environment;
  final int userId;
  final Set<AccountDeletionCleanupStep> remaining;

  AccountDeletionCleanupRecord without(
    Iterable<AccountDeletionCleanupStep> done,
  ) => AccountDeletionCleanupRecord(
    environment: environment,
    userId: userId,
    remaining: remaining.difference(done.toSet()),
  );

  Map<String, Object> toJson() => {
    'environment': environment,
    'user_id': userId,
    'remaining': [for (final step in remaining) step.name],
  };

  static AccountDeletionCleanupRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final environment = json['environment'], userId = json['user_id'];
    final remaining = json['remaining'];
    if (environment is! String || userId is! int || remaining is! List) {
      return null;
    }
    return AccountDeletionCleanupRecord(
      environment: environment,
      userId: userId,
      remaining: {
        for (final step in AccountDeletionCleanupStep.values)
          if (remaining.contains(step.name)) step,
      },
    );
  }
}

abstract interface class AccountDeletionCleanupStorage {
  Future<List<AccountDeletionCleanupRecord>> read();
  Future<void> write(List<AccountDeletionCleanupRecord> records);
}

class PreferencesAccountDeletionCleanupStorage
    implements AccountDeletionCleanupStorage {
  PreferencesAccountDeletionCleanupStorage({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static const _key = 'clipback.account_deletion_cleanup.v1';
  final Future<SharedPreferences> Function() _preferences;

  @override
  Future<List<AccountDeletionCleanupRecord>> read() async {
    final value = (await _preferences()).getString(_key);
    if (value == null) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded
        .map(AccountDeletionCleanupRecord.fromJson)
        .whereType<AccountDeletionCleanupRecord>()
        .toList();
  }

  @override
  Future<void> write(List<AccountDeletionCleanupRecord> records) async {
    final preferences = await _preferences();
    final saved = records.isEmpty
        ? await preferences.remove(_key)
        : await preferences.setString(
            _key,
            jsonEncode([for (final record in records) record.toJson()]),
          );
    if (!saved) throw StateError('Could not persist deletion cleanup');
  }
}

/// Runs and records the retried part of the device cleanup after withdrawal.
/// Every failure is swallowed: a 204 is never reported as a failed withdrawal.
class AccountDeletionCleanup {
  AccountDeletionCleanup({
    required this.environment,
    required this.clearStoredLogin,
    required this.clearSearchHistory,
    required this.discardPendingShares,
    AccountDeletionCleanupStorage? storage,
  }) : _storage = storage ?? PreferencesAccountDeletionCleanupStorage();

  final String environment;
  final Future<void> Function() clearStoredLogin;
  final Future<void> Function(String environment, int userId)
  clearSearchHistory;
  final Future<void> Function(int userId) discardPendingShares;
  final AccountDeletionCleanupStorage _storage;
  List<AccountDeletionCleanupRecord>? _records;

  /// After a 204: record first (R2 detail 1), then try every step once.
  Future<void> start(int userId) async {
    final records = await _load();
    records.add(
      AccountDeletionCleanupRecord(
        environment: environment,
        userId: userId,
        remaining: AccountDeletionCleanupStep.values.toSet(),
      ),
    );
    await _save();
    await _runAll();
  }

  /// Next launch, before the stored session is restored: silently retry.
  Future<void> resume() async {
    final records = await _load();
    if (records.isNotEmpty) await _runAll();
  }

  /// A newer login's session was written over the deleted account's one, so
  /// a later retry must not remove it.
  Future<void> storedLoginReplaced() async {
    final records = _records;
    if (records == null ||
        !records.any(
          (r) => r.remaining.contains(AccountDeletionCleanupStep.storedLogin),
        )) {
      return;
    }
    _replace((r) => r.without(const [AccountDeletionCleanupStep.storedLogin]));
    await _save();
  }

  Future<List<AccountDeletionCleanupRecord>> _load() async {
    if (_records == null) {
      try {
        _records = [...await _storage.read()];
      } catch (_) {
        // An unreadable record cannot block login; this run starts empty.
        _records = [];
      }
    }
    return _records!;
  }

  Future<void> _runAll() async {
    for (final record in List.of(_records!)) {
      final done = <AccountDeletionCleanupStep>[];
      for (final step in record.remaining) {
        try {
          await switch (step) {
            AccountDeletionCleanupStep.storedLogin => clearStoredLogin(),
            AccountDeletionCleanupStep.searchHistory => clearSearchHistory(
              record.environment,
              record.userId,
            ),
            AccountDeletionCleanupStep.pendingShares => discardPendingShares(
              record.userId,
            ),
          };
          done.add(step);
        } catch (_) {
          // Kept for the next launch.
        }
      }
      _replace((r) => identical(r, record) ? r.without(done) : r);
    }
    await _save();
  }

  void _replace(
    AccountDeletionCleanupRecord Function(AccountDeletionCleanupRecord) update,
  ) {
    _records = [
      for (final record in _records!)
        if (update(record) case final next when next.remaining.isNotEmpty) next,
    ];
  }

  Future<void> _save() async {
    try {
      await _storage.write(List.of(_records!));
    } catch (_) {
      // R2 detail 5: the remaining risk is accepted; this run keeps trying.
    }
  }
}
