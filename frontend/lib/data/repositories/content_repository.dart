import 'dart:async';
import 'dart:math' as math;

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:flutter/foundation.dart';
import '../services/event_uuid.dart';
import '../services/api_request_scope.dart';

class CategoryReadSuperseded extends ClipbackApiException {
  const CategoryReadSuperseded() : super('Category read is no longer current');
}

/// The raw accepted response retains its read/account ownership through callers.
class CategoryServerSnapshot {
  CategoryServerSnapshot(List<ApiCategory> categories, this._isCurrent)
    : categories = List.unmodifiable(categories);

  final List<ApiCategory> categories;
  final bool Function() _isCurrent;
  bool get current => _isCurrent();
}

abstract class ContentRepository extends ChangeNotifier {
  int get accountVersion;
  int get refreshVersion;
  List<ApiCategory> get categories;
  Set<int> get bookmarkedIds;
  ApiContent? get selectedContent;
  DetailHandle? get currentDetailHandle;
  FeedSnapshot feed(FeedKey key);
  ApiContent? currentContent(int id);
  ContentMutationKind? contentMutationKind(int id);
  bool? categoryMutationDeleting(int id);
  bool isCategoryDeleted(int id);
  void resetAccount(int version);
  Future<void> loadCategories();
  Future<CategoryServerSnapshot> readCurrentCategories();
  void configureFeed(
    FeedKey key, {
    int? categoryId,
    String? query,
    bool? isFavorite,
    bool bookmarkedFirst = false,
  });
  void resetFeed(FeedKey key);
  Future<void> loadNext(FeedKey key, {bool reset = false});
  void ensureFeed(FeedKey key);
  RefreshTicket beginRefresh({bool preserveViewport = false});

  /// Re-reads the shown, settled lists and categories without spinner or
  /// error state (#460). Applies them together only when every read succeeds;
  /// returns false when it did not run or did not apply.
  Future<bool> refreshInBackground();
  Future<RefreshResult> refresh(
    RefreshTicket ticket, {
    bool includeCategories = true,
  });
  bool isCurrentRefresh(RefreshTicket ticket);
  ContentMutationHandle? beginBookmark(int contentId);
  ContentMutationHandle? beginContentCategoryChange(
    int contentId,
    List<int> categoryIds,
  );
  ContentMutationHandle? beginContentDelete(int contentId);
  Future<MutationResult> executeContentMutation(ContentMutationHandle handle);
  void finishContentMutation(ContentMutationHandle handle);
  CategoryMutationHandle? beginCategoryUpdate(
    int id, {
    required String name,
    required String? color,
  });
  CategoryMutationHandle? beginCategoryDelete(int id);
  Future<MutationResult> executeCategoryMutation(CategoryMutationHandle handle);
  void finishCategoryMutation(CategoryMutationHandle handle);
  Future<ApiCategory?> createCategory({
    required String name,
    String? color,
    String? submissionKey,
  });
  Future<ApiCategory?> updateCategorySubmission({
    required int categoryId,
    required String name,
    required String color,
    required String submissionKey,
  });
  Future<ApiContent> saveLink({
    required String url,
    String? submissionKey,
    int? categoryId,
  });
  Future<ApiContent> saveScreenshot({
    required Uint8List bytes,
    required String filename,
    String? submissionKey,
    int? categoryId,
  });
  void insertSavedContent(ApiContent content);
  DetailHandle openDetail(ApiContent content);
  void closeDetail();
  bool isCurrentDetail(DetailHandle handle);
  Future<bool> refreshDetail(DetailHandle handle);
  Future<Uint8List> readAsset(DetailHandle handle, int assetId);
  ApiWeeklyRecommendation? get weekly;
  Object beginWeeklyVisit();
  void endWeeklyVisit(Object visit);
  Future<void> loadWeekly(Object visit);
  void recordWeeklyExposure(Object visit, int itemId);
  ApiTodayRecommendation? get today;
  int get todayVersion;
  Future<ApiTodayRecommendation?> loadToday({
    required bool Function() isCurrent,
  });
  Future<ApiContent?> readTodayContent(
    int id, {
    required bool Function() isCurrent,
  });
  void removeTodayContent(int id);
  void recordRecommendationOpen(ApiContent content, int recommendationItemId);
  void recordOpen(ApiContent content);
  void recordCategoryFilter(int categoryId);
  void recordOriginalLinkOpened(int contentId);
}

class _FeedState {
  final items = <ApiContent>[];
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
  int viewportVersion = 0;
  int foregroundReads = 0;
  Future<void>? pending;

  // Filter identity for a background re-read; a change cancels it.
  (String?, int?, bool?, bool) get filter =>
      (query, categoryId, isFavorite, bookmarkedFirst);

  void reset({bool preserveViewport = false}) {
    version++;
    if (!preserveViewport) {
      viewportVersion++;
      nextCursor = null;
      totalCount = null;
      initialized = false;
      hasMore = true;
    }
    items.clear();
    loading = false;
    error = null;
    pending = null;
  }

  FeedSnapshot snapshot() => FeedSnapshot(
    items: items,
    categoryId: categoryId,
    query: query,
    isFavorite: isFavorite,
    bookmarkedFirst: bookmarkedFirst,
    nextCursor: nextCursor,
    totalCount: totalCount,
    initialized: initialized,
    loading: loading,
    hasMore: hasMore,
    error: error,
    version: viewportVersion,
    foregroundReads: foregroundReads,
  );
}

class _ContentChange {
  ContentMutationHandle? pending;
  bool requestFinished = false;
  ({int version, bool value})? bookmark;
  ({int version, List<ApiCategory> value})? category;
  int? deletedVersion;
}

class _CategoryChange {
  _CategoryChange(this.handle, this.value);
  final CategoryMutationHandle handle;
  ApiCategory value;
}

/// Owns only the four loaded feeds, one detail, and temporary change journals.
class RemoteContentRepository extends ContentRepository {
  RemoteContentRepository(this._api) {
    _feeds[FeedKey.bookmark]!.isFavorite = true;
  }

