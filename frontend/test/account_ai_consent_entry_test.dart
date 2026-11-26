// #479: the AI 전송 동의 screen opened from 계정 관리, from the server's JSON
// answers (#474 "계정 관리에서 연 화면" column). The harness follows
// ai_consent_entry_test.dart (#477), which this file leaves unchanged.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/logout_confirmation_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/ai_consent_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
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
  }) async => provider == SocialLoginProvider.apple
      ? const SocialCredential(
          token: 'id-token',
          authorizationCode: 'code',
          providerUserId: 'apple-user',
        )
      : const SocialCredential(token: 'provider-token');
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
    if (path == '/api/v1/auth/social/apple/challenge') {
      return _json({
        'challenge_id': 'challenge-1',
        'nonce': 'nonce-1',
        'expires_at': '2030-10-12T00:00:00Z',
      });
    }
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

Future<void> _socialLogin(WidgetTester tester) => performLoginChoice(
  tester,
  () => tester
      .widget<LoginScreen>(find.byType(LoginScreen))
      .onSocialLogin(SocialLoginProvider.google),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The app's fonts, so text heights (U1) are measured as on a device.
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    final bold = FontLoader('PretendardDetail')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'));
    await bold.load();
  });

  // #479: the same screen opened from 계정 관리 ("계정 관리에서 연 화면" column).
  group('account management', () {
    final account = find.byType(AccountManagementScreen);
    final row = find.byKey(const ValueKey('account-ai-consent'));
    String status(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('account-ai-consent-status')))
        .data!;
    Map<String, Object> saved(String status) => {
      'status': status,
      'notice_version': 1,
      'decided_at': '2026-11-26T03:00:00Z',
    };

    Future<void> openAccount(WidgetTester tester) async {
      if (_consent.evaluate().isNotEmpty) {
        await tester.tap(_close);
        await tester.pumpAndSettle();
      }
      tester.widget<HomeScreen>(_home).onTab(AppRoute.my);
      await tester.pumpAndSettle();
      tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
      await tester.pumpAndSettle();
      expect(account, findsOneWidget);
    }

    Future<void> openRow(WidgetTester tester) async {
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(_consent, findsOneWidget);
      expect(account, findsNothing);
    }

    for (final (value, text) in [
      ('granted', '동의함'),
      ('denied', '동의 안 함'),
      ('undecided', '선택 전'),
    ]) {
      testWidgets('$value shows "$text" in the row', (tester) async {
        final server = _Server()..consent[1] = value;
        await _app(tester, server, () async {
          await openAccount(tester);
          expect(find.text('AI 전송 동의'), findsOneWidget);
          expect(status(tester), text);
          expect(server.puts, isEmpty);
        });
      });
    }

    testWidgets('an answer without the field shows no row', (tester) async {
      final server = _Server()..consent.remove(1);
      await _app(tester, server, () async {
        await openAccount(tester);
        expect(row, findsNothing);
        expect(find.text('로그아웃'), findsOneWidget);
      });
    });

    testWidgets('the row opens the same screen with the detail link', (
      tester,
    ) async {
      final server = _Server()..consent[1] = 'granted';
      await _app(tester, server, () async {
        await openAccount(tester);
        await openRow(tester);
        expect(find.text('AI 전송에 동의하시겠어요?'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('ai-consent-detail-link')),
          findsOneWidget,
        );
        expect(_screen(tester).saving, isFalse);
      });
    });

    for (final (from, finder, sent, text) in [
      ('granted', _deny, 'denied', '동의 안 함'),
      ('denied', _agree, 'granted', '동의함'),
      ('undecided', _agree, 'granted', '동의함'),
      ('undecided', _deny, 'denied', '동의 안 함'),
    ]) {
      testWidgets('$from → $sent is saved and the row shows "$text"', (
        tester,
      ) async {
        final server = _Server()..consent[1] = from;
        await _app(tester, server, () async {
          await openAccount(tester);
          await openRow(tester);
          await tester.tap(finder);
          await tester.pumpAndSettle();
          expect(server.puts, [(1, sent, 1)]);
          expect(server.consent[1], sent);
          expect(_consent, findsNothing);
          expect(account, findsOneWidget);
          expect(status(tester), text);
          expect(find.text(_saveFailed), findsNothing);
        });
      });
    }

    for (final (name, leave) in <(String, Future<void> Function(WidgetTester))>[
      ('✕', (tester) => tester.tap(_close)),
      ('system back', (tester) => tester.binding.handlePopRoute()),
    ]) {
      for (final value in ['granted', 'undecided']) {
        testWidgets('$name keeps $value and returns to the account', (
          tester,
        ) async {
          final server = _Server()..consent[1] = value;
          await _app(tester, server, () async {
            await openAccount(tester);
            final before = status(tester);
            await openRow(tester);
            await leave(tester);
            await tester.pumpAndSettle();
            expect(_consent, findsNothing);
            expect(account, findsOneWidget);
            expect(status(tester), before);
            expect(server.puts, isEmpty);
            expect(server.consent[1], value);
          });
        });
      }
    }

    testWidgets('a failure stays with the notice, a retry saves', (
      tester,
    ) async {
      var fail = true;
      final server = _Server()..consent[1] = 'granted';
      server.putRespond = (request) async {
        if (fail) return _json({'detail': 'no'}, 500);
        server.consent[1] = 'denied';
        return _json(saved('denied'));
      };
      await _app(tester, server, () async {
        await openAccount(tester);
        await openRow(tester);
        await tester.tap(_deny);
        await tester.pumpAndSettle();
        expect(_consent, findsOneWidget);
        expect(account, findsNothing);
        expect(find.text(_saveFailed), findsOneWidget);
        expect(_screen(tester).saving, isFalse);
        fail = false;
        await tester.tap(_deny);
        await tester.pumpAndSettle();
        expect(server.puts, [(1, 'denied', 1), (1, 'denied', 1)]);
        expect(account, findsOneWidget);
        expect(status(tester), '동의 안 함');
      });
    });

    testWidgets('✕ and back are locked while saving', (tester) async {
      final put = Completer<http.Response>();
      final server = _Server()
        ..consent[1] = 'granted'
        ..putRespond = (_) => put.future;
      await _app(tester, server, () async {
        await openAccount(tester);
        await openRow(tester);
        await tester.tap(_deny);
        await tester.pump();
        expect(_screen(tester).saving, isTrue);
        await tester.tap(_close, warnIfMissed: false);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(_consent, findsOneWidget);
        expect(server.puts, hasLength(1));
        put.complete(_json(saved('denied')));
        await tester.pumpAndSettle();
        expect(account, findsOneWidget);
        expect(status(tester), '동의 안 함');
      });
    });
    // The first account read failed (or had no consent field), so the row
    // comes from a later read of the same account.
    Future<void> laterRead(
      WidgetTester tester,
      _Server server,
      Future<void> Function() check, {
      required String value,
      required bool failFirst,
    }) async {
      server
        ..consent[1] = value
        ..tokenUser['social-access'] = 1
        ..feed.add({
          'id': 1,
          'saved_at': '2026-10-20T00:00:00Z',
          'summary_status': 'queued',
          'is_favorite': false,
          'last_viewed_at': null,
          'summary': '',
          'content_type': 'link',
          'source': 'web',
          'title': 'queued',
          'original_url': 'https://example.com',
          'categories': <Object>[],
          'tags': <Object>[],
          'assets': <Object>[],
        });
      var first = true;
      server.meRespond = (_) async {
        if (!first) return null;
        first = false;
        return failFirst
            ? _json({'detail': 'down'}, 500)
            : _json(server._me(1)..remove('ai_consent_status'));
      };
      await _app(tester, server, () async {
        expect(_home, findsOneWidget);
        expect(_consent, findsNothing);
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        await openAccount(tester);
        expect(server.meReads.length, greaterThan(1));
        await check();
      });
    }

    for (final (value, text) in [('granted', '동의함'), ('undecided', '선택 전')]) {
      testWidgets('after a failed first read, $value opens and closes', (
        tester,
      ) async {
        final server = _Server();
        await laterRead(
          tester,
          server,
          () async {
            expect(status(tester), text);
            await openRow(tester);
            await tester.tap(_close);
            await tester.pumpAndSettle();
            expect(account, findsOneWidget);
            expect(status(tester), text);
            expect(server.puts, isEmpty);
          },
          value: value,
          failFirst: true,
        );
      });
    }

    testWidgets('after a failed first read, withdrawal is saved', (
      tester,
    ) async {
      final server = _Server();
      await laterRead(
        tester,
        server,
        () async {
          await openRow(tester);
          await tester.tap(_deny);
          await tester.pumpAndSettle();
          expect(server.puts, [(1, 'denied', 1)]);
          expect(account, findsOneWidget);
          expect(status(tester), '동의 안 함');
        },
        value: 'granted',
        failFirst: true,
      );
    });

    // Closing here keeps the choice only; "not asked again in this run"
    // belongs to the first display (#474).
    for (final (name, leave) in <(String, Future<void> Function(WidgetTester))>[
      ('✕', (tester) => tester.tap(_close)),
      ('system back', (tester) => tester.binding.handlePopRoute()),
    ]) {
      testWidgets('$name here still lets the first display ask after login', (
        tester,
      ) async {
        final server = _Server();
        await laterRead(
          tester,
          server,
          () async {
            expect(status(tester), '선택 전');
            await openRow(tester);
            await leave(tester);
            await tester.pumpAndSettle();
            expect(account, findsOneWidget);
            await tester.widget<AccountManagementScreen>(account).onLogout();
            await tester.pumpAndSettle();
            await tester
                .widget<LogoutConfirmationScreen>(
                  find.byType(LogoutConfirmationScreen),
                )
                .onConfirm();
            await tester.pumpAndSettle();
            await _socialLogin(tester);
            await tester.pumpAndSettle();
            expect(_consent, findsOneWidget);
            expect(server.puts, isEmpty);
          },
          value: 'undecided',
          failFirst: false,
        );
      });
    }
  });
}
