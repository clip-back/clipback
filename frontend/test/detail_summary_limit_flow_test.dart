import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_startup.dart';

const _limit = '이번 달 AI 요약을 모두 써서 요약하지 않았어요. 다음 달 1일부터 다시 요약해요.';
const _linkSaved = '저장할 때 들어간 유튜브 영상 설명입니다.';
const _photoSaved = '요약 정보가 아직 없습니다.';
const _first = {
  'id': 201,
  'name': '영상',
  'color': '#22C55E',
  'is_default': false,
};
const _second = {
  'id': 202,
  'name': '읽을거리',
  'color': '#3B82F6',
  'is_default': false,
};
const _uncategorized = {
  'id': 299,
  'name': '미분류',
  'color': '#6B7280',
  'is_default': true,
};
const _categories = [_first, _second, _uncategorized];

// Same keys as the server's ContentResponse (#463 link, #464 photo).
Map<String, Object?> _link({int id = 1}) => {
  'id': id,
  'saved_at': '2026-11-20T03:00:00Z',
  'summary_status': 'skipped',
  'summary_error_code': 'monthly_limit_exceeded',
  'categories': [_first],
  'tags': <Object>[],
  'assets': <Object>[],
  'content_type': 'link',
  'source': 'youtube',
  'title': '한도로 요약을 건너뛴 유튜브 영상',
  'summary': _linkSaved,
  'original_url': 'https://www.youtube.com/watch?v=monthlylimit',
  'is_favorite': false,
  'last_viewed_at': null,
};

