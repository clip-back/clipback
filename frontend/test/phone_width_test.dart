// Window-width policy through the production app/theme and real sheet routes.
// HTTP, sessions and keyboard metrics are local test doubles, not device proof.
import 'dart:convert';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/account/notice_list_screen.dart';
import 'package:clipback_frontend/features/account/settings_sheets.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/shared/widgets/notification_sheet.dart';
import 'support/placeholder_screen.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/auth/account_link_conflict_screen.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_failure_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/login_status_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/auth/session_restore_screen.dart';
import 'package:clipback_frontend/features/home/home_initial_loading_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/share/pending_share_prompt.dart';
import 'package:clipback_frontend/data/repositories/share_repository.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures/home_base_alignment_fixture.dart' as home;
import 'fixtures/search_history_memory_storage.dart';
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as archive;

Finder _type(String name) =>
    find.byWidgetPredicate((widget) => widget.runtimeType.toString() == name);

// Independent expected boundaries, including both sides of the 600 breakpoint.
final _windows = <double, (double, double)>{
  375: (0, 375),
  393: (0, 393),
  430: (0, 430),
  599: (0, 599),
  600: (112.5, 487.5),
  768: (196.5, 571.5),
};

void _edges(WidgetTester tester, Finder finder, (double, double) edges) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.left, closeTo(edges.$1, .01), reason: '$finder left');
  expect(rect.right, closeTo(edges.$2, .01), reason: '$finder right');
  expect(rect.height, greaterThan(0));
  expect(tester.takeException(), isNull);
}

