import 'package:clipback_frontend/shared/theme/assets.dart';
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
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              SvgIcon(asset: iconAsset, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
