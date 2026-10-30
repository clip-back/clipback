import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/models/app_info.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/my_preview.dart' as fixture;

class _Calls {
  int account = 0, categories = 0, links = 0, photos = 0;
  final tabs = <AppRoute>[];
}

Future<_Calls> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  double height = 812,
  AppUser user = fixture.myMember,
  AppInfo? appInfo = fixture.myAppInfo,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0;
  final bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
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
      home: MyScreen(
        user: user,
        appInfo: appInfo,
        onAddLink: ({required url, category}) async {
          calls.links++;
          throw StateError('Unrequested save');
        },
        onAddScreenshot: ({required bytes, required filename, category}) async {
          calls.photos++;
          throw StateError('Unrequested save');
        },
        onOpenAccount: () => calls.account++,
        onOpenCategoryManagement: () => calls.categories++,
        onTab: calls.tabs.add,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    );
Map<String, Object?> _measurement(WidgetTester tester) =>
    fixture.myMeasure(tester.element(find.byType(MyScreen)));

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
      testWidgets('${platform.name} $width approved J01 roles and geometry', (
        tester,
      ) async {
        await _pump(tester, platform: platform, width: width);
        final m = _measurement(tester), j = fixture.myJudgment(m);
        expect(j['stylePassed'], isTrue, reason: '${j['styleFailures']}');
        expect(j['layoutPassed'], isTrue, reason: '${j['layoutFailures']}');
        expect(j['assetPassed'], isTrue, reason: '${j['assetFailures']}');
        final b = m['bounds'] as Map;
        expect(
          (b['header'] as Map)['top'],
          platform == TargetPlatform.iOS ? 59 : 24,
        );
        expect((b['profile'] as Map)['width'], width - 32);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${platform.name} $width raw account and cumulative data', (
        tester,
      ) async {
        for (final provider in [
          '게스트 계정',
          '연동된 계정 없음',
          'kakao 계정 연동 중',
          'kakao, apple, google 계정 연동 중',
          '계정 정보 확인 중',
          '브랜드로 해석하지 않는 아주 길고 확인되지 않은 계정 문구',
        ]) {
          final user = AppUser(
            name: '아주 긴 사용자 이름도 원래 데이터를 유지하면서 한 줄로 보여 줍니다',
            providerLabel: provider,
            joinedAt: '-',
            savedContentCount: 1234567,
            revisitedContentCount: 9876543,
          );
          await _pump(
            tester,
            platform: platform,
            width: width,
            user: user,
            appInfo: const AppInfo(version: '9.8.7', buildNumber: '42'),
          );
          final m = _measurement(tester), styles = m['styles'] as Map;
          expect(styles['account']['text'], provider);
          expect(styles['account']['fontSize'], 12);
          expect(styles['account']['maxLines'], 1);
          expect(styles['account']['overflow'], 'ellipsis');
          expect(styles['name']['maxLines'], 1);
          expect(styles['name']['overflow'], 'ellipsis');
          expect(find.text('1234567'), findsOneWidget);
          expect(find.text('9876543'), findsOneWidget);
          expect(find.text('ver. 9.8.7'), findsOneWidget);
          final n = _paragraph(tester, user.name),
              a = _paragraph(tester, provider);
          expect(n.didExceedMaxLines, isTrue);
          expect(a.text.toPlainText(), provider);
          expect(tester.takeException(), isNull);
        }
        await _pump(
          tester,
          platform: platform,
          width: width,
          user: fixture.myGuest,
        );
        expect(find.text('0'), findsNWidgets(2));
        expect(find.text('게스트 계정'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'Existing account/category callbacks, five sheets, tabs and save',
    (tester) async {
      final calls = await _pump(tester);
      final settings = find.byKey(const ValueKey('my-header-settings'));
      await tester.tap(
        settings.evaluate().isNotEmpty
            ? settings
            : find.descendant(
                of: find.byType(MyPageTopBar),
                matching: find.byType(SvgIconButton),
              ),
      );
      await tester.tap(find.byType(MyProfileRow));
      expect(calls.account, 2);
      await tester.tap(find.text('카테고리 관리'));
      expect(calls.categories, 1);
      for (final entry in <String, Type>{
        '리마인드 설정': ReminderSheet,
        '앱 권한': PermissionSheet,
        '공지사항': NoticeSheet,
        '문의하기': ContactSheet,
        '앱 버전': AppVersionSheet,
      }.entries) {
        final target = find.text(entry.key);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
        Navigator.of(tester.element(find.byType(entry.value))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsNothing);
      }
      for (final label in ['홈', '아카이브', '즐겨찾기', '마이']) {
        await tester.tap(
          find.descendant(
            of: find.byType(ClipbackNavigationBar),
            matching: find.text(label),
          ),
        );
      }
      expect(calls.tabs, [
        AppRoute.home,
        AppRoute.archive,
        AppRoute.bookmark,
        AppRoute.my,
      ]);
      await tester.tap(find.byType(NavAddButton));
      await tester.pumpAndSettle();
      expect(find.byType(AddContentSheet), findsOneWidget);
      final close = find.descendant(
        of: find.byType(AddContentSheet),
        matching: find.byWidgetPredicate(
          (w) => w is SvgIconButton && w.asset == Assets.close,
        ),
      );
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(AddContentSheet), findsNothing);
      expect(calls.links + calls.photos, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Low viewport reaches final version row and 24px body padding', (
    tester,
  ) async {
    await _pump(tester, width: 320, height: 480);
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -800));
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        )
        .position;
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    final viewport = tester.getRect(list);
    final row = tester.getRect(
      find.byWidgetPredicate((w) => w is MyListTile && w.title == '앱 버전'),
    );
    expect(scroll.maxScrollExtent, greaterThan(0));
    expect(viewport.bottom - row.bottom, closeTo(24, .1));
    expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(row.top, greaterThanOrEqualTo(viewport.top));
    expect(tester.takeException(), isNull);
  });
}
