// #391 root app: text without its own font family takes Pretendard from the
// app theme on both platforms. Sizes, weights and line heights stay as
// declared; values the widget does not set stay the theme's.
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/content/content_delete_dialog.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/archive_all_preview.dart' as isolated;
import 'support/theme_font_app.dart';

ThemeData _theme(WidgetTester t) =>
    Theme.of(t.element(find.byType(ClipbackNavigationBar).first));

void _expectStyle(
  WidgetTester t,
  String text, {
  required double size,
  required FontWeight? weight,
  required double? height,
}) {
  final style = paragraph(t, text).text.style!;
  expect(style.fontFamily, 'Pretendard', reason: text);
  expect(style.fontSize, size, reason: text);
  expect(style.fontWeight, weight, reason: text);
  expect(style.height, height, reason: text);
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group(platform.name, () {
      testWidgets('theme text styles are Pretendard', (t) async {
        await withThemeFontApp(t, platform: platform, (s) async {
          final theme = _theme(t).textTheme;
          for (final style in [
            theme.bodyMedium,
            theme.bodyLarge,
            theme.labelLarge,
            theme.titleMedium,
            theme.headlineSmall,
          ]) {
            expect(style!.fontFamily, 'Pretendard');
          }
        });
      });

      testWidgets('link save delay notice is Pretendard 13 w500', (t) async {
        await withThemeFontApp(t, platform: platform, (s) async {
          await showDelayNotice(t, s);
          _expectStyle(
            t,
            delayMessage,
            size: 13,
            weight: FontWeight.w500,
            height: 1.35,
          );
        });
      });

      testWidgets('content list card title, summary and badge', (t) async {
        await withThemeFontApp(t, platform: platform, (s) async {
          final body = _theme(t).textTheme.bodyMedium!;
          final content = isolated.archiveAllContents()[3];
          await showOnApp(
            t,
            ContentListCard(
              content: content,
              onTap: () {},
              onToggleBookmark: () {},
              categories: const [],
              onChangeCategory: (_) {},
              onDelete: () {},
            ),
          );
          _expectStyle(
            t,
            content.title,
            size: 16,
            weight: FontWeight.w600,
            height: 1.4,
          );
          _expectStyle(
            t,
            content.summary,
            size: 15,
            weight: body.fontWeight!,
            height: 1.6,
          );
          _expectStyle(
            t,
            content.category.name,
            size: 12,
            weight: FontWeight.w600,
            height: body.height,
          );
        });
      });

      testWidgets('dialog buttons', (t) async {
        await withThemeFontApp(t, platform: platform, (s) async {
          await showOnApp(t, const ContentDeleteDialog());
          for (final label in ['취소', '삭제']) {
            _expectStyle(
              t,
              label,
              size: 14,
              weight: FontWeight.w600,
              height: 22 / 14,
            );
          }
        });
      });

      testWidgets('PrimaryButton label', (t) async {
        await withThemeFontApp(t, platform: platform, (s) async {
          await showOnApp(t, PrimaryButton(label: '다시 시도', onPressed: () {}));
          _expectStyle(
            t,
            '다시 시도',
            size: 16,
            weight: FontWeight.w700,
            height: null,
          );
        });
      });

      testWidgets('empty state title and body', (t) async {
        await withThemeFontApp(t, platform: platform, (s) async {
          final body = _theme(t).textTheme.bodyMedium!;
          await showOnApp(
            t,
            EmptyStatePanel(
              title: '즐겨찾기한 콘텐츠가 없어요',
              body: '중요한 콘텐츠의 별 아이콘을 누르면 이곳에 모아둘 수 있어요.',
              actionLabel: '아카이브 보러가기',
              onAction: () {},
            ),
          );
          _expectStyle(
            t,
            '즐겨찾기한 콘텐츠가 없어요',
            size: 16,
            weight: FontWeight.w700,
            height: body.height,
          );
          _expectStyle(
            t,
            '중요한 콘텐츠의 별 아이콘을 누르면 이곳에 모아둘 수 있어요.',
            size: 14,
            weight: body.fontWeight!,
            height: 1.5,
          );
        });
      });

      // 2026-11-15 사용자 "추천대로"(B): a button textStyle replaces the
      // theme text whole, so these name Pretendard; unset values stay unset.
      testWidgets('search empty result button', (t) async {
        await withThemeFontApp(t, platform: platform, (s) async {
          await showOnApp(t, EmptySearchResult(onOpenArchive: () {}));
          _expectStyle(
            t,
            '전체 리스트 보기',
            size: 14,
            weight: FontWeight.w700,
            height: null,
          );
        });
      });

      testWidgets('My stats retry button', (t) async {
        await withThemeFontApp(t, platform: platform, failStats: true, (
          s,
        ) async {
          await openMy(t);
          _expectStyle(t, '다시 시도', size: 14, weight: null, height: null);
        });
      });
    });
  }
}
