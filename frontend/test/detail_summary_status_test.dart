import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _category = CategoryItem(
  id: 10,
  name: '영상',
  color: Colors.green,
  tint: Color(0xFFE3F5E9),
  deep: Color(0xFF127342),
);
const _saved = '저장할 때 들어간 영상 설명입니다.';
const _building = '요약을 만들고 있어요. 잠시 뒤 다시 열어 보세요.';
const _failed = '요약을 만들지 못했어요.';

ContentItem _content(String status) => ContentItem(
  id: 'video',
  apiId: 7,
  title: '요약 상태를 보는 영상',
  summary: _saved,
  category: _category,
  categories: const [_category],
  savedAt: '26.11.14',
  savedAtFull: '2026. 11. 14 오후 03:40',
  savedAtFullShort: '2026. 11. 14 15:40',
  tags: const [],
  source: 'YouTube',
  originalUrl: 'https://www.youtube.com/watch?v=summary',
  originalText: '',
  summaryStatus: status,
);

Future<void> _pump(
  WidgetTester tester,
  String status, {
  double width = 375,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  final content = _content(status);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Pretendard'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: DetailScreen(
        content: content,
        contents: [content],
        categories: const [_category],
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

final _summary = find.byKey(const ValueKey('detail-summary'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  for (final (status, expected) in [
    ('queued', _building),
    ('processing', _building),
    ('failed', _failed),
    ('completed', _saved),
    ('skipped', _saved),
    ('not_requested', _saved),
    ('unknown_future_status', _saved),
  ]) {
    testWidgets('$status summary status shows its copy in the summary slot', (
      tester,
    ) async {
      await _pump(tester, status);
      final text = tester.widget<Text>(_summary);
      expect(text.data, expected);
      if (expected != _saved) expect(find.text(_saved), findsNothing);
      final style = text.style!;
      expect(style.inherit, isFalse);
      expect(style.fontFamily, 'Pretendard');
      expect(style.fontSize, 16);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.height, 1.6);
      expect(style.letterSpacing, -0.4);
      expect(style.color, AppColors.text);
      final heading = tester.getRect(find.text('요약'));
      final body = tester.getRect(_summary);
      expect(body.left, 24);
      expect(body.width, 375 - 48);
      expect(body.top - heading.bottom, 8);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (status, copy) in [
    ('processing', _building),
    ('failed', _failed),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('$status copy fits Pretendard width 320 scale $scale', (
        tester,
      ) async {
        await _pump(tester, status, width: 320, scale: scale);
        expect(tester.widget<Text>(_summary).data, copy);
        final paragraph = tester.renderObject<RenderParagraph>(_summary);
        expect(paragraph.size.width, 320 - 48);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.size.height,
          closeTo(paragraph.getMinIntrinsicHeight(paragraph.size.width), .01),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
