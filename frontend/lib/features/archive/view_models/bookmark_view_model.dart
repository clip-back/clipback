import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';

class BookmarkViewModel extends FeedViewModel {
  BookmarkViewModel(ContentRepository repository, this.actions)
    : super(repository, FeedKey.bookmark);

  final ContentActions actions;

  Future<void> toggleBookmark(ContentItem item) async {
    if (!isDisposed && item.apiId != null) {
      await actions.toggleBookmark(item.apiId!, emitEffect);
    }
  }

  Future<void> changeCategory(ContentItem item, List<int> categoryIds) async {
    if (!isDisposed && item.apiId != null) {
      await actions.changeCategory(item.apiId!, categoryIds, emitEffect);
    }
  }

  Future<void> deleteContent(ContentItem item) async {
    if (!isDisposed && item.apiId != null) {
      await actions.deleteContent(item.apiId!, emitEffect);
    }
  }
}
