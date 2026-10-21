import 'dart:async';

import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';

/// Plugin boundary double only. Native device previews do not use this class.
class RecordingUrlLauncher extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;
  final calls = <({String url, LaunchOptions options})>[];
  bool accepted = true;
  Object? failure;
  Completer<bool>? pending;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls.add((url: url, options: options));
    if (failure case final error?) throw error;
    return pending?.future ?? accepted;
  }
}
