# 카테고리 시트와 삭제 팝업

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-62c49a74b76de064"></a>

### 카테고리 관리 시트와 삭제 팝업의 1배율 맞춤 — 2026-10-17

<a id="b-6e13e069474f2533"></a>

`886cdea` 기준으로 Page 1 > `261007`의 E08 더보기(`111:4236`)·E09 추가 전(`111:4287`)·E10 추가 입력(`111:4376`)·E11 수정(`111:4427`)·E12 삭제 확인(`111:4484`)의 시트·팝업 본체1배율을 적용했다. 아카이브와 관리의 기존 두 진입을 유지하며 배경 딤/블러 맞춤·자유 색상 선택기·새 확대 맞춤은 후속이다.

<a id="b-fb457ac3771f2e6e"></a>

- [이번 Figma 원본/컨텍스트](/private/tmp/clipback-category-sheets-20261017/figma/reference-manifest.json): **2026-10-17 10:26:57~10:27:04 UTC /19:26:57~19:27:04 KST**, 5개 모두 성공했다. 구현 에셋 확인용 읽기를 총3회(하위 메타데이터1회·하위 컨텍스트1회·읽기 전용 원본 PNG 내보내기1회) 추가했으며 Figma 노드는 수정하지 않았다. planning 원본/이전 기기 캡처를 이번 비교로 대체하지 않았다.
- 더보기는 핸들50×5/상단8px·헤더 간격16px·폴더40×34px/글자 앞12px·이름15/Medium/−0.375·개수12/Regular/−0.3/문단 사이2px·텍스트 최대156px을 적용했다. 구분 영역 앞뒤16px/높이8px·옵션44px/아이콘20px/앞8px/16Medium−0.4·마지막32px+실제OS하단여백 한 번이다. 정상 본체223px이며 긴 실제 개수는 헤더/본문이 필요한 높이를 늘린다.
- 추가/수정은 기본 본문428px+max(키보드 inset,OS viewPadding)를 실제 top-safe 가용 높이로 제한하고 본문 스크롤과 CTA48px/좌우16px/아래32px을 분리했다. 폴더121×103px/시작60px·입력 앞32px·밑줄 앞8px/높이1px·팔레트 앞32px이다. 안내18/Medium·입력18/SemiBold/−0.45·버튼15/SemiBold/−0.375의 Pretendard/AUTO를 명시했다. Figma 키보드277px이나375px 폭을 OS 창에 강제하지 않는다.
- 삭제는 최대311px/화면 좌우 최소32px·내부 좌우16/상하32px/R16·경고32px 안 원본24px·간격8/8/36px·버튼44px/사이8px을 적용했다. 제목18SemiBold−0.45/AUTO, 본문14Medium−0.35/1.6, 버튼14SemiBold/22px을 명시한다. 실제 이름과 기존 콘텐츠 보존 안내, 중앙 배치와 자연 높이를 유지하고 매우 긴 내용은 실제 viewport 안에서 스크롤한다. Figma top200px/높이279px·콘텐츠 동반 삭제 문구를 적용하지 않았다.
- 사용자 확정 예외: 기존8색 RGB·기존 초기색·무지개 버튼의 고정 코랄 #FF6F61 선택 동작을 유지한다. E09 원본의 무지개 버튼 유무 및 팔레트 색상 차이, E12 보존 문구/자연 높이·중앙 위치, 기존 배경 효과를 전체 원본과 완전 일치로 보고하지 않는다. 실제 자유 색상 선택기는 구현하지 않았다.
- [원본/번들/실제 에셋 검사](/private/tmp/clipback-category-sheets-20261017/static-assets-verification.json): 기존 폴더2역할을 재사용하고 편집20/삭제20/경고24/선택 원30/밑줄327×1의 정확한 원본 SVG5개와 무지개 원본 노드38×32의 PNG1개를 등록했다. PNG는 SVG foreignObject 지원 문제 때문에 원본 노드를 scale3(114×96)로 내보낸 에셋이며 화면 캡처를 자른 이미지가 아니다. 선택 원은 원본 붉은색만 실제 선택색으로 치환하고 흰 체크를 보존한다. 밑줄은 실제 가용 폭/1px이며 원본 문서는 보존한다. 임시 URL/전체 화면 이미지를 제품에 쓰지 않았다.
- [보존 감사](/private/tmp/clipback-category-sheets-20261017/preservation-audit.json): 공개 생성자/필드·더보기 종료 후 수정/삭제를 여는 순서·콜백 인수·실제 ID/집계·추가/수정 payload·콘텐츠 분류 변경 UI·API/모델/App/전역 위젯을 보존했다. 기존 trim/공백 차단·자동 포커스·콜백 후 닫기를 유지하고 버튼/IME 연속 제출을 한 번으로 제한하는 폼 내부 가드만 추가했다. 기존 실패 처리를 새로운 폼 유지/재시도 정책으로 바꾸지 않았다.
- [새 BEFORE 게이트](/private/tmp/clipback-category-sheets-20261017/before-gate.json)·[동결 소스](/private/tmp/clipback-category-sheets-20261017/fixture-manifest.json): 제품 수정 전에 새로운 OS원본10장을 확보했다. 검사/프리뷰는 전후 동일하며 목표치 실패와 캡처 가능 여부를 분리했다. 초기 프리플라이트/수정 전 차이를 최종 성공으로 쓰지 않는다.
- [제품 변경 전 재현](/private/tmp/clipback-category-sheets-20261017/focused-before-summary.json): 같은56검사에서 14통과·42예상 실패, 예상 밖0건이었다. 입력 자동화의 중복 재탭/고정 포인터 시각을 고친 최종 동결 소스로 양 플랫폼 BEFORE를 다시 빌드·촬영했고, 편집 메뉴가 있던 선행 iOS 시도는 canonical 비교에서 제외했다. [입력 보조 교정](/private/tmp/clipback-category-sheets-20261017/input-helper-correction.json)은 제품·데이터·판정 기준을 바꾸지 않았다.
- [이번 자동 검사](/private/tmp/clipback-category-sheets-20261017/automatic-checks.json): 집중 **175/175**(19.21초), 관련 **216/216**(20.28초), 전체 **1111/1111**(62.99초), flutter analyze --no-pub **문제0건**(4.42초)이다. 건너뜀/오류0이며 기존 확대/카테고리 삭제/콘텐츠 보존/저장/상세/루트 앱 복귀·계정 분리 검사를 유지했다.
- 실제 Pretendard·iOS/Android×폭320/375px×1배율의5상태를 검사하고, 별도 하단0/34/48px×키보드0/300px·짧은 화면 cap/본문 스크롤·긴 이름/개수·빈값/trim·버튼/IME 중복·팔레트 밖 초기색/고정 코랄·두 진입·취소/복귀를 확인했다. 실제 RenderParagraph/RenderEditable와 에셋/paint viewport를 측정하고 논리 콘텐츠·의도한 말줄임/스크롤 밖 내용과 실제 잘림을 구분했다.
- 범위 밖 정적 재현: iOS 테마 폭375px·높이568px·OS하단48px·키보드300px에서 배경 CategoryArchiveView의 Column(category_widgets.dart:333)이35px 넘쳤다. [진단 원문](/private/tmp/clipback-category-sheets-20261017/shortcap-diagnostic.log)을 보존하고 목록은 변경하지 않았다. 폼 cap 단위 검사는 같은 실제 modal route를 여는 단순 호스트로 분리해 오류를 무시하지 않고 시트 자체를 검사한다. 일반 native 기기의 실제 목록/관리 배경 검증과 이 단위 호스트 검사를 구분한다.
- iPhone16/iOS18.6: 창Size(393.0, 852.0)·DPR3.0·OS상단59.0/하단34.0px·42기록, **style/layout/behavior/coverage/checksCompleted/전체 passed:true·프레임워크 오류0건**이다. 5상태의 실제 IME와 경계는 [이번 native 결과](/private/tmp/clipback-category-sheets-20261017/native-validation-summary.json)를 따른다.
- Android13/API33 제스처: 창Size(392.7, 783.3)·DPR2.75·OS상단24.0/하단0.0px·42기록, **style/layout/behavior/coverage/checksCompleted/전체 passed:true·프레임워크 오류0건**이다. 5상태의 실제 IME와 경계는 [이번 native 결과](/private/tmp/clipback-category-sheets-20261017/native-validation-summary.json)를 따른다.
- [새 비교10쌍](/private/tmp/clipback-category-sheets-20261017/comparison-document.html)·[독립 동일 조건 QA](/private/tmp/clipback-category-sheets-20261017/pair-verification.json): 플랫폼별 같은 데이터/1배율/상태/스크롤의 변경 전→후→Figma다. 추가/수정3상태는 실제 IME 양수, 더보기/삭제2상태는 IME0으로 촬영했다. 고정 일반2개+미분류/실제 집계37·콘텐츠2개와 Figma 예시 데이터·OS 창/키보드/안전 영역 차이를 표시했다. 원본 자르기·OS 보정·대체 디자인은 없다.
- 합성 포인터와 controller 입력·실제 native IME·메모리 콜백으로 추가/수정/삭제/취소·팔레트 드래그·입력/색/컨트롤러·다른 카테고리/마지막 미분류 이동·콘텐츠 ID/북마크 보존과 두 진입 복귀를 확인했다. 호스트 초기화는 로컬 대역 복원이며 실제 HTTP/영속 저장/운영 서버/OAuth/실기기/원격 CI 검증이 아니다. 실제 루트 앱의 복귀/계정 분리는 별도 자동 회귀다.
- [iOS AFTER 영상](/private/tmp/clipback-category-sheets-20261017/ios/after/interaction.mp4): 47.121667초·[1178, 2556]px, 전체 decode 종료0/오류로그0바이트·모든 행동 종료까지 녹화 유지 확인.
- [Android AFTER 영상](/private/tmp/clipback-category-sheets-20261017/android-gesture/after/interaction.mp4): 104.463422초·[1080, 2220]px, 전체 decode 종료0/오류로그0바이트·모든 행동 종료까지 녹화 유지 확인.
- [HTML 참조/문법 검사](/private/tmp/clipback-category-sheets-20261017/comparison-html-verification.json)는 정적 검사이며 브라우저·비교HTTP서버를 실행하지 않았다. [환경 정리](/private/tmp/clipback-category-sheets-20261017/cleanup-verification.json)로 이번 앱/기기·포워딩·임시 서버를 정리하고 탐색/IME 설정을 보존했다. 과거 기록은 당시 근거로 유지한다.

