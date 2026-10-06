import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _feed = '/api/v1/feed';
const _category = {
  'id': 101,
  'name': '공부',
  'color': '#059669',
  'is_default': false,
};
const _otherCategory = {
  'id': 202,
  'name': '여행',
  'color': '#FB7185',
  'is_default': false,
};
const _uncategorized = {
  'id': 303,
  'name': '미분류',
  'color': '#B5BDC3',
  'is_default': true,
};
const _allCategories = [_category, _otherCategory, _uncategorized];

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Server {
  _Server({this.count = 101, this.respond});

  final int count;
  final FutureOr<http.Response?> Function(http.Request, _Server)? respond;
  final requests = <http.Request>[];
  final _offsets = <String, ({String key, int offset})>{};
  var _cursorNumber = 0;
  var userId = 1;
  late final records = [
    for (var index = 0; index < count; index++) item(index),
  ];

  Map<String, Object?> item(int index) => {
    'id': count - index,
    'categories': [_category],
    'tags': <Object>[],
    'assets': <Object>[],
    'content_type': 'link',
    'source': 'web',
    'title': '피드 항목 ${index + 1}',
    'summary': '저장한 콘텐츠 ${index + 1}',
    'original_url': 'https://example.com/feed/${index + 1}',
    'is_favorite': false,
    'saved_at': DateTime.utc(
      2026,
      10,
      7,
    ).subtract(Duration(minutes: index)).toIso8601String(),
    'last_viewed_at': null,
  };

  http.Response page(http.Request request) {
    final parameters = request.url.queryParameters;
    final key =
        '${parameters['q']}|${parameters['category_id']}|'
        '${parameters['is_favorite']}';
    final cursor = parameters['cursor'];
    final position = cursor == null ? null : _offsets[cursor]!;
    if (position != null && position.key != key) {
      throw StateError('Cursor reused with a different feed condition');
    }
    final offset = position?.offset ?? 0;
    final categoryId = int.tryParse(parameters['category_id'] ?? '');
    final favorite = parameters['is_favorite'];
    final query = parameters['q']?.toLowerCase();
    final matching = records.where((content) {
      final categories = content['categories'] as List;
      if (categoryId != null &&
          !categories.any(
            (category) => (category as Map)['id'] == categoryId,
          )) {
        return false;
      }
      if (favorite != null && content['is_favorite'] != (favorite == 'true')) {
        return false;
      }
      if (query != null &&
          !'${content['title']} ${content['summary']}'.toLowerCase().contains(
            query,
          )) {
        return false;
      }
      return true;
    }).toList();
    final limit = int.parse(parameters['limit']!);
    final end = (offset + limit).clamp(0, matching.length);
    String? nextCursor;
    if (end < matching.length) {
      nextCursor = 'v1.fixture_${++_cursorNumber}-$end';
      _offsets[nextCursor] = (key: key, offset: end);
    }
    return _json({
      'items': matching.sublist(offset, end),
      'next_cursor': nextCursor,
    });
  }

  late final client = MockClient((request) async {
    requests.add(request);
    final overridden = await respond?.call(request, this);
    if (overridden != null) {
      return overridden;
    }
    switch (request.url.path) {
      case '/api/v1/categories':
        return _json(_allCategories);
      case _feed:
        return page(request);
      case '/api/v1/users/me':
        return _json({
          'id': userId,
          'email': null,
          'display_name': '테스트 계정',
          'is_guest': true,
          'created_at': '2026-10-07T00:00:00Z',
          'linked_providers': <String>[],
        });
      case '/api/v1/users/me/stats':
        return _json({'saved_count': 999, 'reopened_count': 0});
      case '/api/v1/auth/refresh':
      case '/api/v1/auth/guest':
        final guest = request.url.path.endsWith('/guest');
        if (guest) {
          userId++;
        }
        return _json({
          'access_token': guest ? 'guest-access' : 'rotated-access',
          'refresh_token': guest ? 'guest-refresh' : 'rotated-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        }, 201);
      case '/api/v1/auth/logout':
        return http.Response('', 204);
      case '/api/v1/metrics/events':
        return _json(<String, Object>{}, 201);
      case '/api/v1/contents':
        final created = {
          ...item(0),
          'id': 1001,
          'title': '새로 저장한 링크',
          'saved_at': '2026-10-08T00:00:00Z',
        };
        records.insert(0, created);
        return _json(created, 201);
      default:
        final match = RegExp(
          r'^/api/v1/contents/(\d+)(?:/(view|favorite|categories))?$',
        ).firstMatch(request.url.path);
        if (match == null) {
          throw StateError(
            'Unexpected request: ${request.method} ${request.url}',
          );
        }
        final id = int.parse(match.group(1)!);
        final index = records.indexWhere((content) => content['id'] == id);
        if (match.group(2) == 'view') {
          return _json(<String, Object>{}, 201);
        }
        if (request.method == 'DELETE') {
          records.removeAt(index);
          return http.Response('', 204);
        }
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map;
          final updated = {
            ...records[index],
            if (match.group(2) == 'favorite')
              'is_favorite': body['is_favorite'],
            if (match.group(2) == 'categories')
              'categories': _allCategories
                  .where(
                    (category) =>
                        (body['category_ids'] as List).contains(category['id']),
                  )
                  .toList(),
          };
          records[index] = updated;
        }
        return _json(records[index]);
    }
  });

  List<http.Request> get feedCalls =>
      requests.where((request) => request.url.path == _feed).toList();

  List<http.Request> calls(String path) =>
      requests.where((request) => request.url.path == path).toList();
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

Future<void> _openArchive(WidgetTester tester) async {
  tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenArchive();
  await tester.pumpAndSettle();
}

Future<void> _scrollArchiveToEnd(WidgetTester tester) async {
  await _scrollToEnd(tester, ContentListView);
}

Future<void> _scrollToEnd(
  WidgetTester tester,
  Type screen, {
  bool settle = true,
}) async {
  final scrollable = find.descendant(
    of: find.byType(screen),
    matching: find.byType(Scrollable),
  );
  final states = tester
      .stateList<ScrollableState>(scrollable)
      .where((state) => state.position.axis == Axis.vertical);
  final position = states.first.position;
  position.jumpTo(position.maxScrollExtent);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

List<ContentItem> _archiveItems(WidgetTester tester) =>
    tester.widget<ArchiveScreen>(find.byType(ArchiveScreen)).contents;

Finder _cardTitle(String title) => find.descendant(
  of: find.byType(ContentListCard),
  matching: find.text(title),
);

Future<void> _openBookmark(WidgetTester tester) async {
  tester.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.bookmark);
  await tester.pumpAndSettle();
}

Future<void> _openCategory(WidgetTester tester, int categoryId) async {
  final archive = tester.widget<ArchiveScreen>(find.byType(ArchiveScreen));
  archive.onOpenCategory(
    archive.categories.singleWhere((category) => category.id == categoryId),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSearch(WidgetTester tester) async {
  tester.widget<HomeScreen>(find.byType(HomeScreen)).onSearch();
  await tester.pumpAndSettle();
}

Future<void> _submitSearch(
  WidgetTester tester,
  String query, {
  bool settle = true,
}) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void _release(Completer<http.Response> response) {
  if (!response.isCompleted) {
    response.complete(_json({'items': [], 'next_cursor': null}));
  }
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

  testWidgets('archive scrolling requests the next opaque feed cursor', (
    tester,
  ) async {
    final server = _Server();
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      final before = tester
          .widget<ArchiveScreen>(find.byType(ArchiveScreen))
          .contents
          .length;
      await _scrollArchiveToEnd(tester);

      expect(
        server.feedCalls.where(
          (request) => request.url.queryParameters['cursor'] != null,
        ),
        isNotEmpty,
        reason: 'A non-final first page must expose older saved content.',
      );
      final contents = tester
          .widget<ArchiveScreen>(find.byType(ArchiveScreen))
          .contents;
      expect(contents.length, greaterThan(before));
      expect(
        contents.map((content) => content.id).toSet().length,
        contents.length,
      );
    });
  });

  test(
    'readFeed preserves explicit conditions and opaque cursor on the wire',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _json({'items': [], 'next_cursor': 'v1.next_-'});
      });
      addTearDown(client.close);
      final api = ClipbackApi(client: client);
      api.restoreSession(
        const ApiSession(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
          expiresIn: 3600,
          refreshExpiresIn: 86400,
        ),
      );
      final page = await api.readFeed(
        query: 'Flutter & 한글',
        categoryId: 202,
        isFavorite: false,
        limit: 20,
        cursor: 'v1.opaque_-',
      );
      expect(requests.single.url.queryParameters, {
        'q': 'Flutter & 한글',
        'category_id': '202',
        'is_favorite': 'false',
        'limit': '20',
        'cursor': 'v1.opaque_-',
      });
      expect(page.nextCursor, 'v1.next_-');
    },
  );

  testWidgets(
    'archive reaches the 101st saved item and stops after the final page',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        expect(
          server.feedCalls.every(
            (request) => request.url.queryParameters['limit'] == '20',
          ),
          isTrue,
        );
        await _openArchive(tester);
        expect(_archiveItems(tester), hasLength(20));
        expect(find.text('총 20개'), findsNothing);
        for (var page = 0; page < 5; page++) {
          await _scrollArchiveToEnd(tester);
        }
        expect(_archiveItems(tester), hasLength(101));
        expect(_archiveItems(tester).last.title, '피드 항목 101');
        await _scrollArchiveToEnd(tester);
        expect(find.text('피드 항목 101'), findsOneWidget);
        final requests = server.feedCalls.length;
        await _scrollArchiveToEnd(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(server.feedCalls, hasLength(requests));
        expect(
          _archiveItems(tester).map((content) => content.id).toSet(),
          hasLength(101),
        );
      });
    },
  );

  testWidgets('home and archive keep independent page positions', (
    tester,
  ) async {
    final server = _Server(count: 65);
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      await _scrollArchiveToEnd(tester);
      expect(_archiveItems(tester), hasLength(40));
      tester
          .widget<ArchiveScreen>(find.byType(ArchiveScreen))
          .onTab(AppRoute.home);
      await tester.pumpAndSettle();
      expect(
        tester.widget<HomeScreen>(find.byType(HomeScreen)).contents,
        hasLength(20),
      );
      final requests = server.feedCalls.length;
      await _openArchive(tester);
      expect(_archiveItems(tester), hasLength(40));
      expect(server.feedCalls, hasLength(requests));
    });
  });

  testWidgets(
    'home category selection and its archive link use the same server category',
    (tester) async {
      final server = _Server();
      server.records.last['categories'] = [_category, _otherCategory];
      await _withApp(tester, server, () async {
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        home.onCategorySelected!(
          home.categories.singleWhere((category) => category.id == 202),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<HomeScreen>(find.byType(HomeScreen))
              .contents
              .single
              .title,
          '피드 항목 101',
        );
        expect(server.feedCalls.last.url.queryParameters['category_id'], '202');
        await _openArchive(tester);
        expect(_archiveItems(tester).single.title, '피드 항목 101');
        expect(
          tester
              .widget<ArchiveScreen>(find.byType(ArchiveScreen))
              .activeCategoryName,
          '여행',
        );
        expect(server.feedCalls.last.url.queryParameters['category_id'], '202');
      });
    },
  );

  testWidgets('overlapping pages display each content only once', (
    tester,
  ) async {
    final server = _Server(
      count: 41,
      respond: (request, server) {
        if (request.url.path == _feed &&
            request.url.queryParameters['cursor'] != null) {
          final body = jsonDecode(server.page(request).body) as Map;
          return _json({
            ...body,
            'items': [server.records[19], ...(body['items'] as List)],
          });
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      await _scrollArchiveToEnd(tester);
      expect(_archiveItems(tester), hasLength(40));
      await _scrollArchiveToEnd(tester);
      expect(_archiveItems(tester), hasLength(41));
      expect(
        _archiveItems(tester).map((content) => content.id).toSet(),
        hasLength(41),
      );
    });
  });

  testWidgets(
    'duplicate end scrolling cannot start a second in-flight page request',
    (tester) async {
      final gate = Completer<http.Response>();
      addTearDown(() => _release(gate));
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['cursor'] != null) {
            return gate.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        await _scrollToEnd(tester, ContentListView, settle: false);
        await _scrollToEnd(tester, ContentListView, settle: false);
        final pages = server.feedCalls
            .where((request) => request.url.queryParameters['cursor'] != null)
            .toList();
        expect(pages, hasLength(1));
        gate.complete(server.page(pages.single));
        await tester.pumpAndSettle();
        expect(_archiveItems(tester), hasLength(40));
      });
    },
  );

  for (final failure in ['503', 'network', 'invalid JSON']) {
    testWidgets(
      'additional page $failure keeps cards and retries the same cursor',
      (tester) async {
        var fail = true;
        final server = _Server(
          count: 21,
          respond: (request, server) {
            if (request.url.path == _feed &&
                request.url.queryParameters['cursor'] != null &&
                fail) {
              return switch (failure) {
                'network' => throw http.ClientException('Offline'),
                'invalid JSON' => http.Response('{broken', 200),
                _ => _json({'detail': '추가 조회 실패'}, 503),
              };
            }
            return null;
          },
        );
        await _withApp(tester, server, () async {
          await _openArchive(tester);
          await _scrollArchiveToEnd(tester);
          expect(_archiveItems(tester), hasLength(20));
          expect(find.text('다시 시도'), findsOneWidget);
          final failed = server.feedCalls.last.url.queryParameters;
          fail = false;
          await tester.tap(find.text('다시 시도'));
          await tester.pumpAndSettle();
          expect(server.feedCalls.last.url.queryParameters, failed);
          expect(_archiveItems(tester), hasLength(21));
          expect(find.text('다시 시도'), findsNothing);
          expect(server.calls('/api/v1/auth/guest'), isEmpty);
        });
      },
    );
  }

  testWidgets(
    'category feed finds old multi-category content beyond the home page',
    (tester) async {
      final server = _Server();
      server.records.last['categories'] = [_category, _otherCategory];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        await _openCategory(tester, 202);
        final request = server.feedCalls.last.url.queryParameters;
        expect(request['category_id'], '202');
        expect(request['cursor'], isNull);
        expect(_archiveItems(tester).map((content) => content.title), [
          '피드 항목 101',
        ]);
        expect(find.text('피드 항목 101'), findsOneWidget);
        expect(find.text('여행 콘텐츠가 없어요'), findsNothing);
      });
    },
  );

  testWidgets(
    'bookmark feed finds an old favorite outside the home first page',
    (tester) async {
      final server = _Server();
      server.records.last['is_favorite'] = true;
      await _withApp(tester, server, () async {
        await _openBookmark(tester);
        expect(
          server.feedCalls.last.url.queryParameters['is_favorite'],
          'true',
        );
        final bookmark = tester.widget<BookmarkScreen>(
          find.byType(BookmarkScreen),
        );
        expect(bookmark.contents.single.title, '피드 항목 101');
        expect(bookmark.bookmarkedIds, contains(bookmark.contents.single.id));
        expect(find.text('피드 항목 101'), findsOneWidget);
        expect(find.text('즐겨찾기한 콘텐츠가 없어요'), findsNothing);
      });
    },
  );

  testWidgets('bookmark scrolling keeps the favorite condition across pages', (
    tester,
  ) async {
    final server = _Server(count: 45);
    for (final record in server.records) {
      record['is_favorite'] = true;
    }
    await _withApp(tester, server, () async {
      await _openBookmark(tester);
      await _scrollToEnd(tester, BookmarkScreen);
      await _scrollToEnd(tester, BookmarkScreen);
      final items = tester
          .widget<BookmarkScreen>(find.byType(BookmarkScreen))
          .contents;
      expect(items, hasLength(45));
      expect(items.every((content) => content.bookmarked), isTrue);
      final favoriteCalls = server.feedCalls.where(
        (request) => request.url.queryParameters['is_favorite'] != null,
      );
      expect(
        favoriteCalls.every(
          (request) => request.url.queryParameters['is_favorite'] == 'true',
        ),
        isTrue,
      );
      final calls = server.feedCalls.length;
      await _scrollToEnd(tester, BookmarkScreen);
      expect(server.feedCalls, hasLength(calls));
    });
  });

  testWidgets(
    'empty bookmark feed stops without fetching the general feed again',
    (tester) async {
      final server = _Server(count: 21);
      await _withApp(tester, server, () async {
        await _openBookmark(tester);
        expect(find.text('즐겨찾기한 콘텐츠가 없어요'), findsOneWidget);
        expect(
          tester.widget<BookmarkScreen>(find.byType(BookmarkScreen)).contents,
          isEmpty,
        );
        final favorite = server.feedCalls
            .where(
              (request) => request.url.queryParameters['is_favorite'] == 'true',
            )
            .toList();
        expect(favorite, hasLength(1));
        expect(favorite.single.url.queryParameters['cursor'], isNull);
        final calls = server.feedCalls.length;
        await tester
            .widget<BookmarkScreen>(find.byType(BookmarkScreen))
            .onLoadMore!();
        await tester.pumpAndSettle();
        expect(server.feedCalls, hasLength(calls));
      });
    },
  );

  testWidgets(
    'category scrolling retains the category condition and does not re-filter its first category label',
    (tester) async {
      final server = _Server(count: 41);
      for (final record in server.records) {
        record['categories'] = [_category, _otherCategory];
      }
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        await _openCategory(tester, 202);
        await _scrollArchiveToEnd(tester);
        await _scrollArchiveToEnd(tester);
        expect(_archiveItems(tester), hasLength(41));
        final filtered = server.feedCalls.where(
          (request) => request.url.queryParameters['category_id'] != null,
        );
        expect(
          filtered.every(
            (request) => request.url.queryParameters['category_id'] == '202',
          ),
          isTrue,
        );
        await _scrollArchiveToEnd(tester);
        expect(find.text('피드 항목 41'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'bookmark-first finishes favorite pages before non-favorite pages',
    (tester) async {
      final server = _Server(count: 45);
      for (var index = 0; index < server.records.length; index++) {
        server.records[index]['is_favorite'] = index.isEven;
      }
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        tester
            .widget<ArchiveScreen>(find.byType(ArchiveScreen))
            .onSortChanged(true);
        await tester.pumpAndSettle();
        expect(_archiveItems(tester), hasLength(20));
        expect(
          _archiveItems(tester).every((content) => content.bookmarked),
          isTrue,
        );
        expect(
          server.feedCalls.where(
            (request) => request.url.queryParameters['is_favorite'] == 'false',
          ),
          isEmpty,
        );
        for (
          var page = 0;
          page < 4 && _archiveItems(tester).length < 45;
          page++
        ) {
          await _scrollArchiveToEnd(tester);
        }
        expect(_archiveItems(tester), hasLength(45));
        expect(
          _archiveItems(tester).take(23).every((content) => content.bookmarked),
          isTrue,
        );
        expect(
          _archiveItems(
            tester,
          ).skip(23).every((content) => !content.bookmarked),
          isTrue,
        );
        final conditions = server.feedCalls
            .map((request) => request.url.queryParameters['is_favorite'])
            .whereType<String>()
            .toList();
        expect(conditions, ['true', 'true', 'false', 'false']);
        final calls = server.feedCalls.length;
        await _scrollArchiveToEnd(tester);
        expect(server.feedCalls, hasLength(calls));
      });
    },
  );

  testWidgets(
    'bookmark-first with no favorites enters non-favorite pages without a false empty state',
    (tester) async {
      final server = _Server(count: 21);
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        tester
            .widget<ArchiveScreen>(find.byType(ArchiveScreen))
            .onSortChanged(true);
        await tester.pumpAndSettle();
        expect(_archiveItems(tester), hasLength(20));
        expect(find.text('저장한 콘텐츠가 없어요'), findsNothing);
        expect(
          server.feedCalls.where(
            (request) => request.url.queryParameters['is_favorite'] == 'true',
          ),
          hasLength(1),
        );
        expect(
          server.feedCalls.where(
            (request) => request.url.queryParameters['is_favorite'] == 'false',
          ),
          hasLength(1),
        );
        await _scrollArchiveToEnd(tester);
        expect(_archiveItems(tester), hasLength(21));
      });
    },
  );

  testWidgets('changing archive sort discards an older pending favorite page', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    addTearDown(() => _release(gate));
    http.Response? oldResponse;
    final server = _Server(
      count: 41,
      respond: (request, server) {
        final parameters = request.url.queryParameters;
        if (request.url.path == _feed &&
            parameters['is_favorite'] == 'true' &&
            parameters['cursor'] != null) {
          oldResponse = server.page(request);
          return gate.future;
        }
        return null;
      },
    );
    for (final record in server.records.skip(1)) {
      record['is_favorite'] = true;
    }
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      tester
          .widget<ArchiveScreen>(find.byType(ArchiveScreen))
          .onSortChanged(true);
      await tester.pumpAndSettle();
      await _scrollToEnd(tester, ContentListView, settle: false);
      tester
          .widget<ArchiveScreen>(find.byType(ArchiveScreen))
          .onSortChanged(false);
      await tester.pumpAndSettle();
      expect(_archiveItems(tester).first.title, '피드 항목 1');
      gate.complete(oldResponse!);
      await tester.pumpAndSettle();
      expect(_archiveItems(tester), hasLength(20));
      expect(_archiveItems(tester).first.title, '피드 항목 1');
      expect(server.feedCalls.last.url.queryParameters['is_favorite'], isNull);
      expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
    });
  });

  testWidgets('category change discards an older in-flight category page', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    addTearDown(() => _release(gate));
    http.Response? oldResponse;
    final server = _Server(
      count: 41,
      respond: (request, server) {
        final parameters = request.url.queryParameters;
        if (request.url.path == _feed &&
            parameters['category_id'] == '101' &&
            parameters['cursor'] != null) {
          oldResponse = server.page(request);
          return gate.future;
        }
        return null;
      },
    );
    server.records.last['categories'] = [_otherCategory];
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      await _openCategory(tester, 101);
      await _scrollToEnd(tester, ContentListView, settle: false);
      await _openCategory(tester, 202);
      expect(_archiveItems(tester).single.title, '피드 항목 41');
      gate.complete(oldResponse!);
      await tester.pumpAndSettle();
      expect(_archiveItems(tester).single.title, '피드 항목 41');
      expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
    });
  });

  testWidgets(
    'search queries fetch independent pages instead of the loaded home subset',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _openSearch(tester);
        await _submitSearch(tester, '피드 항목 101');
        expect(server.feedCalls.last.url.queryParameters['q'], '피드 항목 101');
        expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
        expect(_cardTitle('피드 항목 101'), findsOneWidget);
        await tester.tap(_cardTitle('피드 항목 101'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).content.title,
          '피드 항목 101',
        );
      });
    },
  );

  testWidgets('search scrolling keeps its query and uses the returned cursor', (
    tester,
  ) async {
    final server = _Server(count: 41);
    await _withApp(tester, server, () async {
      await _openSearch(tester);
      await _submitSearch(tester, '피드');
      final before = server.feedCalls
          .where((request) => request.url.queryParameters['q'] == '피드')
          .length;
      await _scrollToEnd(tester, SearchScreen);
      final matching = server.feedCalls
          .where((request) => request.url.queryParameters['q'] == '피드')
          .toList();
      expect(matching, hasLength(before + 1));
      expect(matching.last.url.queryParameters['cursor'], isNotNull);
      expect(matching.last.url.queryParameters['limit'], '20');
      await _scrollToEnd(tester, SearchScreen);
      await _scrollToEnd(tester, SearchScreen);
      expect(find.text('피드 항목 41'), findsOneWidget);
    });
  });

  testWidgets('late search page cannot mix results after changing the query', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    addTearDown(() => _release(gate));
    http.Response? oldResponse;
    final server = _Server(
      count: 41,
      respond: (request, server) {
        final parameters = request.url.queryParameters;
        if (request.url.path == _feed &&
            parameters['q'] == '피드' &&
            parameters['cursor'] != null) {
          oldResponse = server.page(request);
          return gate.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openSearch(tester);
      await _submitSearch(tester, '피드');
      await _scrollToEnd(tester, SearchScreen, settle: false);
      await _submitSearch(tester, '항목 41');
      expect(find.text('피드 항목 41'), findsOneWidget);
      gate.complete(oldResponse!);
      await tester.pumpAndSettle();
      expect(find.text('피드 항목 41'), findsOneWidget);
      expect(find.text('피드 항목 21'), findsNothing);
      expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
    });
  });

  testWidgets(
    'search A to B to A cannot be overwritten by the earlier A request',
    (tester) async {
      final gate = Completer<http.Response>();
      addTearDown(() => _release(gate));
      var queries = 0;
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['q'] == '피드') {
            queries++;
            if (queries == 1) {
              return gate.future;
            }
            return _json({
              'items': [server.item(100)],
              'next_cursor': null,
            });
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openSearch(tester);
        await _submitSearch(tester, '피드', settle: false);
        await _submitSearch(tester, '항목 41');
        await _submitSearch(tester, '피드');
        expect(find.text('피드 항목 101'), findsOneWidget);
        gate.complete(
          _json({
            'items': [server.item(0)],
            'next_cursor': null,
          }),
        );
        await tester.pumpAndSettle();
        expect(find.text('피드 항목 101'), findsOneWidget);
        expect(find.text('피드 항목 1'), findsNothing);
      });
    },
  );

  testWidgets('clearing search removes its cursor and ignores a late page', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    addTearDown(() => _release(gate));
    http.Response? oldResponse;
    final server = _Server(
      count: 41,
      respond: (request, server) {
        if (request.url.path == _feed &&
            request.url.queryParameters['q'] != null &&
            request.url.queryParameters['cursor'] != null) {
          oldResponse = server.page(request);
          return gate.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openSearch(tester);
      await _submitSearch(tester, '피드');
      await _scrollToEnd(tester, SearchScreen, settle: false);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      gate.complete(oldResponse!);
      await tester.pumpAndSettle();
      expect(find.text('최근 검색어'), findsOneWidget);
      expect(find.byType(ContentListCard), findsNothing);
      final calls = server.feedCalls.length;
      await _submitSearch(tester, '   ');
      expect(server.feedCalls, hasLength(calls));
    });
  });

  testWidgets('invalid additional cursor offers a first-page reset', (
    tester,
  ) async {
    var reject = true;
    final server = _Server(
      count: 21,
      respond: (request, server) {
        if (request.url.path == _feed &&
            request.url.queryParameters['cursor'] != null &&
            reject) {
          return _json({'detail': 'Invalid feed cursor'}, 422);
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      await _scrollArchiveToEnd(tester);
      expect(_archiveItems(tester), hasLength(20));
      expect(find.text('처음부터 다시 불러오기'), findsOneWidget);
      reject = false;
      await tester.tap(find.text('처음부터 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
      expect(_archiveItems(tester), hasLength(20));
      expect(find.text('처음부터 다시 불러오기'), findsNothing);
      await _scrollArchiveToEnd(tester);
      expect(_archiveItems(tester), hasLength(21));
    });
  });

  testWidgets(
    'initial category failure offers retry without claiming no saved content',
    (tester) async {
      var fail = true;
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['category_id'] == '202' &&
              fail) {
            return _json({'detail': '분류 조회 실패'}, 503);
          }
          return null;
        },
      );
      server.records.last['categories'] = [_otherCategory];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        await _openCategory(tester, 202);
        expect(find.text('다시 시도'), findsOneWidget);
        expect(find.text('여행 콘텐츠가 없어요'), findsNothing);
        fail = false;
        await tester.tap(find.text('다시 시도'));
        await tester.pumpAndSettle();
        expect(find.text('피드 항목 101'), findsOneWidget);
        expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
      });
    },
  );

  testWidgets(
    'additional-page refresh preserves its cursor and does not create a guest',
    (tester) async {
      var expire = true;
      final server = _Server(
        count: 21,
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['cursor'] != null &&
              expire) {
            expire = false;
            return _json({'detail': 'Expired token'}, 401);
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        await _scrollArchiveToEnd(tester);
        final calls = server.feedCalls
            .where((request) => request.url.queryParameters['cursor'] != null)
            .toList();
        expect(calls, hasLength(2));
        expect(calls.last.url.queryParameters, calls.first.url.queryParameters);
        expect(calls.last.headers['Authorization'], 'Bearer rotated-access');
        expect(server.calls('/api/v1/auth/refresh'), hasLength(1));
        expect(server.calls('/api/v1/auth/guest'), isEmpty);
        expect(_archiveItems(tester), hasLength(21));
      });
    },
  );

  testWidgets('final additional-page 401 keeps the account and loaded cards', (
    tester,
  ) async {
    final server = _Server(
      count: 21,
      respond: (request, server) {
        if (request.url.path == _feed &&
            request.url.queryParameters['cursor'] != null) {
          return _json({'detail': 'Expired token'}, 401);
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      await _scrollArchiveToEnd(tester);
      expect(_archiveItems(tester), hasLength(20));
      expect(find.text('콘텐츠를 더 불러오지 못했어요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(server.calls('/api/v1/auth/refresh'), hasLength(1));
      expect(server.calls('/api/v1/auth/guest'), isEmpty);
    });
  });

  testWidgets(
    'detail next at the loaded boundary fetches and advances without wrapping',
    (tester) async {
      final server = _Server(count: 21);
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final archive = tester.widget<ArchiveScreen>(
          find.byType(ArchiveScreen),
        );
        archive.onOpenContent(archive.contents.last);
        await tester.pumpAndSettle();
        tester
            .widget<DetailScreen>(find.byType(DetailScreen))
            .onOpenAdjacent(1);
        await tester.pumpAndSettle();
        final detail = tester.widget<DetailScreen>(find.byType(DetailScreen));
        expect(detail.content.title, '피드 항목 21');
        expect(detail.contents, hasLength(21));
        expect(
          server.feedCalls.where(
            (request) => request.url.queryParameters['cursor'] != null,
          ),
          hasLength(1),
        );
        final requests = server.feedCalls.length;
        detail.onOpenAdjacent(1);
        await tester.pumpAndSettle();
        expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).content.title,
          '피드 항목 21',
        );
        expect(server.feedCalls, hasLength(requests));
        expect(find.text('21 / 불러온 21개'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'detail boundary failure retains the current item and retries once',
    (tester) async {
      final gate = Completer<http.Response>();
      addTearDown(() => _release(gate));
      var fail = true;
      final server = _Server(
        count: 21,
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['cursor'] != null &&
              fail) {
            return gate.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final archive = tester.widget<ArchiveScreen>(
          find.byType(ArchiveScreen),
        );
        archive.onOpenContent(archive.contents.last);
        await tester.pumpAndSettle();
        final detail = tester.widget<DetailScreen>(find.byType(DetailScreen));
        detail.onOpenAdjacent(1);
        detail.onOpenAdjacent(1);
        await tester.pump();
        expect(
          server.feedCalls.where(
            (request) => request.url.queryParameters['cursor'] != null,
          ),
          hasLength(1),
        );
        expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).content.title,
          '피드 항목 20',
        );
        gate.complete(_json({'detail': '추가 조회 실패'}, 503));
        await tester.pumpAndSettle();
        expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).content.title,
          '피드 항목 20',
        );
        expect(find.text('다시 시도'), findsOneWidget);
        fail = false;
        await tester.tap(find.text('다시 시도'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<DetailScreen>(find.byType(DetailScreen)).content.title,
          '피드 항목 21',
        );
      });
    },
  );

  testWidgets(
    'detail next follows its category feed instead of unrelated home content',
    (tester) async {
      final server = _Server(count: 25);
      for (final record in server.records.skip(1)) {
        record['categories'] = [_otherCategory];
      }
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        await _openCategory(tester, 202);
        final archive = tester.widget<ArchiveScreen>(
          find.byType(ArchiveScreen),
        );
        archive.onOpenContent(archive.contents.last);
        await tester.pumpAndSettle();
        tester
            .widget<DetailScreen>(find.byType(DetailScreen))
            .onOpenAdjacent(1);
        await tester.pumpAndSettle();
        final detail = tester.widget<DetailScreen>(find.byType(DetailScreen));
        expect(detail.content.title, '피드 항목 22');
        expect(
          detail.contents.every((content) => content.category.id == 202),
          isTrue,
        );
        expect(server.feedCalls.last.url.queryParameters['category_id'], '202');
        expect(server.feedCalls.last.url.queryParameters['cursor'], isNotNull);
      });
    },
  );

  testWidgets(
    'detail back restores loaded archive pages without starting again',
    (tester) async {
      final server = _Server(count: 45);
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        await _scrollArchiveToEnd(tester);
        final archive = tester.widget<ArchiveScreen>(
          find.byType(ArchiveScreen),
        );
        archive.onOpenContent(archive.contents.last);
        await tester.pumpAndSettle();
        final requests = server.feedCalls.length;
        tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
        await tester.pumpAndSettle();
        expect(_archiveItems(tester), hasLength(40));
        expect(server.feedCalls, hasLength(requests));
        await _scrollArchiveToEnd(tester);
        expect(_archiveItems(tester), hasLength(45));
      });
    },
  );

  testWidgets('detail first item cannot wrap to a loaded last item', (
    tester,
  ) async {
    final server = _Server(count: 21);
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      final archive = tester.widget<ArchiveScreen>(find.byType(ArchiveScreen));
      archive.onOpenContent(archive.contents.first);
      await tester.pumpAndSettle();
      final requests = server.feedCalls.length;
      tester.widget<DetailScreen>(find.byType(DetailScreen)).onOpenAdjacent(-1);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DetailScreen>(find.byType(DetailScreen)).content.title,
        '피드 항목 1',
      );
      expect(server.feedCalls, hasLength(requests));
      expect(
        find.text('1 / 20'),
        findsNothing,
        reason: 'Loaded rows must not be presented as the entire feed.',
      );
    });
  });

  testWidgets(
    'search page error is visible without switching to partial local matches',
    (tester) async {
      var fail = true;
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['q'] == '피드 항목 101' &&
              fail) {
            return _json({'detail': '검색 조회 실패'}, 503);
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openSearch(tester);
        await _submitSearch(tester, '피드 항목 101');
        expect(find.text('다시 시도'), findsOneWidget);
        expect(find.byType(EmptySearchResult), findsNothing);
        fail = false;
        await tester.tap(find.text('다시 시도'));
        await tester.pumpAndSettle();
        expect(_cardTitle('피드 항목 101'), findsOneWidget);
        expect(server.feedCalls.last.url.queryParameters['q'], '피드 항목 101');
        expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
      });
    },
  );

  testWidgets(
    'successful deletion invalidates a pending page before it can restore deleted content',
    (tester) async {
      final gate = Completer<http.Response>();
      addTearDown(() => _release(gate));
      http.Response? oldResponse;
      final server = _Server(
        count: 41,
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['cursor'] != null) {
            final body = jsonDecode(server.page(request).body) as Map;
            oldResponse = _json({
              ...body,
              'items': [server.records.first, ...(body['items'] as List)],
            });
            return gate.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final deleting = _archiveItems(tester).first;
        await _scrollToEnd(tester, ContentListView, settle: false);
        tester
            .widget<ArchiveScreen>(find.byType(ArchiveScreen))
            .onDeleteContent(deleting);
        await tester.pumpAndSettle();
        expect(
          _archiveItems(tester).any((content) => content.id == deleting.id),
          isFalse,
        );
        gate.complete(oldResponse!);
        await tester.pumpAndSettle();
        expect(_archiveItems(tester), hasLength(20));
        expect(
          _archiveItems(tester).any((content) => content.id == deleting.id),
          isFalse,
        );
        expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
      });
    },
  );

  testWidgets('successful save resets pages and rejects a late pre-save page', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    addTearDown(() => _release(gate));
    http.Response? oldResponse;
    final server = _Server(
      count: 41,
      respond: (request, server) {
        if (request.url.path == _feed &&
            request.url.queryParameters['cursor'] != null) {
          oldResponse = server.page(request);
          return gate.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      final addLink = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .onAddLink;
      await _openArchive(tester);
      await _scrollToEnd(tester, ContentListView, settle: false);
      final saved = addLink(url: 'https://example.com/new');
      await tester.pumpAndSettle();
      await saved;
      gate.complete(oldResponse!);
      await tester.pumpAndSettle();
      tester
          .widget<DetailScreen>(find.byType(DetailScreen))
          .onTab(AppRoute.archive);
      await tester.pumpAndSettle();
      expect(_archiveItems(tester), hasLength(20));
      expect(_archiveItems(tester).first.title, '새로 저장한 링크');
      expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
      expect(server.calls('/api/v1/contents'), hasLength(1));
    });
  });

  testWidgets(
    'new guest account cannot inherit a pending old-account page or cursor',
    (tester) async {
      final gate = Completer<http.Response>();
      addTearDown(() => _release(gate));
      http.Response? oldResponse;
      final server = _Server(
        count: 41,
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['cursor'] != null) {
            oldResponse = server.page(request);
            return gate.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        home.onTab(AppRoute.login);
        await tester.pumpAndSettle();
        final continueGuest = tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onContinue;
        home.onTab(AppRoute.home);
        await tester.pumpAndSettle();
        await _openArchive(tester);
        await _scrollToEnd(tester, ContentListView, settle: false);
        server.records
          ..clear()
          ..add({...server.item(0), 'id': 2001, 'title': '새 계정 콘텐츠'});
        final guest = continueGuest();
        await tester.pumpAndSettle();
        await guest;
        gate.complete(oldResponse!);
        await tester.pumpAndSettle();
        tester.widget<OnboardingScreen>(find.byType(OnboardingScreen)).onDone();
        await tester.pumpAndSettle();
        tester
            .widget<InterestSelectionScreen>(
              find.byType(InterestSelectionScreen),
            )
            .onDone();
        await tester.pumpAndSettle();
        await _openArchive(tester);
        expect(_archiveItems(tester).map((content) => content.title), [
          '새 계정 콘텐츠',
        ]);
        expect(
          server.feedCalls.last.headers['Authorization'],
          'Bearer guest-access',
        );
        expect(server.feedCalls.last.url.queryParameters['cursor'], isNull);
        final calls = server.feedCalls.length;
        await _scrollArchiveToEnd(tester);
        expect(server.feedCalls, hasLength(calls));
      });
    },
  );

  testWidgets(
    'profile statistics remain separate from loaded feed row counts',
    (tester) async {
      final server = _Server(count: 41);
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        expect(find.text('불러온 20개'), findsOneWidget);
        await _scrollArchiveToEnd(tester);
        expect(find.text('불러온 40개'), findsOneWidget);
        tester
            .widget<ArchiveScreen>(find.byType(ArchiveScreen))
            .onTab(AppRoute.my);
        await tester.pumpAndSettle();
        expect(
          tester.widget<MyScreen>(find.byType(MyScreen)).user.savedContentCount,
          999,
        );
        expect(find.text('999'), findsOneWidget);
      });
    },
  );

  test(
    'category editing preserves server counts and raw ordering timestamps',
    () {
      final savedAt = DateTime.parse('2026-10-07T15:30:00+09:00');
      final category = CategoryItem(
        id: 101,
        name: '공부',
        color: Colors.green,
        tint: Colors.greenAccent,
        deep: Colors.teal,
        contentCount: 51,
        lastSavedAt: '2026. 10. 07 오후 03:30',
        rawLastSavedAt: savedAt,
      );
      final renamed = category.copyWith(name: '새 이름', color: Colors.blue);
      expect(renamed.contentCount, 51);
      expect(renamed.rawLastSavedAt, savedAt);
      expect(renamed.lastSavedAt, category.lastSavedAt);
      expect(renamed.id, 101);
    },
  );

  testWidgets(
    'folders use server counts and raw timestamp descending with ID ties and nulls last',
    (tester) async {
      final categories = [
        {
          ..._category,
          'id': 404,
          'name': '날짜 없음',
          'last_saved_at': null,
          'content_count': 74,
        },
        {
          ..._otherCategory,
          'last_saved_at': '2026-10-07T00:00:00Z',
          'content_count': 62,
        },
        {
          ..._category,
          'last_saved_at': '2026-10-07T00:00:00Z',
          'content_count': 51,
        },
        {
          ..._category,
          'id': 505,
          'name': '예전 분류',
          'last_saved_at': '2026-10-01T00:00:00Z',
          'content_count': 83,
        },
        {..._uncategorized, 'last_saved_at': null, 'content_count': 94},
      ];
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == '/api/v1/categories') {
            return _json(categories);
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        final category = home.categories.singleWhere(
          (category) => category.id == 101,
        );
        expect(category.rawLastSavedAt?.toUtc(), DateTime.utc(2026, 10, 7));
        expect(category.contentCount, 51);
        home.onOpenCategories();
        await tester.pumpAndSettle();
        final rows = tester
            .widgetList<CategoryRow>(find.byType(CategoryRow))
            .toList();
        expect(rows.map((row) => row.category.id), [101, 202, 505, 404]);
        expect(rows.map((row) => row.category.contentCount), [51, 62, 83, 74]);
        expect(
          tester
              .widget<UnclassifiedCategoryRow>(
                find.byType(UnclassifiedCategoryRow),
              )
              .count,
          94,
        );
        expect(find.text('51'), findsOneWidget);
        rows.first.onMore!();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CategoryActionSheet>(find.byType(CategoryActionSheet))
              .contentCount,
          51,
        );
        expect(find.text('저장된 콘텐츠 51'), findsOneWidget);
      });
    },
  );

  for (final destination in ['back', 'different content']) {
    testWidgets(
      'late detail boundary page cannot navigate after $destination',
      (tester) async {
        final gate = Completer<http.Response>();
        addTearDown(() => _release(gate));
        http.Response? response;
        final server = _Server(
          count: 21,
          respond: (request, server) {
            if (request.url.path == _feed &&
                request.url.queryParameters['cursor'] != null) {
              response = server.page(request);
              return gate.future;
            }
            return null;
          },
        );
        await _withApp(tester, server, () async {
          await _openArchive(tester);
          final archive = tester.widget<ArchiveScreen>(
            find.byType(ArchiveScreen),
          );
          archive.onOpenContent(archive.contents.last);
          await tester.pumpAndSettle();
          final detail = tester.widget<DetailScreen>(find.byType(DetailScreen));
          detail.onOpenAdjacent(1);
          await tester.pump();
          if (destination == 'back') {
            detail.onBack();
          } else {
            detail.onOpenContent(detail.contents[1]);
          }
          await tester.pump();
          gate.complete(response!);
          await tester.pumpAndSettle();
          if (destination == 'back') {
            expect(find.byType(ArchiveScreen), findsOneWidget);
            expect(find.byType(DetailScreen), findsNothing);
          } else {
            expect(
              tester
                  .widget<DetailScreen>(find.byType(DetailScreen))
                  .content
                  .title,
              '피드 항목 2',
            );
          }
          expect(
            server.feedCalls.where(
              (request) => request.url.queryParameters['cursor'] != null,
            ),
            hasLength(1),
          );
        });
      },
    );
  }

  testWidgets(
    'non-favorite phase failure retries false without restarting favorite pages',
    (tester) async {
      var fail = true;
      final server = _Server(
        count: 41,
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['is_favorite'] == 'false' &&
              fail) {
            return _json({'detail': '일반 구간 조회 실패'}, 503);
          }
          return null;
        },
      );
      for (final record in server.records.take(21)) {
        record['is_favorite'] = true;
      }
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        tester
            .widget<ArchiveScreen>(find.byType(ArchiveScreen))
            .onSortChanged(true);
        await tester.pumpAndSettle();
        await _scrollArchiveToEnd(tester);
        if (!server.feedCalls.any(
          (request) => request.url.queryParameters['is_favorite'] == 'false',
        )) {
          await _scrollArchiveToEnd(tester);
        }
        expect(_archiveItems(tester), hasLength(21));
        expect(find.text('다시 시도'), findsOneWidget);
        final favoriteCalls = server.feedCalls
            .where(
              (request) => request.url.queryParameters['is_favorite'] == 'true',
            )
            .length;
        final failed = server.feedCalls.last.url.queryParameters;
        expect(failed['is_favorite'], 'false');
        fail = false;
        await tester.ensureVisible(find.text('다시 시도'));
        await tester.tap(find.text('다시 시도'));
        await tester.pumpAndSettle();
        expect(_archiveItems(tester), hasLength(41));
        expect(server.feedCalls.last.url.queryParameters, failed);
        expect(
          server.feedCalls.where(
            (request) => request.url.queryParameters['is_favorite'] == 'true',
          ),
          hasLength(favoriteCalls),
        );
        expect(
          _archiveItems(tester).take(21).every((content) => content.bookmarked),
          isTrue,
        );
        expect(
          _archiveItems(
            tester,
          ).skip(21).every((content) => !content.bookmarked),
          isTrue,
        );
      });
    },
  );

  testWidgets('scroll and detail share the same in-flight next page', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    addTearDown(() => _release(gate));
    http.Response? response;
    final server = _Server(
      count: 21,
      respond: (request, server) {
        if (request.url.path == _feed &&
            request.url.queryParameters['cursor'] != null) {
          response = server.page(request);
          return gate.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      final archive = tester.widget<ArchiveScreen>(find.byType(ArchiveScreen));
      await _scrollToEnd(tester, ContentListView, settle: false);
      archive.onOpenContent(archive.contents.last);
      await tester.pump();
      tester.widget<DetailScreen>(find.byType(DetailScreen)).onOpenAdjacent(1);
      await tester.pump();
      expect(
        server.feedCalls.where(
          (request) => request.url.queryParameters['cursor'] != null,
        ),
        hasLength(1),
      );
      gate.complete(response!);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DetailScreen>(find.byType(DetailScreen)).content.title,
        '피드 항목 21',
      );
      expect(
        server.feedCalls.where(
          (request) => request.url.queryParameters['cursor'] != null,
        ),
        hasLength(1),
      );
    });
  });

  testWidgets(
    'a short first page fills the viewport after layout without user scrolling',
    (tester) async {
      const cursor = 'v1.short-page_-';
      final server = _Server(
        count: 21,
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['cursor'] == null) {
            server._offsets[cursor] = (key: 'null|null|null', offset: 3);
            return _json({
              'items': server.records.take(3).toList(),
              'next_cursor': cursor,
            });
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        expect(_archiveItems(tester), hasLength(21));
        final additional = server.feedCalls
            .where((request) => request.url.queryParameters['cursor'] != null)
            .toList();
        expect(additional, hasLength(1));
        expect(additional.single.url.queryParameters['cursor'], cursor);
        expect(
          _archiveItems(tester).map((content) => content.id).toSet(),
          hasLength(21),
        );
      });
    },
  );

  for (final action in ['category', 'delete']) {
    testWidgets(
      'archive second-page $action failure restores its list without polluting home',
      (tester) async {
        final gate = Completer<http.Response>();
        addTearDown(() => _release(gate));
        final server = _Server(
          count: 45,
          respond: (request, server) {
            if ((action == 'delete' && request.method == 'DELETE') ||
                (action == 'category' &&
                    request.method == 'PUT' &&
                    request.url.path.endsWith('/categories'))) {
              return gate.future;
            }
            return null;
          },
        );
        await _withApp(tester, server, () async {
          final homeIds = tester
              .widget<HomeScreen>(find.byType(HomeScreen))
              .contents
              .map((content) => content.id)
              .toList();
          await _openArchive(tester);
          await _scrollArchiveToEnd(tester);
          final originalIds = _archiveItems(
            tester,
          ).map((content) => content.id).toList();
          final target = _archiveItems(tester)[25];
          final archive = tester.widget<ArchiveScreen>(
            find.byType(ArchiveScreen),
          );
          if (action == 'category') {
            archive.onChangeContentCategory(
              target,
              archive.categories.singleWhere((category) => category.id == 202),
            );
          } else {
            archive.onDeleteContent(target);
          }
          await tester.pump();
          if (action == 'category') {
            expect(
              _archiveItems(
                tester,
              ).singleWhere((content) => content.id == target.id).category.id,
              202,
            );
          } else {
            expect(
              _archiveItems(tester).any((content) => content.id == target.id),
              isTrue,
            );
            expect(
              _archiveItems(
                tester,
              ).singleWhere((content) => content.id == target.id).mutationLabel,
              '삭제 중…',
            );
          }
          gate.complete(_json({'detail': '콘텐츠 변경 거절'}, 503));
          await tester.pumpAndSettle();
          expect(
            _archiveItems(tester).map((content) => content.id),
            originalIds,
          );
          expect(
            _archiveItems(
              tester,
            ).singleWhere((content) => content.id == target.id).category.id,
            101,
          );
          expect(find.text('콘텐츠 변경 거절'), findsOneWidget);
          tester
              .widget<ArchiveScreen>(find.byType(ArchiveScreen))
              .onTab(AppRoute.home);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<HomeScreen>(find.byType(HomeScreen))
                .contents
                .map((content) => content.id),
            homeIds,
          );
          expect(
            tester
                .widget<HomeScreen>(find.byType(HomeScreen))
                .contents
                .any((content) => content.id == target.id),
            isFalse,
          );
        });
      },
    );
  }

  testWidgets(
    'older write metadata cannot replace a newer refresh or advance its cursor',
    (tester) async {
      final metadata = Completer<http.Response>();
      final started = Completer<void>();
      addTearDown(() => _release(metadata));
      var categoryReads = 0;
      final server = _Server(
        count: 41,
        respond: (request, server) {
          if (request.url.path == '/api/v1/categories') {
            categoryReads++;
            if (categoryReads == 2) {
              started.complete();
              return metadata.future;
            }
            if (categoryReads >= 3) {
              return _json([
                {..._category, 'name': '최신 분류', 'content_count': 37},
                _otherCategory,
                _uncategorized,
              ]);
            }
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final archive = tester.widget<ArchiveScreen>(
          find.byType(ArchiveScreen),
        );
        final first = archive.contents[0];
        final second = archive.contents[1];
        archive.onToggleBookmark(first);
        await tester.pump();
        await started.future;
        archive.onToggleBookmark(second);
        await tester.pumpAndSettle();
        final current = tester.widget<ArchiveScreen>(
          find.byType(ArchiveScreen),
        );
        expect(current.contents, hasLength(20));
        expect(
          current.categories.singleWhere((category) => category.id == 101).name,
          '최신 분류',
        );
        final cursor = current.feed!.nextCursor;
        final ids = current.contents.map((content) => content.id).toList();
        final calls = server.feedCalls.length;
        metadata.complete(
          _json([
            {..._category, 'name': '이전 분류', 'content_count': 2},
            _otherCategory,
            _uncategorized,
          ]),
        );
        await tester.pumpAndSettle();
        final after = tester.widget<ArchiveScreen>(find.byType(ArchiveScreen));
        expect(after.contents.map((content) => content.id), ids);
        expect(after.feed!.nextCursor, cursor);
        expect(
          after.categories.singleWhere((category) => category.id == 101).name,
          '최신 분류',
        );
        expect(
          after.categories
              .singleWhere((category) => category.id == 101)
              .contentCount,
          37,
        );
        expect(server.feedCalls, hasLength(calls));
      });
    },
  );

  testWidgets(
    'filter changed during metadata refresh keeps its first page and cursor',
    (tester) async {
      final metadata = Completer<http.Response>();
      final started = Completer<void>();
      addTearDown(() => _release(metadata));
      var categoryReads = 0;
      final server = _Server(
        count: 41,
        respond: (request, server) {
          if (request.url.path == '/api/v1/categories' &&
              ++categoryReads == 2) {
            started.complete();
            return metadata.future;
          }
          return null;
        },
      );
      for (final record in server.records) {
        record['categories'] = [_category, _otherCategory];
      }
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final archive = tester.widget<ArchiveScreen>(
          find.byType(ArchiveScreen),
        );
        archive.onToggleBookmark(archive.contents.first);
        await tester.pump();
        await started.future;
        await _openCategory(tester, 202);
        final current = tester.widget<ArchiveScreen>(
          find.byType(ArchiveScreen),
        );
        expect(current.contents, hasLength(20));
        final cursor = current.feed!.nextCursor;
        final filteredCalls = server.feedCalls
            .where(
              (request) => request.url.queryParameters['category_id'] == '202',
            )
            .length;
        metadata.complete(_json(_allCategories));
        await tester.pumpAndSettle();
        final after = tester.widget<ArchiveScreen>(find.byType(ArchiveScreen));
        expect(after.contents, hasLength(20));
        expect(after.feed!.categoryId, 202);
        expect(after.feed!.nextCursor, cursor);
        expect(after.activeCategoryName, '여행');
        expect(
          server.feedCalls.where(
            (request) => request.url.queryParameters['category_id'] == '202',
          ),
          hasLength(filteredCalls),
        );
      });
    },
  );

  testWidgets(
    'deleting an active category clears both home and archive filters',
    (tester) async {
      var deleted = false;
      final server = _Server(
        count: 21,
        respond: (request, server) {
          if (request.method == 'DELETE' &&
              request.url.path == '/api/v1/categories/202') {
            deleted = true;
            for (final record in server.records) {
              final remaining = (record['categories'] as List)
                  .where((category) => (category as Map)['id'] != 202)
                  .toList();
              record['categories'] = remaining.isEmpty
                  ? [_uncategorized]
                  : remaining;
            }
            return http.Response('', 204);
          }
          if (request.url.path == '/api/v1/categories' && deleted) {
            return _json([_category, _uncategorized]);
          }
          return null;
        },
      );
      server.records.last['categories'] = [_otherCategory];
      await _withApp(tester, server, () async {
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        home.onCategorySelected!(
          home.categories.singleWhere((category) => category.id == 202),
        );
        await tester.pumpAndSettle();
        await _openArchive(tester);
        final archive = tester.widget<ArchiveScreen>(
          find.byType(ArchiveScreen),
        );
        expect(archive.feed!.categoryId, 202);
        archive.onDeleteCategory(
          archive.categories.singleWhere((category) => category.id == 202),
        );
        await tester.pumpAndSettle();
        final after = tester.widget<ArchiveScreen>(find.byType(ArchiveScreen));
        expect(after.feed!.categoryId, isNull);
        expect(after.activeCategoryName, isNull);
        expect(after.contents, hasLength(20));
        expect(after.categories.any((category) => category.id == 202), isFalse);
        await _scrollArchiveToEnd(tester);
        expect(_archiveItems(tester).last.title, '피드 항목 21');
        expect(_archiveItems(tester).last.category.id, 303);
        tester
            .widget<ArchiveScreen>(find.byType(ArchiveScreen))
            .onTab(AppRoute.home);
        await tester.pumpAndSettle();
        final currentHome = tester.widget<HomeScreen>(find.byType(HomeScreen));
        expect(currentHome.activeCategoryId, isNull);
        expect(currentHome.feed!.categoryId, isNull);
        expect(currentHome.contents, hasLength(20));
        expect(
          currentHome.categories.any((category) => category.id == 202),
          isFalse,
        );
        expect(find.text('콘텐츠가 없어요'), findsNothing);
      });
    },
  );

  testWidgets(
    'late detail GET cannot undo a successful favorite write and feed refresh',
    (tester) async {
      final detailResponse = Completer<http.Response>();
      final started = Completer<void>();
      addTearDown(() => _release(detailResponse));
      http.Response? oldResponse;
      final server = _Server(
        count: 21,
        respond: (request, server) {
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/contents/21') {
            oldResponse = _json(server.records.first);
            started.complete();
            return detailResponse.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
        home.onOpenContent(home.contents.first);
        await tester.pump();
        await started.future;
        final detail = tester.widget<DetailScreen>(find.byType(DetailScreen));
        detail.onToggleBookmark(detail.content);
        await tester.pumpAndSettle();
        final updated = tester.widget<DetailScreen>(find.byType(DetailScreen));
        expect(updated.bookmarked, isTrue);
        expect(updated.content.bookmarked, isTrue);
        detailResponse.complete(oldResponse!);
        await tester.pumpAndSettle();
        final after = tester.widget<DetailScreen>(find.byType(DetailScreen));
        expect(after.bookmarked, isTrue);
        expect(after.content.bookmarked, isTrue);
        expect(
          after.contents
              .singleWhere((content) => content.apiId == 21)
              .bookmarked,
          isTrue,
        );
        expect(server.calls('/api/v1/contents/21'), hasLength(1));
      });
    },
  );
}
