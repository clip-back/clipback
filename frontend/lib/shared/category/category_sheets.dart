import 'dart:math' as math;

import 'package:clipback_frontend/shared/category/category_colors.dart';
import 'package:clipback_frontend/shared/contracts/category_submission.dart';
import 'package:clipback_frontend/shared/content/mutation_status.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/sheet_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Roles are scoped to the category action, form and confirmation surfaces.
class _CategorySheetText {
  static const actionName = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.375,
    color: AppColors.text,
  );
  static const actionCount = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    color: AppColors.subSubtle,
  );
  static const actionOption = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.4,
    color: AppColors.text,
  );
  static const formHint = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.45,
    color: AppColors.subtler,
    textBaseline: TextBaseline.alphabetic,
  );
  static const formInput = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
    color: AppColors.text,
    textBaseline: TextBaseline.alphabetic,
  );
  static const formButton = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.375,
  );
  static const deleteTitle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
    color: Colors.black,
  );
  static const deleteBody = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: AppColors.subtle,
    height: 1.6,
  );
  static const deleteButton = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 22 / 14,
  );
}

class _CategorySheetHandle extends StatelessWidget {
  const _CategorySheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    height: 5,
    decoration: BoxDecoration(
      color: AppColors.subtler,
      borderRadius: BorderRadius.circular(100),
    ),
  );
}

void showCategoryCreateSheet({
  required BuildContext context,
  required ValueChanged<CategoryItem> onCreate,
  CategorySubmitCallback? onSubmit,
  CategoryPrepareCallback? onPrepare,
}) {
  final route = ModalRoute.of(context);
  bool current() => context.mounted && (route?.isCurrent ?? true);
  void open(CategoryItem? _) {
    if (!current()) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: onSubmit == null,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CategoryCreateSheet(onCreate: onCreate, onSubmit: onSubmit),
    );
  }

  if (onPrepare == null) {
    open(null);
  } else {
    onPrepare(null, isCurrent: current, onReady: open);
  }
}

void showCategoryActionSheet({
  required BuildContext context,
  required CategoryItem category,
  required int contentCount,
  required void Function(CategoryItem original, CategoryItem updated) onUpdate,
  required ValueChanged<CategoryItem> onDelete,
  CategoryUpdateSubmitCallback? onSubmitUpdate,
  CategoryPrepareCallback? onPrepare,
}) {
  if (category.mutationLabel != null) return;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => CategoryActionSheet(
      category: category,
      contentCount: contentCount,
      onEdit: () {
        Navigator.pop(sheetContext);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final route = ModalRoute.of(context);
          bool current() => context.mounted && (route?.isCurrent ?? true);
          void open(CategoryItem? prepared) {
            if (!current()) return;
            final value = prepared ?? category;
            showModalBottomSheet<void>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              enableDrag: onSubmitUpdate == null,
              backgroundColor: Colors.transparent,
              builder: (context) => CategoryEditSheet(
                category: value,
                targetMissing: onPrepare != null && prepared == null,
                onSave: (updated) => onUpdate(value, updated),
                onSubmit: onSubmitUpdate == null
                    ? null
                    : ({required name, required color, submissionKey}) =>
                          onSubmitUpdate(
                            value,
                            name: name,
                            color: color,
                            submissionKey: submissionKey,
                          ),
              ),
            );
          }

          if (onPrepare == null) {
            open(category);
          } else {
            onPrepare(category, isCurrent: current, onReady: open);
          }
        });
      },
      onDelete: () {
        Navigator.pop(sheetContext);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          showDialog<void>(
            context: context,
            builder: (context) => CategoryDeleteDialog(
              category: category,
              onDelete: () {
                Navigator.pop(context);
                onDelete(category);
              },
            ),
          );
        });
      },
    ),
  );
}

