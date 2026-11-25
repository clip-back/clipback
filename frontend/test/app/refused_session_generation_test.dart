// #474 재검수 3차: a refused refresh ends only the account it was refused for.
// A login that replaces it while the native barrier or the storage queue holds
// the ending keeps its memory and stored tokens.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/app_dependencies.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage extends ApiSessionStorage {
  final writes = <String>[];
  int clears = 0;
  Completer<void>? gate;

  @override
  Future<void> write(ApiSession session) async {
    final hold = gate;
    if (hold != null) await hold.future;
    writes.add(session.accessToken);
  }

  @override
  Future<void> clear() async {
    clears++;
  }
}

class _Social extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders => [];
  @override
  Stream<void> get appleCredentialRevocations => const Stream.empty();
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => null;
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.unavailable;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.huturu.app/share');
  late _Storage storage;
  late AppDependencies dependencies;
  late List<String?> authorizations;
  late int blocks;
  late int guests;

  // Every request of the first guest is refused (refresh included, unless
  // [rotate] answers it with new tokens that are refused again); the second
  // guest's categories load.
  Future<void> start({
    Future<int> Function()? block,
    bool rotate = false,
  }) async {
    storage = _Storage();
    authorizations = [];
    blocks = 0;
    guests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/guest')) {
        final prefix = ++guests == 1 ? 'a' : 'b';
        return http.Response(
          jsonEncode({
            'access_token': '$prefix-access',
            'refresh_token': '$prefix-refresh',
            'expires_in': 3600,
            'refresh_expires_in': 86400,
          }),
          201,
        );
      }
      if (rotate && request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          jsonEncode({
            'access_token': 'a2-access',
            'refresh_token': 'a2-refresh',
            'expires_in': 3600,
            'refresh_expires_in': 86400,
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/categories')) {
        authorizations.add(request.headers['Authorization']);
        if (request.headers['Authorization'] == 'Bearer b-access') {
          return http.Response('[]', 200);
        }
      }
      return http.Response('{"detail":"expired"}', 401);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'blockCredential') {
            blocks++;
            return block == null ? 1 : block();
          }
          throw StateError('Unexpected native action: ${call.method}');
        });
    addTearDown(() {
      client.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await http.runWithClient(() async {
      dependencies = AppDependencies(
        storage: storage,
        socialAuth: _Social(),
        nativeShare: NativeShareService(enabled: true),
      );
    }, () => client);
    addTearDown(dependencies.dispose);
    // The API's HTTP client was taken from the zone above.
    await dependencies.session.createGuestSession();
    expect(storage.writes, ['a-access']);
  }

  for (final replace in [true, false]) {
    testWidgets(
      replace
          ? 'a login during the native barrier keeps its memory and stored tokens'
          : 'without a new login the refused account ends after the barrier',
      (tester) async {
        final block = Completer<int>();
        await start(block: () => block.future);
        final restore = dependencies.app.restoreSession();
        await tester.pump();
        expect(blocks, 1); // The refused account's ending entered the barrier.
        expect(storage.clears, 0);
        if (replace) {
          await dependencies.session.createGuestSession();
          expect(dependencies.session.hasSession, isTrue);
          expect(storage.writes, ['a-access', 'b-access']);
        }
        block.complete(1);
        await tester.pump();
        await restore;
        await tester.pump();
        if (replace) {
          expect(
            (
              dependencies.session.hasSession,
              storage.clears,
              storage.writes.join(','),
            ),
            (true, 0, 'a-access,b-access'),
          );
          await dependencies.content.loadCategories();
          expect(authorizations.last, 'Bearer b-access');
        } else {
          expect(
            (
              dependencies.session.hasSession,
              storage.clears,
              storage.writes.join(','),
            ),
            (false, 1, 'a-access'),
          );
        }
        await tester.pump(const Duration(seconds: 30));
      },
    );
  }

  testWidgets(
    'a login during the barrier of a final 401 after a refresh keeps its tokens',
    (tester) async {
      final block = Completer<int>();
      await start(block: () => block.future, rotate: true);
      final restore = dependencies.app.restoreSession();
      await tester.pump();
      // The resent request was refused too: its ending entered the barrier.
      expect(authorizations, ['Bearer a-access', 'Bearer a2-access']);
      expect(blocks, 1);
      await dependencies.session.createGuestSession();
      expect(storage.writes.last, 'b-access');
      block.complete(1);
      await tester.pump();
      await restore;
      await tester.pump();
      expect(
        (dependencies.session.hasSession, storage.clears, storage.writes.last),
        (true, 0, 'b-access'),
      );
      await dependencies.content.loadCategories();
      expect(authorizations.last, 'Bearer b-access');
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets(
    'a login while the clear waits in the storage queue keeps its tokens',
    (tester) async {
      await start();
      // A write of the first guest holds the queue (a slow device write).
      final gate = storage.gate = Completer<void>();
      dependencies.session.retryPersistence();
      await tester.pump();
      expect(dependencies.session.storageBusy, isTrue);
      final restore = dependencies.app.restoreSession();
      await tester.pump();
      expect(blocks, 1);
      expect(dependencies.session.pendingSessionClear, isTrue);
      expect(storage.clears, 0); // The clear waits behind the held write.
      // The second guest's error, if its issue fails.
      final issued = dependencies.session.createGuestSession().then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      await tester.pump();
      expect(guests, 2);
      expect(dependencies.session.hasSession, isTrue);
      storage.gate = null;
      gate.complete();
      await tester.pump();
      final issueError = await issued;
      await restore;
      await tester.pump();
      expect(
        (
          issueError?.toString(),
          dependencies.session.hasSession,
          dependencies.session.pendingSessionClear,
          storage.clears,
          storage.writes.last,
        ),
        (null, true, false, 0, 'b-access'),
      );
      await dependencies.content.loadCategories();
      expect(authorizations.last, 'Bearer b-access');
      await tester.pump(const Duration(seconds: 30));
    },
  );
}
