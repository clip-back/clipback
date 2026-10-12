import 'dart:async';

import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/top_bars.dart';
import 'package:flutter/material.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({
    this.feed,
    this.onLoadMore,
    this.onRetry,
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
  final void Function(CategoryItem original, CategoryItem updated)
  onUpdateCategory;
  final ValueChanged<CategoryItem> onDeleteCategory;
  final SaveLinkCallback onAddLink;
  final SaveScreenshotCallback onAddScreenshot;
  final ValueChanged<CategoryItem> onOpenCategory;
  final ValueChanged<AppRoute> onTab;

  @override
  Widget build(BuildContext context) {
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
        body: Column(
          children: [
            const DesignStatusBar(),
            if (activeCategoryName == null)
              AppTopBar(title: '아카이브', onSearch: onSearch)
            else
              CategoryTopBar(
                title: activeCategoryName!,
                onBack: onClearCategory,
                onSearch: onSearch,
                onMore: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => SortSheet(
                    activeBookmarkedFirst: bookmarkedFirst,
                    onSelect: onSortChanged,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (activeCategoryName == null)
              ArchiveTabs(activeTab: activeTab, onChanged: onTabChanged),
            Expanded(
              child: activeTab == 0
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: ContentListView(
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
                        if (activeCategoryName != null && contents.isNotEmpty)
                          Positioned(
                            right: 16,
                            bottom: 24,
                            child: RandomReviewButton(
                              onPressed: onOpenRandomView,
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
                      onUpdateCategory: onUpdateCategory,
                      onDeleteCategory: onDeleteCategory,
                      onOpenCategory: onOpenCategory,
                    ),
            ),
          ],
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
