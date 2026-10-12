import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/content_actions.dart';
import 'package:clipback_frontend/shared/content/mutation_status.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';

class ContentListCard extends StatelessWidget {
  const ContentListCard({
    required this.content,
    required this.onTap,
    required this.onToggleBookmark,
    required this.categories,
    required this.onChangeCategory,
    required this.onDelete,
    this.bookmarked = false,
    super.key,
  });

  final ContentItem content;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;
  final List<CategoryItem> categories;
  final ValueChanged<CategoryItem> onChangeCategory;
  final VoidCallback onDelete;
  final bool bookmarked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 173,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: 16,
                left: 16,
                child: CategoryBadge(category: content.category),
              ),
              Positioned(
                top: 13,
                right: 8,
                child: Row(
                  children: [
                    BookmarkActionButton(
                      key: ValueKey('list-bookmark-${content.title}'),
                      initialActive: bookmarked,
                      hitSize: 28,
                      onToggle: onToggleBookmark,
                      enabled: content.mutationLabel == null,
                    ),
                    const SizedBox(width: 4),
                    SvgIconButton(
                      asset: Assets.more,
                      enabled: content.mutationLabel == null,
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ContentActionSheet(
                          content: content,
                          categories: categories,
                          onChangeCategory: onChangeCategory,
                          onDelete: onDelete,
                        ),
                      ),
                      size: 24,
                      hitSize: 28,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 46,
                left: 20,
                right: 20,
                height: 22.4,
                child: Text(
                  content.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Positioned(
                top: 72.4,
                left: 20,
                right: 20,
                height: 48,
                child: ClipRect(
                  child: Text(
                    content.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.middle,
                      fontSize: 15,
                      height: 1.6,
                      letterSpacing: -0.375,
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 128,
                left: 20,
                right: 20,
                child: Divider(height: 1, thickness: 1, color: AppColors.faint),
              ),
              Positioned(
                bottom: 16,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        content.savedAt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFA9A9A9),
                          fontSize: 14,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    if (content.mutationLabel != null)
                      ContentMutationStatus(label: content.mutationLabel!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
