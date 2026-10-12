import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';

class CategoryManagementViewModel extends ContentViewModel {
  CategoryManagementViewModel(super.repository, this.actions);
  final ContentActions actions;

  List<ContentItem> get contents =>
      repository.feed(FeedKey.home).items.map(present).toList();

  Future<void> add(CategoryItem category) => actions.createCategory(
    name: category.name,
    color: hexFromColor(category.color),
    feedback: emitEffect,
  );
  Future<void> update(CategoryItem original, CategoryItem updated) async {
    if (isDisposed || original.id == null) return;
    await actions.updateCategory(
      original.id!,
      name: updated.name,
      color: hexFromColor(updated.color),
      feedback: emitEffect,
    );
  }

  Future<void> delete(CategoryItem category) async {
    if (!isDisposed && category.id != null) {
      await actions.deleteCategory(category.id!, emitEffect);
    }
  }
}
