import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/api_request_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/http_response_hold.dart';

const _old = ApiSession(
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _next = ApiSession(
  accessToken: 'next-access',
  refreshToken: 'next-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _contentPath = '/api/v1/contents/7';
const _refreshPath = '/api/v1/auth/refresh';

String _line(http.Request request) => '${request.method} ${request.url.path}';

void main() {
  // #364: a 404 means the content is already gone, so its body is not parsed.
  test(
    'deleteContent succeeds on malformed 404 after refreshing authorization',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == _refreshPath) {
          return http.Response(
            jsonEncode({
              'access_token': 'next-access',
              'refresh_token': 'next-refresh',
              'expires_in': 3600,
              'refresh_expires_in': 86400,
            }),
            200,
          );
        }
        return request.headers['Authorization'] == 'Bearer old-access'
            ? http.Response('', 401)
            : http.Response('null', 404);
      });
      addTearDown(client.close);
      final api = ClipbackApi(client: client)..restoreSession(_old);

      await api.deleteContent(7);

      expect(requests.map(_line), [
        'DELETE $_contentPath',
        'POST $_refreshPath',
        'DELETE $_contentPath',
      ]);
      expect(requests.first.headers['Authorization'], 'Bearer old-access');
      expect(jsonDecode(requests[1].body), {'refresh_token': 'old-refresh'});
      expect(requests.last.headers['Authorization'], 'Bearer next-access');
      expect(api.session?.accessToken, 'next-access');
      expect(api.session?.refreshToken, 'next-refresh');
    },
  );

  test(
    'deleteContent rejects late 404 after session replacement and preserves the new session',
    () async {
      final requests = <http.Request>[];
      final hold = HttpResponseHold('content delete');
      final client = MockClient((request) {
        requests.add(request);
        return hold.hold(request);
      });
      addTearDown(client.close);
      final api = ClipbackApi(client: client)..restoreSession(_old);

      final deletion = expectLater(
        api.deleteContent(7),
        throwsA(
          isA<ClipbackApiException>().having(
            (error) => error.message,
            'message',
            '로그인 상태가 변경되었어요. 다시 시도해 주세요.',
          ),
        ),
      );
      final request = await hold.waitForRequest();
      expect(_line(request), 'DELETE $_contentPath');
      expect(request.headers['Authorization'], 'Bearer old-access');

      api.restoreSession(_next);
      hold.release(http.Response('[]', 404));
      await deletion;
      await pumpEventQueue();

      expect(requests, hasLength(1));
      expect(api.session?.accessToken, 'next-access');
      expect(api.session?.refreshToken, 'next-refresh');
    },
  );

  test(
    'deleteContent rejects late 404 after scope cancellation and preserves the session',
    () async {
      final requests = <http.Request>[];
      final hold = HttpResponseHold('content delete');
      final client = MockClient((request) {
        requests.add(request);
        return hold.hold(request);
      });
      addTearDown(client.close);
      final api = ClipbackApi(client: client)..restoreSession(_old);
      final scope = ApiRequestScope();
      addTearDown(scope.cancel);
      final reason = StateError('content delete scope cancelled');

      final deletion = expectLater(
        scope.run(() => api.deleteContent(7)),
        throwsA(same(reason)),
      );
      final request = await hold.waitForRequest();
      expect(_line(request), 'DELETE $_contentPath');
      expect(request.headers['Authorization'], 'Bearer old-access');

      scope.cancel(reason);
      hold.release(http.Response('[]', 404));
      await deletion;
      await pumpEventQueue();

      expect(requests, hasLength(1));
      expect(api.session?.accessToken, 'old-access');
      expect(api.session?.refreshToken, 'old-refresh');
    },
  );
}
