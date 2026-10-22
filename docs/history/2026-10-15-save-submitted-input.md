# 저장 결과 문구와 제출 입력

- 최초 기록일: 2026-10-15
- 영역: 저장
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-d93c4e241dd57918"></a>

### 저장 결과 문구와 제출 입력 고정 (`a14111f`, 2026-10-15)

<a id="b-2e0878ab72a5d19f"></a>

작업 기준은 `b905769`이고 최신 `261008`의
[링크 결과 D05](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16639)와
[사진 결과 D09](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16602)를 대상으로 합니다.
상세 컨텍스트·원본을 구현 직전 2026-10-15 17:28:27 KST(08:28:27 UTC)에 다시 조회했습니다.
사진 결과는 ‘저장할 사진’으로 표시하고 링크 검증 문구와 전용 5px 간격을 제거합니다.
링크 결과의 ‘저장할 링크’·‘유효한 링크예요!’는 유지합니다.

<a id="b-bbe8803ccf8116e8"></a>

요청 직전의 URL/파일명·사진 바이트 참조를 실제 저장 콜백과 성공 결과에 함께 사용합니다.
요청 중 탭 이동·다른 초안 편집·재선택은 허용하고, 성공하면 제출한 종류의 탭으로 돌아가 결과 맨 위를 한 번 표시한 뒤
닫을 때까지 결과·탭을 고정합니다. 실패하면 현재 초안을 유지하고 재시도 시 그때의 입력을 새로 캡처합니다.
늦게 완료된 사진 선택기·붙여넣기와 오래된 제출 콜백은 성공 결과·스크롤을 바꾸거나 재저장하지 않습니다.

<a id="b-138c657566f39f23"></a>

