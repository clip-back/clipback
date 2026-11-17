import 'dart:async';
import 'dart:math' as math;

import 'package:clipback_frontend/features/account/contact_form.dart';
import 'package:clipback_frontend/features/auth/entry_widgets.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/notice_snack_bar.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/gestures.dart';
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
    if (!linkingGuest && onBack == null && providers.isNotEmpty) {
      return _OrdinaryLoginScreen(
        providers: providers,
        busy: busy,
        onContinue: onContinue,
        onSocialLogin: onSocialLogin,
      );
    }
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

abstract final class _LoginAssets {
  static const logo = 'assets/figma/login-a02-logo.svg';
  static const kakao = 'assets/figma/kakao-login.png';
  static const apple = 'assets/figma/login-a02-apple.png';
  static const google = 'assets/figma/google-login.png';
  static const divider = 'assets/icons/login-a02-divider.svg';
}

abstract final class _LoginText {
  static const tagline = TextStyle(
    inherit: false,
    fontFamily: 'RiaSansLogin',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.subtle,
  );
  static const social = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.375,
    color: AppColors.text,
  );
  static const separator = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.subtler,
  );
  static const guest = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.middle,
  );
  static const terms = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: -0.325,
    color: AppColors.subtle,
  );
  static const termsLink = TextStyle(
    fontWeight: FontWeight.w600,
    color: AppColors.middle,
  );
}

class _OrdinaryLoginScreen extends StatelessWidget {
  const _OrdinaryLoginScreen({
    required this.providers,
    required this.busy,
    required this.onContinue,
    required this.onSocialLogin,
  });

  final List<SocialLoginProvider> providers;
  final bool busy;
  final Future<void> Function() onContinue;
  final Future<void> Function(SocialLoginProvider) onSocialLogin;

