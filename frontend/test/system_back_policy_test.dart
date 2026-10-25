import 'dart:async';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/auth/session_restore_screen.dart';
import 'weekly_root_test.dart' as weekly;
import 'today_root_test.dart' as today;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/app/exit_confirmation_dialog.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/bookmark_screen.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/archive_all_preview.dart' as base;
import 'support/app_startup.dart';
import 'support/system_back_preview.dart' show BackMemoryHistory;

T widget<T extends Widget>(WidgetTester t) => t.widget<T>(find.byType(T));
Future<void> back(WidgetTester t) async {
  expect(await t.binding.handlePopRoute(), isTrue);
  await t.pumpAndSettle();
}

final popup = find.byType(ExitConfirmationDialog);
final cancel = find.byKey(const ValueKey('exit-confirmation-cancel'));
final exit = find.byKey(const ValueKey('exit-confirmation-exit'));

class BackHarness {
  BackHarness([base.ArchiveAllMemoryStorage? storage])
    : storage = storage ?? base.ArchiveAllMemoryStorage();
  int osExits = 0;
  final server = base.ArchiveAllServer();
  final base.ArchiveAllMemoryStorage storage;
}

Future<void> withApp(
  WidgetTester t,
  Future<void> Function(BackHarness h) body, {
  TargetPlatform platform = TargetPlatform.android,
  double width = 375,
  bool loggedIn = true,
  bool finishStartup = true,
  base.ArchiveAllMemoryStorage? storage,
}) async {
  final h = BackHarness(storage);
  if (!loggedIn) h.storage.value = null;
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 812);
  t.view.viewPadding = FakeViewPadding(
    top: platform == TargetPlatform.iOS ? 59 : 24,
    bottom: platform == TargetPlatform.iOS ? 34 : 0,
  );
  addTearDown(t.view.reset);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
    if (c.method == 'SystemNavigator.pop') h.osExits++;
    return null;
  });
  await http.runWithClient(() async {
    try {
      await t.pumpWidget(
        ClipbackApp(
          sessionStorage: h.storage,
          socialAuth: base.ArchiveAllSocialAuth(),
          searchHistoryStorage: BackMemoryHistory(),
        ),
      );
      if (finishStartup) await completeAppStartup(t);
      await body(h);
      expect(t.takeException(), isNull);
      expect(h.server.unexpected, isEmpty);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      debugDefaultTargetPlatformOverride = previous;
    }
  }, () => h.server.client);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });
  for (final method in ['cancel', 'back', 'barrier']) {
    testWidgets('exit $method never exits or changes session', (t) async {
      await withApp(t, (h) async {
        final session = h.storage.value;
        await back(t);
        expect(popup, findsOneWidget);
        final count = h.server.requests.length;
        if (method == 'cancel') {
          await t.tap(cancel);
          await t.pumpAndSettle();
        } else if (method == 'back') {
          await back(t);
        } else {
          await t.tapAt(const Offset(5, 150));
          await t.pumpAndSettle();
        }
        expect(popup, findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(h.osExits, 0);
        expect(h.storage.value, same(session));
        expect(h.server.requests.length, count);
      });
    });
  }
  testWidgets('explicit confirmation once; duplicate and old callbacks inert', (
    t,
  ) async {
    await withApp(t, (h) async {
      await back(t);
      final old = widget<ExitConfirmationDialog>(t).onExit;
      old();
      old();
      await t.pumpAndSettle();
      expect(h.osExits, 1);
      expect(popup, findsNothing);
      old();
      await t.pumpAndSettle();
      expect(h.osExits, 1);
    });
  });
  testWidgets('route change invalidates owned dialog and old confirmation', (
    t,
  ) async {
    await withApp(t, (h) async {
      final home = widget<HomeScreen>(t);
      await back(t);
      final old = widget<ExitConfirmationDialog>(t).onExit;
      home.onTab(AppRoute.my);
      await t.pumpAndSettle();
      expect(popup, findsNothing);
      expect(find.byType(MyScreen), findsOneWidget);
      old();
      await t.pumpAndSettle();
      expect(h.osExits, 0);
      await back(t);
      await back(t);
      expect(popup, findsOneWidget);
      old();
      await t.pumpAndSettle();
      expect(h.osExits, 0);
      expect(popup, findsOneWidget);
    });
  });
  testWidgets('disposed root ignores exit callback', (t) async {
    await withApp(t, (h) async {
      await back(t);
      final old = widget<ExitConfirmationDialog>(t).onExit;
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      old();
      await t.pumpAndSettle();
      expect(h.osExits, 0);
    });
  });
  testWidgets('keyboard inset keeps query and controller; next back returns', (
    t,
  ) async {
    await withApp(t, (h) async {
      widget<HomeScreen>(t).onSearch();
      await t.pumpAndSettle();
      final field = widget<TextField>(t),
          controller = widget<TextField>(t).controller!;
      controller.text = '하루';
      field.onChanged!('하루');
      await t.pumpAndSettle();
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pump();
      await back(t);
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(widget<TextField>(t).controller, same(controller));
      expect(controller.text, '하루');
      t.view.viewInsets = FakeViewPadding.zero;
      await t.pump();
      await back(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(h.osExits, 0);
    });
  });
  testWidgets('save modal back closes modal only without requests', (t) async {
    await withApp(t, (h) async {
      widget<ClipbackNavigationBar>(t).onAdd!();
      await t.pumpAndSettle();
      expect(find.byType(AddContentSheet), findsOneWidget);
      final calls = h.server.requests.length;
      await back(t);
      expect(find.byType(AddContentSheet), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(popup, findsNothing);
      expect(h.server.requests.length, calls);
      expect(h.osExits, 0);
    });
  });
  testWidgets('review-category-archive-home each consume one back', (t) async {
    await withApp(t, (h) async {
      widget<HomeScreen>(t).onTab(AppRoute.archive);
      await t.pumpAndSettle();
      final a = widget<ArchiveScreen>(t);
      a.onOpenCategory(a.categories.first);
      await t.pumpAndSettle();
      widget<ArchiveScreen>(t).onOpenRandomView();
      await t.pumpAndSettle();
      await back(t);
      expect(find.byType(CategoryCardReviewScreen), findsNothing);
      expect(widget<ArchiveScreen>(t).activeCategoryName, isNotNull);
      await back(t);
      expect(widget<ArchiveScreen>(t).activeCategoryName, isNull);
      expect(widget<ArchiveScreen>(t).activeTab, 1);
      await back(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(popup, findsNothing);
      await back(t);
      expect(popup, findsOneWidget);
      expect(h.osExits, 0);
    });
  });
  for (final source in [AppRoute.archive, AppRoute.bookmark, AppRoute.home]) {
    testWidgets('detail back retains origin $source', (t) async {
      await withApp(t, (h) async {
        final home = widget<HomeScreen>(t),
            content = widget<HomeScreen>(t).contents.first;
        if (source != AppRoute.home) {
          home.onTab(source);
          await t.pumpAndSettle();
        }
        if (source == AppRoute.archive) {
          widget<ArchiveScreen>(t).onOpenContent(content);
        } else if (source == AppRoute.bookmark) {
          final b = widget<BookmarkScreen>(t);
          b.onOpenContent(b.contents.first);
        } else {
          home.onOpenContent(content);
        }
        await t.pumpAndSettle();
        expect(find.byType(DetailScreen), findsOneWidget);
        await back(t);
        expect(find.byType(DetailScreen), findsNothing);
        expect(popup, findsNothing);
        expect(
          find.byType(
            source == AppRoute.home
                ? HomeScreen
                : source == AppRoute.archive
                ? ArchiveScreen
                : BookmarkScreen,
          ),
          findsOneWidget,
        );
        expect(h.osExits, 0);
      });
    });
  }
  testWidgets('search detail round-trip retains submitted query', (t) async {
    await withApp(t, (h) async {
      widget<HomeScreen>(t).onSearch();
      await t.pumpAndSettle();
      final f = widget<TextField>(t);
      f.controller!.text = '하루';
      f.onChanged!('하루');
      f.onSubmitted!('하루');
      await t.pumpAndSettle();
      final s = widget<SearchScreen>(t);
      s.onOpenContent(s.contents.first);
      await t.pumpAndSettle();
      await back(t);
      expect(widget<SearchScreen>(t).initialQuery, '하루');
      expect(widget<TextField>(t).controller!.text, '하루');
      await back(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(h.osExits, 0);
    });
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0]) {
      testWidgets('root policy actual fonts $platform $width', (t) async {
        await withApp(
          t,
          (h) async {
            await back(t);
            if (platform == TargetPlatform.android) {
              expect(popup, findsOneWidget);
              final b = t.getRect(
                find.byKey(const ValueKey('exit-confirmation-dialog')),
              );
              expect(b.left, greaterThanOrEqualTo(32));
              expect(b.right, lessThanOrEqualTo(width - 32));
              expect(t.getSize(cancel).height, 44);
              expect(t.getSize(exit).height, 44);
              final title = t.widget<Text>(find.text('앱을 종료할까요?'));
              expect(title.style!.fontFamily, 'Pretendard');
              expect(title.style!.fontSize, 18);
              expect(title.style!.fontWeight, FontWeight.w600);
            } else {
              expect(popup, findsNothing);
            }
            expect(h.osExits, 0);
          },
          platform: platform,
          width: width,
        );
      });
    }
  }
  testWidgets('ordinary login confirmation cancel stays on login', (t) async {
    await withApp(t, (h) async {
      expect(find.byType(LoginScreen), findsOneWidget);
      await back(t);
      expect(popup, findsOneWidget);
      await t.tap(cancel);
      await t.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(h.osExits, 0);
    }, loggedIn: false);
  });
  testWidgets('intro confirms exit and interests returns to intro', (t) async {
    await withApp(t, (h) async {
      await widget<LoginScreen>(t).onContinue();
      await t.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await back(t);
      expect(popup, findsOneWidget);
      await t.tap(cancel);
      await t.pumpAndSettle();
      widget<OnboardingScreen>(t).onDone();
      await t.pumpAndSettle();
      expect(find.byType(InterestSelectionScreen), findsOneWidget);
      await back(t);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(popup, findsNothing);
      expect(h.osExits, 0);
    }, loggedIn: false);
  });
  testWidgets('linking login back returns to account without exit', (t) async {
    await withApp(t, (h) async {
      widget<HomeScreen>(t).onTab(AppRoute.my);
      await t.pumpAndSettle();
      widget<MyScreen>(t).onOpenAccount();
      await t.pumpAndSettle();
      await widget<AccountManagementScreen>(t).onConnect();
      await t.pumpAndSettle();
      expect(widget<LoginScreen>(t).linkingGuest, isTrue);
      await back(t);
      expect(find.byType(AccountManagementScreen), findsOneWidget);
      expect(popup, findsNothing);
      expect(h.osExits, 0);
    });
  });
  testWidgets(
    'launch and pending restore consume Back without exit or bypass',
    (t) async {
      final storage = _PendingStorage();
      await withApp(
        t,
        (h) async {
          expect(await t.binding.handlePopRoute(), isTrue);
          await t.pump();
          expect(h.osExits, 0);
          expect(popup, findsNothing);
          await t.pump(const Duration(milliseconds: 900));
          await t.pump();
          expect(find.byType(SessionRestoreScreen), findsOneWidget);
          expect(await t.binding.handlePopRoute(), isTrue);
          await t.pump();
          expect(find.byType(SessionRestoreScreen), findsOneWidget);
          expect(h.osExits, 0);
          storage.pending.complete(storage.value);
          await t.pump();
          await t.pump(const Duration(milliseconds: 900));
          await t.pumpAndSettle();
          expect(find.byType(HomeScreen), findsOneWidget);
        },
        storage: storage,
        finishStartup: false,
      );
    },
  );
  testWidgets('restore error back stays in recovery', (t) async {
    final storage = _PendingStorage();
    await withApp(
      t,
      (h) async {
        storage.pending.completeError(StateError('controlled storage failure'));
        await completeAppStartup(t);
        expect(find.byType(SessionRestoreScreen), findsOneWidget);
        await back(t);
        expect(find.byType(SessionRestoreScreen), findsOneWidget);
        expect(popup, findsNothing);
        expect(h.osExits, 0);
      },
      storage: storage,
      finishStartup: false,
    );
  });
  testWidgets('Weekly Back preserves attribution then returns directly home', (
    t,
  ) async {
    await weekly.withHome(t, (s) async {
      final home = weekly.home(t), item = weekly.home(t).weeklyItems.first;
      home.onWeeklySelected!(item);
      await t.pumpAndSettle();
      weekly.archive(t).onOpenContent(weekly.archive(t).contents.first);
      await t.pumpAndSettle();
      final views = weekly.views(s).length;
      await back(t);
      expect(weekly.archive(t).feed!.categoryId, item.category.id);
      expect(weekly.views(s).length, views);
      await back(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ArchiveScreen), findsNothing);
    });
  });
  testWidgets('Today Back returns home without a new view', (t) async {
    await today.withHome(t, (s) async {
      today.home(t).onOpenToday();
      await t.pumpAndSettle();
      expect(today.detail(t).content.apiId, 606);
      final views = today.views(s).length;
      await back(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(today.views(s).length, views);
    });
  });
}

class _PendingStorage extends base.ArchiveAllMemoryStorage {
  final pending = Completer<ApiSession?>();
  @override
  Future<ApiSession?> read() => pending.future;
}
