import 'dart:async';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'fixtures/original_link_launcher.dart';
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;
import 'support/original_link_preview.dart';

const _form = 'https://forms.gle/dGjWJc643ZwrXTrF7';
const _contactError = '문의하기를 열지 못했어요. 다시 시도해 주세요.';

Finder get _contact => find.text('문의하기');

Future<void> _withMy(
  WidgetTester tester,
  Future<void> Function(RecordingUrlLauncher) check, {
  double width = 393,
  double scale = 1,
}) async {
  final server = OriginalLinkPreviewServer()..reset('link');
  final old = UrlLauncherPlatform.instance, launcher = RecordingUrlLauncher();
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = old);
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(
          sessionStorage: isolated.ArchiveAllMemoryStorage(),
          socialAuth: isolated.ArchiveAllSocialAuth(),
        ),
      );
      await completeAppStartup(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(ClipbackNavigationBar),
          matching: find.text('마이'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MyScreen), findsOneWidget);
      await tester.ensureVisible(_contact);
      await tester.pumpAndSettle();
      await check(launcher);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      server.previewClient.close();
      server.client.close();
    }
  }, () => server.previewClient);
}

void _expectFormOpens(RecordingUrlLauncher launcher, int times) {
  expect(launcher.calls, hasLength(times));
  for (final call in launcher.calls) {
    expect(call.url, _form);
    expect(call.options.mode, PreferredLaunchMode.externalApplication);
  }
}

void main() {
  testWidgets('my contact opens the form once without a sheet', (tester) async {
    await _withMy(tester, (launcher) async {
      launcher.pending = Completer<bool>();
      await tester.tap(_contact);
      await tester.pump();
      await tester.tap(_contact);
      await tester.pump();
      _expectFormOpens(launcher, 1);
      expect(find.byType(BottomSheet), findsNothing);
      launcher.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(MyScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      _expectFormOpens(launcher, 1);
    });
  });

  for (final refusal in ['os-false', 'exception']) {
    testWidgets('my contact $refusal shows message and retries on next tap', (
      tester,
    ) async {
      await _withMy(tester, (launcher) async {
        if (refusal == 'os-false') {
          launcher.accepted = false;
        } else {
          launcher.failure = PlatformException(code: 'launch_failed');
        }
        await tester.tap(_contact);
        await tester.pumpAndSettle();
        expect(find.text(_contactError), findsOneWidget);
        expect(find.byType(MyScreen), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        launcher
          ..accepted = true
          ..failure = null;
        await tester.tap(_contact);
        await tester.pumpAndSettle();
        _expectFormOpens(launcher, 2);
        expect(find.byType(MyScreen), findsOneWidget);
      });
    });
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('contact failure message ${scale}x width 320 is not clipped', (
      tester,
    ) async {
      await _withMy(tester, width: 320, scale: scale, (launcher) async {
        launcher.accepted = false;
        await tester.tap(_contact);
        await tester.pumpAndSettle();
        final text = find.text(_contactError);
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        // The app snack bar style is measured as rendered (2026-11-12 decision):
        // its family falls back to the 1em-wide test glyphs, wider than Korean
        // device fonts.
        expect(paragraph.textScaler.scale(10), closeTo(10 * scale, .01));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.size.height,
          closeTo(paragraph.getMinIntrinsicHeight(paragraph.size.width), .1),
        );
        final textRect = tester.getRect(text);
        final barRect = tester.getRect(find.byType(SnackBar));
        expect(textRect.left, greaterThanOrEqualTo(barRect.left));
        expect(textRect.right, lessThanOrEqualTo(barRect.right));
        expect(textRect.top, greaterThanOrEqualTo(barRect.top));
        expect(textRect.bottom, lessThanOrEqualTo(barRect.bottom));
        expect(barRect.left, greaterThanOrEqualTo(0));
        expect(barRect.right, lessThanOrEqualTo(320));
      });
    });
  }
}
