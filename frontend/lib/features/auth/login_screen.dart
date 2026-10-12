import 'dart:async';

import 'package:clipback_frontend/features/auth/entry_widgets.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    required this.onContinue,
    required this.onSocialLogin,
    required this.providers,
    this.busy = false,
    this.linkingGuest = false,
    this.onBack,
    super.key,
  });

  final Future<void> Function() onContinue;
  final Future<void> Function(SocialLoginProvider) onSocialLogin;
  final List<SocialLoginProvider> providers;
  final bool busy;
  final bool linkingGuest;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                if (onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: busy ? null : onBack,
                      child: const Text('뒤로'),
                    ),
                  ),
                const SizedBox(height: 70),
                SvgPicture.asset(Assets.entryLogo, width: 179, height: 60),
                const SizedBox(height: 16),
                const EntryTagline(color: AppColors.subtle),
                const SizedBox(height: 72),
                if (linkingGuest) ...[
                  const Text(
                    '게스트의 저장 데이터를 계정에 연결해요.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
                for (final provider in providers) ...[
                  SocialButton(
                    label: switch (provider) {
                      SocialLoginProvider.apple => 'Apple로 계속하기',
                      SocialLoginProvider.google => '구글로 계속하기',
                      SocialLoginProvider.kakao => '카카오로 계속하기',
                    },
                    color: switch (provider) {
                      SocialLoginProvider.apple => Colors.black,
                      SocialLoginProvider.kakao => const Color(0xFFFEE500),
                      SocialLoginProvider.google => Colors.white,
                    },
                    foreground: provider == SocialLoginProvider.apple
                        ? Colors.white
                        : AppColors.text,
                    iconAsset: switch (provider) {
                      SocialLoginProvider.apple => null,
                      SocialLoginProvider.google => Assets.googleLogin,
                      SocialLoginProvider.kakao => Assets.kakaoLogin,
                    },
                    icon: provider == SocialLoginProvider.apple
                        ? Icons.apple
                        : null,
                    iconLeft: 18,
                    iconTop: 14,
                    iconSize: 24,
                    borderColor: provider == SocialLoginProvider.google
                        ? AppColors.subtler
                        : null,
                    onPressed: busy
                        ? null
                        : () => unawaited(onSocialLogin(provider)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                TextButton(
                  onPressed: busy ? null : () => unawaited(onContinue()),
                  child: Text(linkingGuest ? '게스트로 계속 사용' : '게스트로 시작하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    required this.label,
    required this.color,
    required this.foreground,
    this.iconAsset,
    this.icon,
    required this.iconLeft,
    required this.iconTop,
    required this.iconSize,
    required this.onPressed,
    this.borderColor,
    super.key,
  });

  final String label;
  final Color color;
  final Color foreground;
  final String? iconAsset;
  final IconData? icon;
  final double iconLeft;
  final double iconTop;
  final double iconSize;
  final VoidCallback? onPressed;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor!, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: iconLeft,
                  top: iconTop,
                  width: iconSize,
                  height: iconSize,
                  child: icon != null
                      ? Icon(icon, color: foreground, size: iconSize)
                      : Image.asset(
                          iconAsset!,
                          width: iconSize,
                          height: iconSize,
                          fit: BoxFit.cover,
                        ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.35,
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
