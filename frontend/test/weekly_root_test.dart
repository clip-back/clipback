import 'dart:async';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/material.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fixtures/weekly_server.dart';
import 'support/archive_all_preview.dart' as isolated;
import 'support/app_startup.dart';

Future<void> withHome(
  WidgetTester t,
  Future<void> Function(WeeklyServer) check, {
  Future<http.Response?> Function(WeeklyServer, http.Request)? intercept,
  void Function(WeeklyServer)? setup,
  Size size = const Size(393, 852),
}) async {
  final server = WeeklyServer();
  setup?.call(server);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = MockClient((request) async {
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
Iterable<Map<String, dynamic>> views(WeeklyServer s) =>
    s.calls.where((c) => (c['path'] as String).endsWith('/view'));
ArchiveScreen archive(WidgetTester t) =>
    t.widget<ArchiveScreen>(find.byType(ArchiveScreen));
Iterable<Map<String, dynamic>> weekly(WeeklyServer s) =>
    s.calls.where((c) => c['path'] == '/api/v1/recommendations/weekly');
Iterable<Map<String, dynamic>> exposures(WeeklyServer s) =>
    s.calls.where((c) => c['path'] == '/api/v1/recommendations/exposures');
void main() {
  testWidgets(
    'home fetches once, displays real server categories; only visible cards exposed',
    (t) async {
      await withHome(t, (s) async {
        expect(weekly(s), hasLength(1));
        expect(find.text('공지사항'), findsNothing);
        expect(home(t).weeklyItems.map((c) => c.category.id), [102, 101]);
        expect(exposures(s), hasLength(2));
        expect(views(s), isEmpty);
        final h = home(t);
        h.onCategorySelected!(h.categories.first);
        await t.pumpAndSettle();
        expect(weekly(s), hasLength(1));
        expect(exposures(s), hasLength(2));
        final scroll = find.byKey(const ValueKey('home-scroll'));
        await t.drag(scroll, const Offset(0, -400));
        await t.pumpAndSettle();
        await t.drag(scroll, const Offset(0, 400));
        await t.pumpAndSettle();
        expect(exposures(s), hasLength(2));
      });
    },
  );
  testWidgets(
    'ID category destination, attributed details, F01 return and fresh home visit',
    (t) async {
      await withHome(t, (s) async {
        final h = home(t);
        final item = h.weeklyItems.first;
        final firstExposure =
            (exposures(s).first['body'] as Map)['client_event_id'];
        h.onWeeklySelected!(item);
        await t.pumpAndSettle();
        expect(archive(t).activeCategoryName, '여행');
        expect(archive(t).feed!.categoryId, 102);
        expect(views(s), isEmpty);
        archive(t).onOpenContent(archive(t).contents.first);
        await t.pumpAndSettle();
        expect(
          (views(s).last['body'] as Map)['recommendation_item_id'],
          item.id,
        );
        detail(t).onBack();
        await t.pumpAndSettle();
        expect(archive(t).feed!.categoryId, 102);
        archive(t).onClearCategory();
        await t.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(weekly(s), hasLength(2));
        expect(exposures(s), hasLength(4));
        expect(
          (exposures(s).last['body'] as Map)['client_event_id'],
          isNot(firstExposure),
        );
        home(t).onTab(AppRoute.archive);
        await t.pumpAndSettle();
        archive(t).onOpenContent(archive(t).contents.first);
        await t.pumpAndSettle();
        expect(views(s).last.containsKey('body'), isFalse);
      });
    },
  );
  testWidgets(
    'sheet and background retain visit; delivery behind either records no exposure',
    (t) async {
      final pending = Completer<void>();
      await withHome(t, (s) async {
        t
            .widget<ClipbackNavigationBar>(find.byType(ClipbackNavigationBar))
            .onAdd!();
        await t.pumpAndSettle();
        pending.complete();
        await t.pumpAndSettle();
        expect(exposures(s), isEmpty);
        final context = t.element(find.byType(SaveContentTopBar));
        Navigator.of(context).pop();
        await t.pumpAndSettle();
        expect(weekly(s), hasLength(1));
        expect(exposures(s), hasLength(2));
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await t.pumpAndSettle();
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(weekly(s), hasLength(1));
        expect(exposures(s), hasLength(2));
      }, setup: (s) => s.weeklyPending = pending);
    },
  );
  testWidgets(
    'background pending delivery waits until foreground; old visit response ignored',
    (t) async {
      final pending = Completer<void>();
      await withHome(t, (s) async {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await t.pumpAndSettle();
        pending.complete();
        await t.pumpAndSettle();
        expect(exposures(s), isEmpty);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(exposures(s), hasLength(2));
        final old = home(t);
        old.onTab(AppRoute.archive);
        await t.pumpAndSettle();
        s.weeklyPending = Completer<void>();
        archive(t).onTab(AppRoute.home);
        await t.pumpAndSettle();
        expect(home(t).weeklyItems, isEmpty);
        home(t).onTab(AppRoute.my);
        await t.pumpAndSettle();
        s.weeklyPending!.complete();
        await t.pumpAndSettle();
        expect(exposures(s), hasLength(2));
        old.onWeeklySelected!(old.weeklyItems.first);
        await t.pumpAndSettle();
        expect(find.byType(ArchiveScreen), findsNothing);
      }, setup: (s) => s.weeklyPending = pending);
    },
  );
  testWidgets(
    'failed/empty query hides entire section; owned manual retry only',
    (t) async {
      await withHome(t, (s) async {
        expect(find.text('이번주 허투루 픽 🎯'), findsNothing);
        expect(find.text('이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
        final retry = t
            .widget<SnackBarAction>(find.byType(SnackBarAction))
            .onPressed;
        s.weeklyMode = 'empty';
        retry();
        retry();
        await t.pumpAndSettle();
        expect(weekly(s), hasLength(2));
        expect(find.text('이번주 허투루 픽 🎯'), findsNothing);
        expect(exposures(s), isEmpty);
        home(t).onTab(AppRoute.my);
        await t.pumpAndSettle();
        retry();
        await t.pumpAndSettle();
        expect(weekly(s), hasLength(2));
      }, setup: (s) => s.weeklyMode = 'error');
    },
  );
  testWidgets(
    'Weekly category switching/search clear origin; Today uses its own item IDs',
    (t) async {
      await withHome(t, (s) async {
        final h = home(t);
        h.onWeeklySelected!(h.weeklyItems.first);
        await t.pumpAndSettle();
        archive(t).onOpenCategory(archive(t).categories.first);
        await t.pumpAndSettle();
        archive(t).onOpenContent(archive(t).contents.first);
        await t.pumpAndSettle();
        expect(views(s).last.containsKey('body'), isFalse);
        detail(t).onBack();
        await t.pumpAndSettle();
        archive(t).onTab(AppRoute.home);
        await t.pumpAndSettle();
        home(t).onOpenToday();
        await t.pumpAndSettle();
        expect((views(s).last['body'] as Map)['recommendation_item_id'], 1306);
      });
    },
  );
  testWidgets(
    'category adjacency and sorting preserve origin, statistics failure never blocks',
    (t) async {
      await withHome(
        t,
        (s) async {
          final h = home(t), pick = home(t).weeklyItems.first;
          h.onWeeklySelected!(pick);
          await t.pumpAndSettle();
          archive(t).onSortChanged(true);
          await t.pumpAndSettle();
          expect(archive(t).feed!.categoryId, 102);
          expect(archive(t).bookmarkedFirst, isTrue);
          archive(t).onOpenContent(archive(t).contents.first);
          await t.pumpAndSettle();
          expect(detail(t).content.apiId, 602);
          detail(t).onOpenAdjacent(1);
          await t.pumpAndSettle();
          expect(detail(t).content.apiId, 604);
          expect(views(s), hasLength(2));
          expect(
            views(s).map((v) => (v['body'] as Map)['recommendation_item_id']),
            [pick.id, pick.id],
          );
          final uuid = (views(s).first['body'] as Map)['client_event_id'];
          expect(
            (views(s).last['body'] as Map)['client_event_id'],
            isNot(uuid),
          );
          detail(t).onBack();
          await t.pumpAndSettle();
          archive(t).onClearCategory();
          await t.pumpAndSettle();
          expect(weekly(s), hasLength(2));
          expect(home(t).weeklyItems, hasLength(2));
        },
        setup: (s) {
          s.records[3] = {
            ...s.records[3],
            'categories': s.records[1]['categories'],
          };
        },
        intercept: (s, r) async {
          if (r.url.path.endsWith('/exposures')) {
            s.calls.add({
              'method': r.method,
              'path': r.url.path,
              'body': r.body,
            });
            return s.json({'detail': 'controlled'}, 503);
          }
          return null;
        },
      );
    },
  );
  testWidgets('old F01 back cannot dismiss a replacement category context', (
    t,
  ) async {
    await withHome(t, (s) async {
      final h = home(t);
      h.onWeeklySelected!(h.weeklyItems.first);
      await t.pumpAndSettle();
      final back = archive(t).onClearCategory;
      archive(t).onOpenCategory(archive(t).categories.first);
      await t.pumpAndSettle();
      back();
      await t.pumpAndSettle();
      expect(find.byType(ArchiveScreen), findsOneWidget);
      expect(archive(t).feed!.categoryId, 101);
      archive(t).onClearCategory();
      await t.pumpAndSettle();
      expect(archive(t).activeCategoryName, isNull);
    });
  });
}
