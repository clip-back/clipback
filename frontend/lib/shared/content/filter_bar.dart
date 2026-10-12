import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';

class ActiveFilterBar extends StatelessWidget {
  const ActiveFilterBar({
    required this.label,
    required this.onClear,
    super.key,
  });

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              color: AppColors.mainSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.mainDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SvgIconButton(
                  asset: Assets.close,
                  onPressed: onClear,
                  size: 14,
                  hitSize: 30,
                  color: AppColors.mainDeep,
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.subtle,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '전체보기',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
