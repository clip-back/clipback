import 'package:clipback_frontend/data/services/original_link_opener.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'fixtures/original_link_launcher.dart';

void main() {
  test(
    'platform adapter preserves the URI and explicitly requests external handling',
    () async {
      final original = UrlLauncherPlatform.instance,
          platform = RecordingUrlLauncher();
      UrlLauncherPlatform.instance = platform;
      addTearDown(() => UrlLauncherPlatform.instance = original);
      const opener = PlatformOriginalLinkOpener();
      final uri = Uri.parse('https://example.com/path?q=a%20b&x=%2F#part');
      expect(await opener.open(uri), isTrue);
      expect(platform.calls.single.url, uri.toString());
      expect(
        platform.calls.single.options.mode,
        PreferredLaunchMode.externalApplication,
      );
      platform.accepted = false;
      expect(await opener.open(uri), isFalse);
      platform.failure = PlatformException(code: 'launch_failed');
      await expectLater(opener.open(uri), throwsA(isA<PlatformException>()));
      expect(platform.calls, hasLength(3));
    },
  );
}
