import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/feed_status.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:clipback_frontend/shared/widgets/skeleton_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_startup.dart';

// #473: 홈 레일의 스켈레톤(표 1행)과 다시 읽기 때 직전 카드 유지(표 2행, P1–P5).

const _feedPath = '/api/v1/feed';
const _daily = {
  'id': 101,
  'name': '일상',
  'color': '#5BD89D',
  'is_default': false,
};

const _travel = {
  'id': 102,
  'name': '여행',
  'color': '#5B9DD8',
  'is_default': false,
};

Map<String, Object?> _item(
  int id, {
  String? title,
  Map<String, Object?> category = _daily,
  String status = 'completed',
}) => {
  'id': id,
  'title': title ?? '카드 $id',
  'summary': '요약 $id',
  'categories': [category],
  'tags': <Object>[],
  'assets': <Object>[],
  'content_type': 'link',
  'source': 'youtube',
  'original_url': 'https://youtu.be/item-$id',
  'is_favorite': false,
  'saved_at': '2026-11-20T12:00:00Z',
  'last_viewed_at': null,
  'summary_status': status,
};

class _Server {
  _Server({String firstStatus = 'completed', bool travel = false})
    : items = [
        _item(1, status: firstStatus),
        _item(2),
        _item(3),
        if (travel) ...[
          _item(10, category: _travel),
          _item(11, category: _travel),
        ],
      ];

  final List<Map<String, Object?>> items;
  Completer<void>? feedGate;
  bool failFeed = false;
  // Saved elsewhere just after this save; the next feed reply lists it first.
  Map<String, Object?>? newerAfterSave;
  final feedCategories = <String?>[];

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  late final client = MockClient((r) async {
    final path = r.url.path;
    if (path == '/api/v1/contents' && r.method == 'POST') {
      final saved = _item(300);
      items.insert(0, saved);
      if (newerAfterSave != null) items.insert(0, newerAfterSave!);
      return _json(saved, 201);
    }
    if (path == _feedPath) {
      final category = r.url.queryParameters['category_id'];
      feedCategories.add(category);
      await feedGate?.future;
      if (failFeed) return _json({'detail': 'temporary'}, 503);
      return _json({
        'items': [
          for (final item in items)
            if (category == null ||
                (item['categories'] as List).any(
                  (c) => (c as Map)['id'].toString() == category,
                ))
              item,
        ],
        'next_cursor': null,
      });
    }
    final detail = RegExp(r'^/api/v1/contents/(\d+)(/view)?$').firstMatch(path);
    if (detail != null) {
      if (detail[2] != null) return _json(<String, Object>{}, 201);
      return _json(items.firstWhere((v) => v['id'] == int.parse(detail[1]!)));
    }
    return switch (path) {
      '/api/v1/categories' => _json([
        {..._daily, 'content_count': items.length, 'last_saved_at': null},
        {..._travel, 'content_count': 2, 'last_saved_at': null},
      ]),
      '/api/v1/users/me' => _json({
        'id': 1,
        'email': null,
        'display_name': '홈 레일',
        'is_guest': true,
        'created_at': '2026-11-01T00:00:00Z',
        'linked_providers': <String>[],
      }),
      '/api/v1/users/me/stats' => _json({
        'saved_count': items.length,
        'reopened_count': 0,
        'recent_reopened_count': 0,
      }),
      '/api/v1/auth/share-credential' => _json({
        'share_token': 'fixture-share-token',
        'expires_at': '2099-01-01T00:00:00Z',
        'user_id': 1,
        'session_id': 11,
      }),
      '/api/v1/recommendations/weekly' => _json({
        'period_start': '2026-11-16T00:00:00Z',
        'period_end': '2026-11-23T00:00:00Z',
        'batch_id': null,
        'generated_at': null,
        'items': <Object>[],
      }),
      '/api/v1/metrics/events' => _json(<String, Object>{}, 201),
      _ => _json({'detail': 'unexpected $path'}, 404),
    };
  });
}

class _Share {
  var receipts = <Map<String, Object>>[];
  final acknowledgements = <Object?>[];
  static const channel = MethodChannel('com.huturu.app/share');

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getState':
              return {'revision': 0, 'drafts': [], 'receipts': receipts};
            case 'publishCredential':
              return true;
            case 'acknowledgeReceipts':
              acknowledgements.add((call.arguments as Map)['ids']);
              receipts = [];
              return null;
            case 'blockCredential':
              return 1;
          }
          throw StateError('Unexpected native action: ${call.method}');
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
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _toSecondCard(WidgetTester tester) async {
  await tester.drag(find.byType(HomeContentCard).first, const Offset(-306, 0));
  await tester.pumpAndSettle();
  _expectRail(tester, dot: 1, offset: 306);
}

