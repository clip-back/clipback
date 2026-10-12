import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:clipback_frontend/shared/presentation/view_model.dart';

class AccountViewModel extends ViewModel {
  AccountViewModel(this.repository) {
    repository.addListener(notifyListeners);
  }
  final UserRepository repository;

  AppUser get user => repository.user == null
      ? defaultUser
      : userFromApi(
          repository.user!,
          repository.stats ??
              const ApiUserStats(savedCount: 0, reopenedCount: 0),
        );

  @override
  void dispose() {
    repository.removeListener(notifyListeners);
    super.dispose();
  }
}
