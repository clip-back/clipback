import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/content/source_label.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://example.invalid/save-result';
const _filename = 'base-typography.png';
const _description = '앨범에서 선택하거나 스크린샷을 업로드해 주세요.';
const _shortTitle = '짧은 제목';
const _shortSource = '출처';
const _longTitle = '긴 저장 콘텐츠 제목이 아주 길어서 두 줄을 넘는 경우에도 말줄임이 유지되는지 확인해요';
const _longSource = '한 줄 너비를 넘는 아주 긴 콘텐츠 출처 이름';
const _longCategory = '매일 다시 확인하는 아주 긴 카테고리 이름이 끝까지 보존돼요';
const _processingCategoryMessage = '동영상 정보를 처리 중이에요. 분류는 나중에 반영될 수 있어요.';
const _categoryHint = '분류는 상세 화면에서 변경할 수 있어요.';

enum _Scene {
  empty,
  valid,
  invalid,
  photoEmpty,
  photoSelected,
  linkResult,
  photoResult;

  bool get photo =>
      this == photoEmpty || this == photoSelected || this == photoResult;
  bool get result => this == linkResult || this == photoResult;
  bool get enabled => this == valid || this == photoSelected || result;
}

class _Picker extends FilePicker {
  _Picker(this.bytes);
  final Uint8List bytes;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    int compressionQuality = 30,
  }) async => FilePickerResult([
    PlatformFile(name: _filename, size: bytes.length, bytes: bytes),
  ]);
}

class _Saved {
  _Saved({
    this.title = _shortTitle,
    this.source = _shortSource,
    this.category = catUncategorized,
    this.summaryStatus = 'not_requested',
  });

  final String title;
  final String source;
  final CategoryItem category;
  final String summaryStatus;
  int calls = 0;
  String? label;
  Uint8List? photo;

  ContentItem content() => ContentItem(
    id: 'base-typography',
    title: title,
    summary: '기본 글자와 공통 상단 검사',
    category: category,
    savedAt: '26.10.15',
    savedAtFull: '2026. 10. 15 오후 02:00',
    savedAtFullShort: '2026. 10. 15 02:00',
    tags: const [],
    source: source,
    originalUrl: _url,
    originalText: '',
    summaryStatus: summaryStatus,
  );
}

