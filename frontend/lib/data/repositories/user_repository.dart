import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../clipback_api.dart';
import '../services/api_request_scope.dart';

enum UserStatsStatus { idle, loading, success, failure }

abstract class UserRepository extends ChangeNotifier {
  ApiUser? get user;
  ApiUserStats? get stats;
  UserStatsStatus get statsStatus;
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
  UserStatsStatus _statsStatus = UserStatsStatus.idle;
  ApiRequestScope? _statsScope;
  Future<ApiUserStats>? _statsRequest;
  int _statsVersion = 0;
  int _accountVersion = 0;
  int _refreshVersion = 0;
  bool _disposed = false;

  @override
  ApiUser? get user => _user;
  @override
  ApiUserStats? get stats => _stats;
  @override
  UserStatsStatus get statsStatus => _statsStatus;
  @override
  int get accountVersion => _accountVersion;

  bool _current(int accountVersion) =>
      !_disposed && accountVersion == _accountVersion;

  @override
  void resetAccount(int generation) {
    _accountVersion = generation;
    _refreshVersion++;
    _statsVersion++;
    _statsScope?.cancel();
    _statsScope = null;
    _statsRequest = null;
    _statsStatus = UserStatsStatus.idle;
    _user = null;
    _stats = null;
    if (!_disposed) notifyListeners();
  }

  @override
  Future<ApiUser> loadMe() async {
    final generation = _accountVersion;
    final refreshVersion = _refreshVersion;
    final user = await _api.readMe();
    if (_current(generation) && refreshVersion == _refreshVersion) {
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
  Future<ApiUserStats> loadStats({bool apply = true}) {
    ApiRequestScope.current?.checkActive();
    if (_statsScope?.isActive == true && _statsRequest != null) {
      return _statsRequest!;
    }
    final generation = _accountVersion;
    final refreshVersion = _refreshVersion;
    final version = ++_statsVersion;
    final parent = ApiRequestScope.current;
    final scope = ApiRequestScope(timeout: const Duration(seconds: 10));
    _statsScope = scope;
    bool current() =>
        _current(generation) &&
        refreshVersion == _refreshVersion &&
        version == _statsVersion;
    if (parent != null) {
      unawaited(parent.cancelled.then((_) => scope.cancel()));
    }
    if (apply) {
      _statsStatus = UserStatsStatus.loading;
      notifyListeners();
    }
    late final Future<ApiUserStats> request;
    request = scope
        .run(() => _api.readStats())
        .then((stats) {
          if (apply && current() && scope.isActive) {
            _stats = stats;
            _statsStatus = UserStatsStatus.success;
            notifyListeners();
          }
          return stats;
        })
        .catchError((Object error) {
          if (apply && current()) {
            _statsStatus = UserStatsStatus.failure;
            notifyListeners();
          }
          throw error;
        })
        .whenComplete(() {
          scope.cancel();
          if (identical(_statsRequest, request)) {
            _statsScope = null;
            _statsRequest = null;
          }
        });
    _statsRequest = request;
    return request;
  }

  @override
  Future<void> refresh({required bool Function() isCurrent}) async {
    if (_disposed || !isCurrent()) return;
    final generation = _accountVersion;
    final refreshVersion = ++_refreshVersion;
    _statsScope?.cancel();
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
      _statsStatus = UserStatsStatus.success;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _statsScope?.cancel();
    super.dispose();
  }
}
