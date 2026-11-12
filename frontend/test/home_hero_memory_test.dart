import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_startup.dart';
import 'support/memory_api_session_storage.dart';

const _study = {
  'id': 101,
  'name': '공부',
  'color': '#059669',
  'is_default': false,
  'content_count': 0,
  'last_saved_at': null,
};
const _travel = {
  'id': 102,
  'name': '여행',
  'color': '#2563EB',
  'is_default': false,
  'content_count': 0,
  'last_saved_at': null,
};

http.Response _json(Object? value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _content(int id) => {
  'id': id,
  'categories': [_study],
  'tags': <Object>[],
  'assets': <Object>[],
  'content_type': 'link',
  'source': 'web',
  'title': '저장한 콘텐츠 $id',
  'summary': '다시 읽을 요약 $id',
  'original_url': 'https://example.com/$id',
  'is_favorite': false,
  'saved_at': '2026-10-12T00:00:00Z',
  'last_viewed_at': null,
  'summary_status': 'completed',
};

/// Home API whose global feed is [saved]; feed requests can be held open.
class _Server {
  _Server({required this.saved});

  final List<Map<String, Object?>> saved;
  Completer<http.Response>? held;
  bool holdFeed = false;

  late final client = MockClient((request) async {
    switch (request.url.path) {
      case '/api/v1/categories':
        return _json([_study, _travel]);
      case '/api/v1/feed':
        final category = request.url.queryParameters['category_id'];
        final items = category == null
            ? saved
            : saved.where((_) => category == '101').toList();
        final response = _json({'items': items, 'next_cursor': null});
        if (holdFeed) {
          held = Completer<http.Response>();
          return held!.future;
        }
        return response;
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
          'saved_count': saved.length,
          'reopened_count': 0,
          'recent_reopened_count': 0,
        });
      case '/api/v1/auth/guest':
        return _json({
          'access_token': 'guest-access',
          'refresh_token': 'guest-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        });
      case '/api/v1/recommendations/weekly':
        return _json({
          'period_start': '2026-10-19T00:00:00Z',
          'period_end': '2026-10-26T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        });
      case '/api/v1/metrics/events':
        return _json({});
    }
    throw StateError('Unexpected request: ${request.method} ${request.url}');
  });

  /// Answers the held request with that feed's real result; null is all.
  void release(String? categoryId) => held!.complete(
    _json({
      'items': categoryId == null || categoryId == '101' ? saved : <Object>[],
      'next_cursor': null,
    }),
  );

  void fail() => held!.complete(
    http.Response(
      jsonEncode({'detail': 'down'}),
      500,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );
}

Future<void> _withApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(375, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(sessionStorage: MemoryApiSessionStorage()),
      );
      await completeAppStartup(tester);
      await check();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

const _c01 = ['나중에 보려던 것들,', '지금 하나만 꺼내볼까요?', '오늘의 콘텐츠 보기 →'];
const _c02 = ['아직 저장한 콘텐츠가 없어요.', '지금 하나만 저장해볼까요?', '첫 콘텐츠 저장하기'];
const _legacy = ['저장한 정보가 없어요.', '지금 하나만 저장할까요?', '저장 방법 보기 →'];

void _expectHero(WidgetTester tester, List<String> copy, String reason) {
  final hero = find.byType(HomeHero);
  for (final text in copy) {
    expect(
      find.descendant(of: hero, matching: find.text(text)),
      findsOneWidget,
      reason: '$reason: $text',
    );
  }
  for (final text in _legacy) {
    expect(find.text(text), findsNothing, reason: '$reason: $text');
  }
}

double _heroHeight(WidgetTester tester) =>
    tester.getSize(find.byType(HomeHero)).height;

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(CategoryChips), matching: find.text(label)),
  );
  await tester.pump();
}

Future<void> _visitArchiveAndReturn(WidgetTester tester, _Server server) async {
  // The archive tab loads its own feed; only home requests are held.
  final hold = server.holdFeed;
  server.holdFeed = false;
  tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.archive);
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsNothing);
  expect(find.byType(ArchiveScreen), findsOneWidget);
  tester.widget<ArchiveScreen>(find.byType(ArchiveScreen)).onTab(AppRoute.home);
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
  server.holdFeed = hold;
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

  testWidgets('C01 home keeps C01 and its height while a chip loads', (
    tester,
  ) async {
    final server = _Server(saved: [_content(1), _content(2)]);
    await _withApp(tester, server, () async {
      _expectHero(tester, _c01, 'cards');
      final height = _heroHeight(tester);
      server.holdFeed = true;

      await _tapChip(tester, '여행');
      _expectHero(tester, _c01, 'chip loading');
      expect(_heroHeight(tester), height, reason: 'chip loading');

      server.release('102');
      await tester.pumpAndSettle();
      expect(find.byType(HomeFilteredEmptyContent), findsOneWidget);
      _expectHero(tester, _c01, 'empty category');
      expect(_heroHeight(tester), height, reason: 'empty category');

      await _tapChip(tester, '공부');
      _expectHero(tester, _c01, 'loading after empty');
      server.release('101');
      await tester.pumpAndSettle();
      _expectHero(tester, _c01, 'cards again');
      expect(_heroHeight(tester), height);
      expect(tester.takeException(), isNull);
    });
  });

  for (final outcome in ['success', 'failure']) {
    testWidgets('C01 stays through empty category then all-chip $outcome', (
      tester,
    ) async {
      final server = _Server(saved: [_content(1), _content(2)]);
      await _withApp(tester, server, () async {
        _expectHero(tester, _c01, 'cards');
        final height = _heroHeight(tester);
        server.holdFeed = true;
        await _tapChip(tester, '여행');
        server.release('102');
        await tester.pumpAndSettle();
        expect(find.byType(HomeFilteredEmptyContent), findsOneWidget);
        _expectHero(tester, _c01, 'empty category');

        await _tapChip(tester, '전체보기');
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        _expectHero(tester, _c01, 'all-chip loading');
        expect(_heroHeight(tester), height, reason: 'all-chip loading');
        final hero = tester.widget<HomeHero>(find.byType(HomeHero));
        expect(
          hero.onOpenToday,
          same(tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenToday),
          reason: 'C01 button opens today',
        );

        if (outcome == 'success') {
          server.release(null);
        } else {
          server.fail();
        }
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        _expectHero(tester, _c01, 'all-chip $outcome');
        expect(_heroHeight(tester), height, reason: 'all-chip $outcome');

        await _visitArchiveAndReturn(tester, server);
        _expectHero(tester, _c01, 'after another tab');
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets(
    'zero-saved home keeps C02 for chips, including after another tab',
    (tester) async {
      final server = _Server(saved: const []);
      await _withApp(tester, server, () async {
        _expectHero(tester, _c02, 'confirmed zero');
        final height = _heroHeight(tester);
        server.holdFeed = true;

        await _tapChip(tester, '여행');
        _expectHero(tester, _c02, 'chip loading');
        expect(_heroHeight(tester), height, reason: 'chip loading');
        server.release('102');
        await tester.pumpAndSettle();
        _expectHero(tester, _c02, 'empty category');
        expect(_heroHeight(tester), height, reason: 'empty category');

        await _visitArchiveAndReturn(tester, server);
        _expectHero(tester, _c02, 'after another tab');

        await _tapChip(tester, '공부');
        _expectHero(tester, _c02, 'chip loading after another tab');
        server.release('101');
        await tester.pumpAndSettle();
        _expectHero(tester, _c02, 'empty category after another tab');
        expect(_heroHeight(tester), height);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
