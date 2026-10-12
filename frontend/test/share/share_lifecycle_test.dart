import 'dart:async';
import 'dart:convert';
import 'package:clipback_frontend/app/app_dependencies.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Storage extends ApiSessionStorage {
  int clears = 0;
  @override
  Future<void> write(ApiSession session) async {}
  @override
  Future<void> clear() async {
    clears++;
  }
}

class Social extends SocialAuth {
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
  for (final disposeEarly in [false, true]) {
    test(
      'late 401 ${disposeEarly ? "after disposal cannot alter native or persistent state" : "still clears invalid login when native block fails"}',
      () async {
        var nativeBlocks = 0;
        final storage = Storage();
        final response = Completer<http.Response>();
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/auth/guest')) {
            return http.Response(
              jsonEncode({
                'access_token': 'fixture',
                'refresh_token': 'fixture-refresh',
                'expires_in': 60,
                'refresh_expires_in': 600,
              }),
              201,
            );
          }
          if (request.url.path.endsWith('/auth/refresh')) {
            return http.Response('{"detail":"invalid"}', 401);
          }
          return response.future;
        });
        const channel = MethodChannel('com.huturu.app/share');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'blockCredential') {
                nativeBlocks++;
                throw PlatformException(code: 'disk');
              }
              return {'revision': 0, 'drafts': [], 'receipts': []};
            });
        addTearDown(() {
          client.close();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });
        await http.runWithClient(() async {
          final dependencies = AppDependencies(
            storage: storage,
            socialAuth: Social(),
            nativeShare: NativeShareService(enabled: true),
          );
          await dependencies.session.createGuestSession();
          final loading = dependencies.content.loadCategories();
          final failed = expectLater(
            loading,
            throwsA(isA<ClipbackApiException>()),
          );
          await Future<void>.delayed(Duration.zero);
          if (disposeEarly) dependencies.dispose();
          response.complete(http.Response('{"detail":"invalid"}', 401));
          await failed;
          expect(nativeBlocks, disposeEarly ? 0 : 1);
          expect(storage.clears, disposeEarly ? 0 : 1);
          if (!disposeEarly) {
            expect(dependencies.session.hasSession, isFalse);
            expect(dependencies.app.route, AppRoute.login);
            expect(dependencies.sharing.error, isNotNull);
            dependencies.dispose();
          }
        }, () => client);
      },
    );
  }
}
