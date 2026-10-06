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
  static const _sessionKey = 'clipback.session';
  static const _accessTokenKey = 'clipback.access_token';
  static const _refreshTokenKey = 'clipback.refresh_token';
  static const _expiresInKey = 'clipback.expires_in';
  static const _refreshExpiresInKey = 'clipback.refresh_expires_in';

  Future<ApiSession?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final storedSession = preferences.getString(_sessionKey);
    if (storedSession != null) {
      return ApiSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(storedSession) as Map),
      );
    }
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
    final saved = await preferences.setString(
      _sessionKey,
      jsonEncode({
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'expires_in': session.expiresIn,
        'refresh_expires_in': session.refreshExpiresIn,
      }),
    );
    if (!saved) throw StateError('Could not persist session');
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
    final removedLegacy = await Future.wait([
      preferences.remove(_accessTokenKey),
      preferences.remove(_refreshTokenKey),
      preferences.remove(_expiresInKey),
      preferences.remove(_refreshExpiresInKey),
    ]);
    if (removedLegacy.any((removed) => !removed)) {
      throw StateError('Could not clear stored session');
    }
    if (!await preferences.remove(_sessionKey)) {
      throw StateError('Could not clear stored session');
    }
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
  ClipbackApi({
    http.Client? client,
    Future<void> Function(ApiSession)? onSessionChanged,
  }) : _client = client ?? http.Client(),
       _onSessionChanged = onSessionChanged;

  static const _requestTimeout = Duration(seconds: 10);
  static const _baseUrl = String.fromEnvironment(
    'CLIPBACK_API_BASE_URL',
    defaultValue: 'https://clipback-production.up.railway.app/api/v1',
  );

  final http.Client _client;
  final Future<void> Function(ApiSession)? _onSessionChanged;
  ApiSession? _session;
  int _sessionGeneration = 0;
  Future<ApiSession>? _refreshFuture;
  int? _logoutGeneration;

  bool get hasSession => _session != null;
  ApiSession? get session => _session;

  void restoreSession(ApiSession session) => _replaceSession(session);

  void clearSession() => _replaceSession(null);

  void _replaceSession(ApiSession? session) {
    _sessionGeneration++;
    _session = session;
    _refreshFuture = null;
  }

  void _checkSessionGeneration(int generation, {bool allowLogout = false}) {
    if (generation != _sessionGeneration ||
        (!allowLogout && _logoutGeneration == generation)) {
      throw const ClipbackApiException('로그인 상태가 변경되었어요. 다시 시도해 주세요.');
    }
  }

  Future<ApiSession> _setSession(
    ApiSession session, {
    required int generation,
    bool isRefresh = false,
  }) async {
    _checkSessionGeneration(generation, allowLogout: isRefresh);
    if (isRefresh) {
      _session = session;
    } else {
      _replaceSession(session);
      generation = _sessionGeneration;
    }
    try {
      await _onSessionChanged?.call(session);
    } catch (_) {
      _checkSessionGeneration(generation, allowLogout: isRefresh);
      rethrow;
    }
    _checkSessionGeneration(generation, allowLogout: isRefresh);
    return session;
  }

  Future<Map<String, String>> health() => _getPublic('/health');

  Future<Map<String, String>> readiness() => _getPublic('/health/ready');

  Future<ApiSession> createGuestSession() => _issueSession('/auth/guest');

  Future<ApiSession> refreshSession() {
    final generation = _sessionGeneration;
    if (_logoutGeneration == generation) {
      return Future.error(
        const ClipbackApiException('로그인 상태가 변경되었어요. 다시 시도해 주세요.'),
      );
    }
    final session = _session;
    if (session == null) {
      return Future.error(const ClipbackApiException('로그인이 필요합니다.'));
    }
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) return activeRefresh;

    late final Future<ApiSession> refresh;
    refresh = _refreshSession(session, generation).whenComplete(() {
      if (identical(_refreshFuture, refresh)) _refreshFuture = null;
    });
    _refreshFuture = refresh;
    return refresh;
  }

  Future<ApiSession> _refreshSession(ApiSession session, int generation) async {
    late final Map<String, dynamic> response;
    try {
      response = await _json(
        'POST',
        '/auth/refresh',
        authenticated: false,
        body: {'refresh_token': session.refreshToken},
      ).timeout(_requestTimeout);
    } on TimeoutException {
      _checkSessionGeneration(generation, allowLogout: true);
      throw const ClipbackApiException('서버 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.');
    } catch (_) {
      _checkSessionGeneration(generation, allowLogout: true);
      rethrow;
    }
    _checkSessionGeneration(generation, allowLogout: true);
    return _setSession(
      ApiSession.fromJson(response),
      generation: generation,
      isRefresh: true,
    );
  }

  Future<void> logout() async {
    final generation = _sessionGeneration;
    _checkSessionGeneration(generation);
    if (_session == null) return;
    _logoutGeneration = generation;
    try {
      final refresh = _refreshFuture;
      if (refresh != null) {
        try {
          await refresh;
        } catch (_) {
          // Even if refresh fails, attempt logout with the current token.
        }
      }
      _checkSessionGeneration(generation, allowLogout: true);
      await _json(
        'POST',
        '/auth/logout',
        authenticated: false,
        body: {'refresh_token': _session!.refreshToken},
        allowEmpty: true,
      );
      _checkSessionGeneration(generation, allowLogout: true);
      clearSession();
    } catch (_) {
      _checkSessionGeneration(generation, allowLogout: true);
      rethrow;
    } finally {
      if (_logoutGeneration == generation) _logoutGeneration = null;
    }
  }

  Future<ApiSession> socialLogin({
    required String provider,
    required String token,
  }) => _issueSession('/auth/social/$provider', body: {'token': token});

  Future<ApiSession> upgradeGuestWithSocial({
    required String provider,
    required String token,
  }) => _issueSession(
    '/auth/social/$provider/upgrade',
    authenticated: true,
    body: {'token': token},
  );

  Future<ApiSession> _issueSession(
    String path, {
    bool authenticated = false,
    Map<String, dynamic>? body,
  }) async {
    final generation = _sessionGeneration;
    _checkSessionGeneration(generation);
    late final Map<String, dynamic> response;
    try {
      response = await _json(
        'POST',
        path,
        authenticated: authenticated,
        body: body,
      );
    } catch (_) {
      _checkSessionGeneration(generation);
      rethrow;
    }
    _checkSessionGeneration(generation);
    return _setSession(ApiSession.fromJson(response), generation: generation);
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

  Future<List<ApiCategory>> listCategories() async {
    final response = await _request('GET', '/categories');
    _throwForError(response);
    return _decodeJsonList(response).map(ApiCategory.fromJson).toList();
  }

  Future<List<ApiCategory>> listRecentCategories({int limit = 2}) async {
    final query = Uri(queryParameters: {'limit': '$limit'}).query;
    final response = await _request('GET', '/categories/recent?$query');
    _throwForError(response);
    return _decodeJsonList(response).map(ApiCategory.fromJson).toList();
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
    final fileBytes = Uint8List.fromList(bytes);
    final selectedCategoryIds = List<int>.of(categoryIds, growable: false);
    final selectedTagNames = List<String>.of(tagNames, growable: false);
    late http.Response response;
    try {
      response = await _sendWithSessionRetry((session) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/uploads/screenshots'),
        );
        request.headers['Authorization'] = 'Bearer ${session!.accessToken}';
        request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
        );
        for (final id in selectedCategoryIds) {
          request.files.add(
            http.MultipartFile.fromString('category_ids', '$id'),
          );
        }
        for (final name in selectedTagNames) {
          request.files.add(http.MultipartFile.fromString('tag_names', name));
        }
        final streamedResponse = await _client
            .send(request)
            .timeout(_requestTimeout);
        return http.Response.fromStream(
          streamedResponse,
        ).timeout(_requestTimeout);
      });
    } on TimeoutException {
      throw const ClipbackApiException('서버 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.');
    } on http.ClientException {
      throw const ClipbackApiException('서버에 연결하지 못했어요.');
    }
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
  }) => _sendWithSessionRetry((session) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'));
    request.headers['Accept'] = 'application/json';
    if (authenticated) {
      request.headers['Authorization'] = 'Bearer ${session!.accessToken}';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return http.Response.fromStream(await _client.send(request));
  }, authenticated: authenticated);

  Future<http.Response> _sendWithSessionRetry(
    Future<http.Response> Function(ApiSession?) send, {
    bool authenticated = true,
    bool retried = false,
  }) async {
    final generation = _sessionGeneration;
    final session = _session;
    if (authenticated) {
      _checkSessionGeneration(generation);
      if (session == null) throw const ClipbackApiException('로그인이 필요합니다.');
    }
    late final http.Response response;
    try {
      response = await send(session);
    } catch (_) {
      if (authenticated) _checkSessionGeneration(generation);
      rethrow;
    }
    if (authenticated) _checkSessionGeneration(generation);
    if (response.statusCode == 401 && authenticated && !retried) {
      try {
        final activeRefresh = _refreshFuture;
        if (activeRefresh != null) {
          // Memory can change before the persistence callback finishes.
          await activeRefresh;
        } else if (session!.accessToken == _session!.accessToken) {
          await refreshSession();
        }
      } catch (_) {
        _checkSessionGeneration(generation);
        rethrow;
      }
      _checkSessionGeneration(generation);
      return _sendWithSessionRetry(
        send,
        authenticated: authenticated,
        retried: true,
      );
    }
    return response;
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

  List<Map<String, dynamic>> _decodeJsonList(http.Response response) {
    if (response.body.isEmpty) return const [];
    return _jsonList(jsonDecode(response.body));
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