Map<String, Object?> _photo({int id = 2}) => {
  'id': id,
  'saved_at': '2026-11-20T02:00:00Z',
  'summary_status': 'skipped',
  'summary_error_code': 'monthly_limit_exceeded',
  'categories': [_first],
  'tags': <Object>[],
  'assets': [
    {
      'id': 90,
      'asset_type': 'screenshot',
      'mime_type': 'image/png',
      'download_url': '/api/v1/uploads/assets/90',
    },
  ],
  'content_type': 'screenshot',
  'source': 'screenshot',
  'title': '저장한 콘텐츠',
  'summary': _photoSaved,
  'original_url': null,
  'is_favorite': false,
  'last_viewed_at': null,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Server {
  _Server(this.records);

  final List<Map<String, Object?>> records;
  final reads = <int>[];
  Completer<void>? writeGate;

  late final client = MockClient((request) async {
    final path = request.url.path;
    switch (path) {
      case '/api/v1/auth/refresh':
        return _json({
          'access_token': 'access',
          'refresh_token': 'refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        }, 201);
      case '/api/v1/users/me':
        return _json({
          'id': 1,
          'email': 'member@example.invalid',
          'display_name': '한도 확인 회원',
          'is_guest': false,
          'created_at': '2026-10-07T00:00:00Z',
          'linked_providers': ['kakao'],
        });
      case '/api/v1/users/me/stats':
        return _json({
          'saved_count': records.length,
          'reopened_count': 0,
          'recent_reopened_count': 0,
        });
      case '/api/v1/categories':
        return _json([
          for (final category in _categories)
            {...category, 'content_count': 1, 'last_saved_at': null},
        ]);
      case '/api/v1/feed':
        return _json({'items': records, 'next_cursor': null});
      case '/api/v1/recommendations/weekly':
        return _json({
          'period_start': '2026-10-19T00:00:00Z',
          'period_end': '2026-10-26T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        });
      case '/api/v1/metrics/events':
        return _json(<String, Object>{}, 201);
    }
    final match = RegExp(
      r'^/api/v1/contents/(\d+)(?:/(view|favorite|categories))?$',
    ).firstMatch(path);
    if (match == null) throw StateError('Unexpected request: $path');
    if (match[2] == 'view') return _json(<String, Object>{}, 201);
    final id = int.parse(match[1]!);
    final index = records.indexWhere((item) => item['id'] == id);
    if (request.method == 'GET') reads.add(id);
    if (request.method == 'PUT') {
      await writeGate?.future;
      final body = jsonDecode(request.body) as Map;
      records[index] = {
        ...records[index],
        if (match[2] == 'favorite') 'is_favorite': body['is_favorite'],
        if (match[2] == 'categories')
          'categories': _categories
              .where((c) => (body['category_ids'] as List).contains(c['id']))
              .toList(),
      };
    }
    return _json(records[index]);
  });
}

Future<void> _withApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check,
) async {
  SharedPreferences.setMockInitialValues({
    'clipback.session': jsonEncode({
      'access_token': 'access',
      'refresh_token': 'refresh',
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
      await tester.pumpWidget(const ClipbackApp());
      await completeAppStartup(tester);
      await check();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _open(WidgetTester tester, int id) async {
  final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
  home.onOpenContent(home.contents.singleWhere((item) => item.apiId == id));
  await tester.pumpAndSettle();
}

DetailScreen _detail(WidgetTester tester) =>
    tester.widget<DetailScreen>(find.byType(DetailScreen));

String? _slot(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('detail-summary'))).data;

void main() {
  for (final (kind, build, saved) in [
    ('link', _link, _linkSaved),
    ('photo', _photo, _photoSaved),
  ]) {
    testWidgets('$kind limit copy survives reread, category and favorite', (
      tester,
    ) async {
      final record = build(id: 7);
      final server = _Server([record]);
      await _withApp(tester, server, () async {
        await _open(tester, 7);
        expect(_slot(tester), _limit);
        expect(find.text(saved), findsNothing);

        final readsBefore = server.reads.length;
        _detail(tester).onBack();
        await tester.pumpAndSettle();
        await _open(tester, 7);
        expect(server.reads.length, greaterThan(readsBefore));
        expect(_slot(tester), _limit);

        server.writeGate = Completer<void>();
        final detail = _detail(tester);
        detail.onChangeCategory(detail.content, [202]);
        await tester.pump();
        expect(_slot(tester), _limit, reason: 'while category write runs');
        server.writeGate!.complete();
        await tester.pumpAndSettle();
        expect(_detail(tester).content.category.id, 202);
        expect(_slot(tester), _limit);

        server.writeGate = Completer<void>();
        _detail(tester).onToggleBookmark(_detail(tester).content);
        await tester.pump();
        expect(_slot(tester), _limit, reason: 'while favorite write runs');
        server.writeGate!.complete();
        await tester.pumpAndSettle();
        expect(server.records.single['is_favorite'], isTrue);
        expect(_slot(tester), _limit);
        expect(find.text(saved), findsNothing);
      });
    });

    testWidgets('$kind response without summary_error_code shows saved text', (
      tester,
    ) async {
      final record = build(id: 7)..remove('summary_error_code');
      await _withApp(tester, _Server([record]), () async {
        await _open(tester, 7);
        expect(_slot(tester), saved);
      });
    });
  }

  for (final value in <Object?>[null, 7, true, <String>[], 'future_reason']) {
    testWidgets('summary_error_code $value does not show limit copy', (
      tester,
    ) async {
      final record = _link(id: 7)..['summary_error_code'] = value;
      await _withApp(tester, _Server([record]), () async {
        await _open(tester, 7);
        expect(_slot(tester), _linkSaved);
      });
    });
  }

  test('ApiContent keeps only a string summary_error_code', () {
    expect(
      ApiContent.fromJson(_link()).summaryErrorCode,
      'monthly_limit_exceeded',
    );
    expect(
      ApiContent.fromJson(
        _link()..remove('summary_error_code'),
      ).summaryErrorCode,
      isNull,
    );
    expect(
      ApiContent.fromJson(_link()..['summary_error_code'] = 7).summaryErrorCode,
      isNull,
    );
  });

  test('ContentItem.copyWith keeps the summary reason', () {
    const category = catUncategorized;
    const item = ContentItem(
      id: 'api-7',
      apiId: 7,
      title: '제목',
      summary: _linkSaved,
      category: category,
      savedAt: '26.11.20',
      savedAtFull: '2026. 11. 20',
      savedAtFullShort: '2026. 11. 20',
      tags: [],
      source: 'YouTube',
      originalUrl: '',
      originalText: '',
      summaryStatus: 'skipped',
      summaryErrorCode: 'monthly_limit_exceeded',
    );
    expect(
      item.copyWith(bookmarked: true).summaryErrorCode,
      'monthly_limit_exceeded',
    );
    expect(
      item.copyWith(category: category).summaryErrorCode,
      'monthly_limit_exceeded',
    );
  });
}
