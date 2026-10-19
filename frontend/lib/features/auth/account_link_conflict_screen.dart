import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class _ConflictText {
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
  static const warning = TextStyle(
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

/// An explicit choice to keep the guest session or start a fresh social login.
/// Target-account identity is intentionally absent: upgrade409 does not supply it.
class AccountLinkConflictScreen extends StatelessWidget {
  const AccountLinkConflictScreen({
    required this.onKeepGuest,
    required this.onConfirm,
    super.key,
  });

  final VoidCallback onKeepGuest;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onKeepGuest();
    },
    child: PhoneFrame(
      child: Scaffold(
        key: const ValueKey('account-link-conflict-screen'),
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                key: const ValueKey('account-link-conflict-header'),
                height: 64,
                child: Stack(
                  children: [
                    Positioned(
                      left: 4,
                      top: 8.5,
                      child: InkWell(
                        key: const ValueKey('account-link-conflict-back-hit'),
                        onTap: onKeepGuest,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                Assets.detailBack,
                                key: const ValueKey(
                                  'account-link-conflict-back-image',
                                ),
                                width: 24,
                                height: 24,
                                excludeFromSemantics: true,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '처음으로',
                                key: ValueKey(
                                  'account-link-conflict-header-title',
                                ),
                                style: _ConflictText.header,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SizedBox(
                  key: const ValueKey('account-link-conflict-body'),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    key: const ValueKey('account-link-conflict-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '계정 연결을 확인해 주세요.',
                          key: ValueKey('account-link-conflict-title'),
                          style: _ConflictText.title,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '기존 계정으로 전환하면 현재 게스트의 저장 데이터는 합쳐지지 않으며, 이 기기에서 다시 접근하지 못할 수 있어요. 기존 계정으로 로그인할까요?',
                          key: ValueKey('account-link-conflict-warning'),
                          style: _ConflictText.warning,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                key: const ValueKey('account-link-conflict-footer'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ConflictButton(
                      key: const ValueKey('account-link-conflict-confirm'),
                      label: '기존 계정으로 전환',
                      primary: true,
                      onPressed: onConfirm,
                    ),
                    const SizedBox(height: 8),
                    _ConflictButton(
                      key: const ValueKey('account-link-conflict-keep'),
                      label: '게스트 유지',
                      primary: false,
                      onPressed: onKeepGuest,
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

class _ConflictButton extends StatelessWidget {
  const _ConflictButton({
    required this.label,
    required this.primary,
    required this.onPressed,
    super.key,
  });
  final String label;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: primary ? AppColors.text : Colors.white,
      foregroundColor: primary ? AppColors.main : AppColors.text,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
      style: _ConflictText.button.copyWith(
        color: primary ? AppColors.main : AppColors.text,
      ),
    ),
  );
}
