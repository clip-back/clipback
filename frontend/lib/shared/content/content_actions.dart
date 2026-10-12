import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/content/mutation_status.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/sheet_primitives.dart';
import 'package:flutter/material.dart';

class ContentActionSheet extends StatelessWidget {
  const ContentActionSheet({
    required this.content,
    required this.categories,
    required this.onChangeCategory,
    required this.onDelete,
    super.key,
  });

  final ContentItem content;
  final List<CategoryItem> categories;
  final ValueChanged<CategoryItem> onChangeCategory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '콘텐츠 관리',
      children: [
        if (content.mutationLabel != null)
          ContentMutationStatus(label: content.mutationLabel!),
        SheetActionTile(
          icon: Assets.archive,
          title: '카테고리 변경',
          description: '이 콘텐츠를 다른 카테고리로 옮겨요.',
          enabled: content.mutationLabel == null,
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => CategoryChangeSheet(
                current: content.category,
                categories: categories,
                onChange: onChangeCategory,
                enabled: content.mutationLabel == null,
              ),
            );
          },
        ),
        SheetActionTile(
          icon: Assets.close,
          title: '삭제',
          description: '저장한 콘텐츠 목록에서 제거해요.',
          enabled: content.mutationLabel == null,
          onTap: () {
            onDelete();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
