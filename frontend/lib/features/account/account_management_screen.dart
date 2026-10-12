import 'dart:async';

import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';

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
        body: Column(
          children: [
            const DesignStatusBar(),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  SvgIconButton(
                    asset: Assets.back,
                    onPressed: onBack,
                    size: 24,
                    hitSize: 48,
                    color: AppColors.text,
                  ),
                  const Text(
                    '계정 관리',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Image.asset(Assets.character1Png, width: 140, height: 140),
            const SizedBox(height: 10),
            Text(
              user.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '연결된 계정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AccountManagementTile(
              leading: user.providerLabel,
              trailing: isGuest == false ? '연결됨' : null,
              onTap: null,
            ),
            if (isGuest != false)
              AccountManagementTile(
                leading: isGuest == true ? '계정 연결하기' : '계정 정보 다시 확인',
                onTap: busy ? null : () => unawaited(onConnect()),
              ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '계정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AccountManagementTile(
              leading: '로그아웃',
              onTap: busy ? null : () => unawaited(onLogout()),
            ),
            AccountManagementTile(
              leading: '회원 탈퇴',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('회원 탈퇴 API는 아직 제공되지 않습니다.')),
              ),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      leading,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Text(
                      trailing!,
                      style: const TextStyle(
                        color: AppColors.subtle,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(width: 8),
                  const SvgIcon(
                    asset: Assets.chevronRight,
                    size: 20,
                    color: AppColors.text,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
