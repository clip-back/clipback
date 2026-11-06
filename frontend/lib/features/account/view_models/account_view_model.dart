import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:clipback_frontend/shared/presentation/view_model.dart';

class AccountViewModel extends ViewModel {
  AccountViewModel(this.repository) {
    repository.addListener(notifyListeners);
  }
  final UserRepository repository;

  AppUser get user => userFromApi(repository.user, repository.stats);

  String? get statsMessage => switch (repository.statsStatus) {
    UserStatsStatus.idle || UserStatsStatus.loading =>
      repository.stats == null ? '통계를 불러오는 중이에요' : '마지막 확인값 · 새로 불러오는 중',
    UserStatsStatus.failure =>
      repository.stats == null ? '통계를 불러오지 못했어요' : '마지막 확인값 · 새로 불러오지 못했어요',
    UserStatsStatus.success => null,
  };

  bool get canRetryStats => repository.statsStatus == UserStatsStatus.failure;

  int? _deletionContentCount;
  int? _deletionCategoryCount;
  int _deletionCountsVersion = 0;

  /// Null while loading or after a failure; the screen leaves that slot empty.
  int? get deletionContentCount => _deletionContentCount;
  int? get deletionCategoryCount => _deletionCategoryCount;

  /// Reads both counts for J04 independently; one failure keeps the other.
  void loadDeletionCounts() {
    final version = ++_deletionCountsVersion;
    final account = repository.accountVersion;
    _deletionContentCount = null;
    _deletionCategoryCount = null;
    notifyListeners();
    bool current() =>
        !isDisposed &&
        version == _deletionCountsVersion &&
        account == repository.accountVersion;
    repository.readDeletionContentCount().then((count) {
      if (!current()) return;
      _deletionContentCount = count;
      notifyListeners();
    }, onError: (Object _) {});
    repository.readDeletionCategoryCount().then((count) {
      if (!current()) return;
      _deletionCategoryCount = count;
      notifyListeners();
    }, onError: (Object _) {});
  }

  Future<void> retryStats() async {
    try {
      await repository.loadStats();
    } catch (_) {
      // The repository exposes the failure locally; authentication uses the API path.
    }
  }

  @override
  void dispose() {
    repository.removeListener(notifyListeners);
    super.dispose();
  }
}
