import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class _NotificationText {
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
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -.4,
    color: AppColors.text,
  );
  static const time = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -.3,
    color: AppColors.subSubtle,
  );
  static const emptyTitle = TextStyle(
    inherit: false,
    // Existing alias for the real Pretendard Bold file, scoped to this role.
    fontFamily: 'PretendardDetail',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -.6,
    height: 1.6,
    color: AppColors.text,
  );
  static const emptyBody = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -.4,
    height: 1.5,
    color: AppColors.subtle,
  );
}

class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({
    required this.items,
    required this.onBack,
    required this.onOpenSettings,
    super.key,
  });

  final List<({String title, String time})> items;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onBack();
    },
    child: PhoneFrame(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _NotificationHeader(onBack: onBack, onSettings: onOpenSettings),
              Expanded(
                child: SizedBox(
                  key: const ValueKey('notification-viewport'),
                  width: double.infinity,
                  child: items.isEmpty
                      ? const _EmptyNotifications()
                      : ListView.separated(
                          key: const ValueKey('notification-scroll'),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => Container(
                            key: ValueKey('notification-row-$index'),
                            constraints: const BoxConstraints(minHeight: 76),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SvgPicture.asset(
                                  Assets.notificationMarker,
                                  key: ValueKey('notification-marker-$index'),
                                  width: 19,
                                  height: 19,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    items[index].title,
                                    key: ValueKey('notification-title-$index'),
                                    style: _NotificationText.title,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 64,
                                  ),
                                  child: Text(
                                    items[index].time,
                                    key: ValueKey('notification-time-$index'),
                                    style: _NotificationText.time,
                                    textAlign: TextAlign.right,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ],
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

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({required this.onBack, required this.onSettings});
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('notification-header'),
    height: 64,
    child: Stack(
      children: [
        const Positioned.fill(
          left: 48,
          right: 56,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text('알림', style: _NotificationText.header),
            ),
          ),
        ),
        Positioned(
          left: 4,
          top: 8.5,
          child: _HeaderButton(
            hitKey: const ValueKey('notification-back-hit'),
            imageKey: const ValueKey('notification-back-image'),
            label: '뒤로가기',
            asset: Assets.detailBack,
            hitSize: 48,
            onTap: onBack,
          ),
        ),
        Positioned(
          right: 6,
          top: 10.5,
          child: _HeaderButton(
            hitKey: const ValueKey('notification-settings-hit'),
            imageKey: const ValueKey('notification-settings-image'),
            label: '리마인드 설정',
            asset: Assets.notificationSettings,
            hitSize: 44,
            onTap: onSettings,
          ),
        ),
      ],
    ),
  );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.hitKey,
    required this.imageKey,
    required this.label,
    required this.asset,
    required this.hitSize,
    required this.onTap,
  });
  final Key hitKey;
  final Key imageKey;
  final String label;
  final String asset;
  final double hitSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      key: hitKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(hitSize / 2),
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: Center(
          child: SvgPicture.asset(asset, key: imageKey, width: 24, height: 24),
        ),
      ),
    ),
  );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const ValueKey('notification-scroll'),
      padding: EdgeInsets.fromLTRB(
        16,
        math.max(16, constraints.maxHeight / 2 - 240),
        16,
        24,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: const Offset(.5, 0),
          child: ConstrainedBox(
            key: const ValueKey('notification-empty-group'),
            constraints: const BoxConstraints(maxWidth: 224),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _EmptyNotificationIllustration(),
                const SizedBox(height: 16),
                const Text(
                  '아직 받은 알림이 없어요',
                  key: ValueKey('notification-empty-title'),
                  style: _NotificationText.emptyTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 192),
                  child: const Text(
                    '저장한 콘텐츠를\n다시 볼 때 알려드릴게요',
                    key: ValueKey('notification-empty-body'),
                    style: _NotificationText.emptyBody,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyNotificationIllustration extends StatelessWidget {
  const _EmptyNotificationIllustration();

  Widget _crop({required bool shadow}) {
    final prefix = shadow ? 'notification-empty-shadow' : 'notification-empty';
    return ClipRect(
      key: ValueKey('$prefix-clip'),
      child: Stack(
        children: [
          Positioned(
            left: -86 * .3072,
            top: -100 * .172,
            width: 86 * 1.6118,
            height: 100 * 1.3918,
            child: Image.asset(
              Assets.notificationEmptyIllustration,
              key: ValueKey('$prefix-source'),
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('notification-empty-image'),
    width: 86,
    height: 100,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: ExcludeSemantics(
            child: Transform.translate(
              key: const ValueKey('notification-empty-shadow'),
              offset: const Offset(0, 2),
              child: ImageFiltered(
                // CSS/Figma blur radius 2 corresponds to Gaussian sigma 1.
                imageFilter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x1F000000),
                    BlendMode.srcIn,
                  ),
                  child: _crop(shadow: true),
                ),
              ),
            ),
          ),
        ),
        _crop(shadow: false),
      ],
    ),
  );
}
