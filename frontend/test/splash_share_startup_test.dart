import 'package:clipback_frontend/app/app_dependencies.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/login_alignment_preview.dart' as fixture;

const _session = ApiSession(
  accessToken: 'startup-access',
  refreshToken: 'startup-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _channel = MethodChannel('com.huturu.app/share');

Future<void> _turns() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final queued = <Map<String, Object?>>[
    {'id': 'queued-draft', 'label': '공유 대기 링크', 'userId': 1},
  ];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getState':
              return {'revision': 11, 'drafts': queued, 'receipts': []};
            case 'publishCredential':
              return true;
            case 'blockCredential':
              return 12;
            default:
              throw StateError('Unexpected native action: ${call.method}');
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test(
    'startup gate retains native queue and releases preparation once',
    () async {
      var ready = false;
      final server = fixture.LoginServer();
      final storage = fixture.LoginMemoryStorage()..value = _session;
      addTearDown(server.client.close);
      await http.runWithClient(() async {
        final dependencies = AppDependencies(
          storage: storage,
          socialAuth: fixture.LoginControlledSocial(TargetPlatform.android),
          nativeShare: NativeShareService(enabled: true),
          canPrepareSharing: () => ready,
        );
        addTearDown(dependencies.dispose);
        await dependencies.app.restoreSession();
        await dependencies.sharing.resume();
        await _turns();
        expect(dependencies.app.route, AppRoute.home);
        expect(calls, isEmpty);
        expect(
          server.requests.where(
            (r) => r['path'] == '/api/v1/auth/share-credential',
          ),
          isEmpty,
        );
        expect(queued.single['id'], 'queued-draft');
        ready = true;
        dependencies.sharing.sessionSettled();
        await _turns();
        expect(dependencies.sharing.ready, isTrue);
        expect(dependencies.sharing.drafts.single.id, 'queued-draft');
        expect(
          calls.where((c) => c.method == 'publishCredential'),
          hasLength(1),
        );
        expect(
          server.requests.where(
            (r) => r['path'] == '/api/v1/auth/share-credential',
          ),
          hasLength(1),
        );
        dependencies.sharing.sessionSettled();
        await _turns();
        expect(
          calls.where((c) => c.method == 'publishCredential'),
          hasLength(1),
        );
        expect(
          calls.where(
            (c) =>
                c.method == 'presentDraft' || c.method == 'acknowledgeReceipts',
          ),
          isEmpty,
        );
        expect(queued.single['id'], 'queued-draft');
      }, () => server.client);
    },
  );

  test('omitted startup gate retains dependency caller behavior', () async {
    final server = fixture.LoginServer();
    final storage = fixture.LoginMemoryStorage()..value = _session;
    addTearDown(server.client.close);
    await http.runWithClient(() async {
      final dependencies = AppDependencies(
        storage: storage,
        socialAuth: fixture.LoginControlledSocial(TargetPlatform.android),
        nativeShare: NativeShareService(enabled: true),
      );
      addTearDown(dependencies.dispose);
      await dependencies.app.restoreSession();
      await _turns();
      expect(dependencies.sharing.ready, isTrue);
      expect(calls.where((c) => c.method == 'publishCredential'), hasLength(1));
    }, () => server.client);
  });

  test(
    'security blocking and session clear run while preparation gate stays closed',
    () async {
      final server = fixture.LoginServer();
      final storage = fixture.LoginMemoryStorage()..value = _session;
      addTearDown(server.client.close);
      await http.runWithClient(() async {
        final dependencies = AppDependencies(
          storage: storage,
          socialAuth: fixture.LoginControlledSocial(TargetPlatform.android),
          nativeShare: NativeShareService(enabled: true),
          canPrepareSharing: () => false,
        );
        addTearDown(dependencies.dispose);
        await dependencies.app.restoreSession();
        await _turns();
        expect(calls, isEmpty);
        await dependencies.app.logout();
        await _turns();
        expect(calls.where((c) => c.method == 'blockCredential'), hasLength(1));
        expect(calls.where((c) => c.method != 'blockCredential'), isEmpty);
        expect(storage.clears, 1);
        expect(storage.value, isNull);
        expect(dependencies.app.route, AppRoute.login);
        expect(
          server.requests.where(
            (r) => r['path'] == '/api/v1/auth/share-credential',
          ),
          isEmpty,
        );
      }, () => server.client);
    },
  );
}
