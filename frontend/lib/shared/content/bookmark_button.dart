import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';

class BookmarkActionButton extends StatefulWidget {
  const BookmarkActionButton({
    this.initialActive = false,
    this.onToggle,
    this.enabled = true,
    this.size = 28,
    this.hitSize = 44,
    super.key,
  });

  final bool initialActive;
  final VoidCallback? onToggle;
  final bool enabled;
  final double size;
  final double hitSize;

  @override
  State<BookmarkActionButton> createState() => _BookmarkActionButtonState();
}

class _BookmarkActionButtonState extends State<BookmarkActionButton> {
  late bool _active;

  @override
  void initState() {
    super.initState();
    _active = widget.initialActive;
  }

  @override
  void didUpdateWidget(covariant BookmarkActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialActive != widget.initialActive) {
      _active = widget.initialActive;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvgIconButton(
      asset: _active ? Assets.starFilled : Assets.star,
      enabled: widget.enabled,
      onPressed: () {
        if (!widget.enabled) return;
        widget.onToggle?.call();
        if (widget.onToggle == null) {
          setState(() => _active = !_active);
        }
      },
      size: widget.size,
      hitSize: widget.hitSize,
      color: _active ? AppColors.main : AppColors.subtler,
    );
  }
}
