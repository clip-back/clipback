import '../data/services/search_history_storage.dart';
import '../data/services/api_request_scope.dart';
import '../data/repositories/search_history_repository.dart';
import '../clipback_api.dart';
import '../social_auth.dart';
import '../data/repositories/share_repository.dart';
import '../data/services/native_share_service.dart';
import '../data/services/original_link_opener.dart';
import 'actions/share_coordinator.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/user_repository.dart';
import '../features/account/view_models/account_view_model.dart';
import '../features/archive/view_models/archive_view_model.dart';
import '../features/archive/view_models/bookmark_view_model.dart';
import '../features/categories/view_models/category_management_view_model.dart';
import '../features/content/view_models/content_save_view_model.dart';
import '../features/content/view_models/detail_view_model.dart';
import '../features/home/view_models/home_view_model.dart';
import '../features/search/view_models/search_view_model.dart';
import '../shared/presentation/view_model.dart';
import 'actions/account_initialization_action.dart';
import 'actions/content_actions.dart';
import 'app_view_model.dart';

/// Owns dependencies for one app lifetime. Requests start after view subscriptions.
class AppDependencies {
  AppDependencies({
    ApiSessionStorage? storage,
    SearchHistoryStorage? searchHistoryStorage,
    SocialAuth? socialAuth,
    NativeShareService? nativeShare,
    OriginalLinkOpener? originalLinkOpener,
    bool Function()? canPrepareSharing,
  }) {
    final api = ClipbackApi(
      onSessionChanged: (_) async {
        if (!_disposed) await session.persistCurrentSession();
      },
      onSessionInvalidated: () async {
        if (_disposed) return;
        try {
          final barrier = sharing.blockForSessionChange();
          final scope = ApiRequestScope.current;
          await (scope == null ? barrier : scope.wait(barrier));
        } catch (_) {
          // An unavailable native barrier cannot keep a known-invalid login usable.
          // The coordinator still owns the native barrier and any storage error.
        }
        if (!_disposed) await session.invalidate();
      },
    );
    session = RemoteSessionRepository(
      api: api,
      storage: storage ?? ApiSessionStorage(),
      socialAuth: socialAuth ?? PlatformSocialAuth(),
    );
    content = RemoteContentRepository(api);
    users = RemoteUserRepository(api: api);
    initializeAccount = AccountInitializationAction(content, users);
    contentActions = ContentActions(content, users, session);
    app = AppViewModel(
      session: session,
      users: users,
      initializeAccount: initializeAccount,
      beforeSessionChange: () => sharing.blockForSessionChange(),
    );
    sharing = ShareCoordinator(
      shares: ShareRepository(api, nativeShare ?? NativeShareService()),
      session: session,
      users: users,
      contentActions: contentActions,
      canPrepare: () =>
          (canPrepareSharing?.call() ?? true) &&
          !app.authBusy &&
          !app.isRestoringSession,
    );
    app.addListener(sharing.sessionSettled);
    session.addListener(sharing.sessionSettled);
    home = HomeViewModel(content, contentActions);
    archive = ArchiveViewModel(content, contentActions);
    bookmark = BookmarkViewModel(content, contentActions);
    searchHistory = SearchHistoryRepository(
      storage: searchHistoryStorage ?? PreferencesSearchHistoryStorage(),
      environment: api.baseUrl,
    );
    search = SearchViewModel(content, contentActions, history: searchHistory);
    detail = DetailViewModel(
      content,
      contentActions,
      originalLinkOpener: originalLinkOpener,
    );
    save = ContentSaveViewModel(content, contentActions);
    categories = CategoryManagementViewModel(content, contentActions);
    account = AccountViewModel(users);
    app.addListener(_syncSearchHistory);
    session.addListener(_syncSearchHistory);
    users.addListener(_syncSearchHistory);
    _syncSearchHistory();
  }

  void _syncSearchHistory() {
    searchHistory.bind(
      generation: app.accountGeneration,
      active:
          session.hasSession &&
          !session.pendingSessionClear &&
          !app.authBusy &&
          !app.isRestoringSession,
      userId:
          app.authenticatedUser?.id ??
          (users.accountVersion == app.accountGeneration
              ? users.user?.id
              : null),
    );
  }

  late final SearchHistoryRepository searchHistory;
  late final SessionRepository session;
  bool _disposed = false;
  late final ShareCoordinator sharing;
  late final ContentRepository content;
  late final UserRepository users;
  late final AccountInitializationAction initializeAccount;
  late final ContentActions contentActions;
  late final AppViewModel app;
  late final HomeViewModel home;
  late final ArchiveViewModel archive;
  late final BookmarkViewModel bookmark;
  late final SearchViewModel search;
  late final DetailViewModel detail;
  late final ContentSaveViewModel save;
  late final CategoryManagementViewModel categories;
  late final AccountViewModel account;

  List<ViewModel> get featureViewModels => [
    sharing,
    home,
    archive,
    bookmark,
    search,
    detail,
    save,
    categories,
    account,
  ];

  void dispose() {
    _disposed = true;
    app.removeListener(sharing.sessionSettled);
    session.removeListener(sharing.sessionSettled);
    app.removeListener(_syncSearchHistory);
    session.removeListener(_syncSearchHistory);
    users.removeListener(_syncSearchHistory);
    app.dispose();
    for (final viewModel in featureViewModels) {
      viewModel.dispose();
    }
    searchHistory.dispose();
    initializeAccount.dispose();
    contentActions.dispose();
    content.dispose();
    users.dispose();
    session.dispose();
  }
}
