import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';

class SearchViewModel extends FeedViewModel {
  SearchViewModel(ContentRepository repository, this.actions)
    : super(repository, FeedKey.search);

  String query = '';

  void open() => changeQuery('');

  void changeQuery(String value) {
    query = value;
    repository.resetFeed(key);
    repository.configureFeed(key);
    notifyListeners();
  }

  Future<List<ContentItem>> search(String value) async {
    repository.configureFeed(key, query: value.trim());
    await repository.loadNext(key, reset: true);
    return List.of(page.items);
  }

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
