// #412: the A02 terms line under the login buttons. "서비스 이용약관" and
// "개인정보처리방침" open their web pages in the browser like the My
// privacy row (#349), and the line ends 11 above the safe bottom.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'fixtures/original_link_launcher.dart';
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as login;

const _termsWord = '서비스 이용약관';
const _privacyWord = '개인정보처리방침';
const _termsUrl = 'https://huturu-app.github.io/terms';
const _privacyUrl = 'https://huturu-app.github.io/privacy';
const _termsError = '서비스 이용약관을 열지 못했어요. 다시 시도해 주세요.';
const _privacyError = '개인정보처리방침을 열지 못했어요. 다시 시도해 주세요.';
const _line =
    '계속하면 허투루의 서비스 이용약관에 동의하며,\n'
    '개인정보처리방침을 확인한 것으로 간주합니다.';

Finder get _terms => find.byKey(const ValueKey('login-terms'));

RecordingUrlLauncher _launcher() {
  final old = UrlLauncherPlatform.instance, launcher = RecordingUrlLauncher();
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = old);
  return launcher;
}

void _view(
  WidgetTester t, {
  double width = 375,
  double height = 812,
  double top = 59,
  double bottom = 34,
  double scale = 1,
}) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, height);
  t.view.padding = FakeViewPadding(top: top, bottom: bottom);
  t.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

/// The root app on the ordinary login screen (logged out, iOS providers).
Future<void> _withLogin(WidgetTester t, Future<void> Function() check) {
  final server = login.LoginServer();
  return http.runWithClient(() async {
    try {
      await t.pumpWidget(
        ClipbackApp(
          sessionStorage: login.LoginMemoryStorage(),
          socialAuth: login.LoginControlledSocial(TargetPlatform.iOS),
        ),
      );
      await completeAppStartup(t);
      expect(find.byType(LoginScreen), findsOneWidget);
      await _toBottom(t);
      await check();
      expect(t.takeException(), isNull);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  }, () => server.client);
}

Future<void> _toBottom(WidgetTester t) async {
  final position = login.loginPosition(t.element(find.byType(LoginScreen)))!;
  position.jumpTo(position.maxScrollExtent);
  await t.pump();
}

/// The glyph box of [word] inside the terms line, in global coordinates.
Rect _word(WidgetTester t, String word) {
  final paragraph = t.renderObject<RenderParagraph>(_terms);
  final text = paragraph.text.toPlainText();
  final start = text.indexOf(word);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + word.length),
    boxHeightStyle: ui.BoxHeightStyle.max,
  );
  expect(boxes, hasLength(1));
  final origin = paragraph.localToGlobal(Offset.zero);
  return boxes.single.toRect().shift(origin);
}

Future<void> _tapWord(WidgetTester t, String word) =>
    t.tapAt(_word(t, word).center);

void _expectOpens(RecordingUrlLauncher launcher, List<String> urls) {
  expect(launcher.calls.map((c) => c.url).toList(), urls);
  for (final call in launcher.calls) {
    expect(call.options.mode, PreferredLaunchMode.externalApplication);
  }
}

