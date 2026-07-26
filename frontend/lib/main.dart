import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(const ClipbackApp());
}

class ClipbackApp extends StatefulWidget {
  const ClipbackApp({super.key});

  @override
  State<ClipbackApp> createState() => _ClipbackAppState();
}

class _ClipbackAppState extends State<ClipbackApp> {
  AppRoute _route = AppRoute.splash;
  AppRoute _previousRoute = AppRoute.home;
  int _archiveTab = 0;
  bool _bookmarkedFirst = false;
  String? _activeCategoryName;
  ContentItem? _selectedContent;
  String _searchQuery = '';
  late final List<CategoryItem> _categories;
  late final List<ContentItem> _contents;
  late final Set<String> _bookmarkedIds;

  @override
  void initState() {
    super.initState();
    _categories = List.of(initialCategories);
    _contents = List.of(initialContents);
    _bookmarkedIds = {
      for (final content in initialContents.where((item) => item.bookmarked))
        content.id,
    };
  }

  bool _isBookmarked(ContentItem content) =>
      _bookmarkedIds.contains(content.id);

  void _toggleBookmark(ContentItem content) {
    setState(() {
      if (!_bookmarkedIds.remove(content.id)) {
        _bookmarkedIds.add(content.id);
      }
    });
  }

  void _addContent(ContentItem content) {
    setState(() {
      _contents.insert(0, content);
      _selectedContent = content;
      _route = AppRoute.detail;
      _previousRoute = AppRoute.home;
    });
  }

  void _addLinkContent({required String url, required CategoryItem category}) {
    final count = _contents.length + 1;
    _addContent(
      ContentItem(
        id: 'mock-link-$count',
        title: '새로 저장한 링크 요약',
        summary:
            '입력한 링크에서 제목과 설명을 추출한 목데이터입니다. 실제 API 연결 전까지 저장 완료, 자동 분류, 상세 확인 흐름을 검증할 수 있어요.',
        category: category,
        savedAt: '26.07.23',
        savedAtFull: '2026. 07. 23 오후 09:58',
        savedAtFullShort: '2026. 07. 23 21:58',
        tags: ['링크저장', category.name, '자동분류'],
        source: '직접 입력',
        originalUrl: url,
        originalText: '사용자가 입력한 링크: $url',
      ),
    );
  }

  void _addScreenshotContent() {
    final category = _categories.firstWhere(
      (item) => item.name == '생활정보',
      orElse: () => _categories.first,
    );
    _addContent(
      ContentItem(
        id: 'mock-screenshot-${_contents.length + 1}',
        title: '스크린샷으로 저장한 레시피 메모',
        summary:
            '갤러리에서 선택한 이미지를 OCR로 읽어 제목과 요약을 만든 목데이터입니다. OCR 실패 시에도 미분류로 저장되는 기획 흐름을 화면에서 확인할 수 있어요.',
        category: category,
        savedAt: '26.07.23',
        savedAtFull: '2026. 07. 23 오후 10:01',
        savedAtFullShort: '2026. 07. 23 22:01',
        tags: ['스크린샷', 'OCR', '생활정보'],
        source: '스크린샷',
        originalUrl: '',
        originalText: '이미지 OCR 목데이터: 토마토, 달걀, 올리브오일을 사용한 간단한 아침 레시피',
        isScreenshot: true,
      ),
    );
  }

  void _addCategory(CategoryItem category) {
    setState(() {
      _categories.insert(0, category);
      _archiveTab = 1;
      _activeCategoryName = null;
      _route = AppRoute.archive;
      _previousRoute = AppRoute.archive;
    });
  }

  void _changeContentCategory(ContentItem content, CategoryItem category) {
    setState(() {
      final index = _contents.indexWhere((item) => item.id == content.id);
      if (index == -1) return;
      final updated = _contents[index].copyWith(category: category);
      _contents[index] = updated;
      if (_selectedContent?.id == content.id) {
        _selectedContent = updated;
      }
    });
  }

  void _deleteContent(ContentItem content) {
    setState(() {
      _contents.removeWhere((item) => item.id == content.id);
      _bookmarkedIds.remove(content.id);
      _selectedContent = null;
      _route = _previousRoute == AppRoute.detail
          ? AppRoute.home
          : _previousRoute;
    });
  }

  void _openAdjacentContent(int delta) {
    final current = _selectedContent;
    if (current == null || _contents.isEmpty) return;
    final index = _contents.indexWhere((item) => item.id == current.id);
    if (index == -1) return;
    final nextIndex = (index + delta) % _contents.length;
    final wrappedIndex = nextIndex < 0 ? _contents.length - 1 : nextIndex;
    setState(() => _selectedContent = _contents[wrappedIndex]);
  }

  void _go(AppRoute route) {
    setState(() {
      _route = route;
      if (route != AppRoute.detail) {
        _selectedContent = null;
      }
      if (route == AppRoute.home ||
          route == AppRoute.archive ||
          route == AppRoute.bookmark ||
          route == AppRoute.my) {
        _previousRoute = route;
      }
    });
  }

  void _selectRootTab(AppRoute route) {
    setState(() {
      if (route == AppRoute.archive && _route != AppRoute.archive) {
        _archiveTab = 0;
        _activeCategoryName = null;
      }
      _route = route;
      _selectedContent = null;
      if (route == AppRoute.home ||
          route == AppRoute.archive ||
          route == AppRoute.bookmark ||
          route == AppRoute.my) {
        _previousRoute = route;
      }
    });
  }

  void _openSearch() {
    setState(() {
      _previousRoute = _route;
      _searchQuery = '';
      _route = AppRoute.search;
    });
  }

  void _openArchive({int tab = 0, String? categoryName}) {
    setState(() {
      _route = AppRoute.archive;
      _archiveTab = tab;
      _activeCategoryName = categoryName;
      _selectedContent = null;
      _previousRoute = AppRoute.archive;
    });
  }

  void _openDetail(ContentItem content) {
    setState(() {
      _previousRoute = _route;
      _selectedContent = content;
      _route = AppRoute.detail;
    });
  }

  void _backFromDetail() {
    setState(() {
      _route = _previousRoute;
      _selectedContent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      title: '허투루',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.main,
          surface: AppColors.bg,
        ),
        fontFamily: 'Pretendard',
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
      ),
      home: switch (_route) {
        AppRoute.splash => SplashScreen(onDone: () => _go(AppRoute.login)),
        AppRoute.login => LoginScreen(
          onContinue: () => _go(AppRoute.onboarding),
        ),
        AppRoute.onboarding => OnboardingScreen(
          onBack: () => _go(AppRoute.login),
          onDone: () => _go(AppRoute.interests),
        ),
        AppRoute.interests => InterestSelectionScreen(
          onBack: () => _go(AppRoute.onboarding),
          onDone: () => _go(AppRoute.home),
        ),
        AppRoute.home => HomeScreen(
          contents: _contents,
          categories: _categories,
          bookmarkedIds: _bookmarkedIds,
          onSearch: _openSearch,
          onOpenArchive: () => _openArchive(),
          onOpenCategories: () => _openArchive(tab: 1),
          onOpenToday: _contents.isEmpty
              ? () {}
              : () => _openDetail(_contents.first),
          onOpenContent: _openDetail,
          onToggleBookmark: _toggleBookmark,
          onAddLink: _addLinkContent,
          onAddScreenshot: _addScreenshotContent,
          onTab: _selectRootTab,
        ),
        AppRoute.archive => ArchiveScreen(
          activeTab: _archiveTab,
          contents: _contents,
          categories: _categories,
          bookmarkedIds: _bookmarkedIds,
          bookmarkedFirst: _bookmarkedFirst,
          activeCategoryName: _activeCategoryName,
          onTabChanged: (value) => setState(() => _archiveTab = value),
          onSortChanged: (value) => setState(() => _bookmarkedFirst = value),
          onClearCategory: () => setState(() => _activeCategoryName = null),
          onSearch: _openSearch,
          onOpenContent: _openDetail,
          onToggleBookmark: _toggleBookmark,
          onAddCategory: _addCategory,
          onOpenCategory: (category) => setState(() {
            _activeCategoryName = category.name;
            _archiveTab = 0;
          }),
          onTab: _selectRootTab,
        ),
        AppRoute.bookmark => BookmarkScreen(
          contents: _contents
              .where((content) => _bookmarkedIds.contains(content.id))
              .toList(),
          bookmarkedIds: _bookmarkedIds,
          onSearch: _openSearch,
          onOpenContent: _openDetail,
          onToggleBookmark: _toggleBookmark,
          onTab: _selectRootTab,
        ),
        AppRoute.search => SearchScreen(
          initialQuery: _searchQuery,
          contents: _contents,
          bookmarkedIds: _bookmarkedIds,
          onQueryChanged: (value) => _searchQuery = value,
          onClose: () => _go(_previousRoute),
          onOpenContent: _openDetail,
          onToggleBookmark: _toggleBookmark,
          onOpenArchive: () => _openArchive(),
        ),
        AppRoute.detail => DetailScreen(
          content: _selectedContent ?? _contents.first,
          contents: _contents,
          categories: _categories,
          bookmarked: _isBookmarked(_selectedContent ?? _contents.first),
          onBack: _backFromDetail,
          onToggleBookmark: _toggleBookmark,
          onChangeCategory: _changeContentCategory,
          onDeleteContent: _deleteContent,
          onOpenAdjacent: _openAdjacentContent,
          onOpenContent: _openDetail,
          onTab: _selectRootTab,
        ),
        AppRoute.my => MyScreen(onTab: _selectRootTab),
      },
    );
  }
}

enum AppRoute {
  splash,
  login,
  onboarding,
  interests,
  home,
  archive,
  bookmark,
  search,
  detail,
  my,
}

