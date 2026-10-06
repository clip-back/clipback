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

const _upload = '/api/v1/uploads/screenshots';
const _refresh = '/api/v1/auth/refresh';
const _guest = '/api/v1/auth/guest';
const _logout = '/api/v1/auth/logout';
const _warning = '로그인 정보를 기기에 저장하지 못했어요. 앱을 종료하기 전에 다시 저장해 주세요.';
const _sessionKey = 'flutter.clipback.session';
const _old = ApiSession(
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _rotated = ApiSession(
  accessToken: 'rotated-access',
  refreshToken: 'rotated-refresh',
  expiresIn: 7200,
  refreshExpiresIn: 172800,
);
const _replacement = ApiSession(
  accessToken: 'replacement-access',
  refreshToken: 'replacement-refresh',
  expiresIn: 3600,
  refreshExpiresIn: 86400,
);
const _category = {
  'id': 101,
  'name': '공부',
  'color': '#059669',
  'is_default': false,
  'content_count': 0,
  'last_saved_at': null,
};
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Map<String, Object> _tokens(ApiSession session) => {
  'access_token': session.accessToken,
  'refresh_token': session.refreshToken,
  'expires_in': session.expiresIn,
  'refresh_expires_in': session.refreshExpiresIn,
};

Map<String, Object?> _content() => {
  'id': 7,
  'categories': [_category],
  'tags': [
    {'id': 1, 'name': '공부'},
  ],
  'assets': [
    {
      'id': 9,
      'asset_type': 'screenshot',
      'download_url': '/api/v1/uploads/assets/9',
      'mime_type': 'image/png',
    },
  ],
  'content_type': 'screenshot',
  'source': 'screenshot',
  'title': '저장한 테스트 사진',
  'summary': '스크린샷 테스트',
  'original_url': null,
  'is_favorite': false,
  'saved_at': '2026-10-06T00:00:00Z',
  'last_viewed_at': null,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _unauthorized() =>
    _json({'detail': 'Invalid or expired token'}, 401);

http.Response _failure(String kind) => switch (kind) {
  'network' => throw http.ClientException('Offline'),
  'JSON' => http.Response('{broken', 200),
  _ => _json({'detail': 'Injected $kind failure'}, int.parse(kind)),
};

Future<void> _turn() => Future<void>(() {});

void _expectCancelled(Object? error) {
  expect(
    error,
    isA<ClipbackApiException>().having(
      (error) => error.statusCode,
      'status',
      isNull,
    ),
  );
}

Future<({Object? value, Object? error})> _outcome(
  Future<dynamic> operation,
) async {
  try {
    return (value: await operation, error: null);
  } catch (error) {
    return (value: null, error: error);
  }
}

class _Part {
  _Part(this.name, this.filename, this.bytes);
  final String name;
  final String? filename;
  final List<int> bytes;
}

class _Call {
  _Call(this.request, this.bytes) {
    final type = request.headers['content-type'] ?? '';
    final boundary = RegExp(r'boundary=([^;]+)').firstMatch(type)?.group(1);
    if (boundary == null) return;
    // Latin-1 preserves every binary byte while splitting the ASCII framing.
    for (var frame in latin1.decode(bytes).split('--$boundary').skip(1)) {
      if (frame.startsWith('--')) break;
      if (frame.startsWith('\r\n')) frame = frame.substring(2);
      if (frame.endsWith('\r\n')) frame = frame.substring(0, frame.length - 2);
      final separator = frame.indexOf('\r\n\r\n');
      if (separator < 0) continue;
      final headers = utf8.decode(latin1.encode(frame.substring(0, separator)));
      final name = RegExp(r'name="([^"]+)"').firstMatch(headers)?.group(1);
      if (name == null) continue;
      final filename = RegExp(
        r'filename="([^"]+)"',
      ).firstMatch(headers)?.group(1);
      parts.add(
        _Part(name, filename, latin1.encode(frame.substring(separator + 4))),
      );
    }
  }

  final http.BaseRequest request;
  final List<int> bytes;
  final parts = <_Part>[];

  List<String> values(String name) => parts
      .where((part) => part.name == name && part.filename == null)
      .map((part) => utf8.decode(part.bytes))
      .toList();

  _Part get file => parts.singleWhere((part) => part.name == 'file');
}

class _Server {
  _Server({this.respond});
  final Future<http.Response?> Function(_Call)? respond;
  final requests = <_Call>[];
  bool saved = false;
  late final client = MockClient.streaming((request, stream) async {
    final call = _Call(request, await stream.toBytes());
    requests.add(call);
    final response = await respond?.call(call) ?? _defaultResponse(call);
    if (request.url.path == _upload && response.statusCode == 201) saved = true;
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  });

  http.Response _defaultResponse(_Call call) {
    switch (call.request.url.path) {
      case _upload:
        return _json(_content(), 201);
      case _refresh:
        return _json(_tokens(_rotated));
      case _guest:
        return _json(_tokens(_replacement));
      case _logout:
        return http.Response('', 204);
      case '/api/v1/contents/7':
        return _json(_content());
      case '/api/v1/categories':
        return _json([_category]);
      case '/api/v1/feed':
        return _json({
          'items': saved ? [_content()] : <Object>[],
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
        return _json({'saved_count': saved ? 1 : 0, 'reopened_count': 0});
      default:
        throw StateError('Unexpected request: ${call.request.url.path}');
    }
  }

  List<_Call> calls(String path) =>
      requests.where((call) => call.request.url.path == path).toList();
}

class _BackingStore {
  _BackingStore({bool empty = false})
    : data = empty ? {} : {_sessionKey: jsonEncode(_tokens(_old))};

  final Map<String, Object> data;
  final writes = <Map<String, dynamic>>[];
  Future<bool> Function(Map<String, dynamic>)? onWrite;

  void install() {
    SharedPreferences.resetStatic();
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getAll':
        case 'getAllWithParameters':
          return Map<String, Object>.of(data);
        case 'setString':
          final args = call.arguments as Map;
          final value = args['value'] as String;
          final session = Map<String, dynamic>.from(jsonDecode(value) as Map);
          writes.add(session);
          final success = await onWrite?.call(session) ?? true;
          if (success) data[args['key'] as String] = value;
          return success;
        case 'remove':
          data.remove((call.arguments as Map)['key']);
          return true;
        default:
          throw StateError('Unexpected preferences method: ${call.method}');
      }
    });
    addTearDown(() {
      SharedPreferences.resetStatic();
      messenger.setMockMethodCallHandler(channel, null);
    });
  }

  Future<ApiSession?> readFromDisk() {
    SharedPreferences.resetStatic();
    return ApiSessionStorage().read();
  }
}

class _Picker extends FilePicker {
  int calls = 0;
  FileType? requestedType;
  bool? requestedData;

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
  }) async {
    calls++;
    requestedType = type;
    requestedData = withData;
    return FilePickerResult([
      PlatformFile(name: 'screen.png', size: _png.length, bytes: _png),
    ]);
  }
}

