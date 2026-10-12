import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgIcon extends StatelessWidget {
  const SvgIcon({
    required this.asset,
    this.size = 24,
    this.color = AppColors.text,
    super.key,
  });

  final String asset;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class FolderGlyph extends StatelessWidget {
  const FolderGlyph({required this.color, this.size = 40, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.folder_rounded, color: color, size: size);
  }
}
