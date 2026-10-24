import 'dart:convert';
import 'dart:typed_data';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final error in [
    (
      409,
      {'code': 'image_uploads_paused'},
      '이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.',
    ),
    (
      409,
      {'code': 'image_quota_exceeded'},
      '이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요.',
    ),
    (
      413,
      'Screenshot file exceeds the configured size limit',
      '이미지는 10MiB 이하만 저장할 수 있습니다.',
    ),
  ]) {
    test(
      'upload ${error.$1} ${error.$2} shows the specific reason and keeps the session',
      () async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({'detail': error.$2}),
            error.$1,
            headers: {'content-type': 'application/json'},
          ),
        );
        addTearDown(client.close);
        final api = ClipbackApi(client: client)
          ..restoreSession(
            const ApiSession(
              accessToken: 'test-access',
              refreshToken: 'test-refresh',
              expiresIn: 3600,
              refreshExpiresIn: 86400,
            ),
          );
        await expectLater(
          api.uploadScreenshot(
            bytes: Uint8List.fromList([1]),
            filename: 'image.png',
          ),
          throwsA(
            isA<ClipbackApiException>()
                .having((e) => e.message, 'message', error.$3)
                .having((e) => e.statusCode, 'statusCode', error.$1),
          ),
        );
        expect(api.session?.accessToken, 'test-access');
      },
    );
  }
}
