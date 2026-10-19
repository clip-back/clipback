import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// F01 only. Other archive headers keep their own typography and destinations.
class CategoryContentTopBar extends StatelessWidget {
  const CategoryContentTopBar({
    required this.title,
    required this.category,
    required this.onBack,
    required this.onSearch,
    this.onOpenCategoryManagement,
    super.key,
  });
  final String title;
  final CategoryItem? category;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback? onOpenCategoryManagement;
  static const _titleStyle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -.45,
    color: Colors.black,
  );
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('category-content-header'),
    height: 64,
    child: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(left: 48, right: 88),
            child: Transform.translate(
              offset: const Offset(0, .5),
              child: Row(
                children: [
                  SizedBox(
                    width: 23.5294,
                    height: 20,
                    child: category == null
                        ? null
                        : SvgPicture.asset(
                            Assets.categoryContentFolder,
                            width: 23.5294,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              category!.color,
                              BlendMode.srcIn,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 4,
          top: 8.5,
          child: _HeaderAction(
            key: const ValueKey('category-content-back-hit'),
            asset: Assets.detailBack,
            label: '뒤로가기',
            onPressed: onBack,
            width: 48,
          ),
        ),
        Positioned(
          right: 46,
          top: 8.5,
          child: _HeaderAction(
            key: const ValueKey('category-content-search-hit'),
            asset: Assets.archiveSearch,
            label: '검색',
            onPressed: onSearch,
          ),
        ),
        Positioned(
          right: 6,
          top: 8.5,
          child: _HeaderAction(
            key: const ValueKey('category-content-settings-hit'),
            asset: Assets.archiveSettings,
            label: '카테고리 관리',
            onPressed: onOpenCategoryManagement,
          ),
        ),
      ],
    ),
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.asset,
    required this.label,
    required this.onPressed,
    this.width = 44,
    super.key,
  });
  final String asset, label;
  final VoidCallback? onPressed;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 48,
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: width, height: 48),
      icon: SvgPicture.asset(asset, width: 24, height: 24),
    ),
  );
}

class CategoryContentRandomButton extends StatelessWidget {
  const CategoryContentRandomButton({required this.onPressed, super.key});
  final VoidCallback onPressed;
  static const _style = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -.4,
    color: AppColors.text,
  );
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(100),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          alignment: Alignment.bottomCenter,
          child: Container(
            key: const ValueKey('category-content-random-visual'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.main,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  Assets.categoryContentRandom,
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 4),
                const Text('랜덤 보기', style: _style),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
