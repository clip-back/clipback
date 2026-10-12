import 'dart:async';

import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/paged_content_list.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/top_bars.dart';
import 'package:flutter/material.dart';

class BookmarkScreen extends StatelessWidget {
  const BookmarkScreen({
    required this.contents,
    required this.bookmarkedIds,
    required this.categories,
    required this.onSearch,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.onChangeContentCategory,
    required this.onDeleteContent,
    required this.onAddLink,
    required this.onAddScreenshot,
    required this.onTab,
    this.feed,
    this.onLoadMore,
    this.onRetry,
    super.key,
  });

  final List<ContentItem> contents;
  final Set<String> bookmarkedIds;
  final List<CategoryItem> categories;
  final VoidCallback onSearch;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final void Function(ContentItem content, CategoryItem category)
  onChangeContentCategory;
  final ValueChanged<ContentItem> onDeleteContent;
  final SaveLinkCallback onAddLink;
  final SaveScreenshotCallback onAddScreenshot;
  final ValueChanged<AppRoute> onTab;
  final FeedPage? feed;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    void showAddContentSheet() {
      showContentSaveScreen(
        context: context,
        onAddLink: onAddLink,
        onAddScreenshot: onAddScreenshot,
      );
    }

    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppTopBar(
                title: '북마크',
                onBack: () => onTab(AppRoute.home),
                onSearch: onSearch,
              ),
              if (feed != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '불러온 ${contents.length}개',
                      style: const TextStyle(
                        color: AppColors.subtle,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: PagedContentList(
                  feed: feed,
                  contents: contents,
                  onLoadMore: onLoadMore,
                  onRetry: onRetry,
                  empty: EmptyStatePanel(
                    title: '즐겨찾기한 콘텐츠가 없어요',
                    body: '중요한 콘텐츠의 별 아이콘을 누르면 이곳에 모아둘 수 있어요.',
                    actionLabel: '아카이브 보러가기',
                    onAction: () => onTab(AppRoute.archive),
                  ),
                  itemBuilder: (content) => ContentListCard(
                    content: content,
                    bookmarked: bookmarkedIds.contains(content.id),
                    onToggleBookmark: () => onToggleBookmark(content),
                    categories: categories,
                    onChangeCategory: (category) =>
                        onChangeContentCategory(content, category),
                    onDelete: () => onDeleteContent(content),
                    onTap: () => onOpenContent(content),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: 2,
          onTap: onTab,
          onAdd: showAddContentSheet,
        ),
      ),
    );
  }
}
