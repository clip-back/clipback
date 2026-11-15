import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/photo_converter.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Uint8List _ftyp(String major, List<String> compatible) {
  final body = [
    ...ascii.encode('ftyp$major'),
    0,
    0,
    0,
    0,
    for (final brand in compatible) ...ascii.encode(brand),
  ];
  return Uint8List.fromList([0, 0, 0, body.length + 4, ...body, 1, 2, 3]);
}

const _session = ApiSession(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);

ClipbackApi _api(int status, Object detail) {
  final client = MockClient(
    (request) async => http.Response(
      jsonEncode({'detail': detail}),
      status,
      headers: {'content-type': 'application/json'},
    ),
  );
  addTearDown(client.close);
  return ClipbackApi(client: client)..restoreSession(_session);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isHeif reads the ISO BMFF ftyp brands, not the name', () {
    for (final (label, bytes, expected) in [
      ('major heic', _ftyp('heic', ['mif1', 'heic']), true),
      ('major heix', _ftyp('heix', []), true),
      ('major mif1', _ftyp('mif1', []), true),
      ('compatible heic only', _ftyp('isom', ['heic']), true),
      ('hevc sequence', _ftyp('hevc', []), true),
      ('avif is not HEIC', _ftyp('avif', ['mif1', 'miaf']), false),
      ('mp4', _ftyp('isom', ['mp41']), false),
      ('png', base64Decode('iVBORw0KGgo='), false),
      ('jpeg', Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), false),
      ('empty', Uint8List(0), false),
      (
        'truncated ftyp',
        Uint8List.fromList([0, 0, 0, 0x18, ...ascii.encode('ftyp')]),
        false,
      ),
    ]) {
      test(label, () => expect(isHeif(bytes), expected));
    }
  });

  group('jpegName', () {
    for (final (input, expected) in [
      ('IMG_0001.HEIC', 'IMG_0001.jpg'),
      ('photo.heif', 'photo.jpg'),
      ('a.b.heic', 'a.b.jpg'),
      ('photo', 'photo.jpg'),
      ('.heic', '.jpg'),
    ]) {
      test(input, () => expect(jpegName(input), expected));
    }
  });

  group('preparePhotoForUpload', () {
    const channel = MethodChannel('com.huturu.app/image');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final heic = _ftyp('heic', ['mif1', 'heic']);
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDB, 9, 9]);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test(
      'HEIC asks the platform for quality 90 JPEG and renames to .jpg',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return jpeg;
        });
        final photo = await preparePhotoForUpload(heic, 'IMG_0001.HEIC');
        expect(photo.bytes, orderedEquals(jpeg));
        expect(photo.name, 'IMG_0001.jpg');
        expect(calls.single.method, 'heicToJpeg');
        expect(calls.single.arguments, {'bytes': heic, 'quality': 90});
      },
    );

    final failures = <String, Future<Object?> Function(MethodCall)?>{
      'null result': (_) async => null,
      'platform error': (_) async => throw PlatformException(code: 'decode'),
      'no handler (old Android or missing plugin)': null,
      'non-JPEG result': (_) async => Uint8List.fromList([1, 2, 3]),
    };
    for (final MapEntry(key: label, value: handler) in failures.entries) {
      test(
        'conversion failure ($label) keeps the original bytes and name',
        () async {
          messenger.setMockMethodCallHandler(channel, handler);
          final photo = await preparePhotoForUpload(heic, 'IMG_0001.HEIC');
          expect(photo.bytes, same(heic));
          expect(photo.name, 'IMG_0001.HEIC');
        },
      );
    }

    test('PNG, JPEG and WebP are never sent to the converter', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return jpeg;
      });
      for (final (name, bytes) in [
        ('a.png', base64Decode('iVBORw0KGgo=')),
        ('a.jpg', jpeg),
        (
          'a.webp',
          Uint8List.fromList([
            ...ascii.encode('RIFF'),
            0,
            0,
            0,
            0,
            ...ascii.encode('WEBP'),
          ]),
        ),
        // Name says HEIC but the bytes are PNG: bytes decide.
        ('a.HEIC', base64Decode('iVBORw0KGgo=')),
      ]) {
        final photo = await preparePhotoForUpload(bytes, name);
        expect(photo.bytes, same(bytes));
        expect(photo.name, name);
      }
      expect(calls, 0);
    });
  });

  group('photo save 415 message', () {
    test(
      'photo upload 415 shows the Korean supported-format message',
      () async {
        final api = _api(415, 'Unsupported or invalid screenshot image');
        await expectLater(
          api.uploadScreenshot(
            bytes: Uint8List.fromList([1]),
            filename: 'a.heic',
          ),
          throwsA(
            isA<ClipbackApiException>()
                .having(
                  (e) => e.message,
                  'message',
                  'PNG, JPEG, WebP 이미지만 지원합니다.',
                )
                .having((e) => e.statusCode, 'statusCode', 415),
          ),
        );
      },
    );

    for (final (status, detail, message) in [
      (413, 'too large', '이미지는 10MiB 이하만 저장할 수 있습니다.'),
      (500, 'Injected 500 failure', 'Injected 500 failure'),
      (503, 'Injected 503 failure', 'Injected 503 failure'),
    ]) {
      test('photo upload $status keeps its existing message', () async {
        final api = _api(status, detail);
        await expectLater(
          api.uploadScreenshot(
            bytes: Uint8List.fromList([1]),
            filename: 'a.png',
          ),
          throwsA(
            isA<ClipbackApiException>().having(
              (e) => e.message,
              'message',
              message,
            ),
          ),
        );
      });
    }

    test('link save 415 keeps the server message', () async {
      final api = _api(415, 'Unsupported media');
      await expectLater(
        api.createContent(
          originalUrl: 'https://example.com',
          categoryIds: const [],
        ),
        throwsA(
          isA<ClipbackApiException>().having(
            (e) => e.message,
            'message',
            'Unsupported media',
          ),
        ),
      );
    });
  });

  // SaveErrorToast has no font family of its own. Under the app theme
  // (clipback_app.dart: the platform textTheme with Pretendard applied, #391)
  // it inherits Pretendard, so this measures the merged theme rather than the
  // Pretendard test wrapper. Pretendard is not loaded here; the square test
  // glyphs are at least as wide as Latin and Hangul glyphs, a conservative
  // width. Each scale is its own test because Flutter reports one overflow
  // per widget.
  for (final scale in [1.0, 1.3]) {
    testWidgets(
      '415 format message fits a 320pt toast at text scale $scale under the app theme',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          Builder(
            builder: (context) {
              final textTheme = Theme.of(context).textTheme.apply(
                fontFamily: 'Pretendard',
                bodyColor: AppColors.text,
                displayColor: AppColors.text,
              );
              return MaterialApp(
                theme: ThemeData(
                  useMaterial3: true,
                  fontFamily: 'Pretendard',
                  textTheme: textTheme,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 640),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const Material(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        // The save screen's toast slot (save_content_screen.dart).
                        padding: EdgeInsets.fromLTRB(40, 0, 40, 16),
                        child: SaveErrorToast(
                          message: 'PNG, JPEG, WebP 이미지만 지원합니다.',
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text('PNG, JPEG, WebP 이미지만 지원합니다.'),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.text.style?.fontFamily, 'Pretendard');
        expect(paragraph.textScaler.scale(1), scale);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.getRect(find.byType(SaveErrorToast)).width, 240);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
