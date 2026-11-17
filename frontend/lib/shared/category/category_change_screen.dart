import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Figma [64] 403:4438 (queried 2026-11-17).
abstract final class _CategoryChangeText {
  static const header = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -.475,
    color: Colors.black,
  );
  static const count = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -.375,
    color: AppColors.subtle,
  );
  static const toggleAll = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -.35,
    color: AppColors.middle,
  );
  static const name = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -.4,
    color: AppColors.text,
  );
  static const date = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -.325,
    color: AppColors.subSubtle,
  );
  static const submit = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 22 / 17,
    color: AppColors.main,
  );
}

/// Live app state the change screen reads while it is open.
abstract interface class CategoryChangeSource implements Listenable {
  /// The latest app category list, in list order, with deletion state.
  List<CategoryItem> get categories;
  int get accountGeneration;
  bool hasContent(int contentId);
}

/// Gives routes above the app screens the live [CategoryChangeSource].
class CategoryChangeScope extends InheritedWidget {
  const CategoryChangeScope({
    required this.source,
    required super.child,
    super.key,
  });

  final CategoryChangeSource source;

  static CategoryChangeSource? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CategoryChangeScope>()?.source;

  @override
  bool updateShouldNotify(CategoryChangeScope oldWidget) =>
      !identical(source, oldWidget.source);
}

bool _isUncategorized(CategoryItem category) =>
    category.name == catUncategorized.name;

Future<void> showCategoryChangeScreen({
  required BuildContext context,
  required ContentItem content,
  required List<CategoryItem> categories,
  required ValueChanged<List<int>> onChange,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => PhoneFrame(
      child: CategoryChangeScreen(
        content: content,
        categories: categories,
        onChange: onChange,
      ),
    ),
  ),
);

/// Picks every category of one content; "선택 완료" saves them at once.
class CategoryChangeScreen extends StatefulWidget {
  const CategoryChangeScreen({
    required this.content,
    required this.categories,
    required this.onChange,
    super.key,
  });

  final ContentItem content;

  /// Used only without a [CategoryChangeScope] (standalone screens in tests).
  final List<CategoryItem> categories;
  final ValueChanged<List<int>> onChange;

  @override
  State<CategoryChangeScreen> createState() => _CategoryChangeScreenState();
}

class _CategoryChangeScreenState extends State<CategoryChangeScreen> {
  CategoryChangeSource? _source;
  int? _generation;
  late final Set<int> _initial;
  late final Set<int> _selected;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _source = CategoryChangeScope.maybeOf(context);
    _generation = _source?.accountGeneration;
    _initial = {
      for (final category in widget.content.categories)
        if (category.id != null && !_isUncategorized(category)) category.id!,
    };
    _selected = {..._initial};
  }

  List<CategoryItem> get _rows => [
    for (final category in _source?.categories ?? widget.categories)
      if (category.id != null && !_isUncategorized(category)) category,
  ];

  void _toggle(CategoryItem category) => setState(() {
    if (!_selected.remove(category.id)) _selected.add(category.id!);
  });

  void _toggleAll(List<CategoryItem> enabled, bool clear) => setState(() {
    for (final category in enabled) {
      clear ? _selected.remove(category.id) : _selected.add(category.id!);
    }
  });

  void _submit() {
    if (_submitted) return;
    _submitted = true;
    Navigator.pop(context);
    final source = _source;
    if (source != null &&
        (source.accountGeneration != _generation ||
            !source.hasContent(widget.content.apiId!))) {
      return;
    }
    if (setEquals(_selected, _initial)) return;
    widget.onChange([
      for (final category in _rows)
        if (!category.isDeleting && _selected.contains(category.id))
          category.id!,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    return source == null
        ? _build(context)
        : ListenableBuilder(listenable: source, builder: (c, _) => _build(c));
  }

  Widget _build(BuildContext context) {
    final rows = _rows;
    final enabled = rows.where((category) => !category.isDeleting).toList();
    final count = rows.where((row) => _selected.contains(row.id)).length;
    final clear =
        enabled.isNotEmpty && enabled.every((c) => _selected.contains(c.id));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.maybePop(context)),
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$count개 선택',
                        key: const ValueKey('category-change-count'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CategoryChangeText.count,
                      ),
                    ),
                    _TextButton(
                      key: const ValueKey('category-change-toggle-all'),
                      label: clear ? '전체 해제' : '전체 선택',
                      onTap: () => _toggleAll(enabled, clear),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                key: const ValueKey('category-change-list'),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final category = rows[index];
                  return CategoryChangeRow(
                    key: ValueKey('category-change-row-${category.id}'),
                    category: category,
                    selected: _selected.contains(category.id),
                    enabled: !category.isDeleting,
                    onTap: () => _toggle(category),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: _SubmitButton(onTap: _submit),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('category-change-header'),
    height: appHeaderHeight,
    child: Stack(
      children: [
        const Positioned.fill(
          left: 48,
          right: 16,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text(
                '카테고리 변경',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CategoryChangeText.header,
              ),
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
              key: const ValueKey('category-change-back'),
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

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap, super.key});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    onTap: onTap,
    child: ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 80,
          height: 52,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: _CategoryChangeText.toggleAll,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: '선택 완료',
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: const ValueKey('category-change-submit'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: const SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                '선택 완료',
                maxLines: 1,
                style: _CategoryChangeText.submit,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// One category with its folder colour, last save line and round check.
class CategoryChangeRow extends StatelessWidget {
  const CategoryChangeRow({
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
  Widget build(BuildContext context) => Semantics(
    container: true,
    checked: selected,
    enabled: enabled,
    label: category.name,
    onTap: enabled ? onTap : null,
    child: ExcludeSemantics(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  Assets.archiveCategoryFolder,
                  width: 40,
                  height: 34,
                  colorFilter: ColorFilter.mode(
                    category.color,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 156,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CategoryChangeText.name,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category.mutationLabel ??
                                category.lastSavedAt ??
                                '저장된 콘텐츠 없음',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CategoryChangeText.date,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  key: ValueKey('category-change-check-${category.id}'),
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.text : AppColors.subtler,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    selected
                        ? Assets.categoryChangeCheckSelected
                        : Assets.categoryChangeCheckUnselected,
                    width: 14,
                    height: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
