import 'dart:math' as math;

import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _title = '아주 긴 저장 콘텐츠 제목을 확대해도 두 줄까지 읽을 수 있어요';
const _source = '확대해도 한 줄인 긴 콘텐츠 출처';
const _promptBody = '앨범에서 선택하거나 스크린샷을 업로드해 주세요.';

const _content = ContentItem(
  id: 'scaled-result',
  title: _title,
  summary: '저장 결과 크기 검사용 콘텐츠',
  category: catUncategorized,
  savedAt: '26.10.15',
  savedAtFull: '2026. 10. 15 오후 02:00',
  savedAtFullShort: '2026. 10. 15 02:00',
  tags: [],
  source: _source,
  originalUrl: 'https://example.com/saved',
  originalText: '',
);

class _PhotoPicker extends FilePicker {
  _PhotoPicker(this.bytes);

  final Uint8List bytes;
  int calls = 0;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    calls++;
    return FilePickerResult([
      PlatformFile(
        name: 'expanded-photo.png',
        size: bytes.length,
        bytes: bytes,
      ),
    ]);
  }
}

Future<void> _render(
  WidgetTester tester, {
  required Widget child,
  required TargetPlatform platform,
  required double width,
  required double scale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  addTearDown(tester.view.reset);
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
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _contained(Rect content, Rect parent) {
  const tolerance = 0.01;
  expect(content.left, greaterThanOrEqualTo(parent.left - tolerance));
  expect(content.top, greaterThanOrEqualTo(parent.top - tolerance));
  expect(content.right, lessThanOrEqualTo(parent.right + tolerance));
  expect(content.bottom, lessThanOrEqualTo(parent.bottom + tolerance));
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

void _unchangedFont(
  WidgetTester tester,
  String text, {
  required double fontSize,
  required double scale,
}) {
  final paragraph = _paragraph(tester, text);
  expect((paragraph.text as TextSpan).style!.fontSize, fontSize);
  expect(
    paragraph.textScaler.scale(fontSize),
    closeTo(fontSize * scale, 0.001),
  );
}

Finder _resultRole(String role, Finder fallback) {
  final keyed = find.byKey(ValueKey<String>(role));
  return keyed.evaluate().isEmpty ? fallback : keyed;
}

Finder _previewCard() => _resultRole(
  'save-result-preview-card',
  find.descendant(
    of: find.byType(SavedContentConfirmation),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.padding == const EdgeInsets.all(8) &&
          widget.child is Row,
    ),
  ),
);

Finder _previewImage() {
  final role = _resultRole(
    'save-result-preview-image',
    find.descendant(of: _previewCard(), matching: find.byType(Image)),
  );
  return role.evaluate().single.widget is Image
      ? role
      : find.descendant(of: role, matching: find.byType(Image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List photoBytes;
  setUpAll(() async {
    FilePickerIO.registerWith();
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    photoBytes = (await rootBundle.load(
      'assets/figma/saved-photo-preview.png',
    )).buffer.asUint8List();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('real save dialog expands and remains usable at $platform 2x', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.reset);
      final originalPicker = FilePicker.platform;
      final picker = _PhotoPicker(photoBytes);
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = originalPicker);
      final uploads = <(String, Uint8List)>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            platform: platform,
            fontFamily: 'Pretendard',
            textTheme: ThemeData.fallback().textTheme.apply(
              bodyColor: AppColors.text,
              displayColor: AppColors.text,
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showContentSaveScreen(
                  context: context,
                  onAddLink: ({required url, category}) async =>
                      throw StateError('unexpected link save'),
                  onAddScreenshot:
                      ({required bytes, required filename, category}) async {
                        uploads.add((filename, bytes));
                        return _content;
                      },
                ),
                child: const Text('저장 화면 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('저장 화면 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 첨부'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final prompt = tester.getRect(find.byType(PhotoEmptyPrompt));
      final promptText = tester
          .getRect(find.text('사진 선택'))
          .expandToInclude(tester.getRect(find.text(_promptBody)));
      _contained(promptText, prompt);
      expect(prompt.height, greaterThanOrEqualTo(promptText.height));
      expect(prompt.height, greaterThanOrEqualTo(89));
      if (promptText.height > 89) expect(prompt.height, greaterThan(89));
      _unchangedFont(tester, '사진 선택', fontSize: 15, scale: 2);
      _unchangedFont(tester, _promptBody, fontSize: 14, scale: 2);

      await tester.tap(find.text('사진 선택'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectedPhotoPreview), findsOneWidget);
      expect(picker.calls, 1);
      await tester.tap(find.text('허투루에 저장하기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(uploads, hasLength(1));
      expect(uploads.single.$1, 'expanded-photo.png');
      expect(uploads.single.$2, orderedEquals(photoBytes));
      expect(find.text('저장할 사진'), findsOneWidget);
      expect(find.byType(ValidationMessage), findsNothing);
      expect(
        tester.widget<Text>(find.text('사진 첨부')).style!.fontWeight,
        FontWeight.w600,
      );
      await tester.tap(find.text('링크 첨부'));
      await tester.pumpAndSettle();
      expect(find.byType(SavedContentConfirmation), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('사진 첨부')).style!.fontWeight,
        FontWeight.w600,
      );
      await tester.ensureVisible(find.text(_source));
      await tester.pumpAndSettle();
      final card = tester.getRect(_previewCard());
      _contained(tester.getRect(find.text(_title)), card.deflate(8));
      _contained(tester.getRect(find.text(_source)), card.deflate(8));
      expect(card.height, greaterThan(116));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.text('분류는 상세 화면에서 변경할 수 있어요.').hitTestable(), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(AddContentSheet), findsNothing);
      expect(uploads, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'photo selection prompt fits $platform width $width scale $scale',
          (tester) async {
            await _render(
              tester,
              child: const PhotoEmptyPrompt(),
              platform: platform,
              width: width,
              scale: scale,
            );
            expect(tester.takeException(), isNull);
            final prompt = tester.getRect(find.byType(PhotoEmptyPrompt));
            final title = tester.getRect(find.text('사진 선택'));
            final body = tester.getRect(find.text(_promptBody));
            final icon = tester.getRect(find.byType(SvgPicture));
            expect(prompt.height, greaterThanOrEqualTo(89));
            if (scale == 1) expect(prompt.height, 89);
            _contained(title, prompt);
            _contained(body, prompt);
            _contained(icon, prompt);
            expect(icon.size, const Size(40, 40));
            expect(icon.left - prompt.left, 16);
            expect(title.left - icon.right, 8);
            expect(body.top - title.bottom, closeTo(4, 0.01));
            expect(
              title.expandToInclude(body).center.dy,
              closeTo(prompt.center.dy, 0.01),
            );
            expect(icon.center.dy, closeTo(prompt.center.dy, 0.01));
            expect(_paragraph(tester, _promptBody).maxLines, 1);
            expect(
              _paragraph(tester, _promptBody).overflow,
              TextOverflow.ellipsis,
            );
            _unchangedFont(tester, '사진 선택', fontSize: 15, scale: scale);
            _unchangedFont(tester, _promptBody, fontSize: 14, scale: scale);
            if (title.expandToInclude(body).height > 89) {
              expect(prompt.height, greaterThan(89));
            }
          },
        );

        for (final photo in [false, true]) {
          testWidgets(
            '${photo ? 'photo' : 'link'} preview fits $platform width $width scale $scale',
            (tester) async {
              await _render(
                tester,
                child: SavedContentConfirmation(
                  content: _content,
                  originalUrl: photo
                      ? '사진 파일 이름이 길어도 기존처럼 한 줄.png'
                      : 'https://example.com/a-long-submitted-link',
                  photoBytes: photo ? photoBytes : null,
                ),
                platform: platform,
                width: width,
                scale: scale,
              );
              expect(tester.takeException(), isNull);
              final card = tester.getRect(_previewCard());
              final title = tester.getRect(find.text(_title));
              final source = tester.getRect(find.text(_source));
              final text = title.expandToInclude(source);
              final textColumn = tester.getRect(
                find
                    .ancestor(
                      of: find.text(_title),
                      matching: find.byType(Column),
                    )
                    .first,
              );
              final thumbnail = tester.getRect(_previewImage());
              expect(card.width, width - 32);
              expect(card.height, greaterThanOrEqualTo(116));
              if (scale == 1) expect(card.height, 116);
              expect(
                tester.getRect(find.text('카테고리')).top - card.bottom,
                closeTo(32, 0.01),
              );
              final precedingBlock = tester.getRect(
                photo
                    ? _resultRole(
                        'save-result-photo-summary',
                        find
                            .ancestor(
                              of: find.text('사진 파일 이름이 길어도 기존처럼 한 줄.png'),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                    : find.byType(ValidationMessage),
              );
              expect(
                tester.getRect(find.text('미리보기')).top - precedingBlock.bottom,
                closeTo(photo ? 16 : 32, 0.01),
                reason:
                    'The actual preceding result block owns the preview gap',
              );
              if (photo) {
                expect(precedingBlock.height, 89);
                final submitted = find.byKey(
                  const ValueKey('save-result-photo-image'),
                );
                expect(submitted, findsOneWidget);
                final image = tester.widget<Image>(submitted);
                expect(image.fit, BoxFit.cover);
                expect(image.alignment, Alignment.center);
                expect(
                  image.semanticLabel,
                  contains('사진 파일 이름이 길어도 기존처럼 한 줄.png'),
                );
                expect((image.image as MemoryImage).bytes, same(photoBytes));
                final clip = tester.getRect(
                  find
                      .ancestor(of: submitted, matching: find.byType(ClipRect))
                      .first,
                );
                expect(clip.height, 57);
                expect(clip.width, precedingBlock.width - 32);
                expect(clip.center, precedingBlock.center);
              }
              final inner = card.deflate(8);
              _contained(
                title,
                Rect.fromLTRB(
                  inner.left,
                  inner.top,
                  card.right - 16,
                  inner.bottom,
                ),
              );
              _contained(source, card.deflate(8));
              _contained(thumbnail, card.deflate(8));
              expect(thumbnail.size, const Size(164, 100));
              final imageWidget = tester.widget<Image>(_previewImage());
              expect(imageWidget.fit, BoxFit.cover);
              expect(imageWidget.alignment, Alignment.center);
              final borderWidget = tester.widget<Container>(
                find
                    .ancestor(
                      of: _previewImage(),
                      matching: find.byType(Container),
                    )
                    .first,
              );
              final border =
                  borderWidget.foregroundDecoration as BoxDecoration?;
              expect(
                border?.border,
                photo ? Border.all(color: AppColors.subtler) : null,
              );
              if (photo) expect(border?.borderRadius, BorderRadius.circular(4));
              expect(thumbnail.left - card.left, 8);
              expect(title.left - thumbnail.right, 16);
              final columnMaxWidth = card.width - 8 - 164 - 16 - 8;
              expect(textColumn.width, closeTo(columnMaxWidth, 0.01));
              expect(card.right - textColumn.right, closeTo(8, 0.01));
              expect(
                _paragraph(tester, _title).constraints.maxWidth,
                closeTo(columnMaxWidth - 8, 0.01),
              );
              expect(
                _paragraph(tester, _source).constraints.maxWidth,
                closeTo(columnMaxWidth, 0.01),
              );
              expect(source.top - title.bottom, closeTo(14, 0.01));
              expect(
                text.height,
                closeTo(title.height + 14 + source.height, 0.01),
              );
              expect(thumbnail.center.dy, closeTo(card.center.dy, 0.01));
              expect(text.center.dy, closeTo(card.center.dy, 0.01));
              expect(_paragraph(tester, _title).maxLines, 2);
              expect(_paragraph(tester, _source).maxLines, 1);
              expect(
                _paragraph(tester, _title).overflow,
                TextOverflow.ellipsis,
              );
              expect(
                _paragraph(tester, _source).overflow,
                TextOverflow.ellipsis,
              );
              _unchangedFont(tester, _title, fontSize: 15, scale: scale);
              _unchangedFont(tester, _source, fontSize: 14, scale: scale);
              final textHeight = text.height;
              if (textHeight > 100) expect(card.height, greaterThan(116));
              expect(math.min(title.height, source.height), greaterThan(0));
              expect(find.text(photo ? '저장할 사진' : '저장할 링크'), findsOneWidget);
              expect(
                find.byType(ValidationMessage),
                photo ? findsNothing : findsOneWidget,
              );
            },
          );
        }
      }
    }
  }
}
