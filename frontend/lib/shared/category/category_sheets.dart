import 'dart:math' as math;

import 'package:clipback_frontend/shared/category/category_colors.dart';
import 'package:clipback_frontend/shared/content/mutation_status.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/sheet_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void showCategoryActionSheet({
  required BuildContext context,
  required CategoryItem category,
  required int contentCount,
  required void Function(CategoryItem original, CategoryItem updated) onUpdate,
  required ValueChanged<CategoryItem> onDelete,
}) {
  if (category.mutationLabel != null) return;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => CategoryActionSheet(
      category: category,
      contentCount: contentCount,
      onEdit: () {
        Navigator.pop(sheetContext);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CategoryEditSheet(
              category: category,
              onSave: (updated) => onUpdate(category, updated),
            ),
          );
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.subtler,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FolderGlyph(color: category.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
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
                      Text(
                        '저장된 콘텐츠 $contentCount',
                        style: const TextStyle(
                          color: AppColors.subSubtle,
                          fontSize: 12,
                        ),
                      ),
                      if (category.mutationLabel != null)
                        ContentMutationStatus(label: category.mutationLabel!),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.faint),
            CategoryActionRow(
              icon: Icons.edit_outlined,
              title: '카테고리 수정',
              onTap: onEdit,
              enabled: category.mutationLabel == null,
            ),
            CategoryActionRow(
              icon: Icons.delete_outline,
              title: '카테고리 삭제',
              onTap: onDelete,
              enabled: category.mutationLabel == null,
            ),
          ],
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
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    child: SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.text),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ),
  );
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
      constraints: const BoxConstraints(maxWidth: phoneWidth - 64),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.mainSubtle,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '!',
                style: TextStyle(
                  color: AppColors.mainDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '삭제하기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              '‘${category.name}’ 카테고리를 삭제할까요?\n'
              '저장된 콘텐츠는 삭제되지 않아요.\n'
              '다른 카테고리가 있으면 그대로 유지되고, '
              '남은 카테고리가 없으면 미분류로 이동해요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.subtle,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: AppColors.faint),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: category.mutationLabel == null ? onDelete : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: const Color(0xFFFFD9DC),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('삭제'),
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

class CategoryCreateSheet extends StatelessWidget {
  const CategoryCreateSheet({required this.onCreate, super.key});

  final ValueChanged<CategoryItem> onCreate;

  @override
  Widget build(BuildContext context) => CategoryFormSheet(
    actionLabel: '생성하기',
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
    super.key,
  });

  final CategoryItem category;
  final ValueChanged<CategoryItem> onSave;

  @override
  Widget build(BuildContext context) => CategoryFormSheet(
    initialName: category.name,
    initialColor: category.color,
    actionLabel: '수정하기',
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
    super.key,
  });

  final String actionLabel;
  final void Function(String name, Color color) onSave;
  final String initialName;
  final Color? initialColor;

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  late final TextEditingController _controller;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _selectedColor = widget.initialColor ?? FolderColorPicker.colors.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    widget.onSave(name, _selectedColor);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = math.min(
      mediaQuery.size.height * 0.87,
      428 + mediaQuery.viewInsets.bottom,
    );
    final canCreate = _controller.text.trim().isNotEmpty;

    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.subtler,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 60,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  SvgPicture.asset(
                    Assets.folderCreatePreview,
                    width: 121,
                    height: 103,
                    colorFilter: ColorFilter.mode(
                      _selectedColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (canCreate) _save();
                    },
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.45,
                    ),
                    decoration: const InputDecoration(
                      hintText: '카테고리명을 입력해주세요',
                      hintStyle: TextStyle(color: AppColors.subtler),
                      isDense: true,
                      contentPadding: EdgeInsets.only(bottom: 8),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.subtler),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.text),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FolderColorPicker(
                    selectedColor: _selectedColor,
                    onChanged: (color) =>
                        setState(() => _selectedColor = color),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 348,
              left: 16,
              right: 16,
              height: 48,
              child: FilledButton(
                onPressed: canCreate ? _save : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: AppColors.text,
                  disabledBackgroundColor: AppColors.subtler,
                  foregroundColor: AppColors.main,
                  disabledForegroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.375,
                  ),
                ),
                child: Text(widget.actionLabel),
              ),
            ),
          ],
        ),
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
  Widget build(BuildContext context) {
    return Row(
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
                      customBorder: const CircleBorder(),
                      onTap: () => onChanged(color),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Container(
                            width: color == selectedColor ? 36 : 30,
                            height: color == selectedColor ? 36 : 30,
                            padding: color == selectedColor
                                ? const EdgeInsets.all(3)
                                : EdgeInsets.zero,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: color == selectedColor
                                  ? Border.all(color: color, width: 1.5)
                                  : null,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: color == selectedColor
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 21,
                                    )
                                  : null,
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
        _CustomFolderColorSwatch(
          onTap: () => onChanged(const Color(0xFFFF6F61)),
        ),
      ],
    );
  }
}

class _CustomFolderColorSwatch extends StatelessWidget {
  const _CustomFolderColorSwatch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 32,
      child: Row(
        children: [
          Container(width: 1, height: 32, color: AppColors.subtler),
          const SizedBox(width: 7),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 30,
              height: 30,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFD400),
                    Color(0xFF37FF00),
                    Color(0xFF00FFCC),
                    Color(0xFF0072FF),
                    Color(0xFF6905FF),
                    Color(0xFFFF0051),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6F61),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
