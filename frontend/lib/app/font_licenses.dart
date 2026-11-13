import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Bundled fonts are not collected from packages, so the license page only
/// lists Pretendard once it is registered here (#349).
void registerFontLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Pretendard',
    ], await rootBundle.loadString('assets/fonts/Pretendard-LICENSE.txt'));
  });
}
