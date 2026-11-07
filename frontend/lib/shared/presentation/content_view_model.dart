import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:clipback_frontend/shared/presentation/view_model.dart';

/// Projects one shared repository; it never owns another data cache or writes.
class ContentViewModel extends ViewModel {
  ContentViewModel(this.repository) {
    repository.addListener(repositoryChanged);
  }

  final ContentRepository repository;

  List<CategoryItem> get categories => repository.categories.map((category) {
    final deleting = repository.categoryMutationDeleting(category.id);
    // Edits lock silently; only deletion shows text.
    return categoryFromApi(
      category,
      isMutating: deleting != null,
      mutationLabel: deleting == true ? '삭제 중…' : null,
    );
  }).toList();

  Set<String> get bookmarkedIds => {
    for (final id in repository.bookmarkedIds) 'api-$id',
  };

  ContentItem present(ApiContent item) {
    final currentCategories = categories;
    final mutation = repository.contentMutationKind(item.id);
    return contentFromApi(
      item,
      {
        for (final category in currentCategories)
          if (category.id != null) category.id!: category,
      },
      uncategorized: currentCategories
          .where((item) => item.name == catUncategorized.name)
          .firstOrNull,
      // Favorite and category writes lock silently; only deletion shows text.
      isMutating: mutation != null,
      mutationLabel: mutation == ContentMutationKind.delete ? '삭제 중…' : null,
    );
  }

  void repositoryChanged() => notifyListeners();

  @override
  void dispose() {
    repository.removeListener(repositoryChanged);
    super.dispose();
  }
}

class FeedViewModel extends ContentViewModel {
  FeedViewModel(super.repository, this.key) {
    _project();
  }

  final FeedKey key;
  final FeedPage page = FeedPage();

  void _project() {
    final state = repository.feed(key);
    page.project(state, state.items.map(present).toList());
  }

  @override
  void repositoryChanged() {
    _project();
    super.repositoryChanged();
  }

  Future<void> loadMore() => repository.loadNext(key);
  Future<void> retry() => repository.loadNext(key, reset: page.invalidCursor);
  void ensureLoaded() => repository.ensureFeed(key);
}
