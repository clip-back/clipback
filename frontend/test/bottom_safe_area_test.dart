import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/empty_state.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _height = 812.0;
const _labels = ['홈', '아카이브', '즐겨찾기', '마이'];
const _routes = [
  AppRoute.home,
  AppRoute.archive,
  AppRoute.bookmark,
  AppRoute.my,
];
const _icons = [Assets.home, Assets.archive, Assets.star, Assets.account];
const _category = CategoryItem(
  id: 1,
  name: '생활',
  color: AppColors.main,
  tint: AppColors.mainSubtle,
  deep: AppColors.mainDeep,
);

ContentItem _content(int index) => ContentItem(
  id: 'safe-card-$index',
  title: '다시 확인할 정보 $index',
  summary: '짧은 요약을 확인해요.',
  category: _category,
  savedAt: '오늘',
  savedAtFull: '2026. 10. 14',
  savedAtFullShort: '26.10.14',
  tags: const [],
  source: 'web',
  originalUrl: 'https://example.com/safe-card/$index',
  originalText: '다시 확인하고 싶은 내용이에요.',
);

Future<void> _render(
  WidgetTester tester, {
  required Widget screen,
  required double width,
  required TargetPlatform platform,
  double scale = 1,
  double bottom = 0,
  double keyboard = 0,
  GlobalKey? boundary,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, _height);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.padding = FakeViewPadding(
    top: top,
    bottom: math.max(0, bottom - keyboard),
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  final app = MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      platform: platform,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.main,
        surface: AppColors.bg,
      ),
      textTheme: ThemeData.fallback().textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: screen,
  );
  await tester.pumpWidget(
    boundary == null ? app : RepaintBoundary(key: boundary, child: app),
  );
  await tester.pumpAndSettle();
}

Widget _navigation({ValueChanged<AppRoute>? onTap, VoidCallback? onAdd}) =>
    Scaffold(
      bottomNavigationBar: ClipbackNavigationBar(
        activeIndex: 0,
        onTap: onTap ?? (_) {},
        onAdd: onAdd ?? () {},
      ),
    );

Finder _label(String label) => find.descendant(
  of: find.byType(ClipbackNavigationBar),
  matching: find.text(label),
);

double _maxRenderedLabelHeight(WidgetTester tester) => _labels
    .map((label) => tester.getSize(_label(label)).height)
    .reduce(math.max);

Finder _icon(String asset) => find.descendant(
  of: find.byType(ClipbackNavigationBar),
  matching: find.byWidgetPredicate(
    (widget) => widget is SvgIcon && widget.asset == asset,
  ),
);

Finder _slot(String label) =>
    find.ancestor(of: _label(label), matching: find.byType(InkWell)).first;

void _contained(Rect child, Rect parent) {
  expect(child.left, greaterThanOrEqualTo(parent.left - .01));
  expect(child.top, greaterThanOrEqualTo(parent.top - .01));
  expect(child.right, lessThanOrEqualTo(parent.right + .01));
  expect(child.bottom, lessThanOrEqualTo(parent.bottom + .01));
}

Future<Uint8List> _bottomPixels(
  WidgetTester tester,
  GlobalKey boundary,
  int band,
) async => (await tester.runAsync(() async {
  final image =
      await (boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = image.width * (image.height - band) * 4;
    return Uint8List.fromList(
      data!.buffer.asUint8List(
        data.offsetInBytes + offset,
        image.width * band * 4,
      ),
    );
  } finally {
    image.dispose();
  }
}))!;

Widget _cards({
  bool empty = false,
  VoidCallback? onExit,
  ValueChanged<ContentItem>? onOpen,
  ValueChanged<ContentItem>? onBookmark,
}) => CategoryCardReviewScreen(
  contents: empty ? const [] : List.generate(3, _content),
  categoryName: _category.name,
  bookmarkedIds: const {},
  onExit: onExit ?? () {},
  onOpenContent: onOpen ?? (_) {},
  onToggleBookmark: onBookmark ?? (_) {},
);

