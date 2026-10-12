import 'dart:async';
import 'dart:convert';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const tokens = ApiSession(
  accessToken: 'old',
  refreshToken: 'refresh',
  expiresIn: 60,
  refreshExpiresIn: 600,
);
http.Response json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
const credential = {
  'share_token': 'share-only',
  'expires_at': '2099-01-01T00:00:00Z',
  'user_id': 7,
  'session_id': 11,
};
void main() {
  test(
    'expired access refreshes once without nesting mint in persistence callback',
    () async {
      late ClipbackApi api;
      var refreshes = 0, persisted = 0, minted = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshes++;
          return json({
            'access_token': 'new',
            'refresh_token': 'rotated',
            'expires_in': 60,
            'refresh_expires_in': 600,
          });
        }
        minted++;
        if (request.headers['Authorization'] == 'Bearer old') {
          return json({'detail': 'expired'}, 401);
        }
        expect(persisted, 1);
        return json(credential);
      });
      api = ClipbackApi(
        client: client,
        onSessionChanged: (_) async {
          persisted++;
        },
      )..restoreSession(tokens);
      final result = await api.createShareCredential().timeout(
        const Duration(seconds: 2),
      );
      expect(result.userId, 7);
      expect(result.sessionId, 11);
      expect(result.token, 'share-only');
      expect(refreshes, 1);
      expect(minted, 2);
      expect(api.session!.refreshToken, 'rotated');
      client.close();
    },
  );
  test('share preparation 401 never clears the main session', () async {
    var invalidations = 0;
    final client = MockClient(
      (_) async => json({'detail': 'unavailable'}, 401),
    );
    final api = ClipbackApi(
      client: client,
      onSessionInvalidated: () async {
        invalidations++;
      },
    )..restoreSession(tokens);
    await expectLater(
      api.createShareCredential(),
      throwsA(isA<ClipbackApiException>()),
    );
    expect(invalidations, 0);
    expect(api.session, same(tokens));
    client.close();
  });
  test('late mint response cannot cross a session replacement', () async {
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);
    final api = ClipbackApi(client: client)..restoreSession(tokens);
    final mint = api.createShareCredential();
    final failure = expectLater(mint, throwsA(isA<ClipbackApiException>()));
    await Future<void>.delayed(Duration.zero);
    api.clearSession();
    response.complete(json(credential));
    await failure;
    expect(api.hasSession, isFalse);
    client.close();
  });
}
