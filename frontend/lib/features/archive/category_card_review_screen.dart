import 'dart:async';

import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/mutation_status.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CategoryCardReviewScreen extends StatefulWidget {
  const CategoryCardReviewScreen({
    required this.contents,
    required this.categoryName,
    required this.bookmarkedIds,
    required this.onExit,
    required this.onOpenContent,
    required this.onToggleBookmark,
    super.key,
  });

  final List<ContentItem> contents;
  final String categoryName;
  final Set<String> bookmarkedIds;
  final VoidCallback onExit;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;

  @override
  State<CategoryCardReviewScreen> createState() =>
      _CategoryCardReviewScreenState();
}

class _CategoryCardReviewScreenState extends State<CategoryCardReviewScreen> {
  static const _cardTransitionDuration = Duration(milliseconds: 240);
  static const _activeCardTop = appHeaderHeight + 134;

  var _activeIndex = 0;
  var _dragOffset = Offset.zero;
  var _isDragging = false;
  var _isAdvancing = false;
  var _isComplete = false;

  ContentItem get _activeContent => widget.contents[_activeIndex];

  void _updateDrag(DragUpdateDetails details) {
    if (_isAdvancing) return;
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta;
    });
  }

  void _finishDrag(DragEndDetails details) {
    if (_isAdvancing) return;
    final velocity = details.velocity.pixelsPerSecond;
    final shouldAdvance = _dragOffset.distance > 72 || velocity.distance > 650;
    if (!shouldAdvance) {
      setState(() {
        _isDragging = false;
        _dragOffset = Offset.zero;
      });
      return;
    }

    final direction = _dragOffset.distance > 1
        ? _dragOffset / _dragOffset.distance
        : velocity / velocity.distance;
    setState(() {
      _isDragging = false;
      _isAdvancing = true;
      _dragOffset = direction * 620;
    });
    Future<void>.delayed(_cardTransitionDuration, () {
      if (!mounted) return;
      setState(() {
        if (_activeIndex == widget.contents.length - 1) {
          _isComplete = true;
        } else {
          _activeIndex += 1;
        }
        _dragOffset = Offset.zero;
        _isAdvancing = false;
      });
    });
  }

  Widget _backgroundCard(int distance, double top) {
    final content = widget.contents[_activeIndex + distance];
    final promoting = _isAdvancing && distance == 1;
    return AnimatedPositioned(
      key: ValueKey('background-${content.id}-$distance'),
      top: promoting ? _activeCardTop : top,
      left: 0,
      right: 0,
      duration: _cardTransitionDuration,
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        child: Center(
          child: AnimatedRotation(
            alignment: Alignment.topCenter,
            turns: promoting ? 0.00382 : 0,
            duration: _cardTransitionDuration,
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              alignment: Alignment.topCenter,
              scale: promoting ? 1 : (distance == 1 ? 0.907 : 0.86),
              duration: _cardTransitionDuration,
              curve: Curves.easeOutCubic,
              child: CategoryReviewCard(
                content: content,
                bookmarked: widget.bookmarkedIds.contains(content.id),
                onOpenContent: () {},
                onToggleBookmark: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contents.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          bottom: false,
          child: EmptyStatePanel(
            title: '다시 볼 콘텐츠가 없어요',
            body: '카테고리에 콘텐츠를 저장한 뒤 랜덤 보기를 이용해 보세요.',
            actionLabel: '나가기',
            onAction: widget.onExit,
          ),
        ),
      );
    }

    final remainingCount = widget.contents.length - _activeIndex;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: 0,
                right: 16,
                height: appHeaderHeight,
                child: TextButton(
                  onPressed: widget.onExit,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.text,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 44),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                  child: const Text('나가기'),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: appHeaderHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '딱 5개만 다시 확인해볼까요?',
                      style: TextStyle(
                        color: AppColors.subSubtle,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SvgPicture.asset(
                          Assets.categoryCardFolder,
                          width: 28.235,
                          height: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.categoryName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: appHeaderHeight + 78,
                child: CardPagerProgress(
                  activeIndex: _activeIndex,
                  count: widget.contents.length,
                ),
              ),
              if (!_isComplete && remainingCount > 2)
                _backgroundCard(2, appHeaderHeight + 110),
              if (!_isComplete && remainingCount > 1)
                _backgroundCard(1, appHeaderHeight + 122),
              if (!_isComplete)
                Positioned(
                  top: _activeCardTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isAdvancing
                          ? null
                          : () => widget.onOpenContent(_activeContent),
                      onPanUpdate: _updateDrag,
                      onPanEnd: _finishDrag,
                      child: AnimatedSlide(
                        key: ValueKey(_activeContent.id),
                        offset: Offset(
                          _dragOffset.dx / 343,
                          _dragOffset.dy / 496,
                        ),
                        duration: _isDragging
                            ? Duration.zero
                            : _cardTransitionDuration,
                        curve: Curves.easeOutCubic,
                        child: Transform.rotate(
                          angle: 0.024 + _dragOffset.dx / 22000,
                          child: CategoryReviewCard(
                            content: _activeContent,
                            bookmarked: widget.bookmarkedIds.contains(
                              _activeContent.id,
                            ),
                            onOpenContent: () =>
                                widget.onOpenContent(_activeContent),
                            onToggleBookmark: () =>
                                widget.onToggleBookmark(_activeContent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NavigationHomeIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryReviewCard extends StatelessWidget {
  const CategoryReviewCard({
    required this.content,
    required this.bookmarked,
    required this.onOpenContent,
    required this.onToggleBookmark,
    this.compact = false,
    super.key,
  });

  final ContentItem content;
  final bool bookmarked;
  final VoidCallback onOpenContent;
  final VoidCallback onToggleBookmark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 311.0 : 343.0;
    final height = compact ? 449.0 : 496.0;
    final padding = compact ? 20.0 : 24.0;
    final titleSize = compact ? 19.614 : 22.0;
    final bodySize = compact ? 14.264 : 16.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenContent,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x29767676), blurRadius: 8),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: CategoryBadge(category: content.category)),
                  const Spacer(),
                  if (content.mutationLabel != null) ...[
                    ContentMutationStatus(label: content.mutationLabel!),
                    const SizedBox(width: 8),
                  ],
                  if (compact)
                    SvgPicture.asset(
                      Assets.categoryCardStarSmall,
                      width: 24.963,
                      height: 24.963,
                    )
                  else
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: InkWell(
                        onTap: content.mutationLabel == null
                            ? onToggleBookmark
                            : null,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: SvgPicture.asset(
                            bookmarked
                                ? Assets.starFilled
                                : Assets.categoryCardStar,
                            width: 28,
                            height: 28,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  letterSpacing: -titleSize / 40,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  content.originalText.isNotEmpty
                      ? content.originalText
                      : content.summary,
                  maxLines: compact ? 13 : 11,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: bodySize,
                    height: 1.6,
                    letterSpacing: -bodySize / 40,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