void _screen(WidgetTester tester, String name, (double, double) edges) {
  final screen = _type(name);
  expect(screen, findsOneWidget);
  expect(ModalRoute.of(tester.element(screen))!.isCurrent, isTrue);
  _edges(
    tester,
    find.descendant(of: screen, matching: find.byType(Scaffold)),
    edges,
  );
  final navigation = find.descendant(
    of: screen,
    matching: find.byType(ClipbackNavigationBar),
  );
  if (navigation.evaluate().isNotEmpty) _edges(tester, navigation, edges);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _sheet(WidgetTester tester, String name, (double, double) edges) {
  final sheet = _type(name);
  expect(sheet, findsOneWidget);
  expect(ModalRoute.of(tester.element(sheet))!.isCurrent, isTrue);
  _edges(tester, sheet, edges);
}

Future<void> _close(WidgetTester tester, String name) async {
  Navigator.of(tester.element(_type(name))).pop();
  await tester.pumpAndSettle();
  expect(_type(name), findsNothing);
}

Future<void> _root(
  WidgetTester tester,
  double width,
  double scale,
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 852);
  final padding = FakeViewPadding(
    top: platform == TargetPlatform.iOS ? 59 : 24,
    bottom: platform == TargetPlatform.iOS ? 34 : 24,
  );
  tester.view.viewPadding = padding;
  tester.view.padding = padding;
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() {
    tester.view.reset();
    debugDefaultTargetPlatformOverride = null;
  });
  final server = home.HomeBaseServer('normal');
  final client = MockClient((request) async {
    if (request.url.path == '/api/v1/recommendations/weekly') {
      return server.json({
        'period_start': '2026-10-19T00:00:00Z',
        'period_end': '2026-10-26T00:00:00Z',
        'batch_id': null,
        'generated_at': null,
        'items': <Object>[],
      });
    }
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await server.client.send(copy));
  });
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: ClipbackApp(
              sessionStorage: archive.ArchiveAllMemoryStorage(),
              socialAuth: archive.ArchiveAllSocialAuth(),
              searchHistoryStorage: SearchHistoryMemoryStorage(),
            ),
          ),
        ),
      );
      await completeAppStartup(tester);
      await body();
      expect(server.unexpected, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
      server.client.close();
      debugDefaultTargetPlatformOverride = null;
    }
  }, () => client);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family']);
      for (final font in family['fonts']) {
        loader.addFont(rootBundle.load(font['asset']));
      }
      await loader.load();
    }
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final window in _windows.entries) {
      final width = window.key, edges = window.value;
      for (final scale in [1.0, 1.3]) {
        final label = '${platform.name} $width text=$scale';
        testWidgets('$label app screens and fixed home card', (tester) async {
          await _root(tester, width, scale, platform, () async {
            _screen(tester, 'HomeScreen', edges);
            final header = find.byKey(const ValueKey('home-header'));
            expect(
              tester.getRect(header).top,
              platform == TargetPlatform.iOS ? 67 : 32,
            );
            final card = find.byType(HomeContentCard).first;
            expect(tester.getSize(card).width, 298);
            expect(tester.getCenter(card).dx, width / 2);
            final headerRow = find
                .descendant(of: header, matching: find.byType(Row))
                .first;
            expect(tester.getRect(headerRow).left - edges.$1, 16);
            expect(edges.$2 - tester.getRect(headerRow).right, 16);
            final original = tester.widget<HomeScreen>(_type('HomeScreen'));
            original.onOpenContent(original.contents.first);
            await tester.pumpAndSettle();
            _screen(tester, 'DetailScreen', edges);
            original.onTab(AppRoute.home);
            await tester.pumpAndSettle();
            tester.widget<HomeScreen>(_type('HomeScreen')).onOpenArchive();
            await tester.pumpAndSettle();
            _screen(tester, 'ArchiveScreen', edges);
            var current = tester.widget<ArchiveScreen>(_type('ArchiveScreen'));
            current.onTabChanged(1);
            await tester.pumpAndSettle();
            _screen(tester, 'ArchiveScreen', edges);
            current = tester.widget<ArchiveScreen>(_type('ArchiveScreen'));
            current.onOpenCategory(current.categories.first);
            await tester.pumpAndSettle();
            _screen(tester, 'ArchiveScreen', edges);
            tester
                .widget<ArchiveScreen>(_type('ArchiveScreen'))
                .onOpenCategoryManagement!();
            await tester.pumpAndSettle();
            _screen(tester, 'CategoryManagementScreen', edges);
            original.onTab(AppRoute.bookmark);
            await tester.pumpAndSettle();
            _screen(tester, 'BookmarkScreen', edges);
            original.onTab(AppRoute.home);
            await tester.pumpAndSettle();
            tester.widget<HomeScreen>(_type('HomeScreen')).onSearch();
            await tester.pumpAndSettle();
            _screen(tester, 'SearchScreen', edges);
            final search = find.byType(TextField).first;
            await tester.enterText(search, '하루');
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            expect(tester.getRect(search).bottom, lessThanOrEqualTo(552));
            tester.view.viewInsets = const FakeViewPadding();
            await tester.pumpAndSettle();
            expect(tester.widget<TextField>(search).controller!.text, '하루');
            original.onTab(AppRoute.home);
            await tester.pumpAndSettle();
            tester
                .widget<HomeScreen>(_type('HomeScreen'))
                .onOpenNotifications!();
            await tester.pumpAndSettle();
            _screen(tester, 'NotificationListScreen', edges);
            original.onTab(AppRoute.my);
            await tester.pumpAndSettle();
            _screen(tester, 'MyScreen', edges);
            Navigator.of(tester.element(_type('MyScreen'))).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    NoticeListScreen(titles: mockNotices, onBack: () {}),
              ),
            );
            await tester.pumpAndSettle();
            _screen(tester, 'NoticeListScreen', edges);
            Navigator.of(tester.element(_type('NoticeListScreen'))).pop();
            await tester.pumpAndSettle();
            original.onTab(AppRoute.my);
            await tester.pumpAndSettle();
            tester.widget<MyScreen>(_type('MyScreen')).onOpenAccount();
            await tester.pumpAndSettle();
            _screen(tester, 'AccountManagementScreen', edges);
            final account = tester.widget<AccountManagementScreen>(
              _type('AccountManagementScreen'),
            );
            await account.onConnect();
            await tester.pumpAndSettle();
            _screen(tester, 'LoginScreen', edges);
            expect(
              tester.widget<LoginScreen>(_type('LoginScreen')).linkingGuest,
              isTrue,
            );
            tester.widget<LoginScreen>(_type('LoginScreen')).onBack!();
            await tester.pumpAndSettle();
            account.onLogout();
            await tester.pumpAndSettle();
            _screen(tester, 'LogoutConfirmationScreen', edges);
          });
        });
        testWidgets('$label sheet routes and keyboard input', (tester) async {
          await _root(tester, width, scale, platform, () async {
            final original = tester.widget<HomeScreen>(_type('HomeScreen'));
            await _tap(tester, find.byType(NavAddButton));
            // The save route fills the window; measure its constrained Material.
            final save = _type('AddContentSheet');
            expect(
              ModalRoute.of(tester.element(save)).runtimeType.toString(),
              startsWith('RawDialogRoute'),
            );
            _edges(
              tester,
              find.descendant(of: save, matching: find.byType(Material)).first,
              edges,
            );
            await tester.enterText(
              find.byType(TextField).first,
              'https://example.com/capture',
            );
            final input = tester.widget<EditableText>(
              find.byType(EditableText).first,
            );
            final route = ModalRoute.of(tester.element(save));
            for (final bottom in [300.0, 0.0]) {
              tester.view.viewInsets = FakeViewPadding(bottom: bottom);
              await tester.pumpAndSettle();
              expect(ModalRoute.of(tester.element(save)), same(route));
              expect(
                tester
                    .widget<EditableText>(find.byType(EditableText).first)
                    .controller,
                same(input.controller),
              );
              expect(input.controller.text, 'https://example.com/capture');
              expect(
                MediaQuery.viewInsetsOf(tester.element(save)).bottom,
                bottom,
              );
              expect(
                tester.getRect(find.text('허투루에 저장하기').last).bottom,
                lessThanOrEqualTo(852 - bottom),
              );
            }
            await _close(tester, 'AddContentSheet');
            original.onTab(AppRoute.my);
            await tester.pumpAndSettle();
            tester.widget<MyScreen>(_type('MyScreen')).onTab(AppRoute.archive);
            await tester.pumpAndSettle();
            tester
                .widget<ArchiveScreen>(_type('ArchiveScreen'))
                .onOpenCategoryManagement!();
            await tester.pumpAndSettle();
            await _tap(tester, find.byKey(const ValueKey('management-add')));
            _sheet(tester, 'CategoryCreateSheet', edges);
            await _close(tester, 'CategoryCreateSheet');
            tester
                .widget<CategoryRow>(find.byType(CategoryRow).first)
                .onMore!();
            await tester.pumpAndSettle();
            _sheet(tester, 'CategoryActionSheet', edges);
            await _tap(
              tester,
              find.byKey(const ValueKey('category-actions-edit')),
            );
            _sheet(tester, 'CategoryEditSheet', edges);
            final field = find.byType(TextField).first;
            final text = List.filled(40, '가').join();
            await tester.enterText(field, text);
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            _sheet(tester, 'CategoryEditSheet', edges);
            final button = find.byKey(const ValueKey('category-form-button'));
            expect(tester.getRect(button).bottom, lessThanOrEqualTo(552));
            expect(tester.widget<TextField>(field).controller!.text, text);
            tester.view.viewInsets = const FakeViewPadding();
            await _close(tester, 'CategoryEditSheet');
            original.onTab(AppRoute.home);
            await tester.pumpAndSettle();
            original.onOpenContent(original.contents.first);
            await tester.pumpAndSettle();
            await _tap(tester, find.byKey(const ValueKey('detail-more')));
            _sheet(tester, 'ContentActionSheet', edges);
            await _tap(tester, find.text('카테고리 변경'));
            _sheet(tester, 'CategoryChangeSheet', edges);
            await _close(tester, 'CategoryChangeSheet');
          });
        });
        testWidgets(
          '$label auxiliary sheets inherit production route constraints',
          (tester) async {
            await _root(tester, width, scale, platform, () async {
              final context = tester.element(find.byType(HomeScreen));
              // Fallback panels use the public modal route options of their
              // callers; normal app navigation opens dedicated list screens.
              for (final sheet in <Widget>[
                const NoticeSheet(),
                const NotificationSheet(),
              ]) {
                showModalBottomSheet<void>(
                  context: context,
                  useSafeArea: true,

                  backgroundColor: Colors.transparent,
                  builder: (_) => sheet,
                );
                await tester.pumpAndSettle();
                _sheet(tester, sheet.runtimeType.toString(), edges);
                await _close(tester, sheet.runtimeType.toString());
              }
            });
          },
        );
        testWidgets('$label original image failure route and dismissal', (
          tester,
        ) async {
          await _root(tester, width, scale, platform, () async {
            const content = ContentItem(
              id: 'screenshot',
              title: '저장한 사진',
              summary: '원본 확인',
              category: catUncategorized,
              savedAt: '오늘',
              savedAtFull: '2026년 11월 5일',
              savedAtFullShort: '26.11.05',
              tags: [],
              source: '스크린샷',
              originalUrl: '',
              originalText: '',
              isScreenshot: true,
              assets: [
                ApiAsset(
                  id: 9,
                  assetType: 'screenshot',
                  downloadUrl: '/asset/9',
                ),
              ],
            );
            var reads = 0;
            final context = tester.element(find.byType(HomeScreen));
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DetailScreen(
                  content: content,
                  contents: const [content],
                  categories: const [],
                  bookmarked: false,
                  onReadAsset: (_) async {
                    reads++;
                    throw StateError('unavailable test image');
                  },
                  onBack: () {},
                  onToggleBookmark: (_) {},
                  onChangeCategory: (_, _) {},
                  onDeleteContent: (_) {},
                  onOpenOriginalLink: () {},
                  onOpenAdjacent: (_) {},
                  onOpenContent: (_) {},
                  onAddLink: ({required url, submissionKey, category}) async =>
                      content,
                  onAddScreenshot:
                      ({
                        required bytes,
                        required filename,
                        submissionKey,
                        category,
                      }) async => content,
                  onTab: (_) {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            final detailState = tester.state(find.byType(DetailScreen));
            final link = find.byWidgetPredicate(
              (w) => w is SvgIconButton && w.asset == Assets.detailLink,
            );
            await _tap(tester, link);
            _sheet(tester, 'OriginalContentSheet', edges);
            expect(reads, 1);
            expect(find.text('원본 이미지를 불러오지 못했어요.'), findsOneWidget);
            await _tap(tester, find.text('확인'));
            expect(_type('OriginalContentSheet'), findsNothing);
            expect(tester.state(find.byType(DetailScreen)), same(detailState));
          });
        });
        testWidgets('$label pending share chooser uses production theme', (
          tester,
        ) async {
          await _root(tester, width, scale, platform, () async {
            // dart:io disables native share on the host; exercise its actual
            // chooser route with the theme obtained from the real app.
            final theme = tester
                .widget<MaterialApp>(find.byType(MaterialApp))
                .theme;
            final nav = GlobalKey<NavigatorState>();
            await tester.pumpWidget(
              MaterialApp(
                navigatorKey: nav,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: PendingSharePrompt(
                    navigatorKey: nav,
                    promptVersion: 1,
                    drafts: const [
                      PendingShareDraft(
                        id: 'width',
                        label: '저장 대기 공유 링크',
                        userId: 1,
                      ),
                    ],
                    error: null,
                    busy: false,
                    onRetry: () {},
                    onOpen: (_) {},
                    child: child!,
                  ),
                ),
                home: const Scaffold(),
              ),
            );
            await tester.pumpAndSettle();
            await _tap(tester, find.text('확인'));
            _edges(
              tester,
              find
                  .descendant(
                    of: find.byType(BottomSheet),
                    matching: find.byType(Material),
                  )
                  .first,
              edges,
            );
            expect(find.text('저장 대기 공유 링크'), findsOneWidget);
          });
        });
        final screens = <Widget>[
          const HomeInitialLoadingScreen(),
          const LoginProgressScreen(),
          LoginCancelledScreen(
            onChooseMethods: () {},
            onContinueAsGuest: () {},
          ),
          LoginFailureScreen(
            statusCode: 503,
            onChooseMethods: () {},
            onContinueAsGuest: () {},
            onContact: () {},
          ),
          AccountLinkConflictScreen(onKeepGuest: () {}, onConfirm: () {}),
          InterestSelectionScreen(onBack: () {}, onDone: () {}),
          OnboardingScreen(onDone: () {}),
          SessionRestoreScreen(errorMessage: '불러오지 못했어요.', onRetry: () {}),
          const PlaceholderScreen(title: '준비', activeIndex: 0),
        ];
        for (final screen in screens) {
          testWidgets('$label ${screen.runtimeType} visible surface', (
            tester,
          ) async {
            await _root(tester, width, scale, platform, () async {
              final context = tester.element(find.byType(HomeScreen));
              Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => screen));
              await tester.pumpAndSettle();
              _screen(tester, screen.runtimeType.toString(), edges);
            });
          });
        }
      }
    }
  }
}
