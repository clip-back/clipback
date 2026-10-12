import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../clipback_api.dart';
import '../../social_auth.dart';

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
  void retryPersistence();
}

class RemoteSessionRepository extends SessionRepository {
  RemoteSessionRepository({
    required ClipbackApi api,
    required ApiSessionStorage storage,
    required SocialAuth socialAuth,
  }) : _api = api,
       _storage = storage,
       _socialAuth = socialAuth;

  final ClipbackApi _api;
  final ApiSessionStorage _storage;
  final SocialAuth _socialAuth;
  final _invalidations = StreamController<SessionInvalidation>.broadcast(
    sync: true,
  );
  Future<void> _storageQueue = Future.value();
  Future<void>? _invalidationFuture;
  int _pendingStorageOperations = 0;
  ApiSession? _sessionNeedingPersistence;
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
    final stored = await _storage.read();
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

  @override
  void dispose() {
    _disposed = true;
    unawaited(_invalidations.close());
    super.dispose();
  }
}
