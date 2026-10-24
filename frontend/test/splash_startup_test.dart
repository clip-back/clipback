import 'auth_navigation.dart';
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/session_restore_screen.dart';
import 'package:clipback_frontend/features/auth/splash_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/share/pending_share_prompt.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _stored = ApiSession(
  accessToken: 'startup-access',
  refreshToken: 'startup-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _warning = '로그인 정보를 기기에 저장하지 못했어요. 앱을 종료하기 전에 다시 저장해 주세요.';

class _Storage extends ApiSessionStorage {
  _Storage([this.value]);
  ApiSession? value;
  Completer<ApiSession?>? readGate;
  bool failRead = false, failWrite = false;
  int reads = 0, writes = 0, clears = 0;
  @override
  Future<ApiSession?> read() async {
    reads++;
    if (failRead) throw StateError('fixture storage unavailable');
    if (readGate != null) return readGate!.future;
    return value;
  }

  @override
  Future<void> write(ApiSession next) async {
    writes++;
    if (failWrite) throw StateError('fixture persistence unavailable');
    value = next;
  }

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

class _Social extends SocialAuth {
  int checks = 0;
  AppleCredentialStatus status = AppleCredentialStatus.authorized;
  @override
  List<SocialLoginProvider> get supportedProviders => const [
    SocialLoginProvider.kakao,
    SocialLoginProvider.google,
  ];
  @override
  Stream<void> get appleCredentialRevocations => const Stream.empty();
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => null;
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async {
    checks++;
    return status;
  }
}

class _Server {
  final paths = <String>[];
  Completer<http.Response>? categoriesGate;
  bool failCategories = false, rejectOld = false, rejectRefresh = false;
  bool apple = false;
  http.Response json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  late final client = MockClient((r) async {
    final path = r.url.path;
    paths.add(path);
    if (path == '/api/v1/categories') {
      if (categoriesGate != null) return categoriesGate!.future;
      if (rejectOld && r.headers['Authorization'] == 'Bearer startup-access') {
        return json({'detail': 'Invalid or expired token'}, 401);
      }
      if (failCategories) return json({'detail': 'Temporary failure'}, 503);
      return json(<Object>[]);
    }
    if (path == '/api/v1/auth/refresh') {
      if (rejectRefresh) return json({'detail': 'Invalid refresh token'}, 401);
      return json({
        'access_token': 'rotated-access',
        'refresh_token': 'rotated-refresh',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
      });
    }
    if (path == '/api/v1/feed') {
      return json({'items': <Object>[], 'next_cursor': null});
    }
    if (path == '/api/v1/users/me') {
      return json({
        'id': 71,
        'email': null,
        'display_name': '시작 검증',
        'is_guest': !apple,
        'created_at': '2026-10-18T00:00:00Z',
        'linked_providers': apple ? ['apple'] : <String>[],
      });
    }
    if (path == '/api/v1/users/me/stats') {
      return json({'saved_count': 0, 'reopened_count': 0});
    }
    if (path == '/api/v1/auth/logout') return http.Response('', 204);
    throw StateError('Unexpected fixture request: $path');
  });
}

Future<void> _flush(WidgetTester tester) async {
  // Resolve immediate restore futures without advancing the 900ms clock.
  for (var i = 0; i < 12; i++) {
    await tester.pump();
  }
}

Future<void> _withRoot(
  WidgetTester tester,
  _Storage storage,
  _Server server,
  Future<void> Function() body, {
  _Social? social,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(tester.view.reset);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(sessionStorage: storage, socialAuth: social ?? _Social()),
      );
      await _flush(tester);
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1000));
    }
  }, () => server.client);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  testWidgets(
    'empty restore runs immediately but login waits for 900ms exactly',
    (tester) async {
      final storage = _Storage(), server = _Server();
      await _withRoot(tester, storage, server, () async {
        expect(storage.reads, 1);
        expect(server.paths, isEmpty);
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(SessionRestoreScreen), findsNothing);
        expect(find.byType(PendingSharePrompt), findsNothing);
        await tester.pump(const Duration(milliseconds: 899));
        expect(find.byType(SplashScreen), findsOneWidget);
        final finish = tester
            .widget<SplashScreen>(find.byType(SplashScreen))
            .onDone;
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        // The route has mounted; the post-frame ready phase must not insert
        // the prompt until the following frame.
        expect(find.byType(PendingSharePrompt), findsNothing);
        await tester.pump();
        expect(find.byType(PendingSharePrompt), findsOneWidget);
        finish(); // A stale repeated completion cannot restart or misroute.
        await _flush(tester);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(storage.reads, 1);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'queued login route-close effect waits for first route frame and is consumed once',
    (tester) async {
      final storage = _Storage(), server = _Server(), social = _Social();
      await _withRoot(tester, storage, server, () async {
        // An empty restore really invokes _showLoginChoice, which queues its
        // CloseTransientRoutesEffect. The transparent sentinel observes when
        // the root drains that actual effect; no synthetic effect is emitted.
        final navigator = tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .navigatorKey!
            .currentState!;
        PageRoute<void> probe(String name) => PageRouteBuilder<void>(
          settings: RouteSettings(name: name),
          opaque: false,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => const SizedBox.shrink(),
        );
        var firstPops = 0, laterPops = 0;
        final first = probe('startup-effect-probe');
        unawaited(navigator.push(first).then((_) => firstPops++));
        await tester.pump();
        expect(first.isCurrent, isTrue);
        await tester.pump(const Duration(milliseconds: 899));
        expect(first.isCurrent, isTrue);
        expect(firstPops, 0);
        expect(find.byType(SplashScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(firstPops, 1);
        expect(first.isActive, isFalse);

        // A new probe must survive later rebuild/resume notifications: the
        // initial close effect must not be replayed after consumption.
        final later = probe('post-startup-effect-probe');
        unawaited(navigator.push(later).then((_) => laterPops++));
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          ClipbackApp(sessionStorage: storage, socialAuth: social),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        await _flush(tester);
        expect(later.isCurrent, isTrue);
        expect(laterPops, 0);
        expect(firstPops, 1);
        expect(storage.reads, 1);
        expect(find.byType(SplashScreen), findsNothing);
        navigator.pop();
        await tester.pump();
        expect(laterPops, 1);
        expect(tester.takeException(), isNull);
      }, social: social);
    },
  );

  testWidgets(
    'fast restored account requests data in parallel and opens home after 900ms',
    (tester) async {
      final storage = _Storage(_stored), server = _Server();
      await _withRoot(tester, storage, server, () async {
        expect(server.paths, contains('/api/v1/feed'));
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        await tester.pump(const Duration(milliseconds: 899));
        expect(find.byType(SplashScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        await _flush(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(
          server.paths.where((p) => p == '/api/v1/categories'),
          hasLength(1),
        );
        expect(storage.writes, 0);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'slow initial home restore uses home loader after 900ms without replay',
    (tester) async {
      final storage = _Storage(_stored), server = _Server();
      final gate = Completer<http.Response>();
      server.categoriesGate = gate;
      await _withRoot(tester, storage, server, () async {
        expect(server.paths, contains('/api/v1/categories'));
        expect(find.byType(SplashScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 900));
        await _flush(tester);
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(SessionRestoreScreen), findsNothing);
        expect(
          find.byKey(const ValueKey('home-initial-loading-screen')),
          findsOneWidget,
        );
        expect(find.text('홈을 불러오는 중'), findsOneWidget);
        server.categoriesGate = null;
        gate.complete(server.json(<Object>[]));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final storageFailure in [false, true]) {
    testWidgets(
      '${storageFailure ? "storage" : "network"} restore failure waits for splash then existing retry',
      (tester) async {
        final storage = _Storage(_stored)..failRead = storageFailure;
        final server = _Server()..failCategories = !storageFailure;
        await _withRoot(tester, storage, server, () async {
          expect(find.byType(SplashScreen), findsOneWidget);
          expect(find.text('다시 시도'), findsNothing);
          await tester.pump(const Duration(milliseconds: 900));
          await _flush(tester);
          expect(find.byType(SessionRestoreScreen), findsOneWidget);
          expect(find.text('다시 시도'), findsOneWidget);
          storage.failRead = false;
          server.failCategories = false;
          await tester.tap(find.text('다시 시도'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 900));
          await tester.pumpAndSettle();
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(find.byType(SplashScreen), findsNothing);
          expect(storage.clears, 0);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets(
    'known invalid session clears during splash and never forces home or guest',
    (tester) async {
      final storage = _Storage(_stored);
      final server = _Server()
        ..rejectOld = true
        ..rejectRefresh = true;
      await _withRoot(tester, storage, server, () async {
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(storage.clears, 1);
        expect(storage.value, isNull);
        expect(find.byType(LoginScreen), findsNothing);
        await tester.pump(const Duration(milliseconds: 900));
        await _flush(tester);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        expect(server.paths, isNot(contains('/api/v1/auth/guest')));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'persistence warning waits for chosen route then retries using latest session',
    (tester) async {
      final storage = _Storage(_stored)..failWrite = true;
      final server = _Server()..rejectOld = true;
      await _withRoot(tester, storage, server, () async {
        expect(storage.writes, 1);
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.text(_warning), findsNothing);
        expect(find.byType(MaterialBanner), findsNothing);
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text(_warning), findsOneWidget);
        storage.failWrite = false;
        await tester.tap(find.text('다시 저장'));
        await tester.pumpAndSettle();
        expect(storage.value?.accessToken, 'rotated-access');
        expect(storage.writes, 2);
        expect(find.text(_warning), findsNothing);
        expect(find.byType(SplashScreen), findsNothing);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'Apple revocation checking and invalidation are not delayed by splash',
    (tester) async {
      final storage = _Storage(_stored), server = _Server()..apple = true;
      final social = _Social()..status = AppleCredentialStatus.revoked;
      await _withRoot(tester, storage, server, () async {
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(social.checks, 1);
        expect(storage.clears, 1);
        await tester.pump(const Duration(milliseconds: 900));
        await _flush(tester);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        expect(tester.takeException(), isNull);
      }, social: social);
    },
  );

  testWidgets(
    'rebuild resume and logout do not replay startup or restore a second time',
    (tester) async {
      final storage = _Storage(_stored), server = _Server(), social = _Social();
      await _withRoot(tester, storage, server, () async {
        await tester.pump(const Duration(milliseconds: 400));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          ClipbackApp(sessionStorage: storage, socialAuth: social),
        );
        await _flush(tester);
        await tester.pump(const Duration(milliseconds: 499));
        expect(find.byType(SplashScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        await _flush(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(storage.reads, 1);
        tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.my);
        await tester.pumpAndSettle();
        tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
        await tester.pumpAndSettle();
        await logoutFromAccount(tester);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _flush(tester);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(storage.reads, 1);
        expect(tester.takeException(), isNull);
      }, social: social);
    },
  );

  testWidgets(
    'disposing before 900ms suppresses callback and late restore presentation',
    (tester) async {
      final storage = _Storage()..readGate = Completer<ApiSession?>();
      final server = _Server();
      await _withRoot(tester, storage, server, () async {
        expect(find.byType(SplashScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(const SizedBox.shrink());
        storage.readGate!.complete(_stored);
        await tester.pump(const Duration(milliseconds: 1000));
        await _flush(tester);
        expect(find.byType(HomeScreen), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);
        expect(server.paths, isEmpty);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
