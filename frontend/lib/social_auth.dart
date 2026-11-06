import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' as google;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;

enum SocialLoginProvider { google, kakao, apple }

enum AppleCredentialStatus {
  authorized,
  revoked,
  notFound,
  transferred,
  unavailable,
}

class SocialCredential {
  const SocialCredential({
    required this.token,
    this.authorizationCode,
    this.displayName,
    this.providerUserId,
  });

  final String token;
  final String? authorizationCode;
  final String? displayName;
  final String? providerUserId;
}

class SocialAuthException implements Exception {
  const SocialAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class SocialAuth {
  List<SocialLoginProvider> get supportedProviders;
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  });
  Future<void> signOut([SocialLoginProvider? provider]);

  /// [signOut] without clearing the stored Apple user ID: after a withdrawal
  /// only the stored-login cleanup clears it, once it has identified the
  /// stored login (#257). Defaults to [signOut] for an implementation that
  /// stores no Apple user ID.
  Future<void> signOutSdks([SocialLoginProvider? provider]) =>
      signOut(provider);
  Future<void> rememberAppleUserId(String? userId);
  Future<AppleCredentialStatus> appleCredentialState();
  Stream<void> get appleCredentialRevocations => const Stream<void>.empty();

  /// Revokes this app's Google authorization on the device (D6).
  Future<void> disconnectGoogle() async {}
}

class SocialAuthConfig {
  const SocialAuthConfig({
    this.googleServerClientId = const String.fromEnvironment(
      'CLIPBACK_GOOGLE_SERVER_CLIENT_ID',
    ),
    this.googleIosClientId = const String.fromEnvironment(
      'CLIPBACK_GOOGLE_IOS_CLIENT_ID',
    ),
    this.kakaoNativeAppKey = const String.fromEnvironment(
      'CLIPBACK_KAKAO_NATIVE_APP_KEY',
    ),
  });

  final String googleServerClientId;
  final String googleIosClientId;
  final String kakaoNativeAppKey;
}

/// The SDK boundary keeps cancellation and fallback tests independent of accounts.
abstract interface class SocialAuthSdk {
  Future<void> initializeGoogle({
    required String serverClientId,
    String? iosClientId,
  });
  Future<SocialCredential> authenticateGoogle();
  Future<void> signOutGoogle();
  Future<void> disconnectGoogle();
  Future<void> initializeKakao(String nativeAppKey);
  Future<bool> isKakaoTalkInstalled();
  Future<SocialCredential> authenticateKakaoTalk({String? nonce});
  Future<SocialCredential> authenticateKakaoAccount({String? nonce});
  Future<void> clearKakaoTokens();
  Future<SocialCredential> authenticateApple({required String nonce});
  Future<AppleCredentialStatus> appleCredentialState(String userId);
  Future<bool> hasIosUrlScheme(String scheme);
  Stream<void> get appleCredentialRevocations;
}

class PlatformSocialAuth extends SocialAuth {
  PlatformSocialAuth({
    SocialAuthSdk? sdk,
    SocialAuthConfig config = const SocialAuthConfig(),
    TargetPlatform? platform,
    bool? isWeb,
    Future<SharedPreferences> Function()? preferences,
  }) : _sdk = sdk ?? _NativeSocialAuthSdk.instance,
       _config = config,
       _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb,
       _preferences = preferences ?? SharedPreferences.getInstance;

  static const _appleUserIdKey = 'clipback.apple_user_id';
  final SocialAuthSdk _sdk;
  final SocialAuthConfig _config;
  final TargetPlatform _platform;
  final bool _isWeb;
  final Future<SharedPreferences> Function() _preferences;
  Future<void>? _googleInitialization;
  Future<void>? _kakaoInitialization;
  bool _authenticating = false;
  // Sign-ins started so far. Cleanup records it when it starts and skips an
  // SDK call it has not made yet once a newer sign-in started (#250 F1).
  int _signIns = 0;

  @override
  List<SocialLoginProvider> get supportedProviders {
    if (_isWeb) return const [];
    return switch (_platform) {
      TargetPlatform.android => const [
        SocialLoginProvider.google,
        SocialLoginProvider.kakao,
      ],
      TargetPlatform.iOS => const [
        SocialLoginProvider.google,
        SocialLoginProvider.kakao,
        SocialLoginProvider.apple,
      ],
      _ => const [],
    };
  }

  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async {
    if (!supportedProviders.contains(provider)) {
      throw const SocialAuthException('이 기기에서는 지원하지 않는 로그인이에요.');
    }
    if (_authenticating) {
      throw const SocialAuthException('로그인이 진행 중이에요. 잠시 기다려 주세요.');
    }
    _authenticating = true;
    _signIns++;
    try {
      final SocialCredential credential;
      switch (provider) {
        case SocialLoginProvider.google:
          await _initializeGoogle();
          credential = await _sdk.authenticateGoogle();
        case SocialLoginProvider.kakao:
          await _initializeKakao();
          credential = await _authenticateKakao(nonce: nonce);
        case SocialLoginProvider.apple:
          if (nonce == null || nonce.trim().isEmpty) {
            throw const SocialAuthException('로그인 요청을 다시 시작해 주세요.');
          }
          credential = await _sdk.authenticateApple(nonce: nonce);
          if (credential.authorizationCode?.isNotEmpty != true ||
              credential.providerUserId?.isNotEmpty != true) {
            throw const SocialAuthException(
              'Apple 로그인 정보를 받지 못했어요. 다시 시도해 주세요.',
            );
          }
      }
      if (credential.token.trim().isEmpty) {
        throw const SocialAuthException('로그인 인증 정보를 받지 못했어요. 로그인 설정을 확인해 주세요.');
      }
      return credential;
    } catch (error) {
      if (_isCancellation(error)) return null;
      if (error is SocialAuthException) rethrow;
      // SDK errors may contain tokens or account details. Never surface their text.
      throw const SocialAuthException('로그인을 완료하지 못했어요. 연결과 로그인 설정을 확인해 주세요.');
    } finally {
      _authenticating = false;
    }
  }

