import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_startup.dart';
import 'support/memory_api_session_storage.dart';

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
          final key = request.headers['Idempotency-Key'];
          return _json({
            ...categories[0],
            if (key != null)
              'submission': {
                'key': key,
                'status': 'succeeded',
                'replayed': false,
              },
          });
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
  Future<void> Function(MemoryApiSessionStorage storage) check,
) async {
  SharedPreferences.setMockInitialValues({});
  final storage = MemoryApiSessionStorage();
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

Future<void> _navigate(WidgetTester tester, bool management) async {
  tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenArchive();
  await tester.pumpAndSettle();
  _archive(tester).onTabChanged(1);
  await tester.pumpAndSettle();
  if (management) {
    _archive(tester).onOpenCategoryManagement!();
    await tester.pumpAndSettle();
  }
}

Future<void> _open(WidgetTester tester, bool edit) async {
  if (edit) {
    await tester.tap(find.byKey(const ValueKey('archive-category-more-101')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카테고리 수정'));
  } else {
    final management = find
        .byType(CategoryManagementScreen)
        .evaluate()
        .isNotEmpty;
    await tester.tap(
      find.byKey(
        ValueKey(management ? 'management-add' : 'archive-category-add'),
      ),
    );
  }
  await tester.pumpAndSettle();
}

String _input(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('category-form-input')))
    .controller!
    .text;
Future<void> _save(WidgetTester tester, bool edit, String name) async {
  await tester.enterText(
    find.byKey(const ValueKey('category-form-input')),
    name,
  );
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, edit ? '수정하기' : '생성하기'));
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.tapAt(const Offset(16, 100));
  await tester.pumpAndSettle();
}

