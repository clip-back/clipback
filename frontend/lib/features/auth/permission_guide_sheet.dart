import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:flutter/material.dart';

/// A local explanation only. Confirming this sheet does not grant OS access.
class PermissionGuideSheet extends StatelessWidget {
  const PermissionGuideSheet({required this.onContinue, super.key});

  final VoidCallback onContinue;

  static const _titleStyle = TextStyle(
    inherit: false,
    fontFamily: 'PretendardDetail',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -.45,
    color: AppColors.text,
    height: 1.6,
  );
  static const _descriptionStyle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -.35,
    color: AppColors.subtle,
    height: 1.5,
  );
  static const _nameStyle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -.4,
    color: AppColors.text,
  );
  static const _optionalStyle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -.4,
    color: Color(0xFFC5A544),
  );
  static const _buttonStyle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.main,
    height: 22 / 16,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final bottom = media.viewPadding.bottom;
      final available = math.max(
        0.0,
        math.min(
          constraints.maxHeight,
          media.size.height - media.viewPadding.top,
        ),
      );
      return Container(
        key: const ValueKey('permission-guide-panel'),
        width: double.infinity,
        height: math.min(460 + bottom, available),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('permission-guide-scroll'),
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 135),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '허투루를 더 편하게 이용하려면\n다음 권한이 필요해요',
                                key: ValueKey('permission-guide-title'),
                                style: _titleStyle,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '허용하지 않아도 기본 서비스 이용은 가능해요.',
                                key: ValueKey('permission-guide-description'),
                                style: _descriptionStyle,
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 80),
                          child: const Align(
                            alignment: Alignment.topLeft,
                            child: _PermissionRow(
                              index: 0,
                              title: '알림 권한',
                              detail: '콘텐츠를 다시 볼 수 있도록 알림을 보내드려요.',
                            ),
                          ),
                        ),
                        const _PermissionRow(
                          index: 1,
                          title: '사진 권한',
                          detail: '스크린샷이나 이미지를 첨부할 때 필요해요.',
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  key: const ValueKey('permission-guide-footer'),
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 32 + bottom),
                  child: Semantics(
                    button: true,
                    child: Material(
                      color: AppColors.text,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: const ValueKey('permission-guide-continue-hit'),
                        onTap: onContinue,
                        borderRadius: BorderRadius.circular(8),
                        child: const SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              '계속하기',
                              key: ValueKey('permission-guide-continue-label'),
                              style: _buttonStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  key: const ValueKey('permission-guide-handle'),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.subtler,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.index,
    required this.title,
    required this.detail,
  });
  final int index;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    key: ValueKey('permission-guide-row-$index'),
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        key: ValueKey('permission-guide-icon-$index'),
        width: 42,
        height: 42,
        child: ClipRect(
          key: ValueKey('permission-guide-icon-$index-clip'),
          child: Stack(
            children: [
              Positioned(
                left: -42 * (index == 0 ? .0296 : .0554),
                top: -42 * (index == 0 ? .035 : .0554),
                width: 42 * (index == 0 ? 1.0591 : 1.1109),
                height: 42 * (index == 0 ? 1.07 : 1.1109),
                child: Image.asset(
                  index == 0
                      ? 'assets/figma/permission-b01-notification.png'
                      : 'assets/figma/permission-b01-photo.png',
                  key: ValueKey('permission-guide-icon-$index-source'),
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  key: ValueKey('permission-guide-name-$index'),
                  style: PermissionGuideSheet._nameStyle,
                ),
                Text(
                  '(선택)',
                  key: ValueKey('permission-guide-optional-$index'),
                  style: PermissionGuideSheet._optionalStyle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              key: ValueKey('permission-guide-detail-$index'),
              style: PermissionGuideSheet._descriptionStyle,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Keep native bottom-sheet dismissal/drag semantics and blur its barrier once.
class PermissionGuideRoute extends ModalBottomSheetRoute<bool> {
  PermissionGuideRoute({
    required BuildContext context,
    required WidgetBuilder builder,
  }) : super(
         // ModalBottomSheetRoute removes top padding (and viewPadding). Restore
         // the actual window metrics without adding another SafeArea.
         builder: (sheetContext) => MediaQuery(
           data: MediaQuery.of(context),
           child: builder(sheetContext),
         ),
         isScrollControlled: true,
         isDismissible: true,
         enableDrag: true,
         showDragHandle: false,
         useSafeArea: false,
         elevation: 0,
         backgroundColor: Colors.white,
         shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
         ),
         clipBehavior: Clip.antiAlias,
         constraints: const BoxConstraints(maxWidth: phoneWidth),
         modalBarrierColor: Colors.black.withValues(alpha: .5),
         barrierLabel: MaterialLocalizations.of(
           context,
         ).modalBarrierDismissLabel,
         capturedThemes: InheritedTheme.capture(
           from: context,
           to: Navigator.of(context).context,
         ),
       );

  @override
  Widget buildModalBarrier() => BackdropFilter(
    key: const ValueKey('permission-guide-backdrop'),
    filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
    child: super.buildModalBarrier(),
  );
}
