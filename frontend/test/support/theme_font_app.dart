// #391 root app on the home memory API, for font and overflow checks that
// must run on the app's own merged theme.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fixtures/home_base_alignment_fixture.dart';
import 'app_startup.dart';
import 'archive_all_preview.dart' as isolated;

const delayMessage = '서버 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.';

/// Loads the bundled Pretendard faces. [pretendardLoaded] then compares a
/// mixed Latin and Hangul run against the test font: equal widths mean the
/// faces did not load, and a check must not count as passing.
Future<void> loadPretendard() async {
  final fonts = FontLoader('Pretendard');
  for (final weight in ['Regular', 'Medium', 'SemiBold']) {
    fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
  }
  await fonts.load();
}

bool pretendardLoaded() {
  double width(String family) {
    final painter = TextPainter(
      text: TextSpan(
        text: '저장 Save 123',
        style: TextStyle(fontFamily: family, fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final value = painter.width;
    painter.dispose();
    return value;
  }

  return width('Pretendard') != width('FlutterTest');
}

/// Memory API: home data, an empty weekly pick, and every link save POST held
/// without a response (the app's 20 second limit then shows the delay notice).
class ThemeFontServer {
  final base = HomeBaseServer('normal');
  final held = <http.Request>[];

  /// Fails the My stats request, so My shows its stats retry button.
  bool failStats = false;
  late final client = MockClient((r) async {
    if (failStats && r.url.path == '/api/v1/users/me/stats') {
      return http.Response(
        jsonEncode({'detail': '통계 대역 실패'}),
        503,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (r.method == 'POST' && r.url.path == '/api/v1/contents') {
      held.add(r);
      return Completer<http.Response>().future;
    }
    if (r.url.path == '/api/v1/recommendations/weekly') {
      return http.Response(
        jsonEncode({
          'period_start': '2026-10-19T00:00:00Z',
          'period_end': '2026-10-26T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return base.client.send(copy).then(http.Response.fromStream);
  });
}

/// Runs [check] on the started root app at [width] and [scale].
Future<void> withThemeFontApp(
  WidgetTester t,
  Future<void> Function(ThemeFontServer server) check, {
  double width = 393,
  double scale = 1,
  TargetPlatform? platform,
  bool failStats = false,
}) async {
  final server = ThemeFontServer()..failStats = failStats;
  t.view.physicalSize = Size(width, 852);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  debugDefaultTargetPlatformOverride = platform;
  try {
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
        expect(server.base.unexpected, isEmpty);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      }
    }, () => server.client);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Shows [child] as a page on the root app's navigator, under its theme.
Future<void> showOnApp(WidgetTester t, Widget child) async {
  unawaited(
    Navigator.of(t.element(find.byType(HomeScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: Align(alignment: Alignment.topCenter, child: child),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

/// Types a valid link in the save sheet, saves, and waits out the app's limit.
Future<void> showDelayNotice(WidgetTester t, ThemeFontServer server) async {
  await t.tap(find.byType(NavAddButton));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), 'https://example.com/lt391');
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(find.text('허투루에 저장하기'));
  await t.pump();
  expect(server.held, hasLength(1));
  await t.pump(const Duration(seconds: 20));
  await t.pump();
}

RenderParagraph paragraph(WidgetTester t, String text) =>
    t.renderObject<RenderParagraph>(find.text(text));

/// Opens the My tab from the bottom navigation.
Future<void> openMy(WidgetTester t) async {
  await t.tap(
    find.descendant(
      of: find.byType(ClipbackNavigationBar),
      matching: find.text('마이'),
    ),
  );
  await t.pumpAndSettle();
}
