import 'dart:async';
import 'dart:math' as math;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class _LogoutText {
  static const header = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -.45,
    color: Colors.black,
  );
  static const title = TextStyle(
    inherit: false,
    fontFamily: 'PretendardDetail',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -.6,
    color: AppColors.text,
    height: 1.6,
  );
  static const description = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -.4,
    color: AppColors.subtle,
    height: 1.5,
  );
  static const button = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 22 / 16,
  );
}

class LogoutConfirmationScreen extends StatelessWidget {
  const LogoutConfirmationScreen({
    required this.onConfirm,
    required this.onCancel,
    this.busy = false,
    super.key,
  });

  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) onCancel();
      },
      child: PhoneFrame(
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, safe) => Column(
                children: [
                  _LogoutHeader(onBack: busy ? null : onCancel),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, viewport) => SizedBox(
                        key: const ValueKey('logout-body'),
                        width: double.infinity,
                        child: SingleChildScrollView(
                          key: const ValueKey('logout-scroll'),
                          child: _LogoutBodyLayout(
                            minHeight: viewport.maxHeight,
                            imageTop: safe.maxHeight / 2 - 8 - 64 - 112,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '정말 로그아웃 하시겠어요?',
                                    key: ValueKey('logout-title'),
                                    style: _LogoutText.title,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '기기에 저장된 로그인 정보가 삭제됩니다.',
                                    key: ValueKey('logout-description'),
                                    style: _LogoutText.description,
                                  ),
                                ],
                              ),
                              Image.asset(
                                'assets/figma/logout-illustration.png',
                                key: const ValueKey('logout-illustration'),
                                width: 224,
                                height: 224,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    key: const ValueKey('logout-footer'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LogoutButton(
                          key: const ValueKey('logout-confirm'),
                          label: '확인',
                          primary: true,
                          onPressed: busy ? null : () => unawaited(onConfirm()),
                        ),
                        const SizedBox(height: 8),
                        _LogoutButton(
                          key: const ValueKey('logout-cancel'),
                          label: '취소',
                          primary: false,
                          onPressed: busy ? null : onCancel,
                        ),
                      ],
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
}

class _LogoutHeader extends StatelessWidget {
  const _LogoutHeader({required this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('logout-header'),
    height: 64,
    child: Stack(
      children: [
        const Positioned.fill(
          left: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text('계정 관리', style: _LogoutText.header),
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
              key: const ValueKey('logout-back-hit'),
              onTap: onBack,
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SvgPicture.asset(
                    Assets.detailBack,
                    key: const ValueKey('logout-back-image'),
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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.label,
    required this.primary,
    required this.onPressed,
    super.key,
  });
  final String label;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: primary ? AppColors.text : Colors.white,
        disabledBackgroundColor: primary ? AppColors.text : Colors.white,
        foregroundColor: primary ? AppColors.main : AppColors.text,
        disabledForegroundColor: primary ? AppColors.main : AppColors.text,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: primary
            ? BorderSide.none
            : const BorderSide(color: AppColors.subtle),
        elevation: 0,
      ),
      child: Text(
        label,
        style: _LogoutText.button.copyWith(
          color: primary ? AppColors.main : AppColors.text,
        ),
      ),
    ),
  );
}

// Measure the real text before placing the illustration. This preserves its
// safe-area center on normal screens and grows the scroll body on low screens.
class _LogoutBodyLayout extends MultiChildRenderObjectWidget {
  const _LogoutBodyLayout({
    required this.minHeight,
    required this.imageTop,
    required super.children,
  });
  final double minHeight;
  final double imageTop;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLogoutBodyLayout(minHeight, imageTop);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLogoutBodyLayout renderObject,
  ) {
    renderObject.update(minHeight, imageTop);
  }
}

class _LogoutParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderLogoutBodyLayout extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _RenderLogoutBodyLayout(this._minHeight, this._imageTop);
  double _minHeight;
  double _imageTop;

  void update(double minHeight, double imageTop) {
    if (_minHeight == minHeight && _imageTop == imageTop) return;
    _minHeight = minHeight;
    _imageTop = imageTop;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LogoutParentData) {
      child.parentData = _LogoutParentData();
    }
  }

  @override
  void performLayout() {
    final heading = firstChild!, image = childAfter(heading)!;
    final width = constraints.maxWidth;
    heading.layout(
      BoxConstraints(maxWidth: math.max(0, width - 32)),
      parentUsesSize: true,
    );
    image.layout(
      const BoxConstraints.tightFor(width: 224, height: 224),
      parentUsesSize: true,
    );
    final minImageTop = 16 + heading.size.height + 16;
    size = constraints.constrain(
      Size(width, math.max(_minHeight, minImageTop + 224 + 24)),
    );
    (heading.parentData! as ContainerBoxParentData<RenderBox>).offset =
        const Offset(16, 16);
    (image.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset(
      (width - 224) / 2 + .5,
      _imageTop.clamp(minImageTop, size.height - 224 - 24),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
