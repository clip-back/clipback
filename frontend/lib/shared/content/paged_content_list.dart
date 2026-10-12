import 'dart:async';

import 'package:clipback_frontend/shared/content/feed_status.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:flutter/material.dart';

class PagedContentList extends StatefulWidget {
  const PagedContentList({
    required this.contents,
    required this.itemBuilder,
    required this.empty,
    this.feed,
    this.onLoadMore,
    this.onRetry,
    super.key,
  });

  final FeedPage? feed;
  final List<ContentItem> contents;
  final Widget Function(ContentItem) itemBuilder;
  final Widget empty;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRetry;

  @override
  State<PagedContentList> createState() => _PagedContentListState();
}

class _PagedContentListState extends State<PagedContentList> {
  late final ScrollController _controller;
  int? _feedVersion;
  double _restoreOffset = 0;
  bool _restorePending = true;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _feedVersion = widget.feed?.version;
    _restoreOffset = widget.feed?.scrollOffset ?? 0;
    _controller = ScrollController(
      initialScrollOffset: _restoreOffset,
      keepScrollOffset: false,
    )..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PagedContentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.feed, widget.feed) ||
        _feedVersion != widget.feed?.version) {
      if (!identical(oldWidget.feed, widget.feed) &&
          !_restorePending &&
          _controller.hasClients &&
          oldWidget.feed?.version == _feedVersion) {
        oldWidget.feed?.scrollOffset = _controller.offset;
      }
      _feedVersion = widget.feed?.version;
      _restoreOffset = widget.feed?.scrollOffset ?? 0;
      _restorePending = true;
    }
  }

  @override
  void dispose() {
    _saveOffset();
    _controller.dispose();
    super.dispose();
  }

  void _saveOffset() {
    if (_restorePending ||
        !_controller.hasClients ||
        _feedVersion != widget.feed?.version) {
      return;
    }
    widget.feed?.scrollOffset = _controller.offset;
  }

  void _onScroll() {
    _saveOffset();
    _maybeLoadMore();
  }

  void _scheduleViewportCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || !_controller.hasClients) return;
      if (_restorePending) {
        final offset = _restoreOffset
            .clamp(0.0, _controller.position.maxScrollExtent)
            .toDouble();
        _restorePending = false;
        _controller.jumpTo(offset);
      }
      _saveOffset();
      _maybeLoadMore();
    });
  }

  void _maybeLoadMore() {
    final page = widget.feed;
    final loadMore = widget.onLoadMore;
    if (_restorePending ||
        !_controller.hasClients ||
        page == null ||
        loadMore == null ||
        _feedVersion != page.version ||
        !page.initialized ||
        page.loading ||
        page.error != null ||
        !page.hasMore ||
        _controller.position.extentAfter > 300) {
      return;
    }
    unawaited(_loadMore(loadMore));
  }

  Future<void> _loadMore(Future<void> Function() loadMore) async {
    try {
      await loadMore();
    } finally {
      if (mounted) _scheduleViewportCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleViewportCheck();
    final page = widget.feed;
    if (widget.contents.isEmpty) {
      if (page != null &&
          (!page.initialized || page.loading || page.error != null)) {
        return Center(
          child: FeedStatus(page: page, onRetry: widget.onRetry),
        );
      }
      return widget.empty;
    }
    return ListView.separated(
      controller: _controller,
      padding: EdgeInsets.zero,
      itemCount: widget.contents.length + (page == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == widget.contents.length) {
          return FeedStatus(page: page!, onRetry: widget.onRetry);
        }
        final content = widget.contents[index];
        return KeyedSubtree(
          key: ValueKey(content.id),
          child: widget.itemBuilder(content),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 8),
    );
  }
}
