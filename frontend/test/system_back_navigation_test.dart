import 'dart:convert';
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/logout_confirmation_screen.dart';
import 'package:clipback_frontend/features/categories/category_management_screen.dart';
import 'package:clipback_frontend/features/home/notification_list_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/archive_all_preview.dart' as base;
import 'support/app_startup.dart';
import 'support/system_back_preview.dart' show BackMemoryHistory;

String screen() {
  for (final type in [
    DetailScreen,
    SearchScreen,
    AccountManagementScreen,
    CategoryCardReviewScreen,
    CategoryManagementScreen,
    NotificationListScreen,
    LogoutConfirmationScreen,
    ArchiveScreen,
    BookmarkScreen,
    MyScreen,
    HomeScreen,
  ]) {
    if (find
        .byWidgetPredicate((w) => w.runtimeType == type)
        .evaluate()
        .isNotEmpty) {
      return type.toString();
    }
  }
  return 'other';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scene in [
    'home',
    'archive',
    'bookmark',
    'my',
    'search',
    'detail',
    'account',
    'category-list',
    'card-review',
    'category-management',
    'notifications',
    'logout-confirmation',
  ]) {
    testWidgets('system Back handles $scene without implicit OS exit', (
      t,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var pops = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemNavigator.pop') pops++;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final server = base.ArchiveAllServer();
      await http.runWithClient(() async {
        try {
          await t.pumpWidget(
            ClipbackApp(
              sessionStorage: base.ArchiveAllMemoryStorage(),
              socialAuth: base.ArchiveAllSocialAuth(),
              searchHistoryStorage: BackMemoryHistory(),
            ),
          );
          await completeAppStartup(t);
          HomeScreen home() => t.widget<HomeScreen>(find.byType(HomeScreen));
          if (scene == 'archive' ||
              scene == 'category-list' ||
              scene == 'card-review') {
            home().onTab(AppRoute.archive);
            await t.pumpAndSettle();
            if (scene != 'archive') {
              final a = t.widget<ArchiveScreen>(find.byType(ArchiveScreen));
              a.onOpenCategory(a.categories.first);
              await t.pumpAndSettle();
              if (scene == 'card-review') {
                t
                    .widget<ArchiveScreen>(find.byType(ArchiveScreen))
                    .onOpenRandomView();
                await t.pumpAndSettle();
              }
            }
          } else if (scene == 'bookmark') {
            home().onTab(AppRoute.bookmark);
            await t.pumpAndSettle();
          } else if (scene == 'search') {
            home().onSearch();
            await t.pumpAndSettle();
          } else if (scene == 'detail') {
            home().onOpenContent(home().contents.first);
            await t.pumpAndSettle();
          } else if (scene == 'notifications') {
            home().onOpenNotifications!();
            await t.pumpAndSettle();
          } else if ([
            'my',
            'account',
            'category-management',
            'logout-confirmation',
          ].contains(scene)) {
            home().onTab(AppRoute.my);
            await t.pumpAndSettle();
            final my = t.widget<MyScreen>(find.byType(MyScreen));
            if (scene == 'category-management') {
              my.onOpenCategoryManagement();
              await t.pumpAndSettle();
            } else if (scene != 'my') {
              my.onOpenAccount();
              await t.pumpAndSettle();
              if (scene == 'logout-confirmation') {
                await t
                    .widget<AccountManagementScreen>(
                      find.byType(AccountManagementScreen),
                    )
                    .onLogout();
                await t.pumpAndSettle();
              }
            }
          }
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpAndSettle();
          final before = screen();
          pops = 0;
          final handled = await t.binding.handlePopRoute();
          await t.pumpAndSettle();
          final result = {
            'scene': scene,
            'before': before,
            'after': screen(),
            'frameworkHandled': handled,
            'systemNavigatorPopRequests': pops,
            'frameworkError': t.takeException()?.toString(),
          };
          debugPrint('BACK_PROBE ${jsonEncode(result)}');
          expect(pops, 0);
          expect(result['frameworkError'], isNull);
          const expected = {
            'archive': 'HomeScreen',
            'bookmark': 'HomeScreen',
            'my': 'HomeScreen',
            'search': 'HomeScreen',
            'detail': 'HomeScreen',
            'account': 'MyScreen',
            'category-list': 'ArchiveScreen',
            'card-review': 'ArchiveScreen',
            'category-management': 'MyScreen',
            'notifications': 'HomeScreen',
            'logout-confirmation': 'AccountManagementScreen',
          };
          if (scene == 'home') {
            expect(find.text('앱을 종료할까요?'), findsOneWidget);
          } else {
            expect(screen(), expected[scene]);
          }
          expect(handled, isTrue);
        } finally {
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
          debugDefaultTargetPlatformOverride = null;
        }
      }, () => server.client);
    });
  }
}