Future<void> _dismissNotice(WidgetTester t) async {
  await t.drag(find.byType(SnackBar), const Offset(0, 300));
  await t.pumpAndSettle();
  expect(find.byType(SnackBar), findsNothing);
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });

  testWidgets('terms line shows the Figma text and link styles', (t) async {
    _view(t);
    await _withLogin(t, () async {
      final paragraph = t.renderObject<RenderParagraph>(_terms);
      expect(paragraph.text.toPlainText(), _line);
      expect(paragraph.textAlign, TextAlign.center);
      // Text.rich puts the line's span under the default text style span.
      final line = (paragraph.text as TextSpan).children!.single as TextSpan;
      final base = line.style!;
      expect(base.inherit, isFalse);
      expect(base.fontFamily, 'Pretendard');
      expect(base.fontSize, 13);
      expect(base.height, 1.6);
      expect(base.letterSpacing, -0.325);
      expect(base.fontWeight, FontWeight.w400);
      expect(base.color, const Color(0xFF767676));
      final links = <String, TextStyle?>{};
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) {
          links[span.text!] = span.style;
        }
        return true;
      });
      expect(links.keys, [_termsWord, _privacyWord]);
      for (final style in links.values) {
        expect(style!.fontWeight, FontWeight.w600);
        expect(style.color, const Color(0xFF484848));
        expect(style.decoration, anyOf(isNull, TextDecoration.none));
      }
    });
  });

  testWidgets('each word opens its page once in the browser', (t) async {
    _view(t);
    final launcher = _launcher();
    await _withLogin(t, () async {
      launcher.pending = Completer<bool>();
      await _tapWord(t, _termsWord);
      await t.pump();
      await _tapWord(t, _termsWord);
      await t.pump();
      _expectOpens(launcher, [_termsUrl]);
      launcher.pending!.complete(true);
      await t.pumpAndSettle();
      launcher.pending = Completer<bool>();
      await _tapWord(t, _privacyWord);
      await t.pump();
      await _tapWord(t, _privacyWord);
      await t.pump();
      _expectOpens(launcher, [_termsUrl, _privacyUrl]);
      launcher.pending!.complete(true);
      await t.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      _expectOpens(launcher, [_termsUrl, _privacyUrl]);
    });
  });

  for (final refusal in ['os-false', 'exception']) {
    for (final (word, url, error) in [
      (_termsWord, _termsUrl, _termsError),
      (_privacyWord, _privacyUrl, _privacyError),
    ]) {
      testWidgets('$word $refusal shows its notice and retries on tap', (
        t,
      ) async {
        _view(t);
        final launcher = _launcher();
        await _withLogin(t, () async {
          if (refusal == 'os-false') {
            launcher.accepted = false;
          } else {
            launcher.failure = PlatformException(code: 'launch_failed');
          }
          await _tapWord(t, word);
          await t.pumpAndSettle();
          expect(find.text(error), findsOneWidget);
          expect(find.byType(SnackBar), findsOneWidget);
          expect(find.byType(LoginScreen), findsOneWidget);
          await _dismissNotice(t);
          launcher
            ..accepted = true
            ..failure = null;
          await _tapWord(t, word);
          await t.pumpAndSettle();
          _expectOpens(launcher, [url, url]);
          expect(find.byType(SnackBar), findsNothing);
        });
      });
    }
  }

  for (final scale in [1.0, 1.3]) {
    for (final (word, error) in [
      (_termsWord, _termsError),
      (_privacyWord, _privacyError),
    ]) {
      testWidgets('$word failure notice ${scale}x width 320 is not clipped', (
        t,
      ) async {
        _view(t, width: 320, height: 568, top: 20, bottom: 0, scale: scale);
        final launcher = _launcher()..accepted = false;
        await _withLogin(t, () async {
          await _tapWord(t, word);
          await t.pumpAndSettle();
          final text = find.text(error);
          expect(text, findsOneWidget);
          final paragraph = t.renderObject<RenderParagraph>(text);
          expect(paragraph.textScaler.scale(10), closeTo(10 * scale, .01));
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.size.height,
            closeTo(paragraph.getMinIntrinsicHeight(paragraph.size.width), .1),
          );
          final textRect = t.getRect(text);
          final barRect = t.getRect(find.byType(SnackBar));
          expect(textRect.left, greaterThanOrEqualTo(barRect.left));
          expect(textRect.right, lessThanOrEqualTo(barRect.right));
          expect(textRect.top, greaterThanOrEqualTo(barRect.top));
          expect(textRect.bottom, lessThanOrEqualTo(barRect.bottom));
          expect(barRect.left, greaterThanOrEqualTo(0));
          expect(barRect.right, lessThanOrEqualTo(320));
          expect(launcher.calls, hasLength(1));
        });
      });
    }
  }

  for (final (width, height) in [
    (375.0, 812.0),
    (320.0, 568.0),
    (375.0, 667.0),
  ]) {
    for (final (top, bottom) in [(59.0, 34.0), (20.0, 0.0)]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '${width}x$height safe $top/$bottom ${scale}x terms ends 11 above '
          'the safe bottom and the guest label 30 above the terms',
          (t) async {
            _view(
              t,
              width: width,
              height: height,
              top: top,
              bottom: bottom,
              scale: scale,
            );
            await _withLogin(t, () async {
              final safeBottom = height - bottom;
              final terms = t.getRect(_terms);
              final guest = t.getRect(find.text('게스트로 시작하기'));
              expect(terms.bottom, closeTo(safeBottom - 11, .5));
              expect(guest.bottom, closeTo(terms.top - 30, .5));
              if (scale == 1.0) {
                expect(guest.bottom, closeTo(safeBottom - 83, .5));
              }
            });
          },
        );
      }
    }
  }

  for (final width in [320.0, 360.0, 375.0]) {
    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets('width $width ${scale}x terms line does not overflow', (
        t,
      ) async {
        _view(t, width: width, scale: scale);
        await _withLogin(t, () async {
          final paragraph = t.renderObject<RenderParagraph>(_terms);
          expect(paragraph.textScaler.scale(10), closeTo(10 * scale, .01));
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.size.width, lessThanOrEqualTo(width - 32 + .01));
          expect(
            paragraph.size.height,
            closeTo(paragraph.getMinIntrinsicHeight(paragraph.size.width), .1),
          );
          // Issue #412 position table: the forced break gives two lines,
          // except 320 at 1.3 where each line wraps again.
          final lines = (paragraph.size.height / (13 * 1.6 * scale)).round();
          expect(lines, width == 320 && scale == 1.3 ? 4 : 2);
        });
      });
    }
  }

  testWidgets('screen reader reads the two words as links that open', (
    t,
  ) async {
    _view(t);
    final launcher = _launcher();
    final handle = t.ensureSemantics();
    await _withLogin(t, () async {
      FinderBase<SemanticsNode> node(String label) =>
          find.semantics.byLabel(label);
      for (final word in [_termsWord, _privacyWord]) {
        final data = node(word).evaluate().single.getSemanticsData();
        expect(data.flagsCollection.isLink, isTrue, reason: word);
        expect(data.hasAction(SemanticsAction.tap), isTrue, reason: word);
      }
      for (final rest in ['계속하면 허투루의 ', '에 동의하며,\n', '을 확인한 것으로 간주합니다.']) {
        final data = node(rest).evaluate().single.getSemanticsData();
        expect(data.flagsCollection.isLink, isFalse, reason: rest);
        expect(data.hasAction(SemanticsAction.tap), isFalse, reason: rest);
      }
      t.semantics.tap(node(_termsWord));
      await t.pumpAndSettle();
      t.semantics.tap(node(_privacyWord));
      await t.pumpAndSettle();
      _expectOpens(launcher, [_termsUrl, _privacyUrl]);
    });
    handle.dispose();
  });

  testWidgets('busy login locks providers and guest but the words open', (
    t,
  ) async {
    _view(t);
    final launcher = _launcher();
    final calls = <SocialLoginProvider>[];
    var guests = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: login.loginTheme(platform: TargetPlatform.iOS),
        home: LoginScreen(
          onContinue: () async => guests++,
          onSocialLogin: (p) async => calls.add(p),
          providers: login.loginPlatformProviders(TargetPlatform.iOS),
          busy: true,
        ),
      ),
    );
    await t.pump();
    final position = login.loginPosition(t.element(find.byType(LoginScreen)))!;
    for (final p in login.loginPlatformProviders(TargetPlatform.iOS)) {
      final finder = find.text(login.loginLabel(p));
      await t.ensureVisible(finder);
      await t.pump();
      await t.tap(finder, warnIfMissed: false);
      await t.pump();
    }
    position.jumpTo(position.maxScrollExtent);
    await t.pump();
    await t.tap(find.text('게스트로 시작하기'), warnIfMissed: false);
    await t.pump();
    await _tapWord(t, _termsWord);
    await t.pump();
    await _tapWord(t, _privacyWord);
    await t.pump();
    expect(calls, isEmpty);
    expect(guests, 0);
    _expectOpens(launcher, [_termsUrl, _privacyUrl]);
    expect(t.takeException(), isNull);
  });

  testWidgets('guest account linking login screen has no terms line', (
    t,
  ) async {
    _view(t);
    await t.pumpWidget(
      MaterialApp(
        theme: login.loginTheme(platform: TargetPlatform.iOS),
        home: LoginScreen(
          onContinue: () async {},
          onSocialLogin: (_) async {},
          providers: login.loginPlatformProviders(TargetPlatform.iOS),
          linkingGuest: true,
          onBack: () {},
        ),
      ),
    );
    await t.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(_terms, findsNothing);
    for (final word in [_termsWord, _privacyWord]) {
      expect(find.textContaining(word, findRichText: true), findsNothing);
    }
  });
}
