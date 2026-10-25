class AppUser {
  const AppUser({
    required this.name,
    required this.providerLabel,
    required this.joinedAt,
    required this.savedContentCount,
    required this.revisitedContentCount,
    required this.appVersion,
  });

  final String name;
  final String providerLabel;
  final String joinedAt;
  final int? savedContentCount;
  final int? revisitedContentCount;
  final String appVersion;
}

const defaultUser = AppUser(
  name: '계정 정보 확인 중',
  providerLabel: '계정 정보 확인 중',
  joinedAt: '-',
  savedContentCount: null,
  revisitedContentCount: null,
  appVersion: 'ver. 1.1',
);
