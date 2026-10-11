import 'dart:async';

import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart' as google;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;

const _config = SocialAuthConfig(
  googleServerClientId: 'test-server-client',
  googleIosClientId: 'test-ios.apps.googleusercontent.com',
  kakaoNativeAppKey: 'test-native-key',
);
const _credential = SocialCredential(token: 'test-id-token');
const _appleCredential = SocialCredential(
  token: 'test-apple-id-token',
  authorizationCode: 'test-one-use-code',
  providerUserId: 'test-apple-user',
  displayName: '테스트 사용자',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSdk sdk;
  late PlatformSocialAuth auth;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sdk = _FakeSdk();
    auth = PlatformSocialAuth(
      sdk: sdk,
      config: _config,
      platform: TargetPlatform.iOS,
    );
  });
  tearDown(() async => sdk.revocations.close());

  test('only supported mobile providers are listed', () async {
    expect(auth.supportedProviders, SocialLoginProvider.values);
    final android = PlatformSocialAuth(
      sdk: sdk,
      platform: TargetPlatform.android,
    );
    expect(android.supportedProviders, [
      SocialLoginProvider.google,
      SocialLoginProvider.kakao,
    ]);
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        PlatformSocialAuth(sdk: sdk, platform: platform).supportedProviders,
        isEmpty,
      );
    }
    final web = PlatformSocialAuth(
      sdk: sdk,
      platform: TargetPlatform.iOS,
      isWeb: true,
    );
    expect(web.supportedProviders, isEmpty);
    await expectLater(
      web.authenticate(SocialLoginProvider.google),
      throwsA(isA<SocialAuthException>()),
    );
    await expectLater(
      android.authenticate(SocialLoginProvider.apple),
      throwsA(isA<SocialAuthException>()),
    );
    expect(sdk.googleLogins, 0);
    expect(sdk.appleLogins, 0);
  });

  test(
    'missing config and iOS URL scheme mismatch stop before SDK initialization',
    () async {
      final unconfigured = PlatformSocialAuth(
        sdk: sdk,
        config: const SocialAuthConfig(
          googleServerClientId: '',
          googleIosClientId: '',
          kakaoNativeAppKey: '',
        ),
        platform: TargetPlatform.iOS,
      );
      for (final provider in [
        SocialLoginProvider.google,
        SocialLoginProvider.kakao,
      ]) {
        await expectLater(
          unconfigured.authenticate(provider),
          throwsA(isA<SocialAuthException>()),
        );
      }
      sdk.hasScheme = false;
      for (final provider in [
        SocialLoginProvider.google,
        SocialLoginProvider.kakao,
      ]) {
        await expectLater(
          auth.authenticate(provider),
          throwsA(isA<SocialAuthException>()),
        );
      }
      expect(sdk.checkedSchemes, [
        'com.googleusercontent.apps.test-ios',
        'kakaotest-native-key',
      ]);
      expect(sdk.googleInitializations, 0);
      expect(sdk.kakaoInitializations, 0);
    },
  );

  test(
    'Google initializes once with the server audience and iOS client',
    () async {
      expect(
        (await auth.authenticate(SocialLoginProvider.google))?.token,
        'test-id-token',
      );
      await auth.authenticate(SocialLoginProvider.google);
      await auth.signOut(SocialLoginProvider.google);
      expect(sdk.googleInitializations, 1);
      expect(sdk.serverClientId, _config.googleServerClientId);
      expect(sdk.iosClientId, _config.googleIosClientId);
      expect(sdk.googleLogins, 2);
      expect(sdk.googleSignOuts, 1);
      expect(sdk.kakaoClears, 0);
    },
  );

  test(
    'Android Google does not require the iOS client or native URL check',
    () async {
      final android = PlatformSocialAuth(
        sdk: sdk,
        config: const SocialAuthConfig(
          googleServerClientId: 'test-server-client',
        ),
        platform: TargetPlatform.android,
      );
      await android.authenticate(SocialLoginProvider.google);
      expect(sdk.iosClientId, isNull);
      expect(sdk.checkedSchemes, isEmpty);
    },
  );

  test(
    'Google cancellation returns null and a later login can proceed',
    () async {
      sdk.googleError = const google.GoogleSignInException(
        code: google.GoogleSignInExceptionCode.canceled,
      );
      expect(await auth.authenticate(SocialLoginProvider.google), isNull);
      sdk.googleError = null;
      expect(
        await auth.authenticate(SocialLoginProvider.google),
        same(_credential),
      );
    },
  );

  test('SDK error account details never appear in displayed errors', () async {
    sdk.googleError = StateError('test-private-provider-detail');
    await expectLater(
      auth.authenticate(SocialLoginProvider.google),
      throwsA(
        isA<SocialAuthException>().having(
          (e) => e.message,
          'sanitized message',
          isNot(contains('test-private-provider-detail')),
        ),
      ),
    );
  });

  test(
    'KakaoTalk succeeds without opening account login and forwards nonce',
    () async {
      expect(
        await auth.authenticate(SocialLoginProvider.kakao, nonce: 'test-nonce'),
        same(_credential),
      );
      expect(sdk.talkLogins, 1);
      expect(sdk.accountLogins, 0);
      expect(sdk.kakaoNonce, 'test-nonce');
      expect(sdk.kakaoKey, _config.kakaoNativeAppKey);
    },
  );

  test(
    'KakaoTalk cancellation and consent denial never fall back to account login',
    () async {
      final cancellations = [
        kakao.KakaoClientException(
          kakao.ClientErrorCause.cancelled,
          'cancelled',
        ),
        kakao.KakaoAuthException(kakao.AuthErrorCause.accessDenied, 'denied'),
        PlatformException(code: 'CANCELED'),
      ];
      for (final error in cancellations) {
        sdk.talkError = error;
        expect(await auth.authenticate(SocialLoginProvider.kakao), isNull);
      }
      expect(sdk.accountLogins, 0);
      expect(sdk.kakaoInitializations, 1);
    },
  );

  test(
    'KakaoTalk failure falls back once and missing Talk uses account login',
    () async {
      sdk.talkError = StateError('Talk unavailable');
      expect(
        await auth.authenticate(SocialLoginProvider.kakao, nonce: 'test-nonce'),
        same(_credential),
      );
      expect(sdk.accountLogins, 1);
      expect(sdk.kakaoNonce, 'test-nonce');
      sdk.talkInstalled = false;
      await auth.authenticate(SocialLoginProvider.kakao);
      expect(sdk.talkLogins, 1);
      expect(sdk.accountLogins, 2);
    },
  );

  test(
    'missing OIDC ID token is rejected without another login attempt',
    () async {
      sdk.credential = const SocialCredential(token: '');
      await expectLater(
        auth.authenticate(SocialLoginProvider.kakao),
        throwsA(isA<SocialAuthException>()),
      );
      expect(sdk.talkLogins, 1);
      expect(sdk.accountLogins, 0);
    },
  );

  test(
    'Apple requires a nonce and returns code/name without persisting before backend success',
    () async {
      await expectLater(
        auth.authenticate(SocialLoginProvider.apple),
        throwsA(isA<SocialAuthException>()),
      );
      expect(sdk.appleLogins, 0);
      final credential = await auth.authenticate(
        SocialLoginProvider.apple,
        nonce: 'server-challenge-nonce',
      );
      expect(credential, same(_appleCredential));
      expect(sdk.appleNonce, 'server-challenge-nonce');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'clipback.apple_user_id',
        ),
        isNull,
      );
    },
  );

  test(
    'Apple missing authorization code or user id cannot become a backend login',
    () async {
      for (final credential in [
        const SocialCredential(
          token: 'test-token',
          providerUserId: 'test-user',
        ),
        const SocialCredential(
          token: 'test-token',
          authorizationCode: 'test-code',
        ),
      ]) {
        sdk.appleCredential = credential;
        await expectLater(
          auth.authenticate(SocialLoginProvider.apple, nonce: 'test-nonce'),
          throwsA(isA<SocialAuthException>()),
        );
      }
    },
  );

  test('Apple cancellation is a non-error result', () async {
    sdk.appleError = const apple.SignInWithAppleAuthorizationException(
      code: apple.AuthorizationErrorCode.canceled,
      message: 'cancelled',
    );
    expect(
      await auth.authenticate(SocialLoginProvider.apple, nonce: 'test-nonce'),
      isNull,
    );
  });

  test(
    'Apple state is unavailable until remembered and preserves the session JSON',
    () async {
      SharedPreferences.setMockInitialValues({
        'clipback.session': 'test-existing-session-json',
      });
      expect(
        await auth.appleCredentialState(),
        AppleCredentialStatus.unavailable,
      );
      expect(sdk.stateChecks, 0);
      await auth.rememberAppleUserId('test-apple-user');
      for (final status in [
        AppleCredentialStatus.authorized,
        AppleCredentialStatus.revoked,
        AppleCredentialStatus.notFound,
      ]) {
        sdk.appleState = status;
        expect(await auth.appleCredentialState(), status);
        expect(sdk.checkedUserId, 'test-apple-user');
      }
      sdk.stateError = StateError('temporarily unavailable');
      expect(
        await auth.appleCredentialState(),
        AppleCredentialStatus.unavailable,
      );
      await auth.rememberAppleUserId(null);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('clipback.apple_user_id'), isNull);
      expect(
        preferences.getString('clipback.session'),
        'test-existing-session-json',
      );
    },
  );

  test('Apple revocation events are forwarded only on supported iOS', () async {
    final event = expectLater(auth.appleCredentialRevocations, emits(null));
    sdk.revocations.add(null);
    await event;
    final android = PlatformSocialAuth(
      sdk: sdk,
      platform: TargetPlatform.android,
    );
    expect(await android.appleCredentialRevocations.toList(), isEmpty);
  });

  test(
    'logout clears every local provider even if Google cleanup fails',
    () async {
      await auth.rememberAppleUserId('test-apple-user');
      sdk.signOutError = StateError('cleanup failed');
      await expectLater(auth.signOut(), throwsA(isA<SocialAuthException>()));
      expect(sdk.googleSignOuts, 1);
      expect(sdk.kakaoClears, 1);
      expect(sdk.googleLogins + sdk.talkLogins + sdk.accountLogins, 0);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'clipback.apple_user_id',
        ),
        isNull,
      );
    },
  );

  test('another provider cannot start while a login is in flight', () async {
    sdk.googlePending = Completer<SocialCredential>();
    final first = auth.authenticate(SocialLoginProvider.google);
    await expectLater(
      auth.authenticate(SocialLoginProvider.kakao),
      throwsA(isA<SocialAuthException>()),
    );
    sdk.googlePending!.complete(_credential);
    expect(await first, same(_credential));
    expect(sdk.talkLogins + sdk.accountLogins, 0);
  });
}

