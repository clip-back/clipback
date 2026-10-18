import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Advances only a newly mounted app's finite launch splash. Pending API work
/// remains pending when [settle] is false; later route changes need no delay.
Future<void> completeAppStartup(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tester.pump();
  if (find.byType(SplashScreen).evaluate().isNotEmpty) {
    await tester.pump(const Duration(milliseconds: 900));
    // Mount the chosen route, then release UI work after its first frame.
    await tester.pump();
  }
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
