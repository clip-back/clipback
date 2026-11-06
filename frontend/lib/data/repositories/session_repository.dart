import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../clipback_api.dart';
import '../../social_auth.dart';
import 'account_deletion_cleanup.dart';

enum SessionInvalidation { started, completed, failed }

class SocialSessionResult {
  const SocialSessionResult(this.session, this.credential);

  final ApiSocialSession session;
  final SocialCredential credential;
}

abstract class SessionRepository extends ChangeNotifier {
  bool get hasSession;
  bool get pendingSessionClear;
  bool get storageBusy;
  bool get needsPersistence;
  bool get authenticationBusy;
  void setAuthenticationBusy(bool busy);
  List<SocialLoginProvider> get supportedProviders;
  Stream<SessionInvalidation> get invalidations;
  Stream<void> get appleCredentialRevocations;

  Future<bool> restoreStoredSession();
  Future<void> retryPendingClear();
  Future<void> persistCurrentSession();
  Future<void> invalidate();
  Future<void> createGuestSession();
  Future<SocialSessionResult?> authenticateSocial(
    SocialLoginProvider provider, {
    required bool upgrade,
    required bool Function() isCurrent,
  });
  Future<void> rememberAppleUserId(String? userId);
  Future<AppleCredentialStatus> checkAppleCredential();
  Future<void> revokeAppleSession();
  Future<bool> logout({
    SocialLoginProvider? provider,
    required bool Function() isCurrent,
  });
  Future<void> clearAfterAccountDeletion({
    required int userId,
    SocialLoginProvider? provider,
  });
  Future<void> resumeAccountDeletionCleanup();
  void retryPersistence();
}

class RemoteSessionRepository extends SessionRepository {
  RemoteSessionRepository({
    required ClipbackApi api,
    required ApiSessionStorage storage,
    required SocialAuth socialAuth,
    Future<void> Function(String environment, int userId)? clearSearchHistory,
    Future<void> Function(int userId)? discardPendingShares,
    AccountDeletionCleanupStorage? deletionCleanupStorage,
  }) : _api = api,
       _storage = storage,
       _socialAuth = socialAuth {
    _deletionCleanup = AccountDeletionCleanup(
      environment: api.baseUrl,
      clearStoredLogin: _clearDeletedLogin,
      clearSearchHistory: clearSearchHistory ?? (_, _) async {},
      discardPendingShares: discardPendingShares ?? (_) async {},
      storage: deletionCleanupStorage,
    );
  }

  final ClipbackApi _api;
  final ApiSessionStorage _storage;
  final SocialAuth _socialAuth;
  late final AccountDeletionCleanup _deletionCleanup;
  final _invalidations = StreamController<SessionInvalidation>.broadcast(
    sync: true,
  );
  Future<void> _storageQueue = Future.value();
  Future<void>? _invalidationFuture;
  int _pendingStorageOperations = 0;
  ApiSession? _sessionNeedingPersistence;
  // What the device's stored session can be (#257): every session read from
  // it or about to be written to it in this run. It is complete once a read
  // succeeded before any write or clear, while shared_preferences' cache still
  // matched the device; later reads may show the cache instead.
  final _storedLogins = <String>{};
  bool _storedLoginsComplete = false;
  int _storageChanges = 0; // writes and clears started in this run
  bool _deletedThisRun = false;
  bool _pendingSessionClear = false;
  bool _authenticationBusy = false;
  bool _disposed = false;

  @override
  bool get hasSession => _api.hasSession;
  @override
  bool get pendingSessionClear => _pendingSessionClear;
  @override
  bool get authenticationBusy => _authenticationBusy;
  @override
  void setAuthenticationBusy(bool busy) {
    if (_authenticationBusy == busy) return;
    _authenticationBusy = busy;
    _notify();
  }

  @override
  bool get storageBusy => _pendingStorageOperations > 0;
  @override
  bool get needsPersistence =>
      _sessionNeedingPersistence != null &&
      identical(_api.session, _sessionNeedingPersistence);
  @override
  List<SocialLoginProvider> get supportedProviders =>
      _socialAuth.supportedProviders;
  @override
  Stream<SessionInvalidation> get invalidations => _invalidations.stream;
  @override
  Stream<void> get appleCredentialRevocations =>
      _socialAuth.appleCredentialRevocations;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _enqueueStorage(Future<void> Function() operation) {
    _pendingStorageOperations++;
    _notify();
    final result = _storageQueue.then((_) => operation());
    // Storage failures reach their caller without blocking later storage work.
    _storageQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result.whenComplete(() {
      _pendingStorageOperations--;
      _notify();
    });
  }

