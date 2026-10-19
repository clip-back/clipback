import 'dart:async';

import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/shared/content/mutation_status.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class _ReviewText {
  static const exit = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.4,
    color: AppColors.text,
  );
  static const guide = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AppColors.subSubtle,
  );
  static const category = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: AppColors.text,
  );
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
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.55,
    color: AppColors.text,
    height: 1.4,
  );
  static const body = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    color: AppColors.text,
    height: 1.6,
  );
}

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
  static const _activeCardTop = appHeaderHeight + 132;

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
    final inset = promoting ? 16.0 : 16.0 * (distance + 1);
    return AnimatedPositioned(
      key: ValueKey('background-${content.id}-$distance'),
      top: promoting ? _activeCardTop : top,
      left: inset,
      right: inset,
      height: promoting ? 496 : (distance == 1 ? 449 : 403),
      duration: _cardTransitionDuration,
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        child: SizedBox(
          key: ValueKey('review-background-$distance'),
          child: _ReviewCardBody(
            content: content,
            bookmarked: widget.bookmarkedIds.contains(content.id),
            shadowBlur: 16,
            onOpenContent: () {},
            onToggleBookmark: () {},
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
        child: ClipRect(
          key: const ValueKey('review-viewport'),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth - 32;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: appHeaderHeight,
                    child: Padding(
                      key: const ValueKey('review-header'),
                      padding: const EdgeInsets.only(right: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          key: const ValueKey('review-exit-hit'),
                          width: 48,
                          height: appHeaderHeight,
                          child: TextButton(
                            onPressed: widget.onExit,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.text,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 44),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.centerRight,
                            ),
                            child: const Text(
                              '나가기',
                              key: ValueKey('review-exit-label'),
                              style: _ReviewText.exit,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: appHeaderHeight,
                    child: Column(
                      key: const ValueKey('review-guide'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '딱 5개만 다시 확인해볼까요?',
                          style: _ReviewText.guide,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SvgPicture.asset(
                              Assets.categoryCardFolder,
                              width: 28.2353,
                              height: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _ReviewText.category,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_isComplete)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: appHeaderHeight + 56,
                      height: 60,
                      child: Center(
                        key: const ValueKey('review-progress-region'),
                        child: CardPagerProgress(
                          key: const ValueKey('review-progress'),
                          activeIndex: _activeIndex,
                          count: widget.contents.length,
                          reviewStyle: true,
                        ),
                      ),
                    ),
                  if (!_isComplete && remainingCount > 2)
                    _backgroundCard(2, appHeaderHeight + 241),
                  if (!_isComplete && remainingCount > 1)
                    _backgroundCard(1, appHeaderHeight + 187),
                  if (!_isComplete)
                    Positioned(
                      top: _activeCardTop,
                      left: 16,
                      right: 16,
                      child: SizedBox(
                        key: const ValueKey('review-active-card'),
                        width: cardWidth,
                        height: 496,
                        child: GestureDetector(
                          onTap: _isAdvancing
                              ? null
                              : () => widget.onOpenContent(_activeContent),
                          onPanUpdate: _updateDrag,
                          onPanEnd: _finishDrag,
                          child: AnimatedSlide(
                            key: ValueKey(_activeContent.id),
                            offset: Offset(
                              _dragOffset.dx / cardWidth,
                              _dragOffset.dy / 496,
                            ),
                            duration: _isDragging
                                ? Duration.zero
                                : _cardTransitionDuration,
                            curve: Curves.easeOutCubic,
                            child: Transform.rotate(
                              angle: _dragOffset.dx / 22000,
                              child: CategoryReviewCard(
                                key: ValueKey(
                                  'review-card-${_activeContent.id}',
                                ),
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
                ],
              );
            },
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
  Widget build(BuildContext context) => _ReviewCardBody(
    content: content,
    bookmarked: bookmarked,
    onOpenContent: onOpenContent,
    onToggleBookmark: onToggleBookmark,
    compact: compact,
  );
}

class _ReviewCardBody extends StatelessWidget {
  const _ReviewCardBody({
    required this.content,
    required this.bookmarked,
    required this.onOpenContent,
    required this.onToggleBookmark,
    this.compact = false,
    this.shadowBlur = 8,
  });

  final ContentItem content;
  final bool bookmarked;
  final VoidCallback onOpenContent;
  final VoidCallback onToggleBookmark;
  final bool compact;
  final double shadowBlur;

  @override
  Widget build(BuildContext context) {
    final titleStyle = compact
        ? _ReviewText.title.copyWith(
            fontSize: 19.614,
            letterSpacing: -19.614 / 40,
          )
        : _ReviewText.title;
    final bodyStyle = compact
        ? _ReviewText.body.copyWith(
            fontSize: 14.264,
            letterSpacing: -14.264 / 40,
          )
        : _ReviewText.body;
    final body = content.originalText.isNotEmpty
        ? content.originalText
        : content.summary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenContent,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: compact ? 311 : 343,
          height: compact ? 449 : 496,
          padding: EdgeInsets.all(compact ? 20 : 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: const Color(0x29000000), blurRadius: shadowBlur),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    // Preserve the old Flexible/Spacer split for the badge,
                    // while anchoring the trailing actions to the right edge.
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      alignment: Alignment.centerLeft,
                      child: Align(
                        alignment: Alignment.centerLeft,
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
                            key: ValueKey('review-badge-${content.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ReviewText.badge.copyWith(
                              color: content.category.deep,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
                      key: ValueKey('review-bookmark-${content.id}'),
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
                key: ValueKey('review-title-${content.id}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final painter = TextPainter(
                      text: TextSpan(text: body, style: bodyStyle),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      locale: Localizations.maybeLocaleOf(context),
                    )..layout(maxWidth: constraints.maxWidth);
                    // Ask the engine how many complete, ellipsized lines fit
                    // after the actual header/title have taken their height.
                    var low = 1;
                    var high = painter.computeLineMetrics().length;
                    var lines = 1;
                    painter.ellipsis = '…';
                    while (low <= high) {
                      final middle = (low + high) ~/ 2;
                      painter.maxLines = middle;
                      painter.layout(maxWidth: constraints.maxWidth);
                      if (painter.height <= constraints.maxHeight + 0.01) {
                        lines = middle;
                        low = middle + 1;
                      } else {
                        high = middle - 1;
                      }
                    }
                    painter.dispose();
                    return Text(
                      body,
                      key: ValueKey('review-body-${content.id}'),
                      maxLines: lines,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle,
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
