// #256 R10: J04·J05·J06 take long names, large counts and 1.3x text by
// wrapping, never by shrinking or ellipsis. Real Pretendard fonts are loaded.
// Each input and scale has its own test because Flutter reports an overflow
// of the same widget only once per test.
import 'package:clipback_frontend/features/account/account_deleted_screen.dart';
import 'package:clipback_frontend/features/account/account_deletion_screen.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/logout_alignment_fixture.dart' as fixture;

// 80 characters: the server's display name limit.
final _longName = List.filled(8, '가나다라마바사아자차').join();

typedef _Input = ({String name, int content, int category});

final _inputs = <String, _Input>{
  'name 80': (name: _longName, content: 1557, category: 10),
  'max counts': (name: '정지윤', content: 9999999, category: 99999),
};

Future<void> _pump(WidgetTester tester, double scale, Widget screen) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 812);
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
      ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

List<RenderParagraph> _paragraphs(WidgetTester tester, Finder screen) => tester
    .renderObjectList<RenderParagraph>(
      find.descendant(of: screen, matching: find.byType(RichText)),
    )
    .toList();

RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)).first,
    );

// Line count from the laid-out height and the fixed line height of the style.
int _lines(RenderParagraph p) {
  final style = (p.text as TextSpan).style!;
  return (p.size.height / p.textScaler.scale(style.fontSize! * style.height!))
      .round();
}

void _expectWrappedNotShrunk(WidgetTester tester, Finder screen, double scale) {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final paragraphs = _paragraphs(tester, screen);
  expect(paragraphs, isNotEmpty);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    expect(p.maxLines, isNull, reason: text);
    expect(p.overflow, TextOverflow.clip, reason: text);
    expect(p.didExceedMaxLines, isFalse, reason: text);
    expect(p.softWrap, isTrue, reason: text);
    expect(p.textScaler.scale(10), closeTo(10 * scale, 1e-9), reason: text);
    expect(p.size.width, lessThanOrEqualTo(p.constraints.maxWidth + .01));
    final box = MatrixUtils.transformRect(
      p.getTransformTo(null),
      Offset.zero & p.size,
    );
    expect(box.left, greaterThanOrEqualTo(-.01), reason: text);
    expect(box.right, lessThanOrEqualTo(width + .01), reason: text);
  }
  expect(tester.takeException(), isNull);
}

