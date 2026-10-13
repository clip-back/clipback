import 'dart:math' as math;

import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';

const _navLabelStyle = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  fontSize: 12,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.3,
);

double _maxLabelHeight(
  BuildContext context,
  List<NavSpec> items,
  TextScaler textScaler,
) {
  var height = 0.0;
  for (final item in items) {
    final painter = TextPainter(
      text: TextSpan(text: item.label, style: _navLabelStyle),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      textScaler: textScaler,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 56);
    height = math.max(height, painter.height);
    painter.dispose();
  }
  return height;
}

class ClipbackNavigationBar extends StatelessWidget {
  const ClipbackNavigationBar({
    required this.activeIndex,
    required this.onTap,
    this.onAdd,
    super.key,
  });

  final int activeIndex;
  final ValueChanged<AppRoute> onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final items = [
      NavSpec(Assets.home, '홈', AppRoute.home, 0),
      NavSpec(Assets.archive, '아카이브', AppRoute.archive, 1),
      NavSpec(Assets.star, '즐겨찾기', AppRoute.bookmark, 2),
      NavSpec(Assets.account, '마이', AppRoute.my, 3),
    ];
    final labelHeight = _maxLabelHeight(
      context,
      items,
      MediaQuery.textScalerOf(context),
    );
    final baseLabelHeight = _maxLabelHeight(
      context,
      items,
      TextScaler.noScaling,
    );
    final extraHeight = math.max(0.0, labelHeight - baseLabelHeight);

    return Container(
      height: 96 + extraHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 16)],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 64 + extraHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth >= 343
                    ? 16.0
                    : 8.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NavItem(
                        spec: items[0],
                        active: activeIndex == items[0].activeIndex,
                        labelHeight: labelHeight,
                        height: 56 + extraHeight,
                        onTap: () => onTap(items[0].route),
                      ),
                      _NavItem(
                        spec: items[1],
                        active: activeIndex == items[1].activeIndex,
                        labelHeight: labelHeight,
                        height: 56 + extraHeight,
                        onTap: () => onTap(items[1].route),
                      ),
                      const SizedBox(width: 72),
                      _NavItem(
                        spec: items[2],
                        active: activeIndex == items[2].activeIndex,
                        labelHeight: labelHeight,
                        height: 56 + extraHeight,
                        onTap: () => onTap(items[2].route),
                      ),
                      _NavItem(
                        spec: items[3],
                        active: activeIndex == items[3].activeIndex,
                        labelHeight: labelHeight,
                        height: 56 + extraHeight,
                        onTap: () => onTap(items[3].route),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavigationHomeIndicator(),
          ),
          Positioned(
            top: -22,
            left: 0,
            right: 0,
            height: 72,
            child: Center(child: NavAddButton(onTap: onAdd)),
          ),
        ],
      ),
    );
  }
}

class NavAddButton extends StatelessWidget {
  const NavAddButton({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.main,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 4),
        ),
        child: Center(
          child: SvgIcon(asset: Assets.plus, size: 38.5, color: AppColors.text),
        ),
      ),
    );
  }
}

class NavigationHomeIndicator extends StatelessWidget {
  const NavigationHomeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 34,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            width: 144,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.text,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.active,
    required this.onTap,
    required this.labelHeight,
    required this.height,
  });

  final NavSpec spec;
  final bool active;
  final VoidCallback onTap;
  final double labelHeight;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: height,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SvgIcon(
              asset: spec.asset,
              size: 28,
              color: active ? AppColors.text : AppColors.subtler,
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 56,
              height: labelHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  spec.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _navLabelStyle.copyWith(
                    color: active ? AppColors.text : AppColors.subtler,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavSpec {
  const NavSpec(this.asset, this.label, this.route, this.activeIndex);

  final String asset;
  final String label;
  final AppRoute route;
  final int activeIndex;
}