class AppColors {
  static const bg = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const middle = Color(0xFF484848);
  static const subtle = Color(0xFF767676);
  static const subSubtle = Color(0xFFB5BDC3);
  static const subtler = Color(0xFFD1D1D1);
  static const faint = Color(0xFFE4E4E4);
  static const main = Color(0xFFFFD75C);
  static const mainSubtle = Color(0xFFFFF3CE);
  static const mainDeep = Color(0xFFC5A544);
  static const blueSubtle = Color(0xFFE2F1FF);
  static const blueDeep = Color(0xFF4676A4);
}

class Assets {
  static const logo = 'assets/figma/hutureu-logo.svg';
  static const appIcon = 'assets/figma/app-icon.svg';
  static const onboarding1 = 'assets/figma/onboarding-1.svg';
  static const onboarding2 = 'assets/figma/onboarding-2.svg';
  static const onboarding3 = 'assets/figma/onboarding-3.svg';
  static const character1 = 'assets/figma/hutureu-character-1.svg';
  static const character2 = 'assets/figma/hutureu-character-2.svg';
  static const onboarding1Png = 'assets/figma/onboarding-1.png';
  static const onboarding2Png = 'assets/figma/onboarding-2.png';
  static const onboarding3Png = 'assets/figma/onboarding-3.png';
  static const character1Png = 'assets/figma/hutureu-character-1.png';
  static const character2Png = 'assets/figma/hutureu-character-2.png';
  static const homeCharacter = 'assets/figma/home-character.png';

  static const home = 'assets/icons/home.svg';
  static const archive = 'assets/icons/archive.svg';
  static const star = 'assets/icons/star.svg';
  static const account = 'assets/icons/account.svg';
  static const plus = 'assets/icons/plus.svg';
  static const search = 'assets/icons/search.svg';
  static const bell = 'assets/icons/bell.svg';
  static const chevronRight = 'assets/icons/chevron-right.svg';
  static const chevronDown = 'assets/icons/chevron-down.svg';
  static const arrowRight = 'assets/icons/arrow-right.svg';
  static const back = 'assets/icons/back.svg';
  static const more = 'assets/icons/more-vertical.svg';
  static const moreHorizontal = 'assets/icons/more-horizontal.svg';
  static const folderPlus = 'assets/icons/folder-plus.svg';
  static const clock = 'assets/icons/clock.svg';
  static const close = 'assets/icons/x.svg';
  static const instagram = 'assets/icons/instagram.svg';
}

