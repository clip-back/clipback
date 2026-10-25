import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_startup.dart';
import 'auth_navigation.dart';

const _categories = '/api/v1/categories';
const _refresh = '/api/v1/auth/refresh';
const _category = {
  'id': 101,
  'name': '공부',
  'color': '#059669',
  'is_default': false,
  'content_count': 0,
  'last_saved_at': null,
};
const _savedMessage = '저장은 완료됐지만 카테고리 목록을 새로 불러오지 못했어요';

http.Response _json(Object? value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response _tokens(String prefix) => _json({
  'access_token': '$prefix-access',
  'refresh_token': '$prefix-refresh',
  'expires_in': 3600,
  'refresh_expires_in': 86400,
});

class _Storage extends ApiSessionStorage {
  ApiSession? session = const ApiSession(
    accessToken: 'test-access',
    refreshToken: 'test-refresh',
    expiresIn: 3600,
    refreshExpiresIn: 86400,
  );
  int writes = 0, clears = 0;
  @override
  Future<ApiSession?> read() async => session;
  @override
  Future<void> write(ApiSession value) async {
    writes++;
    session = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    session = null;
  }
}

class _Server {
  _Server({this.respond});
  final FutureOr<http.Response?> Function(http.Request, _Server)? respond;
  final requests = <http.Request>[];
  final categories = <Map<String, Object?>>[
    {..._category},
  ];
  var userId = 1;
  late final client = MockClient((request) async {
    requests.add(request);
    final response = await respond?.call(request, this);
    if (response != null) return response;
    switch (request.url.path) {
      case _categories:
        if (request.method == 'POST') {
          final created = {
            'id': 403 + calls(_categories, 'POST').length,
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'is_default': false,
            'content_count': 0,
            'last_saved_at': null,
          };
          categories.add(created);
          return _json({
            ...created,
            'submission': {
              'key': request.headers['Idempotency-Key'],
              'status': 'succeeded',
              'replayed': false,
            },
          }, 201);
        }
        return _json(categories);
      case '/api/v1/feed':
        return _json({'items': <Object>[], 'next_cursor': null});
      case '/api/v1/users/me':
        return _json({
          'id': userId,
          'email': null,
          'display_name': '테스트 계정',
          'is_guest': true,
          'created_at': '2026-10-25T00:00:00Z',
          'linked_providers': <String>[],
        });
      case '/api/v1/users/me/stats':
        return _json({'saved_count': 7, 'reopened_count': 3});
      case _refresh:
        return _tokens('rotated');
      case '/api/v1/auth/logout':
        return http.Response('', 204);
      case '/api/v1/auth/guest':
        userId++;
        categories
          ..clear()
          ..add({..._category, 'id': 707, 'name': '새 계정 목록'});
        return _tokens('guest');
      case '/api/v1/recommendations/weekly':
        return _json({
          'period_start': '2026-10-19T00:00:00Z',
          'period_end': '2026-10-26T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        });
      default:
        if (request.method == 'PATCH' &&
            request.url.path == '$_categories/101') {
          categories[0] = {
            ...categories[0],
            ...jsonDecode(request.body) as Map<String, dynamic>,
          };
          return _json(categories[0]);
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
    }
  });
  List<http.Request> calls(String path, [String? method]) => requests
      .where(
        (r) => r.url.path == path && (method == null || r.method == method),
      )
      .toList();
}

ArchiveScreen _archive(WidgetTester tester) =>
    tester.widget<ArchiveScreen>(find.byType(ArchiveScreen));

Future<void> _withApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function(_Storage storage) check,
) async {
  SharedPreferences.setMockInitialValues({});
  final storage = _Storage();
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(ClipbackApp(sessionStorage: storage));
      await completeAppStartup(tester);
      await check(storage);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _create(WidgetTester tester, [String name = '취업 준비']) async {
  if (find.byType(HomeScreen).evaluate().isNotEmpty) {
    tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenArchive();
    await tester.pumpAndSettle();
    _archive(tester).onTabChanged(1);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const ValueKey('archive-category-add')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('category-form-input')),
    name,
  );
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
  await tester.pumpAndSettle();
}

Future<void> _advanceTo(
  WidgetTester tester,
  DateTime start,
  Duration elapsed,
) async {
  final remaining = start.add(elapsed).difference(tester.binding.clock.now());
  if (remaining > Duration.zero) await tester.pump(remaining);
  await tester.pump();
}

Future<void> _newAccount(WidgetTester tester) async {
  _archive(tester).onTab(AppRoute.my);
  await tester.pumpAndSettle();
  tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
  await tester.pumpAndSettle();
  await startLogoutFromAccount(tester);
  await tester.pumpAndSettle();
  await startGuestAndFinishOnboarding(tester);
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
  testWidgets('저장 성공 뒤 목록 실패는 마지막 목록과 닫힌 시트를 유지하고 GET만 재시도한다', (tester) async {
    var failed = true;
    final server = _Server(
      respond: (request, server) {
        if (request.url.path == _categories &&
            request.method == 'GET' &&
            server.calls(_categories, 'POST').isNotEmpty &&
            failed) {
          return _json({'detail': 'Offline'}, 503);
        }
        return null;
      },
    );
    await _withApp(tester, server, (_) async {
      await _create(tester);
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(_archive(tester).categories.map((c) => c.name), contains('공부'));
      expect(find.text(_savedMessage), findsOneWidget);
      final start = server.requests.length;
      failed = false;
      server.categories[0] = {..._category, 'name': '최신 공부'};
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(_archive(tester).categories.map((c) => c.name), contains('최신 공부'));
      expect(
        server.requests.skip(start).map((r) => '${r.method} ${r.url.path}'),
        ['GET $_categories'],
      );
      expect(server.calls(_categories, 'POST'), hasLength(1));
      expect(find.byType(CategoryFormSheet), findsNothing);
    });
  });
  for (final malformed in <String, Object?>{
    'empty HTTP body': '',
    'JSON null': 'null',
    'missing count': jsonEncode([
      Map<String, Object?>.of(_category)..remove('content_count'),
    ]),
    'missing timestamp': jsonEncode([
      Map<String, Object?>.of(_category)..remove('last_saved_at'),
    ]),
    'object': '{}',
    'invalid JSON': '{broken',
    'null item': '[null]',
    'missing name': jsonEncode([
      Map<String, Object?>.of(_category)..remove('name'),
    ]),
    'invalid identifier': jsonEncode([
      {..._category, 'id': 0},
    ]),
    'null default flag': jsonEncode([
      {..._category, 'is_default': null},
    ]),
    'invalid timestamp': jsonEncode([
      {..._category, 'last_saved_at': 42},
    ]),
    'null count': jsonEncode([
      {..._category, 'content_count': null},
    ]),
    'negative count': jsonEncode([
      {..._category, 'content_count': -1},
    ]),
    'invalid color': jsonEncode([
      {..._category, 'color': 42},
    ]),
  }.entries) {
    testWidgets('${malformed.key} 목록 응답은 마지막 목록을 유지하고 정상 빈 배열은 반영한다', (
      tester,
    ) async {
      var broken = true;
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == _categories &&
              request.method == 'GET' &&
              server.calls(_categories, 'POST').isNotEmpty) {
            return broken
                ? http.Response(
                    malformed.value as String,
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  )
                : _json([]);
          }
          return null;
        },
      );
      await _withApp(tester, server, (_) async {
        await _create(tester);
        expect(find.text(_savedMessage), findsOneWidget);
        expect(_archive(tester).categories.map((c) => c.name), contains('공부'));
        broken = false;
        await tester.tap(find.text('다시 불러오기'));
        await tester.pumpAndSettle();
        expect(_archive(tester).categories, isEmpty);
        expect(find.byType(CategoryFormSheet), findsNothing);
        expect(server.calls(_categories, 'POST'), hasLength(1));
      });
    });
  }

  testWidgets('새 저장과 조회보다 먼저 시작한 공통 조회는 늦게 와도 최신 목록을 덮지 않는다', (tester) async {
    final oldRead = Completer<http.Response?>();
    var holdNext = false;
    final server = _Server(
      respond: (request, _) {
        if (request.url.path == _categories &&
            request.method == 'GET' &&
            holdNext) {
          holdNext = false;
          return oldRead.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, (_) async {
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenArchive();
      await tester.pumpAndSettle();
      _archive(tester).onTabChanged(1);
      await tester.pumpAndSettle();
      final category = _archive(tester).categories.single;
      holdNext = true;
      _archive(
        tester,
      ).onUpdateCategory(category, category.copyWith(name: '수정한 공부'));
      await tester.pumpAndSettle();
      await _create(tester);
      expect(_archive(tester).categories.map((c) => c.name), contains('취업 준비'));
      oldRead.complete(
        _json([
          {..._category, 'name': '수정한 공부'},
        ]),
      );
      await tester.pumpAndSettle();
      expect(_archive(tester).categories.map((c) => c.name), contains('취업 준비'));
      expect(
        _archive(tester).categories.firstWhere((c) => c.id == 101).name,
        '수정한 공부',
      );
    });
  });

  testWidgets('저장 후 조회와 수동 재조회는 각각 전체10초이며 늦은 응답은 목록을 바꾸지 않는다', (tester) async {
    final first = Completer<http.Response?>();
    final second = Completer<http.Response?>();
    final starts = <DateTime>[];
    final server = _Server(
      respond: (request, server) {
        if (request.url.path == _categories &&
            request.method == 'GET' &&
            server.calls(_categories, 'POST').isNotEmpty) {
          starts.add(tester.binding.clock.now());
          if (starts.length == 1) return first.future;
          if (starts.length == 2) return second.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, (storage) async {
      await _create(tester);
      expect(find.byType(CategoryFormSheet), findsNothing);
      await _advanceTo(tester, starts[0], const Duration(milliseconds: 9999));
      expect(find.text(_savedMessage), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text(_savedMessage), findsOneWidget);
      expect(_archive(tester).categories.map((c) => c.name), contains('공부'));
      first.complete(
        _json([
          {..._category, 'name': '늦은 목록'},
        ]),
      );
      await tester.pumpAndSettle();
      expect(
        _archive(tester).categories.map((c) => c.name),
        isNot(contains('늦은 목록')),
      );
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      await _advanceTo(tester, starts[1], const Duration(milliseconds: 9999));
      expect(find.text(_savedMessage), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text(_savedMessage), findsOneWidget);
      second.complete(
        _json([
          {..._category, 'name': '역시 늦은 목록'},
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(server.calls(_categories, 'POST'), hasLength(1));
      expect(_archive(tester).categories.map((c) => c.name), contains('공부'));
      expect(storage.clears, 0);
    });
  });

  for (final lateStatus in [200, 401]) {
    testWidgets('목록 조회의 인증 갱신도10초에 포함하고 늦은$lateStatus 인증 결과는 세션을 바꾸지 않는다', (
      tester,
    ) async {
      final denied = Completer<http.Response?>();
      final refresh = Completer<http.Response?>();
      DateTime? start;
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == _refresh) return refresh.future;
          if (request.url.path == _categories &&
              request.method == 'GET' &&
              server.calls(_categories, 'POST').isNotEmpty) {
            start ??= tester.binding.clock.now();
            return denied.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, (storage) async {
        await _create(tester);
        await _advanceTo(tester, start!, const Duration(seconds: 7));
        denied.complete(_json({'detail': 'Expired'}, 401));
        await tester.pump();
        expect(server.calls(_refresh), hasLength(1));
        await _advanceTo(tester, start!, const Duration(milliseconds: 9999));
        expect(find.text(_savedMessage), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(find.text(_savedMessage), findsOneWidget);
        refresh.complete(
          lateStatus == 200
              ? _tokens('too-late')
              : _json({'detail': 'Expired'}, 401),
        );
        await tester.pumpAndSettle();
        expect(storage.session?.accessToken, 'test-access');
        expect(storage.writes, 0);
        expect(storage.clears, 0);
        expect(server.calls('/api/v1/auth/guest'), isEmpty);
        expect(server.calls(_categories, 'POST'), hasLength(1));
      });
    });
  }

  testWidgets('카테고리 조회만 만료돼도 현재 검색과 공유한 인증 갱신은 완료한다', (tester) async {
    final denied = Completer<http.Response?>();
    final refresh = Completer<http.Response?>();
    DateTime? start;
    final server = _Server(
      respond: (request, server) {
        if (request.url.path == _refresh) return refresh.future;
        if (request.url.path == _categories &&
            request.method == 'GET' &&
            server.calls(_categories, 'POST').isNotEmpty) {
          start ??= tester.binding.clock.now();
          return denied.future;
        }
        if (request.url.path == '/api/v1/feed' &&
            request.url.queryParameters['q'] != null &&
            request.headers['Authorization'] == 'Bearer test-access') {
          return _json({'detail': 'Expired'}, 401);
        }
        return null;
      },
    );
    await _withApp(tester, server, (storage) async {
      await _create(tester);
      await _advanceTo(tester, start!, const Duration(seconds: 7));
      denied.complete(_json({'detail': 'Expired'}, 401));
      await tester.pump();
      _archive(tester).onSearch();
      await tester.pumpAndSettle();
      final search = tester
          .widget<SearchScreen>(find.byType(SearchScreen))
          .onSearch('현재 검색');
      await tester.pump();
      await _advanceTo(tester, start!, const Duration(seconds: 10));
      refresh.complete(_tokens('shared'));
      await tester.pumpAndSettle();
      expect(await search, isEmpty);
      expect(storage.session?.accessToken, 'shared-access');
      expect(storage.writes, 1);
      expect(storage.clears, 0);
      expect(server.calls(_refresh), hasLength(1));
      expect(server.calls(_categories, 'POST'), hasLength(1));
    });
  });

  testWidgets('계정 전환 뒤 이전 목록 응답과 이전 스낵바 재시도는 새 계정에 적용되지 않는다', (tester) async {
    final pending = Completer<http.Response?>();
    DateTime? start;
    final server = _Server(
      respond: (request, server) {
        if (request.url.path == _categories &&
            request.method == 'GET' &&
            server.userId == 1 &&
            server.calls(_categories, 'POST').isNotEmpty) {
          start ??= tester.binding.clock.now();
          return pending.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, (storage) async {
      await _create(tester);
      await _advanceTo(tester, start!, const Duration(seconds: 10));
      final retry = tester
          .widget<SnackBarAction>(find.byType(SnackBarAction))
          .onPressed;
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SnackBar), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      await _newAccount(tester);
      final requestCount = server.requests.length;
      retry();
      pending.complete(
        _json([
          {..._category, 'name': '이전 계정 목록'},
        ]),
      );
      await tester.pumpAndSettle();
      expect(server.requests.length, requestCount);
      expect(storage.session?.accessToken, 'guest-access');
      final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(home.categories.map((c) => c.name), contains('새 계정 목록'));
      expect(home.categories.map((c) => c.name), isNot(contains('이전 계정 목록')));
    });
  });

  testWidgets('스낵바의 수동 조회도 인증 갱신을 포함한 전체10초만 기다린다', (tester) async {
    final denied = Completer<http.Response?>();
    final refresh = Completer<http.Response?>();
    DateTime? start;
    var retrying = false;
    final server = _Server(
      respond: (request, server) {
        if (request.url.path == _refresh) return refresh.future;
        if (request.url.path == _categories &&
            request.method == 'GET' &&
            server.calls(_categories, 'POST').isNotEmpty) {
          if (!retrying) return _json({'detail': 'Offline'}, 503);
          start ??= tester.binding.clock.now();
          return denied.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, (storage) async {
      await _create(tester);
      retrying = true;
      final initialRequests = server.requests.length;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      await _advanceTo(tester, start!, const Duration(seconds: 7));
      denied.complete(_json({'detail': 'Expired'}, 401));
      await tester.pump();
      await _advanceTo(tester, start!, const Duration(milliseconds: 9999));
      expect(find.text(_savedMessage), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text(_savedMessage), findsOneWidget);
      refresh.complete(_tokens('late-retry'));
      await tester.pumpAndSettle();
      expect(storage.session?.accessToken, 'test-access');
      expect(storage.writes, 0);
      expect(
        server.requests
            .skip(initialRequests)
            .map((r) => '${r.method} ${r.url.path}'),
        ['GET $_categories', 'POST $_refresh'],
      );
    });
  });

  for (final deleted in [false, true]) {
    testWidgets('재확인된 성공 스냅샷보다 현재 서버 목록의 ${deleted ? '삭제' : '이름과 색상'}을 반영한다', (
      tester,
    ) async {
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == _categories && request.method == 'POST') {
            if (!deleted) {
              server.categories.add({
                ..._category,
                'id': 404,
                'name': '이후 이름',
                'color': '#FB7185',
              });
            } else {
              // A different category with the same name is not the saved target.
              server.categories.add({..._category, 'id': 505, 'name': '취업 준비'});
            }
            return _json({
              'id': 404,
              ...jsonDecode(request.body) as Map<String, dynamic>,
              'is_default': false,
              'submission': {
                'key': request.headers['Idempotency-Key'],
                'status': 'succeeded',
                'replayed': true,
              },
            }, 201);
          }
          return null;
        },
      );
      await _withApp(tester, server, (_) async {
        await _create(tester);
        expect(find.byType(CategoryFormSheet), findsNothing);
        if (deleted) {
          expect(_archive(tester).categories.any((c) => c.id == 404), isFalse);
          expect(_archive(tester).categories.any((c) => c.id == 505), isTrue);
        } else {
          final current = _archive(
            tester,
          ).categories.firstWhere((c) => c.id == 404);
          expect(current.name, '이후 이름');
          expect(current.color, const Color(0xFFFB7185));
        }
        expect(server.calls(_categories, 'POST'), hasLength(1));
      });
    });
  }
  for (final lateStatus in [200, 401]) {
    testWidgets('진행 중 카테고리 조회의 늦은$lateStatus 응답은 새 계정과 세션을 바꾸지 않는다', (
      tester,
    ) async {
      final oldRead = Completer<http.Response?>();
      final server = _Server(
        respond: (request, server) {
          if (request.url.path == _categories &&
              request.method == 'GET' &&
              server.userId == 1 &&
              server.calls(_categories, 'POST').isNotEmpty) {
            return oldRead.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, (storage) async {
        await _create(tester);
        await _newAccount(tester);
        final requestCount = server.requests.length;
        oldRead.complete(
          lateStatus == 200
              ? _json([
                  {..._category, 'name': '이전 계정 목록'},
                ])
              : _json({'detail': 'Expired old account'}, 401),
        );
        await tester.pumpAndSettle();
        expect(server.requests.length, requestCount);
        expect(storage.session?.accessToken, 'guest-access');
        expect(
          tester
              .widget<HomeScreen>(find.byType(HomeScreen))
              .categories
              .map((c) => c.name),
          contains('새 계정 목록'),
        );
        expect(find.text(_savedMessage), findsNothing);
        expect(server.calls(_refresh), isEmpty);
      });
    });
  }

  testWidgets('더 새 저장 뒤의 카테고리 조회가 먼저 끝나면 이전 전용 조회는 최신 목록을 덮지 않는다', (
    tester,
  ) async {
    final first = Completer<http.Response?>();
    final server = _Server(
      respond: (request, server) {
        if (request.url.path == _categories &&
            request.method == 'GET' &&
            server.calls(_categories, 'POST').length == 1) {
          return first.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, (_) async {
      await _create(tester, '첫 번째 생성');
      await _create(tester, '두 번째 생성');
      expect(
        _archive(tester).categories.map((c) => c.name),
        containsAll(['첫 번째 생성', '두 번째 생성']),
      );
      first.complete(
        _json([
          {..._category, 'name': '늦은 이전 응답'},
        ]),
      );
      await tester.pumpAndSettle();
      expect(
        _archive(tester).categories.map((c) => c.name),
        containsAll(['첫 번째 생성', '두 번째 생성']),
      );
      expect(find.text(_savedMessage), findsNothing);
      expect(server.calls(_categories, 'POST'), hasLength(2));
    });
  });
  testWidgets('새 조회가 끝난 뒤 이전 공통 조회의 늦은401은 인증 갱신을 시작하지 않는다', (tester) async {
    final oldRead = Completer<http.Response?>();
    var holdNext = false;
    final server = _Server(
      respond: (request, _) {
        if (request.url.path == _categories &&
            request.method == 'GET' &&
            holdNext) {
          holdNext = false;
          return oldRead.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, (storage) async {
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenArchive();
      await tester.pumpAndSettle();
      _archive(tester).onTabChanged(1);
      await tester.pumpAndSettle();
      final category = _archive(tester).categories.single;
      final feeds = server.calls('/api/v1/feed').length;
      final statistics = server.calls('/api/v1/users/me/stats').length;
      holdNext = true;
      _archive(
        tester,
      ).onUpdateCategory(category, category.copyWith(name: '새 이름'));
      await tester.pumpAndSettle();
      await _create(tester);
      oldRead.complete(_json({'detail': 'Expired obsolete read'}, 401));
      await tester.pumpAndSettle();
      expect(server.calls(_refresh), isEmpty);
      expect(server.calls('/api/v1/feed').length, greaterThan(feeds));
      expect(
        server.calls('/api/v1/users/me/stats').length,
        greaterThan(statistics),
      );
      expect(find.text(_savedMessage), findsNothing);
      expect(find.text('최신 정보를 불러오지 못했어요.'), findsNothing);
      expect(storage.session?.accessToken, 'test-access');
      expect(storage.writes, 0);
      expect(_archive(tester).categories.map((c) => c.name), contains('취업 준비'));
    });
  });
  testWidgets('새 공통 조회가 이전 전용 조회를 대신해도 콘텐츠와 통계를 갱신하고 오래된 오류 안내를 띄우지 않는다', (
    tester,
  ) async {
    final oldRead = Completer<http.Response?>();
    var holdNext = true;
    final server = _Server(
      respond: (request, server) {
        if (request.url.path == _categories &&
            request.method == 'GET' &&
            holdNext &&
            server.calls(_categories, 'POST').isNotEmpty) {
          holdNext = false;
          return oldRead.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, (_) async {
      await _create(tester);
      final feeds = server.calls('/api/v1/feed').length;
      final statistics = server.calls('/api/v1/users/me/stats').length;
      final category = _archive(
        tester,
      ).categories.firstWhere((c) => c.id == 101);
      _archive(
        tester,
      ).onUpdateCategory(category, category.copyWith(name: '후속 수정'));
      await tester.pumpAndSettle();
      oldRead.complete(_json({'detail': 'Obsolete failure'}, 503));
      await tester.pumpAndSettle();
      expect(server.calls('/api/v1/feed').length, greaterThan(feeds));
      expect(
        server.calls('/api/v1/users/me/stats').length,
        greaterThan(statistics),
      );
      expect(
        _archive(tester).categories.firstWhere((c) => c.id == 101).name,
        '후속 수정',
      );
      expect(find.text(_savedMessage), findsNothing);
      expect(find.text('최신 정보를 불러오지 못했어요.'), findsNothing);
      expect(server.calls(_categories, 'POST'), hasLength(1));
    });
  });
  testWidgets('이전 변경의 표시 정리가 나중 조회의 현재 서버 값을 무효화하지 않는다', (tester) async {
    final first = Completer<http.Response?>();
    final latest = Completer<http.Response?>();
    var holdNext = false;
    final server = _Server(
      respond: (request, server) {
        if (request.url.path == _categories && request.method == 'GET') {
          if (holdNext) {
            holdNext = false;
            return first.future;
          }
          if (server.calls(_categories, 'POST').isNotEmpty) {
            return latest.future;
          }
        }
        return null;
      },
    );
    await _withApp(tester, server, (_) async {
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenArchive();
      await tester.pumpAndSettle();
      _archive(tester).onTabChanged(1);
      await tester.pumpAndSettle();
      final category = _archive(tester).categories.single;
      holdNext = true;
      _archive(
        tester,
      ).onUpdateCategory(category, category.copyWith(name: '먼저 수정'));
      await tester.pumpAndSettle();
      await _create(tester);
      expect(
        _archive(
          tester,
        ).categories.firstWhere((c) => c.id == 101).mutationLabel,
        isNull,
      );
      latest.complete(
        _json([
          {..._category, 'name': '가장 최신 서버 이름'},
        ]),
      );
      first.complete(_json([_category]));
      await tester.pumpAndSettle();
      expect(_archive(tester).categories.single.name, '가장 최신 서버 이름');
    });
  });
}