  Future<void> _initializeGoogle() async {
    if (_config.googleServerClientId.trim().isEmpty ||
        (_platform == TargetPlatform.iOS &&
            _config.googleIosClientId.trim().isEmpty)) {
      throw const SocialAuthException('Google 로그인 설정이 준비되지 않았어요.');
    }
    if (_platform == TargetPlatform.iOS) {
      final scheme = _config.googleIosClientId.split('.').reversed.join('.');
      await _requireIosUrlScheme(scheme, 'Google');
    }
    await (_googleInitialization ??= _sdk.initializeGoogle(
      serverClientId: _config.googleServerClientId,
      iosClientId: _platform == TargetPlatform.iOS
          ? _config.googleIosClientId
          : null,
    ));
  }

  Future<void> _initializeKakao() async {
    if (_config.kakaoNativeAppKey.trim().isEmpty) {
      throw const SocialAuthException('카카오 로그인 설정이 준비되지 않았어요.');
    }
    if (_platform == TargetPlatform.iOS) {
      await _requireIosUrlScheme('kakao${_config.kakaoNativeAppKey}', '카카오');
    }
    await (_kakaoInitialization ??= _sdk.initializeKakao(
      _config.kakaoNativeAppKey,
    ));
  }

  Future<void> _requireIosUrlScheme(String scheme, String provider) async {
    if (!await _sdk.hasIosUrlScheme(scheme)) {
      throw SocialAuthException('$provider 로그인 앱 설정이 일치하지 않아요.');
    }
  }

  Future<SocialCredential> _authenticateKakao({String? nonce}) async {
    if (await _sdk.isKakaoTalkInstalled()) {
      try {
        return await _sdk.authenticateKakaoTalk(nonce: nonce);
      } catch (error) {
        // Closing KakaoTalk or denying consent must not open a second login UI.
        if (_isCancellation(error)) rethrow;
      }
    }
    return _sdk.authenticateKakaoAccount(nonce: nonce);
  }

  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {
    var failed = false;
    try {
      await signOutSdks(provider);
    } catch (_) {
      failed = true;
    }
    try {
      await rememberAppleUserId(null);
    } catch (_) {
      failed = true;
    }
    if (failed) {
      throw const SocialAuthException('기기의 소셜 로그인 정보를 정리하지 못했어요.');
    }
  }

  @override
  Future<void> signOutSdks([SocialLoginProvider? provider]) async {
    final signIns = _signIns;
    // Providers run side by side: one SDK still initializing must not hold
    // another's cleanup until a newer sign-in may have started.
    final results = await Future.wait([
      if (supportedProviders.contains(SocialLoginProvider.google) &&
          (provider == null || provider == SocialLoginProvider.google) &&
          _config.googleServerClientId.isNotEmpty)
        _cleanUp(signIns, _initializeGoogle, _sdk.signOutGoogle),
      if (supportedProviders.contains(SocialLoginProvider.kakao) &&
          (provider == null || provider == SocialLoginProvider.kakao) &&
          _config.kakaoNativeAppKey.isNotEmpty)
        _cleanUp(signIns, _initializeKakao, _sdk.clearKakaoTokens),
    ]);
    if (results.contains(false)) {
      throw const SocialAuthException('기기의 소셜 로그인 정보를 정리하지 못했어요.');
    }
  }

