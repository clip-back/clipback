import 'dart:ui' show Tristate;

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/link_pending_fixture.dart' as f;
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as login;

// 시트 160 (#492): 아래 버튼 이름은 스크린 리더에 한 번만 전달된다.
// 실제 루트 앱의 홈 + 버튼으로 저장 화면을 열고, 메모리 서버가 저장 요청을 붙잡는다.

Future<void> _withSaveScreen(
  WidgetTester tester,
  Future<void> Function(f.LinkPendingServer server) body,
) async {
  final semantics = tester.ensureSemantics();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 812);
  final server = f.LinkPendingServer();
  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        ClipbackApp(
          sessionStorage: login.LoginMemoryStorage()..value = f.pendingSession,
          socialAuth: login.LoginControlledSocial(defaultTargetPlatform),
        ),
      );
      await completeAppStartup(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'NavAddButton',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinkSaveBody), findsOneWidget);
      await body(server);
      server.resolve(success: false);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }, () => server.controlledClient);
  } finally {
    server.resolve(success: false);
    tester.view.reset();
    semantics.dispose();
  }
}

Future<void> _link(WidgetTester tester, String url) async {
  await tester.enterText(find.byType(TextField), url);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _submit(WidgetTester tester, f.LinkPendingServer server) async {
  await _link(tester, f.pendingLink);
  await tester.tap(find.text('허투루에 저장하기'));
  await tester.pump(const Duration(milliseconds: 50));
  expect(server.submissions, [f.pendingLink]);
}

void _expectButton(
  WidgetTester tester, {
  required String label,
  required bool enabled,
}) {
  final node = tester.getSemantics(find.byType(SaveFlowButton));
  // 안쪽 글자가 따로 읽히는 자식 노드도 없어야 한다.
  expect(node.hasChildren, isFalse);
  final data = node.getSemanticsData();
  expect(data.label, label);
  expect(data.flagsCollection.isButton, isTrue);
  expect(
    data.flagsCollection.isEnabled,
    enabled ? Tristate.isTrue : Tristate.isFalse,
  );
  expect(data.hasAction(SemanticsAction.tap), enabled);
}

void main() {
  testWidgets('empty and invalid link: disabled save named once', (
    tester,
  ) async {
    await _withSaveScreen(tester, (server) async {
      expect(find.byType(ValidationMessage), findsNothing);
      _expectButton(tester, label: '허투루에 저장하기', enabled: false);
      await _link(tester, 'not a link');
      expect(find.text('유효하지 않은 링크예요.'), findsOneWidget);
      _expectButton(tester, label: '허투루에 저장하기', enabled: false);
      expect(server.submissions, isEmpty);
    });
  });

  testWidgets('valid link: semantic tap sends one save request', (
    tester,
  ) async {
    await _withSaveScreen(tester, (server) async {
      await _link(tester, f.pendingLink);
      _expectButton(tester, label: '허투루에 저장하기', enabled: true);
      tester.semantics.tap(find.semantics.byLabel('허투루에 저장하기'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(server.submissions, [f.pendingLink]);
    });
  });

  testWidgets('processing close and loading are disabled and named once', (
    tester,
  ) async {
    await _withSaveScreen(tester, (server) async {
      await _submit(tester, server);
      _expectButton(tester, label: '닫기', enabled: false);
      // 처리 중 표시가 지금 입력을 설명하지 않으면 '저장 중' 로딩 버튼이 된다.
      await tester.tap(find.text('사진 첨부'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).loading,
        isTrue,
      );
      _expectButton(tester, label: '저장 중', enabled: false);
      expect(server.submissions, hasLength(1));
    });
  });

  testWidgets('saved: semantic tap on 저장 완료 closes the save screen', (
    tester,
  ) async {
    await _withSaveScreen(tester, (server) async {
      await _submit(tester, server);
      server.resolve();
      await tester.pumpAndSettle();
      expect(find.byType(SavedContentConfirmation), findsOneWidget);
      _expectButton(tester, label: '저장 완료', enabled: true);
      tester.semantics.tap(find.semantics.byLabel('저장 완료'));
      await tester.pumpAndSettle();
      expect(find.byType(AddContentSheet), findsNothing);
      expect(server.submissions, hasLength(1));
    });
  });
}
