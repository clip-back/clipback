import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/home/notification_list_screen.dart';
import 'package:clipback_frontend/shared/models/app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/my_preview.dart' as fixture;

Future<void> _my(
  WidgetTester tester, {
  AppInfo? info = fixture.myAppInfo,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 812);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: MyScreen(
        user: fixture.myMember,
        appInfo: info,
        onAddLink: ({required url, category}) async =>
            throw UnimplementedError(),
        onAddScreenshot:
            ({required bytes, required filename, category}) async =>
                throw UnimplementedError(),
        onOpenAccount: () {},
        onTab: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });
  testWidgets(
    'approved management and support groups omit category and terms',
    (tester) async {
      await _my(tester);
      final groups = tester
          .widgetList<MyListGroup>(find.byType(MyListGroup))
          .toList();
      expect(
        groups
            .map(
              (g) => g.children
                  .whereType<MyListTile>()
                  .map((t) => t.title)
                  .toList(),
            )
            .toList(),
        [
          ['알림 설정', '앱 권한'],
          ['공지사항', '문의하기', '앱 버전'],
        ],
      );
      expect(find.text('카테고리 관리'), findsNothing);
      expect(find.text('이용약관 및 개인정보'), findsNothing);
    },
  );
  for (final info in [fixture.myAppInfo, null]) {
    testWidgets(
      'version ${info?.version ?? 'failure'} has no tap action or navigation',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _my(tester, info: info);
          final row = find.ancestor(
            of: find.text('앱 버전'),
            matching: find.byType(MyListTile),
          );
          await tester.ensureVisible(row);
          final context = tester.element(row);
          final route = ModalRoute.of(context);
          final position = Scrollable.of(context).position;
          final offset = position.pixels;
          final nodes = tester.semantics
              .simulatedAccessibilityTraversal()
              .where((n) => n.label.contains('앱 버전'))
              .toList();
          expect(nodes, isNotEmpty);
          for (final node in nodes) {
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              isFalse,
            );
            expect(node.getSemanticsData().flagsCollection.isButton, isFalse);
          }
          await tester.tapAt(tester.getCenter(row));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(ModalRoute.of(tester.element(row)), same(route));
          expect(position.pixels, offset);
          expect(
            find.text(info == null ? '-' : 'ver. ${info.version}'),
            findsOneWidget,
          );
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets(
    'notification header has no settings icon hit surface or semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationListScreen(
              items: const [(title: '알림 내용', time: '지금')],
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('notification-settings-image')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('notification-settings-hit')),
          findsNothing,
        );
        expect(
          tester.semantics.simulatedAccessibilityTraversal().where(
            (n) => n.label.contains('설정'),
          ),
          isEmpty,
        );
        final header = tester.getRect(
          find.byKey(const ValueKey('notification-header')),
        );
        await tester.tapAt(Offset(header.right - 28, header.center.dy));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(ReminderSheet), findsNothing);
        expect(find.text('알림 내용'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'My notification settings keeps read-only values and scroll on return',
    (tester) async {
      await _my(tester);
      tester.view.physicalSize = const Size(320, 480);
      await tester.pumpAndSettle();
      final target = find.text('알림 설정');
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      final position = Scrollable.of(tester.element(target)).position;
      final offset = position.pixels;
      await tester.tap(target);
      await tester.pumpAndSettle();
      final sheet = find.byType(ReminderSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('알림 설정')),
        findsOneWidget,
      );
      for (final pair in {
        '오늘의 리마인드': '오후 8:00',
        '반복': '매일',
        '추천 콘텐츠': '켜짐',
      }.entries) {
        expect(
          find.descendant(of: sheet, matching: find.text(pair.key)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text(pair.value)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: sheet, matching: find.byType(Switch)),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.byType(EditableText)),
        findsNothing,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(position.pixels, offset);
      expect(find.byType(MyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 1.1, 1.2, 1.3]) {
    testWidgets('320px Pretendard menu and version fit scale $scale', (
      tester,
    ) async {
      await _my(
        tester,
        scale: scale,
        info: const AppInfo(version: '123.456.789', buildNumber: '999'),
      );
      for (final text in ['알림 설정', '앱 버전', 'ver. 123.456.789']) {
        final target = find.text(text);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: target, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, lessThanOrEqualTo(41));
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout();
        expect(painter.width, lessThanOrEqualTo(paragraph.size.width + .1));
        expect(tester.getRect(target).top, greaterThanOrEqualTo(0));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
