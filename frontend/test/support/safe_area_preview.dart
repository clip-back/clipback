// Local UI fixture, never a production entrypoint.
// Run: flutter run -t test/support/safe_area_preview.dart
// All API requests and login/session state stay in this process. Unsupported
// requests return an error; there is no real HTTP client or provider SDK fallback.
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> main() => runSafeAreaPreview();

Future<void> runSafeAreaPreview({
  Widget Function(Widget child)? wrapApp,
  Future<void> Function()? afterRunApp,
}) {
  late final _PreviewServer server;
  return http.runWithClient(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final image = await rootBundle.load(Assets.savedPhotoPreview);
    server = _PreviewServer(image.buffer.asUint8List());
    final app = ClipbackApp(
      sessionStorage: _MemorySessionStorage(),
      socialAuth: _PreviewSocialAuth(),
    );
    runApp(wrapApp?.call(app) ?? app);
    await afterRunApp?.call();
  }, () => server.client);
}

class _MemorySessionStorage extends ApiSessionStorage {
  ApiSession? _value;

  @override
  Future<ApiSession?> read() async => _value;
  @override
  Future<void> write(ApiSession session) async => _value = session;
  @override
  Future<void> clear() async => _value = null;
}

class _PreviewSocialAuth extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders =>
      SocialLoginProvider.values;

  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => const SocialCredential(
    token: 'local-preview-credential',
    authorizationCode: 'local-preview-code',
    providerUserId: 'local-preview-user',
  );

  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.authorized;
}

