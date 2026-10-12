import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PageDots extends StatelessWidget {
  const PageDots({required this.count, required this.activeIndex, super.key});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: activeIndex == index ? 10 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: activeIndex == index ? AppColors.text : AppColors.subtler,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}
