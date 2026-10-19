import 'dart:async';

import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Explicit local roles retain AUTO font metrics without inherited theme styles.
abstract final class _AccountText {
  static const header = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
    color: Colors.black,
  );
  static const name = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: Colors.black,
  );
  static const section = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AppColors.text,
  );
  static const row = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: Colors.black,
  );
  static const status = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: AppColors.subtle,
  );
}

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({
    required this.user,
    required this.onBack,
    required this.onLogout,
    required this.onConnect,
    required this.isGuest,
    this.busy = false,
    super.key,
  });

  final AppUser user;
  final VoidCallback onBack;
  final Future<void> Function() onLogout;
  final Future<void> Function() onConnect;
  final bool? isGuest;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _AccountHeader(onBack: onBack),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('account-viewport'),
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(left: 1),
                          child: _AccountAvatar(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          user.name,
                          key: const ValueKey('account-name'),
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: _AccountText.name,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _AccountSection(
                        key: ValueKey('account-section-connected'),
                        title: '연결된 계정',
                      ),
                      _AccountGroup(
                        id: 'account-connected-group',
                        children: [
                          AccountManagementTile(
                            leading: user.providerLabel,
                            trailing: isGuest == false ? '연결됨' : null,
                            onTap: null,
                          ),
                          if (isGuest != false)
                            AccountManagementTile(
                              leading: isGuest == true
                                  ? '계정 연결하기'
                                  : '계정 정보 다시 확인',
                              onTap: busy ? null : () => unawaited(onConnect()),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _AccountSection(
                        key: ValueKey('account-section-actions'),
                        title: '계정',
                      ),
                      _AccountGroup(
                        id: 'account-actions-group',
                        children: [
                          AccountManagementTile(
                            leading: '로그아웃',
                            onTap: busy ? null : () => unawaited(onLogout()),
                          ),
                          const SizedBox(height: 10),
                          AccountManagementTile(
                            leading: '회원 탈퇴',
                            onTap: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('회원 탈퇴 API는 아직 제공되지 않습니다.'),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('account-header'),
      height: appHeaderHeight,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(
                  left: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Text('계정 관리', style: _AccountText.header),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 8.5,
                  child: Semantics(
                    button: true,
                    label: '뒤로가기',
                    child: InkWell(
                      key: const ValueKey('account-back-hit'),
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.detailBack,
                            key: const ValueKey('account-back-image'),
                            width: 24,
                            height: 24,
                          ),
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
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar();

  @override
  Widget build(BuildContext context) {
    const clipWidth = 88.038;
    const clipHeight = 97.821;
    return SizedBox(
      key: const ValueKey('account-avatar'),
      width: 140,
      height: 140,
      child: Stack(
        children: [
          SvgPicture.asset(
            'assets/icons/account-avatar-background.svg',
            key: const ValueKey('account-avatar-background'),
            width: 140,
            height: 140,
          ),
          Positioned(
            left: 24.23,
            top: 18.84,
            width: clipWidth,
            height: clipHeight,
            child: ClipRect(
              key: const ValueKey('account-avatar-character-clip'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -0.2301 * clipWidth,
                    top: -0.1452 * clipHeight,
                    width: 1.5323 * clipWidth,
                    height: 1.3621 * clipHeight,
                    child: Image.asset(
                      'assets/figma/my-avatar-character.png',
                      key: const ValueKey('account-avatar-character-source'),
                      fit: BoxFit.fill,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: _AccountText.section),
        ),
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.id, required this.children});

  final String id;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        key: ValueKey(id),
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class AccountManagementTile extends StatelessWidget {
  const AccountManagementTile({
    required this.leading,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final String leading;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('account-row-$leading'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 41),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(leading, softWrap: true, style: _AccountText.row),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(trailing!, style: _AccountText.status),
                const SizedBox(width: 16),
              ] else
                const SizedBox(width: 8),
              SizedBox(
                key: ValueKey('account-arrow-$leading'),
                width: 5,
                height: 10,
                child: OverflowBox(
                  minWidth: 6.66667,
                  maxWidth: 6.66667,
                  minHeight: 11.6667,
                  maxHeight: 11.6667,
                  child: SvgPicture.asset(
                    'assets/icons/my-menu-chevron.svg',
                    key: ValueKey('account-arrow-image-$leading'),
                    width: 6.66667,
                    height: 11.6667,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
