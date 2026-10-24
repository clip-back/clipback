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
}
