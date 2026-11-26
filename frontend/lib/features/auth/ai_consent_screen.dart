import 'dart:async';

import 'package:clipback_frontend/features/account/contact_form.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/notice_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const aiConsentPolicyFailureMessage = '개인정보처리방침을 열지 못했어요. 다시 시도해 주세요.';

abstract final class _ConsentText {
  static const header = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.text,
  );
  static const title = TextStyle(
    inherit: false,
    fontFamily: 'PretendardDetail',
    fontSize: 25,
    fontWeight: FontWeight.w700,
    height: 1.55,
    color: AppColors.text,
  );
  static const heading = TextStyle(
    inherit: false,
    fontFamily: 'PretendardDetail',
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 1.55,
    color: AppColors.text,
  );
  static const label = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.55,
    color: AppColors.text,
  );
  static const field = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.55,
    color: AppColors.text,
  );
  static const body = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.text,
  );
  static const link = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.55,
    color: AppColors.text,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.text,
  );
  static const button = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
  );
}

/// AI 전송 동의 shown before the first screen (Figma 486:5085, #474). Only
/// the body scrolls; the two choices stay in the fixed area below it.
class AiConsentScreen extends StatefulWidget {
  const AiConsentScreen({
    required this.saving,
    required this.onAgree,
    required this.onDeny,
    required this.onClose,
    this.openPolicy = openPrivacyPolicy,
    super.key,
  });

  /// While a choice is saved both buttons and ✕ are locked.
  final bool saving;
  final VoidCallback onAgree;
  final VoidCallback onDeny;
  final VoidCallback onClose;
  final Future<bool?> Function() openPolicy;

  @override
  State<AiConsentScreen> createState() => _AiConsentScreenState();
}

class _AiConsentScreenState extends State<AiConsentScreen> {
  /// A choice was tapped and the screen has not rebuilt since: the saving
  /// state it holds may be a frame old, so it is locked meanwhile.
  bool _chosen = false;

  @override
  void didUpdateWidget(covariant AiConsentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _chosen = false;
  }

  VoidCallback _choose(VoidCallback save) => () {
    _chosen = true;
    save();
  };

  Future<void> _openPolicy() async {
    // A late failure is shown only while this screen (this account's) stays.
    // Only over this screen itself, not over '자세히 보기' opened meanwhile.
    if (await widget.openPolicy() == false &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(noticeSnackBar(context, aiConsentPolicyFailureMessage));
    }
  }

