import 'dart:async';

import 'package:clipback_frontend/features/archive/category_content_widgets.dart';

import 'package:clipback_frontend/features/archive/unclassified_widgets.dart';

import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/paged_content_list.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _archiveAllToolbarStyle = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  fontSize: 14,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.35,
  color: AppColors.subtle,
);

class ContentListView extends StatelessWidget {
  const ContentListView({
    required this.contents,
    required this.bookmarkedIds,
    required this.bookmarkedFirst,
    required this.activeCategoryName,
    required this.onSortChanged,
    required this.onClearCategory,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.categories,
    required this.onChangeContentCategory,
    required this.onDeleteContent,
    required this.onGoHome,
    this.feed,
    this.onLoadMore,
    this.onRetry,
    this.archiveAllStyle = false,
    this.listBottomPadding = 0,
    super.key,
  });

  final List<ContentItem> contents;
  final Set<String> bookmarkedIds;
  final bool bookmarkedFirst;
  final String? activeCategoryName;
  final ValueChanged<bool> onSortChanged;
  final VoidCallback onClearCategory;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final List<CategoryItem> categories;
  final void Function(ContentItem content, CategoryItem category)
  onChangeContentCategory;
  final ValueChanged<ContentItem> onDeleteContent;
  final VoidCallback onGoHome;
  final FeedPage? feed;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRetry;
  final bool archiveAllStyle;
  final double listBottomPadding;

