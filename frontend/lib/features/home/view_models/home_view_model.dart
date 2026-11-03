import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';

class HomeViewModel extends FeedViewModel {
  HomeViewModel(ContentRepository repository, this.actions)
    : super(repository, FeedKey.home) {
    // Registered first, so it runs on the new page before other listeners.
    addListener(_rememberHero);
    _rememberHero();
  }

  bool _emptyHero = false;

  /// Whether home last settled on the C02 hero; unknown counts as C01.
  /// Kept here so it survives leaving the home tab.
  bool get emptyHero => _emptyHero;

  void _rememberHero() {
    if (page.items.isNotEmpty) {
      _emptyHero = false;
    } else if (page.confirmedEmpty) {
      _emptyHero = true;
    }
  }

  Future<void> selectCategory(CategoryItem? category) async {
    if (category?.id != null && repository.isCategoryDeleted(category!.id!)) {
      return;
    }
    // Drop the previous filter's result first so the new filter is never
    // observed with it (an empty chip would otherwise read as confirmed zero).
    repository.resetFeed(key);
    repository.configureFeed(key, categoryId: category?.id);
    await repository.loadNext(key, reset: true);
  }

  @override
  Future<void> retry() => repository.loadNext(key, reset: true);

  final ContentActions actions;

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
}
