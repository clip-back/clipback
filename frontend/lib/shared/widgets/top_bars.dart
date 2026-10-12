import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({required this.title, this.onBack, this.onSearch, super.key});

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (onBack != null) ...[
              SvgIconButton(asset: Assets.back, onPressed: onBack!, size: 24),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.45,
              ),
            ),
            const Spacer(),
            if (onSearch != null)
              SvgIconButton(
                asset: Assets.search,
                onPressed: onSearch!,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
