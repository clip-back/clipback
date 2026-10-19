import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'category_content_alignment_test.dart' show pumpF01;
import 'fixtures/category_content_fixture.dart';
import 'support/archive_all_preview.dart' as base;

Element svg(Element root, String asset) => f01Elements(root).firstWhere(
  (e) =>
      e.widget is SvgPicture &&
      (e.widget as SvgPicture).bytesLoader is SvgAssetLoader &&
      ((e.widget as SvgPicture).bytesLoader as SvgAssetLoader).assetName ==
          asset,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await loader.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        'F01 original SVG slots, icon alignment and touch $platform $width',
        (tester) async {
          final key = await pumpF01(tester, platform, width);
          final root = key.currentContext! as Element;
          final header = f01Key(root, 'category-content-header')!,
              bounds = f01Box(header);
          final back = f01Box(svg(header, Assets.detailBack)),
              folder = f01Box(svg(header, Assets.categoryContentFolder));
          final search = f01Box(svg(header, Assets.archiveSearch)),
              settings = f01Box(svg(header, Assets.archiveSettings));
          expect(back.size, const Size(24, 24));
          expect(back.left - bounds.left, 16);
          expect(folder.width, closeTo(23.5294, .001));
          expect(folder.height, 20);
          expect(folder.left - back.right, 8);
          expect(settings.size, const Size(24, 24));
          expect(bounds.right - settings.right, 16);
          expect(settings.left - search.right, 16);
          for (final rect in [back, folder, search, settings]) {
            expect(rect.center.dy - bounds.center.dy, closeTo(.5, .001));
          }
          for (final role in ['back', 'search', 'settings']) {
            final hit = f01Box(f01Key(root, 'category-content-$role-hit')!);
            expect(hit.width, greaterThanOrEqualTo(44));
            expect(hit.height, 48);
            await tester.tapAt(Offset(hit.center.dx, hit.bottom - 1));
            await tester.pumpAndSettle();
          }
          expect(key.currentState!.calls, ['back', 'search', 'management']);
          final random = f01Box(
            f01Key(root, 'category-content-random-visual')!,
          );
          final icon = f01Box(svg(root, Assets.categoryContentRandom));
          expect(icon.size, const Size(18, 18));
          expect(icon.left - random.left, 10);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'F01 ID owns folder color with duplicate names $platform $width',
        (tester) async {
          final key = await pumpF01(tester, platform, width);
          key.currentState!.feed.categoryId = 102;
          key.currentState!.categories[1] = key.currentState!.categories[1]
              .copyWith(name: categoryContentName);
          await tester.pumpWidget(
            CategoryContentHost(key: key, platform: platform),
          );
          await tester.pumpAndSettle();
          final w =
              svg(
                    key.currentContext! as Element,
                    Assets.categoryContentFolder,
                  ).widget
                  as SvgPicture;
          expect(
            w.colorFilter,
            ColorFilter.mode(
              key.currentState!.categories[1].color,
              BlendMode.srcIn,
            ),
          );
          expect(key.currentState!.feed.categoryId, 102);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'F01 cards use visual16 gap and render every real badge $platform $width',
        (tester) async {
          final key = await pumpF01(tester, platform, width),
              root = key.currentContext! as Element;
          final first = f01Find<ContentListCard>(root)!;
          final star = f01Box(svg(first, Assets.categoryCardStar)),
              more = f01Box(svg(first, Assets.archiveAllMore));
          expect(more.left - star.right, 16);
          expect(star.size, const Size(28, 28));
          expect(more.size, const Size(24, 24));
          final p = base.archiveAllPosition(root);
          p.jumpTo(550);
          await tester.pumpAndSettle();
          final card = f01Key(root, 'archive-all-card-api-604')!;
          for (final c in key.currentState!.feed.items[3].categories) {
            expect(f01Paragraph(card, c.name), isNotNull);
          }
          expect(f01Box(card).height, greaterThan(173));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
