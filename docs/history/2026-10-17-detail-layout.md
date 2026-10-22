# 상세 화면 표현

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-db79d84869b3c657"></a>

### 콘텐츠 상세 화면의 1배율 표현 맞춤 — 2026-10-17

<a id="b-9c990d533d2a3a20"></a>

`bff0a7c` 기준으로 Page 1 > `261007`의 F02 기본(`111:3842`)·F03 전문 펼침(`111:3771`)·F04 연관 없음(`111:3909`)을 대조했다. 완료 범위는 상세의 흰 배경·상단·기본 글자·태그·카테고리와 연관 카드이며 실제 원문/미디어·추천 API 연결이나 상세 전체 기능 완료를 뜻하지 않는다.

<a id="b-550eb7a85f334610"></a>

사용자 확정으로 제목·요약의 3줄 제한/요약72px 고정을 제거해 전체 내용을 표시한다. 상단에는 실제 소속을 모두 Wrap8/8로 표시하고 연관 카드는 소속1개면 한 행, 2개 이상이면 배지 위/제목 아래8px으로 높이를 늘린다. ‘함께 보면 좋은 콘텐츠’와 범위를 명시한 ‘불러온 목록에 연관 콘텐츠가 없어요.’를 적용하고 미연결 추천을 약속하는 보조 문구는 추가하지 않는다.

<a id="b-50beca1a2a20af37"></a>

- [Figma 조회 원본과 시각](/private/tmp/clipback-detail-alignment-20261017/figma/reference-manifest.json): 2026-10-17 **07:18:07~07:18:13 UTC / 16:18:07~16:18:13 KST**, 컨텍스트에 원본을 포함해3회 성공했다. 별도 스크린샷/메타데이터 재호출·보관본 fallback·누락은0이다.
- 실제 Pretendard·iOS/Android 테마 × 폭320/375px ×1배율의 새 검사16건은 수정 전4통과/12목표 실패를 재현한 뒤 **16통과**했다. [자동 검사](/private/tmp/clipback-detail-alignment-20261017/automatic-checks.json): 관련 **355건**(24.38초)·전체 **987건**(49.71초) 통과, 건너뜀0, `flutter analyze --no-pub` 문제0건(5.25초)이다. 기존 확대/저장 자동 검사를 삭제하거나 건너뛰지 않았다.
- [수정 전 게이트](/private/tmp/clipback-detail-alignment-20261017/before-gate.json) 통과 뒤 제품을 수정했다. 최종 fixture `dafe10b8c3dfd7e0c9f91e31ab07335f7cf293e6813603c5b915b5aa984699a2`와 새 검사 `910d87eb066c9bb083c86b8dc4ed1ebf36b3484bd32f2749a5604ad92632cada`는 전후 동일하다. 초기 무한 폭 JSON 진단·기대색/커버리지 보완 이전의 시도는 `.attempts/`에 보존하고 최종 비교에서 제외했다.
- 양 플랫폼에서 ios 28기록 / android-gesture 28기록, 프레임워크 오류0건이며 `stylePassed`·`layoutPassed`·`behaviorPassed`·`coveragePassed`·`checksCompleted`·전체 `passed: true`다. 각 상태의 스크롤0/고정 위치/최대 스크롤 기록을 합쳐 실제 역할·복수 소속·연관 카드2개와 실제 세로 순서의 누락도 검사했다.
- 펼침/접기·원문 시트/URL/닫기·북마크 상태·분류 변경·연관 제목 스크롤/카드 이동·이전/다음·저장 진입 후 추가 저장 없는 닫기·네 탭·뒤로가기를 합성 포인터로 실제 위젯에서 확인했다. 사진 inline/시트의 원본 bytes·contain·로컬 콜백1회와 캐시 재사용은 **로컬 `onReadAsset` 콜백** 검증이며 실제 HTTP 다운로드나 운영 서버·OAuth·실기기 증거가 아니다.

<a id="b-5d46be05446c0c12"></a>

