import 'package:clipback_frontend/shared/models/app_info.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/sheet_primitives.dart';
import 'package:flutter/material.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '계정 관리',
      children: [
        SheetInfoRow(label: '이름', value: user.name),
        SheetInfoRow(label: '연동 계정', value: user.providerLabel),
        SheetInfoRow(label: '가입일', value: user.joinedAt),
        const SizedBox(height: 12),
        PrimaryButton(
          label: '확인',
          onPressed: () => Navigator.pop(context),
          height: 48,
        ),
      ],
    );
  }
}

class ReminderSheet extends StatelessWidget {
  const ReminderSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '리마인드 설정',
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

class NoticeSheet extends StatelessWidget {
  const NoticeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '공지사항',
      children: [
        for (final notice in mockNotices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              notice,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class ContactSheet extends StatelessWidget {
  const ContactSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '문의하기',
      children: const [
        Text(
          '문의는 help@hutureu.app 으로 보내주세요. 목데이터 기준 응답 시간은 평일 24시간 이내입니다.',
          style: TextStyle(color: AppColors.subtle, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }
}

class AppVersionSheet extends StatelessWidget {
  const AppVersionSheet({required this.appInfo, super.key});

  final AppInfo? appInfo;

  @override
  Widget build(BuildContext context) {
    final info = appInfo;
    return AppSheet(
      title: '앱 버전',
      children: [
        SheetInfoRow(
          label: '현재 버전',
          value: info == null
              ? '-'
              : 'ver. ${info.version} (${info.buildNumber})',
        ),
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

const mockNotices = [
  '허투루 베타 앱에 오신 것을 환영합니다.',
  '저장한 링크 요약 품질이 개선되었습니다.',
  '관심사 기반 리마인드 추천이 추가되었습니다.',
];
