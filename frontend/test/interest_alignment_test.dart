import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _title = '주로 어떤 정보를\n저장하고 싶으신가요?';
const _description = '최대 3개까지 선택해 주세요.';
const _limit = '최대 3개까지만 선택 가능해요';
const _labels = ['직장/자기개발', '뷰티/패션', '여행/장소', '인문/지식', '요리/식품', '경제/시사'];

Finder _key(String name) => find.byKey(ValueKey(name));
Finder _visibleLimit() => find.byElementPredicate((element) {
  final widget = element.widget;
  return widget is Text && widget.data == _limit && Visibility.of(element);
});
Finder _row(int index) {
  final keyed = _key('interest-option-$index');
  return keyed.evaluate().isNotEmpty
      ? keyed
      : find.byType(InterestOptionTile).at(index);
}

Finder _next() {
  final keyed = _key('interest-next');
  if (keyed.evaluate().isNotEmpty) return keyed;
  return find.ancestor(
    of: find.text('완료'),
    matching: find.byType(FilledButton),
  );
}

Finder _filled(WidgetTester tester) => tester.widget(_next()) is FilledButton
    ? _next()
    : find.descendant(of: _next(), matching: find.byType(FilledButton));
RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
TextStyle _style(WidgetTester tester, Finder text) =>
    (_paragraph(tester, text).text as TextSpan).style!;
void _expectStyle(
  WidgetTester tester,
  Finder text, {
  String family = 'Pretendard',
  required double size,
  required FontWeight weight,
  required double tracking,
  required Color color,
  double? height,
}) {
  final actual = _style(tester, text);
  expect(actual.fontFamily, family);
  expect(actual.fontSize, size);
  expect(actual.fontWeight, weight);
  expect(actual.letterSpacing, tracking);
  expect(actual.color, color);
  expect(actual.height, height);
  expect(_paragraph(tester, text).textScaler.scale(size), size);
}

