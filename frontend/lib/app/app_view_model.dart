import 'dart:async';

import 'package:flutter/foundation.dart';

import '../clipback_api.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/user_repository.dart';
import '../shared/contracts/app_route.dart';
import '../shared/contracts/ui_effect.dart';
import '../social_auth.dart';
import 'actions/account_initialization_action.dart';

class AppViewModel extends ChangeNotifier {
  AppViewModel({
    required SessionRepository session,
    required UserRepository users,
    required AccountInitializationAction initializeAccount,
    Future<void> Function()? beforeSessionChange,
  }) : _session = session,
       _users = users,
       _initializeAccount = initializeAccount,
       _beforeSessionChange = beforeSessionChange {
    _users.addListener(_onUserChanged);
    _invalidations = session.invalidations.listen(_onSessionInvalidation);
    _appleRevocations = session.appleCredentialRevocations.listen(
      (_) => unawaited(checkAppleCredential()),
      onError: (Object _) {
        // A device channel error is not proof of revoked credentials.
      },
    );
  }

  final SessionRepository _session;
  final UserRepository _users;
  final AccountInitializationAction _initializeAccount;
  final Future<void> Function()? _beforeSessionChange;
  late final StreamSubscription<SessionInvalidation> _invalidations;
  late final StreamSubscription<void> _appleRevocations;
  final List<UiEffect> _effects = [];
  Object? _initialization;
  int? _initializationGeneration;
  int? _initializationEpoch;
  Object? _initialHomeLoading;
  int? _initialHomeLoadingEpoch;
  int? _initialHomeLoadingGeneration;
  bool _firstAccountInitializationComplete = false;
  ApiUser? _authenticatedUser;
  bool _authBusy = false;
  bool _linkingGuest = false;
  bool _checkingAppleCredential = false;
  bool _isRestoringSession = false;
  bool _disposed = false;
  bool _started = false;
  int _authEpoch = 0;
  int _accountGeneration = 0;
  AppRoute? _postAuthRoute;
  AppRoute _route = AppRoute.home;
  AppRoute _previousRoute = AppRoute.home;
  AppRoute _searchReturnRoute = AppRoute.home;
  String? _apiConnectionError;

  AppRoute get route => _route;
  AppRoute get previousRoute => _previousRoute;
  AppRoute get searchReturnRoute => _searchReturnRoute;
  bool get authBusy => _authBusy;
  bool get linkingGuest => _linkingGuest;
  bool get isRestoringSession => _isRestoringSession;
  bool get showInitialHomeLoading =>
      !_disposed &&
      _initialHomeLoading != null &&
      _initialHomeLoadingEpoch == _authEpoch &&
      _initialHomeLoadingGeneration == _accountGeneration &&
      _session.hasSession &&
      !_session.pendingSessionClear &&
      _apiConnectionError == null;
  String? get apiConnectionError => _apiConnectionError;
  ApiUser? get authenticatedUser => _authenticatedUser;
  int get authEpoch => _authEpoch;
  int get accountGeneration => _accountGeneration;
  List<SocialLoginProvider> get supportedProviders =>
      _session.supportedProviders;

