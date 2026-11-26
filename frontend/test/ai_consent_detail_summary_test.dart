// #477: the consent copy in the detail summary slot fits with Pretendard.
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _copy = 'AI 전송에 동의하지 않아 요약하지 않았어요.';
const _saved = '저장할 때 들어간 설명입니다.';
const _category = CategoryItem(
  id: 10,
  name: '영상',
  color: Colors.green,
  tint: Color(0xFFE3F5E9),
  deep: Color(0xFF127342),
);

Future<void> _pump(WidgetTester tester, double width, double scale) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  const content = ContentItem(
    id: 'video',
    apiId: 7,
    title: '동의 전에 저장한 영상',
    summary: _saved,
    category: _category,
    categories: [_category],
    savedAt: '26.11.14',
    savedAtFull: '2026. 11. 14 오후 03:40',
    savedAtFullShort: '2026. 11. 14 15:40',
    tags: [],
    source: 'YouTube',
    originalUrl: 'https://www.youtube.com/watch?v=consent',
    originalText: '',
    summaryStatus: 'skipped',
    summaryErrorCode: 'ai_consent_required',
  );
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
        contents: const [content],
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

  for (final width in [320.0, 375.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('consent copy fits Pretendard width $width scale $scale', (
        tester,
      ) async {
        await _pump(tester, width, scale);
        expect(tester.widget<Text>(_summary).data, _copy);
        expect(find.text(_saved), findsNothing);
        final paragraph = tester.renderObject<RenderParagraph>(_summary);
        expect(paragraph.size.width, width - 48);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.size.height,
          closeTo(paragraph.getMinIntrinsicHeight(paragraph.size.width), .01),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('consent copy replaces the saved text in semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, 375, 1);
    expect(find.bySemanticsLabel(_copy), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(_saved)), findsNothing);
    semantics.dispose();
  });
}
