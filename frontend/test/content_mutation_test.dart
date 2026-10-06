import 'dart:async';
import 'dart:convert';

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
  _Server({this.count = 3, this.respond});

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

Future<void> _detail(WidgetTester tester, {int index = 0}) async {
  final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
  home.onOpenContent(home.contents[index]);
  await tester.pumpAndSettle();
}

DetailScreen _currentDetail(WidgetTester tester) =>
    tester.widget<DetailScreen>(find.byType(DetailScreen));

List<http.Request> _mutations(_Server server) => server.requests
    .where((request) => request.method == 'PUT' || request.method == 'DELETE')
    .toList();

void _change(DetailScreen detail, String action, {ContentItem? target}) {
  final content = target ?? detail.content;
  switch (action) {
    case 'favorite':
      detail.onToggleBookmark(content);
    case 'category':
      detail.onChangeCategory(
        content,
        detail.categories.singleWhere((category) => category.id == 202),
      );
    case 'delete':
      detail.onDeleteContent(content);
  }
}

http.Response _failure(String kind) => switch (kind) {
  'network' => throw http.ClientException('Offline'),
  'JSON' => http.Response('{broken', 200),
  _ => _json({'detail': '변경 실패 $kind'}, int.parse(kind)),
};

Future<void> _archive(WidgetTester tester) async {
  tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenArchive();
  await tester.pumpAndSettle();
}

ArchiveScreen _currentArchive(WidgetTester tester) =>
    tester.widget<ArchiveScreen>(find.byType(ArchiveScreen));