Future<_Saved> _open(
  WidgetTester tester, {
  required _Scene scene,
  required TargetPlatform platform,
  required double width,
  String title = _shortTitle,
  String source = _shortSource,
  CategoryItem category = catUncategorized,
  String summaryStatus = 'not_requested',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  final saved = _Saved(
    title: title,
    source: source,
    category: category,
    summaryStatus: summaryStatus,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
        // Match the production app's surrounding text theme as well as its
        // family setting; an explicit label must survive that inheritance.
        textTheme: ThemeData.fallback().textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showContentSaveScreen(
              context: context,
              onAddLink: ({required url, category}) async {
                saved.calls++;
                saved.label = url;
                return saved.content();
              },
              onAddScreenshot:
                  ({required bytes, required filename, category}) async {
                    saved.calls++;
                    saved.label = filename;
                    saved.photo = bytes;
                    return saved.content();
                  },
            ),
            child: const Text('open save'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open save'));
  await tester.pumpAndSettle();
  if (scene.photo) {
    await tester.tap(find.text('사진 첨부'));
    await tester.pumpAndSettle();
    if (scene != _Scene.photoEmpty) {
      await tester.tap(find.text('사진 선택'));
      await tester.pumpAndSettle();
    }
  } else if (scene != _Scene.empty) {
    await tester.enterText(
      find.byType(TextField),
      scene == _Scene.invalid ? 'invalid-link' : _url,
    );
    await tester.pump(const Duration(milliseconds: 400));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }
  if (scene.result) {
    await tester.tap(find.byType(SaveFlowButton));
    await tester.pumpAndSettle();
    expect(saved.calls, 1);
    expect(find.byType(SavedContentConfirmation), findsOneWidget);
  }
  return saved;
}

class _Style {
  const _Style(this.size, this.weight, this.spacing, this.color, {this.height});
  final double size;
  final FontWeight weight;
  final double spacing;
  final Color color;
  final double? height;
}

void _same(
  List<String> failures,
  String role,
  Object? actual,
  Object? expected,
) {
  if (actual != expected) failures.add('$role: $actual instead of $expected');
}

void _near(List<String> failures, String role, double actual, double expected) {
  if ((actual - expected).abs() > 0.01) {
    failures.add('$role: $actual instead of $expected');
  }
}

void _inside(List<String> failures, String role, Rect inner, Rect outer) {
  const tolerance = 0.2;
  if (inner.left < outer.left - tolerance ||
      inner.top < outer.top - tolerance ||
      inner.right > outer.right + tolerance ||
      inner.bottom > outer.bottom + tolerance) {
    failures.add('$role: $inner outside $outer');
  }
}

void _style(
  List<String> failures,
  String role,
  TextStyle actual,
  _Style expected,
) {
  _same(failures, '$role family', actual.fontFamily, 'Pretendard');
  _same(failures, '$role size', actual.fontSize, expected.size);
  _same(failures, '$role weight', actual.fontWeight, expected.weight);
  _same(failures, '$role spacing', actual.letterSpacing, expected.spacing);
  _same(failures, '$role color', actual.color, expected.color);
  if (expected.height != null) {
    _same(failures, '$role line height', actual.height, expected.height);
  }
}

void _text(
  WidgetTester tester,
  List<String> failures,
  String text,
  _Style expected, {
  required Rect boundary,
  bool localAutoHeight = true,
  bool respectEllipsisClip = false,
  bool checkSelectionBounds = true,
}) {
  final finder = find.text(text);
  expect(finder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final style = (paragraph.text as TextSpan).style!;
  _style(failures, text, style, expected);
  _near(failures, '$text actual scale', paragraph.textScaler.scale(1), 1);
  if (expected.height == null && localAutoHeight) {
    _same(
      failures,
      '$text retains AUTO local line height',
      tester.widget<Text>(finder).style?.height,
      null,
    );
  }
  _inside(failures, '$text paragraph', tester.getRect(finder), boundary);
  // A selection box is not the painted glyph boundary. Category roles use
  // their actual paragraph/row/ellipsis clip for containment instead.
  if (!checkSelectionBounds) return;
  for (final box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
    boxHeightStyle: ui.BoxHeightStyle.tight,
  )) {
    final raw = box.toRect().shift(paragraph.localToGlobal(Offset.zero));
    // Ellipsis paints inside the paragraph's own clip. Selection boxes can
    // include a fraction of font overhang, which is not itself a paint clip.
    final painted =
        respectEllipsisClip &&
            paragraph.didExceedMaxLines &&
            paragraph.overflow == TextOverflow.ellipsis
        ? raw.intersect(tester.getRect(finder))
        : raw;
    if (painted.isEmpty) continue;
    _inside(failures, '$text glyphs', painted, boundary);
  }
}

Finder _tab(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first;

void _tabs(WidgetTester tester, List<String> failures, {required bool photo}) {
  for (final label in ['링크 첨부', '사진 첨부']) {
    final active = (label == '사진 첨부') == photo;
    final bounds = tester.getRect(_tab(label));
    _near(failures, '$label height', bounds.height, 56);
    _text(
      tester,
      failures,
      label,
      _Style(
        16,
        active ? FontWeight.w600 : FontWeight.w500,
        -0.4,
        active ? AppColors.text : AppColors.subtler,
      ),
      boundary: bounds,
    );
    _near(
      failures,
      '$label horizontal center',
      tester.getCenter(find.text(label)).dx,
      bounds.center.dx,
    );
    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;
    _same(
      failures,
      '$label underline color',
      border.bottom.color,
      active ? AppColors.text : AppColors.subtler,
    );
    _same(
      failures,
      '$label underline width',
      border.bottom.width,
      active ? 2.0 : 1.0,
    );
  }
}

void _contracts(
  WidgetTester tester,
  List<String> failures, {
  required _Scene scene,
  required TargetPlatform platform,
  required double width,
  required _Saved saved,
}) {
  final top = tester.getRect(find.byType(SaveContentTopBar));
  final close = find.descendant(
    of: find.byType(SaveContentTopBar),
    matching: find.byType(SvgIconButton),
  );
  final closeRect = tester.getRect(close);
  final closeWidget = tester.widget<SvgIconButton>(close);
  _near(
    failures,
    'top safe area',
    top.top,
    platform == TargetPlatform.iOS ? 59 : 24,
  );
  _near(failures, 'top height', top.height, 64);
  _near(failures, 'close left', closeRect.left, 16);
  _near(failures, 'close hit width', closeRect.width, 24);
  _near(failures, 'close hit height', closeRect.height, 24);
  _same(failures, 'close icon size', closeWidget.size, 24.0);
  _near(failures, 'close center', closeRect.center.dy, top.center.dy);
  _text(
    tester,
    failures,
    '콘텐츠 저장하기',
    const _Style(18, FontWeight.w600, -0.45, Colors.black),
    boundary: top,
  );
  _near(
    failures,
    'title gap',
    tester.getRect(find.text('콘텐츠 저장하기')).left - closeRect.right,
    8,
  );
  _near(
    failures,
    'title vertical center',
    tester.getCenter(find.text('콘텐츠 저장하기')).dy,
    top.center.dy,
  );
  _tabs(tester, failures, photo: scene.photo);

  final body = find.byType(SingleChildScrollView);
  final viewport = tester.getRect(body);
  final scrollView = tester.widget<SingleChildScrollView>(body);
  _near(
    failures,
    'body viewport begins at tab bottom',
    viewport.top,
    tester.getRect(_tab('링크 첨부')).bottom,
  );
  _same(
    failures,
    'body padding',
    scrollView.padding,
    const EdgeInsets.fromLTRB(16, 32, 16, 24),
  );
  _near(
    failures,
    'body initial scroll offset',
    scrollView.controller!.offset,
    0,
  );
  final inputTitle = scene.photo ? '저장할 사진' : '저장할 링크';
  _text(
    tester,
    failures,
    inputTitle,
    const _Style(16, FontWeight.w600, -0.4, Colors.black),
    boundary: viewport,
  );
  _near(failures, 'body left', tester.getRect(find.text(inputTitle)).left, 16);
  _near(
    failures,
    'body top gap',
    tester.getRect(find.text(inputTitle)).top - viewport.top,
    32,
  );

  if (!scene.photo && !scene.result) {
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    _style(
      failures,
      'URL',
      editable.style,
      const _Style(14, FontWeight.w500, -0.35, AppColors.text),
    );
    final field = tester.getRect(find.byType(TextField));
    final paste = tester.getRect(find.widgetWithText(TextButton, '붙여넣기'));
    _near(failures, 'URL height', field.height, 44);
    _near(failures, 'paste height', paste.height, 44);
    _near(failures, 'paste width', paste.width, 64);
    _near(failures, 'paste gap', paste.left - field.right, 8);
    _near(
      failures,
      'URL vertical center',
      tester.getCenter(find.byType(EditableText)).dy,
      field.center.dy,
    );
    _same(failures, 'URL max lines', editable.maxLines, 1);
    if (scene == _Scene.empty) {
      _text(
        tester,
        failures,
        'https://',
        const _Style(14, FontWeight.w500, -0.35, AppColors.subtler),
        boundary: field,
        // InputDecorator builds this Text and resolves its own inherited
        // line height; only the product's explicit hint style owns AUTO.
        localAutoHeight: false,
      );
      _same(
        failures,
        'hint retains AUTO local line height',
        tester
            .widget<TextField>(find.byType(TextField))
            .decoration
            ?.hintStyle
            ?.height,
        null,
      );
    }
  } else if (scene.result) {
    final label = scene.photo ? _filename : _url;
    final labelContainer = tester.getRect(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );
    _near(failures, 'result label height', labelContainer.height, 44);
    _text(
      tester,
      failures,
      label,
      const _Style(14, FontWeight.w500, -0.35, AppColors.text),
      boundary: labelContainer,
    );
    _preview(tester, failures, saved: saved, longText: false);
    _category(tester, failures, saved: saved);
  }
  if (scene == _Scene.photoEmpty) {
    final prompt = tester.getRect(find.byType(PhotoEmptyPrompt));
    _near(failures, 'photo prompt height', prompt.height, 89);
    _text(
      tester,
      failures,
      '사진 선택',
      const _Style(15, FontWeight.w600, -0.375, AppColors.subtle),
      boundary: prompt,
    );
    _text(
      tester,
      failures,
      _description,
      const _Style(14, FontWeight.w500, -0.35, AppColors.subSubtle),
      boundary: prompt,
    );
    final description = tester.widget<Text>(find.text(_description));
    _same(failures, 'photo description max lines', description.maxLines, 1);
    _same(
      failures,
      'photo description ellipsis',
      description.overflow,
      TextOverflow.ellipsis,
    );
  }
  final hasValidation = !scene.photo && scene != _Scene.empty;
  _same(
    failures,
    'link-only validation',
    find.byType(ValidationMessage).evaluate().isNotEmpty,
    hasValidation,
  );
  if (hasValidation) {
    final label = scene == _Scene.invalid ? '유효하지 않은 링크예요.' : '유효한 링크예요!';
    final validation = tester.getRect(find.byType(ValidationMessage));
    _text(
      tester,
      failures,
      label,
      const _Style(14, FontWeight.w500, -0.35, AppColors.subSubtle),
      boundary: validation,
    );
    final preceding = scene.result
        ? tester.getRect(
            find
                .ancestor(of: find.text(_url), matching: find.byType(Container))
                .first,
          )
        : tester.getRect(find.byType(TextField));
    _near(
      failures,
      'validation preceding gap',
      validation.top - preceding.bottom,
      5,
    );
  }
  final button = tester.getRect(find.byType(SaveFlowButton));
  final label = scene.result ? '닫기' : '허투루에 저장하기';
  _near(failures, 'CTA height', button.height, 56);
  _near(failures, 'CTA left', button.left, 16);
  _near(failures, 'CTA right', button.right, width - 16);
  _near(
    failures,
    'CTA OS clearance',
    button.bottom,
    812 - 32 - (platform == TargetPlatform.iOS ? 34 : 0),
  );
  _text(
    tester,
    failures,
    label,
    _Style(
      16,
      FontWeight.w600,
      0,
      scene.enabled ? AppColors.main : Colors.white,
      height: 22 / 16,
    ),
    boundary: button,
  );
  _near(
    failures,
    'CTA label x center',
    tester.getCenter(find.text(label)).dx,
    button.center.dx,
  );
  _near(
    failures,
    'CTA label y center',
    tester.getCenter(find.text(label)).dy,
    button.center.dy,
  );
  _near(
    failures,
    'CTA label line height',
    tester.getSize(find.text(label)).height,
    22,
  );
}

void _preview(
  WidgetTester tester,
  List<String> failures, {
  required _Saved saved,
  required bool longText,
  int? expectedTitleLines,
}) {
  final result = find.byType(SavedContentConfirmation);
  final image = find.descendant(of: result, matching: find.byType(Image));
  expect(image, findsOneWidget);
  final cardFinder = find
      .ancestor(of: image, matching: find.byType(Container))
      .first;
  final card = tester.getRect(cardFinder);
  final thumbnail = tester.getRect(image);
  final inner = card.deflate(8);
  final titleFinder = find.text(saved.title);
  final sourceFinder = find.text(saved.source);
  final title = tester.getRect(titleFinder);
  final source = tester.getRect(sourceFinder);
  final text = title.expandToInclude(source);
  final textColumn = tester.getRect(
    find.ancestor(of: titleFinder, matching: find.byType(Column)).first,
  );
  final viewport = tester.getRect(find.byType(SingleChildScrollView));

  _text(
    tester,
    failures,
    '미리보기',
    const _Style(16, FontWeight.w600, -0.4, Colors.black),
    boundary: viewport,
  );
  _text(
    tester,
    failures,
    saved.title,
    const _Style(15, FontWeight.w500, -0.375, Colors.black, height: 1.6),
    boundary: inner,
    respectEllipsisClip: true,
  );
  _text(
    tester,
    failures,
    saved.source,
    const _Style(14, FontWeight.w400, -0.35, AppColors.subtle, height: 1.6),
    boundary: inner,
    respectEllipsisClip: true,
  );
  _near(
    failures,
    'preview heading left',
    tester.getRect(find.text('미리보기')).left,
    card.left,
  );
  _near(
    failures,
    'preview heading/card gap',
    card.top - tester.getRect(find.text('미리보기')).bottom,
    16,
  );
  _near(failures, 'preview width', card.width, viewport.width - 32);
  _near(failures, 'preview image width', thumbnail.width, 164);
  _near(failures, 'preview image height', thumbnail.height, 100);
  _near(failures, 'preview image left padding', thumbnail.left - card.left, 8);
  _near(failures, 'preview image/text gap', title.left - thumbnail.right, 16);
  _near(
    failures,
    'preview text right padding',
    card.right - textColumn.right,
    8,
  );
  _near(failures, 'preview source left', source.left, title.left);
  _near(failures, 'preview title/source gap', source.top - title.bottom, 14);
  _near(
    failures,
    'preview text natural height',
    text.height,
    title.height + 14 + source.height,
  );
  _near(failures, 'preview base card height', card.height, 116);
  _near(failures, 'preview image center', thumbnail.center.dy, card.center.dy);
  _near(failures, 'preview text center', text.center.dy, card.center.dy);
  _near(
    failures,
    'preview natural height',
    card.height,
    16 + math.max(100, text.height),
  );
  if (card.height < 116) {
    failures.add('preview is shorter than its 116px minimum');
  }
  _inside(failures, 'preview thumbnail', thumbnail, inner);
  _inside(failures, 'preview text block', text, inner);

  for (final entry in [
    (titleFinder, 2, 'title'),
    (sourceFinder, 1, 'source'),
  ]) {
    final paragraph = tester.renderObject<RenderParagraph>(entry.$1);
    final widget = tester.widget<Text>(entry.$1);
    _same(
      failures,
      'preview ${entry.$3} max lines',
      paragraph.maxLines,
      entry.$2,
    );
    _same(
      failures,
      'preview ${entry.$3} ellipsis',
      widget.overflow,
      TextOverflow.ellipsis,
    );
    _same(
      failures,
      'preview ${entry.$3} actual overflow',
      paragraph.didExceedMaxLines,
      longText,
    );
    final textLength = widget.data!.length;
    final lineTops = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: textLength),
          boxHeightStyle: ui.BoxHeightStyle.tight,
        )
        .map((box) => (box.top * 100).round())
        .toSet();
    _same(
      failures,
      'preview ${entry.$3} visible lines',
      lineTops.length,
      entry.$3 == 'title' ? expectedTitleLines ?? (longText ? entry.$2 : 1) : 1,
    );
  }
}

void _category(
  WidgetTester tester,
  List<String> failures, {
  required _Saved saved,
  String message = '아직 분류되지 않았어요.',
  bool longName = false,
}) {
  final result = find.byType(SavedContentConfirmation);
  final resultBounds = tester.getRect(result);
  final heading = find.text('카테고리');
  final status = find.text(message);
  final name = find.text(saved.category.name);
  expect(heading, findsOneWidget);
  expect(status, findsOneWidget);
  expect(name, findsOneWidget);
  final rowFinder = find
      .ancestor(of: name, matching: find.byType(Container))
      .first;
  final row = tester.getRect(rowFinder);
  final folderFinder = find.descendant(
    of: rowFinder,
    matching: find.byType(FolderGlyph),
  );
  expect(folderFinder, findsOneWidget);
  final folder = tester.getRect(folderFinder);
  final nameBounds = tester.getRect(name);
  final viewport = tester.getRect(find.byType(SingleChildScrollView));

  // These roles may be below the viewport at scroll zero. Their actual
  // parent/row bounds own clipping; the maximum-scroll check owns visibility.
  _text(
    tester,
    failures,
    '카테고리',
    const _Style(16, FontWeight.w600, -0.4, Colors.black),
    boundary: resultBounds,
    checkSelectionBounds: false,
  );
  _text(
    tester,
    failures,
    message,
    const _Style(14, FontWeight.w500, -0.35, AppColors.subtle),
    boundary: resultBounds,
    checkSelectionBounds: false,
  );
  _text(
    tester,
    failures,
    saved.category.name,
    const _Style(16, FontWeight.w500, 0, Colors.black, height: 22 / 16),
    boundary: row,
    respectEllipsisClip: true,
    checkSelectionBounds: false,
  );
  _near(failures, 'category row height', row.height, 55);
  _near(failures, 'category row left', row.left, viewport.left + 16);
  _near(failures, 'category row right', row.right, viewport.right - 16);
  _near(
    failures,
    'category heading left',
    tester.getRect(heading).left,
    row.left,
  );
  _near(
    failures,
    'category status left',
    tester.getRect(status).left,
    row.left,
  );
  _near(
    failures,
    'category heading/status gap',
    tester.getRect(status).top - tester.getRect(heading).bottom,
    8,
  );
  _near(
    failures,
    'category status/row gap',
    row.top - tester.getRect(status).bottom,
    16,
  );
  _near(failures, 'category folder width', folder.width, 28);
  _near(failures, 'category folder height', folder.height, 28);
  _near(failures, 'category left padding', folder.left - row.left, 16);
  _near(
    failures,
    'category folder/name gap',
    nameBounds.left - folder.right,
    8,
  );
  _near(failures, 'category right padding', row.right - nameBounds.right, 16);
  _near(failures, 'category folder center', folder.center.dy, row.center.dy);
  _near(failures, 'category name center', nameBounds.center.dy, row.center.dy);
  _inside(failures, 'category folder containment', folder, row);
  _inside(failures, 'category name containment', nameBounds, row);
  final glyph = tester.widget<FolderGlyph>(folderFinder);
  _same(failures, 'actual category color', glyph.color, saved.category.color);
  final paragraph = tester.renderObject<RenderParagraph>(name);
  _same(failures, 'category name max lines', paragraph.maxLines, 1);
  _same(
    failures,
    'category name ellipsis',
    paragraph.overflow,
    TextOverflow.ellipsis,
  );
  _same(
    failures,
    'category actual truncation',
    paragraph.didExceedMaxLines,
    longName,
  );
  _near(failures, 'category name line height', nameBounds.height, 22);
  _same(
    failures,
    'category source value unchanged',
    tester.widget<Text>(name).data,
    saved.category.name,
  );
  for (final other in [
    '아직 분류되지 않았어요.',
    '저장된 카테고리',
    _processingCategoryMessage,
  ]) {
    _same(
      failures,
      'category status $other',
      find.text(other).evaluate().length,
      other == message ? 1 : 0,
    );
  }
  expect(find.text('허투루가 자동으로 분류했어요!'), findsNothing);
  if (message == _processingCategoryMessage) {
    final text = tester.renderObject<RenderParagraph>(status);
    final lineTops = text
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: message.length),
        )
        .map((box) => (box.top * 100).round())
        .toSet();
    _same(
      failures,
      'processing message natural line count',
      lineTops.length,
      viewport.width == 320 ? 2 : 1,
    );
    _same(
      failures,
      'processing message max lines unchanged',
      text.maxLines,
      null,
    );
    _same(
      failures,
      'processing message overflow unchanged',
      text.overflow,
      TextOverflow.clip,
    );
  }
  final hint = tester.widget<Text>(find.text(_categoryHint));
  _same(
    failures,
    'existing detail hint style unchanged',
    hint.style,
    const TextStyle(color: AppColors.subtle, fontSize: 14),
  );
  _near(
    failures,
    'category existing detail hint gap',
    tester.getRect(find.text(_categoryHint)).top - row.bottom,
    8,
  );
}

