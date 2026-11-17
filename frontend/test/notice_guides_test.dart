// #420: in-app usage guide notices. The list rows, the detail screen and the
// home card are judged on real Pretendard fonts; root flows use the app with
// the weekly memory server and assert only screens, callbacks and requests.
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/notice_detail_screen.dart';
import 'package:clipback_frontend/features/account/notice_list_screen.dart';
import 'package:clipback_frontend/features/account/notices.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'weekly_root_test.dart' show withHome, home, weekly, exposures;

Future<void> _fonts() async {
  final pretendard = FontLoader('Pretendard');
  for (final weight in ['Regular', 'Medium', 'SemiBold']) {
    pretendard.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
  }
  await pretendard.load();
  final bold = FontLoader('PretendardDetail')
    ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'));
  await bold.load();
}

Future<void> _show(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double height = 812,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)).first,
    );

void _style(
  RenderParagraph p, {
  required double size,
  required FontWeight weight,
  required Color color,
  double? height,
  String family = 'Pretendard',
}) {
  final s = (p.text as TextSpan).style!;
  expect(s.fontFamily, family);
  expect(s.fontSize, size);
  expect(s.fontWeight, weight);
  expect(s.color, color);
  expect(s.height, height);
  expect(s.letterSpacing ?? 0, 0);
  expect(p.maxLines, isNull);
  expect(p.overflow, TextOverflow.clip);
  expect(p.didExceedMaxLines, isFalse);
}

Finder _text(String value) => find.text(value);

Future<void> _scrollDetailToEnd(WidgetTester tester) async {
  final scroll = find.byKey(const ValueKey('notice-detail-scroll'));
  final position = tester
      .state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
      )
      .position;
  for (var i = 0; i < 40 && position.pixels < position.maxScrollExtent; i++) {
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  expect(position.pixels, closeTo(position.maxScrollExtent, .2));
}

