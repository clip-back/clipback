/// Notices (#420, #486): the list shows `GET /notices`; the two pinned usage
/// guides below are the list until an answer arrives, and the home card's guide.
class NoticeStep {
  const NoticeStep({required this.title, required this.body, this.note});

  final String title;
  final String body;

  /// The smaller follow-up paragraph under [body], when the step has one.
  final String? note;
}

class Notice {
  const Notice({
    required this.title,
    required this.publishedLabel,
    required this.pinned,
    required this.introTitle,
    required this.intro,
    required this.steps,
    required this.closingTitle,
    required this.closing,
  });

  final String title;

  /// Shown as is, in the content detail date format.
  final String publishedLabel;
  final bool pinned;
  final String introTitle;
  final String intro;
  final List<NoticeStep> steps;
  final String closingTitle;
  final String closing;
}

const noticeFooter = '사용 중 궁금한 점은 마이의 문의하기로 알려주세요.';

// Figma 423:4520. STEP 03 drops "전문 보기를 펼치거나" and STEP 05 spells
// "랜덤 보기" as the app does (#420 Q8).
const usageGuideNotice = Notice(
  title: '허투루 100% 활용법',
  publishedLabel: '2026. 11. 23',
  pinned: true,
  introTitle: '저장한 정보, 다시 꺼내 쓰세요.',
  intro:
      '나중에 보려고 모아둔 링크와 사진.\n'
      '허투루에서 정리하고, 필요한 순간에 다시 발견해 보세요.',
  steps: [
    NoticeStep(
      title: '링크와 사진을 저장해요',
      body:
          '화면 아래의 + 버튼을 누르고 링크 첨부 또는 사진 첨부를 선택해 주세요. '
          '내용을 확인한 뒤 저장하면 나만의 아카이브에 모을 수 있어요.',
      note: '다른 앱에서 발견한 링크는 공유하기 메뉴에서 허투루로 보낼 수도 있어요.',
    ),
    NoticeStep(
      title: '카테고리로 정리하고 찾아요',
      body:
          '아카이브에서 카테고리별로 저장한 콘텐츠를 살펴보세요. '
          '이름과 색상을 정해두면 원하는 정보를 더 쉽게 찾을 수 있어요.',
      note: '카테고리가 정해지지 않은 콘텐츠는 ‘분류가 필요한 콘텐츠’에서 확인해 주세요.',
    ),
    NoticeStep(
      title: '요약으로 훑고, 원문으로 읽어요',
      body:
          '저장한 콘텐츠를 열어 핵심 내용을 확인해 보세요. '
          '더 자세히 읽고 싶다면 원본 링크로 이동하면 돼요.',
      note: '요약이 만들어지는 동안에는 안내 문구가 표시돼요. 실패한 경우에는 다시 시도할 수 있어요.',
    ),
    NoticeStep(
      title: '다시 볼 콘텐츠는 즐겨찾기해요',
      body:
          '중요하거나 자주 참고하는 콘텐츠의 별 아이콘을 눌러보세요. '
          '즐겨찾기 탭에서 따로 모아볼 수 있어요.',
    ),
    NoticeStep(
      title: '잊고 있던 콘텐츠를 다시 발견해요',
      body:
          '홈의 ‘오늘의 콘텐츠 보기’로 저장해 둔 정보를 다시 만나보세요. '
          '아카이브의 랜덤 보기로 하나씩 꺼내보는 방법도 있어요.',
    ),
  ],
  closingTitle: '오늘은 하나만 꺼내볼까요?',
  closing: '저장만 해두었던 콘텐츠 하나를 골라 읽어보세요. 작은 재발견이 쌓이면 나만의 정보가 됩니다.',
);

