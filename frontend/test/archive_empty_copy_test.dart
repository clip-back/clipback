import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });
  for (final width in [320.0, 375.0]) {
    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets('archive confirmed empty copy width$width scale$scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 812);
        addTearDown(tester.view.reset);
        final feed = FeedPage()
          ..initialized = true
          ..hasMore = false
          ..totalCount = 0;
        final routes = <AppRoute>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Pretendard'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ArchiveScreen(
              feed: feed,
              activeTab: 0,
              contents: feed.items,
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
              onAddLink: ({required url, submissionKey, category}) async =>
                  throw StateError('unused'),
              onAddScreenshot:
                  ({
                    required bytes,
                    required filename,
                    String? submissionKey,
                    category,
                  }) async => throw StateError('unused'),
              onOpenCategory: (_) {},
              onTab: routes.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(feed.confirmedEmpty, isTrue);
        expect(feed.loading, isFalse);
        expect(feed.error, isNull);
        expect(find.text('총 0개'), findsOneWidget);
        expect(find.text('저장한 콘텐츠가 없어요'), findsOneWidget);
        final body = find.text('아래 + 버튼에서 링크나 스크린샷을 추가해 보세요.');
        expect(body, findsOneWidget);
        expect(find.textContaining('홈의 + 버튼'), findsNothing);
        final paragraph = tester.renderObject<RenderParagraph>(body);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.getRect(body).left, greaterThanOrEqualTo(32));
        expect(tester.getRect(body).right, lessThanOrEqualTo(width - 32));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('홈으로 가기'));
        await tester.pumpAndSettle();
        expect(routes, [AppRoute.home]);
        await tester.tap(find.byType(NavAddButton));
        await tester.pumpAndSettle();
        expect(find.byType(AddContentSheet), findsOneWidget);
        expect(routes, [AppRoute.home]);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('ordinary category empty copy keeps its existing guidance', (
    tester,
  ) async {
    final feed = FeedPage()
      ..categoryId = 101
      ..initialized = true
      ..hasMore = false;
    var cleared = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Pretendard'),
        home: Scaffold(
          body: ContentListView(
            contents: feed.items,
            feed: feed,
            bookmarkedIds: const {},
            bookmarkedFirst: false,
            activeCategoryName: '일반 카테고리',
            categories: const [],
            onSortChanged: (_) {},
            onClearCategory: () => cleared++,
            onOpenContent: (_) {},
            onToggleBookmark: (_) {},
            onChangeContentCategory: (_, _) {},
            onDeleteContent: (_) {},
            onGoHome: () => fail('category empty action must clear its filter'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(feed.initialized, isTrue);
    expect(feed.loading, isFalse);
    expect(feed.error, isNull);
    expect(feed.items, isEmpty);
    expect(find.text('일반 카테고리 콘텐츠가 없어요'), findsOneWidget);
    expect(find.text('다른 카테고리를 보거나 필터를 해제해 전체 콘텐츠를 확인해 보세요.'), findsOneWidget);
    expect(find.text('아래 + 버튼에서 링크나 스크린샷을 추가해 보세요.'), findsNothing);
    await tester.tap(find.text('전체보기'));
    await tester.pumpAndSettle();
    expect(cleared, 1);
    expect(tester.takeException(), isNull);
  });
}