void main() {
  setUpAll(_fonts);

  test('two pinned guides in order, published 2026. 11. 23', () {
    expect(notices.map((n) => n.title), ['허투루 100% 활용법', '허투루 사용이 처음이라면?']);
    for (final notice in notices) {
      expect(notice.pinned, isTrue);
      expect(notice.publishedLabel, '2026. 11. 23');
      expect(notice.steps, hasLength(5));
    }
    // #420 Q8: the app has no "전문 보기" and spells "랜덤 보기".
    expect(usageGuideNotice.steps[2].body, isNot(contains('전문 보기')));
    expect(firstTimeNotice.steps[2].note, isNot(contains('전문 보기')));
    expect(usageGuideNotice.steps[4].body, contains('아카이브의 랜덤 보기로'));
    expect(usageGuideNotice.intro, contains('사진.\n허투루에서'));
  });

  group('notice list', () {
    testWidgets('a row is one button read as pin, title and date', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final opened = <Notice>[];
        await _show(
          tester,
          NoticeListScreen(notices: notices, onBack: () {}, onOpen: opened.add),
        );
        final rows = tester.semantics.simulatedAccessibilityTraversal().where(
          (n) => n.label.contains('허투루'),
        );
        expect(rows.map((n) => n.label), [
          '고정 공지, 허투루 100% 활용법, 2026. 11. 23',
          '고정 공지, 허투루 사용이 처음이라면?, 2026. 11. 23',
        ]);
        for (final row in rows) {
          final data = row.getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
        }
        expect(find.bySemanticsLabel(RegExp('📌')), findsNothing);
        tester.semantics.tap(find.semantics.byLabel(RegExp('처음이라면')));
        await tester.pumpAndSettle();
        expect(opened, [firstTimeNotice]);
      } finally {
        semantics.dispose();
      }
    });

    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$width x$scale titles wrap beside the arrow', (
          tester,
        ) async {
          await _show(
            tester,
            NoticeListScreen(notices: notices, onBack: () {}, onOpen: (_) {}),
            width: width,
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          for (var i = 0; i < notices.length; i++) {
            final title = tester.getRect(
              find.byKey(ValueKey('notice-title-$i')),
            );
            final arrow = tester.getRect(
              find.byKey(ValueKey('notice-arrow-$i')),
            );
            expect(title.right, lessThanOrEqualTo(arrow.left - 8 + .2));
            final row = tester.getRect(find.byKey(ValueKey('notice-row-$i')));
            expect(row.height, greaterThanOrEqualTo(81.8));
          }
          // Measured: only 처음이라면 at 320 x1.3 needs two lines.
          final second = _paragraph(
            tester,
            find.byKey(const ValueKey('notice-title-1')),
          );
          final lines = second.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: notices[1].title.length),
          );
          final tops = lines.map((b) => b.top.round()).toSet();
          expect(tops.length, width == 320 && scale == 1.3 ? 2 : 1);
        });
      }
    }
  });

  group('notice detail', () {
    testWidgets('roles, order and gaps follow Figma 423:4520', (tester) async {
      await _show(
        tester,
        NoticeDetailScreen(notice: usageGuideNotice, onBack: () {}),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.surface);
      final header = tester.getRect(
        find.byKey(const ValueKey('notice-header')),
      );
      expect(header.height, 64);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('notice-header')),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      final title = _text('허투루 100% 활용법');
      _style(
        _paragraph(tester, title),
        size: 25,
        weight: FontWeight.w700,
        color: AppColors.text,
        height: 1.5,
        family: 'PretendardDetail',
      );
      _style(
        _paragraph(tester, _text('2026. 11. 23')),
        size: 15,
        weight: FontWeight.w400,
        color: AppColors.middle,
        height: 1.5,
      );
      _style(
        _paragraph(tester, _text('저장한 정보, 다시 꺼내 쓰세요.')),
        size: 17,
        weight: FontWeight.w600,
        color: AppColors.text,
        height: 1.5,
      );
      _style(
        _paragraph(tester, _text(usageGuideNotice.intro)),
        size: 16,
        weight: FontWeight.w400,
        color: AppColors.text,
        height: 1.6,
      );
      _style(
        _paragraph(tester, _text('STEP 01')),
        size: 13,
        weight: FontWeight.w600,
        color: AppColors.middle,
        height: 1.5,
      );
      _style(
        _paragraph(tester, _text(usageGuideNotice.steps.first.note!)),
        size: 15,
        weight: FontWeight.w400,
        color: AppColors.middle,
        height: 1.6,
      );
      final titleRect = tester.getRect(title),
          date = tester.getRect(_text('2026. 11. 23')),
          divider = tester.getRect(
            find.byKey(const ValueKey('notice-detail-divider')),
          ),
          introTitle = tester.getRect(_text('저장한 정보, 다시 꺼내 쓰세요.')),
          intro = tester.getRect(_text(usageGuideNotice.intro)),
          step = tester.getRect(_text('STEP 01')),
          stepTitle = tester.getRect(_text('링크와 사진을 저장해요')),
          stepBody = tester.getRect(_text(usageGuideNotice.steps.first.body)),
          stepNote = tester.getRect(_text(usageGuideNotice.steps.first.note!));
      expect(titleRect.top - header.bottom, 8);
      expect(titleRect.left, 24);
      expect(date.top - titleRect.bottom, 8);
      expect(divider.top - date.bottom, 28);
      expect(divider.height, 1);
      expect(divider.width, 375 - 48);
      final line = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const ValueKey('notice-detail-divider')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(line.color, const Color(0xFFE5E5E5));
      expect(introTitle.top - divider.bottom, 28);
      expect(intro.top - introTitle.bottom, 10);
      expect(step.top - intro.bottom, 28);
      expect(stepTitle.top - step.bottom, 12);
      expect(stepBody.top - stepTitle.bottom, 12);
      expect(stepNote.top - stepBody.bottom, 12);
      expect(tester.takeException(), isNull);
    });

    for (final notice in notices) {
      for (final width in [320.0, 375.0]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets(
            '${notice.title} $width x$scale scrolls to the last guide line',
            (tester) async {
              await _show(
                tester,
                NoticeDetailScreen(notice: notice, onBack: () {}),
                width: width,
                scale: scale,
              );
              expect(tester.takeException(), isNull);
              for (final text in [
                notice.title,
                notice.introTitle,
                for (var i = 0; i < 5; i++) 'STEP 0${i + 1}',
                for (final step in notice.steps) ...[
                  step.title,
                  step.body,
                  ?step.note,
                ],
                notice.closingTitle,
                notice.closing,
                noticeFooter,
              ]) {
                expect(find.text(text), findsOneWidget, reason: text);
              }
              await _scrollDetailToEnd(tester);
              final footer = find.text(noticeFooter);
              expect(footer.hitTestable(), findsOneWidget);
              final scroll = tester.getRect(
                find.byKey(const ValueKey('notice-detail-scroll')),
              );
              expect(scroll.bottom - tester.getRect(footer).bottom, 32);
              expect(scroll.bottom, 812 - 34);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('screen reader reads back, then text in screen order', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _show(
          tester,
          NoticeDetailScreen(notice: firstTimeNotice, onBack: () {}),
          height: 4000,
        );
        final labels = tester.semantics
            .simulatedAccessibilityTraversal()
            .map((n) => n.label)
            .where((l) => l.isNotEmpty)
            .toList();
        expect(labels.first, '뒤로가기');
        final order = [
          firstTimeNotice.title,
          '2026. 11. 23',
          firstTimeNotice.introTitle,
          firstTimeNotice.intro,
          'STEP 01',
          firstTimeNotice.steps.first.title,
          firstTimeNotice.closing,
          noticeFooter,
        ].map(labels.indexOf).toList();
        expect(order, everyElement(greaterThan(0)));
        expect(order, [...order]..sort());
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('header and OS back invoke only the caller callback', (
      tester,
    ) async {
      var backs = 0;
      await _show(
        tester,
        NoticeDetailScreen(notice: usageGuideNotice, onBack: () => backs++),
      );
      await tester.tap(find.byKey(const ValueKey('notice-back-hit')));
      await tester.pumpAndSettle();
      expect(backs, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(backs, 2);
      expect(find.byType(NoticeDetailScreen), findsOneWidget);
    });
  });

  group('home notice card', () {
    final picks = [
      ApiWeeklyRecommendationItem(
        id: 11,
        rank: 1,
        type: WeeklyCardType.mostSaved,
        category: ApiCategory(
          id: 1,
          name: '여행',
          color: '#FFD75C',
          isDefault: false,
        ),
      ),
    ];
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$width x$scale last card, 133 wide, two lines at most', (
          tester,
        ) async {
          var opened = 0, selected = 0, exposed = 0;
          await _show(
            tester,
            Scaffold(
              body: WeeklyPickRail(
                items: picks,
                onOpenCategory: () {},
                onSelected: (_) => selected++,
                onExposed: (_) => exposed++,
                onOpenNotice: () => opened++,
              ),
            ),
            width: width,
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          final card = find.byKey(const ValueKey('weekly-notice-card'));
          final pick = tester.getRect(
            find.byKey(const ValueKey('weekly-card-11')),
          );
          final rect = tester.getRect(card);
          expect(rect.left - pick.right, 8);
          expect(rect.width, 133);
          expect(rect.height, pick.height);
          if (scale == 1) expect(rect.height, 120);
          final box = tester.widget<Container>(
            find.descendant(of: card, matching: find.byType(Container)).first,
          );
          final decoration = box.decoration! as BoxDecoration;
          expect(decoration.color, AppColors.main);
          expect(decoration.border, isNull);
          expect(decoration.borderRadius, BorderRadius.circular(8));
          expect(box.foregroundDecoration, isNull);
          final label = _paragraph(tester, find.text('공지사항'));
          expect((label.text as TextSpan).style!.fontSize, 14);
          expect((label.text as TextSpan).style!.fontWeight, FontWeight.w500);
          expect((label.text as TextSpan).style!.color, AppColors.middle);
          final title = _paragraph(tester, find.text('허투루\n100% 활용법'));
          final style = (title.text as TextSpan).style!;
          expect(style.fontSize, 16);
          expect(style.fontWeight, FontWeight.w600);
          expect(style.height, 1.5);
          expect(title.maxLines, 2);
          expect(title.overflow, TextOverflow.ellipsis);
          // Measured: "100% 활용법" is wider than 96 at x1.3 and is cut short.
          expect(title.didExceedMaxLines, scale == 1.3);
          await tester.tap(card);
          expect(opened, 1);
          expect(selected, 0);
          await tester.pumpAndSettle();
          expect(exposed, 0);
        });
      }
    }

    testWidgets('without picks the card stays, read as one button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var opened = 0;
        await _show(
          tester,
          Scaffold(
            body: WeeklyPickRail(
              onOpenCategory: () {},
              onOpenNotice: () => opened++,
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('weekly-notice-card')),
          findsOneWidget,
        );
        final node = tester.getSemantics(
          find.byKey(const ValueKey('weekly-notice-card')),
        );
        expect(node.label, '공지사항, 허투루 100% 활용법');
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        tester.semantics.tap(find.semantics.byLabel('공지사항, 허투루 100% 활용법'));
        expect(opened, 1);
      } finally {
        semantics.dispose();
      }
    });
  });

  group('root flows', () {
    testWidgets(
      'My -> notices -> detail -> back keeps list and My scroll; no requests',
      (t) async {
        await withHome(t, (s) async {
          home(t).onTab(AppRoute.my);
          await t.pumpAndSettle();
          final myScroll = find.byType(Scrollable).first;
          await t.drag(myScroll, const Offset(0, -120));
          await t.pumpAndSettle();
          final myOffset = t.state<ScrollableState>(myScroll).position.pixels;
          expect(myOffset, greaterThan(0));
          final calls = s.calls.length;
          await t.tap(find.text('공지사항'));
          await t.pumpAndSettle();
          expect(find.byType(NoticeListScreen), findsOneWidget);
          await t.tap(find.text('허투루 사용이 처음이라면?'));
          await t.pumpAndSettle();
          expect(find.byType(NoticeDetailScreen), findsOneWidget);
          expect(find.text(firstTimeNotice.introTitle), findsOneWidget);
          await _scrollDetailToEnd(t);
          await t.tap(find.byKey(const ValueKey('notice-back-hit')));
          await t.pumpAndSettle();
          expect(find.byType(NoticeListScreen), findsOneWidget);
          await t.tap(find.text('허투루 100% 활용법'));
          await t.pumpAndSettle();
          // A newly opened guide starts at its top.
          expect(
            find.text(usageGuideNotice.title).hitTestable(),
            findsOneWidget,
          );
          await t.binding.handlePopRoute();
          await t.pumpAndSettle();
          expect(find.byType(NoticeListScreen), findsOneWidget);
          // Notices send nothing; entering My again refreshes its stats.
          expect(s.calls.length, calls);
          await t.binding.handlePopRoute();
          await t.pumpAndSettle();
          expect(find.byType(MyScreen), findsOneWidget);
          expect(
            t
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .pixels,
            myOffset,
          );
        }, size: const Size(393, 600));
      },
    );

    testWidgets(
      'home bell opens notices over home; detail -> list -> home keeps home',
      (t) async {
        final semantics = t.ensureSemantics();
        try {
          await withHome(t, (s) async {
            final scroll = find.byKey(const ValueKey('home-scroll'));
            final vertical = t
                .state<ScrollableState>(
                  find
                      .descendant(of: scroll, matching: find.byType(Scrollable))
                      .first,
                )
                .position;
            vertical.jumpTo(16);
            await t.pumpAndSettle();
            final offset = vertical.pixels;
            expect(offset, closeTo(16, .2));
            final homeElement = t.element(find.byType(HomeScreen));
            final calls = s.calls.length;
            await t.tap(find.bySemanticsLabel('알림'));
            await t.pumpAndSettle();
            expect(find.byType(NoticeListScreen), findsOneWidget);
            expect(find.byType(HomeScreen), findsNothing);
            expect(
              find.byType(HomeScreen, skipOffstage: false),
              findsOneWidget,
            );
            final labels = t.semantics
                .simulatedAccessibilityTraversal()
                .map((n) => n.label)
                .where((l) => l.isNotEmpty)
                .toList();
            expect(labels.take(2), ['뒤로가기', '공지사항']);
            expect(labels.join('\n'), isNot(contains('이번주 허투루 픽 🎯')));
            await t.tap(find.text('허투루 사용이 처음이라면?'));
            await t.pumpAndSettle();
            expect(find.byType(NoticeDetailScreen), findsOneWidget);
            await t.binding.handlePopRoute();
            await t.pumpAndSettle();
            expect(find.byType(NoticeListScreen), findsOneWidget);
            await t.tap(find.byKey(const ValueKey('notice-back-hit')));
            await t.pumpAndSettle();
            expect(find.byType(NoticeListScreen), findsNothing);
            expect(t.element(find.byType(HomeScreen)), same(homeElement));
            expect(vertical.pixels, offset);
            expect(s.calls.length, calls);
          }, size: const Size(320, 480));
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'home card opens the guide; back returns to the same home and visit',
      (t) async {
        await withHome(t, (s) async {
          final scroll = find.byKey(const ValueKey('home-scroll'));
          final card = find.byKey(const ValueKey('weekly-notice-card'));
          await t.ensureVisible(card);
          await t.pumpAndSettle();
          // The notice card follows the two weekly picks.
          final picks = home(t).weeklyItems;
          expect(picks, hasLength(2));
          expect(
            t.getRect(card).left,
            greaterThan(
              t
                  .getRect(find.byKey(ValueKey('weekly-card-${picks.last.id}')))
                  .right,
            ),
          );
          double homeOffset() => t
              .state<ScrollableState>(
                find
                    .descendant(of: scroll, matching: find.byType(Scrollable))
                    .first,
              )
              .position
              .pixels;
          t
              .state<ScrollableState>(
                find
                    .descendant(of: scroll, matching: find.byType(Scrollable))
                    .first,
              )
              .position
              .jumpTo(16);
          await t.pumpAndSettle();
          final offset = homeOffset();
          expect(offset, closeTo(16, .2));
          final gets = weekly(s).length, records = exposures(s).length;
          final homeElement = t.element(find.byType(HomeScreen));
          await t.tap(card);
          await t.pumpAndSettle();
          expect(find.byType(NoticeDetailScreen), findsOneWidget);
          expect(find.text(usageGuideNotice.introTitle), findsOneWidget);
          await t.binding.handlePopRoute();
          await t.pumpAndSettle();
          expect(find.byType(NoticeDetailScreen), findsNothing);
          expect(t.element(find.byType(HomeScreen)), same(homeElement));
          expect(homeOffset(), offset);
          await t.tap(card);
          await t.pumpAndSettle();
          await t.tap(find.byKey(const ValueKey('notice-back-hit')));
          await t.pumpAndSettle();
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(weekly(s), hasLength(gets));
          expect(exposures(s), hasLength(records));
        }, size: const Size(320, 480));
      },
    );
  });
}
