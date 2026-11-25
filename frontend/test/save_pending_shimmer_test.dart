import 'dart:ui' as ui;

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/skeleton_shimmer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/link_pending_fixture.dart' as link;
import 'fixtures/photo_pending_fixture.dart' as photo;
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as login;

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _openSaveScreen(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 812);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ClipbackApp(
      sessionStorage: login.LoginMemoryStorage()..value = link.pendingSession,
      socialAuth: login.LoginControlledSocial(TargetPlatform.android),
    ),
  );
  await completeAppStartup(tester);
  await tester.tap(
    find.byWidgetPredicate((w) => w.runtimeType.toString() == 'NavAddButton'),
  );
  await tester.pump();
}

Future<void> _submitLink(WidgetTester tester) async {
  await _openSaveScreen(tester);
  await tester.enterText(find.byType(TextField), link.pendingLink);
  await tester.pump(const Duration(milliseconds: 400));
  tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).onPressed();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<({ByteData bytes, int width, Offset origin})> _captureRoute(
  WidgetTester tester,
  String prefix,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .ancestor(
          of: _key('$prefix-skeleton'),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (
      bytes: bytes!,
      width: width,
      origin: boundary.localToGlobal(Offset.zero),
    );
  }))!;
}

/// RGBA of each pixel on the middle row of one bar, with its screen x.
List<(int, List<int>)> _barRow(
  WidgetTester tester,
  ({ByteData bytes, int width, Offset origin}) shot,
  String key,
) {
  final rect = tester.getRect(_key(key)).shift(-shot.origin);
  final y = rect.center.dy.floor();
  return [
    for (var x = rect.left.ceil() + 4; x < rect.right.floor() - 4; x++)
      (
        x,
        [
          for (var channel = 0; channel < 4; channel++)
            shot.bytes.getUint8((y * shot.width + x) * 4 + channel),
        ],
      ),
  ];
}

double? _bandCenter(List<(int, List<int>)> row) {
  var total = 0.0, weighted = 0.0;
  for (final (x, rgba) in row) {
    final lift = rgba[0] - 0xE4;
    if (lift <= 0) continue;
    total += lift;
    weighted += lift * x;
  }
  return total == 0 ? null : weighted / total;
}

Future<void> _expectSharedShimmer(WidgetTester tester, String prefix) async {
  final skeleton = _key('$prefix-skeleton');
  final area = find.ancestor(
    of: skeleton,
    matching: find.byType(SkeletonShimmer),
  );
  expect(area, findsOneWidget);
  for (final group in ['$prefix-preview', '$prefix-category']) {
    final bars = find.descendant(
      of: _key(group),
      matching: find.byType(SkeletonShimmerBars),
    );
    expect(bars, findsOneWidget);
    expect(
      find.ancestor(of: bars, matching: find.byWidget(tester.widget(area))),
      findsOneWidget,
    );
  }
  expect(find.byType(ShaderMask), findsNothing);

  // One band crosses both boxes: same screen x, and it moves to the right.
  await tester.pump(const Duration(milliseconds: 400));
  final first = await _captureRoute(tester, prefix);
  final previewAt = _bandCenter(_barRow(tester, first, '$prefix-thumbnail'));
  final categoryAt = _bandCenter(
    _barRow(tester, first, '$prefix-category-bar'),
  );
  expect(previewAt, isNotNull);
  expect(categoryAt, closeTo(previewAt!, 1.5));

  await tester.pump(const Duration(milliseconds: 100));
  final later = await _captureRoute(tester, prefix);
  expect(
    _bandCenter(_barRow(tester, later, '$prefix-thumbnail')),
    greaterThan(previewAt),
  );
}