Future<void> _categoryMaximumScroll(
  WidgetTester tester,
  List<String> failures,
) async {
  final scrollable = tester.widget<SingleChildScrollView>(
    find.byType(SingleChildScrollView),
  );
  final position = scrollable.controller!.position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
  final viewport = tester.getRect(find.byType(SingleChildScrollView));
  final hint = tester.getRect(find.text(_categoryHint));
  final heading = tester.getRect(find.text('카테고리'));
  _inside(failures, 'category heading at maximum scroll', heading, viewport);
  _inside(failures, 'existing detail hint at maximum scroll', hint, viewport);
  if (hint.bottom > viewport.bottom - 23.8) {
    failures.add('Last category hint must retain the 24px body bottom padding');
  }
  if (position.maxScrollExtent > 0) {
    _near(
      failures,
      'category maximum scroll bottom padding',
      viewport.bottom - hint.bottom,
      24,
    );
  }
  final button = tester.getRect(find.byType(SaveFlowButton));
  if (viewport.bottom > button.top + 0.2) {
    failures.add('Category viewport overlaps the footer button');
  }
}

Future<void> _interaction(
  WidgetTester tester,
  _Scene scene,
  _Saved saved,
  Uint8List photo,
) async {
  // Both equal-width tab regions are tappable. Completed results stay pinned.
  await tester.tap(_tab(scene.photo ? '링크 첨부' : '사진 첨부'));
  await tester.pumpAndSettle();
  if (!scene.result) {
    expect(
      find.byType(scene.photo ? LinkSaveBody : PhotoSaveBody),
      findsOneWidget,
    );
    await tester.tap(_tab(scene.photo ? '사진 첨부' : '링크 첨부'));
    await tester.pumpAndSettle();
  } else {
    expect(find.byType(SavedContentConfirmation), findsOneWidget);
    expect(saved.calls, 1);
    final failures = <String>[];
    _tabs(tester, failures, photo: scene.photo);
    expect(failures, isEmpty, reason: failures.join('\n'));
  }
  final button = tester.getRect(find.byType(SaveFlowButton));
  await tester.tapAt(Offset(button.center.dx, button.bottom - 2));
  await tester.pumpAndSettle();
  if (scene.result) {
    expect(find.byType(AddContentSheet), findsNothing);
    expect(saved.calls, 1);
    return;
  }
  if (scene.enabled) {
    expect(saved.calls, 1);
    expect(saved.label, scene.photo ? _filename : _url);
    if (scene.photo) expect(saved.photo, orderedEquals(photo));
    expect(find.byType(SavedContentConfirmation), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(AddContentSheet), findsNothing);
  } else {
    expect(saved.calls, 0);
    expect(find.byType(AddContentSheet), findsOneWidget);
    final close = find.descendant(
      of: find.byType(SaveContentTopBar),
      matching: find.byType(SvgIconButton),
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(AddContentSheet), findsNothing);
  }
}

