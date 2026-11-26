// #486: the notice list reads `GET /api/v1/notices` on entry. Parsing, the
// order table's root flows (weekly memory server) and the server-only shapes
// (not pinned, no steps) on real Pretendard fonts.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/notice_detail_screen.dart';
import 'package:clipback_frontend/features/account/notice_list_screen.dart';
import 'package:clipback_frontend/features/account/notices.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'auth_navigation.dart';
import 'fixtures/notice_alignment_fixture.dart'
    show noticesJson, revisionNotice;
import 'fixtures/weekly_server.dart';
import 'weekly_root_test.dart' show withHome, home;

Map<String, dynamic> _serverFile() =>
    jsonDecode(File('../backend/app/notices.json').readAsStringSync())
        as Map<String, dynamic>;

void _expectSame(List<Notice> actual, List<Notice> expected) {
  expect(actual, hasLength(expected.length));
  for (var i = 0; i < expected.length; i++) {
    final a = actual[i], e = expected[i];
    expect(
      [a.title, a.publishedLabel, a.pinned, a.introTitle, a.intro],
      [e.title, e.publishedLabel, e.pinned, e.introTitle, e.intro],
    );
    expect([a.closingTitle, a.closing], [e.closingTitle, e.closing]);
    expect(
      [
        for (final s in a.steps) [s.title, s.body, s.note],
      ],
      [
        for (final s in e.steps) [s.title, s.body, s.note],
      ],
    );
  }
}

Map<String, dynamic> _changed(void Function(Map<String, dynamic>) change) {
  final data = _serverFile();
  change(data);
  return data;
}

Map<String, dynamic> _first(Map<String, dynamic> d) =>
    (d['notices'] as List).first as Map<String, dynamic>;
Map<String, dynamic> _firstStep(Map<String, dynamic> d) =>
    (_first(d)['steps'] as List).first as Map<String, dynamic>;

final _invalid = <String, void Function(Map<String, dynamic>)>{
  'empty list': (d) => d['notices'] = [],
  'notices null': (d) => d['notices'] = null,
  'notices missing': (d) => d.remove('notices'),
  'notice not an object': (d) => (d['notices'] as List).add('x'),
  'title missing': (d) => _first(d).remove('title'),
  'title empty': (d) => _first(d)['title'] = '',
  'title null': (d) => _first(d)['title'] = null,
  'title number': (d) => _first(d)['title'] = 1,
  'title array': (d) => _first(d)['title'] = ['a'],
  'intro empty': (d) => _first(d)['intro'] = '',
  'closing missing': (d) => _first(d).remove('closing'),
  'closing_title empty': (d) => _first(d)['closing_title'] = '',
  'intro_title number': (d) => _first(d)['intro_title'] = 3,
  'pinned string': (d) => _first(d)['pinned'] = 'true',
  'pinned null': (d) => _first(d)['pinned'] = null,
  'date missing': (d) => _first(d).remove('published_on'),
  'date text': (d) => _first(d)['published_on'] = '2026. 11. 23',
  'date impossible': (d) => _first(d)['published_on'] = '2026-02-30',
  'date time': (d) => _first(d)['published_on'] = '2026-11-23T00:00:00',
  'date number': (d) => _first(d)['published_on'] = 20261123,
  'steps null': (d) => _first(d)['steps'] = null,
  'steps object': (d) => _first(d)['steps'] = {},
  'step body empty': (d) => _firstStep(d)['body'] = '',
  'step title missing': (d) => _firstStep(d).remove('title'),
  'step note number': (d) => _firstStep(d)['note'] = 1,
  'step note array': (d) => _firstStep(d)['note'] = ['a'],
};

/// Answers `GET /api/v1/notices` with [answer] after [hold], recording it.
Future<http.Response?> Function(WeeklyServer, http.Request) _notices(
  List<String> log,
  FutureOr<http.Response> Function(WeeklyServer) answer, {
  List<Completer<void>>? holds,
}) => (s, r) async {
  if (r.url.path != '/api/v1/notices') return null;
  log.add('${r.method} ${r.url.path}');
  final hold = holds == null || holds.isEmpty ? null : holds.removeAt(0);
  await hold?.future;
  return answer(s);
};

http.Response _added(WeeklyServer s) =>
    s.json(noticesJson([...notices, revisionNotice]));

List<String> _rows(WidgetTester t) => [
  for (final n
      in t.widget<NoticeListScreen>(find.byType(NoticeListScreen)).notices)
    n.title,
];

const _inApp = ['허투루 100% 활용법', '허투루 사용이 처음이라면?'];
final _withRevision = [..._inApp, revisionNotice.title];

