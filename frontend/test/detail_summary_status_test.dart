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
const _limit = '이번 달 AI 요약을 모두 써서 요약하지 않았어요. 다음 달 1일부터 다시 요약해요.';
const _consent = 'AI 전송에 동의하지 않아 요약하지 않았어요.';

ContentItem _content(String status, {String? errorCode}) => ContentItem(
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
  summaryErrorCode: errorCode,
);

Future<void> _pump(
  WidgetTester tester,
  String status, {
  double width = 375,
  double scale = 1,
  String? errorCode,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  final content = _content(status, errorCode: errorCode);
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

  for (final (status, code, expected) in [
    ('skipped', 'monthly_limit_exceeded', _limit),
    ('skipped', 'ai_consent_required', _consent),
    ('queued', 'ai_consent_required', _building),
    ('processing', 'ai_consent_required', _building),
    ('failed', 'ai_consent_required', _failed),
    ('completed', 'ai_consent_required', _saved),
    ('not_requested', 'ai_consent_required', _saved),
    ('skipped', 'daily_limit_exceeded', _saved),
    ('skipped', 'unsupported_content', _saved),
    ('skipped', 'unknown_future_reason', _saved),
    ('skipped', null, _saved),
    ('queued', 'monthly_limit_exceeded', _building),
    ('processing', 'monthly_limit_exceeded', _building),
    ('failed', 'monthly_limit_exceeded', _failed),
    ('completed', 'monthly_limit_exceeded', _saved),
    ('not_requested', 'monthly_limit_exceeded', _saved),
    ('unknown_future_status', 'monthly_limit_exceeded', _saved),
  ]) {
    testWidgets(
      '$status with reason $code shows its copy in the summary slot',
      (tester) async {
        await _pump(tester, status, errorCode: code);
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
      },
    );
  }

  testWidgets('limit copy replaces the saved text in semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, 'skipped', errorCode: 'monthly_limit_exceeded');
    expect(find.bySemanticsLabel(_limit), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(_saved)), findsNothing);
    semantics.dispose();
  });

  for (final width in [320.0, 375.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('limit copy fits Pretendard width $width scale $scale', (
        tester,
      ) async {
        await _pump(
          tester,
          'skipped',
          errorCode: 'monthly_limit_exceeded',
          width: width,
          scale: scale,
        );
        expect(tester.widget<Text>(_summary).data, _limit);
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
}