  final ClipbackApi _api;
  final _feeds = {for (final key in FeedKey.values) key: _FeedState()};
  final _categories = <ApiCategory>[];
  final _bookmarkedIds = <int>{};
  final _contentChanges = <int, _ContentChange>{};
  final _contentReads = <Object, int>{};
  final _categoryMutations = <int, _CategoryChange>{};
  final _deletedCategoryIds = <int>{};
  bool _categoryRefreshRequired = false;
  int _accountVersion = 0;
  int _refreshVersion = 0;
  int _categoryReadVersion = 0;
  // Background re-reads (#460): each one gets a generation; a newer one, or a
  // user read of one of its lists, cancels it so its replies are discarded.
  int _backgroundGeneration = 0;
  Set<FeedKey> _backgroundTargets = const {};
  // Owns the background re-read's HTTP requests. Its GETs never refresh the
  // login (decision A: a 401 just ends them); cancelling the scope ends the
  // requests still waiting, its sibling lists and the wait for an earlier
  // user category read, so a batch that can no longer be published stops.
  ApiRequestScope? _backgroundScope;
  // Whether the running background batch could still be published. Checked
  // on every change notice so the events that make it unpublishable cancel it.
  bool Function()? _backgroundPublishable;
  ApiRequestScope? _categoryReadScope;
  int _contentVersion = 0;
  int _detailVersion = 0;
  int _detailReadOrder = 0;
  int _detailAppliedRead = 0;
  ApiContent? _selectedContent;
  DetailHandle? _detailHandle;
  ApiWeeklyRecommendation? _weekly;
  Object? _weeklyVisit;
  int _weeklyRequest = 0;
  Future<void>? _weeklyPending;
  final _weeklyExposures = <int, String>{};
  @override
  ApiWeeklyRecommendation? get weekly => _weekly;
  ApiTodayRecommendation? _today;
  int _todayVersion = 0;
  int _todayRequest = 0;
  @override
  ApiTodayRecommendation? get today => _today;
  @override
  int get todayVersion => _todayVersion;
  bool _disposed = false;

  @override
  int get accountVersion => _accountVersion;
  @override
  int get refreshVersion => _refreshVersion;
  @override
  List<ApiCategory> get categories => List.unmodifiable(_categories);
  @override
  Set<int> get bookmarkedIds => Set.unmodifiable(_bookmarkedIds);
  @override
  ApiContent? get selectedContent => _selectedContent;
  @override
  DetailHandle? get currentDetailHandle => _detailHandle;
  @override
  FeedSnapshot feed(FeedKey key) => _feeds[key]!.snapshot();
  @override
  ContentMutationKind? contentMutationKind(int id) =>
      _contentChanges[id]?.pending?.kind;
  @override
  bool? categoryMutationDeleting(int id) =>
      _categoryMutations[id]?.handle.deleting;
  @override
  bool isCategoryDeleted(int id) => _deletedCategoryIds.contains(id);

  void _notify() {
    _recheckBackground();
    if (!_disposed) notifyListeners();
  }

  // An account reset, filter change, list reset, refresh, category read or a
  // replaced shown card makes the background batch unpublishable: end its
  // requests and waits now instead of when a late reply arrives.
  void _recheckBackground() {
    final publishable = _backgroundPublishable;
    if (publishable != null && !publishable()) _cancelBackground();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelBackground();
    _categoryReadScope?.cancel();
    _detailHandle = null;
    super.dispose();
  }

  @override
  void resetAccount(int version) {
    if (_disposed) return;
    _accountVersion = version;
    _weekly = null;
    _weeklyVisit = null;
    _weeklyRequest++;
    _weeklyPending = null;
    _weeklyExposures.clear();
    _today = null;
    _todayVersion++;
    _todayRequest++;
    _contentVersion++;
    _contentChanges.clear();
    _contentReads.clear();
    _categoryMutations.clear();
    _deletedCategoryIds.clear();
    _categoryRefreshRequired = false;
    _categoryReadScope?.cancel();
    _categoryReadVersion++;
    _refreshVersion++;
    _detailVersion++;
    _detailHandle = null;
    _selectedContent = null;
    for (final page in _feeds.values) {
      page.reset();
      page.categoryId = null;
      page.query = null;
    }
    _categories.clear();
    _bookmarkedIds.clear();
    _notify();
  }

  @override
  Future<void> loadCategories() async {
    await _loadCategories();
  }

  /// Accepted server values, before optimistic display reconciliation.
  @override
  Future<CategoryServerSnapshot> readCurrentCategories() async {
    final response = await _loadCategories();
    if (response == null || !response.current) {
      throw const CategoryReadSuperseded();
    }
    return response;
  }

  Future<CategoryServerSnapshot?> _loadCategories({
    bool Function()? isCurrent,
  }) async {
    final account = _accountVersion;
    final read = ++_categoryReadVersion;
    // A user category read wins over a background batch.
    _recheckBackground();
    final owner = ApiRequestScope.current;
    _categoryReadScope?.cancel();
    bool current() =>
        !_disposed &&
        account == _accountVersion &&
        read == _categoryReadVersion &&
        (isCurrent?.call() ?? true);
    final scope = ApiRequestScope(
      isCurrent: () => current() && (owner?.isActive ?? true),
    );
    _categoryReadScope = scope;
    if (owner != null) {
      unawaited(owner.cancelled.then((_) => scope.cancel()));
    }
    try {
      final response = await scope.run(_api.listCategories);
      if (_disposed || account != _accountVersion) return null;
      scope.checkActive();
      _categories
        ..clear()
        ..addAll(_reconcileCategoryList(response));
      _notify();
      scope.checkActive();
      return CategoryServerSnapshot(
        response,
        () => current() && (owner?.isActive ?? true),
      );
    } catch (error) {
      if (!current() && error is! ClipbackApiException) {
        throw const CategoryReadSuperseded();
      }
      rethrow;
    } finally {
      scope.cancel();
      if (identical(_categoryReadScope, scope)) _categoryReadScope = null;
    }
  }

  /// Replaces the whole filter; loading/resetting remains an explicit command.
  @override
  void configureFeed(
    FeedKey key, {
    int? categoryId,
    String? query,
    bool? isFavorite,
    bool bookmarkedFirst = false,
  }) {
    if (_disposed || _deletedCategoryIds.contains(categoryId)) return;
    final page = _feeds[key]!;
    page.categoryId = categoryId;
    page.query = query;
    page.isFavorite = isFavorite;
    page.bookmarkedFirst = bookmarkedFirst;
    _notify();
  }

