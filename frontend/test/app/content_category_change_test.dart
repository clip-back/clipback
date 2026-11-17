// #408 콘텐츠 카테고리 여러 개 고르기: 변경 화면과 "선택 완료" 판정 순서.
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/shared/category/category_change_screen.dart';
import 'package:clipback_frontend/shared/content/content_actions.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryItem _cat(int id, String name, {bool deleting = false}) => CategoryItem(
  id: id,
  name: name,
  lastSavedAt: '2026. 11. 17 오후 03:00',
  color: const Color(0xFFB499F3),
  tint: const Color(0x33B499F3),
  deep: const Color(0xFF6B4FBB),
  isMutating: deleting,
  mutationLabel: deleting ? '삭제 중…' : null,
);

final _a = _cat(1, '제품추천');
final _b = _cat(2, '일본여행');
final _c = _cat(3, '자기개발');
final _u = _cat(9, '미분류');

ContentItem _content(List<CategoryItem> categories) => ContentItem(
  id: 'api-77',
  apiId: 77,
  title: '콘텐츠',
  summary: '요약',
  category: categories.first,
  categories: categories,
  savedAt: '26.11.17',
  savedAtFull: '2026. 11. 17 오후 03:00',
  savedAtFullShort: '2026. 11. 17 15:00',
  tags: const [],
  source: '웹 링크',
  originalUrl: 'https://example.invalid/77',
  originalText: '',
);

class _Source extends ChangeNotifier implements CategoryChangeSource {
  _Source(this.categories);

  @override
  List<CategoryItem> categories;
  @override
  int accountGeneration = 0;
  bool contentPresent = true;

  @override
  bool hasContent(int contentId) => contentPresent && contentId == 77;

  void update(List<CategoryItem> next) {
    categories = next;
    notifyListeners();
  }
}

class _Host {
  _Host(this.source);
  final _Source source;
  final sent = <List<int>>[];
}

Future<_Host> _open(
  WidgetTester tester,
  List<CategoryItem> categories,
  List<CategoryItem> current, {
  double width = 375,
  double textScale = 1,
}) async {
  final host = _Host(_Source(categories));
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  final content = _content(current);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Pretendard'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: CategoryChangeScope(source: host.source, child: child!),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showCategoryChangeScreen(
                context: context,
                content: content,
                categories: const [],
                onChange: host.sent.add,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  expect(find.byType(CategoryChangeScreen), findsOneWidget);
  return host;
}

Finder _row(CategoryItem category) =>
    find.byKey(ValueKey('category-change-row-${category.id}'));

Future<void> _tapRow(WidgetTester tester, CategoryItem category) async {
  await tester.ensureVisible(_row(category));
  await tester.tap(_row(category));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('선택 완료'));
  await tester.pumpAndSettle();
}

Future<void> _toggleAll(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('category-change-toggle-all')));
  await tester.pumpAndSettle();
}

String _count(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('category-change-count')))
    .data!;

String _toggleLabel(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('category-change-toggle-all')),
        matching: find.byType(Text),
      ),
    )
    .data!;

