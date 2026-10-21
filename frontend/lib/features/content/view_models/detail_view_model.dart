import 'dart:async';
import 'dart:typed_data';

import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/services/original_link_opener.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';

class DetailViewModel extends ContentViewModel {
  DetailViewModel(
    super.repository,
    this.actions, {
    OriginalLinkOpener? originalLinkOpener,
  }) : _originalLinkOpener =
           originalLinkOpener ?? const PlatformOriginalLinkOpener();

  final ContentActions actions;
  final OriginalLinkOpener _originalLinkOpener;
  Object? _originalOpening;
  DetailHandle? _handle;
  FeedKey? _source;
  FeedPage? _sourcePage;
  int _navigationVersion = 0;
  bool _active = false;
  bool moving = false;

  ContentItem? get content => !_active || repository.selectedContent == null
      ? null
      : present(repository.selectedContent!);
  FeedPage? get feed => _sourcePage;
  FeedKey? get source => _source;
  List<ContentItem> get contents => _sourcePage?.items ?? const [];
  bool get bookmarked =>
      repository.bookmarkedIds.contains(repository.selectedContent?.id);

  @override
  void repositoryChanged() {
    if (_active && _handle != null && !repository.isCurrentDetail(_handle!)) {
      final sameAccount = _handle!.accountVersion == repository.accountVersion;
      // A new open sets its handle after the synchronous repository notification.
      if (repository.selectedContent == null) {
        _active = false;
        _handle = null;
        _navigationVersion++;
        moving = false;
        _source = null;
        _sourcePage = null;
        if (sameAccount) emitEffect(const DetailDeletedEffect());
      }
    }
    super.repositoryChanged();
  }

  /// Returns whether a current item was selected; rejected opens leave it unchanged.
  bool open(
    ContentItem item, {
    required FeedKey source,
    required FeedPage sourcePage,
    bool recordView = true,
  }) {
    if (isDisposed || item.apiId == null) return false;
    final current = repository.currentContent(item.apiId!);
    if (current == null) return false;
    _source = source;
    _sourcePage = sourcePage;
    _active = true;
    _originalOpening = null;
    _navigationVersion++;
    moving = false;
    _handle = repository.openDetail(current);
    notifyListeners();
    if (recordView) {
      unawaited(repository.refreshDetail(_handle!));
      repository.recordOpen(current);
    }
    return true;
  }

  void close() {
    _originalOpening = null;
    _active = false;
    _handle = null;
    _source = null;
    _sourcePage = null;
    _navigationVersion++;
    moving = false;
    repository.closeDetail();
    notifyListeners();
  }

  Future<void> move(int delta) async {
    final current = content;
    final source = _source;
    final page = _sourcePage;
    if (isDisposed ||
        current == null ||
        source == null ||
        page == null ||
        moving) {
      return;
    }
    final index = page.items.indexWhere((item) => item.id == current.id);
    if (index == -1) return;
    final navigationVersion = _navigationVersion;
    final pageVersion = page.version;
    moving = true;
    notifyListeners();
    if (delta > 0 && index + 1 == page.items.length && page.hasMore) {
      await repository.loadNext(source);
    }
    if (isDisposed || navigationVersion != _navigationVersion) return;
    moving = false;
    notifyListeners();
    if (!_active || content?.id != current.id || pageVersion != page.version) {
      return;
    }
    final nextIndex = index + delta;
    if (nextIndex >= 0 && nextIndex < page.items.length) {
      open(page.items[nextIndex], source: source, sourcePage: page);
    }
  }

  Future<void> retry() async {
    if (feed?.invalidCursor ?? false) {
      await repository.loadNext(_source!, reset: true);
    } else {
      await move(1);
    }
  }

  Future<Uint8List> readAsset(int assetId) async {
    final handle = _handle;
    final version = _navigationVersion;
    if (!_active || handle == null || isDisposed) {
      throw const ClipbackApiException('화면이 변경되어 원본 조회를 취소했어요.');
    }
    final bytes = await repository.readAsset(handle, assetId);
    if (!_active || isDisposed || version != _navigationVersion) {
      throw const ClipbackApiException('화면이 변경되어 원본 조회를 취소했어요.');
    }
    return bytes;
  }

  /// Bind the action to this visit, including close/reopen of the same content.
  void Function() originalLinkAction() {
    final handle = _handle;
    final version = _navigationVersion;
    return () {
      if (!_ownsOriginalAction(handle, version)) return;
      unawaited(_openOriginalLink(handle!, version));
    };
  }

  bool _ownsOriginalAction(DetailHandle? handle, int version) =>
      !isDisposed &&
      _active &&
      handle != null &&
      identical(_handle, handle) &&
      version == _navigationVersion &&
      repository.isCurrentDetail(handle);

  Future<void> _openOriginalLink(DetailHandle handle, int version) async {
    if (_originalOpening != null) return;
    final snapshot = repository.currentContent(handle.contentId);
    if (snapshot == null || snapshot.contentType != 'link') return;
    final token = Object();
    _originalOpening = token;
    const message = '원본 링크를 열지 못했어요. 다시 시도해 주세요.';
    try {
      final uri = Uri.tryParse((snapshot.originalUrl ?? '').trim());
      final valid =
          uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority &&
          uri.host.isNotEmpty;
      final accepted = valid && await _originalLinkOpener.open(uri);
      if (!_ownsOriginalAction(handle, version)) return;
      if (accepted) {
        repository.recordOriginalLinkOpened(snapshot.id);
      } else {
        emitEffect(const MessageEffect(message));
      }
    } catch (_) {
      if (_ownsOriginalAction(handle, version)) {
        emitEffect(const MessageEffect(message));
      }
    } finally {
      // An older completion must not unlock a new detail's pending launch.
      if (identical(_originalOpening, token)) _originalOpening = null;
    }
  }

  Future<void> toggleBookmark(ContentItem item) async {
    if (!isDisposed && item.apiId != null) {
      await actions.toggleBookmark(item.apiId!, emitEffect);
    }
  }

  Future<void> changeCategory(ContentItem item, CategoryItem category) async {
    if (!isDisposed && item.apiId != null && category.id != null) {
      await actions.changeCategory(item.apiId!, category.id!, emitEffect);
    }
  }

  Future<void> deleteContent(ContentItem item) async {
    if (!isDisposed && item.apiId != null) {
      await actions.deleteContent(item.apiId!, emitEffect);
    }
  }

  @override
  void dispose() {
    _originalOpening = null;
    _navigationVersion++;
    _active = false;
    _handle = null;
    super.dispose();
  }
}
