// #265: 즐겨찾기·카테고리 이동 요청 중에는 '변경 중…' 없이 잠그고, 배치는 평상시와 같다.
// 실제 Pretendard, 40자 한글 카테고리 이름 × 저장 날짜 있음/없음 × 글자 배율 1.0·1.3을
// 조합마다 따로 둔다(Flutter는 같은 위젯의 넘침을 한 번만 알린다).
// 콘텐츠 관리 시트(B9)와 화면에 연결되지 않은 대표 카드는 위젯에 상태를 직접 넣어 확인한다.
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/content_actions.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/sheet_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 카테고리 이름 최대 길이 40자.
final _longName = '가나다라마바사아자차' * 4;

const _category = CategoryItem(
  id: 101,
  name: '공부',
  color: Colors.green,
  tint: Colors.white,
  deep: Colors.green,
);

ContentItem _content({
  required bool dated,
  bool mutating = false,
  String? label,
}) => ContentItem(
  id: 'api-3',
  apiId: 3,
  title: '두 줄 제목 첫째 줄 두 줄 제목 둘째 줄',
  summary: '세 줄 요약 첫째 줄 세 줄 요약 둘째 줄 세 줄 요약 셋째 줄',
  category: CategoryItem(
    id: 101,
    name: _longName,
    color: Colors.green,
    tint: Colors.white,
    deep: Colors.green,
  ),
  savedAt: dated ? '26.10.12' : '',
  savedAtFull: dated ? '2026. 10. 12 오후 12:03' : '',
  savedAtFullShort: dated ? '10.12' : '',
  tags: const [],
  source: '웹 링크',
  originalUrl: 'https://example.com/card',
  originalText: '원문',
  isMutating: mutating,
  mutationLabel: label,
);

Widget _app(Widget child, double scale) => MaterialApp(
  key: UniqueKey(),
  theme: ThemeData(fontFamily: 'Pretendard'),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: child),
    ),
  ),
);

Widget _target(String place, ContentItem content) => switch (place) {
  'home' => Center(
    child: SizedBox(
      width: 298,
      height: 186,
      child: HomeContentCard(
        content: content,
        bookmarked: false,
        onTap: () {},
        onToggleBookmark: () {},
      ),
    ),
  ),
  'list' || 'archive-all' => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 393,
      child: ContentListCard(
        content: content,
        archiveAllStyle: place == 'archive-all',
        bookmarked: false,
        categories: const [_category],
        onTap: () {},
        onToggleBookmark: () {},
        onChangeCategory: (_) {},
        onDelete: () {},
      ),
    ),
  ),
  'detail' => Align(
    alignment: Alignment.topCenter,
    child: DetailTopBar(
      content: content,
      categories: const [_category],
      bookmarked: false,
      onBack: () {},
      onToggleBookmark: () {},
      onChangeCategory: (_) {},
      onDeleteContent: () {},
    ),
  ),
  _ => Center(
    child: CategoryReviewCard(
      content: content,
      bookmarked: false,
      onOpenContent: () {},
      onToggleBookmark: () {},
    ),
  ),
};

Finder _star(String place, ContentItem content) => switch (place) {
  'home' || 'detail' => find.byType(BookmarkActionButton),
  'list' ||
  'archive-all' => find.byKey(ValueKey('list-bookmark-${content.title}')),
  _ => find.byKey(ValueKey('review-bookmark-${content.id}')),
};

Finder? _more(String place, ContentItem content) => switch (place) {
  'list' => find.byWidgetPredicate(
    (w) => w is SvgIconButton && w.asset == Assets.more,
  ),
  'archive-all' => find.byKey(ValueKey('archive-all-more-${content.id}')),
  'detail' => find.byKey(const ValueKey('detail-more')),
  _ => null,
};

