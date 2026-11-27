import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

// 시트 160 (#492): 아래 버튼 이름은 스크린 리더에 한 번만 전달된다.

const _saved = ContentItem(
  id: 'saved-result',
  title: '저장한 콘텐츠',
  summary: '서버가 반환한 요약',
  category: catUncategorized,
  savedAt: '26.10.15',
  savedAtFull: '2026. 10. 15 오후 02:00',
  savedAtFullShort: '2026. 10. 15 02:00',
  tags: [],
  source: '테스트',
  originalUrl: 'https://example.com/saved',
  originalText: '',
);

Future<void> _open(
  WidgetTester tester,
  Future<ContentItem> Function() onAddLink,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 812);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showContentSaveScreen(
              context: context,
              onAddLink: ({required url, submissionKey, category}) =>
                  onAddLink(),
              onAddScreenshot:
                  ({
                    required bytes,
                    required filename,
                    String? submissionKey,
                    category,
                  }) => throw StateError('photo'),
            ),
            child: const Text('저장 화면 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('저장 화면 열기'));
  await tester.pumpAndSettle();
}

Future<void> _link(WidgetTester tester, String url) async {
  await tester.tap(find.text('링크 첨부'));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.enterText(find.byType(TextField), url);
  await tester.pump(const Duration(milliseconds: 400));
}

SemanticsNode _node(WidgetTester tester) =>
    tester.getSemantics(find.byType(SaveFlowButton));

void _expectButton(
  WidgetTester tester, {
  required String label,
  required bool enabled,
}) {
  final data = _node(tester).getSemanticsData();
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
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await _open(tester, () async {
      calls++;
      return _saved;
    });
    await tester.tap(find.text('링크 첨부'));
    await tester.pump(const Duration(milliseconds: 50));
    _expectButton(tester, label: '허투루에 저장하기', enabled: false);
    await _link(tester, 'not a link');
    _expectButton(tester, label: '허투루에 저장하기', enabled: false);
    expect(calls, 0);
    semantics.dispose();
  });

  testWidgets('valid link: semantic tap saves once', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await _open(tester, () async {
      calls++;
      return _saved;
    });
    await _link(tester, 'https://example.com/saved');
    _expectButton(tester, label: '허투루에 저장하기', enabled: true);
    tester.semantics.tap(find.semantics.byLabel('허투루에 저장하기'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(SavedContentConfirmation), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('processing close and loading are disabled and named once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final pending = Completer<ContentItem>();
    var calls = 0;
    await _open(tester, () {
      calls++;
      return pending.future;
    });
    await _link(tester, 'https://example.com/pending');
    await tester.tap(find.text('허투루에 저장하기'));
    await tester.pump(const Duration(milliseconds: 50));
    _expectButton(tester, label: '닫기', enabled: false);
    // 처리 중 표시가 지금 입력을 설명하지 않으면 '저장 중' 로딩 버튼이 된다.
    await tester.tap(find.text('사진 첨부'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).loading,
      isTrue,
    );
    _expectButton(tester, label: '저장 중', enabled: false);
    expect(calls, 1);
    pending.complete(_saved);
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('saved: semantic tap on 저장 완료 closes the screen', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await _open(tester, () async {
      calls++;
      return _saved;
    });
    await _link(tester, 'https://example.com/saved');
    await tester.tap(find.text('허투루에 저장하기'));
    await tester.pumpAndSettle();
    _expectButton(tester, label: '저장 완료', enabled: true);
    tester.semantics.tap(find.semantics.byLabel('저장 완료'));
    await tester.pumpAndSettle();
    expect(find.byType(AddContentSheet), findsNothing);
    expect(calls, 1);
    semantics.dispose();
  });
}
