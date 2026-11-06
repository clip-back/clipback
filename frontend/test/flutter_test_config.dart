import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnavailableDeviceCache extends PathProviderPlatform {
  @override
  Future<String?> getApplicationCachePath() async =>
      throw UnsupportedError('No device cache in widget tests');
}

const _preferences = MethodChannel('plugins.flutter.io/shared_preferences');

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Widget tests use fake time. Cache integration tests inject private real
  // directories instead of accessing the host app's directory through a plugin.
  PathProviderPlatform.instance = _UnavailableDeviceCache();
  // App launch reads the withdrawal cleanup record (#257) from preferences,
  // and an unmocked platform channel never answers under fake time. Each test
  // starts with an empty in-memory channel; a test may install its own.
  // Plain Dart tests without a binding keep failing fast as before.
  setUp(() {
    if (BindingBase.debugBindingType() == null) return;
    final values = <String, Object?>{};
    SharedPreferences.resetStatic();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_preferences, (call) async {
          final arguments = call.arguments is Map
              ? call.arguments as Map
              : const {};
          switch (call.method) {
            case 'getAll':
            case 'getAllWithParameters':
              return Map.of(values);
            case 'remove':
              values.remove(arguments['key']);
              return true;
            case 'clear':
            case 'clearWithParameters':
              values.clear();
              return true;
          }
          if (!call.method.startsWith('set')) {
            throw MissingPluginException(call.method);
          }
          values[arguments['key'] as String] = arguments['value'];
          return true;
        });
  });
  await testMain();
}