class _FakeSdk implements SocialAuthSdk {
  bool hasScheme = true;
  bool talkInstalled = true;
  final checkedSchemes = <String>[];
  final revocations = StreamController<void>.broadcast();
  int googleInitializations = 0;
  int kakaoInitializations = 0;
  int googleLogins = 0;
  int talkLogins = 0;
  int accountLogins = 0;
  int appleLogins = 0;
  int googleSignOuts = 0;
  int kakaoClears = 0;
  int stateChecks = 0;
  String? serverClientId;
  String? iosClientId;
  String? kakaoKey;
  String? kakaoNonce;
  String? appleNonce;
  String? checkedUserId;
  Object? googleError;
  Object? talkError;
  Object? appleError;
  Object? stateError;
  Object? signOutError;
  SocialCredential credential = _credential;
  SocialCredential appleCredential = _appleCredential;
  AppleCredentialStatus appleState = AppleCredentialStatus.authorized;
  Completer<SocialCredential>? googlePending;

  @override
  Future<void> initializeGoogle({
    required String serverClientId,
    String? iosClientId,
  }) async {
    googleInitializations++;
    this.serverClientId = serverClientId;
    this.iosClientId = iosClientId;
  }

  @override
  Future<SocialCredential> authenticateGoogle() async {
    googleLogins++;
    if (googleError != null) throw googleError!;
    return googlePending == null ? credential : await googlePending!.future;
  }

