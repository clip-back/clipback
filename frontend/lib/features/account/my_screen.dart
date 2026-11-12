import 'dart:async';

import 'package:clipback_frontend/features/account/contact_form.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/app_info.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
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

Future<void> _openContact(BuildContext context) async {
  if (await openContactForm() == false && context.mounted) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text(contactFormFailureMessage)));
  }
}

class MyScreen extends StatelessWidget {
  const MyScreen({
    required this.user,
    required this.appInfo,
    required this.onAddLink,
    required this.onAddScreenshot,
    required this.onOpenAccount,
    required this.onTab,
    this.statsMessage,
    this.onRetryStats,
    super.key,
  });

  final AppUser user;
  final AppInfo? appInfo;
  final String? statsMessage;
  final VoidCallback? onRetryStats;
  final SaveLinkCallback onAddLink;
  final SaveScreenshotCallback onAddScreenshot;
  final VoidCallback onOpenAccount;
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
                  key: const PageStorageKey('my-scroll'),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                  children: [
                    MyProfileRow(user: user, onTap: onOpenAccount),
                    const MySectionHeader(title: '나의 허투루'),
                    MyStatsStrip(user: user),
                    if (statsMessage case final message?)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.subtle,
                              ),
                            ),
                            if (onRetryStats != null) ...[
                              const SizedBox(height: 8),
                              // Consume a rapid second tap before retry moves the menus.
                              GestureDetector(
                                onDoubleTap: onRetryStats,
                                excludeFromSemantics: true,
                                child: OutlinedButton(
                                  onPressed: onRetryStats,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(88, 44),
                                    foregroundColor: AppColors.text,
                                    side: const BorderSide(
                                      color: AppColors.subtle,
                                    ),
                                    textStyle: const TextStyle(fontSize: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('다시 시도'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    const MySectionHeader(title: '관리'),
                    MyListGroup(
                      children: [
                        MyListTile(
                          title: '알림 설정',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const ReminderSheet(),
                          ),
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
                          title: '문의하기',
                          onTap: () => unawaited(_openContact(context)),
                        ),
                        MyListTile(
                          title: '앱 버전',
                          trailingText: appInfo == null
                              ? '-'
                              : 'ver. ${appInfo!.version}',
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
        constraints: const BoxConstraints(minHeight: 80),
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: FixedColumnWidth(1),
                  2: FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    children: [
                      _metricText('저장한 콘텐츠', _MyText.metricLabel),
                      const SizedBox.shrink(),
                      _metricText('최근 다시 본 콘텐츠', _MyText.metricLabel),
                    ],
                  ),
                  const TableRow(
                    children: [
                      SizedBox(height: 8),
                      SizedBox.shrink(),
                      SizedBox(height: 8),
                    ],
                  ),
                  TableRow(
                    children: [
                      _metricText(
                        user.savedContentCount?.toString() ?? '—',
                        _MyText.metricValue,
                      ),
                      const SizedBox.shrink(),
                      _metricText(
                        user.revisitedContentCount?.toString() ?? '—',
                        _MyText.metricValue,
                      ),
                    ],
                  ),
                ],
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
          ],
        ),
      ),
    );
  }

  Widget _metricText(String text, TextStyle style) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(text, textAlign: TextAlign.center, style: style),
  );
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
    this.onTap,
    this.trailingText,
    super.key,
  });

  final String title;
  final VoidCallback? onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
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
    );
    // Each row stays its own accessibility node even when only one row in the
    // group is tappable; otherwise the version text merges into 문의하기.
    return Semantics(
      container: true,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
