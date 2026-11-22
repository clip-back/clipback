import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/feed_status.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_startup.dart';

// #460: 앱 복귀·홈·아카이브 재진입 때 불러온 목록에 처리 중 항목이 있으면 목록을 한 번 다시 읽는다.
// 서버가 받은 요청과 화면 글자만 본다.

const _feed = '/api/v1/feed';
const _categories = '/api/v1/categories';
const _stats = '/api/v1/users/me/stats';
const _profile = '/api/v1/users/me';
const _listPaths = [_feed, _categories, _stats, _profile];
const _pendingTitle = '저장한 콘텐츠';
const _doneTitle = '완성된 영상 제목';
const _doneSummary = '완성된 영상 요약';
const _daily = {
  'id': 101,
  'name': '일상',
  'color': '#5BD89D',
  'is_default': false,
};
const _unclassified = {
  'id': 99,
  'name': '미분류',
  'color': '#B5BDC3',
  'is_default': true,
};

Map<String, Object?> _item(
  int id,
  String title,
  Map<String, Object?> category, {
  String status = 'completed',
  String summary = '저장한 요약',
}) => {
  'id': id,
  'title': title,
  'summary': summary,
  'categories': [category],
  'tags': <Object>[],
  'assets': <Object>[],
  'content_type': 'link',
  'source': 'youtube',
  'original_url': 'https://youtu.be/item-$id',
  'is_favorite': false,
  'saved_at': '2026-11-2${id % 10}T12:00:00Z',
  'last_viewed_at': null,
  'summary_status': status,
};

class _Server {
  _Server({bool processing = true, int extra = 0}) {
    items.addAll([
      _item(
        7,
        _pendingTitle,
        _unclassified,
        status: processing ? 'processing' : 'completed',
        summary: '요약 정보가 아직 없습니다.',
      ),
      _item(8, '정해진 일상 콘텐츠', _daily),
      _item(9, '아직 분류 전 콘텐츠', _unclassified),
      for (var i = 0; i < extra; i++)
        _item(100 + i, '더 저장한 콘텐츠 ${i + 1}', _daily),
    ]);
  }

  final items = <Map<String, Object?>>[];
  final calls = <(String, String, Map<String, String>)>[];
  final unexpected = <String>[];
  bool failLists = false;
  bool failCategories = false;
  int failFeeds = 0; // 다음 N번의 GET /feed를 503으로
  Completer<void>? logoutGate;
  // While set, every feed read waits for it. The reply carries the items as
  // they were when the request arrived; failures are judged after the wait.
  Completer<void>? feedGate;
  // While set, the first GET /users/me/stats waits for it and succeeds;
  // later stats reads answer 503 (a competing second read would fail).
  Completer<void>? statsGate;
  int gatedStats = 0;
  // A malformed 200 body for every feed read while set.
  Map<String, Object?>? invalidFeed;

  void complete() {
    final i = items.indexWhere((v) => v['id'] == 7);
    items[i] = {
      ...items[i],
      'title': _doneTitle,
      'summary': _doneSummary,
      'summary_status': 'completed',
      'categories': [_daily],
    };
  }

  // 목록 네 경로는 GET만 받는다. 세는 것도 GET + 경로다.
  int count(String path) =>
      calls.where((c) => c.$1 == 'GET' && c.$2 == path).length;
  Map<String, int> listCounts() => {for (final p in _listPaths) p: count(p)};

