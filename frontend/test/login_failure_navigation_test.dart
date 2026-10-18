import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/auth/login_failure_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as fixture;

Finder get _guide => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == 'PermissionGuideSheet',
);
LoginScreen _login(WidgetTester tester) =>
    tester.widget<LoginScreen>(find.byType(LoginScreen));
LoginFailureScreen _failure(WidgetTester tester) =>
    tester.widget<LoginFailureScreen>(find.byType(LoginFailureScreen));

Future<void> _root(
  WidgetTester tester,
  Future<void> Function(fixture.LoginServer, fixture.LoginControlledSocial)
  body,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final old = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  final server = fixture.LoginServer();
  final social = fixture.LoginControlledSocial(TargetPlatform.iOS)
    ..cancel = false;
  final storage = fixture.LoginMemoryStorage();
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(
          key: UniqueKey(),
          sessionStorage: storage,
          socialAuth: social,
        ),
      );
      await completeAppStartup(tester);
      await body(server, social);
      expect(server.unexpected, isEmpty);
      expect(server.contentWrites, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      server.client.close();
      debugDefaultTargetPlatformOverride = old;
    }
  }, () => server.client);
}

Future<void> _choose(
  WidgetTester tester,
  SocialLoginProvider provider, {
  bool guide = false,
}) async {
  final pending = _login(tester).onSocialLogin(provider);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (guide) {
    expect(_guide, findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('permission-guide-continue-hit')),
    );
    await tester.tap(
      find.byKey(const ValueKey('permission-guide-continue-hit')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  } else {
    expect(_guide, findsNothing);
  }
  await pending;
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    var revision = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.huturu.app/share'), (
          call,
        ) async {
          switch (call.method) {
            case 'getState':
              return {
                'revision': revision,
                'drafts': <Object>[],
                'receipts': <Object>[],
              };
            case 'blockCredential':
              return ++revision;
            case 'publishCredential':
              return true;
            case 'presentDraft':
            case 'acknowledgeReceipts':
              return null;
            default:
              throw StateError('Unexpected isolated share call ${call.method}');
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.huturu.app/share'),
          null,
        );
  });

  testWidgets(
    'HTTP and SDK failure return to methods with same visit acknowledgement',
    (tester) async {
      await _root(tester, (server, social) async {
        server.failIssuance = true;
        await _choose(tester, SocialLoginProvider.google, guide: true);
        expect(_failure(tester).statusCode, 503);
        expect(find.text('응답 상태 : HTTP 503'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        final requests = server.requests.length;
        _failure(tester).onChooseMethods();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(server.requests, hasLength(requests));
        social.fail = true;
        await _choose(tester, SocialLoginProvider.kakao);
        expect(_failure(tester).statusCode, isNull);
        expect(find.text('응답 상태를 확인할 수 없어요'), findsOneWidget);
        expect(social.calls, ['google', 'kakao']);
        expect(find.byType(SnackBar), findsNothing);
      });
    },
  );

  testWidgets('contact opens once and preserves same failure on closing', (
    tester,
  ) async {
    await _root(tester, (server, social) async {
      social.fail = true;
      await _choose(tester, SocialLoginProvider.google, guide: true);
      final failure = _failure(tester);
      final requests = server.requests.length;
      failure.onContact();
      failure.onContact();
      await tester.pumpAndSettle();
      expect(find.byType(ContactSheet), findsOneWidget);
      // Background/stale actions do not dismiss failure or start guest auth.
      failure.onChooseMethods();
      failure.onContinueAsGuest();
      await tester.pump();
      expect(server.guestIssuances, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ContactSheet), findsNothing);
      expect(_failure(tester).statusCode, isNull);
      expect(server.requests, hasLength(requests));
      expect(social.calls, ['google']);
    });
  });

  testWidgets(
    'failure guest reuses confirmed guide and duplicate action issues once',
    (tester) async {
      await _root(tester, (server, social) async {
        social.fail = true;
        await _choose(tester, SocialLoginProvider.google, guide: true);
        final failure = _failure(tester);
        failure.onContinueAsGuest();
        failure.onContinueAsGuest();
        await tester.pumpAndSettle();
        expect(_guide, findsNothing);
        expect(server.guestIssuances, 1);
        expect(find.byType(OnboardingScreen), findsOneWidget);
      });
    },
  );

  testWidgets(
    'OS back and stale failure callbacks cannot dismiss a newer failure',
    (tester) async {
      await _root(tester, (server, social) async {
        social.fail = true;
        await _choose(tester, SocialLoginProvider.google, guide: true);
        final oldFailure = _failure(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        await _choose(tester, SocialLoginProvider.kakao);
        final requests = server.requests.length;
        oldFailure.onChooseMethods();
        oldFailure.onContinueAsGuest();
        oldFailure.onContact();
        await tester.pumpAndSettle();
        expect(find.byType(LoginFailureScreen), findsOneWidget);
        expect(find.byType(ContactSheet), findsNothing);
        expect(server.guestIssuances, 0);
        expect(server.requests, hasLength(requests));
        expect(social.calls, ['google', 'kakao']);
      });
    },
  );
}
