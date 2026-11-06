import 'package:clipback_frontend/features/account/account_deletion_screen.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';

/// Figma J06 111:5756 (queried 2026-11-06). The app is already logged out;
/// the button and system back both open login (D22).
class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDone();
      },
      child: PhoneFrame(
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewport) => SingleChildScrollView(
                      key: const ValueKey('account-deleted-scroll'),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: viewport.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const Spacer(),
                              Padding(
                                key: const ValueKey('account-deleted-body'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  children: [
                                    Image.asset(
                                      Assets.accountDeletedIllustration,
                                      key: const ValueKey(
                                        'account-deleted-illustration',
                                      ),
                                      width: 277,
                                      height: 277,
                                      fit: BoxFit.cover,
                                      excludeFromSemantics: true,
                                    ),
                                    const Text(
                                      '탈퇴가 완료되었습니다.',
                                      key: ValueKey('account-deleted-title'),
                                      textAlign: TextAlign.center,
                                      style: AccountDeletionText.title,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '그동안 이용해주셔서 감사합니다\n'
                                      '회원가입을 통해 언제든지 다시 시작하세요!',
                                      key: ValueKey(
                                        'account-deleted-description',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: AccountDeletionText.description,
                                    ),
                                  ],
                                ),
                              ),
                              // Figma centers the group 29.5px above the body center.
                              const SizedBox(height: 59),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  key: const ValueKey('account-deleted-footer'),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: AccountDeletionButton(
                      key: const ValueKey('account-deleted-login'),
                      label: '로그인 화면으로 돌아가기',
                      background: AppColors.text,
                      foreground: AppColors.main,
                      minHeight: 56,
                      onPressed: onDone,
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
}
