import 'package:clipback_frontend/features/account/notice_list_screen.dart';
import 'package:clipback_frontend/features/account/notices.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';

// Figma 423:4520 roles; the title uses the content detail's bold family.
abstract final class _DetailText {
  static const title = TextStyle(
    inherit: false,
    fontFamily: 'PretendardDetail',
    fontSize: 25,
    fontWeight: FontWeight.w700,
    height: 1.5,
    color: AppColors.text,
  );
  static const date = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.middle,
  );
  static const heading = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.text,
  );
  static const step = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.middle,
  );
  static const body = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.text,
  );
  static const note = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.middle,
  );
}

class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({
    required this.notice,
    required this.onBack,
    super.key,
  });

  final Notice notice;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final groups = <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notice.title, style: _DetailText.title),
          const SizedBox(height: 8),
          Text(notice.publishedLabel, style: _DetailText.date),
        ],
      ),
      const SizedBox(
        key: ValueKey('notice-detail-divider'),
        height: 1,
        width: double.infinity,
        child: ColoredBox(color: Color(0xFFE5E5E5)),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notice.introTitle, style: _DetailText.heading),
          const SizedBox(height: 10),
          Text(notice.intro, style: _DetailText.body),
        ],
      ),
      for (var i = 0; i < notice.steps.length; i++)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STEP 0${i + 1}', style: _DetailText.step),
            const SizedBox(height: 12),
            Text(notice.steps[i].title, style: _DetailText.heading),
            const SizedBox(height: 12),
            Text(notice.steps[i].body, style: _DetailText.body),
            if (notice.steps[i].note case final note?) ...[
              const SizedBox(height: 12),
              Text(note, style: _DetailText.note),
            ],
          ],
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notice.closingTitle, style: _DetailText.heading),
          const SizedBox(height: 12),
          Text(notice.closing, style: _DetailText.body),
        ],
      ),
      const Text(noticeFooter, style: _DetailText.note),
    ];
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: PhoneFrame(
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                NoticeHeader(onBack: onBack),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('notice-detail-scroll'),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < groups.length; i++) ...[
                          if (i > 0) const SizedBox(height: 28),
                          groups[i],
                        ],
                      ],
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
}
