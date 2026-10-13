import 'package:clipback_frontend/data/repositories/share_repository.dart';
import 'package:clipback_frontend/features/share/pending_share_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pending chooser leaves underlying input and route alive', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final input = TextEditingController(text: '작성 중인 링크');
    addTearDown(input.dispose);
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => PendingSharePrompt(
          navigatorKey: navigator,
          promptVersion: 1,
          drafts: const [PendingShareDraft(id: 'one', label: '공유한 링크')],
          error: null,
          busy: false,
          onRetry: () {},
          onOpen: (draft) => opened = draft.id,
          child: child!,
        ),
        home: Scaffold(
          body: Center(child: TextField(controller: input)),
        ),
      ),
    );
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('저장 대기 중인 공유'), findsOneWidget);
    await tester.tap(find.text('공유한 링크'));
    await tester.pumpAndSettle();
    expect(opened, 'one');
    expect(input.text, '작성 중인 링크');
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('나중에'));
    await tester.pumpAndSettle();
    expect(find.text('저장 대기 중인 공유 1개'), findsNothing);
    expect(input.text, '작성 중인 링크');
  });
}
