import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _old = ApiSession(
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _mePath = '/api/v1/users/me';
const _refreshPath = '/api/v1/auth/refresh';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _rotated = _json({
  'access_token': 'rotated-access',
  'refresh_token': 'rotated-refresh',
  'expires_in': 7200,
  'refresh_expires_in': 172800,
  'is_new_user': false,
});

/// Answers each request with the next queued reply; a reply may delay or hang.
class _Server {
  _Server(this.replies);
  final List<Future<http.Response> Function()> replies;
  final requests = <http.Request>[];
  late final client = MockClient((request) {
    requests.add(request);
    return replies.removeAt(0)();
  });

  List<String> get paths => [
    for (final request in requests) '${request.method} ${request.url.path}',
  ];
}

Future<http.Response> Function() _now(http.Response response) =>
    () async => response;

Future<http.Response> Function() _after(
  Duration delay,
  http.Response response,
) =>
    () => Future.delayed(delay, () => response);

class _Submission {
  _Submission(ClipbackApi api, {List<AccountDeletionReason>? reasons}) {
    api
        .deleteAccount(reasons ?? const [AccountDeletionReason.rejoin])
        .then((value) => result = value);
  }
  AccountDeletionResult? result;
}

void main() {
  late int invalidations;

  ClipbackApi apiFor(_Server server) {
    invalidations = 0;
    addTearDown(server.client.close);
    return ClipbackApi(
      client: server.client,
      onSessionInvalidated: () async => invalidations++,
    )..restoreSession(_old);
  }

  testWidgets('sends the chosen reasons and 204 is a deletion', (tester) async {
    final server = _Server([_now(http.Response('', 204))]);
    final submission = _Submission(
      apiFor(server),
      reasons: AccountDeletionReason.values,
    );
    await tester.pump();

    expect(submission.result, AccountDeletionResult.deleted);
    final request = server.requests.single;
    expect('${request.method} ${request.url.path}', 'DELETE $_mePath');
    expect(request.headers['Authorization'], 'Bearer old-access');
    expect(request.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(request.body), {
      'reasons': ['rejoin', 'low_usage', 'privacy_security', 'other'],
    });
    expect(invalidations, 0);
  });

  for (final (name, reply) in <(String, Future<http.Response> Function())>[
    ('422', _now(_json({'detail': []}, 422))),
    ('503', _now(_json({'detail': 'Temporarily unavailable'}, 503))),
    (
      'maintenance 503',
      _now(
        _json({
          'detail': {'code': 'service_maintenance'},
        }, 503),
      ),
    ),
    ('500', _now(http.Response('', 500))),
    ('200 instead of 204', _now(_json(<String, Object>{}))),
    ('202 instead of 204', _now(http.Response('', 202))),
    ('connection failure', () => throw http.ClientException('Offline')),
  ]) {
    testWidgets('$name is a failure and keeps the session', (tester) async {
      final server = _Server([reply]);
      final api = apiFor(server);
      final submission = _Submission(api);
      await tester.pump();

      expect(submission.result, AccountDeletionResult.failed);
      expect(api.session?.accessToken, 'old-access');
      expect(invalidations, 0);
    });
  }

  testWidgets('401 with a failed refresh uses the existing 401 handling', (
    tester,
  ) async {
    final server = _Server([
      _now(_json({'detail': 'Invalid'}, 401)),
      _now(_json({'detail': 'Invalid'}, 401)),
    ]);
    final submission = _Submission(apiFor(server));
    await tester.pump();

    expect(submission.result, AccountDeletionResult.unauthorized);
    expect(server.paths, ['DELETE $_mePath', 'POST $_refreshPath']);
    expect(invalidations, 1);
  });

  testWidgets('401 again after a refresh uses the existing 401 handling', (
    tester,
  ) async {
    final server = _Server([
      _now(_json({'detail': 'Invalid'}, 401)),
      _now(_rotated),
      _now(_json({'detail': 'Invalid'}, 401)),
    ]);
    final submission = _Submission(apiFor(server));
    await tester.pump();

    expect(submission.result, AccountDeletionResult.unauthorized);
    expect(invalidations, 1);
  });

  testWidgets('a refreshed session resends the same reasons', (tester) async {
    final server = _Server([
      _now(_json({'detail': 'Invalid'}, 401)),
      _now(_rotated),
      _now(http.Response('', 204)),
    ]);
    final submission = _Submission(
      apiFor(server),
      reasons: const [AccountDeletionReason.other],
    );
    await tester.pump();

    expect(submission.result, AccountDeletionResult.deleted);
    expect(server.paths, [
      'DELETE $_mePath',
      'POST $_refreshPath',
      'DELETE $_mePath',
    ]);
    expect(
      server.requests.last.headers['Authorization'],
      'Bearer rotated-access',
    );
    expect(jsonDecode(server.requests.last.body), {
      'reasons': ['other'],
    });
    expect(invalidations, 0);
  });

  testWidgets('the whole submission with refresh and resend ends at 60s', (
    tester,
  ) async {
    final hung = Completer<http.Response>();
    final server = _Server([
      _after(const Duration(seconds: 30), _json({'detail': 'Invalid'}, 401)),
      _after(const Duration(seconds: 9), _rotated),
      () => hung.future,
    ]);
    final api = apiFor(server);
    final submission = _Submission(api);

    await tester.pump(const Duration(seconds: 59, milliseconds: 999));
    expect(server.paths, [
      'DELETE $_mePath',
      'POST $_refreshPath',
      'DELETE $_mePath',
    ]);
    expect(submission.result, isNull);

    await tester.pump(const Duration(milliseconds: 1));
    expect(submission.result, AccountDeletionResult.failed);

    // The late answer is dropped: the result and the login stay as they are.
    hung.complete(http.Response('', 204));
    await tester.pump();
    expect(submission.result, AccountDeletionResult.failed);
    expect(api.session?.accessToken, 'rotated-access');
    expect(invalidations, 0);
  });

  testWidgets('a refresh inside the 60s keeps its own 10s limit', (
    tester,
  ) async {
    final hung = Completer<http.Response>();
    final server = _Server([
      _now(_json({'detail': 'Invalid'}, 401)),
      () => hung.future,
    ]);
    final api = apiFor(server);
    final submission = _Submission(api);

    await tester.pump(const Duration(seconds: 9));
    expect(submission.result, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(submission.result, AccountDeletionResult.failed);
    expect(server.paths, ['DELETE $_mePath', 'POST $_refreshPath']);
    expect(api.session?.accessToken, 'old-access');
    expect(invalidations, 0);
    hung.complete(_rotated);
    await tester.pump();
  });

  // Both 401 paths wait for the session invalidation callback; that wait is
  // part of the 60s submission, and its late end does not change the result.
  for (final (name, replies) in <(String, List<http.Response>)>[
    (
      'a refresh 401',
      [
        _json({'detail': 'Invalid'}, 401),
        _json({'detail': 'Invalid'}, 401),
      ],
    ),
    (
      'a resend 401 after a refresh',
      [
        _json({'detail': 'Invalid'}, 401),
        _rotated,
        _json({'detail': 'Invalid'}, 401),
      ],
    ),
  ]) {
    testWidgets('60s also covers the invalidation after $name', (tester) async {
      final invalidation = Completer<void>();
      var entered = 0;
      final server = _Server([for (final reply in replies) _now(reply)]);
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionInvalidated: () {
          entered++;
          return invalidation.future;
        },
      )..restoreSession(_old);
      final submission = _Submission(api);

      await tester.pump();
      expect(entered, 1);
      await tester.pump(const Duration(seconds: 59, milliseconds: 999));
      expect(submission.result, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(submission.result, AccountDeletionResult.failed);

      // The session cleanup still finishes on its own; the result stays.
      invalidation.complete();
      await tester.pump();
      expect(submission.result, AccountDeletionResult.failed);
      expect(entered, 1);
      expect(server.requests, hasLength(replies.length));
    });
  }

  testWidgets('other requests keep waiting past 60s', (tester) async {
    final hung = Completer<http.Response>();
    final server = _Server([() => hung.future]);
    var finished = false;
    unawaited(apiFor(server).deleteContent(7).then((_) => finished = true));

    await tester.pump(const Duration(seconds: 61));
    expect(finished, isFalse);
    hung.complete(http.Response('', 204));
    await tester.pump();
    expect(finished, isTrue);
  });
}
