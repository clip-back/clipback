import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> startGuestAndFinishOnboarding(WidgetTester tester) async {
  await tester.widget<LoginScreen>(find.byType(LoginScreen)).onContinue();
  await tester.pumpAndSettle();
  if (find.byType(OnboardingScreen).evaluate().isNotEmpty) {
    tester.widget<OnboardingScreen>(find.byType(OnboardingScreen)).onDone();
    await tester.pumpAndSettle();
    await completeInterestSelection(tester);
  }
}

/// Exercises a valid UI selection rather than bypassing the screen's guard.
Future<void> completeInterestSelection(WidgetTester tester) async {
  final tiles = tester.widgetList<InterestOptionTile>(
    find.byType(InterestOptionTile),
  );
  if (!tiles.any((tile) => tile.selected)) {
    await tester.ensureVisible(find.byType(InterestOptionTile).first);
    await tester.tap(find.byType(InterestOptionTile).first);
    await tester.pump();
  }
  // The fallback lets the same helper compile and run on the BEFORE source.
  final next = find.text('다음').evaluate().isNotEmpty
      ? find.text('다음')
      : find.text('완료');
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pumpAndSettle();
}

/// Keeps the in-flight request available to tests that control its HTTP/storage
/// gates. The helper itself only mounts and confirms the screen; it never waits
/// for the request to finish.
class LogoutAttempt {
  const LogoutAttempt(this.completion);

  final Future<void> completion;
}

Future<LogoutAttempt> startLogoutFromAccount(WidgetTester tester) async {
  final navigationOrRequest = tester
      .widget<AccountManagementScreen>(find.byType(AccountManagementScreen))
      .onLogout();
  await tester.pump();
  // Runtime lookup keeps the frozen harness executable against the BEFORE
  // source, where the account callback starts logout immediately.
  final confirmation = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'LogoutConfirmationScreen',
  );
  if (confirmation.evaluate().isEmpty) {
    return LogoutAttempt(navigationOrRequest);
  }
  final dynamic screen = tester.widget(confirmation);
  final completion = (screen.onConfirm as Future<void> Function())();
  await tester.pump();
  return LogoutAttempt(completion);
}

Future<void> logoutFromAccount(WidgetTester tester) async {
  final attempt = await startLogoutFromAccount(tester);
  await attempt.completion;
}