Future<void> _to(WidgetTester tester, DateTime start, Duration elapsed) async {
  final remain = start.add(elapsed).difference(tester.binding.clock.now());
  if (remain > Duration.zero) await tester.pump(remain);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('수정 재진입은 서버의 현재 이름과 색상을 확인한 뒤 새 시트를 연다', (tester) async {
    final server = _Server();
    await _withApp(tester, server, (_) async {
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenArchive();
      await tester.pumpAndSettle();
      _archive(tester).onTabChanged(1);
      await tester.pumpAndSettle();
      server.categories[0] = {
        ..._category,
        'name': '다른 기기의 현재 값',
        'color': '#FB7185',
      };
      await tester.tap(find.byKey(const ValueKey('archive-category-more-101')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카테고리 수정'));
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('category-form-input')),
      );
      expect(input.controller!.text, '다른 기기의 현재 값');
      expect(
        tester
            .widget<CategoryEditSheet>(find.byType(CategoryEditSheet))
            .category
            .color
            .toARGB32(),
        0xFFFB7185,
      );
    });
  });
  for (final management in [false, true]) {
    for (final edit in [false, true]) {
      final label = '${management ? '관리' : '아카이브'} ${edit ? '수정' : '생성'}';
      testWidgets('$label 편집 초안 직접 닫기 뒤 새 입력 또는 현재 서버 값으로 시작한다', (
        tester,
      ) async {
        final server = _Server();
        await _withApp(tester, server, (_) async {
          await _navigate(tester, management);
          await _open(tester, edit);
          await tester.enterText(
            find.byKey(const ValueKey('category-form-input')),
            '버린 초안',
          );
          await tester.tap(
            find.byKey(const ValueKey('palette-color-ffffa24b')),
          );
          await _close(tester);
          expect(find.byType(CategoryFormSheet), findsNothing);
          server.categories[0] = {..._category, 'name': '현재 저장값'};
          await _open(tester, edit);
          expect(_input(tester), edit ? '현재 저장값' : '');
          expect(
            tester
                .widget<FolderColorPicker>(find.byType(FolderColorPicker))
                .selectedColor
                .toARGB32(),
            edit ? 0xFF059669 : 0xFFFF6277,
          );
          expect(
            server.requests.where(
              (r) => r.method == 'POST' || r.method == 'PATCH',
            ),
            isEmpty,
          );
        });
      });
      testWidgets('$label 미확인 닫기 계속 확인은 같은 키, 닫은 뒤 재진입은 새 제출을 쓴다', (
        tester,
      ) async {
        final writes = <http.Request>[];
        final server = _Server(
          respond: (request, _) {
            if ((request.method == 'POST' && request.url.path == _categories) ||
                request.method == 'PATCH') {
              writes.add(request);
              return _json({'detail': 'Lost response'}, 503);
            }
            return null;
          },
        );
        await _withApp(tester, server, (_) async {
          await _navigate(tester, management);
          await _open(tester, edit);
          await _save(tester, edit, '원래 초안');
          await _close(tester);
          expect(find.text('입력 창을 닫을까요?'), findsOneWidget);
          await tester.tap(find.text('계속 확인하기'));
          await tester.pumpAndSettle();
          expect(_input(tester), '원래 초안');
          await tester.tap(find.widgetWithText(FilledButton, '결과 다시 확인'));
          await tester.pumpAndSettle();
          expect(
            writes[1].headers['Idempotency-Key'],
            writes[0].headers['Idempotency-Key'],
          );
          expect(writes[1].body, writes[0].body);
          await _close(tester);
          await tester.tap(find.widgetWithText(FilledButton, '닫기'));
          await tester.pumpAndSettle();
          server.categories[0] = {..._category, 'name': '다른 기기 저장값'};
          await _open(tester, edit);
          expect(_input(tester), edit ? '다른 기기 저장값' : '');
          await _save(tester, edit, '새 제출');
          expect(
            writes[2].headers['Idempotency-Key'],
            isNot(writes[0].headers['Idempotency-Key']),
          );
        });
      });
      testWidgets('$label 재진입 조회 실패는 마지막 목록을 유지하고 GET만 재시도해 새 시트를 연다', (
        tester,
      ) async {
        var fail = false;
        final server = _Server(
          respond: (request, _) {
            if (request.method == 'GET' &&
                request.url.path == _categories &&
                fail) {
              return _json(null);
            }
            return null;
          },
        );
        await _withApp(tester, server, (_) async {
          await _navigate(tester, management);
          fail = true;
          await _open(tester, edit);
          expect(find.byType(CategoryFormSheet), findsNothing);
          expect(find.text('최신 정보를 불러오지 못했어요.'), findsOneWidget);
          expect(find.textContaining('저장은 완료됐지만'), findsNothing);
          expect(find.text('공부'), findsOneWidget);
          fail = false;
          server.categories[0] = {..._category, 'name': '조회로 확인한 현재 값'};
          final start = server.requests.length;
          await tester.tap(find.text('다시 불러오기'));
          await tester.pumpAndSettle();
          expect(_input(tester), edit ? '조회로 확인한 현재 값' : '');
          expect(
            server.requests.skip(start).map((r) => '${r.method} ${r.url.path}'),
            ['GET $_categories'],
          );
        });
      });
    }
  }
  for (final edit in [false, true]) {
    testWidgets('${edit ? '수정' : '생성'} 새 앱은 닫힌 미확인 제출과 초안을 복원하거나 전송하지 않는다', (
      tester,
    ) async {
      final server = _Server(
        respond: (request, _) {
          if (request.method == 'PATCH' ||
              (request.method == 'POST' && request.url.path == _categories)) {
            return _json({}, 503);
          }
          return null;
        },
      );
      await _withApp(tester, server, (storage) async {
        await _navigate(tester, false);
        await _open(tester, edit);
        await _save(tester, edit, '앱 종료로 버린 초안');
        final writes = server.requests
            .where((r) => r.method == 'POST' || r.method == 'PATCH')
            .length;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(ClipbackApp(sessionStorage: storage));
        await completeAppStartup(tester);
        expect(find.byType(CategoryFormSheet), findsNothing);
        expect(
          server.requests.where(
            (r) => r.method == 'POST' || r.method == 'PATCH',
          ),
          hasLength(writes),
        );
        await _navigate(tester, false);
        await _open(tester, edit);
        expect(_input(tester), edit ? '공부' : '');
      });
    });
  }
  testWidgets('재진입 조회는 인증 기다림을 포함해10초이고 늦은 결과는 시트를 열지 않는다', (tester) async {
    var blocked = false;
    final response = Completer<http.Response?>();
    final refresh = Completer<http.Response?>();
    DateTime? start;
    final server = _Server(
      respond: (request, _) {
        if (request.url.path == _categories && blocked) {
          start ??= tester.binding.clock.now();
          return response.future;
        }
        if (request.url.path == _refresh) return refresh.future;
        return null;
      },
    );
    await _withApp(tester, server, (storage) async {
      await _navigate(tester, false);
      blocked = true;
      await _open(tester, true);
      await _to(tester, start!, const Duration(seconds: 7));
      response.complete(_json({}, 401));
      await tester.pump();
      await _to(tester, start!, const Duration(milliseconds: 9999));
      expect(find.text('최신 정보를 불러오지 못했어요.'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('최신 정보를 불러오지 못했어요.'), findsOneWidget);
      expect(find.byType(CategoryFormSheet), findsNothing);
      refresh.complete(_tokens('late'));
      await tester.pumpAndSettle();
      expect(storage.session!.accessToken, 'test-access');
      expect(storage.writes, 0);
      expect(find.byType(CategoryFormSheet), findsNothing);
    });
  });
  for (final missing in [false, true]) {
    testWidgets('준비된 수정 입력은 낙관적 표시와 구분한 서버 ${missing ? '대상 부재' : '원본'}을 사용한다', (
      tester,
    ) async {
      final patch = Completer<http.Response?>();
      final server = _Server(
        respond: (r, _) => r.method == 'PATCH' ? patch.future : null,
      );
      await _withApp(tester, server, (_) async {
        await _navigate(tester, false);
        await tester.tap(
          find.byKey(const ValueKey('archive-category-more-101')),
        );
        await tester.pumpAndSettle();
        final old = _archive(tester).categories.single;
        _archive(tester).onUpdateCategory(old, old.copyWith(name: '낙관적 표시'));
        await tester.pumpAndSettle();
        if (missing) server.categories.clear();
        await tester.tap(find.text('카테고리 수정'));
        await tester.pumpAndSettle();
        expect(_archive(tester).categories.single.name, '낙관적 표시');
        expect(_input(tester), '공부');
        expect(
          find.text('이 카테고리가 삭제되어 수정할 수 없어요.'),
          missing ? findsOneWidget : findsNothing,
        );
        if (missing) {
          await tester.tap(find.widgetWithText(FilledButton, '목록으로 돌아가기'));
          await tester.pumpAndSettle();
          expect(find.byType(CategoryFormSheet), findsNothing);
          expect(server.calls(_categories, 'POST'), isEmpty);
        }
        patch.complete(_json({..._category, 'name': '낙관적 표시'}));
        await tester.pumpAndSettle();
      });
    });
  }
  testWidgets('재진입 조회를 새 공통 조회가 대신하면 오래된 read 완료로 편집기를 열지 않는다', (tester) async {
    final oldRead = Completer<http.Response?>();
    var hold = false;
    final server = _Server(
      respond: (r, _) {
        if (r.method == 'GET' && r.url.path == _categories && hold) {
          hold = false;
          return oldRead.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, (_) async {
      await _navigate(tester, false);
      final old = _archive(tester).categories.single;
      hold = true;
      await _open(tester, true);
      expect(find.byType(CategoryFormSheet), findsNothing);
      _archive(tester).onUpdateCategory(old, old.copyWith(name: '더 새 공통 조회'));
      await tester.pumpAndSettle();
      oldRead.complete(
        _json([
          {..._category, 'name': '오래된 준비 응답'},
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(_archive(tester).categories.single.name, '더 새 공통 조회');
      expect(find.text('최신 정보를 불러오지 못했어요.'), findsNothing);
    });
  });
  testWidgets('재진입 조회 대기와 실패 스낵바는 원래 화면을 떠난 뒤 편집기를 열지 않는다', (tester) async {
    var failed = false;
    final server = _Server(
      respond: (r, _) =>
          failed && r.url.path == _categories ? _json({}, 503) : null,
    );
    await _withApp(tester, server, (_) async {
      await _navigate(tester, false);
      failed = true;
      await _open(tester, false);
      _archive(tester).onTab(AppRoute.home);
      await tester.pumpAndSettle();
      final start = server.requests.length;
      failed = false;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(server.requests.length, start);
      expect(find.byType(CategoryFormSheet), findsNothing);
    });
  });
  for (final edit in [false, true]) {
    for (final rejected in [false, true]) {
      testWidgets(
        '${edit ? '수정' : '생성'} 이전 시트의 늦은${rejected ? '거절' : '성공'}은 재진입한 새 초안을 바꾸지 않는다',
        (tester) async {
          final oldWrite = Completer<http.Response?>();
          DateTime? start;
          http.Request? write;
          final server = _Server(
            respond: (r, _) {
              if (r.method == 'PATCH' ||
                  (r.method == 'POST' && r.url.path == _categories)) {
                write = r;
                start ??= tester.binding.clock.now();
                return oldWrite.future;
              }
              return null;
            },
          );
          await _withApp(tester, server, (_) async {
            await _navigate(tester, false);
            await _open(tester, edit);
            await _save(tester, edit, '응답을 놓친 이름');
            await _to(tester, start!, const Duration(seconds: 10));
            await _close(tester);
            await tester.tap(find.widgetWithText(FilledButton, '닫기'));
            await tester.pumpAndSettle();
            await _open(tester, edit);
            await tester.enterText(
              find.byKey(const ValueKey('category-form-input')),
              '새 시트의 초안',
            );
            final count = server.requests.length;
            oldWrite.complete(
              rejected
                  ? _json({
                      'detail': 'Category already exists',
                      'code': 'category_name_exists',
                      'submission': {
                        'key': write!.headers['Idempotency-Key'],
                        'status': 'rejected',
                        'replayed': false,
                      },
                    }, 409)
                  : _json({
                      ..._category,
                      'id': edit ? 101 : 404,
                      ...jsonDecode(write!.body) as Map<String, dynamic>,
                      'submission': {
                        'key': write!.headers['Idempotency-Key'],
                        'status': 'succeeded',
                        'replayed': false,
                      },
                    }, edit ? 200 : 201),
            );
            await tester.pumpAndSettle();
            expect(_input(tester), '새 시트의 초안');
            expect(server.requests.length, count);
            expect(_archive(tester).categories.single.name, '공부');
            expect(find.textContaining('같은 이름의 카테고리'), findsNothing);
          });
        },
      );
    }
    for (final deleted in [false, true]) {
      testWidgets(
        '${edit ? '수정' : '생성'} 실제 미확인 재확인 성공은 이후 ${deleted ? '삭제' : '변경'}를 현재 목록으로 유지한다',
        (tester) async {
          final writes = <http.Request>[];
          final server = _Server(
            respond: (r, server) {
              if (r.method == 'PATCH' ||
                  (r.method == 'POST' && r.url.path == _categories)) {
                writes.add(r);
                if (writes.length == 1) return _json({}, 503);
                server.categories
                  ..clear()
                  ..addAll(
                    deleted
                        ? [
                            {..._category, 'id': 505, 'name': '응답을 놓친 이름'},
                          ]
                        : [
                            {
                              ..._category,
                              'id': edit ? 101 : 404,
                              'name': '이후 이름',
                              'color': '#FB7185',
                            },
                          ],
                  );
                return _json({
                  ..._category,
                  'id': edit ? 101 : 404,
                  ...jsonDecode(r.body) as Map<String, dynamic>,
                  'submission': {
                    'key': r.headers['Idempotency-Key'],
                    'status': 'succeeded',
                    'replayed': true,
                  },
                }, edit ? 200 : 201);
              }
              return null;
            },
          );
          await _withApp(tester, server, (_) async {
            await _navigate(tester, false);
            await _open(tester, edit);
            await _save(tester, edit, '응답을 놓친 이름');
            await tester.tap(find.widgetWithText(FilledButton, '결과 다시 확인'));
            await tester.pumpAndSettle();
            expect(find.byType(CategoryFormSheet), findsNothing);
            expect(
              _archive(tester).categories.single.name,
              deleted ? '응답을 놓친 이름' : '이후 이름',
            );
            expect(
              _archive(tester).categories.single.id,
              deleted ? 505 : (edit ? 101 : 404),
            );
            if (!deleted) {
              expect(
                _archive(tester).categories.single.color.toARGB32(),
                0xFFFB7185,
              );
            }
            expect(
              writes[0].headers['Idempotency-Key'],
              writes[1].headers['Idempotency-Key'],
            );
            expect(writes[0].body, writes[1].body);
          });
        },
      );
    }
  }
  for (final management in [false, true]) {
    for (final edit in [false, true]) {
      testWidgets(
        '${management ? '관리' : '아카이브'} ${edit ? '수정' : '생성'} 확정 거절 시트를 직접 닫으면 초안과 키를 버린다',
        (tester) async {
          final writes = <http.Request>[];
          final server = _Server(
            respond: (r, _) {
              if (r.method == 'PATCH' ||
                  (r.method == 'POST' && r.url.path == _categories)) {
                writes.add(r);
                return _json({
                  'detail': 'Category already exists',
                  'code': 'category_name_exists',
                  'submission': {
                    'key': r.headers['Idempotency-Key'],
                    'status': 'rejected',
                    'replayed': false,
                  },
                }, 409);
              }
              return null;
            },
          );
          await _withApp(tester, server, (_) async {
            await _navigate(tester, management);
            await _open(tester, edit);
            await _save(tester, edit, '거절된 초안');
            expect(
              find.text('같은 이름의 카테고리가 있어요. 다른 이름을 입력해 주세요.'),
              findsOneWidget,
            );
            await _close(tester);
            expect(find.text('입력 창을 닫을까요?'), findsNothing);
            await _open(tester, edit);
            expect(_input(tester), edit ? '공부' : '');
            await _save(tester, edit, '다시 쓴 초안');
            expect(
              writes[1].headers['Idempotency-Key'],
              isNot(writes[0].headers['Idempotency-Key']),
            );
          });
        },
      );
    }
  }
  testWidgets('수정 재진입 대상 부재는 같은 이름의 다른 카테고리로 대체하지 않는다', (tester) async {
    final server = _Server();
    await _withApp(tester, server, (_) async {
      await _navigate(tester, false);
      server.categories
        ..clear()
        ..add({..._category, 'id': 505});
      await _open(tester, true);
      expect(find.text('이 카테고리가 삭제되어 수정할 수 없어요.'), findsOneWidget);
      expect(_input(tester), '공부');
      await tester.tap(find.widgetWithText(FilledButton, '목록으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(_archive(tester).categories.single.id, 505);
      expect(
        server.requests.where((r) => r.method == 'POST' || r.method == 'PATCH'),
        isEmpty,
      );
    });
  });
}
