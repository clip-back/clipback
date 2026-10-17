import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BookmarkTopBar extends StatelessWidget {
  const BookmarkTopBar({
    required this.onSearch,
    this.onOpenCategoryManagement,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback? onOpenCategoryManagement;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('bookmark-header'),
    height: appHeaderHeight,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 1, 16, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '즐겨찾기',
              key: ValueKey('bookmark-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                inherit: false,
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.45,
                color: Colors.black,
              ),
            ),
          ),
          _BookmarkAssetButton(
            key: const ValueKey('bookmark-search'),
            asset: Assets.archiveSearch,
            onPressed: onSearch,
          ),
          const SizedBox(width: 16),
          _BookmarkAssetButton(
            key: const ValueKey('bookmark-settings'),
            asset: Assets.archiveSettings,
            onPressed: onOpenCategoryManagement,
          ),
        ],
      ),
    ),
  );
}

class _BookmarkAssetButton extends StatelessWidget {
  const _BookmarkAssetButton({
    required this.asset,
    required this.onPressed,
    super.key,
  });

  final String asset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 24,
    child: IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      onPressed: onPressed,
      icon: SvgPicture.asset(asset, width: 24, height: 24),
    ),
  );
}

class BookmarkToolbar extends StatelessWidget {
  const BookmarkToolbar({required this.loadedCount, super.key});
  final int loadedCount;

  static const _style = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: AppColors.subtle,
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('bookmark-toolbar'),
    height: 52,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('최신순', key: ValueKey('bookmark-sort'), style: _style),
          Text(
            '불러온 $loadedCount개',
            key: const ValueKey('bookmark-count'),
            style: _style,
          ),
        ],
      ),
    ),
  );
}

class BookmarkEmptyState extends StatelessWidget {
  const BookmarkEmptyState({required this.onOpenArchiveAll, super.key});
  final VoidCallback onOpenArchiveAll;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: const ValueKey('bookmark-empty-viewport'),
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _BookmarkEmptyLayout(
        viewportHeight: constraints.maxHeight,
        child: ConstrainedBox(
          key: const ValueKey('bookmark-empty-group'),
          constraints: const BoxConstraints(maxWidth: 260),
          child: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: const ValueKey('bookmark-empty-image'),
                  width: 40,
                  height: 46,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Transform.translate(
                          offset: const Offset(0, 2),
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 1,
                              sigmaY: 1,
                            ),
                            child: const ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Color(0x1F000000),
                                BlendMode.srcIn,
                              ),
                              child: _BookmarkEmptyIllustration(shadow: true),
                            ),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: _BookmarkEmptyIllustration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '북마크한 콘텐츠가 없어요',
                  key: ValueKey('bookmark-empty-title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    inherit: false,
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.4,
                    color: AppColors.middle,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '중요한 정보는 북마크를 통해 저장하세요!',
                  key: ValueKey('bookmark-empty-body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    inherit: false,
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.35,
                    height: 1.6,
                    color: AppColors.subtle,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 35),
                  child: Container(
                    key: const ValueKey('bookmark-empty-cta'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    foregroundDecoration: BoxDecoration(
                      border: Border.all(color: AppColors.subtler),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: onOpenArchiveAll,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                Assets.bookmarkBookOpen,
                                key: const ValueKey('bookmark-empty-cta-icon'),
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 4),
                              const Flexible(
                                child: Text(
                                  '전체 리스트 보기',
                                  style: TextStyle(
                                    inherit: false,
                                    fontFamily: 'Pretendard',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.4,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
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
    ),
  );
}

// Preserve the exact source crop; only its alpha silhouette casts the shadow.
class _BookmarkEmptyIllustration extends StatelessWidget {
  const _BookmarkEmptyIllustration({this.shadow = false});
  final bool shadow;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: [
        Positioned(
          left: -40 * 0.3072,
          top: -46 * 0.172,
          width: 40 * 1.6118,
          height: 46 * 1.3918,
          child: Image.asset(
            Assets.unclassifiedEmptyIllustration,
            key: ValueKey(
              shadow
                  ? 'bookmark-empty-image-shadow'
                  : 'bookmark-empty-image-source',
            ),
            excludeFromSemantics: true,
            fit: BoxFit.fill,
          ),
        ),
      ],
    ),
  );
}

class _BookmarkEmptyLayout extends SingleChildRenderObjectWidget {
  const _BookmarkEmptyLayout({
    required this.viewportHeight,
    required super.child,
  });
  final double viewportHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBookmarkEmptyLayout(viewportHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBookmarkEmptyLayout renderObject,
  ) => renderObject.viewportHeight = viewportHeight;
}

class _RenderBookmarkEmptyLayout extends RenderShiftedBox {
  _RenderBookmarkEmptyLayout(this._viewportHeight) : super(null);
  double _viewportHeight;

  set viewportHeight(double value) {
    if (_viewportHeight == value) return;
    _viewportHeight = value;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childSize = child!.getDryLayout(constraints.loosen());
    return constraints.constrain(
      Size(constraints.maxWidth, math.max(_viewportHeight, childSize.height)),
    );
  }

  @override
  void performLayout() {
    child!.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(
      Size(constraints.maxWidth, math.max(_viewportHeight, child!.size.height)),
    );
    final freeHeight = size.height - child!.size.height;
    (child!.parentData! as BoxParentData).offset = Offset(
      (size.width - child!.size.width) / 2,
      (freeHeight / 2 - 43.5).clamp(0.0, freeHeight),
    );
  }
}
