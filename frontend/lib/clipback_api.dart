import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClipbackApiException implements Exception {
  const ClipbackApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiSession {
  const ApiSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.refreshExpiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final int refreshExpiresIn;

  factory ApiSession.fromJson(Map<String, dynamic> json) {
    return ApiSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      refreshExpiresIn: json['refresh_expires_in'] as int,
    );
  }
}

class ApiSessionStorage {
  static const _accessTokenKey = 'clipback.access_token';
  static const _refreshTokenKey = 'clipback.refresh_token';
  static const _expiresInKey = 'clipback.expires_in';
  static const _refreshExpiresInKey = 'clipback.refresh_expires_in';

  Future<ApiSession?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final accessToken = preferences.getString(_accessTokenKey);
    final refreshToken = preferences.getString(_refreshTokenKey);
    if (accessToken == null || refreshToken == null) return null;
    return ApiSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: _readInt(preferences, _expiresInKey),
      refreshExpiresIn: _readInt(preferences, _refreshExpiresInKey),
    );
  }

  Future<void> write(ApiSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_accessTokenKey, session.accessToken),
      preferences.setString(_refreshTokenKey, session.refreshToken),
      preferences.setInt(_expiresInKey, session.expiresIn),
      preferences.setInt(_refreshExpiresInKey, session.refreshExpiresIn),
    ]);
  }

  int _readInt(SharedPreferences preferences, String key) {
    final value = preferences.get(key);
    return switch (value) {
      int value => value,
      String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_accessTokenKey),
      preferences.remove(_refreshTokenKey),
      preferences.remove(_expiresInKey),
      preferences.remove(_refreshExpiresInKey),
    ]);
  }
}

class ApiCategory {
  const ApiCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.isDefault,
    this.contentCount = 0,
    this.lastSavedAt,
  });

  final int id;
  final String name;
  final String? color;
  final bool isDefault;
  final int contentCount;
  final DateTime? lastSavedAt;

  factory ApiCategory.fromJson(Map<String, dynamic> json) {
    return ApiCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      color: json['color'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      contentCount: json['content_count'] as int? ?? 0,
      lastSavedAt: _dateTime(json['last_saved_at']),
    );
  }
}

class ApiAsset {
  const ApiAsset({
    required this.id,
    required this.assetType,
    required this.downloadUrl,
    this.mimeType,
  });

  final int id;
  final String assetType;
  final String downloadUrl;
  final String? mimeType;

  factory ApiAsset.fromJson(Map<String, dynamic> json) => ApiAsset(
    id: json['id'] as int,
    assetType: json['asset_type'] as String,
    downloadUrl: json['download_url'] as String,
    mimeType: json['mime_type'] as String?,
  );
}

class ApiContent {
  const ApiContent({
    required this.id,
    required this.categories,
    required this.tags,
    required this.assets,
    required this.contentType,
    required this.source,
    required this.title,
    required this.summary,
    required this.originalUrl,
    required this.isFavorite,
    required this.savedAt,
    required this.lastViewedAt,
  });

  final int id;
  final List<ApiCategory> categories;
  final List<String> tags;
  final List<ApiAsset> assets;
  final String contentType;
  final String source;
  final String title;
  final String summary;
  final String? originalUrl;
  final bool isFavorite;
  final DateTime savedAt;
  final DateTime? lastViewedAt;

  factory ApiContent.fromJson(Map<String, dynamic> json) {
    return ApiContent(
      id: json['id'] as int,
      categories: _jsonList(
        json['categories'],
      ).map(ApiCategory.fromJson).toList(),
      tags: _jsonList(
        json['tags'],
      ).map((item) => item['name'] as String).toList(),
      assets: _jsonList(json['assets']).map(ApiAsset.fromJson).toList(),
      contentType: json['content_type'] as String,
      source: json['source'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      originalUrl: json['original_url'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      savedAt: _dateTime(json['saved_at'])!,
      lastViewedAt: _dateTime(json['last_viewed_at']),
    );
  }
}

class ApiFeed {
  const ApiFeed({required this.items, this.nextCursor});

  final List<ApiContent> items;
  final String? nextCursor;

  factory ApiFeed.fromJson(Map<String, dynamic> json) => ApiFeed(
    items: _jsonList(json['items']).map(ApiContent.fromJson).toList(),
    nextCursor: json['next_cursor'] as String?,
  );
}

class ApiUser {
  const ApiUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.isGuest,
    required this.createdAt,
    required this.linkedProviders,
  });

  final int id;
  final String? email;
  final String displayName;
  final bool isGuest;
  final DateTime createdAt;
  final List<String> linkedProviders;

  factory ApiUser.fromJson(Map<String, dynamic> json) => ApiUser(
    id: json['id'] as int,
    email: json['email'] as String?,
    displayName: json['display_name'] as String,
    isGuest: json['is_guest'] as bool,
    createdAt: _dateTime(json['created_at'])!,
    linkedProviders: List<String>.from(json['linked_providers'] as List),
  );
}

class ApiUserStats {
  const ApiUserStats({required this.savedCount, required this.reopenedCount});

