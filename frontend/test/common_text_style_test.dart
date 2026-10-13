import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _longSectionTitle = '오랫동안 보관한 콘텐츠 중 다시 읽고 싶은 오늘의 추천';

Future<void> _render(
  WidgetTester tester, {
  required double width,
  required Widget child,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 700);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 700),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
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

  for (final width in [320.0, 375.0]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'long section title fits at width $width and text scale $textScale',
        (tester) async {
          addTearDown(tester.view.reset);
          var tapCount = 0;
          await _render(
            tester,
            width: width,
            textScale: textScale,
            child: SectionHeader(
              title: _longSectionTitle,
              onTap: () => tapCount++,
            ),
          );

          expect(tester.takeException(), isNull);
          final headerRect = tester.getRect(find.byType(SectionHeader));
          final titleRect = tester.getRect(find.text(_longSectionTitle));
          final iconRect = tester.getRect(find.byType(SvgIcon));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(_longSectionTitle),
          );

          expect(paragraph.didExceedMaxLines, isTrue);
          expect(paragraph.maxLines, 1);
          expect(paragraph.overflow, TextOverflow.ellipsis);
          expect(titleRect.right, lessThanOrEqualTo(iconRect.left));
          expect(titleRect.top, greaterThanOrEqualTo(headerRect.top));
          expect(titleRect.bottom, lessThanOrEqualTo(headerRect.bottom));
          expect(iconRect.right, lessThanOrEqualTo(headerRect.right));
          expect(iconRect.top, greaterThanOrEqualTo(headerRect.top));
          expect(iconRect.bottom, lessThanOrEqualTo(headerRect.bottom));
          expect(headerRect.height, greaterThanOrEqualTo(44));
          if (textScale == 2) {
            expect(headerRect.height, greaterThan(44));
          }

          await tester.tapAt(titleRect.center);
          await tester.pumpAndSettle();
          expect(tapCount, 1);
          await tester.tapAt(iconRect.center);
          await tester.pumpAndSettle();
          expect(tapCount, 2);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final height in [52.0, 56.0]) {
    for (final customColors in [false, true]) {
      testWidgets('primary button preserves height $height and '
          '${customColors ? 'custom' : 'default'} colors and taps', (
        tester,
      ) async {
        addTearDown(tester.view.reset);
        var tapCount = 0;
        const customBackground = Color(0xFF304FFE);
        const customForeground = Color(0xFFFDF5E6);
        const label = '콘텐츠 저장하기';
        await _render(
          tester,
          width: 320,
          child: PrimaryButton(
            label: label,
            onPressed: () => tapCount++,
            height: height,
            color: customColors ? customBackground : AppColors.text,
            foreground: customColors ? customForeground : AppColors.main,
          ),
        );

        expect(tester.takeException(), isNull);
        final buttonRect = tester.getRect(find.byType(PrimaryButton));
        final labelRect = tester.getRect(find.text(label));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(Material),
          ),
        );

        expect(buttonRect.size, Size(320, height));
        expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left));
        expect(labelRect.right, lessThanOrEqualTo(buttonRect.right));
        expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
        expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
        expect(
          paragraph.text.style?.color,
          customColors ? customForeground : AppColors.main,
        );
        expect(
          material.color,
          customColors ? customBackground : AppColors.text,
        );
        expect(material.shape, isA<RoundedRectangleBorder>());
        expect(
          (material.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(8),
        );

        await tester.tapAt(labelRect.center);
        await tester.pumpAndSettle();
        expect(tapCount, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
