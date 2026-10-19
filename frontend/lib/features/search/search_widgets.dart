import 'dart:math' as math;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchTextStyles {
  static const input = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    textBaseline: TextBaseline.alphabetic,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    height: 1.4,
    color: AppColors.text,
  );
  static final hint = input.copyWith(color: AppColors.subSubtle);
  static const cancel = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.375,
    color: Color(0xFF595959),
  );
  static const historyHeading = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.375,
    color: Color(0xFF121212),
  );
  static const history = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: AppColors.subtle,
  );
  static const emptyTitle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.4,
    color: AppColors.middle,
  );
  static const emptyBody = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    height: 1.6,
    color: AppColors.subtle,
  );
  static const emptyAction = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.4,
    color: AppColors.text,
  );
}

class SearchInputBar extends StatelessWidget {
  const SearchInputBar({
    required this.controller,
    required this.autofocus,
    required this.hasQuery,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onClose,
    super.key,
  });

  final TextEditingController controller;
  final bool autofocus;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('search-header'),
    height: 76,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        key: const ValueKey('search-row'),
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Container(
                key: const ValueKey('search-input-box'),
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      hasQuery ? Assets.searchInput : Assets.searchHint,
                      key: const ValueKey('search-input-icon'),
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('search-input'),
                        controller: controller,
                        autofocus: autofocus,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        maxLines: 1,
                        textAlignVertical: TextAlignVertical.center,
                        style: SearchTextStyles.input,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: '찾고 싶은 정보를 검색해보세요',
                          hintStyle: SearchTextStyles.hint,
                        ),
                      ),
                    ),
                    if (hasQuery)
                      GestureDetector(
                        key: const ValueKey('search-clear'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onClear,
                        child: SvgPicture.asset(
                          Assets.xCircle,
                          width: 18,
                          height: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              key: const ValueKey('search-cancel'),
              width: 44,
              height: 44,
              child: TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('취소', style: SearchTextStyles.cancel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({required this.onOpenArchive, super.key});
  final VoidCallback onOpenArchive;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: const ValueKey('search-empty-viewport'),
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _SearchEmptyLayout(
        viewportHeight: constraints.maxHeight,
        child: ConstrainedBox(
          key: const ValueKey('search-empty-group'),
          constraints: const BoxConstraints(maxWidth: 260),
          child: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: const ValueKey('search-empty-image'),
                  width: 81,
                  height: 123,
                  child: Image.asset(
                    Assets.searchEmptyIllustration,
                    key: const ValueKey('search-empty-image-source'),
                    excludeFromSemantics: true,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '검색 결과가 없어요',
                  key: ValueKey('search-empty-title'),
                  textAlign: TextAlign.center,
                  style: SearchTextStyles.emptyTitle,
                ),
                const SizedBox(height: 8),
                const Text(
                  '핵심 키워드 위주로 검색해 주세요',
                  key: ValueKey('search-empty-body'),
                  textAlign: TextAlign.center,
                  style: SearchTextStyles.emptyBody,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 35),
                  child: Container(
                    key: const ValueKey('search-empty-cta'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    foregroundDecoration: BoxDecoration(
                      border: Border.all(color: AppColors.subtler),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: onOpenArchive,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                Assets.bookmarkBookOpen,
                                key: const ValueKey('search-empty-cta-icon'),
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 4),
                              const Flexible(
                                child: Text(
                                  '전체 리스트 보기',
                                  style: SearchTextStyles.emptyAction,
                                ),
                              ),
                            ],
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
      ),
    ),
  );
}

class _SearchEmptyLayout extends SingleChildRenderObjectWidget {
  const _SearchEmptyLayout({
    required this.viewportHeight,
    required super.child,
  });
  final double viewportHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSearchEmptyLayout(viewportHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSearchEmptyLayout renderObject,
  ) => renderObject.viewportHeight = viewportHeight;
}

class _RenderSearchEmptyLayout extends RenderShiftedBox {
  _RenderSearchEmptyLayout(this._viewportHeight) : super(null);
  double _viewportHeight;

  set viewportHeight(double value) {
    if (_viewportHeight == value) return;
    _viewportHeight = value;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childSize = child!.getDryLayout(constraints.loosen());
    return constraints.constrain(
      Size(constraints.maxWidth, math.max(_viewportHeight, childSize.height)),
    );
  }

  @override
  void performLayout() {
    child!.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(
      Size(constraints.maxWidth, math.max(_viewportHeight, child!.size.height)),
    );
    final freeHeight = size.height - child!.size.height;
    (child!.parentData! as BoxParentData).offset = Offset(
      (size.width - child!.size.width) / 2,
      (freeHeight / 2 - 92.5).clamp(0.0, freeHeight),
    );
  }
}
