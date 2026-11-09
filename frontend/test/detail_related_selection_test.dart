import 'dart:typed_data';

import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = CategoryItem(
  id: 10,
  name: 'A',
  color: Colors.green,
  tint: Colors.green,
  deep: Colors.green,
);
const _b = CategoryItem(
  id: 20,
  name: 'B',
  color: Colors.blue,
  tint: Colors.blue,
  deep: Colors.blue,
);
const _sameNameAsA = CategoryItem(
  id: 30,
  name: 'A',
  color: Colors.red,
  tint: Colors.red,
  deep: Colors.red,
);
final _serverUncategorized = CategoryItem(
  id: 1,
  name: catUncategorized.name,
  color: catUncategorized.color,
  tint: catUncategorized.tint,
  deep: catUncategorized.deep,
);

ContentItem _item(String id, List<CategoryItem> categories) => ContentItem(
  id: id,
  apiId: id.hashCode,
  title: 'title-$id',
  summary: 's',
  category: categories.first,
  categories: categories,
  savedAt: '',
  savedAtFull: '',
  savedAtFullShort: '',
  tags: const [],
  source: '웹 링크',
  originalUrl: 'https://example.invalid/$id',
  originalText: '',
);

Future<List<String>> _related(
  WidgetTester tester,
  ContentItem current,
  List<ContentItem> contents,
) async {
  tester.view.physicalSize = const Size(375, 20000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DetailScreen(
        content: current,
        contents: contents,
        categories: const [_a, _b],
        bookmarked: false,
        onReadAsset: (_) async => Uint8List(0),
        onBack: () {},
        onToggleBookmark: (_) {},
        onChangeCategory: (_, _) {},
        onDeleteContent: (_) {},
        onOpenOriginalLink: () {},
        onOpenAdjacent: (_) {},
        onOpenContent: (_) {},
        onAddLink: ({required url, submissionKey, category}) async => current,
        onAddScreenshot:
            ({
              required bytes,
              required filename,
              String? submissionKey,
              category,
            }) async => current,
        onTab: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  const prefix = 'detail-related-card-';
  return find
      .byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(prefix),
      )
      .evaluate()
      .map(
        (e) =>
            (e.widget.key! as ValueKey<String>).value.substring(prefix.length),
      )
      .toList();
}

void main() {
  testWidgets('same category shows only the first three in loaded order', (
    tester,
  ) async {
    final all = [
      for (var i = 0; i < 8; i++) _item('c$i', const [_a]),
    ];
    expect(await _related(tester, all[0], all), ['c1', 'c2', 'c3']);
  });

  testWidgets('any shared category counts, including the second one', (
    tester,
  ) async {
    final current = _item('cur', const [_a, _b]);
    final all = [
      current,
      _item('bOnly', const [_b]),
      _item('bThenA', const [_b, _a]),
      _item('aOnly', const [_a]),
    ];
    expect(await _related(tester, current, all), ['bOnly', 'bThenA', 'aOnly']);
  });

  testWidgets('a fourth overlapping content is cut by the cap', (tester) async {
    final current = _item('cur', const [_a, _b]);
    final all = [
      current,
      _item('bOnly', const [_b]),
      _item('bThenA', const [_b, _a]),
      _item('aOnly', const [_a]),
      _item('aAndB', const [_a, _b]),
    ];
    expect(await _related(tester, current, all), ['bOnly', 'bThenA', 'aOnly']);
  });

  testWidgets('no overlap shows no card and the empty text', (tester) async {
    final current = _item('cur', const [_a]);
    final all = [
      current,
      _item('x', const [_b]),
    ];
    expect(await _related(tester, current, all), isEmpty);
    expect(find.byKey(const ValueKey('detail-related-empty')), findsOneWidget);
    expect(find.text('불러온 목록에 연관 콘텐츠가 없어요.'), findsOneWidget);
  });

  testWidgets('fewer than three shows as many as there are', (tester) async {
    final current = _item('cur', const [_a]);
    final all = [
      current,
      _item('a1', const [_a]),
      _item('a2', const [_a]),
    ];
    expect(await _related(tester, current, all), ['a1', 'a2']);
    expect(find.byKey(const ValueKey('detail-related-empty')), findsNothing);
  });

  testWidgets('server uncategorized contents pick each other', (tester) async {
    final current = _item('cur', [_serverUncategorized]);
    final all = [
      current,
      _item('u1', [_serverUncategorized]),
      _item('a1', const [_a]),
      _item('u2', [_serverUncategorized]),
    ];
    expect(await _related(tester, current, all), ['u1', 'u2']);
  });

  testWidgets('fallback uncategorized without id picks uncategorized', (
    tester,
  ) async {
    final current = _item('cur', const [catUncategorized]);
    final all = [
      current,
      _item('u1', const [catUncategorized]),
      _item('a1', const [_a]),
      _item('u2', [_serverUncategorized]),
    ];
    expect(await _related(tester, current, all), ['u1', 'u2']);
  });

  testWidgets('same name with a different id is not related', (tester) async {
    final current = _item('cur', const [_a]);
    final all = [
      current,
      _item('sameName', const [_sameNameAsA]),
    ];
    expect(await _related(tester, current, all), isEmpty);
  });

  testWidgets('content sharing several categories appears once', (
    tester,
  ) async {
    final current = _item('cur', const [_a, _b]);
    final all = [
      current,
      _item('ab', const [_a, _b]),
    ];
    expect(await _related(tester, current, all), ['ab']);
  });

  testWidgets('current content is never its own candidate', (tester) async {
    final current = _item('cur', const [_a]);
    final all = [
      _item('cur', const [_a]),
      _item('a1', const [_a]),
    ];
    expect(await _related(tester, current, all), ['a1']);
  });
}
