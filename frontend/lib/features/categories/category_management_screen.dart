import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({
    required this.categories,
    required this.contents,
    required this.onBack,
    required this.onAddCategory,
    required this.onUpdateCategory,
    required this.onDeleteCategory,
    super.key,
  });

  final List<CategoryItem> categories;
  final List<ContentItem> contents;
  final VoidCallback onBack;
  final ValueChanged<CategoryItem> onAddCategory;
  final void Function(CategoryItem original, CategoryItem updated)
  onUpdateCategory;
  final ValueChanged<CategoryItem> onDeleteCategory;

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories
        .where((category) => category.name != catUncategorized.name)
        .toList();
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height: appHeaderHeight,
                child: Row(
                  children: [
                    SvgIconButton(
                      asset: Assets.back,
                      onPressed: onBack,
                      size: 24,
                      hitSize: 48,
                      color: AppColors.text,
                    ),
                    const Expanded(
                      child: Text(
                        '카테고리 관리',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SvgIconButton(
                      asset: Assets.folderPlus,
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        useSafeArea: true,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            CategoryCreateSheet(onCreate: onAddCategory),
                      ),
                      size: 24,
                      hitSize: 48,
                      color: AppColors.subtle,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '총 ${visibleCategories.length}개',
                    style: const TextStyle(
                      color: AppColors.subtle,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: visibleCategories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final category = visibleCategories[index];
                    return CategoryRow(
                      category: category,
                      onMore: () => showCategoryActionSheet(
                        context: context,
                        category: category,
                        contentCount: category.contentCount,
                        onUpdate: onUpdateCategory,
                        onDelete: onDeleteCategory,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
