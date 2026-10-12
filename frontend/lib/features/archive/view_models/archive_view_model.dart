import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';

class ArchiveViewModel extends FeedViewModel {
  ArchiveViewModel(ContentRepository repository, this.actions)
    : super(repository, FeedKey.archive) {
    _accountVersion = repository.accountVersion;
  }

  int activeTab = 0;
  bool bookmarkedFirst = false;
  bool randomViewing = false;
  String? activeCategoryName;
  int _accountVersion = 0;
  int? _selectedCategoryId;

  @override
  void repositoryChanged() {
    if (_accountVersion != repository.accountVersion) {
      _accountVersion = repository.accountVersion;
      activeCategoryName = null;
      _selectedCategoryId = null;
    } else if (_selectedCategoryId != null) {
      if (repository.isCategoryDeleted(_selectedCategoryId!)) {
        activeCategoryName = null;
        _selectedCategoryId = null;
      } else {
        final category = categories
            .where((item) => item.id == _selectedCategoryId)
            .firstOrNull;
        if (category != null) activeCategoryName = category.name;
      }
    }
    super.repositoryChanged();
  }

  void _configureCategory(int? id) {
    repository.configureFeed(
      key,
      categoryId: id,
      bookmarkedFirst: bookmarkedFirst,
    );
  }

  void open({int tab = 0, String? categoryName}) {
    final category = categories
        .where((item) => item.name == categoryName)
        .firstOrNull;
    activeTab = tab;
    activeCategoryName = categoryName;
    _selectedCategoryId = category?.id;
    if (page.categoryId != category?.id) {
      _configureCategory(category?.id);
      repository.resetFeed(key);
    }
    notifyListeners();
    if (tab == 0) ensureLoaded();
  }

  void enterRootTab() {
    activeTab = 0;
    activeCategoryName = null;
    _selectedCategoryId = null;
    if (page.categoryId != null) {
      _configureCategory(null);
      repository.resetFeed(key);
    }
    notifyListeners();
  }

  void selectTab(int value) {
    activeTab = value;
    notifyListeners();
    if (value == 0) ensureLoaded();
  }

  Future<void> selectCategory(CategoryItem? category) async {
    if (category?.id != null && repository.isCategoryDeleted(category!.id!)) {
      return;
    }
    activeCategoryName = category?.name;
    _selectedCategoryId = category?.id;
    activeTab = 0;
    randomViewing = false;
    _configureCategory(category?.id);
    notifyListeners();
    await repository.loadNext(key, reset: true);
  }

  Future<void> sort(bool value) async {
    bookmarkedFirst = value;
    _configureCategory(page.categoryId);
    await repository.loadNext(key, reset: true);
  }

  void setRandomViewing(bool value) {
    randomViewing = value;
    notifyListeners();
  }

  void clearCategory() {
    activeCategoryName = null;
    _selectedCategoryId = null;
    activeTab = 1;
    randomViewing = false;
    _configureCategory(null);
    repository.resetFeed(key);
    notifyListeners();
  }

  void recordCategoryOpen(int id) => repository.recordCategoryFilter(id);

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
