// #257 root app: device cleanup after a confirmed withdrawal (204) and the
// next-launch retry of what R2 names, on an in-memory API and device stores.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/app_view_model.dart';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:clipback_frontend/data/services/search_history_storage.dart';
import 'package:clipback_frontend/features/account/account_deleted_screen.dart';
import 'package:clipback_frontend/features/account/account_deletion_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/logout_alignment_fixture.dart' as fixture;
import 'support/account_preview.dart' as account;
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;

const _cleanupKey = 'clipback.account_deletion_cleanup.v1';
const _shareChannel = MethodChannel('com.huturu.app/share');
// The fixture account is user 1; user 2 is another account on this device.
const _deletedUser = 1, _otherUser = 2;
final _environment = ClipbackApi().baseUrl;

class _Server {
  _Server() : base = account.AccountServer('member');
  final account.AccountServer base;
  List<String>? providers;
  int deleteStatus = 204, deleteCalls = 0, requests = 0;
  bool deleted = false;

  late final client = MockClient((r) async {
    requests++;
    if (deleted) return base.json({'detail': 'Not authenticated'}, 401);
    if (r.method == 'DELETE' && r.url.path == '/api/v1/users/me') {
      deleteCalls++;
      if (deleteStatus != 204) {
        return base.json({'detail': 'unavailable'}, deleteStatus);
      }
      deleted = true;
      return http.Response('', 204);
    }
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    final response = await base.client
        .send(copy)
        .then(http.Response.fromStream);
    final linked = providers;
    if (linked == null || r.url.path != '/api/v1/users/me') return response;
    final user = jsonDecode(response.body) as Map<String, dynamic>;
    return base.json({...user, 'linked_providers': linked});
  });
}

class _History implements SearchHistoryStorage {
  final values = <(String, int), List<String>>{
    (_environment, _deletedUser): ['탈퇴 계정 검색'],
    (_environment, _otherUser): ['다른 계정 검색'],
  };
  final clears = <(String, int)>[];
  bool failClear = false;

  @override
  Future<List<String>> read(String environment, int userId) async =>
      List.of(values[(environment, userId)] ?? const <String>[]);

  @override
  Future<void> write(String environment, int userId, List<String> terms) async {
    values[(environment, userId)] = List.of(terms);
  }

  @override
  Future<void> clear(String environment, int userId) async {
    clears.add((environment, userId));
    if (failClear) throw StateError('Fixture history clear failure');
    values.remove((environment, userId));
  }
}

class _Shares {
  final drafts = <Map<String, Object?>>[];
  final discarded = <Object?>[];
  bool failDiscard = false;
  int revision = 0;

  void addDrafts() => drafts.addAll([
    {'id': 'own', 'label': '탈퇴 계정 공유', 'userId': _deletedUser},
    {'id': 'unassigned', 'label': '계정 번호 없는 공유'},
    {'id': 'other', 'label': '다른 계정 공유', 'userId': _otherUser},
  ]);

  List<Object?> get ids => [for (final d in drafts) d['id']];

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getState':
        return {
          'revision': revision,
          'drafts': [for (final d in drafts) Map.of(d)],
          'receipts': <Object>[],
        };
      case 'blockCredential':
        return ++revision;
      case 'publishCredential':
        return true;
      case 'discardAccountDrafts':
        final userId = (call.arguments as Map)['userId'];
        discarded.add(userId);
        if (failDiscard) throw PlatformException(code: 'share_storage');
        drafts.removeWhere((d) => d['userId'] == userId);
        return null;
      case 'presentDraft':
      case 'acknowledgeReceipts':
        return null;
    }
    throw StateError('Unexpected share method ${call.method}');
  }
}

class _Social extends isolated.ArchiveAllSocialAuth {
  int signOuts = 0, disconnects = 0, appleClears = 0;
  bool failAppleClear = false;
  Object? disconnectError;
  Completer<void>? disconnectGate;

