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
        ['알림 설정', '앱 권한'],
        ['문의하기', '앱 버전'],
      ]);
      expect(find.text('공지사항'), findsNothing);
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
  });

  testWidgets('support rows keep row size and the group shrinks by one row', (
    tester,
  ) async {
    await _my(tester, fixture.myMember);
    final groups = find.byType(MyListGroup);
    final management = tester.getRect(groups.at(0));
    final support = tester.getRect(groups.at(1));
    final heights = {
      for (final title in ['알림 설정', '앱 권한', '문의하기', '앱 버전'])
        title: tester
            .getSize(
              find.ancestor(
                of: find.text(title),
                matching: find.byType(MyListTile),
              ),
            )
            .height,
    };
    expect(heights.values.toSet(), {heights['알림 설정']});
    expect(support.height, management.height);
    expect(support.width, management.width);
  });
}
