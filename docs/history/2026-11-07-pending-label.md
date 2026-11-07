# 콘텐츠 즐겨찾기·카테고리 이동 중 "변경 중…" 문구 없애기 (#265)

2026-11-07, 시작 커밋 `41febf4` 기준으로 구현하고 티켓 리뷰 반영과 전체 검증까지 마쳤다. 상위 스펙 #264(팀 시트 12 "'변경 중' 삭제")의 첫 티켓이다.
카테고리 행·카테고리 관리 시트의 문구는 #266에서 다룬다. 코드 커밋은 `c28f039` 하나이고, 이 기록을 더한 커밋은 문서만 바꾼다. 전체 검증의 기준 코드는 `c28f039`이다.
이 기록은 변경 후 iOS Simulator·Android Emulator 실행 확인과 변경 전·후·Figma 비교 완료를 뜻하지 않는다(화면 확인 미완료).

## 사용자 결정

- 2026-11-07 회의(#264 Q1–Q7): 문구만 지우고 요청 중 동작(별 즉시 반전, 그 콘텐츠의 별·더보기·관리 시트 항목 잠금, 실패 시 원래 값 복귀와 기존 오류 안내)은 그대로 둔다.
  쓰기 성공 뒤 후속 재조회가 끝날 때까지 잠금이 이어지는 순서도 바꾸지 않는다(Q3 알려진 한계). 대체 표시와 새 디자인 확인 항목은 만들지 않는다(Q4).
- 2026-11-07 "둘 다 추천대로 해줘":
  1. 잠긴 별을 다시 누르면 홈·전체보기·카드 다시보기에서 카드 탭으로 상세가 열리는 지금 동작과 쓰기 차단을 보존한다. #265 촬영 상태 pl-01의 "다시 눌러도 변화 없음"은 별 상태·쓰기 변화 없음을 뜻한다. 상세 이동 차단은 이번 범위 밖 별도 후보다.
  2. 별·더보기에 접근성 라벨이 없어, 기기 촬영은 앱이 알려 주는 대상 좌표(대상 1개, 전체 영역이 화면 안)로 OS 탭을 보내는 방식을 변경 전·후 똑같이 쓴다.

## 구현

- `ContentItem`(`frontend/lib/shared/models/content_item.dart`)에 진행 중 여부 `isMutating`을 더했다. 표시 문구 `mutationLabel`은 `isMutating`일 때만 둘 수 있다.
- `ContentViewModel.present`(`frontend/lib/shared/presentation/content_view_model.dart`)는 저장소의 진행 중 변경이 있으면 `isMutating`을 켜고,
  삭제일 때만 `mutationLabel`을 `삭제 중…`으로 둔다. 즐겨찾기·카테고리 이동은 문구가 없다.
- 별·더보기·콘텐츠 관리 시트 항목의 활성 여부와 시트의 "지금 이 콘텐츠인가" 확인(`isCurrent`)은 `isMutating`으로 정한다.
  대상: 홈 카드, 목록 카드(일반·전체보기), 상세 상단 바, 카드 다시보기, 카테고리 대표 카드(현재 화면에 연결되지 않은 위젯), 콘텐츠 관리 시트.
- 문구를 그리는 자리는 그대로 `mutationLabel`을 본다. 문구가 없으면 문구와 그 앞 간격이 함께 빠져 평상시 배치와 같다.
  홈 카드 높이 계산(`HomeContentCard.heightFor`)도 문구가 있을 때(삭제 중)만 문구 높이를 더한다.
- 저장소의 중복 차단·낙관적 반영·쓰기 → 후속 재조회 → 해제 순서·실패 복귀·계정 전환과 늦은 응답 처리, 401 뒤 세션 갱신과 최종 401 처리는 바꾸지 않았다.

## 테스트

- 새 루트 앱 테스트(`frontend/test/content_mutation_test.dart`):
  - 상세에서 즐겨찾기·카테고리 이동을 쓰기 대기와 후속 재조회 대기로 각각 붙잡고, 별·더보기 잠금, 다시 눌러도 쓰기 1회, `변경 중…`·`삭제 중…` 없음, 끝난 뒤 다시 누를 수 있음을 본다.
  - 홈·전체보기·카테고리 목록·즐겨찾기·검색·카드 다시보기에서 즐겨찾기 쓰기를 붙잡고 그 자리 별 잠금, 쓰기 1회, 문구 없음을 본다.
  - 홈에서 잠긴 별을 실제로 다시 누르면 쓰기는 1회, 별은 켜진 채이고 카드 탭으로 상세가 열린다(결정 1의 보존 동작).
  - 상세를 닫은 뒤 늦게 온 즐겨찾기 성공이 홈에 한 번 반영되고 잠금이 풀리는지 본다(B10 화면 종료). 계정 전환·이전 계정의 늦은 응답은 기존
    "old-account $action $outcome cannot alter the new guest or show its error"가 덮는다.
- 새 위젯 테스트(`frontend/test/pending_label_layout_test.dart`): 실제 Pretendard, 40자 한글 카테고리 이름 × 저장 날짜 있음/없음 × 글자 배율 1.0·1.3을 조합마다 따로 두고,
  요청 중 홈 카드·목록 카드(일반·전체보기)·상세 상단 바·카드 다시보기가 넘치지 않고, 한 줄 말줄임을 유지하며, 별·더보기 위치·크기가 평상시와 같은지 본다.
  삭제 중 `삭제 중…`과 잠금, 콘텐츠 관리 시트(B9)와 카테고리 대표 카드는 위젯에 상태를 직접 넣어 확인한다(실제 앱 경로 확인이 아니다).
- 기존 테스트의 `변경 중…` 표시 단언은 "문구 없음 + 잠금 유지"로 바꾸었고, 문구 유무로 요청 중을 판정하던 단언·미리보기 도우미는 `isMutating`으로 바꾸었다.
  잠금·요청 횟수 단언과 최종 401·실패 복귀 테스트의 단언은 바꾸지 않았다.

## 리뷰

- 티켓 리뷰(`41febf4..c28f039`): Standards 0건, Spec 중간 1건. 지적은 앱 코드가 아니라 촬영용 진입 파일(저장소 밖 작업 파일)의 결함이었다.
  별·더보기·제목 좌표 probe가 탭 가능한 첫 후보만 고르고 후보 수를 늘 1로 적어, 승인된 "대상 하나" 확인이 실제 중복을 놓쳤다. 리뷰어는 같은 key의 별 2개를 화면에 넣어 probe가 1로 보고하는 것을 재현했다.
- 반영: 후보를 모두 모아(별은 key 경로와 상세 상단 바 경로를 합치고 같은 요소는 한 번만) 실제 수를 적고, 정확히 하나일 때만 좌표·상태를 낸다. 0개·2개 이상이면 OS 탭 도구가 탭 전에 거부한다.
  iOS·Android는 같은 probe와 탭 도구를 쓴다. 대상 0·1·2개, 일부 화면 밖, key와 상세 경로 동시, 같은 요소 중복을 고정 검사로 두었다.
- 영향: 같은 진입 파일로 변경 전(41febf4) 코드와 변경 후 코드의 촬영 상태 6개를 다시 확인했고, 촬영 순간의 별·더보기 후보는 모두 1개였다.
  이미 찍은 변경 전 기기 증거의 별·더보기·제목 후보 수는 당시 상수 1이라 유일성 증명이 아니다. 재촬영 여부는 감독이 정한다.

## 검증

2026-11-07, 기준 코드 `c28f039`(로컬, 대역 데이터).

- 전체 검증 `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  앱 테스트 `+3223: All tests passed!`, 백엔드 `pytest: 2207 passed, 47 skipped, 3 warnings`.
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
  - 백엔드는 이번에 바꾸지 않았다. 건너뛴 Docker 복구·S3 통합 테스트는 이 변경과 무관하며 CI·별도 환경 대상이다.
- 수정 전 재현: 새 루트 앱 테스트 11개가 수정 전 코드에서 잠금·쓰기 1회 단언은 통과하고 `변경 중…` 없음 단언에서만 실패했다.
- 변형 확인: 표시 자리 6파일을 "진행 중이면 `변경 중…`을 그림"으로 잠시 바꾸면 배치 테스트 22개가 실패했다(원본 복원 확인).
- 촬영 진입 파일의 빌드 전 확인: 변경 전 코드에서 `변경 중…`이 보이는 상태 6개, 변경 후 코드에서 문구가 없는 상태 6개가 각각 통과했다.

미검증: 변경 후 iOS Simulator·Android Emulator 실행과 변경 전·후·Figma 비교·영상(감독 담당, 화면 확인 미완료). 실기기·운영 서버·CI는 이번 확인 범위가 아니다.

## 기능 전체 최종 검수와 main 병합

- #264 기능 전체 최종 검수(#265 `c28f039`, #266 `69f88be` 포함): Standards 0건, Spec 0건. #266 세부 검증은 [카테고리 이력](2026-11-07-category-pending-label.md)에 있다.
- `488ddf0`에서 `origin/main`(`b8d4b45`, 아이콘 접근성 이름·미분류 예약 이름 #268)을 병합했다. 양쪽 결정대로 main의 `semanticLabel`·`Semantics`와 이 브랜치의 `isMutating`을 모두 보존했다.
  main에서 온 접근성 테스트 `frontend/test/icon_button_semantics_test.dart`의 콘텐츠 fixture에만 `isMutating: mutating`을 보완했다(앱 코드 추가 변경 없음).

## 전체 검사(최종)

2026-11-07 14:50–14:57, 기준 코드 `488ddf0`(병합 뒤, 로컬, 대역 데이터).

- 전체 검증 `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  앱 테스트 `+3253: All tests passed!`, 백엔드 `pytest: 2207 passed, 47 skipped, 3 warnings`.
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
  - 건너뛴 Docker 복구·S3 통합 테스트는 이 기능과 무관하며 CI·별도 환경 대상이다.

화면: 변경 전 iOS·Android 기기 촬영은 #265 단계에서 확보했다. 변경 후 촬영, 변경 전·후·Figma 3열 비교와 영상은 아직 하지 않았으며 최종 촬영 단계(감독)에 남아 있다.
실기기·운영 서버·CI는 이번 확인 범위가 아니다.