  @override
  Widget build(BuildContext context) {
    final visibleContents = feed == null
        ? contents
              .where(
                (content) =>
                    activeCategoryName == null ||
                    content.category.name == activeCategoryName,
              )
              .toList()
        : contents;
    if (feed == null && bookmarkedFirst) {
      visibleContents.sort((a, b) {
        final aMarked = bookmarkedIds.contains(a.id) ? 0 : 1;
        final bMarked = bookmarkedIds.contains(b.id) ? 0 : 1;
        return aMarked.compareTo(bMarked);
      });
    }
    final isUnclassified = activeCategoryName == catUncategorized.name;
    final unclassifiedCategory = categories
        .where((category) => category.name == catUncategorized.name)
        .firstOrNull;
    final page = feed;
    final confirmedUnclassifiedEmpty =
        isUnclassified &&
        unclassifiedCategory != null &&
        unclassifiedCategory.id != null &&
        page != null &&
        page.categoryId == unclassifiedCategory.id &&
        page.query == null &&
        page.isFavorite == null &&
        page.initialized &&
        !page.loading &&
        page.error == null &&
        !page.hasMore &&
        page.items.isEmpty &&
        visibleContents.isEmpty;

    return Column(
      children: [
        if (!isUnclassified)
          ArchiveToolbar(
            archiveAllStyle: archiveAllStyle,
            countLabel: feed == null
                ? '총 ${visibleContents.length}개'
                : '총 ${feed!.displayTotalCount ?? '-'}개',
            sortLabel: bookmarkedFirst ? '즐겨찾기 우선' : '최신순',
            onSortChanged: onSortChanged,
          ),
        if (isUnclassified && visibleContents.isNotEmpty)
          const SizedBox(height: 12),
        Expanded(
          child: PagedContentList(
            feed: feed,
            contents: visibleContents,
            onLoadMore: onLoadMore,
            onRetry: onRetry,
            bottomPadding: listBottomPadding,
            empty: confirmedUnclassifiedEmpty
                ? const UnclassifiedEmptyState()
                : EmptyStatePanel(
                    title: activeCategoryName == null
                        ? '저장한 콘텐츠가 없어요'
                        : isUnclassified
                        ? '분류가 필요한 콘텐츠가 없어요'
                        : '$activeCategoryName 콘텐츠가 없어요',
                    body: activeCategoryName == null
                        ? '아래 + 버튼에서 링크나 스크린샷을 추가해 보세요.'
                        : '다른 카테고리를 보거나 필터를 해제해 전체 콘텐츠를 확인해 보세요.',
                    actionLabel: activeCategoryName == null ? '홈으로 가기' : '전체보기',
                    onAction: activeCategoryName == null
                        ? onGoHome
                        : onClearCategory,
                  ),
            itemBuilder: (content) => ContentListCard(
              archiveAllStyle: archiveAllStyle,
              unclassifiedStyle: isUnclassified,
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
    );
  }
}

class CardPagerProgress extends StatelessWidget {
  const CardPagerProgress({
    required this.activeIndex,
    required this.count,
    this.reviewStyle = false,
    super.key,
  });

  final int activeIndex;
  final int count;
  final bool reviewStyle;

  @override
  Widget build(BuildContext context) {
    if (reviewStyle) return _buildReviewProgress();
    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.faint,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(count, (index) {
              final active = index == activeIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 16 : 8,
                height: active ? 16 : 8,
                decoration: BoxDecoration(
                  color: active ? AppColors.subtle : AppColors.faint,
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewProgress() => SizedBox(
    height: 16,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          key: const ValueKey('review-progress-track'),
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.faint,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (index) {
            final active = index == activeIndex;
            final imageSize = active ? 20.0 : 8.0;
            return AnimatedContainer(
              key: ValueKey('review-progress-dot-$index'),
              duration: const Duration(milliseconds: 180),
              width: active ? 16 : 8,
              height: active ? 16 : 8,
              child: OverflowBox(
                minWidth: imageSize,
                maxWidth: imageSize,
                minHeight: imageSize,
                maxHeight: imageSize,
                child: SvgPicture.asset(
                  active
                      ? 'assets/icons/review-progress-active.svg'
                      : 'assets/icons/review-progress-inactive.svg',
                  key: ValueKey('review-progress-image-$index'),
                  width: imageSize,
                  height: imageSize,
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );
}

class RandomReviewButton extends StatelessWidget {
  const RandomReviewButton({
    required this.onPressed,
    this.categoryContentStyle = false,
    super.key,
  });

  final bool categoryContentStyle;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (categoryContentStyle) {
      return CategoryContentRandomButton(onPressed: onPressed);
    }
    return Material(
      color: AppColors.main,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      shadowColor: const Color(0x33767676),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: const SizedBox(
          height: 48,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shuffle_rounded, color: AppColors.text, size: 16),
                SizedBox(width: 6),
                Text(
                  '랜덤 보기',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.375,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArchiveTabs extends StatelessWidget {
  const ArchiveTabs({
    required this.activeTab,
    required this.onChanged,
    this.labelStyle,
    super.key,
  });

  final int activeTab;
  final ValueChanged<int> onChanged;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.faint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: ArchiveTabButton(
                label: '카테고리',
                labelStyle: labelStyle,
                active: activeTab == 1,
                onTap: () => onChanged(1),
              ),
            ),
            Expanded(
              child: ArchiveTabButton(
                label: '전체보기',
                labelStyle: labelStyle,
                active: activeTab == 0,
                onTap: () => onChanged(0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArchiveTabButton extends StatelessWidget {
  const ArchiveTabButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.labelStyle,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: Text(
              label,
              style:
                  labelStyle?.copyWith(
                    color: active ? AppColors.text : AppColors.subtle,
                  ) ??
                  TextStyle(
                    color: active ? AppColors.text : AppColors.subtle,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArchiveToolbar extends StatelessWidget {
  const ArchiveToolbar({
    required this.countLabel,
    this.sortLabel = '최신순',
    this.onSortChanged,
    this.archiveAllStyle = false,
    super.key,
  });

  final String countLabel;
  final String sortLabel;
  final ValueChanged<bool>? onSortChanged;
  final bool archiveAllStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: archiveAllStyle ? const ValueKey('archive-all-toolbar') : null,
      height: archiveAllStyle ? 52 : 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ArchiveSortButton(
              archiveAllStyle: archiveAllStyle,
              label: sortLabel,
              bookmarkedFirst: sortLabel == '즐겨찾기 우선',
              onSelected: onSortChanged ?? (_) {},
            ),
            const Spacer(),
            Text(
              countLabel,
              style: archiveAllStyle
                  ? _archiveAllToolbarStyle
                  : const TextStyle(
                      color: AppColors.subtle,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArchiveSortButton extends StatelessWidget {
  const ArchiveSortButton({
    required this.label,
    required this.bookmarkedFirst,
    required this.onSelected,
    this.archiveAllStyle = false,
    super.key,
  });

  final String label;
  final bool bookmarkedFirst;
  final ValueChanged<bool> onSelected;
  final bool archiveAllStyle;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      onSelected: onSelected,
      padding: EdgeInsets.zero,
      tooltip: '',
      offset: const Offset(0, 32),
      color: AppColors.surface,
      elevation: 1,
      shadowColor: const Color(0x1F000000),
      menuPadding: const EdgeInsets.all(4),
      constraints: const BoxConstraints.tightFor(width: 145),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.faint),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<bool>(
          value: false,
          height: 40,
          padding: EdgeInsets.zero,
          child: _ArchiveSortOption(label: '최신순', selected: !bookmarkedFirst),
        ),
        PopupMenuItem<bool>(
          value: true,
          height: 40,
          padding: EdgeInsets.zero,
          child: _ArchiveSortOption(
            label: '즐겨찾기 우선',
            selected: bookmarkedFirst,
          ),
        ),
      ],
      child: SizedBox(
        height: 32,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: archiveAllStyle
                  ? _archiveAllToolbarStyle
                  : const TextStyle(
                      color: AppColors.subtle,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.35,
                    ),
            ),
            const SizedBox(width: 2),
            if (archiveAllStyle)
              SvgPicture.asset(
                Assets.archiveAllChevronDown,
                width: 16,
                height: 16,
              )
            else
              const SvgIcon(
                asset: Assets.chevronDown,
                size: 16,
                color: AppColors.subtle,
              ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveSortOption extends StatelessWidget {
  const _ArchiveSortOption({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.text : AppColors.middle,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: -0.35,
            ),
          ),
          const Spacer(),
          if (selected)
            const Icon(Icons.check, size: 16, color: AppColors.mainDeep),
        ],
      ),
    );
  }
}
