import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/skeleton_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _captureKey = ValueKey('shimmer-capture');
const _barWidth = 200;
const _barHeight = 20;

Widget _bar() => Container(
  width: _barWidth.toDouble(),
  height: _barHeight.toDouble(),
  color: AppColors.faint,
);

Widget _harness({bool disableAnimations = false, required Widget child}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: _captureKey, child: child),
        ),
      ),
    );

Widget _singleBar({bool disableAnimations = false}) => _harness(
  disableAnimations: disableAnimations,
  child: SkeletonShimmer(child: SkeletonShimmerBars(child: _bar())),
);

Future<ByteData> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!;
  }))!;
}

/// Brightness-weighted x position of the band on one pixel row.
double? _bandCenter(ByteData bytes, {int y = _barHeight ~/ 2}) {
  final faint = (AppColors.faint.r * 255).round();
  var total = 0.0;
  var weighted = 0.0;
  for (var x = 0; x < _barWidth; x++) {
    final lift = bytes.getUint8((y * _barWidth + x) * 4) - faint;
    if (lift <= 0) continue;
    total += lift;
    weighted += lift * x;
  }
  return total == 0 ? null : weighted / total;
}

void main() {
  testWidgets('the band moves left to right and repeats every 1.5 seconds', (
    tester,
  ) async {
    await tester.pumpWidget(_singleBar());

    await tester.pump(const Duration(milliseconds: 500));
    final early = _bandCenter(await _capture(tester));
    await tester.pump(const Duration(milliseconds: 300));
    final middle = _bandCenter(await _capture(tester));
    await tester.pump(const Duration(milliseconds: 300));
    final late = _bandCenter(await _capture(tester));

    expect(early, isNotNull);
    expect(middle, greaterThan(early!));
    expect(late, greaterThan(middle!));

    await tester.pump(const Duration(milliseconds: 1500));
    expect(_bandCenter(await _capture(tester)), closeTo(late!, 1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the band uses only the existing faint and bg colors', (
    tester,
  ) async {
    await tester.pumpWidget(_singleBar());
    await tester.pump(const Duration(milliseconds: 750));
    final bytes = await _capture(tester);
    final faint = (AppColors.faint.r * 255).round();
    final bg = (AppColors.bg.r * 255).round();
    final row = [
      for (var x = 0; x < _barWidth; x++)
        bytes.getUint8((_barHeight ~/ 2 * _barWidth + x) * 4),
    ];

    expect(row.reduce((a, b) => a < b ? a : b), faint);
    expect(row.reduce((a, b) => a > b ? a : b), closeTo(bg, 1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('bar groups under one shimmer share the same phase', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        child: SkeletonShimmer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonShimmerBars(child: _bar()),
              SkeletonShimmerBars(child: _bar()),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final bytes = await _capture(tester);
    final first = _bandCenter(bytes, y: _barHeight ~/ 2);
    final second = _bandCenter(bytes, y: _barHeight + _barHeight ~/ 2);

    expect(first, isNotNull);
    expect(second, closeTo(first!, 1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final signal in ['disableAnimations', 'reduceMotion']) {
    testWidgets('$signal alone stops the band with no scheduled frame', (
      tester,
    ) async {
      if (signal == 'reduceMotion') {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      await tester.pumpWidget(
        _singleBar(disableAnimations: signal == 'disableAnimations'),
      );

      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle();

      final first = await _capture(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final second = await _capture(tester);
      await tester.pump(const Duration(milliseconds: 300));
      final third = await _capture(tester);

      expect(_bandCenter(first), isNull);
      expect(second.buffer.asUint8List(), first.buffer.asUint8List());
      expect(third.buffer.asUint8List(), first.buffer.asUint8List());
    });
  }

  testWidgets('no ticker remains after leaving the screen', (tester) async {
    await tester.pumpWidget(_singleBar());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.binding.transientCallbackCount, 0);
    // The frame requested by the last tick before disposal may still run once.
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('wrapped bars leave the semantics tree, siblings stay', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: SkeletonShimmer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('남는 제목'),
              SkeletonShimmerBars(
                child: Semantics(label: '막대', child: _bar()),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('남는 제목'), findsOneWidget);
    expect(find.bySemanticsLabel('막대'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
