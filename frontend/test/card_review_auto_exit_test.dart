// #309: 랜덤 보기에서 마지막 카드를 넘기면 나가기와 같은 카테고리 콘텐츠 목록으로
// 자동으로 돌아온다. 실제 루트 앱과 메모리 API로 복귀 화면·카테고리·정렬·목록·스크롤을 비교한다.
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/content/paged_content_list.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as base;
import 'support/system_back_preview.dart' show BackMemoryHistory;

base.ArchiveAllServer _server(int count) {
  final server = base.ArchiveAllServer();
  final template = server.records.first;
  server.records
    ..clear()
    ..addAll([
      for (var i = 0; i < count; i++)
        {
          ...template,
          'id': 701 + i,
          'title': '랜덤 보기 콘텐츠 ${i + 1}',
          'categories': [base.archiveAllCategoryMaps.first],
          'is_favorite': i.isEven,
          'saved_at':
              '2026-10-${(28 - i).toString().padLeft(2, '0')}T12:00:00Z',
        },
    ]);
  return server;
}

Finder get _review => find.byType(CategoryCardReviewScreen);
Finder get _activeCard => find.byKey(const ValueKey('review-active-card'));
ArchiveScreen _archive(WidgetTester t) =>
    t.widget<ArchiveScreen>(find.byType(ArchiveScreen));

Map<String, Object?> _listState(WidgetTester t) {
  final a = _archive(t);
  final list = find.byType(PagedContentList);
  return {
    'review': _review.evaluate().length,
    'randomViewing': a.randomViewing,
    'category': a.activeCategoryName,
    'bookmarkedFirst': a.bookmarkedFirst,
    'ids': [for (final c in a.contents) c.id],
    'scroll': list.evaluate().isEmpty
        ? null
        : t
              .state<ScrollableState>(
                find.descendant(of: list, matching: find.byType(Scrollable)),
              )
              .position
              .pixels,
  };
}

Future<void> _withApp(
  WidgetTester t,
  base.ArchiveAllServer server,
  Future<void> Function() body,
) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await http.runWithClient(() async {
    try {
      await t.pumpWidget(
        ClipbackApp(
          sessionStorage: base.ArchiveAllMemoryStorage(),
          socialAuth: base.ArchiveAllSocialAuth(),
          searchHistoryStorage: BackMemoryHistory(),
        ),
      );
      await completeAppStartup(t);
      t.widget<HomeScreen>(find.byType(HomeScreen)).onTab(AppRoute.archive);
      await t.pumpAndSettle();
      final a = _archive(t);
      a.onOpenCategory(a.categories.first);
      await t.pumpAndSettle();
      await body();
      expect(t.takeException(), isNull);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _openRandom(WidgetTester t) async {
  await t.tap(find.text('랜덤 보기'));
  await t.pumpAndSettle();
  expect(_review, findsOneWidget);
}

Future<void> _passCard(WidgetTester t) async {
  await t.drag(_activeCard, const Offset(0, -130));
  await t.pump(const Duration(milliseconds: 250));
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final count in [1, 2, 3, 4, 5]) {
    testWidgets('root count $count returns to the category list after the '
        'last card', (t) async {
      await _withApp(t, _server(count), () async {
        final before = _listState(t);
        await _openRandom(t);
        final cards = t.widget<CategoryCardReviewScreen>(_review).contents;
        expect(cards, hasLength(count));
        for (var i = 0; i < count - 1; i++) {
          await _passCard(t);
          expect(_review, findsOneWidget);
        }
        await t.drag(_activeCard, const Offset(0, -130));
        await t.pump(const Duration(milliseconds: 200));
        expect(_review, findsOneWidget);
        await t.pump(const Duration(milliseconds: 50));
        await t.pumpAndSettle();
        expect(_review, findsNothing);
        expect(_listState(t), before);
        await t.pump(const Duration(seconds: 1));
        await t.pumpAndSettle();
        expect(_listState(t), before);
      });
    });
  }

  testWidgets('auto exit matches manual exit with sort and scroll kept and '
      'random view opens again', (t) async {
    await _withApp(t, _server(25), () async {
      _archive(t).onSortChanged(true);
      await t.pumpAndSettle();
      await t.drag(find.byType(PagedContentList), const Offset(0, -400));
      await t.pumpAndSettle();
      final before = _listState(t);
      expect(before['bookmarkedFirst'], isTrue);
      expect(before['scroll'], greaterThan(0));

      await _openRandom(t);
      await t.tap(find.text('나가기'));
      await t.pumpAndSettle();
      final manual = _listState(t);
      expect(manual, before);

      await _openRandom(t);
      for (var i = 0; i < 5; i++) {
        await _passCard(t);
      }
      expect(_listState(t), manual);

      await _openRandom(t);
      expect(
        t.widget<CategoryCardReviewScreen>(_review).contents,
        hasLength(5),
      );
    });
  });

  for (final interrupt in ['exit button', 'system back']) {
    testWidgets('$interrupt during the last transition returns only once', (
      t,
    ) async {
      await _withApp(t, _server(1), () async {
        final before = _listState(t);
        await _openRandom(t);
        await t.drag(_activeCard, const Offset(0, -130));
        await t.pump(const Duration(milliseconds: 100));
        if (interrupt == 'exit button') {
          await t.tap(find.text('나가기'));
        } else {
          expect(await t.binding.handlePopRoute(), isTrue);
        }
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 1));
        await t.pumpAndSettle();
        expect(_listState(t), before);
      });
    });
  }
}