<a id="b-e7723ecd395ee52f"></a>

실제 고정 데이터의 표면 경계 실측(logical px, 소수 둘째 자리 반올림):

<a id="b-3be5ccbd92db2b9a"></a>

| 플랫폼·상태 | 표면 높이 변경 전 → 후 | 핵심 거리 변경 전 → 후 | 실제 IME |
| --- | --- | --- | --- |
| iOS E08 | 240→257 | 마지막 옵션 아래 58→66; 구분 영역 1→8 | 0 |
| iOS E09·E10·E11 | 741.24→764 | 키보드 위 버튼 여백 9.24→32 | 336 |
| iOS E12 | 286→301 | 버튼 48→44; 본문–버튼 18→36 | 0 |
| Android 제스처 E08 | 207→223 | 마지막 옵션 아래 24→32; 구분 영역 1→8 | 0 |
| Android 제스처 E09·E10·E11 | 681.45→702.91 | 키보드 위 버튼 여백 10.54→32 | 274.91 |
| Android 제스처 E12 | 290→301 | 버튼 48→44; 본문–버튼 18→36 | 0 |

<a id="b-b3622d06a1b9a36d"></a>

더보기·폼의 실제 표면 폭은 양 플랫폼375px, 삭제 표면 폭은311px이다. 폼 표면 높이는 실제 IME 자리를 포함하며 이를 뺀 본문 기준은428px이다. 삭제 높이301px은 이 이름·보존 문구의 자연 높이 실측이며 고정 높이를 추가한 값이 아니다. 전체 경계·원본은 위 비교/상태 JSON을 따른다.