  int _members(int id) => items
      .where(
        (v) => (v['categories'] as List).any((c) => (c as Map)['id'] == id),
      )
      .length;

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  late final client = MockClient((r) async {
    final path = r.url.path, q = r.url.queryParameters;
    calls.add((r.method, path, q));
    if (_listPaths.contains(path) && r.method != 'GET') {
      unexpected.add('${r.method} $path');
      return _json({'detail': 'GET only'}, 405);
    }
    final requested = [for (final v in items) Map<String, Object?>.of(v)];
    if (path == _feed) await feedGate?.future;
    if (path == _feed && invalidFeed != null) return _json(invalidFeed!);
    if ((failLists && _listPaths.contains(path)) ||
        (failCategories && path == _categories)) {
      return _json({'detail': 'temporary'}, 503);
    }
    if (path == _feed && failFeeds > 0) {
      failFeeds--;
      return _json({'detail': 'temporary'}, 503);
    }
    switch (path) {
      case _categories:
        return _json([
          {..._daily, 'content_count': _members(101), 'last_saved_at': null},
          {
            ..._unclassified,
            'content_count': _members(99),
            'last_saved_at': null,
          },
        ]);
      case _feed:
        final category = q['category_id'];
        final rows = [
          for (final v in requested)
            if (category == null ||
                (v['categories'] as List).any(
                  (c) => (c as Map)['id'].toString() == category,
                ))
              v,
        ];
        final start = int.parse(q['cursor'] ?? '0');
        final end = (start + int.parse(q['limit'] ?? '20')).clamp(
          0,
          rows.length,
        );
        return _json({
          'items': rows.sublist(start, end),
          'next_cursor': end < rows.length ? '$end' : null,
        });
      case _profile:
        return _json({
          'id': 1,
          'email': null,
          'display_name': '목록 갱신',
          'is_guest': true,
          'created_at': '2026-11-01T00:00:00Z',
          'linked_providers': <String>[],
        });
      case _stats:
        if (statsGate != null) {
          if (++gatedStats == 1) {
            await statsGate!.future;
          } else {
            return _json({'detail': 'temporary'}, 503);
          }
        }
        return _json({
          'saved_count': items.length,
          'reopened_count': 0,
          'recent_reopened_count': 0,
        });
      case '/api/v1/auth/share-credential':
        return _json({
          'share_token': 'fixture-share-token',
          'expires_at': '2099-01-01T00:00:00Z',
          'user_id': 1,
          'session_id': 11,
        });
      case '/api/v1/auth/logout':
        await logoutGate?.future;
        return http.Response('', 204);
      case '/api/v1/recommendations/weekly':
        return _json({
          'period_start': '2026-11-16T00:00:00Z',
          'period_end': '2026-11-23T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        });
      case '/api/v1/metrics/events':
        return _json(<String, Object>{}, 201);
    }
    final detail = RegExp(r'^/api/v1/contents/(\d+)(/view)?$').firstMatch(path);
    if (detail != null) {
      if (detail[2] != null) return _json(<String, Object>{}, 201);
      return _json(items.firstWhere((v) => v['id'] == int.parse(detail[1]!)));
    }
    unexpected.add('${r.method} $path');
    return _json({'detail': 'unexpected'}, 404);
  });
}

// 공유 확장 대역: 영수증·확인 기록, getState 한 번을 붙잡는 문.
class _Share {
  var receipts = <Map<String, Object>>[];
  final acknowledgements = <Object?>[];
  Completer<void>? stateGate;
  static const channel = MethodChannel('com.huturu.app/share');

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getState':
              final gate = stateGate;
              stateGate = null;
              await gate?.future;
              return {'revision': 0, 'drafts': [], 'receipts': receipts};
            case 'publishCredential':
              return true;
            case 'acknowledgeReceipts':
              acknowledgements.add((call.arguments as Map)['ids']);
              receipts = [];
              return null;
            case 'blockCredential':
              return 1;
            default:
              throw StateError('Unexpected native action: ${call.method}');
          }
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }
}

Future<void> _withApp(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check, {
  _Share? share,
}) async {
  SharedPreferences.setMockInitialValues({
    'clipback.session': jsonEncode({
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
      'expires_in': 3600,
      'refresh_expires_in': 86400,
    }),
  });
  share?.install();
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        Theme(
          data: ThemeData(fontFamily: 'Pretendard'),
          child: ClipbackApp(
            nativeShare: NativeShareService(enabled: share != null),
          ),
        ),
      );
      await completeAppStartup(tester);
      await check();
      expect(server.unexpected, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _background(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pump();
  }
}

Future<void> _foreground(WidgetTester tester, {bool settle = true}) async {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pump();
  }
  if (settle) await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('navigation-icon-$index')));
  await tester.pumpAndSettle();
}

Future<void> _categoryTab(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate((w) => w is ArchiveTabButton && w.label == '카테고리'),
  );
  await tester.pumpAndSettle();
}

Finder _inCard(String text) => find.descendant(
  of: find.byType(HomeContentCard),
  matching: find.text(text),
);

void _expectCard({required bool done}) {
  expect(_inCard(done ? _doneTitle : _pendingTitle), findsOneWidget);
  expect(_inCard(done ? _pendingTitle : _doneTitle), findsNothing);
  // 카드 7의 카테고리 배지
  final card = find.ancestor(
    of: find.text(done ? _doneTitle : _pendingTitle),
    matching: find.byType(HomeContentCard),
  );
  expect(
    find.descendant(of: card, matching: find.text(done ? '일상' : '미분류')),
    findsOneWidget,
  );
}

