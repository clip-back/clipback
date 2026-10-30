import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/shared/models/app_info.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ClipbackApp(appInfo: await _readAppInfo()));
}

/// 설치된 앱의 앱 정보를 한 번 읽는다. 읽지 못하면 "정보 없음"(null)이다.
Future<AppInfo?> _readAppInfo() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(version: info.version, buildNumber: info.buildNumber);
  } catch (_) {
    return null;
  }
}
