import 'package:clipback_frontend/features/account/placeholder_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/navigation_alignment_fixture.dart' as f;

const routes = [
  AppRoute.home,
  AppRoute.archive,
  AppRoute.bookmark,
  AppRoute.my,
];
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(f.navigationLoadFonts);
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (var selected = 0; selected < 4; selected++) {
        testWidgets(
          '${platform.name} width $width selected $selected exact navigation sources tints labels and unchanged geometry',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 812);
            final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
            tester.view.padding = FakeViewPadding(top: 24, bottom: bottom);
            tester.view.viewPadding = FakeViewPadding(top: 24, bottom: bottom);
            addTearDown(tester.view.reset);
            final tapped = <AppRoute>[];
            var adds = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  useMaterial3: true,
                  platform: platform,
                  fontFamily: 'Pretendard',
                  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.main),
                ),
                home: Scaffold(
                  bottomNavigationBar: ClipbackNavigationBar(
                    activeIndex: selected,
                    onTap: tapped.add,
                    onAdd: () => adds++,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final measure = f.navigationMeasure(
              tester.element(find.byType(ClipbackNavigationBar)),
            );
            final judgment = f.navigationJudgment(measure);
            for (final pair in const {
              'stylePassed': 'styleFailures',
              'layoutPassed': 'layoutFailures',
              'assetPassed': 'assetFailures',
            }.entries) {
              expect(
                judgment[pair.key],
                isTrue,
                reason: '${judgment[pair.value]}',
              );
            }
            for (final label in f.navigationLabels) {
              await tester.tap(
                find.descendant(
                  of: find.byType(ClipbackNavigationBar),
                  matching: find.text(label),
                ),
              );
              await tester.pumpAndSettle();
            }
            expect(tapped, routes);
            final add = tester.getRect(find.byType(NavAddButton));
            await tester.tapAt(add.center);
            await tester.pumpAndSettle();
            await tester.tapAt(add.bottomCenter - const Offset(0, 2));
            await tester.pumpAndSettle();
            expect(adds, 2);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  for (var active = 0; active < 4; active++) {
    testWidgets(
      'Placeholder forwards active state $active with existing navigation callbacks',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PlaceholderScreen(title: '준비 중', activeIndex: active),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ClipbackNavigationBar>(find.byType(ClipbackNavigationBar))
              .activeIndex,
          active,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(ClipbackNavigationBar),
            matching: find.text('홈'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
