import 'package:clipback_frontend/shared/widgets/sheet_primitives.dart';
import 'package:flutter/material.dart';

class ReminderSheet extends StatelessWidget {
  const ReminderSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '알림 설정',
      children: [
        for (final item in mockReminderSettings)
          SheetInfoRow(label: item.label, value: item.value),
      ],
    );
  }
}

class PermissionSheet extends StatelessWidget {
  const PermissionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '알림 및 앱 권한',
      children: [
        for (final item in mockPermissionSettings)
          SheetInfoRow(label: item.label, value: item.value),
      ],
    );
  }
}

class MockSettingItem {
  const MockSettingItem({required this.label, required this.value});

  final String label;
  final String value;
}

const mockReminderSettings = [
  MockSettingItem(label: '오늘의 리마인드', value: '오후 8:00'),
  MockSettingItem(label: '반복', value: '매일'),
  MockSettingItem(label: '추천 콘텐츠', value: '켜짐'),
];

const mockPermissionSettings = [
  MockSettingItem(label: '푸시 알림', value: '허용'),
  MockSettingItem(label: '갤러리 접근', value: '선택한 사진만'),
  MockSettingItem(label: '클립보드 감지', value: '켜짐'),
];
