import 'dart:ui' as ui;

import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/navigation_alignment_fixture.dart' as f;

const _routes = [
  AppRoute.home,
  AppRoute.archive,
  AppRoute.bookmark,
  AppRoute.my,
];

// Measure painted geometry, independently of the 28px layout slot. Recover
// coverage from the known foreground/background colors so both styles use 50%.
Future<Offset> _starCenter(
  WidgetTester tester,
  GlobalKey key,
  int active,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final slot = tester.getRect(find.byKey(const ValueKey('navigation-icon-2')));
  final origin = boundary.localToGlobal(Offset.zero);
  return (await tester.runAsync(() async {
    const ratio = 8.0;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    final crop = slot.shift(-origin);
    final threshold = active == 2 ? (255 + 26) / 2 : (255 + 209) / 2;
    var left = image.width, top = image.height, right = -1, bottom = -1;
    for (
      var y = (crop.top * ratio).ceil();
      y < (crop.bottom * ratio).floor();
      y++
    ) {
      for (
        var x = (crop.left * ratio).ceil();
        x < (crop.right * ratio).floor();
        x++
      ) {
        if (bytes[(y * image.width + x) * 4] < threshold) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }
    image.dispose();
    expect(right, greaterThan(left), reason: 'star must actually paint');
    return origin +
        Offset(
          (left + right + 1) / (2 * ratio),
          (top + bottom + 1) / (2 * ratio),
        );
  }))!;
}

void main() {
  setUpAll(f.navigationLoadFonts);
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'star stays fixed through real tab taps $platform $width $scale',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 812);
            final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
            tester.view.padding = FakeViewPadding(bottom: bottom);
            tester.view.viewPadding = FakeViewPadding(bottom: bottom);
            addTearDown(tester.view.reset);
            var active = 0;
            var adds = 0;
            final key = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform, fontFamily: 'Pretendard'),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: StatefulBuilder(
                  builder: (context, setState) => Scaffold(
                    body: Text('destination-${_routes[active].name}'),
                    bottomNavigationBar: RepaintBoundary(
                      key: key,
                      child: ClipbackNavigationBar(
                        activeIndex: active,
                        onTap: (route) =>
                            setState(() => active = _routes.indexOf(route)),
                        onAdd: () => adds++,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final slots = [
              for (var i = 0; i < 4; i++)
                tester.getRect(find.byKey(ValueKey('navigation-icon-$i'))),
            ];
            final initial = await _starCenter(tester, key, active);
            // Home -> archive -> home is deliberately first: catches the original
            // 1 logical pixel defect after verifying the tap changed active state.
            for (final next in [1, 0, 2, 1, 2, 3, 1, 3, 0, 1, 2, 3, 2, 1, 0]) {
              await tester.tap(find.text(f.navigationLabels[next]));
              await tester.pump(); // no settle between rapid taps
              expect(
                tester
                    .widget<ClipbackNavigationBar>(
                      find.byType(ClipbackNavigationBar),
                    )
                    .activeIndex,
                next,
              );
              expect(
                find.text('destination-${_routes[next].name}'),
                findsOneWidget,
              );
              for (var i = 0; i < 4; i++) {
                expect(
                  tester.getRect(find.byKey(ValueKey('navigation-icon-$i'))),
                  slots[i],
                );
                expect(
                  tester
                      .widget<Text>(find.text(f.navigationLabels[i]))
                      .style!
                      .color,
                  i == next ? AppColors.text : AppColors.subtler,
                );
              }
              final center = await _starCenter(tester, key, next);
              expect(center.dx, closeTo(initial.dx, .15));
              expect(center.dy, closeTo(initial.dy, .15));
              expect(center.dx - slots[2].left, closeTo(14.25, .15));
              expect(center.dy - slots[2].top, closeTo(13.5, .15));
              expect(tester.takeException(), isNull);
            }
            await tester.pumpAndSettle();
            await tester.tap(find.byType(NavAddButton));
            await tester.pumpAndSettle();
            expect(adds, 1);
            expect(active, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