bool _checked(WidgetTester tester, CategoryItem category) =>
    tester.widget<CategoryChangeRow>(_row(category)).selected;

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  group('opening', () {
    testWidgets('every current category starts checked, without 미분류', (
      tester,
    ) async {
      await _open(tester, [_a, _b, _c, _u], [_a, _b]);
      expect(_count(tester), '2개 선택');
      expect(_checked(tester, _a), isTrue);
      expect(_checked(tester, _b), isTrue);
      expect(_checked(tester, _c), isFalse);
      expect(find.text('미분류'), findsNothing);
      expect(find.text('카테고리 변경'), findsOneWidget);
      expect(find.text('2026. 11. 17 오후 03:00'), findsNWidgets(3));
    });

    testWidgets('a 미분류 content starts at 0 and lists no 미분류 row', (
      tester,
    ) async {
      await _open(tester, [_a, _b, _u], [_u]);
      expect(_count(tester), '0개 선택');
      expect(find.text('미분류'), findsNothing);
      expect(find.byType(CategoryChangeRow), findsNWidgets(2));
    });

    testWidgets('a category without saved content shows the empty line', (
      tester,
    ) async {
      const empty = CategoryItem(
        id: 4,
        name: '빈 분류',
        color: Colors.blue,
        tint: Colors.blue,
        deep: Colors.blue,
      );
      await _open(tester, [empty], [_u]);
      expect(find.text('저장된 콘텐츠 없음'), findsOneWidget);
    });
  });

  group('checking', () {
    testWidgets('rows toggle without a request and the count follows', (
      tester,
    ) async {
      final host = await _open(tester, [_a, _b, _c], [_a]);
      await _tapRow(tester, _c);
      expect(_count(tester), '2개 선택');
      expect(_checked(tester, _c), isTrue);
      await _tapRow(tester, _a);
      expect(_count(tester), '1개 선택');
      expect(_checked(tester, _a), isFalse);
      expect(find.byType(CategoryChangeScreen), findsOneWidget);
      expect(host.sent, isEmpty);
    });

    testWidgets('전체 선택 becomes 전체 해제 and both skip deleting rows', (
      tester,
    ) async {
      final deleting = _cat(3, '자기개발', deleting: true);
      await _open(tester, [_a, _b, deleting], [_a]);
      expect(_toggleLabel(tester), '전체 선택');
      await _toggleAll(tester);
      expect(_checked(tester, _b), isTrue);
      expect(_checked(tester, deleting), isFalse);
      expect(_count(tester), '2개 선택');
      expect(_toggleLabel(tester), '전체 해제');
      await _toggleAll(tester);
      expect(_count(tester), '0개 선택');
      expect(_toggleLabel(tester), '전체 선택');
    });

    testWidgets('전체 해제 keeps a checked deleting row', (tester) async {
      final deleting = _cat(3, '자기개발', deleting: true);
      await _open(tester, [_a, deleting], [_a, deleting]);
      expect(_count(tester), '2개 선택');
      expect(_toggleLabel(tester), '전체 해제');
      await _toggleAll(tester);
      expect(_checked(tester, deleting), isTrue);
      expect(_count(tester), '1개 선택');
    });

    testWidgets('deleting rows ignore taps and show 삭제 중…', (tester) async {
      final deleting = _cat(3, '자기개발', deleting: true);
      await _open(tester, [_a, deleting], [_a]);
      expect(find.text('삭제 중…'), findsOneWidget);
      await _tapRow(tester, deleting);
      expect(_checked(tester, deleting), isFalse);
      expect(_count(tester), '1개 선택');
    });

    testWidgets('deletion state changes while open follow the latest list', (
      tester,
    ) async {
      final host = await _open(tester, [_a, _b], [_a, _b]);
      host.source.update([_cat(1, '제품추천', deleting: true), _b]);
      await tester.pumpAndSettle();
      expect(_checked(tester, _a), isTrue);
      expect(_count(tester), '2개 선택');
      await _tapRow(tester, _a);
      expect(_checked(tester, _a), isTrue);

      host.source.update([_a, _b]);
      await tester.pumpAndSettle();
      await _tapRow(tester, _a);
      expect(_checked(tester, _a), isFalse);
      await _tapRow(tester, _a);

      host.source.update([_b]);
      await tester.pumpAndSettle();
      expect(_row(_a), findsNothing);
      expect(_count(tester), '1개 선택');
    });

    testWidgets('a list longer than the screen scrolls; 선택 완료 stays', (
      tester,
    ) async {
      final many = [for (var i = 1; i <= 20; i++) _cat(i, '분류 $i')];
      await _open(tester, many, [many.first]);
      final button = tester.getRect(find.text('선택 완료'));
      await tester.drag(
        find.byKey(const ValueKey('category-change-list')),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(find.text('분류 20'), findsOneWidget);
      expect(tester.getRect(find.text('선택 완료')), button);
      expect(button.bottom, lessThanOrEqualTo(812 - 34));
    });
  });

  group('no category to pick', () {
    testWidgets('0개 선택, 전체 선택 does nothing, 선택 완료 closes', (tester) async {
      final host = await _open(tester, [_u], [_u]);
      expect(find.byType(CategoryChangeRow), findsNothing);
      expect(_count(tester), '0개 선택');
      await _toggleAll(tester);
      expect(_count(tester), '0개 선택');
      expect(_toggleLabel(tester), '전체 선택');
      await _submit(tester);
      expect(find.byType(CategoryChangeScreen), findsNothing);
      expect(host.sent, isEmpty);
    });
  });

  group('선택 완료 decision order', () {
    // (S0, rows to tap, deleting at submit, expected requests)
    final cases =
        <
          String,
          (List<CategoryItem>, List<CategoryItem>, Set<int>, List<List<int>>)
        >{
          '{A}/{A}/none: no request': ([_a], [], {}, []),
          '{A}/{A,B}/none: list order': (
            [_a],
            [_b],
            {},
            [
              [1, 2],
            ],
          ),
          '{C}/{A,C}: list order, not tap order': (
            [_c],
            [_a],
            {},
            [
              [1, 3],
            ],
          ),
          '{A}/{}/none: empty list': ([_a], [_a], {}, [<int>[]]),
          '{}(미분류)/{}: no request': ([_u], [], {}, []),
          '{A}/{A}/{A}: no request': ([_a], [], {1}, []),
          '{A,B}/{A,B}/{A}: no request': ([_a, _b], [], {1}, []),
          '{A,B}/{B}/{A}: sends [B]': (
            [_a, _b],
            [_a],
            {1},
            [
              [2],
            ],
          ),
          '{A}/{A,C}/{A}: A is filtered out': (
            [_a],
            [_c],
            {1},
            [
              [3],
            ],
          ),
        };
    for (final MapEntry(key: name, value: (s0, taps, deleting, sent))
        in cases.entries) {
      testWidgets(name, (tester) async {
        final host = await _open(tester, [_a, _b, _c, _u], s0);
        for (final row in taps) {
          await _tapRow(tester, row);
        }
        host.source.update([
          for (final category in [_a, _b, _c, _u])
            deleting.contains(category.id)
                ? _cat(category.id!, category.name, deleting: true)
                : category,
        ]);
        await tester.pump();
        await _submit(tester);
        expect(find.byType(CategoryChangeScreen), findsNothing);
        expect(host.sent, sent);
      });
    }

    testWidgets('a deleted category drops out of the list sent', (
      tester,
    ) async {
      final host = await _open(tester, [_a, _b, _c], [_a]);
      await _tapRow(tester, _b);
      host.source.update([_b, _c]);
      await tester.pump();
      await _submit(tester);
      expect(host.sent, [
        [2],
      ]);
    });

    testWidgets('another account before 선택 완료 closes without a request', (
      tester,
    ) async {
      final host = await _open(tester, [_a, _b], [_a]);
      await _tapRow(tester, _b);
      host.source.accountGeneration++;
      await _submit(tester);
      expect(find.byType(CategoryChangeScreen), findsNothing);
      expect(host.sent, isEmpty);
    });

    testWidgets('a deleted content closes without a request or notice', (
      tester,
    ) async {
      final host = await _open(tester, [_a, _b], [_a]);
      await _tapRow(tester, _b);
      host.source.contentPresent = false;
      await _submit(tester);
      expect(find.byType(CategoryChangeScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(host.sent, isEmpty);
    });

    testWidgets('repeated 선택 완료 sends one request', (tester) async {
      final host = await _open(tester, [_a, _b], [_a]);
      await _tapRow(tester, _b);
      await tester.tap(find.text('선택 완료'));
      await tester.tap(find.text('선택 완료'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(host.sent, [
        [1, 2],
      ]);
      expect(find.text('열기'), findsOneWidget);
    });
  });

  group('leaving without saving', () {
    testWidgets('‹ closes without a request', (tester) async {
      final host = await _open(tester, [_a, _b], [_a]);
      await _tapRow(tester, _b);
      await tester.tap(find.byKey(const ValueKey('category-change-back')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryChangeScreen), findsNothing);
      expect(host.sent, isEmpty);
    });

    testWidgets('Android back closes without a request', (tester) async {
      final host = await _open(tester, [_a, _b], [_a]);
      await _tapRow(tester, _b);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CategoryChangeScreen), findsNothing);
      expect(host.sent, isEmpty);
    });

    testWidgets('iOS edge swipe closes without a request', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final host = await _open(tester, [_a, _b], [_a]);
        await _tapRow(tester, _b);
        await tester.timedDragFrom(
          const Offset(5, 400),
          const Offset(300, 0),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CategoryChangeScreen), findsNothing);
        expect(host.sent, isEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('screen reader reads name and check state; buttons are buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, [_a, _b], [_a]);
    expect(
      tester.getSemantics(_row(_a)),
      isSemantics(
        label: '제품추천',
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_row(_b)),
      isSemantics(label: '일본여행', hasCheckedState: true, isChecked: false),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('category-change-toggle-all')),
      ),
      isSemantics(label: '전체 선택', isButton: true, hasTapAction: true),
    );
    expect(find.bySemanticsLabel('선택 완료'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('선택 완료')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  group('overflow at 320 wide', () {
    final long = _cat(5, List.filled(40, '가').join());
    for (final scale in [1.0, 1.3]) {
      testWidgets('40-character name at $scale ellipsizes in one line', (
        tester,
      ) async {
        await _open(tester, [long], [long], width: 320, textScale: scale);
        final name = find.text(long.name);
        final paragraph = tester.renderObject<RenderParagraph>(name);
        expect(paragraph.text.style?.fontFamily, 'Pretendard');
        expect(paragraph.didExceedMaxLines, isTrue);
        expect(
          tester.getRect(name).right,
          lessThanOrEqualTo(tester.getRect(_row(long)).right),
        );
        expect(tester.takeException(), isNull);
      });
    }
    for (final scale in [1.0, 1.3]) {
      testWidgets('count and 전체 해제 line at $scale fits', (tester) async {
        await _open(tester, [_a], [_a], width: 320, textScale: scale);
        expect(_toggleLabel(tester), '전체 해제');
        final label = find.text('전체 해제');
        expect(
          tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
          isFalse,
        );
        expect(tester.getRect(label).right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
      });
    }
    for (final scale in [1.0, 1.3]) {
      testWidgets('content management menu description at $scale fits', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 812);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              fontFamily: 'Pretendard',
              textTheme: ThemeData.fallback().textTheme.apply(
                fontFamily: 'Pretendard',
              ),
            ),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 812),
                textScaler: TextScaler.linear(scale),
              ),
              child: Builder(
                builder: (context) => Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: ContentActionSheet(
                      content: _content([_a]),
                      categories: [_a],
                      onChangeCategory: (_) {},
                      onDelete: () {},
                      ownerContext: context,
                      isCurrent: () => true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final description = find.text('이 콘텐츠를 넣을 카테고리를 골라요.');
        expect(description, findsOneWidget);
        expect(find.text('이 콘텐츠를 다른 카테고리로 옮겨요.'), findsNothing);
        expect(
          tester
              .renderObject<RenderParagraph>(description)
              .text
              .style
              ?.fontFamily,
          'Pretendard',
        );
        expect(tester.getRect(description).right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('archive filtering without a server feed (#408 ①)', () {
    testWidgets('a content in two categories shows under its second name', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentListView(
              contents: [
                _content([_a, _b]),
              ],
              categories: [_a, _b],
              bookmarkedIds: const {},
              bookmarkedFirst: false,
              activeCategoryName: _b.name,
              onSortChanged: (_) {},
              onClearCategory: () {},
              onOpenContent: (_) {},
              onToggleBookmark: (_) {},
              onChangeContentCategory: (_, _) {},
              onDeleteContent: (_) {},
              onGoHome: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('콘텐츠'), findsOneWidget);
    });
  });
}
