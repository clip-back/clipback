import 'dart:async';

/// A short-lived group of requests. Cancellation also rejects late responses
/// when a transport (such as a test client) cannot abort its pending work.
class ApiRequestScope {
  ApiRequestScope({Duration? timeout, bool Function()? isCurrent})
    : _isCurrent = isCurrent {
    if (timeout != null) {
      _timer = Timer(
        timeout,
        () => cancel(TimeoutException('Request timed out')),
      );
    }
  }

  static final _zoneKey = Object();
  static ApiRequestScope? get current =>
      Zone.current[_zoneKey] as ApiRequestScope?;

  final bool Function()? _isCurrent;
  final _cancelled = Completer<void>();
  Timer? _timer;
  Object? _reason;

  bool get isActive {
    if (_reason == null && _isCurrent?.call() == false) cancel();
    return _reason == null;
  }

  Future<void> get cancelled => _cancelled.future;

  void checkActive() {
    if (!isActive) throw _reason!;
  }

  void cancel([Object? reason]) {
    if (_reason != null) return;
    _reason = reason ?? StateError('Request scope ended');
    _timer?.cancel();
    _cancelled.complete();
  }

  Future<T> run<T>(Future<T> Function() operation) => runZoned(() {
    checkActive();
    return operation();
  }, zoneValues: {_zoneKey: this});

  Future<T> wait<T>(Future<T> operation) {
    checkActive();
    return Future.any([operation, cancelled.then<T>((_) => throw _reason!)]);
  }

  /// Runs [operation] in this scope and ends the scope after judging how it
  /// ended. A request that is no longer current is stale even if it failed.
  Future<RequestOutcome<T>> settle<T>(Future<T> Function() operation) async {
    RequestOutcome<T> outcome;
    try {
      final value = await run(() => wait(operation()));
      outcome = _isCurrent?.call() == false
          ? RequestStale<T>()
          : RequestSucceeded<T>(value);
    } catch (error) {
      outcome = _isCurrent?.call() == false
          ? RequestStale<T>()
          : RequestFailed<T>(error);
    }
    cancel();
    return outcome;
  }
}

/// How a request ended: its value, a late response, or its error.
sealed class RequestOutcome<T> {
  const RequestOutcome();
}

final class RequestSucceeded<T> extends RequestOutcome<T> {
  const RequestSucceeded(this.value);

  final T value;
}

final class RequestStale<T> extends RequestOutcome<T> {
  const RequestStale();
}

final class RequestFailed<T> extends RequestOutcome<T> {
  const RequestFailed(this.error);

  final Object error;
}
