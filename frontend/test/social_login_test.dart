import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/main.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _session = ApiSession(
  accessToken: 'guest-access',
  refreshToken: 'guest-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);

class _Social extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders =>
      SocialLoginProvider.values;
  final calls = <SocialLoginProvider>[];
  final nonces = <String?>[];
  final revocations = StreamController<void>.broadcast();
  SocialCredential? credential = const SocialCredential(
    token: 'provider-token',
    displayName: 'SDK 사용자',
  );
  Future<SocialCredential?> Function()? respond;
  AppleCredentialStatus state = AppleCredentialStatus.authorized;
  String? remembered;
  @override
  Stream<void> get appleCredentialRevocations => revocations.stream;
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async {
    calls.add(provider);
    nonces.add(nonce);
    return respond != null ? respond!() : credential;
  }

  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? id) async {
    remembered = id;
  }

  @override
  Future<AppleCredentialStatus> appleCredentialState() async => state;
}

class _Storage extends ApiSessionStorage {
  bool failWrite = false;
  bool failClear = false;
  int writes = 0;
  @override
  Future<void> write(ApiSession session) async {
    writes++;
    if (failWrite) throw StateError('storage unavailable');
    await super.write(session);
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('clear unavailable');
    await super.clear();
  }
}

http.Response _json(Object value, [int status = 200]) => http.Response(
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

class _Server {
  bool guest = true;
  bool newUser = false;
  String provider = 'google';
  int challenges = 0;
  Future<http.Response?> Function(http.Request)? respond;
  final calls = <http.Request>[];
  late final client = MockClient((request) async {
    calls.add(request);
    final override = await respond?.call(request);
    if (override != null) return override;
    final path = request.url.path;
    if (path == '/api/v1/auth/social/apple/challenge') {
      challenges++;
      return _json({
        'challenge_id': 'challenge-$challenges',
        'nonce': 'nonce-$challenges',
        'expires_at': '2026-10-12T00:00:00Z',
      });
    }
    if (path.startsWith('/api/v1/auth/social/')) {
      guest = false;
      provider = path.split('/')[5];
      return _json(_tokens('social', isNew: newUser));
    }
    return switch (path) {
      '/api/v1/auth/guest' => _json(_tokens('guest'), 201),
      '/api/v1/auth/logout' => http.Response('', 204),
      '/api/v1/auth/refresh' => _json(_tokens('rotated')),
      '/api/v1/categories' => _json(<Object>[]),
      '/api/v1/feed' => _json({'items': <Object>[], 'next_cursor': null}),
      '/api/v1/users/me' => _json({
        'id': guest ? 1 : 2,
        'email': null,
        'display_name': guest ? '게스트' : '연결된 사용자',
        'is_guest': guest,
        'created_at': '2026-10-10T00:00:00Z',
        'linked_providers': guest ? <String>[] : [provider],
      }),
      '/api/v1/users/me/stats' => _json({
        'saved_count': 0,
        'reopened_count': 0,
      }),
      _ => throw StateError('Unexpected ${request.method} $path'),
    };
  });
  List<http.Request> at(String suffix) =>
      calls.where((r) => r.url.path == '/api/v1$suffix').toList();
}

Future<void> _app(
  WidgetTester tester,
  _Server server,
  _Social social,
  Future<void> Function() check, {
  bool stored = false,
  _Storage? storage,
}) async {
  SharedPreferences.setMockInitialValues({});
  if (stored) await ApiSessionStorage().write(_session);
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(server.client.close);
  addTearDown(social.revocations.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(sessionStorage: storage, socialAuth: social),
      );
      await tester.pumpAndSettle();
      await check();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _openConnect(WidgetTester tester) async {
  tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
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
  testWidgets(
    'first launch waits for an explicit choice; cancellation keeps it empty',
    (tester) async {
      final server = _Server();
      final social = _Social()..credential = null;
      await _app(tester, server, social, () async {
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(server.calls, isEmpty);
        await tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        expect(server.calls, isEmpty);
        expect(await ApiSessionStorage().read(), isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
      });
    },
  );

  for (final isNew in [false, true]) {
    testWidgets(
      'social login reloads profile; onboarding only when new=$isNew',
      (tester) async {
        final server = _Server()..newUser = isNew;
        await _app(tester, server, _Social(), () async {
          await tester
              .widget<LoginScreen>(find.byType(LoginScreen))
              .onSocialLogin(SocialLoginProvider.google);
          await tester.pumpAndSettle();
          expect(server.at('/auth/social/google'), hasLength(1));
          expect(jsonDecode(server.at('/auth/social/google').single.body), {
            'token': 'provider-token',
          });
          expect(server.at('/auth/guest'), isEmpty);
          expect(
            (await ApiSessionStorage().read())?.accessToken,
            'social-access',
          );
          expect(
            find.byType(isNew ? OnboardingScreen : HomeScreen),
            findsOneWidget,
          );
        });
      },
    );
  }

  testWidgets(
    'guest connection uses upgrade and preserves the session on 409 cancellation',
    (tester) async {
      final server = _Server()
        ..respond = (r) async => r.url.path.endsWith('/upgrade')
            ? _json({'detail': 'already linked'}, 409)
            : null;
      await _app(tester, server, _Social(), () async {
        await _openConnect(tester);
        final attempt = tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        expect(find.text('이미 연결된 계정이에요'), findsOneWidget);
        expect((await ApiSessionStorage().read())?.accessToken, 'guest-access');
        await tester.tap(find.text('게스트 유지'));
        await tester.pumpAndSettle();
        await attempt;
        expect(server.at('/auth/social/google'), isEmpty);
        expect(
          server
              .at('/auth/social/google/upgrade')
              .single
              .headers['Authorization'],
          'Bearer guest-access',
        );
      }, stored: true);
    },
  );

  testWidgets(
    'confirmed Apple conflict uses a new challenge and SDK credential',
    (tester) async {
      final server = _Server()
        ..respond = (r) async => r.url.path.endsWith('/upgrade')
            ? _json({'detail': 'already linked'}, 409)
            : null;
      final social = _Social()
        ..credential = const SocialCredential(
          token: 'id-token',
          authorizationCode: 'code',
          providerUserId: 'apple-user',
        );
      await _app(tester, server, social, () async {
        await _openConnect(tester);
        final attempt = tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.apple);
        await tester.pumpAndSettle();
        await tester.tap(find.text('기존 계정으로 전환'));
        await tester.pumpAndSettle();
        await attempt;
        expect(social.nonces, ['nonce-1', 'nonce-2']);
        expect(jsonDecode(server.at('/auth/social/apple/challenge')[0].body), {
          'purpose': 'upgrade',
        });
        expect(jsonDecode(server.at('/auth/social/apple/challenge')[1].body), {
          'purpose': 'login',
        });
        expect(
          server.at('/auth/social/apple/challenge')[1].headers['Authorization'],
          isNull,
        );
        expect(
          jsonDecode(
            server.at('/auth/social/apple').single.body,
          )['challenge_id'],
          'challenge-2',
        );
        expect(social.remembered, 'apple-user');
        expect(find.byType(HomeScreen), findsOneWidget);
      }, stored: true);
    },
  );

  testWidgets('SDK work is single-flight and logout cannot race it', (
    tester,
  ) async {
    final pending = Completer<SocialCredential?>();
    final social = _Social()..respond = () => pending.future;
    final server = _Server();
    await _app(tester, server, social, () async {
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
      await tester.pumpAndSettle();
      tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
      await tester.pumpAndSettle();
      final account = tester.widget<AccountManagementScreen>(
        find.byType(AccountManagementScreen),
      );
      await account.onConnect();
      await tester.pumpAndSettle();
      final screen = tester.widget<LoginScreen>(find.byType(LoginScreen));
      final first = screen.onSocialLogin(SocialLoginProvider.google);
      await tester.pump();
      await screen.onSocialLogin(SocialLoginProvider.kakao);
      await account.onLogout();
      expect(social.calls, [SocialLoginProvider.google]);
      expect(server.at('/auth/logout'), isEmpty);
      pending.complete(null);
      await first;
      await tester.pumpAndSettle();
      expect((await ApiSessionStorage().read())?.accessToken, 'guest-access');
    }, stored: true);
  });

  testWidgets(
    'successful issuance with failed storage retries only persistence',
    (tester) async {
      final server = _Server();
      final storage = _Storage()..failWrite = true;
      await _app(tester, server, _Social(), () async {
        await tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(server.at('/auth/social/google'), hasLength(1));
        storage.failWrite = false;
        await tester.tap(find.text('다시 저장'));
        await tester.pumpAndSettle();
        expect(
          (await ApiSessionStorage().read())?.accessToken,
          'social-access',
        );
        expect(server.at('/auth/social/google'), hasLength(1));
      }, storage: storage);
    },
  );

  testWidgets('post-login feed retry does not issue tokens again', (
    tester,
  ) async {
    var fail = true;
    final server = _Server()..newUser = true;
    server.respond = (r) async => r.url.path.endsWith('/feed') && fail
        ? _json({'detail': 'unavailable'}, 503)
        : null;
    await _app(tester, server, _Social(), () async {
      await tester
          .widget<LoginScreen>(find.byType(LoginScreen))
          .onSocialLogin(SocialLoginProvider.google);
      await tester.pumpAndSettle();
      expect(find.text('다시 시도'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(server.at('/auth/social/google'), hasLength(1));
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });

  testWidgets('stats failure does not hide a known guest connection action', (
    tester,
  ) async {
    final server = _Server()
      ..respond = (r) async => r.url.path.endsWith('/stats')
          ? _json({'detail': 'unavailable'}, 503)
          : null;
    await _app(tester, server, _Social(), () async {
      await _openConnect(tester);
      expect(
        tester.widget<LoginScreen>(find.byType(LoginScreen)).linkingGuest,
        isTrue,
      );
    }, stored: true);
  });

  testWidgets(
    'confirmed Apple revocation returns to login despite logout network failure',
    (tester) async {
      final server = _Server()
        ..guest = false
        ..provider = 'apple';
      server.respond = (r) async => r.url.path.endsWith('/logout')
          ? throw http.ClientException('offline')
          : null;
      final social = _Social()..state = AppleCredentialStatus.revoked;
      await _app(tester, server, social, () async {
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(await ApiSessionStorage().read(), isNull);
        expect(server.at('/auth/guest'), isEmpty);
      }, stored: true);
    },
  );
  for (final expiredGuest in [false, true]) {
    testWidgets(
      'Apple upgrade rejection validates guest without replay (expired=$expiredGuest)',
      (tester) async {
        var rejected = false;
        final server = _Server();
        server.respond = (r) async {
          if (r.url.path.endsWith('/upgrade')) {
            rejected = true;
            return _json({'detail': 'Invalid social credential'}, 401);
          }
          if (rejected &&
              expiredGuest &&
              r.url.path.endsWith('/users/me') &&
              r.headers['Authorization'] == 'Bearer guest-access') {
            return _json({'detail': 'Expired access token'}, 401);
          }
          return null;
        };
        final social = _Social()
          ..credential = const SocialCredential(
            token: 'apple-token',
            authorizationCode: 'one-use-code',
            providerUserId: 'apple-user',
          );
        await _app(tester, server, social, () async {
          await _openConnect(tester);
          await tester
              .widget<LoginScreen>(find.byType(LoginScreen))
              .onSocialLogin(SocialLoginProvider.apple);
          await tester.pumpAndSettle();
          expect(server.at('/auth/social/apple/upgrade'), hasLength(1));
          expect(server.at('/auth/social/apple/challenge'), hasLength(1));
          expect(social.calls, [SocialLoginProvider.apple]);
          expect(server.at('/auth/refresh'), hasLength(expiredGuest ? 1 : 0));
          expect(
            (await ApiSessionStorage().read())?.accessToken,
            expiredGuest ? 'rotated-access' : 'guest-access',
          );
          expect(
            tester.widget<LoginScreen>(find.byType(LoginScreen)).linkingGuest,
            isTrue,
          );
          expect(server.at('/auth/guest'), isEmpty);
          expect(social.remembered, isNull);
        }, stored: true);
      },
    );
  }

  testWidgets(
    'upgrade credential rejection with expired refresh asks for login',
    (tester) async {
      var rejected = false;
      final server = _Server();
      server.respond = (r) async {
        if (r.url.path.endsWith('/upgrade')) rejected = true;
        if (rejected &&
            (r.url.path.endsWith('/upgrade') ||
                r.url.path.endsWith('/users/me') ||
                r.url.path.endsWith('/refresh'))) {
          return _json({'detail': 'Invalid credential'}, 401);
        }
        return null;
      };
      await _app(tester, server, _Social(), () async {
        await _openConnect(tester);
        await tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        expect(server.at('/auth/social/google/upgrade'), hasLength(1));
        expect(server.at('/auth/refresh'), hasLength(1));
        expect(await ApiSessionStorage().read(), isNull);
        expect(
          tester.widget<LoginScreen>(find.byType(LoginScreen)).linkingGuest,
          isFalse,
        );
        expect(server.at('/auth/guest'), isEmpty);
      }, stored: true);
    },
  );

  testWidgets(
    'unavailable guest verification after rejected upgrade preserves data',
    (tester) async {
      var rejected = false;
      final server = _Server();
      server.respond = (r) async {
        if (r.url.path.endsWith('/upgrade')) {
          rejected = true;
          return _json({'detail': 'Invalid credential'}, 401);
        }
        if (rejected && r.url.path.endsWith('/users/me')) {
          return _json({'detail': 'Provider unavailable'}, 502);
        }
        return null;
      };
      await _app(tester, server, _Social(), () async {
        await _openConnect(tester);
        await tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.kakao);
        await tester.pumpAndSettle();
        expect(server.at('/auth/social/kakao/upgrade'), hasLength(1));
        expect(server.at('/auth/refresh'), isEmpty);
        expect((await ApiSessionStorage().read())?.accessToken, 'guest-access');
        expect(
          tester.widget<LoginScreen>(find.byType(LoginScreen)).linkingGuest,
          isTrue,
        );
      }, stored: true);
    },
  );

  testWidgets(
    'Apple device status unavailable preserves session; revocation event clears it',
    (tester) async {
      final server = _Server()
        ..guest = false
        ..provider = 'apple';
      final social = _Social()..state = AppleCredentialStatus.unavailable;
      await _app(tester, server, social, () async {
        expect(find.byType(HomeScreen), findsOneWidget);
        expect((await ApiSessionStorage().read())?.accessToken, 'guest-access');
        social.revocations.addError(StateError('device channel unavailable'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        social.state = AppleCredentialStatus.revoked;
        social.revocations.add(null);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(await ApiSessionStorage().read(), isNull);
      }, stored: true);
    },
  );

  testWidgets(
    'logout clear failure blocks access and retry never restores old tokens',
    (tester) async {
      final storage = _Storage()..failClear = true;
      final server = _Server();
      await _app(
        tester,
        server,
        _Social(),
        () async {
          tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
          await tester.pumpAndSettle();
          tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
          await tester.pumpAndSettle();
          await tester
              .widget<AccountManagementScreen>(
                find.byType(AccountManagementScreen),
              )
              .onLogout();
          await tester.pumpAndSettle();
          expect(find.byType(HomeScreen), findsNothing);
          expect(find.text('다시 시도'), findsOneWidget);
          storage.failClear = false;
          await tester.tap(find.text('다시 시도'));
          await tester.pumpAndSettle();
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(await ApiSessionStorage().read(), isNull);
          expect(server.at('/auth/logout'), hasLength(1));
          expect(server.at('/auth/guest'), isEmpty);
        },
        stored: true,
        storage: storage,
      );
    },
  );
  testWidgets('device revocation owns the logout lock until local cleanup', (
    tester,
  ) async {
    final pending = Completer<http.Response?>();
    addTearDown(() {
      if (!pending.isCompleted) {
        pending.complete(_json({'detail': 'offline'}, 503));
      }
    });
    final server = _Server()
      ..guest = false
      ..provider = 'apple';
    server.respond = (r) async =>
        r.url.path.endsWith('/logout') ? pending.future : null;
    final social = _Social();
    await _app(tester, server, social, () async {
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
      await tester.pumpAndSettle();
      tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
      await tester.pumpAndSettle();
      final account = tester.widget<AccountManagementScreen>(
        find.byType(AccountManagementScreen),
      );
      social.state = AppleCredentialStatus.revoked;
      social.revocations.add(null);
      await tester.pump();
      await account.onLogout();
      expect(server.at('/auth/logout'), hasLength(1));
      pending.complete(_json({'detail': 'offline'}, 503));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await ApiSessionStorage().read(), isNull);
    }, stored: true);
  });
}
