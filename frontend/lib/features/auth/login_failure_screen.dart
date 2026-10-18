import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class _FailureText {
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
  static const detail = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -.35,
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
  static const contact = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.subtle,
  );
}

/// The ordinary social-login failure only. Authentication and recovery remain
/// owned by the app; no credentials or raw exception messages enter this view.
class LoginFailureScreen extends StatelessWidget {
  const LoginFailureScreen({
    required this.statusCode,
    required this.onChooseMethods,
    required this.onContinueAsGuest,
    required this.onContact,
    super.key,
  });

  final int? statusCode;
  final VoidCallback onChooseMethods;
  final VoidCallback onContinueAsGuest;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onChooseMethods();
    },
    child: PhoneFrame(
      child: Scaffold(
        key: const ValueKey('login-failure-screen'),
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _FailureHeader(onBack: onChooseMethods),
              Expanded(
                child: SizedBox(
                  key: const ValueKey('login-failure-body'),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    key: const ValueKey('login-failure-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '로그인하지 못했어요.',
                          key: ValueKey('login-failure-title'),
                          style: _FailureText.title,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '연결 상태를 확인한 뒤 다시 시도해주세요.',
                          key: ValueKey('login-failure-description'),
                          style: _FailureText.description,
                        ),
                        const SizedBox(height: 80),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(left: 1),
                            child: _FailureIllustration(),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            key: const ValueKey('login-failure-error-card'),
                            constraints: const BoxConstraints(minHeight: 103),
                            padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
                            decoration: BoxDecoration(
                              color: AppColors.faint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/figma/login-failure-alert.svg',
                                      key: const ValueKey(
                                        'login-failure-warning',
                                      ),
                                      width: 18,
                                      height: 18,
                                      excludeFromSemantics: true,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        statusCode == null
                                            ? '응답 상태를 확인할 수 없어요'
                                            : '응답 상태 : HTTP $statusCode',
                                        key: const ValueKey(
                                          'login-failure-status',
                                        ),
                                        style: _FailureText.detail,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '계속해서 로그인이 되지 않으면 문의해주세요.',
                                  key: ValueKey('login-failure-notice'),
                                  style: _FailureText.detail,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                key: const ValueKey('login-failure-footer'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 19),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FailureButton(
                      key: const ValueKey('login-failure-methods'),
                      label: '다른 로그인 방법 선택',
                      primary: true,
                      onPressed: onChooseMethods,
                    ),
                    const SizedBox(height: 8),
                    _FailureButton(
                      key: const ValueKey('login-failure-guest'),
                      label: '게스트로 시작하기',
                      primary: false,
                      onPressed: onContinueAsGuest,
                    ),
                    const SizedBox(height: 3),
                    Transform.translate(
                      offset: const Offset(.5, 0),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          const Text(
                            '계속 로그인에 실패한다면?',
                            key: ValueKey('login-failure-contact-prefix'),
                            style: _FailureText.contact,
                          ),
                          InkWell(
                            key: const ValueKey('login-failure-contact-hit'),
                            onTap: onContact,
                            borderRadius: BorderRadius.circular(4),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                child: Text(
                                  '문의하기',
                                  key: const ValueKey(
                                    'login-failure-contact-label',
                                  ),
                                  style: _FailureText.contact.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.middle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _FailureHeader extends StatelessWidget {
  const _FailureHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('login-failure-header'),
    height: 64,
    child: Stack(
      children: [
        Positioned(
          left: 4,
          top: 8.5,
          child: InkWell(
            key: const ValueKey('login-failure-back-hit'),
            onTap: onBack,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    Assets.detailBack,
                    key: const ValueKey('login-failure-back-image'),
                    width: 24,
                    height: 24,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '처음으로',
                    key: ValueKey('login-failure-header-title'),
                    style: _FailureText.header,
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

class _FailureIllustration extends StatelessWidget {
  const _FailureIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('login-failure-illustration-clip'),
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
            key: const ValueKey('login-failure-illustration-image'),
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
      ],
    ),
  );
}

class _FailureButton extends StatelessWidget {
  const _FailureButton({
    required this.label,
    required this.primary,
    required this.onPressed,
    super.key,
  });
  final String label;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
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
      textAlign: TextAlign.center,
      style: _FailureText.button.copyWith(
        color: primary ? AppColors.main : AppColors.text,
      ),
    ),
  );
}