// Figma 425:4491. STEP 03 drops "전문 보기를 펼치거나" (#420 Q8).
const firstTimeNotice = Notice(
  title: '허투루 사용이 처음이라면?',
  publishedLabel: '2026. 11. 23',
  pinned: true,
  introTitle: '처음이라면, 하나만 저장해 보세요.',
  intro:
      '링크 하나를 저장하고 다시 열어보는 것부터 시작해 보세요. '
      '허투루의 기본 흐름을 차근차근 안내할게요.',
  steps: [
    NoticeStep(
      title: '저장할 링크나 사진을 준비해요',
      body:
          '나중에 다시 보고 싶은 글이나 영상을 발견했나요? '
          '링크를 복사하거나 저장할 사진을 준비해 주세요.',
      note: '다른 앱의 공유하기 메뉴에서 허투루를 선택해 시작할 수도 있어요.',
    ),
    NoticeStep(
      title: '+ 버튼으로 첫 콘텐츠를 저장해요',
      body:
          '화면 아래의 + 버튼을 누르고 링크 첨부 또는 사진 첨부를 선택해 주세요. '
          '미리보기와 카테고리를 확인한 뒤 저장해 주세요.',
      note:
          '정보를 확인하는 중이라면 잠시 기다려 주세요. '
          '사진에서 정보를 찾지 못할 때는 다른 사진으로 시도해 보세요.',
    ),
    NoticeStep(
      title: '아카이브에서 다시 열어봐요',
      body:
          '아카이브로 이동하면 저장한 콘텐츠를 찾을 수 있어요. '
          '콘텐츠를 눌러 내용을 열고, 요약으로 먼저 훑어보세요.',
      note: '자세히 읽으려면 원본 링크로 이동해 주세요.',
    ),
    NoticeStep(
      title: '마음에 드는 콘텐츠에 별을 눌러요',
      body:
          '다시 참고하고 싶은 콘텐츠라면 별 아이콘을 눌러 즐겨찾기에 모아두세요. '
          '즐겨찾기 탭에서 빠르게 찾을 수 있어요.',
    ),
    NoticeStep(
      title: '찾고 싶은 정보는 검색해요',
      body:
          '저장한 콘텐츠가 많아졌다면 검색을 이용해 보세요. '
          '기억나는 단어를 입력해 필요한 콘텐츠를 찾아볼 수 있어요.',
    ),
  ],
  closingTitle: '첫 번째 저장을 마쳤나요?',
  closing: '이제 저장한 콘텐츠를 하나 열어보세요. 저장하고, 다시 찾고, 읽는 경험을 허투루와 함께 시작해 보세요.',
);

/// The list before (or without) a server answer, in this order (#486 decision 4).
const notices = [usageGuideNotice, firstTimeNotice];

/// Reads a `GET /notices` answer; any rule break rejects the whole answer.
List<Notice> noticesFromJson(Object? json) {
  final items = _list(_object(json)['notices']);
  if (items.isEmpty) _bad();
  return [for (final item in items) _notice(_object(item))];
}

Never _bad() => throw const FormatException('Malformed notices response');
Map _object(Object? value) => value is Map ? value : _bad();
List _list(Object? value) => value is List ? value : _bad();
String _text(Map item, String key) {
  final value = item[key];
  return value is String && value.isNotEmpty ? value : _bad();
}

Notice _notice(Map item) {
  final pinned = item['pinned'];
  return Notice(
    title: _text(item, 'title'),
    publishedLabel: _dateLabel(_text(item, 'published_on')),
    pinned: pinned is bool ? pinned : _bad(),
    introTitle: _text(item, 'intro_title'),
    intro: _text(item, 'intro'),
    steps: [for (final step in _list(item['steps'])) _step(_object(step))],
    closingTitle: _text(item, 'closing_title'),
    closing: _text(item, 'closing'),
  );
}

NoticeStep _step(Map step) {
  // The key is required; only its value may be null.
  if (!step.containsKey('note')) _bad();
  final note = step['note'];
  return NoticeStep(
    title: _text(step, 'title'),
    body: _text(step, 'body'),
    note: note == null || note is String ? note as String? : _bad(),
  );
}

/// `2026-11-23` -> `2026. 11. 23`; anything but a real calendar day is rejected.
String _dateLabel(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) _bad();
  final [y, m, d] = [for (var i = 1; i <= 3; i++) int.parse(match[i]!)];
  final day = DateTime.utc(y, m, d);
  // Year 0000 is no calendar day for the server either.
  if (y < 1 || day.year != y || day.month != m || day.day != d) _bad();
  return '${match[1]}. ${match[2]}. ${match[3]}';
}
