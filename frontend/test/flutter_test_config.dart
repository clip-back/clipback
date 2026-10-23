import 'dart:async';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _UnavailableDeviceCache extends PathProviderPlatform {
  @override
  Future<String?> getApplicationCachePath() async =>
      throw UnsupportedError('No device cache in widget tests');
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Widget tests use fake time. Cache integration tests inject private real
  // directories instead of accessing the host app's directory through a plugin.
  PathProviderPlatform.instance = _UnavailableDeviceCache();
  await testMain();
}
