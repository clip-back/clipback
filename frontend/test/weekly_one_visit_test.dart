import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/home/notification_list_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_navigation.dart';
import 'fixtures/weekly_server.dart';
import 'support/archive_all_preview.dart' as isolated;

// #379: one weekly visit per account and app process. The app start loads it
// before home is shown (15s bound), and leaving home keeps it. Only server
// requests, visible widgets and HomeScreen arguments/callbacks are asserted.

const _weeklyPath = '/api/v1/recommendations/weekly';
const _exposurePath = '/api/v1/recommendations/exposures';
const _failure = '이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.';
const _loading = ValueKey('home-initial-loading-screen');

class _Log {
  final requests = <http.Request>[];
  int get weeklyGets => requests
      .where((r) => r.method == 'GET' && r.url.path == _weeklyPath)
      .length;
  List<int> get exposedItems => [
    for (final r in requests.where((r) => r.url.path == _exposurePath))
      (jsonDecode(r.body) as Map)['recommendation_item_id'] as int,
  ];
}

/// The real [ClipbackApp] on [WeeklyServer]; the caller drives the launch.
Future<void> _withApp(
  WidgetTester t,
  Future<void> Function(WeeklyServer, _Log) check, {
  void Function(WeeklyServer)? setup,
  Future<http.Response?> Function(WeeklyServer, http.Request)? intercept,
}) async {
  final server = WeeklyServer();
  final log = _Log();
  setup?.call(server);
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = MockClient((request) async {
    log.requests.add(request);
    final handled = await intercept?.call(server, request);
    if (handled != null) return handled;
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return server.weeklyClient.send(copy).then(http.Response.fromStream);
  });
  await http.runWithClient(() async {
    try {
      await t.pumpWidget(
        ClipbackApp(
          sessionStorage: isolated.ArchiveAllMemoryStorage(),
          socialAuth: isolated.ArchiveAllSocialAuth(),
        ),
      );
      await check(server, log);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  }, () => client);
}

Finder get _home => find.byType(HomeScreen);
HomeScreen _screen(WidgetTester t) => t.widget<HomeScreen>(_home);
List<int> _items(WidgetTester t) =>
    _screen(t).weeklyItems.map((item) => item.id).toList();
Finder get _message => find.text(_failure);

/// Pumps 50ms frames until home is drawn, recording each home frame's cards.
Future<List<List<int>>> _launch(WidgetTester t, {int limitMs = 20000}) async {
  final homeFrames = <List<int>>[];
  for (var ms = 0; ms <= limitMs; ms += 50) {
    await t.pump(const Duration(milliseconds: 50));
    if (_home.evaluate().isNotEmpty) {
      homeFrames.add(_items(t));
      break;
    }
  }
  await t.pumpAndSettle();
  homeFrames.add(_items(t));
  return homeFrames;
}

/// Goes back to home and returns the cards of the first frame drawn there.
Future<List<int>> _returnHome(WidgetTester t, VoidCallback go) async {
  go();
  await t.pump();
  final first = _items(t);
  await t.pumpAndSettle();
  return first;
}

void main() {
  testWidgets(
    'app start: one weekly GET on the loading screen; home is first drawn with the cards',
    (t) async {
      final pending = Completer<void>();
      await _withApp(t, (s, log) async {
        await t.pump();
        expect(log.weeklyGets, 1, reason: 'requested while loading');
        // The 900ms minimum is over; the weekly response still holds home.
        await t.pump(const Duration(milliseconds: 1500));
        await t.pump();
        expect(_home, findsNothing);
        expect(find.byKey(_loading), findsOneWidget);
        expect(log.exposedItems, isEmpty);

        pending.complete();
        final frames = await _launch(t);
        expect(frames.first, [
          8011,
          8012,
        ], reason: 'no home frame without picks');
        expect(frames.last, [8011, 8012]);
        expect(log.weeklyGets, 1);
        expect(log.exposedItems..sort(), [8011, 8012]);
        expect(_message, findsNothing);
      }, setup: (s) => s.weeklyPending = pending);
    },
  );

  testWidgets(
    'app start waits 15s at most; the late success is ignored; retry asks once more',
    (t) async {
      final pending = Completer<void>();
      await _withApp(t, (s, log) async {
        await t.pump();
        await t.pump(const Duration(milliseconds: 14900));
        expect(_home, findsNothing);
        final frames = await _launch(t, limitMs: 1000);
        expect(frames.first, isEmpty);
        expect(find.text('이번주 허투루 픽 🎯'), findsNothing);
        expect(_message, findsOneWidget);
        expect(log.weeklyGets, 1);

        // The response after the deadline fills nothing and records nothing.
        pending.complete();
        await t.pumpAndSettle();
        expect(_items(t), isEmpty);
        expect(log.exposedItems, isEmpty);

        s.weeklyPending = null;
        await t.tap(find.text('다시 시도'));
        await t.pumpAndSettle();
        expect(log.weeklyGets, 2);
        expect(_items(t), [8021, 8022]);
        expect(_message, findsNothing);
      }, setup: (s) => s.weeklyPending = pending);
    },
  );

  testWidgets(
    'app start failure: home without picks, one notice; leaving and returning asks nothing',
    (t) async {
      await _withApp(t, (s, log) async {
        final frames = await _launch(t);
        expect(frames.first, isEmpty);
        expect(_message, findsOneWidget);
        expect(log.weeklyGets, 1);
        ScaffoldMessenger.of(
          t.element(_home),
        ).removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
        await t.pumpAndSettle();

        _screen(t).onTab(AppRoute.my);
        await t.pumpAndSettle();
        final first = await _returnHome(
          t,
          () => t.widget<MyScreen>(find.byType(MyScreen)).onTab(AppRoute.home),
        );
        expect(first, isEmpty);
        expect(log.weeklyGets, 1, reason: 'no automatic request');
        expect(_message, findsNothing, reason: 'shown once already');
      }, setup: (s) => s.weeklyMode = 'error');
    },
  );

  testWidgets(
    'a failure while away from home waits; one notice on return; its retry only from home',
    (t) async {
      await _withApp(t, (s, log) async {
        await _launch(t);
        expect(_message, findsOneWidget);
        final pending = Completer<void>();
        s.weeklyPending = pending;
        await t.tap(find.text('다시 시도'));
        await t.pump();
        expect(log.weeklyGets, 2);

        _screen(t).onTab(AppRoute.archive);
        await t.pumpAndSettle();
        pending.complete();
        await t.pumpAndSettle();
        expect(find.byType(ArchiveScreen), findsOneWidget);
        expect(_message, findsNothing, reason: 'deferred until home');

        await _returnHome(
          t,
          () => t
              .widget<ArchiveScreen>(find.byType(ArchiveScreen))
              .onTab(AppRoute.home),
        );
        expect(_message, findsOneWidget);
        final retry = t
            .widget<SnackBarAction>(find.byType(SnackBarAction))
            .onPressed;
        ScaffoldMessenger.of(
          t.element(_home),
        ).removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
        await t.pumpAndSettle();
        _screen(t).onTab(AppRoute.my);
        await t.pumpAndSettle();
        retry();
        await t.pumpAndSettle();
        expect(log.weeklyGets, 2, reason: 'the notice retries only from home');

        await _returnHome(
          t,
          () => t.widget<MyScreen>(find.byType(MyScreen)).onTab(AppRoute.home),
        );
        expect(_message, findsNothing);
        expect(log.weeklyGets, 2);
      }, setup: (s) => s.weeklyMode = 'error');
    },
  );

  testWidgets(
    'tabs, notifications and detail keep the visit: same cards from the first frame, no GET, no exposure',
    (t) async {
      await _withApp(t, (s, log) async {
        await _launch(t);
        expect(_items(t), [8011, 8012]);
        final exposed = log.exposedItems..sort();
        expect(exposed, [8011, 8012]);

        _screen(t).onTab(AppRoute.archive);
        await t.pumpAndSettle();
        expect(
          await _returnHome(
            t,
            () => t
                .widget<ArchiveScreen>(find.byType(ArchiveScreen))
                .onTab(AppRoute.home),
          ),
          [8011, 8012],
        );

        _screen(t).onTab(AppRoute.my);
        await t.pumpAndSettle();
        expect(
          await _returnHome(
            t,
            () =>
                t.widget<MyScreen>(find.byType(MyScreen)).onTab(AppRoute.home),
          ),
          [8011, 8012],
        );

        _screen(t).onOpenNotifications!();
        await t.pumpAndSettle();
        expect(
          await _returnHome(
            t,
            () => t
                .widget<NotificationListScreen>(
                  find.byType(NotificationListScreen),
                )
                .onBack(),
          ),
          [8011, 8012],
        );

        _screen(t).onOpenContent(_screen(t).contents.first);
        await t.pumpAndSettle();
        expect(
          await _returnHome(
            t,
            () => t.widget<DetailScreen>(find.byType(DetailScreen)).onBack(),
          ),
          [8011, 8012],
        );

        expect(log.weeklyGets, 1);
        expect(
          log.exposedItems,
          hasLength(2),
          reason: 'once per visit and card',
        );
      });
    },
  );

  testWidgets(
    'account change starts a new visit; old callbacks and responses do nothing',
    (t) async {
      await _withApp(
        t,
        (s, log) async {
          await _launch(t);
          final old = _screen(t);
          expect(_items(t), [8011, 8012]);
          final exposures = log.exposedItems.length;

          old.onTab(AppRoute.my);
          await t.pumpAndSettle();
          t.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
          await t.pumpAndSettle();
          await logoutFromAccount(t);
          await t.pumpAndSettle();
          expect(find.byType(LoginScreen), findsOneWidget);
          await startGuestAndFinishOnboarding(t);
          await t.pumpAndSettle();
          expect(_home, findsOneWidget);
          expect(log.weeklyGets, 2);
          expect(_items(t), [8021, 8022]);
          final current = log.exposedItems.length;

          old.onWeeklyExposed!(8011);
          old.onWeeklySelected!(old.weeklyItems.first);
          await t.pumpAndSettle();
          expect(log.exposedItems, hasLength(current));
          expect(
            log.exposedItems.skip(exposures),
            everyElement(isIn([8021, 8022])),
          );
          expect(find.byType(ArchiveScreen), findsNothing);
        },
        intercept: (s, request) async => switch (request.url.path) {
          '/api/v1/auth/logout' => http.Response('', 204),
          _ => null,
        },
      );
    },
  );

  testWidgets(
    'app removed during the app start wait: the late response changes nothing',
    (t) async {
      final pending = Completer<void>();
      await _withApp(t, (s, log) async {
        await t.pump();
        await t.pump(const Duration(milliseconds: 1500));
        expect(log.weeklyGets, 1);
        final requests = log.requests.length;
        await t.pumpWidget(const SizedBox.shrink());
        pending.complete();
        await t.pump(const Duration(seconds: 16));
        await t.pumpAndSettle();
        expect(log.requests, hasLength(requests));
        expect(log.exposedItems, isEmpty);
        expect(t.takeException(), isNull);
      }, setup: (s) => s.weeklyPending = pending);
    },
  );
}
