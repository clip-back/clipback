// Local HTTP fixture entrypoint for native sharing. No production HTTP fallback.
// Use CLIPBACK_API_BASE_URL=http://127.0.0.1:18765/api/v1 on iOS and
// http://10.0.2.2:18765/api/v1 on Android. Run tool/share_fixture_server.py first.
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';

void main() {
  const base = String.fromEnvironment('CLIPBACK_API_BASE_URL');
  final uri = Uri.parse(base);
  if (!['127.0.0.1', '10.0.2.2'].contains(uri.host)) {
    throw StateError('Share preview requires an explicit local fixture API');
  }
  runApp(ClipbackApp(sessionStorage: _Storage(), socialAuth: _Social()));
}

class _Storage extends ApiSessionStorage {
  ApiSession? session =
      (const bool.fromEnvironment('SHARE_PREVIEW_SIGNED_OUT') ||
          const bool.fromEnvironment('SHARE_PREVIEW_REAL_BACKEND'))
      ? null
      : const ApiSession(
          accessToken: 'local-share-fixture-access',
          refreshToken: 'local-share-fixture-refresh',
          expiresIn: 3600,
          refreshExpiresIn: 86400,
        );
  @override
  Future<ApiSession?> read() async => session;
  @override
  Future<void> write(ApiSession value) async => session = value;
  @override
  Future<void> clear() async => session = null;
}

class _Social extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders => const [];
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
