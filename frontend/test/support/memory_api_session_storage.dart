import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';

class MemoryApiSessionStorage extends ApiSessionStorage {
  ApiSession? session = const ApiSession(
    accessToken: 'test-access',
    refreshToken: 'test-refresh',
    expiresIn: 3600,
    refreshExpiresIn: 86400,
  );
  int writes = 0, clears = 0;
  Completer<void>? writeGate;

  @override
  Future<ApiSession?> read() async => session;

  @override
  Future<void> write(ApiSession value) async {
    writes++;
    final gate = writeGate;
    if (gate != null) await gate.future;
    session = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    session = null;
  }
}
