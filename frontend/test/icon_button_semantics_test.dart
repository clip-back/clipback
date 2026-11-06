import 'package:clipback_frontend/features/archive/bookmark_widgets.dart';
import 'package:clipback_frontend/features/archive/unclassified_widgets.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _category = CategoryItem(
  id: 301,
  name: '읽을거리',
  color: Color(0xFF6C8CFF),
  tint: Color(0x336C8CFF),
  deep: Color(0xFF3D5BD9),
);
const _item = ContentItem(
  id: 'api-901',
  apiId: 901,
  title: '접근성 이름 확인용 콘텐츠',
  summary: '요약',
  category: _category,
  categories: [_category],
  savedAt: '2026. 10. 17. 오후 3:00',
  savedAtFull: '2026. 10. 17. 오후 3:00',
  savedAtFullShort: '26.10.17',
  tags: [],
  source: '웹',
  originalUrl: 'https://example.invalid/a11y/901',
  originalText: '원문',
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SafeArea(child: child)),
  ),
);

void _expectNamedButton(WidgetTester tester, String label, {int count = 1}) {
  final finder = find.bySemanticsLabel(label);
  expect(finder, findsNWidgets(count), reason: '"$label" 이름의 버튼 수');
  for (var i = 0; i < count; i++) {
    expect(
      tester.getSemantics(finder.at(i)),
      isSemantics(label: label, isButton: true, hasTapAction: true),
    );
  }
}

void main() {
  testWidgets('홈 상단 검색·알림 버튼은 "검색", "알림"으로 읽힌다', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      HomeHero(
        empty: false,
        onSearch: () {},
        onOpenNotifications: () {},
        onOpenToday: () {},
      ),
    );
    _expectNamedButton(tester, '검색');
    _expectNamedButton(tester, '알림');
    semantics.dispose();
  });

  testWidgets('상세 상단 뒤로·더보기 버튼에 이름이 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      DetailTopBar(
        content: _item,
        categories: const [_category],
        bookmarked: false,
        onBack: () {},
        onToggleBookmark: () {},
        onChangeCategory: (_) {},
        onDeleteContent: () {},
      ),
    );
    _expectNamedButton(tester, '뒤로가기');
    _expectNamedButton(tester, '더보기');
    semantics.dispose();
  });

  testWidgets('아카이브 카테고리 상단·도구 막대 버튼에 이름이 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      Column(
        children: [
          CategoryArchiveTopBar(
            onSearch: () {},
            onOpenCategoryManagement: () {},
          ),
          CategoryArchiveToolbar(
            bookmarkedFirst: false,
            onSortChanged: (_) {},
            onAddCategory: () {},
          ),
        ],
      ),
    );
    _expectNamedButton(tester, '검색');
    _expectNamedButton(tester, '카테고리 관리');
    _expectNamedButton(tester, '카테고리 추가');
    semantics.dispose();
  });

  testWidgets('즐겨찾기 상단 검색·카테고리 관리 버튼에 이름이 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      BookmarkTopBar(onSearch: () {}, onOpenCategoryManagement: () {}),
    );
    _expectNamedButton(tester, '검색');
    _expectNamedButton(tester, '카테고리 관리');
    semantics.dispose();
  });

  testWidgets('분류 필요 상단 뒤로·검색·카테고리 관리 버튼에 이름이 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      UnclassifiedTopBar(
        onBack: () {},
        onSearch: () {},
        onOpenCategoryManagement: () {},
      ),
    );
    _expectNamedButton(tester, '뒤로가기');
    _expectNamedButton(tester, '검색');
    _expectNamedButton(tester, '카테고리 관리');
    semantics.dispose();
  });

  testWidgets('콘텐츠 저장 상단 닫기 버튼에 이름이 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, SaveContentTopBar(onClose: () {}));
    _expectNamedButton(tester, '닫기');
    semantics.dispose();
  });

  for (final archiveAllStyle in [false, true]) {
    testWidgets('콘텐츠 카드 더보기 버튼에 이름이 있다 archiveAllStyle=$archiveAllStyle', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        ContentListCard(
          content: _item,
          onTap: () {},
          onToggleBookmark: () {},
          categories: const [_category],
          onChangeCategory: (_) {},
          onDelete: () {},
          archiveAllStyle: archiveAllStyle,
        ),
      );
      _expectNamedButton(tester, '더보기');
      semantics.dispose();
    });
  }

  void expectCategoryMore(WidgetTester tester, {required bool enabled}) {
    final finder = find.bySemanticsLabel('더보기');
    expect(finder, findsOneWidget);
    expect(
      tester.getSemantics(finder),
      isSemantics(label: '더보기', isButton: true, hasTapAction: enabled),
    );
  }

  for (final archiveStyle in [false, true]) {
    for (final mutating in [false, true]) {
      testWidgets(
        '카테고리 행 더보기 버튼에 이름이 있다 archiveStyle=$archiveStyle mutating=$mutating',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await _pump(
            tester,
            CategoryRow(
              category: CategoryItem(
                id: _category.id,
                name: _category.name,
                color: _category.color,
                tint: _category.tint,
                deep: _category.deep,
                mutationLabel: mutating ? '삭제 중…' : null,
              ),
              archiveStyle: archiveStyle,
              onTap: () {},
              onMore: () {},
            ),
          );
          expectCategoryMore(tester, enabled: !mutating);
          semantics.dispose();
        },
      );
    }
  }

  testWidgets('아카이브 카테고리 목록의 행 더보기 버튼에 이름이 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      CategoryArchiveView(
        categories: const [_category],
        contents: const [],
        bookmarkedIds: const {},
        bookmarkedFirst: false,
        onSortChanged: (_) {},
        onAddCategory: (_) {},
        onUpdateCategory: (_, _) {},
        onDeleteCategory: (_) {},
        onOpenCategory: (_) {},
      ),
    );
    expectCategoryMore(tester, enabled: true);
    expect(
      tester.getRect(find.bySemanticsLabel('더보기')),
      tester.getRect(find.byKey(const ValueKey('archive-category-more-301'))),
    );
    semantics.dispose();
  });

  testWidgets('카테고리 관리 화면의 행 더보기 버튼에 이름이 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagementScreen(
          categories: const [_category],
          contents: const [],
          onBack: () {},
          onAddCategory: (_) {},
          onUpdateCategory: (_, _) {},
          onDeleteCategory: (_) {},
        ),
      ),
    );
    expectCategoryMore(tester, enabled: true);
    semantics.dispose();
  });
}