class CategoryActionSheet extends StatelessWidget {
  const CategoryActionSheet({
    required this.category,
    required this.contentCount,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final CategoryItem category;
  final int contentCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      key: const ValueKey('category-actions-sheet'),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: 8, bottom: 32 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CategorySheetHandle(
                key: ValueKey('category-actions-handle'),
              ),
              const SizedBox(height: 16),
              Padding(
                key: const ValueKey('category-actions-header'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      Assets.archiveCategoryFolder,
                      key: const ValueKey('category-actions-folder'),
                      width: 40,
                      height: 34,
                      colorFilter: ColorFilter.mode(
                        category.color,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: SizedBox(
                        width: 156,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              key: const ValueKey('category-actions-name'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _CategorySheetText.actionName,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '저장된 콘텐츠 $contentCount',
                              key: const ValueKey('category-actions-count'),
                              style: _CategorySheetText.actionCount,
                            ),
                            if (category.mutationLabel != null)
                              ContentMutationStatus(
                                label: category.mutationLabel!,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                key: ValueKey('category-actions-separator'),
                height: 8,
                width: double.infinity,
                child: ColoredBox(color: AppColors.bg),
              ),
              const SizedBox(height: 16),
              CategoryActionRow(
                key: const ValueKey('category-actions-edit'),
                icon: Icons.edit_outlined,
                title: '카테고리 수정',
                onTap: onEdit,
                enabled: category.mutationLabel == null,
              ),
              CategoryActionRow(
                key: const ValueKey('category-actions-delete'),
                icon: Icons.delete_outline,
                title: '카테고리 삭제',
                onTap: onDelete,
                enabled: category.mutationLabel == null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryActionRow extends StatelessWidget {
  const CategoryActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final asset = icon == Icons.edit_outlined
        ? Assets.categorySheetEdit
        : icon == Icons.delete_outline
        ? Assets.categorySheetTrash
        : null;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (asset != null)
                SvgPicture.asset(asset, width: 20, height: 20)
              else
                Icon(icon, size: 24, color: AppColors.text),
              const SizedBox(width: 8),
              Text(title, style: _CategorySheetText.actionOption),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryDeleteDialog extends StatelessWidget {
  const CategoryDeleteDialog({
    required this.category,
    required this.onDelete,
    super.key,
  });

  final CategoryItem category;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: phoneWidth - 64),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        key: const ValueKey('category-delete-viewport'),
        child: Padding(
          key: const ValueKey('category-delete-dialog'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('category-delete-warning'),
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.mainSubtle,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    Assets.categorySheetWarning,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '삭제하기',
                key: ValueKey('category-delete-title'),
                style: _CategorySheetText.deleteTitle,
              ),
              const SizedBox(height: 8),
              Text(
                '‘${category.name}’ 카테고리를 삭제할까요?\n'
                '저장된 콘텐츠는 삭제되지 않아요.\n'
                '다른 카테고리가 있으면 그대로 유지되고, '
                '남은 카테고리가 없으면 미분류로 이동해요.',
                key: const ValueKey('category-delete-body'),
                textAlign: TextAlign.center,
                style: _CategorySheetText.deleteBody,
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('category-delete-cancel'),
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.standard,
                          foregroundColor: AppColors.text,
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.subtler),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: _CategorySheetText.deleteButton,
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('category-delete-confirm'),
                        onPressed: category.mutationLabel == null
                            ? onDelete
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.standard,
                          backgroundColor: const Color(0xFFFFDDDD),
                          foregroundColor: const Color(0xFFFF0000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: _CategorySheetText.deleteButton,
                        ),
                        child: const Text('삭제'),
                      ),
                    ),
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

class CategoryCreateSheet extends StatelessWidget {
  const CategoryCreateSheet({required this.onCreate, this.onSubmit, super.key});

  final ValueChanged<CategoryItem> onCreate;
  final CategorySubmitCallback? onSubmit;

  @override
  Widget build(BuildContext context) => CategoryFormSheet(
    actionLabel: '생성하기',
    onSubmit: onSubmit,
    onSave: (name, color) => onCreate(
      CategoryItem(
        name: name,
        color: color,
        tint: color.withValues(alpha: 0.22),
        deep: color,
      ),
    ),
  );
}

class CategoryEditSheet extends StatelessWidget {
  const CategoryEditSheet({
    required this.category,
    required this.onSave,
    this.onSubmit,
    this.targetMissing = false,
    super.key,
  });

  final CategoryItem category;
  final bool targetMissing;
  final ValueChanged<CategoryItem> onSave;
  final CategorySubmitCallback? onSubmit;

  @override
  Widget build(BuildContext context) => CategoryFormSheet(
    targetMissing: targetMissing,
    initialName: category.name,
    initialColor: category.color,
    actionLabel: '수정하기',
    onSubmit: onSubmit,
    onSave: (name, color) => onSave(
      category.copyWith(
        name: name,
        color: color,
        tint: color.withValues(alpha: 0.22),
        deep: deepCategoryColor(color),
      ),
    ),
  );
}

class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({
    required this.actionLabel,
    required this.onSave,
    this.initialName = '',
    this.initialColor,
    this.onSubmit,
    this.targetMissing = false,
    super.key,
  });

  final String actionLabel;
  final void Function(String name, Color color) onSave;
  final String initialName;
  final Color? initialColor;
  final CategorySubmitCallback? onSubmit;
  final bool targetMissing;

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  late final TextEditingController _controller;
  late Color _selectedColor;
  bool _submitted = false;
  bool _busy = false;
  bool _unconfirmed = false;
  bool _edited = false;
  bool _confirmingClose = false;
  int _attempt = 0;
  double _dragDistance = 0;
  CategorySaveRejection? _rejection;
  String? _rejectedName;
  ({String name, Color color, String? key})? _submission;

  bool get _async => widget.onSubmit != null;
  bool get _targetMissing => _rejection == CategorySaveRejection.targetMissing;
  bool get _locked => _busy || _unconfirmed || _targetMissing;
  String? get _fieldError {
    final name = _controller.text.trim();
    if (_edited && name.isEmpty) return '카테고리 이름을 입력해 주세요.';
    if (name.runes.length > 40) return '이름은 40자 이내로 입력해 주세요.';
    if (_rejection == CategorySaveRejection.nameExists &&
        name == _rejectedName) {
      return '같은 이름의 카테고리가 있어요. 다른 이름을 입력해 주세요.';
    }
    return null;
  }

  String? get _resultMessage {
    if (_busy) return _unconfirmed ? '저장 결과를 확인하고 있어요.' : '저장하고 있어요.';
    if (_unconfirmed) {
      return '저장 결과를 확인하지 못했어요.\n이미 저장됐을 수 있어요. 결과를 다시 확인해 주세요.';
    }
    if (_targetMissing) return '이 카테고리가 삭제되어 수정할 수 없어요.';
    if (_rejection != null && _rejection != CategorySaveRejection.nameExists) {
      return '카테고리를 저장하지 못했어요.\n입력은 그대로예요. 다시 시도해 주세요.';
    }
    return null;
  }

  bool get _canSave => _async
      ? !_busy &&
            (_unconfirmed ||
                _targetMissing ||
                (_controller.text.trim().isNotEmpty && _fieldError == null))
      : !_submitted && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    if (widget.targetMissing) _rejection = CategorySaveRejection.targetMissing;
    _selectedColor = widget.initialColor ?? FolderColorPicker.colors.first;
  }

  @override
  void dispose() {
    _attempt++;
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_targetMissing) {
      Navigator.pop(context);
      return;
    }
    if (_async) {
      if (_canSave) _submit();
      return;
    }
    if (_submitted || !mounted) return;
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    _submitted = true;
    widget.onSave(name, _selectedColor);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _submit() async {
    final submission =
        _submission ??
        (name: _controller.text.trim(), color: _selectedColor, key: null);
    _submission = submission;
    final attempt = ++_attempt;
    setState(() => _busy = true);
    final result = await widget.onSubmit!(
      name: submission.name,
      color: submission.color,
      submissionKey: submission.key,
    );
    if (!mounted || attempt != _attempt) return;
    if (result.status == CategorySaveStatus.stale) return;
    if (result.status == CategorySaveStatus.succeeded) {
      if (ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _unconfirmed = result.status == CategorySaveStatus.unconfirmed;
      _rejection = result.rejection;
      _rejectedName = submission.name;
      _submission = _unconfirmed
          ? (
              name: submission.name,
              color: submission.color,
              key: result.submissionKey,
            )
          : null;
    });
  }

  Future<void> _close() async {
    if (_busy || _confirmingClose) return;
    if (_unconfirmed) {
      _confirmingClose = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '입력 창을 닫을까요?',
                    style: _CategorySheetText.deleteTitle,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '닫아도 서버 저장은 완료될 수 있어요.\n작성한 내용은 이 창에서 사라져요.',
                    style: _CategorySheetText.deleteBody,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('계속 확인하기'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      _confirmingClose = false;
      if (!mounted || discard != true) return;
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _fields() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SvgPicture.asset(
        Assets.folderCreatePreview,
        key: const ValueKey('category-form-folder'),
        width: 121,
        height: 103,
        colorFilter: ColorFilter.mode(_selectedColor, BlendMode.srcIn),
      ),
      const SizedBox(height: 32),
      TextField(
        key: const ValueKey('category-form-input'),
        controller: _controller,
        autofocus: true,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        maxLines: 1,
        readOnly: _async && _locked,
        onChanged: (_) => setState(() {
          _edited = true;
        }),
        onSubmitted: (_) {
          if (_canSave) _save();
        },
        style: _CategorySheetText.formInput,
        decoration: const InputDecoration(
          hintText: '카테고리명을 입력해주세요',
          hintStyle: _CategorySheetText.formHint,
          isDense: true,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        key: const ValueKey('category-form-underline'),
        width: double.infinity,
        height: 1,
        child: SvgPicture.asset(
          Assets.categorySheetUnderline,
          width: 327,
          height: 1,
          fit: BoxFit.fill,
        ),
      ),
      if (_async && _fieldError != null) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _fieldError!,
            key: const ValueKey('category-form-error'),
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFFBD263B),
            ),
          ),
        ),
      ],
      const SizedBox(height: 32),
      AbsorbPointer(
        absorbing: _async && _locked,
        child: FolderColorPicker(
          key: const ValueKey('category-form-palette'),
          selectedColor: _selectedColor,
          onChanged: (color) => setState(() => _selectedColor = color),
        ),
      ),
      if (_async && _resultMessage != null) ...[
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _resultMessage!,
              key: const ValueKey('category-form-status'),
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.subtle,
              ),
            ),
          ),
        ),
      ],
    ],
  );

  Widget _button() => FilledButton(
    onPressed: _canSave ? _save : null,
    style: FilledButton.styleFrom(
      padding: _async
          ? const EdgeInsets.symmetric(vertical: 14, horizontal: 12)
          : EdgeInsets.zero,
      minimumSize: _async ? const Size(0, 48) : Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      backgroundColor: AppColors.text,
      disabledBackgroundColor: AppColors.subtler,
      foregroundColor: AppColors.main,
      disabledForegroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: _CategorySheetText.formButton,
    ),
    child: Text(
      _busy
          ? (_unconfirmed ? '확인 중…' : '저장 중…')
          : _unconfirmed
          ? '결과 다시 확인'
          : _targetMissing
          ? '목록으로 돌아가기'
          : widget.actionLabel,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = math.max(media.viewInsets.bottom, media.viewPadding.bottom);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : media.size.height - media.padding.top;
        final sheetHeight = math.min(428 + inset, available);
        if (_async) {
          final extra =
              (_resultMessage == null ? 0 : 78) +
              (_fieldError == null ? 0 : 44);
          final scale = media.textScaler.scale(12) / 12;
          return PopScope<void>(
            canPop: !_locked,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (media.viewInsets.bottom > 0) {
                FocusScope.of(context).unfocus();
              } else {
                _close();
              }
            },
            child: SizedBox(
              key: const ValueKey('category-form-sheet'),
              height: math.min(
                428 + inset + extra * scale + (scale - 1) * 90,
                available,
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  key: const ValueKey('category-form-body-scroll'),
                  padding: EdgeInsets.only(bottom: 32 + inset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (_) => _dragDistance = 0,
                        onVerticalDragUpdate: (details) =>
                            _dragDistance += details.delta.dy,
                        onVerticalDragEnd: (_) {
                          if (_dragDistance > 40) _close();
                        },
                        child: const SizedBox(
                          height: 29,
                          child: Stack(
                            children: [
                              Positioned(
                                top: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _CategorySheetHandle(
                                    key: ValueKey('category-form-handle'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 31, 24, 0),
                        child: _fields(),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          _resultMessage == null ? 56 : 24,
                          16,
                          0,
                        ),
                        child: SizedBox(
                          key: const ValueKey('category-form-button'),
                          width: double.infinity,
                          child: _button(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return SizedBox(
          key: const ValueKey('category-form-sheet'),
          height: sheetHeight,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(
                  height: 29,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _CategorySheetHandle(
                            key: ValueKey('category-form-handle'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('category-form-body-scroll'),
                    clipBehavior: Clip.hardEdge,
                    padding: const EdgeInsets.fromLTRB(24, 31, 24, 0),
                    child: _fields(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + inset),
                  child: SizedBox(
                    key: const ValueKey('category-form-button'),
                    height: 48,
                    width: double.infinity,
                    child: _button(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    this.enabled = true,
    super.key,
  });

  final CategoryItem current;
  final List<CategoryItem> categories;
  final ValueChanged<CategoryItem> onChange;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '카테고리 변경',
      children: [
        const Text(
          '저장할 카테고리를 선택해 주세요.',
          style: TextStyle(
            color: AppColors.subtle,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        for (final category in categories)
          CategoryChangeTile(
            category: category,
            selected: category.id == current.id,
            enabled: enabled && !category.isDeleting,
            onTap: () {
              onChange(category);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}

class CategoryChangeTile extends StatelessWidget {
  const CategoryChangeTile({
    required this.category,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final CategoryItem category;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? category.tint : AppColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? category.deep : AppColors.faint,
              ),
            ),
            child: Row(
              children: [
                FolderGlyph(color: category.color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? category.deep : AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? category.deep : Colors.transparent,
                    shape: BoxShape.circle,
                    border: selected
                        ? null
                        : Border.all(color: AppColors.subtler),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
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
    Color(0xFFFF6277),
    Color(0xFFFFA24B),
    Color(0xFFFFD75C),
    Color(0xFF5BD89D),
    Color(0xFF64B5F6),
    Color(0xFFB9AAFF),
    Color(0xFFFFB3C1),
    Color(0xFF1F5E24),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final color in colors)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    key: ValueKey(
                      'palette-color-${color.toARGB32().toRadixString(16)}',
                    ),
                    customBorder: const CircleBorder(),
                    onTap: () => onChanged(color),
                    child: SizedBox(
                      width: color == selectedColor ? 36 : 30,
                      height: 36,
                      child: Center(
                        child: color == selectedColor
                            ? SizedBox(
                                width: 36,
                                height: 36,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: color,
                                            width: 1.431,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: SvgPicture.asset(
                                        Assets.categorySheetSelectedSwatch,
                                        width: 30,
                                        height: 30,
                                        colorMapper: _CategorySwatchColorMapper(
                                          color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      _CustomFolderColorSwatch(onTap: () => onChanged(const Color(0xFFFF6F61))),
    ],
  );
}

class _CategorySwatchColorMapper extends ColorMapper {
  const _CategorySwatchColorMapper(this.selectedColor);
  final Color selectedColor;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => color.toARGB32() == 0xFFFF6277 ? selectedColor : color;

  @override
  bool operator ==(Object other) =>
      other is _CategorySwatchColorMapper &&
      other.selectedColor == selectedColor;
  @override
  int get hashCode => selectedColor.hashCode;
}

class _CustomFolderColorSwatch extends StatelessWidget {
  const _CustomFolderColorSwatch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('palette-custom'),
    customBorder: const CircleBorder(),
    onTap: onTap,
    child: Image.asset(
      Assets.categorySheetCustom,
      scale: 3,
      width: 38,
      height: 32,
    ),
  );
}