  @override
  Widget build(BuildContext context) {
    final ordered = const [
      SocialLoginProvider.kakao,
      SocialLoginProvider.apple,
      SocialLoginProvider.google,
    ].where(providers.contains).toList(growable: false);
    // A02 (#412): the terms line ends 11 above the safe bottom and the guest
    // label ends 30 above the terms line (83 above the safe bottom at 1x).
    // The label is centered in its 44px hit box, so the gap under the hit box
    // is 30 minus half of the box's spare height (17 at 1x).
    final guestLabel = TextPainter(
      text: const TextSpan(text: '게스트로 시작하기', style: _LoginText.guest),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final termsGap = 30 - (44 - guestLabel.height) / 2;
    guestLabel.dispose();
    const bottom = 11.0;
    return PhoneFrame(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          // The logo stays 129 below the safe top. Only the logo-button gap
          // (at least 159) grows; a shorter screen scrolls.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: const ValueKey('login-a02-viewport'),
              padding: EdgeInsets.fromLTRB(16, 129, 16, bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 129 - bottom),
                ),
                child: Column(
                  key: const ValueKey('login-a02-body'),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Transform.translate(
                      offset: const Offset(0.5, 0),
                      child: Center(
                        child: SizedBox(
                          width: 232,
                          child: Column(
                            key: const ValueKey('login-logo-group'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                _LoginAssets.logo,
                                key: const ValueKey('login-logo'),
                                width: 178.525,
                                height: 60,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '저장한 정보를 다시 볼 순간으로',
                                key: ValueKey('login-tagline'),
                                textAlign: TextAlign.center,
                                style: _LoginText.tagline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 159),
                        Column(
                          key: const ValueKey('login-controls'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < ordered.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              _LoginProviderButton(
                                provider: ordered[i],
                                onPressed: busy
                                    ? null
                                    : () =>
                                          unawaited(onSocialLogin(ordered[i])),
                              ),
                            ],
                          ],
                        ),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            key: const ValueKey('login-divider'),
                            children: [
                              const Expanded(
                                child: _LoginDivider(side: 'left'),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '또는',
                                key: ValueKey('login-or'),
                                style: _LoginText.separator,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: _LoginDivider(side: 'right'),
                              ),
                            ],
                          ),
                        ),
                        // The 44px hit box adds 13px above the 18px base label.
                        // Together with this gap the visual paragraph gap is 24px.
                        const SizedBox(height: 11),
                        SizedBox(
                          key: const ValueKey('login-guest-hit'),
                          height: 44,
                          child: TextButton(
                            onPressed: busy
                                ? null
                                : () => unawaited(onContinue()),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '게스트로 시작하기',
                              key: ValueKey('login-guest-label'),
                              style: _LoginText.guest,
                            ),
                          ),
                        ),
                        SizedBox(height: termsGap),
                        const _LoginTerms(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _termsFailureMessage = '서비스 이용약관을 열지 못했어요. 다시 시도해 주세요.';
const _privacyFailureMessage = '개인정보처리방침을 열지 못했어요. 다시 시도해 주세요.';

/// The A02 terms line (Figma 111:3419). Each of the two words opens its web
/// page like the My privacy row (#349), also while a login is busy (#412).
class _LoginTerms extends StatefulWidget {
  const _LoginTerms();

  @override
  State<_LoginTerms> createState() => _LoginTermsState();
}

class _LoginTermsState extends State<_LoginTerms> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => _open(openTermsOfService, _termsFailureMessage);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _open(openPrivacyPolicy, _privacyFailureMessage);

  Future<void> _open(Future<bool?> Function() open, String failure) async {
    if (await open() == false && mounted) {
      // Same rule as the app's MessageEffect notices (#353).
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(noticeSnackBar(context, failure));
    }
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text.rich(
    key: const ValueKey('login-terms'),
    textAlign: TextAlign.center,
    TextSpan(
      style: _LoginText.terms,
      children: [
        const TextSpan(text: '계속하면 허투루의 '),
        TextSpan(
          text: '서비스 이용약관',
          style: _LoginText.termsLink,
          recognizer: _terms,
        ),
        // Figma keeps this line break (decision 4).
        const TextSpan(text: '에 동의하며,\n'),
        TextSpan(
          text: '개인정보처리방침',
          style: _LoginText.termsLink,
          recognizer: _privacy,
        ),
        const TextSpan(text: '을 확인한 것으로 간주합니다.'),
      ],
    ),
  );
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider({required this.side});

  final String side;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(0, -1),
    child: SizedBox(
      key: ValueKey('login-divider-$side'),
      height: 1,
      child: SvgPicture.asset(_LoginAssets.divider, fit: BoxFit.fill),
    ),
  );
}

class _LoginProviderButton extends StatelessWidget {
  const _LoginProviderButton({required this.provider, required this.onPressed});

  final SocialLoginProvider provider;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground, labelDx) = switch (provider) {
      SocialLoginProvider.kakao => (
        '카카오로 계속하기',
        const Color(0xFFFDDC3F),
        AppColors.text,
        1.0,
      ),
      SocialLoginProvider.apple => (
        'Apple로 계속하기',
        Colors.black,
        Colors.white,
        1.5,
      ),
      SocialLoginProvider.google => (
        'Google로 계속하기',
        Colors.white,
        AppColors.text,
        1.5,
      ),
    };
    final (path, width, height, left, sx, sy, dx, dy) = switch (provider) {
      SocialLoginProvider.kakao => (
        _LoginAssets.kakao,
        24.0,
        24.0,
        16.0,
        1.5833,
        1.5833,
        -0.2917,
        -0.2917,
      ),
      SocialLoginProvider.apple => (
        _LoginAssets.apple,
        21.0,
        20.0,
        16.0,
        1.3894,
        1.2377,
        -0.1947,
        -0.1189,
      ),
      SocialLoginProvider.google => (
        _LoginAssets.google,
        18.0,
        18.0,
        18.0,
        1.0,
        1.0,
        0.0,
        0.0,
      ),
    };
    return SizedBox(
      key: ValueKey('login-provider-${provider.name}'),
      height: 52,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: provider == SocialLoginProvider.google
                  ? Border.all(color: AppColors.subtler, width: 0.5)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: left,
                  top: (52 - height) / 2,
                  width: width,
                  height: height,
                  child: SizedBox(
                    key: ValueKey('login-provider-icon-${provider.name}'),
                    child: ClipRect(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: width * dx,
                            top: height * dy,
                            width: width * sx,
                            height: height * sy,
                            child: Image.asset(
                              path,
                              key: ValueKey(
                                'login-provider-image-${provider.name}',
                              ),
                              fit: BoxFit.fill,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(labelDx, 0),
                  child: Text(
                    label,
                    key: ValueKey('login-provider-label-${provider.name}'),
                    maxLines: 1,
                    softWrap: false,
                    style: _LoginText.social.copyWith(color: foreground),
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
