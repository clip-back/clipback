// #407 root app: every bottom notice uses the Figma C01 (428:4419) place and
// shape. It ends 32 above the screen bottom (or at the top of a taller
// system area), keeps 16 from both sides, and is drawn over the bottom tabs.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/notice_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'auth_navigation.dart';
import 'fixtures/original_link_launcher.dart';
import 'fixtures/weekly_server.dart';
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;
import 'support/login_alignment_preview.dart' as login;

const _stage0 = '콘텐츠를 5개 이상 저장하면 오늘의 추천을 볼 수 있어요.';
const _weekly = '이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.';
const _contactError = '문의하기를 열지 못했어요. 다시 시도해 주세요.';
const _guestLimit = '지금은 게스트로 시작할 수 없어요. 잠시 후 다시 시도해 주세요.';

void _view(WidgetTester t, Size size, double bottom, double scale) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.view.padding = FakeViewPadding(top: 59, bottom: bottom);
  t.view.viewPadding = FakeViewPadding(top: 59, bottom: bottom);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _run(
  WidgetTester t,
  http.Client client,
  Widget app,
  Future<void> Function() check,
) => http.runWithClient(() async {
  try {
    await t.pumpWidget(app);
    await completeAppStartup(t);
    await check();
    expect(t.takeException(), isNull);
  } finally {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  }
}, () => client);

Future<void> _withHome(
  WidgetTester t,
  Future<void> Function(WeeklyServer) check, {
  String weeklyMode = 'normal',
}) {
  final server = WeeklyServer()..weeklyMode = weeklyMode;
  final old = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = RecordingUrlLauncher()..accepted = false;
  addTearDown(() => UrlLauncherPlatform.instance = old);
  return _run(
    t,
    server.weeklyClient,
    ClipbackApp(
      sessionStorage: isolated.ArchiveAllMemoryStorage(),
      socialAuth: isolated.ArchiveAllSocialAuth(),
    ),
    () => check(server),
  );
}

Future<void> _showStage0(WidgetTester t, WeeklyServer s) async {
  s.mode = 'stage0';
  t.widget<HomeScreen>(find.byType(HomeScreen)).onOpenToday();
  await t.pumpAndSettle();
}

/// The notice box: the Material the SnackBar paints, without its margin.
Finder _box() => find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
    .first;