Future<void> _resumeWithShareReceipt(WidgetTester tester, _Share share) async {
  share.receipts = [
    {'id': 'share-473', 'userId': 1},
  ];
  await _resume(tester);
}

Future<void> _resume(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 100));
}

void _expectRail(
  WidgetTester tester, {
  required int dot,
  required double offset,
}) {
  expect(tester.widget<PageDots>(find.byType(PageDots)).activeIndex, dot);
  final rail = tester.widget<ListView>(
    find.descendant(
      of: find.byType(HomeContentPanel),
      matching: find.byWidgetPredicate(
        (w) => w is ListView && w.key is ValueKey<int>,
      ),
    ),
  );
  expect(rail.controller!.offset, offset);
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.byType(HomeContentCardSkeleton), findsNothing);
}

int? _centeredId(WidgetTester tester) {
  final center = tester.getCenter(find.byType(HomeContentPanel)).dx;
  for (final element in find.byType(HomeContentCard).evaluate()) {
    final box = element.renderObject! as RenderBox;
    final middle = box.localToGlobal(box.size.center(Offset.zero)).dx;
    if ((middle - center).abs() < 1) {
      return (element.widget as HomeContentCard).content.apiId;
    }
  }
  return null;
}

List<int?> _railIds(WidgetTester tester) => tester
    .widget<HomeContentPanel>(find.byType(HomeContentPanel))
    .contents
    .take(4)
    .map((item) => item.apiId)
    .toList();

String _selectedChip(WidgetTester tester) =>
    tester.widget<CategoryChips>(find.byType(CategoryChips)).activeLabel;

Future<void> _saveAndReturnHome(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate((w) => w.runtimeType.toString() == 'NavAddButton'),
  );
  await tester.pump();
  await tester.enterText(find.byType(TextField), 'https://example.com/new');
  await tester.pump(const Duration(milliseconds: 400));
  tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).onPressed();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  // The save route waits for the re-read; closing it shows the detail that
  // was opened underneath.
  tester.widget<SaveContentTopBar>(find.byType(SaveContentTopBar)).onClose();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(SaveContentTopBar), findsNothing);
  tester.widget<DetailScreen>(find.byType(DetailScreen)).onBack();
  await tester.pump(const Duration(milliseconds: 400));
  expect(
    tester
        .widget<HomeContentPanel>(find.byType(HomeContentPanel))
        .feed!
        .loading,
    isTrue,
    reason: '재조회가 보류 중이다',
  );
}

Finder _chip(String label) =>
    find.descendant(of: find.byType(CategoryChips), matching: find.text(label));

void _expectCentered(WidgetTester tester, String title) {
  final center = tester.getCenter(find.byType(HomeContentPanel)).dx;
  final card = find.ancestor(
    of: find.text(title),
    matching: find.byType(HomeContentCard),
  );
  expect(tester.getCenter(card).dx, closeTo(center, 1));
}