  @override
  void resetFeed(FeedKey key) {
    if (_disposed) return;
    _feeds[key]!.reset();
    _notify();
  }

  @override
  Future<void> loadNext(FeedKey key, {bool reset = false}) {
    if (_disposed) return Future.value();
    final page = _feeds[key]!;
    if (reset) page.reset();
    // A user read wins over a background re-read of the same list: cancel it
    // and continue from the shown items and cursor.
    if (_backgroundTargets.contains(key)) _cancelBackground();
    if (page.pending != null) return page.pending!;
    // Metadata is still loading for a write-triggered first-page refresh.
    if (page.loading || !page.hasMore || _disposed) return Future.value();
    final version = page.version;
    final account = _accountVersion;
    bool current() =>
        !_disposed && version == page.version && account == _accountVersion;
    final completion = Completer<void>();
    page.pending = completion.future;
    page.loading = true;
    page.error = null;
    _notify();
    unawaited(() async {
      try {
        do {
          final read = _beginContentRead();
          try {
            final response = await _api.readFeed(
              limit: 20,
              query: page.query,
              categoryId: page.categoryId,
              isFavorite: page.isFavorite,
              sort: page.bookmarkedFirst ? 'favorites_first' : null,
              cursor: page.nextCursor,
            );
            if (!current()) return;
            if (!page.initialized) page.items.clear();
            final knownIds = page.items.map((item) => item.id).toSet();
            for (final raw in response.items) {
              final item = _reconcileContentRead(raw, read.version);
              if (item == null) continue;
              if (knownIds.add(item.id)) page.items.add(item);
              _trackBookmark(item);
            }
            page.totalCount =
                response.totalCount ??
                (response.nextCursor == null ? page.items.length : null);
            page.initialized = true;
            page.nextCursor = response.nextCursor;
            page.hasMore = response.nextCursor != null;
            _notify();
          } finally {
            _endContentRead(read.key);
          }
        } while (page.items.isEmpty && page.hasMore);
      } catch (error) {
        if (current()) {
          page.error = error;
          _notify();
        }
      } finally {
        if (current()) {
          page.loading = false;
          page.pending = null;
          _notify();
        }
        completion.complete();
      }
    }());
    return completion.future;
  }

  @override
  void ensureFeed(FeedKey key) {
    final page = _feeds[key]!;
    if (!page.initialized && !page.loading && page.error == null) {
      unawaited(loadNext(key));
    }
  }

  @override
  RefreshTicket beginRefresh({bool preserveViewport = false}) {
    if (_disposed) {
      return RefreshTicket(
        accountVersion: _accountVersion,
        version: _refreshVersion,
        feedVersions: const {},
        categoryDetailsRequired: false,
      );
    }
    final version = ++_refreshVersion;
    final pages = _feeds.entries.where(
      (entry) =>
          entry.key == FeedKey.home ||
          entry.value.initialized ||
          entry.value.loading ||
          entry.value.error != null,
    );
    final versions = <FeedKey, int>{};
    for (final entry in pages) {
      final page = entry.value;
      final previousItems = List<ApiContent>.of(page.items);
      // Older pages must be invalidated before category metadata is requested.
      final previousTotalCount = page.totalCount;
      page.reset(preserveViewport: preserveViewport);
      page.totalCount = previousTotalCount;
      page.items.addAll(previousItems);
      page.loading = true;
      versions[entry.key] = page.version;
    }
    final ticket = RefreshTicket(
      accountVersion: _accountVersion,
      version: version,
      feedVersions: versions,
      categoryDetailsRequired: _categoryRefreshRequired,
      preserveViewport: preserveViewport,
    );
    _notify();
    return ticket;
  }

  void _cancelBackground() {
    _backgroundGeneration++;
    _backgroundTargets = const {};
    _backgroundPublishable = null;
    _backgroundScope?.cancel();
    _backgroundScope = null;
  }

  @override
  Future<bool> refreshInBackground() async {
    if (_disposed ||
        _feeds.values.any((page) => page.loading || page.pending != null)) {
      // A user or caller read owns the lists; it shows its own result.
      return false;
    }
    // A failed page keeps its error and retry; an unread page stays unread.
    final targets = [
      for (final entry in _feeds.entries)
        if (entry.value.initialized && entry.value.error == null)
          (
            key: entry.key,
            page: entry.value,
            version: entry.value.version,
            filter: entry.value.filter,
            shown: List<ApiContent>.of(entry.value.items),
          ),
    ];
    if (targets.isEmpty) return false;
    // A newer re-entry replaces an older background read still waiting.
    _cancelBackground();
    final generation = _backgroundGeneration;
    _backgroundTargets = {for (final target in targets) target.key};
    final account = _accountVersion;
    final refreshVersion = _refreshVersion;
    final categoryRead = _categoryReadVersion;
    bool current() =>
        !_disposed &&
        generation == _backgroundGeneration &&
        account == _accountVersion &&
        refreshVersion == _refreshVersion &&
        targets.every(
          (target) =>
              target.page.version == target.version &&
              target.page.filter == target.filter,
        );
    // A newer detail, today or change reply replaced a shown item; this
    // older snapshot must not undo it.
    bool unchanged() => targets.every((target) {
      final items = target.page.items;
      if (items.length != target.shown.length) return false;
      for (var i = 0; i < items.length; i++) {
        if (!identical(items[i], target.shown[i])) return false;
      }
      return true;
    });
    // Ends the requests as soon as this batch can no longer be published:
    // replaced, a user category read started, or a shown card was replaced.
    bool publishable() =>
        current() && categoryRead == _categoryReadVersion && unchanged();
    final scope = ApiRequestScope(isCurrent: publishable);
    _backgroundScope = scope;
    _backgroundPublishable = publishable;
    final read = _beginContentRead();
    try {
      // One failing list ends the batch at once; the scope then ends the
      // sibling requests still waiting.
      final staged = await Future.wait([
        for (final target in targets)
          scope.run(() => _readShownPages(target.page, publishable)),
      ], eagerError: true);
      if (!publishable()) return false;
      // Read directly, once with the current access token: a user category
      // read is neither cancelled nor superseded, and nothing is published
      // before the lists.
      final categories = await scope.run(_api.listCategoriesOnce);
      // A user category read that started earlier publishes first; this
      // newer batch follows it so an older count cannot overwrite it. A
      // cancelled batch stops waiting at once.
      for (
        var user = _categoryReadScope;
        user != null && publishable();
        user = _categoryReadScope
      ) {
        await Future.any([user.cancelled, scope.cancelled]);
      }
      if (!publishable()) return false;
      // The batch publishes now; its own change notice must not cancel it.
      _backgroundPublishable = null;
      _categories
        ..clear()
        ..addAll(_reconcileCategoryList(categories));
      for (var i = 0; i < targets.length; i++) {
        final page = targets[i].page;
        final (items, cursor, totalCount, hasMore) = staged[i];
        final reconciled = <int, ApiContent>{};
        for (final raw in items) {
          final item = _reconcileContentRead(raw, read.version);
          if (item != null) {
            reconciled[item.id] = item;
            _trackBookmark(item);
          }
        }
        page.items
          ..clear()
          ..addAll(reconciled.values);
        page.totalCount = totalCount ?? (!hasMore ? reconciled.length : null);
        page.nextCursor = cursor;
        page.hasMore = hasMore;
      }
      _notify();
      return true;
    } catch (_) {
      // Keep every list as shown; the next resume or re-entry tries again.
      return false;
    } finally {
      _endContentRead(read.key);
      scope.cancel();
      if (generation == _backgroundGeneration) {
        _backgroundTargets = const {};
        _backgroundScope = null;
        _backgroundPublishable = null;
      }
    }
  }

