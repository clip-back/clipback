import 'package:flutter/services.dart';
import 'native_share_support_stub.dart'
    if (dart.library.io) 'native_share_support_io.dart';

/// The platform owns credentials, drafts, revisions and receipts durably.
class NativeShareService {
  NativeShareService({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel('com.huturu.app/share'),
      _enabled = enabled ?? nativeSharingAvailable;

  final MethodChannel _channel;
  final bool _enabled;
  bool get enabled => _enabled;

  Future<T?> invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    if (!_enabled) return null;
    return _channel.invokeMethod<T>(method, arguments);
  }
}
