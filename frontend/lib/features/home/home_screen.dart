import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/feed_status.dart';
import 'package:clipback_frontend/shared/content/mutation_status.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/notification_sheet.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:clipback_frontend/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    this.feed,
    this.onRetry,
    this.activeCategoryId,
    this.onCategorySelected,
    required this.contents,
    required this.categories,
    required this.bookmarkedIds,
    required this.onSearch,
    required this.onOpenArchive,
    required this.onOpenCategories,
    required this.onOpenToday,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.onAddLink,
    required this.onAddScreenshot,
    required this.onTab,
    super.key,
  });

  final List<ContentItem> contents;
  final FeedPage? feed;
  final VoidCallback? onRetry;
  final int? activeCategoryId;
  final ValueChanged<CategoryItem?>? onCategorySelected;
  final List<CategoryItem> categories;
  final Set<String> bookmarkedIds;
  final VoidCallback onSearch;
  final VoidCallback onOpenArchive;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenToday;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final SaveLinkCallback onAddLink;
  final SaveScreenshotCallback onAddScreenshot;
  final ValueChanged<AppRoute> onTab;

  @override
  Widget build(BuildContext context) {
    final hasSavedContent = contents.isNotEmpty;
    void showAddContentSheet() {
      showContentSaveScreen(
        context: context,
        onAddLink: onAddLink,
        onAddScreenshot: onAddScreenshot,
      );
    }

    return PhoneFrame(
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              HomeHero(
                hasSavedContent: hasSavedContent,
                onSearch: onSearch,
                onOpenToday: hasSavedContent
                    ? onOpenToday
                    : showAddContentSheet,
              ),
              HomeContentPanel(
                feed: feed,
                onRetry: onRetry,
                activeCategoryId: activeCategoryId,
                onCategorySelected: onCategorySelected,
                hasSavedContent: hasSavedContent,
                contents: contents,
                categories: categories,
                bookmarkedIds: bookmarkedIds,
                onOpenArchive: onOpenArchive,
                onOpenCategories: onOpenCategories,
                onOpenContent: onOpenContent,
                onToggleBookmark: onToggleBookmark,
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: 0,
          onTap: onTab,
          onAdd: showAddContentSheet,
        ),
      ),
    );
  }
}

