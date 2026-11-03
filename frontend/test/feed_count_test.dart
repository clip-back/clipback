import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/archive/bookmark_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    await (FontLoader(
      'PretendardDetail',
    )..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'))).load();
  });
  for (final scale in [1.0, 1.15, 1.3]) {
    for (final count in <int?>[9999, null]) {
      for (final kind in [
        'detail',
        'all',
        'category',
        'all-latest',
        'category-latest',
        'bookmark',
      ]) {
        testWidgets('$kind count=$count scale=$scale Pretendard fits', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final sortLabel = kind.endsWith('latest') ? '최신순' : '즐겨찾기 우선';
          final label = kind == 'detail'
              ? '20 / ${count ?? '-'}'
              : '총 ${count ?? '-'}개';
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'Pretendard'),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(375, 812),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: kind == 'detail'
                      ? DetailPager(
                          currentIndex: 19,
                          totalCount: count,
                          onPrevious: () {},
                          onNext: () {},
                        )
                      : kind == 'bookmark'
                      ? BookmarkToolbar(totalCount: count)
                      : ArchiveToolbar(
                          countLabel: label,
                          sortLabel: sortLabel,
                          archiveAllStyle: kind.startsWith('all'),
                        ),
                ),
              ),
            ),
          );
          expect(find.text(label), findsOneWidget);
          expect(tester.takeException(), isNull);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse);

          if (kind.startsWith('all') || kind.startsWith('category')) {
            expect(
              tester.getRect(find.text(sortLabel)).right,
              lessThan(tester.getRect(find.text(label)).left),
            );
          }
        });
      }
    }
  }

  for (final value in [0, 25, null, '25', -1, 2.5, true, [], {}]) {
    test('feed total_count parses $value (${value.runtimeType})', () {
      final feed = ApiFeed.fromJson({'items': [], 'total_count': value});
      expect(feed.totalCount, value is int && value >= 0 ? value : null);
    });
  }
  test('old server omits total_count', () {
    expect(ApiFeed.fromJson({'items': []}).totalCount, isNull);
  });
}
