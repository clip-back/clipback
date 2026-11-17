import 'package:clipback_frontend/features/account/notices.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// K01 roles (Figma 423:4464) are local to notices.
abstract final class _NoticeText {
  static const header = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -.475,
    color: Colors.black,
  );
  static const title = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 19,
    fontWeight: FontWeight.w500,
    letterSpacing: -.475,
    color: AppColors.text,
  );
  static const date = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -.4,
    color: AppColors.subtle,
  );
  static const pin = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 19,
    fontWeight: FontWeight.w500,
  );
}

class NoticeListScreen extends StatelessWidget {
  const NoticeListScreen({
    required this.notices,
    required this.onBack,
    required this.onOpen,
    super.key,
  });

  final List<Notice> notices;
  final VoidCallback onBack;
  final ValueChanged<Notice> onOpen;

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
              NoticeHeader(onBack: onBack, title: '공지사항'),
              Expanded(
                child: SizedBox(
                  key: const ValueKey('notice-viewport'),
                  width: double.infinity,
                  child: ListView.separated(
                    key: const PageStorageKey('notice-scroll'),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: notices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (context, index) => _NoticeRow(
                      index: index,
                      notice: notices[index],
                      onOpen: onOpen,
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

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({
    required this.index,
    required this.notice,
    required this.onOpen,
  });

  final int index;
  final Notice notice;
  final ValueChanged<Notice> onOpen;

  @override
  Widget build(BuildContext context) {
    void open() => onOpen(notice);
    // One button per row: "고정 공지, 제목, 게시일"; 📌 and the arrow are not read.
    return Semantics(
      key: ValueKey('notice-row-$index'),
      container: true,
      button: true,
      label: [
        if (notice.pinned) '고정 공지',
        notice.title,
        notice.publishedLabel,
      ].join(', '),
      onTap: open,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 82),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (notice.pinned) ...[
                    Text(
                      '📌',
                      key: ValueKey('notice-pin-$index'),
                      style: _NoticeText.pin,
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.publishedLabel,
                          key: ValueKey('notice-date-$index'),
                          style: _NoticeText.date,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notice.title,
                          key: ValueKey('notice-title-$index'),
                          style: _NoticeText.title,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    Assets.chevronRight,
                    key: ValueKey('notice-arrow-$index'),
                    width: 24,
                    height: 24,
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

/// The K01 header: back button, plus the title when the screen has one.
class NoticeHeader extends StatelessWidget {
  const NoticeHeader({required this.onBack, this.title, super.key});
  final VoidCallback onBack;
  final String? title;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('notice-header'),
    height: 64,
    child: Stack(
      children: [
        if (title case final title?)
          Positioned.fill(
            left: 48,
            right: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(title, style: _NoticeText.header),
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
