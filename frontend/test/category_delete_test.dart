import 'support/app_startup.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'auth_navigation.dart';

import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
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
  'content_count': 0,
  'last_saved_at': null,
};
const _otherCategory = {
  'id': 202,
  'name': '여행',
  'color': '#FB7185',
  'is_default': false,
  'content_count': 0,
  'last_saved_at': null,
};
const _uncategorized = {
  'id': 303,
  'name': '미분류',
  'color': '#B5BDC3',
  'is_default': true,
  'content_count': 0,
  'last_saved_at': null,
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
  final categories = _allCategories
      .map((category) => Map<String, Object?>.of(category))
      .toList();
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
    if (request.url.path == '/api/v1/recommendations/weekly') {
      return _json({
        'period_start': '2026-10-19T00:00:00Z',
        'period_end': '2026-10-26T00:00:00Z',
        'batch_id': null,
        'generated_at': null,
        'items': <Object>[],
      });
    }
    switch (request.url.path) {
      case '/api/v1/categories':
        if (request.method == 'POST') {
          final created = {
            ..._category,
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'id': 404,
          };
          categories.add(created);
          return _json({
            ...created,
            if (request.headers['Idempotency-Key'] case final String key)
              'submission': {
                'key': key,
                'status': 'succeeded',
                'replayed': false,
              },
          }, 201);
        }
        return _json(categories);
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
        final categoryMatch = RegExp(
          r'^/api/v1/categories/(\d+)$',
        ).firstMatch(request.url.path);
        if (categoryMatch != null) {
          final id = int.parse(categoryMatch.group(1)!);
          final index = categories.indexWhere(
            (category) => category['id'] == id,
          );
          if (request.method == 'DELETE') {
            categories.removeWhere((category) => category['id'] == id);
            for (final record in records) {
              final remaining = (record['categories'] as List)
                  .where((category) => (category as Map)['id'] != id)
                  .toList();
              record['categories'] = remaining.isEmpty
                  ? [_uncategorized]
                  : remaining;
            }
            return http.Response('', 204);
          }
          if (request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            categories[index] = {...categories[index], ...body};
            for (final record in records) {
              record['categories'] = (record['categories'] as List)
                  .map(
                    (category) => (category as Map)['id'] == id
                        ? categories[index]
                        : category,
                  )
                  .toList();
            }
            return _json(categories[index]);
          }
        }
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
DetailScreen _detail(WidgetTester tester) =>
    tester.widget<DetailScreen>(find.byType(DetailScreen));

Future<void> _openArchive(WidgetTester tester) async {
  _home(tester).onOpenArchive();
  await tester.pumpAndSettle();
}

Future<void> _openCategoryCreate(WidgetTester tester) async {
  await _openArchive(tester);
  _archive(tester).onTabChanged(1);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('archive-category-add')));
  await tester.pumpAndSettle();
}

Future<void> _openCategoryEdit(
  WidgetTester tester, {
  bool management = false,
}) async {
  await _openArchive(tester);
  if (management) {
    _archive(tester).onOpenCategoryManagement!();
  } else {
    _archive(tester).onTabChanged(1);
  }
  await tester.pumpAndSettle();
  _moreTap(tester, 101)!();
  await tester.pumpAndSettle();
  await tester.tap(find.text('카테고리 수정'));
  await tester.pumpAndSettle();
}

List<http.Request> _updates(_Server server) => server.requests
    .where(
      (request) =>
          request.method == 'PATCH' &&
          request.url.path == '/api/v1/categories/101',
    )
    .toList();

http.Response _updateResult(http.Request request, {bool replayed = false}) =>
    _json({
      ..._category,
      ...jsonDecode(request.body) as Map,
      'submission': {
        'key': request.headers['Idempotency-Key'],
        'status': 'succeeded',
        'replayed': replayed,
      },
    });

List<http.Request> _creates(_Server server) => server.requests
    .where(
      (request) =>
          request.method == 'POST' && request.url.path == '/api/v1/categories',
    )
    .toList();

http.Response _createResult(http.Request request, {bool replayed = false}) =>
    _json({
      'id': 404,
      ...jsonDecode(request.body) as Map<String, dynamic>,
      'is_default': false,
      'submission': {
        'key': request.headers['Idempotency-Key'],
        'status': 'succeeded',
        'replayed': replayed,
      },
    }, 201);

CategoryItem _categoryItem(ArchiveScreen screen, [int id = 101]) =>
    screen.categories.singleWhere((category) => category.id == id);
List<http.Request> _deletes(_Server server) => server.requests
    .where(
      (request) =>
          request.method == 'DELETE' &&
          request.url.path.startsWith('/api/v1/categories/'),
    )
    .toList();

http.Response _failure(String kind) => switch (kind) {
  'network' => throw http.ClientException('Offline'),
  'JSON' => http.Response('{broken', 200),
  _ => _json({'detail': '분류 삭제 실패 $kind'}, int.parse(kind)),
};

Future<void> _newAccount(
  WidgetTester tester,
  _Server server,
  ValueChanged<AppRoute> navigate,
) async {
  navigate(AppRoute.my);
  await tester.pumpAndSettle();
  tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
  await tester.pumpAndSettle();
  await startLogoutFromAccount(tester);
  await tester.pumpAndSettle();
  server.records.clear();
  await startGuestAndFinishOnboarding(tester);
  unawaited(_home(tester).onAddLink(url: 'https://example.com/new-account'));
  await tester.pumpAndSettle();
}

List<int?> _categoryIds(ContentItem item) =>
    item.categories.map((category) => category.id).toList();

