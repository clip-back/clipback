import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

// #413(시트 77): 아카이브 계열 헤더의 돋보기는 홈 돋보기와 같은 20×20 그림(Figma E02 `428:4694`)이고,
// 24×24 칸은 그대로다.
String _pathData(String svg) {
  final paths = RegExp(r'\sd="([^"]+)"').allMatches(svg).toList();
  expect(paths, hasLength(1));
  return paths.single[1]!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('archive search draws the same 20x20 glyph as home search', () async {
    final archive = await rootBundle.loadString(Assets.archiveSearch);
    final home = await rootBundle.loadString(Assets.search);
    expect(_pathData(archive), _pathData(home));
    expect(archive, contains('viewBox="0 0 24 24"'));
  });

  testWidgets('archive root header keeps the 24x24 search slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CategoryArchiveTopBar(onSearch: () {})),
      ),
    );
    final button = find.byKey(const ValueKey('archive-category-search'));
    final glyph = find.descendant(
      of: button,
      matching: find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName == Assets.archiveSearch,
      ),
    );
    expect(glyph, findsOneWidget);
    expect(tester.getSize(button), const Size(24, 24));
    expect(tester.getSize(glyph), const Size(24, 24));
    expect(tester.getCenter(glyph), tester.getCenter(button));
  });
}
