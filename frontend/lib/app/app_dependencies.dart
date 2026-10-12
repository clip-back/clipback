import '../clipback_api.dart';
import '../social_auth.dart';
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
  AppDependencies({ApiSessionStorage? storage, SocialAuth? socialAuth}) {
    final api = ClipbackApi(
      onSessionChanged: (_) => session.persistCurrentSession(),
      onSessionInvalidated: () => session.invalidate(),
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
    );
    home = HomeViewModel(content, contentActions);
    archive = ArchiveViewModel(content, contentActions);
    bookmark = BookmarkViewModel(content, contentActions);
    search = SearchViewModel(content, contentActions);
    detail = DetailViewModel(content, contentActions);
    save = ContentSaveViewModel(content, contentActions);
    categories = CategoryManagementViewModel(content, contentActions);
    account = AccountViewModel(users);
  }

  late final SessionRepository session;
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
    app.dispose();
    for (final viewModel in featureViewModels) {
      viewModel.dispose();
    }
    initializeAccount.dispose();
    contentActions.dispose();
    content.dispose();
    users.dispose();
    session.dispose();
  }
}
