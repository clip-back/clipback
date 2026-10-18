import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeInitialLoadingScreen extends StatelessWidget {
  const HomeInitialLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        key: const ValueKey('home-initial-loading-screen'),
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: const ValueKey('home-initial-loading-viewport'),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Transform.translate(
                          offset: const Offset(.5, 0),
                          child: SizedBox(
                            key: const ValueKey('home-initial-loading-group'),
                            width: 224,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  Assets.homeInitialLoadingIllustration,
                                  key: const ValueKey(
                                    'home-initial-loading-illustration',
                                  ),
                                  width: 224,
                                  height: 224,
                                  fit: BoxFit.cover,
                                ),
                                const SizedBox(
                                  width: 192,
                                  child: Text(
                                    '홈을 불러오는 중',
                                    key: ValueKey('home-initial-loading-title'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      inherit: false,
                                      fontFamily: 'PretendardDetail',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -.6,
                                      color: AppColors.text,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '저장한 콘텐츠를 준비하고 있어요',
                                  key: ValueKey(
                                    'home-initial-loading-description',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    inherit: false,
                                    fontFamily: 'Pretendard',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -.4,
                                    color: AppColors.subtle,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: 52,
                                  height: 12,
                                  child: SvgPicture.asset(
                                    Assets.homeInitialLoadingDots,
                                    key: const ValueKey(
                                      'home-initial-loading-dots',
                                    ),
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
    );
  }
}
