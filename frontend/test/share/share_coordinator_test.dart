import 'dart:async';
import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/app/actions/share_coordinator.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/data/repositories/share_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const tokens = ApiSession(
  accessToken: 'fixture-access',
  refreshToken: 'fixture-refresh',
  expiresIn: 60,
  refreshExpiresIn: 600,
);
const channel = MethodChannel('com.huturu.app/share');

class TestApi extends ClipbackApi {
  int mints = 0;
  Future<ApiShareCredential> Function()? mint;
  @override
  Future<ApiShareCredential> createShareCredential() {
    mints++;
    return mint?.call() ?? Future.value(credential());
  }
}

ApiShareCredential credential() => ApiShareCredential(
  token: 'share-only',
  expiresAt: DateTime.utc(2099),
  userId: 7,
  sessionId: 11,
);

class TestSession extends SessionRepository {
  bool changing = false;
  bool active = true;
  @override
  bool get hasSession => active;
  @override
  bool get authenticationBusy => changing;
  @override
  bool get pendingSessionClear => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestUsers extends UserRepository {
  int generation = 0;
  @override
  int get accountVersion => generation;
  @override
  ApiUser get user => ApiUser(
    id: 7,
    email: null,
    displayName: 'test',
    isGuest: true,
    createdAt: DateTime.utc(2026),
    linkedProviders: [],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestActions extends ContentActions {
  TestActions(super.content, super.users, super.session);
  int refreshes = 0;
  bool successful = true;
  Completer<bool>? waiting;
  @override
  Future<bool> refreshExternal() async {
    refreshes++;
    return await waiting?.future ?? successful;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestApi api;
  late TestSession session;
  late TestUsers users;
  late TestActions actions;
  late RemoteContentRepository content;
  late ShareCoordinator model;
  late List<MethodCall> calls;
  late List<Map<String, Object?>> drafts, receipts;
  var revision = 0, disposed = false, failBlock = false;
  setUp(() {
    calls = [];
    drafts = [];
    receipts = [];
    revision = 0;
    disposed = false;
    failBlock = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getState':
              return {
                'revision': revision,
                'drafts': drafts,
                'receipts': receipts,
              };
            case 'blockCredential':
              if (failBlock) throw PlatformException(code: 'storage');
              return ++revision;
            case 'publishCredential':
              return (call.arguments as Map)['revision'] == revision;
            case 'acknowledgeReceipts':
              receipts = [];
              return null;
            case 'presentDraft':
              drafts = [];
              return null;
            default:
              throw StateError(call.method);
          }
        });
    api = TestApi()..restoreSession(tokens);
    session = TestSession();
    users = TestUsers();
    content = RemoteContentRepository(api);
    actions = TestActions(content, users, session);
    model = ShareCoordinator(
      shares: ShareRepository(api, NativeShareService(enabled: true)),
      session: session,
      users: users,
      contentActions: actions,
      canPrepare: () => true,
    );
  });
  tearDown(() {
    if (!disposed) model.dispose();
    actions.dispose();
    content.dispose();
    users.dispose();
    session.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('publishes only share credential with native revision', () async {
    revision = 41;
    await model.prepare();
    final args =
        calls.singleWhere((c) => c.method == 'publishCredential').arguments
            as Map;
    expect(args['revision'], 41);
    expect(args['token'], 'share-only');
    expect(args.values, isNot(contains('fixture-access')));
    expect(args.values, isNot(contains('fixture-refresh')));
    expect(model.ready, isTrue);
  });
  for (final sameEnvironment in [true, false]) {
    test(
      'newer native credential reuse checks environment: $sameEnvironment',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              if (call.method == 'getState') {
                return {
                  'revision': revision,
                  'credential': {
                    'userId': 7,
                    'sessionId': 11,
                    'expiresAt': DateTime.utc(2100).toIso8601String(),
                    'apiBaseUrl': sameEnvironment
                        ? '${api.baseUrl}/'
                        : 'https://other.example/api/v1',
                  },
                  'drafts': [],
                  'receipts': [],
                };
              }
              if (call.method == 'publishCredential') return false;
              if (call.method == 'blockCredential') return ++revision;
              throw StateError(call.method);
            });
        await model.prepare();
        expect(model.ready, sameEnvironment);
        expect(model.error, sameEnvironment ? isNull : isNotNull);
        expect(api.session, same(tokens));
        expect(
          calls.where((call) => call.method == 'blockCredential'),
          hasLength(sameEnvironment ? 0 : 1),
        );
      },
    );
  }
  test('preparation is shared and settled notifications do not loop', () async {
    final waiting = Completer<ApiShareCredential>();
    api.mint = () => waiting.future;
    final first = model.prepare();
    expect(identical(first, model.prepare()), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(api.mints, 1);
    waiting.complete(credential());
    await first;
    model.sessionSettled();
    await Future<void>.delayed(Duration.zero);
    expect(api.mints, 1);
  });
  test(
    'barrier ignores late mint and cancelled auth can restore original session',
    () async {
      final waiting = Completer<ApiShareCredential>();
      api.mint = () => waiting.future;
      final first = model.prepare();
      await Future<void>.delayed(Duration.zero);
      session.changing = true;
      await model.blockForSessionChange();
      waiting.complete(credential());
      await first;
      expect(calls.where((c) => c.method == 'publishCredential'), isEmpty);
      expect(model.ready, isFalse);
      session.changing = false;
      api.mint = null;
      await model.prepare();
      expect(model.ready, isTrue);
      expect(
        (calls.lastWhere((c) => c.method == 'publishCredential').arguments
            as Map)['revision'],
        1,
      );
    },
  );
  test('block persistence failure propagates and can be retried', () async {
    failBlock = true;
    await expectLater(
      model.blockForSessionChange(),
      throwsA(isA<PlatformException>()),
    );
    expect(model.ready, isFalse);
    expect(model.error, contains('계정 변경'));
    failBlock = false;
    await model.blockForSessionChange();
    expect(revision, 1);
  });
  test('mint failure preserves login and only retries explicitly', () async {
    api.mint = () async => throw const ClipbackApiException('offline');
    await model.prepare();
    model.sessionSettled();
    await Future<void>.delayed(Duration.zero);
    expect(session.hasSession, isTrue);
    expect(api.mints, 1);
    expect(model.error, isNotNull);
    api.mint = null;
    await model.resume();
    expect(model.ready, isTrue);
  });
  test(
    'unreadable native credential retries through a durable block without losing drafts',
    () async {
      var unreadable = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'getState') {
              if (unreadable) throw PlatformException(code: 'share_storage');
              return {
                'revision': revision,
                'drafts': [
                  {'id': 'kept', 'label': '공유한 이미지'},
                ],
                'receipts': [],
              };
            }
            if (call.method == 'blockCredential') {
              unreadable = false;
              return ++revision;
            }
            if (call.method == 'publishCredential') return true;
            throw StateError(call.method);
          });
      await model.prepare();
      expect(model.error, isNotNull);
      expect(api.mints, 0);
      expect(session.hasSession, isTrue);
      await model.retry();
      expect(model.error, isNull);
      expect(model.ready, isTrue);
      expect(model.drafts.single.id, 'kept');
      expect(api.session, same(tokens));
      expect(
        calls.where((call) => call.method == 'blockCredential'),
        hasLength(1),
      );
    },
  );
  test(
    'receipt failure after token refresh still prepares the new token',
    () async {
      receipts = [
        {'id': 'saved', 'userId': 7},
      ];
      actions.waiting = Completer<bool>();
      final first = model.prepare();
      while (actions.refreshes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      api.restoreSession(
        const ApiSession(
          accessToken: 'refreshed',
          refreshToken: 'rotated',
          expiresIn: 60,
          refreshExpiresIn: 600,
        ),
      );
      actions.waiting!.complete(false);
      await first;
      while (model.busy || api.mints < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(api.mints, 2);
      expect(model.ready, isTrue);
      expect(model.error, contains('최신 정보'));
      expect(calls.where((c) => c.method == 'acknowledgeReceipts'), isEmpty);
      model.sessionSettled();
      await Future<void>.delayed(Duration.zero);
      expect(api.mints, 2);
    },
  );
  test(
    'same-user receipts acknowledged only after successful refresh',
    () async {
      receipts = [
        {'id': 'same', 'userId': 7},
        {'id': 'other', 'userId': 8},
      ];
      drafts = [
        {'id': 'unbound', 'label': 'link'},
        {'id': 'same', 'label': 'image', 'userId': 7},
        {'id': 'other', 'label': 'private', 'userId': 8},
      ];
      actions.successful = false;
      await model.prepare();
      expect(calls.where((c) => c.method == 'acknowledgeReceipts'), isEmpty);
      expect(model.drafts.map((d) => d.id), ['unbound', 'same']);
      expect(model.error, contains('최신 정보'));
      actions.successful = true;
      await model.resume();
      expect(
        (calls.singleWhere((c) => c.method == 'acknowledgeReceipts').arguments
            as Map)['ids'],
        ['same'],
      );
    },
  );
  test('account switch while refreshing does not consume receipt', () async {
    receipts = [
      {'id': 'same', 'userId': 7},
    ];
    actions.waiting = Completer<bool>();
    final first = model.prepare();
    await Future<void>.delayed(Duration.zero);
    expect(actions.refreshes, 1);
    session.changing = true;
    await model.blockForSessionChange();
    users.generation++;
    actions.waiting!.complete(true);
    await first;
    expect(calls.where((c) => c.method == 'acknowledgeReceipts'), isEmpty);
  });
  test('dispose prevents late publication or effects', () async {
    final waiting = Completer<ApiShareCredential>();
    api.mint = () => waiting.future;
    final first = model.prepare();
    await Future<void>.delayed(Duration.zero);
    model.dispose();
    disposed = true;
    waiting.complete(credential());
    await first;
    expect(calls.where((c) => c.method == 'publishCredential'), isEmpty);
    expect(model.drainEffects(), isEmpty);
  });
  test(
    'recovery uses native ID and produces no save navigation effect',
    () async {
      drafts = [
        {'id': 'pending', 'label': 'link'},
      ];
      await model.prepare();
      await model.present(model.drafts.single);
      expect(
        (calls.singleWhere((c) => c.method == 'presentDraft').arguments as Map),
        {'id': 'pending'},
      );
      expect(model.drainEffects(), isEmpty);
      expect(model.drafts, isEmpty);
    },
  );
  test(
    'dispose also prevents a delayed invalidation from blocking native credentials',
    () async {
      model.dispose();
      disposed = true;
      await model.blockForSessionChange();
      expect(calls, isEmpty);
    },
  );

  test(
    'a missing mobile channel is a retryable error, not a successful block',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw MissingPluginException('unregistered channel'),
          );
      await expectLater(
        model.blockForSessionChange(),
        throwsA(isA<MissingPluginException>()),
      );
      expect(model.shares.supported, isTrue);
      expect(model.ready, isFalse);
    },
  );

  test('refresh during mint prepares again for the newer main token', () async {
    final waiting = Completer<ApiShareCredential>();
    api.mint = () => waiting.future;
    final first = model.prepare();
    await Future<void>.delayed(Duration.zero);
    api.restoreSession(
      const ApiSession(
        accessToken: 'refreshed',
        refreshToken: 'rotated',
        expiresIn: 60,
        refreshExpiresIn: 600,
      ),
    );
    api.mint = null;
    waiting.complete(credential());
    await first;
    for (var turn = 0; turn < 5; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(api.mints, 2);
    expect(model.ready, isTrue);
  });
  test(
    'a late platform publication result cannot mark a blocked account ready',
    () async {
      final publishing = Completer<void>();
      final published = Completer<bool>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'getState') {
              return {'revision': revision, 'drafts': [], 'receipts': []};
            }
            if (call.method == 'blockCredential') return ++revision;
            if (call.method == 'publishCredential') {
              publishing.complete();
              return published.future;
            }
            return null;
          });
      final first = model.prepare();
      await publishing.future;
      session.changing = true;
      await model.blockForSessionChange();
      published.complete(true);
      await first;
      expect(model.ready, isFalse);
      expect(model.drafts, isEmpty);
    },
  );

  test(
    'failed native block can retry even after main session was invalidated',
    () async {
      failBlock = true;
      await expectLater(
        model.blockForSessionChange(),
        throwsA(isA<PlatformException>()),
      );
      session.active = false;
      await model.resume();
      expect(model.error, isNotNull);
      expect(api.mints, 0);
      failBlock = false;
      await model.retry();
      expect(model.error, isNull);
      expect(revision, 1);
      expect(api.mints, 0);
      expect(model.ready, isFalse);
    },
  );
}
