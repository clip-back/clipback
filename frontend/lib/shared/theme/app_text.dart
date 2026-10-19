import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppText {
  static const sectionTitle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    color: AppColors.text,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
  );
  static const primaryButtonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const title24 = TextStyle(
    color: AppColors.text,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.5,
  );
  static const body16Subtle = TextStyle(
    color: AppColors.subtle,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );
}
