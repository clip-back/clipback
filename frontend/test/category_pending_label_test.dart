// #266: 카테고리 수정 중에는 '변경 중…' 없이 행 더보기를 잠그고 관리 시트를 열지 않는다.
// 수정 중 상태(B8, 재확인 경로 콜백이 없을 때의 경로)는 실제 앱 화면에서 지나지 않으므로
// 저장소의 카테고리 진행 상태를 화면 모델(ContentViewModel.categories)로 투영해 위젯에 직접 넣는다.
// 넘침·배치는 실제 Pretendard, 40자 한글 이름 × 저장 날짜 있음/없음 × 배율 1.0·1.3 ×
// 행 일반·아카이브 형태를 조합마다 따로 둔다(Flutter는 같은 위젯의 넘침을 한 번만 알린다).
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 카테고리 이름 최대 길이 40자.
final _longName = '가나다라마바사아자차' * 4;

/// 카테고리 목록과 진행 상태만 내주는 저장소 대역. [deleting]은
/// `categoryMutationDeleting`의 값이다(null 평상시, false 수정 중, true 삭제 중).
class _Repo extends ChangeNotifier implements ContentRepository {
  _Repo(this.categories, this.deleting);

  @override
  final List<ApiCategory> categories;
  final bool? deleting;

  @override
  bool? categoryMutationDeleting(int id) => deleting;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CategoryItem _project({required bool? deleting, bool dated = true}) {
  final model = ContentViewModel(
    _Repo([
      ApiCategory(
        id: 101,
        name: _longName,
        color: '#4CAF50',
        isDefault: false,
        contentCount: 3,
        lastSavedAt: dated ? DateTime(2026, 10, 12, 12, 3) : null,
      ),
    ], deleting),
  );
  addTearDown(model.dispose);
  return model.categories.single;
}

Widget _app(Widget child, double scale) => MaterialApp(
  key: UniqueKey(),
  theme: ThemeData(fontFamily: 'Pretendard'),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 393, child: child),
        ),
      ),
    ),
  ),
);

Finder _more(bool archive) => archive
    ? find.byKey(const ValueKey('archive-category-more-101'))
    : find
          .descendant(
            of: find.byType(CategoryRow),
            matching: find.byType(GestureDetector),
          )
          .last;

// 일반 형태 행(archiveStyle: false, 앱 화면 미사용)은 배율 1.3에서 평상시에도 아래로 8px
// 넘친다(#266 결정 A: 범위 밖 발견, 이번에 고치지 않음). 그 두 조합만 평상시와 B8의
// 넘침이 이 같은 8px인지 비교하고, 그 밖의 조합·오류는 모두 실패시킨다.
const _knownGeneralOverflow =
    'A RenderFlex overflowed by 8.0 pixels on the bottom.';

String? _takeOverflow(WidgetTester tester) =>
    tester.takeException()?.toString().split('\n').first;

String _dateText(CategoryItem category) => category.lastSavedAt ?? '저장된 콘텐츠 없음';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
  });

  for (final archive in [false, true]) {
    final style = archive ? 'archive' : 'general';
    for (final dated in [true, false]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('B8 pending $style category row keeps idle layout without '
            '변경 중… (40자, date=$dated, scale=$scale)', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(393, 852);
          addTearDown(tester.view.reset);
          var opened = 0;
          final expectedOverflow = !archive && scale == 1.3
              ? _knownGeneralOverflow
              : null;

          final idle = _project(deleting: null, dated: dated);
          await tester.pumpWidget(
            _app(
              CategoryRow(
                category: idle,
                archiveStyle: archive,
                onMore: () => opened++,
              ),
              scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(_takeOverflow(tester), expectedOverflow, reason: '평상시 넘침');
          final idleRow = tester.getRect(find.byType(CategoryRow));
          final idleMore = tester.getRect(_more(archive));
          await tester.tap(_more(archive));
          expect(opened, 1, reason: '평상시 더보기는 열린다');

          final pending = _project(deleting: false, dated: dated);
          await tester.pumpWidget(
            _app(
              CategoryRow(
                category: pending,
                archiveStyle: archive,
                onMore: () => opened++,
              ),
              scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            _takeOverflow(tester),
            expectedOverflow,
            reason: '평상시와 다른 넘침 없음',
          );
          expect(find.text('변경 중…'), findsNothing);
          final date = tester.widget<Text>(find.text(_dateText(idle)));
          expect(date.maxLines, 1);
          expect(date.overflow, TextOverflow.ellipsis);
          final name = tester.widget<Text>(find.text(_longName));
          expect(name.maxLines, 1);
          expect(name.overflow, TextOverflow.ellipsis);
          expect(tester.getRect(find.byType(CategoryRow)), idleRow);
          expect(tester.getRect(_more(archive)), idleMore);
          await tester.tap(_more(archive));
          await tester.pumpAndSettle();
          expect(opened, 1, reason: '수정 중 더보기는 잠긴다');
        });
      }
    }
  }

  for (final state in ['idle', 'pending', 'deleting']) {
    testWidgets('category management sheet $state shows no 변경 중… and '
        'opens only when idle', (tester) async {
      final category = _project(
        deleting: switch (state) {
          'pending' => false,
          'deleting' => true,
          _ => null,
        },
      );
      late BuildContext owner;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Pretendard'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                owner = context;
                return CategoryActionSheet(
                  category: category,
                  contentCount: 3,
                  onEdit: () {},
                  onDelete: () {},
                );
              },
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
      expect(category.isDeleting, state == 'deleting');
      for (final row in tester.widgetList<CategoryActionRow>(
        find.byType(CategoryActionRow),
      )) {
        expect(row.enabled, state == 'idle', reason: row.title);
      }

      showCategoryActionSheet(
        context: owner,
        category: category,
        contentCount: 3,
        onUpdate: (_, _) {},
        onDelete: (_) {},
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(CategoryActionSheet),
        state == 'idle' ? findsNWidgets(2) : findsOneWidget,
        reason: '관리 시트는 평상시에만 열린다',
      );
    });
  }

  testWidgets('deleting category row keeps 삭제 중… and locks more', (
    tester,
  ) async {
    for (final archive in [false, true]) {
      var opened = 0;
      await tester.pumpWidget(
        _app(
          CategoryRow(
            category: _project(deleting: true),
            archiveStyle: archive,
            onMore: () => opened++,
          ),
          1,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('삭제 중…'), findsOneWidget);
      await tester.tap(_more(archive));
      await tester.pumpAndSettle();
      expect(opened, 0);
    }
  });
}
