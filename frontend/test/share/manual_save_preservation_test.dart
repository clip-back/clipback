import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/repositories/share_repository.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/share/pending_share_prompt.dart';
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
      PlatformFile(
        name: 'manual-preserved.png',
        size: bytes.length,
        bytes: bytes,
      ),
    ]);
  }
}

void main() {
  setUpAll(FilePickerIO.registerWith);

  testWidgets(
    'native share recovery preserves the real manual save dialog and selected photo',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);

      final bytes = (await rootBundle.load(
        'assets/figma/saved-photo-preview.png',
      )).buffer.asUint8List();
      final picker = _Picker(bytes);
      final originalPicker = FilePicker.platform;
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = originalPicker);

      final navigator = GlobalKey<NavigatorState>();
      final prompt = ValueNotifier<(int, List<PendingShareDraft>)>((
        0,
        const [],
      ));
      addTearDown(prompt.dispose);
      final opened = <String>[];
      final links = <String>[];
      final uploads = <(String, Uint8List)>[];
      var retries = 0;
      const manualUrl = 'https://www.instagram.com/p/manual-draft/';
      const first = PendingShareDraft(id: 'first', label: '외부에서 공유한 링크');
      const second = PendingShareDraft(id: 'second', label: '외부에서 공유한 사진');
      const third = PendingShareDraft(id: 'third', label: '새로 도착한 공유');

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => ValueListenableBuilder(
            valueListenable: prompt,
            child: child,
            builder: (context, value, child) => PendingSharePrompt(
              navigatorKey: navigator,
              promptVersion: value.$1,
              drafts: value.$2,
              error: null,
              busy: false,
              onRetry: () => retries++,
              onOpen: (draft) => opened.add(draft.id),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showContentSaveScreen(
                    context: context,
                    onAddLink: ({required url, category}) async {
                      links.add(url);
                      throw const ClipbackApiException('수동 저장 실패 확인');
                    },
                    onAddScreenshot:
                        ({required bytes, required filename, category}) async {
                          uploads.add((filename, bytes));
                          throw const ClipbackApiException('수동 저장 실패 확인');
                        },
                  ),
                  child: const Text('수동 저장 열기'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('수동 저장 열기'));
      await tester.pumpAndSettle();
      final sheet = find.byType(AddContentSheet, skipOffstage: false);
      final sheetState = tester.state(sheet);
      await tester.enterText(find.byType(TextField), manualUrl);
      await tester.pump(const Duration(milliseconds: 400));
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('사진 첨부'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 선택'));
      await tester.pumpAndSettle();

      void expectDraftPreserved() {
        expect(tester.state(sheet), same(sheetState));
        expect(controller.text, manualUrl);
        expect(
          tester
              .widget<PhotoSaveBody>(
                find.byType(PhotoSaveBody, skipOffstage: false),
              )
              .photoBytes,
          same(bytes),
        );
        expect(picker.calls, 1);
      }

      expectDraftPreserved();
      prompt.value = (1, const [first]);
      await tester.pumpAndSettle();
      expect(find.text('저장 대기 중인 공유 1개'), findsOneWidget);
      expectDraftPreserved();

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('저장 대기 중인 공유'), findsOneWidget);
      expectDraftPreserved();
      await tester.tap(find.text(first.label));
      await tester.pumpAndSettle();
      expect(opened, [first.id]);
      expect(navigator.currentState!.canPop(), isTrue);
      expectDraftPreserved();

      prompt.value = (2, const [second, third]);
      await tester.pumpAndSettle();
      expect(find.text('저장 대기 중인 공유 2개'), findsOneWidget);
      expectDraftPreserved();
      await tester.tap(find.bySemanticsLabel('나중에'));
      await tester.pumpAndSettle();
      expect(find.text('저장 대기 중인 공유 2개'), findsNothing);
      expectDraftPreserved();
      expect(links, isEmpty);
      expect(uploads, isEmpty);
      expect(retries, 0);

      await tester.tap(find.text('링크 첨부'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(controller),
      );
      expect(controller.text, manualUrl);
      expect(tester.state(sheet), same(sheetState));

      await tester.tap(find.text('사진 첨부'));
      await tester.pumpAndSettle();
      expectDraftPreserved();
      await tester.tap(find.text('허투루에 저장하기'));
      await tester.pumpAndSettle();
      expect(uploads, hasLength(1));
      expect(uploads.single.$1, 'manual-preserved.png');
      expect(uploads.single.$2, orderedEquals(bytes));
      expect(links, isEmpty);
      expect(find.text('수동 저장 실패 확인'), findsOneWidget);
      expectDraftPreserved();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
