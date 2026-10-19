import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/placeholder_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _routes = [
  AppRoute.home,
  AppRoute.archive,
  AppRoute.bookmark,
  AppRoute.my,
];
const _labels = ['홈', '아카이브', '즐겨찾기', '마이'];
const _icons = [Assets.home, Assets.archive, Assets.star, Assets.account];
const _date = '2020. 3. 10. 오후 11:56';
const _longCategoryName = '여행 중 다시 찾아볼 장소와 유용한 생활 정보를 모아둔 아주 긴 카테고리';
const _shortCategory = CategoryItem(
  id: 1,
  name: '생활',
  color: AppColors.main,
  tint: AppColors.mainSubtle,
  deep: AppColors.mainDeep,
);
const _longCategory = CategoryItem(
  id: 2,
  name: _longCategoryName,
  color: AppColors.blueSubtle,
  tint: AppColors.blueSubtle,
  deep: AppColors.blueDeep,
);
const _content = ContentItem(
  id: 'scaled-layout-content',
  title: '다시 읽을 정보',
  summary: '짧은 요약을 확인해요.',
  category: _shortCategory,
  savedAt: '오늘',
  savedAtFull: '2026. 10. 13',
  savedAtFullShort: '26.10.13',
  tags: [],
  source: 'web',
  originalUrl: 'https://example.com/scaled-layout',
  originalText: '원문을 확인해요.',
);
const _previousContent = ContentItem(
  id: 'previous-content',
  title: '이전 정보',
  summary: '이전 내용',
  category: _shortCategory,
  savedAt: '오늘',
  savedAtFull: '2026. 10. 13',
  savedAtFullShort: '26.10.13',
  tags: [],
  source: 'web',
  originalUrl: 'https://example.com/previous',
  originalText: '이전 원문',
);
const _nextContent = ContentItem(
  id: 'next-content',
  title: '다음 정보',
  summary: '다음 내용',
  category: _shortCategory,
  savedAt: '오늘',
  savedAtFull: '2026. 10. 13',
  savedAtFullShort: '26.10.13',
  tags: [],
  source: 'web',
  originalUrl: 'https://example.com/next',
  originalText: '다음 원문',
);

double _normalNavigationHeight(TargetPlatform platform) =>
    64.0 + (platform == TargetPlatform.iOS ? 34.0 : 0.0);