const double phoneWidth = 375;
const double phoneHeight = 812;

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 480) {
            return child;
          }

          final previewHeight = constraints.maxHeight < phoneHeight
              ? constraints.maxHeight
              : phoneHeight;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: phoneWidth,
              height: previewHeight,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(Assets.logo, width: 149, fit: BoxFit.contain),
                const SizedBox(height: 16),
                const Text(
                  '저장한 정보를 다시 볼 순간으로',
                  style: TextStyle(
                    color: AppColors.subtle,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onBack,
    required this.onDone,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    OnboardingData(
      title: '저장한 정보,\n다시 보고 있나요?',
      body: '허투루가 다시 볼 순간을 만들어 드릴게요.',
      asset: Assets.onboarding1Png,
    ),
    OnboardingData(
      title: '흩어진 정보를\n허투루 넘기지 않도록,',
      body: '필요한 순간 다시 볼 수 있게 모아둘게요.',
      asset: Assets.onboarding2Png,
    ),
    OnboardingData(
      title: '이제 다 끝났어요!\n다시 볼 준비를 해볼까요?',
      body: '알림과 갤러리를 허용하면 필요한 순간 더 쉽게 다시 만날 수 있어요.',
      asset: Assets.onboarding3Png,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page == 0) {
      widget.onBack();
      return;
    }
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                onPageChanged: (value) => setState(() => _page = value),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index]),
              ),
              if (_page > 0)
                Positioned(
                  left: 6,
                  top: 8,
                  child: SvgIconButton(
                    asset: Assets.back,
                    onPressed: _back,
                    size: 24,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 96,
                child: PageDots(count: _pages.length, activeIndex: _page),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: PrimaryButton(
                  label: _page == _pages.length - 1 ? '시작하기' : '다음',
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 80),
          Text(data.title, style: AppText.title24),
          const SizedBox(height: 8),
          Text(data.body, style: AppText.body16Subtle),
          const Spacer(),
          Center(
            child: Image.asset(
              data.asset,
              width: 311,
              height: 252,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 200),
        ],
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Spacer(flex: 5),
                SvgPicture.asset(Assets.logo, width: 182, fit: BoxFit.contain),
                const SizedBox(height: 14),
                const Text('저장한 정보를 다시 볼 순간으로', style: AppText.body16Subtle),
                const Spacer(flex: 6),
                SocialButton(
                  label: '카카오로 계속하기',
                  color: const Color(0xFFFDDC3F),
                  foreground: AppColors.text,
                  mark: 'K',
                  onPressed: onContinue,
                ),
                const SizedBox(height: 8),
                SocialButton(
                  label: '네이버로 계속하기',
                  color: const Color(0xFF00BF18),
                  foreground: Colors.white,
                  mark: 'N',
                  onPressed: onContinue,
                ),
                const SizedBox(height: 8),
                SocialButton(
                  label: '구글로 계속하기',
                  color: Colors.white,
                  foreground: AppColors.text,
                  mark: 'G',
                  borderColor: AppColors.subtler,
                  onPressed: onContinue,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({
    required this.onBack,
    required this.onDone,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final Set<String> _selected = {mockInterestOptions.first};

  void _toggle(String option) {
    setState(() {
      if (_selected.contains(option)) {
        _selected.remove(option);
        return;
      }
      if (_selected.length < 3) {
        _selected.add(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 6,
                top: 8,
                child: SvgIconButton(
                  asset: Assets.back,
                  onPressed: widget.onBack,
                  size: 24,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '주로 어떤 정보를\n저장하고 싶으신가요?',
                      style: AppText.title24,
                    ),
                    const SizedBox(height: 8),
                    const Text('최대 3개까지 선택해 주세요.', style: AppText.body16Subtle),
                    const SizedBox(height: 48),
                    for (final option in mockInterestOptions)
                      InterestOptionTile(
                        label: option,
                        selected: _selected.contains(option),
                        onTap: () => _toggle(option),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: PrimaryButton(
                  label: '완료',
                  onPressed: widget.onDone,
                  color: _selected.isEmpty ? AppColors.faint : AppColors.text,
                  foreground: _selected.isEmpty
                      ? AppColors.subtle
                      : AppColors.main,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InterestOptionTile extends StatelessWidget {
  const InterestOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? AppColors.text : Colors.transparent,
                  shape: BoxShape.circle,
                  border: selected
                      ? null
                      : Border.all(color: AppColors.subtler, width: 1),
                ),
                child: selected
                    ? const Icon(Icons.check, color: AppColors.main, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.contents,
    required this.categories,
    required this.bookmarkedIds,
    required this.onSearch,
    required this.onOpenArchive,
    required this.onOpenCategories,
    required this.onOpenToday,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.onAddLink,
    required this.onAddScreenshot,
    required this.onTab,
    super.key,
  });

  final List<ContentItem> contents;
  final List<CategoryItem> categories;
  final Set<String> bookmarkedIds;
  final VoidCallback onSearch;
  final VoidCallback onOpenArchive;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenToday;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final void Function({required String url, required CategoryItem category})
  onAddLink;
  final VoidCallback onAddScreenshot;
  final ValueChanged<AppRoute> onTab;

  @override
  Widget build(BuildContext context) {
    final hasSavedContent = contents.isNotEmpty;
    void showAddContentSheet() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddContentSheet(
          categories: categories,
          onAddLink: onAddLink,
          onAddScreenshot: onAddScreenshot,
        ),
      );
    }

    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      HomeHero(
                        hasSavedContent: hasSavedContent,
                        onSearch: onSearch,
                        onOpenToday: hasSavedContent
                            ? onOpenToday
                            : showAddContentSheet,
                      ),
                      HomeContentPanel(
                        hasSavedContent: hasSavedContent,
                        contents: contents,
                        categories: categories,
                        bookmarkedIds: bookmarkedIds,
                        onOpenArchive: onOpenArchive,
                        onOpenCategories: onOpenCategories,
                        onOpenContent: onOpenContent,
                        onToggleBookmark: onToggleBookmark,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 113,
                child: FloatingAddButton(onPressed: showAddContentSheet),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: 0,
          onTap: onTab,
        ),
      ),
    );
  }
}

class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.hasSavedContent,
    required this.onSearch,
    required this.onOpenToday,
    super.key,
  });

  final bool hasSavedContent;
  final VoidCallback onSearch;
  final VoidCallback onOpenToday;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 254,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            right: 16,
            top: 8,
            child: Row(
              children: [
                SvgPicture.asset(
                  Assets.logo,
                  width: 72,
                  height: 24,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                SvgIconButton(asset: Assets.search, onPressed: onSearch),
                const SizedBox(width: 16),
                SvgIconButton(
                  asset: Assets.bell,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const NotificationSheet(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            top: 72,
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSavedContent ? '나중에 보려던 것들,' : '저장한 정보가 없어요.',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.6,
                  ),
                ),
                Text(
                  hasSavedContent ? '지금 하나만 꺼내볼까요?' : '지금 하나만 저장할까요?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onOpenToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.text,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasSavedContent ? '오늘의 콘텐츠 보기 →' : '저장 방법 보기 →',
                      style: const TextStyle(
                        color: AppColors.main,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            top: 64,
            child: Image.asset(
              hasSavedContent ? Assets.homeCharacter : Assets.character2Png,
              width: hasSavedContent ? 99 : 81,
              height: 123,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeContentPanel extends StatefulWidget {
  const HomeContentPanel({
    required this.hasSavedContent,
    required this.contents,
    required this.categories,
    required this.bookmarkedIds,
    required this.onOpenArchive,
    required this.onOpenCategories,
    required this.onOpenContent,
    required this.onToggleBookmark,
    super.key,
  });

  final bool hasSavedContent;
  final List<ContentItem> contents;
  final List<CategoryItem> categories;
  final Set<String> bookmarkedIds;
  final VoidCallback onOpenArchive;
  final VoidCallback onOpenCategories;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;

  @override
  State<HomeContentPanel> createState() => _HomeContentPanelState();
}

class _HomeContentPanelState extends State<HomeContentPanel> {
  String _activeCategoryLabel = '전체보기';

  List<ContentItem> get _filteredContents {
    if (_activeCategoryLabel == '전체보기') {
      return widget.contents;
    }
    return widget.contents
        .where((content) => content.category.name == _activeCategoryLabel)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredContents = _filteredContents;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          SectionHeader(title: '최근 저장한 콘텐츠', onTap: widget.onOpenArchive),
          CategoryChips(
            categories: ['전체보기', ...widget.categories.map((item) => item.name)],
            activeLabel: _activeCategoryLabel,
            onSelected: (label) {
              setState(() => _activeCategoryLabel = label);
            },
          ),
          if (widget.hasSavedContent && filteredContents.isNotEmpty) ...[
            SizedBox(
              height: 218,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(38, 16, 38, 10),
                itemBuilder: (context, index) {
                  final item = filteredContents[index];
                  return HomeContentCard(
                    content: item,
                    bookmarked: widget.bookmarkedIds.contains(item.id),
                    onTap: () => widget.onOpenContent(item),
                    onToggleBookmark: () => widget.onToggleBookmark(item),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemCount: filteredContents.take(4).length,
              ),
            ),
            PageDots(count: filteredContents.take(5).length, activeIndex: 0),
          ] else if (widget.hasSavedContent)
            HomeFilteredEmptyContent(
              label: _activeCategoryLabel,
              onReset: () => setState(() => _activeCategoryLabel = '전체보기'),
            )
          else
            const EmptyHomeContent(),
          const SizedBox(height: 22),
          SectionHeader(title: '최근 카테고리', onTap: widget.onOpenArchive),
          const SizedBox(height: 8),
          for (final category in widget.categories.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CategoryHomeRow(
                category: category,
                onTap: widget.onOpenCategories,
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyHomeContent extends StatelessWidget {
  const EmptyHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 211,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(Assets.character2Png, width: 67, height: 78),
          const SizedBox(height: 16),
          const Text(
            '저장한 콘텐츠가 없어요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 260,
            child: Text(
              'SNS에서 발견한 유용한 게시물을 저장하면 이곳에서 다시 확인할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.subtle,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeFilteredEmptyContent extends StatelessWidget {
  const HomeFilteredEmptyContent({
    required this.label,
    required this.onReset,
    super.key,
  });

  final String label;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(Assets.character2Png, width: 58, height: 70),
          const SizedBox(height: 12),
          Text(
            '$label 콘텐츠가 없어요',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onReset, child: const Text('전체보기')),
        ],
      ),
    );
  }
}

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({
    required this.activeTab,
    required this.contents,
    required this.categories,
    required this.bookmarkedIds,
    required this.bookmarkedFirst,
    required this.activeCategoryName,
    required this.onTabChanged,
    required this.onSortChanged,
    required this.onClearCategory,
    required this.onSearch,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.onAddCategory,
    required this.onOpenCategory,
    required this.onTab,
    super.key,
  });

  final int activeTab;
  final List<ContentItem> contents;
  final List<CategoryItem> categories;
  final Set<String> bookmarkedIds;
  final bool bookmarkedFirst;
  final String? activeCategoryName;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<bool> onSortChanged;
  final VoidCallback onClearCategory;
  final VoidCallback onSearch;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final ValueChanged<CategoryItem> onAddCategory;
  final ValueChanged<CategoryItem> onOpenCategory;
  final ValueChanged<AppRoute> onTab;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppTopBar(
                title: '아카이브',
                onBack: () => onTab(AppRoute.home),
                onSearch: onSearch,
              ),
              ArchiveTabs(activeTab: activeTab, onChanged: onTabChanged),
              Expanded(
                child: activeTab == 0
                    ? ContentListView(
                        contents: contents,
                        bookmarkedIds: bookmarkedIds,
                        bookmarkedFirst: bookmarkedFirst,
                        activeCategoryName: activeCategoryName,
                        onSortChanged: onSortChanged,
                        onClearCategory: onClearCategory,
                        onOpenContent: onOpenContent,
                        onToggleBookmark: onToggleBookmark,
                        onGoHome: () => onTab(AppRoute.home),
                      )
                    : CategoryArchiveView(
                        categories: categories,
                        onAddCategory: onAddCategory,
                        onOpenCategory: onOpenCategory,
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: 1,
          onTap: onTab,
        ),
      ),
    );
  }
}

class BookmarkScreen extends StatelessWidget {
  const BookmarkScreen({
    required this.contents,
    required this.bookmarkedIds,
    required this.onSearch,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.onTab,
    super.key,
  });

  final List<ContentItem> contents;
  final Set<String> bookmarkedIds;
  final VoidCallback onSearch;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final ValueChanged<AppRoute> onTab;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppTopBar(
                title: '북마크',
                onBack: () => onTab(AppRoute.home),
                onSearch: onSearch,
              ),
              Expanded(
                child: contents.isEmpty
                    ? EmptyStatePanel(
                        title: '즐겨찾기한 콘텐츠가 없어요',
                        body: '중요한 콘텐츠의 별 아이콘을 누르면 이곳에 모아둘 수 있어요.',
                        actionLabel: '아카이브 보러가기',
                        onAction: () => onTab(AppRoute.archive),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 8),
                        itemBuilder: (context, index) {
                          final content = contents[index];
                          return ContentListCard(
                            content: content,
                            bookmarked: bookmarkedIds.contains(content.id),
                            onToggleBookmark: () => onToggleBookmark(content),
                            onTap: () => onOpenContent(content),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemCount: contents.length,
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: 2,
          onTap: onTab,
        ),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.initialQuery,
    required this.contents,
    required this.bookmarkedIds,
    required this.onQueryChanged,
    required this.onClose,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.onOpenArchive,
    super.key,
  });

  final String initialQuery;
  final List<ContentItem> contents;
  final Set<String> bookmarkedIds;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClose;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final VoidCallback onOpenArchive;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late List<String> _terms;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _terms = List.of(recentSearches);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasQuery => _controller.text.trim().isNotEmpty;

  void _submitQuery(String value) {
    final term = value.trim();
    if (term.isEmpty) return;
    widget.onQueryChanged(term);
    setState(() {
      _terms
        ..remove(term)
        ..insert(0, term);
      if (_terms.length > 5) {
        _terms = _terms.take(5).toList();
      }
    });
  }

  List<ContentItem> get _results {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return const [];
    }
    final normalizedQuery = query.toLowerCase();
    return widget.contents.where((content) {
      final searchableText = [
        content.title,
        content.summary,
        content.category.name,
        content.source,
        content.originalUrl,
        ...content.tags,
      ].join(' ').toLowerCase();
      return searchableText.contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            SvgIcon(
                              asset: Assets.search,
                              size: 16,
                              color: AppColors.subSubtle,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                onChanged: (value) {
                                  widget.onQueryChanged(value);
                                  setState(() {});
                                },
                                onSubmitted: _submitQuery,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: '찾고 싶은 정보를 검색해보세요',
                                  hintStyle: TextStyle(
                                    color: AppColors.subSubtle,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            if (_hasQuery)
                              GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  widget.onQueryChanged('');
                                  setState(() {});
                                },
                                child: const SvgIcon(
                                  asset: Assets.close,
                                  size: 18,
                                  color: AppColors.subSubtle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: TextButton(
                        onPressed: widget.onClose,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF595959),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (!_hasQuery) ...[
                      const Text(
                        '최근 검색어',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final term in _terms)
                        SearchHistoryRow(
                          term: term,
                          onTap: () {
                            _controller.text = term;
                            _submitQuery(term);
                            widget.onQueryChanged(term);
                            setState(() {});
                          },
                          onRemove: () => setState(() => _terms.remove(term)),
                        ),
                    ] else ...[
                      for (final content in _results)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ContentListCard(
                            content: content,
                            bookmarked: widget.bookmarkedIds.contains(
                              content.id,
                            ),
                            onToggleBookmark: () =>
                                widget.onToggleBookmark(content),
                            onTap: () => widget.onOpenContent(content),
                          ),
                        ),
                      if (_results.isEmpty)
                        EmptySearchResult(onOpenArchive: widget.onOpenArchive),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    required this.content,
    required this.contents,
    required this.categories,
    required this.bookmarked,
    required this.onBack,
    required this.onToggleBookmark,
    required this.onChangeCategory,
    required this.onDeleteContent,
    required this.onOpenAdjacent,
    required this.onOpenContent,
    required this.onTab,
    super.key,
  });

  final ContentItem content;
  final List<ContentItem> contents;
  final List<CategoryItem> categories;
  final bool bookmarked;
  final VoidCallback onBack;
  final ValueChanged<ContentItem> onToggleBookmark;
  final void Function(ContentItem content, CategoryItem category)
  onChangeCategory;
  final ValueChanged<ContentItem> onDeleteContent;
  final ValueChanged<int> onOpenAdjacent;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<AppRoute> onTab;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _relatedKey = GlobalKey();

  void _showOriginal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OriginalContentSheet(content: widget.content),
    );
  }

  void _scrollToRelated() {
    final currentContext = _relatedKey.currentContext;
    if (currentContext == null) return;
    Scrollable.ensureVisible(
      currentContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final currentIndex = widget.contents.indexWhere(
      (item) => item.id == content.id,
    );
    final relatedContents = widget.contents
        .where(
          (item) =>
              item.id != content.id &&
              item.category.name == content.category.name,
        )
        .toList();

    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 128),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CategoryBadge(category: content.category),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.title.replaceFirst(' ', '\n'),
                    style: AppText.title24,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      SvgPicture.asset(Assets.instagram, width: 16, height: 16),
                      const SizedBox(width: 4),
                      Text(
                        content.source,
                        style: const TextStyle(
                          color: AppColors.subtle,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '저장일시 | ${content.savedAtFullShort}',
                        style: const TextStyle(
                          color: AppColors.subtle,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    '핵심 요약',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.summary,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.faint),
                  InkWell(
                    onTap: _showOriginal,
                    child: SizedBox(
                      height: 54,
                      child: Row(
                        children: [
                          const Text(
                            '전문 보기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          SvgIcon(asset: Assets.chevronDown),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.faint),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            '태그',
                            style: TextStyle(
                              color: AppColors.middle,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 6,
                            children: content.tags
                                .map((tag) => TagChip(label: '#$tag'))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionHeader(
                    key: _relatedKey,
                    title: '비슷한 정보 보러가기',
                    onTap: _scrollToRelated,
                    horizontalPadding: 0,
                    iconAsset: Assets.arrowRight,
                  ),
                  const SizedBox(height: 9),
                  if (relatedContents.isNotEmpty)
                    for (final related in relatedContents)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RelatedContentTile(
                          category: related.category,
                          title: related.title,
                          onTap: () => widget.onOpenContent(related),
                        ),
                      )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: 18),
                  DetailPager(
                    currentIndex: currentIndex == -1 ? 0 : currentIndex,
                    totalCount: widget.contents.length,
                    onPrevious: () => widget.onOpenAdjacent(-1),
                    onNext: () => widget.onOpenAdjacent(1),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: DetailTopBar(
                  content: content,
                  categories: widget.categories,
                  bookmarked: widget.bookmarked,
                  onBack: widget.onBack,
                  onToggleBookmark: () => widget.onToggleBookmark(content),
                  onChangeCategory: (category) =>
                      widget.onChangeCategory(content, category),
                  onDeleteContent: () => widget.onDeleteContent(content),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: 1,
          onTap: widget.onTab,
        ),
      ),
    );
  }
}

class MyScreen extends StatelessWidget {
  const MyScreen({required this.onTab, super.key});

  final ValueChanged<AppRoute> onTab;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppTopBar(title: '마이', onBack: () => onTab(AppRoute.home)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                  children: [
                    MyProfileRow(
                      user: mockUser,
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const AccountSheet(),
                      ),
                    ),
                    const MySectionHeader(title: '나의 허투루'),
                    MyStatsStrip(user: mockUser),
                    const SizedBox(height: 16),
                    const MySectionHeader(title: '관리'),
                    MyListGroup(
                      children: [
                        MyListTile(
                          title: '리마인드 설정',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const ReminderSheet(),
                          ),
                        ),
                        MyListTile(
                          title: '카테고리 관리',
                          onTap: () => onTab(AppRoute.archive),
                        ),
                        MyListTile(
                          title: '알림 및 앱 권한',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const PermissionSheet(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const MySectionHeader(title: '고객지원'),
                    MyListGroup(
                      children: [
                        MyListTile(
                          title: '공지사항',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const NoticeSheet(),
                          ),
                        ),
                        MyListTile(
                          title: '문의하기',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const ContactSheet(),
                          ),
                        ),
                        MyListTile(
                          title: '알림 및 앱 권한',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const PermissionSheet(),
                          ),
                        ),
                        MyListTile(
                          title: '앱 버전',
                          trailingText: mockUser.appVersion,
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const AppVersionSheet(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: 3,
          onTap: onTab,
        ),
      ),
    );
  }
}

class MyProfileRow extends StatelessWidget {
  const MyProfileRow({required this.user, required this.onTap, super.key});

  final MockUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.main,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(Assets.homeCharacter, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.mainSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Text(
                      'K',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      user.providerLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SvgIcon(
                asset: Assets.chevronRight,
                size: 20,
                color: AppColors.subtler,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MySectionHeader extends StatelessWidget {
  const MySectionHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class MyStatsStrip extends StatelessWidget {
  const MyStatsStrip({required this.user, super.key});

  final MockUser user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: MyMetric(
                label: '저장한 콘텐츠',
                value: user.savedContentCount.toString(),
              ),
            ),
            Container(width: 1, height: 48, color: AppColors.faint),
            Expanded(
              child: MyMetric(
                label: '다시 본 콘텐츠',
                value: user.revisitedContentCount.toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyMetric extends StatelessWidget {
  const MyMetric({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.subtle, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class MyListGroup extends StatelessWidget {
  const MyListGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class MyListTile extends StatelessWidget {
  const MyListTile({
    required this.title,
    required this.onTap,
    this.trailingText,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 41,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: const TextStyle(
                    color: AppColors.subtle,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                const SvgIcon(
                  asset: Assets.chevronRight,
                  size: 16,
                  color: AppColors.subtler,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyStatCard extends StatelessWidget {
  const MyStatCard({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.faint),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.subtle,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class MyMenuTile extends StatelessWidget {
  const MyMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SvgIcon(asset: icon, size: 22, color: AppColors.text),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SvgIcon(asset: Assets.chevronRight, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.activeIndex,
    super.key,
  });

  final String title;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppTopBar(title: title),
              const Expanded(
                child: Center(
                  child: Text('준비 중입니다', style: AppText.body16Subtle),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: activeIndex,
          onTap: (_) => Navigator.maybePop(context),
        ),
      ),
    );
  }
}

class AppTopBar extends StatelessWidget {
  const AppTopBar({required this.title, this.onBack, this.onSearch, super.key});

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            if (onBack == null)
              const SizedBox(width: 44, height: 44)
            else
              SvgIconButton(asset: Assets.back, onPressed: onBack!, size: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (onSearch != null)
              SvgIconButton(
                asset: Assets.search,
                onPressed: onSearch!,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class DetailTopBar extends StatelessWidget {
  const DetailTopBar({
    required this.content,
    required this.categories,
    required this.bookmarked,
    required this.onBack,
    required this.onToggleBookmark,
    required this.onChangeCategory,
    required this.onDeleteContent,
    super.key,
  });

  final ContentItem content;
  final List<CategoryItem> categories;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback onToggleBookmark;
  final ValueChanged<CategoryItem> onChangeCategory;
  final VoidCallback onDeleteContent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          SvgIconButton(asset: Assets.back, onPressed: onBack, size: 24),
          const Spacer(),
          BookmarkActionButton(
            initialActive: bookmarked,
            onToggle: onToggleBookmark,
          ),
          const SizedBox(width: 16),
          SvgIconButton(
            asset: Assets.more,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => ContentActionSheet(
                content: content,
                categories: categories,
                onChangeCategory: onChangeCategory,
                onDelete: onDeleteContent,
              ),
            ),
            size: 24,
          ),
        ],
      ),
    );
  }
}

class BookmarkActionButton extends StatefulWidget {
  const BookmarkActionButton({
    this.initialActive = false,
    this.onToggle,
    this.size = 28,
    super.key,
  });

  final bool initialActive;
  final VoidCallback? onToggle;
  final double size;

  @override
  State<BookmarkActionButton> createState() => _BookmarkActionButtonState();
}

class _BookmarkActionButtonState extends State<BookmarkActionButton> {
  late bool _active;

  @override
  void initState() {
    super.initState();
    _active = widget.initialActive;
  }

  @override
  void didUpdateWidget(covariant BookmarkActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialActive != widget.initialActive) {
      _active = widget.initialActive;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvgIconButton(
      asset: Assets.star,
      onPressed: () {
        widget.onToggle?.call();
        if (widget.onToggle == null) {
          setState(() => _active = !_active);
        }
      },
      size: widget.size,
      color: _active ? AppColors.text : AppColors.subtler,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    required this.onTap,
    this.horizontalPadding = 16,
    this.iconAsset = Assets.chevronRight,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final double horizontalPadding;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              SvgIcon(asset: iconAsset, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    this.activeLabel = '전체보기',
    this.onSelected,
    super.key,
  });

  final List<String> categories;
  final String activeLabel;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final label = categories[index];
            final active = label == activeLabel;
            return SizedBox(
              height: 40,
              child: Material(
                color: active ? AppColors.faint : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onSelected == null ? null : () => onSelected!(label),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 70),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? AppColors.middle : AppColors.subtle,
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 4),
          itemCount: categories.length,
        ),
      ),
    );
  }
}

class ActiveFilterBar extends StatelessWidget {
  const ActiveFilterBar({
    required this.label,
    required this.onClear,
    super.key,
  });

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              color: AppColors.mainSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.mainDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SvgIconButton(
                  asset: Assets.close,
                  onPressed: onClear,
                  size: 14,
                  hitSize: 30,
                  color: AppColors.mainDeep,
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.subtle,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '전체보기',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeContentCard extends StatelessWidget {
  const HomeContentCard({
    required this.content,
    required this.bookmarked,
    required this.onTap,
    required this.onToggleBookmark,
    super.key,
  });

  final ContentItem content;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 298,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 2)],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -8,
              child: BookmarkActionButton(
                key: ValueKey('home-bookmark-${content.title}'),
                initialActive: bookmarked,
                onToggle: onToggleBookmark,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryBadge(category: content.category),
                const SizedBox(height: 8),
                Text(
                  content.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.subtle,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ContentListView extends StatelessWidget {
  const ContentListView({
    required this.contents,
    required this.bookmarkedIds,
    required this.bookmarkedFirst,
    required this.activeCategoryName,
    required this.onSortChanged,
    required this.onClearCategory,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.onGoHome,
    super.key,
  });

  final List<ContentItem> contents;
  final Set<String> bookmarkedIds;
  final bool bookmarkedFirst;
  final String? activeCategoryName;
  final ValueChanged<bool> onSortChanged;
  final VoidCallback onClearCategory;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final visibleContents = contents
        .where(
          (content) =>
              activeCategoryName == null ||
              content.category.name == activeCategoryName,
        )
        .toList();
    if (bookmarkedFirst) {
      visibleContents.sort((a, b) {
        final aMarked = bookmarkedIds.contains(a.id) ? 0 : 1;
        final bMarked = bookmarkedIds.contains(b.id) ? 0 : 1;
        return aMarked.compareTo(bMarked);
      });
    }

    return Column(
      children: [
        ArchiveToolbar(
          countLabel: '총 ${visibleContents.length}개',
          sortLabel: bookmarkedFirst ? '북마크 우선' : '최신순',
          onSortChanged: onSortChanged,
        ),
        if (activeCategoryName != null)
          ActiveFilterBar(label: activeCategoryName!, onClear: onClearCategory),
        Expanded(
          child: visibleContents.isEmpty
              ? EmptyStatePanel(
                  title: activeCategoryName == null
                      ? '저장한 콘텐츠가 없어요'
                      : '$activeCategoryName 콘텐츠가 없어요',
                  body: activeCategoryName == null
                      ? '홈의 + 버튼에서 링크나 스크린샷 목데이터를 추가해 보세요.'
                      : '다른 카테고리를 보거나 필터를 해제해 전체 콘텐츠를 확인해 보세요.',
                  actionLabel: activeCategoryName == null ? '홈으로 가기' : '전체보기',
                  onAction: activeCategoryName == null
                      ? onGoHome
                      : onClearCategory,
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final content = visibleContents[index];
                    return ContentListCard(
                      content: content,
                      bookmarked: bookmarkedIds.contains(content.id),
                      onToggleBookmark: () => onToggleBookmark(content),
                      onTap: () => onOpenContent(content),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: visibleContents.length,
                ),
        ),
      ],
    );
  }
}

class ContentListCard extends StatelessWidget {
  const ContentListCard({
    required this.content,
    required this.onTap,
    required this.onToggleBookmark,
    this.bookmarked = false,
    super.key,
  });

  final ContentItem content;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;
  final bool bookmarked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryBadge(category: content.category),
                  const Spacer(),
                  BookmarkActionButton(
                    key: ValueKey('list-bookmark-${content.title}'),
                    initialActive: bookmarked,
                    onToggle: onToggleBookmark,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.subtle,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content.savedAt,
                style: const TextStyle(
                  color: AppColors.subSubtle,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArchiveTabs extends StatelessWidget {
  const ArchiveTabs({
    required this.activeTab,
    required this.onChanged,
    super.key,
  });

  final int activeTab;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.faint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: ArchiveTabButton(
                label: '전체보기',
                active: activeTab == 0,
                onTap: () => onChanged(0),
              ),
            ),
            Expanded(
              child: ArchiveTabButton(
                label: '카테고리',
                active: activeTab == 1,
                onTap: () => onChanged(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArchiveTabButton extends StatelessWidget {
  const ArchiveTabButton({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppColors.text : AppColors.subtle,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArchiveToolbar extends StatelessWidget {
  const ArchiveToolbar({
    required this.countLabel,
    this.sortLabel = '최신순',
    this.onSortChanged,
    super.key,
  });

  final String countLabel;
  final String sortLabel;
  final ValueChanged<bool>? onSortChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              sortLabel,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => SortSheet(
                  activeBookmarkedFirst: sortLabel == '북마크 우선',
                  onSelect: onSortChanged ?? (_) {},
                ),
              ),
              icon: const SvgIcon(
                asset: Assets.chevronDown,
                size: 16,
                color: AppColors.subtle,
              ),
            ),
            const Spacer(),
            Text(
              countLabel,
              style: const TextStyle(
                color: AppColors.subtle,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryArchiveToolbar extends StatelessWidget {
  const CategoryArchiveToolbar({required this.onAddCategory, super.key});

  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    SortSheet(activeBookmarkedFirst: false, onSelect: (_) {}),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.subtle,
                padding: EdgeInsets.zero,
                minimumSize: const Size(67, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              label: const Text(
                '최신순',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              iconAlignment: IconAlignment.end,
              icon: const SvgIcon(
                asset: Assets.chevronDown,
                size: 16,
                color: AppColors.subtle,
              ),
            ),
            const Spacer(),
            SvgIconButton(
              asset: Assets.folderPlus,
              onPressed: onAddCategory,
              size: 24,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryArchiveView extends StatelessWidget {
  const CategoryArchiveView({
    required this.categories,
    required this.onAddCategory,
    required this.onOpenCategory,
    super.key,
  });

  final List<CategoryItem> categories;
  final ValueChanged<CategoryItem> onAddCategory;
  final ValueChanged<CategoryItem> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CategoryArchiveToolbar(
          onAddCategory: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CategoryCreateSheet(onCreate: onAddCategory),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final category = categories[index];
              return CategoryRow(
                category: category,
                onTap: () => onOpenCategory(category),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemCount: categories.length,
          ),
        ),
      ],
    );
  }
}

class CategoryHomeRow extends StatelessWidget {
  const CategoryHomeRow({
    required this.category,
    required this.onTap,
    super.key,
  });

  final CategoryItem category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              FolderGlyph(color: category.color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '2020. 3. 10. 오후 11:56',
                    style: TextStyle(color: AppColors.subSubtle, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              const SvgIcon(
                asset: Assets.chevronRight,
                size: 18,
                color: AppColors.subtler,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryRow extends StatelessWidget {
  const CategoryRow({required this.category, required this.onTap, super.key});

  final CategoryItem category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 6),
            child: Row(
              children: [
                FolderGlyph(color: category.color),
                const SizedBox(width: 12),
                SizedBox(
                  width: 156,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '2020. 3. 10. 오후 11:56',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.subSubtle,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.faint,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SvgIcon(
                          asset: Assets.moreHorizontal,
                          size: 19.2,
                          color: AppColors.middle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryCreateSheet extends StatefulWidget {
  const CategoryCreateSheet({required this.onCreate, super.key});

  final ValueChanged<CategoryItem> onCreate;

  @override
  State<CategoryCreateSheet> createState() => _CategoryCreateSheetState();
}

class _CategoryCreateSheetState extends State<CategoryCreateSheet> {
  final _controller = TextEditingController();
  Color _selectedColor = FolderColorPicker.colors.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    widget.onCreate(
      CategoryItem(
        name: name,
        color: _selectedColor,
        tint: _selectedColor.withValues(alpha: 0.22),
        deep: _selectedColor,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '카테고리 만들기',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  hintText: '카테고리 이름',
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              FolderColorPicker(
                selectedColor: _selectedColor,
                onChanged: (color) => setState(() => _selectedColor = color),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: '저장하기', onPressed: _save, height: 52),
            ],
          ),
        ),
      ),
    );
  }
}

class AddContentSheet extends StatelessWidget {
  const AddContentSheet({
    required this.categories,
    required this.onAddLink,
    required this.onAddScreenshot,
    super.key,
  });

  final List<CategoryItem> categories;
  final void Function({required String url, required CategoryItem category})
  onAddLink;
  final VoidCallback onAddScreenshot;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '콘텐츠 추가',
      children: [
        SheetActionTile(
          icon: Assets.plus,
          title: '링크 추가',
          description: 'SNS나 웹에서 발견한 링크를 저장해요.',
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                LinkAddSheet(categories: categories, onSave: onAddLink),
          ),
        ),
        SheetActionTile(
          icon: Assets.archive,
          title: '스크린샷 첨부',
          description: '이미지로 저장한 정보를 허투루에 모아요.',
          onTap: () {
            onAddScreenshot();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class LinkAddSheet extends StatefulWidget {
  const LinkAddSheet({
    required this.categories,
    required this.onSave,
    super.key,
  });

  final List<CategoryItem> categories;
  final void Function({required String url, required CategoryItem category})
  onSave;

  @override
  State<LinkAddSheet> createState() => _LinkAddSheetState();
}

class _LinkAddSheetState extends State<LinkAddSheet> {
  final _controller = TextEditingController(
    text: 'https://www.instagram.com/p/hutureu-mock',
  );
  late CategoryItem _category;

  @override
  void initState() {
    super.initState();
    _category = widget.categories.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    widget.onSave(url: url, category: _category);
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '링크 추가',
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'https://',
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        CategorySelectField(
          categories: widget.categories,
          selected: _category,
          onChanged: (category) => setState(() => _category = category),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '미리보기: 링크 제목, 핵심 요약, 자동 추천 카테고리를 확인한 뒤 저장하는 목데이터 흐름입니다.',
            style: TextStyle(color: AppColors.subtle, fontSize: 14),
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: '저장하기', onPressed: _save, height: 52),
      ],
    );
  }
}

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '알림',
      children: const [
        NotificationRow(title: '오늘의 콘텐츠가 준비됐어요', time: '방금 전'),
        NotificationRow(title: '저장한 링크 요약이 완료됐어요', time: '10분 전'),
        NotificationRow(title: '다시 볼 콘텐츠를 추천해드려요', time: '어제'),
      ],
    );
  }
}

class SortSheet extends StatelessWidget {
  const SortSheet({
    required this.activeBookmarkedFirst,
    required this.onSelect,
    super.key,
  });

  final bool activeBookmarkedFirst;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '정렬',
      children: [
        SheetActionTile(
          icon: Assets.chevronDown,
          title: '최신순',
          description: activeBookmarkedFirst
              ? '최근 저장한 콘텐츠부터 다시 보여줘요.'
              : '현재 적용 중인 정렬입니다.',
          onTap: () {
            onSelect(false);
            Navigator.pop(context);
          },
        ),
        SheetActionTile(
          icon: Assets.star,
          title: '북마크 우선',
          description: activeBookmarkedFirst
              ? '현재 적용 중인 정렬입니다.'
              : '중요 표시한 정보를 먼저 보여줘요.',
          onTap: () {
            onSelect(true);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class ContentActionSheet extends StatelessWidget {
  const ContentActionSheet({
    required this.content,
    required this.categories,
    required this.onChangeCategory,
    required this.onDelete,
    super.key,
  });

  final ContentItem content;
  final List<CategoryItem> categories;
  final ValueChanged<CategoryItem> onChangeCategory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '콘텐츠 관리',
      children: [
        SheetActionTile(
          icon: Assets.archive,
          title: '카테고리 변경',
          description: '이 콘텐츠를 다른 카테고리로 옮겨요.',
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => CategoryChangeSheet(
                current: content.category,
                categories: categories,
                onChange: onChangeCategory,
              ),
            );
          },
        ),
        SheetActionTile(
          icon: Assets.close,
          title: '삭제',
          description: '저장한 콘텐츠 목록에서 제거해요.',
          onTap: () {
            onDelete();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class OriginalContentSheet extends StatelessWidget {
  const OriginalContentSheet({required this.content, super.key});

  final ContentItem content;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '원문 보기',
      children: [
        Row(
          children: [
            SvgPicture.asset(Assets.instagram, width: 18, height: 18),
            const SizedBox(width: 6),
            Text(
              content.source,
              style: const TextStyle(color: AppColors.subtle, fontSize: 14),
            ),
            const Spacer(),
            Text(
              content.savedAtFullShort,
              style: const TextStyle(color: AppColors.subtle, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Text(
              content.originalText.isEmpty
                  ? content.summary
                  : content.originalText,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
        ),
        if (content.originalUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          SheetInfoRow(label: '원본 링크', value: content.originalUrl),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: '확인',
          onPressed: () => Navigator.pop(context),
          height: 52,
        ),
      ],
    );
  }
}

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '계정 관리',
      children: [
        SheetInfoRow(label: '이름', value: mockUser.name),
        SheetInfoRow(label: '연동 계정', value: mockUser.providerLabel),
        SheetInfoRow(label: '가입일', value: mockUser.joinedAt),
        const SizedBox(height: 12),
        PrimaryButton(
          label: '확인',
          onPressed: () => Navigator.pop(context),
          height: 48,
        ),
      ],
    );
  }
}

class ReminderSheet extends StatelessWidget {
  const ReminderSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '리마인드 설정',
      children: [
        for (final item in mockReminderSettings)
          SheetInfoRow(label: item.label, value: item.value),
      ],
    );
  }
}

class PermissionSheet extends StatelessWidget {
  const PermissionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '알림 및 앱 권한',
      children: [
        for (final item in mockPermissionSettings)
          SheetInfoRow(label: item.label, value: item.value),
      ],
    );
  }
}

class NoticeSheet extends StatelessWidget {
  const NoticeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '공지사항',
      children: [
        for (final notice in mockNotices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              notice,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class ContactSheet extends StatelessWidget {
  const ContactSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '문의하기',
      children: const [
        Text(
          '문의는 help@hutureu.app 으로 보내주세요. 목데이터 기준 응답 시간은 평일 24시간 이내입니다.',
          style: TextStyle(color: AppColors.subtle, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }
}

class AppVersionSheet extends StatelessWidget {
  const AppVersionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '앱 버전',
      children: const [
        SheetInfoRow(label: '현재 버전', value: 'ver. 1.1'),
        SheetInfoRow(label: '업데이트', value: '최신 버전입니다'),
      ],
    );
  }
}

class SheetInfoRow extends StatelessWidget {
  const SheetInfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.subtle, fontSize: 14),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class AppSheet extends StatelessWidget {
  const AppSheet({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class SheetActionTile extends StatelessWidget {
  const SheetActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final String icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: SvgIcon(asset: icon, size: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.subtle,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SvgIcon(asset: Assets.chevronRight, size: 20),
          ],
        ),
      ),
    );
  }
}

class NotificationRow extends StatelessWidget {
  const NotificationRow({required this.title, required this.time, super.key});

  final String title;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.main,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: AppColors.subtle, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class CategorySelectField extends StatelessWidget {
  const CategorySelectField({
    required this.categories,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<CategoryItem> categories;
  final CategoryItem selected;
  final ValueChanged<CategoryItem> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories)
          ChoiceChip(
            label: Text(category.name),
            selected: category.name == selected.name,
            onSelected: (_) => onChanged(category),
            selectedColor: category.tint,
            backgroundColor: AppColors.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: category.name == selected.name
                    ? category.deep
                    : AppColors.faint,
              ),
            ),
            labelStyle: TextStyle(
              color: category.name == selected.name
                  ? category.deep
                  : AppColors.subtle,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class CategoryChangeSheet extends StatelessWidget {
  const CategoryChangeSheet({
    required this.current,
    required this.categories,
    required this.onChange,
    super.key,
  });

  final CategoryItem current;
  final List<CategoryItem> categories;
  final ValueChanged<CategoryItem> onChange;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '카테고리 변경',
      children: [
        for (final category in categories)
          SheetActionTile(
            icon: Assets.archive,
            title: category.name,
            description: category.name == current.name
                ? '현재 선택된 카테고리입니다.'
                : '이 카테고리로 콘텐츠를 이동해요.',
            onTap: () {
              onChange(category);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}

class FolderColorPicker extends StatelessWidget {
  const FolderColorPicker({
    required this.selectedColor,
    required this.onChanged,
    super.key,
  });

  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  static const colors = [
    Color(0xFFB48CFF),
    Color(0xFFFF5F78),
    Color(0xFF64B5F6),
    Color(0xFF5BD89D),
    Color(0xFFFFD75C),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final color in colors)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onChanged(color),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: color == selectedColor
                      ? Border.all(color: AppColors.text, width: 2)
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ClipbackNavigationBar extends StatelessWidget {
  const ClipbackNavigationBar({
    required this.activeIndex,
    required this.onTap,
    super.key,
  });

  final int activeIndex;
  final ValueChanged<AppRoute> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      NavSpec(Assets.home, '홈', AppRoute.home),
      NavSpec(Assets.archive, '아카이브', AppRoute.archive),
      NavSpec(Assets.star, '즐겨찾기', AppRoute.bookmark),
      NavSpec(Assets.account, '마이', AppRoute.my),
    ];

    return Container(
      height: 97,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 16)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < items.length; index++)
                    SizedBox(
                      width: 80,
                      child: _NavItem(
                        spec: items[index],
                        active: activeIndex == index,
                        onTap: () => onTap(items[index].route),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  final NavSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 56,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SvgIcon(
              asset: spec.asset,
              size: spec.label == '마이' ? 24 : 28,
              color: active ? AppColors.text : AppColors.subtler,
            ),
            const SizedBox(height: 3),
            Text(
              spec.label,
              style: TextStyle(
                color: active ? AppColors.text : AppColors.subtler,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavSpec {
  const NavSpec(this.asset, this.label, this.route);

  final String asset;
  final String label;
  final AppRoute route;
}

class DetailPager extends StatelessWidget {
  const DetailPager({
    required this.currentIndex,
    required this.totalCount,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final int currentIndex;
  final int totalCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundIconButton(asset: Assets.back, onPressed: onPrevious),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Text(
              '${currentIndex + 1} / $totalCount',
              style: const TextStyle(
                color: AppColors.subtle,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          RoundIconButton(asset: Assets.arrowRight, onPressed: onNext),
        ],
      ),
    );
  }
}

class RelatedContentTile extends StatelessWidget {
  const RelatedContentTile({
    required this.category,
    required this.title,
    this.onTap,
    super.key,
  });

  final CategoryItem category;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CategoryBadge(category: category),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchHistoryRow extends StatelessWidget {
  const SearchHistoryRow({
    required this.term,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SvgIcon(asset: Assets.clock, size: 18, color: AppColors.subtle),
            const SizedBox(width: 10),
            Text(
              term,
              style: const TextStyle(
                color: AppColors.subtle,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onRemove,
              child: const SvgIcon(
                asset: Assets.close,
                size: 18,
                color: AppColors.subtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptySearchResult extends StatelessWidget {
  const EmptySearchResult({required this.onOpenArchive, super.key});

  final VoidCallback onOpenArchive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          Image.asset(Assets.character2Png, width: 64, height: 80),
          const SizedBox(height: 16),
          const Text(
            '검색 결과가 없어요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '핵심 키워드 위주로 검색해 주세요',
            style: TextStyle(color: AppColors.subtle, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 35,
            child: OutlinedButton.icon(
              onPressed: onOpenArchive,
              icon: const SvgIcon(asset: Assets.archive, size: 18),
              label: const Text('전체 리스트 보기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.faint),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStatePanel extends StatelessWidget {
  const EmptyStatePanel({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(Assets.character2Png, width: 64, height: 80),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.subtle,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.faint),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({required this.category, super.key});

  final CategoryItem category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: category.tint,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.name,
        style: TextStyle(
          color: category.deep,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.mainSubtle,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.mainDeep,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.color = AppColors.text,
    this.foreground = AppColors.main,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    required this.label,
    required this.color,
    required this.foreground,
    required this.mark,
    required this.onPressed,
    this.borderColor,
    super.key,
  });

  final String label;
  final Color color;
  final Color foreground;
  final String mark;
  final VoidCallback onPressed;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor!, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 18,
                  child: Text(
                    mark,
                    style: TextStyle(
                      color: foreground == Colors.white
                          ? Colors.white
                          : AppColors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingAddButton extends StatelessWidget {
  const FloatingAddButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.text,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: SvgPicture.asset(
          Assets.plus,
          colorFilter: const ColorFilter.mode(AppColors.main, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.asset,
    required this.onPressed,
    this.rotate = false,
    super.key,
  });

  final String asset;
  final VoidCallback onPressed;
  final bool rotate;

  @override
  Widget build(BuildContext context) {
    final icon = SvgIcon(asset: asset, size: 32);
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: rotate ? Transform.rotate(angle: 3.14159, child: icon) : icon,
        ),
      ),
    );
  }
}

class SvgIconButton extends StatelessWidget {
  const SvgIconButton({
    required this.asset,
    required this.onPressed,
    this.size = 24,
    this.hitSize = 44,
    this.color = AppColors.text,
    super.key,
  });

  final String asset;
  final VoidCallback onPressed;
  final double size;
  final double hitSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: hitSize,
      height: hitSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tight(Size(hitSize, hitSize)),
        onPressed: onPressed,
        icon: SvgIcon(asset: asset, size: size, color: color),
      ),
    );
  }
}

class SvgIcon extends StatelessWidget {
  const SvgIcon({
    required this.asset,
    this.size = 24,
    this.color = AppColors.text,
    super.key,
  });

  final String asset;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class FolderGlyph extends StatelessWidget {
  const FolderGlyph({required this.color, this.size = 40, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.folder_rounded, color: color, size: size);
  }
}

class PageDots extends StatelessWidget {
  const PageDots({required this.count, required this.activeIndex, super.key});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: activeIndex == index ? 13.3 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: activeIndex == index ? AppColors.text : AppColors.subtler,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

class AppText {
  static const title24 = TextStyle(
    color: AppColors.text,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.5,
  );
  static const body16Subtle = TextStyle(
    color: AppColors.subtle,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );
}

class OnboardingData {
  const OnboardingData({
    required this.title,
    required this.body,
    required this.asset,
  });

  final String title;
  final String body;
  final String asset;
}

class ContentItem {
  const ContentItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.savedAt,
    required this.savedAtFull,
    required this.savedAtFullShort,
    required this.tags,
    required this.source,
    required this.originalUrl,
    required this.originalText,
    this.bookmarked = false,
    this.isScreenshot = false,
  });

  final String id;
  final String title;
  final String summary;
  final CategoryItem category;
  final String savedAt;
  final String savedAtFull;
  final String savedAtFullShort;
  final List<String> tags;
  final String source;
  final String originalUrl;
  final String originalText;
  final bool bookmarked;
  final bool isScreenshot;

  ContentItem copyWith({CategoryItem? category, bool? bookmarked}) {
    return ContentItem(
      id: id,
      title: title,
      summary: summary,
      category: category ?? this.category,
      savedAt: savedAt,
      savedAtFull: savedAtFull,
      savedAtFullShort: savedAtFullShort,
      tags: tags,
      source: source,
      originalUrl: originalUrl,
      originalText: originalText,
      bookmarked: bookmarked ?? this.bookmarked,
      isScreenshot: isScreenshot,
    );
  }
}

class MockUser {
  const MockUser({
    required this.name,
    required this.providerLabel,
    required this.joinedAt,
    required this.savedContentCount,
    required this.revisitedContentCount,
    required this.appVersion,
  });

  final String name;
  final String providerLabel;
  final String joinedAt;
  final int savedContentCount;
  final int revisitedContentCount;
  final String appVersion;
}

class MockSettingItem {
  const MockSettingItem({required this.label, required this.value});

  final String label;
  final String value;
}

const mockUser = MockUser(
  name: '정지윤',
  providerLabel: '카카오 계정 연동 중',
  joinedAt: '2026. 03. 07',
  savedContentCount: 218,
  revisitedContentCount: 72,
  appVersion: 'ver. 1.1',
);

const mockInterestOptions = [
  '직장/자기개발',
  '뷰티/패션',
  '여행/장소',
  '인문/지식',
  '요리/식품',
  '경제/시사',
];

const mockReminderSettings = [
  MockSettingItem(label: '오늘의 리마인드', value: '오후 8:00'),
  MockSettingItem(label: '반복', value: '매일'),
  MockSettingItem(label: '추천 콘텐츠', value: '켜짐'),
];

const mockPermissionSettings = [
  MockSettingItem(label: '푸시 알림', value: '허용'),
  MockSettingItem(label: '갤러리 접근', value: '선택한 사진만'),
  MockSettingItem(label: '클립보드 감지', value: '켜짐'),
];

const mockNotices = [
  '허투루 베타 앱에 오신 것을 환영합니다.',
  '저장한 링크 요약 품질이 개선되었습니다.',
  '관심사 기반 리마인드 추천이 추가되었습니다.',
];

class CategoryItem {
  const CategoryItem({
    required this.name,
    required this.color,
    required this.tint,
    required this.deep,
  });

  final String name;
  final Color color;
  final Color tint;
  final Color deep;
}

const catProduct = CategoryItem(
  name: '제품추천',
  color: Color(0xFFB48CFF),
  tint: Color(0xFFDDCEFF),
  deep: Color(0xFF6145A2),
);
const catJapan = CategoryItem(
  name: '일본여행',
  color: Color(0xFFFF5F78),
  tint: Color(0xFFFFE0E4),
  deep: Color(0xFFBC4858),
);
const catSelfGrowth = CategoryItem(
  name: '자기개발',
  color: Color(0xFF64B5F6),
  tint: Color(0xFFE2F1FF),
  deep: Color(0xFF4676A4),
);
const catLife = CategoryItem(
  name: '생활',
  color: Color(0xFF5BD89D),
  tint: Color(0x80C1F1DE),
  deep: Color(0xFF45A27D),
);
const catLifeInfo = CategoryItem(
  name: '생활정보',
  color: Color(0xFFFFA9BD),
  tint: Color(0xFFFFE0E4),
  deep: Color(0xFFBC4858),
);
const catDiet = CategoryItem(
  name: '다이어트',
  color: Color(0xFFFFD75C),
  tint: Color(0xFFFFF0BA),
  deep: Color(0xFF856B00),
);
const catJob = CategoryItem(
  name: '취업준비',
  color: Color(0xFF64B5F6),
  tint: Color(0xFFE2F1FF),
  deep: Color(0xFF4676A4),
);
const catBeauty = CategoryItem(
  name: '뷰티/패션',
  color: Color(0xFFFF8CB4),
  tint: Color(0xFFFFE4EE),
  deep: Color(0xFFB84B72),
);
const catKnowledge = CategoryItem(
  name: '인문/지식',
  color: Color(0xFF8C7BFF),
  tint: Color(0xFFE7E3FF),
  deep: Color(0xFF5144A6),
);
const catEconomy = CategoryItem(
  name: '경제/시사',
  color: Color(0xFF4DB6AC),
  tint: Color(0xFFDDF4F1),
  deep: Color(0xFF2E817A),
);
const catUncategorized = CategoryItem(
  name: '미분류',
  color: Color(0xFFB5BDC3),
  tint: Color(0xFFE9ECEF),
  deep: Color(0xFF626C73),
);

const initialCategories = [
  catJob,
  catBeauty,
  catJapan,
  catKnowledge,
  catSelfGrowth,
  catEconomy,
  catLife,
  catLifeInfo,
  catDiet,
  catProduct,
  catUncategorized,
];

const initialContents = [
  ContentItem(
    id: 'bathroom-cleaning',
    title: '화장실 냄새 잡는 법',
    summary:
        '화장실 냄새 잡는 방법은 그렇게 어렵지 않습니다. 쿠팡에서 추천하는 아이템 3가지만 확실하게 구매하시면 걱정 없이 화장실 냄새 잡을 수 있습니다.',
    category: catLife,
    savedAt: '26.03.07',
    savedAtFull: '2026. 03. 07 오후 02:11',
    savedAtFullShort: '2026. 03. 07 02:11',
    tags: ['생활', '청소', '추천템'],
    source: 'Instagram',
    originalUrl: 'https://www.instagram.com/p/bathroom-cleaning',
    originalText:
        '화장실 냄새를 빠르게 줄이는 청소 루틴과 추천 제품을 소개하는 게시물입니다. 배수구, 환기, 탈취 제품 순서로 정리되어 있습니다.',
  ),
  ContentItem(
    id: 'job-cover-letter',
    title: '자소서 합격률 UP 이건 무조건! 적용해야 합니다',
    summary:
        '자기소개서를 현실적으로 끝까지 다 읽기는 어렵습니다. 요약 없이 문장이 길게 나열되어 있으면, 읽는 입장에서는 숨부터 막히기 시작하죠.',
    category: catJob,
    savedAt: '26.06.11',
    savedAtFull: '2026. 06. 11 오전 09:53',
    savedAtFullShort: '2026. 06. 11. 09:53',
    tags: ['취준', '이력서', '자기소개서'],
    source: 'Instagram',
    originalUrl: 'https://www.instagram.com/reel/job-cover-letter',
    originalText: '자기소개서 첫 문장, 성과 수치화, 직무 연결성을 중심으로 합격률을 높이는 작성 팁을 정리한 릴스입니다.',
    bookmarked: true,
  ),
  ContentItem(
    id: 'japan-snack',
    title: '일본 편의점에서 꼭 사야 하는 간식',
    summary: '도쿄 여행 중 편의점에서 고르기 좋은 간식과 음료를 정리했습니다.',
    category: catJapan,
    savedAt: '26.03.07',
    savedAtFull: '2026. 03. 07 오후 08:10',
    savedAtFullShort: '2026. 03. 07 08:10',
    tags: ['일본여행', '간식', '편의점'],
    source: 'Instagram',
    originalUrl: 'https://www.instagram.com/p/japan-snack',
    originalText: '세븐일레븐, 로손, 패밀리마트에서 구매하기 좋은 간식 리스트와 가격대를 소개하는 여행 저장용 게시물입니다.',
    bookmarked: true,
  ),
  ContentItem(
    id: 'desk-products',
    title: '책상 위를 정리해주는 제품 추천',
    summary: '좁은 책상에서도 케이블과 작은 물건을 깔끔하게 보관할 수 있는 제품 모음입니다.',
    category: catProduct,
    savedAt: '26.03.07',
    savedAtFull: '2026. 03. 07 오후 09:30',
    savedAtFullShort: '2026. 03. 07 09:30',
    tags: ['제품추천', '정리', '업무'],
    source: 'Instagram',
    originalUrl: 'https://www.instagram.com/p/desk-products',
    originalText: '케이블 홀더, 미니 수납함, 모니터 받침대 등 책상 정리에 도움이 되는 제품 추천 목록입니다.',
    bookmarked: true,
  ),
  ContentItem(
    id: 'summer-fashion',
    title: '여름 출근룩 쇼핑몰 모음',
    summary: '얇은 셔츠, 와이드 팬츠, 가벼운 재킷처럼 출근길에 입기 좋은 여름 패션 아이템을 모았습니다.',
    category: catProduct,
    savedAt: '26.07.02',
    savedAtFull: '2026. 07. 02 오후 05:42',
    savedAtFullShort: '2026. 07. 02 17:42',
    tags: ['여름쇼핑몰', '패션', '출근룩'],
    source: 'Web',
    originalUrl: 'https://hutureu.example/summer-fashion',
    originalText: '여름 출근룩을 찾는 사용자를 위한 쇼핑몰 링크 모음과 소재별 추천 포인트입니다.',
  ),
  ContentItem(
    id: 'busan-food',
    title: '부산 1박 2일 맛집 루트',
    summary: '해운대, 전포, 광안리 동선을 기준으로 웨이팅이 적은 맛집과 카페를 묶어둔 여행 루트입니다.',
    category: catJapan,
    savedAt: '26.07.10',
    savedAtFull: '2026. 07. 10 오전 11:20',
    savedAtFullShort: '2026. 07. 10 11:20',
    tags: ['부산맛집', '여행', '해운대놀거리'],
    source: 'Web',
    originalUrl: 'https://hutureu.example/busan-food',
    originalText: '부산 여행 중 저장해두기 좋은 맛집과 이동 순서를 정리한 목데이터입니다.',
  ),
  ContentItem(
    id: 'diet-breakfast-screenshot',
    title: '다이어트 아침 식단 캡처',
    summary: '스크린샷에서 추출한 식단 메모입니다. 단백질, 탄수화물, 준비 시간을 한눈에 볼 수 있게 요약했습니다.',
    category: catDiet,
    savedAt: '26.07.15',
    savedAtFull: '2026. 07. 15 오전 08:12',
    savedAtFullShort: '2026. 07. 15 08:12',
    tags: ['스크린샷', '다이어트', 'OCR'],
    source: '스크린샷',
    originalUrl: '',
    originalText: '닭가슴살 100g, 현미밥 반 공기, 방울토마토 6개. 아침 준비 시간 12분.',
    isScreenshot: true,
  ),
  ContentItem(
    id: 'olive-young-sale',
    title: '올영세일 때 담아둘 스킨케어 리스트',
    summary: '민감성 피부 기준으로 세럼, 선크림, 클렌징 제품을 나눠 저장해둔 쇼핑 체크리스트입니다.',
    category: catBeauty,
    savedAt: '26.07.18',
    savedAtFull: '2026. 07. 18 오후 03:28',
    savedAtFullShort: '2026. 07. 18 15:28',
    tags: ['올영세일', '스킨케어', '뷰티'],
    source: 'Instagram',
    originalUrl: 'https://www.instagram.com/p/olive-young-sale',
    originalText: '올영세일 기간에 가격이 내려가는 스킨케어 제품과 민감성 피부 사용 후기를 묶어둔 게시물입니다.',
    bookmarked: true,
  ),
  ContentItem(
    id: 'book-quotes-note',
    title: '집중이 안 될 때 다시 읽을 문장',
    summary: '책에서 캡처한 문장을 OCR로 저장했습니다. 해야 할 일을 잘게 나누고 시작하는 데 도움이 되는 구절입니다.',
    category: catKnowledge,
    savedAt: '26.07.19',
    savedAtFull: '2026. 07. 19 오후 10:04',
    savedAtFullShort: '2026. 07. 19 22:04',
    tags: ['인문', '독서', '스크린샷'],
    source: '스크린샷',
    originalUrl: '',
    originalText: '큰 결심보다 작은 시작이 오래간다. 오늘의 일을 한 문장으로 줄이고, 그 문장의 첫 단어부터 실행하라.',
    bookmarked: true,
    isScreenshot: true,
  ),
  ContentItem(
    id: 'interest-rate-news',
    title: '기준금리 동결 기사 핵심만 저장',
    summary: '금리 동결 배경, 물가 전망, 대출 금리 영향만 빠르게 다시 보려고 정리한 경제 기사 요약입니다.',
    category: catEconomy,
    savedAt: '26.07.20',
    savedAtFull: '2026. 07. 20 오전 07:35',
    savedAtFullShort: '2026. 07. 20 07:35',
    tags: ['경제', '금리', '뉴스'],
    source: 'News',
    originalUrl: 'https://news.example/hutureu-interest-rate',
    originalText: '한국은행이 기준금리를 동결했다는 기사입니다. 소비자물가 흐름과 가계대출 증가세를 함께 언급합니다.',
  ),
  ContentItem(
    id: 'morning-routine',
    title: '출근 전 20분 루틴',
    summary:
        '아침에 바로 움직이기 어려울 때 쓰는 준비 루틴입니다. 물 마시기, 가방 체크, 오늘 일정 확인 순서로 정리했습니다.',
    category: catLifeInfo,
    savedAt: '26.07.20',
    savedAtFull: '2026. 07. 20 오전 08:10',
    savedAtFullShort: '2026. 07. 20 08:10',
    tags: ['생활정보', '루틴', '출근'],
    source: 'Web',
    originalUrl: 'https://hutureu.example/morning-routine',
    originalText: '출근 전 20분 동안 최소한으로 챙기면 좋은 루틴과 체크리스트를 설명하는 글입니다.',
  ),
  ContentItem(
    id: 'portfolio-checklist',
    title: '포트폴리오 제출 전 체크리스트',
    summary: '프로젝트 설명, 맡은 역할, 성과 수치, 회고 문장을 제출 전 한 번 더 확인하기 위한 체크리스트입니다.',
    category: catJob,
    savedAt: '26.07.21',
    savedAtFull: '2026. 07. 21 오후 01:18',
    savedAtFullShort: '2026. 07. 21 13:18',
    tags: ['취업준비', '포트폴리오', '체크리스트'],
    source: 'Web',
    originalUrl: 'https://hutureu.example/portfolio-checklist',
    originalText:
        '포트폴리오 제출 전에 프로젝트별 문제, 해결 방식, 결과, 배운 점을 빠뜨리지 않았는지 점검하는 목록입니다.',
    bookmarked: true,
  ),
  ContentItem(
    id: 'tokyo-station-locker',
    title: '도쿄역 코인락커 위치 메모',
    summary: '여행 당일 짐 보관을 위해 도쿄역 코인락커 위치와 결제 방법, 혼잡 시간대를 저장했습니다.',
    category: catJapan,
    savedAt: '26.07.21',
    savedAtFull: '2026. 07. 21 오후 07:42',
    savedAtFullShort: '2026. 07. 21 19:42',
    tags: ['일본여행', '도쿄역', '짐보관'],
    source: 'Instagram',
    originalUrl: 'https://www.instagram.com/p/tokyo-station-locker',
    originalText: '도쿄역 주변 코인락커 구역별 위치와 교통카드 결제 가능 여부를 정리한 여행 팁입니다.',
  ),
  ContentItem(
    id: 'airfryer-sweet-potato',
    title: '에어프라이어 고구마 시간표',
    summary: '고구마 크기별 에어프라이어 온도와 시간을 저장한 스크린샷입니다. 실패한 조리 시간도 함께 메모했습니다.',
    category: catLife,
    savedAt: '26.07.22',
    savedAtFull: '2026. 07. 22 오후 09:12',
    savedAtFullShort: '2026. 07. 22 21:12',
    tags: ['요리', '고구마', '스크린샷'],
    source: '스크린샷',
    originalUrl: '',
    originalText:
        '작은 고구마 180도 25분, 중간 고구마 180도 35분, 큰 고구마 170도 45분. 중간에 한 번 뒤집기.',
    isScreenshot: true,
  ),
  ContentItem(
    id: 'ai-prompt-writing',
    title: 'AI로 글 초안 잡는 프롬프트',
    summary: '블로그 글이나 자기소개서 초안을 만들 때 맥락, 독자, 톤, 분량을 함께 넣는 프롬프트 예시입니다.',
    category: catSelfGrowth,
    savedAt: '26.07.22',
    savedAtFull: '2026. 07. 22 오후 11:03',
    savedAtFullShort: '2026. 07. 22 23:03',
    tags: ['자기개발', 'AI', '프롬프트'],
    source: 'Web',
    originalUrl: 'https://hutureu.example/ai-prompt-writing',
    originalText:
        '좋은 초안을 얻기 위해 목적, 독자, 반드시 포함할 정보, 피해야 할 표현을 함께 전달하는 프롬프트 템플릿입니다.',
    bookmarked: true,
  ),
  ContentItem(
    id: 'unknown-link-fallback',
    title: '제목을 추출하지 못한 링크',
    summary:
        '외부 사이트 응답이 제한되어 기본 요약으로 저장된 목데이터입니다. 기획서의 미분류 fallback 상태를 확인할 수 있습니다.',
    category: catUncategorized,
    savedAt: '26.07.23',
    savedAtFull: '2026. 07. 23 오전 12:20',
    savedAtFullShort: '2026. 07. 23 00:20',
    tags: ['미분류', 'fallback', '링크저장'],
    source: 'Web',
    originalUrl: 'https://blocked.example/private-post',
    originalText: '메타데이터 추출에 실패한 링크입니다. 저장 자체는 완료되고, 추후 사용자가 카테고리를 변경할 수 있습니다.',
  ),
];

const recentSearches = ['올영세일', '여름 쇼핑몰', '부산 맛집', '금리', '도쿄역'];
