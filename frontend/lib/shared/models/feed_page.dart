import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';

/// One bounded list, including the query that owns its opaque server cursor.
class FeedPage {
  final List<ContentItem> items = [];
  int? categoryId;
  String? query;
  bool? isFavorite;
  bool bookmarkedFirst = false;
  String? nextCursor;
  int? totalCount;
  bool initialized = false;
  bool loading = false;
  bool hasMore = true;
  Object? error;
  int version = 0;
  double scrollOffset = 0;
  Future<void>? _pending;

  Future<void>? get pendingRequest => _pending;

  void trackRequest(Future<void> request) => _pending = request;
  void clearPendingRequest() => _pending = null;

  /// Server totals belong to the committed items, including during refresh.
  int? get displayTotalCount {
    final count = totalCount ?? (initialized && !hasMore ? items.length : null);
    return count == null ? null : (count < items.length ? items.length : count);
  }

  /// The whole unfiltered feed finished loading with nothing saved.
  bool get confirmedEmpty =>
      categoryId == null &&
      query == null &&
      isFavorite == null &&
      !hasMore &&
      nextCursor == null &&
      initialized &&
      !loading &&
      error == null &&
      items.isEmpty;

  bool get invalidCursor =>
      error is ClipbackApiException &&
      (error as ClipbackApiException).statusCode == 422;

  /// Updates this stable presentation object without resetting an unchanged query.
  void project(FeedSnapshot snapshot, List<ContentItem> contents) {
    if (version != snapshot.version) {
      scrollOffset = 0;
      _pending = null;
    }
    items
      ..clear()
      ..addAll(contents);
    categoryId = snapshot.categoryId;
    query = snapshot.query;
    isFavorite = snapshot.isFavorite;
    bookmarkedFirst = snapshot.bookmarkedFirst;
    nextCursor = snapshot.nextCursor;
    totalCount = snapshot.totalCount;
    initialized = snapshot.initialized;
    loading = snapshot.loading;
    hasMore = snapshot.hasMore;
    error = snapshot.error;
    version = snapshot.version;
  }

  void reset() {
    version++;
    items.clear();
    nextCursor = null;
    totalCount = null;
    initialized = false;
    loading = false;
    hasMore = true;
    error = null;
    scrollOffset = 0;
    _pending = null;
  }
}
