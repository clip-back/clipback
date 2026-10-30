import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/shared/models/app_info.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fixtures/logout_alignment_fixture.dart' as fixture;
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;

const _installed = AppInfo(version: '0.2.0', buildNumber: '6');

Finder get _versionRow =>
    find.ancestor(of: find.text('앱 버전'), matching: find.byType(MyListTile));

Finder _versionRowText(String text) =>
    find.descendant(of: _versionRow, matching: find.text(text));

Finder _sheetText(String text) => find.descendant(
  of: find.byType(AppVersionSheet),
  matching: find.text(text),
);

Future<void> _openVersionSheet(WidgetTester tester) async {
  await tester.ensureVisible(_versionRow);
  await tester.tap(_versionRow);
  await tester.pumpAndSettle();
  expect(find.byType(AppVersionSheet), findsOneWidget);
}

Future<http.Response> _forward(http.Client client, http.Request request) async {
  final copy = http.Request(request.method, request.url)
    ..headers.addAll(request.headers)
    ..bodyBytes = request.bodyBytes;
  return http.Response.fromStream(await client.send(copy));
}

Future<void> _openMy(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ClipbackNavigationBar),
      matching: find.text('마이'),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(MyScreen), findsOneWidget);
}

Future<void> _runApp(
  WidgetTester tester,
  http.Client client,
  Future<void> Function() body, {
  AppInfo? appInfo,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 812);
  addTearDown(tester.view.reset);
  addTearDown(client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(
          key: UniqueKey(),
          sessionStorage: fixture.LogoutMemoryStorage(),
          socialAuth: isolated.ArchiveAllSocialAuth(),
          appInfo: appInfo,
        ),
      );
      await completeAppStartup(tester);
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => client);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.huturu.app/share'), (
          call,
        ) async {
          return switch (call.method) {
            'getState' => {
              'revision': 0,
              'drafts': <Object>[],
              'receipts': <Object>[],
            },
            'blockCredential' => 1,
            'publishCredential' => true,
            _ => null,
          };
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.huturu.app/share'),
          null,
        ),
  );

  testWidgets('마이 화면 앱 버전 줄에 설치된 앱의 앱 버전 세 자리가 보인다', (tester) async {
    final server = fixture.LogoutServer('member');
    await _runApp(tester, server.client, () async {
      await _openMy(tester);
      expect(_versionRowText('ver. 0.2.0'), findsOneWidget);
      expect(find.textContaining('ver. 1.1'), findsNothing);
    }, appInfo: _installed);
  });

  testWidgets('앱 정보가 없으면 앱 버전 줄에 -가 보이고 예전 고정값은 없다', (tester) async {
    final server = fixture.LogoutServer('member');
    await _runApp(tester, server.client, () async {
      await _openMy(tester);
      expect(_versionRowText('-'), findsOneWidget);
      expect(find.textContaining('ver. 1.1'), findsNothing);
    });
  });

  testWidgets('계정을 바꿔도 같은 앱 버전이 보인다', (tester) async {
    final member = fixture.LogoutServer('member'),
        guest = fixture.LogoutServer('guest');
    var current = member;
    final client = MockClient(
      (request) async => _forward(current.client, request),
    );
    await _runApp(tester, client, () async {
      await _openMy(tester);
      expect(find.text(member.expected.name), findsOneWidget);
      expect(_versionRowText('ver. 0.2.0'), findsOneWidget);

      await tester.tap(find.byType(MyProfileRow));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('로그아웃'));
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('logout-confirm')));
      await tester.pumpAndSettle();
      current = guest;
      await tester.ensureVisible(find.text('게스트로 시작하기'));
      await tester.tap(find.text('게스트로 시작하기'));
      await tester.pumpAndSettle();
      tester.widget<OnboardingScreen>(find.byType(OnboardingScreen)).onDone();
      await tester.pumpAndSettle();
      tester
          .widget<InterestSelectionScreen>(find.byType(InterestSelectionScreen))
          .onDone();
      await tester.pumpAndSettle();

      await _openMy(tester);
      expect(find.text(guest.expected.name), findsOneWidget);
      expect(_versionRowText('ver. 0.2.0'), findsOneWidget);
    }, appInfo: _installed);
  });

  testWidgets('계정 정보를 불러오지 못해도 같은 앱 버전이 보인다', (tester) async {
    final server = fixture.LogoutServer('member');
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/users/me/stats') {
        return server.json({'detail': '계정 통계 대역 요청 실패'}, 503);
      }
      return _forward(server.client, request);
    });
    await _runApp(tester, client, () async {
      await _openMy(tester);
      expect(find.text('통계를 불러오지 못했어요'), findsOneWidget);
      expect(_versionRowText('ver. 0.2.0'), findsOneWidget);
    }, appInfo: _installed);
  });

  testWidgets('앱 버전 시트의 현재 버전에 앱 버전과 빌드 번호가 보이고 업데이트 안내는 없다', (tester) async {
    final server = fixture.LogoutServer('member');
    await _runApp(tester, server.client, () async {
      await _openMy(tester);
      await _openVersionSheet(tester);
      expect(_sheetText('현재 버전'), findsOneWidget);
      expect(_sheetText('ver. 0.2.0 (6)'), findsOneWidget);
      expect(_sheetText('업데이트'), findsNothing);
      expect(find.text('최신 버전입니다'), findsNothing);
    }, appInfo: _installed);
  });

  testWidgets('앱 정보가 없으면 앱 버전 시트의 현재 버전에 -가 보이고 예전 고정값은 없다', (tester) async {
    final server = fixture.LogoutServer('member');
    await _runApp(tester, server.client, () async {
      await _openMy(tester);
      await _openVersionSheet(tester);
      expect(_sheetText('현재 버전'), findsOneWidget);
      expect(_sheetText('-'), findsOneWidget);
      expect(find.textContaining('ver. 1.1'), findsNothing);
    });
  });
}
