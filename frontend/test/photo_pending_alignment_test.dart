import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'fixtures/photo_pending_fixture.dart' as f;
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as login;

late Uint8List _bytes, _alternate;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await font.load();
    final a = await rootBundle.load(Assets.savedPhotoPreview),
        b = await rootBundle.load(Assets.homeInitialLoadingIllustration);
    _bytes = a.buffer.asUint8List(a.offsetInBytes, a.lengthInBytes);
    _alternate = b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final height in [812.0, 520.0]) {
        testWidgets(
          '${platform.name} ${width}x$height D08 actual multipart and preserved photo',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, height);
            final top = platform == TargetPlatform.iOS ? 50.0 : 24.0,
                bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
            tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
            tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
            debugDefaultTargetPlatformOverride = platform;
            final server = f.PhotoPendingServer(_bytes),
                storage = login.LoginMemoryStorage()..value = f.pendingSession,
                picker = f.PendingPhotoPicker([
                  f.PendingPhoto(f.photoName, _bytes),
                  f.PendingPhoto('alternate-photo.png', _alternate),
                ]);
            FilePicker? previous;
            try {
              previous = FilePicker.platform;
            } catch (_) {}
            FilePicker.platform = picker;
            try {
              await http.runWithClient(() async {
                await tester.pumpWidget(
                  ClipbackApp(
                    sessionStorage: storage,
                    socialAuth: login.LoginControlledSocial(platform),
                  ),
                );
                await completeAppStartup(tester);
                expect(find.byType(HomeScreen), findsOneWidget);
                await tester.tap(
                  find.byWidgetPredicate(
                    (w) => w.runtimeType.toString() == 'NavAddButton',
                  ),
                );
                await tester.pump();
                await tester.tap(find.text('사진 첨부'));
                await tester.pump();
                await tester.tap(find.text('사진 선택'));
                await tester.pumpAndSettle();
                final submit = tester
                    .widget<SaveFlowButton>(find.byType(SaveFlowButton))
                    .onPressed;
                submit();
                await tester.pump(const Duration(milliseconds: 50));
                expect(server.submissions, [f.photoName]);
                expect(server.uploads.single['originalBytesContained'], isTrue);
                expect(server.uploads.single['multipart'], isTrue);
                final root = tester.element(find.byType(ClipbackApp)),
                    m = f.photoPendingMeasure(root, expectedBytes: _bytes),
                    j = f.photoPendingJudgment(m);
                expect(
                  j['stylePassed'],
                  isTrue,
                  reason: '$m ${j['styleFailures']}',
                );
                expect(
                  j['layoutPassed'],
                  isTrue,
                  reason: '$m ${j['layoutFailures']}',
                );
                final target = tester.element(
                      find.byKey(const ValueKey('photo-pending-skeleton')),
                    ),
                    pos = target
                        .findAncestorStateOfType<ScrollableState>()!
                        .position;
                pos.jumpTo(pos.maxScrollExtent);
                await tester.pump();
                final end = f.photoPendingMeasure(root, expectedBytes: _bytes),
                    card = (end['category'] as Map)['bounds'] as Map,
                    viewport = end['viewport'] as Map;
                expect(
                  card['bottom'],
                  lessThanOrEqualTo((viewport['bottom'] as num) - 23.9),
                );
                if (pos.maxScrollExtent > 0) {
                  expect(
                    (viewport['bottom'] as num) - (card['bottom'] as num),
                    closeTo(24, .2),
                  );
                }
                pos.jumpTo(0);
                await tester.pump();
                submit();
                submit();
                await tester.pump();
                expect(server.submissions, [f.photoName]);
                await tester.tap(find.text('링크 첨부'));
                await tester.pump();
                expect(
                  find.byKey(const ValueKey('photo-pending-skeleton')),
                  findsNothing,
                );
                await tester.tap(find.text('사진 첨부'));
                await tester.pump();
                expect(
                  find.byKey(const ValueKey('photo-pending-skeleton')),
                  findsOneWidget,
                );
                picker.cancelNext = true;
                await tester.tap(
                  find.byKey(const ValueKey('photo-pending-reselect')),
                );
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 30));
                expect(
                  find.byKey(const ValueKey('photo-pending-skeleton')),
                  findsOneWidget,
                );
                await tester.tap(
                  find.byKey(const ValueKey('photo-pending-reselect')),
                );
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 30));
                expect(
                  find.byKey(const ValueKey('photo-pending-skeleton')),
                  findsNothing,
                );
                expect(
                  tester
                      .widget<PhotoSaveBody>(find.byType(PhotoSaveBody))
                      .photoBytes,
                  same(_alternate),
                );
                server.resolve();
                await tester.pumpAndSettle();
                final result = tester.widget<SavedContentConfirmation>(
                  find.byType(SavedContentConfirmation),
                );
                expect(result.originalUrl, f.photoName);
                expect(result.photoBytes, same(_bytes));
                expect(server.submissions, [f.photoName]);
                expect(tester.takeException(), isNull);
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump(const Duration(seconds: 1));
              }, () => server.photoClient);
            } finally {
              server.resolve(success: false);
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(seconds: 1));
              server.close();
              if (previous != null) {
                FilePicker.platform = previous;
              }
              tester.view.reset();
              debugDefaultTargetPlatformOverride = null;
            }
          },
        );
      }
    }
  }
}