Widget _loadingPanel(double scale, {double width = 375}) => MaterialApp(
  theme: ThemeData(fontFamily: 'Pretendard'),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 900),
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        child: HomeContentPanel(
          feed: FeedPage()..loading = true,
          contents: const [],
          categories: const <CategoryItem>[],
          bookmarkedIds: const {},
          onOpenArchive: () {},
          onOpenCategories: () {},
          onOpenContent: (_) {},
          onToggleBookmark: (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  for (final scale in [1.0, 1.15, 1.3]) {
    testWidgets('row 1 fits the fixed rail height at $scale', (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_loadingPanel(scale));
      await tester.pump();

      final cards = find.byType(HomeContentCardSkeleton);
      expect(cards, findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(FeedStatus), findsNothing);
      final context = tester.element(find.byType(HomeContentPanel));
      expect(
        tester.getSize(find.byType(SkeletonShimmer)).height,
        HomeContentPanel.recentAreaHeight(context),
      );
      expect(
        tester.getSize(cards.first).height,
        HomeContentCard.heightFor(context),
      );
      expect(tester.getSize(cards.first).width, 298);
      // 첫 장은 가운데, 둘째 장은 오른쪽 끝에 일부만 보인다.
      expect(tester.getCenter(cards.first).dx, closeTo(187.5, 0.01));
      expect(tester.getTopLeft(cards.last).dx, lessThan(375));
      expect(tester.getTopRight(cards.last).dx, greaterThan(375));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('row 1 cannot be scrolled or tapped and hides its bars', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_loadingPanel(1));
    await tester.pump();

    final cards = find.byType(HomeContentCardSkeleton);
    final before = tester.getTopLeft(cards.first);
    await tester.drag(cards.first, const Offset(-200, 0));
    await tester.pump();
    expect(tester.getTopLeft(cards.first), before);
    expect(
      find.descendant(
        of: find.byType(SkeletonShimmer),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SkeletonShimmer),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    expect(find.bySemanticsLabel('가나다라'), findsNothing);
    semantics.dispose();
  });

  testWidgets('P1 P2 a home re-read keeps the second card, then same ids '
      'return to the first', (tester) async {
    final server = _Server();
    final share = _Share();
    await _withApp(tester, server, share: share, () async {
      await _toSecondCard(tester);
      final gate = server.feedGate = Completer<void>();
      await _resumeWithShareReceipt(tester, share);
      expect(
        tester
            .widget<HomeContentPanel>(find.byType(HomeContentPanel))
            .feed!
            .loading,
        isTrue,
      );
      _expectRail(tester, dot: 1, offset: 306);
      _expectCentered(tester, '카드 2');

      server.feedGate = null;
      gate.complete();
      await tester.pumpAndSettle();
      _expectRail(tester, dot: 0, offset: 0);
      _expectCentered(tester, '카드 1');
    });
  });

  testWidgets('P3 a new card in front returns to the first card', (
    tester,
  ) async {
    final server = _Server();
    final share = _Share();
    await _withApp(tester, server, share: share, () async {
      await _toSecondCard(tester);
      final gate = server.feedGate = Completer<void>();
      await _resumeWithShareReceipt(tester, share);
      _expectRail(tester, dot: 1, offset: 306);

      server
        ..items.insert(0, _item(9))
        ..feedGate = null;
      gate.complete();
      await tester.pumpAndSettle();
      _expectRail(tester, dot: 0, offset: 0);
      _expectCentered(tester, '카드 9');
    });
  });

  testWidgets('P4 a failed re-read shows the current error', (tester) async {
    final server = _Server();
    final share = _Share();
    await _withApp(tester, server, share: share, () async {
      await _toSecondCard(tester);
      final gate = server.feedGate = Completer<void>();
      await _resumeWithShareReceipt(tester, share);
      _expectRail(tester, dot: 1, offset: 306);

      server
        ..failFeed = true
        ..feedGate = null;
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(FeedStatus), findsOneWidget);
      expect(find.text('콘텐츠를 더 불러오지 못했어요.'), findsOneWidget);
      expect(find.byType(HomeContentCardSkeleton), findsNothing);
    });
  });

  testWidgets('P5 a chip switch shows the skeleton, then the first card', (
    tester,
  ) async {
    final server = _Server();
    await _withApp(tester, server, () async {
      await _toSecondCard(tester);
      final gate = server.feedGate = Completer<void>();
      await tester.tap(_chip('일상'));
      await tester.pump();
      expect(find.byType(HomeContentCardSkeleton), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(PageDots), findsNothing);

      server.feedGate = null;
      gate.complete();
      await tester.pumpAndSettle();
      _expectRail(tester, dot: 0, offset: 0);
      _expectCentered(tester, '카드 1');
    });
  });

  testWidgets('the same ids answered at once still return to the first card', (
    tester,
  ) async {
    final server = _Server();
    final share = _Share();
    await _withApp(tester, server, share: share, () async {
      await _toSecondCard(tester);
      await _resumeWithShareReceipt(tester, share);
      await tester.pumpAndSettle();
      expect(share.acknowledgements, [
        ['share-473'],
      ]);
      _expectRail(tester, dot: 0, offset: 0);
      expect(_centeredId(tester), 1);
    });
  });

  testWidgets('a failure answered at once leaves no stale dot for the next '
      'read', (tester) async {
    final server = _Server();
    final share = _Share();
    await _withApp(tester, server, share: share, () async {
      await _toSecondCard(tester);
      server.failFeed = true;
      await _resumeWithShareReceipt(tester, share);
      await tester.pumpAndSettle();
      expect(find.text('콘텐츠를 더 불러오지 못했어요.'), findsOneWidget);
      expect(share.acknowledgements, isEmpty);

      server.failFeed = false;
      final gate = server.feedGate = Completer<void>();
      await _resume(tester);
      _expectRail(tester, dot: 0, offset: 0);
      server.feedGate = null;
      gate.complete();
      await tester.pumpAndSettle();
      _expectRail(tester, dot: 0, offset: 0);
    });
  });

  group('a #460 background read is not a foreground re-read', () {
    testWidgets('success keeps the second card', (tester) async {
      final server = _Server(firstStatus: 'processing');
      await _withApp(tester, server, () async {
        await _toSecondCard(tester);
        server.items[0] = _item(1);
        final gate = server.feedGate = Completer<void>();
        await _resume(tester);
        _expectRail(tester, dot: 1, offset: 306);
        server.feedGate = null;
        gate.complete();
        await tester.pumpAndSettle();
        _expectRail(tester, dot: 1, offset: 306);
        expect(_centeredId(tester), 2);
      });
    });

    testWidgets('failure keeps the second card', (tester) async {
      final server = _Server(firstStatus: 'processing');
      await _withApp(tester, server, () async {
        await _toSecondCard(tester);
        server.failFeed = true;
        await _resume(tester);
        await tester.pumpAndSettle();
        _expectRail(tester, dot: 1, offset: 306);
        expect(find.textContaining('불러오지 못했어요'), findsNothing);
      });
    });

    testWidgets('a chip switch cancels it and owns the rail', (tester) async {
      final server = _Server(firstStatus: 'processing', travel: true);
      await _withApp(tester, server, () async {
        await _toSecondCard(tester);
        final gate = server.feedGate = Completer<void>();
        await _resume(tester);
        await tester.tap(_chip('여행'));
        await tester.pump();
        expect(find.byType(HomeContentCardSkeleton), findsNWidgets(2));
        server.feedGate = null;
        gate.complete();
        await tester.pumpAndSettle();
        _expectRail(tester, dot: 0, offset: 0);
        expect(_railIds(tester), [10, 11]);
      });
    });
  });

  group('after a save, home waits on the saved card', () {
    testWidgets('then shows the reply first card when it is the saved one', (
      tester,
    ) async {
      final server = _Server();
      await _withApp(tester, server, () async {
        await _toSecondCard(tester);
        final gate = server.feedGate = Completer<void>();
        await _saveAndReturnHome(tester);
        expect(_centeredId(tester), 300);
        _expectRail(tester, dot: 0, offset: 0);

        server.feedGate = null;
        gate.complete();
        await tester.pumpAndSettle();
        expect(_selectedChip(tester), '전체보기');
        expect(server.feedCategories.last, isNull);
        expect(_railIds(tester), [300, 1, 2, 3]);
        expect(_centeredId(tester), 300);
        _expectRail(tester, dot: 0, offset: 0);
      });
    });

    testWidgets('a save outside the chip leaves it after the reply and stays '
        'in the whole list', (tester) async {
      final server = _Server(travel: true);
      await _withApp(tester, server, () async {
        await tester.tap(_chip('여행'));
        await tester.pumpAndSettle();
        await _toSecondCard(tester);
        final gate = server.feedGate = Completer<void>();
        await _saveAndReturnHome(tester);
        expect(_selectedChip(tester), '여행');
        expect(_centeredId(tester), 300);
        _expectRail(tester, dot: 0, offset: 0);

        server.feedGate = null;
        gate.complete();
        await tester.pumpAndSettle();
        expect(_selectedChip(tester), '여행');
        expect(server.feedCategories.last, '102');
        expect(_railIds(tester), [10, 11]);
        expect(_centeredId(tester), 10);
        _expectRail(tester, dot: 0, offset: 0);

        await tester.tap(_chip('전체보기'));
        await tester.pumpAndSettle();
        expect(_railIds(tester).first, 300);
      });
    });

    testWidgets('a newer card with the same title comes first by id', (
      tester,
    ) async {
      final server = _Server()..newerAfterSave = _item(301, title: '카드 300');
      await _withApp(tester, server, () async {
        await _toSecondCard(tester);
        final gate = server.feedGate = Completer<void>();
        await _saveAndReturnHome(tester);
        expect(_centeredId(tester), 300);
        _expectRail(tester, dot: 0, offset: 0);

        server.feedGate = null;
        gate.complete();
        await tester.pumpAndSettle();
        expect(_railIds(tester), [301, 300, 1, 2]);
        expect(_centeredId(tester), 301);
        _expectRail(tester, dot: 0, offset: 0);
      });
    });
  });
}
