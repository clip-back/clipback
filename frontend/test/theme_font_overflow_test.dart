// #391 fixed-size areas and changing text that take Pretendard from the app
// theme: the real Pretendard faces at width 320, one test per input and text
// scale (Flutter reports one overflow per widget, #355). The test font has
// other glyph widths, so a check without the loaded faces does not count.
import 'package:clipback_frontend/app/exit_confirmation_dialog.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/content/content_delete_dialog.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/archive_all_preview.dart' as isolated;
import 'support/theme_font_app.dart';

/// The longest category name the app accepts (40 runes), Hangul and Latin.
final _name40 = '개발과 기술의 참고자료 Flutter Dart 모음 2026 보관함 정리'.padRight(40, '가');

const _photoFormat = 'PNG, JPEG, WebP 이미지만 지원합니다.';

typedef _Text = (String text, Type box, bool ellipsis);

Future<void> _show(WidgetTester t, Widget child) => showOnApp(t, child);

/// [text] is drawn in Pretendard inside its [box] widget. Unless the widget
/// shortens it by design ([ellipsis]), it is not cut off either.
void _expectFits(WidgetTester t, _Text target) {
  final (text, box, ellipsis) = target;
  final p = paragraph(t, text);
  expect(p.text.style!.fontFamily, 'Pretendard', reason: text);
  if (!ellipsis) expect(p.didExceedMaxLines, isFalse, reason: text);
  final r = t.getRect(find.text(text));
  final b = t.getRect(
    find.ancestor(of: find.text(text), matching: find.byType(box)).first,
  );
  const e = .01;
  expect(
    r.left >= b.left - e &&
        r.right <= b.right + e &&
        r.top >= b.top - e &&
        r.bottom <= b.bottom + e,
    isTrue,
    reason: '$text $r outside $box $b',
  );
}

