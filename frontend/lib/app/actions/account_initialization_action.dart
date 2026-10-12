import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';

class AccountInitializationAction {
  AccountInitializationAction(this.content, this.users);

  final ContentRepository content;
  final UserRepository users;
  bool _disposed = false;

  void dispose() => _disposed = true;

  void reset(int generation) {
    if (_disposed) return;
    content.resetAccount(generation);
    users.resetAccount(generation);
  }

  Future<void> load() async {
    if (_disposed) return;
    final generation = content.accountVersion;
    bool current() => !_disposed && generation == content.accountVersion;
    await content.loadCategories();
    if (!current()) return;
    await content.loadNext(FeedKey.home, reset: true);
    if (!current()) return;
    final error = content.feed(FeedKey.home).error;
    if (error != null) throw error;
    var loadedUser = false;
    try {
      await users.loadMe();
      loadedUser = true;
    } catch (error) {
      if (!current()) return;
      if (error is ClipbackApiException && error.statusCode == 401) rethrow;
    }
    if (!current()) return;
    try {
      await users.loadStats(apply: loadedUser);
    } catch (error) {
      if (!current()) return;
      if (error is ClipbackApiException && error.statusCode == 401) rethrow;
    }
  }
}