  /// Reads the shown extent of one list for a background re-read. Checks the
  /// generation before every request and after every reply, and fails when a
  /// page makes no progress (a next cursor this list already used).
  Future<(List<ApiContent>, String?, int?, bool)> _readShownPages(
    _FeedState page,
    bool Function() current,
  ) async {
    final targetCount = page.items.length;
    final items = <ApiContent>[];
    String? cursor;
    int? totalCount;
    var hasMore = true;
    final used = <String>{};
    do {
      if (!current()) throw const _BackgroundCancelled();
      final sent = cursor;
      if (sent != null) used.add(sent);
      final response = await _api.readFeedStrict(
        limit: 20,
        query: page.query,
        categoryId: page.categoryId,
        isFavorite: page.isFavorite,
        sort: page.bookmarkedFirst ? 'favorites_first' : null,
        cursor: sent,
      );
      if (!current()) throw const _BackgroundCancelled();
      items.addAll(response.items);
      totalCount = response.totalCount;
      cursor = response.nextCursor;
      hasMore = cursor != null;
      if (hasMore && used.contains(cursor)) {
        throw StateError('Feed cursor made no progress');
      }
    } while (hasMore && (items.isEmpty || items.length < targetCount));
    return (items, cursor, totalCount, hasMore);
  }

  @override
  bool isCurrentRefresh(RefreshTicket ticket) =>
      !_disposed &&
      ticket.accountVersion == _accountVersion &&
      ticket.version == _refreshVersion;

  @override
  Future<RefreshResult> refresh(
    RefreshTicket ticket, {
    bool includeCategories = true,
  }) async {
    var metadataFailed = false;
    RefreshResult result() => RefreshResult(
      current: isCurrentRefresh(ticket),
      metadataFailed: metadataFailed,
      categoryDetailsRequired: ticket.categoryDetailsRequired,
    );
    if (!isCurrentRefresh(ticket)) return result();
    if (includeCategories) {
      try {
        await _loadCategories(isCurrent: () => isCurrentRefresh(ticket));
      } on CategoryReadSuperseded {
        // The newer category read owns metadata; keep this caller's feed refresh.
      } catch (_) {
        metadataFailed = true;
        // Category metadata failure does not prevent the list refresh.
      }
    }
    if (!isCurrentRefresh(ticket)) return result();
    await Future.wait(
      ticket.feedVersions.entries
          .where((entry) => _feeds[entry.key]!.version == entry.value)
          .map((entry) {
            if (ticket.preserveViewport) {
              return _refreshVisiblePages(entry.key, entry.value, ticket);
            }
            _feeds[entry.key]!.loading = false;
            return loadNext(entry.key);
          }),
    );
    if (!isCurrentRefresh(ticket)) return result();
    final detail = _detailHandle;
    if (ticket.categoryDetailsRequired && detail != null) {
      if (!await refreshDetail(detail)) metadataFailed = true;
    }
    if (!isCurrentRefresh(ticket)) return result();
    if (ticket.categoryDetailsRequired) {
      _categoryRefreshRequired = metadataFailed;
    }
    return result();
  }

  /// Read the already visible extent off-screen, then replace it atomically.
  /// Keeping old items until all pages arrive avoids scroll clamping mid-refresh.
  Future<void> _refreshVisiblePages(
    FeedKey key,
    int version,
    RefreshTicket ticket,
  ) async {
    final page = _feeds[key]!;
    final targetCount = page.items.length;
    final read = _beginContentRead();
    bool current() => isCurrentRefresh(ticket) && page.version == version;
    final items = <ApiContent>[];
    String? cursor;
    int? totalCount;
    var hasMore = true;
    try {
      do {
        final response = await _api.readFeed(
          limit: 20,
          query: page.query,
          categoryId: page.categoryId,
          isFavorite: page.isFavorite,
          sort: page.bookmarkedFirst ? 'favorites_first' : null,
          cursor: cursor,
        );
        if (!current()) return;
        items.addAll(response.items);
        totalCount = response.totalCount;
        cursor = response.nextCursor;
        hasMore = cursor != null;
      } while (hasMore && (items.isEmpty || items.length < targetCount));
      if (!current()) return;
      final reconciled = <int, ApiContent>{};
      for (final raw in items) {
        final item = _reconcileContentRead(raw, read.version);
        if (item != null) {
          reconciled[item.id] = item;
          _trackBookmark(item);
        }
      }
      page.items
        ..clear()
        ..addAll(reconciled.values);
      page.totalCount = totalCount ?? (!hasMore ? reconciled.length : null);
      page.nextCursor = cursor;
      page.hasMore = hasMore;
      page.initialized = true;
      page.foregroundReads++;
    } catch (error) {
      if (current()) page.error = error;
    } finally {
      _endContentRead(read.key);
      if (current()) {
        page.loading = false;
        _notify();
      }
    }
  }

