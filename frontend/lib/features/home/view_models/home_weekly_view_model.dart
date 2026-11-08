import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:clipback_frontend/shared/presentation/view_model.dart';
import 'package:flutter/foundation.dart';

/// Owns one home weekly-recommendation visit: its start and end, the load
/// after the first frame, and a failure notice deferred while home is covered.
class HomeWeeklyViewModel extends ViewModel {
  HomeWeeklyViewModel(
    this.repository, {
    required this.isHome,
    required this.isVisible,
    required this.accountGeneration,
    required this.afterFrame,
  });

  final ContentRepository repository;
  final bool Function() isHome;
  final bool Function() isVisible;
  final int Function() accountGeneration;
  final void Function(VoidCallback) afterFrame;

  Object? _visit, _request, _pendingFailure;
  int _generation = -1;

  bool _owns(Object visit) =>
      !isDisposed &&
      isHome() &&
      identical(_visit, visit) &&
      _generation == accountGeneration();

  List<ApiWeeklyRecommendationItem> get items =>
      _visit == null ? const [] : repository.weekly?.items ?? const [];

  void sync() {
    if (!isHome() || _generation != accountGeneration()) {
      // Cleared first: endWeeklyVisit notifies synchronously and re-enters sync.
      final old = _visit;
      _visit = null;
      _request = null;
      _pendingFailure = null;
      if (old != null) repository.endWeeklyVisit(old);
    }
    if (isHome() && _visit == null) {
      _generation = accountGeneration();
      final visit = repository.beginWeeklyVisit();
      _visit = visit;
      afterFrame(() {
        if (_owns(visit)) unawaited(_load(visit));
      });
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

  Future<void> _load(Object visit) async {
    if (!_owns(visit) || _request != null) return;
    final request = Object();
    _request = request;
    try {
      await repository.loadWeekly(visit);
    } catch (_) {
      if (_owns(visit)) {
        _pendingFailure = visit;
        _showFailure();
      }
    } finally {
      if (identical(_request, request)) _request = null;
    }
  }

  void _showFailure() {
    final visit = _pendingFailure;
    if (isDisposed || visit == null || !isVisible() || !_owns(visit)) return;
    // Cleared before emitting: emitEffect notifies synchronously.
    _pendingFailure = null;
    emitEffect(
      MessageEffect(
        '이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.',
        retry: () {
          if (_owns(visit)) unawaited(_load(visit));
        },
      ),
    );
  }
}
