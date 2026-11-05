import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decode the asset selected by the rendered state at its native resolution.
Future<void> expectEmptyAssetResolution(
  WidgetTester tester,
  Finder finder, {
  required int minimumWidth,
  required int minimumHeight,
  String? digest,
  bool transparent = false,
  bool homeCrop = false,
  bool searchLayout = false,
}) async {
  expect(finder, findsOneWidget);
  final provider = tester.widget<Image>(finder).image as AssetImage;
  final decoded = (await tester.runAsync(() async {
    final bytes = await File(provider.assetName).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final pixels = (await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    final result = (
      width: frame.image.width,
      height: frame.image.height,
      pixels: pixels,
      digest: sha256.convert(bytes).toString(),
    );
    frame.image.dispose();
    codec.dispose();
    return result;
  }))!;
  expect(decoded.width, greaterThanOrEqualTo(minimumWidth));
  expect(decoded.height, greaterThanOrEqualTo(minimumHeight));
  if (digest != null) {
    expect(decoded.digest, digest);
  }
  final pixels = decoded.pixels;
  if (transparent) {
    expect(pixels[3], 0, reason: 'Figma original has a transparent corner');
    expect(
      Iterable<int>.generate(
        pixels.length ~/ 4,
        (i) => pixels[i * 4 + 3],
      ).any((alpha) => alpha == 255),
      isTrue,
    );
  }
  if (searchLayout) {
    final slot = find.byKey(const ValueKey('search-empty-image'));
    final slotRect = tester.getRect(slot), imageRect = tester.getRect(finder);
    final widget = tester.widget<Image>(finder);
    final native = Size(decoded.width.toDouble(), decoded.height.toDouble());
    final fitted = applyBoxFit(
      widget.fit ?? BoxFit.scaleDown,
      native,
      imageRect.size,
    );
    final alignment = widget.alignment.resolve(TextDirection.ltr);
    final source = alignment.inscribe(fitted.source, Offset.zero & native);
    final destination = alignment.inscribe(fitted.destination, imageRect);
    Rect visibleBounds(int threshold) {
      var left = decoded.width, top = decoded.height, right = 0, bottom = 0;
      for (var y = 0; y < decoded.height; y++) {
        for (var x = 0; x < decoded.width; x++) {
          if (pixels[(y * decoded.width + x) * 4 + 3] > threshold) {
            left = x < left ? x : left;
            top = y < top ? y : top;
            right = x + 1 > right ? x + 1 : right;
            bottom = y + 1 > bottom ? y + 1 : bottom;
          }
        }
      }
      return Rect.fromLTRB(
        destination.left +
            (left - source.left) * destination.width / source.width,
        destination.top +
            (top - source.top) * destination.height / source.height,
        destination.left +
            (right - source.left) * destination.width / source.width,
        destination.top +
            (bottom - source.top) * destination.height / source.height,
      );
    }

    final body = visibleBounds(128).shift(-slotRect.topLeft);
    final outline = visibleBounds(0).shift(-slotRect.topLeft);
    expect(slotRect.size, const Size(81, 123));
    expect(
      destination.width / source.width,
      closeTo(destination.height / source.height, .000001),
      reason: 'The approved original must keep a uniform scale',
    );
    expect(body.top, closeTo(2, .01));
    expect(body.height, closeTo(119, .01));
    expect(body.center.dx, closeTo(40.5, .01));
    expect(body.width, closeTo(76.88477, .01));
    final title = tester.getRect(
      find.byKey(const ValueKey('search-empty-title')),
    );
    expect(title.top - (slotRect.top + body.bottom), closeTo(18, .01));
    expect(outline.left, closeTo(.75171, .01));
    expect(outline.top, closeTo(-.04047, .01));
    expect(outline.right, closeTo(79.18724, .01));
    expect(outline.bottom, closeTo(125.81550, .01));
    final stacks = find.ancestor(of: finder, matching: find.byType(Stack));
    final localStack = tester.widget<Stack>(stacks.first);
    expect(
      localStack.clipBehavior,
      Clip.none,
      reason: 'Do not cut the faint original outline at the 81x123 slot',
    );
    // Reject a new local clip between the actual image and the slot's column.
    final clips = find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ClipRect || widget is ClipRRect || widget is ClipPath,
      ),
    );
    for (final element in clips.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(
        rect.size == slotRect.size,
        isFalse,
        reason: 'A slot-sized clip would hide the approved overflow',
      );
    }
  }
  if (homeCrop) {
    final logical = find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 67 && widget.height == 78,
      ),
    );
    expect(logical, findsOneWidget);
    expect(tester.getSize(finder), const Size(71, 82));
    final imageRect = tester.getRect(finder),
        logicalRect = tester.getRect(logical);
    expect(imageRect.left, logicalRect.left - 2);
    expect(imageRect.top, logicalRect.top);
    // Effective artwork, excluding the white export canvas and faint shadow.
    // A padded 1254px full original in this slot must not pass on size alone.
    var left = decoded.width, top = decoded.height, right = 0, bottom = 0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final i = (y * decoded.width + x) * 4;
        final ink =
            255 -
            (.299 * pixels[i] + .587 * pixels[i + 1] + .114 * pixels[i + 2]);
        if (pixels[i + 3] > 128 && ink >= 10) {
          left = x < left ? x : left;
          top = y < top ? y : top;
          right = x + 1 > right ? x + 1 : right;
          bottom = y + 1 > bottom ? y + 1 : bottom;
        }
      }
    }
    expect(right - left, greaterThanOrEqualTo(67 * 3));
    expect(bottom - top, greaterThanOrEqualTo(78 * 3));
    final scaleX = decoded.width / 71, scaleY = decoded.height / 82;
    // Old export's visible boundary at this threshold: (3,2)-(69,80).
    expect(left / scaleX, closeTo(3, 1));
    expect(top / scaleY, closeTo(2, 1));
    expect(right / scaleX, closeTo(69, 1));
    expect(bottom / scaleY, closeTo(80, 1));
  }
}
