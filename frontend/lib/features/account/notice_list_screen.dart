import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// K01 roles are local to notices. Missing dates/pins and detail affordances
// are deliberately omitted until real metadata and a destination exist.
abstract final class _NoticeText {
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
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: -.45,
    color: AppColors.text,
  );
}

class NoticeListScreen extends StatelessWidget {
  const NoticeListScreen({
    required this.titles,
    required this.onBack,
    super.key,
  });

  final List<String> titles;
  final VoidCallback onBack;

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
              _NoticeHeader(onBack: onBack),
              Expanded(
                child: SizedBox(
                  key: const ValueKey('notice-viewport'),
                  width: double.infinity,
                  child: ListView.separated(
                    key: const ValueKey('notice-scroll'),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: titles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => Container(
                      key: ValueKey('notice-row-$index'),
                      constraints: const BoxConstraints(minHeight: 79),
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.centerLeft,
                      color: AppColors.surface,
                      child: Text(
                        titles[index],
                        key: ValueKey('notice-title-$index'),
                        style: _NoticeText.title,
                        softWrap: true,
                        overflow: TextOverflow.visible,
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

class _NoticeHeader extends StatelessWidget {
  const _NoticeHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('notice-header'),
    height: 64,
    child: Stack(
      children: [
        const Positioned.fill(
          left: 48,
          right: 16,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text('공지사항', style: _NoticeText.header),
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
              key: const ValueKey('notice-back-hit'),
              onTap: onBack,
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SvgPicture.asset(
                    Assets.detailBack,
                    key: const ValueKey('notice-back-image'),
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