  @override
  ApiContent? currentContent(int id) {
    if (_selectedContent?.id == id) return _selectedContent;
    for (final page in _feeds.values) {
      for (final content in page.items) {
        if (content.id == id) return content;
      }
    }
    return _today?.items
        .where((item) => item.content.id == id)
        .firstOrNull
        ?.content;
  }

  ContentMutationHandle? _beginContentMutation(
    int contentId,
    ContentMutationKind kind, {
    List<int>? categoryIds,
  }) {
    final current = currentContent(contentId);
    if (_disposed ||
        current == null ||
        _contentChanges[contentId]?.pending != null) {
      return null;
    }
    final handle = ContentMutationHandle(
      original: current,
      kind: kind,
      accountVersion: _accountVersion,
      targetCategoryIds: categoryIds,
    );
    final change = _contentChanges[contentId] ??= _ContentChange();
    change.pending = handle;
    change.requestFinished = false;
    return handle;
  }

  @override
  ContentMutationHandle? beginBookmark(int contentId) {
    final handle = _beginContentMutation(
      contentId,
      ContentMutationKind.bookmark,
    );
    if (handle == null) return null;
    final next = !handle.original.isFavorite;
    _contentChanges[contentId]!.bookmark = (
      version: ++_contentVersion,
      value: next,
    );
    _updateExistingContent(
      contentId,
      (item) => _copyContent(item, isFavorite: next),
    );
    return handle;
  }

  @override
  ContentMutationHandle? beginContentCategoryChange(
    int contentId,
    List<int> categoryIds,
  ) {
    final ids = categoryIds.toSet().toList();
    final categories = <ApiCategory>[];
    for (final id in ids) {
      final category = _categories.where((item) => item.id == id).firstOrNull;
      if (category == null ||
          _deletedCategoryIds.contains(id) ||
          _categoryMutations[id]?.handle.deleting == true) {
        return null;
      }
      categories.add(category);
    }
    // 미분류 cannot share a content with another category.
    if (categories.length > 1 && categories.any((item) => item.name == '미분류')) {
      return null;
    }
    final handle = _beginContentMutation(
      contentId,
      ContentMutationKind.category,
      categoryIds: ids,
    );
    if (handle == null) return null;
    _contentChanges[contentId]!.category = (
      version: ++_contentVersion,
      value: categories,
    );
    _updateExistingContent(
      contentId,
      (item) => _copyContent(item, categories: categories),
    );
    return handle;
  }

  @override
  ContentMutationHandle? beginContentDelete(int contentId) {
    final handle = _beginContentMutation(contentId, ContentMutationKind.delete);
    if (handle != null) _notify();
    return handle;
  }

  bool _isCurrentMutation(ContentMutationHandle handle) =>
      !_disposed &&
      handle.accountVersion == _accountVersion &&
      identical(_contentChanges[handle.original.id]?.pending, handle);

  @override
  Future<MutationResult> executeContentMutation(
    ContentMutationHandle handle,
  ) async {
    if (!_isCurrentMutation(handle)) return const MutationResult.stale();
    final id = handle.original.id;
    ApiContent? response;
    try {
      switch (handle.kind) {
        case ContentMutationKind.bookmark:
          response = await _api.updateContentFavorite(
            id,
            !handle.original.isFavorite,
          );
        case ContentMutationKind.category:
          response = await _api.updateContentCategories(
            id,
            handle.targetCategoryIds!,
          );
        case ContentMutationKind.delete:
          await _api.deleteContent(id);
      }
    } catch (error) {
      if (!_isCurrentMutation(handle)) return const MutationResult.stale();
      final change = _contentChanges[id]!;
      change.requestFinished = true;
      final version = ++_contentVersion;
      switch (handle.kind) {
        case ContentMutationKind.bookmark:
          change.bookmark = (
            version: version,
            value: handle.original.isFavorite,
          );
          _updateExistingContent(
            id,
            (item) =>
                _copyContent(item, isFavorite: handle.original.isFavorite),
          );
        case ContentMutationKind.category:
          change.category = (
            version: version,
            value: handle.original.categories,
          );
          _updateExistingContent(
            id,
            (item) =>
                _copyContent(item, categories: handle.original.categories),
          );
        case ContentMutationKind.delete:
          break;
      }
      return MutationResult.failure(error);
    }
    if (!_isCurrentMutation(handle)) return const MutationResult.stale();
    final change = _contentChanges[id]!;
    change.requestFinished = true;
    final version = ++_contentVersion;
    if (handle.kind == ContentMutationKind.delete) {
      change.deletedVersion = version;
      for (final page in _feeds.values) {
        page.items.removeWhere((item) => item.id == id);
      }
      _today = _today?.mapContents((item) => item.id == id ? null : item);
      _bookmarkedIds.remove(id);
      if (_selectedContent?.id == id) {
        _detailVersion++;
        _detailHandle = null;
        _selectedContent = null;
      }
      _notify();
    } else {
      final updated = _normalizeContentCategories(response!);
      if (handle.kind == ContentMutationKind.bookmark) {
        change.bookmark = (version: version, value: updated.isFavorite);
      } else {
        change.category = (version: version, value: updated.categories);
      }
      _replaceContent(updated);
    }
    return const MutationResult.success();
  }

  @override
  void finishContentMutation(ContentMutationHandle handle) {
    if (!_isCurrentMutation(handle)) return;
    _contentChanges[handle.original.id]!.pending = null;
    _updateExistingContent(handle.original.id, (item) => item);
    _pruneContentChanges();
  }

  ApiCategory _applyCategoryState(ApiCategory category) {
    final pending = _categoryMutations[category.id];
    if (pending == null) return category;
    return _copyCategory(
      category,
      name: pending.value.name,
      color: pending.value.color,
    );
  }

  List<ApiCategory> _reconcileCategoryList(List<ApiCategory> response) {
    final result = response
        .where((item) => !_deletedCategoryIds.contains(item.id))
        .map(_applyCategoryState)
        .toList();
    // A read may observe a commit before the DELETE response acknowledges it.
    for (final mutation in _categoryMutations.values) {
      final id = mutation.handle.original.id;
      if (!_deletedCategoryIds.contains(id) &&
          !result.any((item) => item.id == id)) {
        result.add(_applyCategoryState(mutation.value));
      }
    }
    return result;
  }

