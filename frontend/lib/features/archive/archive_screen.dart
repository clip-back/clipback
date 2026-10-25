import 'dart:async';

import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/archive/category_content_widgets.dart';
import 'package:clipback_frontend/features/archive/unclassified_widgets.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/category_submission.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({
    this.feed,
    this.onLoadMore,
    this.onRetry,
    this.onOpenCategoryManagement,
    required this.activeTab,
    required this.contents,
    required this.categories,
    required this.bookmarkedIds,
    required this.bookmarkedFirst,
    required this.randomViewing,
    required this.activeCategoryName,
    required this.onTabChanged,
    required this.onSortChanged,
    required this.onOpenRandomView,
    required this.onExitRandomView,
    required this.onClearCategory,
    required this.onSearch,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.onChangeContentCategory,
    required this.onDeleteContent,
    required this.onAddCategory,
    this.onSubmitCategory,
    required this.onUpdateCategory,
    required this.onDeleteCategory,
    required this.onAddLink,
    required this.onAddScreenshot,
    required this.onOpenCategory,
    required this.onTab,
    super.key,
  });

  final int activeTab;
  final FeedPage? feed;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenCategoryManagement;
  final List<ContentItem> contents;
  final List<CategoryItem> categories;
  final Set<String> bookmarkedIds;
  final bool bookmarkedFirst;
  final bool randomViewing;
  final String? activeCategoryName;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<bool> onSortChanged;
  final VoidCallback onOpenRandomView;
  final VoidCallback onExitRandomView;
  final VoidCallback onClearCategory;
  final VoidCallback onSearch;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final void Function(ContentItem content, CategoryItem category)
  onChangeContentCategory;
  final ValueChanged<ContentItem> onDeleteContent;
  final ValueChanged<CategoryItem> onAddCategory;
  final CategorySubmitCallback? onSubmitCategory;
  final void Function(CategoryItem original, CategoryItem updated)
  onUpdateCategory;
  final ValueChanged<CategoryItem> onDeleteCategory;
  final SaveLinkCallback onAddLink;
  final SaveScreenshotCallback onAddScreenshot;
  final ValueChanged<CategoryItem> onOpenCategory;
  final ValueChanged<AppRoute> onTab;

  @override
  Widget build(BuildContext context) {
    final rootArchive = activeCategoryName == null;
    final allRoot = rootArchive && activeTab == 0;
    final unclassified = activeCategoryName == catUncategorized.name;
    final categoryContent = !rootArchive && !unclassified && activeTab == 0;
    final selectedCategory = categories
        .where(
          (category) => feed?.categoryId != null
              ? category.id == feed!.categoryId
              : category.name == activeCategoryName,
        )
        .firstOrNull;
    void showAddContentSheet() {
      showContentSaveScreen(
        context: context,
        onAddLink: onAddLink,
        onAddScreenshot: onAddScreenshot,
      );
    }

    if (activeCategoryName != null && randomViewing && activeTab == 0) {
      final categoryContents = List.of(contents);
      categoryContents.shuffle();
      return PhoneFrame(
        child: CategoryCardReviewScreen(
          contents: categoryContents.take(5).toList(),
          categoryName: activeCategoryName!,
          bookmarkedIds: bookmarkedIds,
          onExit: onExitRandomView,
          onOpenContent: onOpenContent,
          onToggleBookmark: onToggleBookmark,
        ),
      );
    }

    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (rootArchive)
                CategoryArchiveTopBar(
                  onSearch: onSearch,
                  onOpenCategoryManagement: onOpenCategoryManagement,
                )
              else if (unclassified)
                UnclassifiedTopBar(
                  onBack: onClearCategory,
                  onSearch: onSearch,
                  onOpenCategoryManagement: onOpenCategoryManagement,
                )
              else
                CategoryContentTopBar(
                  title: activeCategoryName!,
                  category: selectedCategory,
                  onBack: onClearCategory,
                  onSearch: onSearch,
                  onOpenCategoryManagement: onOpenCategoryManagement,
                ),
              if (rootArchive)
                SizedBox(
                  key: ValueKey(
                    allRoot ? 'archive-all-tabs' : 'archive-category-tabs',
                  ),
                  height: 64,
                  child: Center(
                    child: ArchiveTabs(
                      activeTab: activeTab,
                      onChanged: onTabChanged,
                      labelStyle: const TextStyle(
                        inherit: false,
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: activeTab == 0
                    ? Column(
                        children: [
                          Expanded(
                            child: ContentListView(
                              archiveAllStyle: allRoot || categoryContent,
                              feed: feed,
                              onLoadMore: onLoadMore,
                              onRetry: onRetry,
                              contents: contents,
                              bookmarkedIds: bookmarkedIds,
                              bookmarkedFirst: bookmarkedFirst,
                              activeCategoryName: activeCategoryName,
                              onSortChanged: onSortChanged,
                              onClearCategory: onClearCategory,
                              onOpenContent: onOpenContent,
                              onToggleBookmark: onToggleBookmark,
                              categories: categories,
                              onChangeContentCategory: onChangeContentCategory,
                              onDeleteContent: onDeleteContent,
                              onGoHome: () => onTab(AppRoute.home),
                            ),
                          ),
                          if (categoryContent && contents.isNotEmpty)
                            // The footer takes its natural height. The list ends
                            // above it, so even the final card remains reachable.
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: RandomReviewButton(
                                  categoryContentStyle: true,
                                  onPressed: onOpenRandomView,
                                ),
                              ),
                            ),
                        ],
                      )
                    : CategoryArchiveView(
                        categories: categories,
                        contents: contents,
                        bookmarkedIds: bookmarkedIds,
                        bookmarkedFirst: bookmarkedFirst,
                        onSortChanged: onSortChanged,
                        onAddCategory: onAddCategory,
                        onSubmitCategory: onSubmitCategory,
                        onUpdateCategory: onUpdateCategory,
                        onDeleteCategory: onDeleteCategory,
                        onOpenCategory: onOpenCategory,
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: 1,
          onTap: onTab,
          onAdd: showAddContentSheet,
        ),
      ),
    );
  }
}
