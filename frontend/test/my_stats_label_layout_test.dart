import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/my_preview.dart' as fixture;

const _label = '최근 다시 본 콘텐츠';

Future<void> _strip(WidgetTester tester, double scale) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 640);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: MyStatsStrip(user: fixture.myMember),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectLabelFits(WidgetTester tester, double scale, int lines) {
  final label = find.text(_label);
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: label, matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse);
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(scale),
  )..layout(maxWidth: paragraph.size.width);
  expect(painter.computeLineMetrics(), hasLength(lines));
  expect(paragraph.size.height, greaterThanOrEqualTo(painter.height - .1));
  final strip = tester.getRect(find.byType(MyStatsStrip));
  final rect = tester.getRect(label);
  expect(
    strip.contains(rect.topLeft) && strip.contains(rect.bottomRight),
    true,
  );
  expect(
    tester.getRect(find.text('150')).top,
    tester.getRect(find.text('12')).top,
  );
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  testWidgets('360px Pretendard recent reopened label is one line at 1.0', (
    tester,
  ) async {
    await _strip(tester, 1.0);
    _expectLabelFits(tester, 1.0, 1);
  });

  testWidgets(
    '360px Pretendard recent reopened label wraps without clipping at 1.3',
    (tester) async {
      await _strip(tester, 1.3);
      _expectLabelFits(tester, 1.3, 2);
    },
  );
}