Future<void> _openFromMy(WidgetTester t) async {
  home(t).onTab(AppRoute.my);
  await t.pumpAndSettle();
  await t.tap(find.text('공지사항'));
  await t.pump();
}

Future<void> _back(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('notice-back-hit')));
  await t.pumpAndSettle();
}

Future<void> _fonts() async {
  final pretendard = FontLoader('Pretendard');
  for (final weight in ['Regular', 'Medium', 'SemiBold']) {
    pretendard.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
  }
  await pretendard.load();
  final bold = FontLoader('PretendardDetail')
    ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'));
  await bold.load();
}

Future<void> _show(
  WidgetTester t,
  Widget child, {
  required double width,
  required double scale,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 812);
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  t.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('parsing', () {
    test('the server file is the in-app two: text, order and date', () {
      _expectSame(noticesFromJson(_serverFile()), notices);
      expect(notices.first.publishedLabel, '2026. 11. 23');
    });

    test('no steps and a null note are allowed', () {
      final parsed = noticesFromJson(noticesJson([revisionNotice]));
      _expectSame(parsed, [revisionNotice]);
      expect(parsed.single.steps, isEmpty);
    });

    for (final MapEntry(key: name, value: change) in _invalid.entries) {
      test('$name rejects the whole answer', () {
        expect(
          () => noticesFromJson(_changed(change)),
          throwsA(isA<FormatException>()),
        );
      });
    }

    test('a non-object answer is rejected', () {
      for (final json in [null, 'x', 1, <Object?>[]]) {
        expect(() => noticesFromJson(json), throwsFormatException);
      }
    });
  });

  group('root flows', () {
    testWidgets('My entry shows the last list at once, then the answer', (
      t,
    ) async {
      final log = <String>[];
      final hold = Completer<void>();
      await withHome(t, (s) async {
        await _openFromMy(t);
        // The entry frame already shows the list; the request has started.
        expect(_rows(t), _inApp);
        expect(log, ['GET /api/v1/notices']);
        hold.complete();
        await t.pumpAndSettle();
        expect(_rows(t), _withRevision);
        expect(find.text(revisionNotice.title), findsOneWidget);
        expect(log, hasLength(1));
      }, intercept: _notices(log, _added, holds: [hold]));
    });

    testWidgets('the bell entry asks too; back returns home', (t) async {
      final log = <String>[];
      await withHome(t, (s) async {
        await t.tap(find.bySemanticsLabel('알림'));
        await t.pumpAndSettle();
        expect(_rows(t), _withRevision);
        expect(log, ['GET /api/v1/notices']);
        await _back(t);
        expect(find.byType(HomeScreen), findsOneWidget);
      }, intercept: _notices(log, _added));
    });

    for (final MapEntry(key: name, value: answer)
        in <String, FutureOr<http.Response> Function(WeeklyServer)>{
          '503 maintenance': (s) => s.json({
            'detail': {'code': 'service_maintenance'},
          }, 503),
          '404': (s) => s.json({'detail': 'Not Found'}, 404),
          'connection lost': (s) =>
              throw http.ClientException('connection lost'),
          'one bad notice among good ones': (s) {
            final data = noticesJson([...notices, revisionNotice]);
            ((data['notices'] as List).last as Map)['title'] = '';
            return s.json(data);
          },
          'not json': (s) => http.Response('<html>', 200),
        }.entries) {
      testWidgets('$name keeps the in-app list quietly', (t) async {
        final log = <String>[];
        await withHome(t, (s) async {
          await _openFromMy(t);
          await t.pumpAndSettle();
          expect(_rows(t), _inApp);
          expect(find.byType(SnackBar), findsNothing);
          expect(t.takeException(), isNull);
          await _back(t);
          // The next entry asks again.
          await t.tap(find.text('공지사항'));
          await t.pumpAndSettle();
          expect(log, ['GET /api/v1/notices', 'GET /api/v1/notices']);
          expect(_rows(t), _inApp);
        }, intercept: _notices(log, answer));
      });
    }

    testWidgets('an answer during a detail shows on the list back; no resend', (
      t,
    ) async {
      final log = <String>[];
      final hold = Completer<void>();
      await withHome(t, (s) async {
        await _openFromMy(t);
        await t.pumpAndSettle();
        await t.tap(find.text('허투루 사용이 처음이라면?'));
        await t.pumpAndSettle();
        hold.complete();
        await t.pumpAndSettle();
        // The opened notice stays as tapped.
        expect(find.byType(NoticeDetailScreen), findsOneWidget);
        expect(find.text(firstTimeNotice.introTitle), findsOneWidget);
        await _back(t);
        expect(_rows(t), _withRevision);
        expect(log, ['GET /api/v1/notices']);
      }, intercept: _notices(log, _added, holds: [hold]));
    });

    testWidgets('an answer after closing the list shows on the next entry', (
      t,
    ) async {
      final log = <String>[];
      final first = Completer<void>(), second = Completer<void>();
      await withHome(t, (s) async {
        await _openFromMy(t);
        await t.pumpAndSettle();
        await _back(t);
        expect(find.byType(MyScreen), findsOneWidget);
        first.complete();
        await t.pumpAndSettle();
        await t.tap(find.text('공지사항'));
        await t.pump();
        // Stored, so the entry frame shows it before the second answer.
        expect(_rows(t), _withRevision);
        expect(log, hasLength(2));
        second.complete();
        await t.pumpAndSettle();
      }, intercept: _notices(log, _added, holds: [first, second]));
    });

    testWidgets('re-entry during the first request sends nothing new', (
      t,
    ) async {
      final log = <String>[];
      final hold = Completer<void>();
      await withHome(t, (s) async {
        await _openFromMy(t);
        await t.pumpAndSettle();
        await _back(t);
        await t.tap(find.text('공지사항'));
        await t.pumpAndSettle();
        expect(log, hasLength(1));
        expect(_rows(t), _inApp);
        hold.complete();
        await t.pumpAndSettle();
        expect(_rows(t), _withRevision);
        expect(log, hasLength(1));
      }, intercept: _notices(log, _added, holds: [hold]));
    });

    testWidgets('an answer after logout is kept for the next login', (t) async {
      final log = <String>[];
      final first = Completer<void>(), second = Completer<void>();
      await withHome(
        t,
        (s) async {
          await _openFromMy(t);
          await t.pumpAndSettle();
          await _back(t);
          t.widget<MyScreen>(find.byType(MyScreen)).onOpenAccount();
          await t.pumpAndSettle();
          await logoutFromAccount(t);
          await t.pumpAndSettle();
          first.complete();
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await startGuestAndFinishOnboarding(t);
          await _openFromMy(t);
          expect(_rows(t), _withRevision);
          second.complete();
          await t.pumpAndSettle();
          expect(log, hasLength(2));
        },
        intercept: (s, r) async =>
            await _notices(log, _added, holds: [first, second])(s, r) ??
            (r.url.path == '/api/v1/auth/logout'
                ? http.Response('', 204)
                : null),
      );
    });

    testWidgets('an answer after the app is gone changes nothing', (t) async {
      final log = <String>[];
      final hold = Completer<void>();
      await withHome(t, (s) async {
        await _openFromMy(t);
        await t.pumpAndSettle();
        await t.pumpWidget(const SizedBox.shrink());
        hold.complete();
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(log, hasLength(1));
      }, intercept: _notices(log, _added, holds: [hold]));
    });
  });

  group('server-only shapes', () {
    setUpAll(_fonts);
    final list = [...notices, revisionNotice];
    for (final width in [320.0, 360.0, 393.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$width x$scale a row without a pin fits', (t) async {
          await _show(
            t,
            NoticeListScreen(notices: list, onBack: () {}, onOpen: (_) {}),
            width: width,
            scale: scale,
          );
          expect(t.takeException(), isNull);
          expect(find.byKey(const ValueKey('notice-pin-2')), findsNothing);
          final row = t.getRect(find.byKey(const ValueKey('notice-row-2')));
          final title = t.getRect(find.byKey(const ValueKey('notice-title-2')));
          final arrow = t.getRect(find.byKey(const ValueKey('notice-arrow-2')));
          expect(title.left, row.left + 16);
          expect(title.right, lessThanOrEqualTo(arrow.left));
        });

        testWidgets('$width x$scale a detail without steps fits', (t) async {
          await _show(
            t,
            NoticeDetailScreen(notice: revisionNotice, onBack: () {}),
            width: width,
            scale: scale,
          );
          expect(t.takeException(), isNull);
          expect(find.textContaining('STEP'), findsNothing);
          for (final text in [
            revisionNotice.title,
            revisionNotice.introTitle,
            revisionNotice.intro,
            revisionNotice.closingTitle,
            revisionNotice.closing,
            noticeFooter,
          ]) {
            await t.scrollUntilVisible(
              find.text(text),
              200,
              scrollable: find
                  .descendant(
                    of: find.byKey(const ValueKey('notice-detail-scroll')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            expect(find.text(text), findsOneWidget);
          }
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
