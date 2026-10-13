import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/app_text.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    required this.onTap,
    this.horizontalPadding = 16,
    this.iconAsset = Assets.chevronRight,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final double horizontalPadding;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sectionTitle,
                ),
              ),
              SvgIcon(asset: iconAsset, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
