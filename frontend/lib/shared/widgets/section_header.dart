import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/app_text.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.onTap,
    this.horizontalPadding = 16,
    this.iconAsset = Assets.chevronRight,
    this.showTrailingIcon = true,
    super.key,
  });

  final String title;

  /// Null makes a plain title: no ink, no button semantics.
  final VoidCallback? onTap;
  final double horizontalPadding;
  final String iconAsset;
  final bool showTrailingIcon;

  @override
  Widget build(BuildContext context) {
    final header = ConstrainedBox(
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
            if (showTrailingIcon) SvgIcon(asset: iconAsset, size: 24),
          ],
        ),
      ),
    );
    return onTap == null ? header : InkWell(onTap: onTap, child: header);
  }
}
