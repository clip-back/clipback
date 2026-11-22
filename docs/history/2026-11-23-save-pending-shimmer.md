# 저장 처리 중 막대 반짝임 (#471)

2026-11-23에 `55fd45c`를 기준으로 구현했습니다. 첫 구현은 `cb24dbc`, 검수 반영과 전체 검증의 기준은 `6de656b`입니다.

## 변경

- 패키지 없이 Flutter SDK로 반짝임 공용 위젯 `skeleton_shimmer.dart`를 만들었습니다. 막대 바탕은 `AppColors.faint`, 띠는 `AppColors.bg`이며 띠는 약 1.5초에 한 번 왼쪽에서 오른쪽으로 지나갑니다.
- 링크·사진 저장 처리 중의 미리보기 상자와 카테고리 상자가 한 영역의 띠를 함께 씁니다. 막대 모양·크기·키·문구와 제출·실패·늦은 응답 흐름은 그대로입니다.
- `disableAnimations`나 `reduceMotion` 중 하나가 켜져 있으면 띠를 그리지 않고 프레임도 예약하지 않습니다. 막대 묶음은 의미 트리에서 빠지고 제목과 "허투루가 분류하고 있어요."는 남습니다.
- 띠 폭은 명세에 값이 없어 영역 폭의 40%로 정했습니다.
- 계획 문서의 현재 기준 표에 D04·D08 행이 없어, 감독 답에 따라 새 행 `figma-current-pending-shimmer`로 적었습니다. 최종 디자인 요청은 `figma-pending-skeleton`에 남겼습니다.

## 검증

- 첫 단계: 저장 관련 테스트 29개 파일을 반짝임 적용 상태로 실행해 1,480건이 통과했고 `pumpAndSettle` 시간 초과는 0건이었습니다. 보류 중 호출이 없어 기존 저장 테스트와 fixture는 고치지 않았습니다.
- 검수 지적 2건을 반영했습니다. 폭과 시작 x가 다른 두 막대의 띠 중심 비교와 RGBA 검사를 iOS·Android 대상 플랫폼 값으로 각각 실행합니다.
- 묶음별 로컬 폭으로 바꾼 변형은 두 플랫폼 값에서 띠 중심 비교가, 띠를 빨강으로 바꾼 변형은 두 플랫폼 값에서 RGB 검사가 실패했습니다. 실제 구현은 통과했습니다.
- 깨끗한 `6de656b`에서 전체 검사를 한 번 실행했습니다. Flutter 테스트는 3,980건이 통과했고, CI의 앱 네 명령은 verify 단계와 같습니다.

```text
pytest: 3054 passed, 50 skipped, 3 warnings in 347.83s (0:05:47)
VERIFY result=PASS scope=all checks=12 failed=0
```

- 건너뛴 pytest는 Docker 복구 49건과 S3 이미지 1건입니다.
- 스피너 7곳은 그대로이고 `pubspec` 차이는 없습니다. 동작 줄이기 신호는 `git grep -nE "disableAnimations|reduceMotion" -- frontend/lib`에서 공용 위젯 파일 2줄만 나옵니다. 티켓의 `\|` 형식은 이 Mac의 `git grep`에서 대체 패턴으로 동작하지 않아 항상 0줄이므로 근거로 쓰지 않았습니다.

## 미검증

iOS Simulator·Android Emulator 촬영과 화면 판정, 실기기 확인, 원격 CI는 이 기록 시점에 실행하지 않았습니다.
