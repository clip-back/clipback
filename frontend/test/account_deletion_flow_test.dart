// #256 root app: account management → J04 → J05 → J06 → login, with the
// state tables of the account deletion spec (#250) on an in-memory API.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/app_view_model.dart';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/account_deleted_screen.dart';
import 'package:clipback_frontend/features/account/account_deletion_screen.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures/logout_alignment_fixture.dart' as fixture;
import 'support/account_preview.dart' as account;
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;

const _failure = accountDeletionFailureMessage;
// Every listed category except the shared "미분류" (U4).
final _ownedCategories = isolated.archiveAllCategoryMaps
    .where((c) => !(c['is_default'] == true && c['name'] == '미분류'))
    .length;

class _Server {
  _Server(String kind) : base = account.AccountServer(kind);
  final account.AccountServer base;
  final deleteBodies = <Object?>[];
  Completer<void>? deleteGate, contentGate, categoryGate;
  http.Response Function() deleteResponse = () => http.Response('', 204);
  Object? deleteError;
  bool contentFails = false, categoryFails = false;
  // The account is gone on the server: every session request is 401.
  bool deleted = false;

  http.Response json(Object body, [int status = 200]) =>
      base.json(body, status);

  late final client = MockClient((r) async {
    final path = r.url.path;
    if (deleted) return json({'detail': 'Not authenticated'}, 401);
    if (r.method == 'DELETE' && path == '/api/v1/users/me') {
      deleteBodies.add(jsonDecode(r.body));
      final gate = deleteGate;
      if (gate != null) await gate.future;
      final error = deleteError;
      if (error != null) throw error;
      final response = deleteResponse();
      if (response.statusCode == 204) deleted = true;
      return response;
    }
    if (path == '/api/v1/feed' && r.url.queryParameters['limit'] == '1') {
      await contentGate?.future;
      if (contentFails) return json({'detail': 'count failure'}, 500);
      return json({
        'items': <Object>[],
        'next_cursor': null,
        'total_count': 1557,
      });
    }
    if (path == '/api/v1/categories' &&
        (categoryGate != null || categoryFails)) {
      await categoryGate?.future;
      if (categoryFails) return json({'detail': 'count failure'}, 500);
    }
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return base.client.send(copy).then(http.Response.fromStream);
  });
}

