import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/logout_confirmation_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/notice_list_screen.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/account_link_conflict_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/login_failure_screen.dart';
import 'package:clipback_frontend/features/auth/login_status_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/auth/permission_guide_sheet.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:clipback_frontend/features/auth/session_restore_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_initial_loading_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/home/notification_list_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:clipback_frontend/shared/models/app_info.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/notification_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_dependencies.dart';
import 'app_view_model.dart';
import 'exit_confirmation_dialog.dart';
import '../features/share/pending_share_prompt.dart';
import '../data/services/search_history_storage.dart';

class ClipbackApp extends StatefulWidget {
  const ClipbackApp({
    this.sessionStorage,
    this.socialAuth,
    this.searchHistoryStorage,
    this.appInfo,
    super.key,
  });

  final ApiSessionStorage? sessionStorage;
  final SearchHistoryStorage? searchHistoryStorage;
  final SocialAuth? socialAuth;

  /// 설치된 앱의 앱 정보. 읽지 못했으면 null이다.
  final AppInfo? appInfo;

  @override
  State<ClipbackApp> createState() => _ClipbackAppState();
}

enum _LaunchPhase { showing, mounting, ready }

class _ClipbackAppState extends State<ClipbackApp> with WidgetsBindingObserver {
  late final AppDependencies _d;
  _LaunchPhase _launchPhase = _LaunchPhase.showing;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _isSessionStorageBusy = ValueNotifier(false);
  bool _persistenceBannerVisible = false;
  bool _notificationSettingsOpen = false;
  bool _loginFailureContactOpen = false;
  bool _permissionGuideAcknowledged = false;
  bool _permissionGuideVisitActive = false;
  int _permissionGuideVisitGeneration = -1;
  _PermissionGuideAttempt? _permissionGuideAttempt;
  PermissionGuideRoute? _permissionGuideRoute;
  _ExitConfirmationAttempt? _exitConfirmation;
  bool _persistenceBannerUpdateScheduled = false;
  PageStorageBucket _archivePageStorageBucket = PageStorageBucket();
  int _archiveStorageAccountGeneration = 0;
  PageStorageBucket _myNoticePageStorageBucket = PageStorageBucket();
  AppRoute _myNoticeStorageRoute = AppRoute.splash;
  int _myNoticeStorageAccountGeneration = 0;
  int _myNoticeStorageAuthEpoch = 0;
  bool _myNoticeStorageBlocked = true;
  AppRoute _categoryManagementReturnRoute = AppRoute.my;
  AppRoute _statsRoute = AppRoute.splash;
  Object? _weeklyVisit, _weeklyRequest, _pendingWeeklyFailure;
  int _weeklyGeneration = -1;
  bool _weeklyForeground = true;
  bool _weeklyVisibilityScheduled = false;
  late final _WeeklyOverlayObserver _weeklyObserver = _WeeklyOverlayObserver(
    _weeklyVisibilityChanged,
  );
  bool get _weeklyHome =>
      mounted &&
      _launchPhase == _LaunchPhase.ready &&
      _d.app.route == AppRoute.home &&
      _canUseAccountActions &&
      _d.session.hasSession &&
      !_d.session.pendingSessionClear;
  bool get _weeklyVisible =>
      _weeklyHome && _weeklyForeground && !_weeklyObserver.covered;
  bool _ownsWeekly(Object visit) =>
      _weeklyHome &&
      identical(_weeklyVisit, visit) &&
      _weeklyGeneration == _d.app.accountGeneration;

