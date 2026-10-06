import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/main.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _assetPath = '/api/v1/uploads/assets/9';
const _storageWarning = '로그인 정보를 기기에 저장하지 못했어요. 앱을 종료하기 전에 다시 저장해 주세요.';
const _category = {
  'id': 101,
  'name': '공부',
  'color': '#059669',
  'is_default': false,
  'content_count': 1,
  'last_saved_at': '2026-10-06T00:00:00Z',
};
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final Uint8List _portraitPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAQCAIAAACk6KkqAAAAGUlEQVR4nGOUrLjDgA0'
  'wYRVlGJXAAqgYVgBRYQGNcB1eZgAAAABJRU5ErkJggg==',
);
final Uint8List _landscapeJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8U'
  'HRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgN'
  'DRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy'
  'MjIyMjIyMjIyMjL/wAARCAAIABADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAE'
  'CAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKB'
  'kaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZ'
  'WmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5'
  'usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQE'
  'BAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBh'
  'JBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZH'
  'SElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanq'
  'KmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADA'
  'MBAAIRAxEAPwDGooor7s+NP//Z',
);
final Uint8List _squareWebp = base64Decode(
  'UklGRjwAAABXRUJQVlA4IDAAAAAwAgCdASoIAAgAAUAmJaACdLoB+AH4AAShAAD+7Qcv'
  '/YOmDLn+K9/6nBg58/H+AAA=',
);

Map<String, Object?> _content({
  int id = 7,
  int assetId = 9,
  bool screenshot = true,
  String mime = 'image/png',
}) => {
  'id': id,
  'categories': [_category],
  'tags': <Object>[],
  'assets': screenshot
      ? [
          {
            'id': assetId,
            'asset_type': 'screenshot',
            'download_url': '/api/v1/uploads/assets/$assetId',
            'mime_type': mime,
          },
        ]
      : <Object>[],
  'content_type': screenshot ? 'screenshot' : 'link',
  'source': screenshot ? 'screenshot' : 'web',
  'title': '저장한 테스트 사진 $id',
  'summary': '스크린샷 테스트',
  'original_url': screenshot ? null : 'https://example.com/original',
  'is_favorite': false,
  'saved_at': '2026-10-06T00:00:00Z',
  'last_viewed_at': null,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Server {
  _Server({this.respond, this.saved = true});

  final Future<http.Response?> Function(http.BaseRequest)? respond;
  final calls = <http.BaseRequest>[];
  bool saved;
  final contents = [_content()];
  late final client = MockClient.streaming((request, stream) async {
    await stream.toBytes();
    calls.add(request);
    final response = await respond?.call(request) ?? _default(request);
    if (request.url.path == '/api/v1/uploads/screenshots' &&
        response.statusCode == 201) {
      saved = true;
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  });

  http.Response _default(http.BaseRequest request) {
    final path = request.url.path;
    switch (path) {
      case '/api/v1/uploads/screenshots':
        return _json(contents.first, 201);
      case '/api/v1/auth/refresh':
      case '/api/v1/auth/guest':
        return _json({
          'access_token': 'replacement-access',
          'refresh_token': 'replacement-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        });
      case '/api/v1/auth/logout':
        return http.Response('', 204);
      case '/api/v1/categories':
        return _json([_category]);
      case '/api/v1/feed':
        return _json({
          'items': saved ? contents : <Object>[],
          'next_cursor': null,
        });
      case '/api/v1/users/me':
        return _json({
          'id': 1,
          'email': null,
          'display_name': '테스트 계정',
          'is_guest': true,
          'created_at': '2026-10-06T00:00:00Z',
          'linked_providers': <String>[],
        });
      case '/api/v1/users/me/stats':
        return _json({
          'saved_count': saved ? contents.length : 0,
          'reopened_count': 0,
        });
      case '/api/v1/metrics/events':
        return _json(<String, Object>{}, 201);
    }
    if (path.startsWith('/api/v1/uploads/assets/')) {
      return http.Response.bytes(
        _png,
        200,
        headers: {'content-type': 'image/png'},
      );
    }
    if (path.endsWith('/view')) return _json(<String, Object>{}, 201);
    if (path.startsWith('/api/v1/contents/')) {
      final id = int.parse(path.split('/')[4]);
      return _json(contents.singleWhere((item) => item['id'] == id));
    }
    throw StateError('Unexpected request: ${request.method} $path');
  }

  List<http.BaseRequest> at(String path) =>
      calls.where((call) => call.url.path == path).toList();
}

class _Picker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'screen.png', size: _png.length, bytes: _png),
  ]);
}

