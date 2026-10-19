import 'dart:async';
import 'dart:math' as math;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
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
    return Scaffold(
      key: const ValueKey('splash-a01-body'),
      backgroundColor: AppColors.main,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: phoneWidth),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                key: const ValueKey('splash-a01-viewport'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          // Center the natural group 23.5px above safe center.
                          padding: const EdgeInsets.only(bottom: 47),
                          child: Transform.translate(
                            offset: const Offset(.5, 0),
                            child: SizedBox(
                              key: const ValueKey('splash-a01-group'),
                              width: math.max(
                                0,
                                math.min(232, constraints.maxWidth - 32),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    'assets/figma/splash-a01-logo.svg',
                                    key: const ValueKey('splash-a01-logo'),
                                    width: 148.771,
                                    height: 50,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '저장한 정보를 다시 볼 순간으로',
                                    key: ValueKey('splash-a01-tagline'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      inherit: false,
                                      fontFamily: 'RiaSansSplash',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      color: AppColors.mainDeep,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
