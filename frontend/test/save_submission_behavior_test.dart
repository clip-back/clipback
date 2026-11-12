// Behavior pins for the save sheet's submission state (G1–G9 of #288) and
// the link save time limit (L1–L6 of #319).
// Assertions use only the screen, the save callbacks and server requests.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_navigation.dart';
import 'support/app_startup.dart';
import 'support/memory_api_session_storage.dart';

const _defaultError = '저장하지 못했어요. 다시 시도해 주세요.';
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

// ---------------------------------------------------------------------------
// Sheet with fake callbacks
// ---------------------------------------------------------------------------

ContentItem _savedContent() => ContentItem(
  id: 'saved-result',
  title: '저장한 콘텐츠',
  summary: '서버가 반환한 요약',
  category: catUncategorized,
  savedAt: '26.10.15',
  savedAtFull: '2026. 10. 15 오후 02:00',
  savedAtFullShort: '2026. 10. 15 02:00',
  tags: const [],
  source: '테스트',
  originalUrl: 'https://example.com/server-value',
  originalText: '',
);

class _Picker extends FilePicker {
  _Picker(this.photos);

  final List<(String, Uint8List)> photos;
  int calls = 0;

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
    final (name, bytes) = photos[calls++];
    return FilePickerResult([
      PlatformFile(name: name, size: bytes.length, bytes: bytes),
    ]);
  }
}