class _Calls {
  int backs = 0, done = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  double? bottom,
}) async {
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final safeBottom = bottom ?? (platform == TargetPlatform.iOS ? 34.0 : 0.0);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.view.padding = FakeViewPadding(top: top, bottom: safeBottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: safeBottom);
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: InterestSelectionScreen(
        onBack: () => calls.backs++,
        onDone: () => calls.done++,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

Future<void> _tapRow(WidgetTester tester, int index) async {
  await tester.ensureVisible(_row(index));
  await tester.pump();
  await tester.tap(_row(index));
  await tester.pump();
}

List<int> _selected(WidgetTester tester) => [
  for (var i = 0; i < _labels.length; i++)
    if (tester
        .widgetList<InterestOptionTile>(find.byType(InterestOptionTile))
        .elementAt(i)
        .selected)
      i,
];
Future<void> _select(WidgetTester tester, Set<int> selected) async {
  for (var i = 0; i < _labels.length; i++) {
    if (_selected(tester).contains(i) && !selected.contains(i)) {
      await _tapRow(tester, i);
    }
  }
  for (final i in selected) {
    if (!_selected(tester).contains(i)) {
      await _tapRow(tester, i);
    }
  }
}

List<String> _svgPaths(WidgetTester tester, Finder parent) => [
  for (final svg in tester.widgetList<SvgPicture>(
    find.descendant(of: parent, matching: find.byType(SvgPicture)),
  ))
    if (svg.bytesLoader case SvgAssetLoader loader) loader.assetName,
];
BoxDecoration _decoration(WidgetTester tester, Finder finder) {
  final widget = tester.widget(finder);
  if (widget is Container && widget.decoration is BoxDecoration) {
    return widget.decoration! as BoxDecoration;
  }
  return tester
          .widget<DecoratedBox>(
            find
                .descendant(of: finder, matching: find.byType(DecoratedBox))
                .first,
          )
          .decoration
      as BoxDecoration;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final regular = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      regular.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await regular.load();
    await (FontLoader(
      'PretendardDetail',
    )..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'))).load();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        'B02 B03 typography layout original assets $platform width$width',
        (tester) async {
          final calls = await _pump(tester, platform: platform, width: width);
          final safeTop = platform == TargetPlatform.iOS ? 59.0 : 24.0;
          final safeBottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
          _expectStyle(
            tester,
            find.text(_title),
            family: 'PretendardDetail',
            size: 24,
            weight: FontWeight.w700,
            tracking: -.6,
            color: const Color(0xFF1A1A1A),
            height: 1.6,
          );
          _expectStyle(
            tester,
            find.text(_description),
            size: 16,
            weight: FontWeight.w500,
            tracking: -.4,
            color: const Color(0xFF767676),
            height: 1.5,
          );
          final titleParagraph = _paragraph(tester, find.text(_title));
          final titlePainter = TextPainter(
            text: titleParagraph.text,
            textDirection: TextDirection.ltr,
            textScaler: titleParagraph.textScaler,
          )..layout(maxWidth: titleParagraph.size.width);
          expect(titlePainter.computeLineMetrics(), hasLength(2));
          expect(
            tester.getTopLeft(find.text(_title)).dy,
            closeTo(safeTop + 80, .2),
          );
          final title = tester.getRect(find.text(_title)),
              desc = tester.getRect(find.text(_description));
          expect(desc.top - title.bottom, closeTo(8, .2));
          final rows = [
            for (var i = 0; i < _labels.length; i++) tester.getRect(_row(i)),
          ];
          expect(rows.first.top - desc.bottom, closeTo(31.2, .2));
          // Nominal 24 * 1.6 * 2 is 76.8px; Flutter rounds this actual
          // loaded-font paragraph to 76px. Keep measured gaps strict above.
          expect(rows.first.top, closeTo(safeTop + 220, 1));
          expect(_selected(tester), isEmpty);
          for (var i = 0; i < _labels.length; i++) {
            expect(rows[i].height, closeTo(44, .000001));
            expect(rows[i].width, width - 32);
            expect(rows[i].left, 16);
            if (i > 0) {
              expect(rows[i].top - rows[i - 1].bottom, closeTo(8, .2));
            }
            _expectStyle(
              tester,
              find.text(_labels[i]),
              size: 16,
              weight: FontWeight.w500,
              tracking: -.4,
              color: const Color(0xFF1A1A1A),
            );
            final rowDecoration = _decoration(tester, _row(i));
            expect(rowDecoration.color, Colors.white);
            expect(rowDecoration.borderRadius, BorderRadius.circular(4));
            final circle = _key('interest-circle-$i');
            expect(tester.getSize(circle), const Size(24, 24));
            expect(_decoration(tester, circle).color, const Color(0xFFD1D1D1));
            final check = _key('interest-check-$i');
            expect(tester.getSize(check), const Size(14, 14));
            expect(
              _svgPaths(tester, _row(i)),
              contains('assets/figma/interest-check-unselected.svg'),
            );
          }
          final nextButton = _filled(tester);
          expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
          expect(tester.getSize(_next()), Size(width - 32, 56));
          expect(
            tester.getRect(_next()).bottom,
            closeTo(812 - safeBottom - 32, .2),
          );
          expect(tester.getSize(_key('interest-limit-slot')).height, 37);
          expect(
            tester.getRect(_key('interest-body')).bottom,
            lessThanOrEqualTo(tester.getRect(_key('interest-footer')).top + .2),
          );
          expect(
            _svgPaths(tester, find.byType(InterestSelectionScreen)),
            isNot(contains(Assets.back)),
          );
          expect(find.byType(BackButton), findsNothing);
          expect(find.byType(PopScope<void>), findsNothing);
          expect(find.byType(PrimaryButton), findsNothing);
          expect(calls.backs, 0);
          await tester.tap(_next());
          await tester.pump();
          expect(calls.done, 0);
          await _tapRow(tester, 0);
          expect(_selected(tester), [0]);
          expect(
            _decoration(tester, _key('interest-circle-0')).color,
            const Color(0xFF1A1A1A),
          );
          expect(
            _svgPaths(tester, _row(0)),
            contains('assets/figma/interest-check-selected.svg'),
          );
          _expectStyle(
            tester,
            find.text('다음'),
            size: 16,
            weight: FontWeight.w600,
            tracking: 0,
            color: const Color(0xFFFFD75C),
            height: 22 / 16,
          );
          await tester.tap(_next());
          await tester.pump();
          expect(calls.done, 1);
          expect(calls.backs, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'zero one three selection and fourth rejected shows exact B04 inline alert',
    (tester) async {
      final calls = await _pump(tester);
      expect(_selected(tester), isEmpty);
      await _tapRow(tester, 0);
      await _tapRow(tester, 1);
      await _tapRow(tester, 2);
      expect(_selected(tester), [0, 1, 2]);
      final beforeFooter = tester.getRect(_key('interest-footer'));
      final beforeButton = tester.getRect(_next());
      final beforeScroll = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;
      await _tapRow(tester, 3);
      expect(_selected(tester), [0, 1, 2]);
      expect(_visibleLimit(), findsOneWidget);
      _expectStyle(
        tester,
        _visibleLimit(),
        size: 14,
        weight: FontWeight.w500,
        tracking: -.35,
        color: const Color(0xFFFF3C40),
        height: 1.5,
      );
      expect(tester.getSize(_key('interest-limit-icon')), const Size(18, 18));
      expect(
        _svgPaths(tester, _key('interest-limit-slot')),
        contains('assets/figma/interest-alert.svg'),
      );
      final icon = tester.getRect(_key('interest-limit-icon'));
      final text = tester.getRect(_visibleLimit());
      expect(text.left - icon.right, closeTo(4, .2));
      expect(tester.getRect(_key('interest-footer')), beforeFooter);
      expect(tester.getRect(_next()), beforeButton);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        beforeScroll,
      );
      expect(calls.done, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'B04 remains until 3 seconds and repeat fourth tap resets its timer',
    (tester) async {
      await _pump(tester);
      await _select(tester, {0, 1, 2});
      await _tapRow(tester, 3);
      expect(_visibleLimit(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(_visibleLimit(), findsOneWidget);
      await _tapRow(tester, 4);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_visibleLimit(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2998));
      expect(_visibleLimit(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_visibleLimit(), findsNothing);
      expect(_selected(tester), [0, 1, 2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ordinary selection change hides alert and zero selection blocks next again',
    (tester) async {
      final calls = await _pump(tester);
      await _select(tester, {0, 1, 2});
      await _tapRow(tester, 3);
      expect(_visibleLimit(), findsOneWidget);
      await _tapRow(tester, 1);
      expect(_visibleLimit(), findsNothing);
      expect(_selected(tester), [0, 2]);
      await _tapRow(tester, 3);
      expect(_selected(tester), [0, 2, 3]);
      expect(_visibleLimit(), findsNothing);
      await _select(tester, {});
      expect(_selected(tester), isEmpty);
      final filled = _filled(tester);
      expect(tester.widget<FilledButton>(filled).onPressed, isNull);
      _expectStyle(
        tester,
        find.text('다음'),
        size: 16,
        weight: FontWeight.w600,
        tracking: 0,
        color: Colors.white,
        height: 22 / 16,
      );
      await tester.tap(_next());
      await tester.pump();
      expect(calls.done, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'low viewport scroll exposes last option above stable footer $platform',
      (tester) async {
        final bottom = platform == TargetPlatform.iOS ? 34.0 : 24.0;
        await _pump(
          tester,
          platform: platform,
          width: 320,
          height: 480,
          bottom: bottom,
        );
        final footer = tester.getRect(_key('interest-footer'));
        final button = tester.getRect(_next());
        expect(button.bottom, closeTo(480 - bottom - 32, .2));
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        final viewport = tester.getRect(_key('interest-body'));
        final last = tester.getRect(_row(5));
        expect(last.top, greaterThanOrEqualTo(viewport.top - .2));
        expect(last.bottom, lessThanOrEqualTo(viewport.bottom + .2));
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        expect(position.pixels, closeTo(position.maxScrollExtent, .2));
        expect(viewport.bottom - last.bottom, closeTo(24, .2));
        expect(viewport.bottom, lessThanOrEqualTo(footer.top + .2));
        await tester.tap(_row(5));
        await tester.pump();
        expect(_selected(tester), [5]);
        expect(tester.getRect(_key('interest-footer')), footer);
        expect(tester.getRect(_next()), button);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'disposing a visible limit timer does not notify or call navigation later',
    (tester) async {
      final calls = await _pump(tester);
      await _select(tester, {0, 1, 2});
      await _tapRow(tester, 3);
      expect(_visibleLimit(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      expect(calls.done, 0);
      expect(calls.backs, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'public options and callback surface retain existing values and order',
    (tester) async {
      await _pump(tester);
      expect(mockInterestOptions, _labels);
      expect(
        tester
            .widgetList<InterestOptionTile>(find.byType(InterestOptionTile))
            .map((w) => w.label),
        _labels,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
