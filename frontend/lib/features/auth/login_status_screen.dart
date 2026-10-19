import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class _StatusText {
  static const header = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -.45,
    color: Colors.black,
  );
  static const title = TextStyle(
    inherit: false,
    fontFamily: 'PretendardDetail',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -.6,
    color: AppColors.text,
    height: 1.6,
  );
  static const description = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -.4,
    color: AppColors.subtle,
    height: 1.5,
  );
  static const button = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 22 / 16,
  );
}

/// A03 is only presentation of an owned ordinary authentication request.
/// The SDK owns cancellation; the existing busy lock cannot abort credentials.
class LoginProgressScreen extends StatelessWidget {
  const LoginProgressScreen({super.key});
  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    child: PhoneFrame(
      child: Scaffold(
        key: const ValueKey('login-progress-screen'),
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              const _StatusHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    key: const ValueKey('login-progress-scroll'),
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
                            // Safe-center -27px = remaining body center -59px (64px header).
                            Padding(
                              padding: const EdgeInsets.only(bottom: 118),
                              child: Transform.translate(
                                offset: const Offset(.5, 0),
                                child: SizedBox(
                                  key: const ValueKey('login-progress-group'),
                                  width: 224,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/figma/logout-illustration.png',
                                        key: const ValueKey(
                                          'login-progress-illustration',
                                        ),
                                        width: 224,
                                        height: 224,
                                        fit: BoxFit.cover,
                                        excludeFromSemantics: true,
                                      ),
                                      const SizedBox(
                                        width: 192,
                                        child: Text(
                                          '로그인하고 있어요',
                                          key: ValueKey('login-progress-title'),
                                          textAlign: TextAlign.center,
                                          style: _StatusText.title,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        '인증이 끝날 때까지\n잠시 기다려주세요',
                                        key: ValueKey(
                                          'login-progress-description',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: _StatusText.description,
                                      ),
                                      const SizedBox(height: 32),
                                      SvgPicture.asset(
                                        'assets/figma/home-initial-loading-dots.svg',
                                        key: const ValueKey(
                                          'login-progress-dots',
                                        ),
                                        width: 52,
                                        height: 12,
                                        excludeFromSemantics: true,
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
            ],
          ),
        ),
      ),
    ),
  );
}

/// A04 follows an actual null SDK result, never a caught HTTP/SDK failure.
class LoginCancelledScreen extends StatelessWidget {
  const LoginCancelledScreen({
    required this.onChooseMethods,
    required this.onContinueAsGuest,
    super.key,
  });
  final VoidCallback onChooseMethods, onContinueAsGuest;
  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onChooseMethods();
    },
    child: PhoneFrame(
      child: Scaffold(
        key: const ValueKey('login-cancelled-screen'),
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _StatusHeader(onBack: onChooseMethods),
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    key: const ValueKey('login-cancelled-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '로그인이 취소됐어요.',
                          key: ValueKey('login-cancelled-title'),
                          style: _StatusText.title,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 282),
                            child: Text(
                              '계속하려면 로그인 방법을 다시 선택해주세요.',
                              key: ValueKey('login-cancelled-description'),
                              style: _StatusText.description,
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 1),
                            child: SizedBox(
                              key: const ValueKey(
                                'login-cancelled-illustration',
                              ),
                              width: 110,
                              height: 148,
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned(
                                    left: -110 * .3763,
                                    top: -148 * .1386,
                                    width: 110 * 1.7526,
                                    height: 148 * 1.3031,
                                    child: Image.asset(
                                      'assets/figma/login-failure-illustration.png',
                                      key: const ValueKey(
                                        'login-cancelled-image',
                                      ),
                                      fit: BoxFit.fill,
                                      excludeFromSemantics: true,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusButton(
                      name: 'primary',
                      label: '다른 로그인 방법 선택',
                      primary: true,
                      onPressed: onChooseMethods,
                    ),
                    const SizedBox(height: 8),
                    _StatusButton(
                      name: 'guest',
                      label: '게스트로 시작하기',
                      primary: false,
                      onPressed: onContinueAsGuest,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({this.onBack});
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('login-status-header'),
    height: 64,
    child: Stack(
      children: [
        Positioned(
          left: 4,
          top: 8.5,
          child: InkWell(
            key: const ValueKey('login-status-back'),
            onTap: onBack,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    Assets.detailBack,
                    key: const ValueKey('login-status-back-image'),
                    width: 24,
                    height: 24,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '처음으로',
                    key: ValueKey('login-status-heading'),
                    style: _StatusText.header,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.name,
    required this.label,
    required this.primary,
    required this.onPressed,
  });
  final String name, label;
  final bool primary;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton(
    key: ValueKey('login-cancelled-$name'),
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: primary ? AppColors.text : Colors.white,
      foregroundColor: primary ? AppColors.main : AppColors.text,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      minimumSize: const Size(0, 48),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: primary
          ? BorderSide.none
          : const BorderSide(color: AppColors.subtle),
      elevation: 0,
    ),
    child: Text(
      label,
      key: ValueKey('login-cancelled-$name-label'),
      textAlign: TextAlign.center,
      style: _StatusText.button.copyWith(
        color: primary ? AppColors.main : AppColors.text,
      ),
    ),
  );
}