  @override
  Future<void> signOut([SocialLoginProvider? provider]) async => signOuts++;

  @override
  Future<void> rememberAppleUserId(String? userId) async {
    if (userId != null) return;
    appleClears++;
    if (failAppleClear) throw StateError('Fixture Apple user ID failure');
  }

  @override
  Future<void> disconnectGoogle() async {
    disconnects++;
    await disconnectGate?.future;
    if (disconnectError != null) throw disconnectError!;
  }
}

class _Device {
  final server = _Server();
  final storage = fixture.LogoutMemoryStorage();
  final social = _Social();
  final history = _History();
  final shares = _Shares();
}

Finder get _j04 => find.byType(AccountDeletionScreen);
Finder get _j06 => find.byType(AccountDeletedScreen);
Finder get _failure => find.text(accountDeletionFailureMessage);

Future<List<Object?>?> _record() async {
  final value = (await SharedPreferences.getInstance()).getString(_cleanupKey);
  return value == null ? null : jsonDecode(value) as List<Object?>;
}

Future<void> _launch(WidgetTester tester, _Device device) async {
  await tester.pumpWidget(
    ClipbackApp(
      key: UniqueKey(),
      sessionStorage: device.storage,
      socialAuth: device.social,
      searchHistoryStorage: device.history,
      nativeShare: NativeShareService(enabled: true),
    ),
  );
  await completeAppStartup(tester);
}

/// Launches as the member, opens J04, adds pending shares and submits.
Future<void> _withdraw(
  WidgetTester tester,
  _Device device, {
  bool settle = true,
}) async {
  await _launch(tester, device);
  await tester.tap(
    find.descendant(
      of: find.byType(ClipbackNavigationBar),
      matching: find.text('마이'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(MyProfileRow));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('회원 탈퇴'));
  await tester.tap(find.text('회원 탈퇴'));
  await tester.pumpAndSettle();
  expect(_j04, findsOneWidget);
  // Shares saved by this device's accounts, added after the share
  // coordinator has prepared so no pending-share prompt covers the flow.
  device.shares.addDrafts();
  final reason = find.byKey(const ValueKey('account-deletion-reason-기타'));
  await tester.ensureVisible(reason);
  await tester.tap(reason);
  await tester.pump();
  final submit = find.byKey(const ValueKey('account-deletion-submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  if (settle) await tester.pumpAndSettle();
}

Future<void> _run(
  WidgetTester tester,
  Future<void> Function(_Device device) body, {
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final device = _Device();
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 812);
  addTearDown(tester.view.reset);
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_shareChannel, device.shares.handle);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null),
  );
  await http.runWithClient(() async {
    try {
      await body(device);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    }
  }, () => device.server.client);
}