http.Response _json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _PreviewServer {
  _PreviewServer(this.image) {
    for (var index = 0; index < 90; index++) {
      records.add(_content(900 - index, index));
    }
  }

  final Uint8List image;
  final categories = <Map<String, Object?>>[
    for (var index = 0; index < 20; index++)
      {
        'id': index + 1,
        'name':
            '${const ['공부', '여행', '개발', '생활', '아이디어'][index % 5]} ${index + 1}',
        'color': const ['#059669', '#FB7185', '#3B82F6', '#F59E0B'][index % 4],
        'is_default': false,
      },
    {'id': 99, 'name': '미분류', 'color': '#B5BDC3', 'is_default': true},
  ];
  final records = <Map<String, Object?>>[];
  final viewedIds = <int>{};
  final cursors = <String, ({String filter, int offset})>{};
  var cursorNumber = 0;
  var nextContentId = 1000;
  var nextCategoryId = 100;
  String? provider;

  Map<String, Object?> _content(int id, int index, {bool? screenshot}) {
    final isScreenshot = screenshot ?? index % 5 == 0;
    return {
      'id': id,
      'categories': [categories[index % 20]],
      'tags': [
        {'name': '안전영역'},
        {'name': '화면확인'},
      ],
      'assets': isScreenshot
          ? [
              {
                'id': 10000 + id,
                'asset_type': 'screenshot',
                'download_url': '/api/v1/uploads/assets/${10000 + id}',
                'mime_type': 'image/png',
              },
            ]
          : <Object>[],
      'content_type': isScreenshot ? 'screenshot' : 'link',
      'source': isScreenshot ? 'screenshot' : 'web',
      'title': '${isScreenshot ? '스크린샷' : '저장한 링크'} 화면 확인 ${index + 1}',
      'summary':
          '상단 버튼, 긴 목록, 카테고리 시트와 키보드가 겹치지 않는지 확인하는 로컬 예시입니다. '
          '현재 목록의 ${index + 1}번째 콘텐츠로 상세 화면과 이전·다음 이동을 확인할 수 있습니다.',
      'summary_status': 'completed',
      'original_url': isScreenshot ? null : 'https://example.invalid/item/$id',
      'is_favorite': index % 3 == 0,
      'saved_at': DateTime.utc(
        2026,
        10,
        12,
      ).subtract(Duration(minutes: index)).toIso8601String(),
      'last_viewed_at': null,
    };
  }

  List<Map<String, Object?>> _selectedCategories(Object? ids) {
    final selected = categories
        .where((category) => (ids as List? ?? []).contains(category['id']))
        .toList();
    return selected.isEmpty
        ? [categories.firstWhere((category) => category['is_default'] == true)]
        : selected;
  }

  List<Map<String, Object?>> _categoryCounts() => [
    for (final category in categories)
      {
        ...category,
        'content_count': records
            .where(
              (content) => (content['categories'] as List).any(
                (value) => (value as Map)['id'] == category['id'],
              ),
            )
            .length,
        'last_saved_at': '2026-10-12T00:00:00Z',
      },
  ];

  http.Response _feed(http.BaseRequest request) {
    final query = request.url.queryParameters;
    final filter =
        '${query['q']}|${query['category_id']}|${query['is_favorite']}';
    final cursor = query['cursor'];
    final position = cursor == null ? null : cursors[cursor];
    if (cursor != null && (position == null || position.filter != filter)) {
      return _json({'detail': 'Invalid preview cursor'}, 400);
    }
    final matching = records.where((content) {
      final category = int.tryParse(query['category_id'] ?? '');
      if (category != null &&
          !(content['categories'] as List).any(
            (value) => (value as Map)['id'] == category,
          )) {
        return false;
      }
      if (query['is_favorite'] case final favorite?) {
        if (content['is_favorite'] != (favorite == 'true')) return false;
      }
      final term = query['q']?.trim().toLowerCase() ?? '';
      return '${content['title']} ${content['summary']}'.toLowerCase().contains(
        term,
      );
    }).toList();
    final offset = (position?.offset ?? 0).clamp(0, matching.length);
    final end = (offset + (int.tryParse(query['limit'] ?? '') ?? 20)).clamp(
      offset,
      matching.length,
    );
    String? next;
    if (end < matching.length) {
      next = 'preview-${++cursorNumber}';
      cursors[next] = (filter: filter, offset: end);
    }
    return _json({'items': matching.sublist(offset, end), 'next_cursor': next});
  }

  late final client = MockClient.streaming((request, body) async {
    final bytes = await body.toBytes();
    final isJson =
        request.headers['content-type']?.contains('application/json') ?? false;
    final data = isJson && bytes.isNotEmpty
        ? Map<String, Object?>.from(jsonDecode(utf8.decode(bytes)) as Map)
        : <String, Object?>{};
    final response = _respond(request, data);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  });

  http.Response _respond(http.BaseRequest request, Map<String, Object?> data) {
    final path = request.url.path;
    final method = request.method;
    if (method == 'POST' && path == '/api/v1/auth/social/apple/challenge') {
      return _json({
        'challenge_id': 'preview-challenge',
        'nonce': 'preview-nonce',
      });
    }
    final social = RegExp(
      r'^/api/v1/auth/social/(google|kakao|apple)(/upgrade)?$',
    ).firstMatch(path);
    if (method == 'POST' &&
        (path == '/api/v1/auth/guest' ||
            path == '/api/v1/auth/refresh' ||
            social != null)) {
      if (path.endsWith('/guest')) provider = null;
      if (social != null) provider = social.group(1);
      return _json({
        'access_token': 'local-preview-access',
        'refresh_token': 'local-preview-refresh',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
        'is_new_user': true,
      }, 201);
    }
    if (method == 'POST' && path == '/api/v1/auth/logout') {
      return http.Response('', 204);
    }
    if (method == 'GET' && path == '/api/v1/users/me') {
      return _json({
        'id': 1,
        'email': null,
        'display_name': '안전 영역 확인용 계정',
        'is_guest': provider == null,
        'created_at': '2026-10-12T00:00:00Z',
        'linked_providers': [if (provider != null) provider],
      });
    }
    if (method == 'GET' && path == '/api/v1/users/me/stats') {
      return _json({
        'saved_count': records.length,
        'reopened_count': viewedIds.length,
      });
    }
    if (method == 'GET' && path == '/api/v1/feed') return _feed(request);
    if (method == 'POST' && path == '/api/v1/metrics/events') {
      return _json({}, 201);
    }
    if (method == 'GET' && path == '/api/v1/categories') {
      return _json(_categoryCounts());
    }
    if (method == 'POST' && path == '/api/v1/categories') {
      final category = <String, Object?>{
        'id': nextCategoryId++,
        'name': data['name'],
        'color': data['color'],
        'is_default': false,
      };
      categories.add(category);
      return _json(category, 201);
    }
    final categoryMatch = RegExp(
      r'^/api/v1/categories/(\d+)$',
    ).firstMatch(path);
    if (categoryMatch != null) {
      final id = int.parse(categoryMatch.group(1)!);
      final category = categories
          .where((value) => value['id'] == id)
          .firstOrNull;
      if (category != null && method == 'PATCH') {
        category.addAll(data);
        return _json(category);
      }
      if (category != null &&
          method == 'DELETE' &&
          category['is_default'] != true) {
        categories.remove(category);
        for (final record in records) {
          final selected = (record['categories'] as List)
              .where((value) => (value as Map)['id'] != id)
              .toList();
          record['categories'] = selected.isEmpty
              ? [categories.firstWhere((value) => value['is_default'] == true)]
              : selected;
        }
        return http.Response('', 204);
      }
    }
    final assetMatch = RegExp(
      r'^/api/v1/uploads/assets/(\d+)$',
    ).firstMatch(path);
    if (method == 'GET' && assetMatch != null) {
      final assetId = int.parse(assetMatch.group(1)!);
      if (records.any(
        (record) => (record['assets'] as List).any(
          (asset) => (asset as Map)['id'] == assetId,
        ),
      )) {
        return http.Response.bytes(
          image,
          200,
          headers: {'content-type': 'image/png'},
        );
      }
    }
    if (method == 'POST' &&
        (path == '/api/v1/contents' || path == '/api/v1/uploads/screenshots')) {
      final screenshot = path.endsWith('/screenshots');
      final created = _content(nextContentId++, 0, screenshot: screenshot);
      created['categories'] = _selectedCategories(data['category_ids']);
      created['title'] = screenshot ? '새 스크린샷 화면 확인' : '새 링크 화면 확인';
      if (!screenshot) created['original_url'] = data['original_url'];
      records.insert(0, created);
      return _json(created, 201);
    }
    final contentMatch = RegExp(
      r'^/api/v1/contents/(\d+)(?:/(view|favorite|categories))?$',
    ).firstMatch(path);
    if (contentMatch != null) {
      final id = int.parse(contentMatch.group(1)!);
      final record = records.where((value) => value['id'] == id).firstOrNull;
      final action = contentMatch.group(2);
      if (record != null) {
        if (method == 'GET' && action == null) return _json(record);
        if (method == 'POST' && action == 'view') {
          viewedIds.add(id);
          return _json({}, 201);
        }
        if (method == 'PUT' && action == 'favorite') {
          record['is_favorite'] = data['is_favorite'];
          return _json(record);
        }
        if (method == 'PUT' && action == 'categories') {
          record['categories'] = _selectedCategories(data['category_ids']);
          return _json(record);
        }
        if (method == 'DELETE' && action == null) {
          records.remove(record);
          return http.Response('', 204);
        }
      }
    }
    return _json({
      'detail': 'Unsupported local preview request: $method $path',
    }, 404);
  }
}
