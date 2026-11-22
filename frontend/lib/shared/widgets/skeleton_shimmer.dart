import 'dart:ui' as ui;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/widgets.dart';

const _period = Duration(milliseconds: 1500);
const _bandWidthFactor = 0.4;

/// One shimmer area. Every [SkeletonShimmerBars] below it shares a single band
/// that crosses the area left to right. With the platform's reduced motion
/// setting on, the bars stay still and no frame is scheduled.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );
  bool _still = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // iOS reports Reduce Motion only through accessibilityFeatures.
    _still =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    if (_still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ShimmerArea(
    animation: _still ? null : _controller,
    areaContext: context,
    child: widget.child,
  );
}

class _ShimmerArea extends InheritedWidget {
  const _ShimmerArea({
    required this.animation,
    required this.areaContext,
    required super.child,
  });

  final Animation<double>? animation;
  final BuildContext areaContext;

  @override
  bool updateShouldNotify(_ShimmerArea oldWidget) =>
      animation != oldWidget.animation;
}

/// A group of placeholder bars inside a [SkeletonShimmer]. The bars are hidden
/// from screen readers.
class SkeletonShimmerBars extends StatelessWidget {
  const SkeletonShimmerBars({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final area = context.dependOnInheritedWidgetOfExactType<_ShimmerArea>()!;
    final animation = area.animation;
    return ExcludeSemantics(
      child: animation == null
          ? child
          : AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (_, child) => ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (_) =>
                    _bandShader(context, area.areaContext, animation.value),
                child: child,
              ),
            ),
    );
  }
}

Shader _bandShader(BuildContext bars, BuildContext area, double progress) {
  final areaBox = area.findRenderObject()! as RenderBox;
  final barsBox = bars.findRenderObject()! as RenderBox;
  final barsLeft = barsBox.localToGlobal(Offset.zero, ancestor: areaBox).dx;
  final bandWidth = areaBox.size.width * _bandWidthFactor;
  final bandLeft =
      -bandWidth + progress * (areaBox.size.width + bandWidth) - barsLeft;
  return ui.Gradient.linear(
    Offset(bandLeft, 0),
    Offset(bandLeft + bandWidth, 0),
    const [AppColors.faint, AppColors.bg, AppColors.faint],
    const [0, 0.5, 1],
  );
}
