import 'package:flutter/foundation.dart';

import '../../clipback_api.dart';

abstract class UserRepository extends ChangeNotifier {
  ApiUser? get user;
  ApiUserStats? get stats;
  int get accountVersion;
  void resetAccount(int generation);
  Future<ApiUser> loadMe();
  Future<void> verifySession();
  Future<ApiUserStats> loadStats({bool apply = true});
  Future<void> refresh({required bool Function() isCurrent});
}

class RemoteUserRepository extends UserRepository {
  RemoteUserRepository({required ClipbackApi api}) : _api = api;

  final ClipbackApi _api;
  ApiUser? _user;
  ApiUserStats? _stats;
  int _accountVersion = 0;
  int _refreshVersion = 0;
  bool _disposed = false;

  @override
  ApiUser? get user => _user;
  @override
  ApiUserStats? get stats => _stats;
  @override
  int get accountVersion => _accountVersion;

  bool _current(int accountVersion) =>
      !_disposed && accountVersion == _accountVersion;

  @override
  void resetAccount(int generation) {
    _accountVersion = generation;
    _refreshVersion++;
    _user = null;
    _stats = null;
    if (!_disposed) notifyListeners();
  }

  @override
  Future<ApiUser> loadMe() async {
    final generation = _accountVersion;
    final user = await _api.readMe();
    if (_current(generation)) {
      _user = user;
      notifyListeners();
    }
    return user;
  }

  @override
  Future<void> verifySession() async {
    await _api.readMe();
  }

  @override
  Future<ApiUserStats> loadStats({bool apply = true}) async {
    final generation = _accountVersion;
    final stats = await _api.readStats();
    if (apply && _current(generation)) {
      _stats = stats;
      notifyListeners();
    }
    return stats;
  }

  @override
  Future<void> refresh({required bool Function() isCurrent}) async {
    if (_disposed || !isCurrent()) return;
    final generation = _accountVersion;
    final refreshVersion = ++_refreshVersion;
    bool current() =>
        _current(generation) &&
        refreshVersion == _refreshVersion &&
        isCurrent();
    final stats = await _api.readStats();
    if (!current()) return;
    final user = await _api.readMe();
    if (current()) {
      _user = user;
      _stats = stats;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
