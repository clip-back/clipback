import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/logout_confirmation_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:clipback_frontend/features/auth/session_restore_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'app_dependencies.dart';
import '../features/share/pending_share_prompt.dart';

class ClipbackApp extends StatefulWidget {
  const ClipbackApp({this.sessionStorage, this.socialAuth, super.key});

  final ApiSessionStorage? sessionStorage;
  final SocialAuth? socialAuth;

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
  bool _persistenceBannerUpdateScheduled = false;
  PageStorageBucket _archivePageStorageBucket = PageStorageBucket();
  int _archiveStorageAccountGeneration = 0;
  AppRoute _categoryManagementReturnRoute = AppRoute.my;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _d = AppDependencies(
      storage: widget.sessionStorage,
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
    if (state == AppLifecycleState.resumed) {
      unawaited(_d.app.checkAppleCredential());
      unawaited(_d.sharing.resume());
    }
  }

  void _onChanged() {
    if (!mounted) return;
    if (_archiveStorageAccountGeneration != _d.app.accountGeneration) {
      _archiveStorageAccountGeneration = _d.app.accountGeneration;
      _archivePageStorageBucket = PageStorageBucket();
      _categoryManagementReturnRoute = AppRoute.my;
    }
    setState(() {});
    _flushUiEffects();
  }

  void _finishLaunchSplash() {
    if (!mounted || _launchPhase != _LaunchPhase.showing) return;
    setState(() => _launchPhase = _LaunchPhase.mounting);
    // Route selection is still owned by session restoration. Wait for that
    // route's first frame before presenting queued UI or preparing sharing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _launchPhase != _LaunchPhase.mounting) return;
      setState(() => _launchPhase = _LaunchPhase.ready);
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
        unawaited(_confirmAccountSwitch(effect));
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

  Future<void> _confirmAccountSwitch(ConfirmAccountSwitchEffect effect) async {
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미 연결된 계정이에요'),
        content: const Text(
          '기존 계정으로 전환하면 현재 게스트의 저장 데이터는 합쳐지지 않으며, 이 기기에서 다시 접근하지 못할 수 있어요. 기존 계정으로 로그인할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('게스트 유지'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('기존 계정으로 전환'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _d.app.confirmAccountSwitch(effect.epoch, effect.provider);
    }
  }

  void _onSessionChanged() {
    if (!mounted) return;
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

  void _openSearch() {
    _d.search.open();
    _d.app.openSearch();
  }

  void _openArchive({int tab = 0, String? categoryName}) {
    _d.detail.close();
    _d.archive.open(tab: tab, categoryName: categoryName);
    _d.app.openArchive();
  }

  void _openDetail(ContentItem content) {
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
    if (_d.detail.open(content, source: source, sourcePage: page)) {
      _d.app.openDetail();
    }
  }

  void _backFromDetail() {
    _d.detail.close();
    _d.app.backFromDetail();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
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
        _ when _d.app.isRestoringSession || _d.app.apiConnectionError != null =>
          SessionRestoreScreen(
            errorMessage: _d.app.apiConnectionError,
            onRetry: _d.app.restoreSession,
          ),
        AppRoute.splash => SplashScreen(onDone: _d.app.finishSplash),
        AppRoute.login => LoginScreen(
          onContinue: _d.app.continueAsGuest,
          onSocialLogin: _d.app.authenticateSocial,
          providers: _d.app.supportedProviders,
          busy: _d.app.authBusy,
          linkingGuest: _d.app.linkingGuest,
          onBack: _d.app.linkingGuest ? () => _go(AppRoute.account) : null,
        ),
        AppRoute.onboarding => OnboardingScreen(
          onDone: () => _go(AppRoute.interests),
        ),
        AppRoute.interests => InterestSelectionScreen(
          onBack: () => _go(AppRoute.onboarding),
          onDone: () => _go(AppRoute.home),
        ),
        AppRoute.home => HomeScreen(
          contents: _d.home.page.items,
          feed: _d.home.page,
          onRetry: _d.home.retry,
          activeCategoryId: _d.home.page.categoryId,
          onCategorySelected: _d.home.selectCategory,
          categories: _d.categories.categories,
          bookmarkedIds: _d.home.bookmarkedIds,
          onSearch: _openSearch,
          onOpenArchive: () => _openArchive(
            categoryName: _d.home.categories
                .where((item) => item.id == _d.home.page.categoryId)
                .firstOrNull
                ?.name,
          ),
          onOpenCategories: () => _openArchive(tab: 1),
          onOpenToday: _d.home.page.items.isEmpty
              ? () {}
              : () => _openDetail(_d.home.page.items.first),
          onOpenContent: _openDetail,
          onToggleBookmark: _d.home.toggleBookmark,
          onAddLink: _d.save.addLink,
          onAddScreenshot: _d.save.addScreenshot,
          onTab: _selectRootTab,
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
            onClearCategory: _d.archive.clearCategory,
            onSearch: _openSearch,
            onOpenCategoryManagement: () =>
                _openCategoryManagement(AppRoute.archive),
            onOpenContent: _openDetail,
            onToggleBookmark: _d.archive.toggleBookmark,
            onChangeContentCategory: _d.archive.changeCategory,
            onDeleteContent: _d.archive.deleteContent,
            onAddCategory: _d.categories.add,
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
        AppRoute.search => SearchScreen(
          initialQuery: _d.search.query,
          contents: _d.search.page.items,
          feed: _d.search.page,
          onLoadMore: _d.search.loadMore,
          onRetry: _d.search.retry,
          bookmarkedIds: _d.home.bookmarkedIds,
          categories: _d.categories.categories,
          onSearch: _d.search.search,
          onQueryChanged: _d.search.changeQuery,
          onClose: () => _go(_d.app.searchReturnRoute),
          onOpenContent: _openDetail,
          onToggleBookmark: _d.search.toggleBookmark,
          onChangeContentCategory: _d.search.changeCategory,
          onDeleteContent: _d.search.deleteContent,
          onOpenArchive: () => _openArchive(),
        ),
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
          onOpenOriginalLink: _d.detail.recordOriginalOpen,
          onOpenAdjacent: _d.detail.move,
          onOpenContent: _openDetail,
          onAddLink: _d.save.addLink,
          onAddScreenshot: _d.save.addScreenshot,
          onTab: _selectRootTab,
        ),
        AppRoute.my => MyScreen(
          user: _d.account.user,
          onAddLink: _d.save.addLink,
          onAddScreenshot: _d.save.addScreenshot,
          onOpenAccount: () => _go(AppRoute.account),
          onOpenCategoryManagement: () => _openCategoryManagement(AppRoute.my),
          onTab: _selectRootTab,
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
            onUpdateCategory: _d.categories.update,
            onDeleteCategory: _d.categories.delete,
          ),
        ),
      }),
    );
  }

  Widget _withLaunchSplash(Widget route) => _launchPhase == _LaunchPhase.showing
      ? SplashScreen(onDone: _finishLaunchSplash)
      : route;
}
