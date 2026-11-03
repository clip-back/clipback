import 'dart:async';

import 'package:http/http.dart' as http;

/// One selected MockClient request and its explicitly supplied response.
/// Routing belongs to the fixture; use a new hold for each request.
class HttpResponseHold {
  HttpResponseHold(this.description);

  final String description;
  final _arrival = Completer<http.Request>();
  final _response = Completer<http.Response>();

  Future<http.Response> hold(http.Request request) {
    if (_arrival.isCompleted) {
      throw StateError('$description already has a request');
    }
    _arrival.complete(request);
    return _response.future;
  }

  /// Fails with a labeled TimeoutException if this request never arrives.
  /// Widget tests must pump frames while waiting; do not pumpAndSettle while
  /// the response is held. A timeout does not release or replace the response.
  Future<http.Request> waitForRequest({
    Duration timeout = const Duration(seconds: 5),
  }) => _arrival.future.timeout(
    timeout,
    onTimeout: () =>
        throw TimeoutException('Timed out waiting for $description', timeout),
  );

  void release(http.Response response) {
    if (!_arrival.isCompleted) {
      throw StateError('$description has not arrived');
    }
    if (_response.isCompleted) {
      throw StateError('$description was already released');
    }
    _response.complete(response);
  }
}
