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
  testWidgets('인증 갱신 뒤 공유 자격증명 재준비는 끝난 HTTP 요청과 독립적으로 완료한다', (tester) async {
    var expire = false;
    var holdNative = false;
    final native = Completer<Map<String, Object>>();
    final credentials = <String?>[];
    final published = <Object?>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      Object body;
      if (path.endsWith('/auth/guest') || path.endsWith('/auth/refresh')) {
        final prefix = path.endsWith('/refresh') ? 'rotated' : 'original';
        body = {
          'access_token': '$prefix-access',
          'refresh_token': '$prefix-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        };
      } else if (path.endsWith('/auth/share-credential')) {
        credentials.add(request.headers['Authorization']);
        body = {
          'share_token': 'share-${credentials.length}',
          'expires_at': '2099-01-01T00:00:00Z',
          'user_id': 7,
          'session_id': 11,
        };
      } else if (path.endsWith('/categories')) {
        if (expire &&
            request.headers['Authorization'] == 'Bearer original-access') {
          return http.Response('{"detail":"expired"}', 401);
        }
        body = <Object>[];
      } else if (path.endsWith('/feed')) {
        body = {'items': <Object>[], 'next_cursor': null};
      } else if (path.endsWith('/users/me')) {
        body = {
          'id': 7,
          'email': null,
          'display_name': '공유 계정',
          'is_guest': true,
          'created_at': '2026-10-05T00:00:00Z',
          'linked_providers': <String>[],
        };
      } else if (path.endsWith('/stats')) {
        body = {'saved_count': 0, 'reopened_count': 0};
      } else {
        throw StateError('Unexpected request: $path');
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    const channel = MethodChannel('com.huturu.app/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getState') {
            if (holdNative) return native.future;
            return {'revision': 0, 'drafts': [], 'receipts': []};
          }
          if (call.method == 'publishCredential') {
            published.add((call.arguments as Map)['token']);
            return true;
          }
          throw StateError('Unexpected native action: ${call.method}');
        });
    addTearDown(() {
      client.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await http.runWithClient(() async {
      final dependencies = AppDependencies(
        storage: Storage(),
        socialAuth: Social(),
        nativeShare: NativeShareService(enabled: true),
      );
      addTearDown(dependencies.dispose);
      await dependencies.session.createGuestSession();
      await dependencies.initializeAccount.load();
      await dependencies.sharing.prepare();
      expect(dependencies.sharing.error, isNull);
      expect(credentials, ['Bearer original-access']);
      expect(published, ['share-1']);
      holdNative = true;
      expire = true;
      await dependencies.content.loadCategories();
      await tester.pump();
      expect(credentials, ['Bearer original-access']);
      native.complete({'revision': 0, 'drafts': [], 'receipts': []});
      await tester.pump();
      expect(credentials, ['Bearer original-access', 'Bearer rotated-access']);
      expect(published, ['share-1', 'share-2']);
      expect(dependencies.sharing.ready, isTrue);
      expect(dependencies.sharing.error, isNull);
    }, () => client);
  });

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
