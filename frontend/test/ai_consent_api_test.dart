// #475: the app reads ai_consent_status and saves a decision with PUT.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/api_request_scope.dart';
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

  // A refused refresh shared by callers with different deadlines (#474 재검수 3차).
  // The session callback waits for a native barrier bounded by the current
  // request scope, as the app's does. Each caller stops at its own deadline or
  // cancellation without ending the session; the one ending waits for the
  // barrier while any caller still waits, and an ended caller does not cut it.
  group('a refused shared refresh', () {
    late int clears;
    late Completer<void> barrier;
    // How a caller ended and how many clears were done when it learned it.
    final outcomes = <String, (String, int)>{};

    ClipbackApi barrierApi(_Server server) {
      clears = 0;
      outcomes.clear();
      barrier = Completer<void>();
      addTearDown(server.client.close);
      return ClipbackApi(
        client: server.client,
        onSessionInvalidated: () async {
          final scope = ApiRequestScope.current;
          try {
            await (scope == null ? barrier.future : scope.wait(barrier.future));
          } catch (_) {}
          clears++;
        },
      )..restoreSession(_session);
    }

    void watch(String name, Future<Object?> request) {
      outcomes.remove(name);
      unawaited(
        request.then<void>(
          (value) =>
              outcomes[name] = (value is Enum ? value.name : 'ok', clears),
          onError: (Object error) => outcomes[name] = (
            error is ClipbackApiException
                ? '${error.statusCode ?? error.message}'
                : '${error.runtimeType}',
            clears,
          ),
        ),
      );
    }

    ApiRequestScope read(ClipbackApi api, String name, {Duration? deadline}) {
      final scope = ApiRequestScope(timeout: deadline);
      watch(name, scope.run(() => scope.wait(api.readMe())));
      return scope;
    }

    List<Future<http.Response> Function()> twoReadsSharingARefusal() => [
      _now(_json({'detail': 'expired'}, 401)),
      () => Future.delayed(
        const Duration(seconds: 1),
        () => _json({'detail': 'expired'}, 401),
      ),
      _now(_json({'detail': 'expired'}, 401)),
    ];

    for (final shortFirst in [true, false]) {
      final order = shortFirst ? 'short first' : 'long first';
      testWidgets(
        '$order: the short caller times out alone and the long one waits for the barrier',
        (tester) async {
          final server = _Server(twoReadsSharingARefusal());
          final api = barrierApi(server);
          void short() =>
              read(api, 'short', deadline: const Duration(seconds: 5));
          void long() =>
              read(api, 'long', deadline: const Duration(seconds: 15));
          shortFirst ? short() : long();
          await tester.pump(const Duration(milliseconds: 500));
          shortFirst ? long() : short();
          await tester.pump(const Duration(milliseconds: 600));
          expect(server.requests, hasLength(3)); // Both joined one refresh.
          expect(clears, 0); // The refusal arrived; the barrier holds.
          await tester.pump(const Duration(milliseconds: 4500)); // 5.6 s
          // Past the short deadline (5 s or 5.5 s) only the short caller ended.
          expect(outcomes['short'], ('TimeoutException', 0));
          expect(outcomes['long'], isNull);
          await tester.pump(const Duration(seconds: 2)); // 7.6 s
          expect(clears, 0);
          barrier.complete();
          await tester.pump();
          expect(clears, 1);
          expect(outcomes['long'], ('401', 1));
          await tester.pump(const Duration(seconds: 30));
          expect(clears, 1);
          expect(server.requests, hasLength(3));
        },
      );

      testWidgets(
        '$order: cancelling the short caller does not end the long caller early',
        (tester) async {
          final server = _Server(twoReadsSharingARefusal());
          final api = barrierApi(server);
          late ApiRequestScope shortScope;
          void short() => shortScope = read(api, 'short');
          void long() =>
              read(api, 'long', deadline: const Duration(seconds: 15));
          shortFirst ? short() : long();
          await tester.pump(const Duration(milliseconds: 500));
          shortFirst ? long() : short();
          await tester.pump(const Duration(milliseconds: 600));
          expect(server.requests, hasLength(3));
          shortScope.cancel();
          await tester.pump();
          expect(outcomes['short'], ('StateError', 0));
          await tester.pump(const Duration(seconds: 5));
          expect(clears, 0);
          expect(outcomes['long'], isNull);
          barrier.complete();
          await tester.pump();
          expect(clears, 1);
          expect(outcomes['long'], ('401', 1));
          await tester.pump(const Duration(seconds: 30));
          expect(clears, 1);
        },
      );
    }

    testWidgets('with the barrier held the last caller deadline ends it', (
      tester,
    ) async {
      final server = _Server(twoReadsSharingARefusal());
      final api = barrierApi(server);
      read(api, 'short', deadline: const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));
      read(api, 'long', deadline: const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 5)); // 5.5 s
      expect(outcomes['short'], ('TimeoutException', 0));
      await tester.pump(const Duration(seconds: 9)); // 14.5 s
      expect(clears, 0);
      expect(outcomes['long'], isNull);
      await tester.pump(const Duration(seconds: 1)); // 15.5 s
      expect(clears, 1);
      // The long caller learns its own deadline first; the ending, cut by the
      // same timer, clears right after.
      expect(outcomes['long'], ('TimeoutException', 0));
      await tester.pump(const Duration(seconds: 30));
      expect(clears, 1);
    });

    testWidgets(
      'an expired PUT does not cut the barrier a valid GET waits for',
      (tester) async {
        final refusal = Completer<http.Response>();
        // The PUT is refused at 4 s, so its refresh (own 10-second limit) is
        // still waiting when the PUT deadline passes at 10 s.
        final server = _Server([
          () => Future.delayed(
            const Duration(seconds: 4),
            () => _json({'detail': 'expired'}, 401),
          ), // PUT
          () => refusal.future, // refresh
          _now(_json({'detail': 'expired'}, 401)), // GET
        ]);
        final api = barrierApi(server);
        watch('put', api.saveAiConsent(AiConsentStatus.denied));
        await tester.pump(const Duration(seconds: 5));
        final get = read(api, 'get', deadline: const Duration(seconds: 15));
        await tester.pump();
        expect(server.requests, hasLength(3)); // The GET joined the refresh.
        await tester.pump(const Duration(seconds: 5)); // 10 s
        expect(outcomes['put'], ('unconfirmed', 0));
        refusal.complete(_json({'detail': 'expired'}, 401));
        await tester.pump(const Duration(seconds: 1)); // 11 s
        expect(clears, 0);
        expect(get.isActive, isTrue);
        expect(outcomes['get'], isNull);
        barrier.complete();
        await tester.pump();
        expect(clears, 1);
        expect(outcomes['get'], ('401', 1));
        await tester.pump(const Duration(seconds: 30));
        expect(clears, 1);
        expect(server.requests.where((r) => r.method == 'PUT'), hasLength(1));
        expect(
          server.requests.where((r) => r.url.path.endsWith('/auth/refresh')),
          hasLength(1),
        );
      },
    );

    testWidgets('a lone late refusal ends the session without the barrier', (
      tester,
    ) async {
      final refusal = Completer<http.Response>();
      final server = _Server([
        () => Future.delayed(
          const Duration(seconds: 4),
          () => _json({'detail': 'expired'}, 401),
        ),
        () => refusal.future,
      ]);
      final api = barrierApi(server);
      watch('put', api.saveAiConsent(AiConsentStatus.denied));
      await tester.pump(const Duration(seconds: 11));
      expect(outcomes['put'], ('unconfirmed', 0));
      expect(clears, 0);
      refusal.complete(_json({'detail': 'expired'}, 401));
      await tester.pump();
      expect(barrier.isCompleted, isFalse);
      expect(clears, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(clears, 1);
      expect(server.requests, hasLength(2));
    });
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

    final rotated = _json({
      'access_token': 'rotated-access',
      'refresh_token': 'rotated-refresh',
      'expires_in': 7200,
      'refresh_expires_in': 172800,
      'is_new_user': false,
    });

    int puts(_Server server) =>
        server.requests.where((request) => request.method == 'PUT').length;

    testWidgets('an answer just before the deadline is still judged', (
      tester,
    ) async {
      final server = _Server([
        () => Future.delayed(
          const Duration(milliseconds: 9900),
          () => _json(_saved('granted')),
        ),
      ]);
      AiConsentSaveResult? result;
      unawaited(
        apiFor(server)
            .saveAiConsent(AiConsentStatus.granted)
            .then((value) => result = value),
      );
      await tester.pump(const Duration(milliseconds: 9950));
      expect(result, AiConsentSaveResult.saved);
    });

    testWidgets('a 401 arriving after the deadline sends nothing more', (
      tester,
    ) async {
      final server = _Server([
        () => Future.delayed(
          const Duration(seconds: 11),
          () => _json({'detail': 'expired'}, 401),
        ),
        _now(rotated),
        _now(_json(_saved('granted'))),
      ]);
      AiConsentSaveResult? result;
      unawaited(
        apiFor(server)
            .saveAiConsent(AiConsentStatus.granted)
            .then((value) => result = value),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(result, AiConsentSaveResult.unconfirmed);
      await tester.pump(const Duration(seconds: 20));
      expect(puts(server), 1);
      expect(server.requests, hasLength(1));
      expect(invalidations, 0);
    });

    testWidgets('a refresh finishing after the deadline does not resend', (
      tester,
    ) async {
      final server = _Server([
        // The 401 at 5 s starts a refresh that answers at 11 s, after the
        // PUT's deadline and within the refresh's own 10 s limit.
        () => Future.delayed(
          const Duration(seconds: 5),
          () => _json({'detail': 'expired'}, 401),
        ),
        () => Future.delayed(const Duration(seconds: 6), () => rotated),
        _now(_json(_saved('granted'))),
      ]);
      AiConsentSaveResult? result;
      unawaited(
        apiFor(server)
            .saveAiConsent(AiConsentStatus.granted)
            .then((value) => result = value),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(result, AiConsentSaveResult.unconfirmed);
      expect(server.requests, hasLength(2)); // The refresh was sent in time.
      await tester.pump(const Duration(seconds: 20));
      expect(puts(server), 1);
      expect(invalidations, 0);
    });

    testWidgets('another caller keeps the shared refresh after the deadline', (
      tester,
    ) async {
      final server = _Server([
        // The 401 at 5 s starts a refresh that answers at 11 s, after the
        // PUT's deadline and within the refresh's own 10 s limit.
        () => Future.delayed(
          const Duration(seconds: 5),
          () => _json({'detail': 'expired'}, 401),
        ),
        () => Future.delayed(const Duration(seconds: 6), () => rotated),
        _now(_json(_user())),
      ]);
      final api = apiFor(server);
      AiConsentSaveResult? result;
      ApiUser? me;
      unawaited(
        api
            .saveAiConsent(AiConsentStatus.granted)
            .then((value) => result = value),
      );
      await tester.pump(const Duration(seconds: 6));
      expect(server.requests, hasLength(2)); // PUT, then its refresh.
      // An unscoped caller joins the refresh the consent PUT started.
      unawaited(
        api.refreshSession().then((_) => api.readMe()).then((u) => me = u),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(result, AiConsentSaveResult.unconfirmed);
      await tester.pump(const Duration(seconds: 20));
      expect(me?.id, 7);
      expect(api.session?.accessToken, 'rotated-access');
      expect(
        [
          for (final request in server.requests)
            '${request.method} ${request.url.path}',
        ],
        ['PUT $_path', 'POST /api/v1/auth/refresh', 'GET /api/v1/users/me'],
      );
    });

    for (final (name, body) in [
      ('an empty object', _json(<String, Object?>{})),
      ('a body that is not JSON', http.Response('<html>', 200)),
    ]) {
      test('a refresh answering $name fails without resending', () async {
        final server = _Server([
          _now(_json({'detail': 'expired'}, 401)),
          _now(body),
        ]);
        expect(
          await apiFor(server).saveAiConsent(AiConsentStatus.granted),
          AiConsentSaveResult.failed,
        );
        expect(puts(server), 1);
        expect(server.requests, hasLength(2));
      });
    }

    for (final (time, expected) in [
      ('2028-02-29T00:00:00Z', AiConsentSaveResult.saved),
      ('2026-11-25T10:00:00.5+09:00', AiConsentSaveResult.saved),
      ('2026-02-29T00:00:00Z', AiConsentSaveResult.unconfirmed),
      ('2026-02-31T00:00:00Z', AiConsentSaveResult.unconfirmed),
      ('2026-11-25T24:00:00Z', AiConsentSaveResult.unconfirmed),
      ('2026-11-25', AiConsentSaveResult.unconfirmed),
      ('2026-11-25T01:00:00', AiConsentSaveResult.unconfirmed),
      ('2026-11-25 01:00:00Z', AiConsentSaveResult.unconfirmed),
      ('2026-11-25T01:00:00+24:00', AiConsentSaveResult.unconfirmed),
      ('2026-11-25T01:00:00+00:60', AiConsentSaveResult.unconfirmed),
      ('2026-11-25T01:00:00-23:59', AiConsentSaveResult.saved),
    ]) {
      test('decided_at $time is ${expected.name}', () async {
        final server = _Server([
          _now(_json({..._saved('granted'), 'decided_at': time})),
        ]);
        expect(
          await apiFor(server).saveAiConsent(AiConsentStatus.granted),
          expected,
        );
      });
    }

    testWidgets(
      'a refresh the server applied after the deadline keeps its tokens',
      (tester) async {
        final server = _Server([
          // The lone PUT gets its 401 at 5 s; the refresh is applied on the
          // server and answers at 11 s, after the PUT's 10 s deadline.
          () => Future.delayed(
            const Duration(seconds: 5),
            () => _json({'detail': 'expired'}, 401),
          ),
          () => Future.delayed(const Duration(seconds: 6), () => rotated),
          // The follow-up re-read the screen makes for an unconfirmed result.
          _now(_json(_user({'ai_consent_status': 'granted'}))),
        ]);
        final api = apiFor(server);
        AiConsentSaveResult? result;
        unawaited(
          api
              .saveAiConsent(AiConsentStatus.granted)
              .then((value) => result = value),
        );
        await tester.pump(const Duration(seconds: 10));
        expect(result, AiConsentSaveResult.unconfirmed);
        expect(api.session?.accessToken, 'old-access');
        await tester.pump(const Duration(seconds: 2));
        // The rotated tokens are kept: the old refresh token is no longer valid.
        expect(api.session?.accessToken, 'rotated-access');
        expect(api.session?.refreshToken, 'rotated-refresh');
        ApiUser? me;
        unawaited(api.readMe().then((user) => me = user));
        await tester.pump();
        expect(me?.aiConsentStatus, AiConsentStatus.granted);
        expect(
          [
            for (final request in server.requests)
              '${request.method} ${request.url.path}',
          ],
          ['PUT $_path', 'POST /api/v1/auth/refresh', 'GET /api/v1/users/me'],
        );
        expect(
          server.requests.last.headers['Authorization'],
          'Bearer rotated-access',
        );
        expect(invalidations, 0);
      },
    );

    testWidgets('a late refresh answer is dropped after an account change', (
      tester,
    ) async {
      const other = ApiSession(
        accessToken: 'other-access',
        refreshToken: 'other-refresh',
        expiresIn: 3600,
        refreshExpiresIn: 86400,
      );
      final server = _Server([
        () => Future.delayed(
          const Duration(seconds: 5),
          () => _json({'detail': 'expired'}, 401),
        ),
        () => Future.delayed(const Duration(seconds: 6), () => rotated),
      ]);
      final api = apiFor(server);
      AiConsentSaveResult? result;
      unawaited(
        api
            .saveAiConsent(AiConsentStatus.granted)
            .then((value) => result = value),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(result, AiConsentSaveResult.unconfirmed);
      api.restoreSession(other); // Another account signs in.
      await tester.pump(const Duration(seconds: 5));
      expect(api.session?.accessToken, 'other-access');
      expect(puts(server), 1);
    });

    // Review recheck 2, Spec 1: a refresh kept past the PUT deadline that the server
    // refuses for good (401) still ends this account's session exactly once.
    Future<http.Response> Function() late401(int seconds) =>
        () => Future.delayed(
          Duration(seconds: seconds),
          () => _json({'detail': 'expired'}, 401),
        );

    testWidgets('a late 401 refresh after the deadline ends the session once', (
      tester,
    ) async {
      final server = _Server([late401(5), late401(6)]);
      final api = apiFor(server);
      AiConsentSaveResult? result;
      unawaited(
        api
            .saveAiConsent(AiConsentStatus.granted)
            .then((value) => result = value),
      );
      await tester.pump(const Duration(seconds: 6));
      expect(
        server.requests,
        hasLength(2),
      ); // The refresh was sent before the deadline.
      await tester.pump(const Duration(seconds: 4));
      expect(result, AiConsentSaveResult.unconfirmed);
      expect(invalidations, 0); // The refresh has not answered yet.
      await tester.pump(const Duration(seconds: 2));
      expect(invalidations, 1);
      expect(puts(server), 1);
      await tester.pump(const Duration(seconds: 20));
      expect(invalidations, 1);
      expect(server.requests, hasLength(2));
    });

    testWidgets('a shared late 401 refresh ends the session once', (
      tester,
    ) async {
      final server = _Server([
        late401(5),
        late401(6),
        // Another request with the old token joins the refresh.
        _now(_json({'detail': 'expired'}, 401)),
      ]);
      final api = apiFor(server);
      AiConsentSaveResult? result;
      Object? otherError;
      unawaited(
        api
            .saveAiConsent(AiConsentStatus.granted)
            .then((value) => result = value),
      );
      await tester.pump(const Duration(seconds: 6));
      unawaited(
        api.readMe().then<void>((_) {}, onError: (Object e) => otherError = e),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        server.requests,
        hasLength(3),
      ); // PUT, refresh, then the other GET.
      await tester.pump(const Duration(seconds: 3));
      expect(result, AiConsentSaveResult.unconfirmed);
      await tester.pump(const Duration(seconds: 20));
      expect(invalidations, 1);
      expect(otherError, isA<ClipbackApiException>());
      expect((otherError as ClipbackApiException).statusCode, 401);
      expect(puts(server), 1);
    });

    testWidgets('a late 401 refresh after an account change ends nothing', (
      tester,
    ) async {
      const other = ApiSession(
        accessToken: 'other-access',
        refreshToken: 'other-refresh',
        expiresIn: 3600,
        refreshExpiresIn: 86400,
      );
      final server = _Server([late401(5), late401(6)]);
      final api = apiFor(server);
      AiConsentSaveResult? result;
      unawaited(
        api
            .saveAiConsent(AiConsentStatus.granted)
            .then((value) => result = value),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(result, AiConsentSaveResult.unconfirmed);
      api.restoreSession(other);
      await tester.pump(const Duration(seconds: 20));
      expect(invalidations, 0);
      expect(api.session?.accessToken, 'other-access');
      expect(puts(server), 1);
    });

    test(
      'a lost connection during the refresh fails without resending',
      () async {
        final server = _Server([
          _now(_json({'detail': 'expired'}, 401)),
          () async => throw http.ClientException('refresh connection closed'),
        ]);
        expect(
          await apiFor(server).saveAiConsent(AiConsentStatus.granted),
          AiConsentSaveResult.failed,
        );
        expect(puts(server), 1);
        expect(server.requests, hasLength(2));
      },
    );

    test('a lost answer to the resent PUT is unconfirmed', () async {
      final server = _Server([
        _now(_json({'detail': 'expired'}, 401)),
        _now(rotated),
        () async => throw http.ClientException('resend connection closed'),
      ]);
      expect(
        await apiFor(server).saveAiConsent(AiConsentStatus.granted),
        AiConsentSaveResult.unconfirmed,
      );
      expect(puts(server), 2);
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
