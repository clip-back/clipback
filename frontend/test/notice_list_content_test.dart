// Added after the native BEFORE freeze: arbitrary supplied titles require the
// newly introduced public NoticeListScreen constructor. Not a baseline claim.
import 'dart:math' as math;
import 'package:clipback_frontend/features/account/notice_list_screen.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/notice_alignment_fixture.dart' as fixture;

Future<void> _show(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double width,
  required List<String> titles,
  VoidCallback? onBack,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 480);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
      ),
      home: NoticeListScreen(titles: titles, onBack: onBack ?? () {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await fixture.noticeLoadFonts(loadForTest: true);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width supplied long title wraps and grows without font reduction or ellipsis',
        (tester) async {
          final title = List.filled(
                18,
                '긴 공지 제목도 원문을 줄이거나 생략하지 않고 필요한 높이만큼 자연스럽게 보여 줍니다.',
              ).join(' '),
              titles = [title],
              original = List<String>.from([title]);
          await _show(tester, platform: platform, width: width, titles: titles);
          final text = find.byKey(const ValueKey('notice-title-0')),
              rich = find.descendant(of: text, matching: find.byType(RichText)),
              paragraph = tester.renderObject<RenderParagraph>(rich),
              style = (paragraph.text as TextSpan).style!;
          expect(style.fontFamily, 'Pretendard');
          expect(style.fontSize, 18);
          expect(style.fontWeight, FontWeight.w500);
          expect(style.letterSpacing, -.45);
          expect(style.height, isNull);
          expect(paragraph.textScaler.scale(18), 18);
          expect(paragraph.maxLines, isNull);
          expect(paragraph.softWrap, isTrue);
          expect(paragraph.overflow, TextOverflow.visible);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.text.toPlainText(), title);
          final row = tester.getRect(
                find.byKey(const ValueKey('notice-row-0')),
              ),
              p = tester.getRect(rich);
          expect(row.height, greaterThan(79));
          expect(row.height, closeTo(math.max(79, p.height + 32), .18));
          expect(p.left - row.left, closeTo(16, .18));
          expect(row.right - p.right, greaterThanOrEqualTo(15.8));
          final position = fixture.noticePosition(
            tester.element(find.byType(NoticeListScreen)),
          )!;
          expect(position.maxScrollExtent, greaterThan(0));
          for (
            var i = 0;
            i < 20 && (position.pixels - position.maxScrollExtent).abs() > .2;
            i++
          ) {
            await tester.drag(
              find.byKey(const ValueKey('notice-viewport')),
              const Offset(0, -300),
            );
            await tester.pumpAndSettle();
          }
          expect(position.pixels, closeTo(position.maxScrollExtent, .2));
          final m = fixture.noticeMeasure(
                tester.element(find.byType(NoticeListScreen)),
              ),
              j = fixture.noticeJudgment(m);
          for (final pair in {
            'stylePassed': 'styleFailures',
            'layoutPassed': 'layoutFailures',
            'assetPassed': 'assetFailures',
          }.entries) {
            expect(j[pair.key], isTrue, reason: '${j[pair.value]}');
          }
          expect(titles, original);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('standalone header and OS back invoke only the caller callback', (
    tester,
  ) async {
    var backs = 0;
    await _show(
      tester,
      platform: TargetPlatform.iOS,
      width: 375,
      titles: const ['공지 원문'],
      onBack: () => backs++,
    );
    await tester.tap(find.byKey(const ValueKey('notice-back-hit')));
    await tester.pumpAndSettle();
    expect(backs, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(backs, 2);
    expect(find.byType(NoticeListScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
