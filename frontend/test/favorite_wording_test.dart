import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/archive/bookmark_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// #198: 화면에 보이는 "북마크" 문구는 "즐겨찾기"로 바꾼다.
void main() {
  // 정렬 메뉴 폭(128)에 실제 글꼴로 들어가는지 보려고 앱 글꼴을 쓴다.
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  Future<void> pumpBody(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Pretendard'),
      home: Scaffold(body: child),
    ),
  );

  Finder option(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(PopupMenuItem<bool>),
  );

  testWidgets('정렬 버튼과 메뉴는 즐겨찾기 우선으로 바꾸고 최신순으로 돌아온다', (tester) async {
    var bookmarkedFirst = false;
    await pumpBody(
      tester,
      StatefulBuilder(
        builder: (context, setState) => ContentListView(
          contents: const [],
          bookmarkedIds: const {},
          bookmarkedFirst: bookmarkedFirst,
          activeCategoryName: null,
          onSortChanged: (value) => setState(() => bookmarkedFirst = value),
          onClearCategory: () {},
          onOpenContent: (_) {},
          onToggleBookmark: (_) {},
          categories: const [],
          onChangeContentCategory: (_, _) {},
          onDeleteContent: (_) {},
          onGoHome: () {},
        ),
      ),
    );
    final button = find.byType(ArchiveSortButton);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(option('즐겨찾기 우선'), findsOneWidget);
    expect(find.textContaining('북마크'), findsNothing);
    await tester.tap(find.text('즐겨찾기 우선'));
    await tester.pumpAndSettle();
    expect(bookmarkedFirst, isTrue);
    expect(
      find.descendant(of: button, matching: find.text('즐겨찾기 우선')),
      findsOneWidget,
    );
    expect(tester.widget<ArchiveSortButton>(button).bookmarkedFirst, isTrue);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: option('즐겨찾기 우선'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('북마크'), findsNothing);
    await tester.tap(option('최신순'));
    await tester.pumpAndSettle();
    expect(bookmarkedFirst, isFalse);
    expect(
      find.descendant(of: button, matching: find.text('최신순')),
      findsOneWidget,
    );
    expect(tester.widget<ArchiveSortButton>(button).bookmarkedFirst, isFalse);
  });

  // 사용자 결정(2026-11-03): 즐겨찾기 우선이 선택돼 체크가 보여도 1.3배까지 넘치지 않는다.
  for (final bookmarkedFirst in [false, true]) {
    for (final scale in [1.0, 1.1, 1.2, 1.3]) {
      final sortLabel = bookmarkedFirst ? '즐겨찾기 우선' : '최신순';
      testWidgets('정렬 메뉴는 $sortLabel 선택·글자 $scale배에서 넘치지 않는다', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpBody(
          tester,
          ArchiveToolbar(
            countLabel: '총 1개',
            sortLabel: sortLabel,
            onSortChanged: (_) {},
          ),
        );
        await tester.tap(find.byType(ArchiveSortButton));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: option(sortLabel),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('정렬 선택 시트 항목은 즐겨찾기 우선이다', (tester) async {
    await pumpBody(
      tester,
      SortSheet(activeBookmarkedFirst: false, onSelect: (_) {}),
    );
    expect(find.text('즐겨찾기 우선'), findsOneWidget);
    expect(find.textContaining('북마크'), findsNothing);
  });

  testWidgets('즐겨찾기 빈 화면 문구는 즐겨찾기로 안내한다', (tester) async {
    await pumpBody(tester, BookmarkEmptyState(onOpenArchiveAll: () {}));
    expect(find.text('즐겨찾기한 콘텐츠가 없어요'), findsOneWidget);
    expect(find.text('중요한 정보는 즐겨찾기를 통해 저장하세요!'), findsOneWidget);
    expect(find.textContaining('북마크'), findsNothing);
  });
}
