import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/widgets/top_bars.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/data/sample_contents.dart';

final events = <String>[];
void noop() {}
void searched() => events.add('search');
void backed() => events.add('back');
void one<T>(T value) => events.add('value:$value');
void two<A, B>(A _, B __) {}
Future<ContentItem> saveLink({
  required String url,
  CategoryItem? category,
}) async => initialContents.first;
Future<ContentItem> saveImage({
  required Uint8List bytes,
  required String filename,
  CategoryItem? category,
}) async => initialContents.first;

Widget home() => HomeScreen(
  contents: initialContents,
  categories: const [],
  bookmarkedIds: const {},
  onSearch: searched,
  onOpenArchive: noop,
  onOpenCategories: noop,
  onOpenToday: noop,
  onOpenContent: one,
  onToggleBookmark: one,
  onAddLink: saveLink,
  onAddScreenshot: saveImage,
  onTab: one,
);
Widget archive({String? categoryName}) => ArchiveScreen(
  activeTab: 0,
  contents: const [],
  categories: const [],
  bookmarkedIds: const {},
  bookmarkedFirst: false,
  randomViewing: false,
  activeCategoryName: categoryName,
  onTabChanged: one,
  onSortChanged: one,
  onOpenRandomView: noop,
  onExitRandomView: noop,
  onClearCategory: backed,
  onSearch: searched,
  onOpenContent: one,
  onToggleBookmark: one,
  onChangeContentCategory: two,
  onDeleteContent: one,
  onAddCategory: one,
  onUpdateCategory: two,
  onDeleteCategory: one,
  onAddLink: saveLink,
  onAddScreenshot: saveImage,
  onOpenCategory: one,
  onTab: one,
);
Widget bookmark() => BookmarkScreen(
  contents: const [],
  categories: const [],
  bookmarkedIds: const {},
  onSearch: searched,
  onOpenContent: one,
  onToggleBookmark: one,
  onChangeContentCategory: two,
  onDeleteContent: one,
  onAddLink: saveLink,
  onAddScreenshot: saveImage,
  onTab: one,
);
Widget search() => SearchScreen(
  initialQuery: 'query',
  contents: const [],
  categories: const [],
  bookmarkedIds: const {},
  onSearch: (_) async => [],
  onQueryChanged: one,
  onClose: backed,
  onOpenContent: one,
  onToggleBookmark: one,
  onChangeContentCategory: two,
  onDeleteContent: one,
  onOpenArchive: noop,
);
Widget detail() => DetailScreen(
  content: initialContents.first,
  contents: [initialContents.first],
  categories: const [],
  bookmarked: false,
  onReadAsset: (_) async => Uint8List(0),
  onBack: backed,
  onToggleBookmark: one,
  onChangeCategory: two,
  onDeleteContent: one,
  onOpenOriginalLink: noop,
  onOpenAdjacent: one,
  onOpenContent: one,
  onAddLink: saveLink,
  onAddScreenshot: saveImage,
  onTab: one,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });
  for (final size in [const Size(375, 812), const Size(430, 932)]) {
    for (final inset in [0.0, 20.0, 44.0, 59.0, 62.0]) {
      testWidgets('headers respect inset $inset at $size', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = FakeViewPadding(top: inset, bottom: 34);
        tester.view.viewPadding = FakeViewPadding(top: inset, bottom: 34);
        addTearDown(tester.view.reset);
        Future<void> render(Widget w) async {
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              theme: ThemeData(
                fontFamily: 'Pretendard',
                platform: TargetPlatform.iOS,
              ),
              home: w,
            ),
          );
          await tester.pumpAndSettle();
        }

        Finder headerRow(String title) => find
            .ancestor(of: find.text(title), matching: find.byType(Row))
            .first;
        final cases =
            <(String, Widget Function(), Finder Function(), double, double)>[
              ('archive', archive, () => find.byType(AppTopBar), inset, 64),
              (
                'category archive',
                () => archive(categoryName: '분류'),
                () => find.byType(CategoryTopBar),
                inset,
                64,
              ),
              ('bookmark', bookmark, () => find.byType(AppTopBar), inset, 64),
              (
                'search',
                search,
                () => find
                    .ancestor(
                      of: find.byType(TextField),
                      matching: find.byWidgetPredicate(
                        (w) => w is Container && w.constraints?.maxHeight == 44,
                      ),
                    )
                    .first,
                inset + 10,
                44,
              ),
              ('detail', detail, () => find.byType(DetailTopBar), inset, 64),
              (
                'home',
                home,
                () => find
                    .descendant(
                      of: find.byType(HomeHero),
                      matching: find.byType(Row),
                    )
                    .first,
                inset + 8,
                56,
              ),
              (
                'my',
                () => MyScreen(
                  user: defaultUser,
                  onAddLink: saveLink,
                  onAddScreenshot: saveImage,
                  onOpenAccount: noop,
                  onOpenCategoryManagement: noop,
                  onTab: one,
                ),
                () => find.byType(MyPageTopBar),
                inset,
                64,
              ),
              (
                'account',
                () => AccountManagementScreen(
                  user: defaultUser,
                  onBack: backed,
                  onLogout: () async {},
                  onConnect: () async {},
                  isGuest: true,
                ),
                () => headerRow('계정 관리'),
                inset,
                64,
              ),
              (
                'categories',
                () => CategoryManagementScreen(
                  categories: const [],
                  contents: const [],
                  onBack: backed,
                  onAddCategory: one,
                  onUpdateCategory: two,
                  onDeleteCategory: one,
                ),
                () => headerRow('카테고리 관리'),
                inset,
                64,
              ),
              (
                'random',
                () => random(),
                () => find.widgetWithText(TextButton, '나가기'),
                inset,
                64,
              ),
            ];
        for (final entry in cases) {
          await render(entry.$2());
          final rect = tester.getRect(entry.$3());
          expect(rect.top, entry.$4, reason: entry.$1);
          expect(rect.height, entry.$5, reason: entry.$1);
          final controls = find.byWidgetPredicate(
            (w) =>
                w is SvgIconButton &&
                (w.asset == Assets.back ||
                    w.asset == Assets.detailBack ||
                    w.asset == Assets.search),
          );
          for (final element in controls.evaluate()) {
            final finder = find.byElementPredicate(
              (candidate) => identical(candidate, element),
            );
            final hit = tester.getRect(finder);
            expect(hit.top, greaterThanOrEqualTo(inset), reason: entry.$1);
            events.clear();
            await tester.tap(finder);
            await tester.pump();
            expect(events, hasLength(1), reason: '${entry.$1} header callback');
          }
          if (entry.$1 == 'categories') {
            final add = find.byWidgetPredicate(
              (w) => w is SvgIconButton && w.asset == Assets.folderPlus,
            );
            expect(tester.getRect(add).top, greaterThanOrEqualTo(inset));
            await tester.tap(add);
            await tester.pumpAndSettle();
            expect(find.byType(CategoryFormSheet), findsOneWidget);
            Navigator.of(tester.element(find.byType(CategoryFormSheet))).pop();
            await tester.pumpAndSettle();
          }
          if (entry.$1 == 'search') {
            events.clear();
            await tester.tap(find.text('취소'));
            expect(events, ['back']);
          }
          if (entry.$1 == 'random') {
            events.clear();
            await tester.tap(find.text('나가기'));
            expect(events, ['back']);
          }
          expect(tester.takeException(), isNull, reason: entry.$1);
        }
        await render(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showContentSaveScreen(
                    context: context,
                    onAddLink: saveLink,
                    onAddScreenshot: saveImage,
                  ),
                  child: const Text('open save'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open save'));
        await tester.pumpAndSettle();
        final save = tester.getRect(find.byType(SaveContentTopBar));
        expect(save.top, inset);
        expect(save.height, 64);
        final close = find.descendant(
          of: find.byType(SaveContentTopBar),
          matching: find.byType(SvgIconButton),
        );
        expect(tester.getRect(close).top, greaterThanOrEqualTo(inset));
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.byType(AddContentSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'home scrolls and random cards drag without painting into the notch',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      Future<void> render(Widget child) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Pretendard'),
              home: child,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<Uint8List> topPixels() async => (await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final pixels = Uint8List.fromList(
          data!.buffer.asUint8List(0, image.width * 59 * 4),
        );
        image.dispose();
        return pixels;
      }))!;

      await render(home());
      final original = await topPixels();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(scroll.maxScrollExtent, greaterThan(40));
      await tester.dragFrom(const Offset(180, 180), const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(scroll.pixels, greaterThan(0));
      expect(await topPixels(), orderedEquals(original));
      final beforeResize = scroll.pixels;
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      await tester.pumpAndSettle();
      expect(scroll.pixels, beforeResize);
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      await render(random());
      final randomTop = await topPixels();
      final gesture = await tester.startGesture(const Offset(180, 410));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -350));
      await tester.pump();
      expect(await topPixels(), orderedEquals(randomTop));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(await topPixels(), orderedEquals(randomTop));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(initialContents[1].id)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Widget random() => CategoryCardReviewScreen(
  contents: initialContents.take(3).toList(),
  categoryName: '분류',
  bookmarkedIds: const {},
  onExit: backed,
  onOpenContent: one,
  onToggleBookmark: one,
);