Future<void> _render(
  WidgetTester tester, {
  required Widget screen,
  required double width,
  required TargetPlatform platform,
  double scale = 1,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final insets = FakeViewPadding(
    top: platform == TargetPlatform.iOS ? 44 : 24,
    bottom: platform == TargetPlatform.iOS ? 34 : 0,
  );
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
        textTheme: ThemeData.fallback().textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _navigationText(String label) => find.descendant(
  of: find.byType(ClipbackNavigationBar),
  matching: find.text(label),
);

// Follow the labelled touch slot, not a shared SVG path: active assets may
// differ and the inactive My source contains two SVG layers.
Finder _navigationIcon(String asset) {
  final label = _labels[_icons.indexOf(asset)];
  final column = find.descendant(
    of: _slot(label),
    matching: find.byType(Column),
  );
  final firstChild = (column.evaluate().single.widget as Column).children.first;
  return find.byWidget(firstChild);
}

Finder _slot(String label) => find
    .ancestor(of: _navigationText(label), matching: find.byType(InkWell))
    .first;

void _contained(Rect child, Rect parent) {
  expect(child.left, greaterThanOrEqualTo(parent.left - 0.01));
  expect(child.top, greaterThanOrEqualTo(parent.top - 0.01));
  expect(child.right, lessThanOrEqualTo(parent.right + 0.01));
  expect(child.bottom, lessThanOrEqualTo(parent.bottom + 0.01));
}

Future<ContentItem> _saveLink({
  required String url,
  CategoryItem? category,
}) async => _content;
Future<ContentItem> _saveScreenshot({
  required Uint8List bytes,
  required String filename,
  CategoryItem? category,
}) async => _content;

Widget _screen(
  String name,
  ValueChanged<AppRoute> onTab, {
  ValueChanged<int>? onOpenAdjacent,
}) {
  switch (name) {
    case 'home':
      return HomeScreen(
        feed: FeedPage()
          ..initialized = true
          ..hasMore = false
          ..items.add(_content),
        contents: const [_content],
        categories: const [],
        bookmarkedIds: const {},
        onSearch: () {},
        onOpenArchive: () {},
        onOpenCategories: () {},
        onOpenToday: () {},
        onOpenContent: (_) {},
        onToggleBookmark: (_) {},
        onAddLink: _saveLink,
        onAddScreenshot: _saveScreenshot,
        onTab: onTab,
      );
    case 'archive':
      return ArchiveScreen(
        activeTab: 0,
        contents: const [],
        categories: const [],
        bookmarkedIds: const {},
        bookmarkedFirst: false,
        randomViewing: false,
        activeCategoryName: null,
        onTabChanged: (_) {},
        onSortChanged: (_) {},
        onOpenRandomView: () {},
        onExitRandomView: () {},
        onClearCategory: () {},
        onSearch: () {},
        onOpenContent: (_) {},
        onToggleBookmark: (_) {},
        onChangeContentCategory: (_, _) {},
        onDeleteContent: (_) {},
        onAddCategory: (_) {},
        onUpdateCategory: (_, _) {},
        onDeleteCategory: (_) {},
        onAddLink: _saveLink,
        onAddScreenshot: _saveScreenshot,
        onOpenCategory: (_) {},
        onTab: onTab,
      );
    case 'bookmark':
      return BookmarkScreen(
        contents: const [],
        categories: const [],
        bookmarkedIds: const {},
        onSearch: () {},
        onOpenContent: (_) {},
        onToggleBookmark: (_) {},
        onChangeContentCategory: (_, _) {},
        onDeleteContent: (_) {},
        onAddLink: _saveLink,
        onAddScreenshot: _saveScreenshot,
        onTab: onTab,
      );
    case 'my':
      return MyScreen(
        user: const AppUser(
          name: '테스터',
          providerLabel: '게스트',
          joinedAt: '오늘',
          savedContentCount: 1,
          revisitedContentCount: 0,
          appVersion: 'ver. 1.1',
        ),
        onAddLink: _saveLink,
        onAddScreenshot: _saveScreenshot,
        onOpenAccount: () {},
        onOpenCategoryManagement: () {},
        onTab: onTab,
      );
    case 'detail':
      return DetailScreen(
        onReadAsset: (_) async => Uint8List(0),
        content: _content,
        contents: const [_previousContent, _content, _nextContent],
        categories: const [],
        bookmarked: false,
        onBack: () {},
        onToggleBookmark: (_) {},
        onChangeCategory: (_, _) {},
        onDeleteContent: (_) {},
        onOpenOriginalLink: () {},
        onOpenAdjacent: onOpenAdjacent ?? (_) {},
        onOpenContent: (_) {},
        onAddLink: _saveLink,
        onAddScreenshot: _saveScreenshot,
        onTab: onTab,
      );
    default:
      throw ArgumentError.value(name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'navigation fits and taps at $platform $width scale $scale',
          (tester) async {
            addTearDown(tester.view.reset);
            final routes = <AppRoute>[];
            var addCount = 0;
            var activeIndex = 0;
            Widget screen() => Scaffold(
              bottomNavigationBar: ClipbackNavigationBar(
                activeIndex: activeIndex,
                onTap: routes.add,
                onAdd: () => addCount++,
              ),
            );
            await _render(
              tester,
              screen: screen(),
              width: width,
              platform: platform,
            );
            expect(tester.takeException(), isNull);
            final baseIcons = [
              for (final icon in _icons) tester.getRect(_navigationIcon(icon)),
            ];
            final baseAdd = tester.getRect(find.byType(NavAddButton));
            expect(
              tester.getSize(find.byType(ClipbackNavigationBar)).height,
              _normalNavigationHeight(platform),
            );
            await _render(
              tester,
              screen: screen(),
              width: width,
              platform: platform,
              scale: scale,
            );
            expect(tester.takeException(), isNull);
            final bar = tester.getRect(find.byType(ClipbackNavigationBar));
            final slots = [
              for (final label in _labels) tester.getRect(_slot(label)),
            ];
            for (var index = 0; index < _labels.length; index++) {
              final paragraph = tester.renderObject<RenderParagraph>(
                _navigationText(_labels[index]),
              );
              expect(paragraph.maxLines, 2);
              expect(paragraph.overflow, TextOverflow.ellipsis);
              expect(slots[index].width, 56);
              expect(slots[index].height, slots.first.height);
              _contained(
                tester.getRect(_navigationText(_labels[index])),
                slots[index],
              );
              final icon = tester.getRect(_navigationIcon(_icons[index]));
              expect(icon.size, const Size(28, 28));
              expect(icon.center.dx, baseIcons[index].center.dx);
              expect(
                icon.top,
                tester.getRect(_navigationIcon(_icons.first)).top,
              );
              _contained(icon, slots[index]);
            }
            final addRect = tester.getRect(find.byType(NavAddButton));
            expect(addRect.size, const Size(72, 72));
            expect(addRect.center.dx, baseAdd.center.dx);
            expect(addRect.top, bar.top - 22);
            expect(bar.bottom, 812);
            if (scale == 1) {
              expect(bar.height, _normalNavigationHeight(platform));
              expect(slots.first.height, 56);
            } else {
              expect(
                bar.height,
                greaterThan(_normalNavigationHeight(platform)),
              );
            }

            for (var index = 0; index < _labels.length; index++) {
              await tester.tap(_navigationText(_labels[index]));
              await tester.pumpAndSettle();
              expect(routes, _routes.take(index + 1).toList());
            }
            await tester.tap(find.byType(NavAddButton));
            await tester.pumpAndSettle();
            expect(addCount, 1);
            final bottomTap = addRect.bottomCenter - const Offset(0, 2);
            expect(bar.contains(bottomTap), isTrue);
            await tester.tapAt(bottomTap);
            await tester.pumpAndSettle();
            expect(addCount, 2);
            expect(routes, _routes);
            expect(tester.takeException(), isNull);
            if (scale == 2) {
              for (final index in [1, 3]) {
                activeIndex = index;
                await _render(
                  tester,
                  screen: screen(),
                  width: width,
                  platform: platform,
                  scale: scale,
                );
                expect(tester.takeException(), isNull);
                expect(
                  tester.getSize(find.byType(ClipbackNavigationBar)).height,
                  bar.height,
                );
                final activeLabel = tester.renderObject<RenderParagraph>(
                  _navigationText(_labels[index]),
                );
                expect(
                  (activeLabel.text as TextSpan).style!.color,
                  AppColors.text,
                );
                for (var icon = 0; icon < _icons.length; icon++) {
                  expect(
                    tester.getRect(_navigationIcon(_icons[icon])).center.dx,
                    baseIcons[icon].center.dx,
                  );
                }
              }
            }
          },
        );

        testWidgets(
          'category rows fit and tap at $platform $width scale $scale',
          (tester) async {
            addTearDown(tester.view.reset);
            final taps = <int>[];
            await _render(
              tester,
              width: width,
              platform: platform,
              scale: scale,
              screen: Scaffold(
                body: SafeArea(
                  child: Column(
                    children: [
                      for (final category in [_shortCategory, _longCategory])
                        CategoryHomeRow(
                          category: category,
                          onTap: () => taps.add(category.id!),
                        ),
                    ],
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            for (final category in [_shortCategory, _longCategory]) {
              final row = find.ancestor(
                of: find.text(category.name),
                matching: find.byType(CategoryHomeRow),
              );
              final rowRect = tester.getRect(row);
              final name = find.descendant(
                of: row,
                matching: find.text(category.name),
              );
              final date = find.descendant(of: row, matching: find.text(_date));
              final chevron = find.descendant(
                of: row,
                matching: find.byType(SvgIcon),
              );
              for (final text in [name, date]) {
                final paragraph = tester.renderObject<RenderParagraph>(text);
                expect(paragraph.maxLines, 1);
                expect(paragraph.overflow, TextOverflow.ellipsis);
                final rect = tester.getRect(text);
                _contained(rect, rowRect);
                expect(
                  rect.right,
                  lessThanOrEqualTo(tester.getRect(chevron).left),
                );
              }
              await tester.tap(name);
              await tester.pumpAndSettle();
              expect(taps.where((id) => id == category.id).length, 1);
            }
            expect(taps, [1, 2]);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final name in ['home', 'archive', 'bookmark', 'my', 'detail']) {
    final scale = name == 'my' || name == 'detail' ? 1.0 : 2.0;
    testWidgets('$name keeps shared navigation reachable at scale $scale', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final routes = <AppRoute>[];
      final adjacent = <int>[];
      await _render(
        tester,
        screen: _screen(name, routes.add, onOpenAdjacent: adjacent.add),
        width: 375,
        platform: TargetPlatform.android,
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      final barRect = tester.getRect(find.byType(ClipbackNavigationBar));
      if (scale == 1) {
        expect(barRect.height, _normalNavigationHeight(TargetPlatform.android));
      } else {
        expect(
          barRect.height,
          greaterThan(_normalNavigationHeight(TargetPlatform.android)),
        );
      }
      _contained(barRect, const Rect.fromLTWH(0, 0, 375, 812));
      if (name == 'detail') {
        final pagerRect = tester.getRect(find.byType(DetailPager));
        expect(pagerRect.bottom, lessThanOrEqualTo(barRect.top));
        _contained(pagerRect, const Rect.fromLTWH(0, 0, 375, 812));
        final pagerButtons = find.descendant(
          of: find.byType(DetailPager),
          matching: find.byType(RoundIconButton),
        );
        await tester.tap(pagerButtons.first);
        await tester.pumpAndSettle();
        await tester.tap(pagerButtons.last);
        await tester.pumpAndSettle();
        expect(adjacent, [-1, 1]);
      }
      await tester.tap(_navigationText('홈'));
      await tester.pumpAndSettle();
      expect(routes, [AppRoute.home]);
      expect(tester.takeException(), isNull);
      if (name == 'detail') {
        await tester.tap(find.byType(NavAddButton));
        await tester.pumpAndSettle();
        expect(find.byType(AddContentSheet), findsOneWidget);
        expect(find.text('콘텐츠 저장하기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('placeholder scaled navigation preserves Navigator pop', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    await _render(
      tester,
      navigatorKey: navigator,
      screen: const Scaffold(body: Text('원래 화면')),
      width: 375,
      platform: TargetPlatform.android,
      scale: 2,
    );
    final returned = navigator.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PlaceholderScreen(title: '준비', activeIndex: 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(find.byType(ClipbackNavigationBar));
    expect(
      bar.height,
      greaterThan(_normalNavigationHeight(TargetPlatform.android)),
    );
    _contained(bar, const Rect.fromLTWH(0, 0, 375, 812));
    await tester.tap(_navigationText('아카이브'));
    await tester.pumpAndSettle();
    await returned;
    expect(find.text('원래 화면'), findsOneWidget);
    expect(find.byType(PlaceholderScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
