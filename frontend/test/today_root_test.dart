import 'dart:async';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/material.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'fixtures/today_server.dart';
import 'support/archive_all_preview.dart' as isolated;
import 'support/app_startup.dart';

Future<void> withHome(
  WidgetTester t,
  Future<void> Function(TodayServer) check, {
  Future<http.Response?> Function(TodayServer, http.Request)? intercept,
  Size size = const Size(393, 852),
}) async {
  final server = TodayServer();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = MockClient((request) async {
    final handled = await intercept?.call(server, request);
    if (handled != null) return handled;
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return server.todayClient.send(copy).then(http.Response.fromStream);
  });
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
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  }, () => client);
}

HomeScreen home(WidgetTester t) =>
    t.widget<HomeScreen>(find.byType(HomeScreen));
DetailScreen detail(WidgetTester t) =>
    t.widget<DetailScreen>(find.byType(DetailScreen));
Iterable<Map<String, dynamic>> views(TodayServer s) =>
    s.calls.where((c) => (c['path'] as String).endsWith('/view'));
void main() {
  testWidgets(
    'Today uses independent server sequence and recommendation view identity',
    (t) async {
      await withHome(t, (s) async {
        expect(
          s.calls.where((c) => c['path'] == '/api/v1/recommendations/today'),
          isEmpty,
        );
        home(t).onOpenToday();
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 606);
        expect(detail(t).contents.map((i) => i.apiId), [
          606,
          604,
          602,
          605,
          603,
        ]);
        expect(
          views(s).single['body'],
          containsPair('recommendation_item_id', 1306),
        );
        final id = (views(s).single['body'] as Map)['client_event_id'];
        expect(
          id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        detail(t).onOpenAdjacent(1);
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 604);
        expect(
          views(s).last['body'],
          containsPair('recommendation_item_id', 1304),
        );
        expect((views(s).last['body'] as Map)['client_event_id'], isNot(id));
        detail(t).onBack();
        await t.pumpAndSettle();
        expect(home(t).contents.map((i) => i.apiId), [601, 602, 603, 604]);
        expect(
          s.calls.where(
            (c) => c['path'] == '/api/v1/recommendations/exposures',
          ),
          isEmpty,
        );
      });
    },
  );
  testWidgets('no recommendation and failure stay home, manual retry works', (
    t,
  ) async {
    await withHome(t, (s) async {
      for (final mode in ['stage0', 'empty', 'error']) {
        s.mode = mode;
        home(t).onOpenToday();
        await t.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(views(s), isEmpty);
      }
      s.mode = 'normal';
      home(t).onOpenToday();
      await t.pumpAndSettle();
      expect(detail(t).content.apiId, 606);
    });
  });
  testWidgets(
    'pending duplicate and leave-home/reenter invalidate old completion',
    (t) async {
      await withHome(t, (s) async {
        s.pending = Completer<void>();
        final h = home(t);
        h.onOpenToday();
        h.onOpenToday();
        await t.pump();
        expect(
          s.calls.where((c) => c['path'] == '/api/v1/recommendations/today'),
          hasLength(1),
        );
        h.onTab(AppRoute.archive);
        await t.pumpAndSettle();
        s.pending!.complete();
        await t.pumpAndSettle();
        expect(find.byType(DetailScreen), findsNothing);
        expect(views(s), isEmpty);
      });
    },
  );

  testWidgets('404 preflight stays home, no ordinary fallback or view', (
    t,
  ) async {
    await withHome(t, (s) async {
      s.missing.add(606);
      home(t).onOpenToday();
      await t.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('이 콘텐츠는 더 이상 볼 수 없어요.'), findsOneWidget);
      expect(views(s), isEmpty);
      expect(
        s.calls.where((c) => c['path'] == '/api/v1/contents/604'),
        isEmpty,
      );
      s.missing.clear();
      home(t).onOpenToday();
      await t.pumpAndSettle();
      expect(detail(t).content.apiId, 606);
    });
  });
  testWidgets(
    'missing adjacent is removed without replacing current, old callbacks cannot move',
    (t) async {
      await withHome(t, (s) async {
        home(t).onOpenToday();
        await t.pumpAndSettle();
        final old = detail(t);
        s.missing.add(604);
        old.onOpenAdjacent(1);
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 606);
        expect(detail(t).contents.map((c) => c.apiId), [606, 602, 605, 603]);
        expect(views(s), hasLength(1));
        detail(t).onOpenAdjacent(1);
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 602);
        old.onOpenAdjacent(1);
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 602);
        detail(t).onOpenAdjacent(-1);
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 606);
        expect(views(s), hasLength(3));
        expect(
          views(s).map((c) => (c['body'] as Map)['client_event_id']).toSet(),
          hasLength(3),
        );
      });
    },
  );
  testWidgets(
    'save sheet opened then closed invalidates pending home request',
    (t) async {
      await withHome(t, (s) async {
        s.pending = Completer<void>();
        home(t).onOpenToday();
        await t.pump();
        await t.tap(find.byType(NavAddButton));
        await t.pumpAndSettle();
        expect(find.byType(AddContentSheet), findsOneWidget);
        s.pending!.complete();
        await t.pumpAndSettle();
        expect(find.byType(DetailScreen), findsNothing);
        expect(views(s), isEmpty);
        Navigator.of(t.element(find.byType(AddContentSheet))).pop();
        await t.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        home(t).onOpenToday();
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 606);
      });
    },
  );
  testWidgets('late preflight after leaving home never opens or records', (
    t,
  ) async {
    final pending = Completer<http.Response>();
    await withHome(
      t,
      (s) async {
        final old = home(t);
        old.onOpenToday();
        await t.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(views(s), isEmpty);
        old.onTab(AppRoute.archive);
        await t.pumpAndSettle();
        pending.complete(s.json(s.records.last));
        await t.pumpAndSettle();
        expect(find.byType(DetailScreen), findsNothing);
        expect(views(s), isEmpty);
      },
      intercept: (s, r) async =>
          r.url.path == '/api/v1/contents/606' ? await pending.future : null,
    );
  });
  testWidgets(
    'today context survives bookmark refresh, ordinary view has no attribution',
    (t) async {
      await withHome(t, (s) async {
        home(t).onOpenToday();
        await t.pumpAndSettle();
        final current = detail(t);
        current.onToggleBookmark(current.content);
        await t.pumpAndSettle();
        expect(detail(t).bookmarked, isTrue);
        expect(detail(t).contents.map((c) => c.apiId), [
          606,
          604,
          602,
          605,
          603,
        ]);
        expect(
          s.calls.where((c) => c['path'] == '/api/v1/recommendations/today'),
          hasLength(1),
        );
        detail(t).onBack();
        await t.pumpAndSettle();
        final h = home(t);
        h.onOpenContent(h.contents.first);
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 601);
        expect(views(s).last.containsKey('body'), isFalse);
      });
    },
  );
  testWidgets(
    'gapped rank order, five ends, one item, next-day fresh selection',
    (t) async {
      await withHome(t, (s) async {
        s.ids = [606, 604, 602];
        s.ranks = [1, 3, 5];
        home(t).onOpenToday();
        await t.pumpAndSettle();
        expect(detail(t).contents.map((c) => c.apiId), [606, 604, 602]);
        detail(t).onOpenAdjacent(-1);
        await t.pumpAndSettle();
        expect(views(s), hasLength(1));
        for (var i = 0; i < 3; i++) {
          detail(t).onOpenAdjacent(1);
          await t.pumpAndSettle();
        }
        expect(detail(t).content.apiId, 602);
        expect(views(s), hasLength(3));
        detail(t).onBack();
        await t.pumpAndSettle();
        s.date = '2026-10-22';
        s.ids = [605];
        s.ranks = [4];
        home(t).onOpenToday();
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 605);
        expect(detail(t).contents, hasLength(1));
        detail(t).onOpenAdjacent(1);
        detail(t).onOpenAdjacent(-1);
        await t.pumpAndSettle();
        expect(views(s), hasLength(4));
        expect(
          s.calls.where((c) => c['path'] == '/api/v1/recommendations/today'),
          hasLength(2),
        );
      });
    },
  );
  testWidgets('statistics rejection does not fail recommendation navigation', (
    t,
  ) async {
    await withHome(
      t,
      (s) async {
        home(t).onOpenToday();
        await t.pumpAndSettle();
        expect(detail(t).content.apiId, 606);
        expect(t.takeException(), isNull);
      },
      intercept: (s, r) async => r.url.path.endsWith('/view')
          ? s.json({'detail': 'metric failed'}, 503)
          : null,
    );
  });
}
