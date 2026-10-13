import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';

class CategoryTopBar extends StatelessWidget {
  const CategoryTopBar({
    required this.title,
    required this.onBack,
    required this.onSearch,
    this.onMore,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: appHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SvgIconButton(asset: Assets.back, onPressed: onBack, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.45,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SvgIconButton(asset: Assets.search, onPressed: onSearch, size: 24),
            const SizedBox(width: 16),
            SvgIconButton(
              asset: Assets.more,
              onPressed: onMore ?? () {},
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    this.activeLabel = '전체보기',
    this.onSelected,
    super.key,
  });

  final List<String> categories;
  final String activeLabel;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final height =
        32.0 *
        (MediaQuery.textScalerOf(context).scale(15) / 15).clamp(
          1,
          double.infinity,
        );
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final label = categories[index];
            final active = label == activeLabel;
            return SizedBox(
              width: 70,
              height: height,
              child: Material(
                color: active ? AppColors.faint : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onSelected == null ? null : () => onSelected!(label),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        inherit: false,
                        fontFamily: 'Pretendard',
                        color: active ? AppColors.middle : AppColors.subtler,
                        fontSize: 15,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        letterSpacing: -0.375,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 4),
          itemCount: categories.length,
        ),
      ),
    );
  }
}

class CategoryArchiveToolbar extends StatelessWidget {
  const CategoryArchiveToolbar({
    required this.bookmarkedFirst,
    required this.onSortChanged,
    required this.onAddCategory,
    super.key,
  });

  final bool bookmarkedFirst;
  final ValueChanged<bool> onSortChanged;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Text(
              '최신순',
              style: TextStyle(
                color: AppColors.subtle,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.35,
              ),
            ),
            const Spacer(),
            SvgIconButton(
              asset: Assets.folderPlus,
              onPressed: onAddCategory,
              size: 24,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryArchiveView extends StatelessWidget {
  const CategoryArchiveView({
    required this.categories,
    required this.contents,
    required this.bookmarkedIds,
    required this.bookmarkedFirst,
    required this.onSortChanged,
    required this.onAddCategory,
    required this.onUpdateCategory,
    required this.onDeleteCategory,
    required this.onOpenCategory,
    super.key,
  });

  final List<CategoryItem> categories;
  final List<ContentItem> contents;
  final Set<String> bookmarkedIds;
  final bool bookmarkedFirst;
  final ValueChanged<bool> onSortChanged;
  final ValueChanged<CategoryItem> onAddCategory;
  final void Function(CategoryItem original, CategoryItem updated)
  onUpdateCategory;
  final ValueChanged<CategoryItem> onDeleteCategory;
  final ValueChanged<CategoryItem> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories
        .where((category) => category.name != catUncategorized.name)
        .toList();
    final unclassifiedCategory = categories.firstWhere(
      (category) => category.name == catUncategorized.name,
      orElse: () => catUncategorized,
    );
    visibleCategories.sort((a, b) {
      final aSavedAt = a.rawLastSavedAt;
      final bSavedAt = b.rawLastSavedAt;
      if (aSavedAt != null && bSavedAt != null) {
        final timeOrder = bSavedAt.compareTo(aSavedAt);
        if (timeOrder != 0) return timeOrder;
      } else if (aSavedAt != bSavedAt) {
        return aSavedAt == null ? 1 : -1;
      }
      final aId = a.id;
      final bId = b.id;
      if (aId == null) return bId == null ? 0 : 1;
      if (bId == null) return -1;
      return aId.compareTo(bId);
    });

    return Column(
      children: [
        CategoryArchiveToolbar(
          bookmarkedFirst: bookmarkedFirst,
          onSortChanged: onSortChanged,
          onAddCategory: () => showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CategoryCreateSheet(onCreate: onAddCategory),
          ),
        ),
        UnclassifiedCategoryRow(
          count: unclassifiedCategory.contentCount,
          onTap: () => onOpenCategory(unclassifiedCategory),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final category = visibleCategories[index];
              return CategoryRow(
                category: category,
                onTap: () => onOpenCategory(category),
                onMore: () => showCategoryActionSheet(
                  context: context,
                  category: category,
                  contentCount: category.contentCount,
                  onUpdate: onUpdateCategory,
                  onDelete: onDeleteCategory,
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemCount: visibleCategories.length,
          ),
        ),
      ],
    );
  }
}

class UnclassifiedCategoryRow extends StatelessWidget {
  const UnclassifiedCategoryRow({
    required this.count,
    required this.onTap,
    super.key,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const SvgIcon(
                    asset: Assets.star,
                    size: 20,
                    color: AppColors.main,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '분류가 필요한 콘텐츠',
                    style: TextStyle(
                      color: AppColors.main,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mainSubtle,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 14,
                        letterSpacing: -0.35,
                      ),
                    ),
                  ),
                  const SvgIcon(
                    asset: Assets.chevronRight,
                    size: 24,
                    color: AppColors.main,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryHomeRow extends StatelessWidget {
  const CategoryHomeRow({
    required this.category,
    required this.onTap,
    super.key,
  });

  final CategoryItem category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              FolderGlyph(color: category.color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '2020. 3. 10. 오후 11:56',
                    style: TextStyle(color: AppColors.subSubtle, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              const SvgIcon(
                asset: Assets.chevronRight,
                size: 18,
                color: AppColors.subtler,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryRow extends StatelessWidget {
  const CategoryRow({
    required this.category,
    this.onTap,
    this.onMore,
    super.key,
  });

  final CategoryItem category;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 6),
            child: Row(
              children: [
                FolderGlyph(color: category.color),
                const SizedBox(width: 12),
                SizedBox(
                  width: 156,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.mutationLabel ??
                            category.lastSavedAt ??
                            '저장된 콘텐츠 없음',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.subSubtle,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${category.contentCount}',
                  style: const TextStyle(color: AppColors.subtle, fontSize: 14),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: category.mutationLabel == null ? onMore : null,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.faint,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SvgIcon(
                            asset: Assets.moreHorizontal,
                            size: 19.2,
                            color: AppColors.middle,
                          ),
                        ),
                      ),
                    ),
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

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({required this.category, super.key});

  final CategoryItem category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: category.tint,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: category.deep,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
