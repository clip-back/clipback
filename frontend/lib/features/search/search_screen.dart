import 'dart:async';

import 'package:clipback_frontend/shared/content/content_list_card.dart';
import 'package:clipback_frontend/shared/content/paged_content_list.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/features/search/search_widgets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    this.feed,
    this.recentTerms,
    this.onRemoveRecentTerm,
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

  final List<String>? recentTerms;
  final ValueChanged<String>? onRemoveRecentTerm;
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
  final List<String> _localTerms = [];
  List<String> get _terms => widget.recentTerms ?? _localTerms;
  List<ContentItem>? _serverResults;
  String? _completedQuery;
  var _isSearching = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
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
    if (widget.recentTerms == null) {
      setState(() {
        _localTerms
          ..remove(term)
          ..insert(0, term);
        if (_localTerms.length > 5) {
          _localTerms.removeRange(5, _localTerms.length);
        }
      });
    }
    setState(() {
      _isSearching = true;
      _serverResults = null;
      _completedQuery = null;
    });
    try {
      final results = await widget.onSearch(term);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _serverResults = results;
        _completedQuery = term;
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

  bool get _confirmedEmpty {
    if (!_hasQuery || _results.isNotEmpty) return false;
    final page = widget.feed;
    if (page == null) {
      return !_isSearching &&
          _serverResults?.isEmpty == true &&
          _completedQuery == _controller.text.trim();
    }
    return page.query == _controller.text.trim() &&
        page.categoryId == null &&
        page.isFavorite == null &&
        page.initialized &&
        !page.loading &&
        page.error == null &&
        !page.hasMore &&
        page.items.isEmpty;
  }

  void _changeQuery(String value) {
    _requestVersion++;
    widget.onQueryChanged(value);
    setState(() {
      _serverResults = null;
      _completedQuery = null;
      _isSearching = false;
    });
  }

  void _clearQuery() {
    _controller.clear();
    _changeQuery('');
  }

  Widget _card(ContentItem content) => ContentListCard(
    archiveAllStyle: true,
    content: content,
    bookmarked: widget.bookmarkedIds.contains(content.id),
    onToggleBookmark: () => widget.onToggleBookmark(content),
    categories: widget.categories,
    onChangeCategory: (category) =>
        widget.onChangeContentCategory(content, category),
    onDelete: () => widget.onDeleteContent(content),
    onTap: () => widget.onOpenContent(content),
  );

  Widget _emptyResult() => _confirmedEmpty
      ? SearchEmptyState(onOpenArchive: widget.onOpenArchive)
      : EmptySearchResult(onOpenArchive: widget.onOpenArchive);

  Widget _resultsBody() {
    if (widget.feed != null) {
      if (widget.feed!.query == null) {
        return const Center(child: Text('검색어를 입력하고 검색해 주세요.'));
      }
      return PagedContentList(
        feed: widget.feed,
        contents: _results,
        onLoadMore: widget.onLoadMore,
        onRetry: widget.onRetry,
        empty: _emptyResult(),
        itemBuilder: _card,
      );
    }
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.only(top: 72),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.mainDeep),
        ),
      );
    }
    if (_confirmedEmpty) return _emptyResult();
    return ListView(
      padding: _results.isEmpty
          ? const EdgeInsets.symmetric(horizontal: 16)
          : EdgeInsets.zero,
      children: [
        for (final content in _results)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _card(content),
          ),
        if (_results.isEmpty) _emptyResult(),
      ],
    );
  }

  Widget _historyBody() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    children: [
      const Text(
        '최근 검색어',
        key: ValueKey('search-history-title'),
        style: SearchTextStyles.historyHeading,
      ),
      const SizedBox(height: 16),
      Column(
        key: const ValueKey('search-history-list'),
        children: [
          for (final (index, term) in _terms.indexed) ...[
            if (index > 0) const SizedBox(height: 4),
            SearchHistoryRow(
              term: term,
              onTap: () {
                _controller.text = term;
                unawaited(_submitQuery(term));
              },
              onRemove: () {
                if (widget.recentTerms != null) {
                  widget.onRemoveRecentTerm?.call(term);
                } else {
                  setState(() => _localTerms.remove(term));
                }
              },
            ),
          ],
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PhoneFrame(
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SearchInputBar(
              controller: _controller,
              autofocus: widget.initialQuery.trim().isEmpty,
              hasQuery: _hasQuery,
              onChanged: _changeQuery,
              onSubmitted: (value) => unawaited(_submitQuery(value)),
              onClear: _clearQuery,
              onClose: widget.onClose,
            ),
            Expanded(
              child: SizedBox(
                key: const ValueKey('search-results-viewport'),
                child: _hasQuery ? _resultsBody() : _historyBody(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('search-history-row-$term'),
    height: 32,
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SvgPicture.asset(
                  Assets.searchHistoryClock,
                  key: ValueKey('search-history-clock-$term'),
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 9.542),
                Expanded(
                  child: Text(
                    term,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SearchTextStyles.history,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: ValueKey('search-history-remove-$term'),
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: SvgPicture.asset(
              Assets.searchHistoryRemove,
              width: 18,
              height: 18,
            ),
          ),
        ],
      ),
    ),
  );
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
