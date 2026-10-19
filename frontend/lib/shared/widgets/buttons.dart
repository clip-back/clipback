import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/app_text.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.color = AppColors.text,
    this.foreground = AppColors.main,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: AppText.primaryButtonLabel,
        ),
        child: Text(label),
      ),
    );
  }
}

class FloatingAddButton extends StatelessWidget {
  const FloatingAddButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.text,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: SvgPicture.asset(
          Assets.plus,
          colorFilter: const ColorFilter.mode(AppColors.main, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.asset,
    required this.onPressed,
    this.rotate = false,
    this.iconSize = 28,
    this.backgroundOpacity = 0.45,
    super.key,
  });

  final String asset;
  final VoidCallback? onPressed;
  final bool rotate;
  final double iconSize;
  final double backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    final icon = SvgIcon(
      asset: asset,
      size: iconSize,
      color: onPressed == null ? AppColors.subSubtle : AppColors.text,
    );
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: backgroundOpacity),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: rotate ? Transform.rotate(angle: 3.14159, child: icon) : icon,
        ),
      ),
    );
  }
}

class SvgIconButton extends StatelessWidget {
  const SvgIconButton({
    required this.asset,
    required this.onPressed,
    this.enabled = true,
    this.size = 24,
    this.hitSize = 44,
    this.color = AppColors.text,
    super.key,
  });

  final String asset;
  final VoidCallback onPressed;
  final bool enabled;
  final double size;
  final double hitSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: hitSize,
      height: hitSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tight(Size(hitSize, hitSize)),
        onPressed: enabled ? onPressed : null,
        icon: SvgIcon(asset: asset, size: size, color: color),
      ),
    );
  }
}
