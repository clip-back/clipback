import 'dart:async';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/shared/models/app_info.dart';
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

const _privacyUrl = 'https://huturu-app.github.io/privacy';
const _privacyError = '이용약관 및 개인정보를 열지 못했어요. 다시 시도해 주세요.';

Finder get _privacy => find.text('이용약관 및 개인정보');
Finder get _licenses => find.text('오픈소스 라이선스');

Future<void> _withMy(
  WidgetTester tester,
  Future<void> Function(RecordingUrlLauncher) check, {
  double width = 393,
  double height = 852,
  double scale = 1,
}) async {
  final server = OriginalLinkPreviewServer()..reset('link');
  final old = UrlLauncherPlatform.instance, launcher = RecordingUrlLauncher();
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = old);
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(
          appInfo: const AppInfo(version: '9.8.7', buildNumber: '42'),
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
      await tester.scrollUntilVisible(
        _licenses,
        100,
        scrollable: find
            .descendant(
              of: find.byType(MyScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
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

void _expectPrivacyOpens(RecordingUrlLauncher launcher, int times) {
  expect(launcher.calls, hasLength(times));
  for (final call in launcher.calls) {
    expect(call.url, _privacyUrl);
    expect(call.options.mode, PreferredLaunchMode.externalApplication);
  }
}

void main() {
  testWidgets('my privacy row opens the policy once without a sheet', (
    tester,
  ) async {
    await _withMy(tester, (launcher) async {
      launcher.pending = Completer<bool>();
      await tester.tap(_privacy);
      await tester.pump();
      await tester.tap(_privacy);
      await tester.pump();
      _expectPrivacyOpens(launcher, 1);
      expect(find.byType(BottomSheet), findsNothing);
      launcher.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(MyScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      _expectPrivacyOpens(launcher, 1);
    });
  });

  for (final refusal in ['os-false', 'exception']) {
    testWidgets('my privacy row $refusal shows message and retries on tap', (
      tester,
    ) async {
      await _withMy(tester, (launcher) async {
        if (refusal == 'os-false') {
          launcher.accepted = false;
        } else {
          launcher.failure = PlatformException(code: 'launch_failed');
        }
        await tester.tap(_privacy);
        await tester.pumpAndSettle();
        expect(find.text(_privacyError), findsOneWidget);
        expect(find.byType(MyScreen), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        launcher
          ..accepted = true
          ..failure = null;
        await tester.tap(_privacy);
        await tester.pumpAndSettle();
        _expectPrivacyOpens(launcher, 2);
        expect(find.byType(MyScreen), findsOneWidget);
      });
    });
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('privacy failure message ${scale}x width 320 is not clipped', (
      tester,
    ) async {
      await _withMy(tester, width: 320, scale: scale, (launcher) async {
        launcher.accepted = false;
        await tester.tap(_privacy);
        await tester.pumpAndSettle();
        final text = find.text(_privacyError);
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        // Same measurement as the contact failure message (#336).
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

  testWidgets('my licenses row opens the license page and returns to My', (
    tester,
  ) async {
    await _withMy(tester, height: 480, (launcher) async {
      final position = Scrollable.of(tester.element(_licenses)).position;
      final offset = position.pixels;
      expect(offset, greaterThan(0));
      await tester.tap(_licenses);
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('허투루'), findsOneWidget);
      expect(find.text('9.8.7'), findsOneWidget);
      final pretendard = find.text('Pretendard');
      await tester.scrollUntilVisible(
        pretendard,
        200,
        scrollable: find
            .descendant(
              of: find.byType(LicensePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(pretendard);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('SIL Open Font License', findRichText: true),
        findsWidgets,
      );
      expect(launcher.calls, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsNothing);
      expect(find.byType(MyScreen), findsOneWidget);
      expect(Scrollable.of(tester.element(_licenses)).position.pixels, offset);
    });
  });
}
