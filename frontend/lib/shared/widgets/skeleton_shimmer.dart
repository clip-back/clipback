import 'dart:ui' as ui;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/widgets.dart';

const _period = Duration(milliseconds: 1500);
const _bandWidthFactor = 0.4;
const _barRadius = BorderRadius.all(Radius.circular(4));

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
  Widget build(BuildContext context) => ExcludeSemantics(child: child);
}

/// One rounded placeholder bar. It paints the band of the [SkeletonShimmer]
/// above it directly, so no offscreen layer is needed.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({
    this.barKey,
    this.width,
    this.height,
    this.padding,
    this.child,
    super.key,
  });

  /// Key of the inner [Container] that carries the bar's size and decoration.
  final Key? barKey;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final area = context.dependOnInheritedWidgetOfExactType<_ShimmerArea>()!;
    final animation = area.animation;
    return Container(
      key: barKey,
      width: width,
      height: height,
      padding: padding,
      decoration: animation == null
          ? const BoxDecoration(
              color: AppColors.faint,
              borderRadius: _barRadius,
            )
          : _BandDecoration(animation, area.areaContext, context),
      child: child,
    );
  }
}

class _BandDecoration extends BoxDecoration {
  const _BandDecoration(this.animation, this.area, this.bar)
    : super(color: AppColors.faint, borderRadius: _barRadius);

  final Animation<double> animation;
  final BuildContext area;
  final BuildContext bar;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _BandPainter(this, onChanged);

  @override
  bool operator ==(Object other) =>
      other is _BandDecoration &&
      other.animation == animation &&
      other.area == area &&
      other.bar == bar;

  @override
  int get hashCode => Object.hash(animation, area, bar);
}

class _BandPainter extends BoxPainter {
  _BandPainter(this.decoration, VoidCallback? onChanged) : super(onChanged) {
    if (onChanged != null) decoration.animation.addListener(onChanged);
  }

  final _BandDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final areaBox = decoration.area.findRenderObject()! as RenderBox;
    final barBox = decoration.bar.findRenderObject()! as RenderBox;
    final barLeft = barBox.localToGlobal(Offset.zero, ancestor: areaBox).dx;
    final areaWidth = areaBox.size.width;
    final bandWidth = areaWidth * _bandWidthFactor;
    final bandLeft =
        offset.dx -
        barLeft -
        bandWidth +
        decoration.animation.value * (areaWidth + bandWidth);
    canvas.drawRRect(
      _barRadius.toRRect(offset & configuration.size!),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bandLeft, 0),
          Offset(bandLeft + bandWidth, 0),
          const [AppColors.faint, AppColors.bg, AppColors.faint],
          const [0, 0.5, 1],
        ),
    );
  }

  @override
  void dispose() {
    if (onChanged != null) decoration.animation.removeListener(onChanged!);
    super.dispose();
  }
}