Future<void> _withApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check, {
  _BackingStore? backing,
}) async {
  (backing ?? _BackingStore()).install();
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
          child: const ClipbackApp(),
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

Future<_Picker> _selectPhoto(WidgetTester tester) async {
  final previousPicker = FilePicker.platform;
  final picker = _Picker();
  FilePicker.platform = picker;
  addTearDown(() => FilePicker.platform = previousPicker);
  final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
  unawaited(
    showContentSaveScreen(
      context: tester.element(find.byType(HomeScreen)),
      categories: home.categories,
      onAddLink: home.onAddLink,
      onAddScreenshot: home.onAddScreenshot,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('사진 첨부'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('사진 선택'));
  await tester.pumpAndSettle();
  return picker;
}

Future<ApiContent> _uploadPhoto(ClipbackApi api) => api.uploadScreenshot(
  bytes: _png,
  filename: 'screen.png',
  categoryIds: [101],
  tagNames: ['공부'],
);

bool _expired(_Call call) =>
    call.request.headers['Authorization'] == 'Bearer old-access';

void _expectSelection(WidgetTester tester) {
  expect(find.byType(SavedContentConfirmation), findsNothing);
  expect(find.byType(SaveErrorToast), findsOneWidget);
  final preview = tester.widget<SelectedPhotoPreview>(
    find.byType(SelectedPhotoPreview),
  );
  expect(preview.photoBytes, orderedEquals(_png));
  final button = tester.widget<SaveFlowButton>(find.byType(SaveFlowButton));
  expect(button.enabled, isTrue);
  expect(button.loading, isFalse);
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

  test(
    'expired screenshot upload refreshes once and replays its file',
    () async {
      final sessions = <ApiSession>[];
      final server = _Server(
        respond: (call) async {
          if (call.request.url.path == _upload &&
              call.request.headers['Authorization'] == 'Bearer old-access') {
            return _unauthorized();
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (session) async => sessions.add(session),
      )..restoreSession(_old);

      final result = await _outcome(
        api.uploadScreenshot(
          bytes: _png,
          filename: 'screen.png',
          categoryIds: [101],
          tagNames: ['공부'],
        ),
      );

      expect(server.calls(_refresh), hasLength(1));
      expect(result.error, isNull);
      expect((result.value as ApiContent).id, 7);
      expect(sessions, hasLength(1));
      expect(api.session?.refreshToken, _rotated.refreshToken);
      final uploads = server.calls(_upload);
      expect(uploads, hasLength(2));
      expect(identical(uploads.first.request, uploads.last.request), isFalse);
      expect(
        uploads.last.request.headers['Authorization'],
        'Bearer rotated-access',
      );
      for (final upload in uploads) {
        expect(upload.file.filename, 'screen.png');
        expect(upload.file.bytes, orderedEquals(_png));
        expect(upload.values('category_ids'), ['101']);
        expect(upload.values('tag_names'), ['공부']);
      }
      expect(server.calls(_guest), isEmpty);
    },
  );

  test('screenshot multipart preserves every category and tag', () async {
    final server = _Server();
    addTearDown(server.client.close);
    final api = ClipbackApi(client: server.client)..restoreSession(_old);
    await api.uploadScreenshot(
      bytes: _png,
      filename: 'screen.png',
      categoryIds: [101, 102],
      tagNames: ['공부', '회귀'],
    );

    final upload = server.calls(_upload).single;
    expect(
      {
        'category_ids': upload.values('category_ids'),
        'tag_names': upload.values('tag_names'),
      },
      {
        'category_ids': ['101', '102'],
        'tag_names': ['공부', '회귀'],
      },
    );
    expect(upload.file.filename, 'screen.png');
    expect(upload.file.bytes, orderedEquals(_png));
    expect(server.calls(_refresh), isEmpty);
  });

  testWidgets(
    'final screenshot 401 keeps the selected file without a new guest',
    (tester) async {
      final server = _Server(
        respond: (call) async =>
            call.request.url.path == _upload ? _unauthorized() : null,
      );
      await _withApp(tester, server, () async {
        final picker = await _selectPhoto(tester);
        await tester.tap(find.text('허투루에 저장하기'));
        await tester.pumpAndSettle();

        expect(server.calls(_guest), isEmpty);
        expect(server.calls(_refresh), hasLength(1));
        expect(server.calls(_upload), hasLength(2));
        expect(find.byType(SavedContentConfirmation), findsNothing);
        expect(find.byType(SaveErrorToast), findsOneWidget);
        final preview = tester.widget<SelectedPhotoPreview>(
          find.byType(SelectedPhotoPreview),
        );
        expect(preview.photoBytes, orderedEquals(_png));
        expect(
          tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).enabled,
          isTrue,
        );
        expect(picker.calls, 1);
        expect(picker.requestedType, FileType.image);
        expect(picker.requestedData, isTrue);
      });
    },
  );

  test('empty category and tag lists remain absent from multipart', () async {
    final server = _Server();
    addTearDown(server.client.close);
    final api = ClipbackApi(client: server.client)..restoreSession(_old);
    await api.uploadScreenshot(bytes: _png, filename: 'screen.png');
    final upload = server.calls(_upload).single;
    expect(upload.parts, hasLength(1));
    expect(upload.file.bytes, orderedEquals(_png));
    expect(server.calls(_refresh), isEmpty);
  });

  test(
    'retry snapshots mutable bytes and repeated UTF-8 form values',
    () async {
      final bytes = Uint8List.fromList(_png);
      final categories = [101, 102];
      final tags = ['공부', '회귀 태그'];
      final server = _Server(
        respond: (call) async {
          if (call.request.url.path == _upload && _expired(call)) {
            bytes.fillRange(0, bytes.length, 0);
            categories
              ..clear()
              ..add(999);
            tags
              ..clear()
              ..add('다른 입력');
            return _unauthorized();
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      await api.uploadScreenshot(
        bytes: bytes,
        filename: '회귀 사진.png',
        categoryIds: categories,
        tagNames: tags,
      );
      expect(categories, [999]);
      expect(tags, ['다른 입력']);
      final uploads = server.calls(_upload);
      expect(uploads, hasLength(2));
      for (final upload in uploads) {
        expect(upload.file.filename, '회귀 사진.png');
        expect(upload.file.bytes, orderedEquals(_png));
        expect(upload.values('category_ids'), ['101', '102']);
        expect(upload.values('tag_names'), ['공부', '회귀 태그']);
        expect(upload.request, isA<http.MultipartRequest>());
      }
      expect(identical(uploads.first.request, uploads.last.request), isFalse);
      expect(server.calls(_refresh), hasLength(1));
    },
  );

  test(
    'JSON and two uploads share refresh through the persistence callback',
    () async {
      final expiredTogether = Completer<void>();
      final saving = Completer<void>();
      final saved = Completer<void>();
      var expiredCalls = 0;
      var callbacks = 0;
      final server = _Server(
        respond: (call) async {
          if (_expired(call)) {
            expiredCalls++;
            if (expiredCalls == 3) expiredTogether.complete();
            await expiredTogether.future;
            return _unauthorized();
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async {
          callbacks++;
          saving.complete();
          await saved.future;
        },
      )..restoreSession(_old);
      final results = [
        _outcome(_uploadPhoto(api)),
        _outcome(_uploadPhoto(api)),
        _outcome(api.readContent(7)),
      ];
      await saving.future;
      expect(server.calls(_refresh), hasLength(1));
      expect(callbacks, 1);
      expect(server.calls(_upload), hasLength(2));
      expect(server.calls('/api/v1/contents/7'), hasLength(1));
      expect(api.session?.refreshToken, _rotated.refreshToken);
      saved.complete();
      expect(
        (await Future.wait(results)).map((result) => result.error),
        everyElement(isNull),
      );
      expect(server.calls(_upload), hasLength(4));
      expect(server.calls('/api/v1/contents/7'), hasLength(2));
      expect(server.calls(_refresh), hasLength(1));
      for (final upload in server.calls(_upload)) {
        expect(upload.file.bytes, orderedEquals(_png));
      }
    },
  );

  test('late upload 401 reuses a completed JSON refresh', () async {
    final late = Completer<http.Response?>();
    final started = Completer<void>();
    final server = _Server(
      respond: (call) async {
        if (_expired(call)) {
          if (call.request.url.path == _upload) {
            started.complete();
            return late.future;
          }
          return _unauthorized();
        }
        return null;
      },
    );
    addTearDown(server.client.close);
    final api = ClipbackApi(client: server.client)..restoreSession(_old);
    final upload = _outcome(_uploadPhoto(api));
    await started.future;
    await api.readContent(7);
    late.complete(_unauthorized());
    expect((await upload).error, isNull);
    expect(server.calls(_refresh), hasLength(1));
    expect(
      server
          .calls(_upload)
          .map((call) => call.request.headers['Authorization']),
      ['Bearer old-access', 'Bearer rotated-access'],
    );
  });

  test(
    'upload with new memory tokens still waits for their persistence',
    () async {
      final saving = Completer<void>();
      final saved = Completer<void>();
      final server = _Server(
        respond: (call) async {
          if (call.request.url.path == _upload &&
              call.request.headers['Authorization'] ==
                  'Bearer rotated-access' &&
              !saved.isCompleted) {
            return _unauthorized();
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async {
          saving.complete();
          await saved.future;
        },
      )..restoreSession(_old);
      final refresh = _outcome(api.refreshSession());
      await saving.future;
      final upload = _outcome(_uploadPhoto(api));
      await _turn();
      expect(server.calls(_upload), hasLength(1));
      expect(server.calls(_refresh), hasLength(1));
      saved.complete();
      expect((await refresh).error, isNull);
      expect((await upload).error, isNull);
      expect(server.calls(_upload), hasLength(2));
      expect(server.calls(_refresh), hasLength(1));
    },
  );

  test(
    'a final upload 401 is returned after one refresh and one replay',
    () async {
      final server = _Server(
        respond: (call) async =>
            call.request.url.path == _upload ? _unauthorized() : null,
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      final result = await _outcome(_uploadPhoto(api));
      expect(
        result.error,
        isA<ClipbackApiException>().having(
          (error) => error.statusCode,
          'status',
          401,
        ),
      );
      expect(server.calls(_refresh), hasLength(1));
      expect(server.calls(_upload), hasLength(2));
      expect(server.calls(_guest), isEmpty);
      expect(api.session?.refreshToken, _rotated.refreshToken);
    },
  );

  for (final failure in ['401', '403', '503', 'network', 'JSON']) {
    test(
      'upload refresh $failure does not replay and a later attempt recovers',
      () async {
        var failing = true;
        final server = _Server(
          respond: (call) async {
            if (_expired(call)) return _unauthorized();
            if (call.request.url.path == _refresh && failing) {
              return _failure(failure);
            }
            return null;
          },
        );
        addTearDown(server.client.close);
        final api = ClipbackApi(client: server.client)..restoreSession(_old);
        expect((await _outcome(_uploadPhoto(api))).error, isNotNull);
        expect(server.calls(_upload), hasLength(1));
        expect(server.calls(_refresh), hasLength(1));
        expect(server.calls(_guest), isEmpty);
        expect(api.session?.refreshToken, _old.refreshToken);
        failing = false;
        expect((await _outcome(_uploadPhoto(api))).error, isNull);
        expect(server.calls(_upload), hasLength(3));
        expect(server.calls(_refresh), hasLength(2));
      },
    );
  }

  test(
    'failed persistence callback stops the replay but keeps rotated memory',
    () async {
      final server = _Server(
        respond: (call) async => _expired(call) ? _unauthorized() : null,
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async => throw StateError('Storage failed'),
      )..restoreSession(_old);
      expect((await _outcome(_uploadPhoto(api))).error, isA<StateError>());
      expect(api.session?.refreshToken, _rotated.refreshToken);
      expect(server.calls(_upload), hasLength(1));
      expect((await _outcome(_uploadPhoto(api))).error, isNull);
      expect(server.calls(_upload), hasLength(2));
      expect(server.calls(_refresh), hasLength(1));
    },
  );

  for (final failure in [
    '403',
    '413',
    '415',
    '422',
    '503',
    'network',
    'JSON',
  ]) {
    test('upload $failure is not automatically retried', () async {
      final server = _Server(
        respond: (call) async =>
            call.request.url.path == _upload ? _failure(failure) : null,
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      final result = await _outcome(_uploadPhoto(api));
      expect(result.error, isNotNull);
      if (failure == 'network') {
        expect(
          result.error,
          isA<ClipbackApiException>().having(
            (error) => error.message,
            'message',
            '서버에 연결하지 못했어요.',
          ),
        );
      }
      expect(server.calls(_upload), hasLength(1));
      expect(server.calls(_refresh), isEmpty);
      expect(server.calls(_guest), isEmpty);
      expect(api.session?.refreshToken, _old.refreshToken);
    });
  }

  for (final replacement in ['restore', 'clear']) {
    for (final response in ['200', '401', 'network']) {
      test('pending upload $response is cancelled by $replacement', () async {
        final pending = Completer<http.Response?>();
        final started = Completer<void>();
        final server = _Server(
          respond: (call) async {
            if (call.request.url.path == _upload) {
              started.complete();
              return pending.future;
            }
            return null;
          },
        );
        addTearDown(server.client.close);
        final api = ClipbackApi(client: server.client)..restoreSession(_old);
        final result = _outcome(_uploadPhoto(api));
        await started.future;
        if (replacement == 'clear') {
          api.clearSession();
        } else {
          api.restoreSession(_replacement);
        }
        if (response == 'network') {
          pending.completeError(http.ClientException('Old request failed'));
        } else {
          pending.complete(
            response == '401' ? _unauthorized() : _json(_content()),
          );
        }
        _expectCancelled((await result).error);
        expect(server.calls(_upload), hasLength(1));
        expect(server.calls(_refresh), isEmpty);
        expect(
          api.session?.refreshToken,
          replacement == 'clear' ? isNull : _replacement.refreshToken,
        );
      });
    }
  }

  test(
    'logout blocks new uploads and cancels an in-flight upload response',
    () async {
      final pendingUpload = Completer<http.Response?>();
      final pendingLogout = Completer<http.Response?>();
      final uploadStarted = Completer<void>();
      final logoutStarted = Completer<void>();
      final server = _Server(
        respond: (call) async {
          if (call.request.url.path == _upload) {
            uploadStarted.complete();
            return pendingUpload.future;
          }
          if (call.request.url.path == _logout) {
            logoutStarted.complete();
            return pendingLogout.future;
          }
          return null;
        },
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)..restoreSession(_old);
      final upload = _outcome(_uploadPhoto(api));
      await uploadStarted.future;
      final logout = _outcome(api.logout());
      await logoutStarted.future;
      _expectCancelled((await _outcome(_uploadPhoto(api))).error);
      expect(server.calls(_upload), hasLength(1));
      pendingUpload.complete(_unauthorized());
      _expectCancelled((await upload).error);
      expect(server.calls(_refresh), isEmpty);
      pendingLogout.complete(http.Response('', 204));
      expect((await logout).error, isNull);
      expect(api.hasSession, isFalse);
    },
  );

  test(
    'logout waits for upload refresh persistence and prevents its replay',
    () async {
      final saving = Completer<void>();
      final saved = Completer<void>();
      final server = _Server(
        respond: (call) async => _expired(call) ? _unauthorized() : null,
      );
      addTearDown(server.client.close);
      final api = ClipbackApi(
        client: server.client,
        onSessionChanged: (_) async {
          saving.complete();
          await saved.future;
        },
      )..restoreSession(_old);
      final upload = _outcome(_uploadPhoto(api));
      await saving.future;
      final logout = _outcome(api.logout());
      await _turn();
      expect(server.calls(_logout), isEmpty);
      expect(server.calls(_upload), hasLength(1));
      saved.complete();
      expect((await logout).error, isNull);
      _expectCancelled((await upload).error);
      expect(server.calls(_upload), hasLength(1));
      expect(jsonDecode(utf8.decode(server.calls(_logout).single.bytes)), {
        'refresh_token': _rotated.refreshToken,
      });
      expect(api.hasSession, isFalse);
    },
  );

  for (final phase in ['send', 'body']) {
    testWidgets('upload $phase times out after ten seconds without retry', (
      tester,
    ) async {
      final pendingSend = Completer<http.Response?>();
      final pendingBody = StreamController<List<int>>();
      final calls = <_Call>[];
      final client = MockClient.streaming((request, stream) async {
        calls.add(_Call(request, await stream.toBytes()));
        if (phase == 'send') {
          final response = await pendingSend.future;
          return http.StreamedResponse(
            Stream.value(response!.bodyBytes),
            response.statusCode,
            headers: response.headers,
          );
        }
        return http.StreamedResponse(
          pendingBody.stream,
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.close);
      final api = ClipbackApi(client: client)..restoreSession(_old);
      var settled = false;
      final result = _outcome(_uploadPhoto(api)).then((result) {
        settled = true;
        return result;
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect(settled, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(
        (await result).error,
        isA<ClipbackApiException>().having(
          (error) => error.message,
          'message',
          '서버 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.',
        ),
      );
      expect(calls, hasLength(1));
      expect(calls.single.request.url.path, _upload);
      expect(api.session?.refreshToken, _old.refreshToken);
      if (phase == 'send') {
        pendingSend.complete(_json(_content(), 201));
      } else {
        pendingBody.add(utf8.encode(jsonEncode(_content())));
        await pendingBody.close();
      }
      await tester.pump();
      expect(calls, hasLength(1));
      expect(api.session?.refreshToken, _old.refreshToken);
    });
  }

  testWidgets('upload refresh times out and ignores its late token response', (
    tester,
  ) async {
    final pending = Completer<http.Response?>();
    final server = _Server(
      respond: (call) async {
        if (_expired(call)) return _unauthorized();
        if (call.request.url.path == _refresh) return pending.future;
        return null;
      },
    );
    addTearDown(server.client.close);
    final api = ClipbackApi(client: server.client)..restoreSession(_old);
    final upload = _outcome(_uploadPhoto(api));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect((await upload).error, isA<ClipbackApiException>());
    expect(server.calls(_refresh), hasLength(1));
    expect(server.calls(_upload), hasLength(1));
    pending.complete(_json(_tokens(_rotated)));
    await tester.pump();
    expect(api.session?.refreshToken, _old.refreshToken);
    expect(server.calls(_upload), hasLength(1));
  });

  testWidgets('upload retry does not time out while saving refreshed tokens', (
    tester,
  ) async {
    final saved = Completer<void>();
    final server = _Server(
      respond: (call) async => _expired(call) ? _unauthorized() : null,
    );
    addTearDown(server.client.close);
    final api = ClipbackApi(
      client: server.client,
      onSessionChanged: (_) => saved.future,
    )..restoreSession(_old);
    var settled = false;
    final upload = _outcome(_uploadPhoto(api)).then((result) {
      settled = true;
      return result;
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    expect(settled, isFalse);
    expect(server.calls(_upload), hasLength(1));
    expect(server.calls(_refresh), hasLength(1));
    saved.complete();
    await tester.pump();
    expect((await upload).error, isNull);
    expect(server.calls(_upload), hasLength(2));
  });

  testWidgets(
    'successful refreshed upload shows confirmation and persists tokens',
    (tester) async {
      final backing = _BackingStore();
      final server = _Server(
        respond: (call) async =>
            _expired(call) && call.request.url.path == _upload
            ? _unauthorized()
            : null,
      );
      await _withApp(tester, server, () async {
        await _selectPhoto(tester);
        await tester.tap(find.text('허투루에 저장하기'));
        await tester.pumpAndSettle();
        expect(find.byType(SavedContentConfirmation), findsOneWidget);
        expect(find.text('screen.png'), findsOneWidget);
        expect(find.text('저장한 테스트 사진'), findsWidgets);
        expect(find.byType(SaveErrorToast), findsNothing);
        expect(server.calls(_upload), hasLength(2));
        expect(server.calls(_refresh), hasLength(1));
        expect(server.calls(_guest), isEmpty);
        expect(
          (await backing.readFromDisk())?.refreshToken,
          _rotated.refreshToken,
        );
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        expect(find.byType(AddContentSheet), findsNothing);
        final content = tester
            .widget<DetailScreen>(find.byType(DetailScreen))
            .content;
        expect(content.apiId, 7);
      }, backing: backing);
    },
  );

  testWidgets(
    'pending upload blocks duplicate taps and restores the same input on failure',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (call) async =>
            call.request.url.path == _upload ? pending.future : null,
      );
      await _withApp(tester, server, () async {
        final picker = await _selectPhoto(tester);
        final submit = tester
            .widget<SaveFlowButton>(find.byType(SaveFlowButton))
            .onPressed;
        submit();
        submit();
        await tester.pump();
        expect(server.calls(_upload), hasLength(1));
        final button = tester.widget<SaveFlowButton>(
          find.byType(SaveFlowButton),
        );
        expect(button.enabled, isFalse);
        expect(button.loading, isTrue);
        submit();
        await tester.pump();
        expect(server.calls(_upload), hasLength(1));
        pending.complete(_json({'detail': 'Temporary failure'}, 503));
        await tester.pumpAndSettle();
        _expectSelection(tester);
        expect(picker.calls, 1);
        expect(server.calls(_refresh), isEmpty);
        expect(server.calls(_guest), isEmpty);
      });
    },
  );

  for (final failure in [
    '403',
    '413',
    '415',
    '422',
    '503',
    'network',
    'JSON',
  ]) {
    testWidgets('upload $failure keeps image and metadata for a manual retry', (
      tester,
    ) async {
      var failing = true;
      final server = _Server(
        respond: (call) async => call.request.url.path == _upload && failing
            ? _failure(failure)
            : null,
      );
      await _withApp(tester, server, () async {
        final picker = await _selectPhoto(tester);
        await tester.tap(find.text('허투루에 저장하기'));
        await tester.pumpAndSettle();
        _expectSelection(tester);
        expect(server.calls(_upload), hasLength(1));
        expect(server.calls(_refresh), isEmpty);
        expect(server.calls(_guest), isEmpty);
        failing = false;
        await tester.tap(find.text('허투루에 저장하기'));
        await tester.pumpAndSettle();
        expect(find.byType(SavedContentConfirmation), findsOneWidget);
        expect(find.text('screen.png'), findsOneWidget);
        expect(picker.calls, 1);
        final uploads = server.calls(_upload);
        expect(uploads, hasLength(2));
        for (final upload in uploads) {
          expect(upload.file.filename, 'screen.png');
          expect(upload.file.bytes, orderedEquals(_png));
          expect(upload.values('category_ids'), ['101']);
          expect(upload.values('tag_names'), ['공부']);
        }
        expect(server.calls(_refresh), isEmpty);
        expect(server.calls(_guest), isEmpty);
      });
    });
  }

  testWidgets(
    'failed auth refresh keeps screenshot and retries in the same account',
    (tester) async {
      var refreshFails = true;
      final server = _Server(
        respond: (call) async {
          if (_expired(call) && call.request.url.path == _upload) {
            return _unauthorized();
          }
          if (call.request.url.path == _refresh && refreshFails) {
            return _failure('503');
          }
          return null;
        },
      );
      final backing = _BackingStore();
      await _withApp(tester, server, () async {
        final picker = await _selectPhoto(tester);
        await tester.tap(find.text('허투루에 저장하기'));
        await tester.pumpAndSettle();
        _expectSelection(tester);
        expect(server.calls(_upload), hasLength(1));
        expect(server.calls(_refresh), hasLength(1));
        expect(server.calls(_guest), isEmpty);
        expect((await backing.readFromDisk())?.refreshToken, _old.refreshToken);
        refreshFails = false;
        await tester.tap(find.text('허투루에 저장하기'));
        await tester.pumpAndSettle();
        expect(find.byType(SavedContentConfirmation), findsOneWidget);
        expect(picker.calls, 1);
        expect(server.calls(_upload), hasLength(3));
        expect(server.calls(_refresh), hasLength(2));
        expect(server.calls(_guest), isEmpty);
        expect(
          (await backing.readFromDisk())?.refreshToken,
          _rotated.refreshToken,
        );
      }, backing: backing);
    },
  );

  for (final failure in ['false', 'throw']) {
    testWidgets(
      'token storage $failure keeps upload successful and retries only storage',
      (tester) async {
        var failing = true;
        final backing = _BackingStore()
          ..onWrite = (_) async {
            if (!failing) return true;
            if (failure == 'throw') {
              throw PlatformException(code: 'Storage unavailable');
            }
            return false;
          };
        final server = _Server(
          respond: (call) async =>
              _expired(call) && call.request.url.path == _upload
              ? _unauthorized()
              : null,
        );
        await _withApp(tester, server, () async {
          await _selectPhoto(tester);
          await tester.tap(find.text('허투루에 저장하기'));
          await tester.pumpAndSettle();
          expect(find.byType(SavedContentConfirmation), findsOneWidget);
          expect(server.calls(_upload), hasLength(2));
          expect(server.calls(_refresh), hasLength(1));
          expect(
            (await backing.readFromDisk())?.refreshToken,
            _old.refreshToken,
          );
          await tester.tap(find.text('닫기'));
          await tester.pumpAndSettle();
          expect(find.text(_warning), findsOneWidget);
          for (var attempt = 0; attempt < 2; attempt++) {
            await tester.tap(find.text('다시 저장'));
            await tester.pumpAndSettle();
            expect(find.text(_warning), findsOneWidget);
            expect(server.calls(_upload), hasLength(2));
            expect(server.calls(_refresh), hasLength(1));
            expect(server.calls(_guest), isEmpty);
          }
          failing = false;
          await tester.tap(find.text('다시 저장'));
          await tester.pumpAndSettle();
          expect(find.text(_warning), findsNothing);
          expect(
            (await backing.readFromDisk())?.refreshToken,
            _rotated.refreshToken,
          );
          expect(server.calls(_upload), hasLength(2));
          expect(server.calls(_refresh), hasLength(1));
          expect(server.calls(_guest), isEmpty);
          expect(
            backing.writes.map((session) => session['refresh_token']),
            everyElement(_rotated.refreshToken),
          );
        }, backing: backing);
      },
    );
  }

  testWidgets(
    'fresh app creates one guest and saves its first screenshot once',
    (tester) async {
      final backing = _BackingStore(empty: true);
      final server = _Server();
      await _withApp(tester, server, () async {
        expect(server.calls(_guest), hasLength(1));
        await _selectPhoto(tester);
        await tester.tap(find.text('허투루에 저장하기'));
        await tester.pumpAndSettle();
        expect(find.byType(SavedContentConfirmation), findsOneWidget);
        expect(server.calls(_guest), hasLength(1));
        expect(server.calls(_upload), hasLength(1));
        expect(
          server.calls(_upload).single.request.headers['Authorization'],
          'Bearer replacement-access',
        );
        expect(server.calls(_refresh), isEmpty);
        expect(
          (await backing.readFromDisk())?.refreshToken,
          _replacement.refreshToken,
        );
      }, backing: backing);
    },
  );

  testWidgets(
    'final link 401 does not invoke the removed guest save fallback',
    (tester) async {
      final server = _Server(
        respond: (call) async => call.request.url.path == '/api/v1/contents'
            ? _unauthorized()
            : null,
      );
      await _withApp(tester, server, () async {
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        final result = await _outcome(
          home.onAddLink(
            url: 'https://example.com/test',
            category: home.categories.single,
          ),
        );
        expect(
          result.error,
          isA<ClipbackApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        );
        expect(server.calls('/api/v1/contents'), hasLength(2));
        expect(server.calls(_refresh), hasLength(1));
        expect(server.calls(_guest), isEmpty);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
      });
    },
  );
}
