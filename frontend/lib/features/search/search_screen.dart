import 'dart:async';

import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/paged_content_list.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    this.feed,
    this.onLoadMore,
    this.onRetry,
    required this.initialQuery,
    required this.contents,
    required this.bookmarkedIds,
    required this.categories,
    required this.onSearch,
    required this.onQueryChanged,
    required this.onClose,
    required this.onOpenContent,
    required this.onToggleBookmark,
    required this.onChangeContentCategory,
    required this.onDeleteContent,
    required this.onOpenArchive,
    super.key,
  });

  final String initialQuery;
  final FeedPage? feed;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRetry;
  final List<ContentItem> contents;
  final Set<String> bookmarkedIds;
  final List<CategoryItem> categories;
  final Future<List<ContentItem>> Function(String query) onSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClose;
  final ValueChanged<ContentItem> onOpenContent;
  final ValueChanged<ContentItem> onToggleBookmark;
  final void Function(ContentItem content, CategoryItem category)
  onChangeContentCategory;
  final ValueChanged<ContentItem> onDeleteContent;
  final VoidCallback onOpenArchive;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late List<String> _terms;
  List<ContentItem>? _serverResults;
  var _isSearching = false;
  int _requestVersion = 0;

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

  Future<void> _submitQuery(String value) async {
    final term = value.trim();
    if (term.isEmpty) return;
    final version = ++_requestVersion;
    widget.onQueryChanged(term);
    setState(() {
      _terms
        ..remove(term)
        ..insert(0, term);
      if (_terms.length > 5) {
        _terms = _terms.take(5).toList();
      }
    });
    setState(() {
      _isSearching = true;
      _serverResults = null;
    });
    try {
      final results = await widget.onSearch(term);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _serverResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (mounted && version == _requestVersion) {
        setState(() => _isSearching = false);
      }
    }
  }

  List<ContentItem> get _results {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return const [];
    }
    if (widget.feed != null) return widget.contents;
    return _serverResults ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: appHeaderHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                  autofocus: widget.initialQuery.trim().isEmpty,
                                  onChanged: (value) {
                                    _requestVersion++;
                                    widget.onQueryChanged(value);
                                    setState(() {
                                      _serverResults = null;
                                      _isSearching = false;
                                    });
                                  },
                                  onSubmitted: (value) {
                                    unawaited(_submitQuery(value));
                                  },
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
                                    _requestVersion++;
                                    _controller.clear();
                                    widget.onQueryChanged('');
                                    setState(() {
                                      _serverResults = null;
                                      _isSearching = false;
                                    });
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
              ),
              const SizedBox(height: 32),
              Expanded(
                child: _hasQuery && widget.feed != null
                    ? (widget.feed!.query == null
                          ? const Center(child: Text('검색어를 입력하고 검색해 주세요.'))
                          : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text('불러온 ${_results.length}개'),
                                ),
                                Expanded(
                                  child: PagedContentList(
                                    feed: widget.feed,
                                    contents: _results,
                                    onLoadMore: widget.onLoadMore,
                                    onRetry: widget.onRetry,
                                    empty: EmptySearchResult(
                                      onOpenArchive: widget.onOpenArchive,
                                    ),
                                    itemBuilder: (content) => ContentListCard(
                                      content: content,
                                      bookmarked: widget.bookmarkedIds.contains(
                                        content.id,
                                      ),
                                      onToggleBookmark: () =>
                                          widget.onToggleBookmark(content),
                                      categories: widget.categories,
                                      onChangeCategory: (category) =>
                                          widget.onChangeContentCategory(
                                            content,
                                            category,
                                          ),
                                      onDelete: () =>
                                          widget.onDeleteContent(content),
                                      onTap: () =>
                                          widget.onOpenContent(content),
                                    ),
                                  ),
                                ),
                              ],
                            ))
                    : ListView(
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
                                  unawaited(_submitQuery(term));
                                },
                                onRemove: () =>
                                    setState(() => _terms.remove(term)),
                              ),
                          ] else ...[
                            if (_isSearching)
                              const Padding(
                                padding: EdgeInsets.only(top: 72),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.mainDeep,
                                  ),
                                ),
                              )
                            else ...[
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
                                    categories: widget.categories,
                                    onChangeCategory: (category) =>
                                        widget.onChangeContentCategory(
                                          content,
                                          category,
                                        ),
                                    onDelete: () =>
                                        widget.onDeleteContent(content),
                                    onTap: () => widget.onOpenContent(content),
                                  ),
                                ),
                              if (_results.isEmpty)
                                EmptySearchResult(
                                  onOpenArchive: widget.onOpenArchive,
                                ),
                            ],
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

const recentSearches = ['올영세일', '여름 쇼핑몰', '부산 맛집', '금리', '도쿄역'];
