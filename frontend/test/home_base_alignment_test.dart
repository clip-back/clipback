import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'fixtures/home_base_alignment_fixture.dart' as fixture;
import 'support/archive_all_preview.dart' as archive;

FeedPage _feed(List<ContentItem> items) => FeedPage()
  ..initialized = true
  ..hasMore = false
  ..items.addAll(items);
Future<void> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  FeedPage? feed,
  List<ContentItem>? contents,
  int? categoryId,
}) async {
  final items = contents ?? fixture.homeBaseContents();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
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
      home: HomeScreen(
        contents: items,
        feed: feed ?? _feed(items),
        categories: archive.archiveAllCategories(),
        activeCategoryId: categoryId,
        bookmarkedIds: const {'api-602'},
        onSearch: () {},
        onOpenArchive: () {},
        onOpenCategories: () {},
        onOpenToday: () {},
        onOpenContent: (_) {},
        onToggleBookmark: (_) {},
        onAddLink: ({required url, category}) async =>
            fixture.homeBaseContents().first,
        onAddScreenshot:
            ({required bytes, required filename, category}) async =>
                fixture.homeBaseContents().first,
        onTab: (_) {},
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Map<String, Object?> _measure(WidgetTester tester) =>
    fixture.homeBaseMeasure(tester.element(find.byType(HomeScreen)));
void _expectTarget(WidgetTester tester) {
  final judgment = fixture.homeBaseJudgment(_measure(tester));
  for (final role in {
    'stylePassed': 'styleFailures',
    'layoutPassed': 'layoutFailures',
    'assetPassed': 'assetFailures',
  }.entries) {
    expect(judgment[role.key], isTrue, reason: '${judgment[role.value]}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await fixture.homeBaseLoadFonts(loadForTest: true);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width C01/C02 actual roles source assets and logical boundaries',
        (tester) async {
          for (final empty in [false, true]) {
            await _pump(
              tester,
              platform: platform,
              width: width,
              contents: empty ? const [] : null,
            );
            _expectTarget(tester);
            final m = _measure(tester);
            expect((m['hero'] as Map)['confirmedEmpty'], empty);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
  for (final state in [
    'query',
    'empty query',
    'favorite true',
    'favorite false',
    'more pages',
    'next cursor',
    'loading',
    'error',
    'uninitialized',
    'feed category',
    'active category',
    'stale feed items',
  ]) {
    testWidgets('C02 requires unfiltered fully completed global feed: $state', (
      tester,
    ) async {
      final feed = _feed(const []);
      switch (state) {
        case 'query':
          feed.query = '키워드';
        case 'empty query':
          feed.query = '';
        case 'favorite true':
          feed.isFavorite = true;
        case 'favorite false':
          feed.isFavorite = false;
        case 'more pages':
          feed.hasMore = true;
        case 'next cursor':
          feed.nextCursor = 'memory-cursor';
        case 'loading':
          feed.loading = true;
        case 'error':
          feed.error = StateError('Fixture incomplete load');
        case 'uninitialized':
          feed.initialized = false;
        case 'feed category':
          feed.categoryId = 101;
        case 'stale feed items':
          feed.items.add(fixture.homeBaseContents().first);
      }
      await _pump(
        tester,
        feed: feed,
        contents: const [],
        categoryId: state == 'active category' ? 101 : null,
      );
      expect(
        tester.widget<HomeHero>(find.byType(HomeHero)).confirmedEmpty,
        isFalse,
      );
      expect(find.text('첫 콘텐츠 저장하기'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'recent count follows zero one four and preserves exact content strings',
    (tester) async {
      for (final count in [0, 1, 4]) {
        final items = fixture.homeBaseContents().take(count).toList();
        await _pump(tester, contents: items);
        if (count == 0) {
          expect(find.byType(PageDots), findsNothing);
        } else {
          expect(tester.widget<PageDots>(find.byType(PageDots)).count, count);
          final cards = tester.widgetList<HomeContentCard>(
            find.byType(HomeContentCard),
          );
          for (final card in cards) {
            final source = items.firstWhere((v) => v.id == card.content.id);
            expect(card.content.title, source.title);
            expect(card.content.summary, source.summary);
          }
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'common bookmark default asset selected state disabled callback and hit size stay unchanged',
    (tester) async {
      var calls = 0;
      Future<void> show({
        bool selected = false,
        bool enabled = true,
        bool callback = true,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookmarkActionButton(
                key: UniqueKey(),
                initialActive: selected,
                enabled: enabled,
                onToggle: callback ? () => calls++ : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      String asset() {
        final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
        return (svg.bytesLoader as SvgAssetLoader).assetName;
      }

      await show();
      expect(asset(), Assets.star);
      expect(
        tester.getSize(find.byType(BookmarkActionButton)),
        const Size(44, 44),
      );
      await tester.tap(find.byType(BookmarkActionButton));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await show(selected: true);
      expect(asset(), Assets.starFilled);
      await show(enabled: false);
      await tester.tap(find.byType(BookmarkActionButton));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await show(callback: false);
      expect(asset(), Assets.star);
      await tester.tap(find.byType(BookmarkActionButton));
      await tester.pumpAndSettle();
      expect(asset(), Assets.starFilled);
      expect(tester.takeException(), isNull);
    },
  );
}