<a id="b-6e7e82b0723450c1"></a>

관리 시트 전용 프리뷰 실행:

<a id="b-ef93d1d303e6e1f4"></a>

```bash
cd frontend
flutter test --no-pub test/category_sheet_alignment_test.dart test/category_management_alignment_test.dart test/category_archive_alignment_test.dart test/feed_pagination_test.dart
flutter run --no-pub -d <device-id> -t test/support/category_sheet_preview.dart --dart-define=CATEGORY_SHEETS_PHASE=after
```

<a id="b-37f1843eed5d2968"></a>

loopback8767의 `/ready`·`/state`·`/status`, 정적 `/scene?kind=actions|create-empty|create-filled|edit|delete`, 전체 동작 `/run`을 제공합니다. Android는 `adb -s <serial> forward tcp:8768 tcp:8767` 후 host8768로 접근하고 종료 후 제거합니다. `/run`은 두 진입의 메모리 대역 콜백을 검증합니다.

<a id="b-c4a215e0be8ae9b2"></a>

| 상태 | iOS 변경 전 → 후 → Figma | Android 변경 전 → 후 → Figma |
| --- | --- | --- |
| 더보기 | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/ios-category_sheets_actions_scale_1_top.png) | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/android-gesture-category_sheets_actions_scale_1_top.png) |
| 추가 입력 전 | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/ios-category_sheets_create-empty_scale_1_top.png) | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/android-gesture-category_sheets_create-empty_scale_1_top.png) |
| 추가 입력 후 | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/ios-category_sheets_create-filled_scale_1_top.png) | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/android-gesture-category_sheets_create-filled_scale_1_top.png) |
| 수정 | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/ios-category_sheets_edit_scale_1_top.png) | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/android-gesture-category_sheets_edit_scale_1_top.png) |
| 삭제 확인 | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/ios-category_sheets_delete_scale_1_top.png) | [3열 비교](/private/tmp/clipback-category-sheets-20261017/comparisons/android-gesture-category_sheets_delete_scale_1_top.png) |
