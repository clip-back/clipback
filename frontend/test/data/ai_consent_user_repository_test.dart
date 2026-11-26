// #477: a profile read started before a consent save does not replace the
// saved choice (#474 overlap table, first two rows).
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _session = ApiSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _me(String status) => {
  'id': 1,
  'email': null,
  'display_name': '회원',
  'is_guest': false,
  'created_at': '2026-10-10T00:00:00Z',
  'linked_providers': ['google'],
  'ai_consent_status': status,
};

void main() {
  late List<Completer<http.Response>> reads;
  late Completer<http.Response> put;
  late RemoteUserRepository users;
  late ClipbackApi api;

  setUp(() {
    reads = [];
    put = Completer();
    api = ClipbackApi(
      client: MockClient((request) {
        if (request.url.path == '/api/v1/users/me/ai-consent') {
          return put.future;
        }
        if (request.url.path == '/api/v1/users/me/stats') {
          return Future.value(
            _json({
              'saved_count': 0,
              'reopened_count': 0,
              'recent_reopened_count': 0,
            }),
          );
        }
        final read = Completer<http.Response>();
        reads.add(read);
        return read.future;
      }),
    )..restoreSession(_session);
    users = RemoteUserRepository(api: api);
  });

  tearDown(() => users.dispose());

  Future<void> turns() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'an earlier read arriving during the save keeps the old choice',
    () async {
      final first = users.loadMe();
      await turns();
      reads.single.complete(_json(_me('undecided')));
      await first;
      final early = users.refresh(isCurrent: () => true);
      await turns();
      final save = users.saveAiConsent(AiConsentStatus.granted);
      await turns();
      // The earlier read answers "granted" while the PUT is pending: its
      // consent is not taken; the save decides.
      reads.last.complete(_json(_me('granted')));
      await early;
      expect(users.user!.aiConsentStatus, AiConsentStatus.undecided);
      put.complete(
        _json({
          'status': 'granted',
          'notice_version': 1,
          'decided_at': '2026-11-26T03:00:00Z',
        }),
      );
      expect(await save, isTrue);
      expect(users.user!.aiConsentStatus, AiConsentStatus.granted);
    },
  );

  test('an earlier read arriving after the save does not undo it', () async {
    final first = users.loadMe();
    await turns();
    reads.single.complete(_json(_me('undecided')));
    await first;
    final early = users.refreshInBackground(isCurrent: () => true);
    await turns();
    final save = users.saveAiConsent(AiConsentStatus.denied);
    put.complete(
      _json({
        'status': 'denied',
        'notice_version': 1,
        'decided_at': '2026-11-26T03:00:00Z',
      }),
    );
    expect(await save, isTrue);
    expect(users.user!.aiConsentStatus, AiConsentStatus.denied);
    reads.last.complete(_json({..._me('undecided'), 'display_name': '새 이름'}));
    await early;
    expect(users.user!.displayName, '새 이름', reason: 'the read applied');
    expect(users.user!.aiConsentStatus, AiConsentStatus.denied);
  });

  test('a read started and ended during the save keeps the choice', () async {
    final first = users.loadMe();
    await turns();
    reads.single.complete(_json(_me('undecided')));
    await first;
    final save = users.saveAiConsent(AiConsentStatus.granted);
    await turns();
    final during = users.loadMe();
    await turns();
    reads.last.complete(_json({..._me('denied'), 'display_name': '새 이름'}));
    final returned = await during;
    expect(users.user!.displayName, '새 이름', reason: 'other fields apply');
    expect(users.user!.aiConsentStatus, AiConsentStatus.undecided);
    expect(
      returned.aiConsentStatus,
      AiConsentStatus.undecided,
      reason: 'the returned user matches the stored one',
    );
    put.complete(
      _json({
        'status': 'granted',
        'notice_version': 1,
        'decided_at': '2026-11-26T03:00:00Z',
      }),
    );
    expect(await save, isTrue);
    expect(users.user!.aiConsentStatus, AiConsentStatus.granted);
  });

  test('a read started after the save is taken as is', () async {
    final save = users.saveAiConsent(AiConsentStatus.granted);
    put.complete(
      _json({
        'status': 'granted',
        'notice_version': 1,
        'decided_at': '2026-11-26T03:00:00Z',
      }),
    );
    expect(await save, isTrue);
    final later = users.loadMe();
    await turns();
    reads.single.complete(_json(_me('denied')));
    await later;
    expect(users.user!.aiConsentStatus, AiConsentStatus.denied);
  });

  test('an account reset during the save drops it', () async {
    final first = users.loadMe();
    await turns();
    reads.single.complete(_json(_me('undecided')));
    await first;
    final save = users.saveAiConsent(AiConsentStatus.granted);
    await turns();
    users.resetAccount(1);
    put.complete(
      _json({
        'status': 'granted',
        'notice_version': 1,
        'decided_at': '2026-11-26T03:00:00Z',
      }),
    );
    expect(await save, isFalse);
    expect(users.user, isNull);
  });
}
