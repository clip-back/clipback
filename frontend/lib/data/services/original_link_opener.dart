import 'package:url_launcher/url_launcher.dart';

/// The OS accepting a URL is distinct from the remote page finishing its load.
abstract interface class OriginalLinkOpener {
  Future<bool> open(Uri uri);
}

class PlatformOriginalLinkOpener implements OriginalLinkOpener {
  const PlatformOriginalLinkOpener();

  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