  void _openDetail() {
    // While saving the screen may leave at any moment; it opens nothing.
    if (widget.saving || _chosen) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AiConsentDetailScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.saving || _chosen;
    return PhoneFrame(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _ConsentHeader(
                title: 'AI 전송 동의',
                onClose: locked ? null : widget.onClose,
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('ai-consent-scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: const Text(
                          'AI 전송에 동의하시겠어요?',
                          key: ValueKey('ai-consent-title'),
                          style: _ConsentText.title,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '저장한 콘텐츠를 분석하고 정리하기 위해 아래 정보를 국외의 AI 업체로 전송해요. '
                        '동의하지 않아도 저장할 수 있지만 요약과 자동 분류는 제공되지 않아요. '
                        '선택은 계정 관리에서 언제든 바꿀 수 있어요.',
                        style: _ConsentText.body,
                      ),
                      for (final (label, value) in _summary) ...[
                        const SizedBox(height: 24),
                        Text(label, style: _ConsentText.label),
                        const SizedBox(height: 6),
                        Text(value, style: _ConsentText.body),
                      ],
                      const SizedBox(height: 24),
                      _ConsentLink(
                        key: const ValueKey('ai-consent-detail-link'),
                        label: '자세히 보기',
                        onTap: locked ? null : _openDetail,
                      ),
                      _ConsentLink(
                        key: const ValueKey('ai-consent-policy-link'),
                        label: '개인정보처리방침 보기',
                        onTap: () => unawaited(_openPolicy()),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                key: const ValueKey('ai-consent-footer'),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ConsentButton(
                      key: const ValueKey('ai-consent-deny'),
                      label: '동의하지 않음',
                      height: 48,
                      primary: false,
                      onPressed: locked ? null : _choose(widget.onDeny),
                    ),
                    const SizedBox(height: 16),
                    _ConsentButton(
                      key: const ValueKey('ai-consent-agree'),
                      label: '동의하고 계속',
                      height: 56,
                      primary: true,
                      onPressed: locked ? null : _choose(widget.onAgree),
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

/// 제28조의8 제2항 in summary: 1호 items, 2·3호 recipients and countries,
/// 4호 purpose and retention. 5호 is the description and "동의하지 않음".
const _summary = [
  ('보내는 정보', '저장한 링크(제목·설명·게시물 글·대표 이미지 포함), 함께 공유한 글, 선택한 사진, 내 카테고리 이름'),
  ('받는 업체와 국가', 'OpenAI(미국) · Google Gemini(미국 등)'),
  ('이용 목적', '콘텐츠 분석 · 요약 · 카테고리 추천 · 태그'),
  ('보관 기간', 'OpenAI 최대 30일 · Google Gemini 55일 (남용 방지 기록)'),
];

/// '자세히 보기' (Figma 486:5281): the full 제2항 text in the app, without
/// network. Closing returns to the consent screen and changes no choice.
class AiConsentDetailScreen extends StatelessWidget {
  const AiConsentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => PhoneFrame(
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _ConsentHeader(
              title: 'AI 전송 안내',
              onClose: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('ai-consent-detail-scroll'),
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, (heading, fields))
                        in _detail.indexed) ...[
                      if (index > 0) const SizedBox(height: 32),
                      Semantics(
                        header: true,
                        child: Text(heading, style: _ConsentText.heading),
                      ),
                      for (final (label, value) in fields) ...[
                        const SizedBox(height: 16),
                        if (label != null) ...[
                          Text(label, style: _ConsentText.field),
                          const SizedBox(height: 4),
                        ],
                        Text(value, style: _ConsentText.body),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Figma 486:4958, the confirmed text of 2026-11-24.
const _detail = <(String, List<(String?, String)>)>[
  (
    'OpenAI',
    [
      (
        '받는 곳',
        'OpenAI OpCo, LLC(1455 3rd Street, San Francisco, CA 94158, 미국), privacy@openai.com',
      ),
      ('국가', '미국'),
      (
        '보내는 정보',
        '링크 제목·설명·주소(인스타그램은 게시자 계정 이름, 좋아요·댓글 수, 게시 날짜가 포함될 수 있어요), '
            '콘텐츠 출처 종류, 공유한 글, 사진 원본과 사진 속 글자, 인스타그램 게시물 글과 대표 이미지, '
            '내 카테고리 번호·이름',
      ),
      ('보내는 때와 방법', '링크나 사진을 저장할 때와 저장한 뒤 요약할 때, 암호화된 연결(HTTPS)'),
      ('쓰는 목적', '사진 제목·요약, 인스타그램 요약, 카테고리·태그 추천'),
      (
        '보관 기간',
        '응답을 저장하지 않도록 요청하고 호출 기록을 꺼 두었어요. '
            'OpenAI 정책에 따라 남용 감시 기록은 최대 30일 보관될 수 있어요.',
      ),
    ],
  ),
  (
    'Google',
    [
      (
        '받는 곳',
        'Gemini API는 Google Cloud Korea LLC, YouTube Data API는 YouTube LLC'
            '(901 Cherry Ave., San Bruno, CA 94066, 미국). '
            '문의: https://support.google.com/policies?p=privpol_privts',
      ),
      ('국가', 'Google 데이터센터가 있는 국가(미국 등)'),
      (
        '보내는 정보',
        '유튜브 영상 주소(Gemini가 공개 영상의 화면과 음성을 분석해요), 영상 작성자가 쓴 제목·설명, '
            '내 카테고리 번호·이름. YouTube Data API에는 영상 ID만 보내요.',
      ),
      ('보내는 때와 방법', '유튜브 링크를 저장한 뒤 요약할 때, 암호화된 연결(HTTPS)'),
      ('쓰는 목적', '유튜브 영상 제목·요약, 카테고리·태그 추천, 영상 공개 여부 확인'),
      (
        '보관 기간',
        'Gemini API 요청 기록 저장을 꺼 두었어요. Google은 금지된 사용을 찾기 위해 요청과 응답을 55일 보관해요. '
            'YouTube Data API의 보관은 YouTube API 서비스 약관과 Google 정책을 따라요.',
      ),
    ],
  ),
  (
    'AI 전송과 별개로',
    [
      (
        null,
        '유튜브 외의 링크를 저장하면 서버가 그 주소로 접속해 공개된 제목과 설명을 읽어요. '
            '동의와 관계없이 동작하고, 내 IP 주소와 계정 정보는 보내지 않아요.',
      ),
    ],
  ),
  (
    '동의하지 않거나 바꾸고 싶을 때',
    [
      (null, '"동의하지 않음"을 누르거나, 계정 관리의 AI 전송 동의에서 언제든 바꿀 수 있어요.'),
      (null, '동의하지 않아도 링크와 사진은 저장돼요. 요약, 사진 글자 읽기, 카테고리·태그 추천은 제공되지 않아요.'),
      (
        null,
        '동의를 철회하면 새로 저장하는 콘텐츠와 아직 보내지 않은 작업은 전송하지 않아요. '
            '이미 보낸 정보는 위 보관 기간을 따라요.',
      ),
    ],
  ),
];

/// Top bar with ✕ only (Figma 487:5341): 64 high, a 44 touch area.
class _ConsentHeader extends StatelessWidget {
  const _ConsentHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Semantics(
          button: true,
          enabled: onClose != null,
          label: '닫기',
          onTap: onClose,
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('ai-consent-close'),
            onTap: onClose,
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/ai-consent-close.svg',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(child: Text(title, style: _ConsentText.header)),
      ],
    ),
  );
}

/// An underlined link in a 44-high touch area (Figma 486:4954).
class _ConsentLink extends StatelessWidget {
  const _ConsentLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: _ConsentText.link),
        ),
      ),
    ),
  );
}

class _ConsentButton extends StatelessWidget {
  const _ConsentButton({
    required this.label,
    required this.height,
    required this.primary,
    required this.onPressed,
    super.key,
  });

  final String label;
  final double height;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final background = primary ? AppColors.text : Colors.white;
    final foreground = primary ? AppColors.main : AppColors.text;
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background,
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: _ConsentText.button.copyWith(color: foreground),
        ),
      ),
    );
  }
}