void main() {
  setUpAll(loadPretendard);

  test('the long category name is the 40 rune limit', () {
    expect(_name40.runes.length, 40);
  });

  final category = isolated.archiveAllCategories().first.copyWith(
    name: _name40,
  );
  final contents = isolated.archiveAllContents();
  final longTitle = contents.reduce(
    (a, b) => a.title.length >= b.title.length ? a : b,
  );
  final longBadge = contents.first.copyWith(category: category);

  ContentListCard card(ContentItem content) => ContentListCard(
    content: content,
    onTap: () {},
    onToggleBookmark: () {},
    categories: const [],
    onChangeCategory: (_) {},
    onDelete: () {},
  );

  final cases =
      <
        String,
        (Future<void> Function(WidgetTester t, ThemeFontServer s), List<_Text>)
      >{
        'link save delay notice': (
          showDelayNotice,
          [(delayMessage, SaveErrorToast, false)],
        ),
        'list card longest title': (
          (t, s) => _show(t, card(longTitle)),
          [(longTitle.title, ContentListCard, true)],
        ),
        'list card longest summary': (
          (t, s) => _show(t, card(longTitle)),
          [(longTitle.summary, ContentListCard, true)],
        ),
        'photo format notice': (
          (t, s) => _show(
            t,
            const Padding(
              // The save screen's toast slot (save_content_screen.dart).
              padding: EdgeInsets.fromLTRB(40, 0, 40, 16),
              child: SaveErrorToast(message: _photoFormat),
            ),
          ),
          [(_photoFormat, SaveErrorToast, false)],
        ),
        'category change tile 40': (
          (t, s) => _show(
            t,
            CategoryChangeTile(
              category: category,
              selected: true,
              onTap: () {},
            ),
          ),
          [(_name40, CategoryChangeTile, true)],
        ),
        'PrimaryButton label': (
          (t, s) => _show(t, PrimaryButton(label: '시작하기', onPressed: () {})),
          [('시작하기', PrimaryButton, false)],
        ),
        'category delete dialog buttons': (
          (t, s) => _show(
            t,
            CategoryDeleteDialog(category: category, onDelete: () {}),
          ),
          [('취소', OutlinedButton, false), ('삭제', FilledButton, false)],
        ),
        'content delete dialog buttons': (
          (t, s) => _show(t, const ContentDeleteDialog()),
          [('취소', OutlinedButton, false), ('삭제', FilledButton, false)],
        ),
        'exit dialog buttons': (
          (t, s) =>
              _show(t, ExitConfirmationDialog(onCancel: () {}, onExit: () {})),
          [('취소', OutlinedButton, false), ('종료', FilledButton, false)],
        ),
        'home empty state': (
          (t, s) => _show(t, const EmptyHomeContent()),
          [
            ('저장한 콘텐츠가 없어요', EmptyHomeContent, false),
            (
              'SNS에서 발견한 유용한 게시물을 저장하면 이곳에서 다시 확인할 수 있어요.',
              EmptyHomeContent,
              false,
            ),
          ],
        ),
        'EmptyStatePanel longest': (
          (t, s) => _show(
            t,
            EmptyStatePanel(
              title: '$_name40 콘텐츠가 없어요',
              body: '다른 카테고리를 보거나 필터를 해제해 전체 콘텐츠를 확인해 보세요.',
              actionLabel: '아카이브 보러가기',
              onAction: () {},
            ),
          ),
          [
            ('$_name40 콘텐츠가 없어요', EmptyStatePanel, false),
            ('다른 카테고리를 보거나 필터를 해제해 전체 콘텐츠를 확인해 보세요.', EmptyStatePanel, false),
            ('아카이브 보러가기', OutlinedButton, false),
          ],
        ),
        'archive sort menu': (
          (t, s) async {
            await _show(
              t,
              ArchiveSortButton(
                label: '즐겨찾기 우선',
                bookmarkedFirst: true,
                onSelected: (_) {},
              ),
            );
            await t.tap(find.byType(ArchiveSortButton));
            await t.pumpAndSettle();
          },
          [
            // '즐겨찾기 우선' is also the button label; checked below.
            ('최신순', PopupMenuItem<bool>, false),
          ],
        ),
        'login social and guest buttons': (
          (t, s) => _show(
            t,
            LoginScreen(
              linkingGuest: true,
              providers: SocialLoginProvider.values,
              onContinue: () async {},
              onSocialLogin: (_) async {},
            ),
          ),
          [
            ('구글로 계속하기', SocialButton, false),
            ('카카오로 계속하기', SocialButton, false),
            ('Apple로 계속하기', SocialButton, false),
            ('게스트로 계속 사용', TextButton, false),
          ],
        ),
        'search empty result button': (
          (t, s) => _show(t, EmptySearchResult(onOpenArchive: () {})),
          [('전체 리스트 보기', OutlinedButton, false)],
        ),
        'My stats retry button': (
          (t, s) => openMy(t),
          [('다시 시도', OutlinedButton, false)],
        ),
      };

  // The badge has no width limit (content_list_card.dart:54–57), so a
  // 40 rune name runs past the card with any font. That is out of #391's
  // scope and only recorded here; no screen reaches this card today
  // (archive_screen.dart:176). These tests check the font and errors only.
  for (final scale in [1.0, 1.3]) {
    testWidgets('list card badge 40 at width 320 and ${scale}x is Pretendard '
        '(running past the card is out of scope, recorded only)', (t) async {
      expect(pretendardLoaded(), isTrue, reason: 'Pretendard did not load');
      await withThemeFontApp(t, width: 320, scale: scale, (s) async {
        await _show(t, card(longBadge));
        expect(paragraph(t, _name40).text.style!.fontFamily, 'Pretendard');
        debugPrint(
          'BADGE40 scale=$scale badge=${t.getRect(find.text(_name40))} '
          'card=${t.getRect(find.byType(ContentListCard))}',
        );
        expect(t.takeException(), isNull);
      });
    });
  }

  for (final MapEntry(key: name, value: (show, targets)) in cases.entries) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('$name at width 320 and ${scale}x', (t) async {
        expect(pretendardLoaded(), isTrue, reason: 'Pretendard did not load');
        await withThemeFontApp(
          t,
          width: 320,
          scale: scale,
          failStats: name == 'My stats retry button',
          (s) async {
            await show(t, s);
            for (final target in targets) {
              _expectFits(t, target);
            }
            if (name == 'archive sort menu') {
              final selected = find.descendant(
                of: find.byType(PopupMenuItem<bool>),
                matching: find.text('즐겨찾기 우선'),
              );
              expect(selected, findsOneWidget);
              final p = t.renderObject(selected);
              expect((p as dynamic).text.style.fontFamily, 'Pretendard');
              final row = t.getRect(
                find
                    .ancestor(
                      of: selected,
                      matching: find.byType(PopupMenuItem<bool>),
                    )
                    .first,
              );
              expect(t.getRect(selected).right, lessThanOrEqualTo(row.right));
            }
            expect(t.takeException(), isNull);
          },
        );
      });
    }
  }
}
