import 'dart:async';

import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://example.com/pasted';
const _longUrl =
    'https://example.com/a-very-long-single-line-path-to-check-horizontal-scrolling';
const _saved = ContentItem(
  id: 'paste-result',
  title: '붙여넣은 링크 저장 결과',
  summary: '붙여넣기 회귀 검사',
  category: catUncategorized,
  savedAt: '26.10.15',
  savedAtFull: '2026. 10. 15 오후 02:00',
  savedAtFullShort: '2026. 10. 15 02:00',
  tags: [],
  source: '테스트',
  originalUrl: _url,
  originalText: '',
);

Finder _paste() => find.widgetWithText(TextButton, '붙여넣기');
Finder _clear() => find.descendant(
  of: find.byType(TextField),
  matching: find.byType(IconButton),
);

void _metrics(WidgetTester tester, {double keyboard = 0}) {
  tester.view.padding = FakeViewPadding(
    top: 59,
    bottom: keyboard == 0 ? 34 : 0,
  );
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
}

Future<void> _open(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double scale = 1,
  Future<ContentItem> Function(String)? save,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  _metrics(tester);
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showContentSaveScreen(
              context: context,
              onAddLink: ({required url, category}) async =>
                  save == null ? _saved : await save(url),
              onAddScreenshot:
                  ({required bytes, required filename, category}) async =>
                      throw StateError('Unexpected photo save'),
            ),
            child: const Text('open save'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open save'));
  await tester.pumpAndSettle();
}

void _contained(
  Rect inner,
  Rect outer, {
  required String reason,
  double tolerance = 0.01,
}) {
  expect(
    inner.left,
    greaterThanOrEqualTo(outer.left - tolerance),
    reason: reason,
  );
  expect(
    inner.top,
    greaterThanOrEqualTo(outer.top - tolerance),
    reason: reason,
  );
  expect(
    inner.right,
    lessThanOrEqualTo(outer.right + tolerance),
    reason: reason,
  );
  expect(
    inner.bottom,
    lessThanOrEqualTo(outer.bottom + tolerance),
    reason: reason,
  );
}

void _pasteGeometry(WidgetTester tester, double scale) {
  final button = tester.getRect(_paste());
  final field = tester.getRect(find.byType(TextField));
  final paragraph = tester.renderObject<RenderParagraph>(find.text('붙여넣기'));
  final paragraphBounds = paragraph.localToGlobal(Offset.zero) & paragraph.size;
  final lineTops = <int>{};
  // Selection boxes include the half-letter-spacing overhang at a line edge.
  final selectionTolerance =
      ((paragraph.text as TextSpan).style!.letterSpacing ?? 0).abs() / 2 + 0.01;

  // Each character must have a real selection box inside both the paragraph
  // and the painted button. Framework overflow errors do not detect this clip.
  for (var offset = 0; offset < '붙여넣기'.length; offset++) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    );
    expect(boxes, isNotEmpty, reason: 'Character $offset must remain visible.');
    for (final box in boxes) {
      final rect = box.toRect().shift(paragraph.localToGlobal(Offset.zero));
      _contained(
        rect,
        paragraphBounds,
        reason: 'Paste text clips its paragraph.',
        tolerance: selectionTolerance,
      );
      _contained(
        rect,
        button,
        reason: 'Paste text clips its button.',
        tolerance: selectionTolerance,
      );
      lineTops.add((rect.top * 100).round());
    }
  }
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(lineTops.length, lessThanOrEqualTo(2));
  expect((paragraph.text as TextSpan).style!.fontSize, 14);
  expect(paragraph.textScaler.scale(14), closeTo(14 * scale, 0.01));
  expect(button.width, closeTo(64, 0.01));
  expect(button.left - field.right, closeTo(8, 0.01));
  expect(button.height, greaterThanOrEqualTo(44));
  expect(field.height, closeTo(button.height, 0.01));
  expect(field.top, closeTo(button.top, 0.01));
  expect(field.bottom, closeTo(button.bottom, 0.01));
  final container = InputDecorator.containerOf(
    tester.element(find.byType(EditableText)),
  )!;
  final fill = container.localToGlobal(Offset.zero) & container.size;
  expect(fill.height, closeTo(field.height, 0.01));
  expect(fill.top, closeTo(field.top, 0.01));
  expect(fill.bottom, closeTo(field.bottom, 0.01));
  expect(paragraphBounds.center.dy, closeTo(button.center.dy, 0.01));
  if (scale == 1) expect(button.height, closeTo(44, 0.01));

  final editable = tester.widget<EditableText>(find.byType(EditableText));
  expect(editable.maxLines, 1);
  expect(editable.style.fontSize, 14);
  final render = tester
      .state<EditableTextState>(find.byType(EditableText))
      .renderEditable;
  expect(render.textScaler.scale(14), closeTo(14 * scale, 0.01));
  final editableBounds = render.localToGlobal(Offset.zero) & render.size;
  final hasClear = editable.controller.text.isNotEmpty;
  final trailingInset = hasClear ? 52.0 : 4.0;
  expect(editableBounds.left - field.left, closeTo(12, 0.01));
  expect(field.right - editableBounds.right, closeTo(trailingInset, 0.01));
  expect(
    editableBounds.width,
    closeTo(field.width - 12 - trailingInset, 0.01),
    reason: 'The original URL viewport must retain its clear-control space.',
  );
  _contained(
    editableBounds,
    field,
    reason: 'The single URL line must fit its input field.',
  );
  expect(editableBounds.center.dy, closeTo(field.center.dy, 0.01));
}

