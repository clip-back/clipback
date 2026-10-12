import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';

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

    return Container(
      height: 96,
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
            height: 64,
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
                        onTap: () => onTap(items[0].route),
                      ),
                      _NavItem(
                        spec: items[1],
                        active: activeIndex == items[1].activeIndex,
                        onTap: () => onTap(items[1].route),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -22),
                        child: NavAddButton(onTap: onAdd),
                      ),
                      _NavItem(
                        spec: items[2],
                        active: activeIndex == items[2].activeIndex,
                        onTap: () => onTap(items[2].route),
                      ),
                      _NavItem(
                        spec: items[3],
                        active: activeIndex == items[3].activeIndex,
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
  });

  final NavSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
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
            Text(
              spec.label,
              style: TextStyle(
                color: active ? AppColors.text : AppColors.subtler,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
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