공개 `SavedContentConfirmation` 생성자·콜백·API·저장 시점·분류·콘텐츠 보존은 유지합니다.
사진 프리뷰 배치/비율, 결과 상단 80px·고정 미리보기, 카테고리 추가/제거(DEC-03), 하단 버튼/스크롤과
`_SaveHomeIndicator`는 후속 범위이며 [계획과 디자인 확인 목록](../figma-ui-alignment-plan.md#디자인-확인-필요)을 따릅니다.

<a id="b-d7bfcb1c3dd54e2a"></a>

```bash
# frontend/ — 집중 회귀입니다. 관련 검사·전체 검사는 진행 기록의 실제 결과를 따릅니다.
flutter test --no-pub test/saved_content_confirmation_test.dart

# 연결된 Simulator/Emulator ID로 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/save_result_preview.dart \
  --dart-define=SAVE_RESULT_PHASE=before
# 수정 후 같은 기기·데이터·배율·스크롤 상태에서 PHASE를 after로 바꿔 다시 실행합니다.

# Android에서는 기기 서버 8767을 호스트 8768로 연결합니다.
adb -s "$EMULATOR_ID" forward tcp:8768 tcp:8767
curl http://127.0.0.1:8768/status
curl http://127.0.0.1:8768/run
# iOS Simulator의 제어 주소는 http://127.0.0.1:8767 입니다.
```

<a id="b-46b740ec4502cfcf"></a>

프리뷰는 실제 저장 위젯·대역 사진 선택기·메모리 저장 콜백과 합성 포인터/텍스트 입력을 사용합니다.
서버는 프리뷰 조작을 위한 루프백 제어용이며 실제 백엔드·인증·저장을 사용하지 않습니다.
`a14111f` 당시 `/scene?kind=photo|link&scale=1|2`, `/run`, `/keyboard`, `/scroll`, `/status`를 제공했고
기기 임시 `clipback-save-result-*`에 PNG·`report.json`을 저장합니다.
실제 OS 화면은 별도 `simctl`·`adb` 원본 캡처와 영상으로 기록합니다.

<a id="b-a4bbc0c55ece062b"></a>

집중 검사 **11개**·관련 검사 **132개**·전체 Flutter 테스트 **703개**를 통과했고 정적 분석은 **문제 없음**입니다.
변경 전·후 배율 2에서 기존 결과 미리보기의 높이 100px 텍스트 열 넘침은
iOS 46px·Android 47px, 선택 전 `PhotoEmptyPrompt`의 89px 안내 열 넘침은 2px·4px였습니다.
선택된 사진을 표시하는 `SelectedPhotoPreview` 자체의 텍스트 열 오류로 분류하지 않습니다.
`checksCompleted`·`behaviorPassed`와 `layoutPassed`·전체 `passed`를 구분하며 기존 레이아웃 실패를 문구 수정의 성공으로 덮지 않습니다.
이번 범위는 위 문구·상태 고정이며 확대 배치를 임의로 바꾸지 않습니다.
수정 후 양 플랫폼의 18개 기록은 `checksCompleted`·`behaviorPassed: true`이고
`layoutPassed`·전체 `passed: false`입니다. 기존 배율 2의 오류 종류·크기는 전후 동일합니다.

<a id="b-eabdced3d1789824"></a>

iPhone 16/iOS 18.6은 논리 393×852·DPR 3·안전 영역 상단 59px/하단 34px,
Pixel 3a 설정의 Android 13/API 33 제스처 모드는 논리 392.7×783.3·DPR 2.75·상단 24px/하단 0px입니다.
실제 저장 창에서 문구·제출 입력·탭 복귀/고정·수동 재시도·닫기/늦은 완료를 확인했습니다.
사진 결과 배율 2의 스크롤 위치는 iOS 124px·Android 161.727px이었습니다.
키보드는 양쪽 OS 캡처에서 보였으며 iOS inset은 336px입니다. Android는 보이는 IME와 달리 Flutter 스냅샷의
`viewInsets.bottom`이 0이어서 키보드 inset 반영 검증은 한계로 남겼습니다.

<a id="b-cea3769806219815"></a>

증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording`입니다.
[원본 변경 전·후·Figma 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/comparison-document.html),
[iOS 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/ios/after/interaction.mp4),
[Android 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/android/after/interaction.mp4)을 보존했습니다.
두 플랫폼의 링크/사진·배율 1/2, 원본 OS 화면 비교 8건의 조건·파일·해시를 대조했습니다.
최종 기종·OS·자동/기기 결과와 미검증 범위는 [프론트 진행 기록](../fe-merge-fixes.md)에 기록했습니다.
실제 공급자·AI/OCR·운영 서버·실기기·원격 CI는 이번 대역 렌더링으로 검증하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-74f1860441055132"></a>

### 2026-10-15 — 사진 저장 결과 문구와 실제 제출 입력 유지

<a id="b-274effd28131c374"></a>

- 브랜치 `feature/figma-ui-alignment`, 변경 전 기준 `b905769`.
  최신 `b2lmAo9VtbL6Qi0mzX5IMu`의 `WireFrame & UI > 261008`에서 D05 `912:16639`·D09 `912:16602`를 사용했다.
  초기 원본·컨텍스트를 확보하고 제품 수정 직전 **2026-10-15 17:28:27 KST / 08:28:27 UTC**에 다시 기록했다.
  원본 화면은 비교 자료로만 사용하며 제품 에셋으로 사용하지 않았다.
- 사진 결과 제목을 ‘저장할 사진’으로 바꾸고 링크 검증 메시지와 바로 앞 5px 간격은 링크에만 표시한다.
  사진 파일명·기존 이미지 미리보기·링크의 기존 제목/검증 표현을 유지한다.
  제출 직전 URL/파일명/사진 바이트 참조를 캡처하여 같은 값으로 저장 콜백을 호출하고 성공한 콘텐츠와 함께 보관한다.
  서버가 반환한 콘텐츠 종류나 현재 초안으로 결과 입력을 다시 판정하지 않는다.
- 요청 중 탭 전환·입력 변경·다른 사진 선택을 허용한다. 성공하면 실제 제출한 종류의 탭으로 복귀해
  결과 맨 위를 한 번 표시하며 닫기 전까지 탭과 결과를 유지한다. 실패 시 현재 초안을 보존하고 재시도 때 새로 캡처한다.
  늦은 사진 선택기/붙여넣기, 오래된 제출 콜백과 화면 종료 뒤 응답이 결과·스크롤·저장 횟수를 바꾸지 않도록 방어한다.
- 공개 생성자·콜백·API·데이터 모델과 저장 실행 시점은 변경하지 않는다. 사진 비율/고정 잘림, 결과 상단 80px,
  미리보기와 카테고리 배치·분류 정책·하단 버튼·`_SaveHomeIndicator`는 후속 범위다.
  [계획의 UI-06과 디자인 확인 목록](../figma-ui-alignment-plan.md)을 부분 적용 기준으로 갱신했다.
- **제품 수정 전** 실제 저장 다이얼로그에 고정 메모리 콜백·사진 선택 대역을 연결한 프리뷰를 준비했다.
  `before-gate.json`에서 제품 diff가 비어 있고 기준 SHA가 `b905769c84df669eabd97b24b50319e5e93615b0`임을 확인했다.
  링크·사진 × 배율 1/2 × 두 플랫폼의 OS 원본 **8장**을 새로 촬영했다. 과거 화면을 재사용하지 않았다.
  프리뷰 소스 SHA256 `3d0181ef1b596b171a356939039f4d444d2e6bfd7b1a10fef3de4ad5d86492c9`를 변경 전·후 동일하게 유지했다.
- 새 집중 테스트의 수정 전 결과는 **4 passed / 7 failed**다. 사진 제목, 제출 중 초안/탭 변경에 따른 결과 오표시,
  늦은 사진 선택 응답, 성공 뒤 이전 제출 콜백을 통한 중복 저장을 재현했다.
  수정 후 집중 **11 passed**, 관련 인증·원본 이미지·자동 분류·키보드·수동 입력 보존 6개 파일 묶음은 **132 passed**다.
  전체 `flutter test --no-pub --reporter expanded` **703 passed**(Flutter 3분 56초, wall 242.26초),
  `flutter analyze --no-pub` **문제 없음**(20.5초), 변경 Dart 3개 형식 검사 **0 changed**를 확인했다.
  이전 692개 통과를 이번 결과로 사용하지 않았다.

<a id="b-b59ed88f2b020af4"></a>

| 실제 실행 환경 | 창·OS 여백 | 수정 후 동작 결과 |
| --- | --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 393×852 논리 px, DPR 3, 상단 59px·하단 viewPadding 34px | 링크/사진·배율 1/2, 요청 중 교차 탭/초안 변경, 성공 탭 고정, 중복 방지·실패 재시도·닫기/늦은 완료 확인. 결과 배율 2 드래그 offset 124px, 실제 키보드 표시 시 inset 336px. |
| Android 13 / API 33 Emulator (`Clipback_Share_API_33`) | 392.7×783.3 논리 px, DPR 2.75, 상단 24px·하단 viewPadding 0px, 제스처 탐색 값 2 | 같은 동작 확인. 결과 배율 2 드래그 offset 약 161.73px. OS 원본에서 키보드 표시·이후 해제를 확인했으나 프리뷰의 MediaQuery inset은 0px로 기록돼 양수 inset 측정 성공으로 보고하지 않는다. |

<a id="b-9fd9bf3064dd5f89"></a>

- 실제 위젯과 Flutter 합성 포인터·컨트롤러 입력, 메모리 저장 콜백/파일 선택기를 사용했다.
  양 플랫폼 AFTER 보고서는 각각 **18개 기록, `checksCompleted: true`, `behaviorPassed: true`**다.
  배율 2에서 기존 고정 미리보기 텍스트 열의 넘침(iOS 46px·Android 47px)과 사진 선택 전 안내 열의 넘침(2px·4px)이
  변경 전·후 동일하게 남아 **`layoutPassed: false`, 전체 `passed: false`**로 보존했다.
  일반 배율에서는 프레임워크 오류가 없으며 확대 전용 배치 디자인을 임의로 만들거나 카드 높이를 수정하지 않았다.
  정상 링크의 카테고리 안내/고정 닫기 버튼 겹침과 저장 화면의 앱/OS 인디케이터 중복도 이번 범위 밖이다.
- Android 최초 실행에서 호스트 창 렌더링 오류가 나 검증용 Emulator를 창 없이 다시 실행했다.
  앱/AVD 데이터를 지우거나 OS 탐색 설정을 바꾸지 않았다. 최종 OS 캡처·동작 검증은 재실행한 동일 AVD에서 수행했다.
  최종 빌드 생성은 iOS Xcode 337.7초·Android Gradle 302.6초이며 실제 API/인증 호출을 포함하지 않는다.

<a id="b-b0df33850f6a5b60"></a>

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording`.

<a id="b-4daad9bcef1d6e2b"></a>

- [변경 전 → 변경 후 → Figma 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/comparison-document.html)는
  플랫폼·입력 종류·글자 배율별 **8개 비교**와 원본/영상 링크를 제공한다. 같은 기종·논리 크기·DPR·고정 데이터·배율·스크롤 0·OS 여백을 대조했다.
  OS 원본 16장과 Figma 원본 2개의 해시를 보존했다. 비교 PNG는 원본 전체를 동일 표시 폭으로만 줄였으며 잘라내거나 위치/OS 영역을 보정하지 않았다.
  Figma 375×812와 실제 기기/안전 영역 차이, D09의 사진 띠 대신 유지한 파일명 필드와 부분 적용 범위를 표시한다.
  확대 비교는 기본 원본과 사용자 확정 기준을 사용하고 별도 디자인 이미지를 만들지 않았다.
- 동작 영상: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/ios/after/interaction.mp4),
  [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/android/after/interaction.mp4).
  iOS 원본은 HEVC 1178×2556/140.335초(PNG 1179×2556), Android 원본은 H.264 1080×2220/178.630초다.
  변경 전 원본 영상·플랫폼별 키보드/스크롤 PNG·보고서도 보존한다.
