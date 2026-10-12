import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ContentMutationStatus extends StatelessWidget {
  const ContentMutationStatus({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(color: AppColors.subtle, fontSize: 11),
  );
}
