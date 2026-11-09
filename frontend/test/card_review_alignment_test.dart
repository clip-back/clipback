import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/card_review_alignment_preview.dart' as fixture;

class _Calls {
  final opened = <String>[], bookmarked = <String>[];
  int exits = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  int count = 5,
  bool longTitle = false,
  bool shortBody = false,
  bool originalEmpty = false,
  bool longBadge = false,
  String category = '일상',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: fixture.reviewTheme(platform: platform),
      home: PhoneFrame(
        child: CategoryCardReviewScreen(
          contents: fixture.reviewContents(
            count: count,
            longTitle: longTitle,
            shortBody: shortBody,
            originalEmpty: originalEmpty,
            longBadge: longBadge,
          ),
          categoryName: category,
          bookmarkedIds: const {},
          onExit: () => calls.exits++,
          onOpenContent: (c) => calls.opened.add(c.id),
          onToggleBookmark: (c) => calls.bookmarked.add(c.id),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

Map<String, Object?> _m(WidgetTester tester) => fixture.reviewMeasure(
  tester.element(find.byType(CategoryCardReviewScreen)),
);
Finder get _active => find.byType(CategoryReviewCard).last;
Future<void> _advance(WidgetTester tester) async {
  await tester.drag(_active, const Offset(0, -130));
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width G02 fixed direct geometry styles and exact progress',
        (tester) async {
          await _pump(tester, platform: platform, width: width);
          final m = _m(tester), j = fixture.reviewJudgment(m);
          expect(j['stylePassed'], isTrue, reason: '${j['styleFailures']}');
          expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
          expect(j['assetPassed'], isTrue, reason: '${j['assetFailures']}');
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        '${platform.name} $width remaining body fits full lines for short long titles',
        (tester) async {
          for (final long in [false, true]) {
            for (final short in [false, true]) {
              await _pump(
                tester,
                platform: platform,
                width: width,
                longTitle: long,
                shortBody: short,
              );
              final m = _m(tester),
                  f = (m['cards'] as List).firstWhere(
                    (c) => c['front'] == true,
                  ),
                  body = f['body'] as Map;
              expect(body['fontSize'], 16);
              expect(body['fontWeight'], 400);
              expect(body['overflow'], 'ellipsis');
              expect(body['maxLines'], body['expectedFullLines']);
              expect(
                (body['lastPaintedLineBottom'] as num),
                lessThanOrEqualTo((body['localHeight'] as num) + .2),
              );
              if (!short) {
                expect(body['maxLines'] as int, greaterThan(11));
                expect(body['didExceedMaxLines'], isTrue);
              } else {
                expect(body['fullLineCount'], 1);
                expect(body['didExceedMaxLines'], isFalse);
              }
              expect(f['title']['maxLines'], 2);
              expect(f['title']['overflow'], 'ellipsis');
              expect(tester.takeException(), isNull);
            }
          }
        },
      );
      testWidgets(
        '${platform.name} $width long category keeps one line and actual data',
        (tester) async {
          const category = '길이가 매우 길어져도 실제 이름을 보존하는 카테고리 이름';
          await _pump(
            tester,
            platform: platform,
            width: width,
            category: category,
            longBadge: true,
          );
          final m = _m(tester), p = m['category'] as Map;
          expect(p['text'], category);
          expect(p['maxLines'], 1);
          expect(p['overflow'], 'ellipsis');
          expect(p['didExceedMaxLines'], isTrue);
          expect(p['fontSize'], 24);
          final f = (m['cards'] as List).firstWhere((c) => c['front'] == true),
              badge = f['badge'] as Map;
          expect(badge['maxLines'], 1);
          expect(badge['overflow'], 'ellipsis');
          expect(badge['didExceedMaxLines'], isTrue);
          expect(badge['color'], f['badgeColor']);
          expect(f['badgeSurface']['fill'], f['badgeTint']);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'empty original uses actual summary without a new fallback policy',
    (tester) async {
      await _pump(tester, originalEmpty: true);
      final m = _m(tester),
          f = (m['cards'] as List).firstWhere((c) => c['front'] == true);
      expect(f['body']['text'], '원문이 없을 때 실제 요약을 표시해요.');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('count 0 drag callback completion and existing empty state', (
    tester,
  ) async {
    final c = await _pump(tester, count: 0);
    expect(find.byType(EmptyStatePanel), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(c.exits, 0);
    await tester.tap(find.text('나가기'));
    expect(c.exits, 1);
    expect(tester.takeException(), isNull);
  });
  // #309: 마지막 카드의 넘김 전환이 끝나면 나가기와 같은 복귀를 한 번만 한다.
  for (final count in [1, 2, 3, 4, 5]) {
    testWidgets(
      'count $count drag callback completion auto exits once after last card',
      (tester) async {
        final c = await _pump(tester, count: count);
        expect(
          tester
              .widget<CardPagerProgress>(find.byType(CardPagerProgress))
              .count,
          count,
        );
        expect(
          tester
              .widget<CardPagerProgress>(find.byType(CardPagerProgress))
              .activeIndex,
          0,
        );
        final initial = _m(tester);
        expect(
          (initial['cards'] as List).length +
              (initial['backgrounds'] as List).length,
          1 + (count - 1).clamp(0, 2),
        );
        final star = find.descendant(
          of: _active,
          matching: find.byWidgetPredicate(
            (w) => w is InkWell && w.customBorder is CircleBorder,
          ),
        );
        await tester.tap(star);
        expect(c.bookmarked, ['review-1']);
        expect(c.opened, isEmpty);
        await tester.tap(
          find.descendant(of: _active, matching: find.text('다시 확인할 정보 1')),
        );
        expect(c.opened, ['review-1']);
        final gesture = await tester.startGesture(tester.getCenter(_active));
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 500));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CardPagerProgress>(find.byType(CardPagerProgress))
              .activeIndex,
          0,
        );
        expect(c.exits, 0);
        for (var i = 0; i < count - 1; i++) {
          await _advance(tester);
          expect(
            tester
                .widget<CardPagerProgress>(find.byType(CardPagerProgress))
                .activeIndex,
            i + 1,
          );
          expect(c.exits, 0);
        }
        await tester.drag(_active, const Offset(0, -130));
        await tester.pump(const Duration(milliseconds: 200));
        expect(c.exits, 0);
        await tester.pump(const Duration(milliseconds: 50));
        expect(c.exits, 1);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        expect(c.exits, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('drag during the last transition still auto exits once', (
    tester,
  ) async {
    final c = await _pump(tester, count: 1);
    await tester.drag(_active, const Offset(0, -130));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(_active, const Offset(-200, 0), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.exits, 0);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(c.exits, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('removing the screen before the last transition ends is quiet', (
    tester,
  ) async {
    final c = await _pump(tester, count: 1);
    await tester.drag(_active, const Offset(0, -130));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(c.exits, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shared progress default remains original24 and circles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 343,
              child: CardPagerProgress(activeIndex: 1, count: 5),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CardPagerProgress)).height, 24);
    final dots = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    expect(dots.length, 5);
    expect(dots[1].constraints!.maxWidth, 16);
    expect(dots[0].constraints!.maxWidth, 8);
    expect(tester.takeException(), isNull);
  });
}
