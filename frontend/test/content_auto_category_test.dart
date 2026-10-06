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

const _contents = '/api/v1/contents';
const _upload = '/api/v1/uploads/screenshots';
const _videoUrl = 'https://youtu.be/dQw4w9WgXcQ';
const _first = {
  'id': 101,
  'name': '첫 카테고리',
  'color': '#059669',
  'is_default': false,
};
const _recommended = {
  'id': 202,
  'name': '서버 분류',
  'color': '#059669',
  'is_default': false,
};
const _uncategorized = {
  'id': 303,
  'name': '미분류',
  'color': '#B5BDC3',
  'is_default': true,
};
const _hashCategory = {
  'id': 404,
  'name': '###',
  'color': '#059669',
  'is_default': false,
};
const _pendingMessage = '동영상 정보를 처리 중이에요. 분류는 나중에 반영될 수 있어요.';
const _unclassifiedMessage = '아직 분류되지 않았어요.';
const _classifiedMessage = '저장된 카테고리';
const _changeHint = '분류는 상세 화면에서 변경할 수 있어요.';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _content({bool screenshot = false}) => {
  'id': 7,
  'categories': [_recommended],
  'tags': <Object>[],
  'assets': <Object>[],
  'content_type': screenshot ? 'screenshot' : 'link',
  'source': screenshot ? 'screenshot' : 'web',
  'title': '서버 응답 제목',
  'summary': '서버 응답 요약',
  'original_url': screenshot ? null : 'https://example.com/auto-category',
  'is_favorite': false,
  'saved_at': '2026-10-06T00:00:00Z',
  'last_viewed_at': null,
};

class _Call {
  _Call(this.request, this.bytes);
  final http.BaseRequest request;
  final List<int> bytes;

  Map<String, dynamic> get json =>
      Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);

  List<String> values(String name) {
    final boundary = RegExp(
      r'boundary=([^;]+)',
    ).firstMatch(request.headers['content-type'] ?? '')?.group(1);
    if (boundary == null) return [];
    final values = <String>[];
    for (final part in latin1.decode(bytes).split('--$boundary')) {
      final separator = part.indexOf('\r\n\r\n');
      if (separator < 0) continue;
      final header = part.substring(0, separator);
      if (!header.contains('name="$name"') || header.contains('filename=')) {
        continue;
      }
      final data = part.substring(separator + 4, part.length - 2);
      values.add(utf8.decode(latin1.encode(data)));
    }
    return values;
  }
}

class _Server {
  _Server({this.source, this.summaryStatus, this.category = _recommended});
  final String? source;
  final String? summaryStatus;
  final Map<String, Object> category;
  final calls = <_Call>[];
  Map<String, Object?>? saved;
  late final client = MockClient.streaming((request, stream) async {
    final call = _Call(request, await stream.toBytes());
    calls.add(call);
    late final http.Response response;
    switch (request.url.path) {
      case _contents:
      case _upload:
        saved = {
          ..._content(screenshot: request.url.path == _upload),
          'categories': [category],
          if (source != null) 'source': source,
          if (source == 'youtube') 'original_url': _videoUrl,
          if (summaryStatus != null) 'summary_status': summaryStatus,
        };
        response = _json(saved!, 201);
      case '/api/v1/categories':
        response = _json([_first, _recommended, _uncategorized, _hashCategory]);
      case '/api/v1/feed':
        response = _json({
          'items': saved == null ? <Object>[] : [saved],
          'next_cursor': null,
        });
      case '/api/v1/users/me':
        response = _json({
          'id': 1,
          'email': null,
          'display_name': '테스트 계정',
          'is_guest': true,
          'created_at': '2026-10-06T00:00:00Z',
          'linked_providers': <String>[],
        });
      case '/api/v1/users/me/stats':
        response = _json({
          'saved_count': saved == null ? 0 : 1,
          'reopened_count': 0,
        });
      case '/api/v1/contents/7':
        response = _json(saved!);
      case '/api/v1/contents/7/view':
      case '/api/v1/metrics/events':
        response = _json(<String, Object>{}, 201);
      default:
        throw StateError('Unexpected request: ${request.url.path}');
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  });

  List<_Call> at(String path) =>
      calls.where((call) => call.request.url.path == path).toList();
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

Future<void> _withApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check,
) async {
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

Future<void> _openSave(WidgetTester tester) async {
  final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
  unawaited(
    showContentSaveScreen(
      context: tester.element(find.byType(HomeScreen)),
      onAddLink: home.onAddLink,
      onAddScreenshot: home.onAddScreenshot,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveLink(
  WidgetTester tester, {
  String url = 'https://example.com/auto-category',
}) async {
  await _openSave(tester);
  await tester.enterText(find.byType(TextField), url);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('허투루에 저장하기'));
  await tester.pumpAndSettle();
}

Future<void> _savePhoto(WidgetTester tester) async {
  final previous = FilePicker.platform;
  FilePicker.platform = _Picker();
  addTearDown(() => FilePicker.platform = previous);
  await _openSave(tester);
  await tester.tap(find.text('사진 첨부'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('사진 선택'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('허투루에 저장하기'));
  await tester.pumpAndSettle();
}

void _expectNoClassificationWrites(_Server server) {
  expect(server.calls.where((call) => call.request.method == 'PUT'), isEmpty);
  expect(
    server.calls.where((call) => call.request.url.path.contains('summary')),
    isEmpty,
  );
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

  testWidgets(
    'unselected link requests automatic classification without a name tag',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _saveLink(tester);
        final body = server.at(_contents).single.json;
        expect(
          {
            'category_ids': body['category_ids'],
            'tag_names': body['tag_names'],
          },
          {'category_ids': <Object>[], 'tag_names': <Object>[]},
        );
      });
    },
  );

  testWidgets(
    'unselected screenshot sends no category or tag multipart parts',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _savePhoto(tester);
        final upload = server.at(_upload).single;
        expect(
          {
            'category_ids': upload.values('category_ids'),
            'tag_names': upload.values('tag_names'),
          },
          {'category_ids': <String>[], 'tag_names': <String>[]},
        );
      });
    },
  );

