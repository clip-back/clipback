import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/app_text.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
          bottom: true,
          child: Column(
            children: [
              SizedBox(
                key: const ValueKey('management-header'),
                height: appHeaderHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const SizedBox(width: 32),
                            Expanded(
                              child: Text(
                                '카테고리 관리',
                                style: AppText.sectionTitle.copyWith(
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 8,
                      child: SizedBox(
                        key: const ValueKey('management-back'),
                        width: 48,
                        height: 48,
                        child: IconButton(
                          tooltip: '뒤로가기',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          onPressed: onBack,
                          icon: SvgPicture.asset(
                            Assets.detailBack,
                            width: 24,
                            height: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                key: const ValueKey('management-toolbar'),
                height: 52,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '총 ${visibleCategories.length}개',
                            key: const ValueKey('management-count'),
                            style: const TextStyle(
                              inherit: false,
                              fontFamily: 'Pretendard',
                              color: AppColors.subtle,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 2,
                      child: SizedBox(
                        key: const ValueKey('management-add'),
                        width: 48,
                        height: 48,
                        child: IconButton(
                          tooltip: '카테고리 추가',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            useSafeArea: true,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                CategoryCreateSheet(onCreate: onAddCategory),
                          ),
                          icon: SvgPicture.asset(
                            Assets.archiveFolderPlus,
                            width: 24,
                            height: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  key: const ValueKey('category-management-list'),
                  padding: EdgeInsets.zero,
                  itemCount: visibleCategories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final category = visibleCategories[index];
                    return CategoryRow(
                      key: ValueKey(
                        'management-category-row-${category.id ?? category.name}',
                      ),
                      archiveStyle: true,
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