  @override
  Future<void> persistCurrentSession() => _enqueueStorage(() async {
    // A queued retry must write the latest tokens, not its enqueue-time snapshot.
    final session = _api.session;
    if (session == null) return;
    _storageChanges++;
    _storedLogins.add(_loginId(session));
    try {
      await _storage.write(session);
      if (identical(_api.session, session)) _sessionNeedingPersistence = null;
    } catch (_) {
      if (identical(_api.session, session)) {
        _sessionNeedingPersistence = session;
      }
      // Issued tokens remain usable even if device persistence failed.
    }
    _notify();
  });

  Future<void> _clearStoredSession({bool afterLogout = false}) =>
      _enqueueStorage(() async {
        // A newer login owns its stored session while an earlier logout waits.
        if (afterLogout && _api.hasSession) return;
        _storageChanges++;
        try {
          await _storage.clear();
          _sessionNeedingPersistence = null;
        } finally {
          _notify();
        }
      });

  @override
  void retryPersistence() {
    if (storageBusy || !hasSession || _disposed) return;
    unawaited(persistCurrentSession());
  }

  @override
  Future<bool> restoreStoredSession() async {
    if (hasSession) return false;
    final stored = await _readStored();
    if (stored == null || _disposed) return false;
    _api.restoreSession(stored);
    _notify();
    return true;
  }

  @override
  Future<void> retryPendingClear() async {
    await _clearStoredSession();
    _api.clearSession();
    _pendingSessionClear = false;
    _notify();
  }

  @override
  Future<void> invalidate() {
    final pending = _invalidationFuture;
    if (pending != null) return pending;
    late final Future<void> operation;
    operation = _clearInvalidSession().whenComplete(() {
      if (identical(_invalidationFuture, operation)) _invalidationFuture = null;
    });
    _invalidationFuture = operation;
    return operation;
  }

  Future<void> _clearInvalidSession() async {
    _pendingSessionClear = true;
    _emitInvalidation(SessionInvalidation.started);
    try {
      await retryPendingClear();
      _emitInvalidation(SessionInvalidation.completed);
    } catch (_) {
      _emitInvalidation(SessionInvalidation.failed);
    }
  }

  void _emitInvalidation(SessionInvalidation event) {
    if (!_disposed) _invalidations.add(event);
    _notify();
  }

  @override
  Future<void> createGuestSession() async {
    await _api.createGuestSession();
  }

  @override
  Future<SocialSessionResult?> authenticateSocial(
    SocialLoginProvider provider, {
    required bool upgrade,
    required bool Function() isCurrent,
  }) async {
    final challenge = provider == SocialLoginProvider.apple
        ? await _api.createAppleChallenge(upgrade: upgrade)
        : null;
    if (_disposed || !isCurrent()) return null;
    final credential = await _socialAuth.authenticate(
      provider,
      nonce: challenge?.nonce,
    );
    if (_disposed || !isCurrent() || credential == null) return null;
    final session = upgrade
        ? await _api.upgradeGuestWithSocial(
            provider: provider.name,
            token: credential.token,
            authorizationCode: credential.authorizationCode,
            challengeId: challenge?.id,
            displayName: credential.displayName,
          )
        : await _api.socialLogin(
            provider: provider.name,
            token: credential.token,
            authorizationCode: credential.authorizationCode,
            challengeId: challenge?.id,
            displayName: credential.displayName,
          );
    if (_disposed || !isCurrent()) return null;
    return SocialSessionResult(session, credential);
  }

  @override
  Future<void> rememberAppleUserId(String? userId) =>
      _socialAuth.rememberAppleUserId(userId);

  @override
  Future<AppleCredentialStatus> checkAppleCredential() =>
      _socialAuth.appleCredentialState();

  @override
  Future<void> revokeAppleSession() async {
    try {
      await _api.logout();
    } catch (_) {
      // Confirmed device revocation blocks access even when offline.
    }
  }

