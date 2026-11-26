// #477: the AI 전송 동의 screen at app entry, from the server's JSON answers.
// Rows follow #474 "앱의 동의 화면 표시 판단", "앱 진입 순서",
// "앱의 동의 저장 완료 판정" and its overlap table.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/logout_confirmation_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/ai_consent_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/share/pending_share_prompt.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_navigation.dart';
import 'support/app_startup.dart';

const _saveFailed = '선택을 저장하지 못했어요. 다시 시도해 주세요.';
const _consentCopy = 'AI 전송에 동의하지 않아 요약하지 않았어요.';

http.Response _json(Object? value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object> _tokens(String prefix, {bool isNew = false}) => {
  'access_token': '$prefix-access',
  'refresh_token': '$prefix-refresh',
  'expires_in': 3600,
  'refresh_expires_in': 86400,
  'is_new_user': isNew,
};

class _Social extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders =>
      SocialLoginProvider.values;
  final revocations = StreamController<void>.broadcast();
  @override
  Stream<void> get appleCredentialRevocations => revocations.stream;
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => const SocialCredential(token: 'provider-token');
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? id) async {}
  AppleCredentialStatus state = AppleCredentialStatus.authorized;
  @override
  Future<AppleCredentialStatus> appleCredentialState() async => state;
}

/// Accounts by access token. `consent[id]` is sent as ai_consent_status;
/// an id without a key sends no field (an older server).
class _Server {
  final consent = <int, Object?>{1: 'undecided'};
  final tokenUser = <String, int>{
    'stored-access': 1,
    'guest-access': 1,
    'social-access': 2,
    'upgraded-access': 1,
    'rotated-access': 1,
  };
  final guests = <int>{};
  final apple = <int>{};
  Future<http.Response> Function()? refreshRespond;
  bool newUser = false;
  final feed = <Map<String, Object?>>[];
  final puts = <(int, Object?, Object?)>[];
  final meReads = <int>[];

  /// Answers a PUT instead of saving; null saves and answers 200.
  Future<http.Response> Function(http.Request)? putRespond;

  /// Answers `GET /users/me` instead of the account; null answers it.
  Future<http.Response?> Function(http.Request)? meRespond;
  Future<http.Response?> Function(http.Request)? upgradeRespond;
  final calls = <String>[];

  int _user(http.Request request) {
    final token = request.headers['Authorization']?.replaceFirst('Bearer ', '');
    return tokenUser[token] ?? 0;
  }

  Map<String, Object?> _me(int id) => {
    'id': id,
    'email': null,
    'display_name': '사용자 $id',
    'is_guest': guests.contains(id),
    'created_at': '2026-10-10T00:00:00Z',
    'linked_providers': guests.contains(id)
        ? <String>[]
        : [apple.contains(id) ? 'apple' : 'google'],
    if (consent.containsKey(id)) 'ai_consent_status': consent[id],
  };