/// The notice text sits in the box 18 from its left (Figma 428:4569), the
/// box ends [bottomGap] above the screen bottom with 16 on both sides, and a
/// tap on its center reaches the notice even where the bottom tabs or the +
/// button lie under it.
void _expectPlace(WidgetTester t, String message, {double bottomGap = 32}) {
  final size = t.view.physicalSize / t.view.devicePixelRatio;
  final box = t.getRect(_box());
  expect(box.bottom, closeTo(size.height - bottomGap, .5));
  expect(box.left, closeTo(16, .5));
  expect(box.right, closeTo(size.width - 16, .5));
  final text = t.getRect(find.text(message));
  expect(box.contains(text.topLeft) && box.contains(text.bottomRight), isTrue);
  expect(text.left - box.left, closeTo(18, .5));
  final result = HitTestResult();
  t.binding.hitTestInView(result, box.center, t.view.viewId);
  final hit = result.path
      .map((entry) => entry.target)
      .whereType<RenderObject>()
      .first;
  final boxObject = t.renderObject(_box());
  RenderObject? node = hit;
  while (node != null && node != boxObject) {
    node = node.parent;
  }
  expect(node, boxObject, reason: 'the center tap reaches the notice');
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  for (final size in const [Size(375, 812), Size(430, 932)]) {
    for (final scale in const [1.0, 1.3]) {
      for (final bottom in const [34.0, 0.0]) {
        testWidgets('home stage0 notice ${size.width}x${size.height} '
            '${scale}x safe bottom $bottom ends 32 above the screen bottom '
            'over the tabs', (t) async {
          _view(t, size, bottom, scale);
          await _withHome(t, (s) async {
            await _showStage0(t, s);
            final box = t.getRect(_box());
            final nav = t.getRect(find.byType(ClipbackNavigationBar));
            final add = t.getRect(find.byType(NavAddButton));
            // Drawn over the tab row and the lower part of the + button.
            expect(box.overlaps(nav), isTrue);
            expect(box.overlaps(add), isTrue);
            _expectPlace(t, _stage0);
          });
        });
      }
    }
  }

  testWidgets('a system area taller than 34 keeps the notice above it', (
    t,
  ) async {
    _view(t, const Size(375, 812), 48, 1);
    await _withHome(t, (s) async {
      await _showStage0(t, s);
      _expectPlace(t, _stage0, bottomGap: 48);
    });
  });

  testWidgets('weekly failure notice with a retry button', (t) async {
    _view(t, const Size(375, 812), 34, 1);
    await _withHome(t, weeklyMode: 'error', (s) async {
      _expectPlace(t, _weekly);
      expect(find.text('다시 시도').hitTestable(), findsOneWidget);
      // 2026-11-17 decision "1번": two lines are 67 high like a notice
      // without a button; the Flutter button stays 8 from the box's right.
      final box = t.getRect(_box());
      expect(box.height, closeTo(67, .5));
      final button = t.getRect(
        find.ancestor(
          of: find.text('다시 시도'),
          matching: find.byType(TextButton),
        ),
      );
      expect(box.right - button.right, closeTo(8, .5));
    });
  });

  // 2026-11-17 decision "1번": a notice with a button is as high as one
  // without (text 16.5 from the top and bottom, by its line count) while
  // the button keeps its 48 tap height and its place 8 from the right.
  for (final width in const [375.0, 393.0, 430.0]) {
    for (final scale in const [1.0, 1.3]) {
      for (final (message, label) in const [
        ('최신 정보를 불러오지 못했어요.', '다시 불러오기'),
        (_weekly, '다시 시도'),
      ]) {
        testWidgets('button notice "$label" $width ${scale}x follows its '
            'line count', (t) async {
          _view(t, Size(width, 852), 34, scale);
          await _withHome(t, (s) async {
            final home = t.element(find.byType(HomeScreen));
            ScaffoldMessenger.of(home).showSnackBar(
              noticeSnackBar(
                home,
                message,
                action: SnackBarAction(label: label, onPressed: () {}),
              ),
            );
            await t.pumpAndSettle();
            final box = t.getRect(_box());
            final text = t.getRect(find.text(message));
            final paragraph = t.renderObject<RenderParagraph>(
              find.text(message),
            );
            final lines = paragraph
                .getBoxesForSelection(
                  TextSelection(baseOffset: 0, extentOffset: message.length),
                )
                .map((b) => b.top.round())
                .toSet()
                .length;
            final heights = {
              1.0: {1: 50.0, 2: 67.0},
              1.3: {1: 55.0, 2: 77.0},
            };
            expect(box.height, closeTo(heights[scale]![lines]!, .5));
            expect(text.top - box.top, closeTo(16.5, .5));
            expect(box.bottom - text.bottom, closeTo(16.5, .5));
            expect(text.left - box.left, closeTo(18, .5));
            final button = t.getRect(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(TextButton),
              ),
            );
            expect(button.height, closeTo(48, .5));
            expect(box.right - button.right, closeTo(8, .5));
            expect(paragraph.didExceedMaxLines, isFalse);
          });
        });
      }
    }
  }

  // The notice is over the bottom tabs but stays under modal routes and
  // their barriers, as before #407; it is kept, not removed, while they show.
  testWidgets('dialogs and bottom sheets stay over the notice', (t) async {
    _view(t, const Size(375, 812), 34, 1);
    await _withHome(t, weeklyMode: 'error', (s) async {
      final home = t.element(find.byType(HomeScreen));
      Future<void> check(String label) async {
        expect(find.text(label), findsOneWidget);
        expect(find.text(_weekly), findsOneWidget);
        expect(find.text('다시 시도').hitTestable(), findsNothing);
        Navigator.of(home).pop();
        await t.pumpAndSettle();
        expect(find.text('다시 시도').hitTestable(), findsOneWidget);
      }

      unawaited(
        showDialog<void>(
          context: home,
          builder: (_) => const AlertDialog(content: Text('dialog')),
        ),
      );
      await t.pumpAndSettle();
      await check('dialog');
      unawaited(
        showModalBottomSheet<void>(
          context: home,
          builder: (_) =>
              const SizedBox(height: 250, child: Center(child: Text('sheet'))),
        ),
      );
      await t.pumpAndSettle();
      await check('sheet');
    });
  });

  testWidgets('my screen external open failure notice', (t) async {
    _view(t, const Size(375, 812), 34, 1);
    await _withHome(t, (s) async {
      await t.tap(
        find.descendant(
          of: find.byType(ClipbackNavigationBar),
          matching: find.text('마이'),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('문의하기'));
      await t.pumpAndSettle();
      await t.tap(find.text('문의하기'));
      await t.pumpAndSettle();
      _expectPlace(t, _contactError);
    });
  });

  testWidgets('login guest limit notice leaves the guest label clear', (
    t,
  ) async {
    _view(t, const Size(375, 812), 34, 1);
    final server = login.LoginServer();
    final client = MockClient((r) async {
      if (r.url.path == '/api/v1/auth/guest') {
        return http.Response(
          jsonEncode({'detail': _guestLimit}),
          429,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return server.client.send(r).then(http.Response.fromStream);
    });
    await _run(
      t,
      client,
      ClipbackApp(
        sessionStorage: login.LoginMemoryStorage(),
        socialAuth: login.LoginControlledSocial(TargetPlatform.iOS),
      ),
      () async {
        await performLoginChoice(
          t,
          t.widget<LoginScreen>(find.byType(LoginScreen)).onContinue,
        );
        await t.pumpAndSettle();
        _expectPlace(t, _guestLimit);
        // The notice stays below the visible guest label (2026-11-17
        // decision); a two-line notice still meets the lower 10 of its
        // 44-high tap area.
        final label = t.getRect(find.text('게스트로 시작하기'));
        expect(t.getRect(_box()).top, greaterThanOrEqualTo(label.bottom));
      },
    );
  });

  testWidgets('notice shape: #484848 95%, radius 8, Pretendard Medium 14 '
      'white, one line 50 high', (t) async {
    _view(t, const Size(375, 812), 34, 1);
    await _withHome(t, (s) async {
      await _showStage0(t, s);
      final material = t.widget<Material>(_box());
      expect(material.color, const Color(0xFF484848).withValues(alpha: .95));
      expect(
        material.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      );
      final style = t
          .renderObject<RenderParagraph>(find.text(_stage0))
          .text
          .style!;
      expect(style.fontFamily, 'Pretendard');
      expect(style.fontWeight, FontWeight.w500);
      expect(style.fontSize, 14);
      expect(style.color, Colors.white);
      // One line: text 18 from the box's left, box 50 high (Figma 428:4568).
      final box = t.getRect(_box()), text = t.getRect(find.text(_stage0));
      expect(text.left - box.left, closeTo(18, .5));
      expect(box.height, closeTo(50, .5));
      expect(text.center.dy, closeTo(box.center.dy, .5));
    });
  });
}