bool _enabled(WidgetTester tester, Finder control) {
  final widget = tester.widget(control);
  if (widget is BookmarkActionButton) return widget.enabled;
  if (widget is SvgIconButton) return widget.enabled;
  final icon = find.descendant(of: control, matching: find.byType(IconButton));
  if (icon.evaluate().isNotEmpty) {
    return tester.widget<IconButton>(icon).onPressed != null;
  }
  return tester
          .widget<InkWell>(
            find.descendant(of: control, matching: find.byType(InkWell)),
          )
          .onTap !=
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
  });

  for (final place in ['home', 'list', 'archive-all', 'detail', 'review']) {
    for (final dated in [true, false]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('pending $place keeps idle layout without 변경 중… '
            '(40자 카테고리, date=$dated, scale=$scale)', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(393, 852);
          addTearDown(tester.view.reset);
          final idle = _content(dated: dated);
          await tester.pumpWidget(_app(_target(place, idle), scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final more = _more(place, idle);
          final idleStar = tester.getRect(_star(place, idle));
          final idleMore = more == null ? null : tester.getRect(more);
          expect(_enabled(tester, _star(place, idle)), isTrue);

          final pending = _content(dated: dated, mutating: true);
          await tester.pumpWidget(_app(_target(place, pending), scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '넘침 없음');
          expect(find.text('변경 중…'), findsNothing);
          expect(tester.getRect(_star(place, pending)), idleStar);
          expect(_enabled(tester, _star(place, pending)), isFalse);
          if (more != null) {
            expect(tester.getRect(more), idleMore);
            expect(_enabled(tester, more), isFalse);
          }
          if (place != 'detail') {
            final name = tester.widget<Text>(find.text(_longName));
            expect(name.maxLines, 1);
            expect(name.overflow, TextOverflow.ellipsis);
          }
          if (dated && (place == 'list' || place == 'archive-all')) {
            final date = tester.widget<Text>(find.text('26.10.12'));
            expect(date.maxLines, 1);
            expect(date.overflow, TextOverflow.ellipsis);
          }
        });
      }
    }
  }

  // 삭제 중에는 지금처럼 '삭제 중…'과 잠금이 보인다.
  for (final place in ['home', 'list', 'archive-all', 'detail', 'review']) {
    testWidgets('deleting $place still shows 삭제 중… and locks', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      final content = _content(dated: true, mutating: true, label: '삭제 중…');
      await tester.pumpWidget(_app(_target(place, content), 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('삭제 중…'), findsOneWidget);
      expect(_enabled(tester, _star(place, content)), isFalse);
    });
  }

  // B9: 요청 중에는 더보기가 잠겨 실제 앱에서 시트를 새로 열 수 없다. 상태를 직접 넣어 확인한다.
  for (final state in ['idle', 'pending', 'deleting']) {
    testWidgets('content management sheet $state status and actions', (
      tester,
    ) async {
      final content = _content(
        dated: true,
        mutating: state != 'idle',
        label: state == 'deleting' ? '삭제 중…' : null,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Pretendard'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ContentActionSheet(
                content: content,
                categories: const [_category],
                onChangeCategory: (_) {},
                onDelete: () {},
                ownerContext: context,
                isCurrent: () => true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('변경 중…'), findsNothing);
      expect(
        find.text('삭제 중…'),
        state == 'deleting' ? findsOneWidget : findsNothing,
      );
      for (final tile in tester.widgetList<SheetActionTile>(
        find.byType(SheetActionTile),
      )) {
        expect(tile.enabled, state == 'idle', reason: tile.title);
      }
    });
  }

  // 화면에 연결되지 않은 카테고리 대표 카드 위젯.
  for (final state in ['idle', 'pending', 'deleting']) {
    testWidgets('category featured card $state status and star', (
      tester,
    ) async {
      final content = _content(
        dated: true,
        mutating: state != 'idle',
        label: state == 'deleting' ? '삭제 중…' : null,
      );
      await tester.pumpWidget(
        _app(
          Center(
            child: CategoryFeaturedCard(
              content: content,
              bookmarked: false,
              onTap: () {},
              onToggleBookmark: () {},
            ),
          ),
          1,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('변경 중…'), findsNothing);
      expect(
        find.text('삭제 중…'),
        state == 'deleting' ? findsOneWidget : findsNothing,
      );
      expect(
        tester
            .widget<BookmarkActionButton>(find.byType(BookmarkActionButton))
            .enabled,
        state == 'idle',
      );
    });
  }
}