void _photoFrame(WidgetTester tester, List<String> failures) {
  final preview = find.byType(SelectedPhotoPreview);
  final container = find.descendant(
    of: preview,
    matching: find.byType(Container),
  );
  final clip = find.descendant(of: preview, matching: find.byType(ClipRect));
  final inner = find
      .ancestor(of: clip, matching: find.byType(DecoratedBox))
      .first;
  final builder = find.descendant(
    of: clip,
    matching: find.byType(LayoutBuilder),
  );
  final image = find.descendant(of: clip, matching: find.byType(Image));
  expect(container, findsOneWidget);
  expect(clip, findsOneWidget);
  expect(builder, findsOneWidget);
  expect(image, findsOneWidget);
  final outerBounds = tester.getRect(container);
  final innerBounds = tester.getRect(inner);
  final clipBounds = tester.getRect(clip);
  final imageBounds = tester.getRect(image);
  final viewport =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;

  _near(failures, 'photo outer width', outerBounds.width, viewport - 32);
  _near(failures, 'photo outer height', outerBounds.height, 437);
  _near(failures, 'photo outer left', outerBounds.left, 16);
  _near(failures, 'photo outer right', outerBounds.right, viewport - 16);
  _near(
    failures,
    'photo inner width',
    innerBounds.width,
    outerBounds.width - 32,
  );
  _near(failures, 'photo inner height', innerBounds.height, 405);
  _near(failures, 'photo left inset', innerBounds.left - outerBounds.left, 16);
  _near(failures, 'photo top inset', innerBounds.top - outerBounds.top, 16);
  _near(
    failures,
    'photo right inset',
    outerBounds.right - innerBounds.right,
    16,
  );
  _near(
    failures,
    'photo bottom inset',
    outerBounds.bottom - innerBounds.bottom,
    16,
  );
  _same(failures, 'photo clip bounds', clipBounds, innerBounds);
  _same(failures, 'photo layout bounds', tester.getRect(builder), innerBounds);
  _inside(failures, 'photo inner frame containment', innerBounds, outerBounds);
  _same(
    failures,
    'photo clip behavior',
    tester.widget<ClipRect>(clip).clipBehavior,
    Clip.hardEdge,
  );
  final stack = tester.widget<Stack>(
    find.descendant(of: builder, matching: find.byType(Stack)),
  );
  _same(failures, 'photo stack clip', stack.clipBehavior, Clip.hardEdge);

  final outer = tester.widget<Container>(container);
  final background = outer.decoration! as BoxDecoration;
  final outline = outer.foregroundDecoration as BoxDecoration? ?? background;
  _same(
    failures,
    'photo explicit padding',
    outer.padding,
    const EdgeInsets.all(16),
  );
  _same(failures, 'photo background', background.color, AppColors.surface);
  _same(
    failures,
    'photo outer radius',
    outline.borderRadius,
    BorderRadius.circular(8),
  );
  for (final entry in [
    ('outer', outline),
    ('inner', tester.widget<DecoratedBox>(inner).decoration as BoxDecoration),
  ]) {
    _same(
      failures,
      'photo ${entry.$1} border',
      entry.$2.border,
      Border.all(color: AppColors.subtler),
    );
  }

  // The existing enlarged image intentionally extends beyond the clip. Keep
  // its relative crop; containment applies to the clip, not the image itself.
  _near(failures, 'photo image left', imageBounds.left, clipBounds.left);
  _near(failures, 'photo image right', imageBounds.right, clipBounds.right);
  _near(
    failures,
    'photo crop top',
    imageBounds.top - clipBounds.top,
    -clipBounds.height * 0.4067,
  );
  _near(
    failures,
    'photo crop height',
    imageBounds.height,
    clipBounds.height * 1.6607,
  );
  _same(
    failures,
    'photo image fit',
    tester.widget<Image>(image).fit,
    BoxFit.fill,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List photo;
  setUpAll(() async {
    FilePickerIO.registerWith();
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    photo = (await rootBundle.load(
      'assets/figma/saved-photo-preview.png',
    )).buffer.asUint8List();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final memoryPhoto in [true, false]) {
        testWidgets(
          'photo frame geometry $platform width $width ${memoryPhoto ? 'memory' : 'asset fallback'}',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 812);
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  useMaterial3: true,
                  platform: platform,
                  fontFamily: 'Pretendard',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SelectedPhotoPreview(
                      photoBytes: memoryPhoto ? photo : null,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final failures = <String>[];
            _photoFrame(tester, failures);
            final image = tester.widget<Image>(
              find.descendant(
                of: find.byType(SelectedPhotoPreview),
                matching: find.byType(Image),
              ),
            );
            if (memoryPhoto) {
              expect(image.image, isA<MemoryImage>());
              expect((image.image as MemoryImage).bytes, orderedEquals(photo));
            } else {
              expect(image.image, isA<AssetImage>());
              expect(
                (image.image as AssetImage).assetName,
                'assets/figma/saved-photo-preview.png',
              );
            }
            expect(tester.takeException(), isNull);
            expect(failures, isEmpty, reason: failures.join('\n'));
          },
        );
      }
      for (final scene in _Scene.values) {
        testWidgets('base typography $platform width $width ${scene.name}', (
          tester,
        ) async {
          final previous = FilePicker.platform;
          FilePicker.platform = _Picker(photo);
          addTearDown(() => FilePicker.platform = previous);
          final saved = await _open(
            tester,
            scene: scene,
            platform: platform,
            width: width,
          );
          final failures = <String>[];
          _contracts(
            tester,
            failures,
            scene: scene,
            platform: platform,
            width: width,
            saved: saved,
          );
          expect(tester.takeException(), isNull);
          if (scene.result) await _categoryMaximumScroll(tester, failures);
          expect(failures, isEmpty, reason: failures.join('\n'));
          await _interaction(tester, scene, saved, photo);
          expect(tester.takeException(), isNull);
        });
      }
      for (final scene in [_Scene.linkResult, _Scene.photoResult]) {
        testWidgets(
          'preview two lines without ellipsis $platform width $width ${scene.name}',
          (tester) async {
            final previous = FilePicker.platform;
            FilePicker.platform = _Picker(photo);
            addTearDown(() => FilePicker.platform = previous);
            final saved = await _open(
              tester,
              scene: scene,
              platform: platform,
              width: width,
              title: width == 375
                  ? "'주술회전(呪術廻戦)' 초반 1~10권 감상회"
                  : '저장 결과 확인 제목 미리보기',
              source: scene.photo ? '사진' : 'Youtube',
            );
            final failures = <String>[];
            _preview(
              tester,
              failures,
              saved: saved,
              longText: false,
              expectedTitleLines: 2,
            );
            expect(tester.takeException(), isNull);
            expect(failures, isEmpty, reason: failures.join('\n'));
            await _interaction(tester, scene, saved, photo);
            expect(tester.takeException(), isNull);
          },
        );
        testWidgets('preview long text $platform width $width ${scene.name}', (
          tester,
        ) async {
          final previous = FilePicker.platform;
          FilePicker.platform = _Picker(photo);
          addTearDown(() => FilePicker.platform = previous);
          final saved = await _open(
            tester,
            scene: scene,
            platform: platform,
            width: width,
            title: _longTitle,
            source: _longSource,
          );
          final failures = <String>[];
          _preview(tester, failures, saved: saved, longText: true);
          _category(tester, failures, saved: saved);
          await _categoryMaximumScroll(tester, failures);
          expect(tester.takeException(), isNull);
          expect(failures, isEmpty, reason: failures.join('\n'));
          await _interaction(tester, scene, saved, photo);
          expect(tester.takeException(), isNull);
        });
        for (final variant in [
          (
            label: 'classified',
            category: catUncategorized.copyWith(name: '알아두기'),
            source: _shortSource,
            summaryStatus: 'not_requested',
            message: '저장된 카테고리',
            longName: false,
          ),
          (
            label: 'long classified',
            category: catUncategorized.copyWith(name: _longCategory),
            source: _shortSource,
            summaryStatus: 'not_requested',
            message: '저장된 카테고리',
            longName: true,
          ),
          (
            label: 'youtube queued',
            category: catUncategorized.copyWith(name: _longCategory),
            source: sourceLabel('youtube'),
            summaryStatus: 'queued',
            message: _processingCategoryMessage,
            longName: true,
          ),
          (
            label: 'youtube processing',
            category: catUncategorized,
            source: sourceLabel('youtube'),
            summaryStatus: 'processing',
            message: _processingCategoryMessage,
            longName: false,
          ),
        ]) {
          testWidgets(
            'category typography $platform width $width ${scene.name} ${variant.label}',
            (tester) async {
              final previous = FilePicker.platform;
              FilePicker.platform = _Picker(photo);
              addTearDown(() => FilePicker.platform = previous);
              final saved = await _open(
                tester,
                scene: scene,
                platform: platform,
                width: width,
                category: variant.category,
                source: variant.source,
                summaryStatus: variant.summaryStatus,
              );
              final failures = <String>[];
              _category(
                tester,
                failures,
                saved: saved,
                message: variant.message,
                longName: variant.longName,
              );
              await _categoryMaximumScroll(tester, failures);
              expect(tester.takeException(), isNull);
              expect(failures, isEmpty, reason: failures.join('\n'));
              await _interaction(tester, scene, saved, photo);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
