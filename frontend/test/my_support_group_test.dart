import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/my_preview.dart' as fixture;

Future<void> _my(
  WidgetTester tester,
  AppUser user, {
  double height = 812,
  String? statsMessage,
  VoidCallback? onRetryStats,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(320, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MyScreen(
        user: user,
        appInfo: fixture.myAppInfo,
        onAddLink: ({required url, submissionKey, category}) async =>
            throw UnimplementedError(),
        onAddScreenshot:
            ({
              required bytes,
              required filename,
              String? submissionKey,
              category,
            }) async => throw UnimplementedError(),
        onOpenAccount: () {},
        onTab: (_) {},
        statsMessage: statsMessage,
        onRetryStats: onRetryStats,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<List<String>> _groups(WidgetTester tester) => tester
    .widgetList<MyListGroup>(find.byType(MyListGroup))
    .map((g) => g.children.whereType<MyListTile>().map((t) => t.title).toList())
    .toList();

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  for (final (label, user) in [
    ('member', fixture.myMember),
    ('guest', fixture.myGuest),
  ]) {
    testWidgets('$label My support group has no notice row', (tester) async {
      await _my(tester, user);
      expect(_groups(tester), [
        ['문의하기', '이용약관 및 개인정보', '오픈소스 라이선스', '앱 버전'],
      ]);
      expect(find.text('공지사항'), findsNothing);
    });

    testWidgets('$label My hides management header and rows in semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _my(tester, user);
        for (final text in ['관리', '알림 설정', '앱 권한']) {
          expect(find.text(text), findsNothing);
          expect(find.bySemanticsLabel(text), findsNothing);
        }
        final labels = [
          for (final text in [
            '나의 허투루',
            '고객지원',
            '문의하기',
            '이용약관 및 개인정보',
            '오픈소스 라이선스',
            '앱 버전',
          ])
            tester.getRect(find.bySemanticsLabel(RegExp(text)).first).top,
        ];
        expect(labels, [...labels]..sort());
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('scrolled to the end, version is the last row and no notice', (
    tester,
  ) async {
    await _my(tester, fixture.myMember, height: 480);
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -2000));
    await tester.pumpAndSettle();
    final position = Scrollable.of(
      tester.element(find.byType(MyListGroup).last),
    ).position;
    expect(position.pixels, position.maxScrollExtent);
    expect(find.text('공지사항'), findsNothing);
    final tiles = tester.widgetList<MyListTile>(find.byType(MyListTile));
    expect(tiles.last.title, '앱 버전');
    final viewport = tester.getRect(find.byType(Scrollable).first);
    expect(
      viewport.bottom - tester.getRect(find.byType(MyListGroup).last).bottom,
      24,
    );
  });

  for (final error in [false, true]) {
    testWidgets(
      'support header follows ${error ? 'stats error retry' : 'stats strip'} after one 16 gap',
      (tester) async {
        await _my(
          tester,
          fixture.myMember,
          statsMessage: error ? '통계를 불러오지 못했어요.' : null,
          onRetryStats: error ? () {} : null,
        );
        final above = error
            ? tester.getRect(find.widgetWithText(OutlinedButton, '다시 시도'))
            : tester.getRect(find.byType(MyStatsStrip));
        final header = tester.getRect(
          find.widgetWithText(MySectionHeader, '고객지원'),
        );
        expect(header.top - above.bottom, 16);
        expect(find.text('관리'), findsNothing);
      },
    );
  }

  testWidgets('support rows keep row size and the group is rows times height', (
    tester,
  ) async {
    await _my(tester, fixture.myMember);
    final groups = find.byType(MyListGroup);
    final support = tester.getRect(groups);
    final heights = {
      for (final title in ['문의하기', '이용약관 및 개인정보', '오픈소스 라이선스', '앱 버전'])
        title: tester
            .getSize(
              find.ancestor(
                of: find.text(title),
                matching: find.byType(MyListTile),
              ),
            )
            .height,
    };
    expect(heights.values.toSet(), {heights['문의하기']});
    expect(support.height, 4 * heights['문의하기']!);
    // Was the management group width: the support surface inside the 16px
    // side margins spans the My list width minus 32.
    expect(support.width, tester.getRect(find.byType(ListView)).width);
    final surface = find.descendant(
      of: groups,
      matching: find.byType(Container),
    );
    expect(
      tester.getRect(surface.first).width,
      tester.getRect(find.byType(ListView)).width - 32,
    );
  });
}
