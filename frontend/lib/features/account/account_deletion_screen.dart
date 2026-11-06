import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Figma J04 111:5780 and J05 111:5824 (queried 2026-11-06).
abstract final class AccountDeletionText {
  static const header = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -.475,
    color: Colors.black,
  );
  static const title = TextStyle(
    inherit: false,
    fontFamily: 'PretendardDetail',
    fontSize: 25,
    fontWeight: FontWeight.w700,
    letterSpacing: -.625,
    color: AppColors.text,
    height: 1.6,
  );
  static const description = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 17,
    fontWeight: FontWeight.w500,
    letterSpacing: -.425,
    color: AppColors.subtle,
    height: 1.5,
  );
  static const cardTitle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -.375,
    color: AppColors.middle,
    height: 1.5,
  );
  static const cardBody = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -.375,
    color: AppColors.subtle,
    height: 1.5,
  );
  static const reason = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -.375,
    color: AppColors.text,
    height: 1.5,
  );
  static const noticeTitle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -.375,
    color: AppColors.subtle,
  );
  static const noticeBody = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -.325,
    color: AppColors.subtle,
    height: 1.5,
  );
  static const button = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 22 / 17,
  );
}

const accountDeletionReasonLabels = {
  AccountDeletionReason.rejoin: '재가입',
  AccountDeletionReason.lowUsage: '이용 빈도 및 기대감이 낮음',
  AccountDeletionReason.privacySecurity: '개인정보보호 및 보안',
  AccountDeletionReason.other: '기타',
};

/// J04 before a reason is chosen, J05 after. Counts are null while loading or
/// after a failure and leave the number slot empty (D21).
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    required this.name,
    required this.contentCount,
    required this.categoryCount,
    required this.onBack,
    required this.onSubmit,
    this.busy = false,
    super.key,
  });

  final String name;
  final int? contentCount;
  final int? categoryCount;
  final VoidCallback onBack;
  final Future<void> Function(List<AccountDeletionReason> reasons) onSubmit;
  final bool busy;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _selected = <AccountDeletionReason>{};

  void _toggle(AccountDeletionReason reason) => setState(() {
    if (!_selected.remove(reason)) _selected.add(reason);
  });

  @override
  Widget build(BuildContext context) {
    final busy = widget.busy;
    final canSubmit = _selected.isNotEmpty && !busy;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !widget.busy) widget.onBack();
      },
      child: PhoneFrame(
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Header(onBack: busy ? null : widget.onBack),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('account-deletion-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '정말로 탈퇴하시겠어요?',
                          key: ValueKey('account-deletion-title'),
                          style: AccountDeletionText.title,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.name} 님의 아래 정보는 모두 삭제되며,\n'
                          '탈퇴 시 정보 복구가 어려워요.',
                          key: const ValueKey('account-deletion-description'),
                          style: AccountDeletionText.description,
                        ),
                        const SizedBox(height: 10),
                        _TargetCard(
                          contentCount: widget.contentCount,
                          categoryCount: widget.categoryCount,
                        ),
                        const SizedBox(height: 4),
                        _ReasonCard(selected: _selected, onToggle: _toggle),
                        const SizedBox(height: 7),
                        const Padding(
                          key: ValueKey('account-deletion-notice'),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '회원탈퇴 유의사항',
                                style: AccountDeletionText.noticeTitle,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '회원 탈퇴 시 계정과 프로필 정보 및 저장한 모든 콘텐츠가 삭제되며,\n'
                                '이후 같은 계정으로 재가입하여도 삭제된 정보는 복구되지 않습니다.',
                                style: AccountDeletionText.noticeBody,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  key: const ValueKey('account-deletion-footer'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AccountDeletionButton(
                        key: const ValueKey('account-deletion-submit'),
                        label: '탈퇴하기',
                        background: canSubmit
                            ? AppColors.text
                            : AppColors.subtler,
                        foreground: canSubmit
                            ? AppColors.main
                            : AppColors.surface,
                        onPressed: canSubmit
                            ? () => unawaited(
                                widget.onSubmit([
                                  for (final reason
                                      in AccountDeletionReason.values)
                                    if (_selected.contains(reason)) reason,
                                ]),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      AccountDeletionButton(
                        key: const ValueKey('account-deletion-cancel'),
                        label: '취소',
                        background: AppColors.surface,
                        foreground: AppColors.text,
                        border: AppColors.subtle,
                        onPressed: busy ? null : widget.onBack,
                      ),
                    ],
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('account-deletion-header'),
    height: appHeaderHeight,
    child: Stack(
      children: [
        const Positioned.fill(
          left: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text('계정 관리', style: AccountDeletionText.header),
            ),
          ),
        ),
        Positioned(
          left: 4,
          top: 8.5,
          child: Semantics(
            button: true,
            label: '뒤로가기',
            child: InkWell(
              key: const ValueKey('account-deletion-back-hit'),
              onTap: onBack,
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SvgPicture.asset(
                    Assets.detailBack,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
      child: child,
    ),
  );
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.contentCount, required this.categoryCount});
  final int? contentCount;
  final int? categoryCount;

  @override
  Widget build(BuildContext context) => _Card(
    key: const ValueKey('account-deletion-target'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              Assets.accountDeletionHardDrive,
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 4),
            const Flexible(
              child: Text('삭제 대상', style: AccountDeletionText.cardTitle),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '콘텐츠 ${contentCount ?? ''}개',
              key: const ValueKey('account-deletion-content-count'),
              style: AccountDeletionText.cardBody,
            ),
            SvgPicture.asset(Assets.accountDeletionDot, width: 3, height: 3),
            Text(
              '카테고리 ${categoryCount ?? ''}개',
              key: const ValueKey('account-deletion-category-count'),
              style: AccountDeletionText.cardBody,
            ),
          ],
        ),
      ],
    ),
  );
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.selected, required this.onToggle});
  final Set<AccountDeletionReason> selected;
  final ValueChanged<AccountDeletionReason> onToggle;

  @override
  Widget build(BuildContext context) => _Card(
    key: const ValueKey('account-deletion-reasons'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text.rich(
          TextSpan(
            text: '허투루를 탈퇴하려는 이유가 무엇인가요? ',
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(color: Color(0xFFFF3C40)),
              ),
            ],
          ),
          style: AccountDeletionText.cardTitle,
        ),
        const SizedBox(height: 8),
        const Text('복수 선택 가능', style: AccountDeletionText.cardBody),
        const SizedBox(height: 10),
        for (final (index, reason) in AccountDeletionReason.values.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          _ReasonRow(
            label: accountDeletionReasonLabels[reason]!,
            selected: selected.contains(reason),
            onTap: () => onToggle(reason),
          ),
        ],
      ],
    ),
  );
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      checked: selected,
      child: GestureDetector(
        key: ValueKey('account-deletion-reason-$label'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 14,
              child: selected
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.text,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: SvgPicture.asset(
                        Assets.accountDeletionCheck,
                        width: 14,
                        height: 14,
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.subtler),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: AccountDeletionText.reason)),
          ],
        ),
      ),
    ),
  );
}

class AccountDeletionButton extends StatelessWidget {
  const AccountDeletionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.border,
    this.minHeight = 48,
    super.key,
  });
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final double minHeight;
  final VoidCallback? onPressed;

  // The height grows with wrapped text instead of shrinking it (R10).
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minHeight),
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: border == null ? BorderSide.none : BorderSide(color: border!),
        elevation: 0,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AccountDeletionText.button.copyWith(color: foreground),
      ),
    ),
  );
}
