import 'dart:math' as math;

import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/feed_status.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _heroTitle = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  color: AppColors.text,
  fontSize: 20,
  fontWeight: FontWeight.w600,
  height: 1.6,
  letterSpacing: -0.5,
);
const _heroSubtitle = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  color: AppColors.text,
  fontSize: 18,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.45,
);
const _heroButtonLabel = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  color: AppColors.main,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  height: 1.4,
  letterSpacing: -0.35,
);
const _pickLabel = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  color: AppColors.middle,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.35,
);
const _cardTitle = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  color: AppColors.text,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  height: 1.5,
  letterSpacing: -0.4,
);
const _cardSummary = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  color: AppColors.subtle,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.6,
  letterSpacing: -0.35,
);
const _cardCategory = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  fontSize: 12,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.3,
);
const _cardMutation = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  color: AppColors.subtle,
  fontSize: 11,
);

double _textHeight(
  BuildContext context,
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
  int? maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: maxWidth);
  final height = painter.height;
  painter.dispose();
  return height;
}

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
    final confirmedEmpty =
        !hasSavedContent &&
        activeCategoryId == null &&
        feed != null &&
        feed!.categoryId == null &&
        feed!.query == null &&
        feed!.isFavorite == null &&
        !feed!.hasMore &&
        feed!.nextCursor == null &&
        feed!.initialized &&
        !feed!.loading &&
        feed!.error == null &&
        feed!.items.isEmpty;
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                HomeHero(
                  hasSavedContent: hasSavedContent,
                  confirmedEmpty: confirmedEmpty,
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
                  confirmedEmpty: confirmedEmpty,
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
    this.confirmedEmpty = false,
    required this.onSearch,
    required this.onOpenToday,
    super.key,
  });

  final bool hasSavedContent;
  final bool confirmedEmpty;
  final VoidCallback onSearch;
  final VoidCallback onOpenToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            key: const ValueKey('home-header'),
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Transform.translate(
                offset: const Offset(0, 0.5),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      Assets.homeLogo,
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
                      color: Colors.black,
                    ),
                    const SizedBox(width: 16),
                    SvgIconButton(
                      asset: Assets.bell,
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const NotificationSheet(),
                      ),
                      size: 24,
                      hitSize: 24,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasSavedContent || confirmedEmpty)
          _alignedIntro(context)
        else
          SizedBox(
            height: 172,
            child: Stack(
              children: [
                Positioned(
                  left: 24,
                  top: 8,
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
                  top: 0,
                  child: Image.asset(
                    hasSavedContent
                        ? Assets.homeCharacter
                        : Assets.character2Png,
                    width: hasSavedContent ? 99 : 81,
                    height: 123,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _alignedIntro(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textWidth = math.max(1.0, constraints.maxWidth - 147);
      final title = hasSavedContent ? '나중에 보려던 것들,' : '아직 저장한 콘텐츠가 없어요.';
      final subtitle = hasSavedContent ? '지금 하나만 꺼내볼까요?' : '지금 하나만 저장해볼까요?';
      final button = hasSavedContent ? '오늘의 콘텐츠 보기 →' : '첫 콘텐츠 저장하기';
      final introHeight = math.max(
        140.0,
        8 +
            _textHeight(context, title, _heroTitle, maxWidth: textWidth) +
            _textHeight(context, subtitle, _heroSubtitle, maxWidth: textWidth) +
            16 +
            16 +
            _textHeight(
              context,
              button,
              _heroButtonLabel,
              maxWidth: math.max(1, textWidth - 16),
            ) +
            16,
      );
      return SizedBox(
        height: introHeight,
        child: Stack(
          children: [
            Positioned(
              left: 16,
              top: 8,
              width: textWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _heroTitle),
                  Text(subtitle, style: _heroSubtitle),
                  const SizedBox(height: 16),
                  Material(
                    color: AppColors.text,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onOpenToday,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(button, style: _heroButtonLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 24,
              top: 0,
              child: Image.asset(
                Assets.homeHeroIllustration,
                width: 99,
                height: 123,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class HomeContentPanel extends StatefulWidget {
  const HomeContentPanel({
    this.feed,
    this.onRetry,
    this.activeCategoryId,
    this.onCategorySelected,
    required this.hasSavedContent,
    this.confirmedEmpty = false,
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
  final bool confirmedEmpty;
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
  final _recentController = ScrollController(keepScrollOffset: false);
  late List<String> _visibleIds;
  int? _activeCategoryId;
  int? _feedCategoryId;
  int? _feedVersion;
  int _activeIndex = 0;
  int _railGeneration = 0;

  void _rememberFeed() {
    _visibleIds = widget.contents.take(4).map((item) => item.id).toList();
    _activeCategoryId = widget.activeCategoryId;
    _feedCategoryId = widget.feed?.categoryId;
    _feedVersion = widget.feed?.version;
  }

  @override
  void initState() {
    super.initState();
    _rememberFeed();
    _recentController.addListener(_updateActiveIndex);
  }

  @override
  void didUpdateWidget(covariant HomeContentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.contents.take(4).map((item) => item.id).toList();
    if (_activeCategoryId != widget.activeCategoryId ||
        _feedCategoryId != widget.feed?.categoryId ||
        _feedVersion != widget.feed?.version ||
        !listEquals(_visibleIds, ids)) {
      _activeIndex = 0;
      _railGeneration++;
    }
    _rememberFeed();
  }

  void _updateActiveIndex() {
    if (!_recentController.hasClients || _visibleIds.isEmpty) return;
    final next = (_recentController.offset / 306).round().clamp(
      0,
      _visibleIds.length - 1,
    );
    if (next != _activeIndex) {
      setState(() => _activeIndex = next);
    }
  }

  @override
  void dispose() {
    _recentController.dispose();
    super.dispose();
  }

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
              showTrailingIcon: false,
            ),
            const SizedBox(height: 8),
            WeeklyPickRail(onOpenCategory: widget.onOpenCategories),
            const SizedBox(height: 32),
          ],
          SectionHeader(title: '최근 저장한 콘텐츠', onTap: widget.onOpenArchive),
          const SizedBox(height: 8),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final cardHeight = filteredContents
                    .take(4)
                    .map((item) => HomeContentCard.heightFor(context, item))
                    .reduce(math.max);
                final horizontalPadding = math.max(
                  0.0,
                  (constraints.maxWidth - 298) / 2,
                );
                return SizedBox(
                  height: cardHeight + 32,
                  child: ListView.separated(
                    key: ValueKey(_railGeneration),
                    controller: _recentController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      16,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredContents[index];
                      return HomeContentCard(
                        content: item,
                        bookmarked: widget.bookmarkedIds.contains(item.id),
                        onTap: () => widget.onOpenContent(item),
                        onToggleBookmark: () => widget.onToggleBookmark(item),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemCount: filteredContents.take(4).length,
                  ),
                );
              },
            ),
            PageDots(
              count: filteredContents.take(4).length,
              activeIndex: _activeIndex,
            ),
          ] else if (widget.activeCategoryId != null)
            HomeFilteredEmptyContent(
              label: _activeCategoryLabel,
              onReset: () => widget.onCategorySelected?.call(null),
            )
          else
            EmptyHomeContent(confirmedEmpty: widget.confirmedEmpty),
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
  const EmptyHomeContent({this.confirmedEmpty = false, super.key});

  final bool confirmedEmpty;

  @override
  Widget build(BuildContext context) {
    if (confirmedEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 67,
                height: 78,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -2,
                      top: 0,
                      child: Image.asset(
                        Assets.homeEmptyIllustration,
                        width: 71,
                        height: 82,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '저장한 콘텐츠가 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  inherit: false,
                  fontFamily: 'Pretendard',
                  color: AppColors.middle,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.375,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'SNS에서 발견한 유용한 게시물을 저장하면 이곳에서 다시 확인할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  inherit: false,
                  fontFamily: 'Pretendard',
                  color: AppColors.subtle,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                  letterSpacing: -0.35,
                ),
              ),
            ],
          ),
        ),
      );
    }
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
      ('많이 저장한', '일본 여행을\n준비 중이라면?', false, '일본 여행'),
      ('자주 본', '평생의 숙제\n다이어트', false, '다이어트'),
      ('공지사항', '허투루\n100% 활용법', true, ''),
    ];
    final labelHeight = _textHeight(context, '한', _pickLabel, maxLines: 1);
    final titleHeight = _textHeight(context, '한\n한', _cardTitle, maxLines: 2);
    final railHeight = math.max(
      120.0,
      120.0 + math.max(0.0, labelHeight - 20) + math.max(0.0, titleHeight - 48),
    );
    return SizedBox(
      height: railHeight,
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
                padding: const EdgeInsets.fromLTRB(16, 16, 21, 16),
                decoration: BoxDecoration(
                  color: pick.$3 ? AppColors.main : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                foregroundDecoration: BoxDecoration(
                  border: pick.$3 ? null : Border.all(color: AppColors.faint),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pick.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _pickLabel,
                    ),
                    const Spacer(),
                    Text.rich(
                      _pickTitleSpan(pick.$2, pick.$4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _cardTitle,
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

TextSpan _pickTitleSpan(String title, String highlighted) {
  if (highlighted.isEmpty) return TextSpan(text: title);
  final start = title.indexOf(highlighted);
  return TextSpan(
    children: [
      TextSpan(text: title.substring(0, start)),
      TextSpan(
        text: highlighted,
        style: const TextStyle(color: Color(0xFFFF0000)),
      ),
      TextSpan(text: title.substring(start + highlighted.length)),
    ],
  );
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

  static double heightFor(BuildContext context, ContentItem content) {
    final categoryHeight = _textHeight(context, '한', _cardCategory) + 8;
    final mutationHeight = content.mutationLabel == null
        ? 0.0
        : _textHeight(context, '한', _cardMutation);
    return math.max(
      186.0,
      32 +
          math.max(categoryHeight, mutationHeight) +
          8 +
          _textHeight(context, '한\n한', _cardTitle, maxLines: 2) +
          8 +
          _textHeight(context, '한\n한\n한', _cardSummary, maxLines: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 298,
        height: heightFor(context, content),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 2)],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.5, 16, 15.5, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 28),
                    child: Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: content.category.tint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              content.category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _cardCategory.copyWith(
                                color: content.category.deep,
                              ),
                            ),
                          ),
                        ),
                        if (content.mutationLabel != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              content.mutationLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _cardMutation,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _cardTitle,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      content.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: _cardSummary,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 3.5,
              top: 4,
              child: BookmarkActionButton(
                key: ValueKey('home-bookmark-${content.title}'),
                initialActive: bookmarked,
                inactiveAsset: Assets.homeBookmarkOutline,
                onToggle: onToggleBookmark,
                enabled: content.mutationLabel == null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
