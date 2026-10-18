// Memory fixture contract only. Native preparation also checks this ownership
// pair; a mismatched fixture must not be mistaken for a product navigation bug.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/notice_alignment_fixture.dart' as fixture;

Future<void> _expectOwner(fixture.NoticeServer server, int expectedId) async {
  final profile =
      jsonDecode(
            (await server.client.get(
              Uri.parse('https://example.invalid/api/v1/users/me'),
            )).body,
          )
          as Map;
  final credential =
      jsonDecode(
            (await server.client.post(
              Uri.parse('https://example.invalid/api/v1/auth/share-credential'),
            )).body,
          )
          as Map;
  expect(profile['id'], expectedId);
  expect(credential['user_id'], profile['id']);
  expect(credential['session_id'], isA<int>());
  expect(DateTime.parse(credential['expires_at'] as String).year, 2030);
  expect(credential['share_token'], isA<String>());
  expect(server.unexpected, isEmpty);
}

void main() {
  for (final kind in ['member', 'guest']) {
    test(
      '$kind memory profile and share credential have the same owner',
      () async {
        final server = fixture.NoticeServer(kind);
        addTearDown(server.client.close);
        await _expectOwner(server, kind == 'guest' ? 2 : 1);
      },
    );
  }
  test(
    'member fixture switches both profile and share credential ownership after guest creation',
    () async {
      final server = fixture.NoticeServer('member');
      addTearDown(server.client.close);
      await _expectOwner(server, 1);
      await server.client.post(
        Uri.parse('https://example.invalid/api/v1/auth/guest'),
      );
      expect(server.kind, 'guest');
      await _expectOwner(server, 2);
    },
  );
}
