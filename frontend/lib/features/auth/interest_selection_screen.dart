import 'dart:async';

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _titleStyle = TextStyle(
  inherit: false,
  fontFamily: 'PretendardDetail',
  fontSize: 24,
  fontWeight: FontWeight.w700,
  letterSpacing: -.6,
  color: AppColors.text,
  height: 1.6,
);
const _descriptionStyle = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  fontSize: 16,
  fontWeight: FontWeight.w500,
  letterSpacing: -.4,
  color: AppColors.subtle,
  height: 1.5,
);
const _optionStyle = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  fontSize: 16,
  fontWeight: FontWeight.w500,
  letterSpacing: -.4,
  color: AppColors.text,
);
const _nextStyle = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  fontSize: 16,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  height: 22 / 16,
);
const _limitStyle = TextStyle(
  inherit: false,
  fontFamily: 'Pretendard',
  fontSize: 14,
  fontWeight: FontWeight.w500,
  letterSpacing: -.35,
  color: Color(0xFFFF3C40),
  height: 1.5,
);

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({
    required this.onBack,
    required this.onDone,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final Set<String> _selected = {};
  Timer? _limitTimer;
  bool _showLimit = false;

  void _toggle(String option) {
    _limitTimer?.cancel();
    if (!_selected.contains(option) && _selected.length == 3) {
      setState(() => _showLimit = true);
      _limitTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showLimit = false);
      });
      return;
    }
    setState(() {
      _showLimit = false;
      if (!_selected.remove(option)) _selected.add(option);
    });
  }

  @override
  void dispose() {
    _limitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _selected.isNotEmpty;
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SizedBox(
                  key: const ValueKey('interest-body'),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    key: const ValueKey('interest-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '주로 어떤 정보를\n저장하고 싶으신가요?',
                          key: ValueKey('interest-title'),
                          style: _titleStyle,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '최대 3개까지 선택해 주세요.',
                          key: ValueKey('interest-description'),
                          style: _descriptionStyle,
                        ),
                        const SizedBox(height: 31.2),
                        Column(
                          key: const ValueKey('interest-options'),
                          children: [
                            for (
                              var i = 0;
                              i < mockInterestOptions.length;
                              i++
                            ) ...[
                              if (i > 0) const SizedBox(height: 8),
                              InterestOptionTile(
                                label: mockInterestOptions[i],
                                selected: _selected.contains(
                                  mockInterestOptions[i],
                                ),
                                onTap: () => _toggle(mockInterestOptions[i]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                key: const ValueKey('interest-footer'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      key: const ValueKey('interest-limit-slot'),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Visibility(
                        visible: _showLimit,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 21),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/figma/interest-alert.svg',
                                key: const ValueKey('interest-limit-icon'),
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 4),
                              const Flexible(
                                child: Text(
                                  '최대 3개까지만 선택 가능해요',
                                  key: ValueKey('interest-limit-message'),
                                  textAlign: TextAlign.center,
                                  style: _limitStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('interest-next'),
                        onPressed: enabled ? widget.onDone : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.text,
                          foregroundColor: AppColors.main,
                          disabledBackgroundColor: AppColors.subtler,
                          disabledForegroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '다음',
                          style: _nextStyle.copyWith(
                            color: enabled ? AppColors.main : Colors.white,
                          ),
                        ),
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

class InterestOptionTile extends StatelessWidget {
  const InterestOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final index = mockInterestOptions.indexOf(label);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          key: ValueKey('interest-option-$index'),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: _optionStyle)),
              const SizedBox(width: 8),
              Container(
                key: ValueKey('interest-circle-$index'),
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.text : AppColors.subtler,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  selected
                      ? 'assets/figma/interest-check-selected.svg'
                      : 'assets/figma/interest-check-unselected.svg',
                  key: ValueKey('interest-check-$index'),
                  width: 14,
                  height: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const mockInterestOptions = [
  '직장/자기개발',
  '뷰티/패션',
  '여행/장소',
  '인문/지식',
  '요리/식품',
  '경제/시사',
];
