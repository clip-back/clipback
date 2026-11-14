// #354 root app: snack bar notices use Pretendard; the rest of the theme and
// the SnackBarAction label keep their fonts.
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'fixtures/original_link_launcher.dart';
import 'fixtures/weekly_server.dart';
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;

const _stage0 = '콘텐츠를 5개 이상 저장하면 오늘의 추천을 볼 수 있어요.';
const _weekly = '이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.';
const _contactError = '문의하기를 열지 못했어요. 다시 시도해 주세요.';

Future<void> _withApp(
  WidgetTester t,
  Future<void> Function(WeeklyServer) check, {
  String weeklyMode = 'normal',
  double width = 393,
  double scale = 1,
}) async {
  final server = WeeklyServer()..weeklyMode = weeklyMode;
  final old = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = RecordingUrlLauncher()..accepted = false;
  addTearDown(() => UrlLauncherPlatform.instance = old);
  t.view.physicalSize = Size(width, 852);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await http.runWithClient(() async {
    try {
      await t.pumpWidget(
        ClipbackApp(
          sessionStorage: isolated.ArchiveAllMemoryStorage(),
          socialAuth: isolated.ArchiveAllSocialAuth(),
        ),
      );
      await completeAppStartup(t);
      await check(server);
      expect(t.takeException(), isNull);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  }, () => server.weeklyClient);
}

TextStyle _style(WidgetTester t, String text) =>
    t.renderObject<RenderParagraph>(find.text(text)).text.style!;

ThemeData _appTheme(WidgetTester t) =>
    Theme.of(t.element(find.byType(ClipbackNavigationBar)));

/// The notice text is Pretendard 14 in the current color; every other value
/// is the theme's bodyMedium, and the theme's own fonts stay as they were.
void _expectNoticeFont(WidgetTester t, String text) {
  final theme = _appTheme(t), body = theme.textTheme.bodyMedium!;
  final style = _style(t, text);
  expect(style.fontFamily, 'Pretendard');
  expect(style.fontSize, 14);
  expect(style.color, theme.colorScheme.onInverseSurface);
  expect(style.fontWeight, body.fontWeight);
  expect(style.height, body.height);
  expect(style.letterSpacing, body.letterSpacing);
  // "테마 전체는 고치지 않는다" (2026-11-14): test default font.
  expect(body.fontFamily, 'Roboto');
  expect(theme.textTheme.labelLarge!.fontFamily, 'Roboto');
}

Future<void> _openMy(WidgetTester t) async {
  await t.tap(
    find.descendant(
      of: find.byType(ClipbackNavigationBar),
      matching: find.text('마이'),
    ),
  );
  await t.pumpAndSettle();
  await t.ensureVisible(find.text('문의하기'));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  testWidgets('my contact failure notice is Pretendard 14', (t) async {
    await _withApp(t, (s) async {
      await _openMy(t);
      await t.tap(find.text('문의하기'));
      await t.pumpAndSettle();
      _expectNoticeFont(t, _contactError);
    });
  });

  testWidgets('MessageEffect notice is Pretendard 14', (t) async {
    await _withApp(t, (s) async {
      s.mode = 'stage0';
      t.widget<HomeScreen>(find.byType(HomeScreen)).onOpenToday();
      await t.pumpAndSettle();
      _expectNoticeFont(t, _stage0);
    });
  });

  testWidgets('SnackBarAction label keeps the theme labelLarge font', (
    t,
  ) async {
    await _withApp(t, weeklyMode: 'error', (s) async {
      _expectNoticeFont(t, _weekly);
      final label = _style(t, '다시 시도');
      expect(label.fontFamily, 'Roboto');
      expect(label.fontSize, _appTheme(t).textTheme.labelLarge!.fontSize);
    });
  });

  // Longest fixed notices: app_view_model.dart (no button) and
  // content_actions.dart (button). Shown on the app's own messenger and theme
  // in the same shape as the app's MessageEffect snack bar.
  for (final (message, action) in [
    ('공유 인증 차단을 다시 확인해야 해요. 기기에서 철회한 로그인은 종료합니다.', null),
    ('저장은 완료됐지만 카테고리 목록을 새로 불러오지 못했어요', '다시 불러오기'),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Pretendard notice ${action ?? 'no button'} ${scale}x '
          'width 320 is not clipped', (t) async {
        await _withApp(t, width: 320, scale: scale, (s) async {
          ScaffoldMessenger.of(t.element(find.byType(HomeScreen))).showSnackBar(
            SnackBar(
              content: Text(message),
              action: action == null
                  ? null
                  : SnackBarAction(label: action, onPressed: () {}),
            ),
          );
          await t.pumpAndSettle();
          _expectNoticeFont(t, message);
          final paragraph = t.renderObject<RenderParagraph>(find.text(message));
          expect(paragraph.textScaler.scale(10), closeTo(10 * scale, .01));
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.size.height,
            closeTo(paragraph.getMinIntrinsicHeight(paragraph.size.width), .1),
          );
          final bar = t.getRect(find.byType(SnackBar));
          expect(bar.left, greaterThanOrEqualTo(0));
          expect(bar.right, lessThanOrEqualTo(320));
          for (final text in [message, ?action]) {
            final rect = t.getRect(find.text(text));
            expect(rect.left, greaterThanOrEqualTo(bar.left));
            expect(rect.right, lessThanOrEqualTo(bar.right));
            expect(rect.top, greaterThanOrEqualTo(bar.top));
            expect(rect.bottom, lessThanOrEqualTo(bar.bottom));
          }
          if (action != null) {
            final label = t.renderObject<RenderParagraph>(find.text(action));
            expect(label.didExceedMaxLines, isFalse);
          }
        });
      });
    }
  }
}
