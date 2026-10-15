import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/data/sample_contents.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Picker extends FilePicker {
  _Picker(this.bytes);
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
      PlatformFile(name: 'safe-area.png', size: bytes.length, bytes: bytes),
    ]);
  }
}

void _metrics(WidgetTester tester, {double top = 59, double keyboard = 0}) {
  tester.view.padding = FakeViewPadding(
    top: top,
    bottom: keyboard == 0 ? 34 : 0,
  );
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: 34);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
}

void main() {
  setUpAll(FilePickerIO.registerWith);
  testWidgets(
    'save dialog preserves link and selected photo through inset changes and failed retries',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      _metrics(tester);
      addTearDown(tester.view.reset);
      final bytes = (await rootBundle.load(
        'assets/figma/saved-photo-preview.png',
      )).buffer.asUint8List();
      final picker = _Picker(bytes);
      final originalPicker = FilePicker.platform;
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = originalPicker);
      final urls = <String>[];
      final uploads = <(String, Uint8List)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showContentSaveScreen(
                    context: context,
                    onAddLink: ({required url, category}) async {
                      urls.add(url);
                      throw const ClipbackApiException('fixture failure');
                    },
                    onAddScreenshot:
                        ({required bytes, required filename, category}) async {
                          uploads.add((filename, bytes));
                          throw const ClipbackApiException('fixture failure');
                        },
                  ),
                  child: const Text('open save'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open save'));
      await tester.pumpAndSettle();
      final sheetState = tester.state(find.byType(AddContentSheet));
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/preserved',
      );
      await tester.pump(const Duration(milliseconds: 400));
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller;
      final saveButton = find.text('허투루에 저장하기');
      final buttonBottom = tester.getBottomLeft(find.byType(SaveFlowButton)).dy;
      expect(buttonBottom, 812 - 34 - 32);
      _metrics(tester, top: 62, keyboard: 300);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(AddContentSheet)), same(sheetState));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(controller),
      );
      expect(controller!.text, 'https://example.com/preserved');
      expect(tester.getTopLeft(find.byType(SaveContentTopBar)).dy, 62);
      expect(
        tester.getBottomLeft(find.byType(SaveFlowButton)).dy,
        812 - 300 - 32,
      );
      _metrics(tester, top: 62);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byType(SaveFlowButton)).dy,
        buttonBottom,
      );
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text('fixture failure'), findsOneWidget);
      expect(controller.text, 'https://example.com/preserved');
      _metrics(tester, top: 44);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(urls, [
        'https://example.com/preserved',
        'https://example.com/preserved',
      ]);

      await tester.tap(find.text('사진 첨부'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 선택'));
      await tester.pumpAndSettle();
      final selected = find.byWidgetPredicate(
        (w) => w is Image && w.image is MemoryImage,
      );
      expect(selected, findsWidgets);
      _metrics(tester, top: 59, keyboard: 260);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(SaveContentTopBar)).dy, 59);
      expect(tester.state(find.byType(AddContentSheet)), same(sheetState));
      expect(selected, findsWidgets);
      _metrics(tester);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      _metrics(tester, top: 62);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(uploads, hasLength(2));
      for (final upload in uploads) {
        expect(upload.$1, 'safe-area.png');
        expect(upload.$2, orderedEquals(bytes));
      }
      expect(selected, findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'search keeps its controller and query when keyboard and safe inset change',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      _metrics(tester);
      addTearDown(tester.view.reset);
      final queries = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(
            initialQuery: 'initial',
            contents: initialContents,
            categories: const [],
            bookmarkedIds: const {},
            onSearch: (query) async {
              queries.add(query);
              return initialContents;
            },
            onQueryChanged: (_) {},
            onClose: () {},
            onOpenContent: (_) {},
            onToggleBookmark: (_) {},
            onChangeContentCategory: (_, _) {},
            onDeleteContent: (_) {},
            onOpenArchive: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller;
      await tester.enterText(find.byType(TextField), 'preserved query');
      _metrics(tester, top: 62, keyboard: 280);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(controller),
      );
      expect(controller!.text, 'preserved query');
      expect(
        tester.getTopLeft(find.byType(TextField)).dy,
        greaterThanOrEqualTo(62),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(queries.last, 'preserved query');
      _metrics(tester, top: 44);
      await tester.pumpAndSettle();
      expect(controller.text, 'preserved query');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
