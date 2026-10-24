import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/data/services/api_request_scope.dart';

class AccountInitializationAction {
  AccountInitializationAction(this.content, this.users);

  final ContentRepository content;
  final UserRepository users;
  bool _disposed = false;
  ApiRequestScope? _metadataScope;

  void dispose() {
    _disposed = true;
    _metadataScope?.cancel();
  }

  void reset(int generation) {
    if (_disposed) return;
    _metadataScope?.cancel();
    content.resetAccount(generation);
    users.resetAccount(generation);
  }

  Future<void> load({
    bool waitForMetadata = true,
    void Function()? onUserLoaded,
  }) async {
    if (_disposed) return;
    _metadataScope?.cancel();
    final generation = content.accountVersion;
    bool current() => !_disposed && generation == content.accountVersion;
    await content.loadCategories();
    if (!current()) return;
    await content.loadNext(FeedKey.home, reset: true);
    if (!current()) return;
    final error = content.feed(FeedKey.home).error;
    if (error != null) throw error;
    if (waitForMetadata) {
      await _loadMetadata(current, onUserLoaded);
      return;
    }
    final scope = ApiRequestScope(timeout: const Duration(seconds: 10));
    _metadataScope = scope;
    unawaited(
      scope
          .run(
            () => _loadMetadata(
              () =>
                  current() &&
                  identical(_metadataScope, scope) &&
                  scope.isActive,
              onUserLoaded,
            ),
          )
          .catchError((Object _) {
            // Authentication errors already follow the API session invalidation path.
          })
          .whenComplete(() {
            scope.cancel();
            if (identical(_metadataScope, scope)) _metadataScope = null;
          }),
    );
  }

  Future<void> _loadMetadata(
    bool Function() current,
    void Function()? onUserLoaded,
  ) async {
    var loadedUser = false;
    try {
      await users.loadMe();
      loadedUser = true;
      if (current()) onUserLoaded?.call();
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
