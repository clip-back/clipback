import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/services/api_request_scope.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:clipback_frontend/shared/presentation/view_model.dart';
import 'package:flutter/foundation.dart';

/// Owns the weekly-recommendation visit: one per account and app process.
/// App start loads it before home is shown ([prepare]); otherwise the first
/// home frame starts it. Leaving home keeps the visit, its cards, recorded
/// exposures and a failure notice deferred until home is visible again.
class HomeWeeklyViewModel extends ViewModel {
  HomeWeeklyViewModel(
    this.repository, {
    required this.isHome,
    required this.isVisible,
    required this.accountGeneration,
    required this.afterFrame,
  });

  /// The app start waits this long at most, like the initial home load.
  static const prepareTimeout = Duration(seconds: 15);

  final ContentRepository repository;
  final bool Function() isHome;
  final bool Function() isVisible;
  final int Function() accountGeneration;
  final void Function(VoidCallback) afterFrame;

  Object? _visit, _request, _pendingFailure;
  Future<void>? _loading;
  ApiRequestScope? _prepareScope;
  int _generation = -1;

  bool _owns(Object visit) =>
      !isDisposed &&
      identical(_visit, visit) &&
      _generation == accountGeneration();

  List<ApiWeeklyRecommendationItem> get items =>
      _visit == null ? const [] : repository.weekly?.items ?? const [];

  void sync() {
    if (_visit != null && _generation != accountGeneration()) _end();
    if (isHome() && _visit == null) {
      final visit = _begin();
      afterFrame(() {
        if (_owns(visit)) unawaited(_load(visit));
      });
    }
  }

  /// Starts this account's visit and loads it while the app start's loading
  /// screen is shown. Completes after the response, a failure or
  /// [prepareTimeout]; never throws. The request runs in its own scope like
  /// the initial home load, so a timed-out request (and its authentication
  /// refresh) ends; its visit is replaced, so a late response is ignored, and
  /// the failure notice waits for home. An existing visit sends no request.
  Future<void> prepare() async {
    if (isDisposed) return;
    if (_visit != null && _generation != accountGeneration()) _end();
    final visit = _visit ?? _begin();
    if (repository.weekly != null || _pendingFailure != null) return;
    final scope = ApiRequestScope(
      timeout: prepareTimeout,
      isCurrent: () => _owns(visit),
    );
    _prepareScope?.cancel();
    _prepareScope = scope;
    try {
      await scope.run(() => scope.wait(_load(visit)));
    } catch (_) {
      if (_owns(visit) && _loading != null) _abandon();
    } finally {
      scope.cancel();
      if (identical(_prepareScope, scope)) _prepareScope = null;
    }
  }

  void visibilityChanged() => _showFailure();

  ValueChanged<int> exposureAction() {
    final visit = _visit;
    return (id) {
      if (visit != null && _owns(visit) && isVisible()) {
        repository.recordWeeklyExposure(visit, id);
      }
    };
  }

  ValueChanged<ApiWeeklyRecommendationItem> selectionAction(
    ValueChanged<ApiWeeklyRecommendationItem> open,
  ) {
    final visit = _visit;
    return (item) {
      if (visit == null ||
          !_owns(visit) ||
          !isVisible() ||
          !(repository.weekly?.items.any(
                (c) => c.id == item.id && c.category.id == item.category.id,
              ) ??
              false)) {
        return;
      }
      open(item);
    };
  }

  @override
  void dispose() {
    _prepareScope?.cancel();
    super.dispose();
  }

  Object _begin() {
    _generation = accountGeneration();
    return _visit = repository.beginWeeklyVisit();
  }

  void _end() {
    // Cleared first: endWeeklyVisit notifies synchronously and re-enters sync.
    final old = _visit;
    _visit = null;
    _request = null;
    _loading = null;
    _pendingFailure = null;
    _prepareScope?.cancel();
    if (old != null) repository.endWeeklyVisit(old);
  }

  /// Ends the timed-out request's visit and keeps the account's visit with a
  /// fresh token, so the late response cannot fill it.
  void _abandon() {
    _end();
    _pendingFailure = _begin();
    _showFailure();
  }

  Future<void> _load(Object visit) {
    if (!_owns(visit)) return Future.value();
    final pending = _loading;
    if (pending != null) return pending;
    final request = Object();
    _request = request;
    final loading = () async {
      try {
        await repository.loadWeekly(visit);
      } catch (_) {
        if (_owns(visit) && identical(_request, request)) {
          _pendingFailure = visit;
          _showFailure();
        }
      } finally {
        if (identical(_request, request)) {
          _request = null;
          _loading = null;
        }
      }
    }();
    if (identical(_request, request)) _loading = loading;
    return loading;
  }

  void _showFailure() {
    final visit = _pendingFailure;
    if (isDisposed || visit == null || !isVisible() || !_owns(visit)) return;
    // Cleared before emitting: emitEffect notifies synchronously.
    _pendingFailure = null;
    emitEffect(
      MessageEffect(
        '이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.',
        // Only from home: a notice still shown after leaving home asks nothing.
        retry: () {
          if (_owns(visit) && isVisible()) unawaited(_load(visit));
        },
      ),
    );
  }
}
