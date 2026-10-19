import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/sheet_primitives.dart';
import 'package:flutter/material.dart';

const mockNotifications = <({String title, String time})>[
  (title: '오늘의 콘텐츠가 준비됐어요', time: '방금 전'),
  (title: '저장한 링크 요약이 완료됐어요', time: '10분 전'),
  (title: '다시 볼 콘텐츠를 추천해드려요', time: '어제'),
];

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '알림',
      children: [
        for (final item in mockNotifications)
          NotificationRow(title: item.title, time: item.time),
      ],
    );
  }
}

class NotificationRow extends StatelessWidget {
  const NotificationRow({required this.title, required this.time, super.key});

  final String title;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.main,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: AppColors.subtle, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
