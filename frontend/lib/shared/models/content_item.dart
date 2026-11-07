import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';

class ContentItem {
  const ContentItem({
    required this.id,
    this.apiId,
    required this.title,
    required this.summary,
    required CategoryItem category,
    List<CategoryItem>? categories,
    required this.savedAt,
    required this.savedAtFull,
    required this.savedAtFullShort,
    required this.tags,
    required this.source,
    required this.originalUrl,
    required this.originalText,
    this.bookmarked = false,
    this.isScreenshot = false,
    this.assets = const [],
    this.summaryStatus = 'not_requested',
    this.isMutating = false,
    this.mutationLabel,
  }) : assert(mutationLabel == null || isMutating),
       _category = category,
       _categories = categories;

  final String id;
  final int? apiId;
  final String title;
  final String summary;
  final CategoryItem _category;
  final List<CategoryItem>? _categories;
  CategoryItem get category => _categories?.firstOrNull ?? _category;
  List<CategoryItem> get categories => List.unmodifiable(
    _categories == null || _categories.isEmpty ? [_category] : _categories,
  );
  final String savedAt;
  final String savedAtFull;
  final String savedAtFullShort;
  final List<String> tags;
  final String source;
  final String originalUrl;
  final String originalText;
  final bool bookmarked;
  final bool isScreenshot;
  final List<ApiAsset> assets;
  final String summaryStatus;

  /// A write for this content is in flight: its star, more menu and
  /// management actions stay locked until the write and its reload finish.
  final bool isMutating;

  /// Text shown while [isMutating]; only deletion has one (`삭제 중…`).
  final String? mutationLabel;

  ContentItem copyWith({
    CategoryItem? category,
    List<CategoryItem>? categories,
    bool? bookmarked,
    bool? isMutating,
    String? mutationLabel,
    bool clearMutationLabel = false,
  }) {
    final nextCategories =
        categories ?? (category == null ? this.categories : [category]);
    return ContentItem(
      id: id,
      apiId: apiId,
      title: title,
      summary: summary,
      category: nextCategories.firstOrNull ?? catUncategorized,
      categories: List.unmodifiable(
        nextCategories.isEmpty ? [catUncategorized] : nextCategories,
      ),
      savedAt: savedAt,
      savedAtFull: savedAtFull,
      savedAtFullShort: savedAtFullShort,
      tags: tags,
      source: source,
      originalUrl: originalUrl,
      originalText: originalText,
      bookmarked: bookmarked ?? this.bookmarked,
      isScreenshot: isScreenshot,
      assets: assets,
      summaryStatus: summaryStatus,
      isMutating: isMutating ?? this.isMutating,
      mutationLabel: clearMutationLabel
          ? null
          : mutationLabel ?? this.mutationLabel,
    );
  }
}
