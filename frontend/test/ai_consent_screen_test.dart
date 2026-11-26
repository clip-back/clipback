// #477: the AI 전송 동의 screen and '자세히 보기' (Figma 486:4934).
import 'dart:async';

import 'package:clipback_frontend/features/auth/ai_consent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _scroll = find.byKey(const ValueKey('ai-consent-scroll'));
final _detailScroll = find.byKey(const ValueKey('ai-consent-detail-scroll'));
final _footer = find.byKey(const ValueKey('ai-consent-footer'));
final _agree = find.byKey(const ValueKey('ai-consent-agree'));
final _deny = find.byKey(const ValueKey('ai-consent-deny'));
final _close = find.byKey(const ValueKey('ai-consent-close'));
final _detailLink = find.byKey(const ValueKey('ai-consent-detail-link'));
final _policyLink = find.byKey(const ValueKey('ai-consent-policy-link'));

class _Calls {
  int agree = 0, deny = 0, close = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  double width = 375,
  double scale = 1,
  bool saving = false,
  Future<bool?> Function()? openPolicy,
  Key? key,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  tester.view.padding = const FakeViewPadding(top: 50, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 50, bottom: 34);
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Pretendard'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: AiConsentScreen(
        key: key,
        saving: saving,
        onAgree: () => calls.agree++,
        onDeny: () => calls.deny++,
        onClose: () => calls.close++,
        openPolicy: openPolicy ?? () async => true,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

/// Every text in [scroll] wraps inside the 24 margins without clipping.
void _expectFits(WidgetTester tester, Finder scroll, double width) {
  final paragraphs = tester
      .renderObjectList<RenderParagraph>(
        find.descendant(of: scroll, matching: find.byType(RichText)),
      )
      .toList();
  expect(paragraphs, isNotEmpty);
  for (final paragraph in paragraphs) {
    final text = paragraph.text.toPlainText();
    expect(paragraph.didExceedMaxLines, isFalse, reason: text);
    expect(
      paragraph.size.height,
      closeTo(paragraph.getMinIntrinsicHeight(paragraph.size.width), .01),
      reason: text,
    );
    final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
    expect(rect.left, greaterThanOrEqualTo(24 - .01), reason: text);
    expect(rect.right, lessThanOrEqualTo(width - 24 + .01), reason: text);
  }
  expect(tester.takeException(), isNull);
}

Future<void> _scrollToEnd(WidgetTester tester, Finder scroll) async {
  final position = tester
      .state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)),
      )
      .position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.ensureVisible(_detailLink);
  await tester.tap(_detailLink);
  await tester.pumpAndSettle();
  expect(find.byType(AiConsentDetailScreen), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    final bold = FontLoader('PretendardDetail')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'));
    await bold.load();
  });

  // One test per screen, width and scale: Flutter reports an overflow once.
  for (final width in [320.0, 375.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('consent screen fits width $width scale $scale', (
        tester,
      ) async {
        await _pump(tester, width: width, scale: scale);
        _expectFits(tester, _scroll, width);
        await _scrollToEnd(tester, _scroll);
        _expectFits(tester, _scroll, width);
        final footer = tester.getRect(_footer);
        expect(
          tester.getRect(_policyLink).bottom,
          lessThanOrEqualTo(footer.top),
        );
        for (final button in [_agree, _deny]) {
          final label = find.descendant(
            of: button,
            matching: find.byType(Text),
          );
          final paragraph = tester.renderObject<RenderParagraph>(label);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            tester.getRect(label).height,
            lessThanOrEqualTo(tester.getRect(button).height),
          );
        }
      });

      testWidgets('detail screen fits width $width scale $scale', (
        tester,
      ) async {
        await _pump(tester, width: width, scale: scale);
        await _openDetail(tester);
        _expectFits(tester, _detailScroll, width);
        await _scrollToEnd(tester, _detailScroll);
        _expectFits(tester, _detailScroll, width);
        final last = find.textContaining('동의를 철회하면');
        expect(
          tester.getRect(last).bottom,
          lessThanOrEqualTo(tester.getRect(_detailScroll).bottom),
        );
      });
    }
  }

  testWidgets('only the body scrolls; buttons stay in the fixed area below', (
    tester,
  ) async {
    await _pump(tester, width: 320, scale: 1.3);
    final footer = tester.getRect(_footer);
    final scroll = tester.getRect(_scroll);
    expect(scroll.bottom, lessThanOrEqualTo(footer.top));
    expect(find.descendant(of: _scroll, matching: _agree), findsNothing);
    expect(find.descendant(of: _scroll, matching: _deny), findsNothing);
    final deny = tester.getRect(_deny), agree = tester.getRect(_agree);
    expect(deny.height, 48);
    expect(agree.height, 56);
    expect(agree.top - deny.bottom, 16);
    expect(deny.left, 16);
    expect(deny.width, 320 - 32);
    // 4 above the 34 home indicator area (Figma 486:5126).
    expect(agree.bottom, 812 - 34 - 4);
    expect(tester.getRect(_scroll).height, greaterThan(0));
    final before = tester.getRect(_agree);
    await tester.drag(_scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(_agree), before);
  });

  testWidgets('the links and ✕ have 44 touch areas', (tester) async {
    await _pump(tester);
    for (final link in [_detailLink, _policyLink]) {
      await tester.ensureVisible(link);
      expect(tester.getSize(link).height, greaterThanOrEqualTo(44));
    }
    expect(tester.getSize(_close), const Size(44, 44));
  });

  testWidgets('both screens carry the five items of 제2항', (tester) async {
    await _pump(tester);
    for (final text in [
      // 1호, 2·3호, 4호 and 5호 (description and the deny button).
      '보내는 정보',
      '저장한 링크(제목·설명·게시물 글·대표 이미지 포함), 함께 공유한 글, 선택한 사진, 내 카테고리 이름',
      '받는 업체와 국가',
      'OpenAI(미국) · Google Gemini(미국 등)',
      '이용 목적',
      '콘텐츠 분석 · 요약 · 카테고리 추천 · 태그',
      '보관 기간',
      'OpenAI 최대 30일 · Google Gemini 55일 (남용 방지 기록)',
      '저장한 콘텐츠를 분석하고 정리하기 위해 아래 정보를 국외의 AI 업체로 전송해요. '
          '동의하지 않아도 저장할 수 있지만 요약과 자동 분류는 제공되지 않아요. '
          '선택은 계정 관리에서 언제든 바꿀 수 있어요.',
      '동의하지 않음',
      '동의하고 계속',
      'AI 전송 동의',
      'AI 전송에 동의하시겠어요?',
      '자세히 보기',
      '개인정보처리방침 보기',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await _openDetail(tester);
    expect(find.text('AI 전송 안내'), findsOneWidget);
    for (final company in ['OpenAI', 'Google']) {
      expect(find.text(company), findsOneWidget);
    }
    for (final (label, count) in [
      ('받는 곳', 2), // 3호
      ('국가', 2), // 2호
      ('보내는 정보', 2), // 1호
      ('보내는 때와 방법', 2), // 2호
      ('쓰는 목적', 2), // 4호
      ('보관 기간', 2), // 4호
    ]) {
      expect(find.text(label), findsNWidgets(count), reason: label);
    }
    for (final text in [
      'OpenAI OpCo, LLC(1455 3rd Street, San Francisco, CA 94158, 미국), privacy@openai.com',
      'Google 데이터센터가 있는 국가(미국 등)',
      'AI 전송과 별개로',
      '동의하지 않거나 바꾸고 싶을 때', // 5호
      '"동의하지 않음"을 누르거나, 계정 관리의 AI 전송 동의에서 언제든 바꿀 수 있어요.',
      '동의하지 않아도 링크와 사진은 저장돼요. 요약, 사진 글자 읽기, 카테고리·태그 추천은 제공되지 않아요.',
      '동의를 철회하면 새로 저장하는 콘텐츠와 아직 보내지 않은 작업은 전송하지 않아요. '
          '이미 보낸 정보는 위 보관 기간을 따라요.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byType(FilledButton), findsNothing, reason: 'no buttons');
  });

  for (final how in ['close', 'back']) {
    testWidgets('detail $how returns to the same scroll, choosing nothing', (
      tester,
    ) async {
      final calls = await _pump(tester);
      final scrollable = find.descendant(
        of: _scroll,
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(scrollable).position.jumpTo(120);
      await tester.pumpAndSettle();
      await tester.tap(_detailLink);
      await tester.pumpAndSettle();
      expect(find.byType(AiConsentDetailScreen), findsOneWidget);
      if (how == 'close') {
        await tester.tap(
          find.descendant(
            of: find.byType(AiConsentDetailScreen),
            matching: _close,
          ),
        );
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byType(AiConsentDetailScreen), findsNothing);
      expect(find.byType(AiConsentScreen), findsOneWidget);
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 120);
      expect((calls.agree, calls.deny, calls.close), (0, 0, 0));
    });
  }

  testWidgets('title, buttons and the lock are in semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(
      tester.getSemantics(find.text('AI 전송에 동의하시겠어요?')),
      isSemantics(isHeader: true, label: 'AI 전송에 동의하시겠어요?'),
    );
    for (final label in ['동의하고 계속', '동의하지 않음', '닫기']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(
          label: label,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
        reason: label,
      );
    }
    await _pump(tester, saving: true);
    for (final label in ['동의하고 계속', '동의하지 않음', '닫기']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(
          label: label,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
        reason: '$label locked',
      );
    }
    semantics.dispose();
  });

  testWidgets('locked buttons and ✕ ignore taps', (tester) async {
    final calls = await _pump(tester, saving: true);
    await tester.tap(_agree, warnIfMissed: false);
    await tester.tap(_deny, warnIfMissed: false);
    await tester.tap(_close, warnIfMissed: false);
    expect((calls.agree, calls.deny, calls.close), (0, 0, 0));
  });

  testWidgets('a failed policy open shows its notice', (tester) async {
    await _pump(tester, openPolicy: () async => false);
    await tester.ensureVisible(_policyLink);
    await tester.tap(_policyLink);
    await tester.pumpAndSettle();
    expect(find.text(aiConsentPolicyFailureMessage), findsOneWidget);
  });

  testWidgets('a late policy failure is not shown over the detail screen', (
    tester,
  ) async {
    final open = Completer<bool?>();
    await _pump(tester, openPolicy: () => open.future);
    await tester.ensureVisible(_policyLink);
    await tester.tap(_policyLink);
    await tester.pump();
    await _openDetail(tester);
    open.complete(false);
    await tester.pumpAndSettle();
    expect(find.text(aiConsentPolicyFailureMessage), findsNothing);
  });

  testWidgets('detail does not open while saving', (tester) async {
    await _pump(tester, saving: true);
    await tester.ensureVisible(_detailLink);
    await tester.tap(_detailLink);
    await tester.pumpAndSettle();
    expect(find.byType(AiConsentDetailScreen), findsNothing);
  });

  testWidgets('a late policy failure after the account changed is dropped', (
    tester,
  ) async {
    final open = Completer<bool?>();
    await _pump(
      tester,
      openPolicy: () => open.future,
      key: const ValueKey('account-1'),
    );
    await tester.ensureVisible(_policyLink);
    await tester.tap(_policyLink);
    await tester.pump();
    await _pump(tester, key: const ValueKey('account-2'));
    open.complete(false);
    await tester.pumpAndSettle();
    expect(find.text(aiConsentPolicyFailureMessage), findsNothing);
  });
}