- 검증 종료 시 [정리 기록](/private/tmp/clipback-detail-alignment-20261017/cleanup-verification.json)으로 양쪽 앱·기기 종료, Android 포워딩 제거·기존 제스처 설정 일치/설정 변경0을 확인했다. 이번 비교 서버는 시작하지 않았다.
- [HTML 정적 검사](/private/tmp/clipback-detail-alignment-20261017/comparison-html-verification.json)의 로컬 참조54개와 JavaScript 문법은 통과했다. 브라우저 자동화는 `kernel assets` 파일 누락으로 초기화에 실패하여 HTML의 브라우저 렌더는 미검증이다. 실제 기기 원본·3열 PNG·네이티브 동작 결과와 구분한다.

<a id="b-73011f33e673f99f"></a>

- 기존 전역 Pretendard400/500/600 등록은 유지하고 공식1.3.9의 실제 Bold700을 상세 제목 전용 `PretendardDetail` 별칭으로 등록했다. [글꼴 출처/메타데이터](/private/tmp/clipback-detail-alignment-20261017/font-provenance.json)·[원본 에셋/양 플랫폼 번들/슬롯 검사](/private/tmp/clipback-detail-alignment-20261017/static-assets-verification.json)에 원본 back/more/link3개와 재사용 star/chevron의 검증을 기록했다. 라이선스도 번들에 포함했다. 최종 공백 검사에서 공식 라이선스22행의 행 끝 공백1개만 제거했으며, 촬영 번들과의 차이는 이 비표시 공백뿐이고 라이선스 본문·제품 렌더는 동일하다.
- [보존 검사](/private/tmp/clipback-detail-alignment-20261017/preservation-audit.json)에서 공개 생성자6개·사진 원본 controller/view/시트·선정 필터·mapper·공통 테마/배지/태그의 보존을 확인했다. 기존 회귀 검사는 상세 전용 아이콘 selector만 새 에셋에 연결하고 요청/인증/실패 복원·콜백 기대는 유지했다.

<a id="b-65de479a6610fc2b"></a>

[새 비교 8쌍](/private/tmp/clipback-detail-alignment-20261017/comparison-document.html) · [비교/조건 QA](/private/tmp/clipback-detail-alignment-20261017/pair-verification.json) · [영상 전체 디코딩 검사](/private/tmp/clipback-detail-alignment-20261017/media-verification.json) · [환경 정리](/private/tmp/clipback-detail-alignment-20261017/cleanup-verification.json)

<a id="b-d5a6a9c4ce47d823"></a>

| 상태·위치 | iPhone 16 / iOS 18.6 | Android 13 / API 33 제스처 |
| --- | --- | --- |
| 기본·스크롤0 | [3열 비교](/private/tmp/clipback-detail-alignment-20261017/comparisons/ios-detail_basic_scale_1_top.png) | [3열 비교](/private/tmp/clipback-detail-alignment-20261017/comparisons/android-gesture-detail_basic_scale_1_top.png) |
| 전문 펼침·스크롤0 | [3열 비교](/private/tmp/clipback-detail-alignment-20261017/comparisons/ios-detail_expanded_scale_1_top.png) | [3열 비교](/private/tmp/clipback-detail-alignment-20261017/comparisons/android-gesture-detail_expanded_scale_1_top.png) |
| 연관 없음·스크롤0 | [3열 비교](/private/tmp/clipback-detail-alignment-20261017/comparisons/ios-detail_empty_scale_1_top.png) | [3열 비교](/private/tmp/clipback-detail-alignment-20261017/comparisons/android-gesture-detail_empty_scale_1_top.png) |
| 전문 펼침·고정 위치 | [3열 비교](/private/tmp/clipback-detail-alignment-20261017/comparisons/ios-detail_expanded_scale_1_lower.png) | [3열 비교](/private/tmp/clipback-detail-alignment-20261017/comparisons/android-gesture-detail_expanded_scale_1_lower.png) |

<a id="b-2c7cafe694f92d0b"></a>

[iOS 동작 영상](/private/tmp/clipback-detail-alignment-20261017/ios/after/interaction.mp4) · [Android 동작 영상](/private/tmp/clipback-detail-alignment-20261017/android-gesture/after/interaction.mp4)

