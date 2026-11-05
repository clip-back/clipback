import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/home_base_alignment_fixture.dart' as fixture;

const _emptyCategory = CategoryItem(
  id: 99,
  name: '가나다라마바사아자차카타파하가나다라마바사아자차카타파하가나다라마바사아자차카타',
  color: AppColors.main,
  tint: AppColors.mainSubtle,
  deep: AppColors.mainDeep,
);
const _weekly = [
  ApiWeeklyRecommendationItem(
    id: 1,
    rank: 1,
    type: WeeklyCardType.mostSaved,
    category: ApiCategory(id: 1, name: '생활', color: null, isDefault: false),
  ),
  ApiWeeklyRecommendationItem(
    id: 2,
    rank: 2,
    type: WeeklyCardType.mostViewed,
    category: ApiCategory(id: 2, name: '여행', color: null, isDefault: false),
  ),
];

Future<void> _render(
  WidgetTester tester, {
  required String state,
  required bool weekly,
  required Size size,
  required double scale,
  required double inset,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  final padding = FakeViewPadding(top: 24, bottom: inset);
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
  final items = state == 'saved'
      ? fixture.homeBaseContents()
      : state == 'short'
      ? fixture.homeBaseContents().take(1).toList()
      : fixture.homeBaseContents().take(0).toList();
  final feed = FeedPage()
    ..initialized = true
    ..hasMore = false
    ..categoryId = state == 'chip' ? _emptyCategory.id : null
    ..items.addAll(items);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: HomeScreen(
        contents: items,
        feed: feed,
        categories: const [_emptyCategory],
        activeCategoryId: feed.categoryId,
        weeklyItems: weekly ? _weekly : const [],
        bookmarkedIds: const {},
        onSearch: () {},
        onOpenArchive: () {},
        onOpenCategories: () {},
        onOpenToday: () {},
        onOpenContent: (_) {},
        onToggleBookmark: (_) {},
        onAddLink: ({required url, category}) async =>
            fixture.homeBaseContents().first,
        onAddScreenshot:
            ({
              required bytes,
              required filename,
              String? submissionKey,
              category,
            }) async => fixture.homeBaseContents().first,
        onTab: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('home-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void _expectWhiteThroughNavigation(WidgetTester tester, {bool atEnd = false}) {
  final panel = tester.getRect(find.byType(HomeContentPanel));
  final navigation = tester.getRect(find.byType(ClipbackNavigationBar));
  expect(panel.left, navigation.left);
  expect(panel.right, navigation.right);
  expect(panel.bottom, greaterThanOrEqualTo(navigation.top - 0.01));
  if (atEnd) expect(panel.bottom, closeTo(navigation.top, 0.01));
  final surface = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(HomeContentPanel),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = surface.decoration! as BoxDecoration;
  expect(decoration.color, const Color(0xFFFFFFFF));
  expect(
    decoration.borderRadius,
    const BorderRadius.vertical(top: Radius.circular(16)),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  for (final state in ['saved', 'empty', 'short']) {
    testWidgets('$state panel reaches navigation at scroll end', (
      tester,
    ) async {
      await _render(
        tester,
        state: state,
        weekly: state != 'short',
        size: state == 'short' ? const Size(393, 1200) : const Size(375, 640),
        scale: 1,
        inset: 34,
      );
      final position = _position(tester);
      if (state == 'short') expect(position.maxScrollExtent, 0);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      _expectWhiteThroughNavigation(tester, atEnd: true);
    });
  }

  for (final state in ['saved', 'empty', 'short', 'chip']) {
    for (final weekly in [false, true]) {
      for (final size in [const Size(375, 640), const Size(393, 1200)]) {
        for (final scale in [1.0, 1.3]) {
          for (final inset in [0.0, 34.0]) {
            testWidgets(
              '$state weekly=$weekly $size scale=$scale inset=$inset white at start/end',
              (tester) async {
                await _render(
                  tester,
                  state: state,
                  weekly: weekly,
                  size: size,
                  scale: scale,
                  inset: inset,
                );
                final hero = tester.getRect(find.byType(HomeHero));
                final panel = tester.getRect(find.byType(HomeContentPanel));
                expect(hero.top, 24);
                expect(panel.top, hero.bottom);
                expect(
                  tester.widget<HomeHero>(find.byType(HomeHero)).empty,
                  state == 'empty',
                );
                expect(
                  Theme.of(
                    tester.element(find.byType(HomeHero)),
                  ).scaffoldBackgroundColor,
                  const Color(0xFFF5F5F5),
                );
                if (state == 'chip') {
                  expect(find.byType(HomeFilteredEmptyContent), findsOneWidget);
                  expect(_emptyCategory.name.length, 40);
                }
                final position = _position(tester);
                expect(position.pixels, 0);
                _expectWhiteThroughNavigation(tester);
                // Each long-screen case fits naturally: filling the remainder
                // must not introduce a vertical scroll just for blank space.
                if (size.height == 1200) {
                  expect(position.maxScrollExtent, 0);
                }
                position.jumpTo(position.maxScrollExtent);
                await tester.pumpAndSettle();
                expect(position.pixels, position.maxScrollExtent);
                _expectWhiteThroughNavigation(tester, atEnd: true);
                final lastContent = tester.getRect(
                  find.byType(
                    state == 'saved' || state == 'short'
                        ? PageDots
                        : state == 'chip'
                        ? HomeFilteredEmptyContent
                        : EmptyHomeContent,
                  ),
                );
                final navigation = tester.getRect(
                  find.byType(ClipbackNavigationBar),
                );
                expect(lastContent.top, greaterThanOrEqualTo(24));
                expect(
                  lastContent.bottom,
                  lessThanOrEqualTo(navigation.top - 32 + 0.01),
                );
              },
            );
          }
        }
      }
    }
  }
}
