# 홈 '최근 저장한 콘텐츠' 카드를 한 장 단위로 가운데에 맞춰 멈추기 (#389)

2026-11-15, 브랜치 `fix/home-carousel-snap`. 시작 커밋 `af2fb2b`, 구현 커밋 `b86c090`, 리뷰 반영·문서 커밋은 이 문서와 같은 커밋이다.
팀 피드백 시트 53("콘텐츠 보여주는 거 가로 캐러셀 고정됐으면 좋겠음", 제보자 뜻: 하나 넘기면 그 콘텐츠에 맞춰 멈추기)을 다룬다.

## 문제

- 홈 '최근 저장한 콘텐츠' 카드 목록(최대 4장, 카드 298·간격 8)은 손을 뗀 자리(iOS는 관성 뒤 자리)에서 그대로 멈춰 카드 두 장이 반씩 걸쳤다.

## 사용자 결정

- 2026-11-15(이슈 #389 확정 절): (a) "한 장씩 (Recommended)", (b) "화면 가운데 (Recommended)", (c) "최근 저장한 콘텐츠만 (Recommended)", (d) 1.3배·320 폭 추가 처리 없음.
- 2026-11-15 "지금 구현 유지"(리뷰 지적 뒤 조율이 두 선택지를 보임. 추천안 "빠른 튕김은 항상 한 장"은 고르지 않음): 손 뗀 자리에서 가장 가까운 카드 + 빠르게 튕기면 그 방향으로 한 장 더(Flutter 기본 페이지 넘김과 같은 방식). 카드 한 장 폭보다 길게 빠르게 밀면 두 장 넘어갈 수 있다.
- 이슈 #389의 "세게 튕겨도 한 장", "한 번 튕김 = 한 장"과 다른 점: 놓을 때 이미 한 장 가까이 넘게 끌었으면 그 자리 기준으로 한 장 더 간다(예: 폭 393, 첫 카드에서 350 빠르게 밀기 → 3번째 카드). 한 칸 미만으로 튕기면 지금처럼 한 장이다. 이슈 본문은 고치지 않았다.

## 구현

- `frontend/lib/features/home/home_screen.dart`: 최근 카드 목록에 `_RecentCardSnapPhysics`를 붙였다. 위치 ÷ 306을 기준으로, 속도가 허용 오차를 넘으면 그 방향으로 0.5를 더하거나 빼 반올림한 카드 자리(306 배수)로 스프링 이동한다. 끝 밖으로 당긴 경우는 플랫폼 기본 동작에 맡긴다. 양쪽 여백 `(폭 − 298) / 2`는 그대로라 멈춘 카드 가운데가 화면 가운데다.
- 같은 목록에 `scrollCacheExtent`(918)로 카드 4장을 처음부터 배치한다. 없으면 세게 튕길 때 스프링이 목표를 조금 지나치는 동안 다음 카드가 새로 배치되며 끝 위치 추정값이 바뀌어 다시 계산되고, 150 거리 튕김도 두 장(612) 넘어갔다(부분 검사에서 재현).
- 점 표시 계산과 맞춤 간격이 같은 상수 `_recentCardStride`(306)를 쓴다. 위젯 종류(`ListView`)·controller는 그대로라 기존 테스트·기기 측정 스크립트의 목록 찾기는 바꾸지 않았다.

## 테스트

- `frontend/test/home_alignment_test.dart`에 group 'recent cards snap one card to the center' 19건을 더했다: 천천히 100 → 0, 천천히 200 → 306, 짧게 튕기기 → 306, 세게 짧게(150·8000px/s) → 306, 2번째에서 오른쪽 → 0, 끝에서 더 튕기기 → 918(시작 직후 `maxScrollExtent` 918), 카드 1장 → 0, 폭 320·393 × 배율 1.0·1.3 × Android·iOS에서 멈춘 카드 가운데 = 폭/2, "지금 구현 유지" 회귀(폭 393, 350·3000px/s 왼쪽 0 → 612·점 2, 오른쪽 918 → 306·점 1, Android·iOS).
- 변경 전 `af2fb2b`에서 첫 15건 중 14건 실패(카드 1장만 통과), 1–3번은 손 뗀 자리 70·170·235.1에서 멈췄다.
- 기존 테스트는 바꾸지 않았다(`git diff af2fb2b -- frontend/test`에 지운 줄 없음). 이슈 허용 표의 ①·② 수정도 쓰지 않았다.

## 검증

- 전체 검증(구현 `b86c090` + 이 커밋의 테스트 변경, 문서 반영 전): `VERIFY result=PASS scope=all checks=12 failed=0`. 앱 테스트 3682건 통과. 백엔드 pytest 2667 passed, 49 skipped. skip은 `tests/deployment` 48건(`RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are …` 외 6종)과 `tests/integration` 1건(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…`)이다. 백엔드는 바꾸지 않았다.
- 변경 전 화면: 감독이 iOS Simulator iPhone 16(iOS 18.6, 393×852)·Android Emulator `Medium_Phone`(Android 16, 약 411.43×914.29)에서 6상태(`home-recent-top`·`slow-short`·`slow-long`·`flick`·`last`·`scale13`)와 영상 4개씩을 촬영했다. 손 뗀 자리에서 걸쳐 멈췄다(예: iOS slow-short 125.0, Android slow-short 91.4).
- 변경 후 화면·카드 탭·별 탭·Figma C01 `111:3621` 비교: 아직 하지 않았다(감독 최종 촬영 예정).
- 운영 서버·실기기는 범위 밖이다. 원격 CI는 PR 뒤 확인하며 아직 실행하지 않았다.
