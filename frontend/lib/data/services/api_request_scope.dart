import 'dart:async';

/// A short-lived group of requests. Cancellation also rejects late responses
/// when a transport (such as a test client) cannot abort its pending work.
class ApiRequestScope {
  ApiRequestScope({Duration? timeout}) {
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

  final _cancelled = Completer<void>();
  Timer? _timer;
  Object? _reason;

  bool get isActive => _reason == null;
  Future<void> get cancelled => _cancelled.future;

  void checkActive() {
    if (_reason case final reason?) throw reason;
  }

  void cancel([Object? reason]) {
    if (!isActive) return;
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
