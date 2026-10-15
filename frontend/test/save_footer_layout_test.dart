import 'dart:math' as math;

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://example.com/footer-preserved';
const _failure = '저장하지 못했어요. 입력을 유지하고 다시 저장해 주세요.';
const _lastMessage = '분류는 상세 화면에서 변경할 수 있어요.';
const _saved = ContentItem(
  id: 'footer-result',
  title: '화면 아래 안내까지 끝까지 스크롤하여 읽을 수 있는 저장 결과',
  summary: '하단 영역 검사용 고정 콘텐츠',
  category: catUncategorized,
  savedAt: '26.10.15',
  savedAtFull: '2026. 10. 15 오후 02:00',
  savedAtFullShort: '2026. 10. 15 02:00',
  tags: [],
  source: '고정 출처',
  originalUrl: _url,
  originalText: '',
);

Finder _bodyScroll() => find.descendant(
  of: find.byType(AddContentSheet),
  matching: find.byType(SingleChildScrollView),
);

Future<void> _open(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double width,
  required double scale,
  required double safeBottom,
  required double keyboard,
  required Future<ContentItem> Function(String url) save,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  tester.view.padding = FakeViewPadding(
    top: 59,
    bottom: keyboard == 0 ? safeBottom : 0,
  );
  tester.view.viewPadding = FakeViewPadding(top: 59, bottom: safeBottom);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showContentSaveScreen(
              context: context,
              onAddLink: ({required url, category}) => save(url),
              onAddScreenshot:
                  ({required bytes, required filename, category}) async =>
                      throw StateError('unexpected photo save'),
            ),
            child: const Text('open save'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open save'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), _url);
  await tester.pump(const Duration(milliseconds: 400));
}

Rect _button(
  WidgetTester tester, {
  required double width,
  required double safeBottom,
  required double keyboard,
}) {
  final rect = tester.getRect(find.byType(SaveFlowButton));
  expect(rect.left, closeTo(16, 0.01));
  expect(rect.right, closeTo(width - 16, 0.01));
  expect(rect.height, closeTo(56, 0.01));
  expect(
    rect.bottom,
    closeTo(812 - math.max(safeBottom, keyboard) - 32, 0.01),
    reason: 'The CTA must clear the OS safe area or keyboard exactly once.',
  );
  return rect;
}

void _bodyAbove(WidgetTester tester, Rect footerTop) {
  final viewport = tester.getRect(_bodyScroll());
  expect(viewport.height, greaterThan(0));
  expect(
    viewport.bottom,
    lessThanOrEqualTo(footerTop.top + 0.01),
    reason: 'The scroll viewport must not continue behind a footer element.',
  );
  expect(
    tester.widget<SingleChildScrollView>(_bodyScroll()).padding,
    isA<EdgeInsets>().having((value) => value.bottom, 'bottom padding', 24),
  );
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

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final safeBottom in [0.0, 24.0, 34.0, 48.0]) {
          for (final keyboard in [0.0, 300.0]) {
            testWidgets(
              'footer clears body $platform width $width scale $scale safe $safeBottom keyboard $keyboard',
              (tester) async {
                final submitted = <String>[];
                await _open(
                  tester,
                  platform: platform,
                  width: width,
                  scale: scale,
                  safeBottom: safeBottom,
                  keyboard: keyboard,
                  save: (url) async {
                    submitted.add(url);
                    if (submitted.length == 1) {
                      throw const ClipbackApiException(_failure);
                    }
                    return _saved;
                  },
                );
                final sheet = tester.state(find.byType(AddContentSheet));
                final controller = tester
                    .widget<TextField>(find.byType(TextField))
                    .controller!;
                final button = _button(
                  tester,
                  width: width,
                  safeBottom: safeBottom,
                  keyboard: keyboard,
                );
                _bodyAbove(tester, button);
                final label = tester.renderObject<RenderParagraph>(
                  find.text('허투루에 저장하기'),
                );
                expect((label.text as TextSpan).style!.fontSize, 16);
                expect(label.textScaler.scale(16), closeTo(16 * scale, 0.01));

                await tester.tapAt(button.center);
                await tester.pumpAndSettle();
                expect(submitted, [_url]);
                expect(tester.state(find.byType(AddContentSheet)), same(sheet));
                expect(
                  tester.widget<TextField>(find.byType(TextField)).controller,
                  same(controller),
                );
                expect(controller.text, _url);
                final toast = tester.getRect(find.byType(SaveErrorToast));
                expect(toast.left, closeTo(40, 0.01));
                expect(toast.right, closeTo(width - 40, 0.01));
                expect(toast.bottom + 16, closeTo(button.top, 0.01));
                _bodyAbove(tester, toast);
                expect(tester.takeException(), isNull);

                await tester.tapAt(Offset(button.center.dx, button.bottom - 1));
                await tester.pumpAndSettle();
                expect(submitted, [_url, _url]);
                expect(find.byType(SaveErrorToast), findsNothing);
                expect(find.byType(SavedContentConfirmation), findsOneWidget);
                expect(find.text(_url), findsOneWidget);
                expect(
                  tester.widget<Text>(find.text('링크 첨부')).style!.fontWeight,
                  FontWeight.w600,
                );
                await tester.tap(find.text('사진 첨부'));
                await tester.pumpAndSettle();
                expect(find.byType(SavedContentConfirmation), findsOneWidget);
                expect(find.text('저장할 링크'), findsOneWidget);
                final close = _button(
                  tester,
                  width: width,
                  safeBottom: safeBottom,
                  keyboard: keyboard,
                );
                _bodyAbove(tester, close);
                await tester.drag(_bodyScroll(), const Offset(0, -2000));
                await tester.pumpAndSettle();
                final viewport = tester.getRect(_bodyScroll());
                final last = tester.getRect(find.text(_lastMessage));
                expect(last.top, greaterThanOrEqualTo(viewport.top - 0.01));
                expect(last.bottom, lessThanOrEqualTo(viewport.bottom + 0.01));
                expect(last.bottom, lessThanOrEqualTo(close.top - 24 + 0.01));
                expect(find.text(_lastMessage).hitTestable(), findsOneWidget);
                await tester.tapAt(Offset(close.center.dx, close.bottom - 1));
                await tester.pumpAndSettle();
                expect(find.byType(AddContentSheet), findsNothing);
                expect(submitted, [_url, _url]);
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  }
}
