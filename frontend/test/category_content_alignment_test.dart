import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/category_content_fixture.dart';
import 'support/archive_all_preview.dart' as base;

Future<GlobalKey<CategoryContentHostState>> pumpF01(
  WidgetTester tester,
  TargetPlatform platform,
  double width, {
  String name = categoryContentName,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final key = GlobalKey<CategoryContentHostState>();
  await tester.pumpWidget(
    CategoryContentHost(key: key, platform: platform, name: name),
  );
  await tester.pumpAndSettle();
  return key;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await loader.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets('F01 actual style/assets/start/random $platform $width', (
        tester,
      ) async {
        final key = await pumpF01(tester, platform, width);
        final m = f01Measure(key.currentContext! as Element), j = f01Judge(m);
        expect(j['styleFindings'], isEmpty);
        expect(j['layoutFindings'], isEmpty);
        expect(j['assetFindings'], isEmpty);
        expect(j['passed'], isTrue);
        final first = find.byWidgetPredicate(
          (w) => w is ContentListCard && w.content.id == 'api-601',
        );
        expect(tester.getSize(first).height, 173);
        final title = (m['rows'] as List).first['title'] as Map;
        expect(title['fontSize'], 16);
        expect(title['fontWeight'], 600);
        expect(title['height'], 1.4);
        expect(title['maxLines'], 1);
        expect(tester.takeException(), isNull);
      });
      testWidgets('F01 full memberships/scroll/last card $platform $width', (
        tester,
      ) async {
        final key = await pumpF01(tester, platform, width);
        final root = key.currentContext! as Element,
            p = base.archiveAllPosition(root);
        p.jumpTo(p.maxScrollExtent);
        await tester.pumpAndSettle();
        final m = f01Measure(root), rows = m['rows'] as List;
        expect(rows.last['id'], 'api-606');
        final last = rows.last['bounds'] as Map,
            button = m['randomVisual'] as Map;
        expect(last['bottom'], lessThanOrEqualTo(button['top']));
        expect(key.currentState!.feed.items[3].categories.length, 6);
        expect(tester.takeException(), isNull);
      });
      testWidgets(
        'F01 long header and real callback targets $platform $width',
        (tester) async {
          final key = await pumpF01(
            tester,
            platform,
            width,
            name: '길어진 카테고리 이름을 임의로 바꾸거나 글자를 축소하지 않아요',
          );
          final root = key.currentContext! as Element, m = f01Measure(root);
          final h = m['headerTitle'] as Map;
          expect(h['fontSize'], 18);
          expect(h['scaledFontSize'], 18);
          expect(h['maxLines'], 1);
          expect(h['overflow'], 'ellipsis');
          for (final pair in [
            ('back', 'back'),
            ('search', 'search'),
            ('settings', 'management'),
          ]) {
            await tester.tap(
              find.byKey(ValueKey('category-content-${pair.$1}-hit')),
            );
            await tester.pumpAndSettle();
            expect(key.currentState!.calls.last, pair.$2);
          }
          await tester.tap(find.text('랜덤 보기'));
          await tester.pumpAndSettle();
          expect(key.currentState!.calls.last, 'random');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
