// B01 behavior is exercised through the real root app with the existing memory
// authentication server. Runtime sheet discovery also compiles on BEFORE.
import 'dart:async';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'auth_navigation.dart';
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as fixture;

Finder get _guide => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == 'PermissionGuideSheet',
);
Finder get _continue =>
    find.byKey(const ValueKey('permission-guide-continue-hit'));
LoginScreen _login(WidgetTester tester) =>
    tester.widget<LoginScreen>(find.byType(LoginScreen));

class _Social extends fixture.LoginControlledSocial {
  _Social({this.noProviders = false}) : super(TargetPlatform.iOS);
  final bool noProviders;
  void Function()? onAuthenticate;

  @override
  List<SocialLoginProvider> get supportedProviders =>
      noProviders ? const [] : super.supportedProviders;

  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) {
    onAuthenticate?.call();
    return super.authenticate(provider, nonce: nonce);
  }
}

Future<void> _pumpRoot(
  WidgetTester tester,
  fixture.LoginMemoryStorage storage,
  _Social social,
) async {
  await tester.pumpWidget(
    ClipbackApp(key: UniqueKey(), sessionStorage: storage, socialAuth: social),
  );
  await completeAppStartup(tester);
}

Future<void> _withRoot(
  WidgetTester tester,
  Future<void> Function(
    fixture.LoginServer server,
    fixture.LoginMemoryStorage storage,
    _Social social,
  )
  body, {
  bool stored = false,
  bool noProviders = false,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  final server = fixture.LoginServer();
  final storage = fixture.LoginMemoryStorage();
  if (stored) {
    storage.value = const ApiSession(
      accessToken: 'fixture-guest',
      refreshToken: 'fixture-refresh-guest',
      expiresIn: 3600,
      refreshExpiresIn: 86400,
    );
  }
  final social = _Social(noProviders: noProviders);
  await http.runWithClient(() async {
    try {
      await _pumpRoot(tester, storage, social);
      await body(server, storage, social);
      expect(server.unexpected, isEmpty);
      expect(server.contentWrites, 0);
      expect(tester.takeException(), isNull);
    } finally {
      if (social.gate case final gate? when !gate.isCompleted) {
        gate.complete(null);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      server.client.close();
      debugDefaultTargetPlatformOverride = previous;
    }
  }, () => server.client);
}

Future<Future<void> Function()> _openGuide(
  WidgetTester tester, {
  SocialLoginProvider? provider,
}) async {
  final screen = _login(tester);
  final completion = provider == null
      ? screen.onContinue()
      : screen.onSocialLogin(provider);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(_guide, findsOneWidget);
  expect(_login(tester).busy, isFalse);
  // Returning a closure avoids async flattening of the pending auth Future.
  return () => completion;
}

Future<void> _approve(WidgetTester tester) async {
  expect(_guide, findsOneWidget);
  await tester.ensureVisible(_continue);
  await tester.tap(_continue);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> _cancel(WidgetTester tester, String method) async {
  switch (method) {
    case 'barrier':
      await tester.tapAt(const Offset(20, 100));
    case 'drag':
      await tester.drag(
        find.byKey(const ValueKey('permission-guide-handle')),
        const Offset(0, 600),
      );
    case 'back':
      await tester.binding.handlePopRoute();
  }
  await tester.pumpAndSettle();
  expect(_guide, findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    var revision = 0;
    // Installed before ClipbackApp's very first frame. No native queue or
    // permission plugin is used as evidence of real device authorization.
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
    'social choice waits for guide and full route removal before SDK',
    (tester) async {
      await _withRoot(tester, (server, storage, social) async {
        expect(server.requests, isEmpty);
        final completion = await _openGuide(
          tester,
          provider: SocialLoginProvider.google,
        );
        expect(social.calls, isEmpty);
        expect(server.requests, isEmpty);
        final route = ModalRoute.of(tester.element(_guide))!;
        final entries = List<OverlayEntry>.of(route.overlayEntries);
        final boundary = <Map<String, Object?>>[];
        social.onAuthenticate = () {
          boundary.add({
            'routeActive': route.isActive,
            'routeCurrent': route.isCurrent,
            'overlayMounted': entries.map((entry) => entry.mounted).toList(),
            'guideElements': _guide.evaluate().length,
          });
        };
        await _approve(tester);
        await completion();
        await tester.pumpAndSettle();
        expect(social.calls, ['google']);
        debugPrint('B01_SDK_BOUNDARY $boundary');
        expect(boundary, hasLength(1));
        expect(boundary.single['routeActive'], isFalse);
        expect(boundary.single['routeCurrent'], isFalse);
        expect(boundary.single['overlayMounted'], everyElement(isFalse));
        expect(boundary.single['guideElements'], 0);
        expect(storage.value, isNull);
        expect(server.socialIssuances, 0);
      });
    },
  );

  testWidgets(
    'guest guide does not issue a session until explicit continuation',
    (tester) async {
      await _withRoot(tester, (server, storage, social) async {
        final completion = await _openGuide(tester);
        expect(server.guestIssuances, 0);
        expect(storage.value, isNull);
        expect(social.calls, isEmpty);
        await _approve(tester);
        await completion();
        await tester.pumpAndSettle();
        expect(server.guestIssuances, 1);
        expect(server.socialIssuances, 0);
        expect(find.byType(OnboardingScreen), findsOneWidget);
      });
    },
  );

  for (final method in ['barrier', 'drag', 'back']) {
    testWidgets('$method cancellation issues nothing and next choice reopens', (
      tester,
    ) async {
      await _withRoot(tester, (server, storage, social) async {
        final first = await _openGuide(
          tester,
          provider: SocialLoginProvider.google,
        );
        await _cancel(tester, method);
        await first();
        expect(social.calls, isEmpty);
        expect(server.requests, isEmpty);
        expect(storage.value, isNull);
        final second = await _openGuide(
          tester,
          provider: SocialLoginProvider.kakao,
        );
        await _approve(tester);
        await second();
        await tester.pumpAndSettle();
        expect(social.calls, ['kakao']);
        expect(server.guestIssuances, 0);
      });
    });
  }

  testWidgets(
    'SDK cancellation retains acknowledgement across provider choices',
    (tester) async {
      await _withRoot(tester, (server, storage, social) async {
        final first = await _openGuide(
          tester,
          provider: SocialLoginProvider.google,
        );
        await _approve(tester);
        await first();
        await tester.pumpAndSettle();
        await _login(tester).onSocialLogin(SocialLoginProvider.kakao);
        await tester.pumpAndSettle();
        expect(_guide, findsNothing);
        expect(social.calls, ['google', 'kakao']);
        expect(server.requests, isEmpty);
        expect(storage.value, isNull);
      });
    },
  );

  testWidgets(
    'API failure retains acknowledgement for manual other-provider retry',
    (tester) async {
      await _withRoot(tester, (server, storage, social) async {
        social.cancel = false;
        server.failIssuance = true;
        final first = await _openGuide(
          tester,
          provider: SocialLoginProvider.google,
        );
        await _approve(tester);
        await first();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(server.socialIssuances, 1);
        expect(storage.value, isNull);
        await _login(tester).onSocialLogin(SocialLoginProvider.kakao);
        await tester.pumpAndSettle();
        expect(_guide, findsNothing);
        expect(social.calls, ['google', 'kakao']);
        expect(server.socialIssuances, 2);
        expect(server.guestIssuances, 0);
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    },
  );

  testWidgets('guide and SDK pending phases block captured duplicate choices', (
    tester,
  ) async {
    await _withRoot(tester, (server, storage, social) async {
      social.gate = Completer<SocialCredential?>();
      final screen = _login(tester);
      final first = await _openGuide(
        tester,
        provider: SocialLoginProvider.google,
      );
      await screen.onSocialLogin(SocialLoginProvider.kakao);
      await screen.onContinue();
      expect(_guide, findsOneWidget);
      expect(social.calls, isEmpty);
      expect(server.requests, isEmpty);
      await _approve(tester);
      expect(social.calls, ['google']);
      expect(_login(tester).busy, isTrue);
      await screen.onSocialLogin(SocialLoginProvider.apple);
      await screen.onContinue();
      expect(_guide, findsNothing);
      expect(social.calls, ['google']);
      expect(server.guestIssuances, 0);
      expect(server.challenges, 0);
      social.gate!.complete(null);
      await first();
      await tester.pumpAndSettle();
      expect(_login(tester).busy, isFalse);
    });
  });

  testWidgets('logout creates a new login visit and requires guide again', (
    tester,
  ) async {
    await _withRoot(tester, (server, storage, social) async {
      social.cancel = false;
      final first = await _openGuide(
        tester,
        provider: SocialLoginProvider.google,
      );
      await _approve(tester);
      await first();
      await tester.pumpAndSettle();
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
      await tester.pumpAndSettle();
      tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
      await tester.pumpAndSettle();
      await logoutFromAccount(tester);
      await tester.pumpAndSettle();
      expect(server.logouts, 1);
      expect(storage.value, isNull);
      final second = await _openGuide(tester);
      expect(server.guestIssuances, 0);
      await _cancel(tester, 'back');
      await second();
      expect(server.guestIssuances, 0);
    });
  });

  testWidgets(
    'fresh root does not persist a prior cancelled SDK acknowledgement',
    (tester) async {
      await _withRoot(tester, (server, storage, social) async {
        final first = await _openGuide(
          tester,
          provider: SocialLoginProvider.google,
        );
        await _approve(tester);
        await first();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await _pumpRoot(tester, storage, social);
        final second = await _openGuide(
          tester,
          provider: SocialLoginProvider.kakao,
        );
        expect(social.calls, ['google']);
        await _cancel(tester, 'barrier');
        await second();
        expect(storage.writes, 0);
      });
    },
  );

  testWidgets(
    'guest account linking bypasses guide and keeps its existing back',
    (tester) async {
      await _withRoot(tester, (server, storage, social) async {
        final saved = storage.value;
        tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
        await tester.pumpAndSettle();
        tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
        await tester.pumpAndSettle();
        await tester
            .widget<AccountManagementScreen>(
              find.byType(AccountManagementScreen),
            )
            .onConnect();
        await tester.pumpAndSettle();
        expect(_login(tester).linkingGuest, isTrue);
        expect(_login(tester).onBack, isNotNull);
        await _login(tester).onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        expect(_guide, findsNothing);
        expect(social.calls, ['google']);
        expect(storage.value, saved);
        expect(server.socialIssuances, 0);
        _login(tester).onBack!();
        await tester.pumpAndSettle();
        expect(find.byType(AccountManagementScreen), findsOneWidget);
      }, stored: true);
    },
  );

  testWidgets(
    'providerless legacy login keeps guest choice without the guide',
    (tester) async {
      await _withRoot(tester, (server, storage, social) async {
        expect(_login(tester).providers, isEmpty);
        await _login(tester).onContinue();
        await tester.pumpAndSettle();
        expect(_guide, findsNothing);
        expect(server.guestIssuances, 1);
        expect(find.byType(OnboardingScreen), findsOneWidget);
      }, noProviders: true);
    },
  );

  testWidgets('dispose during guide reverse transition ignores late approval', (
    tester,
  ) async {
    await _withRoot(tester, (server, storage, social) async {
      final first = await _openGuide(
        tester,
        provider: SocialLoginProvider.google,
      );
      await tester.tap(_continue);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await first();
      expect(social.calls, isEmpty);
      expect(server.requests, isEmpty);
      expect(storage.value, isNull);
    });
  });

  testWidgets(
    'route invalidation cancels only this guide and ignores old choice',
    (tester) async {
      await _withRoot(tester, (server, storage, social) async {
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        home.onTab(AppRoute.login);
        await tester.pumpAndSettle();
        final saved = storage.value;
        final before = server.requests.length;
        final first = await _openGuide(
          tester,
          provider: SocialLoginProvider.google,
        );
        final dialog = showDialog<void>(
          context: tester.element(_guide),
          builder: (_) => const AlertDialog(title: Text('별도 대화상자 유지')),
        );
        await tester.pumpAndSettle();
        expect(find.text('별도 대화상자 유지'), findsOneWidget);
        home.onTab(AppRoute.my);
        await tester.pumpAndSettle();
        await first();
        expect(_guide, findsNothing);
        expect(find.text('별도 대화상자 유지'), findsOneWidget);
        expect(social.calls, isEmpty);
        expect(server.socialIssuances, 0);
        expect(server.guestIssuances, 0);
        expect(storage.value, saved);
        // Changing root tabs may read the existing profile, but may not create a
        // new authentication request from the invalidated captured choice.
        expect(
          server.requests
              .skip(before)
              .where(
                (r) => (r['path'] as String).startsWith('/api/v1/auth/social/'),
              ),
          isEmpty,
        );
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        await tester.pumpAndSettle();
        await dialog;
        expect(find.byType(MyScreen), findsOneWidget);
      }, stored: true);
    },
  );
}