class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.hasSavedContent,
    required this.onSearch,
    required this.onOpenToday,
    super.key,
  });

  final bool hasSavedContent;
  final VoidCallback onSearch;
  final VoidCallback onOpenToday;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hasSavedContent ? 254 : 286,
      child: Stack(
        children: [
          const Positioned(left: 0, right: 0, top: 0, child: DesignStatusBar()),
          Positioned(
            left: 16,
            right: 16,
            top: 58,
            height: 56,
            child: Row(
              children: [
                SvgPicture.asset(
                  Assets.entryLogo,
                  width: 71.41,
                  height: 24,
                  fit: BoxFit.fill,
                ),
                const Spacer(),
                SvgIconButton(
                  asset: Assets.search,
                  onPressed: onSearch,
                  size: 24,
                  hitSize: 24,
                ),
                const SizedBox(width: 16),
                Transform.translate(
                  offset: const Offset(0, 1),
                  child: SvgIconButton(
                    asset: Assets.bell,
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const NotificationSheet(),
                    ),
                    size: 24,
                    hitSize: 24,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            top: 122,
            width: 168,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSavedContent ? '나중에 보려던 것들,' : '저장한 정보가 없어요.',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(
                  width: 168,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hasSavedContent ? '지금 하나만 꺼내볼까요?' : '지금 하나만 저장할까요?',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onOpenToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.text,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasSavedContent ? '오늘의 콘텐츠 보기 →' : '저장 방법 보기 →',
                      style: const TextStyle(
                        color: AppColors.main,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        letterSpacing: -0.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: hasSavedContent ? 24 : 30,
            top: 114,
            child: Image.asset(
              hasSavedContent ? Assets.homeCharacter : Assets.character2Png,
              width: hasSavedContent ? 99 : 81,
              height: 123,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeContentPanel extends StatefulWidget {
  const HomeContentPanel({
    this.feed,
    this.onRetry,
    this.activeCategoryId,
    this.onCategorySelected,
    required this.hasSavedContent,
    required this.contents,
    required this.categories,
    required this.bookmarkedIds,
    required this.onOpenArchive,
    required this.onOpenCategories,
    required this.onOpenContent,
    required this.onToggleBookmark,
    super.key,
  });

  final bool hasSavedContent;
  final FeedPage? feed;
  final VoidCallback? onRetry;
  final int? activeCategoryId;
  final ValueChanged<CategoryItem?>? onCategorySelected;
  final List<ContentItem> contents;
  final List<CategoryItem> categories;
  final Set<String> bookmarkedIds;
  final VoidCallback onOpenArchive;
  final VoidCallback onOpenCategories;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;

  @override
  State<HomeContentPanel> createState() => _HomeContentPanelState();
}

class _HomeContentPanelState extends State<HomeContentPanel> {
  String get _activeCategoryLabel =>
      widget.categories
          .where(
            (item) => item.id != null && item.id == widget.activeCategoryId,
          )
          .firstOrNull
          ?.name ??
      '전체보기';

  @override
  Widget build(BuildContext context) {
    final filteredContents = widget.contents;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          if (widget.hasSavedContent) ...[
            SectionHeader(
              title: '이번주 허투루 픽 🎯',
              onTap: widget.onOpenCategories,
            ),
            const SizedBox(height: 8),
            WeeklyPickRail(onOpenCategory: widget.onOpenCategories),
            const SizedBox(height: 32),
          ],
          SectionHeader(title: '최근 저장한 콘텐츠', onTap: widget.onOpenArchive),
          CategoryChips(
            categories: ['전체보기', ...widget.categories.map((item) => item.name)],
            activeLabel: _activeCategoryLabel,
            onSelected: (label) {
              widget.onCategorySelected?.call(
                label == '전체보기'
                    ? null
                    : widget.categories
                          .where((item) => item.name == label)
                          .first,
              );
            },
          ),
          if (widget.feed != null &&
              (widget.feed!.loading || widget.feed!.error != null))
            FeedStatus(page: widget.feed!, onRetry: widget.onRetry)
          else if (filteredContents.isNotEmpty) ...[
            SizedBox(
              height: 218,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(38, 16, 38, 10),
                itemBuilder: (context, index) {
                  final item = filteredContents[index];
                  return HomeContentCard(
                    content: item,
                    bookmarked: widget.bookmarkedIds.contains(item.id),
                    onTap: () => widget.onOpenContent(item),
                    onToggleBookmark: () => widget.onToggleBookmark(item),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemCount: filteredContents.take(4).length,
              ),
            ),
            PageDots(count: filteredContents.take(4).length, activeIndex: 0),
          ] else if (widget.activeCategoryId != null)
            HomeFilteredEmptyContent(
              label: _activeCategoryLabel,
              onReset: () => widget.onCategorySelected?.call(null),
            )
          else
            const EmptyHomeContent(),
          const SizedBox(height: 32),
          if (!widget.hasSavedContent) ...[
            SectionHeader(title: '최근 카테고리', onTap: widget.onOpenCategories),
            const SizedBox(height: 8),
            for (final category in widget.categories.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CategoryHomeRow(
                  category: category,
                  onTap: widget.onOpenCategories,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class EmptyHomeContent extends StatelessWidget {
  const EmptyHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 211,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(Assets.character2Png, width: 67, height: 78),
          const SizedBox(height: 16),
          const Text(
            '저장한 콘텐츠가 없어요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 260,
            child: Text(
              'SNS에서 발견한 유용한 게시물을 저장하면 이곳에서 다시 확인할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.subtle,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeFilteredEmptyContent extends StatelessWidget {
  const HomeFilteredEmptyContent({
    required this.label,
    required this.onReset,
    super.key,
  });

  final String label;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(Assets.character2Png, width: 58, height: 70),
          const SizedBox(height: 12),
          Text(
            '$label 콘텐츠가 없어요',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onReset, child: const Text('전체보기')),
        ],
      ),
    );
  }
}

class WeeklyPickRail extends StatelessWidget {
  const WeeklyPickRail({required this.onOpenCategory, super.key});

  final VoidCallback onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final picks = [
      ('많이 저장한', '일본 여행을\n준비 중이라면?', false),
      ('자주 본', '평생의 숙제\n다이어트', false),
      ('공지사항', '허투루\n100% 활용법', true),
    ];
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: picks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pick = picks[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenCategory,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 133,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pick.$3 ? AppColors.main : AppColors.surface,
                  border: pick.$3 ? null : Border.all(color: AppColors.faint),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pick.$1,
                      style: const TextStyle(
                        color: AppColors.middle,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      pick.$2,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HomeContentCard extends StatelessWidget {
  const HomeContentCard({
    required this.content,
    required this.bookmarked,
    required this.onTap,
    required this.onToggleBookmark,
    super.key,
  });

  final ContentItem content;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 298,
        height: 186,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 2)],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -8,
              child: BookmarkActionButton(
                key: ValueKey('home-bookmark-${content.title}'),
                initialActive: bookmarked,
                onToggle: onToggleBookmark,
                enabled: content.mutationLabel == null,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 28),
                  child: Row(
                    children: [
                      Flexible(
                        child: CategoryBadge(category: content.category),
                      ),
                      if (content.mutationLabel != null) ...[
                        const SizedBox(width: 8),
                        ContentMutationStatus(label: content.mutationLabel!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.subtle,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