  ApiContent _normalizeContentCategories(ApiContent content) {
    final current = {for (final category in _categories) category.id: category};
    final categories = content.categories
        .where((item) => !_deletedCategoryIds.contains(item.id))
        .map((item) => _applyCategoryState(current[item.id] ?? item))
        .toList();
    if (categories.isEmpty) {
      final uncategorized = _categories
          .where((item) => item.name == '미분류')
          .firstOrNull;
      if (uncategorized != null) categories.add(uncategorized);
    }
    return _copyContent(content, categories: List.unmodifiable(categories));
  }

  void _normalizeWeekly() {
    _weekly = _weekly?.mapCategories(
      (category) => _deletedCategoryIds.contains(category.id)
          ? null
          : _applyCategoryState(category),
    );
  }

  void _normalizeLoadedCategories() {
    _normalizeWeekly();
    _today = _today?.mapContents(_normalizeContentCategories);
    for (final page in _feeds.values) {
      for (var index = 0; index < page.items.length; index++) {
        page.items[index] = _normalizeContentCategories(page.items[index]);
      }
    }
    if (_selectedContent != null) {
      _selectedContent = _normalizeContentCategories(_selectedContent!);
    }
  }

  CategoryMutationHandle? _beginCategoryMutation(
    int id, {
    required bool deleting,
    String? name,
    String? color,
  }) {
    final current = _categories.where((item) => item.id == id).firstOrNull;
    if (_disposed ||
        current == null ||
        current.name == '미분류' ||
        _deletedCategoryIds.contains(id) ||
        _categoryMutations.containsKey(id)) {
      return null;
    }
    final handle = CategoryMutationHandle(
      original: current,
      accountVersion: _accountVersion,
      deleting: deleting,
      name: name ?? current.name,
      color: color ?? current.color,
    );
    final value = _copyCategory(
      current,
      name: handle.name,
      color: handle.color,
    );
    _categoryReadVersion++;
    _categoryMutations[id] = _CategoryChange(handle, value);
    _replaceCategoryLocally(id, value);
    return handle;
  }

  @override
  CategoryMutationHandle? beginCategoryUpdate(
    int id, {
    required String name,
    required String? color,
  }) => _beginCategoryMutation(id, deleting: false, name: name, color: color);

  @override
  CategoryMutationHandle? beginCategoryDelete(int id) =>
      _beginCategoryMutation(id, deleting: true);

  bool _isCurrentCategoryMutation(CategoryMutationHandle handle) =>
      !_disposed &&
      handle.accountVersion == _accountVersion &&
      identical(_categoryMutations[handle.original.id]?.handle, handle);

  void _replaceCategoryLocally(int id, ApiCategory updated) {
    final index = _categories.indexWhere((item) => item.id == id);
    if (index != -1) _categories[index] = _applyCategoryState(updated);
    ApiContent replace(ApiContent content) => _normalizeContentCategories(
      _copyContent(
        content,
        categories: [
          for (final item in content.categories)
            if (item.id == id) updated else item,
        ],
      ),
    );
    for (final page in _feeds.values) {
      for (var index = 0; index < page.items.length; index++) {
        page.items[index] = replace(page.items[index]);
      }
    }
    _weekly = _weekly?.mapCategories(
      (category) => category.id == id ? updated : category,
    );
    _normalizeWeekly();
    _today = _today?.mapContents(replace);
    if (_selectedContent != null) _selectedContent = replace(_selectedContent!);
    _notify();
  }

  @override
  Future<MutationResult> executeCategoryMutation(
    CategoryMutationHandle handle,
  ) async {
    if (!_isCurrentCategoryMutation(handle)) {
      return const MutationResult.stale();
    }
    final id = handle.original.id;
    try {
      if (handle.deleting) {
        await _api.deleteCategory(id);
        if (!_isCurrentCategoryMutation(handle)) {
          return const MutationResult.stale();
        }
        _categoryReadVersion++;
        _deletedCategoryIds.add(id);
        _categories.removeWhere((item) => item.id == id);
        _normalizeLoadedCategories();
        for (final page in _feeds.values) {
          if (page.categoryId == id) page.categoryId = null;
        }
        _categoryRefreshRequired = true;
        _notify();
      } else {
        final saved = await _api.updateCategory(
          categoryId: id,
          name: handle.name,
          color: handle.color,
        );
        if (!_isCurrentCategoryMutation(handle)) {
          return const MutationResult.stale();
        }
        _categoryReadVersion++;
        final change = _categoryMutations[id]!;
        change.value = _copyCategory(
          change.value,
          name: saved.name,
          color: saved.color,
        );
        _replaceCategoryLocally(id, change.value);
      }
      return const MutationResult.success();
    } catch (error) {
      if (!_isCurrentCategoryMutation(handle)) {
        return const MutationResult.stale();
      }
      if (!handle.deleting) {
        _categoryMutations[id]!.value = handle.original;
        _replaceCategoryLocally(id, handle.original);
      }
      return MutationResult.failure(error);
    }
  }

  @override
  void finishCategoryMutation(CategoryMutationHandle handle) {
    if (!_isCurrentCategoryMutation(handle)) return;
    _categoryMutations.remove(handle.original.id);
    for (var index = 0; index < _categories.length; index++) {
      _categories[index] = _applyCategoryState(_categories[index]);
    }
    _normalizeLoadedCategories();
    _notify();
  }

  @override
  Future<ApiCategory?> createCategory({
    required String name,
    String? color,
    String? submissionKey,
  }) async {
    final account = _accountVersion;
    _categoryReadVersion++;
    final created = await _api.createCategory(
      name: name,
      color: color,
      submissionKey: submissionKey,
    );
    ApiRequestScope.current?.checkActive();
    if (_disposed || account != _accountVersion) return null;
    _categoryReadVersion++;
    if (!created.submissionReplayed) {
      _categories.insert(0, created);
      _notify();
    }
    return created;
  }

  @override
  Future<ApiCategory?> updateCategorySubmission({
    required int categoryId,
    required String name,
    required String color,
    required String submissionKey,
  }) async {
    final account = _accountVersion;
    final saved = await _api.updateCategory(
      categoryId: categoryId,
      name: name,
      color: color,
      submissionKey: submissionKey,
    );
    ApiRequestScope.current?.checkActive();
    if (_disposed || account != _accountVersion) return null;
    _categoryReadVersion++;
    final current = _categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    if (!saved.submissionReplayed && current != null) {
      _replaceCategoryLocally(
        categoryId,
        _copyCategory(current, name: saved.name, color: saved.color),
      );
    }
    return saved;
  }

