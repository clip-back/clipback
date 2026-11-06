import 'dart:typed_data';

import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _photo = ContentItem(
  id: 'original-photo',
  apiId: 8,
  title: '원본 이미지 검증',
  summary: '사진 요약',
  category: catUncategorized,
  savedAt: '26.10.21',
  savedAtFull: '2026. 10. 21 오후 06:00',
  savedAtFullShort: '2026. 10. 21',
  tags: [],
  source: '스크린샷',
  originalUrl: '',
  originalText: '',
  isScreenshot: true,
);

const _link = ContentItem(
  id: 'original-link',
  apiId: 7,
  title: '원본 링크 검증',
  summary: '보존할 요약',
  category: catUncategorized,
  savedAt: '26.10.21',
  savedAtFull: '2026. 10. 21 오후 06:00',
  savedAtFullShort: '2026. 10. 21',
  tags: [],
  source: '웹 링크',
  originalUrl: 'https://example.com/?q=a%20b#part',
  originalText: '전달된 전문은 그대로 유지합니다.',
);

Finder get _bodyDividers =>
    find.descendant(of: find.byType(ListView), matching: find.byType(Divider));

Future<int Function()> _pumpDetail(
  WidgetTester tester,
  ContentItem content,
) async {
  var opens = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: DetailScreen(
        content: content,
        contents: [content],
        categories: const [catUncategorized],
        bookmarked: false,
        onReadAsset: (_) async => Uint8List(0),
        onBack: () {},
        onToggleBookmark: (_) {},
        onChangeCategory: (_, _) {},
        onDeleteContent: (_) {},
        onOpenOriginalLink: () => opens++,
        onOpenAdjacent: (_) {},
        onOpenContent: (_) {},
        onAddLink: ({required url, category}) async => content,
        onAddScreenshot:
            ({
              required bytes,
              required filename,
              String? submissionKey,
              category,
            }) async => content,
        onTab: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return () => opens;
}

void main() {
  testWidgets(
    'link icon calls the opener without constructing the legacy sheet',
    (tester) async {
      final opens = await _pumpDetail(tester, _link);
      expect(find.text('전문 보기'), findsNothing);
      expect(find.byKey(const ValueKey('detail-original-text')), findsNothing);
      expect(find.text(_link.summary), findsOneWidget);
      expect(_bodyDividers, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-original-button')));
      await tester.pump();
      expect(opens(), 1);
      expect(find.byType(OriginalContentSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('screenshot detail keeps original image toggle and sheet', (
    tester,
  ) async {
    final opens = await _pumpDetail(tester, _photo);
    expect(find.text('원본 이미지 보기'), findsOneWidget);
    expect(_bodyDividers, findsNWidgets(2));
    expect(find.text(_photo.summary), findsOneWidget);
    await tester.tap(find.text('원본 이미지 보기'));
    await tester.pumpAndSettle();
    expect(find.text('원본 이미지 보기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('detail-original-button')));
    await tester.pumpAndSettle();
    expect(find.byType(OriginalContentSheet), findsOneWidget);
    expect(opens(), 0);
  });
}