  @override
  Future<bool> logout({
    SocialLoginProvider? provider,
    required bool Function() isCurrent,
  }) async {
    // Never enqueue the entire logout: refresh persistence may be awaited by it.
    await _api.logout();
    _pendingSessionClear = true;
    _notify();
    await _clearStoredSession(afterLogout: true);
    if (_disposed || !isCurrent() || hasSession) return false;
    _pendingSessionClear = false;
    _notify();
    try {
      await _socialAuth.signOut(provider);
    } catch (_) {
      // Server logout is already complete; SDK sign-out is best effort.
    }
    return !_disposed && isCurrent();
  }

  // The server already deleted the account, so no server logout is sent.
  // Retried cleanup is recorded first; the rest is tried once (R2).
  @override
  Future<void> clearAfterAccountDeletion({
    required int userId,
    SocialLoginProvider? provider,
  }) async {
    final deleted = _api.session;
    _api.clearSession();
    _deletedThisRun = true;
    // Every session the device could hold now, and the one in memory.
    final logins = {..._storedLogins, if (deleted != null) _loginId(deleted)};
    final changes = _storageChanges;
    _pendingSessionClear = true;
    _notify();
    try {
      try {
        final stored = await _readStored();
        // Unless a newer write started meanwhile, this is from before too.
        if (stored != null && _storageChanges == changes) {
          logins.add(_loginId(stored));
        }
      } catch (_) {
        // Unread now, the logins are still complete if this run knew.
      }
      await _deletionCleanup.start(
        userId,
        logins: logins,
        loginsComplete: _storedLoginsComplete,
      );
    } finally {
      _pendingSessionClear = false;
      _notify();
    }
    if (provider == SocialLoginProvider.google) {
      try {
        await _socialAuth.disconnectGoogle().timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {
        // Disconnect is attempted once and never delays J06 past 5s (D6).
      }
    }
    // The stored Apple user ID is left to the stored-login cleanup above.
    // SDK sign-out is best effort, as after logout, and like the disconnect it
    // never holds J06: an SDK still initializing or signing out finishes on
    // its own after the 204 (#250 final review P1).
    unawaited(_socialAuth.signOutSdks(provider).catchError((Object _) {}));
  }

  @override
  Future<void> resumeAccountDeletionCleanup() => _deletionCleanup.resume();

  static String _loginId(ApiSession session) =>
      sha256.convert(utf8.encode(session.refreshToken)).toString();

  Future<ApiSession?> _readStored() async {
    final stored = await _storage.read();
    if (_storageChanges == 0) _storedLoginsComplete = true;
    if (stored != null) _storedLogins.add(_loginId(stored));
    return stored;
  }

  // Clears the stored login only with evidence that it predates the
  // withdrawal: it is one of [deletedLogins], or this run withdrew and has
  // written nothing, so the device still holds what it had at launch. An
  // unread session is never cleared, and neither is the Apple user ID. A
  // session missing from a complete list is a newer login: both stay and the
  // step ends; missing from an incomplete one, it is unknown and stays failed.
  // The decision is made from the disk each time, so no record update is
  // needed when a newer login is saved. The session and Apple user ID are
  // each tried.
  Future<void> _clearDeletedLogin(
    Set<String> deletedLogins,
    bool complete,
  ) async {
    bool? noNewerLogin; // null: the stored session could not be read
    Object? failure;
    try {
      await _enqueueStorage(() async {
        final stored = await _readStored();
        noNewerLogin =
            stored == null ||
            deletedLogins.contains(_loginId(stored)) ||
            (_deletedThisRun && _storageChanges == 0);
        if (stored == null || !noNewerLogin!) return;
        _storageChanges++;
        await _storage.clear();
        _sessionNeedingPersistence = null;
      });
    } catch (error) {
      failure = error;
    }
    if (noNewerLogin == null) throw failure!;
    if (!noNewerLogin!) {
      if (complete) return;
      throw StateError('The stored login could not be identified');
    }
    try {
      await _socialAuth.rememberAppleUserId(null);
    } catch (error) {
      failure = error;
    }
    if (failure != null) throw failure;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_invalidations.close());
    super.dispose();
  }
}
