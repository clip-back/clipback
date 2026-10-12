import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _content = ContentItem(
  id: 'screenshot-1',
  apiId: 1,
  title: '저장한 스크린샷',
  summary: '원본 이미지와 카테고리를 확인해요.',
  category: catUncategorized,
  savedAt: '방금',
  savedAtFull: '2026년 10월 12일',
  savedAtFullShort: '2026.10.12',
  tags: [],
  source: '스크린샷',
  originalUrl: '',
  originalText: '',
  isScreenshot: true,
  assets: [
    ApiAsset(
      id: 9,
      assetType: 'screenshot',
      downloadUrl: '/api/v1/uploads/assets/9',
    ),
  ],
);

final _portraitPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAQCAIAAACk6KkqAAAAGUlEQVR4nGOUrLjDgA0'
  'wYRVlGJXAAqgYVgBRYQGNcB1eZgAAAABJRU5ErkJggg==',
);

Finder _icon(String asset) => find.byWidgetPredicate(
  (widget) => widget is SvgIconButton && widget.asset == asset,
);

Finder get _memoryImages => find.byWidgetPredicate(
  (widget) => widget is Image && widget.image is MemoryImage,
);

void _setTopInset(WidgetTester tester, double top) {
  tester.view.padding = FakeViewPadding(top: top, bottom: 34);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: 34);
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required double top,
  double height = 812,
  List<CategoryItem> categories = const [],
  void Function(ContentItem, CategoryItem)? onChangeCategory,
  Future<Uint8List> Function(int)? onReadAsset,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(375, height);
  _setTopInset(tester, top);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Pretendard', platform: TargetPlatform.iOS),
      home: DetailScreen(
        content: _content,
        contents: const [_content],
        categories: categories,
        bookmarked: false,
        onReadAsset: onReadAsset ?? (_) async => _portraitPng,
        onBack: () {},
        onToggleBookmark: (_) {},
        onChangeCategory: onChangeCategory ?? (_, _) {},
        onDeleteContent: (_) {},
        onOpenOriginalLink: () {},
        onOpenAdjacent: (_) {},
        onOpenContent: (_) {},
        onAddLink: ({required url, category}) async => _content,
        onAddScreenshot:
            ({required bytes, required filename, category}) async => _content,
        onTab: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _finishImageDecode(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final image in tester.widgetList<Image>(_memoryImages)) {
      final completed = Completer<void>();
      final stream = image.image.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (info, _) {
          info.dispose();
          if (!completed.isCompleted) completed.complete();
        },
        onError: (Object error, StackTrace? stackTrace) {
          if (!completed.isCompleted) {
            completed.completeError(error, stackTrace);
          }
        },
      );
      stream.addListener(listener);
      try {
        await completed.future;
      } finally {
        stream.removeListener(listener);
      }
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  for (final top in [0.0, 62.0]) {
    testWidgets('tall category modal keeps top inset $top and selection', (
      tester,
    ) async {
      final categories = List.generate(
        20,
        (index) => CategoryItem(
          id: index + 1,
          name: '카테고리 ${index + 1}',
          color: Colors.blue,
          tint: Colors.blue.shade50,
          deep: Colors.blue.shade800,
        ),
      );
      final selected = <CategoryItem>[];
      await _pumpDetail(
        tester,
        top: top,
        categories: categories,
        onChangeCategory: (content, category) {
          expect(content, same(_content));
          selected.add(category);
        },
      );

      await tester.tap(_icon(Assets.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카테고리 변경'));
      await tester.pumpAndSettle();

      final sheet = find.byType(CategoryChangeSheet);
      expect(tester.getTopLeft(sheet).dy, top);
      expect(tester.getSize(sheet).height, 812 - top);
      expect(tester.getTopLeft(find.text('카테고리 변경')).dy, top + 18);
      expect(selected, isEmpty);

      await tester.ensureVisible(find.text('카테고리 20'));
      await tester.tap(find.text('카테고리 20'));
      await tester.pumpAndSettle();
      expect(selected, [categories.last]);
      expect(sheet, findsNothing);
      expect(find.byType(DetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('original image modal keeps one request across inset changes', (
    tester,
  ) async {
    final request = Completer<Uint8List>();
    final requestedAssets = <int>[];
    await _pumpDetail(
      tester,
      top: 20,
      onReadAsset: (id) {
        requestedAssets.add(id);
        return request.future;
      },
    );
    final detailState = tester.state(find.byType(DetailScreen));
    await tester.ensureVisible(find.text('원본 이미지 보기'));
    await tester.tap(find.text('원본 이미지 보기'));
    await tester.pump();
    expect(requestedAssets, [9]);

    await tester.ensureVisible(_icon(Assets.link));
    await tester.tap(_icon(Assets.link));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OriginalContentSheet), findsOneWidget);
    expect(requestedAssets, [9]);

    tester.view.physicalSize = const Size(375, 600);
    _setTopInset(tester, 62);
    await tester.pump();
    expect(tester.state(find.byType(DetailScreen)), same(detailState));
    expect(requestedAssets, [9]);

    request.complete(_portraitPng);
    await tester.pump();
    await _finishImageDecode(tester);
    final sheet = find.byType(OriginalContentSheet);
    expect(tester.getTopLeft(sheet).dy, 62);
    expect(tester.getSize(sheet).height, 600 - 62);
    expect(tester.getTopLeft(find.text('원본 이미지')).dy, 62 + 18);
    final sheetImage = find.descendant(of: sheet, matching: _memoryImages);
    expect(sheetImage, findsOneWidget);
    expect(
      (tester.widget<Image>(sheetImage).image as MemoryImage).bytes,
      same(_portraitPng),
    );

    await tester.ensureVisible(find.text('확인'));
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(tester.state(find.byType(DetailScreen)), same(detailState));

    tester.view.physicalSize = const Size(375, 812);
    _setTopInset(tester, 20);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('원본 이미지 보기'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(DetailScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.getTopLeft(find.byType(DetailTopBar)).dy, 20);
    expect(_memoryImages, findsOneWidget);
    expect(
      (tester.widget<Image>(_memoryImages).image as MemoryImage).bytes,
      same(_portraitPng),
    );
    expect(requestedAssets, [9]);
    expect(tester.takeException(), isNull);
  });
}
