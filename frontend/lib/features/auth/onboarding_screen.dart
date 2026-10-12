import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    OnboardingData(
      title: '저장한 정보,\n다시 보고 있나요?',
      body: '허투루가 다시 볼 순간을 만들어 드릴게요.',
      asset: Assets.onboarding1Png,
    ),
    OnboardingData(
      title: '흩어진 정보를\n허투루 넘기지 않도록,',
      body: '필요한 순간 다시 볼 수 있게 모아둘게요.',
      asset: Assets.onboarding2Png,
    ),
    OnboardingData(
      title: '이제 다 끝났어요!\n다시 볼 준비를 해볼까요?',
      body: '알림과 갤러리를 허용하면 필요한 순간 더 쉽게 다시 만날 수 있어요.',
      asset: Assets.onboarding3Png,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                onPageChanged: (value) => setState(() => _page = value),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index]),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 128,
                child: PageDots(count: _pages.length, activeIndex: _page),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 40,
                child: PrimaryButton(
                  label: _page == _pages.length - 1 ? '시작하기' : '다음',
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 104),
          Text(
            data.title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 26,
              fontWeight: FontWeight.w600,
              height: 1.4,
              letterSpacing: -0.65,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.body,
            style: const TextStyle(
              color: AppColors.subtle,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.5,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          Center(
            child: Image.asset(
              data.asset,
              width: 311,
              height: 252,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 200),
        ],
      ),
    );
  }
}

class OnboardingData {
  const OnboardingData({
    required this.title,
    required this.body,
    required this.asset,
  });

  final String title;
  final String body;
  final String asset;
}
