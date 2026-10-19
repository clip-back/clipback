import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Confirms only a guide already opened by an explicit login choice. Runtime
/// lookup keeps this helper executable on BEFORE, where no B01 route exists.
/// Do not use this in guide cancellation, duplicate or pending-guide assertions.
Future<void> confirmPermissionGuideIfPresent(WidgetTester tester) async {
  await tester.pump();
  final guide = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'PermissionGuideSheet',
  );
  if (guide.evaluate().isEmpty) return;
  await tester.pump(const Duration(milliseconds: 400));
  final continueButton = find.byKey(
    const ValueKey('permission-guide-continue-hit'),
  );
  expect(continueButton, findsOneWidget);
  await tester.ensureVisible(continueButton);
  await tester.tap(continueButton);
  // Complete route removal without pumpAndSettle: a gated authentication may
  // start a perpetual busy indicator as soon as the sheet reverse completes.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

class LoginAttempt {
  const LoginAttempt(this.completion);

  final Future<void> completion;
}

/// Keeps the actual authentication Future under the caller's control. Tests
/// with pending HTTP/SDK gates should await this helper, not its completion.
Future<LoginAttempt> startLoginChoice(
  WidgetTester tester,
  Future<void> Function() choose,
) async {
  final completion = choose();
  await confirmPermissionGuideIfPresent(tester);
  return LoginAttempt(completion);
}

Future<void> performLoginChoice(
  WidgetTester tester,
  Future<void> Function() choose,
) async {
  final attempt = await startLoginChoice(tester, choose);
  await attempt.completion;
}

Future<void> startGuestAndFinishOnboarding(WidgetTester tester) async {
  await performLoginChoice(
    tester,
    tester.widget<LoginScreen>(find.byType(LoginScreen)).onContinue,
  );
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