Finder get _activeCard => find.byType(CategoryReviewCard).last;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final bottom in [0.0, 24.0, 34.0, 48.0]) {
          testWidgets('navigation uses one safe inset at $platform $width '
              'scale $scale bottom $bottom', (tester) async {
            addTearDown(tester.view.reset);
            final routes = <AppRoute>[];
            var adds = 0;
            Widget screen() =>
                _navigation(onTap: routes.add, onAdd: () => adds++);
            await _render(
              tester,
              screen: screen(),
              width: width,
              platform: platform,
            );
            final baseLabel = _maxRenderedLabelHeight(tester);
            expect(
              tester.getSize(find.byType(ClipbackNavigationBar)).height,
              64,
            );
            final baseIcons = [
              for (final icon in _icons) tester.getRect(_icon(icon)),
            ];
            await _render(
              tester,
              screen: screen(),
              width: width,
              platform: platform,
              scale: scale,
              bottom: bottom,
            );
            expect(tester.takeException(), isNull);
            final bar = tester.getRect(find.byType(ClipbackNavigationBar));
            final fontExtra = _maxRenderedLabelHeight(tester) - baseLabel;
            expect(bar.height, closeTo(64 + fontExtra + bottom, .01));
            expect(bar.bottom, _height);
            final content = Rect.fromLTRB(
              bar.left,
              bar.top,
              bar.right,
              bar.bottom - bottom,
            );
            final slots = [
              for (final label in _labels) tester.getRect(_slot(label)),
            ];
            for (var index = 0; index < _labels.length; index++) {
              final paragraph = tester.renderObject<RenderParagraph>(
                _label(_labels[index]),
              );
              expect(paragraph.maxLines, 2);
              expect(paragraph.overflow, TextOverflow.ellipsis);
              expect(slots[index].height, closeTo(slots.first.height, .01));
              _contained(slots[index], content);
              _contained(tester.getRect(_label(_labels[index])), slots[index]);
              final icon = tester.getRect(_icon(_icons[index]));
              expect(icon.size, const Size(28, 28));
              expect(icon.center.dx, baseIcons[index].center.dx);
              expect(icon.top, tester.getRect(_icon(_icons.first)).top);
            }
            final add = tester.getRect(find.byType(NavAddButton));
            expect(add.size, const Size(72, 72));
            expect(add.top, bar.top - 22);
            expect(add.bottom, lessThanOrEqualTo(content.bottom));
            for (var index = 0; index < _labels.length; index++) {
              await tester.tap(_label(_labels[index]));
              await tester.pumpAndSettle();
              expect(routes, _routes.take(index + 1).toList());
            }
            await tester.tapAt(add.center);
            await tester.pumpAndSettle();
            expect(adds, 1);
            await tester.tapAt(add.bottomCenter - const Offset(0, 2));
            await tester.pumpAndSettle();
            expect(adds, 2);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets('application does not paint a second system home indicator', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await _render(
      tester,
      screen: _navigation(),
      width: 375,
      platform: TargetPlatform.iOS,
      bottom: 34,
      boundary: boundary,
    );
    final band = await _bottomPixels(tester, boundary, 34);
    final offset = ((34 - 10) * 375 + 187) * 4;
    expect(band.sublist(offset, offset + 4), [255, 255, 255, 255]);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        'keyboard never becomes navigation safe padding at $platform $width',
        (tester) async {
          addTearDown(tester.view.reset);
          await _render(
            tester,
            screen: _navigation(),
            width: width,
            platform: platform,
            scale: 2,
            bottom: 34,
          );
          final before = tester.getRect(find.byType(ClipbackNavigationBar));
          await _render(
            tester,
            screen: _navigation(),
            width: width,
            platform: platform,
            scale: 2,
            bottom: 34,
            keyboard: 300,
          );
          final during = tester.getRect(find.byType(ClipbackNavigationBar));
          expect(during, before);
          expect(during.height, lessThan(300));
          final slot = tester.getRect(_slot('아카이브'));
          expect(slot.bottom, lessThanOrEqualTo(during.bottom - 34));
          await _render(
            tester,
            screen: _navigation(),
            width: width,
            platform: platform,
            scale: 2,
            bottom: 34,
          );
          expect(tester.getRect(find.byType(ClipbackNavigationBar)), before);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final bottom in [0.0, 24.0, 34.0, 48.0]) {
    for (final empty in [false, true]) {
      testWidgets(
        'card review ${empty ? 'empty' : 'populated'} reserves bottom $bottom',
        (tester) async {
          addTearDown(tester.view.reset);
          var exits = 0;
          await _render(
            tester,
            screen: _cards(empty: empty, onExit: () => exits++),
            width: 375,
            platform: TargetPlatform.iOS,
            bottom: bottom,
          );
          final content = empty
              ? find.byType(EmptyStatePanel)
              : find
                    .ancestor(of: _activeCard, matching: find.byType(ClipRect))
                    .first;
          final viewport = tester.getRect(content);
          expect(viewport.top, 59);
          expect(viewport.bottom, _height - bottom);
          if (!empty) {
            expect(tester.getSize(_activeCard), const Size(343, 496));
            expect(
              tester
                  .widget<CardPagerProgress>(find.byType(CardPagerProgress))
                  .activeIndex,
              0,
            );
          }
          await tester.tap(find.text('나가기'));
          await tester.pumpAndSettle();
          expect(exits, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final empty in [false, true]) {
    testWidgets(
      'narrow scaled card review remains above its bottom safe inset, empty=$empty',
      (tester) async {
        addTearDown(tester.view.reset);
        await _render(
          tester,
          screen: _cards(empty: empty),
          width: 320,
          platform: TargetPlatform.android,
          scale: 2,
          bottom: 48,
        );
        final content = empty
            ? find.byType(EmptyStatePanel)
            : find
                  .ancestor(of: _activeCard, matching: find.byType(ClipRect))
                  .first;
        expect(tester.getRect(content).bottom, _height - 48);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        'card drag and transition never paint in bottom inset at $platform $width',
        (tester) async {
          addTearDown(tester.view.reset);
          final boundary = GlobalKey();
          final opened = <String>[];
          final bookmarks = <String>[];
          var exits = 0;
          await _render(
            tester,
            screen: _cards(
              onOpen: (item) => opened.add(item.id),
              onBookmark: (item) => bookmarks.add(item.id),
              onExit: () => exits++,
            ),
            width: width,
            platform: platform,
            bottom: 34,
            boundary: boundary,
          );
          final original = await _bottomPixels(tester, boundary, 34);
          final initialSize = tester.getSize(_activeCard);
          await tester.tap(find.text('다시 확인할 정보 0'));
          await tester.pumpAndSettle();
          expect(opened, ['safe-card-0']);
          final bookmark = find.descendant(
            of: _activeCard,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is InkWell && widget.customBorder is CircleBorder,
            ),
          );
          await tester.tap(bookmark);
          await tester.pumpAndSettle();
          expect(bookmarks, ['safe-card-0']);
          expect(opened, ['safe-card-0']);
          final gesture = await tester.startGesture(
            tester.getCenter(_activeCard),
          );
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump();
          await gesture.moveBy(const Offset(0, 80));
          await tester.pump();
          final duringDrag = await _bottomPixels(tester, boundary, 34);
          await gesture.up();
          await tester.pump(const Duration(milliseconds: 100));
          final duringTransition = await _bottomPixels(tester, boundary, 34);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();
          expect(duringDrag, orderedEquals(original));
          expect(duringTransition, orderedEquals(original));
          expect(
            tester
                .widget<CardPagerProgress>(find.byType(CardPagerProgress))
                .activeIndex,
            1,
          );
          expect(find.text('다시 확인할 정보 1'), findsWidgets);
          expect(tester.getSize(_activeCard), initialSize);
          await tester.tap(find.text('나가기'));
          await tester.pumpAndSettle();
          expect(exits, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
