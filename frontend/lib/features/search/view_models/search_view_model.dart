import 'package:clipback_frontend/data/repositories/search_history_repository.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';

class SearchViewModel extends FeedViewModel {
  SearchViewModel(ContentRepository repository, this.actions, {this.history})
    : super(repository, FeedKey.search) {
    history?.addListener(notifyListeners);
  }
  final SearchHistoryRepository? history;
  List<String> get recentTerms => history?.terms ?? const [];
  Object? get historyOwner => history?.owner;
  void removeRecentTerm(String term) => history?.remove(term);
  @override
  void dispose() {
    history?.removeListener(notifyListeners);
    super.dispose();
  }

  String query = '';

  void open() {
    history?.open();
    changeQuery('');
  }

  void changeQuery(String value) {
    query = value;
    repository.resetFeed(key);
    repository.configureFeed(key);
    notifyListeners();
  }

  Future<List<ContentItem>> search(String value) async {
    final term = value.trim();
    if (isDisposed || term.isEmpty) return const [];
    history?.record(term);
    repository.configureFeed(key, query: term);
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