  testWidgets(
    'saved confirmation does not claim automatic classification succeeded',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _saveLink(tester);
        expect(find.byType(SavedContentConfirmation), findsOneWidget);
        expect(find.text('허투루가 자동으로 분류했어요!'), findsNothing);
        expect(find.text('변경'), findsNothing);
        expect(find.text(_classifiedMessage), findsOneWidget);
        expect(find.text(_changeHint), findsOneWidget);
      });
    },
  );

  for (final status in [
    'not_requested',
    'queued',
    'processing',
    'completed',
    'failed',
    'skipped',
  ]) {
    test('ApiContent preserves summary status $status', () {
      expect(
        ApiContent.fromJson({
          ..._content(),
          'summary_status': status,
        }).summaryStatus,
        status,
      );
    });
  }

  for (final nullValue in [false, true]) {
    test(
      'missing or null summary status defaults to not_requested ($nullValue)',
      () {
        final json = _content();
        if (nullValue) json['summary_status'] = null;
        expect(ApiContent.fromJson(json).summaryStatus, 'not_requested');
      },
    );
  }

  test('existing model constructors retain the not_requested default', () {
    final content = ApiContent(
      id: 7,
      categories: const [],
      tags: const [],
      assets: const [],
      contentType: 'link',
      source: 'web',
      title: '기존 호출',
      summary: '',
      originalUrl: null,
      isFavorite: false,
      savedAt: DateTime.utc(2026, 10, 6),
      lastViewedAt: null,
    );
    expect(content.summaryStatus, 'not_requested');
    expect(initialContents.first.summaryStatus, 'not_requested');
  });

  test(
    'explicit API category lists and user tags remain intact for JSON saves',
    () async {
      final server = _Server();
      addTearDown(server.client.close);
      final api = ClipbackApi(client: server.client)
        ..restoreSession(
          const ApiSession(
            accessToken: 'test-access',
            refreshToken: 'test-refresh',
            expiresIn: 3600,
            refreshExpiresIn: 86400,
          ),
        );
      await api.createContent(
        originalUrl: 'https://example.com/manual',
        categoryIds: [101, 202],
        tagNames: ['사용자 태그', '두 번째 태그'],
      );
      final body = server.at(_contents).single.json;
      expect(body['category_ids'], [101, 202]);
      expect(body['tag_names'], ['사용자 태그', '두 번째 태그']);
    },
  );

  for (final status in ['queued', 'failed', 'completed']) {
    test(
      'copyWith preserves summary status $status when category or bookmark changes',
      () {
        final original = ContentItem(
          id: 'api-7',
          apiId: 7,
          title: '동영상',
          summary: '',
          category: catUncategorized,
          savedAt: '',
          savedAtFull: '',
          savedAtFullShort: '',
          tags: const [],
          source: '유튜브',
          originalUrl: 'https://youtu.be/example',
          originalText: '',
          summaryStatus: status,
        );
        final categorized = original.copyWith(category: catJob);
        final bookmarked = original.copyWith(bookmarked: true);
        expect(categorized.summaryStatus, status);
        expect(categorized.category, same(catJob));
        expect(bookmarked.summaryStatus, status);
        expect(bookmarked.bookmarked, isTrue);
        expect(bookmarked.category, same(catUncategorized));
      },
    );
  }

  for (final screenshot in [false, true]) {
    testWidgets(
      'server-selected category replaces the first category in ${screenshot ? 'photo' : 'link'} confirmation',
      (tester) async {
        final server = _Server();
        await _withApp(tester, server, () async {
          if (screenshot) {
            await _savePhoto(tester);
          } else {
            await _saveLink(tester);
          }
          final confirmation = tester.widget<SavedContentConfirmation>(
            find.byType(SavedContentConfirmation),
          );
          expect(confirmation.content.category.id, _recommended['id']);
          expect(confirmation.content.category.name, _recommended['name']);
          expect(confirmation.content.tags, isEmpty);
          expect(find.text('서버 분류'), findsWidgets);
          expect(find.text(_classifiedMessage), findsOneWidget);
          expect(find.text('허투루가 자동으로 분류했어요!'), findsNothing);
          expect(find.text(_changeHint), findsOneWidget);
          expect(find.text('변경'), findsNothing);
          _expectNoClassificationWrites(server);
          await tester.tap(find.text('닫기'));
          await tester.pumpAndSettle();
          final detail = tester
              .widget<DetailScreen>(find.byType(DetailScreen))
              .content;
          expect(detail.category.id, _recommended['id']);
          expect(detail.summaryStatus, 'not_requested');
        });
      },
    );
  }

  for (final category in [_first, _uncategorized, _hashCategory]) {
    for (final screenshot in [false, true]) {
      testWidgets(
        'explicit ${category['name']} ${screenshot ? 'photo' : 'link'} callback keeps its ID without a category-name tag',
        (tester) async {
          final server = _Server(category: category);
          await _withApp(tester, server, () async {
            final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
            final selected = home.categories.singleWhere(
              (item) => item.id == category['id'],
            );
            final item = screenshot
                ? await home.onAddScreenshot(
                    bytes: _png,
                    filename: 'screen.png',
                    category: selected,
                  )
                : await home.onAddLink(
                    url: 'https://example.com/manual',
                    category: selected,
                  );
            await tester.pumpAndSettle();
            if (screenshot) {
              final upload = server.at(_upload).single;
              expect(upload.values('category_ids'), ['${category['id']}']);
              expect(upload.values('tag_names'), isEmpty);
            } else {
              final body = server.at(_contents).single.json;
              expect(body['category_ids'], [category['id']]);
              expect(body['tag_names'], isEmpty);
            }
            expect(item.category.id, category['id']);
            expect(item.tags, isEmpty);
            expect(
              tester
                  .widget<DetailScreen>(find.byType(DetailScreen))
                  .content
                  .category
                  .id,
              category['id'],
            );
            _expectNoClassificationWrites(server);
          });
        },
      );
    }
  }

  for (final screenshot in [false, true]) {
    testWidgets(
      'explicit null category uses automatic ${screenshot ? 'photo' : 'link'} callback',
      (tester) async {
        final server = _Server();
        await _withApp(tester, server, () async {
          final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
          final item = screenshot
              ? await home.onAddScreenshot(
                  bytes: _png,
                  filename: 'screen.png',
                  category: null,
                )
              : await home.onAddLink(
                  url: 'https://example.com/nullable',
                  category: null,
                );
          await tester.pumpAndSettle();
          if (screenshot) {
            final upload = server.at(_upload).single;
            expect(upload.values('category_ids'), isEmpty);
            expect(upload.values('tag_names'), isEmpty);
          } else {
            final body = server.at(_contents).single.json;
            expect(body['category_ids'], isEmpty);
            expect(body['tag_names'], isEmpty);
          }
          expect(item.category.id, _recommended['id']);
          _expectNoClassificationWrites(server);
        });
      },
    );
  }

  for (final category in [_uncategorized, _recommended]) {
    for (final status in [
      'queued',
      'processing',
      'failed',
      'skipped',
      'completed',
    ]) {
      testWidgets(
        'YouTube $status with ${category['name']} reports returned state without success claims',
        (tester) async {
          final server = _Server(
            source: 'youtube',
            summaryStatus: status,
            category: category,
          );
          await _withApp(tester, server, () async {
            await _saveLink(tester, url: _videoUrl);
            final content = tester
                .widget<SavedContentConfirmation>(
                  find.byType(SavedContentConfirmation),
                )
                .content;
            expect(content.source, '유튜브');
            expect(content.summaryStatus, status);
            expect(content.category.id, category['id']);
            final expected = ['queued', 'processing'].contains(status)
                ? _pendingMessage
                : category['is_default'] == true
                ? _unclassifiedMessage
                : _classifiedMessage;
            expect(find.text(expected), findsOneWidget);
            expect(find.text('허투루가 자동으로 분류했어요!'), findsNothing);
            expect(find.text(_changeHint), findsOneWidget);
            _expectNoClassificationWrites(server);
          });
        },
      );
    }
  }

  for (final screenshot in [false, true]) {
    testWidgets(
      'unclassified ${screenshot ? 'photo' : 'web link'} uses neutral wording',
      (tester) async {
        final server = _Server(
          category: _uncategorized,
          summaryStatus: 'queued',
        );
        await _withApp(tester, server, () async {
          if (screenshot) {
            await _savePhoto(tester);
          } else {
            await _saveLink(tester);
          }
          expect(find.text(_unclassifiedMessage), findsOneWidget);
          expect(find.text(_pendingMessage), findsNothing);
          expect(find.text('허투루가 자동으로 분류했어요!'), findsNothing);
        });
      },
    );
  }

  testWidgets(
    'YouTube completion is read on the next detail entry without polling or classification PUT',
    (tester) async {
      final server = _Server(
        source: 'youtube',
        summaryStatus: 'queued',
        category: _uncategorized,
      );
      await _withApp(tester, server, () async {
        await _saveLink(tester, url: _videoUrl);
        expect(find.text(_pendingMessage), findsOneWidget);
        final callsAfterSave = server.calls.length;
        await tester.pump(const Duration(seconds: 30));
        expect(server.calls, hasLength(callsAfterSave));
        expect(server.at('/api/v1/contents/7'), isEmpty);
        server.saved = {
          ...server.saved!,
          'summary_status': 'completed',
          'categories': [_recommended],
        };
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DetailScreen>(find.byType(DetailScreen))
              .content
              .summaryStatus,
          'queued',
        );
        tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
        await tester.pumpAndSettle();
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        home.onOpenContent(home.contents.single);
        await tester.pumpAndSettle();
        final detail = tester
            .widget<DetailScreen>(find.byType(DetailScreen))
            .content;
        expect(detail.summaryStatus, 'completed');
        expect(detail.category.id, _recommended['id']);
        expect(find.text('서버 분류'), findsWidgets);
        expect(server.at(_contents), hasLength(1));
        expect(server.at('/api/v1/contents/7'), hasLength(1));
        _expectNoClassificationWrites(server);
      });
    },
  );

  testWidgets('a new app instance restores completed server classification', (
    tester,
  ) async {
    final server = _Server(
      source: 'youtube',
      summaryStatus: 'processing',
      category: _uncategorized,
    );
    await _withApp(tester, server, () async {
      await _saveLink(tester, url: _videoUrl);
      expect(find.text(_pendingMessage), findsOneWidget);
      server.saved = {
        ...server.saved!,
        'summary_status': 'completed',
        'categories': [_recommended],
      };
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        Theme(
          data: ThemeData(fontFamily: 'Pretendard'),
          child: const ClipbackApp(),
        ),
      );
      await tester.pumpAndSettle();
      final contents = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .contents;
      expect(contents, hasLength(1));
      expect(contents.single.summaryStatus, 'completed');
      expect(contents.single.category.id, _recommended['id']);
      expect(find.text('서버 응답 제목'), findsWidgets);
      expect(server.at(_contents), hasLength(1));
      expect(server.at('/api/v1/feed'), hasLength(3));
      expect(server.at('/api/v1/auth/guest'), isEmpty);
      _expectNoClassificationWrites(server);
    });
  });
}
