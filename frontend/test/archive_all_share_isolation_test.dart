import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/archive_all_preview.dart';

class _Delegate extends BinaryMessenger {
  final sent = <String>[];
  final handled = <String>[];
  @override
  Future<ByteData?>? send(String channel, ByteData? message) async {
    sent.add(channel);
    return message;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    handled.add(channel);
  }

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) async {}
}

void main() {
  const codec = StandardMethodCodec();
  test(
    'preview share reads and credential operations stay in memory',
    () async {
      final delegate = _Delegate();
      final isolated = ArchiveAllShareMessenger(delegate);
      Future<Object?> call(String method, [Object? args]) async =>
          codec.decodeEnvelope(
            (await isolated.send(
              ArchiveAllShareMessenger.shareChannel,
              codec.encodeMethodCall(MethodCall(method, args)),
            ))!,
          );
      expect(await call('getState'), {
        'revision': 0,
        'drafts': [],
        'receipts': [],
      });
      expect(await call('blockCredential'), 1);
      expect(await call('publishCredential', {'revision': 0}), isFalse);
      expect(await call('publishCredential', {'revision': 1}), isTrue);
      expect(await call('presentDraft', {'id': 'fixture'}), isNull);
      expect(await call('acknowledgeReceipts', {'ids': []}), isNull);
      expect((await call('getState') as Map)['drafts'], isEmpty);
      expect(delegate.sent, isEmpty);
      expect(isolated.nativeDelegationCount, 0);
      expect(isolated.unknownShareMethods, isEmpty);
      expect(isolated.namesOnlyCalls, contains('publishCredential'));
    },
  );
  test(
    'unsupported share method cannot escape to retained native data',
    () async {
      final delegate = _Delegate();
      final isolated = ArchiveAllShareMessenger(delegate);
      final result = await isolated.send(
        ArchiveAllShareMessenger.shareChannel,
        codec.encodeMethodCall(const MethodCall('unexpected')),
      );
      expect(
        () => codec.decodeEnvelope(result!),
        throwsA(isA<PlatformException>()),
      );
      expect(isolated.unknownShareMethods, ['unexpected']);
      expect(isolated.delegatedChannels, isEmpty);
      expect(delegate.sent, isEmpty);
    },
  );
  test('real IME and other channels retain their messenger', () async {
    final delegate = _Delegate();
    final messenger = ArchiveAllShareMessenger(delegate);
    final bytes = codec.encodeMethodCall(const MethodCall('TextInput.hide'));
    expect(await messenger.send('flutter/textinput', bytes), same(bytes));
    messenger.setMessageHandler('flutter/textinput', null);
    expect(delegate.sent, ['flutter/textinput']);
    expect(delegate.handled, ['flutter/textinput']);
    expect(messenger.nativeDelegationCount, 0);
    expect(messenger.namesOnlyCalls, isEmpty);
  });
}