void _expectJ06WithoutRetry(WidgetTester tester, _Device device) {
  expect(_j06, findsOneWidget);
  expect(_failure, findsNothing);
  expect(device.server.deleteCalls, 1);
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '${platform.name} 204 removes this account\'s search history and pending shares only',
      (tester) async {
        await _run(tester, (device) async {
          await _withdraw(tester, device);
          _expectJ06WithoutRetry(tester, device);
          expect(device.history.values.keys, [(_environment, _otherUser)]);
          expect(device.shares.discarded, [_deletedUser]);
          expect(device.shares.ids, ['unassigned', 'other']);
          expect(device.storage.value, isNull);
          expect(device.social.appleClears, 1);
          // Kakao + Apple member: logout's SDK cleanup, no Google disconnect.
          expect(device.social.signOuts, 1);
          expect(device.social.disconnects, 0);
          expect(await _record(), isNull);
        }, platform: platform);
      },
    );
  }

  testWidgets(
    'Google disconnect failure does not hold J06 and is not retried',
    (tester) async {
      await _run(tester, (device) async {
        device.server.providers = ['google'];
        device.social.disconnectError = StateError(
          'Fixture disconnect failure',
        );
        await _withdraw(tester, device);
        _expectJ06WithoutRetry(tester, device);
        expect(device.social.disconnects, 1);
        expect(device.social.signOuts, 1);
        await _launch(tester, device);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(device.social.disconnects, 1);
        expect(device.social.signOuts, 1);
      });
    },
  );

  testWidgets(
    'a Google disconnect over 5 seconds is left behind and J06 follows',
    (tester) async {
      await _run(tester, (device) async {
        device.server.providers = ['google'];
        device.social.disconnectGate = Completer();
        await _withdraw(tester, device, settle: false);
        await tester.pump(const Duration(milliseconds: 4900));
        expect(device.social.disconnects, 1);
        expect(_j06, findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        _expectJ06WithoutRetry(tester, device);
        expect(device.social.signOuts, 1);
        expect(device.shares.discarded, [_deletedUser]);
        expect(await _record(), isNull);
        await _launch(tester, device);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(device.social.disconnects, 1);
      });
    },
  );

  final failures = <String, (String, void Function(_Device, bool))>{
    'stored session': ('storedLogin', (d, fail) => d.storage.failClear = fail),
    'Apple user ID': (
      'storedLogin',
      (d, fail) => d.social.failAppleClear = fail,
    ),
    'search history': (
      'searchHistory',
      (d, fail) => d.history.failClear = fail,
    ),
    'pending shares': (
      'pendingShares',
      (d, fail) => d.shares.failDiscard = fail,
    ),
  };
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final MapEntry(key: target, value: (step, fail)) in failures.entries) {
      testWidgets(
        '${platform.name} $target cleanup failure after 204 still shows J06 '
        'and the next launch finishes it before restoring, without requests',
        (tester) async {
          await _run(tester, (device) async {
            fail(device, true);
            await _withdraw(tester, device);
            _expectJ06WithoutRetry(tester, device);
            // Every other cleanup was still tried once.
            expect(device.shares.discarded, [_deletedUser]);
            expect(device.history.clears, [(_environment, _deletedUser)]);
            expect(device.social.appleClears, 1);
            expect(device.storage.clears, 1);
            expect(await _record(), [
              {
                'environment': _environment,
                'user_id': _deletedUser,
                'remaining': [step],
              },
            ]);

            // The app is closed on J06 and opened again.
            fail(device, false);
            final requests = device.server.requests;
            final signOuts = device.social.signOuts;
            await _launch(tester, device);
            expect(find.byType(LoginScreen), findsOneWidget);
            expect(_j06, findsNothing);
            expect(_failure, findsNothing);
            expect(device.server.requests, requests);
            expect(device.server.deleteCalls, 1);
            expect(await _record(), isNull);
            expect(device.storage.value, isNull);
            expect(device.history.values.keys, [(_environment, _otherUser)]);
            expect(device.shares.ids, ['unassigned', 'other']);
            // One-time cleanup is not repeated on the next launch.
            expect(device.social.signOuts, signOuts);
            expect(device.social.disconnects, 0);
            expect(tester.takeException(), isNull);
          }, platform: platform);
        },
      );
    }
  }

  testWidgets('a 503 withdrawal keeps the session, search history and shares', (
    tester,
  ) async {
    await _run(tester, (device) async {
      device.server.deleteStatus = 503;
      await _withdraw(tester, device);
      expect(_j04, findsOneWidget);
      expect(_j06, findsNothing);
      expect(_failure, findsOneWidget);
      expect(device.storage.value, isNotNull);
      expect(device.storage.clears, 0);
      expect(device.history.values.keys, [
        (_environment, _deletedUser),
        (_environment, _otherUser),
      ]);
      expect(device.history.clears, isEmpty);
      expect(device.shares.discarded, isEmpty);
      expect(device.shares.ids, ['own', 'unassigned', 'other']);
      expect(device.social.appleClears, 0);
      expect(device.social.signOuts, 0);
      expect(await _record(), isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
