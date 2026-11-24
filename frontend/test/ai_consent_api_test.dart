// #475: the app reads ai_consent_status and saves a decision with PUT.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _session = ApiSession(
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _path = '/api/v1/users/me/ai-consent';

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _user([Map<String, Object?> extra = const {}]) => {
  'id': 7,
  'email': null,
  'display_name': '사용자',
  'is_guest': false,
  'created_at': '2026-11-25T00:00:00Z',
  'linked_providers': <String>[],
  ...extra,
};

Map<String, Object?> _saved(String status) => {
  'status': status,
  'notice_version': 1,
  'decided_at': '2026-11-25T01:00:00.123456Z',
};

class _Server {
  _Server(this.replies);
  final List<Future<http.Response> Function()> replies;
  final requests = <http.Request>[];
  late final client = MockClient((request) {
    requests.add(request);
    return replies.removeAt(0)();
  });
}

Future<http.Response> Function() _now(http.Response response) =>
    () async => response;

void main() {
  group('ai_consent_status', () {
    for (final (value, expected) in [
      ('undecided', AiConsentStatus.undecided),
      ('granted', AiConsentStatus.granted),
      ('denied', AiConsentStatus.denied),
    ]) {
      test('$value is read', () {
        expect(
          ApiUser.fromJson(_user({'ai_consent_status': value})).aiConsentStatus,
          expected,
        );
      });
    }

    test('a server without the field gives unknown', () {
      expect(
        ApiUser.fromJson(_user()).aiConsentStatus,
        AiConsentStatus.unknown,
      );
    });

    for (final value in <Object?>[
      null,
      'paused',
      'GRANTED',
      '',
      1,
      true,
      ['granted'],
      {'status': 'granted'},
    ]) {
      test('unknown value ${jsonEncode(value)} gives unknown', () {
        final user = ApiUser.fromJson(_user({'ai_consent_status': value}));
        expect(user.aiConsentStatus, AiConsentStatus.unknown);
        expect(user.id, 7);
      });
    }
  });

  group('saveAiConsent', () {
    late int invalidations;

    ClipbackApi apiFor(_Server server) {
      invalidations = 0;
      addTearDown(server.client.close);
      return ClipbackApi(
        client: server.client,
        onSessionInvalidated: () async => invalidations++,
      )..restoreSession(_session);
    }

    for (final status in [AiConsentStatus.granted, AiConsentStatus.denied]) {
      test('${status.name}: a matching 200 is saved', () async {
        final server = _Server([_now(_json(_saved(status.value!)))]);
        expect(
          await apiFor(server).saveAiConsent(status),
          AiConsentSaveResult.saved,
        );
        final request = server.requests.single;
        expect('${request.method} ${request.url.path}', 'PUT $_path');
        expect(request.headers['Authorization'], 'Bearer old-access');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(request.body), {
          'status': status.value,
          'notice_version': 1,
        });
      });
    }

    final unconfirmed = <String, http.Response>{
      'empty body': http.Response('', 200),
      'not JSON': http.Response('<html>', 200),
      'JSON array': _json([_saved('granted')]),
      'JSON null': _json(null),
      'other status': _json(_saved('denied')),
      'missing status': _json({..._saved('granted')}..remove('status')),
      'version 2': _json({..._saved('granted'), 'notice_version': 2}),
      'version "1"': _json({..._saved('granted'), 'notice_version': '1'}),
      'version 1.0': http.Response(
        '{"status":"granted","notice_version":1.0,'
        '"decided_at":"2026-11-25T01:00:00Z"}',
        200,
      ),
      'missing version': _json(
        {..._saved('granted')}..remove('notice_version'),
      ),
      'missing time': _json({..._saved('granted')}..remove('decided_at')),
      'invalid time': _json({..._saved('granted'), 'decided_at': 'yesterday'}),
      'numeric time': _json({..._saved('granted'), 'decided_at': 1}),
    };
    for (final MapEntry(key: name, value: response) in unconfirmed.entries) {
      test('200 with $name is unconfirmed', () async {
        final server = _Server([_now(response)]);
        expect(
          await apiFor(server).saveAiConsent(AiConsentStatus.granted),
          AiConsentSaveResult.unconfirmed,
        );
        expect(server.requests, hasLength(1));
      });
    }

    for (final code in [201, 204, 400, 403, 409, 422, 500, 502, 503]) {
      test('$code fails', () async {
        final server = _Server([
          _now(
            code == 204
                ? http.Response('', 204)
                : _json(_saved('granted'), code),
          ),
        ]);
        expect(
          await apiFor(server).saveAiConsent(AiConsentStatus.granted),
          AiConsentSaveResult.failed,
        );
        expect(server.requests, hasLength(1));
      });
    }

    test('a lost connection is unconfirmed', () async {
      final server = _Server([
        () async => throw http.ClientException('connection closed'),
      ]);
      expect(
        await apiFor(server).saveAiConsent(AiConsentStatus.denied),
        AiConsentSaveResult.unconfirmed,
      );
    });

    testWidgets('no answer within 10 seconds is unconfirmed', (tester) async {
      final hanging = Completer<http.Response>();
      final server = _Server([() => hanging.future]);
      AiConsentSaveResult? result;
      unawaited(
        apiFor(server)
            .saveAiConsent(AiConsentStatus.granted)
            .then((value) => result = value),
      );
      await tester.pump(const Duration(milliseconds: 9900));
      expect(result, isNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(result, AiConsentSaveResult.unconfirmed);
    });

    test('a 401 refreshes the session and resends once', () async {
      final server = _Server([
        _now(_json({'detail': 'expired'}, 401)),
        _now(
          _json({
            'access_token': 'rotated-access',
            'refresh_token': 'rotated-refresh',
            'expires_in': 7200,
            'refresh_expires_in': 172800,
            'is_new_user': false,
          }),
        ),
        _now(_json(_saved('granted'))),
      ]);
      expect(
        await apiFor(server).saveAiConsent(AiConsentStatus.granted),
        AiConsentSaveResult.saved,
      );
      expect(
        [
          for (final request in server.requests)
            '${request.method} ${request.url.path}',
        ],
        ['PUT $_path', 'POST /api/v1/auth/refresh', 'PUT $_path'],
      );
      expect(
        server.requests.last.headers['Authorization'],
        'Bearer rotated-access',
      );
      expect(invalidations, 0);
    });

    test('a failed refresh ends the session and fails', () async {
      final server = _Server([
        _now(_json({'detail': 'expired'}, 401)),
        _now(_json({'detail': 'expired'}, 401)),
      ]);
      expect(
        await apiFor(server).saveAiConsent(AiConsentStatus.granted),
        AiConsentSaveResult.failed,
      );
      expect(invalidations, 1);
      expect(server.requests, hasLength(2));
    });
  });
}
