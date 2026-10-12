import 'dart:async';
import 'dart:math' as math;

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:flutter/foundation.dart';

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
  RefreshTicket beginRefresh();
  Future<RefreshResult> refresh(RefreshTicket ticket);
  bool isCurrentRefresh(RefreshTicket ticket);
  ContentMutationHandle? beginBookmark(int contentId);
  ContentMutationHandle? beginContentCategoryChange(
    int contentId,
    int categoryId,
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
  Future<ApiCategory?> createCategory({required String name, String? color});
  Future<ApiContent> saveLink({required String url, int? categoryId});
  Future<ApiContent> saveScreenshot({
    required Uint8List bytes,
    required String filename,
    int? categoryId,
  });
  void insertSavedContent(ApiContent content);
  DetailHandle openDetail(ApiContent content);
  void closeDetail();
  bool isCurrentDetail(DetailHandle handle);
  Future<bool> refreshDetail(DetailHandle handle);
  Future<Uint8List> readAsset(DetailHandle handle, int assetId);
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
  bool favoritePhase = true;
  String? nextCursor;
  bool initialized = false;
  bool loading = false;
  bool hasMore = true;
  Object? error;
  int version = 0;
  Future<void>? pending;

  void reset() {
    version++;
    items.clear();
    nextCursor = null;
    initialized = false;
    loading = false;
    hasMore = true;
    error = null;
    favoritePhase = true;
    pending = null;
  }

  FeedSnapshot snapshot() => FeedSnapshot(
    items: items,
    categoryId: categoryId,
    query: query,
    isFavorite: isFavorite,
    bookmarkedFirst: bookmarkedFirst,
    nextCursor: nextCursor,
    initialized: initialized,
    loading: loading,
    hasMore: hasMore,
    error: error,
    version: version,
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
  int _contentVersion = 0;
  int _detailVersion = 0;
  ApiContent? _selectedContent;
  DetailHandle? _detailHandle;
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
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _detailHandle = null;
    super.dispose();
  }

  @override
  void resetAccount(int version) {
    if (_disposed) return;
    _accountVersion = version;
    _contentVersion++;
    _contentChanges.clear();
    _contentReads.clear();
    _categoryMutations.clear();
    _deletedCategoryIds.clear();
    _categoryRefreshRequired = false;
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
    final account = _accountVersion;
    final response = await _api.listCategories();
    if (_disposed || account != _accountVersion) return;
    _categories
      ..clear()
      ..addAll(_reconcileCategoryList(response));
    _notify();
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
        // Empty favorites fall through without prefetching the entire segment.
        do {
          final read = _beginContentRead();
          try {
            final response = await _api.readFeed(
              limit: 20,
              query: page.query,
              categoryId: page.categoryId,
              isFavorite: page.bookmarkedFirst
                  ? page.favoritePhase
                  : page.isFavorite,
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
            page.initialized = true;
            page.nextCursor = response.nextCursor;
            if (response.nextCursor == null) {
              if (page.bookmarkedFirst && page.favoritePhase) {
                page.favoritePhase = false;
              } else {
                page.hasMore = false;
              }
            }
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
  RefreshTicket beginRefresh() {
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
      page.reset();
      page.items.addAll(previousItems);
      page.loading = true;
      versions[entry.key] = page.version;
    }
    final ticket = RefreshTicket(
      accountVersion: _accountVersion,
      version: version,
      feedVersions: versions,
      categoryDetailsRequired: _categoryRefreshRequired,
    );
    _notify();
    return ticket;
  }

  @override
  bool isCurrentRefresh(RefreshTicket ticket) =>
      !_disposed &&
      ticket.accountVersion == _accountVersion &&
      ticket.version == _refreshVersion;

  @override
  Future<RefreshResult> refresh(RefreshTicket ticket) async {
    var metadataFailed = false;
    RefreshResult result() => RefreshResult(
      current: isCurrentRefresh(ticket),
      metadataFailed: metadataFailed,
      categoryDetailsRequired: ticket.categoryDetailsRequired,
    );
    if (!isCurrentRefresh(ticket)) return result();
    try {
      final response = await _api.listCategories();
      if (!isCurrentRefresh(ticket)) return result();
      _categories
        ..clear()
        ..addAll(_reconcileCategoryList(response));
      _notify();
    } catch (_) {
      metadataFailed = true;
      // Category metadata failure does not prevent the list refresh.
    }
    if (!isCurrentRefresh(ticket)) return result();
    await Future.wait(
      ticket.feedVersions.entries
          .where((entry) => _feeds[entry.key]!.version == entry.value)
          .map((entry) {
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

  @override
  ApiContent? currentContent(int id) {
    if (_selectedContent?.id == id) return _selectedContent;
    for (final page in _feeds.values) {
      for (final content in page.items) {
        if (content.id == id) return content;
      }
    }
    return null;
  }

  ContentMutationHandle? _beginContentMutation(
    int contentId,
    ContentMutationKind kind, {
    int? categoryId,
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
      targetCategoryId: categoryId,
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
    int categoryId,
  ) {
    if (_deletedCategoryIds.contains(categoryId) ||
        _categoryMutations[categoryId]?.handle.deleting == true) {
      return null;
    }
    final category = _categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    if (category == null) return null;
    final handle = _beginContentMutation(
      contentId,
      ContentMutationKind.category,
      categoryId: categoryId,
    );
    if (handle == null) return null;
    _contentChanges[contentId]!.category = (
      version: ++_contentVersion,
      value: [category],
    );
    _updateExistingContent(
      contentId,
      (item) => _copyContent(item, categories: [category]),
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
          response = await _api.updateContentCategories(id, [
            handle.targetCategoryId!,
          ]);
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

  void _normalizeLoadedCategories() {
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
  }) async {
    final account = _accountVersion;
    final created = await _api.createCategory(name: name, color: color);
    if (_disposed || account != _accountVersion) return null;
    _categories.insert(0, created);
    _notify();
    return created;
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
  Future<ApiContent> saveLink({required String url, int? categoryId}) => _save(
    () => _api.createContent(
      originalUrl: url,
      categoryIds: categoryId == null ? const [] : [categoryId],
    ),
  );

  @override
  Future<ApiContent> saveScreenshot({
    required Uint8List bytes,
    required String filename,
    int? categoryId,
  }) => _save(
    () => _api.uploadScreenshot(
      bytes: bytes,
      filename: filename,
      categoryIds: categoryId == null ? const [] : [categoryId],
    ),
  );

  @override
  void insertSavedContent(ApiContent content) {
    if (_disposed) return;
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
    final read = _beginContentRead();
    try {
      final response = await _api.readContent(handle.contentId);
      if (isCurrentDetail(handle) && refresh == _refreshVersion) {
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
);
