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

  List<CategoryItem> get categories => [
    for (final category in repository.categories)
      categoryFromApi(
        category,
        mutationLabel: switch (repository.categoryMutationDeleting(
          category.id,
        )) {
          true => '삭제 중…',
          false => '변경 중…',
          null => null,
        },
      ),
  ];

  Set<String> get bookmarkedIds => {
    for (final id in repository.bookmarkedIds) 'api-$id',
  };

  ContentItem present(ApiContent item) {
    final currentCategories = categories;
    return contentFromApi(
      item,
      {
        for (final category in currentCategories)
          if (category.id != null) category.id!: category,
      },
      uncategorized: currentCategories
          .where((item) => item.name == catUncategorized.name)
          .firstOrNull,
      mutationLabel: switch (repository.contentMutationKind(item.id)) {
        ContentMutationKind.delete => '삭제 중…',
        ContentMutationKind.bookmark || ContentMutationKind.category => '변경 중…',
        null => null,
      },
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
