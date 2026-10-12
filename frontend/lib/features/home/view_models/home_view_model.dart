import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';

class HomeViewModel extends FeedViewModel {
  HomeViewModel(ContentRepository repository, this.actions)
    : super(repository, FeedKey.home);

  Future<void> selectCategory(CategoryItem? category) async {
    if (category?.id != null && repository.isCategoryDeleted(category!.id!)) {
      return;
    }
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
