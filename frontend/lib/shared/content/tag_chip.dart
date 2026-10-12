import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  const TagChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.mainSubtle,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.mainDeep,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
      ),
    );
  }
}
