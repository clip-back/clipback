import 'dart:typed_data';

import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets(
    'link icon calls the opener without constructing the legacy sheet',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DetailScreen(
            content: _link,
            contents: const [_link],
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
            onAddLink: ({required url, category}) async => _link,
            onAddScreenshot:
                ({required bytes, required filename, category}) async => _link,
            onTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-original-button')));
      await tester.pump();
      expect(opens, 1);
      expect(find.byType(OriginalContentSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('전문 보기'));
      await tester.pumpAndSettle();
      expect(find.text(_link.originalText), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-original-button')));
      await tester.pump();
      expect(opens, 2);
      expect(find.text(_link.originalText), findsOneWidget);
    },
  );
}
