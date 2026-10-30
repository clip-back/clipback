/// 설치된 앱의 네이티브 정보에서 읽은 앱 버전과 빌드 번호.
class AppInfo {
  const AppInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}