  Future<ApiContent> _save(Future<ApiContent> Function() request) async {
    final account = _accountVersion;
    final result = await request();
    if (_disposed || account != _accountVersion) {
      throw const ClipbackApiException('계정이 변경되어 저장 결과를 표시하지 못했어요.');
    }
    return _normalizeContentCategories(result);
  }

  @override
  Future<ApiContent> saveLink({
    required String url,
    String? submissionKey,
    int? categoryId,
  }) => _save(
    () => _api.createContent(
      originalUrl: url,
      submissionKey: submissionKey,
      categoryIds: categoryId == null ? const [] : [categoryId],
    ),
  );

  @override
  Future<ApiContent> saveScreenshot({
    required Uint8List bytes,
    required String filename,
    String? submissionKey,
    int? categoryId,
  }) => _save(
    () => _api.uploadScreenshot(
      bytes: bytes,
      filename: filename,
      submissionKey: submissionKey,
      categoryIds: categoryId == null ? const [] : [categoryId],
    ),
  );

  @override
  void insertSavedContent(ApiContent content) {
    if (_disposed) return;
    _feeds[FeedKey.home]!.items.removeWhere((item) => item.id == content.id);
    _feeds[FeedKey.home]!.items.insert(0, _normalizeContentCategories(content));
    _notify();
  }

  @override
  DetailHandle openDetail(ApiContent content) {
    if (_disposed) {
      return DetailHandle(
        accountVersion: _accountVersion,
        version: _detailVersion,
        contentId: content.id,
      );
    }
    final handle = DetailHandle(
      accountVersion: _accountVersion,
      version: ++_detailVersion,
      contentId: content.id,
    );
    _detailHandle = handle;
    _selectedContent =
        currentContent(content.id) ?? _normalizeContentCategories(content);
    _notify();
    return handle;
  }

  @override
  void closeDetail() {
    if (_disposed) return;
    _detailVersion++;
    _detailHandle = null;
    _selectedContent = null;
    _notify();
  }

  @override
  bool isCurrentDetail(DetailHandle handle) =>
      !_disposed &&
      handle.accountVersion == _accountVersion &&
      identical(_detailHandle, handle);

  /// Returns false only for a failed read that still owns the active detail.
  @override
  Future<bool> refreshDetail(DetailHandle handle) async {
    if (!isCurrentDetail(handle)) return true;
    final refresh = _refreshVersion;
    // Detail reads apply in send order; a reply older than an applied one loses.
    final order = ++_detailReadOrder;
    final read = _beginContentRead();
    try {
      final response = await _api.readContent(handle.contentId);
      if (isCurrentDetail(handle) &&
          refresh == _refreshVersion &&
          order > _detailAppliedRead) {
        _detailAppliedRead = order;
        final updated = _reconcileContentRead(response, read.version);
        if (updated != null) _replaceContent(updated);
      }
      return true;
    } catch (_) {
      return !isCurrentDetail(handle) || refresh != _refreshVersion;
    } finally {
      _endContentRead(read.key);
    }
  }

  @override
  Future<Uint8List> readAsset(DetailHandle handle, int assetId) async {
    final bytes = await _api.readAsset(assetId);
    if (!isCurrentDetail(handle)) {
      throw const ClipbackApiException('화면이 변경되어 원본 조회를 취소했어요.');
    }
    return bytes;
  }

  @override
  Object beginWeeklyVisit() {
    final token = Object();
    _weeklyVisit = token;
    _weekly = null;
    _weeklyPending = null;
    _weeklyRequest++;
    _weeklyExposures.clear();
    return token;
  }

  @override
  void endWeeklyVisit(Object visit) {
    if (!identical(visit, _weeklyVisit)) return;
    _weeklyVisit = null;
    _weekly = null;
    _weeklyPending = null;
    _weeklyRequest++;
    _weeklyExposures.clear();
    _notify();
  }

  @override
  Future<void> loadWeekly(Object visit) {
    if (_disposed || !identical(visit, _weeklyVisit)) return Future.value();
    if (_weeklyPending != null) return _weeklyPending!;
    final account = _accountVersion, request = ++_weeklyRequest;
    bool current() =>
        !_disposed &&
        identical(visit, _weeklyVisit) &&
        account == _accountVersion &&
        request == _weeklyRequest;
    final task = () async {
      try {
        final response = await _api.readWeeklyRecommendation();
        if (!current()) return;
        _weekly = response;
        _normalizeWeekly();
        _notify();
      } catch (_) {
        if (current()) rethrow;
      } finally {
        if (current()) _weeklyPending = null;
      }
    }();
    _weeklyPending = task;
    return task;
  }

  @override
  void recordWeeklyExposure(Object visit, int itemId) {
    if (_disposed ||
        !identical(visit, _weeklyVisit) ||
        !(_weekly?.items.any((item) => item.id == itemId) ?? false) ||
        _weeklyExposures.containsKey(itemId)) {
      return;
    }
    final id = newEventUuid();
    _weeklyExposures[itemId] = id;
    // ClipbackApi's authentication refresh replays this captured body unchanged.
    _ignoreEventFailure(
      () => _api.recordRecommendationExposure(
        clientEventId: id,
        recommendationItemId: itemId,
      ),
    );
  }

  @override
  Future<ApiTodayRecommendation?> loadToday({
    required bool Function() isCurrent,
  }) async {
    final account = _accountVersion, request = ++_todayRequest;
    final read = _beginContentRead();
    bool current() =>
        !_disposed &&
        account == _accountVersion &&
        request == _todayRequest &&
        isCurrent();
    try {
      final response = await _api.readTodayRecommendation();
      if (!current()) return null;
      _today = response.mapContents(
        (item) => _reconcileContentRead(item, read.version),
      );
      _todayVersion++;
      // Update already-loaded copies without inserting into any feed.
      for (final item in _today!.items) {
        _replaceContent(item.content);
      }
      _notify();
      return _today;
    } finally {
      _endContentRead(read.key);
    }
  }