Future<void> _open(
  WidgetTester tester, {
  required SaveLinkCallback onAddLink,
  required SaveScreenshotCallback onAddScreenshot,
  double height = 812,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(375, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Pretendard'),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showContentSaveScreen(
              context: context,
              onAddLink: onAddLink,
              onAddScreenshot: onAddScreenshot,
            ),
            child: const Text('저장 화면 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('저장 화면 열기'));
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _link(WidgetTester tester, String url) async {
  await _tab(tester, '링크 첨부');
  await tester.enterText(find.byType(TextField), url);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _photo(WidgetTester tester) async {
  await _tab(tester, '사진 첨부');
  await tester.tap(
    find.byType(SelectedPhotoPreview).evaluate().isEmpty
        ? find.text('사진 선택')
        : find.byType(SelectedPhotoPreview),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('허투루에 저장하기'));
  await tester.pump(const Duration(milliseconds: 50));
}

SavedContentConfirmation _result(WidgetTester tester) => tester
    .widget<SavedContentConfirmation>(find.byType(SavedContentConfirmation));

void _expectActiveTab(WidgetTester tester, String label) {
  expect(
    tester.widget<Text>(find.text(label)).style!.fontWeight,
    FontWeight.w600,
  );
}

ScrollPosition _bodyScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void _clipboard(WidgetTester tester, Future<Object?> Function() read) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) =>
        call.method == 'Clipboard.getData' ? read() : Future<Object?>.value(),
  );
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

// ---------------------------------------------------------------------------
// Real app with a fake server
// ---------------------------------------------------------------------------

const _contents = '/api/v1/contents';
const _upload = '/api/v1/uploads/screenshots';
const _category = {
  'id': 101,
  'name': '공부',
  'color': '#059669',
  'is_default': false,
  'content_count': 0,
  'last_saved_at': null,
};

http.Response _json(Object? value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _linkContent() => {
  'id': 7,
  'categories': [_category],
  'tags': <Object>[],
  'assets': <Object>[],
  'content_type': 'link',
  'source': 'web',
  'title': '링크 저장 결과',
  'summary': '링크 요약',
  'original_url': 'https://example.com/g-link',
  'is_favorite': false,
  'saved_at': '2026-10-06T00:00:00Z',
  'last_viewed_at': null,
};

Map<String, Object?> _photoContent() => {
  'id': 8,
  'categories': [_category],
  'tags': <Object>[],
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
  'title': '사진 저장 결과',
  'summary': '사진 요약',
  'original_url': null,
  'is_favorite': false,
  'saved_at': '2026-10-06T00:00:00Z',
  'last_viewed_at': null,
};

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Server {
  _Server({this.respond});

  final Future<http.Response?> Function(http.Request)? respond;
  final requests = <http.Request>[];
  late final client = MockClient((request) async {
    requests.add(request);
    final response = await respond?.call(request);
    if (response != null) return response;
    switch (request.url.path) {
      case _contents:
        return _json(_linkContent(), 201);
      case _upload:
        return _json(_photoContent(), 201);
      case '/api/v1/contents/7':
        return _json(_linkContent());
      case '/api/v1/contents/8':
        return _json(_photoContent());
      case '/api/v1/categories':
        return _json([_category]);
      // The feed never lists saved content, so a home entry comes only from
      // the app's own handling of a save response.
      case '/api/v1/feed':
        return _json({'items': <Object>[], 'next_cursor': null});
      case '/api/v1/users/me':
        return _json({
          'id': 1,
          'email': null,
          'display_name': '테스트 계정',
          'is_guest': true,
          'created_at': '2026-10-25T00:00:00Z',
          'linked_providers': <String>[],
        });
      case '/api/v1/users/me/stats':
        return _json({
          'saved_count': 0,
          'reopened_count': 0,
          'recent_reopened_count': 0,
        });
      case '/api/v1/recommendations/weekly':
        return _json({
          'period_start': '2026-10-19T00:00:00Z',
          'period_end': '2026-10-26T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        });
      case '/api/v1/auth/logout':
        return http.Response('', 204);
      case '/api/v1/auth/guest':
        return _json({
          'access_token': 'guest-access',
          'refresh_token': 'guest-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        });
      default:
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
    }
  });

  List<http.Request> calls(String path) =>
      requests.where((request) => request.url.path == path).toList();
}

class _SocialAuth extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders => [
    SocialLoginProvider.google,
  ];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => null;
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.unavailable;
}

Future<void> _withApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check,
) async {
  SharedPreferences.setMockInitialValues({});
  final storage = MemoryApiSessionStorage();
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
          child: ClipbackApp(
            sessionStorage: storage,
            socialAuth: _SocialAuth(),
          ),
        ),
      );
      await completeAppStartup(tester);
      await check();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

HomeScreen _home(WidgetTester tester) =>
    tester.widget<HomeScreen>(find.byType(HomeScreen));

Future<void> _openAppSheet(WidgetTester tester) async {
  final home = _home(tester);
  unawaited(
    showContentSaveScreen(
      context: tester.element(find.byType(HomeScreen)),
      onAddLink: home.onAddLink,
      onAddScreenshot: home.onAddScreenshot,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitAppLink(WidgetTester tester) async {
  await _openAppSheet(tester);
  await tester.enterText(find.byType(TextField), 'https://example.com/g-link');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('허투루에 저장하기'));
  await tester.pump();
}

Future<void> _submitAppPhoto(WidgetTester tester) async {
  final previous = FilePicker.platform;
  FilePicker.platform = _Picker([('screen.png', _png)]);
  addTearDown(() => FilePicker.platform = previous);
  await _openAppSheet(tester);
  await tester.tap(find.text('사진 첨부'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('사진 선택'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('허투루에 저장하기'));
  await tester.pump();
}

Future<void> _closeAppSheet(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(AddContentSheet))).pop();
  await tester.pumpAndSettle();
  expect(find.byType(AddContentSheet), findsNothing);
}

void _expectPhotoAbsentFromHome(WidgetTester tester) {
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(_home(tester).contents.where((item) => item.apiId == 8), isEmpty);
  expect(find.text('사진 저장 결과'), findsNothing);
}

// #319 link save time limit helpers.
const _delayError = '서버 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.';

bool _isLinkPost(http.Request request) =>
    request.url.path == _contents && request.method == 'POST';

Future<http.Response?> _never() => Completer<http.Response?>().future;

http.Response _savedFeed() => _json({
  'items': [_linkContent()],
  'next_cursor': null,
});

// A successful save opens its detail behind the sheet: close both, then read
// the home list.
Future<List<ContentItem>> _homeAfterResult(WidgetTester tester) async {
  await tester.tap(find.text('저장 완료'));
  await tester.pumpAndSettle();
  tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
  await tester.pumpAndSettle();
  return _home(tester).contents;
}

void _expectProcessing(WidgetTester tester) {
  expect(find.text('허투루가 정보를 추출 중입니다...'), findsOneWidget);
  final button = tester.widget<SaveFlowButton>(find.byType(SaveFlowButton));
  expect(button.label, '닫기');
  expect(button.enabled, isFalse);
  expect(find.byType(SaveErrorToast), findsNothing);
}

void _expectDelayFailure(WidgetTester tester) {
  expect(find.text('허투루가 정보를 추출 중입니다...'), findsNothing);
  expect(
    tester.widget<SaveErrorToast>(find.byType(SaveErrorToast)).message,
    _delayError,
  );
  expect(
    tester.widget<LinkSaveBody>(find.byType(LinkSaveBody)).controller.text,
    'https://example.com/g-link',
  );
  final button = tester.widget<SaveFlowButton>(find.byType(SaveFlowButton));
  expect(button.label, '허투루에 저장하기');
  expect(button.enabled, isTrue);
  expect(find.byType(SavedContentConfirmation), findsNothing);
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

  late Uint8List firstBytes;
  late Uint8List secondBytes;
  late FilePicker originalPicker;

  setUp(() async {
    firstBytes = (await rootBundle.load(
      'assets/figma/saved-photo-preview.png',
    )).buffer.asUint8List();
    secondBytes = (await rootBundle.load(
      'assets/figma/save-link-preview.png',
    )).buffer.asUint8List();
    originalPicker = FilePicker.platform;
  });

  tearDown(() => FilePicker.platform = originalPicker);

  testWidgets(
    'G1 failed photo A, unsubmitted B, then A again submits with a new key',
    (tester) async {
      FilePicker.platform = _Picker([
        ('first-photo.png', firstBytes),
        ('second-photo.png', secondBytes),
        ('first-photo.png', Uint8List.fromList(firstBytes)),
      ]);
      final uploads = <(String, Uint8List, String?)>[];
      await _open(
        tester,
        onAddLink: ({required url, submissionKey, category}) async =>
            _savedContent(),
        onAddScreenshot:
            ({
              required bytes,
              required filename,
              String? submissionKey,
              category,
            }) async {
              uploads.add((filename, bytes, submissionKey));
              if (uploads.length == 1) {
                throw const ClipbackApiException('사진 실패');
              }
              return _savedContent();
            },
      );
      await _photo(tester);
      await _submit(tester);
      await tester.pump();
      expect(find.text('사진 실패'), findsOneWidget);
      await _photo(tester);
      expect(
        tester
            .widget<SelectedPhotoPreview>(find.byType(SelectedPhotoPreview))
            .photoBytes,
        orderedEquals(secondBytes),
      );
      await _photo(tester);
      await _submit(tester);
      await tester.pumpAndSettle();

      expect(uploads, hasLength(2));
      expect(uploads.first.$2, orderedEquals(firstBytes));
      expect(uploads.last.$1, 'first-photo.png');
      expect(uploads.last.$2, orderedEquals(firstBytes));
      final firstKey = uploads.first.$3;
      final retryKey = uploads.last.$3;
      expect(firstKey, matches(_uuid));
      expect(retryKey, matches(_uuid));
      expect(retryKey, isNot(firstKey));
      expect(_result(tester).originalUrl, 'first-photo.png');
      expect(tester.takeException(), isNull);
    },
  );

  for (final photo in [false, true]) {
    final kind = photo ? 'photo' : 'link';
    testWidgets('G4 non-server $kind failure shows the default message', (
      tester,
    ) async {
      FilePicker.platform = _Picker([('first-photo.png', firstBytes)]);
      await _open(
        tester,
        onAddLink: ({required url, submissionKey, category}) async =>
            throw Exception('link boom'),
        onAddScreenshot:
            ({
              required bytes,
              required filename,
              String? submissionKey,
              category,
            }) async => throw StateError('photo boom'),
      );
      if (photo) {
        await _photo(tester);
      } else {
        await _link(tester, 'https://example.com/fail');
      }
      await _submit(tester);
      await tester.pump();

      expect(find.byType(SaveErrorToast), findsOneWidget);
      expect(
        tester.widget<SaveErrorToast>(find.byType(SaveErrorToast)).message,
        _defaultError,
      );
      expect(find.text(_defaultError), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.byType(SavedContentConfirmation), findsNothing);
      expect(
        tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).label,
        '허투루에 저장하기',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'G7 failure message lasts three seconds and restarts on a new failure',
    (tester) async {
      final failures = <Completer<ContentItem>>[];
      await _open(
        tester,
        onAddLink: ({required url, submissionKey, category}) {
          failures.add(Completer<ContentItem>());
          return failures.last.future;
        },
        onAddScreenshot:
            ({
              required bytes,
              required filename,
              String? submissionKey,
              category,
            }) async => _savedContent(),
      );
      await _link(tester, 'https://example.com/fail');

      // Single failure: visible until just before 3s, gone at 3s.
      await _submit(tester);
      failures.last.completeError(const ClipbackApiException('첫 번째 실패'));
      await tester.pump();
      expect(find.text('첫 번째 실패'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.text('첫 번째 실패'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('첫 번째 실패'), findsNothing);
      expect(find.byType(SaveErrorToast), findsNothing);

      // Failing again while a message is shown restarts the 3s window.
      await _submit(tester);
      failures.last.completeError(const ClipbackApiException('두 번째 실패'));
      await tester.pump();
      expect(find.text('두 번째 실패'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('두 번째 실패'), findsOneWidget);
      await _submit(tester);
      failures.last.completeError(const ClipbackApiException('세 번째 실패'));
      await tester.pump();
      expect(find.text('두 번째 실패'), findsNothing);
      expect(find.text('세 번째 실패'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.text('세 번째 실패'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('세 번째 실패'), findsNothing);
      expect(find.byType(SaveErrorToast), findsNothing);
      expect(failures, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  for (final photo in [false, true]) {
    final kind = photo ? 'photo' : 'link';
    testWidgets(
      'G8 $kind success while another tab is scrolled shows submitted tab at top',
      (tester) async {
        FilePicker.platform = _Picker([('first-photo.png', firstBytes)]);
        final response = Completer<ContentItem>();
        await _open(
          tester,
          height: 330,
          onAddLink: ({required url, submissionKey, category}) =>
              response.future,
          onAddScreenshot:
              ({
                required bytes,
                required filename,
                String? submissionKey,
                category,
              }) => response.future,
        );
        if (photo) {
          await _photo(tester);
        } else {
          await _link(tester, '  https://example.com/g8  ');
        }
        await _submit(tester);
        await _tab(tester, photo ? '링크 첨부' : '사진 첨부');
        _expectActiveTab(tester, photo ? '링크 첨부' : '사진 첨부');
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.pump();
        expect(_bodyScroll(tester).pixels, greaterThan(0));

        response.complete(_savedContent());
        await tester.pump();
        await tester.pump();

        _expectActiveTab(tester, photo ? '사진 첨부' : '링크 첨부');
        if (photo) {
          expect(_result(tester).originalUrl, 'first-photo.png');
          expect(_result(tester).photoBytes, orderedEquals(firstBytes));
        } else {
          expect(_result(tester).originalUrl, 'https://example.com/g8');
          expect(_result(tester).photoBytes, isNull);
        }
        expect(_bodyScroll(tester).pixels, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('G9a paste callback taken before success changes nothing after', (
    tester,
  ) async {
    _clipboard(tester, () async => {'text': 'https://example.com/pasted'});
    final response = Completer<ContentItem>();
    await _open(
      tester,
      onAddLink: ({required url, submissionKey, category}) => response.future,
      onAddScreenshot:
          ({
            required bytes,
            required filename,
            String? submissionKey,
            category,
          }) => response.future,
    );
    await _link(tester, 'https://example.com/submitted');
    final body = tester.widget<LinkSaveBody>(find.byType(LinkSaveBody));
    final paste = body.onPaste;
    final controller = body.controller;
    await _submit(tester);
    response.complete(_savedContent());
    await tester.pumpAndSettle();
    expect(_result(tester).originalUrl, 'https://example.com/submitted');

    paste();
    await tester.pumpAndSettle();

    expect(controller.text, 'https://example.com/submitted');
    expect(_result(tester).originalUrl, 'https://example.com/submitted');
    expect(find.text('저장 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('G9b clipboard reply arriving after success changes nothing', (
    tester,
  ) async {
    final clipboard = Completer<Object?>();
    var reads = 0;
    _clipboard(tester, () {
      reads++;
      return clipboard.future;
    });
    final response = Completer<ContentItem>();
    await _open(
      tester,
      onAddLink: ({required url, submissionKey, category}) => response.future,
      onAddScreenshot:
          ({
            required bytes,
            required filename,
            String? submissionKey,
            category,
          }) => response.future,
    );
    await _link(tester, 'https://example.com/submitted');
    final controller = tester
        .widget<LinkSaveBody>(find.byType(LinkSaveBody))
        .controller;
    await _submit(tester);
    await tester.tap(find.text('붙여넣기'));
    await tester.pump();
    expect(reads, 1);

    response.complete(_savedContent());
    await tester.pumpAndSettle();
    expect(_result(tester).originalUrl, 'https://example.com/submitted');

    clipboard.complete({'text': 'https://example.com/pasted'});
    await tester.pumpAndSettle();

    expect(controller.text, 'https://example.com/submitted');
    expect(_result(tester).originalUrl, 'https://example.com/submitted');
    expect(find.text('저장 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('G2 link save closed while pending still opens its detail', (
    tester,
  ) async {
    final response = Completer<http.Response?>();
    final server = _Server(
      respond: (request) async =>
          request.url.path == _contents && request.method == 'POST'
          ? response.future
          : null,
    );
    await _withApp(tester, server, () async {
      await _submitAppLink(tester);
      expect(server.calls(_contents), hasLength(1));
      await _closeAppSheet(tester);
      expect(find.byType(DetailScreen), findsNothing);

      response.complete(_json(_linkContent(), 201));
      await tester.pumpAndSettle();

      expect(find.byType(AddContentSheet), findsNothing);
      expect(find.byType(DetailScreen), findsOneWidget);
      expect(
        tester.widget<DetailScreen>(find.byType(DetailScreen)).content.apiId,
        7,
      );
      expect(server.calls(_contents), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'G3 photo success after an account change shows nothing in the new account',
    (tester) async {
      final response = Completer<http.Response?>();
      final server = _Server(
        respond: (request) async =>
            request.url.path == _upload ? response.future : null,
      );
      await _withApp(tester, server, () async {
        await _submitAppPhoto(tester);
        expect(server.calls(_upload), hasLength(1));
        _home(tester).onTab(AppRoute.my);
        await tester.pumpAndSettle();
        tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
        await tester.pumpAndSettle();
        await logoutFromAccount(tester);
        await tester.pumpAndSettle();
        expect(find.byType(AddContentSheet), findsNothing);
        await startGuestAndFinishOnboarding(tester);
        await tester.pumpAndSettle();

        response.complete(_json(_photoContent(), 201));
        await tester.pumpAndSettle();

        expect(find.byType(AddContentSheet), findsNothing);
        expect(find.byType(DetailScreen), findsNothing);
        _expectPhotoAbsentFromHome(tester);
        expect(server.calls(_upload), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('G5 link and photo saves each send a key', (tester) async {
    final server = _Server();
    await _withApp(tester, server, () async {
      await _submitAppLink(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장 완료'));
      await tester.pumpAndSettle();
      tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
      await tester.pumpAndSettle();
      await _submitAppPhoto(tester);
      await tester.pumpAndSettle();

      final links = server.calls(_contents);
      expect(links, hasLength(1));
      expect(links.single.method, 'POST');
      expect(links.single.headers['Idempotency-Key'], matches(_uuid));
      final photos = server.calls(_upload);
      expect(photos, hasLength(1));
      expect(photos.single.headers['Idempotency-Key'], matches(_uuid));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'G6 photo success after closing the sheet stays out of the same account home',
    (tester) async {
      final response = Completer<http.Response?>();
      final server = _Server(
        respond: (request) async =>
            request.url.path == _upload ? response.future : null,
      );
      await _withApp(tester, server, () async {
        await _submitAppPhoto(tester);
        expect(server.calls(_upload), hasLength(1));
        await _closeAppSheet(tester);

        response.complete(_json(_photoContent(), 201));
        await tester.pumpAndSettle();

        expect(find.byType(DetailScreen), findsNothing);
        _expectPhotoAbsentFromHome(tester);
        expect(tester.takeException(), isNull);
      });
    },
  );

  // -------------------------------------------------------------------------
  // #319 link save time limit: 20 seconds from the save tap, refresh and
  // resend after a 401 included. Decided toast text and no automatic retry.
  // -------------------------------------------------------------------------

  testWidgets(
    'L1 link save with no response ends at 20s with the delay toast',
    (tester) async {
      final server = _Server(
        respond: (request) async => _isLinkPost(request) ? _never() : null,
      );
      await _withApp(tester, server, () async {
        await _submitAppLink(tester);
        await tester.pump(const Duration(milliseconds: 19900));
        _expectProcessing(tester);

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        _expectDelayFailure(tester);
        expect(server.calls(_contents), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'L2 saving again after the limit sends the same key and shows the first save once',
    (tester) async {
      var posts = 0;
      final server = _Server(
        respond: (request) async {
          // The server saved the first request, so its feed lists it.
          if (request.url.path == '/api/v1/feed' && posts > 0) {
            return _savedFeed();
          }
          if (!_isLinkPost(request)) return null;
          // The first answer never arrives; the same key answers with the
          // content saved by the first request.
          return ++posts == 1 ? _never() : _json(_linkContent(), 201);
        },
      );
      await _withApp(tester, server, () async {
        await _submitAppLink(tester);
        await tester.pump(const Duration(seconds: 20));
        await tester.pump();
        _expectDelayFailure(tester);

        await tester.tap(find.text('허투루에 저장하기'));
        await tester.pumpAndSettle();

        final keys = server
            .calls(_contents)
            .map((request) => request.headers['Idempotency-Key'])
            .toList();
        expect(keys, hasLength(2));
        expect(keys.first, matches(_uuid));
        expect(keys.last, keys.first);
        expect(_result(tester).content.apiId, 7);
        expect(find.text('저장 완료'), findsOneWidget);
        expect(
          (await _homeAfterResult(tester)).where((item) => item.apiId == 7),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('L3a a response arriving after the limit changes nothing', (
    tester,
  ) async {
    final response = Completer<http.Response?>();
    final server = _Server(
      respond: (request) async => _isLinkPost(request) ? response.future : null,
    );
    await _withApp(tester, server, () async {
      await _submitAppLink(tester);
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      _expectDelayFailure(tester);

      response.complete(_json(_linkContent(), 201));
      await tester.pumpAndSettle();

      expect(find.byType(SavedContentConfirmation), findsNothing);
      expect(find.byType(DetailScreen), findsNothing);
      expect(
        tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).label,
        '허투루에 저장하기',
      );
      expect(_home(tester).contents.where((item) => item.apiId == 7), isEmpty);
      expect(server.calls(_contents), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'L3b a closed pending link save answered after the limit opens nothing',
    (tester) async {
      final response = Completer<http.Response?>();
      final server = _Server(
        respond: (request) async =>
            _isLinkPost(request) ? response.future : null,
      );
      await _withApp(tester, server, () async {
        await _submitAppLink(tester);
        await _closeAppSheet(tester);
        await tester.pump(const Duration(seconds: 20));

        response.complete(_json(_linkContent(), 201));
        await tester.pumpAndSettle();

        expect(find.byType(AddContentSheet), findsNothing);
        expect(find.byType(DetailScreen), findsNothing);
        expect(
          _home(tester).contents.where((item) => item.apiId == 7),
          isEmpty,
        );
        expect(server.calls(_contents), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'L4 a 401 refresh and resend past the limit ends with the delay toast',
    (tester) async {
      final refresh = Completer<http.Response?>();
      var posts = 0;
      final server = _Server(
        respond: (request) async {
          if (request.url.path == '/api/v1/auth/refresh') return refresh.future;
          if (!_isLinkPost(request)) return null;
          return switch (++posts) {
            1 => _json({'detail': '만료'}, 401),
            2 => _never(),
            _ => _json(_linkContent(), 201),
          };
        },
      );
      await _withApp(tester, server, () async {
        await _submitAppLink(tester);
        expect(server.calls('/api/v1/auth/refresh'), hasLength(1));
        // The refresh takes 8s (under its own 10s limit), then the resent
        // request gets no answer.
        await tester.pump(const Duration(seconds: 8));
        refresh.complete(
          _json({
            'access_token': 'refreshed-access',
            'refresh_token': 'refreshed-refresh',
            'expires_in': 3600,
            'refresh_expires_in': 86400,
          }, 201),
        );
        await tester.pump();
        await tester.pump();
        expect(server.calls(_contents), hasLength(2));
        await tester.pump(const Duration(milliseconds: 11900));
        _expectProcessing(tester);

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        _expectDelayFailure(tester);

        await tester.tap(find.text('허투루에 저장하기'));
        await tester.pumpAndSettle();
        final keys = server
            .calls(_contents)
            .map((request) => request.headers['Idempotency-Key'])
            .toList();
        expect(keys, hasLength(3));
        expect(keys.first, matches(_uuid));
        expect(keys.toSet(), {keys.first});
        expect(_result(tester).content.apiId, 7);
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final outcome in ['success', 'server error', 'disconnect']) {
    testWidgets('L5 $outcome just before the limit keeps its current result', (
      tester,
    ) async {
      final response = Completer<http.Response?>();
      final server = _Server(
        respond: (request) async {
          if (request.url.path == '/api/v1/feed' && outcome == 'success') {
            return response.isCompleted ? _savedFeed() : null;
          }
          return _isLinkPost(request) ? response.future : null;
        },
      );
      await _withApp(tester, server, () async {
        await _submitAppLink(tester);
        await tester.pump(const Duration(milliseconds: 19900));
        switch (outcome) {
          case 'success':
            response.complete(_json(_linkContent(), 201));
          case 'server error':
            response.complete(_json({'detail': '서버 오류'}, 503));
          default:
            response.completeError(http.ClientException('connection lost'));
        }
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(find.text(_delayError), findsNothing);
        if (outcome == 'success') {
          expect(_result(tester).content.apiId, 7);
          expect(
            (await _homeAfterResult(tester)).where((item) => item.apiId == 7),
            hasLength(1),
          );
        } else {
          expect(find.byType(SavedContentConfirmation), findsNothing);
          expect(
            tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).label,
            '허투루에 저장하기',
          );
        }
        expect(server.calls(_contents), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    });
  }

  // Each text scale gets its own test: Flutter reports one overflow per
  // widget, so measuring two scales in one test can hide the second.
  for (final photo in [false, true]) {
    final kind = photo ? 'photo' : 'link';
    for (final scale in [1.0, 1.3]) {
      testWidgets('L6 $kind delay toast fits 320pt at text scale $scale', (
        tester,
      ) async {
        final server = _Server(
          respond: (request) async =>
              _isLinkPost(request) || request.url.path == _upload
              ? _never()
              : null,
        );
        await _withApp(tester, server, () async {
          tester.view.physicalSize = const Size(320, 640);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          if (photo) {
            await _submitAppPhoto(tester);
            // The photo request keeps its own 10s wait for the answer.
            await tester.pump(const Duration(seconds: 10));
          } else {
            await _submitAppLink(tester);
            await tester.pump(const Duration(seconds: 20));
          }
          await tester.pump();

          if (!photo) _expectDelayFailure(tester);
          final text = find.descendant(
            of: find.byType(SaveErrorToast),
            matching: find.text(_delayError),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.textScaler.scale(1), scale);
          expect(paragraph.didExceedMaxLines, isFalse);
          final screen = tester.getRect(find.byType(AddContentSheet));
          for (final finder in [
            find.byType(SaveErrorToast),
            find.byType(SaveFlowButton),
          ]) {
            final rect = tester.getRect(finder);
            expect(rect.left, greaterThanOrEqualTo(screen.left));
            expect(rect.right, lessThanOrEqualTo(screen.right));
          }
          expect(
            tester.getRect(find.byType(SaveErrorToast)).bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(SaveFlowButton)).top),
          );
          expect(tester.takeException(), isNull);
        });
      });
    }
  }
}