// The body scrolls; its last text must be reachable above the footer.
Future<void> _expectBodyReachable(
  WidgetTester tester,
  String scrollKey,
  Finder last,
) async {
  final scroll = find.byKey(ValueKey(scrollKey));
  final position = tester
      .state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)),
      )
      .position;
  // Drag like a user so that a body which cannot scroll fails here.
  await tester.drag(scroll, const Offset(0, -2000));
  await tester.pumpAndSettle();
  expect(position.pixels, closeTo(position.maxScrollExtent, .01));
  expect(
    tester.getRect(last).bottom,
    lessThanOrEqualTo(tester.getRect(scroll).bottom + .01),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = await fixture.logoutInspectFonts(loadForTest: true);
    expect(fonts['available'], isTrue);
  });

  for (final scale in [1.0, 1.3]) {
    for (final input in _inputs.entries) {
      for (final selected in [false, true]) {
        final state = selected ? 'J05' : 'J04';
        testWidgets('$state ${input.key} at ${scale}x wraps without overflow', (
          tester,
        ) async {
          final v = input.value;
          await _pump(
            tester,
            scale,
            AccountDeletionScreen(
              name: v.name,
              contentCount: v.content,
              categoryCount: v.category,
              onBack: () {},
              onSubmit: (_) async {},
            ),
          );
          if (selected) {
            for (final label in accountDeletionReasonLabels.values) {
              await tester.ensureVisible(
                find.byKey(ValueKey('account-deletion-reason-$label')),
              );
              await tester.tap(
                find.byKey(ValueKey('account-deletion-reason-$label')),
              );
              await tester.pump();
            }
          }
          final screen = find.byType(AccountDeletionScreen);
          _expectWrappedNotShrunk(tester, screen, scale);
          final description = _paragraph(
            tester,
            find.byKey(const ValueKey('account-deletion-description')),
          );
          expect(description.text.toPlainText(), startsWith('${v.name} 님의'));
          if (input.key == 'name 80') {
            // The name wraps onto more lines than the two of the design.
            expect(_lines(description), greaterThan(2));
          }
          expect(
            find.text('콘텐츠 ${v.content}개'),
            findsOneWidget,
            reason: 'counts are shown in full',
          );
          expect(find.text('카테고리 ${v.category}개'), findsOneWidget);
          for (final key in [
            'account-deletion-submit',
            'account-deletion-cancel',
          ]) {
            final button = tester.getRect(find.byKey(ValueKey(key)));
            expect(button.height, greaterThanOrEqualTo(48));
            expect(button.width, 343);
          }
          await _expectBodyReachable(
            tester,
            'account-deletion-scroll',
            find.byKey(const ValueKey('account-deletion-notice')),
          );
        });
      }
    }
    testWidgets('J06 at ${scale}x wraps without overflow', (tester) async {
      await _pump(tester, scale, AccountDeletedScreen(onDone: () {}));
      _expectWrappedNotShrunk(tester, find.byType(AccountDeletedScreen), scale);
      final button = tester.getRect(
        find.byKey(const ValueKey('account-deleted-login')),
      );
      expect(button.height, greaterThanOrEqualTo(56));
      expect(button.width, 343);
      await _expectBodyReachable(
        tester,
        'account-deleted-scroll',
        find.byKey(const ValueKey('account-deleted-description')),
      );
    });
  }

  // Figma J04 111:5780 / J05 111:5824 / J06 111:5756 at 1.0x on 375×812.
  testWidgets('J04 and J05 follow the Figma text roles and geometry', (
    tester,
  ) async {
    await _pump(
      tester,
      1,
      AccountDeletionScreen(
        name: '정지윤',
        contentCount: 1557,
        categoryCount: 10,
        onBack: () {},
        onSubmit: (_) async {},
      ),
    );
    void style(String text, double size, int weight, double spacing) {
      final s = (_paragraph(tester, find.text(text)).text as TextSpan).style!;
      expect(s.fontSize, size, reason: text);
      expect(s.fontWeight!.value, weight, reason: text);
      expect(s.letterSpacing, spacing, reason: text);
    }

    style('계정 관리', 19, 600, -.475);
    style('정말로 탈퇴하시겠어요?', 25, 700, -.625);
    style('삭제 대상', 15, 600, -.375);
    style('콘텐츠 1557개', 15, 500, -.375);
    style('재가입', 15, 500, -.375);
    style('회원탈퇴 유의사항', 15, 600, -.375);
    style('탈퇴하기', 17, 600, 0);
    style('취소', 17, 600, 0);
    // Safe-area top 59 = Figma status bar 50 + 9; offsets below follow Figma.
    const top = 59.0 - 50;
    expect(tester.getRect(find.text('정말로 탈퇴하시겠어요?')).top, 130 + top);
    expect(
      tester.getRect(find.byKey(const ValueKey('account-deletion-target'))),
      const Rect.fromLTWH(16, 240 + top, 343, 86),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('account-deletion-reasons'))),
      const Rect.fromLTWH(16, 330 + top, 343, 212),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('account-deletion-notice'))),
      // 8px side padding inside the 343 body gives the Figma 327 text width.
      const Rect.fromLTWH(16, 549 + top, 343, 86),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('account-deletion-cancel'))),
      const Rect.fromLTWH(16, 812 - 34 - 32 - 48, 343, 48),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('account-deletion-submit'))),
      const Rect.fromLTWH(16, 812 - 34 - 32 - 48 - 8 - 48, 343, 48),
    );
    final disabled = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('account-deletion-submit')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(disabled.onPressed, isNull);
    expect(
      disabled.style!.backgroundColor!.resolve({WidgetState.disabled}),
      AppColors.subtler,
    );
    await tester.tap(find.byKey(const ValueKey('account-deletion-reason-재가입')));
    await tester.pump();
    final enabled = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('account-deletion-submit')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(enabled.onPressed, isNotNull);
    expect(enabled.style!.backgroundColor!.resolve({}), AppColors.text);
    expect(enabled.style!.foregroundColor!.resolve({}), AppColors.main);
    expect(tester.takeException(), isNull);
  });

  testWidgets('J06 follows the Figma text roles and geometry', (tester) async {
    await _pump(tester, 1, AccountDeletedScreen(onDone: () {}));
    final title = tester.getRect(find.text('탈퇴가 완료되었습니다.'));
    final image = tester.getRect(
      find.byKey(const ValueKey('account-deleted-illustration')),
    );
    expect(image.size, const Size(277, 277));
    expect(image.left, 49);
    expect(title.top, image.bottom);
    final button = tester.getRect(
      find.byKey(const ValueKey('account-deleted-login')),
    );
    expect(button, const Rect.fromLTWH(16, 812 - 34 - 56, 343, 56));
    // Figma centers image+text 29.5px above the body center.
    final group = image.expandToInclude(
      tester.getRect(find.byKey(const ValueKey('account-deleted-description'))),
    );
    final bodyCenter = (59 + button.top) / 2;
    expect(group.center.dy, closeTo(bodyCenter - 29.5, .01));
    expect(tester.takeException(), isNull);
  });
}
