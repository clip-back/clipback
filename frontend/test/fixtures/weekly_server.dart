import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'today_server.dart';
import '../support/archive_all_preview.dart' as base;

class WeeklyServer extends TodayServer {
  String weeklyMode = 'normal';
  int batch = 800;
  Completer<void>? weeklyPending;
  void resetWeekly([String value = 'normal']) {
    resetToday();
    weeklyMode = value;
    batch = 800;
    weeklyPending = null;
  }

  Map<String, dynamic> weeklyResponse() => {
    'period_start': '2026-10-19',
    'period_end': '2026-10-25',
    'batch_id': batch,
    'generated_at': '2026-10-21T12:00:00Z',
    'items': weeklyMode == 'empty'
        ? <Object>[]
        : [
            {
              'recommendation_item_id': batch * 10 + 1,
              'rank': 1,
              'card_type': weeklyMode == 'rediscovery'
                  ? 'REDISCOVERY'
                  : 'MOST_SAVED',
              'category': base.archiveAllCategoryMaps[1],
            },
            {
              'recommendation_item_id': batch * 10 + 2,
              'rank': 3,
              'card_type': 'MOST_VIEWED',
              'category': base.archiveAllCategoryMaps[0],
            },
          ],
  };
  late final weeklyClient = MockClient((request) async {
    final path = request.url.path;
    if (path == '/api/v1/recommendations/weekly' ||
        path == '/api/v1/recommendations/exposures') {
      calls.add({
        'method': request.method,
        'path': path,
        'query': request.url.queryParameters,
        if (request.body.isNotEmpty) 'body': jsonDecode(request.body),
      });
      if (request.method == 'POST') return this.json({'id': 1}, 201);
      batch++;
      final snapshot = weeklyResponse();
      await weeklyPending?.future;
      return weeklyMode == 'error'
          ? this.json({'detail': 'controlled'}, 503)
          : this.json(snapshot);
    }
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return todayClient.send(copy).then(http.Response.fromStream);
  });
}