Future<void> _search(WidgetTester tester, String query) async {
  if (find.byType(SearchScreen).evaluate().isEmpty) {
    tester.widget<HomeScreen>(find.byType(HomeScreen)).onSearch();
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _loadMore(WidgetTester tester) async {
  final screen = _currentArchive(tester);
  unawaited(screen.onLoadMore!());
  await tester.pump();
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

  testWidgets('category 503 restores the selected detail as well as its feed', (
    tester,
  ) async {
    final server = _Server(
      respond: (request, _) =>
          request.method == 'PUT' ? _json({'detail': '분류 변경 거절'}, 503) : null,
    );
    await _withApp(tester, server, () async {
      await _detail(tester);
      final detail = _currentDetail(tester);
      detail.onChangeCategory(
        detail.content,
        detail.categories.singleWhere((category) => category.id == 202),
      );
      await tester.pumpAndSettle();
      final after = _currentDetail(tester);
      expect(after.content.category.id, 101);
      expect(
        after.contents
            .singleWhere((item) => item.id == after.content.id)
            .category
            .id,
        101,
      );
      expect(find.text('분류 변경 거절'), findsOneWidget);
    });
  });

  testWidgets(
    'pending favorite updates the model and displayed favorite together',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.method == 'PUT' ? pending.future : null,
      );
      await _withApp(tester, server, () async {
        await _detail(tester);
        final detail = _currentDetail(tester);
        detail.onToggleBookmark(detail.content);
        await tester.pump();
        final during = _currentDetail(tester);
        final model = during.content.bookmarked;
        final rows = during.contents
            .singleWhere((item) => item.id == detail.content.id)
            .bookmarked;
        final displayed = during.bookmarked;
        pending.complete(null);
        await tester.pumpAndSettle();
        expect(displayed, isTrue);
        expect(model, isTrue);
        expect(rows, isTrue);
      });
    },
  );

  testWidgets(
    'one content rejects duplicate and cross-action writes while pending',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.method == 'PUT' || request.method == 'DELETE'
            ? pending.future
            : null,
      );
      await _withApp(tester, server, () async {
        await _detail(tester);
        final detail = _currentDetail(tester);
        detail.onToggleBookmark(detail.content);
        detail.onToggleBookmark(detail.content);
        detail.onChangeCategory(
          detail.content,
          detail.categories.singleWhere((category) => category.id == 202),
        );
        detail.onDeleteContent(detail.content);
        await tester.pump();
        final calls = _mutations(server).length;
        pending.complete(_json({'detail': '변경 거절'}, 503));
        await tester.pumpAndSettle();
        expect(calls, 1);
      });
    },
  );

  testWidgets('delete keeps the open detail and list until failure is known', (
    tester,
  ) async {
    final pending = Completer<http.Response?>();
    final server = _Server(
      respond: (request, _) =>
          request.method == 'DELETE' ? pending.future : null,
    );
    await _withApp(tester, server, () async {
      await _detail(tester);
      final detail = _currentDetail(tester);
      detail.onDeleteContent(detail.content);
      await tester.pump();
      final remained = find.byType(DetailScreen).evaluate().isNotEmpty;
      final retained =
          remained &&
          _currentDetail(
            tester,
          ).contents.any((item) => item.id == detail.content.id);
      pending.complete(_json({'detail': '삭제 거절'}, 503));
      await tester.pumpAndSettle();
      expect(remained, isTrue);
      expect(retained, isTrue);
      expect(_currentDetail(tester).content.id, detail.content.id);
      expect(find.text('삭제 거절'), findsOneWidget);
    });
  });

  for (final action in ['favorite', 'category', 'delete']) {
    for (final failure in ['401', '403', '404', '503', 'network', 'JSON']) {
      testWidgets(
        '$action $failure preserves the account and restores state before unlocking',
        (tester) async {
          var fails = true;
          final server = _Server(
            respond: (request, _) {
              if ((request.method == 'PUT' || request.method == 'DELETE') &&
                  fails) {
                return _failure(failure);
              }
              return null;
            },
          );
          await _withApp(tester, server, () async {
            await _detail(tester);
            final before = _currentDetail(tester);
            _change(before, action);
            await tester.pumpAndSettle();
            final after = _currentDetail(tester);
            expect(after.content.id, before.content.id);
            expect(after.content.category.id, 101);
            expect(after.content.bookmarked, isFalse);
            expect(after.bookmarked, isFalse);
            expect(
              after.contents.any((item) => item.id == before.content.id),
              isTrue,
            );
            expect(
              after.contents
                  .singleWhere((item) => item.id == before.content.id)
                  .category
                  .id,
              101,
            );
            expect(find.byType(SnackBar), findsOneWidget);
            expect(tester.takeException(), isNull);
            expect(server.calls('/api/v1/auth/guest'), isEmpty);
            final attempts = _mutations(server).length;
            expect(attempts, failure == '401' ? 2 : 1);
            fails = false;
            _change(after, action);
            await tester.pumpAndSettle();
            expect(_mutations(server), hasLength(attempts + 1));
            if (action == 'delete') {
              expect(find.byType(DetailScreen), findsNothing);
              expect(
                tester
                    .widget<HomeScreen>(find.byType(HomeScreen))
                    .contents
                    .any((item) => item.id == before.content.id),
                isFalse,
              );
            } else {
              final saved = _currentDetail(tester);
              expect(
                saved.content.category.id,
                action == 'category' ? 202 : 101,
              );
              expect(saved.content.bookmarked, action == 'favorite');
            }
          });
        },
      );
    }
  }

  for (final action in ['category', 'delete']) {
    testWidgets(
      'pending $action blocks all writes for its ID but allows another content',
      (tester) async {
        final pending = Completer<http.Response?>();
        final server = _Server(
          respond: (request, _) {
            if (request.url.path.startsWith('/api/v1/contents/3') &&
                (request.method == 'PUT' || request.method == 'DELETE')) {
              return pending.future;
            }
            return null;
          },
        );
        await _withApp(tester, server, () async {
          await _detail(tester);
          final before = _currentDetail(tester);
          _change(before, action);
          for (final blocked in ['favorite', 'category', 'delete']) {
            _change(before, blocked);
          }
          _change(before, 'favorite', target: before.contents[1]);
          await tester.pumpAndSettle();
          final calls = _mutations(server).toList();
          final model = _currentDetail(tester);
          expect(
            calls.where(
              (request) => request.url.path.startsWith('/api/v1/contents/3'),
            ),
            hasLength(1),
          );
          expect(
            calls.where(
              (request) => request.url.path.startsWith('/api/v1/contents/2'),
            ),
            hasLength(1),
          );
          expect(
            model.contents.singleWhere((item) => item.apiId == 2).bookmarked,
            isTrue,
          );
          pending.complete(_json({'detail': '변경 거절'}, 503));
          await tester.pumpAndSettle();
          expect(_currentDetail(tester).content.category.id, 101);
          expect(_currentDetail(tester).content.bookmarked, isFalse);
        });
      },
    );
  }

  for (final action in ['favorite', 'category']) {
    for (final outcome in ['success', 'failure']) {
      testWidgets(
        'late detail read cannot replace a pending $action before $outcome',
        (tester) async {
          final read = Completer<http.Response?>();
          final write = Completer<http.Response?>();
          http.Response? stale;
          final server = _Server(
            respond: (request, server) {
              if (request.url.path == '/api/v1/contents/3' &&
                  request.method == 'GET') {
                stale = _json(server.records.first);
                return read.future;
              }
              if (request.method == 'PUT') return write.future;
              return null;
            },
          );
          await _withApp(tester, server, () async {
            await _detail(tester);
            _change(_currentDetail(tester), action);
            await tester.pump();
            read.complete(stale!);
            await tester.pumpAndSettle();
            final during = _currentDetail(tester);
            expect(during.content.bookmarked, action == 'favorite');
            expect(during.bookmarked, action == 'favorite');
            expect(
              during.content.category.id,
              action == 'category' ? 202 : 101,
            );
            write.complete(
              outcome == 'success' ? null : _json({'detail': '변경 거절'}, 503),
            );
            await tester.pumpAndSettle();
            final after = _currentDetail(tester);
            expect(
              after.content.bookmarked,
              action == 'favorite' && outcome == 'success',
            );
            expect(
              after.content.category.id,
              action == 'category' && outcome == 'success' ? 202 : 101,
            );
          });
        },
      );
    }
  }

  testWidgets(
    'a stale additional page preserves the pending favorite and opaque cursor',
    (tester) async {
      final read = Completer<http.Response?>();
      final write = Completer<http.Response?>();
      http.Response? stale;
      String? expectedCursor;
      final server = _Server(
        count: 45,
        respond: (request, server) {
          if (request.url.path == _feed &&
              request.url.queryParameters['cursor'] != null) {
            final body = jsonDecode(server.page(request).body) as Map;
            expectedCursor = body['next_cursor'] as String?;
            stale = _json({
              ...body,
              'items': [server.records.first, ...(body['items'] as List)],
            });
            return read.future;
          }
          if (request.method == 'PUT') return write.future;
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _archive(tester);
        await _loadMore(tester);
        final before = _currentArchive(tester);
        before.onToggleBookmark(before.contents.first);
        await tester.pump();
        read.complete(stale!);
        await tester.pumpAndSettle();
        final during = _currentArchive(tester);
        expect(during.contents, hasLength(40));
        expect(during.contents.first.bookmarked, isTrue);
        expect(during.bookmarkedIds, contains(during.contents.first.id));
        expect(during.feed!.nextCursor, expectedCursor);
        expect(during.contents.map((item) => item.id).toSet(), hasLength(40));
        write.complete(_json({'detail': '북마크 거절'}, 503));
        await tester.pumpAndSettle();
        expect(_currentArchive(tester).contents.first.bookmarked, isFalse);
        expect(_currentArchive(tester).feed!.nextCursor, expectedCursor);
      });
    },
  );

  testWidgets(
    'another successful write reloads pages without losing pending category or its rollback',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.url.path == '/api/v1/contents/3/categories'
            ? pending.future
            : null,
      );
      await _withApp(tester, server, () async {
        await _detail(tester);
        final detail = _currentDetail(tester);
        _change(detail, 'category');
        _change(detail, 'favorite', target: detail.contents[1]);
        await tester.pumpAndSettle();
        final during = _currentDetail(tester);
        expect(during.content.category.id, 202);
        expect(
          during.contents.singleWhere((item) => item.apiId == 3).category.id,
          202,
        );
        expect(
          during.contents.singleWhere((item) => item.apiId == 2).bookmarked,
          isTrue,
        );
        pending.complete(_json({'detail': '분류 거절'}, 503));
        await tester.pumpAndSettle();
        final after = _currentDetail(tester);
        expect(after.content.category.id, 101);
        expect(
          after.contents.singleWhere((item) => item.apiId == 3).category.id,
          101,
        );
        expect(
          after.contents.singleWhere((item) => item.apiId == 2).bookmarked,
          isTrue,
        );
      });
    },
  );

  for (final outcome in ['success', 'failure']) {
    testWidgets(
      'deletion $outcome cannot move a different detail opened while waiting',
      (tester) async {
        final pending = Completer<http.Response?>();
        final server = _Server(
          respond: (request, _) =>
              request.method == 'DELETE' ? pending.future : null,
        );
        await _withApp(tester, server, () async {
          await _detail(tester);
          final detail = _currentDetail(tester);
          final other = detail.contents[1];
          detail.onDeleteContent(detail.content);
          detail.onOpenContent(other);
          await tester.pumpAndSettle();
          pending.complete(
            outcome == 'success' ? null : _json({'detail': '삭제 거절'}, 503),
          );
          await tester.pumpAndSettle();
          expect(_currentDetail(tester).content.id, other.id);
          expect(
            _currentDetail(
              tester,
            ).contents.any((item) => item.id == detail.content.id),
            outcome == 'failure',
          );
        });
      },
    );
  }

  for (final action in ['favorite', 'category', 'delete']) {
    testWidgets(
      'successful $action remains committed when first-page reload fails',
      (tester) async {
        var mutated = false;
        final server = _Server(
          respond: (request, _) {
            if (request.method == 'PUT' || request.method == 'DELETE') {
              mutated = true;
            }
            if (mutated && request.url.path == _feed) {
              return _json({'detail': '조회만 실패'}, 503);
            }
            return null;
          },
        );
        await _withApp(tester, server, () async {
          await _detail(tester);
          final before = _currentDetail(tester);
          _change(before, action);
          await tester.pumpAndSettle();
          expect(_mutations(server), hasLength(1));
          expect(find.byType(SnackBar), findsNothing);
          if (action == 'delete') {
            expect(find.byType(DetailScreen), findsNothing);
            expect(server.records.any((item) => item['id'] == 3), isFalse);
          } else {
            final after = _currentDetail(tester);
            expect(after.content.category.id, action == 'category' ? 202 : 101);
            expect(after.content.bookmarked, action == 'favorite');
            expect(after.feed!.error, isNotNull);
          }
        });
      },
    );
  }

  for (final action in ['favorite', 'category']) {
    testWidgets(
      '$action preserves screenshot assets and summary status on success and failure',
      (tester) async {
        var fail = false;
        final server = _Server(
          respond: (request, _) => request.method == 'PUT' && fail
              ? _json({'detail': '변경 거절'}, 503)
              : null,
        );
        server.records.first.addAll({
          'content_type': 'screenshot',
          'source': 'screenshot',
          'original_url': null,
          'summary_status': 'queued',
          'assets': [
            {
              'id': 9,
              'asset_type': 'screenshot',
              'download_url': '/api/v1/uploads/assets/9',
              'mime_type': 'image/png',
            },
          ],
        });
        await _withApp(tester, server, () async {
          await _detail(tester);
          _change(_currentDetail(tester), action);
          await tester.pumpAndSettle();
          final saved = _currentDetail(tester).content;
          fail = true;
          if (action == 'category') {
            final detail = _currentDetail(tester);
            detail.onChangeCategory(
              detail.content,
              detail.categories.singleWhere((category) => category.id == 101),
            );
          } else {
            _change(_currentDetail(tester), action);
          }
          await tester.pumpAndSettle();
          final after = _currentDetail(tester).content;
          expect(after.category.id, saved.category.id);
          expect(after.bookmarked, saved.bookmarked);
          expect(after.assets.single.id, 9);
          expect(after.assets.single.mimeType, 'image/png');
          expect(after.summaryStatus, 'queued');
          expect(after.isScreenshot, isTrue);
          expect(server.calls('/api/v1/uploads/assets/9'), isEmpty);
        });
      },
    );
  }

  for (final action in ['favorite', 'category', 'delete']) {
    for (final outcome in ['success', 'failure']) {
      testWidgets(
        'old-account $action $outcome cannot alter the new guest or show its error',
        (tester) async {
          final pending = Completer<http.Response?>();
          final server = _Server(
            respond: (request, _) =>
                request.method == 'PUT' || request.method == 'DELETE'
                ? pending.future
                : null,
          );
          await _withApp(tester, server, () async {
            await _detail(tester);
            final detail = _currentDetail(tester);
            final oldResponse = _json(server.records.first);
            _change(detail, action);
            await tester.pump();
            detail.onTab(AppRoute.my);
            await tester.pumpAndSettle();
            tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
            await tester.pumpAndSettle();
            unawaited(
              tester
                  .widget<AccountManagementScreen>(
                    find.byType(AccountManagementScreen),
                  )
                  .onLogout(),
            );
            await tester.pumpAndSettle();
            server.records.clear();
            unawaited(
              tester
                  .widget<HomeScreen>(find.byType(HomeScreen))
                  .onAddLink(url: 'https://example.com/new-account'),
            );
            await tester.pumpAndSettle();
            expect(_currentDetail(tester).content.apiId, 1001);
            pending.complete(
              outcome == 'success'
                  ? (action == 'delete' ? http.Response('', 204) : oldResponse)
                  : _json({'detail': '이전 계정 오류'}, 503),
            );
            await tester.pumpAndSettle();
            expect(_currentDetail(tester).content.apiId, 1001);
            expect(_currentDetail(tester).content.category.id, 101);
            expect(_currentDetail(tester).content.bookmarked, isFalse);
            expect(find.text('이전 계정 오류'), findsNothing);
            expect(server.calls('/api/v1/auth/guest'), hasLength(1));
            expect(tester.takeException(), isNull);
          });
        },
      );
    }
  }

  for (final action in ['favorite', 'category', 'delete']) {
    testWidgets(
      'failed $action after a new search cannot insert the old result',
      (tester) async {
        final pending = Completer<http.Response?>();
        final server = _Server(
          respond: (request, _) =>
              request.method == 'PUT' || request.method == 'DELETE'
              ? pending.future
              : null,
        );
        await _withApp(tester, server, () async {
          await _search(tester, '항목 1');
          final search = tester.widget<SearchScreen>(find.byType(SearchScreen));
          final target = search.contents.single;
          switch (action) {
            case 'favorite':
              search.onToggleBookmark(target);
            case 'category':
              search.onChangeContentCategory(
                target,
                search.categories.singleWhere((category) => category.id == 202),
              );
            case 'delete':
              search.onDeleteContent(target);
          }
          await tester.pump();
          await _search(tester, '항목 2');
          pending.complete(_json({'detail': '이전 검색 변경 거절'}, 503));
          await tester.pumpAndSettle();
          final after = tester.widget<SearchScreen>(find.byType(SearchScreen));
          expect(after.contents.map((item) => item.apiId), [2]);
          expect(after.feed!.query, '항목 2');
          expect(after.contents.single.category.id, 101);
          expect(after.contents.single.bookmarked, isFalse);
        });
      },
    );
  }

  testWidgets(
    'a category rollback stays protected while a later favorite waits for an older page',
    (tester) async {
      final category = Completer<http.Response?>();
      final favorite = Completer<http.Response?>();
      final read = Completer<http.Response?>();
      var holdFeed = false;
      var feedHeld = false;
      http.Response? oldPage;
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == '/api/v1/contents/3/categories') {
            return category.future;
          }
          if (request.url.path == '/api/v1/contents/3/favorite') {
            return favorite.future;
          }
          if (holdFeed && !feedHeld && request.url.path == _feed) {
            feedHeld = true;
            // A request may observe a write that later reports a connection failure.
            oldPage = _json({
              'items': [
                {
                  ...server.records.first,
                  'categories': [_otherCategory],
                },
                ...server.records.skip(1),
              ],
              'next_cursor': null,
            });
            return read.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _detail(tester);
        final before = _currentDetail(tester);
        _change(before, 'category');
        await tester.pump();
        holdFeed = true;
        before.onTab(AppRoute.archive);
        await tester.pump();
        expect(feedHeld, isTrue);
        category.completeError(http.ClientException('Response lost'));
        await tester.pump();
        await tester.pump();
        _change(before, 'favorite');
        await tester.pump();
        read.complete(oldPage!);
        await tester.pumpAndSettle();
        final during = _currentArchive(
          tester,
        ).contents.singleWhere((item) => item.apiId == 3);
        expect(during.category.id, 101);
        expect(during.bookmarked, isTrue);
        favorite.complete(null);
        await tester.pumpAndSettle();
        final after = _currentArchive(
          tester,
        ).contents.singleWhere((item) => item.apiId == 3);
        expect(after.category.id, 101);
        expect(after.bookmarked, isTrue);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'successful write keeps its lock until reload finishes then permits another field',
    (tester) async {
      final metadata = Completer<http.Response?>();
      var reads = 0;
      final server = _Server(
        respond: (request, _) {
          if (request.url.path == '/api/v1/categories' && ++reads == 2) {
            return metadata.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _detail(tester);
        final before = _currentDetail(tester);
        _change(before, 'favorite');
        await tester.pump();
        final pending = _currentDetail(tester);
        expect(pending.content.bookmarked, isTrue);
        expect(pending.content.mutationLabel, isNotNull);
        _change(pending, 'category');
        _change(pending, 'delete');
        await tester.pump();
        expect(_mutations(server), hasLength(1));
        metadata.complete(null);
        await tester.pumpAndSettle();
        final complete = _currentDetail(tester);
        expect(complete.content.mutationLabel, isNull);
        _change(complete, 'category');
        await tester.pumpAndSettle();
        final after = _currentDetail(tester);
        expect(_mutations(server), hasLength(2));
        expect(after.content.bookmarked, isTrue);
        expect(after.content.category.id, 202);
        expect(after.content.mutationLabel, isNull);
        expect(server.calls('/api/v1/contents/3/view'), hasLength(1));
        expect(server.calls('/api/v1/metrics/events'), hasLength(1));
      });
    },
  );

  for (final action in ['favorite', 'category', 'delete']) {
    testWidgets(
      'pending $action visibly disables detail write controls without disabling back',
      (tester) async {
        final pending = Completer<http.Response?>();
        final server = _Server(
          respond: (request, _) =>
              request.method == 'PUT' || request.method == 'DELETE'
              ? pending.future
              : null,
        );
        await _withApp(tester, server, () async {
          await _detail(tester);
          _change(_currentDetail(tester), action);
          await tester.pump();
          final top = find.byType(DetailTopBar);
          final bookmark = tester.widget<BookmarkActionButton>(
            find.descendant(
              of: top,
              matching: find.byType(BookmarkActionButton),
            ),
          );
          final icons = tester
              .widgetList<SvgIconButton>(
                find.descendant(of: top, matching: find.byType(SvgIconButton)),
              )
              .toList();
          expect(bookmark.enabled, isFalse);
          expect(
            icons.singleWhere((button) => button.asset == Assets.more).enabled,
            isFalse,
          );
          expect(
            icons.singleWhere((button) => button.asset == Assets.back).enabled,
            isTrue,
          );
          expect(
            _currentDetail(tester).content.mutationLabel,
            action == 'delete' ? '삭제 중…' : '변경 중…',
          );
          pending.complete(_json({'detail': '변경 거절'}, 503));
          await tester.pumpAndSettle();
          expect(_currentDetail(tester).content.mutationLabel, isNull);
          expect(
            tester
                .widget<BookmarkActionButton>(
                  find.descendant(
                    of: find.byType(DetailTopBar),
                    matching: find.byType(BookmarkActionButton),
                  ),
                )
                .enabled,
            isTrue,
          );
        });
      },
    );
  }

  for (final action in ['favorite', 'category', 'delete']) {
    testWidgets(
      'successful search $action reloads the same query from its first page',
      (tester) async {
        final server = _Server(count: 25);
        await _withApp(tester, server, () async {
          await _search(tester, '피드 항목');
          var search = tester.widget<SearchScreen>(find.byType(SearchScreen));
          await search.onLoadMore!();
          await tester.pumpAndSettle();
          search = tester.widget<SearchScreen>(find.byType(SearchScreen));
          expect(search.contents, hasLength(25));
          final target = search.contents.last;
          final requestCount = server.feedCalls.length;
          switch (action) {
            case 'favorite':
              search.onToggleBookmark(target);
            case 'category':
              search.onChangeContentCategory(
                target,
                search.categories.singleWhere((category) => category.id == 202),
              );
            case 'delete':
              search.onDeleteContent(target);
          }
          await tester.pumpAndSettle();
          final after = tester.widget<SearchScreen>(find.byType(SearchScreen));
          expect(after.feed!.query, '피드 항목');
          expect(after.contents, hasLength(20));
          final reload = server.feedCalls
              .skip(requestCount)
              .where((request) => request.url.queryParameters['q'] != null)
              .single;
          expect(reload.url.queryParameters['q'], '피드 항목');
          expect(reload.url.queryParameters['cursor'], isNull);
          expect(_mutations(server), hasLength(1));
          expect(server.calls('/api/v1/metrics/events'), isEmpty);
        });
      },
    );
  }

  testWidgets(
    'a stale callback uses the latest category while another write reloads metadata',
    (tester) async {
      final metadata = Completer<http.Response?>();
      var categoryReads = 0;
      var categoryWrites = 0;
      final server = _Server(
        respond: (request, _) {
          if (request.url.path == '/api/v1/categories' &&
              ++categoryReads == 3) {
            return metadata.future;
          }
          if (request.url.path == '/api/v1/contents/2/categories' &&
              ++categoryWrites == 2) {
            return _json({'detail': '두 번째 분류 변경 거절'}, 503);
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _archive(tester);
        final old = _currentArchive(tester);
        final oldB = old.contents.singleWhere((item) => item.apiId == 2);
        old.onChangeContentCategory(
          oldB,
          old.categories.singleWhere((category) => category.id == 202),
        );
        await tester.pumpAndSettle();
        final updated = _currentArchive(tester);
        expect(
          updated.contents.singleWhere((item) => item.apiId == 2).category.id,
          202,
        );
        updated.onToggleBookmark(
          updated.contents.singleWhere((item) => item.apiId == 3),
        );
        await tester.pump();
        expect(categoryReads, 3);
        old.onChangeContentCategory(
          oldB,
          old.categories.singleWhere((category) => category.id == 101),
        );
        await tester.pump();
        await tester.pump();
        final duringCategory = _currentArchive(
          tester,
        ).contents.where((item) => item.apiId == 2).firstOrNull?.category.id;
        metadata.complete(null);
        await tester.pumpAndSettle();
        expect(categoryWrites, 2);
        expect(duringCategory, 202);
        expect(
          _currentArchive(
            tester,
          ).contents.singleWhere((item) => item.apiId == 2).category.id,
          202,
        );
        expect(find.text('두 번째 분류 변경 거절'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'older write statistics cannot replace the count from a newer deletion',
    (tester) async {
      final stats = Completer<http.Response?>();
      var statReads = 0;
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == '/api/v1/users/me/stats') {
            if (++statReads == 2) return stats.future;
            return _json({
              'saved_count': server.records.length,
              'reopened_count': 0,
            });
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _archive(tester);
        final before = _currentArchive(tester);
        before.onToggleBookmark(
          before.contents.singleWhere((item) => item.apiId == 3),
        );
        await tester.pumpAndSettle();
        expect(statReads, 2);
        final current = _currentArchive(tester);
        current.onDeleteContent(
          current.contents.singleWhere((item) => item.apiId == 2),
        );
        await tester.pumpAndSettle();
        expect(statReads, 3);
        _currentArchive(tester).onTab(AppRoute.my);
        await tester.pumpAndSettle();
        expect(
          tester.widget<MyScreen>(find.byType(MyScreen)).user.savedContentCount,
          2,
        );
        stats.complete(_json({'saved_count': 3, 'reopened_count': 0}));
        await tester.pumpAndSettle();
        expect(
          tester.widget<MyScreen>(find.byType(MyScreen)).user.savedContentCount,
          2,
        );
      });
    },
  );

  testWidgets('pending home card fits a long category without overflow', (
    tester,
  ) async {
    const content = ContentItem(
      id: 'card',
      apiId: 3,
      title: '두 줄 제목 첫째 줄\n두 줄 제목 둘째 줄',
      summary: '세 줄 요약 첫째 줄\n세 줄 요약 둘째 줄\n세 줄 요약 셋째 줄',
      category: CategoryItem(
        id: 101,
        name: '아주긴카테고리이름테스트스무글자확인중',
        color: Colors.green,
        tint: Colors.white,
        deep: Colors.green,
      ),
      savedAt: '오늘',
      savedAtFull: '2026.10.06',
      savedAtFullShort: '10.06',
      tags: [],
      source: 'web',
      originalUrl: 'https://example.com/card',
      originalText: '원문',
      mutationLabel: '변경 중…',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Pretendard'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 298,
              height: 186,
              child: HomeContentCard(
                content: content,
                bookmarked: false,
                onTap: () {},
                onToggleBookmark: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final categoryText = tester.widget<Text>(
      find.descendant(
        of: find.byType(CategoryBadge),
        matching: find.byType(Text),
      ),
    );
    expect(categoryText.maxLines, 1);
    expect(categoryText.overflow, TextOverflow.ellipsis);
    expect(find.text('변경 중…'), findsOneWidget);
    expect(tester.getSize(find.byType(HomeContentCard)), const Size(298, 186));
  });

  testWidgets(
    'opening a stale card uses the current pending category before detail GET returns',
    (tester) async {
      final read = Completer<http.Response?>();
      final write = Completer<http.Response?>();
      http.Response? stale;
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == '/api/v1/contents/3' &&
              request.method == 'GET') {
            stale = _json(server.records.first);
            return read.future;
          }
          if (request.method == 'PUT') return write.future;
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _archive(tester);
        final before = _currentArchive(tester);
        final staleCard = before.contents.first;
        before.onChangeContentCategory(
          staleCard,
          before.categories.singleWhere((category) => category.id == 202),
        );
        before.onOpenContent(staleCard);
        await tester.pump();
        final during = _currentDetail(tester);
        expect(during.content.category.id, 202);
        expect(during.content.mutationLabel, '변경 중…');
        final bookmark = tester.widget<BookmarkActionButton>(
          find.descendant(
            of: find.byType(DetailTopBar),
            matching: find.byType(BookmarkActionButton),
          ),
        );
        expect(bookmark.enabled, isFalse);
        read.complete(stale!);
        await tester.pumpAndSettle();
        expect(_currentDetail(tester).content.category.id, 202);
        expect(_currentDetail(tester).content.mutationLabel, '변경 중…');
        write.complete(_json({'detail': '변경 거절'}, 503));
        await tester.pumpAndSettle();
        expect(_currentDetail(tester).content.category.id, 101);
        expect(_currentDetail(tester).content.mutationLabel, isNull);
        expect(server.calls('/api/v1/contents/3/view'), hasLength(1));
      });
    },
  );

  testWidgets(
    'returning from search detail preserves its loaded page and does not refocus the query',
    (tester) async {
      final server = _Server(count: 45);
      await _withApp(tester, server, () async {
        tester.widget<HomeScreen>(find.byType(HomeScreen)).onSearch();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
        await _search(tester, '피드 항목');
        var search = tester.widget<SearchScreen>(find.byType(SearchScreen));
        await search.onLoadMore!();
        await tester.pumpAndSettle();
        search = tester.widget<SearchScreen>(find.byType(SearchScreen));
        await search.onLoadMore!();
        await tester.pumpAndSettle();
        search = tester.widget<SearchScreen>(find.byType(SearchScreen));
        expect(search.contents, hasLength(45));
        ScrollPosition resultPosition() => tester
            .stateList<ScrollableState>(
              find.descendant(
                of: find.byType(SearchScreen),
                matching: find.byType(Scrollable),
              ),
            )
            .singleWhere((state) => state.position.axis == Axis.vertical)
            .position;
        final beforePosition = resultPosition();
        beforePosition.jumpTo(beforePosition.maxScrollExtent * .7);
        await tester.pumpAndSettle();
        final offset = resultPosition().pixels;
        final queryCalls = server.feedCalls.length;
        expect(offset, greaterThan(1000));
        search.onOpenContent(search.contents[30]);
        await tester.pumpAndSettle();
        _currentDetail(tester).onBack();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        final restored = tester.widget<SearchScreen>(find.byType(SearchScreen));
        expect(restored.contents, hasLength(45));
        expect(restored.feed!.query, '피드 항목');
        expect(resultPosition().pixels, closeTo(offset, 1));
        expect(server.feedCalls, hasLength(queryCalls));
        final input = tester.widget<EditableText>(find.byType(EditableText));
        expect(input.controller.text, '피드 항목');
        expect(
          input.focusNode.hasFocus,
          isFalse,
          reason:
              'Returning to loaded results must not focus the browser input and scroll it into view.',
        );
      });
    },
  );
}