String? _unclassifiedCount(WidgetTester tester) {
  final row = find.byType(UnclassifiedCategoryRow);
  if (row.evaluate().isEmpty) return null;
  return tester.widget<UnclassifiedCategoryRow>(row).count.toString();
}

void _expectArchiveCounts(
  WidgetTester tester, {
  required int unclassified,
  required int daily,
}) {
  expect(find.byType(UnclassifiedCategoryRow), findsOneWidget);
  expect(
    find.descendant(
      of: find.byType(UnclassifiedCategoryRow),
      matching: find.text('$unclassified'),
    ),
    findsOneWidget,
    reason: '미분류 ${_unclassifiedCount(tester)}',
  );
  // 아카이브 카테고리 행은 개수를 그리지 않는다. 행에 전달된 개수를 본다.
  expect(
    tester
        .widget<CategoryRow>(
          find.byKey(const ValueKey('archive-category-row-101')),
        )
        .category
        .contentCount,
    daily,
  );
}

// 목록 대기 표시(FeedStatus 안의 스피너)와 인라인 오류.
Finder get _feedSpinner => find.descendant(
  of: find.byType(FeedStatus),
  matching: find.byType(CircularProgressIndicator),
);

void _expectNoListNotice() {
  expect(_feedSpinner, findsNothing);
  expect(find.textContaining('불러오지 못했어요'), findsNothing);
  expect(find.text('다시 시도'), findsNothing);
  expect(find.byType(SnackBar), findsNothing);
}

