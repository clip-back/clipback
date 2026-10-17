import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem _savedContent({bool isScreenshot = false}) => ContentItem(
  id: 'saved-result',
  title: '저장한 콘텐츠',
  summary: '서버가 반환한 요약',
  category: catUncategorized,
  savedAt: '26.10.15',
  savedAtFull: '2026. 10. 15 오후 02:00',
  savedAtFullShort: '2026. 10. 15 02:00',
  tags: const [],
  source: '테스트',
  originalUrl: 'https://example.com/server-value',
  originalText: '',
  isScreenshot: isScreenshot,
);

class _Photo {
  const _Photo(this.filename, this.bytes);

  final String filename;
  final Uint8List bytes;
}

class _Picker extends FilePicker {
  _Picker(this.photos);

  final List<_Photo> photos;
  int calls = 0;
  Completer<FilePickerResult?>? pendingResult;

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
    final index = calls++;
    if (pendingResult case final pending?) return pending.future;
    final photo = photos[index];
    return FilePickerResult([
      PlatformFile(
        name: photo.filename,
        size: photo.bytes.length,
        bytes: photo.bytes,
      ),
    ]);
  }
}

Future<void> _open(
  WidgetTester tester, {
  required SaveLinkCallback onAddLink,
  required SaveScreenshotCallback onAddScreenshot,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 812);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showContentSaveScreen(
              context: context,
              onAddLink: onAddLink,
              onAddScreenshot: onAddScreenshot,
            ),
            child: const Text('저장 화면 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('저장 화면 열기'));
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _link(WidgetTester tester, String url) async {
  await _tab(tester, '링크 첨부');
  await tester.enterText(find.byType(TextField), url);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _photo(WidgetTester tester) async {
  await _tab(tester, '사진 첨부');
  await tester.tap(
    find.byType(SelectedPhotoPreview).evaluate().isEmpty
        ? find.text('사진 선택')
        : find.byType(SelectedPhotoPreview),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('허투루에 저장하기'));
  await tester.pump(const Duration(milliseconds: 50));
}

SavedContentConfirmation _result(WidgetTester tester) => tester
    .widget<SavedContentConfirmation>(find.byType(SavedContentConfirmation));

void _expectActiveTab(WidgetTester tester, String label) {
  expect(
    tester.widget<Text>(find.text(label)).style!.fontWeight,
    FontWeight.w600,
  );
}

void main() {
  setUpAll(FilePickerIO.registerWith);

  late Uint8List firstBytes;
  late Uint8List secondBytes;
  late _Picker picker;
  late FilePicker originalPicker;

  setUp(() async {
    final bytes = (await rootBundle.load(
      'assets/figma/saved-photo-preview.png',
    )).buffer.asUint8List();
    firstBytes = Uint8List.fromList(bytes);
    secondBytes = (await rootBundle.load(
      'assets/figma/save-link-preview.png',
    )).buffer.asUint8List();
    picker = _Picker([
      _Photo('first-photo.png', firstBytes),
      _Photo('second-photo.png', secondBytes),
    ]);
    originalPicker = FilePicker.platform;
    FilePicker.platform = picker;
  });

  tearDown(() => FilePicker.platform = originalPicker);

  testWidgets('photo result uses photo wording without link validation', (
    tester,
  ) async {
    final returned = _savedContent();
    await _open(
      tester,
      onAddLink: ({required url, category}) async => throw StateError('link'),
      onAddScreenshot: ({required bytes, required filename, category}) async =>
          returned,
    );
    await _photo(tester);
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('저장할 사진'), findsOneWidget);
    expect(find.text('저장할 링크'), findsNothing);
    expect(find.text('유효한 링크예요!'), findsNothing);
    expect(find.byType(ValidationMessage), findsNothing);
    expect(find.text('first-photo.png'), findsNothing);
    final submittedImage = find.byKey(
      const ValueKey('save-result-photo-image'),
    );
    expect(submittedImage, findsOneWidget);
    final image = tester.widget<Image>(submittedImage);
    expect(image.semanticLabel, contains('first-photo.png'));
    expect((image.image as MemoryImage).bytes, same(firstBytes));
    expect(_result(tester).content, same(returned));
    expect(_result(tester).photoBytes, orderedEquals(firstBytes));
    expect(find.text('아직 분류되지 않았어요.'), findsOneWidget);
    expect(find.text('분류는 상세 화면에서 변경할 수 있어요.'), findsOneWidget);
    _expectActiveTab(tester, '사진 첨부');
    expect(tester.takeException(), isNull);
  });

  for (final portrait in [true, false]) {
    testWidgets(
      '${portrait ? 'portrait' : 'landscape'} submitted photo fills both result clips without changing bytes',
      (tester) async {
        final bytes = portrait ? firstBytes : secondBytes;
        picker = _Picker([_Photo('orientation-photo.png', bytes)]);
        FilePicker.platform = picker;
        final semantics = tester.ensureSemantics();
        try {
          await _open(
            tester,
            onAddLink: ({required url, category}) async =>
                throw StateError('link'),
            onAddScreenshot:
                ({required bytes, required filename, category}) async =>
                    _savedContent(),
          );
          await _photo(tester);
          await _submit(tester);
          await tester.pumpAndSettle();

          final summaryImage = find.byKey(
            const ValueKey('save-result-photo-image'),
          );
          expect(summaryImage, findsOneWidget);
          expect(_result(tester).originalUrl, 'orientation-photo.png');
          expect(_result(tester).photoBytes, same(bytes));
          expect(find.text('orientation-photo.png'), findsNothing);
          expect(
            tester.getSemantics(summaryImage).label,
            contains('orientation-photo.png'),
          );
          final previewRole = find.byKey(
            const ValueKey('save-result-preview-image'),
          );
          expect(previewRole, findsOneWidget);
          final thumbnail = previewRole.evaluate().single.widget is Image
              ? previewRole
              : find.descendant(of: previewRole, matching: find.byType(Image));
          // Widget settling does not wait for asynchronous image decoding. Resolve
          // both real providers before inspecting their decoded RenderImage data.
          await tester.runAsync(() async {
            await Future.wait([
              for (final imageFinder in [summaryImage, thumbnail])
                precacheImage(
                  tester.widget<Image>(imageFinder).image,
                  tester.element(imageFinder),
                ),
            ]);
          });
          await tester.pumpAndSettle();
          for (final imageFinder in [summaryImage, thumbnail]) {
            final image = tester.widget<Image>(imageFinder);
            expect(image.image, isA<MemoryImage>());
            expect((image.image as MemoryImage).bytes, same(bytes));
            expect(image.fit, BoxFit.cover);
            expect(image.alignment, Alignment.center);
            final render = tester.renderObject<RenderImage>(
              find.descendant(of: imageFinder, matching: find.byType(RawImage)),
            );
            expect(render.image, isNotNull);
            final decoded = Size(
              render.image!.width.toDouble(),
              render.image!.height.toDouble(),
            );
            expect(
              decoded,
              portrait ? const Size(1179, 2556) : const Size(399, 243),
            );
            final fitted = applyBoxFit(BoxFit.cover, decoded, render.size);
            expect(fitted.destination, render.size);
            final centeredSource = Alignment.center.inscribe(
              fitted.source,
              Offset.zero & decoded,
            );
            expect(
              (centeredSource.center - (Offset.zero & decoded).center).distance,
              lessThan(1e-9),
            );
            expect(centeredSource.width, lessThanOrEqualTo(decoded.width));
            expect(centeredSource.height, lessThanOrEqualTo(decoded.height));
            if (portrait || imageFinder == summaryImage) {
              expect(centeredSource.height, lessThan(decoded.height));
            }
            final clips = find.ancestor(
              of: imageFinder,
              matching: find.byWidgetPredicate(
                (w) => w is ClipRect || w is ClipRRect,
              ),
            );
            expect(clips.evaluate(), isNotEmpty);
            final clip = tester.getRect(clips.first);
            expect(tester.getRect(imageFinder), clip);
          }
          _expectActiveTab(tester, '사진 첨부');
          await _tab(tester, '링크 첨부');
          _expectActiveTab(tester, '사진 첨부');
          expect(_result(tester).photoBytes, same(bytes));
          await tester.tap(find.text('닫기'));
          await tester.pumpAndSettle();
          expect(find.byType(AddContentSheet), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('link result keeps link wording and submitted trimmed URL', (
    tester,
  ) async {
    final calls = <String>[];
    await _open(
      tester,
      onAddLink: ({required url, category}) async {
        calls.add(url);
        return _savedContent(isScreenshot: true);
      },
      onAddScreenshot: ({required bytes, required filename, category}) async =>
          throw StateError('photo'),
    );
    await _link(tester, '  https://example.com/submitted  ');
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(calls, ['https://example.com/submitted']);
    expect(find.text('저장할 링크'), findsOneWidget);
    expect(find.text('저장할 사진'), findsNothing);
    expect(find.text('유효한 링크예요!'), findsOneWidget);
    expect(find.text('https://example.com/submitted'), findsOneWidget);
    expect(_result(tester).photoBytes, isNull);
    _expectActiveTab(tester, '링크 첨부');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending photo keeps its filename and bytes after draft changes',
    (tester) async {
      final response = Completer<ContentItem>();
      final uploads = <(String, Uint8List)>[];
      var linkCalls = 0;
      await _open(
        tester,
        onAddLink: ({required url, category}) async {
          linkCalls++;
          return _savedContent();
        },
        onAddScreenshot: ({required bytes, required filename, category}) {
          uploads.add((filename, bytes));
          return response.future;
        },
      );
      await _photo(tester);
      await _submit(tester);
      await _link(tester, 'https://example.com/other-draft');
      expect(find.byType(TextField), findsOneWidget);
      await _photo(tester);
      expect(picker.calls, 2);
      await _tab(tester, '링크 첨부');

      response.complete(_savedContent());
      await tester.pumpAndSettle();

      expect(uploads, hasLength(1));
      expect(uploads.single.$1, 'first-photo.png');
      expect(uploads.single.$2, orderedEquals(firstBytes));
      expect(linkCalls, 0);
      expect(_result(tester).originalUrl, 'first-photo.png');
      expect(_result(tester).photoBytes, orderedEquals(firstBytes));
      expect(identical(_result(tester).photoBytes, secondBytes), isFalse);
      expect(find.text('저장할 사진'), findsOneWidget);
      expect(find.text('유효한 링크예요!'), findsNothing);
      _expectActiveTab(tester, '사진 첨부');

      await _tab(tester, '링크 첨부');
      _expectActiveTab(tester, '사진 첨부');
      expect(_result(tester).originalUrl, 'first-photo.png');
      expect(_result(tester).photoBytes, orderedEquals(firstBytes));
      expect(uploads, hasLength(1));
      expect(linkCalls, 0);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(AddContentSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending link keeps submitted URL after tab and draft changes', (
    tester,
  ) async {
    final response = Completer<ContentItem>();
    final urls = <String>[];
    var photoCalls = 0;
    await _open(
      tester,
      onAddLink: ({required url, category}) {
        urls.add(url);
        return response.future;
      },
      onAddScreenshot: ({required bytes, required filename, category}) async {
        photoCalls++;
        return _savedContent();
      },
    );
    await _link(tester, '  https://example.com/original  ');
    await _submit(tester);
    await _photo(tester);
    await _link(tester, 'https://example.com/edited');
    await _tab(tester, '사진 첨부');
    response.complete(_savedContent(isScreenshot: true));
    await tester.pumpAndSettle();

    expect(urls, ['https://example.com/original']);
    expect(photoCalls, 0);
    expect(_result(tester).originalUrl, 'https://example.com/original');
    expect(_result(tester).photoBytes, isNull);
    expect(find.text('저장할 링크'), findsOneWidget);
    expect(find.text('유효한 링크예요!'), findsOneWidget);
    _expectActiveTab(tester, '링크 첨부');
    await _tab(tester, '사진 첨부');
    _expectActiveTab(tester, '링크 첨부');
    expect(_result(tester).photoBytes, isNull);
    expect(urls, hasLength(1));
    expect(photoCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed photo retry submits current selection and freezes it', (
    tester,
  ) async {
    final firstResponse = Completer<ContentItem>();
    final uploads = <(String, Uint8List)>[];
    await _open(
      tester,
      onAddLink: ({required url, category}) async => throw StateError('link'),
      onAddScreenshot: ({required bytes, required filename, category}) {
        uploads.add((filename, bytes));
        return uploads.length == 1
            ? firstResponse.future
            : Future.value(_savedContent());
      },
    );
    await _photo(tester);
    await _submit(tester);
    await _photo(tester);
    firstResponse.completeError(const ClipbackApiException('사진 저장 실패'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SavedContentConfirmation), findsNothing);
    expect(find.text('사진 저장 실패'), findsOneWidget);
    expect(find.byType(SelectedPhotoPreview), findsOneWidget);
    expect(uploads, hasLength(1));
    await _submit(tester);
    await tester.pumpAndSettle();

    expect(picker.calls, 2);
    expect(uploads.map((upload) => upload.$1), [
      'first-photo.png',
      'second-photo.png',
    ]);
    expect(uploads.last.$2, orderedEquals(secondBytes));
    expect(_result(tester).originalUrl, 'second-photo.png');
    expect(_result(tester).photoBytes, orderedEquals(secondBytes));
    expect(find.text('사진 저장 실패'), findsNothing);
    expect(find.text('저장할 사진'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed link retry captures the edited URL', (tester) async {
    final firstResponse = Completer<ContentItem>();
    final urls = <String>[];
    await _open(
      tester,
      onAddLink: ({required url, category}) {
        urls.add(url);
        return urls.length == 1
            ? firstResponse.future
            : Future.value(_savedContent());
      },
      onAddScreenshot: ({required bytes, required filename, category}) async =>
          throw StateError('photo'),
    );
    await _link(tester, 'https://example.com/failed');
    await _submit(tester);
    await _link(tester, '  https://example.com/retry  ');
    firstResponse.completeError(const ClipbackApiException('링크 저장 실패'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SavedContentConfirmation), findsNothing);
    expect(find.text('링크 저장 실패'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '  https://example.com/retry  ',
    );
    await _submit(tester);
    await tester.pumpAndSettle();
    expect(urls, ['https://example.com/failed', 'https://example.com/retry']);
    expect(_result(tester).originalUrl, 'https://example.com/retry');
    expect(find.text('링크 저장 실패'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'late photo picker and inactive result tab preserve saved input and scroll',
    (tester) async {
      final response = Completer<ContentItem>();
      var calls = 0;
      await _open(
        tester,
        onAddLink: ({required url, category}) async => throw StateError('link'),
        onAddScreenshot: ({required bytes, required filename, category}) {
          calls++;
          return response.future;
        },
      );
      tester.view.physicalSize = const Size(375, 650);
      await tester.pump();
      await _photo(tester);
      await _submit(tester);
      picker.pendingResult = Completer<FilePickerResult?>();
      await _photo(tester);
      expect(picker.calls, 2);
      response.complete(_savedContent());
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller!;
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      final savedOffset = scroll.position.maxScrollExtent / 2;
      scroll.jumpTo(savedOffset);
      await tester.pump();

      picker.pendingResult!.complete(
        FilePickerResult([
          PlatformFile(
            name: 'late-photo.png',
            size: secondBytes.length,
            bytes: secondBytes,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(_result(tester).originalUrl, 'first-photo.png');
      expect(_result(tester).photoBytes, orderedEquals(firstBytes));
      expect(scroll.offset, savedOffset);
      _expectActiveTab(tester, '사진 첨부');

      await _tab(tester, '링크 첨부');
      _expectActiveTab(tester, '사진 첨부');
      expect(scroll.offset, savedOffset);
      expect(_result(tester).originalUrl, 'first-photo.png');
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final photo in [false, true]) {
    testWidgets(
      'old ${photo ? 'photo' : 'link'} submit callback cannot save again after success',
      (tester) async {
        var linkCalls = 0;
        var photoCalls = 0;
        await _open(
          tester,
          onAddLink: ({required url, category}) async {
            linkCalls++;
            return _savedContent();
          },
          onAddScreenshot:
              ({required bytes, required filename, category}) async {
                photoCalls++;
                return _savedContent();
              },
        );
        if (photo) {
          await _photo(tester);
        } else {
          await _link(tester, 'https://example.com/save-once');
        }
        final staleSubmit = tester
            .widget<SaveFlowButton>(find.byType(SaveFlowButton))
            .onPressed;
        staleSubmit();
        await tester.pumpAndSettle();
        expect(find.byType(SavedContentConfirmation), findsOneWidget);
        staleSubmit();
        await tester.pumpAndSettle();
        expect(linkCalls, photo ? 0 : 1);
        expect(photoCalls, photo ? 1 : 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final succeeds in [true, false]) {
    testWidgets(
      'duplicate submission and late ${succeeds ? 'success' : 'failure'} do not update a closed dialog',
      (tester) async {
        final response = Completer<ContentItem>();
        var calls = 0;
        await _open(
          tester,
          onAddLink: ({required url, category}) {
            calls++;
            return response.future;
          },
          onAddScreenshot:
              ({required bytes, required filename, category}) async =>
                  throw StateError('photo'),
        );
        await _link(tester, 'https://example.com/pending');
        final submit = tester
            .widget<SaveFlowButton>(find.byType(SaveFlowButton))
            .onPressed;
        submit();
        submit();
        await tester.pump(const Duration(milliseconds: 50));
        expect(calls, 1);
        final button = tester.widget<SaveFlowButton>(
          find.byType(SaveFlowButton),
        );
        expect(button.enabled, isFalse);
        expect(button.loading, isTrue);
        tester
            .widget<SaveContentTopBar>(find.byType(SaveContentTopBar))
            .onClose();
        await tester.pumpAndSettle();
        expect(find.byType(AddContentSheet), findsNothing);
        if (succeeds) {
          response.complete(_savedContent());
        } else {
          response.completeError(const ClipbackApiException('늦은 저장 실패'));
        }
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.byType(SavedContentConfirmation), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