<a id="b-5fec8085cf701f0a"></a>

상세 전용 프리뷰 재실행(`frontend/`, 기기별 순차 실행):

<a id="b-6290318b27502436"></a>

```bash
flutter run --no-pub -d <device-id> -t test/support/detail_preview.dart \
  --dart-define=DETAIL_PREVIEW_PHASE=after

# Android Emulator에서만 호스트 포워딩
adb -s <emulator-id> forward tcp:8768 tcp:8767
```

<a id="b-878fef7c3a2b7aef"></a>

기기 내부 loopback은8767, iOS 호스트 조회는8767, Android 포워딩 조회는8768이다. `/scene?kind=basic|expanded|empty&scroll=0`은 정적 상태, `/scroll?offset=max`는 최하단, `/state`는 실제 스타일·경계, `/run?expandedOffset=<BEFORE에서 고정한 px>`는 동작·커버리지 전체 검사다. 전후 비교에는 새 BEFORE를 확보하고 동일한 수치 offset을 재사용한다. `DETAIL_PREVIEW_PHASE`는 보고서 단계만 구분하며 이전 제품 코드를 복구하지 않는다. 종료 후 해당 포워딩을 제거하고 기기를 종료한다.

<a id="b-735b0ce02fb419f8"></a>

남은 범위와 비교 해석:

<a id="b-5712aba6a20d9b04"></a>

- 현재 연관 선정/순서는 불러온 목록의 같은 첫 카테고리 이름 기준이고, 페이지 표시는 ‘현재 위치 / 불러온 N개’ 의미를 유지한다. 실제 원문은 mapper에서 요약을 재사용하며 원본 링크 콜백은 열람 기록/시트다. F03 미디어 이미지를 구현에 삽입하지 않았다.
- 기존 좌우24px·실제 가용 폭을 사용한다. Figma 제목343px/부모327px의 초과 폭, F02/F04 하단 간격16px과 F03의8px 차이, 실제 원문/미디어/외부 실행·추천 계약과 새 확대 대응은 ‘디자인 확인 필요’로 유지했다. 기존 원본 이미지 컨트롤러/시트·저장 정책·공통 탭/OS 안전 영역은 보존했다.
- 실제 OS 원본을 자르거나 보정하지 않았다. iOS 창393×852/DPR3·상단59/하단34px, Android 창392.7×783.3/DPR2.75·상단24/하단0px이며 본문375px과 실제 viewport559/559.27px를 구분한다. 긴 대역 요약/원문은 Figma 예제와 내용·길이가 다르므로 전체 절대 좌표 일치를 뜻하지 않는다.
- 전문의 고정 위치는 BEFORE 스크롤0에서 보고된 초기 `maxScrollExtent`(sliver 추정값)/2로 정한 **iOS1415.0384615384617px / Android1414.902097902098px**를 전후 그대로 사용한다. 실제 전체 범위의 정확한 중간점이라고 보고하지 않으며 안정화한 최대 스크롤은 runner에서 별도로 기록한다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-081b2960279962c7"></a>

[새 비교 8쌍](/private/tmp/clipback-detail-alignment-20261017/comparison-document.html) · [iOS 동작 영상](/private/tmp/clipback-detail-alignment-20261017/ios/after/interaction.mp4) · [Android 동작 영상](/private/tmp/clipback-detail-alignment-20261017/android-gesture/after/interaction.mp4) · [환경 정리](/private/tmp/clipback-detail-alignment-20261017/cleanup-verification.json)

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-3f9d2c18f44c008e"></a>

[새 비교 8쌍](/private/tmp/clipback-detail-alignment-20261017/comparison-document.html)·[비교/조건 QA](/private/tmp/clipback-detail-alignment-20261017/pair-verification.json) 및 [iOS 동작 영상](/private/tmp/clipback-detail-alignment-20261017/ios/after/interaction.mp4) · [Android 동작 영상](/private/tmp/clipback-detail-alignment-20261017/android-gesture/after/interaction.mp4)를 보존했다. 자세한8쌍 표는 [프론트 README](../../frontend/README.md)의 같은 제목 절을 따른다.
