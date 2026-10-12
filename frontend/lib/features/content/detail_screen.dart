import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/content/content_actions.dart';
import 'package:clipback_frontend/shared/content/feed_status.dart';
import 'package:clipback_frontend/shared/content/mutation_status.dart';
import 'package:clipback_frontend/shared/content/tag_chip.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/sheet_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    required this.onReadAsset,
    this.feed,
    this.moving = false,
    this.onRetry,
    required this.content,
    required this.contents,
    required this.categories,
    required this.bookmarked,
    required this.onBack,
    required this.onToggleBookmark,
    required this.onChangeCategory,
    required this.onDeleteContent,
    required this.onOpenOriginalLink,
    required this.onOpenAdjacent,
    required this.onOpenContent,
    required this.onAddLink,
    required this.onAddScreenshot,
    required this.onTab,
    super.key,
  });

  final ContentItem content;
  final Future<Uint8List> Function(int) onReadAsset;
  final FeedPage? feed;
  final bool moving;
  final VoidCallback? onRetry;
  final List<ContentItem> contents;
  final List<CategoryItem> categories;
  final bool bookmarked;
  final VoidCallback onBack;
  final ValueChanged<ContentItem> onToggleBookmark;
  final void Function(ContentItem content, CategoryItem category)
  onChangeCategory;
  final ValueChanged<ContentItem> onDeleteContent;
  final VoidCallback onOpenOriginalLink;
  final ValueChanged<int> onOpenAdjacent;
  final ValueChanged<ContentItem> onOpenContent;
  final SaveLinkCallback onAddLink;
  final SaveScreenshotCallback onAddScreenshot;
  final ValueChanged<AppRoute> onTab;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _relatedKey = GlobalKey();
  bool _showFullText = false;
  late _ScreenshotAssetController _originalImage;
  Route<void>? _originalSheetRoute;
  bool _showingOriginalSheet = false;
  int _originalSheetVersion = 0;

  int? get _assetId => widget.content.isScreenshot
      ? widget.content.assets
            .where((asset) => asset.assetType == 'screenshot')
            .firstOrNull
            ?.id
      : null;

  @override
  void initState() {
    super.initState();
    _originalImage = _ScreenshotAssetController(_assetId, widget.onReadAsset);
  }

  @override
  void didUpdateWidget(covariant DetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content.id != widget.content.id ||
        _originalImage.assetId != _assetId) {
      _closeOriginalSheet();
      _originalImage.dispose();
      _originalImage = _ScreenshotAssetController(_assetId, widget.onReadAsset);
      _showFullText = false;
    }
  }

  @override
  void dispose() {
    _closeOriginalSheet();
    _originalImage.dispose();
    super.dispose();
  }

  void _closeOriginalSheet() {
    _originalSheetVersion++;
    _showingOriginalSheet = false;
    final route = _originalSheetRoute;
    _originalSheetRoute = null;
    if (route == null) return;
    // A modal route can outlive the detail widget beneath it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  void _showOriginal() {
    setState(() => _showFullText = !_showFullText);
    if (_showFullText && widget.content.isScreenshot) {
      unawaited(_originalImage.load());
    }
  }

  Future<void> _showOriginalSheet() async {
    if (_showingOriginalSheet) return;
    _showingOriginalSheet = true;
    final version = ++_originalSheetVersion;
    final content = widget.content;
    final image = _originalImage;
    if (content.isScreenshot) {
      unawaited(image.load());
    } else if (content.originalUrl.isNotEmpty) {
      widget.onOpenOriginalLink();
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: content.isScreenshot,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final route = ModalRoute.of<void>(sheetContext);
        if (!mounted || version != _originalSheetVersion) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (route != null && route.isActive) {
              route.navigator?.removeRoute(route);
            }
          });
          return const SizedBox.shrink();
        }
        _originalSheetRoute = route;
        return OriginalContentSheet(
          content: content,
          originalImage: content.isScreenshot
              ? _ScreenshotAssetView(controller: image)
              : null,
        );
      },
    );
    if (version == _originalSheetVersion) {
      _originalSheetRoute = null;
      _showingOriginalSheet = false;
    }
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

    void showAddContentSheet() {
      showContentSaveScreen(
        context: context,
        onAddLink: widget.onAddLink,
        onAddScreenshot: widget.onAddScreenshot,
      );
    }

    return PhoneFrame(
      child: Scaffold(
        body: Column(
          children: [
            const DesignStatusBar(),
            const SizedBox(height: 8),
            DetailTopBar(
              content: content,
              categories: widget.categories,
              bookmarked: widget.bookmarked,
              onBack: widget.onBack,
              onToggleBookmark: () => widget.onToggleBookmark(content),
              onChangeCategory: (category) =>
                  widget.onChangeCategory(content, category),
              onDeleteContent: () => widget.onDeleteContent(content),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CategoryBadge(category: content.category),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Text(
                      content.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          Text(
                            '${content.savedAtFull} 저장',
                            style: const TextStyle(
                              color: AppColors.subtle,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const Spacer(),
                          SvgIconButton(
                            asset: Assets.link,
                            onPressed: _showOriginalSheet,
                            size: 32,
                            hitSize: 32,
                            color: AppColors.subtle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '요약',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 19 / 16,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      height: 72,
                      child: Text(
                        content.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.middle,
                          fontSize: 15,
                          height: 1.6,
                          letterSpacing: -0.375,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.faint,
                    ),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: _showOriginal,
                    child: SizedBox(
                      height: 24,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Text(
                              content.isScreenshot ? '원본 이미지 보기' : '전문 보기',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const Spacer(),
                            Transform.rotate(
                              angle: _showFullText ? 3.14159 : 0,
                              child: const SvgIcon(
                                asset: Assets.chevronDown,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_showFullText) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: content.isScreenshot
                          ? _ScreenshotAssetView(controller: _originalImage)
                          : FullContentPreview(content: content),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.faint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            '태그',
                            style: TextStyle(
                              color: AppColors.middle,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 4,
                            runSpacing: 4,
                            children: content.tags
                                .map((tag) => TagChip(label: '#$tag'))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  InkWell(
                    key: _relatedKey,
                    onTap: _scrollToRelated,
                    child: SizedBox(
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: const [
                            Text(
                              '비슷한 태그를 가진 정보',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Spacer(),
                            SvgIcon(asset: Assets.chevronRight, size: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (relatedContents.isNotEmpty)
                    for (final related in relatedContents)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: RelatedContentTile(
                          category: related.category,
                          title: related.title,
                          onTap: () => widget.onOpenContent(related),
                        ),
                      )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.feed?.error != null || widget.moving)
              FeedStatus(page: widget.feed!, onRetry: widget.onRetry),
            DetailPager(
              currentIndex: currentIndex,
              totalCount: widget.contents.length,
              onPrevious: !widget.moving && currentIndex > 0
                  ? () => widget.onOpenAdjacent(-1)
                  : null,
              onNext:
                  !widget.moving &&
                      currentIndex >= 0 &&
                      (currentIndex + 1 < widget.contents.length ||
                          (widget.feed?.hasMore ?? false))
                  ? () => widget.onOpenAdjacent(1)
                  : null,
            ),
            ClipbackNavigationBar(
              activeIndex: 1,
              onTap: widget.onTab,
              onAdd: showAddContentSheet,
            ),
          ],
        ),
      ),
    );
  }
}

/// Only the open detail owns these bytes; its two image surfaces share one load.
class _ScreenshotAssetController extends ChangeNotifier {
  _ScreenshotAssetController(this.assetId, this._read);

  final int? assetId;
  final Future<Uint8List> Function(int) _read;
  Uint8List? bytes;
  String? error;
  bool loading = false;
  bool _disposed = false;
  Future<void>? _pending;

  Future<void> load({bool retry = false}) {
    if (_disposed || assetId == null) return Future.value();
    if (_pending != null) return _pending!;
    if (!retry && (bytes != null || error != null)) return Future.value();
    return _pending = _download();
  }

  void _clearBytes() {
    final previous = bytes;
    bytes = null;
    if (previous != null) {
      PaintingBinding.instance.imageCache.evict(MemoryImage(previous));
    }
  }

  Future<void> _download() async {
    _clearBytes();
    error = null;
    loading = true;
    notifyListeners();
    try {
      final result = await _read(assetId!);
      if (_disposed) return;
      bytes = result;
    } catch (failure) {
      if (_disposed) return;
      error = failure is ClipbackApiException && failure.statusCode == 404
          ? '원본 이미지를 찾을 수 없어요.'
          : '원본 이미지를 불러오지 못했어요.';
    } finally {
      if (!_disposed) {
        loading = false;
        _pending = null;
        notifyListeners();
      }
    }
  }

  void reportDecodeFailure(Uint8List rejectedBytes) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !identical(bytes, rejectedBytes)) return;
      _clearBytes();
      error = '원본 이미지를 표시하지 못했어요.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _clearBytes();
    error = null;
    super.dispose();
  }
}

class _ScreenshotAssetView extends StatelessWidget {
  const _ScreenshotAssetView({required this.controller});

  final _ScreenshotAssetController controller;

  Widget _message(String message, {bool retry = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        if (retry)
          TextButton(
            onPressed: () => controller.load(retry: true),
            child: const Text('다시 시도'),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      if (controller.assetId == null) {
        return _message('저장된 원본 이미지가 없어요.');
      }
      if (controller.loading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('원본 이미지를 불러오는 중이에요.'),
            ],
          ),
        );
      }
      if (controller.error != null) {
        return _message(controller.error!, retry: true);
      }
      final bytes = controller.bytes;
      if (bytes == null) return const SizedBox.shrink();
      return Image.memory(
        bytes,
        width: double.infinity,
        fit: BoxFit.contain,
        semanticLabel: '저장한 스크린샷 원본',
        errorBuilder: (context, error, stackTrace) {
          controller.reportDecodeFailure(bytes);
          return _message('원본 이미지를 표시하지 못했어요.', retry: true);
        },
      );
    },
  );
}

class FullContentPreview extends StatelessWidget {
  const FullContentPreview({required this.content, super.key});

  final ContentItem content;

  @override
  Widget build(BuildContext context) {
    final originalText = content.originalText.isEmpty
        ? content.summary
        : content.originalText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          originalText,
          style: const TextStyle(
            color: AppColors.middle,
            fontSize: 14,
            height: 1.6,
            letterSpacing: -0.35,
          ),
        ),
      ],
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
          if (content.mutationLabel != null) ...[
            ContentMutationStatus(label: content.mutationLabel!),
            const SizedBox(width: 12),
          ],
          BookmarkActionButton(
            initialActive: bookmarked,
            onToggle: onToggleBookmark,
            enabled: content.mutationLabel == null,
            size: 24,
            hitSize: 24,
          ),
          const SizedBox(width: 12),
          SvgIconButton(
            asset: Assets.more,
            enabled: content.mutationLabel == null,
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
            hitSize: 24,
          ),
        ],
      ),
    );
  }
}

class OriginalContentSheet extends StatelessWidget {
  const OriginalContentSheet({
    required this.content,
    this.originalImage,
    super.key,
  });

  final ContentItem content;
  final Widget? originalImage;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: content.isScreenshot ? '원본 이미지' : '원문 보기',
      children: [
        Row(
          children: [
            if (content.isScreenshot)
              const Icon(Icons.image_outlined, size: 18)
            else
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
          constraints: BoxConstraints(
            maxHeight: content.isScreenshot
                ? MediaQuery.sizeOf(context).height * 0.55
                : 280,
          ),
          width: double.infinity,
          padding: EdgeInsets.all(content.isScreenshot ? 0 : 16),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: content.isScreenshot
                ? originalImage ?? const Text('저장된 원본 이미지가 없어요.')
                : Text(
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
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundIconButton(
            asset: Assets.arrowRight,
            rotate: true,
            onPressed: onPrevious,
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 35,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Text(
                currentIndex < 0
                    ? '현재 목록에 없는 콘텐츠'
                    : '${currentIndex + 1} / 불러온 $totalCount개',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.subtle,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 19 / 14,
                ),
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
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
      ),
    );
  }
}
