import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'http_response_hold.dart';

void main() {
  test(
    'two requests can release in reverse order without mixing responses',
    () async {
      final first = HttpResponseHold('first');
      final second = HttpResponseHold('second');
      var firstCompleted = false;
      final firstResponse = first
          .hold(http.Request('GET', Uri.parse('/first')))
          .then((response) {
            firstCompleted = true;
            return response;
          });
      final secondResponse = second.hold(
        http.Request('POST', Uri.parse('/second')),
      );
      await Future.wait([first.waitForRequest(), second.waitForRequest()]);
      second.release(http.Response('second failed', 502));
      final actualSecond = await secondResponse;
      expect(actualSecond.statusCode, 502);
      expect(actualSecond.body, 'second failed');
      expect(firstCompleted, isFalse);
      first.release(http.Response('first succeeded', 202));
      final actualFirst = await firstResponse;
      expect(actualFirst.statusCode, 202);
      expect(actualFirst.body, 'first succeeded');
    },
  );

  test('a hold rejects a second request', () async {
    final hold = HttpResponseHold('single');
    final response = hold.hold(http.Request('GET', Uri.parse('/first')));
    expect(
      () => hold.hold(http.Request('GET', Uri.parse('/second'))),
      throwsStateError,
    );
    hold.release(http.Response('first', 200));
    expect((await response).body, 'first');
  });

  test('missing request times out with its description', () async {
    final hold = HttpResponseHold('POST /missing');
    await expectLater(
      hold.waitForRequest(timeout: Duration.zero),
      throwsA(
        isA<TimeoutException>().having(
          (error) => error.message,
          'message',
          contains('POST /missing'),
        ),
      ),
    );
  });

  test('release before arrival fails without consuming the response', () async {
    final hold = HttpResponseHold('GET /target');
    expect(
      () => hold.release(http.Response('too early', 200)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('GET /target has not arrived'),
        ),
      ),
    );
    final response = hold.hold(http.Request('GET', Uri.parse('/target')));
    await hold.waitForRequest();
    hold.release(http.Response('failure body', 503));
    final actual = await response;
    expect(actual.statusCode, 503);
    expect(actual.body, 'failure body');
    expect(() => hold.release(http.Response('again', 200)), throwsStateError);
  });

  test(
    'only the selected request arrives and its response stays held',
    () async {
      final hold = HttpResponseHold('GET /target');
      final client = MockClient((request) {
        if (request.url.path == '/target') return hold.hold(request);
        return Future.value(http.Response('other', 200));
      });
      addTearDown(client.close);
      var arrived = false;
      final arrival = hold.waitForRequest().then((request) {
        arrived = true;
        return request;
      });
      var loading = true;
      await client.get(Uri.parse('https://example.com/other'));
      loading = false;
      expect(loading, isFalse);
      expect(
        arrived,
        isFalse,
        reason: 'other requests and loading are unrelated',
      );

      var completed = false;
      final response = client.get(Uri.parse('https://example.com/target')).then(
        (r) {
          completed = true;
          return r;
        },
      );
      final request = await arrival;
      expect(request.method, 'GET');
      expect(request.url.path, '/target');
      expect(completed, isFalse);
      hold.release(http.Response('selected success', 201));
      final actual = await response;
      expect(actual.statusCode, 201);
      expect(actual.body, 'selected success');
    },
  );
}
