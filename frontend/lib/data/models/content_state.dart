import 'package:clipback_frontend/clipback_api.dart';

enum FeedKey { home, archive, bookmark, search }

/// An immutable view of one query and the pages already read for it.
class FeedSnapshot {
  FeedSnapshot({
    required List<ApiContent> items,
    required this.categoryId,
    required this.query,
    required this.isFavorite,
    required this.bookmarkedFirst,
    required this.nextCursor,
    required this.initialized,
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.version,
  }) : items = List.unmodifiable(items);

  final List<ApiContent> items;
  final int? categoryId;
  final String? query;
  final bool? isFavorite;
  final bool bookmarkedFirst;
  final String? nextCursor;
  final bool initialized;
  final bool loading;
  final bool hasMore;
  final Object? error;
  final int version;
}

enum ContentMutationKind { bookmark, category, delete }

class ContentMutationHandle {
  const ContentMutationHandle({
    required this.original,
    required this.kind,
    required this.accountVersion,
    this.targetCategoryId,
  });

  final ApiContent original;
  final ContentMutationKind kind;
  final int accountVersion;
  final int? targetCategoryId;
}

class CategoryMutationHandle {
  const CategoryMutationHandle({
    required this.original,
    required this.accountVersion,
    required this.deleting,
    required this.name,
    required this.color,
  });

  final ApiCategory original;
  final int accountVersion;
  final bool deleting;
  final String name;
  final String? color;
}

class MutationResult {
  const MutationResult.success()
    : succeeded = true,
      stale = false,
      error = null;
  const MutationResult.stale() : succeeded = false, stale = true, error = null;
  const MutationResult.failure(this.error) : succeeded = false, stale = false;

  final bool succeeded;
  final bool stale;
  final Object? error;
}

class RefreshTicket {
  RefreshTicket({
    required this.accountVersion,
    required this.version,
    required Map<FeedKey, int> feedVersions,
    required this.categoryDetailsRequired,
    this.preserveViewport = false,
  }) : feedVersions = Map.unmodifiable(feedVersions);

  final int accountVersion;
  final int version;
  final Map<FeedKey, int> feedVersions;
  final bool categoryDetailsRequired;
  final bool preserveViewport;
}

class RefreshResult {
  const RefreshResult({
    required this.current,
    required this.metadataFailed,
    required this.categoryDetailsRequired,
  });

  final bool current;
  final bool metadataFailed;
  final bool categoryDetailsRequired;
}

class DetailHandle {
  const DetailHandle({
    required this.accountVersion,
    required this.version,
    required this.contentId,
  });

  final int accountVersion;
  final int version;
  final int contentId;
}
