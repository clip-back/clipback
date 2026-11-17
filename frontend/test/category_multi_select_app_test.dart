// #408 실제 앱 조립 + 가짜 HTTP: 진입 4곳, 두 카테고리의 아카이브·홈 결과,
// 대표 카테고리 정렬, 실패 되돌림. 늦은 응답(계정 변경)은
// content_mutation_test의 'old-account category …'가 같은 경로를 고정한다.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/category/category_change_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_startup.dart';

Map<String, Object?> _category(int id, String name, {bool isDefault = false}) =>
    {
      'id': id,
      'name': name,
      'color': '#059669',
      'is_default': isDefault,
      'content_count': 1,
      'last_saved_at': null,
    };

final _study = _category(101, '공부');
final _travel = _category(202, '여행');
final _uncategorized = _category(303, '미분류', isDefault: true);
final _life = _category(404, '생활');
final _all = [_study, _travel, _uncategorized, _life];

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Server {
  _Server({this.respond});

  final FutureOr<http.Response?> Function(http.Request)? respond;
  final requests = <http.Request>[];
  late final records = [
    for (var index = 0; index < 3; index++)
      <String, Object?>{
        'id': 3 - index,
        'categories': [_study],
        'tags': <Object>[],
        'assets': <Object>[],
        'content_type': 'link',
        'source': 'web',
        'title': '피드 항목 ${index + 1}',
        'summary': '저장한 콘텐츠 ${index + 1}',
        'original_url': 'https://example.com/feed/${index + 1}',
        'is_favorite': index == 0,
        'saved_at': DateTime.utc(
          2026,
          10,
          7,
        ).subtract(Duration(minutes: index)).toIso8601String(),
        'last_viewed_at': null,
      },
  ];

  List<http.Request> get categoryWrites => requests
      .where((r) => r.method == 'PUT' && r.url.path.endsWith('/categories'))
      .toList();

  late final client = MockClient((request) async {
    requests.add(request);
    final overridden = await respond?.call(request);
    if (overridden != null) return overridden;
    final path = request.url.path;
    switch (path) {
      case '/api/v1/recommendations/weekly':
        return _json({
          'period_start': '2026-10-19T00:00:00Z',
          'period_end': '2026-10-26T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        });
      case '/api/v1/categories':
        return _json(_all);
      case '/api/v1/feed':
        final q = request.url.queryParameters;
        final categoryId = int.tryParse(q['category_id'] ?? '');
        final favorite = q['is_favorite'];
        final query = q['q'];
        return _json({
          'items': records.where((record) {
            final ids = (record['categories'] as List).map(
              (c) => (c as Map)['id'],
            );
            if (categoryId != null && !ids.contains(categoryId)) return false;
            if (favorite != null &&
                record['is_favorite'] != (favorite == 'true')) {
              return false;
            }
            if (query != null && !'${record['title']}'.contains(query)) {
              return false;
            }
            return true;
          }).toList(),
          'next_cursor': null,
        });
      case '/api/v1/users/me':
        return _json({
          'id': 1,
          'email': null,
          'display_name': '테스트 계정',
          'is_guest': true,
          'created_at': '2026-10-07T00:00:00Z',
          'linked_providers': <String>[],
        });
      case '/api/v1/users/me/stats':
        return _json({
          'saved_count': 3,
          'reopened_count': 0,
          'recent_reopened_count': 0,
        });
      case '/api/v1/auth/refresh':
        return _json({
          'access_token': 'rotated-access',
          'refresh_token': 'rotated-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        }, 201);
      case '/api/v1/metrics/events':
        return _json(<String, Object>{}, 201);
    }
    final match = RegExp(
      r'^/api/v1/contents/(\d+)(?:/(view|categories))?$',
    ).firstMatch(path);
    if (match == null) {
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    }
    if (match.group(2) == 'view') return _json(<String, Object>{}, 201);
    final index = records.indexWhere(
      (r) => r['id'] == int.parse(match.group(1)!),
    );
    if (request.method == 'PUT') {
      final ids = (jsonDecode(request.body) as Map)['category_ids'] as List;
      // Answer in the reverse of the request so the app must order them.
      records[index] = {
        ...records[index],
        'categories': [
          for (final id in ids.reversed) _all.firstWhere((c) => c['id'] == id),
        ],
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
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
      'expires_in': 3600,
      'refresh_expires_in': 86400,
    }),
  });
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        Theme(
          data: ThemeData(fontFamily: 'Pretendard'),
          child: const ClipbackApp(),
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
ArchiveScreen _archive(WidgetTester tester) =>
    tester.widget<ArchiveScreen>(find.byType(ArchiveScreen));

Finder _listMore() => find
    .byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            'archive-all-more-',
          ),
    )
    .first;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// From an open content management menu: check 여행 and finish.
Future<void> _addTravel(WidgetTester tester, Finder more) async {
  await _tap(tester, more);
  expect(find.text('이 콘텐츠를 넣을 카테고리를 골라요.'), findsOneWidget);
  await _tap(tester, find.text('카테고리 변경'));
  expect(find.byType(CategoryChangeScreen), findsOneWidget);
  expect(find.text('1개 선택'), findsOneWidget);
  final screen = find.byType(CategoryChangeScreen);
  expect(find.descendant(of: screen, matching: find.text('미분류')), findsNothing);
  await _tap(tester, find.descendant(of: screen, matching: find.text('여행')));
  await _tap(tester, find.text('선택 완료'));
  expect(find.byType(CategoryChangeScreen), findsNothing);
}

void _expectSent(_Server server, int id) {
  expect(server.categoryWrites, hasLength(1));
  expect(
    server.categoryWrites.single.url.path,
    '/api/v1/contents/$id/categories',
  );
  expect(jsonDecode(server.categoryWrites.single.body), {
    'category_ids': [101, 202],
  });
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  group('entry points open the same screen', () {
    testWidgets('archive', (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        _home(tester).onOpenArchive();
        await tester.pumpAndSettle();
        // #408 ①: the real archive always passes its server feed.
        expect(
          tester.widget<ContentListView>(find.byType(ContentListView)).feed,
          isNotNull,
        );
        await _addTravel(tester, _listMore());
        _expectSent(server, 3);
      });
    });

    testWidgets('bookmark', (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        _home(tester).onTab(AppRoute.bookmark);
        await tester.pumpAndSettle();
        await _addTravel(tester, _listMore());
        _expectSent(server, 3);
      });
    });

    testWidgets('search card more', (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        _home(tester).onSearch();
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '피드 항목 2');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          tester.widget<SearchScreen>(find.byType(SearchScreen)).contents,
          hasLength(1),
        );
        await _addTravel(tester, _listMore());
        _expectSent(server, 2);
      });
    });

    testWidgets('detail', (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        final home = _home(tester);
        home.onOpenContent(home.contents.first);
        await tester.pumpAndSettle();
        await _addTravel(tester, find.byKey(const ValueKey('detail-more')));
        _expectSent(server, 3);
        final detail = tester.widget<DetailScreen>(find.byType(DetailScreen));
        expect(detail.content.categories.map((c) => c.id), [101, 202]);
      });
    });
  });

  testWidgets(
    'two categories show in both archive folders and home chips; unchecking one leaves that folder',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        _home(tester).onOpenArchive();
        await tester.pumpAndSettle();
        await _addTravel(tester, _listMore());

        Future<List<int?>> folder(int id) async {
          final archive = _archive(tester);
          archive.onOpenCategory(
            archive.categories.singleWhere((c) => c.id == id),
          );
          await tester.pumpAndSettle();
          final ids = _archive(tester).contents.map((c) => c.apiId).toList();
          _archive(tester).onClearCategory();
          await tester.pumpAndSettle();
          return ids;
        }

        expect(await folder(101), contains(3));
        expect(await folder(202), [3]);

        _archive(tester).onTab(AppRoute.home);
        await tester.pumpAndSettle();
        for (final id in [101, 202]) {
          final home = _home(tester);
          home.onCategorySelected!(
            home.categories.singleWhere((c) => c.id == id),
          );
          await tester.pumpAndSettle();
          expect(_home(tester).contents.map((c) => c.apiId), contains(3));
        }
        _home(tester).onCategorySelected!(null);
        await tester.pumpAndSettle();

        // Home card and detail badges share the list order: 공부 first.
        final card = _home(tester).contents.firstWhere((c) => c.apiId == 3);
        expect(card.category.id, 101);
        expect(card.categories.map((c) => c.id), [101, 202]);

        _home(tester).onOpenArchive();
        await tester.pumpAndSettle();
        await _tap(tester, _listMore());
        await _tap(tester, find.text('카테고리 변경'));
        final screen = find.byType(CategoryChangeScreen);
        expect(find.text('2개 선택'), findsOneWidget);
        await _tap(
          tester,
          find.descendant(of: screen, matching: find.text('여행')),
        );
        await _tap(tester, find.text('선택 완료'));
        expect(jsonDecode(server.categoryWrites.last.body), {
          'category_ids': [101],
        });
        expect(await folder(202), isEmpty);
        expect(await folder(101), contains(3));
      });
    },
  );

  testWidgets('a failed change restores both categories and shows the notice', (
    tester,
  ) async {
    final pending = Completer<http.Response?>();
    final server = _Server(
      respond: (request) => request.method == 'PUT' ? pending.future : null,
    );
    server.records.first['categories'] = [_study, _travel];
    await _withApp(tester, server, () async {
      _home(tester).onOpenArchive();
      await tester.pumpAndSettle();
      await _tap(tester, _listMore());
      await _tap(tester, find.text('카테고리 변경'));
      expect(find.text('2개 선택'), findsOneWidget);
      final screen = find.byType(CategoryChangeScreen);
      for (final name in ['공부', '여행']) {
        await _tap(
          tester,
          find.descendant(of: screen, matching: find.text(name)),
        );
      }
      expect(find.text('0개 선택'), findsOneWidget);
      await _tap(tester, find.text('선택 완료'));
      expect(jsonDecode(server.categoryWrites.single.body), {
        'category_ids': <int>[],
      });
      final changing = _archive(
        tester,
      ).contents.firstWhere((c) => c.apiId == 3);
      expect(changing.category.name, '미분류');
      expect(changing.isMutating, isTrue);
      pending.complete(_json({'detail': '분류 변경 거절'}, 503));
      await tester.pumpAndSettle();
      final restored = _archive(
        tester,
      ).contents.firstWhere((c) => c.apiId == 3);
      expect(restored.categories.map((c) => c.id), [101, 202]);
      expect(restored.isMutating, isFalse);
      expect(find.text('분류 변경 거절'), findsOneWidget);
    });
  });

  // #408 Testing Decisions: the content changes from {A} to {B} on the server
  // while the screen is open; S0 and S1 stay as opened.
  for (final addLife in [false, true]) {
    testWidgets(
      'opened with {A}, updated to {B} while open, ${addLife ? 'S1={A,C} overwrites' : 'S1={A} sends nothing'}',
      (tester) async {
        final server = _Server();
        await _withApp(tester, server, () async {
          _home(tester).onOpenArchive();
          await tester.pumpAndSettle();
          await _tap(tester, _listMore());
          await _tap(tester, find.text('카테고리 변경'));
          final screen = find.byType(CategoryChangeScreen);
          expect(find.text('1개 선택'), findsOneWidget);

          // A real server read under the open screen brings {B}.
          server.records.first['categories'] = [_travel];
          final below = tester.widget<ArchiveScreen>(
            find.byType(ArchiveScreen, skipOffstage: false),
          );
          below.onOpenCategory(
            below.categories.singleWhere((c) => c.id == 202),
          );
          await tester.pumpAndSettle();
          final updated = tester
              .widget<ArchiveScreen>(
                find.byType(ArchiveScreen, skipOffstage: false),
              )
              .contents
              .singleWhere((c) => c.apiId == 3);
          expect(updated.categories.map((c) => c.id), [202]);
          expect(screen, findsOneWidget);
          expect(find.text('1개 선택'), findsOneWidget);

          if (addLife) {
            await _tap(
              tester,
              find.descendant(of: screen, matching: find.text('생활')),
            );
          }
          await _tap(tester, find.text('선택 완료'));
          expect(screen, findsNothing);
          final after = _archive(tester).contents;
          if (addLife) {
            expect(server.categoryWrites, hasLength(1));
            expect(jsonDecode(server.categoryWrites.single.body), {
              'category_ids': [101, 404],
            });
            expect(server.records.first['categories'], [_life, _study]);
            // The 여행 filter no longer holds it; the server now has {A,C}.
            expect(after.where((c) => c.apiId == 3), isEmpty);
            final archive = _archive(tester);
            archive.onOpenCategory(
              archive.categories.singleWhere((c) => c.id == 101),
            );
            await tester.pumpAndSettle();
            expect(
              _archive(tester).contents
                  .singleWhere((c) => c.apiId == 3)
                  .categories
                  .map((c) => c.id),
              [101, 404],
            );
          } else {
            expect(server.categoryWrites, isEmpty);
            expect(
              after
                  .singleWhere((c) => c.apiId == 3)
                  .categories
                  .map((c) => c.id),
              [202],
            );
          }
        });
      },
    );
  }
}
