import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/notice_list_screen.dart';
import 'package:clipback_frontend/features/account/notices.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/notice_alignment_fixture.dart' as fixture;

Finder get _notice => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == 'NoticeListScreen',
);
Future<void> _root(
  WidgetTester tester,
  Future<void> Function(fixture.NoticeServer server) body, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  String kind = 'member',
  ValueChanged<Notice>? onOpen,
}) async {
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final server = fixture.NoticeServer(kind);
  addTearDown(server.client.close);
  try {
    await tester.pumpWidget(
      MaterialApp(
        home: NoticeListScreen(
          notices: notices,
          onBack: () {},
          onOpen: onOpen ?? (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await body(server);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = previous;
  }
}

void _expectOracle(WidgetTester tester) {
  final measure = fixture.noticeMeasure(tester.element(_notice)),
      judge = fixture.noticeJudgment(measure);
  for (final pair in {
    'stylePassed': 'styleFailures',
    'layoutPassed': 'layoutFailures',
    'assetPassed': 'assetFailures',
  }.entries) {
    expect(judge[pair.key], isTrue, reason: '${judge[pair.value]}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await fixture.noticeLoadFonts(loadForTest: true);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width K01 actual roles geometry source and two pinned notices open their detail',
        (tester) async {
          for (final kind in ['member', 'guest']) {
            final opened = <Notice>[];
            await _root(
              tester,
              (server) async {
                expect(_notice, findsOneWidget);
                expect(find.byType(MyScreen), findsNothing);
                _expectOracle(tester);
                final m = fixture.noticeMeasure(tester.element(_notice));
                expect(m['titles'], ['허투루 100% 활용법', '허투루 사용이 처음이라면?']);
                final rows = m['rows'] as List;
                expect(rows.length, 2);
                for (final row in rows) {
                  expect(row['bounds']['height'], closeTo(82, .5));
                  expect((row['dateStyle'] as Map)['text'], '2026. 11. 23');
                  expect((row['pinStyle'] as Map)['text'], '📌');
                }
                expect(find.text('📌'), findsNWidgets(2));
                final requests = server.requests.length,
                    records = server.records.length;
                for (final notice in notices) {
                  await tester.ensureVisible(find.text(notice.title));
                  await tester.tap(find.text(notice.title));
                  await tester.pumpAndSettle();
                  expect(_notice, findsOneWidget);
                }
                expect(opened, notices);
                expect(server.requests.length, requests);
                expect(server.records.length, records);
                expect(server.writes, 0);
                expect(server.logoutCalls, 0);
                expect(tester.takeException(), isNull);
              },
              platform: platform,
              width: width,
              kind: kind,
              onOpen: opened.add,
            );
          }
        },
      );
    }
    testWidgets(
      '${platform.name} low K01 viewport exposes last row plus 24px and OS safety once',
      (tester) async {
        await _root(
          tester,
          (server) async {
            expect(_notice, findsOneWidget);
            // Two notices (#420 decision 3) scroll only below 360px.
            tester.view.physicalSize = const Size(320, 250);
            await tester.pumpAndSettle();
            final p = fixture.noticePosition(tester.element(_notice))!;
            expect(p.maxScrollExtent, greaterThan(0));
            await tester.drag(
              find.byKey(const ValueKey('notice-viewport')),
              const Offset(0, -350),
            );
            await tester.pumpAndSettle();
            expect(p.pixels, closeTo(p.maxScrollExtent, .2));
            _expectOracle(tester);
            expect(find.text(notices.last.title).hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
          platform: platform,
          width: 320,
        );
      },
    );
  }
  test('K01 retains real bundled Pretendard declarations', () async {
    final fonts = await fixture.noticeLoadFonts();
    expect(fonts['available'], isTrue);
    expect(fonts['declared'], isTrue);
    expect(fonts['bytes'], greaterThan(1000));
  });
}
