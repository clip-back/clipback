import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// J01 roles are local so other account screens retain their existing styles.
abstract final class _MyText {
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
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
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
  static const metricLabel = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: AppColors.mainSubtle,
  );
  static const metricValue = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.45,
    color: AppColors.main,
  );
  static const menu = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: Colors.black,
  );
  static const version = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.35,
    color: AppColors.subtle,
  );
}

abstract final class _MyAssets {
  static const settings = Assets.archiveSettings;
  static const avatarBackground = 'assets/icons/my-avatar-background.svg';
  static const avatarCharacter = 'assets/figma/my-avatar-character.png';
  static const profileArrow = Assets.chevronRight;
  static const statsDivider = 'assets/icons/my-stats-divider.svg';
  static const menuArrow = 'assets/icons/my-menu-chevron.svg';
}

class MyScreen extends StatelessWidget {
  const MyScreen({
    required this.user,
    required this.onAddLink,
    required this.onAddScreenshot,
    required this.onOpenAccount,
    required this.onOpenCategoryManagement,
    required this.onTab,
    super.key,
  });

  final AppUser user;
  final SaveLinkCallback onAddLink;
  final SaveScreenshotCallback onAddScreenshot;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenCategoryManagement;
  final ValueChanged<AppRoute> onTab;

  @override
  Widget build(BuildContext context) {
    void showAddContentSheet() {
      showContentSaveScreen(
        context: context,
        onAddLink: onAddLink,
        onAddScreenshot: onAddScreenshot,
      );
    }

    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MyPageTopBar(onMore: onOpenAccount),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                  children: [
                    MyProfileRow(user: user, onTap: onOpenAccount),
                    const MySectionHeader(title: '나의 허투루'),
                    MyStatsStrip(user: user),
                    const SizedBox(height: 16),
                    const MySectionHeader(title: '관리'),
                    MyListGroup(
                      children: [
                        MyListTile(
                          title: '리마인드 설정',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const ReminderSheet(),
                          ),
                        ),
                        MyListTile(
                          title: '카테고리 관리',
                          onTap: onOpenCategoryManagement,
                        ),
                        MyListTile(
                          title: '앱 권한',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const PermissionSheet(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const MySectionHeader(title: '고객지원'),
                    MyListGroup(
                      children: [
                        MyListTile(
                          title: '공지사항',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const NoticeSheet(),
                          ),
                        ),
                        MyListTile(
                          title: '문의하기',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const ContactSheet(),
                          ),
                        ),
                        MyListTile(
                          title: '앱 버전',
                          trailingText: user.appVersion,
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const AppVersionSheet(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: 3,
          onTap: onTab,
          onAdd: showAddContentSheet,
        ),
      ),
    );
  }
}

class MyPageTopBar extends StatelessWidget {
  const MyPageTopBar({required this.onMore, super.key});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: appHeaderHeight,
      child: Stack(
        children: [
          const Positioned.fill(
            left: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text('마이페이지', style: _MyText.header),
              ),
            ),
          ),
          // The visible 24px asset ends at 16px; the larger hit box extends 10px.
          Positioned(
            right: 6,
            top: 10.5,
            child: Semantics(
              button: true,
              label: '계정 관리',
              child: InkWell(
                key: const ValueKey('my-header-settings'),
                onTap: onMore,
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SvgPicture.asset(
                      _MyAssets.settings,
                      key: const ValueKey('my-header-settings-image'),
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
    );
  }
}

class MyProfileRow extends StatelessWidget {
  const MyProfileRow({required this.user, required this.onTap, super.key});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 78,
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                const _MyAvatar(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _MyText.name,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.providerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subtle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  _MyAssets.profileArrow,
                  key: const ValueKey('my-profile-arrow'),
                  width: 24,
                  height: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyAvatar extends StatelessWidget {
  const _MyAvatar();

  @override
  Widget build(BuildContext context) {
    const clipWidth = 28.927;
    const clipHeight = 32.141;
    return SizedBox(
      key: const ValueKey('my-avatar'),
      width: 46,
      height: 46,
      child: Stack(
        children: [
          SvgPicture.asset(
            _MyAssets.avatarBackground,
            key: const ValueKey('my-avatar-background'),
            width: 46,
            height: 46,
          ),
          Positioned(
            left: 7.96,
            top: 6.19,
            width: clipWidth,
            height: clipHeight,
            child: ClipRect(
              key: const ValueKey('my-avatar-character-clip'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Preserve the crop from J01, rather than filling the circle.
                  Positioned(
                    left: -0.2301 * clipWidth,
                    top: -0.1452 * clipHeight,
                    width: 1.5323 * clipWidth,
                    height: 1.3621 * clipHeight,
                    child: Image.asset(
                      _MyAssets.avatarCharacter,
                      key: const ValueKey('my-avatar-character-source'),
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

class MySectionHeader extends StatelessWidget {
  const MySectionHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: _MyText.section),
        ),
      ),
    );
  }
}

class MyStatsStrip extends StatelessWidget {
  const MyStatsStrip({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: MyMetric(
                label: '저장한 콘텐츠',
                value: user.savedContentCount.toString(),
              ),
            ),
            SizedBox(
              key: const ValueKey('my-stats-divider'),
              width: 1,
              height: 48,
              child: RotatedBox(
                quarterTurns: 1,
                child: SvgPicture.asset(
                  _MyAssets.statsDivider,
                  key: const ValueKey('my-stats-divider-source'),
                  width: 48,
                  height: 1,
                ),
              ),
            ),
            Expanded(
              child: MyMetric(
                label: '다시 본 콘텐츠',
                value: user.revisitedContentCount.toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyMetric extends StatelessWidget {
  const MyMetric({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, textAlign: TextAlign.center, style: _MyText.metricLabel),
          const SizedBox(height: 8),
          Text(value, textAlign: TextAlign.center, style: _MyText.metricValue),
        ],
      ),
    );
  }
}

class MyListGroup extends StatelessWidget {
  const MyListGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class MyListTile extends StatelessWidget {
  const MyListTile({
    required this.title,
    required this.onTap,
    this.trailingText,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 41,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: Text(title, style: _MyText.menu)),
              if (trailingText != null)
                Text(trailingText!, style: _MyText.version)
              else
                SizedBox(
                  key: ValueKey('my-menu-arrow-$title'),
                  width: 5,
                  height: 10,
                  child: OverflowBox(
                    minWidth: 6.66667,
                    maxWidth: 6.66667,
                    minHeight: 11.6667,
                    maxHeight: 11.6667,
                    child: SvgPicture.asset(
                      _MyAssets.menuArrow,
                      key: ValueKey('my-menu-arrow-image-$title'),
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

class MyStatCard extends StatelessWidget {
  const MyStatCard({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.faint),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.subtle,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class MyMenuTile extends StatelessWidget {
  const MyMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SvgIcon(asset: icon, size: 22, color: AppColors.text),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SvgIcon(asset: Assets.chevronRight, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
