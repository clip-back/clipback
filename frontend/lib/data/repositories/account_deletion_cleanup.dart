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
    this.logins = const {},
    this.loginsComplete = false,
  });

  final String environment;
  final int userId;
  final Set<AccountDeletionCleanupStep> remaining;

  /// Fingerprints of the sessions the device could hold at the withdrawal.
  /// The stored login is cleared only while it is one of these, so a newer
  /// login is never removed.
  final Set<String> logins;

  /// Whether [logins] has every such session. Only then is a stored session
  /// missing from it a newer login; otherwise it is unknown and kept.
  final bool loginsComplete;

  AccountDeletionCleanupRecord without(
    Iterable<AccountDeletionCleanupStep> done,
  ) => AccountDeletionCleanupRecord(
    environment: environment,
    userId: userId,
    remaining: remaining.difference(done.toSet()),
    logins: logins,
    loginsComplete: loginsComplete,
  );

  Map<String, Object> toJson() => {
    'environment': environment,
    'user_id': userId,
    'remaining': [for (final step in remaining) step.name],
    'logins': [...logins],
    'logins_complete': loginsComplete,
  };

  static AccountDeletionCleanupRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final environment = json['environment'], userId = json['user_id'];
    final remaining = json['remaining'], logins = json['logins'];
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
      logins: {if (logins is List) ...logins.whereType<String>()},
      loginsComplete: json['logins_complete'] == true,
    );
  }
}

/// One stored record per deleted account, so writing one never replaces
/// another that could not be read (review P2).
abstract interface class AccountDeletionCleanupStorage {
  Future<List<AccountDeletionCleanupRecord>> read();

  /// Saves [record]; a record with nothing remaining is removed.
  Future<void> write(AccountDeletionCleanupRecord record);
}

class PreferencesAccountDeletionCleanupStorage
    implements AccountDeletionCleanupStorage {
  PreferencesAccountDeletionCleanupStorage({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static const _prefix = 'clipback.account_deletion_cleanup.v1.';
  final Future<SharedPreferences> Function() _preferences;
  String _key(AccountDeletionCleanupRecord r) =>
      '$_prefix${Uri.encodeComponent(r.environment)}.${r.userId}';

  @override
  Future<List<AccountDeletionCleanupRecord>> read() async {
    final preferences = await _preferences();
    final records = <AccountDeletionCleanupRecord>[];
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final value = preferences.get(key);
      Object? json;
      try {
        json = value is String ? jsonDecode(value) : null;
      } on FormatException {
        json = null;
      }
      // A malformed value is ignored as before; it never blocks login.
      final record = AccountDeletionCleanupRecord.fromJson(json);
      if (record != null) records.add(record);
    }
    return records;
  }

  @override
  Future<void> write(AccountDeletionCleanupRecord record) async {
    final preferences = await _preferences();
    final saved = record.remaining.isEmpty
        ? await preferences.remove(_key(record))
        : await preferences.setString(
            _key(record),
            jsonEncode(record.toJson()),
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
  final Future<void> Function(Set<String> deletedLogins, bool complete)
  clearStoredLogin;
  final Future<void> Function(String environment, int userId)
  clearSearchHistory;
  final Future<void> Function(int userId) discardPendingShares;
  final AccountDeletionCleanupStorage _storage;

  /// After a 204: record first (R2 detail 1), then try every step once. Other
  /// accounts' records left from earlier runs are retried too when readable.
  Future<void> start(
    int userId, {
    required Set<String> logins,
    bool loginsComplete = false,
  }) async {
    final record = AccountDeletionCleanupRecord(
      environment: environment,
      userId: userId,
      remaining: AccountDeletionCleanupStep.values.toSet(),
      logins: logins,
      loginsComplete: loginsComplete,
    );
    await _save(record);
    final others = await _read() ?? const <AccountDeletionCleanupRecord>[];
    await _run(record);
    for (final other in others) {
      if (other.environment != environment || other.userId != userId) {
        await _run(other);
      }
    }
  }

  /// Next launch, before the stored session is restored: silently retry.
  Future<void> resume() async {
    for (final record in await _read() ?? const []) {
      await _run(record);
    }
  }

  Future<List<AccountDeletionCleanupRecord>?> _read() async {
    try {
      return await _storage.read();
    } catch (_) {
      // Unknown, not empty: nothing is retried or overwritten from it.
      return null;
    }
  }

  // Each step is tried once; only failed steps stay in this record.
  Future<void> _run(AccountDeletionCleanupRecord record) async {
    final done = <AccountDeletionCleanupStep>[];
    for (final step in record.remaining) {
      try {
        await switch (step) {
          AccountDeletionCleanupStep.storedLogin => clearStoredLogin(
            record.logins,
            record.loginsComplete,
          ),
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
    await _save(record.without(done));
  }

  Future<void> _save(AccountDeletionCleanupRecord record) async {
    try {
      await _storage.write(record);
    } catch (_) {
      // R2 detail 5: the remaining risk is accepted.
    }
  }
}
