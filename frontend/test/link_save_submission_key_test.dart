// Link save submission key (#298): a retry of the same link on the same save
// sheet reuses its key so the server can return the content it already saved.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_startup.dart';
import 'support/memory_api_session_storage.dart';

const _contents = '/api/v1/contents';
const _link = 'https://example.com/g-link';
const _defaultError = '저장하지 못했어요. 다시 시도해 주세요.';
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
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

Map<String, Object?> _linkContent([int id = 7]) => {
  'id': id,
  'categories': [_category],
  'tags': <Object>[],
  'assets': <Object>[],
  'content_type': 'link',
  'source': 'web',
  'title': '링크 저장 결과',
  'summary': '링크 요약',
  'original_url': _link,
  'is_favorite': false,
  'saved_at': '2026-10-06T00:00:00Z',
  'last_viewed_at': null,
};

class _Server {
  _Server({this.respond});

  final Future<http.Response?> Function(http.Request)? respond;
  final requests = <http.Request>[];
  // Saved rows by submission key: a key saves one row, as the server's
  // receipt guarantees, while a request without a key always saves a new one.
  final rows = <String, Map<String, Object?>>{};
  late final client = MockClient((request) async {
    requests.add(request);
    final response = await respond?.call(request);
    if (response != null) return response;
    switch (request.url.path) {
      case _contents:
        return _json(save(request), 201);
      case '/api/v1/contents/7':
        return _json(_linkContent());
      case '/api/v1/categories':
        return _json([_category]);
      case '/api/v1/feed':
        return _json({'items': rows.values.toList(), 'next_cursor': null});
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
        return _json({'saved_count': 0, 'reopened_count': 0});
      case '/api/v1/recommendations/weekly':
        return _json({
          'period_start': '2026-10-19T00:00:00Z',
          'period_end': '2026-10-26T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        });
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

  Map<String, Object?> save(http.Request request) => rows.putIfAbsent(
    request.headers['Idempotency-Key'] ?? 'no-key-${rows.length}',
    () => _linkContent(7 + rows.length),
  );

  List<String?> keys() => requests
      .where((request) => request.url.path == _contents)
      .map((request) => request.headers['Idempotency-Key'])
      .toList();
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
            sessionStorage: MemoryApiSessionStorage(),
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

Future<void> _openSheet(WidgetTester tester) async {
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

Future<void> _enter(WidgetTester tester, String url) async {
  await tester.enterText(find.byType(TextField), url);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('허투루에 저장하기'));
  await tester.pumpAndSettle();
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tap(find.text('저장 완료'));
  await tester.pumpAndSettle();
  tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  testWidgets(
    'retry after a lost save response reuses the key and shows one content',
    (tester) async {
      late final _Server server;
      server = _Server(
        respond: (request) async {
          if (request.url.path != _contents || server.rows.isNotEmpty) {
            return null;
          }
          // The server saves the first request, but its response is lost.
          server.save(request);
          throw http.ClientException('Connection reset by peer');
        },
      );
      await _withApp(tester, server, () async {
        await _openSheet(tester);
        await _enter(tester, _link);
        await _submit(tester);
        expect(find.text(_defaultError), findsOneWidget);
        expect(find.byType(SavedContentConfirmation), findsNothing);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        await _submit(tester);
        final keys = server.keys();
        expect(keys, hasLength(2));
        expect(keys.first, matches(_uuid));
        expect(keys.last, keys.first);
        final result = tester.widget<SavedContentConfirmation>(
          find.byType(SavedContentConfirmation),
        );
        expect(result.content.apiId, 7);
        await _closeSheet(tester);
        expect(
          _home(tester).contents.where((item) => item.apiId == 7),
          hasLength(1),
        );
        expect(_home(tester).contents, hasLength(1));
      });
    },
  );

  testWidgets('a changed address gets a new key', (tester) async {
    var posts = 0;
    final server = _Server(
      respond: (request) async => request.url.path == _contents && ++posts == 1
          ? _json({'detail': 'Injected failure'}, 500)
          : null,
    );
    await _withApp(tester, server, () async {
      await _openSheet(tester);
      await _enter(tester, _link);
      await _submit(tester);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await _enter(tester, 'https://example.com/other-link');
      await _submit(tester);
      final keys = server.keys();
      expect(keys, hasLength(2));
      expect(keys.first, matches(_uuid));
      expect(keys.last, matches(_uuid));
      expect(keys.last, isNot(keys.first));
    });
  });

  testWidgets('the same address on a newly opened sheet gets a new key', (
    tester,
  ) async {
    final server = _Server();
    await _withApp(tester, server, () async {
      await _openSheet(tester);
      await _enter(tester, _link);
      await _submit(tester);
      await _closeSheet(tester);
      await _openSheet(tester);
      await _enter(tester, _link);
      await _submit(tester);
      final keys = server.keys();
      expect(keys, hasLength(2));
      expect(keys.first, matches(_uuid));
      expect(keys.last, matches(_uuid));
      expect(keys.last, isNot(keys.first));
    });
  });

  for (final status in [409, 410]) {
    testWidgets('link $status never becomes success or a fresh submission', (
      tester,
    ) async {
      final server = _Server(
        respond: (request) async => request.url.path == _contents
            ? _json({'detail': 'Submission rejected'}, status)
            : null,
      );
      await _withApp(tester, server, () async {
        await _openSheet(tester);
        await _enter(tester, _link);
        for (var attempt = 0; attempt < 2; attempt++) {
          await _submit(tester);
          expect(find.text('Submission rejected'), findsOneWidget);
          expect(find.byType(SavedContentConfirmation), findsNothing);
          expect(find.text(_link), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
        }
        final keys = server.keys();
        expect(keys, hasLength(2));
        expect(keys.first, matches(_uuid));
        expect(keys.last, keys.first);
        expect(_home(tester).contents, isEmpty);
      });
    });
  }

  test('link submission key survives authentication refresh', () async {
    final keys = <String?>[];
    final client = MockClient((request) async {
      switch (request.url.path) {
        case _contents:
          keys.add(request.headers['Idempotency-Key']);
          return request.headers['Authorization'] == 'Bearer old-access'
              ? _json({'detail': 'Invalid or expired token'}, 401)
              : _json(_linkContent(), 201);
        case '/api/v1/auth/refresh':
          return _json({
            'access_token': 'rotated-access',
            'refresh_token': 'rotated-refresh',
            'expires_in': 7200,
            'refresh_expires_in': 172800,
          });
        default:
          throw StateError('Unexpected request: ${request.url}');
      }
    });
    addTearDown(client.close);
    final api = ClipbackApi(client: client)
      ..restoreSession(
        const ApiSession(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          expiresIn: 3600,
          refreshExpiresIn: 86400,
        ),
      );
    await api.createContent(
      originalUrl: _link,
      categoryIds: const [],
      submissionKey: '7c6ae050-df1c-4f3e-a280-5a09319e3a7e',
    );
    expect(keys, [
      '7c6ae050-df1c-4f3e-a280-5a09319e3a7e',
      '7c6ae050-df1c-4f3e-a280-5a09319e3a7e',
    ]);
  });
}
