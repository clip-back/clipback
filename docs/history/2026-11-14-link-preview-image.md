# 저장 화면의 고정 예시 그림(링크 썸네일·사진 대체 그림) 제거 (#350)

2026-11-14, 브랜치 `fix/link-preview-image`. 앱 0.5.3 후보.
시작 커밋 `fc969b4`, 구현 커밋 `48fea76`, 리뷰 반영 `9e6482d`, main(#349) 병합 `682981d`, 병합 뒤 테스트 경로 수정 `0a1a08e`(전체 검증·변경 후 촬영 기준).
이 기록을 더한 커밋은 문서만 바꾼다.

## 문제

- 링크를 저장하면 저장 결과(D05) '미리보기' 카드 왼쪽에 어떤 링크든 같은 그림 `assets/figma/save-link-preview.png`가 보였다. Figma 예시에 쓰인 실제 유튜브 썸네일(실제 인물)이다.
- 사진 첨부의 대체 그림 `assets/figma/saved-photo-preview.png`(실제 X 화면 캡처, 실제 계정 이름·프로필 사진)도 화면에는 안 보이지만 앱 묶음에 들어 있었다.

## 사용자 결정

- 2026-11-14: 링크 저장 결과 미리보기 "3. 그림 자리 숨기기". 사진 대체 그림 "같이 바꿈 (Recommended)", 방식 (다) 사진 바이트가 없으면 기존 D06 '선택 전' 칸.
- 2026-11-14 구현 중 "추천대로": 이슈 허용 표 밖의 `save_base_typography_test.dart` 세 테스트('preview two lines without ellipsis'·'preview title width changes wrapping'·'preview long text')는 기대값을 그대로 두고, 링크 경우만 넓어진 글자 열 폭(카드 폭 − 16, 제목은 − 8 더)과 그 폭에서 같은 조건이 나는 링크 전용 문구를 쓴다. `SelectedPhotoPreview`가 사진 바이트를 꼭 받게 되어 생긴 테스트·기기 프리뷰 연결 수정 2곳을 허용한다.

## 구현 (`48fea76`)

- 링크 결과 카드: 그림 칸(164×100)과 그 뒤 간격 16을 사진 결과에만 그린다. 제목·출처는 카드 안쪽 폭 전체를 쓴다. 카드 최소 높이 116·안쪽 여백 8·제목 오른쪽 여백 8·글꼴·줄 수는 그대로다. 사진 결과(D09)의 그림 칸·테두리·cover·위쪽 정렬은 그대로다.
- 사진 칸: `PhotoSaveBody`는 선택 상태이고 사진 바이트가 있을 때만 `SelectedPhotoPreview`를, 아니면 `PhotoEmptyPrompt`를 보인다. `SelectedPhotoPreview.photoBytes`는 non-null이며 대체 그림 분기를 없앴다. 실제 앱에서는 선택 성공 때 단계와 바이트를 함께 넣어 화면이 바뀌지 않는다.
- 두 그림 파일과 상수 `Assets.saveLinkPreview`·`Assets.savedPhotoPreview`를 지웠다. 테스트·기기 프리뷰가 읽던 그림은 앱에 있는 `search-empty-original.png`(1018×1545)와 `huturu-character-1.png`(1448×1086)로 바꿨다.

## 테스트

먼저 테스트를 바꿔 실패를 본 뒤 고쳤다(로그는 로컬 `.utmp/ticket-350/partial-*.log`, 저장소에 넣지 않음).

- 재현: 링크 결과 카드 안에 Image가 없고 제목 왼쪽이 카드 왼쪽 + 8인지(`save_scaled_layout_test.dart` 'link preview fits …', `save_base_typography_test.dart` `_preview`), 바이트 없이 `valid` 단계로 그린 `PhotoSaveBody`가 `PhotoEmptyPrompt`를 보이는지('photo body without bytes shows empty prompt …'). 수정 전 32건 실패(링크 결과 28, 사진 없음 4).
- 바꾼 기존 테스트는 이슈의 허용 표와 위 "추천대로" 범위 안이다. 사진 결과(D09)·사진 칸(D07)의 배치·픽셀 단언은 바꾸지 않았다.
- 기기 프리뷰(`test/support/save_result_preview.dart`)는 링크 결과에서 카드 아래 실제 Image가 없음과 글자 왼쪽 여백 8을 판정한다. 링크 카드 글자 열에 1×1 그림을 잠시 넣은 변형을 iOS Simulator에서 돌려 `Link preview must not show an image`로 실패하는 것을 확인했고, 원래 파일로 되돌렸다.
- `git grep -n -E "save-link-preview|saveLinkPreview|saved-photo-preview|savedPhotoPreview" -- ':!docs/history'` 0건.

## 검토

검수(Codex, `.utmp/review-350.md`): Standards 0개, Spec 낮음 1개.

- 반영(`9e6482d`): 기기 프리뷰가 링크 결과의 그림 없음을 고정값으로 판정했다. 카드 아래 실제 Image 유무를 읽게 했다.

## 검증

- `VERIFY result=PASS scope=all checks=11 failed=0`(`0a1a08e`, main #349 병합 뒤).
  - CI App Validation 명령: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`(0 changed), `flutter analyze --no-pub`, `flutter test --no-pub`(+3511 All tests passed).
  - 백엔드: pytest 2640 passed, 49 skipped(48 `tests/deployment` Docker 복구 시험 조건, 1 `tests/integration` S3 주소 없음). 백엔드는 바꾸지 않았다.
- 병합 직후 검증은 `app:test` 52개 실패였다. #349가 `hutureu-character-1.png`를 `huturu-character-1.png`로 바꿔 테스트 두 곳의 직접 경로가 깨졌고, `0a1a08e`에서 맞췄다.
- `git diff --check` 통과.

## 화면 확인

2026-11-14, iPhone 16 / iOS 18.6 Simulator(Simulator.app 없이 headless)와 `Medium_Phone` / API 36 Emulator. 기기 프리뷰 `flutter run --no-pub -t test/support/save_result_preview.dart --dart-define=SAVE_RESULT_PHASE=before|after`의 `/scene?kind=link&scale=1`(링크 저장 결과, 카테고리 분류됨, 글자 1배율)이다. 메모리 콜백 대역이며 서버·로그인은 쓰지 않았다.
변경 전은 `fc969b4` 임시 워크트리, 변경 후는 `0a1a08e`로 빌드했다. 두 쪽의 논리 크기·글자 배율·스크롤 위치(0)·OS 안전 영역이 같다.
Figma 기준은 D05 `111:4902`(375×812, 2026-11-14 01:24 KST 조회)다. 그림 칸 없는 모양은 Figma에 없다(사용자 결정 3안, [디자인 확인 필요](../figma-ui-alignment-plan.md#figma-pending-link-preview-image)).

| 확인 | iOS | Android |
| --- | --- | --- |
| 링크 결과 카드의 그림 | 변경 전 예시 썸네일 → 변경 후 없음 | 같음 |
| 제목 왼쪽(카드 왼쪽 16) | 204 → 24(카드 + 8) | 같음 |
| 카드 위치·높이 | 위 386, 높이 116 그대로 | 위 351, 높이 116 그대로 |
| 프리뷰 판정(style·layout) | 통과 | 통과 |

- 사진 칸(D07)과 사진 결과(D09)는 실제 화면이 바뀌지 않아 자동 테스트로만 확인했다.
- 촬영 키트의 `compare.py`는 촬영 키트 진입 파일 형식의 JSON을 요구해, 이슈가 정한 기기 프리뷰 결과에는 쓰지 않았다. 같은 조건(위 항목)을 프리뷰 `/status` JSON으로 직접 대조한 뒤 3열 이미지를 붙였다.
- 기기 화면(393×852, 411.4×914.3)과 Figma 프레임(375×812)의 크기·안전 영역 차이는 보정하지 않았다. Figma와의 다른 차이(붙여넣기 버튼·카테고리 편집·버튼 문구)는 이번 변경 전부터 있던 승인된 차이다.

### 증거(로컬, 저장소에 넣지 않음)

- 비교 이미지: `.utmp/ticket-350-screens/compare-{ios,android}.png`(변경 전·후·Figma).
- 원본·조건 JSON: `.utmp/ticket-350/screens/`.

## 범위 밖과 미검증

- 실제 링크 썸네일(서버 대표 이미지 추출·응답 필드·앱 불러오기)과 그 디자인은 따로 다룬다.
- 큰 글자 배율의 링크 카드는 자동 테스트(배율 1.5·2)로만 확인했다. 기기 촬영은 이슈 범위(1배율)만 했다.
- 원격 CI는 돌리지 않았다(push 전).
