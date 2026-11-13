import 'package:clipback_frontend/data/services/original_link_opener.dart';

/// Inquiries go to the team's Google Form instead of an in-app screen (#336).
final contactFormUri = Uri.parse('https://forms.gle/dGjWJc643ZwrXTrF7');
const contactFormFailureMessage = '문의하기를 열지 못했어요. 다시 시도해 주세요.';

/// The web policy page links on to the terms and account deletion (#349).
final privacyPolicyUri = Uri.parse('https://huturu-app.github.io/privacy');
const privacyPolicyFailureMessage = '이용약관 및 개인정보를 열지 못했어요. 다시 시도해 주세요.';

final _opening = <Uri>{};

/// Opens [uri] in an external app. Returns null for a tap made while the OS is
/// still answering the same link, and false for an OS refusal or plugin error.
Future<bool?> _openOnce(Uri uri) async {
  if (!_opening.add(uri)) return null;
  try {
    return await const PlatformOriginalLinkOpener().open(uri);
  } catch (_) {
    return false;
  } finally {
    _opening.remove(uri);
  }
}

Future<bool?> openContactForm() => _openOnce(contactFormUri);

Future<bool?> openPrivacyPolicy() => _openOnce(privacyPolicyUri);
