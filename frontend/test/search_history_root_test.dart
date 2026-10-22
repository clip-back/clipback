import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/archive_all_preview.dart' as base;
import 'support/app_startup.dart';
import 'search_history_repository_test.dart' show MemoryHistory;

void main() {
  testWidgets(
    'actual root restores, deletes and ignores stale search callbacks',
    (t) async {
      final server = base.ArchiveAllServer(), storage = MemoryHistory();
      await http.runWithClient(() async {
        try {
          await t.pumpWidget(
            ClipbackApp(
              searchHistoryStorage: storage,
              sessionStorage: base.ArchiveAllMemoryStorage(),
              socialAuth: base.ArchiveAllSocialAuth(),
            ),
          );
          await completeAppStartup(t);
          void open() =>
              t.widget<HomeScreen>(find.byType(HomeScreen)).onSearch();
          SearchScreen screen() =>
              t.widget<SearchScreen>(find.byType(SearchScreen));
          Future<void> submit(String q) async {
            final f = t.widget<TextField>(find.byType(TextField));
            f.controller!.text = q;
            f.onChanged!(q);
            f.onSubmitted!(q);
            await t.pumpAndSettle();
          }

          Future<void> clear() async {
            final f = t.widget<TextField>(find.byType(TextField));
            f.controller!.clear();
            f.onChanged!('');
            await t.pumpAndSettle();
          }

          List<String> terms() => t
              .widgetList<SearchHistoryRow>(find.byType(SearchHistoryRow))
              .map((r) => r.term)
              .toList();
          open();
          await t.pumpAndSettle();
          expect(terms(), isEmpty);
          await submit('  saved query  ');
          await clear();
          expect(terms(), ['saved query']);
          final old = screen();
          old.onClose();
          await t.pumpAndSettle();
          final before = server.requests.length;
          await old.onSearch('stale');
          old.onQueryChanged('stale');
          expect(server.requests.length, before);
          open();
          await t.pumpAndSettle();
          expect(terms(), ['saved query']);
          final beforeDelete = server.requests.length;
          t.widget<SearchHistoryRow>(find.byType(SearchHistoryRow)).onRemove();
          await t.pumpAndSettle();
          expect(terms(), isEmpty);
          expect(server.requests.length, beforeDelete);
          screen().onClose();
          await t.pumpAndSettle();
          open();
          await t.pumpAndSettle();
          expect(terms(), isEmpty);
          await submit('survives recreation');
          await clear();
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          await t.pumpWidget(
            ClipbackApp(
              searchHistoryStorage: storage,
              sessionStorage: base.ArchiveAllMemoryStorage(),
              socialAuth: base.ArchiveAllSocialAuth(),
            ),
          );
          await completeAppStartup(t);
          open();
          await t.pumpAndSettle();
          expect(terms(), ['survives recreation']);
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        }
      }, () => server.client);
    },
  );
  testWidgets('failed and zero-result searches are recorded before response', (
    t,
  ) async {
    final server = base.ArchiveAllServer(), storage = MemoryHistory();
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/feed' &&
          req.url.queryParameters['q'] == 'failed') {
        return server.json({'detail': 'controlled'}, 503);
      }
      final copy = http.Request(req.method, req.url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes;
      return server.client.send(copy).then(http.Response.fromStream);
    });
    await http.runWithClient(() async {
      try {
        await t.pumpWidget(
          ClipbackApp(
            searchHistoryStorage: storage,
            sessionStorage: base.ArchiveAllMemoryStorage(),
            socialAuth: base.ArchiveAllSocialAuth(),
          ),
        );
        await completeAppStartup(t);
        t.widget<HomeScreen>(find.byType(HomeScreen)).onSearch();
        await t.pumpAndSettle();
        for (final q in ['zero results', 'failed']) {
          final f = t.widget<TextField>(find.byType(TextField));
          f.controller!.text = q;
          f.onChanged!(q);
          f.onSubmitted!(q);
          await t.pumpAndSettle();
          expect(
            t
                .widget<SearchScreen>(find.byType(SearchScreen))
                .recentTerms!
                .first,
            q,
          );
        }
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      }
    }, () => client);
  });
}