void _expectHeadingsRead(String prefix) {
  expect(find.bySemanticsLabel('미리보기'), findsOneWidget);
  expect(find.bySemanticsLabel('카테고리'), findsOneWidget);
  expect(find.bySemanticsLabel('허투루가 분류하고 있어요.'), findsOneWidget);
  for (final bar in ['thumbnail', 'bar-1', 'bar-2', 'bar-3', 'category-bar']) {
    expect(
      find.ancestor(
        of: _key('$prefix-$bar'),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('link pending shimmers both bar groups in one phase', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final server = link.LinkPendingServer();
    try {
      await http.runWithClient(() async {
        await _submitLink(tester);
        await _expectSharedShimmer(tester, 'link-pending');
        _expectHeadingsRead('link-pending');

        server.resolve();
        await tester.pumpAndSettle();
        expect(find.byType(SavedContentConfirmation), findsOneWidget);
        expect(find.byType(SkeletonShimmer), findsNothing);
        expect(server.submissions, [link.pendingLink]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }, () => server.controlledClient);
    } finally {
      semantics.dispose();
      server.close();
    }
  });

  testWidgets('link failure removes the shimmer after one submission', (
    tester,
  ) async {
    final server = link.LinkPendingServer();
    try {
      await http.runWithClient(() async {
        await _submitLink(tester);
        expect(find.byType(SkeletonShimmer), findsOneWidget);

        server.resolve(success: false);
        await tester.pumpAndSettle();
        expect(find.byType(SkeletonShimmer), findsNothing);
        expect(find.byType(SavedContentConfirmation), findsNothing);
        expect(server.submissions, [link.pendingLink]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }, () => server.controlledClient);
    } finally {
      server.close();
    }
  });

  testWidgets('reduced motion keeps the pending bars still', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final server = link.LinkPendingServer();
    try {
      await http.runWithClient(() async {
        await _submitLink(tester);
        expect(find.byType(SkeletonShimmerBars), findsNWidgets(2));
        expect(find.byType(ShaderMask), findsNothing);
        expect(_key('link-pending-category-bar'), findsOneWidget);
        final first = await _captureRoute(tester, 'link-pending');
        await tester.pump(const Duration(milliseconds: 500));
        final later = await _captureRoute(tester, 'link-pending');
        for (final bar in ['thumbnail', 'category-bar']) {
          final row = _barRow(tester, first, 'link-pending-$bar');
          expect(row, isNotEmpty);
          for (final (_, rgba) in row) {
            expect(rgba, [0xE4, 0xE4, 0xE4, 0xFF]);
          }
          expect(
            [
              for (final (_, rgba) in _barRow(
                tester,
                later,
                'link-pending-$bar',
              ))
                rgba,
            ],
            [for (final (_, rgba) in row) rgba],
          );
        }

        server.resolve();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }, () => server.controlledClient);
    } finally {
      server.close();
    }
  });

  testWidgets('photo pending shimmers both bar groups in one phase', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final asset = await rootBundle.load(Assets.searchEmptyIllustration);
    final bytes = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    final server = photo.PhotoPendingServer(bytes);
    FilePicker? previous;
    try {
      previous = FilePicker.platform;
    } catch (_) {}
    FilePicker.platform = photo.PendingPhotoPicker([
      photo.PendingPhoto(photo.photoName, bytes),
    ]);
    try {
      await http.runWithClient(() async {
        await _openSaveScreen(tester);
        await tester.tap(find.text('사진 첨부'));
        await tester.pump();
        await tester.tap(find.text('사진 선택'));
        await tester.pumpAndSettle();
        tester.widget<SaveFlowButton>(find.byType(SaveFlowButton)).onPressed();
        await tester.pump(const Duration(milliseconds: 50));

        await _expectSharedShimmer(tester, 'photo-pending');
        _expectHeadingsRead('photo-pending');
        expect(server.submissions, [photo.photoName]);

        server.resolve();
        await tester.pumpAndSettle();
        expect(find.byType(SavedContentConfirmation), findsOneWidget);
        expect(find.byType(SkeletonShimmer), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }, () => server.photoClient);
    } finally {
      semantics.dispose();
      server.close();
      if (previous != null) FilePicker.platform = previous;
    }
  });
}
