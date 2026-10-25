import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/logout_confirmation_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/social_auth.dart';
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
  Completer<void>? writeGate;
  @override
  Future<ApiSession?> read() async => session;
  @override
  Future<void> write(ApiSession value) async {
    writes++;
    await writeGate?.future;
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
      case '/api/v1/auth/social/google/upgrade':
        userId++;
        return _json({
          'access_token': 'linked-access',
          'refresh_token': 'linked-refresh',
          'expires_in': 3600,
          'refresh_expires_in': 86400,
          'is_new_user': false,
        });
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
          return _saved(request, categories[0]);
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
      await tester.pumpWidget(
        ClipbackApp(sessionStorage: storage, socialAuth: _SocialAuth()),
      );
      await completeAppStartup(tester);
      await check(storage);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _openForm(WidgetTester tester, {bool edit = false}) async {
  if (find.byType(HomeScreen).evaluate().isNotEmpty) {
    tester.widget<HomeScreen>(find.byType(HomeScreen)).onOpenArchive();
    await tester.pumpAndSettle();
    _archive(tester).onTabChanged(1);
    await tester.pumpAndSettle();
  }
  if (edit) {
    await tester.tap(find.byKey(const ValueKey('archive-category-more-101')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카테고리 수정'));
  } else {
    await tester.tap(find.byKey(const ValueKey('archive-category-add')));
  }
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, {bool edit = false}) async {
  await tester.enterText(
    find.byKey(const ValueKey('category-form-input')),
    '보존할 초안',
  );
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, edit ? '수정하기' : '생성하기'));
  await tester.pumpAndSettle();
}

Future<void> _accountBehindForm(WidgetTester tester) async {
  // Public screen callbacks exercise an account event while the root modal is mounted.
  _archive(tester).onTab(AppRoute.my);
  await tester.pumpAndSettle();
  tester.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
  await tester.pumpAndSettle();
}

http.Response _saved(http.Request request, [Map<String, Object?>? category]) =>
    _json({
      ...?category,
      'id': category?['id'] ?? 404,
      ...jsonDecode(request.body) as Map<String, dynamic>,
      'is_default': false,
      'submission': {
        'key': request.headers['Idempotency-Key'],
        'status': 'succeeded',
        'replayed': false,
      },
    }, request.method == 'POST' ? 201 : 200);

Future<void> _until(
  WidgetTester tester,
  DateTime start,
  int milliseconds,
) async {
  final remaining = start
      .add(Duration(milliseconds: milliseconds))
      .difference(tester.binding.clock.now());
  if (remaining > Duration.zero) await tester.pump(remaining);
  await tester.pump();
}

class _SocialAuth extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders => [
    SocialLoginProvider.google,
  ];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => const SocialCredential(token: 'test-sdk-token');
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.unavailable;
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
  testWidgets('실제 계정 교체는 결과 미확인 시트와 닫기 팝업을 함께 정리한다', (tester) async {
    final server = _Server(
      respond: (request, _) {
        if (request.method == 'POST' && request.url.path == _categories) {
          return _json({'detail': 'unavailable'}, 503);
        }
        return null;
      },
    );
    await _withApp(tester, server, (storage) async {
      await _openForm(tester);
      await _submit(tester);
      expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('입력 창을 닫을까요?'), findsOneWidget);
      await _accountBehindForm(tester);
      await tester
          .widget<AccountManagementScreen>(find.byType(AccountManagementScreen))
          .onConnect();
      await tester.pumpAndSettle();
      await tester
          .widget<LoginScreen>(find.byType(LoginScreen))
          .onSocialLogin(SocialLoginProvider.google);
      await tester.pumpAndSettle();
      expect(storage.session?.accessToken, 'linked-access');
      expect(find.byType(CategoryFormSheet), findsNothing);
      expect(find.text('입력 창을 닫을까요?'), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
  for (final edit in [false, true]) {
    for (final lateStatus in [200, 401]) {
      testWidgets(
        '카테고리10초 뒤 단독 갱신$lateStatus 는 토큰·시트·로그인을 바꾸지 않는다 (edit=$edit)',
        (tester) async {
          final denied = Completer<http.Response?>();
          final refresh = Completer<http.Response?>();
          final server = _Server(
            respond: (request, _) {
              if (request.url.path == _refresh) return refresh.future;
              if (request.method == (edit ? 'PATCH' : 'POST') &&
                  request.url.path.startsWith(_categories)) {
                return denied.future;
              }
              return null;
            },
          );
          await _withApp(tester, server, (storage) async {
            await _openForm(tester, edit: edit);
            final start = tester.binding.clock.now();
            await _submit(tester, edit: edit);
            await _until(tester, start, 4000);
            denied.complete(_json({'detail': 'expired'}, 401));
            await tester.pump();
            expect(server.calls(_refresh), hasLength(1));
            await _until(tester, start, 10001);
            expect(
              find.widgetWithText(FilledButton, '결과 다시 확인'),
              findsOneWidget,
            );
            refresh.complete(
              lateStatus == 200
                  ? _tokens('obsolete')
                  : _json({'detail': 'expired'}, 401),
            );
            await tester.pumpAndSettle();
            expect(storage.writes, 0);
            expect(storage.clears, 0);
            expect(storage.session?.accessToken, 'test-access');
            expect(find.byType(CategoryFormSheet), findsOneWidget);
            expect(find.byType(LoginScreen), findsNothing);
            expect(server.calls('/api/v1/auth/guest'), isEmpty);
            expect(
              server.calls(
                edit ? '$_categories/101' : _categories,
                edit ? 'PATCH' : 'POST',
              ),
              hasLength(1),
            );
          });
        },
      );
    }
  }
  for (final edit in [false, true]) {
    for (final reconfirm in [false, true]) {
      for (final refreshStatus in [200, 503]) {
        testWidgets(
          '카테고리 대기가 끝나도 현재 검색의 공유 갱신$refreshStatus 는 유지된다 (edit=$edit,reconfirm=$reconfirm)',
          (tester) async {
            final denied = Completer<http.Response?>();
            final refresh = Completer<http.Response?>();
            var writes = 0;
            final server = _Server(
              respond: (request, _) {
                if (request.url.path == _refresh) return refresh.future;
                if (request.method == (edit ? 'PATCH' : 'POST') &&
                    request.url.path.startsWith(_categories)) {
                  writes++;
                  if (reconfirm && writes == 1) {
                    return _json({'detail': 'unavailable'}, 503);
                  }
                  return denied.future;
                }
                if (request.url.path == '/api/v1/feed' &&
                    request.url.queryParameters['q'] != null &&
                    request.headers['Authorization'] == 'Bearer test-access') {
                  return _json({'detail': 'expired'}, 401);
                }
                return null;
              },
            );
            await _withApp(tester, server, (storage) async {
              await _openForm(tester, edit: edit);
              if (reconfirm) {
                await _submit(tester, edit: edit);
                expect(
                  find.widgetWithText(FilledButton, '결과 다시 확인'),
                  findsOneWidget,
                );
                await tester.pump(const Duration(milliseconds: 400));
              }
              final start = tester.binding.clock.now();
              if (reconfirm) {
                await tester.tap(find.widgetWithText(FilledButton, '결과 다시 확인'));
                await tester.pumpAndSettle();
              } else {
                await _submit(tester, edit: edit);
              }
              await _until(tester, start, 4000);
              denied.complete(_json({'detail': 'expired'}, 401));
              await tester.pump();
              await _until(tester, start, 7000);
              _archive(tester).onTab(AppRoute.home);
              await tester.pump();
              tester.widget<HomeScreen>(find.byType(HomeScreen)).onSearch();
              await tester.pump();
              final search = tester
                  .widget<SearchScreen>(find.byType(SearchScreen))
                  .onSearch('현재 검색');
              await tester.pump();
              expect(server.calls(_refresh), hasLength(1));
              await _until(tester, start, 10001);
              expect(
                find.widgetWithText(FilledButton, '결과 다시 확인'),
                findsOneWidget,
              );
              refresh.complete(
                refreshStatus == 200
                    ? _tokens('shared')
                    : _json({'detail': 'unavailable'}, 503),
              );
              await tester.pumpAndSettle();
              expect(await search, isEmpty);
              expect(storage.writes, refreshStatus == 200 ? 1 : 0);
              expect(storage.clears, 0);
              expect(
                storage.session?.accessToken,
                refreshStatus == 200 ? 'shared-access' : 'test-access',
              );
              expect(find.byType(CategoryFormSheet), findsOneWidget);
              expect(
                find.widgetWithText(FilledButton, '결과 다시 확인'),
                findsOneWidget,
              );
              expect(server.calls(_refresh), hasLength(1));
              final submitted = server.calls(
                edit ? '$_categories/101' : _categories,
                edit ? 'PATCH' : 'POST',
              );
              expect(submitted, hasLength(reconfirm ? 2 : 1));
              if (reconfirm) {
                expect(submitted.first.body, submitted.last.body);
                expect(
                  submitted.first.headers['Idempotency-Key'],
                  submitted.last.headers['Idempotency-Key'],
                );
              }
              expect(server.calls('/api/v1/auth/guest'), isEmpty);
              expect(
                server.requests.where(
                  (r) =>
                      r.url.queryParameters['q'] == '현재 검색' &&
                      r.headers['Authorization'] == 'Bearer shared-access',
                ),
                hasLength(refreshStatus == 200 ? 1 : 0),
              );
            });
          },
        );
      }
    }
  }
  for (final edit in [false, true]) {
    testWidgets('로그아웃 실패는 미확인 초안·닫기 팝업을 보존하고 완료만 정리한다 (edit=$edit)', (
      tester,
    ) async {
      var failLogout = true;
      final server = _Server(
        respond: (request, _) {
          if (request.method == (edit ? 'PATCH' : 'POST') &&
              request.url.path.startsWith(_categories)) {
            return _json({'detail': 'unavailable'}, 503);
          }
          if (request.url.path == '/api/v1/auth/logout' && failLogout) {
            return _json({'detail': 'unavailable'}, 503);
          }
          return null;
        },
      );
      await _withApp(tester, server, (storage) async {
        await _openForm(tester, edit: edit);
        await _submit(tester, edit: edit);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('입력 창을 닫을까요?'), findsOneWidget);
        await _accountBehindForm(tester);
        final failed = await startLogoutFromAccount(tester);
        await failed.completion;
        await tester.pumpAndSettle();
        expect(storage.clears, 0);
        expect(storage.session?.accessToken, 'test-access');
        expect(find.byType(CategoryFormSheet), findsOneWidget);
        expect(find.text('입력 창을 닫을까요?'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '보존할 초안',
        );
        failLogout = false;
        await tester
            .widget<LogoutConfirmationScreen>(
              find.byType(LogoutConfirmationScreen),
            )
            .onConfirm();
        await tester.pumpAndSettle();
        expect(storage.clears, 1);
        expect(storage.session, isNull);
        expect(find.byType(CategoryFormSheet), findsNothing);
        expect(find.text('입력 창을 닫을까요?'), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(server.calls('/api/v1/auth/guest'), isEmpty);
      });
    });
  }
  testWidgets('저장 후 GET10초가 끝나도 검색의 공유 갱신과 닫힌 시트를 유지한다', (tester) async {
    final denied = Completer<http.Response?>();
    final refresh = Completer<http.Response?>();
    final server = _Server(
      respond: (request, server) {
        if (request.url.path == _refresh) return refresh.future;
        if (request.method == 'GET' &&
            request.url.path == _categories &&
            server.calls(_categories, 'POST').isNotEmpty) {
          return denied.future;
        }
        if (request.url.queryParameters['q'] != null &&
            request.headers['Authorization'] == 'Bearer test-access') {
          return _json({'detail': 'expired'}, 401);
        }
        return null;
      },
    );
    await _withApp(tester, server, (storage) async {
      await _openForm(tester);
      final start = tester.binding.clock.now();
      await _submit(tester);
      expect(find.byType(CategoryFormSheet), findsNothing);
      await _until(tester, start, 4000);
      denied.complete(_json({'detail': 'expired'}, 401));
      await tester.pump();
      await _until(tester, start, 7000);
      _archive(tester).onTab(AppRoute.home);
      await tester.pump();
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onSearch();
      await tester.pump();
      final search = tester
          .widget<SearchScreen>(find.byType(SearchScreen))
          .onSearch('현재 검색');
      await tester.pump();
      await _until(tester, start, 10300);
      expect(find.text(_savedMessage), findsOneWidget);
      refresh.complete(_tokens('shared'));
      await tester.pumpAndSettle();
      expect(await search, isEmpty);
      expect(storage.session?.accessToken, 'shared-access');
      expect(storage.writes, 1);
      expect(storage.clears, 0);
      expect(server.calls(_refresh), hasLength(1));
      expect(server.calls(_categories, 'POST'), hasLength(1));
      expect(find.byType(CategoryFormSheet), findsNothing);
    });
  });
  for (final edit in [false, true]) {
    testWidgets('저장 대기 중 로그아웃 완료와 늦은 성공은 새 계정 입력을 닫지 않는다 (edit=$edit)', (
      tester,
    ) async {
      final response = Completer<http.Response?>();
      http.Request? oldWrite;
      final server = _Server(
        respond: (request, _) {
          if (request.method == (edit ? 'PATCH' : 'POST') &&
              request.url.path.startsWith(_categories) &&
              request.headers['Authorization'] == 'Bearer test-access') {
            oldWrite = request;
            return response.future;
          }
          return null;
        },
      );
      await _withApp(tester, server, (storage) async {
        await _openForm(tester, edit: edit);
        await _submit(tester, edit: edit);
        expect(find.text('저장하고 있어요.'), findsOneWidget);
        await _accountBehindForm(tester);
        await logoutFromAccount(tester);
        await tester.pumpAndSettle();
        expect(find.byType(CategoryFormSheet), findsNothing);
        await startGuestAndFinishOnboarding(tester);
        await tester.pumpAndSettle();
        await _openForm(tester);
        await tester.enterText(find.byType(TextField), '새 계정 초안');
        await tester.pump();
        response.complete(_saved(oldWrite!));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '새 계정 초안',
        );
        expect(find.byType(CategoryFormSheet), findsOneWidget);
        expect(storage.session?.accessToken, 'guest-access');
        expect(
          _archive(tester).categories.map((c) => c.name),
          contains('새 계정 목록'),
        );
        expect(
          _archive(tester).categories.map((c) => c.name),
          isNot(contains('보존할 초안')),
        );
        expect(storage.clears, 1);
      });
    });
    for (final refreshed in [false, true]) {
      testWidgets(
        '현재 카테고리 최종401은 기존 로그인 복구를 따른다 (edit=$edit,refresh=$refreshed)',
        (tester) async {
          final server = _Server(
            respond: (request, _) {
              if (request.method == (edit ? 'PATCH' : 'POST') &&
                  request.url.path.startsWith(_categories)) {
                return _json({'detail': 'expired'}, 401);
              }
              if (request.url.path == _refresh && !refreshed) {
                return _json({'detail': 'expired'}, 401);
              }
              return null;
            },
          );
          await _withApp(tester, server, (storage) async {
            await _openForm(tester, edit: edit);
            await _submit(tester, edit: edit);
            expect(find.byType(CategoryFormSheet), findsNothing);
            expect(find.byType(LoginScreen), findsOneWidget);
            expect(storage.session, isNull);
            expect(storage.clears, 1);
            expect(server.calls(_refresh), hasLength(1));
            expect(server.calls('/api/v1/auth/guest'), isEmpty);
          });
        },
      );
    }
  }
  for (final edit in [false, true]) {
    testWidgets('토큰 저장이 카테고리10초보다 길어도 초안·제출 키와 저장된 세션을 보존한다 (edit=$edit)', (
      tester,
    ) async {
      final saved = Completer<void>();
      final server = _Server(
        respond: (request, _) {
          if (request.method == (edit ? 'PATCH' : 'POST') &&
              request.url.path.startsWith(_categories)) {
            if (request.headers['Authorization'] == 'Bearer test-access') {
              return _json({'detail': 'expired'}, 401);
            }
            return _saved(request, edit ? _category : null);
          }
          return null;
        },
      );
      await _withApp(tester, server, (storage) async {
        await _openForm(tester, edit: edit);
        storage.writeGate = saved;
        final start = tester.binding.clock.now();
        await _submit(tester, edit: edit);
        expect(storage.writes, 1);
        expect(find.text('저장하고 있어요.'), findsOneWidget);
        await _until(tester, start, 10001);
        expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
        saved.complete();
        await tester.pumpAndSettle();
        expect(storage.session?.accessToken, 'rotated-access');
        expect(storage.clears, 0);
        expect(find.widgetWithText(FilledButton, '결과 다시 확인'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.widgetWithText(FilledButton, '결과 다시 확인'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryFormSheet), findsNothing);
        final writes = server.calls(
          edit ? '$_categories/101' : _categories,
          edit ? 'PATCH' : 'POST',
        );
        expect(writes, hasLength(2));
        expect(writes.first.body, writes.last.body);
        expect(
          writes.first.headers['Idempotency-Key'],
          writes.last.headers['Idempotency-Key'],
        );
        expect(server.calls(_refresh), hasLength(1));
      });
    });
  }
  for (final status in [200, 401]) {
    testWidgets('계정 교체 뒤 이전 인증$status 응답은 새 세션·입력 창을 바꾸지 않는다', (tester) async {
      final refresh = Completer<http.Response?>();
      final server = _Server(
        respond: (request, _) {
          if (request.url.path == _refresh) return refresh.future;
          if (request.method == 'POST' &&
              request.url.path == _categories &&
              request.headers['Authorization'] == 'Bearer test-access') {
            return _json({'detail': 'expired'}, 401);
          }
          return null;
        },
      );
      await _withApp(tester, server, (storage) async {
        await _openForm(tester);
        await _submit(tester);
        expect(server.calls(_refresh), hasLength(1));
        await _accountBehindForm(tester);
        await tester
            .widget<AccountManagementScreen>(
              find.byType(AccountManagementScreen),
            )
            .onConnect();
        await tester.pumpAndSettle();
        await tester
            .widget<LoginScreen>(find.byType(LoginScreen))
            .onSocialLogin(SocialLoginProvider.google);
        await tester.pumpAndSettle();
        await _openForm(tester);
        await tester.enterText(find.byType(TextField), '새 계정 초안');
        await tester.pump();
        final writes = storage.writes;
        refresh.complete(
          status == 200
              ? _tokens('obsolete')
              : _json({'detail': 'expired'}, 401),
        );
        await tester.pumpAndSettle();
        expect(storage.session?.accessToken, 'linked-access');
        expect(storage.writes, writes);
        expect(storage.clears, 0);
        expect(find.byType(CategoryFormSheet), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '새 계정 초안',
        );
        expect(server.calls(_categories, 'POST'), hasLength(1));
      });
    });
  }
}
