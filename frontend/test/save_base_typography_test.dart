import 'dart:ui' as ui;

import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://example.invalid/save-result';
const _filename = 'base-typography.png';
const _description = '앨범에서 선택하거나 스크린샷을 업로드해 주세요.';

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
  int calls = 0;
  String? label;
  Uint8List? photo;

  ContentItem content() => const ContentItem(
    id: 'base-typography',
    title: '고정된 저장 콘텐츠',
    summary: '기본 글자와 공통 상단 검사',
    category: catUncategorized,
    savedAt: '26.10.15',
    savedAtFull: '2026. 10. 15 오후 02:00',
    savedAtFullShort: '2026. 10. 15 02:00',
    tags: [],
    source: '웹사이트',
    originalUrl: _url,
    originalText: '',
  );
}

Future<_Saved> _open(
  WidgetTester tester, {
  required _Scene scene,
  required TargetPlatform platform,
  required double width,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  final saved = _Saved();
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
  for (final box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
    boxHeightStyle: ui.BoxHeightStyle.tight,
  )) {
    _inside(
      failures,
      '$text glyphs',
      box.toRect().shift(paragraph.localToGlobal(Offset.zero)),
      boundary,
    );
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

  final viewport = tester.getRect(find.byType(SingleChildScrollView));
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
    scene.result ? 80 : 32,
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
          );
          expect(tester.takeException(), isNull);
          expect(failures, isEmpty, reason: failures.join('\n'));
          await _interaction(tester, scene, saved, photo);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