  @override
  Future<void> signOutGoogle() async {
    googleSignOuts++;
    if (signOutError != null) throw signOutError!;
  }

  @override
  Future<void> initializeKakao(String nativeAppKey) async {
    kakaoInitializations++;
    kakaoKey = nativeAppKey;
  }

  @override
  Future<bool> isKakaoTalkInstalled() async => talkInstalled;
  @override
  Future<SocialCredential> authenticateKakaoTalk({String? nonce}) async {
    talkLogins++;
    kakaoNonce = nonce;
    if (talkError != null) throw talkError!;
    return credential;
  }

  @override
  Future<SocialCredential> authenticateKakaoAccount({String? nonce}) async {
    accountLogins++;
    kakaoNonce = nonce;
    return credential;
  }

  @override
  Future<void> clearKakaoTokens() async {
    kakaoClears++;
  }

  @override
  Future<SocialCredential> authenticateApple({required String nonce}) async {
    appleLogins++;
    appleNonce = nonce;
    if (appleError != null) throw appleError!;
    return appleCredential;
  }

  @override
  Future<AppleCredentialStatus> appleCredentialState(String userId) async {
    stateChecks++;
    checkedUserId = userId;
    if (stateError != null) throw stateError!;
    return appleState;
  }

  @override
  Future<bool> hasIosUrlScheme(String scheme) async {
    checkedSchemes.add(scheme);
    return hasScheme;
  }

  @override
  Stream<void> get appleCredentialRevocations => revocations.stream;
}
