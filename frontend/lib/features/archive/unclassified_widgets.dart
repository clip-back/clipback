import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UnclassifiedTopBar extends StatelessWidget {
  const UnclassifiedTopBar({
    required this.onBack,
    required this.onSearch,
    this.onOpenCategoryManagement,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback? onOpenCategoryManagement;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('unclassified-header'),
    height: appHeaderHeight,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 1, 16, 0),
      child: Row(
        children: [
          _UnclassifiedAssetButton(
            key: const ValueKey('unclassified-back'),
            asset: Assets.detailBack,
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '분류가 필요한 콘텐츠',
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
          const SizedBox(width: 8),
          _UnclassifiedAssetButton(
            key: const ValueKey('unclassified-search'),
            asset: Assets.archiveSearch,
            onPressed: onSearch,
          ),
          const SizedBox(width: 16),
          _UnclassifiedAssetButton(
            key: const ValueKey('unclassified-settings'),
            asset: Assets.archiveSettings,
            onPressed: onOpenCategoryManagement,
          ),
        ],
      ),
    ),
  );
}

class _UnclassifiedAssetButton extends StatelessWidget {
  const _UnclassifiedAssetButton({
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

class UnclassifiedEmptyState extends StatelessWidget {
  const UnclassifiedEmptyState({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: const ValueKey('unclassified-empty-viewport'),
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _UnclassifiedEmptyLayout(
        viewportHeight: constraints.maxHeight,
        child: ConstrainedBox(
          key: const ValueKey('unclassified-empty-group'),
          constraints: const BoxConstraints(minHeight: 250, maxWidth: 224),
          child: SizedBox(
            width: 224,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: const ValueKey('unclassified-empty-image'),
                  width: 86,
                  height: 100,
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
                              child: _UnclassifiedEmptyIllustration(
                                shadow: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: _UnclassifiedEmptyIllustration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 192,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '분류가 필요한\n콘텐츠가 없어요',
                        key: ValueKey('unclassified-empty-title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          inherit: false,
                          fontFamily: 'PretendardDetail',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          height: 1.6,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '저장한 콘텐츠가\n모두 정리되어있어요',
                        key: ValueKey('unclassified-empty-body'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          inherit: false,
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.4,
                          height: 1.5,
                          color: AppColors.subtle,
                        ),
                      ),
                    ],
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

// Clip the original image before applying its silhouette shadow. A rectangular
// BoxShadow would darken the transparent corners of the Figma illustration.
class _UnclassifiedEmptyIllustration extends StatelessWidget {
  const _UnclassifiedEmptyIllustration({this.shadow = false});
  final bool shadow;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: [
        Positioned(
          left: -86 * 0.3072,
          top: -100 * 0.172,
          width: 86 * 1.6118,
          height: 100 * 1.3918,
          child: Image.asset(
            Assets.unclassifiedEmptyIllustration,
            key: ValueKey(
              shadow
                  ? 'unclassified-empty-image-shadow'
                  : 'unclassified-empty-image-source',
            ),
            excludeFromSemantics: true,
            fit: BoxFit.fill,
          ),
        ),
      ],
    ),
  );
}

// Position the naturally laid-out group within the real body. In a short
// viewport the group starts at zero and the enclosing scroll view exposes it.
class _UnclassifiedEmptyLayout extends SingleChildRenderObjectWidget {
  const _UnclassifiedEmptyLayout({
    required this.viewportHeight,
    required super.child,
  });

  final double viewportHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderUnclassifiedEmptyLayout(viewportHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderUnclassifiedEmptyLayout renderObject,
  ) => renderObject.viewportHeight = viewportHeight;
}

class _RenderUnclassifiedEmptyLayout extends RenderShiftedBox {
  _RenderUnclassifiedEmptyLayout(this._viewportHeight) : super(null);

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
      (freeHeight / 2 - 84).clamp(0.0, freeHeight),
    );
  }
}