VoidCallback? _moreTap(WidgetTester tester, int id) {
  final row = find.byWidgetPredicate(
    (widget) => widget is CategoryRow && widget.category.id == id,
  );
  return tester
      .widgetList<GestureDetector>(
        find.descendant(of: row, matching: find.byType(GestureDetector)),
      )
      .last
      .onTap;
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

  testWidgets('실제 수정 시트는 현재 값으로 시작하고 성공 확인 뒤 닫는다', (tester) async {
    final pending = Completer<http.Response?>();
    final server = _Server(
      respond: (request, _) =>
          request.method == 'PATCH' &&
              request.url.path == '/api/v1/categories/101'
          ? pending.future
          : null,
    );
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      _archive(tester).onTabChanged(1);
      await tester.pumpAndSettle();
      _moreTap(tester, 101)!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('카테고리 수정'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '공부',
      );
      expect(
        tester
            .widget<FolderColorPicker>(find.byType(FolderColorPicker))
            .selectedColor,
        const Color(0xFF059669),
      );
      await tester.enterText(find.byType(TextField), '수정 초안');
      await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
      await tester.pump();
      expect(find.text('저장하고 있어요.'), findsOneWidget);
      final sent = server.calls('/api/v1/categories/101').last;
      expect(sent.headers['Idempotency-Key'], isNotEmpty);
      pending.complete(
        _json({
          ..._category,
          ...jsonDecode(sent.body) as Map,
          'submission': {
            'key': sent.headers['Idempotency-Key'],
            'status': 'succeeded',
            'replayed': false,
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsNothing);
    });
  });

  testWidgets('수정 성공 뒤 목록 갱신 실패는 시트를 닫고 카테고리만 재조회한다', (tester) async {
    var stored = false;
    var retry = false;
    final server = _Server(
      respond: (request, server) {
        if (request.method == 'PATCH') {
          stored = true;
          server.categories[0] = {
            ...server.categories[0],
            ...jsonDecode(request.body) as Map<String, dynamic>,
          };
          return _updateResult(request);
        }
        if (stored && !retry && request.url.path == '/api/v1/categories') {
          return _json({'detail': 'metadata failed'}, 500);
        }
        return null;
      },
    );
    server.categories.first['content_count'] = 7;
    await _withApp(tester, server, () async {
      await _openCategoryEdit(tester);
      await tester.enterText(find.byType(TextField), '저장한 수정');
      await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(_categoryItem(_archive(tester)).contentCount, 7);
      expect(find.text('저장은 완료됐지만 카테고리 목록을 새로 불러오지 못했어요'), findsOneWidget);
      expect(_updates(server), hasLength(1));
      final beforeRetry = server.requests.length;
      retry = true;
      await tester.tap(find.widgetWithText(SnackBarAction, '다시 불러오기'));
      await tester.pumpAndSettle();
      expect(
        server.requests
            .skip(beforeRetry)
            .map((request) => '${request.method} ${request.url.path}'),
        ['GET /api/v1/categories'],
      );
      expect(_categoryItem(_archive(tester)).name, '저장한 수정');
    });
  });

  testWidgets('삭제된 수정 대상은 초안과 안내를 남기고 목록으로 돌아간다', (tester) async {
    final server = _Server(
      respond: (request, _) {
        if (request.method != 'PATCH') return null;
        return _json({
          'detail': 'Category not found',
          'code': 'category_target_missing',
          'submission': {
            'key': request.headers['Idempotency-Key'],
            'status': 'rejected',
            'replayed': false,
          },
        }, 404);
      },
    );
    await _withApp(tester, server, () async {
      await _openCategoryEdit(tester, management: true);
      await tester.enterText(find.byType(TextField), '삭제된 대상의 초안');
      await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
      await tester.pumpAndSettle();
      expect(find.text('이 카테고리가 삭제되어 수정할 수 없어요.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '삭제된 대상의 초안',
      );
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, '목록으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(_updates(server), hasLength(1));
      expect(_creates(server), isEmpty);
    });
  });

  testWidgets('수정의 전체10초와 늦은 응답은 목록을 되돌리지 않고 같은 제출을 재확인한다', (tester) async {
    final first = Completer<http.Response?>();
    final second = Completer<http.Response?>();
    final read = Completer<http.Response?>();
    var writes = 0;
    final server = _Server(
      respond: (request, _) {
        if (request.method == 'PATCH') {
          return ++writes == 1 ? first.future : second.future;
        }
        if (writes > 1 && request.url.path == '/api/v1/categories') {
          return read.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openCategoryEdit(tester);
      await tester.enterText(find.byType(TextField), '  수정할 이름  ');
      await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tapAt(const Offset(10, 10));
      await tester.drag(
        find.byKey(const ValueKey('category-form-handle')),
        const Offset(0, 120),
      );
      expect(_updates(server), hasLength(1));
      expect(_categoryItem(_archive(tester)).name, '공부');
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('저장하고 있어요.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.tap(find.widgetWithText(FilledButton, '결과 다시 확인'));
      await tester.pump();
      expect(find.text('저장 결과를 확인하고 있어요.'), findsOneWidget);
      first.complete(_updateResult(_updates(server).first));
      await tester.pump();
      expect(find.text('저장 결과를 확인하고 있어요.'), findsOneWidget);
      expect(_categoryItem(_archive(tester)).name, '공부');
      second.complete(_updateResult(_updates(server).last, replayed: true));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(_categoryItem(_archive(tester)).name, '공부');
      expect(_updates(server).last.body, _updates(server).first.body);
      expect(
        _updates(server).last.headers['Idempotency-Key'],
        _updates(server).first.headers['Idempotency-Key'],
      );
      read.complete(
        _json([
          {..._category, 'name': '다른 기기 최종 이름'},
          _otherCategory,
          _uncategorized,
        ]),
      );
      await tester.pumpAndSettle();
      expect(_categoryItem(_archive(tester)).name, '다른 기기 최종 이름');
    });
  });

  for (final code in ['category_name_exists', 'category_input_invalid']) {
    testWidgets('수정 $code 거절 뒤 초안을 고치면 새 제출로 저장한다', (tester) async {
      var writes = 0;
      final server = _Server(
        respond: (request, _) {
          if (request.method != 'PATCH') return null;
          if (++writes > 1) return _updateResult(request);
          return code == 'category_input_invalid'
              ? _json({
                  'detail': [
                    {'msg': 'invalid input'},
                  ],
                }, 422)
              : _json({
                  'detail': 'Category already exists',
                  'code': code,
                  'submission': {
                    'key': request.headers['Idempotency-Key'],
                    'status': 'rejected',
                    'replayed': false,
                  },
                }, 409);
        },
      );
      await _withApp(tester, server, () async {
        await _openCategoryEdit(tester, management: true);
        await tester.enterText(find.byType(TextField), '거절된 초안');
        final picker = tester.widget<FolderColorPicker>(
          find.byType(FolderColorPicker),
        );
        picker.onChanged(FolderColorPicker.colors[3]);
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '거절된 초안',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).readOnly,
          isFalse,
        );
        expect(
          tester
              .widget<FolderColorPicker>(find.byType(FolderColorPicker))
              .selectedColor,
          FolderColorPicker.colors[3],
        );
        if (code == 'category_name_exists') {
          expect(
            find.text('같은 이름의 카테고리가 있어요. 다른 이름을 입력해 주세요.'),
            findsOneWidget,
          );
        }
        await tester.enterText(find.byType(TextField), '고친 초안');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryFormSheet), findsNothing);
        expect(
          _updates(server).first.headers['Idempotency-Key'],
          isNot(_updates(server).last.headers['Idempotency-Key']),
        );
        expect(
          jsonDecode(_updates(server).last.body)['color'],
          jsonDecode(_updates(server).first.body)['color'],
        );
      });
    });
  }

  testWidgets('수정은 인증 갱신 재요청에도 같은 내용을 유지하고 전체10초만 기다린다', (tester) async {
    final denied = Completer<http.Response?>();
    final refresh = Completer<http.Response?>();
    final retried = Completer<http.Response?>();
    var writes = 0;
    final server = _Server(
      respond: (request, _) {
        if (request.url.path == '/api/v1/auth/refresh') return refresh.future;
        if (request.method == 'PATCH') {
          return ++writes == 1 ? denied.future : retried.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openCategoryEdit(tester);
      await tester.enterText(find.byType(TextField), '인증 중 수정 초안');
      await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
      await tester.pump(const Duration(seconds: 4));
      denied.complete(_json({'detail': 'expired'}, 401));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      refresh.complete(
        _json({
          'access_token': 'rotated-access',
          'refresh_token': 'rotated-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        }),
      );
      await tester.pump();
      await tester.pump();
      expect(_updates(server), hasLength(2));
      expect(_updates(server).first.body, _updates(server).last.body);
      expect(
        _updates(server).first.headers['Idempotency-Key'],
        _updates(server).last.headers['Idempotency-Key'],
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
      retried.complete(_updateResult(_updates(server).last));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
      expect(_categoryItem(_archive(tester)).name, '공부');
    });
  });

  testWidgets('수정 입력도 trim 후 code point40자를 검사하고 초과 이름을 자르지 않는다', (
    tester,
  ) async {
    final server = _Server(
      respond: (request, _) =>
          request.method == 'PATCH' ? _updateResult(request) : null,
    );
    await _withApp(tester, server, () async {
      await _openCategoryEdit(tester);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('카테고리 이름을 입력해 주세요.'), findsOneWidget);
      final over = '${'가' * 39}😀나';
      await tester.enterText(find.byType(TextField), over);
      await tester.pump();
      expect(find.text('이름은 40자 이내로 입력해 주세요.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        over,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '수정하기'))
            .onPressed,
        isNull,
      );
      expect(_updates(server), isEmpty);
      final valid = '${'가' * 39}😀';
      await tester.enterText(find.byType(TextField), '  $valid  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
      await tester.pumpAndSettle();
      expect(jsonDecode(_updates(server).single.body)['name'], valid);
      expect(find.byType(CategoryFormSheet), findsNothing);
    });
  });

  for (final failure in [
    'network',
    '500',
    'JSON',
    'missing',
    'wrong-target',
    'conflict',
  ]) {
    testWidgets('수정 $failure 응답은 미확인으로 유지하고 닫기 전에 확인한다', (tester) async {
      final server = _Server(
        respond: (request, _) {
          if (request.method != 'PATCH') return null;
          return switch (failure) {
            'network' => throw http.ClientException('offline'),
            '500' => _json({'detail': 'Server failed'}, 500),
            'JSON' => http.Response('{broken', 200),
            'missing' => _json({
              ..._category,
              ...jsonDecode(request.body) as Map,
            }),
            'wrong-target' => _json({
              ..._category,
              ...jsonDecode(request.body) as Map,
              'id': 202,
              'submission': {
                'key': request.headers['Idempotency-Key'],
                'status': 'succeeded',
                'replayed': false,
              },
            }),
            _ => _json({
              'detail': 'input mismatch',
              'code': 'category_submission_conflict',
            }, 409),
          };
        },
      );
      await _withApp(tester, server, () async {
        await _openCategoryEdit(tester);
        await tester.enterText(find.byType(TextField), '유지할 수정 초안');
        await tester.tap(find.widgetWithText(FilledButton, '수정하기'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '유지할 수정 초안',
        );
        expect(_categoryItem(_archive(tester)).name, '공부');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('입력 창을 닫을까요?'), findsOneWidget);
        await tester.tap(find.text('계속 확인하기'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '닫기'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryFormSheet), findsNothing);
        expect(_updates(server), hasLength(1));
      });
    });
  }

  testWidgets('카테고리 생성은 실제 시트에서 성공을 확인한 뒤 닫는다', (tester) async {
    final pending = Completer<http.Response?>();
    final server = _Server(
      respond: (request, _) =>
          request.url.path == '/api/v1/categories' && request.method == 'POST'
          ? pending.future
          : null,
    );
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      _archive(tester).onTabChanged(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('archive-category-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-form-input')),
        '취업 준비',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
      await tester.pump();
      expect(find.byType(CategoryFormSheet), findsOneWidget);
      expect(find.text('저장하고 있어요.'), findsOneWidget);
      final posted = server.calls('/api/v1/categories').last;
      pending.complete(
        _json({
          'id': 404,
          'name': '취업 준비',
          'color': jsonDecode(posted.body)['color'],
          'is_default': false,
          'submission': {
            'key': posted.headers['Idempotency-Key'],
            'status': 'succeeded',
            'replayed': false,
          },
        }, 201),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsNothing);
    });
  });

  testWidgets('생성 전체 10초 뒤에는 초안을 잠그고 같은 제출로 결과를 다시 확인한다', (tester) async {
    final first = Completer<http.Response?>();
    var writes = 0;
    final server = _Server(
      respond: (request, _) {
        if (request.url.path != '/api/v1/categories' ||
            request.method != 'POST') {
          return null;
        }
        writes++;
        return writes == 1
            ? first.future
            : _createResult(request, replayed: true);
      },
    );
    await _withApp(tester, server, () async {
      await _openCategoryCreate(tester);
      await tester.enterText(
        find.byKey(const ValueKey('category-form-input')),
        '  보존할 이름  ',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tapAt(const Offset(10, 10));
      await tester.drag(
        find.byKey(const ValueKey('category-form-handle')),
        const Offset(0, 120),
      );
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('저장하고 있어요.'), findsOneWidget);
      expect(_creates(server), hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('category-form-input')),
      );
      expect(input.controller!.text, '  보존할 이름  ');
      expect(input.readOnly, isTrue);
      expect(jsonDecode(_creates(server).single.body)['name'], '보존할 이름');
      // A response after the attempt deadline cannot close or rewrite the sheet.
      first.complete(_createResult(_creates(server).single));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '결과 다시 확인'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(_creates(server), hasLength(2));
      expect(
        _creates(server).last.headers['Idempotency-Key'],
        _creates(server).first.headers['Idempotency-Key'],
      );
      expect(_creates(server).last.body, _creates(server).first.body);
    });
  });

  testWidgets('명확한 생성 거절은 이름과 색상을 유지하고 수정 후 새 제출을 보낸다', (tester) async {
    var writes = 0;
    final server = _Server(
      respond: (request, _) {
        if (request.url.path != '/api/v1/categories' ||
            request.method != 'POST') {
          return null;
        }
        if (++writes > 1) return _createResult(request);
        return _json({
          'detail': 'Category already exists',
          'code': 'category_name_exists',
          'submission': {
            'key': request.headers['Idempotency-Key'],
            'status': 'rejected',
            'replayed': false,
          },
        }, 409);
      },
    );
    await _withApp(tester, server, () async {
      await _openCategoryCreate(tester);
      final palette = tester.widget<FolderColorPicker>(
        find.byKey(const ValueKey('category-form-palette')),
      );
      palette.onChanged(FolderColorPicker.colors[3]);
      await tester.enterText(
        find.byKey(const ValueKey('category-form-input')),
        '중복 이름',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
      await tester.pumpAndSettle();
      expect(find.text('같은 이름의 카테고리가 있어요. 다른 이름을 입력해 주세요.'), findsOneWidget);
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('category-form-input')),
      );
      expect(input.controller!.text, '중복 이름');
      expect(input.readOnly, isFalse);
      expect(
        tester
            .widget<FolderColorPicker>(
              find.byKey(const ValueKey('category-form-palette')),
            )
            .selectedColor,
        FolderColorPicker.colors[3],
      );
      await tester.enterText(
        find.byKey(const ValueKey('category-form-input')),
        '새 이름',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(_creates(server), hasLength(2));
      expect(
        _creates(server).last.headers['Idempotency-Key'],
        isNot(_creates(server).first.headers['Idempotency-Key']),
      );
    });
  });

  testWidgets('생성 이름은 초과 붙여넣기와 한글 조합을 보존하고 공백 제거 뒤 40자를 검사한다', (tester) async {
    final server = _Server();
    await _withApp(tester, server, () async {
      await _openCategoryCreate(tester);
      expect(find.byKey(const ValueKey('category-form-error')), findsNothing);
      final input = find.byKey(const ValueKey('category-form-input'));
      final longName = List.filled(41, '😀').join();
      await tester.enterText(input, longName);
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, longName);
      expect(find.text('이름은 40자 이내로 입력해 주세요.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '생성하기'))
            .onPressed,
        isNull,
      );
      await tester.enterText(input, '');
      await tester.pump();
      expect(find.text('카테고리 이름을 입력해 주세요.'), findsOneWidget);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '한ㄱ',
          composing: TextRange(start: 1, end: 2),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(input).controller!.value.composing,
        const TextRange(start: 1, end: 2),
      );
      final valid = List.filled(40, '😀').join();
      await tester.enterText(input, ' $valid ');
      await tester.pump();
      expect(find.byKey(const ValueKey('category-form-error')), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
      await tester.pumpAndSettle();
      expect(jsonDecode(_creates(server).single.body)['name'], valid);
      expect(find.byType(CategoryFormSheet), findsNothing);
    });
  });

  testWidgets('생성은 인증 갱신과 재요청을 합쳐 전체 10초만 기다린다', (tester) async {
    final denied = Completer<http.Response?>();
    final refresh = Completer<http.Response?>();
    final retried = Completer<http.Response?>();
    var writes = 0;
    final server = _Server(
      respond: (request, _) {
        if (request.url.path == '/api/v1/auth/refresh') return refresh.future;
        if (request.url.path == '/api/v1/categories' &&
            request.method == 'POST') {
          return ++writes == 1 ? denied.future : retried.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openCategoryCreate(tester);
      await tester.enterText(
        find.byKey(const ValueKey('category-form-input')),
        '인증 중 보존',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
      await tester.pump(const Duration(seconds: 4));
      denied.complete(_json({'detail': 'expired'}, 401));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      refresh.complete(
        _json({
          'access_token': 'rotated-access',
          'refresh_token': 'rotated-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
        }),
      );
      await tester.pump();
      await tester.pump();
      expect(_creates(server), hasLength(2));
      expect(
        _creates(server).first.headers['Idempotency-Key'],
        _creates(server).last.headers['Idempotency-Key'],
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
      retried.complete(_createResult(_creates(server).last));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
    });
  });

  testWidgets('관리 화면 생성도 성공 뒤 후속 목록을 기다리지 않고 닫는다', (tester) async {
    final read = Completer<http.Response?>();
    var stored = false;
    final server = _Server(
      respond: (request, _) {
        if (request.url.path != '/api/v1/categories') return null;
        if (request.method == 'POST') {
          stored = true;
          return _createResult(request);
        }
        return stored ? read.future : null;
      },
    );
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      _archive(tester).onOpenCategoryManagement!();
      await tester.pumpAndSettle();
      expect(find.byType(CategoryManagementScreen), findsOneWidget);
      await tester.tap(find.byTooltip('카테고리 추가'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-form-input')),
        '관리에서 생성',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(_creates(server), hasLength(1));
      read.complete(_json(_allCategories));
      await tester.pumpAndSettle();
    });
  });

  for (final failure in [
    'network',
    '500',
    'JSON',
    'missing',
    'mismatch',
    'invalid-success',
  ]) {
    testWidgets('생성 $failure 응답은 미확인으로 남기고 직접 닫기 전에 확인한다', (tester) async {
      final server = _Server(
        respond: (request, _) {
          if (request.url.path != '/api/v1/categories' ||
              request.method != 'POST') {
            return null;
          }
          return switch (failure) {
            'network' => throw http.ClientException('offline'),
            '500' => _json({'detail': 'Server failed'}, 500),
            'JSON' => http.Response('{broken', 201),
            'missing' => _json({
              'id': 404,
              'name': '입력 유지',
              'color': '#FF6277',
              'is_default': false,
            }, 201),
            'mismatch' => _json({
              'submission': {
                'key': 'another-key',
                'status': 'succeeded',
                'replayed': false,
              },
            }, 201),
            _ => _json({
              'id': 0,
              'name': '입력 유지',
              'color': '#FF6277',
              'is_default': false,
              'submission': {
                'key': request.headers['Idempotency-Key'],
                'status': 'succeeded',
                'replayed': false,
              },
            }, 201),
          };
        },
      );
      await _withApp(tester, server, () async {
        await _openCategoryCreate(tester);
        await tester.enterText(
          find.byKey(const ValueKey('category-form-input')),
          '입력 유지',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, '생성하기'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('category-form-input')),
              )
              .controller!
              .text,
          '입력 유지',
        );
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('입력 창을 닫을까요?'), findsOneWidget);
        await tester.tap(find.text('계속 확인하기'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryFormSheet), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '닫기'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryFormSheet), findsNothing);
        expect(_creates(server), hasLength(1));
      });
    });
  }

  testWidgets(
    'delete confirmation explains preserved content and uncategorized fallback',
    (tester) async {
      await _withApp(tester, _Server(), () async {
        await _openArchive(tester);
        final screen = _archive(tester);
        final context = tester.element(find.byType(ArchiveScreen));
        unawaited(
          showDialog<void>(
            context: context,
            builder: (_) => CategoryDeleteDialog(
              category: _categoryItem(screen),
              onDelete: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('콘텐츠도 함께 삭제'), findsNothing);
        expect(find.textContaining('미분류'), findsWidgets);
      });
    },
  );

  testWidgets(
    'pending category delete keeps home content and bookmark membership',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.method == 'DELETE' ? pending.future : null,
      );
      server.records.first['is_favorite'] = true;
      await _withApp(tester, server, () async {
        final before = _home(tester).contents.map((item) => item.id).toList();
        final favorites = Set<String>.of(_home(tester).bookmarkedIds);
        await _openArchive(tester);
        final screen = _archive(tester);
        screen.onDeleteCategory(_categoryItem(screen));
        screen.onTab(AppRoute.home);
        await tester.pump();
        final duringIds = _home(
          tester,
        ).contents.map((item) => item.id).toList();
        final duringFavorites = Set<String>.of(_home(tester).bookmarkedIds);
        pending.complete(_json({'detail': '삭제 실패'}, 503));
        await tester.pumpAndSettle();
        expect(duringIds, before);
        expect(duringFavorites, favorites);
      });
    },
  );

  testWidgets(
    'failed category delete leaves the original feed ordering intact',
    (tester) async {
      final server = _Server(
        respond: (request, _) =>
            request.method == 'DELETE' ? _json({'detail': '삭제 실패'}, 503) : null,
      );
      server.records[1]['categories'] = [_otherCategory];
      await _withApp(tester, server, () async {
        final before = _home(tester).contents.map((item) => item.id).toList();
        await _openArchive(tester);
        final screen = _archive(tester);
        screen.onDeleteCategory(_categoryItem(screen));
        await tester.pumpAndSettle();
        _archive(tester).onTab(AppRoute.home);
        await tester.pumpAndSettle();
        expect(_home(tester).contents.map((item) => item.id).toList(), before);
      });
    },
  );

  testWidgets('duplicate stale delete callbacks send one category deletion', (
    tester,
  ) async {
    final pending = Completer<http.Response?>();
    final server = _Server(
      respond: (request, _) =>
          request.method == 'DELETE' ? pending.future : null,
    );
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      final screen = _archive(tester);
      final target = _categoryItem(screen);
      screen.onDeleteCategory(target);
      screen.onDeleteCategory(target);
      await tester.pump();
      final count = _deletes(server).length;
      pending.complete(_json({'detail': '삭제 실패'}, 503));
      await tester.pumpAndSettle();
      expect(count, 1);
    });
  });

  testWidgets(
    'confirmation closes and both folder surfaces show pending without disabling navigation',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.method == 'DELETE' ? pending.future : null,
      );
      await _withApp(tester, server, () async {
        _home(tester).onOpenCategories();
        await tester.pumpAndSettle();
        final row = tester
            .widgetList<CategoryRow>(find.byType(CategoryRow))
            .singleWhere((row) => row.category.id == 101);
        row.onMore!();
        await tester.pumpAndSettle();
        tester
            .widget<CategoryActionSheet>(find.byType(CategoryActionSheet))
            .onDelete();
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '삭제'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryDeleteDialog), findsNothing);
        expect(find.text('삭제 중…'), findsOneWidget);
        final during = tester
            .widgetList<CategoryRow>(find.byType(CategoryRow))
            .singleWhere((row) => row.category.id == 101);
        expect(_moreTap(tester, 101), isNull);
        expect(during.onTap, isNotNull);
        during.onTap!();
        await tester.pumpAndSettle();
        expect(_archive(tester).contents, hasLength(3));
        _archive(tester).onTab(AppRoute.my);
        await tester.pumpAndSettle();
        tester
            .widget<MyScreen>(find.byType(MyScreen))
            .onOpenCategoryManagement();
        await tester.pumpAndSettle();
        expect(find.text('삭제 중…'), findsOneWidget);
        expect(_moreTap(tester, 101), isNull);
        pending.complete(_json({'detail': '삭제 실패'}, 503));
        await tester.pumpAndSettle();
        expect(find.text('삭제 중…'), findsNothing);
        expect(_moreTap(tester, 101), isNotNull);
      });
    },
  );

  testWidgets(
    'successful deletion preserves every content and unrelated field with complete categories',
    (tester) async {
      final server = _Server();
      server.records[0].addAll({
        'is_favorite': true,
        'summary_status': 'processing',
        'tags': [
          {'id': 71, 'name': '보존 태그'},
        ],
        'assets': [
          {
            'id': 91,
            'asset_type': 'screenshot',
            'download_url': '/api/v1/assets/91',
            'mime_type': 'image/png',
          },
        ],
      });
      server.records[1]['categories'] = [_category, _otherCategory];
      server.records[2]['categories'] = [_otherCategory, _category];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final screen = _archive(tester);
        final beforeIds = screen.contents.map((item) => item.id).toList();
        screen.onDeleteCategory(_categoryItem(screen));
        await tester.pumpAndSettle();
        final after = _archive(tester);
        expect(after.contents.map((item) => item.id).toList(), beforeIds);
        expect(after.categories.any((category) => category.id == 101), isFalse);
        expect(after.contents.map(_categoryIds).toList(), [
          [303],
          [202],
          [202],
        ]);
        expect(after.contents.map((item) => item.category.id).toList(), [
          303,
          202,
          202,
        ]);
        expect(after.contents.first.bookmarked, isTrue);
        expect(after.bookmarkedIds, contains('api-3'));
        expect(after.contents.first.assets.single.id, 91);
        expect(after.contents.first.summaryStatus, 'processing');
        expect(after.contents.first.tags, ['보존 태그']);
        expect(after.contents.first.originalUrl, 'https://example.com/feed/1');
        expect(
          server.requests.where(
            (request) =>
                request.method == 'DELETE' &&
                request.url.path.startsWith('/api/v1/contents/'),
          ),
          isEmpty,
        );
      });
    },
  );

  testWidgets(
    'success immediately fixes an open detail beyond the first page while reload fails',
    (tester) async {
      var deleted = false;
      final server = _Server(
        count: 25,
        respond: (request, _) {
          if (request.method == 'DELETE') {
            deleted = true;
          }
          if (deleted &&
              (request.url.path == _feed ||
                  request.url.path == '/api/v1/categories')) {
            return _json({'detail': '재조회 실패'}, 503);
          }
          return null;
        },
      );
      server.records.last['categories'] = [_category, _otherCategory];
      server.records.last['is_favorite'] = true;
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final delete = _archive(tester).onDeleteCategory;
        final target = _categoryItem(_archive(tester));
        await _archive(tester).onLoadMore!();
        await tester.pumpAndSettle();
        _archive(tester).onOpenContent(_archive(tester).contents.last);
        await tester.pumpAndSettle();
        expect(_detail(tester).content.apiId, 1);
        delete(target);
        await tester.pumpAndSettle();
        expect(_detail(tester).content.apiId, 1);
        expect(_categoryIds(_detail(tester).content), [202]);
        expect(_detail(tester).content.bookmarked, isTrue);
        expect(
          _detail(tester).categories.any((category) => category.id == 101),
          isFalse,
        );
        expect(_deletes(server), hasLength(1));
      });
    },
  );

  for (final failure in [
    '401',
    '403',
    '404',
    '409',
    '503',
    'network',
    'JSON',
  ]) {
    testWidgets(
      failure == '401'
          ? 'category delete final 401 returns to login without a replacement guest'
          : 'delete $failure preserves order account and favorites then permits manual retry',
      (tester) async {
        var fail = true;
        final server = _Server(
          respond: (request, _) =>
              request.method == 'DELETE' && fail ? _failure(failure) : null,
        );
        server.records[0]['is_favorite'] = true;
        server.records[1]['categories'] = [_otherCategory];
        await _withApp(tester, server, () async {
          await _openArchive(tester);
          final before = _archive(tester);
          final ids = before.contents.map((item) => item.id).toList();
          final favorites = Set<String>.of(before.bookmarkedIds);
          before.onDeleteCategory(_categoryItem(before));
          await tester.pumpAndSettle();
          if (failure == '401') {
            expect(find.byType(LoginScreen), findsOneWidget);
            expect(server.calls('/api/v1/auth/guest'), isEmpty);
            expect(_deletes(server), hasLength(2));
            expect(await ApiSessionStorage().read(), isNull);
            return;
          }
          final after = _archive(tester);
          expect(after.contents.map((item) => item.id).toList(), ids);
          expect(after.bookmarkedIds, favorites);
          expect(
            after.categories.where((category) => category.id == 101),
            hasLength(1),
          );
          expect(find.byType(SnackBar), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(server.calls('/api/v1/auth/guest'), isEmpty);
          final attempts = _deletes(server).length;
          expect(attempts, failure == '401' ? 2 : 1);
          fail = false;
          after.onDeleteCategory(_categoryItem(after));
          await tester.pumpAndSettle();
          expect(_deletes(server), hasLength(attempts + 1));
          expect(
            _archive(tester).categories.any((category) => category.id == 101),
            isFalse,
          );
        });
      },
    );
  }

  testWidgets(
    'deleted active archive filter becomes all content with a fresh cursor',
    (tester) async {
      final server = _Server(count: 25);
      server.records.last['categories'] = [_otherCategory];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        _archive(tester).onOpenCategory(_categoryItem(_archive(tester)));
        await tester.pumpAndSettle();
        await _archive(tester).onLoadMore!();
        await tester.pumpAndSettle();
        expect(_archive(tester).contents, hasLength(24));
        final before = server.feedCalls.length;
        _archive(tester).onDeleteCategory(_categoryItem(_archive(tester)));
        await tester.pumpAndSettle();
        final after = _archive(tester);
        expect(after.activeCategoryName, isNull);
        expect(after.activeTab, 0);
        expect(after.feed!.categoryId, isNull);
        expect(after.contents, hasLength(20));
        expect(
          server.feedCalls
              .skip(before)
              .every(
                (request) =>
                    !request.url.queryParameters.containsKey('category_id') &&
                    !request.url.queryParameters.containsKey('cursor'),
              ),
          isTrue,
        );
      });
    },
  );

  testWidgets(
    'deleted active home filter is cleared without switching away from home',
    (tester) async {
      final server = _Server();
      server.records.last['categories'] = [_otherCategory];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final delete = _archive(tester).onDeleteCategory;
        final target = _categoryItem(_archive(tester));
        _archive(tester).onTab(AppRoute.home);
        await tester.pumpAndSettle();
        _home(tester).onCategorySelected!(target);
        await tester.pumpAndSettle();
        expect(_home(tester).contents, hasLength(2));
        delete(target);
        await tester.pumpAndSettle();
        expect(_home(tester).activeCategoryId, isNull);
        expect(_home(tester).contents, hasLength(3));
      });
    },
  );

  testWidgets(
    'switching to another filter during deletion preserves that filter and favorite sort',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.method == 'DELETE' ? pending.future : null,
      );
      server.records.last['categories'] = [_otherCategory];
      server.records.last['is_favorite'] = true;
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final original = _archive(tester);
        original.onOpenCategory(_categoryItem(original));
        await tester.pumpAndSettle();
        _archive(tester).onDeleteCategory(_categoryItem(_archive(tester)));
        _archive(tester).onOpenCategory(_categoryItem(_archive(tester), 202));
        _archive(tester).onSortChanged(true);
        await tester.pumpAndSettle();
        pending.complete(null);
        await tester.pumpAndSettle();
        expect(_archive(tester).activeCategoryName, '여행');
        expect(_archive(tester).feed!.categoryId, 202);
        expect(_archive(tester).bookmarkedFirst, isTrue);
        expect(_archive(tester).contents.single.apiId, 1);
      });
    },
  );

  testWidgets(
    'search and favorite feeds keep their own conditions after category removal',
    (tester) async {
      final server = _Server();
      server.records.first['is_favorite'] = true;
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final delete = _archive(tester).onDeleteCategory;
        final target = _categoryItem(_archive(tester));
        _archive(tester).onTab(AppRoute.bookmark);
        await tester.pumpAndSettle();
        tester.widget<BookmarkScreen>(find.byType(BookmarkScreen)).onSearch();
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '항목 1');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        final before = server.feedCalls.length;
        delete(target);
        await tester.pumpAndSettle();
        expect(find.byType(SearchScreen), findsOneWidget);
        expect(find.text('피드 항목 1'), findsOneWidget);
        expect(
          server.feedCalls
              .skip(before)
              .any((request) => request.url.queryParameters['q'] == '항목 1'),
          isTrue,
        );
        expect(
          server.feedCalls
              .skip(before)
              .any(
                (request) =>
                    request.url.queryParameters['is_favorite'] == 'true',
              ),
          isTrue,
        );
        expect(
          server.feedCalls
              .skip(before)
              .every(
                (request) => request.url.queryParameters['cursor'] == null,
              ),
          isTrue,
        );
      });
    },
  );

  for (final first in ['delete', 'rename']) {
    testWidgets(
      'pending $first rejects same-category writes but allows another category and content',
      (tester) async {
        final pending = Completer<http.Response?>();
        final server = _Server(
          respond: (request, _) => request.url.path == '/api/v1/categories/101'
              ? pending.future
              : null,
        );
        await _withApp(tester, server, () async {
          await _openArchive(tester);
          final screen = _archive(tester);
          final target = _categoryItem(screen);
          final other = _categoryItem(screen, 202);
          if (first == 'delete') {
            screen.onDeleteCategory(target);
          } else {
            screen.onUpdateCategory(target, target.copyWith(name: '수정 중'));
          }
          screen.onDeleteCategory(target);
          screen.onUpdateCategory(target, target.copyWith(name: '중복 수정'));
          screen.onUpdateCategory(other, other.copyWith(name: '다른 분류 수정'));
          screen.onToggleBookmark(screen.contents.first);
          await tester.pump();
          final sameCalls = server.calls('/api/v1/categories/101').length;
          pending.complete(_json({'detail': '처리 실패'}, 503));
          await tester.pumpAndSettle();
          expect(sameCalls, 1);
          expect(server.calls('/api/v1/categories/202'), hasLength(1));
          expect(server.calls('/api/v1/contents/3/favorite'), hasLength(1));
          expect(_categoryItem(_archive(tester), 202).name, '다른 분류 수정');
          expect(_archive(tester).contents.first.bookmarked, isTrue);
        });
      },
    );
  }

  testWidgets(
    'stale rename callback rolls back to the latest category name and preserves secondary membership',
    (tester) async {
      var fail = false;
      final server = _Server(
        respond: (request, _) => request.method == 'PATCH' && fail
            ? _json({'detail': '수정 실패'}, 503)
            : null,
      );
      server.records.first['categories'] = [_otherCategory, _category];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final old = _archive(tester);
        final original = _categoryItem(old);
        old.onUpdateCategory(original, original.copyWith(name: '최신 이름'));
        await tester.pumpAndSettle();
        fail = true;
        old.onUpdateCategory(original, original.copyWith(name: '실패 이름'));
        await tester.pumpAndSettle();
        expect(_categoryItem(_archive(tester)).name, '최신 이름');
        expect(_categoryIds(_archive(tester).contents.first), [202, 101]);
        expect(_archive(tester).contents.first.categories.last.name, '최신 이름');
      });
    },
  );

  testWidgets(
    'old feed and detail replies cannot resurrect deleted primary or secondary categories',
    (tester) async {
      final oldFeed = Completer<http.Response?>();
      final oldDetail = Completer<http.Response?>();
      var hold = false;
      http.Response? feedSnapshot;
      http.Response? detailSnapshot;
      final server = _Server(
        respond: (request, server) {
          if (hold &&
              request.url.path == _feed &&
              request.url.queryParameters['category_id'] == '202') {
            feedSnapshot ??= server.page(request);
            return oldFeed.future;
          }
          if (hold &&
              request.url.path == '/api/v1/contents/3' &&
              request.method == 'GET') {
            detailSnapshot ??= _json(server.records.first);
            return oldDetail.future;
          }
          return null;
        },
      );
      server.records.first['categories'] = [_category, _otherCategory];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final old = _archive(tester);
        final content = old.contents.first;
        hold = true;
        old.onOpenCategory(_categoryItem(old, 202));
        old.onOpenContent(content);
        await tester.pump();
        old.onDeleteCategory(_categoryItem(old));
        hold = false;
        await tester.pumpAndSettle();
        oldFeed.complete(feedSnapshot);
        oldDetail.complete(detailSnapshot);
        await tester.pumpAndSettle();
        expect(_categoryIds(_detail(tester).content), [202]);
        expect(
          _detail(tester).categories.any((category) => category.id == 101),
          isFalse,
        );
        _detail(tester).onBack();
        await tester.pumpAndSettle();
        expect(
          _archive(
            tester,
          ).contents.every((item) => !_categoryIds(item).contains(101)),
          isTrue,
        );
      });
    },
  );

  for (final action in ['favorite success', 'category failure']) {
    testWidgets('late $action cannot reintroduce a deleted category', (
      tester,
    ) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.method == 'PUT' ? pending.future : null,
      );
      server.records.first['categories'] = [_category, _otherCategory];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final screen = _archive(tester);
        final response = _json({...server.records.first, 'is_favorite': true});
        if (action == 'favorite success') {
          screen.onToggleBookmark(screen.contents.first);
        } else {
          screen.onChangeContentCategory(
            screen.contents.first,
            _categoryItem(screen, 202),
          );
        }
        screen.onDeleteCategory(_categoryItem(screen));
        await tester.pumpAndSettle();
        if (action == 'favorite success') {
          server.records.first['is_favorite'] = true;
        }
        pending.complete(
          action == 'favorite success'
              ? response
              : _json({'detail': '분류 변경 실패'}, 503),
        );
        await tester.pumpAndSettle();
        final after = _archive(tester).contents.first;
        expect(_categoryIds(after), [202]);
        expect(after.category.id, 202);
        expect(after.bookmarked, action == 'favorite success');
        expect(
          _archive(tester).categories.any((category) => category.id == 101),
          isFalse,
        );
      });
    });
  }

  testWidgets(
    'an older category-list response after another write cannot resurrect a deleted folder',
    (tester) async {
      final oldCategories = Completer<http.Response?>();
      var hold = false;
      var held = false;
      final server = _Server(
        respond: (request, _) {
          if (request.url.path == '/api/v1/categories' && hold && !held) {
            held = true;
            return oldCategories.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final screen = _archive(tester);
        final snapshot = _json(server.categories);
        hold = true;
        screen.onToggleBookmark(screen.contents.first);
        await tester.pump();
        expect(held, isTrue);
        screen.onDeleteCategory(_categoryItem(screen));
        await tester.pumpAndSettle();
        oldCategories.complete(snapshot);
        await tester.pumpAndSettle();
        expect(
          _archive(tester).categories.any((category) => category.id == 101),
          isFalse,
        );
        expect(
          _archive(
            tester,
          ).contents.every((item) => !_categoryIds(item).contains(101)),
          isTrue,
        );
      });
    },
  );

  for (final action in ['delete', 'rename']) {
    for (final outcome in ['success', 'failure']) {
      testWidgets(
        'old-account $action $outcome cannot change the replacement account or show an error',
        (tester) async {
          final pending = Completer<http.Response?>();
          final server = _Server(
            respond: (request, _) =>
                request.url.path == '/api/v1/categories/101'
                ? pending.future
                : null,
          );
          await _withApp(tester, server, () async {
            await _openArchive(tester);
            final screen = _archive(tester);
            final target = _categoryItem(screen);
            if (action == 'delete') {
              screen.onDeleteCategory(target);
            } else {
              screen.onUpdateCategory(target, target.copyWith(name: '옛 계정 수정'));
            }
            await tester.pump();
            await _newAccount(tester, server, screen.onTab);
            pending.complete(
              outcome == 'failure'
                  ? _json({'detail': '옛 계정 오류'}, 503)
                  : action == 'delete'
                  ? http.Response('', 204)
                  : _json({..._category, 'name': '옛 계정 수정'}),
            );
            await tester.pumpAndSettle();
            expect(_detail(tester).content.apiId, 1001);
            expect(_categoryIds(_detail(tester).content), [101]);
            expect(_detail(tester).content.category.name, '공부');
            expect(find.text('옛 계정 오류'), findsNothing);
            expect(tester.takeException(), isNull);
            expect(server.calls('/api/v1/auth/guest'), hasLength(1));
          });
        },
      );
    }
  }

  testWidgets(
    'deleting a folder never blocks a later category with the same name and a new ID',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        _archive(tester).onDeleteCategory(_categoryItem(_archive(tester)));
        await tester.pumpAndSettle();
        server.categories.add({..._category, 'id': 404});
        server.records.first['categories'] = [
          {..._category, 'id': 404},
        ];
        _archive(tester).onToggleBookmark(_archive(tester).contents.last);
        await tester.pumpAndSettle();
        expect(_categoryItem(_archive(tester), 404).name, '공부');
        expect(_categoryIds(_archive(tester).contents.first), [404]);
      });
    },
  );

  testWidgets('older category metadata cannot undo a completed rename', (
    tester,
  ) async {
    final pending = Completer<http.Response?>();
    var hold = false;
    var held = false;
    final server = _Server(
      respond: (request, _) {
        if (request.url.path == '/api/v1/categories' && hold && !held) {
          held = true;
          return pending.future;
        }
        return null;
      },
    );
    await _withApp(tester, server, () async {
      await _openArchive(tester);
      final screen = _archive(tester);
      final before = _json(server.categories);
      final category = _categoryItem(screen);
      hold = true;
      screen.onToggleBookmark(screen.contents.first);
      await tester.pump();
      expect(held, isTrue);
      screen.onUpdateCategory(
        category,
        category.copyWith(name: '확정한 이름', color: Colors.blue),
      );
      await tester.pump();
      expect(_categoryItem(_archive(tester)).name, '확정한 이름');
      pending.complete(before);
      await tester.pumpAndSettle();
      expect(_categoryItem(_archive(tester)).name, '확정한 이름');
      expect(_archive(tester).contents.first.category.name, '확정한 이름');
    });
  });

  testWidgets(
    'failed content-category rollback keeps a newer folder name and color',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.method == 'PUT' ? pending.future : null,
      );
      server.records.first['categories'] = [_category, _otherCategory];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final old = _archive(tester);
        final original = _categoryItem(old);
        old.onChangeContentCategory(
          old.contents.first,
          _categoryItem(old, 202),
        );
        await tester.pump();
        old.onUpdateCategory(
          original,
          original.copyWith(name: '최신 분류', color: Colors.blue),
        );
        await tester.pumpAndSettle();
        pending.complete(_json({'detail': '콘텐츠 분류 실패'}, 503));
        await tester.pumpAndSettle();
        final content = _archive(tester).contents.first;
        expect(_categoryIds(content), [101, 202]);
        expect(_categoryItem(_archive(tester)).name, '최신 분류');
        expect(content.category.name, '최신 분류');
        expect(content.category.color, _categoryItem(_archive(tester)).color);
      });
    },
  );

  testWidgets(
    'content copyWith preserves full category membership and unrelated server fields',
    (tester) async {
      final server = _Server();
      server.records.first.addAll({
        'categories': [_category, _otherCategory],
        'summary_status': 'processing',
        'tags': [
          {'id': 71, 'name': '보존 태그'},
        ],
        'assets': [
          {
            'id': 91,
            'asset_type': 'screenshot',
            'download_url': '/api/v1/assets/91',
          },
        ],
      });
      await _withApp(tester, server, () async {
        final content = _home(tester).contents.first;
        final favorite = content.copyWith(bookmarked: true);
        expect(_categoryIds(favorite), [101, 202]);
        expect(
          _categoryIds(favorite.copyWith(category: content.categories.last)),
          [202],
        );
        expect(
          _categoryIds(
            favorite.copyWith(categories: content.categories.reversed.toList()),
          ),
          [202, 101],
        );
        expect(
          favorite
              .copyWith(categories: content.categories.reversed.toList())
              .category
              .id,
          202,
        );
        expect(favorite.assets.single.id, 91);
        expect(favorite.summaryStatus, 'processing');
        expect(favorite.tags, ['보존 태그']);
        expect(() => favorite.categories.clear(), throwsUnsupportedError);
      });
    },
  );

  testWidgets(
    'pending and completed deletion reject stale content category selection and repeat deletion',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.method == 'DELETE' ? pending.future : null,
      );
      server.records.first['categories'] = [_otherCategory];
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final old = _archive(tester);
        final target = _categoryItem(old);
        final content = old.contents.first;
        old.onDeleteCategory(target);
        old.onChangeContentCategory(content, target);
        await tester.pump();
        expect(server.calls('/api/v1/contents/3/categories'), isEmpty);
        pending.complete(null);
        await tester.pumpAndSettle();
        old.onDeleteCategory(target);
        old.onUpdateCategory(target, target.copyWith(name: '사라진 분류 수정'));
        old.onChangeContentCategory(content, target);
        await tester.pumpAndSettle();
        expect(_deletes(server), hasLength(1));
        expect(
          server.requests.where((request) => request.method == 'PATCH'),
          isEmpty,
        );
        expect(server.calls('/api/v1/contents/3/categories'), isEmpty);
        expect(_categoryIds(_archive(tester).contents.first), [202]);
      });
    },
  );

  testWidgets(
    'uncategorized cannot be deleted or renamed even through captured callbacks',
    (tester) async {
      await _withApp(tester, _Server(), () async {
        await _openArchive(tester);
        final screen = _archive(tester);
        final target = _categoryItem(screen, 303);
        screen.onDeleteCategory(target);
        screen.onUpdateCategory(target, target.copyWith(name: '분류 이름'));
        await tester.pumpAndSettle();
        expect(_categoryItem(_archive(tester), 303).name, target.name);
        expect(_archive(tester).categories, hasLength(3));
        expect(find.byType(SnackBar), findsNothing);
      });
    },
  );

  for (final failure in ['network', 'JSON']) {
    testWidgets(
      'rename $failure restores the latest baseline and unlocks category deletion',
      (tester) async {
        final server = _Server(
          respond: (request, _) =>
              request.method == 'PATCH' ? _failure(failure) : null,
        );
        await _withApp(tester, server, () async {
          await _openArchive(tester);
          final before = _archive(tester);
          final category = _categoryItem(before);
          before.onUpdateCategory(category, category.copyWith(name: '실패 이름'));
          await tester.pumpAndSettle();
          expect(_categoryItem(_archive(tester)).name, '공부');
          expect(_archive(tester).contents.first.category.name, '공부');
          expect(tester.takeException(), isNull);
          expect(find.byType(SnackBar), findsOneWidget);
          _archive(tester).onDeleteCategory(_categoryItem(_archive(tester)));
          await tester.pumpAndSettle();
          expect(_deletes(server), hasLength(1));
          expect(
            _archive(tester).categories.any((category) => category.id == 101),
            isFalse,
          );
        });
      },
    );
  }

  for (final failingRead in ['metadata', 'detail']) {
    testWidgets(
      'delete success with $failingRead failure retries reads without repeating the delete or view event',
      (tester) async {
        var deleted = false;
        var failRead = true;
        final server = _Server(
          respond: (request, _) {
            if (request.method == 'DELETE') {
              deleted = true;
            }
            if (deleted &&
                failRead &&
                request.method == 'GET' &&
                request.url.path ==
                    (failingRead == 'metadata'
                        ? '/api/v1/categories'
                        : '/api/v1/contents/3')) {
              return _json({'detail': '최신 조회 실패'}, 503);
            }
            return null;
          },
        );
        await _withApp(tester, server, () async {
          await _openArchive(tester);
          final before = _archive(tester);
          final target = _categoryItem(before);
          before.onOpenContent(before.contents.first);
          await tester.pumpAndSettle();
          before.onDeleteCategory(target);
          await tester.pumpAndSettle();
          expect(_detail(tester).content.category.id, 303);
          expect(
            _detail(tester).categories.any((category) => category.id == 101),
            isFalse,
          );
          expect(find.text('최신 정보를 불러오지 못했어요.'), findsOneWidget);
          expect(find.text('다시 불러오기'), findsOneWidget);
          final views = server.calls('/api/v1/contents/3/view').length;
          final categoryReads = server.calls('/api/v1/categories').length;
          final detailReads = server.calls('/api/v1/contents/3').length;
          failRead = false;
          await tester.tap(find.text('다시 불러오기'));
          await tester.pumpAndSettle();
          expect(_deletes(server), hasLength(1));
          expect(server.calls('/api/v1/contents/3/view'), hasLength(views));
          expect(
            server.calls('/api/v1/categories').length,
            greaterThan(categoryReads),
          );
          expect(
            server.calls('/api/v1/contents/3').length,
            greaterThan(detailReads),
          );
          expect(_detail(tester).content.category.id, 303);
        });
      },
    );
  }

  for (final outcome in ['success', 'failure']) {
    testWidgets(
      'old-account category creation $outcome cannot affect the new account',
      (tester) async {
        final pending = Completer<http.Response?>();
        final server = _Server(
          respond: (request, _) =>
              request.url.path == '/api/v1/categories' &&
                  request.method == 'POST'
              ? pending.future
              : null,
        );
        await _withApp(tester, server, () async {
          await _openArchive(tester);
          final before = _archive(tester);
          before.onAddCategory(_categoryItem(before).copyWith(name: '옛 계정 신규'));
          await tester.pump();
          await _newAccount(tester, server, before.onTab);
          pending.complete(
            outcome == 'success'
                ? _json({..._category, 'id': 404, 'name': '옛 계정 신규'}, 201)
                : _json({'detail': '옛 계정 생성 실패'}, 503),
          );
          await tester.pumpAndSettle();
          expect(_detail(tester).content.apiId, 1001);
          expect(
            _detail(tester).categories.any((category) => category.id == 404),
            isFalse,
          );
          expect(find.text('옛 계정 생성 실패'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets(
    'a committed delete with a delayed response keeps its pending folder during another content reload',
    (tester) async {
      final pending = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) =>
            request.method == 'DELETE' ? pending.future : null,
      );
      await _withApp(tester, server, () async {
        await _openArchive(tester);
        final before = _archive(tester);
        before.onDeleteCategory(_categoryItem(before));
        await tester.pump();
        server.categories.removeWhere((category) => category['id'] == 101);
        for (final record in server.records) {
          record['categories'] = [_uncategorized];
        }
        before.onToggleBookmark(before.contents.first);
        await tester.pumpAndSettle();
        final during = _archive(tester);
        expect(_categoryItem(during).mutationLabel, '삭제 중…');
        expect(during.contents, hasLength(3));
        expect(during.contents.first.bookmarked, isTrue);
        expect(_deletes(server), hasLength(1));
        pending.complete(http.Response('', 204));
        await tester.pumpAndSettle();
        expect(
          _archive(tester).categories.any((category) => category.id == 101),
          isFalse,
        );
        expect(_archive(tester).contents, hasLength(3));
      });
    },
  );

  testWidgets(
    'delete confirmation stays within the phone width on a wide desktop viewport',
    (tester) async {
      await _withApp(tester, _Server(), () async {
        tester.view.physicalSize = const Size(1600, 900);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(HomeScreen));
        final category = _home(
          tester,
        ).categories.singleWhere((category) => category.id == 101);
        unawaited(
          showDialog<void>(
            context: context,
            builder: (_) =>
                CategoryDeleteDialog(category: category, onDelete: () {}),
          ),
        );
        await tester.pumpAndSettle();
        final dialog = find.byType(CategoryDeleteDialog);
        final surface = find
            .descendant(of: dialog, matching: find.byType(Material))
            .first;
        final bounds = tester.getRect(surface);
        expect(bounds.width, lessThanOrEqualTo(phoneWidth - 64));
        for (final button in [
          find.widgetWithText(OutlinedButton, '취소'),
          find.widgetWithText(FilledButton, '삭제'),
        ]) {
          final buttonBounds = tester.getRect(button);
          expect(buttonBounds.width, greaterThan(0));
          expect(bounds.contains(buttonBounds.topLeft), isTrue);
          expect(bounds.contains(buttonBounds.bottomRight), isTrue);
        }
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining('저장된 콘텐츠는 삭제되지 않아요.'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    },
  );
}
