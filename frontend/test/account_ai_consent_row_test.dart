// #479: the AI 전송 동의 row of 계정 관리 (Figma 487:5410, 487:5416·5450·5484).
// No 1.3x frame exists: the 1.0 shape grows and must not overflow.
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/account_preview.dart' as fixture;

final _row = find.byKey(const ValueKey('account-ai-consent'));

var _opened = 0;

Future<void> _pump(
  WidgetTester tester, {
  required AiConsentStatus status,
  double width = 375,
  double scale = 1,
  bool busy = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  _opened = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
      ),
      home: AccountManagementScreen(
        user: fixture.accountMember,
        isGuest: false,
        busy: busy,
        aiConsentStatus: status,
        onOpenAiConsent: () => _opened++,
        onBack: () {},
        onLogout: () async {},
        onConnect: () async {},
        onWithdraw: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.descendant(of: _row, matching: find.text(text)),
        matching: find.byType(RichText),
      ),
    );

const _labels = {
  AiConsentStatus.granted: '동의함',
  AiConsentStatus.denied: '동의 안 함',
  AiConsentStatus.undecided: '선택 전',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });

  // One test per input and scale: Flutter reports an overflow only once.
  for (final MapEntry(key: status, value: text) in _labels.entries) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${status.name} "$text" width $width scale $scale fits', (
          tester,
        ) async {
          await _pump(tester, status: status, width: width, scale: scale);
          expect(tester.takeException(), isNull);
          final row = tester.getRect(_row);
          final label = _paragraph(tester, 'AI 전송 동의');
          final value = _paragraph(tester, text);
          for (final p in [label, value]) {
            expect(p.didExceedMaxLines, isFalse);
            expect(p.maxLines, isNull);
            expect(p.textScaler.scale(15), closeTo(15 * scale, .01));
          }
          final labelBox = tester.getRect(find.text('AI 전송 동의'));
          final valueBox = tester.getRect(find.text(text));
          final chevron = tester.getRect(
            find.descendant(of: _row, matching: find.byType(SvgPicture)),
          );
          expect(row.left, 16);
          expect(row.width, width - 32);
          expect(row.height, scale == 1 ? closeTo(52, .01) : greaterThan(52));
          for (final box in [labelBox, valueBox, chevron]) {
            expect(box.top, greaterThanOrEqualTo(row.top));
            expect(box.bottom, lessThanOrEqualTo(row.bottom));
          }
          expect(labelBox.left, row.left + 16);
          expect(labelBox.right, lessThanOrEqualTo(valueBox.left));
          expect(chevron.left - valueBox.right, closeTo(8, .01));
          expect(row.right - chevron.right, closeTo(16, .01));
          expect(chevron.size, const Size(20, 20));
          // Logout and withdrawal keep their approved geometry (J02 oracle).
          final m = fixture.accountMeasure(
            tester.element(find.byType(AccountManagementScreen)),
          );
          final j = fixture.accountJudgment(m);
          if (scale == 1) {
            expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
            expect(j['stylePassed'], isTrue, reason: '${j['styleFailures']}');
            expect(j['assetPassed'], isTrue, reason: '${j['assetFailures']}');
          }
        });
      }
    }
  }

  testWidgets('roles follow Figma 487:5410', (tester) async {
    await _pump(tester, status: AiConsentStatus.granted);
    final label = (_paragraph(tester, 'AI 전송 동의').text as TextSpan).style!;
    final value = (_paragraph(tester, '동의함').text as TextSpan).style!;
    expect(label.fontFamily, 'Pretendard');
    expect(label.fontSize, 15);
    expect(label.fontWeight, FontWeight.w500);
    expect(label.height, 1.5);
    expect(label.color, AppColors.text);
    expect(value.fontFamily, 'Pretendard');
    expect(value.fontSize, 15);
    expect(value.fontWeight, FontWeight.w400);
    expect(value.height, 1.5);
    expect(value.color, AppColors.middle);
    final svg = tester.widget<SvgPicture>(
      find.descendant(of: _row, matching: find.byType(SvgPicture)),
    );
    expect(
      (svg.bytesLoader as SvgAssetLoader).assetName,
      'assets/icons/account-ai-consent-chevron.svg',
    );
    // Under 계정, its own rounded card meeting the 로그아웃·회원 탈퇴 card with
    // no gap (488:5457 above 487:5439): the background shows at the corners.
    final group = find.byKey(const ValueKey('account-actions-group'));
    expect(find.descendant(of: group, matching: _row), findsOneWidget);
    Material card(Finder child) => tester.widget<Material>(
      find.ancestor(of: child, matching: find.byType(Material)).first,
    );
    final logout = find.byKey(const ValueKey('account-row-로그아웃'));
    final mine = card(_row), theirs = card(logout);
    expect(identical(mine, theirs), isFalse);
    for (final m in [mine, theirs]) {
      expect(m.color, AppColors.surface);
      expect(m.borderRadius, BorderRadius.circular(8));
    }
    expect(
      tester.getRect(_row).bottom,
      tester.getRect(find.byWidget(theirs)).top,
    );
    expect(
      tester.getRect(find.byWidget(mine)).top,
      tester
          .getRect(find.byKey(const ValueKey('account-section-actions')))
          .bottom,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('account-row-회원 탈퇴'))).top,
      greaterThan(tester.getRect(logout).bottom),
    );
  });

  testWidgets('a tap opens the consent screen', (tester) async {
    await _pump(tester, status: AiConsentStatus.denied);
    await tester.tap(_row);
    await tester.pump();
    expect(_opened, 1);
  });

  testWidgets('busy disables the row', (tester) async {
    await _pump(tester, status: AiConsentStatus.granted, busy: true);
    await tester.tap(_row);
    await tester.pump();
    expect(_opened, 0);
  });

  testWidgets('an unknown status shows no row', (tester) async {
    await _pump(tester, status: AiConsentStatus.unknown);
    expect(_row, findsNothing);
    expect(find.text('AI 전송 동의'), findsNothing);
  });
}
