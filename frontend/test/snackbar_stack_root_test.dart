// #353 root app: a new notice replaces the shown and queued snack bars
// (clearSnackBars) instead of waiting behind them.
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'fixtures/original_link_launcher.dart';
import 'fixtures/weekly_server.dart';
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;
import 'support/original_link_preview.dart';

const _stage0 = '콘텐츠를 5개 이상 저장하면 오늘의 추천을 볼 수 있어요.';
const _empty = '오늘 추천할 콘텐츠가 없어요. 나중에 다시 확인해 주세요.';
const _weekly = '이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.';
const _contactError = '문의하기를 열지 못했어요. 다시 시도해 주세요.';
const _privacyError = '이용약관 및 개인정보를 열지 못했어요. 다시 시도해 주세요.';

/// One 100 ms sample: the snack bar shown on screen, if any.
typedef _Shown = ({Key? key, String? text});

_Shown _shown(WidgetTester t) {
  final bars = t.widgetList<SnackBar>(find.byType(SnackBar)).toList();
  expect(bars.length, lessThanOrEqualTo(1));
  if (bars.isEmpty) return (key: null, text: null);
  return (key: bars.single.key, text: (bars.single.content as Text).data);
}

Future<List<_Shown>> _watch(WidgetTester t, Duration total) async {
  final seen = <_Shown>[];
  for (var i = 0; i < total.inMilliseconds ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
    seen.add(_shown(t));
  }
  return seen;
}

/// Distinct snack bars in the order they appeared.
List<_Shown> _bars(List<_Shown> seen) {
  final bars = <_Shown>[];
  for (final s in seen) {
    if (s.key != null && !bars.any((b) => b.key == s.key)) bars.add(s);
  }
  return bars;
}

/// After [last] leaves the screen, no snack bar comes back.
void _endsWith(List<_Shown> seen, _Shown last) {
  final end = seen.lastIndexWhere((s) => s.key == last.key);
  expect(end, isNonNegative);
  expect(seen.skip(end + 1), everyElement((key: null, text: null)));
  expect(seen.length - end, greaterThan(100), reason: 'watched 10 s after');
}

HomeScreen _home(WidgetTester t) =>
    t.widget<HomeScreen>(find.byType(HomeScreen));

Future<void> _withHome(
  WidgetTester t,
  Future<void> Function(WeeklyServer) check, {
  String weeklyMode = 'normal',
}) async {
  final server = WeeklyServer()..weeklyMode = weeklyMode;
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
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

void main() {
  testWidgets('five today taps leave only the last notice, then nothing', (
    t,
  ) async {
    await _withHome(t, (s) async {
      s.mode = 'stage0';
      final today = find.text('오늘의 콘텐츠 보기 →');
      for (var i = 0; i < 4; i++) {
        await t.tap(today);
        await _watch(t, const Duration(milliseconds: 100));
      }
      await t.tap(today);
      final after = await _watch(t, const Duration(seconds: 30));
      expect(
        s.calls.where((c) => c['path'] == '/api/v1/recommendations/today'),
        hasLength(5),
      );
      final bars = _bars(after);
      // After the last tap only the fourth bar's exit animation and the fifth
      // notice show; nothing that was queued earlier follows.
      expect(bars, hasLength(lessThanOrEqualTo(2)));
      expect(bars.map((b) => b.text), everyElement(_stage0));
      _endsWith(after, bars.last);
      // About 4 s after the last tap, not ~23 s.
      expect(after.lastIndexWhere((s) => s.key != null), lessThan(60));
    });
  });

  testWidgets('a notice with a button gives way to the next notice for good', (
    t,
  ) async {
    await _withHome(t, weeklyMode: 'error', (s) async {
      expect(find.text(_weekly), findsOneWidget);
      // With nothing else arriving it stays until the user closes it.
      final alone = await _watch(t, const Duration(seconds: 30));
      expect(_bars(alone), hasLength(1));
      expect(alone.last.text, _weekly);
      expect(find.byType(SnackBarAction), findsOneWidget);

      s.mode = 'stage0';
      _home(t).onOpenToday();
      final seen = await _watch(t, const Duration(seconds: 30));
      final bars = _bars(seen);
      expect(bars.map((b) => b.text), [_weekly, _stage0]);
      // The weekly notice leaves through its exit animation (~0.26 s).
      expect(
        seen.lastIndexWhere((s) => s.text == _weekly),
        inInclusiveRange(1, 4),
      );
      _endsWith(seen, bars.last);
      expect(find.byType(SnackBarAction), findsNothing);
    });
  });

  testWidgets('a notice arriving during an exit drops the queued middle one', (
    t,
  ) async {
    await _withHome(t, (s) async {
      s.mode = 'stage0';
      _home(t).onOpenToday();
      final seen = await _watch(t, const Duration(seconds: 1));
      s.mode = 'empty';
      _home(t).onOpenToday();
      seen.addAll(await _watch(t, const Duration(milliseconds: 100)));
      s.mode = 'stage0';
      _home(t).onOpenToday();
      seen.addAll(await _watch(t, const Duration(seconds: 30)));
      final bars = _bars(seen);
      expect(bars.map((b) => b.text), [_stage0, _stage0]);
      expect(seen.where((s) => s.text == _empty), isEmpty);
      _endsWith(seen, bars.last);
    });
  });

  testWidgets('my privacy failure replaces the contact failure notice', (
    t,
  ) async {
    final server = OriginalLinkPreviewServer()..reset('link');
    final old = UrlLauncherPlatform.instance;
    final launcher = RecordingUrlLauncher()..accepted = false;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = old);
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await http.runWithClient(() async {
      try {
        await t.pumpWidget(
          ClipbackApp(
            sessionStorage: isolated.ArchiveAllMemoryStorage(),
            socialAuth: isolated.ArchiveAllSocialAuth(),
          ),
        );
        await completeAppStartup(t);
        await t.tap(
          find.descendant(
            of: find.byType(ClipbackNavigationBar),
            matching: find.text('마이'),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(MyScreen), findsOneWidget);
        await t.ensureVisible(find.text('이용약관 및 개인정보'));
        await t.pumpAndSettle();

        await t.tap(find.text('문의하기'));
        final seen = await _watch(t, const Duration(seconds: 1));
        expect(seen.last.text, _contactError);
        await t.tap(find.text('이용약관 및 개인정보'));
        final after = await _watch(t, const Duration(seconds: 30));
        expect(_bars(after).map((b) => b.text), [_contactError, _privacyError]);
        expect(
          after.lastIndexWhere((s) => s.text == _contactError),
          inInclusiveRange(1, 4),
        );
        _endsWith(after, _bars(after).last);
        expect(launcher.calls, hasLength(2));
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        server.previewClient.close();
        server.client.close();
      }
    }, () => server.previewClient);
  });
}
