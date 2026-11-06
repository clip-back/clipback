// #257 with the real session storage on the preferences channel: a failed
// save or clear changes shared_preferences' in-process cache before the
// device, so a read in the same run is not what the next launch reads.

import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionKey = 'flutter.clipback.session';
const _cleanupPrefix = 'flutter.clipback.account_deletion_cleanup.v1.';

/// The device side of the preferences channel; saving or removing the stored
/// session can be made to fail there.
class _Device {
  final data = <String, Object>{};
  bool failSessionSave = false, failSessionRemove = false;

  /// Starts a launch: shared_preferences loads its cache from the device.
  void launch() {
    SharedPreferences.resetStatic();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            final arguments = call.arguments as Map?;
            final key = arguments?['key'];
            switch (call.method) {
              case 'getAll':
              case 'getAllWithParameters':
                return Map<String, Object>.of(data);
              case 'setString':
                if (failSessionSave && key == _sessionKey) return false;
                data[key as String] = arguments!['value'] as Object;
                return true;
              case 'remove':
                if (failSessionRemove && key == _sessionKey) return false;
                data.remove(key);
                return true;
            }
            throw MissingPluginException(call.method);
          },
        );
  }

  String? get storedRefresh => switch (data[_sessionKey]) {
    final String value => (jsonDecode(value) as Map)['refresh_token'] as String,
    _ => null,
  };

  Iterable<String> get cleanupKeys =>
      data.keys.where((key) => key.startsWith(_cleanupPrefix));
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

ApiSession _session(String name) => ApiSession(
  accessToken: name,
  refreshToken: '$name-refresh',
  expiresIn: 60,
  refreshExpiresIn: 600,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Device device;
  late ClipbackApi api;
  late RemoteSessionRepository repository;

  setUp(() async {
    device = _Device()
      ..data[_sessionKey] = jsonEncode({
        'access_token': 'older',
        'refresh_token': 'older-refresh',
        'expires_in': 60,
        'refresh_expires_in': 600,
      })
      ..launch();
    api = ClipbackApi(client: MockClient((_) async => http.Response('', 500)));
    repository = RemoteSessionRepository(
      api: api,
      storage: ApiSessionStorage(),
      socialAuth: _Social(),
    );
    addTearDown(repository.dispose);
    expect(await repository.restoreStoredSession(), isTrue);
  });

  // Same as a refresh: the new tokens are in memory and then persisted.
  Future<void> refresh(String name, {required bool saved}) async {
    device.failSessionSave = !saved;
    api.restoreSession(_session(name));
    await repository.persistCurrentSession();
    device.failSessionSave = false;
  }

  /// Withdrawal whose stored session clear fails, then the next launch.
  Future<bool> withdrawThenRelaunch([RemoteSessionRepository? from]) async {
    device.failSessionRemove = true;
    await (from ?? repository).clearAfterAccountDeletion(userId: 7);
    device
      ..failSessionRemove = false
      ..launch();
    final next = RemoteSessionRepository(
      api: ClipbackApi(client: MockClient((_) async => http.Response('', 500))),
      storage: ApiSessionStorage(),
      socialAuth: _Social(),
    );
    addTearDown(next.dispose);
    await next.resumeAccountDeletionCleanup();
    return next.restoreStoredSession();
  }

  test(
    'a refreshed token that was never saved does not hide the older token on disk',
    () async {
      await refresh('rotated', saved: false);
      expect(device.storedRefresh, 'older-refresh');
      expect(
        (await ApiSessionStorage().read())?.refreshToken,
        'rotated-refresh',
      );

      expect(await withdrawThenRelaunch(), isFalse);
      expect(device.storedRefresh, isNull);
      expect(device.cleanupKeys, isEmpty);
    },
  );

  test(
    'a token saved earlier in the run and still on disk is cleared on the next launch',
    () async {
      await refresh('first', saved: true);
      await refresh('second', saved: false);
      expect(device.storedRefresh, 'first-refresh');

      expect(await withdrawThenRelaunch(), isFalse);
      expect(device.storedRefresh, isNull);
      expect(device.cleanupKeys, isEmpty);
    },
  );

  // The app always reads the stored session at launch first; this run did
  // not, so a read after its failed save shows the cache, not the device.
  test(
    'a read after a failed save does not make the login list complete',
    () async {
      final otherApi = ClipbackApi(
        client: MockClient((_) async => http.Response('', 500)),
      );
      final unread = RemoteSessionRepository(
        api: otherApi,
        storage: ApiSessionStorage(),
        socialAuth: _Social(),
      );
      addTearDown(unread.dispose);
      device.failSessionSave = true;
      otherApi.restoreSession(_session('rotated'));
      await unread.persistCurrentSession();
      device.failSessionSave = false;

      expect(await withdrawThenRelaunch(unread), isTrue);
      // The older token is unknown to the record: neither cleared nor
      // taken as a newer login, so the step stays for a later launch.
      expect(device.storedRefresh, 'older-refresh');
      expect(device.cleanupKeys, hasLength(1));
    },
  );
}