class _Storage extends ApiSessionStorage {
  bool failWrite = true;
  final writes = <ApiSession>[];

  @override
  Future<void> write(ApiSession session) async {
    writes.add(session);
    if (failWrite) throw StateError('Storage write unavailable');
    await super.write(session);
  }
}

Future<void> _withApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check, {
  ApiSessionStorage? storage,
}) async {
  SharedPreferences.setMockInitialValues({
    'clipback.session': jsonEncode({
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
      'expires_in': 3600,
      'refresh_expires_in': 86400,
    }),
  });
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        Theme(
          data: ThemeData(fontFamily: 'Pretendard'),
          child: ClipbackApp(sessionStorage: storage),
        ),
      );
      await tester.pumpAndSettle();
      await check();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _openFirst(WidgetTester tester) async {
  final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
  home.onOpenContent(home.contents.first);
  await tester.pumpAndSettle();
}

Finder get _memoryImages => find.byWidgetPredicate(
  (widget) => widget is Image && widget.image is MemoryImage,
);

Future<void> _expandOriginal(WidgetTester tester) async {
  final toggle = find.text('원본 이미지 보기');
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _openOriginalSheet(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final button = find.descendant(
    of: find.byType(DetailScreen),
    matching: find.byWidgetPredicate(
      (widget) => widget is SvgIconButton && widget.asset == Assets.link,
    ),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _beginOriginal(WidgetTester tester) async {
  await tester.tap(find.text('원본 이미지 보기'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _finishImageDecode(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final image in tester.widgetList<Image>(_memoryImages)) {
      final completed = Completer<void>();
      final stream = image.image.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (info, _) {
          info.dispose();
          if (!completed.isCompleted) completed.complete();
        },
        onError: (Object error, StackTrace? stackTrace) {
          if (!completed.isCompleted) {
            completed.completeError(error, stackTrace);
          }
        },
      );
      stream.addListener(listener);
      try {
        await completed.future;
      } finally {
        stream.removeListener(listener);
      }
    }
  });
  await tester.pumpAndSettle();
}

void _expectOriginalBytes(
  WidgetTester tester,
  Uint8List bytes, {
  int count = 1,
}) {
  expect(_memoryImages, findsNWidgets(count));
  for (final image in tester.widgetList<Image>(_memoryImages)) {
    expect((image.image as MemoryImage).bytes, orderedEquals(bytes));
    expect(image.fit, BoxFit.contain);
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    Theme(
      data: ThemeData(fontFamily: 'Pretendard'),
      child: const ClipbackApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    FilePickerIO.registerWith();
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  testWidgets('saved screenshot keeps its original after reopening detail', (
    tester,
  ) async {
    final server = _Server(saved: false);
    final previousPicker = FilePicker.platform;
    FilePicker.platform = _Picker();
    addTearDown(() => FilePicker.platform = previousPicker);
    await _withApp(tester, server, () async {
      final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      unawaited(
        showContentSaveScreen(
          context: tester.element(find.byType(HomeScreen)),
          onAddLink: home.onAddLink,
          onAddScreenshot: home.onAddScreenshot,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 첨부'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('허투루에 저장하기'));
      await tester.pumpAndSettle();
      expect(find.byType(SavedContentConfirmation), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
      await tester.pumpAndSettle();
      await _openFirst(tester);
      expect(find.text('원본 이미지 보기'), findsOneWidget);
      expect(server.at(_assetPath), isEmpty);
      await _expandOriginal(tester);
      _expectOriginalBytes(tester, _png);
      expect(server.at(_assetPath), hasLength(1));
    });
  });

  testWidgets(
    'API assets survive feed/detail mapping and ContentItem copyWith',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        final item = home.contents.single;
        expect(item.assets.single.id, 9);
        expect(item.assets.single.assetType, 'screenshot');
        expect(item.assets.single.downloadUrl, _assetPath);
        expect(item.assets.single.mimeType, 'image/png');
        final copied = item.copyWith(
          category: catUncategorized,
          bookmarked: true,
        );
        expect(copied.assets, same(item.assets));
        expect(copied.bookmarked, isTrue);
        await _openFirst(tester);
        final detail = tester.widget<DetailScreen>(find.byType(DetailScreen));
        expect(detail.content.assets.single.id, 9);
        expect(server.at(_assetPath), isEmpty);
      });
    },
  );

  test('ContentItem keeps an empty assets default for existing callers', () {
    final item = ContentItem(
      id: 'link',
      title: 'Link',
      summary: 'Summary',
      category: catUncategorized,
      savedAt: '',
      savedAtFull: '',
      savedAtFullShort: '',
      tags: const [],
      source: '웹',
      originalUrl: 'https://example.com',
      originalText: '',
    );
    expect(item.assets, isEmpty);
    expect(item.copyWith(bookmarked: true).assets, isEmpty);
  });

  testWidgets(
    'detail and original sheet share one lazy authenticated download',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        expect(_memoryImages, findsNothing);
        expect(server.at(_assetPath), isEmpty);
        final views = server.at('/api/v1/contents/7/view').length;
        final events = server.at('/api/v1/metrics/events').length;
        await _expandOriginal(tester);
        _expectOriginalBytes(tester, _png);
        await _openOriginalSheet(tester);
        expect(find.text('원본 이미지'), findsOneWidget);
        expect(server.at(_assetPath), hasLength(1));
        expect(server.at(_assetPath).single.method, 'GET');
        expect(
          server.at(_assetPath).single.headers['Authorization'],
          'Bearer test-access',
        );
        _expectOriginalBytes(tester, _png, count: 2);
        expect(server.at('/api/v1/contents/7/view'), hasLength(views));
        expect(server.at('/api/v1/metrics/events'), hasLength(events));
        Navigator.of(tester.element(find.byType(OriginalContentSheet))).pop();
        await tester.pumpAndSettle();
        _expectOriginalBytes(tester, _png);
      });
    },
  );

  testWidgets('sheet first also shares its download with the detail toggle', (
    tester,
  ) async {
    final server = _Server();
    await _withApp(tester, server, () async {
      await _openFirst(tester);
      await _openOriginalSheet(tester);
      expect(find.text('원본 이미지'), findsOneWidget);
      _expectOriginalBytes(tester, _png);
      Navigator.of(tester.element(find.byType(OriginalContentSheet))).pop();
      await tester.pumpAndSettle();
      await _expandOriginal(tester);
      _expectOriginalBytes(tester, _png);
      expect(server.at(_assetPath), hasLength(1));
    });
  });

  testWidgets(
    'restarted app lazily retrieves the saved original without a new guest',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        await _expandOriginal(tester);
        expect(server.at(_assetPath), hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        SharedPreferences.resetStatic();
        await _pumpApp(tester);
        await _openFirst(tester);
        expect(server.at(_assetPath), hasLength(1));
        expect(_memoryImages, findsNothing);
        await _expandOriginal(tester);
        _expectOriginalBytes(tester, _png);
        expect(server.at(_assetPath), hasLength(2));
        expect(server.at('/api/v1/auth/guest'), isEmpty);
      });
    },
  );

  for (final fixture in [
    (
      name: 'portrait PNG',
      bytes: _portraitPng,
      mime: 'image/png',
      width: 8,
      height: 16,
    ),
    (
      name: 'landscape JPEG',
      bytes: _landscapeJpeg,
      mime: 'image/jpeg',
      width: 16,
      height: 8,
    ),
    (
      name: 'square WebP',
      bytes: _squareWebp,
      mime: 'image/webp',
      width: 8,
      height: 8,
    ),
  ]) {
    testWidgets(
      '${fixture.name} displays uncropped original pixels at its aspect ratio',
      (tester) async {
        final server = _Server(
          respond: (request) async => request.url.path == _assetPath
              ? http.Response.bytes(
                  fixture.bytes,
                  200,
                  headers: {'content-type': fixture.mime},
                )
              : null,
        );
        server.contents[0] = _content(mime: fixture.mime);
        await _withApp(tester, server, () async {
          await _openFirst(tester);
          await _expandOriginal(tester);
          _expectOriginalBytes(tester, fixture.bytes);
          await _finishImageDecode(tester);
          final raw = tester.widget<RawImage>(
            find.descendant(of: _memoryImages, matching: find.byType(RawImage)),
          );
          expect(raw.image?.width, fixture.width);
          expect(raw.image?.height, fixture.height);
          expect(raw.fit, BoxFit.contain);
          final rendered = tester.getSize(
            find.descendant(of: _memoryImages, matching: find.byType(RawImage)),
          );
          expect(
            rendered.width / rendered.height,
            closeTo(fixture.width / fixture.height, 0.001),
          );
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  for (final failure in [
    '403',
    '404',
    '503',
    '401',
    'network',
    'empty bytes',
    'decode',
  ]) {
    testWidgets(
      '$failure original failure retries only the download in the same account',
      (tester) async {
        var fail = true;
        final server = _Server(
          respond: (request) async {
            if (request.url.path != _assetPath || !fail) return null;
            if (failure == 'network') throw http.ClientException('Offline');
            if (failure == 'empty bytes') return http.Response.bytes([], 200);
            if (failure == 'decode') return http.Response.bytes([1, 2, 3], 200);
            return _json({'detail': 'Injected failure'}, int.parse(failure));
          },
        );
        await _withApp(tester, server, () async {
          await _openFirst(tester);
          await _expandOriginal(tester);
          final message = switch (failure) {
            '404' => '원본 이미지를 찾을 수 없어요.',
            'decode' || 'empty bytes' => '원본 이미지를 표시하지 못했어요.',
            _ => '원본 이미지를 불러오지 못했어요.',
          };
          expect(find.text(message), findsOneWidget);
          expect(_memoryImages, findsNothing);
          expect(find.byType(DetailScreen), findsOneWidget);
          expect(server.at('/api/v1/auth/guest'), isEmpty);
          expect(
            server.at('/api/v1/auth/refresh'),
            hasLength(failure == '401' ? 1 : 0),
          );
          expect(server.at(_assetPath), hasLength(failure == '401' ? 2 : 1));
          fail = false;
          await tester.tap(find.text('다시 시도'));
          await tester.pumpAndSettle();
          _expectOriginalBytes(tester, _png);
          expect(server.at(_assetPath), hasLength(failure == '401' ? 3 : 2));
          expect(server.at('/api/v1/auth/guest'), isEmpty);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets('missing screenshot asset is explicit and does not download', (
    tester,
  ) async {
    final server = _Server();
    server.contents.single['assets'] = <Object>[];
    await _withApp(tester, server, () async {
      await _openFirst(tester);
      await _expandOriginal(tester);
      expect(find.text('저장된 원본 이미지가 없어요.'), findsOneWidget);
      expect(server.at(_assetPath), isEmpty);
      expect(_memoryImages, findsNothing);
      await _openOriginalSheet(tester);
      expect(find.text('원본 이미지'), findsOneWidget);
      expect(find.text('저장된 원본 이미지가 없어요.'), findsNWidgets(2));
      expect(server.at(_assetPath), isEmpty);
    });
  });

  testWidgets(
    'original refresh keeps working after token storage fails and retry saves only storage',
    (tester) async {
      final storage = _Storage();
      final server = _Server(
        respond: (request) async =>
            request.url.path == _assetPath &&
                request.headers['Authorization'] == 'Bearer test-access'
            ? _json({'detail': 'Invalid or expired token'}, 401)
            : null,
      );
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        expect(storage.writes, isEmpty);
        await _expandOriginal(tester);
        _expectOriginalBytes(tester, _png);
        expect(find.text(_storageWarning), findsOneWidget);
        expect(storage.writes.single.accessToken, 'replacement-access');
        expect(storage.writes.single.refreshToken, 'replacement-refresh');
        expect(
          server.at(_assetPath).map((call) => call.headers['Authorization']),
          ['Bearer test-access', 'Bearer replacement-access'],
        );
        expect(server.at('/api/v1/auth/refresh'), hasLength(1));
        expect(server.at('/api/v1/auth/guest'), isEmpty);
        expect((await ApiSessionStorage().read())?.accessToken, 'test-access');
        final callsBeforeRetry = server.calls.length;
        storage.failWrite = false;
        await tester.tap(find.text('다시 저장'));
        await tester.pumpAndSettle();
        expect(find.text(_storageWarning), findsNothing);
        _expectOriginalBytes(tester, _png);
        expect(storage.writes, hasLength(2));
        SharedPreferences.resetStatic();
        final persisted = await ApiSessionStorage().read();
        expect(persisted?.accessToken, 'replacement-access');
        expect(persisted?.refreshToken, 'replacement-refresh');
        expect(server.calls, hasLength(callsBeforeRetry));
        expect(server.at(_assetPath), hasLength(2));
        expect(server.at('/api/v1/auth/refresh'), hasLength(1));
        expect(server.at('/api/v1/auth/guest'), isEmpty);
        expect(tester.takeException(), isNull);
      }, storage: storage);
    },
  );

  testWidgets(
    'web link retains its original text and URL without an image request',
    (tester) async {
      final server = _Server();
      server.contents[0] = _content(screenshot: false);
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        expect(find.text('원본 이미지 보기'), findsNothing);
        expect(find.text('전문 보기'), findsOneWidget);
        await _openOriginalSheet(tester);
        expect(find.text('원문 보기'), findsOneWidget);
        expect(find.text('https://example.com/original'), findsWidgets);
        expect(server.at(_assetPath), isEmpty);
      });
    },
  );

  testWidgets(
    'two open image surfaces share an in-flight download and loading state',
    (tester) async {
      final response = Completer<http.Response>();
      final server = _Server(
        respond: (request) async =>
            request.url.path == _assetPath ? response.future : null,
      );
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        await _beginOriginal(tester);
        expect(find.text('원본 이미지를 불러오는 중이에요.'), findsOneWidget);
        expect(server.at(_assetPath), hasLength(1));
        await _openOriginalSheet(tester, settle: false);
        expect(find.text('원본 이미지를 불러오는 중이에요.'), findsNWidgets(2));
        expect(server.at(_assetPath), hasLength(1));
        response.complete(http.Response.bytes(_png, 200));
        await tester.pumpAndSettle();
        _expectOriginalBytes(tester, _png, count: 2);
        expect(find.text('원본 이미지를 불러오는 중이에요.'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'closing a loading original sheet keeps the shared detail request',
    (tester) async {
      final response = Completer<http.Response>();
      final server = _Server(
        respond: (request) async =>
            request.url.path == _assetPath ? response.future : null,
      );
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        await _openOriginalSheet(tester, settle: false);
        Navigator.of(tester.element(find.byType(OriginalContentSheet))).pop();
        await tester.pump(const Duration(milliseconds: 400));
        await _beginOriginal(tester);
        expect(server.at(_assetPath), hasLength(1));
        response.complete(http.Response.bytes(_png, 200));
        await tester.pumpAndSettle();
        _expectOriginalBytes(tester, _png);
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final result in ['success', 'failure']) {
    testWidgets('back navigation ignores a late original $result', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      var downloads = 0;
      final server = _Server(
        respond: (request) async {
          if (request.url.path != _assetPath) return null;
          downloads++;
          return downloads == 1
              ? response.future
              : http.Response.bytes(_portraitPng, 200);
        },
      );
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        await _beginOriginal(tester);
        tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        await _openFirst(tester);
        expect(_memoryImages, findsNothing);
        response.complete(
          result == 'success'
              ? http.Response.bytes(_png, 200)
              : _json({'detail': 'Delayed failure'}, 503),
        );
        await tester.pumpAndSettle();
        expect(_memoryImages, findsNothing);
        expect(find.text('원본 이미지를 불러오지 못했어요.'), findsNothing);
        await _expandOriginal(tester);
        _expectOriginalBytes(tester, _portraitPng);
        expect(server.at(_assetPath), hasLength(2));
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('adjacent detail ignores previous content original $result', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _assetPath) return response.future;
          if (request.url.path == '/api/v1/uploads/assets/10') {
            return http.Response.bytes(_portraitPng, 200);
          }
          return null;
        },
      );
      server.contents.add(_content(id: 8, assetId: 10));
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        await _beginOriginal(tester);
        tester
            .widget<DetailScreen>(find.byType(DetailScreen))
            .onOpenAdjacent(1);
        await tester.pumpAndSettle();
        expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).content.apiId,
          8,
        );
        response.complete(
          result == 'success'
              ? http.Response.bytes(_png, 200)
              : _json({'detail': 'Delayed failure'}, 503),
        );
        await tester.pumpAndSettle();
        expect(_memoryImages, findsNothing);
        expect(find.text('원본 이미지를 불러오지 못했어요.'), findsNothing);
        await _expandOriginal(tester);
        _expectOriginalBytes(tester, _portraitPng);
        expect(server.at('/api/v1/uploads/assets/10'), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets(
    'detail asset replacement closes its sheet and ignores old bytes',
    (tester) async {
      final assetResponse = Completer<http.Response>();
      final detailResponse = Completer<http.Response>();
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _assetPath) return assetResponse.future;
          if (request.url.path == '/api/v1/contents/7') {
            return detailResponse.future;
          }
          if (request.url.path == '/api/v1/uploads/assets/10') {
            return http.Response.bytes(_portraitPng, 200);
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        await _beginOriginal(tester);
        await _openOriginalSheet(tester, settle: false);
        detailResponse.complete(_json(_content(assetId: 10)));
        await tester.pumpAndSettle();
        expect(find.byType(OriginalContentSheet), findsNothing);
        expect(
          tester
              .widget<DetailScreen>(find.byType(DetailScreen))
              .content
              .assets
              .single
              .id,
          10,
        );
        expect(_memoryImages, findsNothing);
        expect(find.text('원본 이미지를 불러오는 중이에요.'), findsNothing);
        assetResponse.complete(http.Response.bytes(_png, 200));
        await tester.pumpAndSettle();
        expect(_memoryImages, findsNothing);
        await _expandOriginal(tester);
        _expectOriginalBytes(tester, _portraitPng);
        expect(server.at(_assetPath), hasLength(1));
        expect(server.at('/api/v1/uploads/assets/10'), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'late old-account original does not appear in a new guest detail',
    (tester) async {
      final response = Completer<http.Response>();
      final server = _Server(
        respond: (request) async {
          if (request.url.path == _assetPath) return response.future;
          if (request.url.path == '/api/v1/uploads/assets/10') {
            return http.Response.bytes(_portraitPng, 200);
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        await _beginOriginal(tester);
        tester
            .widget<DetailScreen>(find.byType(DetailScreen))
            .onTab(AppRoute.my);
        await tester.pumpAndSettle();
        tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
        await tester.pumpAndSettle();
        unawaited(
          tester
              .widget<AccountManagementScreen>(
                find.byType(AccountManagementScreen),
              )
              .onLogout(),
        );
        await tester.pumpAndSettle();
        server.contents[0] = _content(id: 8, assetId: 10);
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        unawaited(
          home.onAddScreenshot(bytes: _png, filename: 'new-account.png'),
        );
        await tester.pumpAndSettle();
        expect(server.at('/api/v1/auth/guest'), hasLength(1));
        expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).content.apiId,
          8,
        );
        response.complete(http.Response.bytes(_png, 200));
        await tester.pumpAndSettle();
        expect(_memoryImages, findsNothing);
        expect(find.text('원본 이미지를 불러오지 못했어요.'), findsNothing);
        await _expandOriginal(tester);
        _expectOriginalBytes(tester, _portraitPng);
        expect(
          server
              .at('/api/v1/uploads/assets/10')
              .single
              .headers['Authorization'],
          'Bearer replacement-access',
        );
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'collapsing and reopening keeps the original cached only in its detail',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _openFirst(tester);
        await _expandOriginal(tester);
        _expectOriginalBytes(tester, _png);
        await _expandOriginal(tester);
        expect(_memoryImages, findsNothing);
        await _expandOriginal(tester);
        _expectOriginalBytes(tester, _png);
        expect(server.at(_assetPath), hasLength(1));
        tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
        await tester.pumpAndSettle();
        await _openFirst(tester);
        expect(_memoryImages, findsNothing);
        await _expandOriginal(tester);
        expect(server.at(_assetPath), hasLength(2));
      });
    },
  );

  for (final destination in ['home', 'adjacent']) {
    testWidgets(
      'opening original sheet then navigating $destination before its first frame is cancelled',
      (tester) async {
        final server = _Server();
        server.contents.add(_content(id: 8, assetId: 10));
        await _withApp(tester, server, () async {
          await _openFirst(tester);
          final detail = tester.widget<DetailScreen>(find.byType(DetailScreen));
          final button = tester.widget<SvgIconButton>(
            find.descendant(
              of: find.byType(DetailScreen),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is SvgIconButton && widget.asset == Assets.link,
              ),
            ),
          );
          button.onPressed();
          if (destination == 'home') {
            detail.onBack();
          } else {
            detail.onOpenAdjacent(1);
          }
          await tester.pumpAndSettle();
          expect(find.byType(OriginalContentSheet), findsNothing);
          expect(_memoryImages, findsNothing);
          if (destination == 'home') {
            expect(find.byType(HomeScreen), findsOneWidget);
          } else {
            expect(
              tester
                  .widget<DetailScreen>(find.byType(DetailScreen))
                  .content
                  .apiId,
              8,
            );
          }
          expect(tester.takeException(), isNull);
        });
      },
    );
  }
}
