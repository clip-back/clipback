import 'package:flutter/material.dart';

import '../../data/repositories/share_repository.dart';

/// An unobtrusive entry to native recovery; the underlying route stays alive.
class PendingSharePrompt extends StatefulWidget {
  const PendingSharePrompt({
    required this.child,
    required this.drafts,
    required this.error,
    required this.busy,
    required this.onRetry,
    required this.onOpen,
    required this.navigatorKey,
    required this.promptVersion,
    super.key,
  });

  final Widget child;
  final List<PendingShareDraft> drafts;
  final String? error;
  final bool busy;
  final VoidCallback onRetry;
  final ValueChanged<PendingShareDraft> onOpen;
  final GlobalKey<NavigatorState> navigatorKey;
  final int promptVersion;

  @override
  State<PendingSharePrompt> createState() => _PendingSharePromptState();
}

class _PendingSharePromptState extends State<PendingSharePrompt> {
  bool _dismissed = false;

  @override
  void didUpdateWidget(covariant PendingSharePrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.promptVersion != widget.promptVersion) _dismissed = false;
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (!_dismissed && (widget.drafts.isNotEmpty || widget.error != null))
        Positioned(
          top: 0,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.error ??
                                '저장 대기 중인 공유 ${widget.drafts.length}개',
                          ),
                        ),
                        TextButton(
                          onPressed: widget.busy
                              ? null
                              : widget.error != null
                              ? widget.onRetry
                              : () => _choose(context),
                          child: Text(widget.error != null ? '다시 시도' : '확인'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, semanticLabel: '나중에'),
                          onPressed: () => setState(() => _dismissed = true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Future<void> _choose(BuildContext context) async {
    final navigationContext =
        widget.navigatorKey.currentState?.overlay?.context;
    if (navigationContext == null) return;
    final draft = await showModalBottomSheet<PendingShareDraft>(
      context: navigationContext,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('저장 대기 중인 공유')),
            for (final draft in widget.drafts)
              ListTile(
                title: Text(
                  draft.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, draft),
              ),
          ],
        ),
      ),
    );
    if (draft != null && context.mounted) widget.onOpen(draft);
  }
}