  @override
  Future<ApiContent?> readTodayContent(
    int id, {
    required bool Function() isCurrent,
  }) async {
    final account = _accountVersion, version = _todayVersion;
    final read = _beginContentRead();
    bool current() =>
        !_disposed &&
        account == _accountVersion &&
        version == _todayVersion &&
        isCurrent();
    try {
      final response = await _api.readContent(id);
      if (!current()) return null;
      final updated = _reconcileContentRead(response, read.version);
      if (updated != null) _replaceContent(updated);
      return updated;
    } on ClipbackApiException catch (error) {
      if (current() && error.statusCode == 404) removeTodayContent(id);
      rethrow;
    } finally {
      _endContentRead(read.key);
    }
  }

  @override
  void removeTodayContent(int id) {
    if (_disposed) return;
    _today = _today?.mapContents((item) => item.id == id ? null : item);
    _notify();
  }

  @override
  void recordRecommendationOpen(ApiContent content, int recommendationItemId) {
    final eventId = newEventUuid();
    _ignoreEventFailure(
      () => _api.recordRecommendationView(
        content.id,
        clientEventId: eventId,
        recommendationItemId: recommendationItemId,
      ),
    );
    _ignoreEventFailure(
      () => _api.createCardClickEvent(
        contentId: content.id,
        categoryId: content.categories.firstOrNull?.id,
      ),
    );
  }

  @override
  void recordOpen(ApiContent content) {
    _ignoreEventFailure(() => _api.recordContentView(content.id));
    _ignoreEventFailure(
      () => _api.createCardClickEvent(
        contentId: content.id,
        categoryId: content.categories.firstOrNull?.id,
      ),
    );
  }

  @override
  void recordCategoryFilter(int categoryId) =>
      _ignoreEventFailure(() => _api.createCategoryFilterEvent(categoryId));

  @override
  void recordOriginalLinkOpened(int contentId) =>
      _ignoreEventFailure(() => _api.createOriginalLinkOpenedEvent(contentId));

  void _ignoreEventFailure(Future<void> Function() event) {
    if (_disposed) return;
    unawaited(
      event().then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    );
  }

  void _trackBookmark(ApiContent content) {
    if (content.isFavorite) {
      _bookmarkedIds.add(content.id);
    } else {
      _bookmarkedIds.remove(content.id);
    }
  }

  void _updateExistingContent(int id, ApiContent Function(ApiContent) update) {
    if (_disposed) return;
    _today = _today?.mapContents(
      (item) =>
          item.id == id ? _normalizeContentCategories(update(item)) : item,
    );
    for (final page in _feeds.values) {
      final index = page.items.indexWhere((item) => item.id == id);
      if (index != -1) {
        page.items[index] = _normalizeContentCategories(
          update(page.items[index]),
        );
      }
    }
    if (_selectedContent?.id == id) {
      _selectedContent = _normalizeContentCategories(update(_selectedContent!));
    }
    final current = currentContent(id);
    final bookmarked =
        current?.isFavorite ?? _contentChanges[id]?.bookmark?.value;
    if (bookmarked != null) {
      if (bookmarked) {
        _bookmarkedIds.add(id);
      } else {
        _bookmarkedIds.remove(id);
      }
    }
    _notify();
  }

  void _replaceContent(ApiContent updated) {
    if (_disposed) return;
    updated = _normalizeContentCategories(updated);
    _today = _today?.mapContents(
      (item) => item.id == updated.id ? updated : item,
    );
    for (final page in _feeds.values) {
      final index = page.items.indexWhere((item) => item.id == updated.id);
      if (index != -1) page.items[index] = updated;
    }
    _trackBookmark(updated);
    if (_selectedContent?.id == updated.id) _selectedContent = updated;
    _notify();
  }

  ({Object key, int version}) _beginContentRead() {
    final key = Object();
    _contentReads[key] = _contentVersion;
    return (key: key, version: _contentVersion);
  }

  void _endContentRead(Object key) {
    _contentReads.remove(key);
    _pruneContentChanges();
  }

  void _pruneContentChanges() {
    final oldestRead = _contentReads.values.fold(_contentVersion, math.min);
    _contentChanges.removeWhere((id, change) {
      if (change.pending != null) return false;
      if ((change.bookmark?.version ?? 0) <= oldestRead) change.bookmark = null;
      if ((change.category?.version ?? 0) <= oldestRead) change.category = null;
      if ((change.deletedVersion ?? 0) <= oldestRead) {
        change.deletedVersion = null;
      }
      return change.bookmark == null &&
          change.category == null &&
          change.deletedVersion == null;
    });
  }

  ApiContent? _reconcileContentRead(ApiContent item, int readVersion) {
    final change = _contentChanges[item.id];
    if (change == null) return _normalizeContentCategories(item);
    if (change.deletedVersion != null && readVersion < change.deletedVersion!) {
      return null;
    }
    final pending = change.pending;
    final writing = pending != null && !change.requestFinished;
    final bookmark = change.bookmark;
    final category = change.category;
    return _normalizeContentCategories(
      _copyContent(
        item,
        isFavorite:
            bookmark != null &&
                (readVersion < bookmark.version ||
                    (writing && pending.kind == ContentMutationKind.bookmark))
            ? bookmark.value
            : null,
        categories:
            category != null &&
                (readVersion < category.version ||
                    (writing && pending.kind == ContentMutationKind.category))
            ? category.value
            : null,
      ),
    );
  }
}

ApiCategory _copyCategory(
  ApiCategory value, {
  required String name,
  required String? color,
}) => ApiCategory(
  id: value.id,
  name: name,
  color: color,
  isDefault: value.isDefault,
  contentCount: value.contentCount,
  lastSavedAt: value.lastSavedAt,
);

ApiContent _copyContent(
  ApiContent value, {
  bool? isFavorite,
  List<ApiCategory>? categories,
}) => ApiContent(
  id: value.id,
  categories: categories ?? value.categories,
  tags: value.tags,
  assets: value.assets,
  contentType: value.contentType,
  source: value.source,
  title: value.title,
  summary: value.summary,
  originalUrl: value.originalUrl,
  isFavorite: isFavorite ?? value.isFavorite,
  savedAt: value.savedAt,
  lastViewedAt: value.lastViewedAt,
  summaryStatus: value.summaryStatus,
  summaryErrorCode: value.summaryErrorCode,
);

class _BackgroundCancelled implements Exception {
  const _BackgroundCancelled();
}