  void _syncWeeklyHome() {
    if (!_weeklyHome || _weeklyGeneration != _d.app.accountGeneration) {
      final old = _weeklyVisit;
      _weeklyVisit = null;
      _weeklyRequest = null;
      _pendingWeeklyFailure = null;
      if (old != null) _d.content.endWeeklyVisit(old);
    }
    if (_weeklyHome && _weeklyVisit == null) {
      _weeklyGeneration = _d.app.accountGeneration;
      final visit = _d.content.beginWeeklyVisit();
      _weeklyVisit = visit;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ownsWeekly(visit)) unawaited(_loadWeekly(visit));
      });
    }
    if (_d.app.route != AppRoute.archive && _d.app.route != AppRoute.detail) {
      _d.archive.clearWeeklyOrigin();
    }
  }

  Future<void> _loadWeekly(Object visit) async {
    if (!_ownsWeekly(visit) || _weeklyRequest != null) return;
    final request = Object();
    _weeklyRequest = request;
    try {
      await _d.content.loadWeekly(visit);
    } catch (_) {
      if (_ownsWeekly(visit)) {
        _pendingWeeklyFailure = visit;
        _showWeeklyFailure();
      }
    } finally {
      if (identical(_weeklyRequest, request)) _weeklyRequest = null;
    }
  }

  void _showWeeklyFailure() {
    final visit = _pendingWeeklyFailure;
    if (visit == null || !_weeklyVisible || !_ownsWeekly(visit)) return;
    _pendingWeeklyFailure = null;
    _handleEffect(
      MessageEffect(
        '이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.',
        retry: () {
          if (_ownsWeekly(visit)) unawaited(_loadWeekly(visit));
        },
      ),
    );
  }

  void _weeklyVisibilityChanged() {
    if (!mounted || _weeklyVisibilityScheduled) return;
    _weeklyVisibilityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _weeklyVisibilityScheduled = false;
      if (!mounted) return;
      setState(() {});
      _showWeeklyFailure();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _openWeekly(Object? visit, ApiWeeklyRecommendationItem item) {
    if (visit == null ||
        !_ownsWeekly(visit) ||
        !_weeklyVisible ||
        !(_d.content.weekly?.items.any(
              (c) => c.id == item.id && c.category.id == item.category.id,
            ) ??
            false)) {
      return;
    }
    _d.detail.close();
    if (_d.archive.openWeekly(item)) {
      _d.archive.recordCategoryOpen(item.category.id);
      _d.app.openArchive();
    }
  }

  Object _todayVisit = Object();
  Object? _todayRequest;
  late final NavigatorObserver _todayObserver = _TodayTransientObserver(() {
    _todayVisit = Object();
    _todayRequest = null;
    _d.detail.cancelTodayNavigation();
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _weeklyForeground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _d = AppDependencies(
      storage: widget.sessionStorage,
      searchHistoryStorage: widget.searchHistoryStorage,
      socialAuth: widget.socialAuth,
      canPrepareSharing: () => _launchPhase == _LaunchPhase.ready,
    );
    _archiveStorageAccountGeneration = _d.app.accountGeneration;
    _d.app.addListener(_onChanged);
    for (final viewModel in _d.featureViewModels) {
      viewModel.addListener(_onChanged);
    }
    _d.session.addListener(_onSessionChanged);
    _d.app.start();
  }

  @override
  void dispose() {
    _cancelExitConfirmation();
    _cancelPermissionGuide();
    WidgetsBinding.instance.removeObserver(this);
    _d.app.removeListener(_onChanged);
    for (final viewModel in _d.featureViewModels) {
      viewModel.removeListener(_onChanged);
    }
    _d.session.removeListener(_onSessionChanged);
    _d.dispose();
    _isSessionStorageBusy.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _weeklyForeground = state == AppLifecycleState.resumed;
    _weeklyVisibilityChanged();
    if (state == AppLifecycleState.resumed) {
      unawaited(_d.app.checkAppleCredential());
      unawaited(_d.sharing.resume());
    }
  }

  void _onChanged() {
    if (!mounted) return;
    final exit = _exitConfirmation;
    if (exit != null && exit.owner != _backIdentity) {
      _cancelExitConfirmation();
    }
    if (_d.app.route != AppRoute.home ||
        !_canUseAccountActions ||
        !_d.session.hasSession ||
        _d.session.pendingSessionClear) {
      _todayVisit = Object();
      _todayRequest = null;
    }
    if (_d.app.route != AppRoute.detail && _d.detail.isToday) {
      _d.detail.cancelTodayNavigation();
    }
    _syncWeeklyHome();
    _syncPermissionGuideVisit();
    _syncMyNoticeStorage();
    _syncMyStatsEntry();
    if (_archiveStorageAccountGeneration != _d.app.accountGeneration) {
      _archiveStorageAccountGeneration = _d.app.accountGeneration;
      _archivePageStorageBucket = PageStorageBucket();
      _categoryManagementReturnRoute = AppRoute.my;
    }
    setState(() {});
    _flushUiEffects();
  }

  void _syncMyStatsEntry() {
    final route = _d.app.route;
    final entering = route == AppRoute.my && _statsRoute != AppRoute.my;
    _statsRoute = route;
    if (entering &&
        _canUseAccountActions &&
        _d.session.hasSession &&
        !_d.session.pendingSessionClear) {
      unawaited(_d.account.retryStats());
    }
  }

  VoidCallback _statsRetryAction() {
    final generation = _d.app.accountGeneration;
    final epoch = _d.app.authEpoch;
    return () {
      if (!_canUseAccountActions ||
          _d.app.route != AppRoute.my ||
          generation != _d.app.accountGeneration ||
          epoch != _d.app.authEpoch ||
          !_d.session.hasSession ||
          _d.session.pendingSessionClear ||
          !_d.account.canRetryStats) {
        return;
      }
      unawaited(_d.account.retryStats());
    };
  }

  // Only the My -> notices -> My pair restores My's scroll position. Other
  // routes and security/restore boundaries discard the old bucket entirely.
  void _syncMyNoticeStorage() {
    final route = _d.app.route;
    final generation = _d.app.accountGeneration;
    final epoch = _d.app.authEpoch;
    final blocked =
        _d.app.isRestoringSession ||
        _d.app.apiConnectionError != null ||
        _d.session.pendingSessionClear ||
        !_d.session.hasSession;
    final noticePair =
        (_myNoticeStorageRoute == AppRoute.my &&
            route == AppRoute.noticeList) ||
        (_myNoticeStorageRoute == AppRoute.noticeList && route == AppRoute.my);
    if (generation != _myNoticeStorageAccountGeneration ||
        epoch != _myNoticeStorageAuthEpoch ||
        blocked != _myNoticeStorageBlocked ||
        (route != _myNoticeStorageRoute && !noticePair)) {
      _myNoticePageStorageBucket = PageStorageBucket();
    }
    _myNoticeStorageRoute = route;
    _myNoticeStorageAccountGeneration = generation;
    _myNoticeStorageAuthEpoch = epoch;
    _myNoticeStorageBlocked = blocked;
  }

  VoidCallback _noticeNavigation(AppRoute from, AppRoute to) {
    final generation = _d.app.accountGeneration;
    final epoch = _d.app.authEpoch;
    return () {
      if (!_canUseAccountActions ||
          !_d.session.hasSession ||
          _d.session.pendingSessionClear ||
          _d.app.accountGeneration != generation ||
          _d.app.authEpoch != epoch ||
          _d.app.route != from) {
        return;
      }
      _go(to);
    };
  }

  bool _canUseNotifications(AppRoute from, int generation, int epoch) =>
      _canUseAccountActions &&
      _d.session.hasSession &&
      !_d.session.pendingSessionClear &&
      _d.app.accountGeneration == generation &&
      _d.app.authEpoch == epoch &&
      _d.app.route == from;

  VoidCallback _notificationNavigation(AppRoute from, AppRoute to) {
    final generation = _d.app.accountGeneration;
    final epoch = _d.app.authEpoch;
    return () {
      if (!_notificationSettingsOpen &&
          _canUseNotifications(from, generation, epoch)) {
        _go(to);
      }
    };
  }

  VoidCallback _notificationSettings() {
    final generation = _d.app.accountGeneration;
    final epoch = _d.app.authEpoch;
    return () => unawaited(_showNotificationSettings(generation, epoch));
  }

  Future<void> _showNotificationSettings(int generation, int epoch) async {
    if (_notificationSettingsOpen ||
        !_canUseNotifications(AppRoute.notificationList, generation, epoch)) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _notificationSettingsOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const ReminderSheet(),
      );
    } finally {
      _notificationSettingsOpen = false;
    }
  }

  // An acknowledgement belongs to this ordinary-login visit, not to an auth
  // attempt: the SDK increments authEpoch even when it cancels or fails.
  void _syncPermissionGuideVisit() {
    final active =
        _d.app.route == AppRoute.login &&
        !_d.app.linkingGuest &&
        _d.app.supportedProviders.isNotEmpty &&
        !_d.app.isRestoringSession &&
        _d.app.apiConnectionError == null &&
        !_d.session.pendingSessionClear;
    final generation = _d.app.accountGeneration;
    if (!active ||
        !_permissionGuideVisitActive ||
        generation != _permissionGuideVisitGeneration) {
      _permissionGuideAcknowledged = false;
    }
    _permissionGuideVisitActive = active;
    _permissionGuideVisitGeneration = generation;
    final attempt = _permissionGuideAttempt;
    if (_permissionGuideRoute != null &&
        attempt != null &&
        !_canStartGuidedAuthentication(attempt)) {
      _cancelPermissionGuide();
    }
  }

  bool _canStartGuidedAuthentication(_PermissionGuideAttempt attempt) =>
      mounted &&
      _launchPhase == _LaunchPhase.ready &&
      _canUseAccountActions &&
      _d.app.route == AppRoute.login &&
      !_d.app.linkingGuest &&
      _d.app.ordinaryLoginStatus == null &&
      !_d.session.pendingSessionClear &&
      _d.app.accountGeneration == attempt.generation &&
      _d.app.authEpoch == attempt.epoch &&
      _d.app.supportedProviders.isNotEmpty &&
      (attempt.provider == null ||
          _d.app.supportedProviders.contains(attempt.provider));

  void _cancelPermissionGuide() {
    final attempt = _permissionGuideAttempt;
    final route = _permissionGuideRoute;
    if (attempt == null || route == null) return;
    attempt.cancel();
    final navigator = _navigatorKey.currentState;
    // Listeners may fire while Navigator is building. Retain the exact route,
    // so a subsequent security sheet is never dismissed by an unrelated pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null && navigator.mounted && route.isActive) {
        navigator.removeRoute<bool>(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Widget _buildLogin() {
    final providers = _d.app.supportedProviders;
    final guided = !_d.app.linkingGuest && providers.isNotEmpty;
    final generation = _d.app.accountGeneration;
    final epoch = _d.app.authEpoch;
    final conflict = _d.app.accountLinkConflict;
    if (conflict != null) {
      return AccountLinkConflictScreen(
        onKeepGuest: () {
          if (_canUseAccountLinkConflict(conflict)) {
            _d.app.cancelAccountLinkConflict(conflict);
          }
        },
        onConfirm: () {
          if (_canUseAccountLinkConflict(conflict)) {
            unawaited(
              _d.app.confirmAccountSwitch(
                conflict.authEpoch,
                conflict.provider,
              ),
            );
          }
        },
      );
    }
    final status = _d.app.ordinaryLoginStatus;
    if (status != null) {
      if (status.phase == OrdinaryLoginPhase.authenticating) {
        return const LoginProgressScreen();
      }
      return LoginCancelledScreen(
        onChooseMethods: () => _dismissLoginStatus(status),
        onContinueAsGuest: () {
          if (!_dismissLoginStatus(status)) return;
          unawaited(
            _withPermissionGuide(
              () => _d.app.continueAsGuest(),
              generation: generation,
              epoch: epoch,
            ),
          );
        },
      );
    }
    final failure = _d.app.ordinaryLoginFailure;
    if (failure != null) {
      return LoginFailureScreen(
        statusCode: failure.statusCode,
        onChooseMethods: () => _dismissLoginFailure(failure),
        onContinueAsGuest: () {
          if (!_dismissLoginFailure(failure)) return;
          unawaited(
            _withPermissionGuide(
              () => _d.app.continueAsGuest(),
              generation: generation,
              epoch: epoch,
            ),
          );
        },
        onContact: () => unawaited(_showLoginFailureContact(failure)),
      );
    }
    return LoginScreen(
      onContinue: guided
          ? () => _withPermissionGuide(
              () => _d.app.continueAsGuest(),
              generation: generation,
              epoch: epoch,
            )
          : _d.app.linkingGuest
          ? () async {
              if (_canUseLinkingLogin(generation, epoch)) {
                await _d.app.continueAsGuest();
              }
            }
          : _d.app.continueAsGuest,
      onSocialLogin: guided
          ? (provider) => _withPermissionGuide(
              () => _d.app.authenticateSocial(provider),
              generation: generation,
              epoch: epoch,
              provider: provider,
            )
          : _d.app.linkingGuest
          ? (provider) async {
              if (_canUseLinkingLogin(generation, epoch)) {
                await _d.app.authenticateSocial(provider);
              }
            }
          : _d.app.authenticateSocial,
      providers: providers,
      busy: _d.app.authBusy,
      linkingGuest: _d.app.linkingGuest,
      onBack: _d.app.linkingGuest
          ? () {
              if (_canUseLinkingLogin(generation, epoch)) {
                _go(AppRoute.account);
              }
            }
          : null,
    );
  }

  bool _dismissLoginStatus(OrdinaryLoginStatus expected) {
    if (!mounted ||
        _launchPhase != _LaunchPhase.ready ||
        !_canUseAccountActions ||
        _d.app.route != AppRoute.login ||
        _d.app.linkingGuest ||
        _d.session.hasSession ||
        _d.session.pendingSessionClear ||
        !identical(_d.app.ordinaryLoginStatus, expected)) {
      return false;
    }
    return _d.app.dismissOrdinaryLoginStatus(expected);
  }

  bool _canUseLinkingLogin(int generation, int epoch) =>
      mounted &&
      _launchPhase == _LaunchPhase.ready &&
      _canUseAccountActions &&
      _d.app.route == AppRoute.login &&
      _d.app.linkingGuest &&
      _d.session.hasSession &&
      !_d.session.pendingSessionClear &&
      _d.app.accountGeneration == generation &&
      _d.app.authEpoch == epoch &&
      _d.app.accountLinkConflict == null;

  bool _canUseAccountLinkConflict(AccountLinkConflict expected) =>
      mounted &&
      _launchPhase == _LaunchPhase.ready &&
      _canUseAccountActions &&
      !_d.session.pendingSessionClear &&
      identical(_d.app.accountLinkConflict, expected);

  bool _canUseLoginFailure(OrdinaryLoginFailure expected) =>
      mounted &&
      _launchPhase == _LaunchPhase.ready &&
      _canUseAccountActions &&
      !_d.session.hasSession &&
      !_d.session.pendingSessionClear &&
      identical(_d.app.ordinaryLoginFailure, expected);

  bool _dismissLoginFailure(OrdinaryLoginFailure expected) =>
      !_loginFailureContactOpen &&
      _canUseLoginFailure(expected) &&
      _d.app.dismissOrdinaryLoginFailure(expected);

  Future<void> _showLoginFailureContact(OrdinaryLoginFailure expected) async {
    if (_loginFailureContactOpen || !_canUseLoginFailure(expected)) return;
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _loginFailureContactOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const ContactSheet(),
      );
    } finally {
      _loginFailureContactOpen = false;
    }
  }

  Future<void> _withPermissionGuide(
    Future<void> Function() selectedAction, {
    required int generation,
    required int epoch,
    SocialLoginProvider? provider,
  }) async {
    if (!mounted) return;
    _syncPermissionGuideVisit();
    final attempt = _PermissionGuideAttempt(generation, epoch, provider);
    if (_permissionGuideAttempt != null ||
        !_canStartGuidedAuthentication(attempt)) {
      return;
    }
    _permissionGuideAttempt = attempt;
    PermissionGuideRoute? ownedRoute;
    try {
      if (!_permissionGuideAcknowledged) {
        final navigator = _navigatorKey.currentState;
        final context = _navigatorKey.currentContext;
        if (navigator == null || context == null || !context.mounted) return;
        late final PermissionGuideRoute route;
        route = PermissionGuideRoute(
          context: context,
          builder: (context) => PermissionGuideSheet(
            onContinue: () {
              if (attempt.confirmed ||
                  attempt.cancelled ||
                  !identical(_permissionGuideAttempt, attempt) ||
                  !identical(_permissionGuideRoute, route) ||
                  !route.isCurrent ||
                  !_canStartGuidedAuthentication(attempt)) {
                return;
              }
              attempt.confirmed = true;
              navigator.pop<bool>(true);
            },
          ),
        );
        ownedRoute = route;
        _permissionGuideRoute = route;
        final accepted = await Future.any<bool?>([
          navigator.push<bool>(route),
          attempt.cancellation.future,
        ]);
        if (!mounted) return;
        // SDK UI must not overlap the bottom sheet's reverse transition.
        await route.completed;
        if (identical(_permissionGuideRoute, route)) {
          _permissionGuideRoute = null;
        }
        if (accepted != true ||
            attempt.cancelled ||
            !_canStartGuidedAuthentication(attempt)) {
          return;
        }
        _permissionGuideAcknowledged = true;
      }
      if (_canStartGuidedAuthentication(attempt)) await selectedAction();
    } finally {
      if (identical(_permissionGuideRoute, ownedRoute)) {
        _permissionGuideRoute = null;
      }
      if (identical(_permissionGuideAttempt, attempt)) {
        _permissionGuideAttempt = null;
      }
    }
  }

  void _finishLaunchSplash() {
    if (!mounted || _launchPhase != _LaunchPhase.showing) return;
    setState(() => _launchPhase = _LaunchPhase.mounting);
    // Route selection is still owned by session restoration. Wait for that
    // route's first frame before presenting queued UI or preparing sharing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _launchPhase != _LaunchPhase.mounting) return;
      setState(() => _launchPhase = _LaunchPhase.ready);
      _syncWeeklyHome();
      _d.sharing.sessionSettled();
      _flushUiEffects();
      _schedulePersistenceBannerUpdate();
    });
  }

  void _flushUiEffects() {
    if (!mounted || _launchPhase != _LaunchPhase.ready) return;
    final effects = [
      ..._d.app.drainEffects(),
      for (final viewModel in _d.featureViewModels) ...viewModel.drainEffects(),
    ];
    for (final effect in effects) {
      _handleEffect(effect);
    }
  }

  void _handleEffect(UiEffect effect) {
    switch (effect) {
      case MessageEffect():
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(effect.message),
            action: effect.retry == null
                ? null
                : SnackBarAction(
                    label: effect.retryLabel ?? '다시 시도',
                    onPressed: effect.retry!,
                  ),
          ),
        );
      case CloseTransientRoutesEffect():
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      case ConfirmAccountSwitchEffect():
        // Kept for effect compatibility; the owned login state renders A05-1.
        break;
      case DetailDeletedEffect():
        if (_d.app.route == AppRoute.detail) _d.app.backFromDetail();
      case SavedContentEffect():
        final saved = _d.home.page.items
            .where((item) => item.apiId == effect.contentId)
            .firstOrNull;
        if (saved == null) return;
        final opened = _d.detail.open(
          saved,
          source: FeedKey.home,
          sourcePage: _d.home.page,
          recordView: false,
        );
        if (!opened) return;
        _d.app.go(AppRoute.home);
        _d.app.openDetail();
    }
  }

  void _onSessionChanged() {
    if (!mounted) return;
    _syncPermissionGuideVisit();
    _isSessionStorageBusy.value = _d.session.storageBusy;
    _schedulePersistenceBannerUpdate();
  }

  void _schedulePersistenceBannerUpdate() {
    if (!mounted ||
        _launchPhase != _LaunchPhase.ready ||
        _persistenceBannerUpdateScheduled) {
      return;
    }
    _persistenceBannerUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistenceBannerUpdateScheduled = false;
      if (!mounted || _launchPhase != _LaunchPhase.ready) return;
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      final showBanner = _d.session.needsPersistence;
      if (!showBanner) {
        if (_persistenceBannerVisible) messenger.removeCurrentMaterialBanner();
        _persistenceBannerVisible = false;
        return;
      }
      if (_persistenceBannerVisible) return;
      _persistenceBannerVisible = true;
      messenger.showMaterialBanner(
        MaterialBanner(
          backgroundColor: AppColors.surface,
          content: const Text('로그인 정보를 기기에 저장하지 못했어요. 앱을 종료하기 전에 다시 저장해 주세요.'),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _isSessionStorageBusy,
              builder: (context, busy, child) => TextButton(
                onPressed: busy ? null : _d.session.retryPersistence,
                child: const Text('다시 저장'),
              ),
            ),
          ],
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _go(AppRoute route) {
    if (route != AppRoute.detail) _d.detail.close();
    _d.app.go(route);
  }

  void _openCategoryManagement(AppRoute returnRoute) {
    _categoryManagementReturnRoute = returnRoute;
    _go(AppRoute.categoryManagement);
  }

  bool get _canUseAccountActions =>
      mounted &&
      !_d.app.authBusy &&
      !_d.app.isRestoringSession &&
      _d.app.apiConnectionError == null;

  Future<void> _openLogoutConfirmation() async {
    if (!_canUseAccountActions || _d.app.route != AppRoute.account) return;
    _go(AppRoute.logoutConfirmation);
  }

  Future<void> _confirmLogout() async {
    if (!_canUseAccountActions || _d.app.route != AppRoute.logoutConfirmation) {
      return;
    }
    await _d.app.logout();
  }

  void _cancelLogout() {
    if (!_canUseAccountActions || _d.app.route != AppRoute.logoutConfirmation) {
      return;
    }
    _go(AppRoute.account);
  }

  void _selectRootTab(AppRoute route) {
    _d.detail.close();
    if (route == AppRoute.archive && _d.app.route != AppRoute.archive) {
      _d.archive.enterRootTab();
    }
    _d.app.selectRootTab(route);
    if (route == AppRoute.archive) _d.archive.ensureLoaded();
    if (route == AppRoute.bookmark) _d.bookmark.ensureLoaded();
  }

  VoidCallback _archiveBackAction() {
    final origin = _d.archive.weeklyOrigin;
    final generation = _d.app.accountGeneration;
    return () {
      if (!_canUseAccountActions ||
          _d.app.route != AppRoute.archive ||
          generation != _d.app.accountGeneration ||
          !identical(origin, _d.archive.weeklyOrigin)) {
        return;
      }
      if (origin != null) {
        _selectRootTab(AppRoute.home);
      } else {
        _d.archive.clearCategory();
      }
    };
  }

  Widget _searchScreen() {
    final generation = _d.app.accountGeneration;
    final owner = _d.search.historyOwner;
    bool current() =>
        _canUseAccountActions &&
        _d.app.route == AppRoute.search &&
        generation == _d.app.accountGeneration &&
        _d.searchHistory.owns(owner);
    return SearchScreen(
      key: ValueKey(generation),
      recentTerms: _d.search.recentTerms,
      onRemoveRecentTerm: (term) {
        if (current()) _d.search.removeRecentTerm(term);
      },
      initialQuery: _d.search.query,
      contents: _d.search.page.items,
      feed: _d.search.page,
      onLoadMore: _d.search.loadMore,
      onRetry: _d.search.retry,
      bookmarkedIds: _d.home.bookmarkedIds,
      categories: _d.categories.categories,
      onSearch: (value) =>
          current() ? _d.search.search(value) : Future.value(const []),
      onQueryChanged: (value) {
        if (current()) _d.search.changeQuery(value);
      },
      onClose: () {
        if (current()) _go(_d.app.searchReturnRoute);
      },
      onOpenContent: _openDetail,
      onToggleBookmark: _d.search.toggleBookmark,
      onChangeContentCategory: _d.search.changeCategory,
      onDeleteContent: _d.search.deleteContent,
      onOpenArchive: () => _openArchive(),
    );
  }

  void _openSearch() {
    _d.archive.clearWeeklyOrigin();
    _d.search.open();
    _d.app.openSearch();
  }

  void _openArchive({int tab = 0, String? categoryName}) {
    _d.detail.close();
    _d.archive.open(tab: tab, categoryName: categoryName);
    _d.app.openArchive();
  }

  void _openDetail(ContentItem content) {
    if (_d.app.route == AppRoute.detail && _d.detail.isToday) {
      unawaited(_d.detail.openTodayItem(content));
      return;
    }
    final source = _d.app.route == AppRoute.detail
        ? _d.detail.source ?? FeedKey.home
        : switch (_d.app.route) {
            AppRoute.archive => FeedKey.archive,
            AppRoute.bookmark => FeedKey.bookmark,
            AppRoute.search => FeedKey.search,
            _ => FeedKey.home,
          };
    final page = switch (source) {
      FeedKey.home => _d.home.page,
      FeedKey.archive => _d.archive.page,
      FeedKey.bookmark => _d.bookmark.page,
      FeedKey.search => _d.search.page,
    };
    final origin = source == FeedKey.archive
        ? (_d.app.route == AppRoute.detail
              ? _d.detail.weeklyOrigin
              : _d.archive.weeklyOrigin)
        : null;
    if (_d.detail.open(
      content,
      source: source,
      sourcePage: page,
      weeklyOrigin: origin,
    )) {
      _d.app.openDetail();
    }
  }

  void _backFromDetail() {
    _d.detail.close();
    _d.app.backFromDetail();
  }

  VoidCallback _todayAction() {
    final visit = _todayVisit;
    final generation = _d.app.accountGeneration;
    final epoch = _d.app.authEpoch;
    bool current() =>
        mounted &&
        identical(visit, _todayVisit) &&
        _d.app.route == AppRoute.home &&
        _canUseAccountActions &&
        _d.session.hasSession &&
        !_d.session.pendingSessionClear &&
        generation == _d.app.accountGeneration &&
        epoch == _d.app.authEpoch;
    return () {
      if (!current() || _todayRequest != null) return;
      final token = Object();
      _todayRequest = token;
      unawaited(() async {
        try {
          final opened = await _d.detail.openToday(
            isCurrent: () => current() && identical(_todayRequest, token),
          );
          if (opened && current() && identical(_todayRequest, token)) {
            _d.app.openDetail();
          }
        } finally {
          if (identical(_todayRequest, token)) _todayRequest = null;
        }
      }());
    };
  }

  // Logical screens share one Navigator route. Keep this wrapper stable so
  // home/notification round-trips retain their IndexedStack and scroll state.
  // Existing screen scopes remain the sole handlers when delegated to them.
  bool get _backBlocked =>
      _launchPhase != _LaunchPhase.ready ||
      _d.app.route == AppRoute.splash ||
      _d.app.authBusy ||
      _d.app.isRestoringSession ||
      _d.app.showInitialHomeLoading ||
      _d.app.apiConnectionError != null ||
      _d.session.pendingSessionClear;

  Object get _backIdentity => (
    _d.app.route,
    _d.app.accountGeneration,
    _d.app.authEpoch,
    _d.app.linkingGuest,
    _backBlocked,
    _d.app.ordinaryLoginStatus,
    _d.app.ordinaryLoginFailure,
    _d.app.accountLinkConflict,
    _d.archive.activeCategoryName,
    _d.archive.activeTab,
    _d.archive.randomViewing,
    _d.archive.weeklyOrigin,
  );

  bool get _hasScreenBackOwner {
    // Restore/splash replace the logical screen, including its PopScope.
    if (_launchPhase != _LaunchPhase.ready ||
        _d.app.isRestoringSession ||
        _d.app.showInitialHomeLoading ||
        _d.app.apiConnectionError != null) {
      return false;
    }
    return switch (_d.app.route) {
      AppRoute.notificationList ||
      AppRoute.noticeList ||
      AppRoute.logoutConfirmation ||
      AppRoute.categoryManagement => true,
      AppRoute.login =>
        _d.app.ordinaryLoginStatus != null ||
            _d.app.ordinaryLoginFailure != null ||
            _d.app.accountLinkConflict != null,
      _ => false,
    };
  }

  Widget _withSystemBack(Widget page) {
    final delegated = _hasScreenBackOwner;
    final owner = _backIdentity;
    return Builder(
      builder: (context) => PopScope<void>(
        canPop: delegated,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || delegated || !mounted || owner != _backIdentity) return;
          // Android normally consumes Back in the IME first. Also protect the
          // route when a pop is delivered while its inset is still nonzero.
          if (MediaQuery.viewInsetsOf(context).bottom > 0) {
            FocusManager.instance.primaryFocus?.unfocus();
            return;
          }
          if (_backBlocked) return;
          switch (_d.app.route) {
            case AppRoute.home:
            case AppRoute.onboarding:
              unawaited(_confirmAppExit(context, owner));
            case AppRoute.login:
              if (_d.app.linkingGuest) {
                _go(AppRoute.account);
              } else {
                unawaited(_confirmAppExit(context, owner));
              }
            case AppRoute.archive:
              if (_d.archive.activeCategoryName != null &&
                  _d.archive.randomViewing &&
                  _d.archive.activeTab == 0) {
                _d.archive.setRandomViewing(false);
              } else if (_d.archive.activeCategoryName != null) {
                _archiveBackAction()();
              } else {
                _selectRootTab(AppRoute.home);
              }
            case AppRoute.bookmark:
            case AppRoute.my:
              _selectRootTab(AppRoute.home);
            case AppRoute.detail:
              _backFromDetail();
            case AppRoute.search:
              _go(_d.app.searchReturnRoute);
            case AppRoute.account:
              _go(AppRoute.my);
            case AppRoute.interests:
              _go(AppRoute.onboarding);
            default:
              break;
          }
        },
        child: page,
      ),
    );
  }

  bool _ownsExitConfirmation(_ExitConfirmationAttempt attempt) =>
      mounted &&
      identical(_exitConfirmation, attempt) &&
      !attempt.cancelled &&
      !_backBlocked &&
      attempt.owner == _backIdentity;

  Future<void> _confirmAppExit(BuildContext context, Object owner) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _exitConfirmation != null ||
        _backBlocked ||
        owner != _backIdentity) {
      return;
    }
    final attempt = _ExitConfirmationAttempt(owner);
    final navigator = _navigatorKey.currentState!;
    _exitConfirmation = attempt;
    final route = DialogRoute<bool>(
      context: context,
      builder: (_) => ExitConfirmationDialog(
        onCancel: () {
          if (_ownsExitConfirmation(attempt) && attempt.route!.isCurrent) {
            navigator.pop(false);
          }
        },
        onExit: () {
          if (_ownsExitConfirmation(attempt) &&
              !attempt.confirmed &&
              attempt.route!.isCurrent) {
            attempt.confirmed = true;
            navigator.pop(true);
          }
        },
      ),
    );
    attempt.route = route;
    try {
      final confirmed = await navigator.push(route);
      if (confirmed == true && _ownsExitConfirmation(attempt)) {
        await SystemNavigator.pop();
      }
    } finally {
      if (identical(_exitConfirmation, attempt)) _exitConfirmation = null;
    }
  }

  void _cancelExitConfirmation() {
    final attempt = _exitConfirmation;
    if (attempt == null) return;
    attempt.cancelled = true;
    _exitConfirmation = null;
    final route = attempt.route;
    final navigator = _navigatorKey.currentState;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null && navigator.mounted && route?.isActive == true) {
        navigator.removeRoute<bool>(route!);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      navigatorObservers: [_todayObserver, _weeklyObserver],
      scaffoldMessengerKey: _messengerKey,
      scrollBehavior: const AppScrollBehavior(),
      title: '허투루',
      builder: (context, child) => _launchPhase != _LaunchPhase.ready
          ? child!
          : PendingSharePrompt(
              navigatorKey: _navigatorKey,
              promptVersion: _d.sharing.promptVersion,
              drafts: _d.sharing.drafts,
              error: _d.sharing.error,
              busy: _d.sharing.busy,
              onRetry: () => unawaited(_d.sharing.retry()),
              onOpen: (draft) => unawaited(_d.sharing.present(draft)),
              child: child!,
            ),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        bottomSheetTheme: const BottomSheetThemeData(
          constraints: BoxConstraints(maxWidth: phoneWidth),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
        fontFamily: 'Pretendard',
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
      ),
      home: _withLaunchSplash(switch (_d.app.route) {
        _ when _d.app.apiConnectionError != null => SessionRestoreScreen(
          errorMessage: _d.app.apiConnectionError,
          onRetry: _d.app.restoreSession,
        ),
        _ when _d.app.showInitialHomeLoading =>
          const HomeInitialLoadingScreen(),
        _ when _d.app.isRestoringSession => SessionRestoreScreen(
          errorMessage: null,
          onRetry: _d.app.restoreSession,
        ),
        AppRoute.splash => SplashScreen(onDone: _d.app.finishSplash),
        AppRoute.login => _buildLogin(),
        AppRoute.onboarding => OnboardingScreen(
          onDone: () => _go(AppRoute.interests),
        ),
        AppRoute.interests => InterestSelectionScreen(
          onBack: () => _go(AppRoute.onboarding),
          onDone: () => _go(AppRoute.home),
        ),
        AppRoute.home || AppRoute.notificationList => _HomeNotificationFlow(
          key: ValueKey((
            _d.app.accountGeneration,
            _d.app.authEpoch,
            _d.session.pendingSessionClear,
            _d.session.hasSession,
          )),
          showingNotifications: _d.app.route == AppRoute.notificationList,
          home: HomeScreen(
            weeklyItems: _weeklyVisit == null
                ? const []
                : _d.content.weekly?.items ?? const [],
            weeklyExposureEnabled: _weeklyVisible,
            onWeeklySelected: ((visit) =>
                (item) => _openWeekly(visit, item))(_weeklyVisit),
            onWeeklyExposed: ((visit) => (id) {
              if (visit != null && _ownsWeekly(visit) && _weeklyVisible) {
                _d.content.recordWeeklyExposure(visit, id);
              }
            })(_weeklyVisit),
            contents: _d.home.page.items,
            feed: _d.home.page,
            onRetry: _d.home.retry,
            activeCategoryId: _d.home.page.categoryId,
            onCategorySelected: _d.home.selectCategory,
            categories: _d.categories.categories,
            bookmarkedIds: _d.home.bookmarkedIds,
            onSearch: _openSearch,
            onOpenNotifications: _notificationNavigation(
              AppRoute.home,
              AppRoute.notificationList,
            ),
            onOpenArchive: () => _openArchive(
              categoryName: _d.home.categories
                  .where((item) => item.id == _d.home.page.categoryId)
                  .firstOrNull
                  ?.name,
            ),
            onOpenCategories: () => _openArchive(tab: 1),
            onOpenToday: _todayAction(),
            onOpenContent: _openDetail,
            onToggleBookmark: _d.home.toggleBookmark,
            onAddLink: _d.save.addLink,
            onAddScreenshot: _d.save.addScreenshot,
            onTab: _selectRootTab,
          ),
          notification: _d.app.route == AppRoute.notificationList
              ? NotificationListScreen(
                  items: mockNotifications,
                  onBack: _notificationNavigation(
                    AppRoute.notificationList,
                    AppRoute.home,
                  ),
                  onOpenSettings: _notificationSettings(),
                )
              : const SizedBox.shrink(),
        ),
        AppRoute.archive => PageStorage(
          key: ValueKey(_archiveStorageAccountGeneration),
          bucket: _archivePageStorageBucket,
          child: ArchiveScreen(
            activeTab: _d.archive.activeTab,
            contents: _d.archive.page.items,
            feed: _d.archive.page,
            onLoadMore: _d.archive.loadMore,
            onRetry: _d.archive.retry,
            categories: _d.categories.categories,
            bookmarkedIds: _d.home.bookmarkedIds,
            bookmarkedFirst: _d.archive.bookmarkedFirst,
            randomViewing: _d.archive.randomViewing,
            activeCategoryName: _d.archive.activeCategoryName,
            onTabChanged: _d.archive.selectTab,
            onSortChanged: _d.archive.sort,
            onOpenRandomView: () => _d.archive.setRandomViewing(true),
            onExitRandomView: () => _d.archive.setRandomViewing(false),
            onClearCategory: _archiveBackAction(),
            onSearch: _openSearch,
            onOpenCategoryManagement: () =>
                _openCategoryManagement(AppRoute.archive),
            onOpenContent: _openDetail,
            onToggleBookmark: _d.archive.toggleBookmark,
            onChangeContentCategory: _d.archive.changeCategory,
            onDeleteContent: _d.archive.deleteContent,
            onAddCategory: _d.categories.add,
            onSubmitCategory: _d.categories.submitCreate,
            onSubmitCategoryUpdate: _d.categories.submitUpdate,
            onPrepareCategory: _d.categories.prepareEditor,
            onUpdateCategory: _d.categories.update,
            onDeleteCategory: _d.categories.delete,
            onAddLink: _d.save.addLink,
            onAddScreenshot: _d.save.addScreenshot,
            onOpenCategory: (category) {
              unawaited(_d.archive.selectCategory(category));
              if (category.id != null) {
                _d.archive.recordCategoryOpen(category.id!);
              }
            },
            onTab: _selectRootTab,
          ),
        ),
        AppRoute.bookmark => BookmarkScreen(
          contents: _d.bookmark.page.items,
          feed: _d.bookmark.page,
          onLoadMore: _d.bookmark.loadMore,
          onRetry: _d.bookmark.retry,
          bookmarkedIds: _d.home.bookmarkedIds,
          categories: _d.categories.categories,
          onSearch: _openSearch,
          onOpenCategoryManagement: () =>
              _openCategoryManagement(AppRoute.bookmark),
          onOpenArchiveAll: () => _openArchive(tab: 0),
          onOpenContent: _openDetail,
          onToggleBookmark: _d.bookmark.toggleBookmark,
          onChangeContentCategory: _d.bookmark.changeCategory,
          onDeleteContent: _d.bookmark.deleteContent,
          onAddLink: _d.save.addLink,
          onAddScreenshot: _d.save.addScreenshot,
          onTab: _selectRootTab,
        ),
        AppRoute.search => _searchScreen(),
        AppRoute.detail => DetailScreen(
          key: ValueKey((_d.app.accountGeneration, _d.detail.content?.id)),
          onReadAsset: _d.detail.readAsset,
          content: _d.detail.content ?? _d.home.page.items.first,
          contents: _d.detail.feed?.items ?? const [],
          feed: _d.detail.feed,
          moving: _d.detail.moving,
          onRetry: _d.detail.retry,
          categories: _d.categories.categories,
          bookmarked: _d.detail.bookmarked,
          onBack: _backFromDetail,
          onToggleBookmark: _d.detail.toggleBookmark,
          onChangeCategory: _d.detail.changeCategory,
          onDeleteContent: _d.detail.deleteContent,
          onOpenOriginalLink: _d.detail.originalLinkAction(),
          onOpenAdjacent: _d.detail.adjacentAction(),
          onOpenContent: _openDetail,
          onAddLink: _d.save.addLink,
          onAddScreenshot: _d.save.addScreenshot,
          onTab: _selectRootTab,
        ),
        AppRoute.my => PageStorage(
          key: ObjectKey(_myNoticePageStorageBucket),
          bucket: _myNoticePageStorageBucket,
          child: MyScreen(
            user: _d.account.user,
            appInfo: widget.appInfo,
            statsMessage: _d.account.statsMessage,
            onRetryStats: _d.account.canRetryStats ? _statsRetryAction() : null,
            onAddLink: _d.save.addLink,
            onAddScreenshot: _d.save.addScreenshot,
            onOpenAccount: () => _go(AppRoute.account),
            onOpenCategoryManagement: () =>
                _openCategoryManagement(AppRoute.my),
            onOpenNotices: _noticeNavigation(AppRoute.my, AppRoute.noticeList),
            onTab: _selectRootTab,
          ),
        ),
        AppRoute.noticeList => NoticeListScreen(
          titles: mockNotices,
          onBack: _noticeNavigation(AppRoute.noticeList, AppRoute.my),
        ),
        AppRoute.account => AccountManagementScreen(
          user: _d.account.user,
          onBack: () => _go(AppRoute.my),
          onLogout: _openLogoutConfirmation,
          isGuest: _d.app.authenticatedUser?.isGuest,
          onConnect: _d.app.openAccountLogin,
          busy: _d.app.authBusy,
        ),
        AppRoute.logoutConfirmation => LogoutConfirmationScreen(
          onConfirm: _confirmLogout,
          onCancel: _cancelLogout,
          busy: _d.app.authBusy,
        ),
        AppRoute.categoryManagement => PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _go(_categoryManagementReturnRoute);
          },
          child: CategoryManagementScreen(
            categories: _d.categories.categories,
            contents: _d.home.page.items,
            onBack: () => _go(_categoryManagementReturnRoute),
            onAddCategory: _d.categories.add,
            onSubmitCategory: _d.categories.submitCreate,
            onSubmitCategoryUpdate: _d.categories.submitUpdate,
            onPrepareCategory: _d.categories.prepareEditor,
            onUpdateCategory: _d.categories.update,
            onDeleteCategory: _d.categories.delete,
          ),
        ),
      }),
    );
  }

  Widget _withLaunchSplash(Widget route) => _withSystemBack(
    _launchPhase == _LaunchPhase.showing
        ? SplashScreen(onDone: _finishLaunchSplash)
        : route,
  );
}