  /// Initializes, then runs [clear] unless a sign-in started after [signIns]
  /// was taken; that sign-in owns the SDK now. False when a step failed.
  Future<bool> _cleanUp(
    int signIns,
    Future<void> Function() initialize,
    Future<void> Function() clear,
  ) async {
    try {
      await initialize();
      if (signIns == _signIns) await clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnectGoogle() async {
    if (!supportedProviders.contains(SocialLoginProvider.google) ||
        _config.googleServerClientId.isEmpty) {
      return;
    }
    final signIns = _signIns;
    await _initializeGoogle();
    if (signIns == _signIns) await _sdk.disconnectGoogle();
  }

  @override
  Future<void> rememberAppleUserId(String? userId) async {
    final preferences = await _preferences();
    final saved = userId == null
        ? await preferences.remove(_appleUserIdKey)
        : await preferences.setString(_appleUserIdKey, userId);
    if (!saved) {
      throw const SocialAuthException('Apple 로그인 확인 정보를 기기에 저장하지 못했어요.');
    }
  }

  @override
  Future<AppleCredentialStatus> appleCredentialState() async {
    if (!supportedProviders.contains(SocialLoginProvider.apple)) {
      return AppleCredentialStatus.unavailable;
    }
    try {
      final userId = (await _preferences()).getString(_appleUserIdKey);
      // Missing local metadata is not evidence that Apple revoked the account.
      if (userId == null || userId.isEmpty) {
        return AppleCredentialStatus.unavailable;
      }
      return await _sdk.appleCredentialState(userId);
    } catch (_) {
      return AppleCredentialStatus.unavailable;
    }
  }

  @override
  Stream<void> get appleCredentialRevocations =>
      supportedProviders.contains(SocialLoginProvider.apple)
      ? _sdk.appleCredentialRevocations
      : const Stream<void>.empty();

  static bool _isCancellation(Object error) =>
      (error is google.GoogleSignInException &&
          error.code == google.GoogleSignInExceptionCode.canceled) ||
      (error is kakao.KakaoClientException &&
          error.reason == kakao.ClientErrorCause.cancelled) ||
      (error is kakao.KakaoAuthException &&
          error.error == kakao.AuthErrorCause.accessDenied) ||
      (error is apple.SignInWithAppleAuthorizationException &&
          error.code == apple.AuthorizationErrorCode.canceled) ||
      (error is PlatformException &&
          const {
            'CANCELED',
            'CANCELLED',
            'canceled',
            'cancelled',
          }.contains(error.code));
}

class _NativeSocialAuthSdk implements SocialAuthSdk {
  static final instance = _NativeSocialAuthSdk();
  static const _configChannel = MethodChannel('clipback/social-auth-config');
  static const _revocationChannel = EventChannel(
    'clipback/apple-credential-revocations',
  );
  Future<void>? _googleInitialization;
  Future<void>? _kakaoInitialization;

  @override
  Future<void> initializeGoogle({
    required String serverClientId,
    String? iosClientId,
  }) => _googleInitialization ??= google.GoogleSignIn.instance.initialize(
    clientId: iosClientId,
    serverClientId: serverClientId,
  );

  @override
  Future<SocialCredential> authenticateGoogle() async {
    final account = await google.GoogleSignIn.instance.authenticate();
    return SocialCredential(
      token: account.authentication.idToken ?? '',
      displayName: account.displayName,
      providerUserId: account.id,
    );
  }

  @override
  Future<void> signOutGoogle() => google.GoogleSignIn.instance.signOut();

  @override
  Future<void> disconnectGoogle() => google.GoogleSignIn.instance.disconnect();

  @override
  Future<void> initializeKakao(String nativeAppKey) => _kakaoInitialization ??=
      kakao.KakaoSdk.init(nativeAppKey: nativeAppKey, loggingEnabled: false);

  @override
  Future<bool> isKakaoTalkInstalled() => kakao.isKakaoTalkInstalled();

  @override
  Future<SocialCredential> authenticateKakaoTalk({String? nonce}) async =>
      SocialCredential(
        token:
            (await kakao.UserApi.instance.loginWithKakaoTalk(
              nonce: nonce,
            )).idToken ??
            '',
      );

  @override
  Future<SocialCredential> authenticateKakaoAccount({String? nonce}) async =>
      SocialCredential(
        token:
            (await kakao.UserApi.instance.loginWithKakaoAccount(
              nonce: nonce,
            )).idToken ??
            '',
      );

  @override
  Future<void> clearKakaoTokens() =>
      kakao.TokenManagerProvider.instance.manager.clear();

  @override
  Future<SocialCredential> authenticateApple({required String nonce}) async {
    final credential = await apple.SignInWithApple.getAppleIDCredential(
      scopes: const [
        apple.AppleIDAuthorizationScopes.email,
        apple.AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    return SocialCredential(
      token: credential.identityToken ?? '',
      authorizationCode: credential.authorizationCode,
      displayName: name.isEmpty ? null : name,
      providerUserId: credential.userIdentifier,
    );
  }

  @override
  Future<AppleCredentialStatus> appleCredentialState(String userId) async =>
      switch (await apple.SignInWithApple.getCredentialState(userId)) {
        apple.CredentialState.authorized => AppleCredentialStatus.authorized,
        apple.CredentialState.revoked => AppleCredentialStatus.revoked,
        apple.CredentialState.notFound => AppleCredentialStatus.notFound,
      };

  @override
  Future<bool> hasIosUrlScheme(String scheme) async =>
      await _configChannel.invokeMethod<bool>('hasUrlScheme', scheme) ?? false;

  @override
  Stream<void> get appleCredentialRevocations =>
      _revocationChannel.receiveBroadcastStream().map<void>((_) {});
}