  final int savedCount;
  final int reopenedCount;

  factory ApiUserStats.fromJson(Map<String, dynamic> json) => ApiUserStats(
    savedCount: json['saved_count'] as int,
    reopenedCount: json['reopened_count'] as int,
  );
}

class ClipbackApi {
  ClipbackApi({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = String.fromEnvironment(
    'CLIPBACK_API_BASE_URL',
    defaultValue: 'https://clipback-production.up.railway.app/api/v1',
  );

  final http.Client _client;
  ApiSession? _session;

  bool get hasSession => _session != null;
  ApiSession? get session => _session;

  void restoreSession(ApiSession session) => _session = session;

  void clearSession() => _session = null;

  Future<Map<String, String>> health() => _getPublic('/health');

  Future<Map<String, String>> readiness() => _getPublic('/health/ready');

  Future<ApiSession> createGuestSession() async {
    final session = ApiSession.fromJson(await _json('POST', '/auth/guest'));
    _session = session;
    return session;
  }

  Future<ApiSession> refreshSession() async {
    final session = _session;
    if (session == null) throw const ClipbackApiException('로그인이 필요합니다.');
    final refreshed = ApiSession.fromJson(
      await _json(
        'POST',
        '/auth/refresh',
        authenticated: false,
        body: {'refresh_token': session.refreshToken},
      ),
    );
    _session = refreshed;
    return refreshed;
  }

  Future<void> logout() async {
    final session = _session;
    if (session == null) return;
    await _json(
      'POST',
      '/auth/logout',
      authenticated: false,
      body: {'refresh_token': session.refreshToken},
      allowEmpty: true,
    );
    _session = null;
  }

  Future<ApiSession> socialLogin({
    required String provider,
    required String token,
  }) async {
    final session = ApiSession.fromJson(
      await _json(
        'POST',
        '/auth/social/$provider',
        authenticated: false,
        body: {'token': token},
      ),
    );
    _session = session;
    return session;
  }

  Future<ApiSession> upgradeGuestWithSocial({
    required String provider,
    required String token,
  }) async {
    final session = ApiSession.fromJson(
      await _json(
        'POST',
        '/auth/social/$provider/upgrade',
        body: {'token': token},
      ),
    );
    _session = session;
    return session;
  }

  Future<ApiUser> readMe() async =>
      ApiUser.fromJson(await _json('GET', '/users/me'));

  Future<ApiUserStats> readStats() async =>
      ApiUserStats.fromJson(await _json('GET', '/users/me/stats'));

  Future<ApiContent> createContent({
    required String originalUrl,
    required List<int> categoryIds,
    String? title,
    String? summary,
    List<String> tagNames = const [],
    bool isFavorite = false,
  }) async {
    return ApiContent.fromJson(
      await _json(
        'POST',
        '/contents',
        body: {
          'content_type': 'link',
          'source': 'web',
          'original_url': originalUrl,
          'category_ids': categoryIds,
          'tag_names': tagNames,
          'title': title,
          'summary': summary,
          'is_favorite': isFavorite,
        },
      ),
    );
  }

  Future<ApiContent> createContentFromShare({
    String? url,
    String? rawText,
    String? mimeType,
    String? sourceApp,
    String? platform,
    List<Map<String, dynamic>> attachments = const [],
    List<int> categoryIds = const [],
    List<String> tagNames = const [],
    bool isFavorite = false,
  }) async {
    return ApiContent.fromJson(
      await _json(
        'POST',
        '/contents/share',
        body: {
          'url': url,
          'raw_text': rawText,
          'mime_type': mimeType,
          'source_app': sourceApp,
          'platform': platform,
          'attachments': attachments,
          'category_ids': categoryIds,
          'tag_names': tagNames,
          'is_favorite': isFavorite,
        },
      ),
    );
  }

  Future<ApiContent> readContent(int contentId) async =>
      ApiContent.fromJson(await _json('GET', '/contents/$contentId'));

  Future<void> deleteContent(int contentId) =>
      _json('DELETE', '/contents/$contentId', allowEmpty: true);

  Future<ApiContent> updateContentCategories(
    int contentId,
    List<int> categoryIds,
  ) async => ApiContent.fromJson(
    await _json(
      'PUT',
      '/contents/$contentId/categories',
      body: {'category_ids': categoryIds},
    ),
  );

  Future<ApiContent> updateContentTags(
    int contentId,
    List<String> tagNames,
  ) async => ApiContent.fromJson(
    await _json(
      'PUT',
      '/contents/$contentId/tags',
      body: {'tag_names': tagNames},
    ),
  );

  Future<ApiContent> updateContentFavorite(
    int contentId,
    bool isFavorite,
  ) async => ApiContent.fromJson(
    await _json(
      'PUT',
      '/contents/$contentId/favorite',
      body: {'is_favorite': isFavorite},
    ),
  );

  Future<void> recordContentView(int contentId) =>
      _json('POST', '/contents/$contentId/view');

  Future<List<ApiCategory>> listCategories() async => _jsonList(
    await _json('GET', '/categories'),
  ).map(ApiCategory.fromJson).toList();

  Future<List<ApiCategory>> listRecentCategories({int limit = 2}) async {
    final query = Uri(queryParameters: {'limit': '$limit'}).query;
    return _jsonList(
      await _json('GET', '/categories/recent?$query'),
    ).map(ApiCategory.fromJson).toList();
  }

  Future<ApiCategory> createCategory({
    required String name,
    String? color,
  }) async => ApiCategory.fromJson(
    await _json('POST', '/categories', body: {'name': name, 'color': color}),
  );

  Future<ApiCategory> updateCategory({
    required int categoryId,
    String? name,
    String? color,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (color != null) body['color'] = color;
    return ApiCategory.fromJson(
      await _json('PATCH', '/categories/$categoryId', body: body),
    );
  }

  Future<void> deleteCategory(int categoryId) =>
      _json('DELETE', '/categories/$categoryId', allowEmpty: true);

  Future<ApiContent> uploadScreenshot({
    required Uint8List bytes,
    required String filename,
    List<int> categoryIds = const [],
    List<String> tagNames = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/uploads/screenshots'),
    );
    request.headers['Authorization'] = _authorizationHeader();
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    for (final id in categoryIds) {
      request.fields.putIfAbsent('category_ids', () => '$id');
    }
    for (final name in tagNames) {
      request.fields.putIfAbsent('tag_names', () => name);
    }
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    _throwForError(response);
    return ApiContent.fromJson(_decodeJson(response));
  }

  Future<Uint8List> readAsset(int assetId) async {
    final response = await _request('GET', '/uploads/assets/$assetId');
    _throwForError(response);
    return response.bodyBytes;
  }

  Future<ApiFeed> readFeed({
    String? query,
    int? categoryId,
    bool? isFavorite,
    int limit = 100,
    String? cursor,
  }) async {
    final parameters = <String, String>{'limit': '$limit'};
    if (query != null && query.isNotEmpty) parameters['q'] = query;
    if (categoryId != null) parameters['category_id'] = '$categoryId';
    if (isFavorite != null) parameters['is_favorite'] = '$isFavorite';
    if (cursor != null) parameters['cursor'] = cursor;
    final queryString = Uri(queryParameters: parameters).query;
    return ApiFeed.fromJson(await _json('GET', '/feed?$queryString'));
  }

  Future<void> createCategoryFilterEvent(int categoryId) => _json(
    'POST',
    '/metrics/events',
    body: {'event_type': 'category_filter_used', 'category_id': categoryId},
  );

  Future<void> createCardClickEvent({
    required int contentId,
    int? categoryId,
  }) => _json(
    'POST',
    '/metrics/events',
    body: {
      'event_type': 'card_clicked',
      'content_id': contentId,
      'category_id': categoryId,
    },
  );

  Future<void> createOriginalLinkOpenedEvent(int contentId) => _json(
    'POST',
    '/metrics/events',
    body: {'event_type': 'original_link_opened', 'content_id': contentId},
  );

  Future<Map<String, String>> _getPublic(String path) async {
    final response = await _request('GET', path, authenticated: false);
    _throwForError(response);
    return Map<String, String>.from(_decodeJson(response));
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    bool authenticated = true,
    Map<String, dynamic>? body,
    bool allowEmpty = false,
  }) async {
    final response = await _request(
      method,
      path,
      authenticated: authenticated,
      body: body,
    );
    _throwForError(response);
    if (allowEmpty && response.body.isEmpty) return const {};
    return _decodeJson(response);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    bool authenticated = true,
    Map<String, dynamic>? body,
    bool retried = false,
  }) async {
    if (authenticated && _session == null) {
      throw const ClipbackApiException('로그인이 필요합니다.');
    }
    final request = http.Request(method, Uri.parse('$_baseUrl$path'));
    request.headers['Accept'] = 'application/json';
    if (authenticated) {
      request.headers['Authorization'] = _authorizationHeader();
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode == 401 &&
        authenticated &&
        !retried &&
        _session != null) {
      await refreshSession();
      return _request(
        method,
        path,
        authenticated: authenticated,
        body: body,
        retried: true,
      );
    }
    return response;
  }

  String _authorizationHeader() {
    final session = _session;
    if (session == null) throw const ClipbackApiException('로그인이 필요합니다.');
    return 'Bearer ${session.accessToken}';
  }

  void _throwForError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = '요청을 처리하지 못했습니다.';
    try {
      final data = _decodeJson(response);
      final detail = data['detail'];
      if (detail is String) message = detail;
      if (detail is List && detail.isNotEmpty) {
        message =
            (detail.first as Map<String, dynamic>)['msg'] as String? ?? message;
      }
    } on FormatException {
      // The API can return an empty non-JSON response for infrastructure errors.
    }
    throw ClipbackApiException(message, statusCode: response.statusCode);
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    if (response.body.isEmpty) return const {};
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}

List<Map<String, dynamic>> _jsonList(Object? value) =>
    List<Map<String, dynamic>>.from(
      (value as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