class _ExitConfirmationAttempt {
  _ExitConfirmationAttempt(this.owner);
  final Object owner;
  DialogRoute<bool>? route;
  bool cancelled = false;
  bool confirmed = false;
}

// Preserve the existing modal round-trip semantics only for home/notifications.
// Other logical routes remove this subtree, as they did before this flow existed.
class _HomeNotificationFlow extends StatelessWidget {
  const _HomeNotificationFlow({
    required this.showingNotifications,
    required this.home,
    required this.notification,
    super.key,
  });
  final bool showingNotifications;
  final Widget home;
  final Widget notification;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: showingNotifications ? 1 : 0,
    children: [
      TickerMode(
        enabled: !showingNotifications,
        child: ExcludeFocus(
          excluding: showingNotifications,
          child: ExcludeSemantics(excluding: showingNotifications, child: home),
        ),
      ),
      // An inactive PopScope must not register against the home route.
      notification,
    ],
  );
}

class _PermissionGuideAttempt {
  _PermissionGuideAttempt(this.generation, this.epoch, this.provider);

  final int generation;
  final int epoch;
  final SocialLoginProvider? provider;
  final cancellation = Completer<bool?>();
  bool confirmed = false;
  bool get cancelled => cancellation.isCompleted;

  void cancel() {
    if (!cancelled) cancellation.complete(null);
  }
}

/// A save sheet can open and close while the root route stays home.
class _TodayTransientObserver extends NavigatorObserver {
  _TodayTransientObserver(this.invalidate);
  final VoidCallback invalidate;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) invalidate();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    invalidate();
  }
}

/// Popped overlays remain occluding until their reverse transition completes.
class _WeeklyOverlayObserver extends NavigatorObserver {
  _WeeklyOverlayObserver(this.changed);
  final VoidCallback changed;
  final _overlays = <Route<dynamic>>{};
  bool get covered => _overlays.isNotEmpty;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _overlays.add(route);
      changed();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is TransitionRoute<dynamic>) {
      route.completed.then((_) {
        if (_overlays.remove(route)) changed();
      });
    } else {
      if (_overlays.remove(route)) changed();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_overlays.remove(route)) changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_overlays.remove(oldRoute) && newRoute != null) _overlays.add(newRoute);
    changed();
  }
}