  List<UiEffect> drainEffects() {
    final pending = List<UiEffect>.of(_effects);
    _effects.clear();
    return pending;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _emit(UiEffect effect) {
    if (_disposed) return;
    _effects.add(effect);
    _notify();
  }

  void _showError(String message) => _emit(MessageEffect(message));

  void _setAuthBusy(bool busy) {
    _authBusy = busy;
    _session.setAuthenticationBusy(busy);
    _notify();
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(restoreSession());
  }

  Object? _beginInitialHomeLoading() {
    if (_firstAccountInitializationComplete ||
        _linkingGuest ||
        (_postAuthRoute ?? AppRoute.home) != AppRoute.home) {
      return null;
    }
    final owner = Object();
    _initialHomeLoading = owner;
    _initialHomeLoadingEpoch = _authEpoch;
    _initialHomeLoadingGeneration = _accountGeneration;
    _notify();
    return owner;
  }

  void _clearInitialHomeLoading() {
    _initialHomeLoading = null;
    _initialHomeLoadingEpoch = null;
    _initialHomeLoadingGeneration = null;
  }

  void _endInitialHomeLoading(Object? owner) {
    if (owner == null || !identical(_initialHomeLoading, owner)) return;
    _clearInitialHomeLoading();
  }

  void _resetAccount() {
    _accountGeneration++;
    _firstAccountInitializationComplete = false;
    _clearInitialHomeLoading();
    _initializeAccount.reset(_accountGeneration);
    _authenticatedUser = null;
  }

  void _onSessionInvalidation(SessionInvalidation event) {
    if (_disposed) return;
    switch (event) {
      case SessionInvalidation.started:
        _authEpoch++;
        _clearInitialHomeLoading();
        _setAuthBusy(false);
      case SessionInvalidation.completed:
        _showLoginChoice();
      case SessionInvalidation.failed:
        _apiConnectionError = '저장한 콘텐츠를 불러오지 못했어요.';
        _notify();
    }
  }

  void _showLoginChoice() {
    if (_disposed) return;
    _effects.add(const CloseTransientRoutesEffect());
    _authEpoch++;
    _resetAccount();
    _linkingGuest = false;
    _postAuthRoute = null;
    _previousRoute = AppRoute.login;
    _route = AppRoute.login;
    _notify();
  }

  Future<void> restoreSession() async {
    if (_disposed || _isRestoringSession || _authBusy) return;
    _isRestoringSession = true;
    Object? initialHomeLoading;
    _apiConnectionError = null;
    _notify();
    try {
      if (_session.pendingSessionClear) {
        await _beforeSessionChange?.call();
        await _session.retryPendingClear();
        if (!_disposed) _showLoginChoice();
        return;
      }
      if (!_session.hasSession) {
        final restored = await _session.restoreStoredSession();
        if (_disposed) return;
        if (restored) _resetAccount();
      }
      if (!_session.hasSession) {
        await _beforeSessionChange?.call();
        if (_disposed) return;
        _showLoginChoice();
        return;
      }
      try {
        final epoch = _authEpoch;
        final generation = _accountGeneration;
        initialHomeLoading = _beginInitialHomeLoading();
        await _loadRemoteData();
        if (_disposed ||
            epoch != _authEpoch ||
            generation != _accountGeneration ||
            !_session.hasSession) {
          return;
        }
        _route = _postAuthRoute ?? AppRoute.home;
        _postAuthRoute = null;
        await checkAppleCredential();
        if (!_disposed &&
            epoch == _authEpoch &&
            generation == _accountGeneration &&
            _session.hasSession &&
            !_session.pendingSessionClear) {
          _firstAccountInitializationComplete = true;
        }
      } on ClipbackApiException catch (error) {
        if (error.statusCode != 401 || _session.pendingSessionClear) rethrow;
        if (_session.hasSession) await _session.invalidate();
      }
    } catch (_) {
      if (!_disposed &&
          (_session.hasSession ||
              _session.pendingSessionClear ||
              _route != AppRoute.login)) {
        _apiConnectionError = '저장한 콘텐츠를 불러오지 못했어요.';
        _notify();
      }
    } finally {
      _endInitialHomeLoading(initialHomeLoading);
      if (!_disposed) {
        _isRestoringSession = false;
        _notify();
      }
    }
  }

  Future<void> _loadRemoteData() async {
    final epoch = _authEpoch;
    final generation = _accountGeneration;
    final initialization = Object();
    _initialization = initialization;
    _initializationGeneration = generation;
    _initializationEpoch = epoch;
    try {
      await _initializeAccount.load();
      if (_disposed ||
          epoch != _authEpoch ||
          generation != _accountGeneration) {
        return;
      }
      _authenticatedUser = _users.user;
      _apiConnectionError = null;
      _notify();
    } finally {
      if (identical(_initialization, initialization)) {
        _initialization = null;
        _initializationGeneration = null;
        _initializationEpoch = null;
      }
    }
  }

  void _onUserChanged() {
    if (_disposed ||
        _initialization == null ||
        _initializationEpoch != _authEpoch ||
        _initializationGeneration != _accountGeneration ||
        _users.accountVersion != _accountGeneration ||
        _users.user == null) {
      return;
    }
    // Bootstrap identity becomes available before the subsequent stats request.
    // Ordinary content-triggered stats refreshes do not replace auth identity.
    _authenticatedUser = _users.user;
    _notify();
  }

  Future<void> continueAsGuest() async {
    if (_disposed || _authBusy || _isRestoringSession) return;
    final epoch = ++_authEpoch;
    _setAuthBusy(true);
    try {
      if (!_session.hasSession) {
        await _beforeSessionChange?.call();
        if (_disposed || epoch != _authEpoch) return;
        await _session.createGuestSession();
        if (_disposed || epoch != _authEpoch) return;
        _resetAccount();
        _postAuthRoute = AppRoute.onboarding;
      } else {
        _postAuthRoute = AppRoute.home;
      }
      await _reloadAfterAuthentication();
    } on ClipbackApiException catch (error) {
      if (!_disposed && epoch == _authEpoch) _showError(error.message);
    } catch (_) {
      if (!_disposed && epoch == _authEpoch) {
        _showError('서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (!_disposed && epoch == _authEpoch) _setAuthBusy(false);
    }
  }

  Future<void> _reloadAfterAuthentication() async {
    final epoch = _authEpoch;
    final generation = _accountGeneration;
    bool current() =>
        !_disposed && epoch == _authEpoch && generation == _accountGeneration;
    final initialHomeLoading = _beginInitialHomeLoading();
    try {
      await _loadRemoteData();
      if (!current() || !_session.hasSession) return;
      _firstAccountInitializationComplete = true;
      _route = _postAuthRoute ?? AppRoute.home;
      _postAuthRoute = null;
      _linkingGuest = false;
      _notify();
    } catch (_) {
      // Issuance succeeded: retry data loading without repeating authentication.
      if (current() && (_session.hasSession || _session.pendingSessionClear)) {
        _apiConnectionError = '저장한 콘텐츠를 불러오지 못했어요.';
        _notify();
      }
    } finally {
      _endInitialHomeLoading(initialHomeLoading);
    }
  }

  Future<void> authenticateSocial(
    SocialLoginProvider provider, {
    bool switchAccount = false,
  }) async {
    if (_disposed ||
        _authBusy ||
        _isRestoringSession ||
        !supportedProviders.contains(provider)) {
      return;
    }
    final upgrade = _linkingGuest && !switchAccount;
    if (upgrade && _authenticatedUser?.isGuest != true) return;
    final epoch = ++_authEpoch;
    final generation = _accountGeneration;
    bool current() =>
        !_disposed && epoch == _authEpoch && generation == _accountGeneration;
    _setAuthBusy(true);
    bool conflict = false;
    try {
      await _beforeSessionChange?.call();
      if (!current()) return;
      final result = await _session.authenticateSocial(
        provider,
        upgrade: upgrade,
        isCurrent: current,
      );
      if (!current() || result == null) return;
      _resetAccount();
      _postAuthRoute = result.session.isNewUser
          ? AppRoute.onboarding
          : AppRoute.home;
      try {
        await _session.rememberAppleUserId(
          provider == SocialLoginProvider.apple
              ? result.credential.providerUserId
              : null,
        );
      } catch (_) {
        _showError('기기의 계정 확인 정보를 저장하지 못했어요. 로그인은 완료됐어요.');
      }
      if (_disposed || epoch != _authEpoch) return;
      await _reloadAfterAuthentication();
    } on SocialAuthException catch (error) {
      if (!_disposed && epoch == _authEpoch) _showError(error.message);
    } on ClipbackApiException catch (error) {
      if (!_disposed && epoch == _authEpoch) {
        if (upgrade && error.statusCode == 401) {
          // Check guest validity separately; never replay a one-use Apple code.
          try {
            await _users.verifySession();
          } catch (sessionError) {
            if (!_disposed && epoch == _authEpoch) {
              _showError(
                sessionError is ClipbackApiException
                    ? sessionError.message
                    : '계정 정보를 확인하지 못했어요. 다시 시도해 주세요.',
              );
            }
            return;
          }
          if (_disposed || epoch != _authEpoch) return;
        }
        conflict = upgrade && error.statusCode == 409;
        if (!conflict) _showError(error.message);
      }
    } catch (_) {
      if (!_disposed && epoch == _authEpoch) {
        _showError('로그인하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (!_disposed && epoch == _authEpoch) _setAuthBusy(false);
    }
    if (conflict && !_disposed && epoch == _authEpoch) {
      _emit(ConfirmAccountSwitchEffect(epoch, provider));
    }
  }

  Future<void> confirmAccountSwitch(
    int epoch,
    SocialLoginProvider provider,
  ) async {
    if (_disposed || epoch != _authEpoch) return;
    await authenticateSocial(provider, switchAccount: true);
  }

  Future<void> openAccountLogin() async {
    if (_disposed || _authBusy) return;
    final epoch = _authEpoch;
    final generation = _accountGeneration;
    bool current() =>
        !_disposed && epoch == _authEpoch && generation == _accountGeneration;
    if (_authenticatedUser == null) {
      try {
        final user = await _users.loadMe();
        if (!current()) return;
        _authenticatedUser = user;
      } catch (_) {
        if (current()) _showError('계정 정보를 불러오지 못했어요. 다시 시도해 주세요.');
        return;
      }
    }
    if (_authenticatedUser?.isGuest != true) return;
    _linkingGuest = true;
    _route = AppRoute.login;
    _notify();
  }

  Future<void> logout() async {
    if (_disposed || _authBusy) return;
    final epoch = ++_authEpoch;
    final providers = _authenticatedUser?.linkedProviders ?? const <String>[];
    final provider = SocialLoginProvider.values
        .where((value) => providers.contains(value.name))
        .firstOrNull;
    _setAuthBusy(true);
    try {
      await _beforeSessionChange?.call();
      if (_disposed || epoch != _authEpoch) return;
      final loggedOut = await _session.logout(
        provider: provider,
        isCurrent: () => !_disposed && epoch == _authEpoch,
      );
      if (loggedOut) _showLoginChoice();
    } on ClipbackApiException catch (error) {
      if (!_disposed) _showError(error.message);
    } catch (_) {
      if (!_disposed) {
        if (_session.pendingSessionClear) {
          _apiConnectionError = '로그아웃 상태를 저장하지 못했어요. 다시 시도해 주세요.';
          _notify();
        } else {
          _showError('로그아웃하지 못했어요. 다시 시도해 주세요.');
        }
      }
    } finally {
      if (!_disposed) _setAuthBusy(false);
    }
  }

  Future<void> checkAppleCredential() async {
    if (_disposed ||
        _checkingAppleCredential ||
        _authBusy ||
        !(_authenticatedUser?.linkedProviders.contains('apple') ?? false)) {
      return;
    }
    final epoch = _authEpoch;
    _checkingAppleCredential = true;
    try {
      final state = await _session.checkAppleCredential();
      if (_disposed || epoch != _authEpoch) return;
      if (state == AppleCredentialStatus.revoked ||
          state == AppleCredentialStatus.notFound) {
        _setAuthBusy(true);
        try {
          await _beforeSessionChange?.call();
        } catch (_) {
          _showError('공유 인증 차단을 다시 확인해야 해요. 기기에서 철회한 로그인은 종료합니다.');
        }
        if (_disposed || epoch != _authEpoch) return;
        await _session.revokeAppleSession();
        if (!_disposed && epoch == _authEpoch) await _session.invalidate();
      }
    } catch (_) {
      // An unavailable provider check cannot invalidate a server session.
    } finally {
      _checkingAppleCredential = false;
      if (!_disposed && epoch == _authEpoch) _setAuthBusy(false);
    }
  }

  void finishSplash() {
    if (_route == AppRoute.splash) go(AppRoute.home);
  }

  void go(AppRoute route) {
    if (_disposed) return;
    _route = route;
    if (route == AppRoute.home ||
        route == AppRoute.archive ||
        route == AppRoute.bookmark ||
        route == AppRoute.my) {
      _previousRoute = route;
    }
    _notify();
  }

  void selectRootTab(AppRoute route) => go(route);

  void openSearch() {
    if (_disposed) return;
    _searchReturnRoute = _route;
    _route = AppRoute.search;
    _notify();
  }

  void openArchive() => go(AppRoute.archive);

  void openDetail() {
    if (_disposed) return;
    if (_route != AppRoute.detail) _previousRoute = _route;
    _route = AppRoute.detail;
    _notify();
  }

  void backFromDetail() {
    if (_disposed) return;
    _route = _previousRoute;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _clearInitialHomeLoading();
    _authEpoch++;
    _effects.clear();
    _users.removeListener(_onUserChanged);
    unawaited(_invalidations.cancel());
    unawaited(_appleRevocations.cancel());
    super.dispose();
  }
}