- 두 AFTER 영상의 전체 스트림을 디코딩해 종료 코드 0·오류 로그 0바이트를 확인했다.
  문서 3개의 로컬 Markdown 링크 **147개 모두 존재**, 최종 diff·공백·생성 파일/민감 정보 제외를 확인했다.
  검증에 사용한 Simulator·Emulator와 이번 빌드 프로세스를 종료하고 AVD·앱 데이터는 보존했다.
  읽기 전용 비교 서버 `127.0.0.1:8769`와 기존 비교 서버는 유지한다.
- 실제 OAuth·운영 서버·AI/OCR·실기기·원격 CI·실제 서버 저장 완료는 검증하지 않았다.
  화면 증거·빌드 생성물·`AGENTS.md`는 Git에서 제외하고, 커밋 제목은 `fix: 사진 저장 결과의 링크 전용 문구 수정`이다.
  푸시·PR은 수행하지 않는다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-a726ef01a0fcef72"></a>

### 2026-10-15 — 저장 결과 문구와 제출 입력 고정

<a id="b-4050f1adea3438b2"></a>

작업 기준은 `b905769`이며 최신 파일 `b2lmAo9VtbL6Qi0mzX5IMu`의 `WireFrame & UI > 261008`을 사용한다.
대상은 [링크 저장 결과 D05](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16639)와
[사진 저장 결과 D09](https://www.figma.com/design/b2lmAo9VtbL6Qi0mzX5IMu/?node-id=912-16602)다.
구현 직전 원본·컨텍스트 조회는 2026-10-15 17:28:27 KST(08:28:27 UTC)이며,
이 작업을 D05/D09의 전체 배치·사진 비율·카테고리 편집 적용으로 확대하지 않는다.

<a id="b-b7dd589eb0eace31"></a>

| 적용 영역 | 승인된 동작 |
| --- | --- |
| 결과 문구 | 사진 결과 제목은 ‘저장할 사진’, 링크 결과는 기존 ‘저장할 링크’를 유지한다. `ValidationMessage(valid: true)`와 전용 5px 간격은 링크에만 표시한다. 사진용 성공 검증 메시지를 새로 만들지 않는다. |
| 제출 입력 | 요청 직전 URL은 trim한 문자열, 사진은 당시 파일명·바이트 참조를 캡처한다. 바이트 내용을 수정하지 않고 같은 입력으로 저장 콜백을 호출한다. 성공한 `ContentItem`과 입력 스냅샷을 함께 보관하며 현재 초안이나 서버의 콘텐츠 종류로 결과 입력을 다시 판정하지 않는다. |
| 탭과 결과 | 요청 중 탭 이동·다른 초안 편집·사진 재선택은 허용한다. 성공하면 실제 제출한 종류의 탭으로 복귀하고 결과 맨 위를 한 번 표시한다. 닫을 때까지 결과·선택 탭을 고정하고 탭 클릭으로 스크롤을 초기화하지 않는다. |
| 실패·늦은 응답 | 실패하면 결과를 만들지 않고 현재 초안을 보존한다. 재시도는 그때의 입력을 새로 캡처한다. 성공 후 늦게 완료된 사진 선택기·붙여넣기와 오래된 제출 콜백은 결과·스크롤을 바꾸거나 재저장하지 않는다. 성공 시 기존 검증/오류 타이머를 정리하고 닫힌 화면에는 늦은 결과를 반영하지 않는다. |

<a id="b-fe13f44c982cfef3"></a>

`SavedContentConfirmation`의 공개 생성자·저장 콜백·API·데이터 모델은 유지한다.
저장 실행 시점, 서버 분류·미분류·처리 중 문구, 상세에서 분류를 바꾸는 정책과 콘텐츠 보존은 변경하지 않는다.
사진 입력/결과의 미리보기 배치·비율, 결과 상단 80px, 카테고리 추가/제거(DEC-03),
하단 버튼·스크롤 간격과 `_SaveHomeIndicator`는 유지하며 위 디자인 확인 목록의 후속 범위다.

<a id="b-72eddfcfe3724ec9"></a>

### 저장 결과 작업의 검증 상태

<a id="b-abc5e0ecee66dabc"></a>

- [결과 회귀 테스트](../../frontend/test/saved_content_confirmation_test.dart) **11개**와 관련 검사 **132개**를 통과했다.
  사진/링크 문구·다른 요청 모드의 서버 응답·제출 중 초안 변경·성공 탭 복귀/고정·실패 후 현재 초안 재시도,
  늦은 사진 선택기와 결과 스크롤·성공 후 이전 제출 콜백·닫힌 화면의 늦은 성공/실패를 검사한다.
  전체 Flutter 테스트 **703개 통과**, 최종 `flutter analyze --no-pub` **문제 없음**을 확인했다.
  이전 692개 통과나 기기 결과를 이번 결과로 사용하지 않는다.
- [기기 프리뷰](../../frontend/test/support/save_result_preview.dart)는 실제 저장 위젯에 메모리 콜백·대역 사진 선택기를 연결하고
  Flutter 합성 포인터·텍스트 입력을 사용한다. 실제 HTTP API·인증·저장은 사용하지 않으며 루프백 제어 서버만 연다.
  `SAVE_RESULT_PHASE=before|after`로 요청 스냅샷·탭 정책의 변경 전 기록과 변경 후 판정을 구분한다.
- 변경 전 iOS/Android에서 사진·링크 결과의 배율 1/2, 플랫폼별 원본 OS 캡처 4개를 확보했다.
  배율 2의 기존 결과 미리보기 내부 텍스트 열 넘침은 iOS 46px·Android 47px,
  사진 선택 전 `PhotoEmptyPrompt`의 안내 열은 2px·4px이다.
  변경 전·후 보고서 모두 `checksCompleted`·`behaviorPassed: true`, `layoutPassed`·전체 `passed: false`다.
  변경 후 플랫폼별 기록은 18개이며 문구 분리·요청 입력 고정·요청 중 탭 변경·성공 탭 고정·수동 재시도·닫힌 화면의 늦은 완료를 확인했다.
  배율 2의 기존 넘침 종류와 크기는 전후 동일하다. 동작 확인을 전체 레이아웃 성공이나 프레임워크 오류 0건으로 바꾸지 않는다.
- iPhone 16 / iOS 18.6 Simulator는 논리 393×852·DPR 3·상단 59px·하단 34px,
  Pixel 3a 설정 / Android 13(API 33) Emulator는 논리 392.7×783.3·DPR 2.75·상단 24px·하단 0px이었다.
  Android는 제스처 모드(`navigation_mode=2`)에서 실행했다. 사진 결과 배율 2의 실제 스크롤 위치는 각각 124px·161.727px이었다.
  키보드는 양쪽 OS 원본 화면에서 표시를 확인했다. iOS의 기록 inset은 336px이었으나 Android는 IME가 보여도
  Flutter 스냅샷의 `viewInsets.bottom`이 0이었다. Android의 키보드 inset 반영은 미검증 한계로 남기며 이를 근거로 앱 배치를 바꾸지 않았다.
- 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording`이다.
  [원본 변경 전·후·Figma 비교 문서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/comparison-document.html),
  [iOS 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/ios/after/interaction.mp4),
  [Android 동작 영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/save-result-wording/android/after/interaction.mp4)을 보존했다.
  두 플랫폼 × 링크/사진 × 배율 1/2의 원본 OS 화면 비교 8건에 대해 기종·데이터·배율·스크롤·원본 파일과 해시를 대조했다.
  원본 OS 영역을 보정하지 않고 비교하며 Figma의 1배 원본을 임의로 확대 상태로 재작성하지 않는다.
  기종·OS·최종 측정값·확인한 동작·미검증 범위는 [프론트 진행 기록](../fe-merge-fixes.md)에 기록했다.
  실제 OAuth·운영 서버·AI/OCR·실기기·원격 CI는 이번 대역 화면 검증에 포함하지 않는다.
