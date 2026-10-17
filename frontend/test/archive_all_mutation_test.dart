// Additional post-freeze unit regression. This file is not imported by the
// native fixture, and does not change its fixed data/source/BEFORE matrix.
import 'package:clipback_frontend/shared/content/content_actions.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/archive_all_preview.dart';

class _Calls {
  int body = 0;
  int bookmark = 0;
  int category = 0;
  int delete = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double width,
  required ContentItem content,
  required bool archiveAllStyle,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: ContentListCard(
              content: content,
              archiveAllStyle: archiveAllStyle,
              bookmarked: content.bookmarked,
              categories: archiveAllCategories(),
              onTap: () => calls.body++,
              onToggleBookmark: () => calls.bookmark++,
              onChangeCategory: (_) => calls.category++,
              onDelete: () => calls.delete++,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

Finder _bookmark(ContentItem content) =>
    find.byKey(ValueKey('list-bookmark-${content.title}'));

Finder _more(ContentItem content, bool archiveAllStyle) {
  if (archiveAllStyle) {
    return find.byKey(ValueKey('archive-all-more-${content.id}'));
  }
  return find.descendant(
    of: find.byType(ContentListCard),
    matching: find.byWidgetPredicate(
      (w) => w is SvgIconButton && w.asset == Assets.more,
    ),
  );
}

Offset _point(Rect rect, String place) => switch (place) {
  'top' => Offset(rect.center.dx, rect.top + 1),
  'bottom' => Offset(rect.center.dx, rect.bottom - 1),
  _ => rect.center,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        'mutation lock retains visible hit28 controls and body action $platform width$width',
        (tester) async {
          addTearDown(tester.view.reset);
          final content = archiveAllContents().first.copyWith(
            mutationLabel: '변경 중…',
          );
          for (final archiveAllStyle in [false, true]) {
            final calls = await _pump(
              tester,
              platform: platform,
              width: width,
              content: content,
              archiveAllStyle: archiveAllStyle,
            );
            final bookmark = _bookmark(content),
                more = _more(content, archiveAllStyle);
            expect(bookmark, findsOneWidget);
            expect(more, findsOneWidget);
            expect(tester.getSize(bookmark), const Size(28, 28));
            expect(tester.getSize(more), const Size(28, 28));
            expect(find.text('변경 중…'), findsOneWidget);
            for (final target in [bookmark, more]) {
              for (final point in ['center', 'top', 'bottom']) {
                await tester.tapAt(_point(tester.getRect(target), point));
                await tester.pumpAndSettle();
                expect(calls.bookmark, 0);
                expect(calls.category, 0);
                expect(calls.delete, 0);
                expect(find.byType(ContentActionSheet), findsNothing);
              }
            }
            // The existing parent card action stays available while a write
            // is pending. Do not invent a policy for gesture fall-through from
            // a disabled nested control; check the deliberate body tap itself.
            final bodyBefore = calls.body;
            await tester.tap(find.text(content.title));
            await tester.pumpAndSettle();
            expect(calls.body - bodyBefore, 1);
            expect(calls.bookmark, 0);
            expect(tester.takeException(), isNull);
          }
        },
      );
      testWidgets(
        'unlocked center and full top-bottom hit28 dispatch once $platform width$width',
        (tester) async {
          addTearDown(tester.view.reset);
          final content = archiveAllContents().first;
          for (final archiveAllStyle in [false, true]) {
            final calls = await _pump(
              tester,
              platform: platform,
              width: width,
              content: content,
              archiveAllStyle: archiveAllStyle,
            );
            for (final point in ['center', 'top', 'bottom']) {
              final before = calls.bookmark;
              await tester.tapAt(
                _point(tester.getRect(_bookmark(content)), point),
              );
              await tester.pumpAndSettle();
              expect(calls.bookmark - before, 1);
              expect(calls.body, 0);
              expect(find.byType(ContentActionSheet), findsNothing);
            }
            for (final point in ['center', 'top', 'bottom']) {
              final more = _more(content, archiveAllStyle);
              expect(tester.getSize(more), const Size(28, 28));
              await tester.tapAt(_point(tester.getRect(more), point));
              await tester.pumpAndSettle();
              expect(find.byType(ContentActionSheet), findsOneWidget);
              final sheet = tester.widget<ContentActionSheet>(
                find.byType(ContentActionSheet),
              );
              expect(sheet.content, same(content));
              expect(calls.body, 0);
              expect(calls.category, 0);
              expect(calls.delete, 0);
              Navigator.of(
                tester.element(find.byType(ContentActionSheet)),
              ).pop();
              await tester.pumpAndSettle();
              expect(find.byType(ContentActionSheet), findsNothing);
            }
            await tester.tap(find.text(content.title));
            await tester.pumpAndSettle();
            expect(calls.body, 1);
            expect(calls.bookmark, 3);
            expect(tester.takeException(), isNull);
          }
        },
      );
      testWidgets(
        'model display guard preserves duplicate category IDs and order $platform width$width',
        (tester) async {
          addTearDown(tester.view.reset);
          final categories = archiveAllCategories();
          final content = archiveAllContents().first.copyWith(
            categories: [categories[1], categories[1], categories[0]],
          );
          await _pump(
            tester,
            platform: platform,
            width: width,
            content: content,
            archiveAllStyle: true,
          );
          final wrap = find.byKey(ValueKey('archive-all-badges-${content.id}'));
          final names = tester
              .widgetList<Text>(
                find.descendant(of: wrap, matching: find.byType(Text)),
              )
              .map((w) => w.data)
              .toList();
          expect(names, [
            categories[1].name,
            categories[1].name,
            categories[0].name,
          ]);
          expect(content.categories.map((c) => c.id), [102, 102, 101]);
          expect(tester.takeException(), isNull);
          // This malformed-model guard is not a promise that the server emits
          // duplicate membership, and does not add deduplication policy.
        },
      );
    }
  }
}