class _Social extends isolated.ArchiveAllSocialAuth {
  int signOuts = 0, checks = 0;
  Completer<AppleCredentialStatus>? appleGate;
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async => signOuts++;
  @override
  Future<AppleCredentialStatus> appleCredentialState() {
    checks++;
    return appleGate?.future ?? Future.value(AppleCredentialStatus.authorized);
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _j04 => find.byType(AccountDeletionScreen);
Finder get _j06 => find.byType(AccountDeletedScreen);
Finder get _accountScreen => find.byType(AccountManagementScreen);
Finder _reason(String label) => _key('account-deletion-reason-$label');

int _checked(WidgetTester tester) => tester
    .widgetList<SvgPicture>(find.byType(SvgPicture))
    .where(
      (w) =>
          w.bytesLoader is SvgAssetLoader &&
          (w.bytesLoader as SvgAssetLoader).assetName ==
              Assets.accountDeletionCheck,
    )
    .length;

bool _submitEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.descendant(
            of: _key('account-deletion-submit'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed !=
    null;

Future<void> _app(
  WidgetTester tester,
  _Server server,
  fixture.LogoutMemoryStorage storage,
  SocialAuth social,
) async {
  await tester.pumpWidget(
    ClipbackApp(key: UniqueKey(), sessionStorage: storage, socialAuth: social),
  );
  await completeAppStartup(tester);
}

Future<void> _root(
  WidgetTester tester,
  Future<void> Function(
    _Server server,
    fixture.LogoutMemoryStorage storage,
    _Social social,
  )
  body, {
  String kind = 'member',
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final server = _Server(kind),
      storage = fixture.LogoutMemoryStorage(),
      social = _Social();
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  await http.runWithClient(() async {
    try {
      await _app(tester, server, storage, social);
      await tester.tap(
        find.descendant(
          of: find.byType(ClipbackNavigationBar),
          matching: find.text('마이'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MyProfileRow));
      await tester.pumpAndSettle();
      expect(_accountScreen, findsOneWidget);
      await body(server, storage, social);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    }
  }, () => server.client);
}

Future<void> _open(WidgetTester tester) async {
  await tester.ensureVisible(find.text('회원 탈퇴'));
  await tester.tap(find.text('회원 탈퇴'));
  await tester.pumpAndSettle();
  expect(_j04, findsOneWidget);
}

Future<void> _choose(WidgetTester tester, List<String> labels) async {
  for (final label in labels) {
    await tester.ensureVisible(_reason(label));
    await tester.tap(_reason(label));
    await tester.pump();
  }
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(_key('account-deletion-submit'));
  await tester.tap(_key('account-deletion-submit'));
  await tester.pump();
}

void _expectFailureKept(
  WidgetTester tester,
  fixture.LogoutMemoryStorage storage,
  int reasons,
) {
  expect(_j04, findsOneWidget);
  expect(_j06, findsNothing);
  expect(find.text(_failure), findsOneWidget);
  expect(_checked(tester), reasons);
  expect(_submitEnabled(tester), isTrue);
  expect(storage.value, isNotNull);
}

Future<void> _hideSnackBar(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(_j04)).hideCurrentSnackBar();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    var revision = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.huturu.app/share'), (
          call,
        ) async {
          switch (call.method) {
            case 'getState':
              return {
                'revision': revision,
                'drafts': <Object>[],
                'receipts': <Object>[],
              };
            case 'blockCredential':
              return ++revision;
            case 'publishCredential':
              return true;
            case 'presentDraft':
            case 'acknowledgeReceipts':
              return null;
            default:
              throw StateError('Unexpected share method ${call.method}');
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.huturu.app/share'),
          null,
        ),
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final kind in ['member', 'guest']) {
      testWidgets(
        '${platform.name} $kind J04 wording name counts then J05 and 204 reach a logged-out J06',
        (tester) async {
          await _root(
            tester,
            (server, storage, social) async {
              final name = tester.widget<AccountManagementScreen>(
                _accountScreen,
              );
              await _open(tester);
              expect(find.text('계정 관리'), findsOneWidget);
              expect(find.text('정말로 탈퇴하시겠어요?'), findsOneWidget);
              expect(
                find.text(
                  '${name.user.name} 님의 아래 정보는 모두 삭제되며,\n'
                  '탈퇴 시 정보 복구가 어려워요.',
                ),
                findsOneWidget,
              );
              expect(find.text('삭제 대상'), findsOneWidget);
              expect(find.text('콘텐츠 1557개'), findsOneWidget);
              expect(find.text('카테고리 $_ownedCategories개'), findsOneWidget);
              expect(find.text('허투루를 탈퇴하려는 이유가 무엇인가요? *'), findsOneWidget);
              expect(find.text('복수 선택 가능'), findsOneWidget);
              for (final label in accountDeletionReasonLabels.values) {
                expect(find.text(label), findsOneWidget);
              }
              expect(find.text('회원탈퇴 유의사항'), findsOneWidget);
              expect(
                find.text(
                  '회원 탈퇴 시 계정과 프로필 정보 및 저장한 모든 콘텐츠가 삭제되며,\n'
                  '이후 같은 계정으로 재가입하여도 삭제된 정보는 복구되지 않습니다.',
                ),
                findsOneWidget,
              );
              expect(find.text('탈퇴하기'), findsOneWidget);
              expect(find.text('취소'), findsOneWidget);
              // J04: no reason, no submission.
              expect(_checked(tester), 0);
              expect(_submitEnabled(tester), isFalse);
              await _submit(tester);
              expect(server.deleteBodies, isEmpty);
              // J05: a checked reason enables submit; reasons are sent in order.
              await _choose(tester, ['기타', '재가입']);
              expect(_checked(tester), 2);
              expect(_submitEnabled(tester), isTrue);
              // Untick and tick 재가입 so that tap order differs from spec order.
              await _choose(tester, ['재가입']);
              expect(_checked(tester), 1);
              await _choose(tester, ['재가입']);
              await _submit(tester);
              await tester.pumpAndSettle();
              expect(server.deleteBodies, [
                {
                  'reasons': ['rejoin', 'other'],
                },
              ]);
              expect(_j06, findsOneWidget);
              expect(find.text('탈퇴가 완료되었습니다.'), findsOneWidget);
              expect(
                find.text('그동안 이용해주셔서 감사합니다\n회원가입을 통해 언제든지 다시 시작하세요!'),
                findsOneWidget,
              );
              expect(find.text('로그인 화면으로 돌아가기'), findsOneWidget);
              expect(find.text(_failure), findsNothing);
              // Logged out like logout, without a server logout request.
              expect(storage.value, isNull);
              expect(server.base.logoutCalls, 0);
              expect(social.signOuts, 1);
              await tester.tap(_key('account-deleted-login'));
              await tester.pumpAndSettle();
              expect(find.byType(LoginScreen), findsOneWidget);
              expect(_j06, findsNothing);
              expect(server.deleteBodies, hasLength(1));
              expect(tester.takeException(), isNull);
            },
            kind: kind,
            platform: platform,
          );
        },
      );
    }
  }

  testWidgets('J06 system back opens login and a relaunch opens login', (
    tester,
  ) async {
    await _root(tester, (server, storage, social) async {
      await _open(tester);
      await _choose(tester, ['개인정보보호 및 보안']);
      await _submit(tester);
      await tester.pumpAndSettle();
      expect(_j06, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await _app(tester, server, storage, social);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_j06, findsNothing);
      expect(server.deleteBodies, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'J04 header back, system back and cancel return to account management',
    (tester) async {
      await _root(tester, (server, storage, social) async {
        for (final action in ['header', 'system', 'cancel']) {
          await _open(tester);
          await _choose(tester, ['재가입']);
          switch (action) {
            case 'header':
              await tester.tap(_key('account-deletion-back-hit'));
            case 'system':
              await tester.binding.handlePopRoute();
            default:
              await tester.ensureVisible(_key('account-deletion-cancel'));
              await tester.tap(_key('account-deletion-cancel'));
          }
          await tester.pumpAndSettle();
          expect(_accountScreen, findsOneWidget, reason: action);
          expect(_j04, findsNothing);
        }
        expect(server.deleteBodies, isEmpty);
        expect(storage.value, isNotNull);
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final count in ['loading', 'content failure', 'category failure']) {
    testWidgets(
      'count $count leaves its number slot empty and deletion works',
      (tester) async {
        await _root(tester, (server, storage, social) async {
          switch (count) {
            case 'loading':
              server.contentGate = Completer<void>();
              server.categoryGate = Completer<void>();
            case 'content failure':
              server.contentFails = true;
            default:
              server.categoryFails = true;
          }
          await _open(tester);
          expect(
            find.text(
              count == 'content failure' || count == 'loading'
                  ? '콘텐츠 개'
                  : '콘텐츠 1557개',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              count == 'category failure' || count == 'loading'
                  ? '카테고리 개'
                  : '카테고리 $_ownedCategories개',
            ),
            findsOneWidget,
          );
          await _choose(tester, ['이용 빈도 및 기대감이 낮음']);
          await _submit(tester);
          await tester.pumpAndSettle();
          expect(_j06, findsOneWidget);
          expect(server.deleteBodies, [
            {
              'reasons': ['low_usage'],
            },
          ]);
          server.contentGate?.complete();
          server.categoryGate?.complete();
          await tester.pumpAndSettle();
          expect(_j06, findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets(
    'waiting disables only submit with no spinner and blocks cancel header and system back',
    (tester) async {
      await _root(tester, (server, storage, social) async {
        await _open(tester);
        await _choose(tester, ['재가입']);
        server.deleteGate = Completer<void>();
        await _submit(tester);
        expect(server.deleteBodies, hasLength(1));
        expect(_submitEnabled(tester), isFalse);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await _submit(tester);
        await tester.ensureVisible(_key('account-deletion-cancel'));
        await tester.tap(_key('account-deletion-cancel'));
        await tester.pump();
        await tester.tap(_key('account-deletion-back-hit'));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(_j04, findsOneWidget);
        expect(server.deleteBodies, hasLength(1));
        server.deleteGate!.complete();
        await tester.pumpAndSettle();
        expect(_j06, findsOneWidget);
        expect(server.deleteBodies, hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final failure in <String, void Function(_Server)>{
    '422': (s) => s.deleteResponse = () => s.json({'detail': 'invalid'}, 422),
    '503': (s) =>
        s.deleteResponse = () => s.json({'detail': 'maintenance'}, 503),
    '500': (s) => s.deleteResponse = () => s.json({'detail': 'error'}, 500),
    '200': (s) => s.deleteResponse = () => s.json({}),
    '202': (s) => s.deleteResponse = () => http.Response('', 202),
    'connection': (s) => s.deleteError = http.ClientException('offline'),
  }.entries) {
    testWidgets(
      '${failure.key} keeps J04 with the chosen reasons and the failure snackbar',
      (tester) async {
        await _root(tester, (server, storage, social) async {
          await _open(tester);
          await _choose(tester, ['재가입', '기타']);
          failure.value(server);
          server.deleteGate = Completer<void>();
          await _submit(tester);
          await tester.pump();
          expect(_submitEnabled(tester), isFalse);
          server.deleteGate!.complete();
          server.deleteGate = null;
          await tester.pumpAndSettle();
          _expectFailureKept(tester, storage, 2);
          await _hideSnackBar(tester);
          server
            ..deleteError = null
            ..deleteResponse = () => http.Response('', 204);
          await _submit(tester);
          await tester.pumpAndSettle();
          expect(_j06, findsOneWidget);
          expect(server.deleteBodies, hasLength(2));
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets(
    'a failure snackbar still showing does not follow a successful retry to J06',
    (tester) async {
      await _root(tester, (server, storage, social) async {
        await _open(tester);
        await _choose(tester, ['재가입']);
        server.deleteResponse = () => server.json({'detail': 'x'}, 503);
        await _submit(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(_failure), findsOneWidget);
        server.deleteResponse = () => http.Response('', 204);
        await _submit(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(_j06, findsOneWidget);
        expect(find.text(_failure), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text(_failure), findsNothing);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'no answer fails at 60 seconds and a late 204 does not change the screen',
    (tester) async {
      await _root(tester, (server, storage, social) async {
        await _open(tester);
        await _choose(tester, ['재가입']);
        server.deleteGate = Completer<void>();
        await _submit(tester);
        await tester.pump(const Duration(milliseconds: 59999));
        expect(find.text(_failure), findsNothing);
        expect(_submitEnabled(tester), isFalse);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(find.text(_failure), findsOneWidget);
        await tester.pumpAndSettle();
        expect(_j04, findsOneWidget);
        expect(_checked(tester), 1);
        server.deleteGate!.complete();
        await tester.pumpAndSettle();
        expect(_j04, findsOneWidget);
        expect(_j06, findsNothing);
        expect(storage.value, isNotNull);
        expect(server.deleteBodies, hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('401 with a failed refresh goes to login without J06 (D29)', (
    tester,
  ) async {
    await _root(tester, (server, storage, social) async {
      await _open(tester);
      await _choose(tester, ['재가입']);
      server.deleted = true;
      await _submit(tester);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_j06, findsNothing);
      expect(_j04, findsNothing);
      expect(find.text(_failure), findsNothing);
      expect(storage.value, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'returning from the background while waiting skips the Apple check',
    (tester) async {
      await _root(tester, (server, storage, social) async {
        await _open(tester);
        await _choose(tester, ['재가입']);
        server.deleteGate = Completer<void>();
        await _submit(tester);
        final checks = social.checks;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(social.checks, checks);
        expect(_j04, findsOneWidget);
        server.deleteGate!.complete();
        await tester.pumpAndSettle();
        expect(_j06, findsOneWidget);
        expect(server.base.logoutCalls, 0);
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final checkFirst in [true, false]) {
    for (final result in ['204', '503', '401']) {
      testWidgets(
        'a revoked Apple check started before the wait is discarded '
        '(${checkFirst ? 'check' : 'deletion'} arrives first, deletion $result)',
        (tester) async {
          await _root(tester, (server, storage, social) async {
            await _open(tester);
            await _choose(tester, ['재가입']);
            social.appleGate = Completer<AppleCredentialStatus>();
            final checks = social.checks;
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.pump();
            expect(social.checks, checks + 1);
            server.deleteGate = Completer<void>();
            if (result == '503') {
              server.deleteResponse = () => server.json({'detail': 'x'}, 503);
            }
            if (result == '401') {
              server.deleteResponse = () {
                server.deleted = true;
                return server.json({'detail': 'Not authenticated'}, 401);
              };
            }
            await _submit(tester);
            expect(server.deleteBodies, hasLength(1));
            Future<void> check() async {
              social.appleGate!.complete(AppleCredentialStatus.revoked);
              await tester.pump();
            }

            Future<void> deletion() async {
              server.deleteGate!.complete();
              await tester.pumpAndSettle();
            }

            if (checkFirst) {
              await check();
              expect(_j04, findsOneWidget);
              await deletion();
            } else {
              await deletion();
              await check();
            }
            await tester.pumpAndSettle();
            switch (result) {
              case '204':
                expect(_j06, findsOneWidget);
                expect(storage.value, isNull);
              case '503':
                _expectFailureKept(tester, storage, 1);
              default:
                expect(find.byType(LoginScreen), findsOneWidget);
                expect(_j06, findsNothing);
            }
            // The discarded revocation sends no logout of its own.
            expect(server.base.logoutCalls, 0);
            expect(tester.takeException(), isNull);
          });
        },
      );
    }
  }

  for (final deleted in [true, false]) {
    testWidgets(
      'app closed while waiting restores the stored session next launch '
      '(${deleted ? 'server deleted → login' : 'not deleted → account kept'})',
      (tester) async {
        await _root(tester, (server, storage, social) async {
          await _open(tester);
          await _choose(tester, ['재가입']);
          server.deleteGate = Completer<void>();
          if (!deleted) {
            server.deleteResponse = () => server.json({'detail': 'x'}, 503);
          }
          await _submit(tester);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          server.deleteGate!.complete();
          await tester.pumpAndSettle();
          expect(storage.value, isNotNull);
          await _app(tester, server, storage, social);
          await tester.pumpAndSettle();
          if (deleted) {
            expect(find.byType(LoginScreen), findsOneWidget);
            expect(storage.value, isNull);
          } else {
            expect(find.byType(HomeScreen), findsOneWidget);
            expect(storage.value, isNotNull);
          }
          expect(_j06, findsNothing);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets('rapid taps on the withdrawal row open one J04 from My', (
    tester,
  ) async {
    await _root(tester, (server, storage, social) async {
      await tester.ensureVisible(find.text('회원 탈퇴'));
      await tester.tap(find.text('회원 탈퇴'));
      await tester.tap(find.text('회원 탈퇴'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_j04, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(MyScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
