import 'package:clipback_frontend/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> startGuestAndFinishOnboarding(WidgetTester tester) async {
  await tester.widget<LoginScreen>(find.byType(LoginScreen)).onContinue();
  await tester.pumpAndSettle();
  if (find.byType(OnboardingScreen).evaluate().isNotEmpty) {
    tester.widget<OnboardingScreen>(find.byType(OnboardingScreen)).onDone();
    await tester.pumpAndSettle();
    tester
        .widget<InterestSelectionScreen>(find.byType(InterestSelectionScreen))
        .onDone();
    await tester.pumpAndSettle();
  }
}
