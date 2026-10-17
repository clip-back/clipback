import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/account_preview.dart' as fixture;

class _Calls {
  int back = 0, logout = 0, connect = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  AppUser user = fixture.accountMember,
  bool? isGuest = false,
  bool busy = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: ThemeData(
        useMaterial3: true,
        platform: platform,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.main),
      ),
      home: AccountManagementScreen(
        user: user,
        isGuest: isGuest,
        busy: busy,
        onBack: () => calls.back++,
        onLogout: () async {
          calls.logout++;
        },
        onConnect: () async {
          calls.connect++;
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

Map<String, Object?> _measurement(WidgetTester tester) => fixture
    .accountMeasure(tester.element(find.byType(AccountManagementScreen)));
RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    );
Finder _row(String text) => find.byWidgetPredicate(
  (w) => w is AccountManagementTile && w.leading == text,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width J02 approved roles and original geometry',
        (tester) async {
          for (final guest in [false, true]) {
            await _pump(
              tester,
              platform: platform,
              width: width,
              user: guest ? fixture.accountGuest : fixture.accountMember,
              isGuest: guest,
            );
            final m = _measurement(tester), j = fixture.accountJudgment(m);
            expect(j['stylePassed'], isTrue, reason: '${j['styleFailures']}');
            expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
            expect(j['assetPassed'], isTrue, reason: '${j['assetFailures']}');
            final rows = m['rows'] as List;
            for (final row in rows) {
              expect(row['bounds']['height'], closeTo(41, .18));
            }
            expect(tester.takeException(), isNull);
          }
        },
      );
      testWidgets(
        '${platform.name} $width long raw name and account wrap without shrinking',
        (tester) async {
          const longName = '이름이 아주 긴 사용자도 원래 데이터를 모두 보존하고 가운데 정렬로 필요한 높이를 늘립니다';
          for (final provider in [
            '게스트 계정',
            '연동된 계정 없음',
            'kakao 계정 연동 중',
            'kakao, apple, google 계정 연동 중',
            '계정 정보 확인 중',
            '브랜드로 해석하지 않는 아주 길고 확인되지 않은 계정 문구를 줄이지 않고 줄바꿈하며 전체 내용을 유지합니다',
          ]) {
            final user = AppUser(
              name: longName,
              providerLabel: provider,
              joinedAt: '-',
              savedContentCount: 1234567,
              revisitedContentCount: 9876543,
              appVersion: 'ver. 9.8.7-local',
            );
            await _pump(tester, platform: platform, width: width, user: user);
            final m = _measurement(tester),
                name = _paragraph(tester, longName),
                account = _paragraph(tester, provider);
            expect(name.maxLines, isNull);
            expect(account.maxLines, isNull);
            expect(name.overflow, isNot(TextOverflow.ellipsis));
            expect(account.overflow, isNot(TextOverflow.ellipsis));
            expect(name.didExceedMaxLines, isFalse);
            expect(account.didExceedMaxLines, isFalse);
            expect((name.text as TextSpan).style!.fontSize, 20);
            expect((account.text as TextSpan).style!.fontSize, 14);
            expect(name.textScaler.scale(20), 20);
            expect(name.size.height, greaterThan(24));
            expect(account.text.toPlainText(), provider);
            expect((m['user'] as Map)['savedCount'], 1234567);
            expect((m['user'] as Map)['reopenedCount'], 9876543);
            expect((m['user'] as Map)['appVersion'], user.appVersion);
            final j = fixture.accountJudgment(m);
            expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
            expect(j['stylePassed'], isTrue, reason: '${j['styleFailures']}');
            expect(tester.takeException(), isNull);
          }
        },
      );
      testWidgets(
        '${platform.name} $width guest and busy compatibility matrix',
        (tester) async {
          for (final guest in <bool?>[true, false, null]) {
            for (final busy in [false, true]) {
              final calls = await _pump(
                tester,
                platform: platform,
                width: width,
                isGuest: guest,
                busy: busy,
              );
              final back = find.byKey(const ValueKey('account-back-hit'));
              await tester.tap(
                back.evaluate().isNotEmpty
                    ? back
                    : find.byWidgetPredicate(
                        (w) => w is SvgIconButton && w.asset == Assets.back,
                      ),
              );
              expect(calls.back, 1);
              await tester.tap(_row(fixture.accountMember.providerLabel));
              expect(calls.connect + calls.logout, 0);
              expect(
                find.text('연결됨'),
                guest == false ? findsOneWidget : findsNothing,
              );
              if (guest != false) {
                final text = guest == true ? '계정 연결하기' : '계정 정보 다시 확인';
                await tester.ensureVisible(_row(text));
                await tester.tap(_row(text));
                expect(calls.connect, busy ? 0 : 1);
              }
              await tester.ensureVisible(_row('로그아웃'));
              await tester.tap(_row('로그아웃'));
              expect(calls.logout, busy ? 0 : 1);
              await tester.ensureVisible(_row('회원 탈퇴'));
              await tester.tap(_row('회원 탈퇴'));
              await tester.pumpAndSettle();
              expect(find.text('회원 탈퇴 API는 아직 제공되지 않습니다.'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
          }
        },
      );
    }
    testWidgets(
      '${platform.name} low viewport reaches final row and body/OS padding once',
      (tester) async {
        await _pump(
          tester,
          platform: platform,
          width: 320,
          height: 480,
          isGuest: true,
          user: fixture.accountGuest,
        );
        final scroll = find.byType(SingleChildScrollView);
        expect(scroll, findsOneWidget);
        final p = tester
            .state<ScrollableState>(
              find
                  .descendant(of: scroll, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        p.jumpTo(p.maxScrollExtent);
        await tester.pumpAndSettle();
        final m = _measurement(tester),
            b = m['bounds'] as Map,
            rows = m['rows'] as List;
        expect(p.maxScrollExtent, greaterThan(0));
        expect(
          (b['viewport']['bottom'] as num) -
              (rows.last['bounds']['bottom'] as num),
          closeTo(24, .18),
        );
        expect(
          (b['screen']['bottom'] as num) - (b['viewport']['bottom'] as num),
          platform == TargetPlatform.iOS ? 34 : 0,
        );
        final j = fixture.accountJudgment(m);
        expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