void _clipboard(
  WidgetTester tester,
  Future<Object?> Function(MethodCall) handler,
) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) => call.method == 'Clipboard.getData'
        ? handler(call)
        : Future<Object?>.value(),
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

Future<void> _type(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField), value);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _pasteTypographyModel(
  WidgetTester tester, {
  required TextButton productButton,
  required ThemeData theme,
  required double scale,
  double? inheritedHeight,
  bool withoutPadding = false,
  double? fixedHeight,
}) async {
  final modelTextStyle = productButton.style!.textStyle!
      .resolve({})!
      .copyWith(fontFamily: 'Pretendard', height: inheritedHeight);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 64,
            height: fixedHeight,
            child: TextButton(
              onPressed: productButton.onPressed,
              style: productButton.style!.copyWith(
                textStyle: WidgetStatePropertyAll(modelTextStyle),
                padding: withoutPadding
                    ? const WidgetStatePropertyAll(EdgeInsets.zero)
                    : productButton.style!.padding,
              ),
              child: productButton.child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Rect> _glyphRects(RenderParagraph paragraph) => paragraph
    .getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 4))
    .map((box) => box.toRect().shift(paragraph.localToGlobal(Offset.zero)))
    .toList();

void _typographyBounds(WidgetTester tester, double scale) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text('붙여넣기'));
  final style = (paragraph.text as TextSpan).style!;
  expect(style.fontFamily, 'Pretendard');
  expect(style.fontSize, 14);
  expect(style.fontWeight, FontWeight.w500);
  expect(style.letterSpacing, -0.35);
  expect(paragraph.textScaler.scale(14), closeTo(14 * scale, 0.01));
  expect(paragraph.maxLines, 2);
  expect(paragraph.didExceedMaxLines, isFalse);
  final button = tester.getRect(_paste());
  expect(button.width, 64);
  expect(button.height, greaterThanOrEqualTo(44));
  if (scale == 1) expect(button.height, 44);
  final lines = _glyphRects(paragraph);
  expect(lines.length, lessThanOrEqualTo(2));
  for (var offset = 0; offset < 4; offset++) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    );
    expect(boxes, isNotEmpty);
    for (final box in boxes) {
      _contained(
        box.toRect().shift(paragraph.localToGlobal(Offset.zero)),
        button,
        reason: 'Every real Pretendard character must fit the product button.',
        tolerance: style.letterSpacing!.abs() / 2 + 0.01,
      );
    }
  }
  final paragraphBounds = paragraph.localToGlobal(Offset.zero) & paragraph.size;
  expect(paragraphBounds.center.dy, closeTo(button.center.dy, 0.01));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'paste row shows every glyph $platform width $width scale $scale',
          (tester) async {
            var clipboardReads = 0;
            _clipboard(tester, (call) async {
              expect(call.arguments, Clipboard.kTextPlain);
              clipboardReads++;
              return {'text': '  ${clipboardReads == 1 ? _url : _longUrl}  '};
            });
            await _open(tester, platform: platform, width: width, scale: scale);
            _pasteGeometry(tester, scale);
            final controller = tester
                .widget<TextField>(find.byType(TextField))
                .controller!;
            for (final bottomEdge in [false, true]) {
              final button = tester.getRect(_paste());
              await tester.tapAt(
                bottomEdge
                    ? Offset(button.center.dx, button.bottom - 1)
                    : button.center,
              );
              await tester.pump(const Duration(milliseconds: 400));
              await tester.pumpAndSettle();
              expect(clipboardReads, bottomEdge ? 2 : 1);
              expect(controller.text, bottomEdge ? _longUrl : _url);
              expect(
                tester.widget<TextField>(find.byType(TextField)).controller,
                same(controller),
              );
              _pasteGeometry(tester, scale);
            }
            await _type(tester, _longUrl);
            _pasteGeometry(tester, scale);
            final field = tester.getRect(find.byType(TextField));
            final clear = tester.getRect(_clear());
            expect(clear.center.dy, closeTo(field.center.dy, 0.01));
            expect(clear.width, closeTo(48, 0.01));
            expect(clear.height, greaterThanOrEqualTo(44));
            final clearIcon = tester.getRect(
              find.descendant(of: _clear(), matching: find.byType(SvgPicture)),
            );
            expect(clearIcon.size, const Size(18, 18));
            expect(clearIcon.center.dy, closeTo(field.center.dy, 0.01));
            _contained(
              clearIcon,
              clear,
              reason: 'The clear icon must fit its touch area.',
            );
            _contained(
              clear,
              field,
              reason: 'Clear control must fit the field.',
            );
            final render = tester
                .state<EditableTextState>(find.byType(EditableText))
                .renderEditable;
            final editableBounds =
                render.localToGlobal(Offset.zero) & render.size;
            expect(editableBounds.center.dy, closeTo(field.center.dy, 0.01));
            expect(
              (render.offset as ScrollPosition).maxScrollExtent,
              greaterThan(0),
            );
            expect(render.offset.pixels, greaterThan(0));
            final caret = render
                .getLocalRectForCaret(TextPosition(offset: _longUrl.length))
                .shift(render.localToGlobal(Offset.zero));
            _contained(caret, field, reason: 'The current URL caret must fit.');
            final validation = tester.getRect(find.byType(ValidationMessage));
            expect(validation.top - field.bottom, closeTo(5, 0.01));
            await tester.tapAt(Offset(clear.center.dx, clear.bottom - 1));
            await tester.pumpAndSettle();
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              isEmpty,
            );
            expect(find.byType(ValidationMessage), findsNothing);
            expect(_clear(), findsNothing);
            _pasteGeometry(tester, scale);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('paste label explicitly allows at most two centered lines', (
    tester,
  ) async {
    await _open(tester);
    final text = tester.widget<Text>(find.text('붙여넣기'));
    expect(text.maxLines, 2);
    expect(text.textAlign, TextAlign.center);
  });

  // The real dialog matrix above preserves the production font policy, whose
  // button style has no explicit family and uses the test fallback font. These
  // separate models explicitly select the loaded font to verify real metrics.
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'real Pretendard paste model $platform width $width scale $scale',
          (tester) async {
            await _open(tester, platform: platform, width: width, scale: scale);
            final button = tester.widget<TextButton>(_paste());
            final theme = Theme.of(tester.element(_paste()));
            await _pasteTypographyModel(
              tester,
              productButton: button,
              theme: theme,
              scale: scale,
            );
            _typographyBounds(tester, scale);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('paste contains actual glyph bounds with a short inherited line', (
    tester,
  ) async {
    const inheritedHeight = 1.18;
    await _open(tester, scale: 2);
    final button = tester.widget<TextButton>(_paste());
    final theme = Theme.of(tester.element(_paste()));

    // The production button inherits no explicit font family. This isolated
    // metric model uses a real loaded font and a short inherited line height;
    // it does not change the product's font policy. The negative control
    // differs only by removing the real product button's content padding.
    await _pasteTypographyModel(
      tester,
      productButton: button,
      theme: theme,
      scale: 2,
      inheritedHeight: inheritedHeight,
    );
    final actual = tester.renderObject<RenderParagraph>(find.text('붙여넣기'));
    expect((actual.text as TextSpan).style!.height, inheritedHeight);
    expect((actual.text as TextSpan).style!.fontFamily, 'Pretendard');
    expect((actual.text as TextSpan).style!.fontSize, 14);
    expect(actual.textScaler.scale(14), 28);
    final actualBounds = tester.getRect(_paste());
    final actualGlyphRects = _glyphRects(actual);
    expect(actualGlyphRects.length, 2);
    for (final rect in actualGlyphRects) {
      _contained(
        rect,
        actualBounds,
        reason:
            'The inherited line must leave actual glyphs inside the button.',
      );
    }

    await _pasteTypographyModel(
      tester,
      productButton: button,
      theme: theme,
      scale: 2,
      inheritedHeight: inheritedHeight,
      withoutPadding: true,
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.text('붙여넣기'));
    expect((paragraph.text as TextSpan).style!.height, inheritedHeight);
    expect((paragraph.text as TextSpan).style!.fontFamily, 'Pretendard');
    final bounds = tester.getRect(_paste());
    final controlGlyphRects = _glyphRects(paragraph);
    expect(controlGlyphRects.length, 2);
    expect(
      controlGlyphRects.any((rect) {
        return rect.top < bounds.top - 0.01 ||
            rect.bottom > bounds.bottom + 0.01;
      }),
      isTrue,
      reason: 'The control must reproduce a real glyph/line-box mismatch.',
    );
    await _pasteTypographyModel(
      tester,
      productButton: button,
      theme: theme,
      scale: 2,
      withoutPadding: true,
      fixedHeight: 44,
    );
    final fixed = tester.renderObject<RenderParagraph>(find.text('붙여넣기'));
    final fixedBounds = tester.getRect(_paste());
    expect((fixed.text as TextSpan).style!.fontFamily, 'Pretendard');
    final fixedGlyphRects = _glyphRects(fixed);
    expect(
      fixedGlyphRects.any(
        (rect) =>
            rect.top < fixedBounds.top - 0.01 ||
            rect.bottom > fixedBounds.bottom + 0.01,
      ),
      isTrue,
      reason:
          'The former fixed 44px geometry must reproduce actual-font clipping.',
    );
    debugPrint(
      'PASTE_METRIC_PROBE actualFont=Pretendard shortHeight=$inheritedHeight '
      'currentFits=true zeroPaddingOverhang=true fixed44Overhang=true '
      'fixedButton=$fixedBounds fixedGlyphs=$fixedGlyphRects',
    );
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (name: 'valid', text: _url, valid: true, expected: _url),
    (name: 'trimmed', text: '  $_url  ', valid: true, expected: _url),
    (name: 'invalid', text: 'not a URL', valid: false, expected: 'not a URL'),
  ]) {
    testWidgets('paste ${scenario.name} text retains validation policy', (
      tester,
    ) async {
      var requests = 0;
      _clipboard(tester, (call) async {
        requests++;
        expect(call.arguments, Clipboard.kTextPlain);
        return {'text': scenario.text};
      });
      await _open(tester);
      await tester.tap(_paste());
      await tester.pump(const Duration(milliseconds: 400));
      expect(requests, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        scenario.expected,
      );
      expect(
        tester.widget<ValidationMessage>(find.byType(ValidationMessage)).valid,
        scenario.valid,
      );
      expect(
        tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).enabled,
        scenario.valid,
      );
    });
  }

  for (final value in ['', '   ', null]) {
    testWidgets('empty clipboard $value preserves existing draft', (
      tester,
    ) async {
      _clipboard(tester, (_) async => value == null ? null : {'text': value});
      await _open(tester);
      await _type(tester, _url);
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      await tester.tap(_paste());
      await tester.pumpAndSettle();
      expect(controller.text, _url);
      expect(
        tester.widget<ValidationMessage>(find.byType(ValidationMessage)).valid,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('late clipboard after close cannot update a disposed sheet', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    _clipboard(tester, (_) => pending.future);
    await _open(tester);
    await tester.tap(_paste());
    await tester.pump();
    Navigator.of(tester.element(find.byType(AddContentSheet))).pop();
    await tester.pumpAndSettle();
    pending.complete({'text': _url});
    await tester.pumpAndSettle();
    expect(find.byType(AddContentSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late clipboard after success cannot replace submitted input', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    _clipboard(tester, (_) => pending.future);
    final submitted = <String>[];
    await _open(
      tester,
      save: (url) async {
        submitted.add(url);
        return _saved;
      },
    );
    await _type(tester, _url);
    await tester.tap(_paste());
    await tester.pump();
    await tester.tap(find.byType(SaveFlowButton));
    await tester.pumpAndSettle();
    pending.complete({'text': 'https://example.com/late'});
    await tester.pumpAndSettle();
    expect(submitted, [_url]);
    expect(
      tester
          .widget<SavedContentConfirmation>(
            find.byType(SavedContentConfirmation),
          )
          .originalUrl,
      _url,
    );
    expect(find.text('https://example.com/late'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard and width changes preserve focused URL controller', (
    tester,
  ) async {
    await _open(tester, scale: 2);
    await _type(tester, _longUrl);
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    final selection = controller.selection;
    final focus = tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode;
    final sheet = tester.state(find.byType(AddContentSheet));
    expect(focus.hasFocus, isTrue);
    _metrics(tester, keyboard: 300);
    tester.view.physicalSize = const Size(320, 812);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(AddContentSheet)), same(sheet));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller,
      same(controller),
    );
    expect(controller.text, _longUrl);
    expect(controller.selection, selection);
    expect(focus.hasFocus, isTrue);
    _pasteGeometry(tester, 2);
    _metrics(tester);
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(controller.text, _longUrl);
    expect(tester.takeException(), isNull);
  });
}
