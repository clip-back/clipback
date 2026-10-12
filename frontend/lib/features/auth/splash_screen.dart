import 'dart:async';

import 'package:clipback_frontend/features/auth/entry_widgets.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return EntrySurface(
      backgroundColor: AppColors.main,
      children: [
        Positioned(
          left: 72,
          top: 346,
          width: 232,
          height: 91,
          child: Column(
            children: [
              SvgPicture.asset(
                Assets.entryLogo,
                width: 148.771,
                height: 50,
                fit: BoxFit.fill,
              ),
              const SizedBox(height: 16),
              const EntryTagline(color: AppColors.mainDeep),
            ],
          ),
        ),
      ],
    );
  }
}