ScrollPosition _archiveScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ContentListView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1 resume on home re-reads the list once when an item is processing',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        _expectCard(done: false);
        server.complete();
        final before = server.listCounts();
        await _background(tester);
        await _foreground(tester);
        _expectCard(done: true);
        expect(server.count(_feed), before[_feed]! + 1);
        expect(server.count(_categories), before[_categories]! + 1);
      });
    },
  );

  testWidgets(
    '2 home → archive → home updates the card and the archive root counts',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        _expectCard(done: false);
        server.complete();
        await _tab(tester, 1);
        await _categoryTab(tester);
        _expectArchiveCounts(tester, unclassified: 1, daily: 2);
        await _tab(tester, 0);
        _expectCard(done: true);
      });
    },
  );

  testWidgets(
    '3 no processing item: resume and tab switches send no list request',
    (tester) async {
      final server = _Server(processing: false);
      await _withApp(tester, server, () async {
        // 아카이브 첫 진입의 첫 쪽 읽기는 이번 변경과 무관하게 나가므로 먼저 끝내 둔다.
        await _tab(tester, 1);
        await _tab(tester, 0);
        final before = server.listCounts();
        await _background(tester);
        await _foreground(tester);
        await _tab(tester, 1);
        await _categoryTab(tester);
        await _tab(tester, 0);
        expect(server.listCounts(), before);
      });
    },
  );

  testWidgets(
    '4 resume on detail reads only the detail, once, and shows its reply',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await tester.tap(find.text(_pendingTitle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final reads = server.count('/api/v1/contents/7');
        final lists = server.listCounts();
        server.complete();
        await _background(tester);
        await tester.pump(const Duration(seconds: 5));
        await _foreground(tester, settle: false);
        await tester.pump(const Duration(milliseconds: 500));
        expect(server.count('/api/v1/contents/7'), reads + 1);
        expect(server.listCounts(), lists);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('detail-summary')))
              .data,
          _doneSummary,
        );
      });
    },
  );

  testWidgets(
    '5 share receipt on resume is acknowledged without the share notice',
    (tester) async {
      final server = _Server();
      final share = _Share();
      await _withApp(tester, server, share: share, () async {
        share.receipts = [
          {'id': 'saved-receipt', 'userId': 1},
        ];
        await _background(tester);
        await _foreground(tester);
        expect(share.acknowledgements, [
          ['saved-receipt'],
        ]);
        expect(find.textContaining('공유한 항목의 최신 정보'), findsNothing);

        // 공유 처리 중(getState를 붙잡음) 재진입도 같다.
        share.receipts = [
          {'id': 'second-receipt', 'userId': 1},
        ];
        final gate = Completer<void>();
        share.stateGate = gate;
        await _background(tester);
        await _foreground(tester, settle: false);
        await tester.pump();
        await _tab(tester, 1);
        await _tab(tester, 0);
        gate.complete();
        await tester.pumpAndSettle();
        expect(share.acknowledgements.last, ['second-receipt']);
        expect(find.textContaining('공유한 항목의 최신 정보'), findsNothing);
      });
    },
  );

  testWidgets('6 a failed re-read keeps the card and shows no notice', (
    tester,
  ) async {
    final server = _Server();
    await _withApp(tester, server, () async {
      // 아카이브 첫 쪽은 먼저 읽어 둔다(첫 읽기 실패는 이번 경로가 아니다).
      await _tab(tester, 1);
      await _tab(tester, 0);
      server
        ..complete()
        ..failLists = true;
      var before = server.count(_feed);
      await _background(tester);
      await _foreground(tester);
      expect(server.count(_feed), greaterThan(before), reason: '복귀 다시 읽기');
      _expectCard(done: false);
      _expectNoListNotice();

      before = server.count(_feed);
      await _tab(tester, 1);
      expect(server.count(_feed), greaterThan(before), reason: '아카이브 재진입');
      expect(find.text(_pendingTitle), findsOneWidget);
      expect(find.text('정해진 일상 콘텐츠'), findsOneWidget);
      _expectNoListNotice();
      await _tab(tester, 0);
      _expectCard(done: false);
      _expectNoListNotice();

      // 다음 재진입에서 복구한다.
      server.failLists = false;
      await _tab(tester, 1);
      await _tab(tester, 0);
      _expectCard(done: true);
      _expectNoListNotice();
    });
  });

  testWidgets(
    '7 logout confirmation and a logout in progress send no list request',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await tester.tap(
          find.descendant(
            of: find.byType(ClipbackNavigationBar),
            matching: find.text('마이'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(MyProfileRow));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('로그아웃'));
        await tester.tap(find.text('로그아웃'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('logout-confirm')), findsOneWidget);
        final before = server.listCounts();
        await _background(tester);
        await _foreground(tester);
        expect(server.listCounts(), before);

        server.logoutGate = Completer<void>();
        await tester.tap(find.byKey(const ValueKey('logout-confirm')));
        await tester.pump();
        await _background(tester);
        await _foreground(tester, settle: false);
        await tester.pump(const Duration(milliseconds: 100));
        expect(server.listCounts(), before);
        server.logoutGate!.complete();
        await tester.pumpAndSettle();
      });
    },
  );

  testWidgets(
    '8 back from a processing item in the unclassified list drops it from the list',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _tab(tester, 1);
        await _categoryTab(tester);
        await tester.tap(find.byType(UnclassifiedCategoryRow));
        await tester.pumpAndSettle();
        expect(find.text(_pendingTitle), findsOneWidget);
        await tester.tap(find.text(_pendingTitle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        server.complete();
        await tester.tap(find.byKey(const ValueKey('detail-back')));
        await tester.pumpAndSettle();
        expect(find.text('아직 분류 전 콘텐츠'), findsOneWidget);
        expect(find.text(_pendingTitle), findsNothing);
        expect(find.text(_doneTitle), findsNothing);
      });
    },
  );

  testWidgets(
    '9 while the background read waits, home and archive keep their cards without a spinner',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _tab(tester, 1);
        server.complete();
        final gate = Completer<void>();
        server.feedGate = gate;
        final before = server.count(_feed);
        await _background(tester);
        await _foreground(tester, settle: false);
        await tester.pump(const Duration(milliseconds: 100));
        expect(server.count(_feed), greaterThan(before));
        expect(find.text(_pendingTitle), findsOneWidget);
        expect(find.text('정해진 일상 콘텐츠'), findsOneWidget);
        _expectNoListNotice();
        await _tab(tester, 0);
        _expectCard(done: false);
        _expectNoListNotice();
        server.feedGate = null;
        gate.complete();
        await tester.pumpAndSettle();
        _expectCard(done: true);
        _expectNoListNotice();
      });
    },
  );

  testWidgets(
    '10 a failed background read keeps the archive scroll and cursor for the next page',
    (tester) async {
      final server = _Server(extra: 25);
      await _withApp(tester, server, () async {
        await _tab(tester, 1);
        expect(find.text('더 저장한 콘텐츠 17'), findsNothing);
        await tester.drag(find.byType(ContentListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        final offset = _archiveScroll(tester).pixels;
        expect(offset, greaterThan(0));
        server.failLists = true;
        final before = server.count(_feed);
        await _background(tester);
        await _foreground(tester);
        expect(server.count(_feed), greaterThan(before));
        expect(_archiveScroll(tester).pixels, offset);
        _expectNoListNotice();
        server.failLists = false;
        await tester.dragUntilVisible(
          find.text('더 저장한 콘텐츠 25'),
          find.byType(ContentListView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(
          server.calls.where((c) => c.$2 == _feed && c.$3['cursor'] == '20'),
          isNotEmpty,
          reason: '실패 뒤에도 다음 쪽 커서가 남아 있다',
        );
      });
    },
  );

  testWidgets(
    '11 share receipt refresh keeps its spinner, failure notice and retry',
    (tester) async {
      // 처리 중 항목이 없어 새 배경 경로는 돌지 않는다(D4 기존 경로).
      final server = _Server(processing: false);
      final share = _Share();
      await _withApp(tester, server, share: share, () async {
        share.receipts = [
          {'id': 'share-503', 'userId': 1},
        ];
        final gate = Completer<void>();
        server.feedGate = gate;
        await _background(tester);
        await _foreground(tester, settle: false);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_feedSpinner, findsOneWidget, reason: '대기 중 기존 스피너');
        server
          ..failLists = true
          ..feedGate = null;
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.textContaining('공유한 항목의 최신 정보'), findsOneWidget);
        expect(find.text('콘텐츠를 더 불러오지 못했어요.'), findsOneWidget);
        expect(share.acknowledgements, isEmpty);

        server.failLists = false;
        await _background(tester);
        await _foreground(tester);
        expect(share.acknowledgements, [
          ['share-503'],
        ]);
        expect(find.text('콘텐츠를 더 불러오지 못했어요.'), findsNothing);
      });
    },
  );

  testWidgets(
    '12 a category-only failure keeps the card processing and the next entry reads both',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _tab(tester, 1);
        await _tab(tester, 0);
        server
          ..complete()
          ..failCategories = true;
        final before = server.count(_categories);
        await _background(tester);
        await _foreground(tester);
        expect(server.count(_categories), greaterThan(before));
        _expectCard(done: false);
        _expectNoListNotice();
        server.failCategories = false;
        final categories = server.count(_categories);
        await _tab(tester, 1);
        expect(server.count(_categories), categories + 1);
        await _categoryTab(tester);
        _expectArchiveCounts(tester, unclassified: 1, daily: 2);
        await _tab(tester, 0);
        _expectCard(done: true);
      });
    },
  );

  testWidgets(
    '13 a failed share refresh keeps its inline error and retry; no background read follows',
    (tester) async {
      final server = _Server();
      final share = _Share();
      await _withApp(tester, server, share: share, () async {
        share.receipts = [
          {'id': 'share-processing', 'userId': 1},
        ];
        server.failFeeds = 1;
        final before = server.count(_feed);
        await _background(tester);
        await _foreground(tester);
        expect(server.count(_feed), before + 1, reason: '공유 새로고침만');
        expect(find.text('콘텐츠를 더 불러오지 못했어요.'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FeedStatus),
            matching: find.text('다시 시도'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('공유한 항목의 최신 정보'), findsOneWidget);
        expect(share.receipts, hasLength(1));
        expect(share.acknowledgements, isEmpty);
      });
    },
  );

  testWidgets(
    '14 a resume that went back to the background before the share step ends reads nothing',
    (tester) async {
      final server = _Server();
      final share = _Share();
      await _withApp(tester, server, share: share, () async {
        final gate = Completer<void>();
        share.stateGate = gate;
        await _background(tester);
        await _foreground(tester, settle: false);
        await _background(tester);
        final lists = server.listCounts();
        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(server.listCounts(), lists);
        // 다시 앞으로 오면 그 복귀가 읽는다.
        server.complete();
        await _foreground(tester);
        _expectCard(done: true);
      });
    },
  );

  testWidgets('15 the server double refuses non-GET list requests', (
    tester,
  ) async {
    final server = _Server();
    await http.runWithClient(() async {
      final response = await http.post(
        Uri.parse('https://example.invalid$_feed'),
      );
      expect(response.statusCode, 405);
    }, () => server.client);
    expect(server.count(_feed), 0);
    expect(server.unexpected, ['POST $_feed']);
  });

  testWidgets(
    '16 a newer re-entry wins over an older read still waiting with processing items',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _tab(tester, 1);
        await _tab(tester, 0);
        final gate = Completer<void>();
        server.feedGate = gate;
        await _background(tester);
        await _foreground(tester, settle: false);
        await tester.pump();
        final first = server.count(_feed);
        server
          ..feedGate = null
          ..complete();
        await _tab(tester, 1);
        await _tab(tester, 0);
        expect(server.count(_feed), greaterThan(first), reason: '재진입마다 GET');
        gate.complete();
        await tester.pumpAndSettle();
        _expectCard(done: true);
        _expectNoListNotice();
      });
    },
  );

  for (final body in <Map<String, Object?>>[
    {},
    {'items': null},
    {'items': 5},
  ]) {
    testWidgets('17 a malformed feed reply $body keeps the cards', (
      tester,
    ) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        _expectCard(done: false);
        server.invalidFeed = body;
        final before = server.count(_feed);
        await _background(tester);
        await _foreground(tester);
        expect(server.count(_feed), greaterThan(before));
        _expectCard(done: false);
        _expectNoListNotice();
        // 정상 응답이 돌아오면 다음 진입에서 반영한다.
        server
          ..invalidFeed = null
          ..complete();
        await _tab(tester, 1);
        await _tab(tester, 0);
        _expectCard(done: true);
      });
    });
  }

  testWidgets(
    '18 a My stats read the user started survives a background read finishing',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        final feed = Completer<void>();
        server.feedGate = feed;
        await _background(tester);
        await _foreground(tester, settle: false);
        await tester.pump();
        final stats = Completer<void>();
        server.statsGate = stats;
        await tester.tap(
          find.descendant(
            of: find.byType(ClipbackNavigationBar),
            matching: find.text('마이'),
          ),
        );
        await tester.pumpAndSettle();
        expect(server.gatedStats, 1);
        expect(find.text('마지막 확인값 · 새로 불러오는 중'), findsOneWidget);
        server.feedGate = null;
        feed.complete();
        await tester.pumpAndSettle();
        expect(server.gatedStats, 1, reason: '배경 후속이 통계를 다시 읽지 않는다');
        stats.complete();
        await tester.pumpAndSettle();
        expect(find.text('마지막 확인값 · 새로 불러오지 못했어요'), findsNothing);
        expect(server.gatedStats, 1);
      });
    },
  );

  // 직전 검수 Spec 3: 첫 배경 통계가 걸려 있어도 다음 복귀의 배경은 자기 통계를 읽는다.
  testWidgets(
    '19 a second resume reads its own stats while the first background stats read is pending',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        final gate = Completer<void>();
        server.statsGate = gate;
        await _background(tester);
        await _foreground(tester);
        expect(server.gatedStats, 1);
        final before = server.listCounts();
        server
          ..statsGate = null
          ..complete();
        await _background(tester);
        await _foreground(tester);
        _expectCard(done: true);
        final after = server.listCounts();
        gate.complete();
        await tester.pumpAndSettle();
        expect(after[_stats], before[_stats]! + 1);
        expect(after[_profile], before[_profile]! + 1);
      });
    },
  );

  // 검수 Spec 1: 배경 목록을 기다리는 동안 끝난 마이 통계 실패는 늦은 배경 후속이 덮지 않는다.
  testWidgets(
    '20 a My stats failure finished while the background list waits keeps its retry state',
    (tester) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        final feed = Completer<void>();
        server.feedGate = feed;
        final initialFeed = server.count(_feed);
        await _background(tester);
        await _foreground(tester, settle: false);
        await tester.pump();
        expect(server.count(_feed), initialFeed + 1);
        server.failLists = true;
        final before = server.count(_stats);
        await tester.tap(
          find.descendant(
            of: find.byType(ClipbackNavigationBar),
            matching: find.text('마이'),
          ),
        );
        await tester.pumpAndSettle();
        final error = find.text('마지막 확인값 · 새로 불러오지 못했어요');
        expect(error, findsOneWidget);
        server
          ..failLists = false
          ..feedGate = null;
        feed.complete();
        await tester.pumpAndSettle();
        expect(server.count(_stats), before + 1, reason: '사용자 통계 1회뿐');
        expect(error, findsOneWidget);
      });
    },
  );
}
