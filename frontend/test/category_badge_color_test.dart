import 'dart:typed_data';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/presentation/content_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// #414: 서버 색 → 배지 (연한 배경, 진한 글자) ARGB.
// 팔레트 1–6번은 Figma `428:4712` 3줄(연한)·2줄(진한) 짝(2026-11-17 조회).
const _paired = <String, (int, int)>{
  '#FF6277': (0xFFFFE0E4, 0xFFBC4858),
  '#FFA24B': (0xFFFFDAB2, 0xFFD0802A),
  '#FFD75C': (0xFFFFF3CE, 0xFFC5A544),
  '#5BD89D': (0xFFE0F8EF, 0xFF45A27D),
  '#64B5F6': (0xFFE2F1FF, 0xFF4676A4),
  '#B9AAFF': (0xFFDCD3FF, 0xFF927EDD),
  // 서버가 소문자로 보내도 같은 색이면 짝을 쓴다.
  '#ffa24b': (0xFFFFDAB2, 0xFFD0802A),
};
// 짝 없는 색은 지금 계산 그대로: 연한 = 기본색 alpha 0x33, 진한 = deepCategoryColor 실제 결과
// (시작 커밋 554ba56 실측: 채널이 0 또는 1, 사용자 결정 a 2026-11-17).
const _unpaired = <String, (int, int)>{
  '#FFB3C1': (0x33FFB3C1, 0xFF010101),
  '#1F5E24': (0x331F5E24, 0xFF000000),
  '#059669': (0x33059669, 0xFF000000),
};
const _all = {..._paired, ..._unpaired};

String _name(String hex) => '배지 $hex';

Map<String, Object?> _category(int id, String hex) => {
  'id': id,
  'name': _name(hex),
  'color': hex,
  'is_default': false,
  'content_count': 1,
  'last_saved_at': null,
};

ContentItem _content(int id, List<String> colors) => contentFromApi(
  ApiContent.fromJson({
    'id': id,
    'categories': [
      for (final (i, hex) in colors.indexed) _category(id * 100 + i, hex),
    ],
    'tags': <Object>[],
    'assets': <Object>[],
    'content_type': 'link',
    'source': 'web',
    'title': '배지 색 콘텐츠 $id',
    'summary': '배지 색 요약 $id',
    'original_url': 'https://example.invalid/$id',
    'is_favorite': false,
    'saved_at': '2026-11-17T00:00:00Z',
    'last_viewed_at': null,
    'summary_status': 'completed',
  }),
  const {},
);

/// 그려진 배지(이름 글자와 그 첫 Container 장식)의 (배경, 글자) ARGB.
(int?, int?) _drawn(WidgetTester tester, String hex) {
  final text = find.text(_name(hex));
  expect(text, findsOneWidget, reason: '$hex 배지');
  final box = tester.widget<Container>(
    find.ancestor(of: text, matching: find.byType(Container)).first,
  );
  final bg = (box.decoration as BoxDecoration?)?.color;
  final fg = tester.widget<Text>(text).style?.color;
  return (bg?.toARGB32(), fg?.toARGB32());
}

String _argb((int?, int?) v) =>
    '(${v.$1?.toRadixString(16)}, ${v.$2?.toRadixString(16)})';

Future<void> _pumpDetail(WidgetTester tester, ContentItem content) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DetailScreen(
        content: content,
        contents: [content],
        categories: content.categories,
        bookmarked: false,
        onReadAsset: (_) async => Uint8List(0),
        onBack: () {},
        onToggleBookmark: (_) {},
        onChangeCategory: (_, _) {},
        onDeleteContent: (_) {},
        onOpenOriginalLink: () {},
        onOpenAdjacent: (_) {},
        onOpenContent: (_) {},
        onAddLink: ({required url, submissionKey, category}) async => content,
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
}

/// 시트에서 [hex] 색을 골라 저장했을 때 시트가 만드는 모델.
Future<CategoryItem> _sheetModel(
  WidgetTester tester,
  String hex, {
  required bool edit,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(tester.view.reset);
  CategoryItem? saved;
  final color = Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
  final original = categoryFromApi(
    ApiCategory.fromJson(_category(1, '#FF6277')),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: edit
            ? CategoryEditSheet(category: original, onSave: (v) => saved = v)
            : CategoryCreateSheet(onCreate: (v) => saved = v),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), _name(hex));
  final swatch = find.byKey(
    ValueKey('palette-color-${color.toARGB32().toRadixString(16)}'),
  );
  await tester.ensureVisible(swatch);
  await tester.pumpAndSettle();
  await tester.tap(swatch);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, edit ? '수정하기' : '생성하기'));
  await tester.pumpAndSettle();
  expect(saved, isNotNull, reason: '$hex 시트 저장');
  return saved!;
}

void main() {
  group('server category color maps to badge colors', () {
    for (final MapEntry(key: hex, value: want) in _all.entries) {
      test(hex, () {
        final category = categoryFromApi(
          ApiCategory.fromJson(_category(1, hex)),
        );
        expect(
          (category.tint.toARGB32(), category.deep.toARGB32()),
          want,
          reason: _argb((category.tint.toARGB32(), category.deep.toARGB32())),
        );
      });
    }
  });

  group('home card draws the badge colors', () {
    for (final MapEntry(key: hex, value: want) in _all.entries) {
      testWidgets(hex, (tester) async {
        final content = _content(1, [hex]);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: HomeContentCard(
                  content: content,
                  bookmarked: false,
                  onTap: () {},
                  onToggleBookmark: () {},
                ),
              ),
            ),
          ),
        );
        final drawn = _drawn(tester, hex);
        expect(drawn, want, reason: _argb(drawn));
      });
    }
  });

  testWidgets('detail draws every palette pair badge', (tester) async {
    final colors = _paired.keys.where((hex) => hex != '#ffa24b').toList();
    await _pumpDetail(tester, _content(2, colors));
    for (final hex in colors) {
      final drawn = _drawn(tester, hex);
      expect(drawn, _paired[hex], reason: '$hex ${_argb(drawn)}');
    }
  });

  testWidgets('detail draws unpaired colors with the current calculation', (
    tester,
  ) async {
    await _pumpDetail(tester, _content(3, _unpaired.keys.toList()));
    for (final hex in _unpaired.keys) {
      final drawn = _drawn(tester, hex);
      expect(drawn, _unpaired[hex], reason: '$hex ${_argb(drawn)}');
    }
  });

  // 시트가 저장 직후 잠깐 쓰는 모델도 서버 응답 뒤 모델과 같은 색이다.
  for (final edit in [false, true]) {
    group('${edit ? 'edit' : 'create'} sheet model matches server mapping', () {
      for (final hex in const [
        '#FF6277',
        '#FFA24B',
        '#FFD75C',
        '#5BD89D',
        '#64B5F6',
        '#B9AAFF',
        '#FFB3C1',
        '#1F5E24',
      ]) {
        testWidgets(hex, (tester) async {
          final saved = await _sheetModel(tester, hex, edit: edit);
          final server = categoryFromApi(
            ApiCategory.fromJson(_category(1, hex)),
          );
          expect(
            (saved.tint.toARGB32(), saved.deep.toARGB32()),
            (server.tint.toARGB32(), server.deep.toARGB32()),
          );
          expect((saved.tint.toARGB32(), saved.deep.toARGB32()), _all[hex]);
        });
      }
    });
  }
}
