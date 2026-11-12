import 'package:clipback_frontend/data/services/original_link_opener.dart';

/// Inquiries go to the team's Google Form instead of an in-app screen (#336).
final contactFormUri = Uri.parse('https://forms.gle/dGjWJc643ZwrXTrF7');
const contactFormFailureMessage = '문의하기를 열지 못했어요. 다시 시도해 주세요.';

bool _opening = false;

/// Opens the form in an external app. Returns null for a tap made while the
/// OS is still answering, and false for an OS refusal or plugin error.
Future<bool?> openContactForm() async {
  if (_opening) return null;
  _opening = true;
  try {
    return await const PlatformOriginalLinkOpener().open(contactFormUri);
  } catch (_) {
    return false;
  } finally {
    _opening = false;
  }
}
