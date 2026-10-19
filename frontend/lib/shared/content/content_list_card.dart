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
import 'package:flutter_svg/flutter_svg.dart';

class ContentListCard extends StatelessWidget {
  const ContentListCard({
    required this.content,
    required this.onTap,
    required this.onToggleBookmark,
    required this.categories,
    required this.onChangeCategory,
    required this.onDelete,
    this.bookmarked = false,
    this.archiveAllStyle = false,
    this.unclassifiedStyle = false,
    super.key,
  });

  final ContentItem content;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;
  final List<CategoryItem> categories;
  final ValueChanged<CategoryItem> onChangeCategory;
  final VoidCallback onDelete;
  final bool bookmarked;
  // E01 opts in; other lists retain their existing presentation.
  final bool archiveAllStyle;
  // E06 shares the aligned body; only the system badge has a display alias.
  final bool unclassifiedStyle;

  @override
  Widget build(BuildContext context) {
    if (archiveAllStyle || unclassifiedStyle) {
      return _ArchiveAllContentListCard(this);
    }
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
                        useSafeArea: true,
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

class _ArchiveAllText {
  static const badge = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
  );
  static const title = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AppColors.text,
    height: 1.4,
  );
  static const summary = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.375,
    color: AppColors.middle,
    height: 1.6,
  );
  static const date = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.35,
    color: Color(0xFFA9A9A9),
  );
}

class _ArchiveAllContentListCard extends StatelessWidget {
  const _ArchiveAllContentListCard(this.card);
  final ContentListCard card;

  @override
  Widget build(BuildContext context) {
    final content = card.content;
    final enabled = content.mutationLabel == null;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: card.onTap,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Container(
              key: ValueKey('archive-all-card-${content.id}'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => Padding(
                      padding: const EdgeInsets.only(right: 84),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth - 84,
                          minHeight: 22,
                        ),
                        child: Wrap(
                          key: ValueKey('archive-all-badges-${content.id}'),
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in content.categories)
                              _AlignedCategoryBadge(
                                category: category,
                                maxWidth: constraints.maxWidth - 84,
                                unclassified:
                                    card.unclassifiedStyle &&
                                    category.name == catUncategorized.name,
                                contentId: content.id,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Keep all existing body slots together. Natural Wrap height
                  // moves this entire body once, without measuring text manually.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      key: ValueKey('archive-all-body-${content.id}'),
                      width: double.infinity,
                      height: 111,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 22.4,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 311,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    content.title,
                                    key: ValueKey(
                                      'archive-all-title-${content.id}',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _ArchiveAllText.title,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 26.4,
                            left: 0,
                            right: 0,
                            height: 48,
                            child: ClipRect(
                              child: Text(
                                content.summary,
                                key: ValueKey(
                                  'archive-all-summary-${content.id}',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _ArchiveAllText.summary,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 81.5,
                            left: 0,
                            right: 0,
                            height: 0.5,
                            child: SvgPicture.asset(
                              Assets.archiveAllDivider,
                              key: ValueKey(
                                'archive-all-divider-${content.id}',
                              ),
                              height: 0.5,
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    content.savedAt,
                                    key: ValueKey(
                                      'archive-all-date-${content.id}',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _ArchiveAllText.date,
                                  ),
                                ),
                                if (content.mutationLabel != null)
                                  ContentMutationStatus(
                                    label: content.mutationLabel!,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 13,
              right: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ArchiveAllAssetButton(
                    key: ValueKey('list-bookmark-${content.title}'),
                    asset: card.bookmarked
                        ? Assets.archiveAllStarFilled
                        : Assets.categoryCardStar,
                    size: 28,
                    enabled: enabled,
                    onPressed: card.onToggleBookmark,
                  ),
                  // Two pixels of the more button's 28px hit target
                  // surround its 24px original: visual gap stays 16px.
                  const SizedBox(width: 14),
                  _ArchiveAllAssetButton(
                    key: ValueKey('archive-all-more-${content.id}'),
                    asset: Assets.archiveAllMore,
                    size: 24,
                    enabled: enabled,
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ContentActionSheet(
                        content: content,
                        categories: card.categories,
                        onChangeCategory: card.onChangeCategory,
                        onDelete: card.onDelete,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlignedCategoryBadge extends StatelessWidget {
  const _AlignedCategoryBadge({
    required this.category,
    required this.maxWidth,
    required this.unclassified,
    required this.contentId,
  });

  final CategoryItem category;
  final double maxWidth;
  final bool unclassified;
  final String contentId;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Container(
      key: unclassified ? ValueKey('unclassified-badge-$contentId') : null,
      width: unclassified ? 57 : null,
      alignment: unclassified ? Alignment.center : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: unclassified ? AppColors.subtler : category.tint,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        unclassified ? '미분류' : category.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _ArchiveAllText.badge.copyWith(
          color: unclassified ? AppColors.subtle : category.deep,
        ),
      ),
    ),
  );
}

class _ArchiveAllAssetButton extends StatelessWidget {
  const _ArchiveAllAssetButton({
    required this.asset,
    required this.size,
    required this.enabled,
    required this.onPressed,
    super.key,
  });
  final String asset;
  final double size;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 28,
    child: IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      onPressed: enabled ? onPressed : null,
      icon: SvgPicture.asset(asset, width: size, height: size),
    ),
  );
}