  late final client = MockClient((request) async {
    final path = request.url.path;
    calls.add('${request.method} $path');
    if (path.startsWith('/api/v1/auth/social/')) {
      if (path.endsWith('/upgrade')) {
        final override = await upgradeRespond?.call(request);
        if (override != null) return override;
        return _json(_tokens('upgraded'));
      }
      return _json(_tokens('social', isNew: newUser));
    }
    final contentMatch = RegExp(
      r'^/api/v1/contents/(\d+)(/view)?$',
    ).firstMatch(path);
    if (contentMatch != null) {
      if (contentMatch[2] != null) return _json(<String, Object>{}, 201);
      final id = int.parse(contentMatch[1]!);
      return _json(feed.singleWhere((item) => item['id'] == id));
    }
    switch (path) {
      case '/api/v1/users/me':
        if (request.method == 'GET') {
          final id = _user(request);
          meReads.add(id);
          final override = await meRespond?.call(request);
          if (override != null) return override;
          return _json(_me(id));
        }
      case '/api/v1/users/me/ai-consent':
        final id = _user(request);
        final body = (jsonDecode(request.body) as Map).cast<String, Object?>();
        puts.add((id, body['status'], body['notice_version']));
        final respond = putRespond;
        if (respond != null) return respond(request);
        consent[id] = body['status'];
        return _json({
          'status': body['status'],
          'notice_version': 1,
          'decided_at': '2026-11-26T03:00:00Z',
        });
      case '/api/v1/auth/guest':
        guests.add(1);
        return _json(_tokens('guest'), 201);
      case '/api/v1/auth/refresh':
        return refreshRespond?.call() ?? _json(_tokens('rotated'));
      case '/api/v1/auth/logout':
        return http.Response('', 204);
      case '/api/v1/auth/share-credential':
        return _json({
          'share_token': 'fixture-share',
          'expires_at': '2030-10-18T00:00:00Z',
          'user_id': _user(request),
          'session_id': 1,
        });
      case '/api/v1/users/me/stats':
        return _json({
          'saved_count': feed.length,
          'reopened_count': 0,
          'recent_reopened_count': 0,
        });
      case '/api/v1/categories':
        return _json(<Object>[]);
      case '/api/v1/feed':
        return _json({
          'items': feed,
          'next_cursor': null,
          'total_count': feed.length,
        });
      case '/api/v1/recommendations/weekly':
        return _json({
          'period_start': '2026-10-19T00:00:00Z',
          'period_end': '2026-10-26T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        });
      case '/api/v1/metrics/events':
        return _json(<String, Object>{}, 201);
    }
    throw StateError('Unexpected ${request.method} $path');
  });
}

Future<void> _app(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check, {
  bool stored = true,
  bool settle = true,
  NativeShareService? nativeShare,
  _Social? social,
  Size size = const Size(428, 1000),
}) async {
  SharedPreferences.setMockInitialValues({
    if (stored)
      'clipback.session': jsonEncode({
        'access_token': 'stored-access',
        'refresh_token': 'stored-refresh',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
      }),
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(server.client.close);
  social ??= _Social();
  addTearDown(social.revocations.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(socialAuth: social, nativeShare: nativeShare),
      );
      await completeAppStartup(tester, settle: settle);
      await check();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

final _consent = find.byType(AiConsentScreen);
final _home = find.byType(HomeScreen);
final _agree = find.byKey(const ValueKey('ai-consent-agree'));
final _deny = find.byKey(const ValueKey('ai-consent-deny'));
final _close = find.byKey(const ValueKey('ai-consent-close'));

AiConsentScreen _screen(WidgetTester tester) =>
    tester.widget<AiConsentScreen>(_consent);

Future<void> _logout(WidgetTester tester) async {
  tester.widget<HomeScreen>(_home).onTab(AppRoute.my);
  await tester.pumpAndSettle();
  tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
  await tester.pumpAndSettle();
  await tester
      .widget<AccountManagementScreen>(find.byType(AccountManagementScreen))
      .onLogout();
  await tester.pumpAndSettle();
  await tester
      .widget<LogoutConfirmationScreen>(find.byType(LogoutConfirmationScreen))
      .onConfirm();
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
}

Future<void> _socialLogin(WidgetTester tester) => performLoginChoice(
  tester,
  () => tester
      .widget<LoginScreen>(find.byType(LoginScreen))
      .onSocialLogin(SocialLoginProvider.google),
);

Future<void> _openConnect(WidgetTester tester) async {
  tester.widget<HomeScreen>(_home).onTab(AppRoute.my);
  await tester.pumpAndSettle();
  tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
  await tester.pumpAndSettle();
  await tester
      .widget<AccountManagementScreen>(find.byType(AccountManagementScreen))
      .onConnect();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('display decision', () {
    for (final (name, value) in <(String, Object?)>[
      ('missing field', #missing),
      ('null', null),
      ('unknown value', 'later'),
      ('number', 7),
      ('list', <String>['undecided']),
      ('granted', 'granted'),
      ('denied', 'denied'),
    ]) {
      testWidgets('$name shows home without the consent screen', (
        tester,
      ) async {
        final server = _Server();
        if (value == #missing) {
          server.consent.remove(1);
        } else {
          server.consent[1] = value;
        }
        await _app(tester, server, () async {
          expect(_home, findsOneWidget);
          expect(_consent, findsNothing);
          expect(server.puts, isEmpty);
        });
      });
    }

    testWidgets('an account read failure keeps the existing path', (
      tester,
    ) async {
      final server = _Server()
        ..meRespond = (_) async => _json({'detail': 'down'}, 500);
      await _app(tester, server, () async {
        expect(_consent, findsNothing);
        expect(_home, findsOneWidget);
        expect(server.puts, isEmpty);
      });
    });

    testWidgets('undecided shows the screen before home', (tester) async {
      final server = _Server();
      await _app(tester, server, () async {
        expect(_consent, findsOneWidget);
        expect(_home, findsNothing);
        expect(server.puts, isEmpty);
      });
    });

    testWidgets('a late account answer shows the screen, then home', (
      tester,
    ) async {
      final gate = Completer<void>();
      final server = _Server()
        ..meRespond = (_) async {
          await gate.future;
          return null;
        };
      await _app(tester, server, () async {
        await tester.pump(const Duration(seconds: 2));
        expect(_home, findsOneWidget, reason: 'home does not wait for me');
        expect(_consent, findsNothing);
        gate.complete();
        await tester.pumpAndSettle();
        expect(_consent, findsOneWidget);
        await tester.tap(_agree);
        await tester.pumpAndSettle();
        expect(_home, findsOneWidget);
        expect(_consent, findsNothing);
      }, settle: false);
    });
  });

  group('choices', () {
    for (final (label, finder, status) in [
      ('agree', _agree, 'granted'),
      ('deny', _deny, 'denied'),
    ]) {
      testWidgets('$label saves $status with version 1 and opens home', (
        tester,
      ) async {
        final server = _Server();
        await _app(tester, server, () async {
          await tester.tap(finder);
          await tester.pumpAndSettle();
          expect(server.puts, [(1, status, 1)]);
          expect(_home, findsOneWidget);
          expect(_consent, findsNothing);
        });
      });
    }

    testWidgets('✕ opens home without saving', (tester) async {
      final server = _Server();
      await _app(tester, server, () async {
        await tester.tap(_close);
        await tester.pumpAndSettle();
        expect(_home, findsOneWidget);
        expect(server.puts, isEmpty);
      });
    });

    testWidgets('system back opens home without saving', (tester) async {
      final server = _Server();
      await _app(tester, server, () async {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_home, findsOneWidget);
        expect(_consent, findsNothing);
        expect(server.puts, isEmpty);
      });
    });

    testWidgets('a closed account is not asked again after logout and login', (
      tester,
    ) async {
      final server = _Server()
        ..consent[2] = 'undecided'
        ..tokenUser['social-access'] = 1;
      await _app(tester, server, () async {
        await tester.tap(_close);
        await tester.pumpAndSettle();
        await _logout(tester);
        await _socialLogin(tester);
        await tester.pumpAndSettle();
        expect(_consent, findsNothing);
        expect(_home, findsOneWidget);
        expect(server.puts, isEmpty);
      });
    });

    testWidgets('another account closed in this run does not count', (
      tester,
    ) async {
      final server = _Server()..consent[2] = 'undecided';
      await _app(tester, server, () async {
        await tester.tap(_close);
        await tester.pumpAndSettle();
        await _logout(tester);
        await _socialLogin(tester);
        await tester.pumpAndSettle();
        expect(_consent, findsOneWidget);
        await tester.tap(_agree);
        await tester.pumpAndSettle();
        expect(server.puts.single.$1, 2);
        expect(_home, findsOneWidget);
      });
    });
  });

  group('entry order', () {
    testWidgets('guest start shows the screen, then onboarding once', (
      tester,
    ) async {
      final server = _Server();
      await _app(tester, server, () async {
        await performLoginChoice(
          tester,
          () =>
              tester.widget<LoginScreen>(find.byType(LoginScreen)).onContinue(),
        );
        await tester.pumpAndSettle();
        expect(_consent, findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(_home, findsNothing);
        await tester.tap(_agree);
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(_home, findsNothing);
        expect(server.puts.single, (1, 'granted', 1));
      }, stored: false);
    });

    for (final isNew in [true, false]) {
      testWidgets('social login new=$isNew shows the screen first', (
        tester,
      ) async {
        final server = _Server()
          ..newUser = isNew
          ..consent[2] = 'undecided';
        await _app(tester, server, () async {
          await _socialLogin(tester);
          await tester.pumpAndSettle();
          expect(_consent, findsOneWidget);
          expect(find.byType(OnboardingScreen), findsNothing);
          expect(_home, findsNothing);
          await tester.tap(_deny);
          await tester.pumpAndSettle();
          expect(
            find.byType(isNew ? OnboardingScreen : HomeScreen),
            findsOneWidget,
          );
          expect(server.puts.single, (2, 'denied', 1));
        }, stored: false);
      });
    }

    for (final status in ['granted', 'closed']) {
      testWidgets('guest upgrade of the same account ($status) skips it', (
        tester,
      ) async {
        final server = _Server()..guests.add(1);
        if (status == 'granted') server.consent[1] = 'granted';
        await _app(tester, server, () async {
          if (status == 'closed') {
            await tester.tap(_close);
            await tester.pumpAndSettle();
          }
          await _openConnect(tester);
          server.guests.remove(1);
          await performLoginChoice(
            tester,
            () => tester
                .widget<LoginScreen>(find.byType(LoginScreen))
                .onSocialLogin(SocialLoginProvider.google),
          );
          await tester.pumpAndSettle();
          expect(
            server.calls,
            contains('POST /api/v1/auth/social/google/upgrade'),
          );
          expect(_consent, findsNothing);
          expect(server.puts, isEmpty);
        });
      });
    }

    testWidgets('switching after a conflict judges only the new account', (
      tester,
    ) async {
      final put = Completer<http.Response>();
      final server = _Server()
        ..guests.add(1)
        ..consent[2] = 'undecided'
        ..upgradeRespond = (_) async => _json({'detail': 'linked'}, 409);
      await _app(tester, server, () async {
        // The guest closes; the switched account is asked anyway.
        await tester.tap(_close);
        await tester.pumpAndSettle();
        await _openConnect(tester);
        final attempt = tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('account-link-conflict-confirm')),
        );
        await tester.pumpAndSettle();
        await attempt;
        expect(_consent, findsOneWidget);
        server.putRespond = (_) => put.future;
        await tester.tap(_agree);
        await tester.pump();
        expect(server.puts.single.$1, 2);
      });
      put.complete(_json({}, 500));
    });
  });

  group('save result', () {
    Future<void> expectFailure(WidgetTester tester, _Server server) async {
      expect(_consent, findsOneWidget);
      expect(_home, findsNothing);
      expect(find.text(_saveFailed), findsOneWidget);
      expect(_screen(tester).saving, isFalse);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: _agree, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNotNull,
      );
    }

    for (final status in [422, 500, 503]) {
      testWidgets('$status shows the notice without a check read', (
        tester,
      ) async {
        final server = _Server()
          ..putRespond = (_) async => _json({'detail': 'no'}, status);
        await _app(tester, server, () async {
          final reads = server.meReads.length;
          await tester.tap(_agree);
          await tester.pumpAndSettle();
          await expectFailure(tester, server);
          expect(server.meReads.length, reads);
          expect(server.puts, hasLength(1));
        });
      });
    }

    for (final (name, body) in [
      ('empty', ''),
      (
        'other status',
        '{"status":"denied","notice_version":1,'
            '"decided_at":"2026-11-26T03:00:00Z"}',
      ),
      (
        'bad time',
        '{"status":"granted","notice_version":1,'
            '"decided_at":"2026-02-31T03:00:00Z"}',
      ),
    ]) {
      for (final confirmed in [true, false]) {
        testWidgets('200 $name, check read confirmed=$confirmed', (
          tester,
        ) async {
          final server = _Server()
            ..putRespond = (_) async => http.Response(body, 200);
          await _app(tester, server, () async {
            if (confirmed) server.consent[1] = 'granted';
            final reads = server.meReads.length;
            await tester.tap(_agree);
            await tester.pumpAndSettle();
            expect(server.meReads.length, reads + 1);
            if (confirmed) {
              expect(_home, findsOneWidget);
              expect(find.text(_saveFailed), findsNothing);
            } else {
              await expectFailure(tester, server);
            }
          });
        });
      }
    }

    testWidgets('a failed check read shows the notice', (tester) async {
      final server = _Server()
        ..putRespond = (_) async => http.Response('', 200);
      await _app(tester, server, () async {
        server.meRespond = (_) async => _json({'detail': 'down'}, 500);
        await tester.tap(_agree);
        await tester.pumpAndSettle();
        await expectFailure(tester, server);
      });
    });

    testWidgets('a lost connection checks once', (tester) async {
      final server = _Server()
        ..putRespond = (_) async => throw http.ClientException('lost');
      await _app(tester, server, () async {
        server.consent[1] = 'granted';
        final reads = server.meReads.length;
        await tester.tap(_agree);
        await tester.pumpAndSettle();
        expect(server.meReads.length, reads + 1);
        expect(_home, findsOneWidget);
      });
    });

    testWidgets('401 refreshes and resends once for the same account', (
      tester,
    ) async {
      var first = true;
      final server = _Server();
      server.putRespond = (request) async {
        if (first) {
          first = false;
          return _json({'detail': 'expired'}, 401);
        }
        return _json({
          'status': 'granted',
          'notice_version': 1,
          'decided_at': '2026-11-26T03:00:00Z',
        });
      };
      await _app(tester, server, () async {
        await tester.tap(_agree);
        await tester.pumpAndSettle();
        expect(
          server.calls.where((c) => c == 'POST /api/v1/auth/refresh'),
          hasLength(1),
        );
        expect(server.puts, hasLength(2));
        expect(_home, findsOneWidget);
      });
    });

    testWidgets('a refused refresh ends the session without a notice', (
      tester,
    ) async {
      final server = _Server()
        ..putRespond = ((_) async => _json({'detail': 'expired'}, 401))
        ..refreshRespond = () async => _json({'detail': 'refused'}, 401);
      await _app(tester, server, () async {
        await tester.tap(_agree);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(_consent, findsNothing);
        expect(find.text(_saveFailed), findsNothing);
        expect(server.puts, hasLength(1));
      });
    });

    testWidgets('buttons, ✕ and back are locked while saving', (tester) async {
      final put = Completer<http.Response>();
      final server = _Server()..putRespond = (_) => put.future;
      await _app(tester, server, () async {
        await tester.tap(_agree);
        await tester.pump();
        expect(_screen(tester).saving, isTrue);
        await tester.tap(_deny, warnIfMissed: false);
        await tester.tap(_close, warnIfMissed: false);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(server.puts, hasLength(1));
        expect(_consent, findsOneWidget);
        put.complete(
          _json({
            'status': 'granted',
            'notice_version': 1,
            'decided_at': '2026-11-26T03:00:00Z',
          }),
        );
        await tester.pumpAndSettle();
        expect(_home, findsOneWidget);
      });
    });

    testWidgets('a hung save unlocks at 15 seconds and drops late answers', (
      tester,
    ) async {
      final put = Completer<http.Response>();
      final check = Completer<http.Response?>();
      final server = _Server()..putRespond = (_) => put.future;
      await _app(tester, server, () async {
        final reads = server.meReads.length;
        server.meRespond = (_) => check.future;
        await tester.tap(_agree);
        await tester.pump();
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        expect(server.meReads.length, reads + 1, reason: 'check after 10 s');
        expect(_screen(tester).saving, isTrue);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(_screen(tester).saving, isFalse);
        expect(find.text(_saveFailed), findsOneWidget);
        put.complete(
          _json({
            'status': 'granted',
            'notice_version': 1,
            'decided_at': '2026-11-26T03:00:00Z',
          }),
        );
        check.complete(null);
        await tester.pumpAndSettle();
        expect(_consent, findsOneWidget);
        expect(_home, findsNothing);
        expect(server.puts, hasLength(1));
      });
    });

    testWidgets('a retry after failure sends the same choice again', (
      tester,
    ) async {
      var fail = true;
      final server = _Server();
      server.putRespond = (request) async {
        if (fail) return _json({'detail': 'no'}, 500);
        return _json({
          'status': 'granted',
          'notice_version': 1,
          'decided_at': '2026-11-26T03:00:00Z',
        });
      };
      await _app(tester, server, () async {
        await tester.tap(_agree);
        await tester.pumpAndSettle();
        fail = false;
        await tester.tap(_agree);
        await tester.pumpAndSettle();
        expect(server.puts, hasLength(2));
        expect(_home, findsOneWidget);
      });
    });
  });

  // U1: the save notice over "동의하고 계속" with the app theme and an iPhone
  // safe area. It covers the button (J3 keeps its place); it must be
  // swipeable and the button usable again once it is gone.
  group('U1 save notice over the agree button', () {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('width $width scale $scale', (tester) async {
          tester.view.padding = const FakeViewPadding(top: 50, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 50, bottom: 34);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          var fail = true;
          final server = _Server();
          server.putRespond = (_) async => fail
              ? _json({'detail': 'no'}, 500)
              : _json({
                  'status': 'granted',
                  'notice_version': 1,
                  'decided_at': '2026-11-26T03:00:00Z',
                });
          await _app(tester, server, () async {
            await tester.tap(_agree);
            await tester.pumpAndSettle();
            final notice = tester.getRect(find.byType(SnackBar));
            final button = tester.getRect(_agree);
            final covered = (button.bottom - notice.top).clamp(
              0.0,
              button.height,
            );
            debugPrint(
              'U1 width=$width scale=$scale notice=${notice.height} '
              'covered=$covered left=${button.height - covered}',
            );
            // Recorded only: #474 predicted 16–43 covered; J3 keeps the place.
            expect(covered, greaterThan(0));
            // Swiped down, the notice goes and the button takes taps.
            await tester.drag(find.byType(SnackBar), const Offset(0, 200));
            await tester.pumpAndSettle();
            expect(find.byType(SnackBar), findsNothing);
            await tester.tap(_agree);
            await tester.pumpAndSettle();
            expect(find.byType(SnackBar), findsOneWidget);
            // Left alone, it times out and the button takes taps again.
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
            expect(find.byType(SnackBar), findsNothing);
            fail = false;
            await tester.tap(_agree);
            await tester.pumpAndSettle();
            expect(_home, findsOneWidget);
          }, size: Size(width, 812));
        });
      }
    }
  });

  group('overlap', () {
    Future<void> revokeApple(WidgetTester tester, _Social social) async {
      social.state = AppleCredentialStatus.revoked;
      social.revocations.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    }

    testWidgets('a session ended during the save drops its answer', (
      tester,
    ) async {
      final put = Completer<http.Response>();
      final social = _Social();
      final server = _Server()
        ..apple.add(1)
        ..consent[2] = 'undecided'
        ..putRespond = (_) => put.future;
      await _app(tester, server, () async {
        await tester.tap(_agree);
        await tester.pump();
        await revokeApple(tester, social);
        put.complete(
          _json({
            'status': 'granted',
            'notice_version': 1,
            'decided_at': '2026-11-26T03:00:00Z',
          }),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(_home, findsNothing);
        expect(find.text(_saveFailed), findsNothing);
        expect(server.puts, hasLength(1));
        // The next account starts on its own unlocked screen.
        server.putRespond = null;
        await _socialLogin(tester);
        await tester.pumpAndSettle();
        expect(_consent, findsOneWidget);
        expect(_screen(tester).saving, isFalse);
      }, social: social);
    });

    testWidgets('an account change during the 401 refresh resends nothing', (
      tester,
    ) async {
      final refresh = Completer<http.Response>();
      final social = _Social();
      final server = _Server()
        ..apple.add(1)
        ..putRespond = ((_) async => _json({'detail': 'expired'}, 401))
        ..refreshRespond = () => refresh.future;
      await _app(tester, server, () async {
        await tester.tap(_agree);
        await tester.pump();
        await tester.pump();
        expect(server.calls, contains('POST /api/v1/auth/refresh'));
        // The Apple revocation ends this login while the refresh is out.
        social.state = AppleCredentialStatus.revoked;
        social.revocations.add(null);
        await tester.pump();
        refresh.complete(_json(_tokens('rotated')));
        await tester.pumpAndSettle();
        expect(server.puts, hasLength(1));
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text(_saveFailed), findsNothing);
      }, social: social);
    });

    testWidgets('a save finished in the background moves on when back', (
      tester,
    ) async {
      final put = Completer<http.Response>();
      final server = _Server()..putRespond = (_) => put.future;
      await _app(tester, server, () async {
        await tester.tap(_agree);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        put.complete(
          _json({
            'status': 'granted',
            'notice_version': 1,
            'decided_at': '2026-11-26T03:00:00Z',
          }),
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(_home, findsOneWidget);
        expect(_consent, findsNothing);
      });
    });
  });

  group('pending share prompt', () {
    const channel = MethodChannel('com.huturu.app/share');
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getState':
                return {
                  'revision': 3,
                  'drafts': [
                    {'id': 'mine', 'label': '내 공유', 'userId': 1},
                    {'id': 'other', 'label': '다른 계정 공유', 'userId': 9},
                  ],
                  'receipts': <Object>[],
                };
              case 'publishCredential':
                return true;
              case 'blockCredential':
                return 4;
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('waits for the consent screen, then shows this account once', (
      tester,
    ) async {
      final server = _Server();
      await _app(tester, server, () async {
        expect(_consent, findsOneWidget);
        final held = tester.widget<PendingSharePrompt>(
          find.byType(PendingSharePrompt),
        );
        expect(held.drafts, isEmpty);
        expect(find.textContaining('저장 대기 중인 공유'), findsNothing);
        await tester.tap(_close);
        await tester.pumpAndSettle();
        final shown = tester.widget<PendingSharePrompt>(
          find.byType(PendingSharePrompt),
        );
        expect(shown.drafts.map((d) => d.id), ['mine']);
        expect(find.text('저장 대기 중인 공유 1개'), findsOneWidget);
      }, nativeShare: NativeShareService(enabled: true));
    });
  });

  group('detail summary after the first consent', () {
    Map<String, Object?> item(int id, String type, String source) => {
      'id': id,
      'saved_at': '2026-11-20T03:00:00Z',
      'summary_status': 'skipped',
      'summary_error_code': 'ai_consent_required',
      'categories': <Object>[],
      'tags': <Object>[],
      'assets': type == 'screenshot'
          ? [
              {
                'id': 90,
                'asset_type': 'screenshot',
                'mime_type': 'image/png',
                'download_url': '/api/v1/uploads/assets/90',
              },
            ]
          : <Object>[],
      'content_type': type,
      'source': source,
      'title': '동의 전에 저장한 $source',
      'summary': '저장된 설명 $id',
      'original_url': type == 'link'
          ? 'https://www.youtube.com/watch?v=consent'
          : null,
      'is_favorite': false,
      'last_viewed_at': null,
    };

    for (final (type, source) in [
      ('link', 'youtube'),
      ('link', 'instagram'),
      ('screenshot', 'screenshot'),
    ]) {
      testWidgets('$source keeps the consent copy after agreeing', (
        tester,
      ) async {
        final server = _Server()..feed.add(item(7, type, source));
        await _app(tester, server, () async {
          await tester.tap(_agree);
          await tester.pumpAndSettle();
          final home = tester.widget<HomeScreen>(_home);
          home.onOpenContent(home.contents.single);
          await tester.pumpAndSettle();
          expect(find.byType(DetailScreen), findsOneWidget);
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('detail-summary')))
                .data,
            _consentCopy,
          );
          expect(find.text('저장된 설명 7'), findsNothing);
        });
      });
    }
  });
}
