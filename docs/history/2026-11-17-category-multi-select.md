# 콘텐츠 카테고리 여러 개 고르기 (#408)

2026-11-17, 브랜치 `feat/category-multi-select`. 시작 커밋 `3007b0e`, 구현 커밋 `9b3317c`, 리뷰 반영 커밋 `4696839`. 그 뒤 main `00c30c2`(#406)를 합친 `327d582`와 업데이트 내역 빈 줄 맞춤 `37c2e95`, 이력 문서 `97f8285`와 기기 확인 결과를 더한 이력 갱신 커밋이 있다.

## 문제

- 출처: 팀 피드백 시트 64, 팀 회의(2026-11-16) "카테고리 선택 화면에서 여러개 선택할 수 있게".
- 콘텐츠 관리의 "카테고리 변경"은 한 개만 고를 수 있었다. 하나를 누르면 그 카테고리로 바로 옮겨지고 바텀시트가 닫혀 다른 카테고리가 빠졌다.
- 서버와 DB는 이미 콘텐츠 하나에 카테고리 여러 개를 저장하고(`PUT /contents/{id}/categories`의 `category_ids` 목록) 돌려준다. 앱만 한 개로 보냈다. 서버는 바꾸지 않았다.

## 사용자 결정

이슈 #408 결정 기록을 따른다. 이 작업 중 추가로 받은 결정은 아래 "바뀐 기존 테스트"의 두 승인이다.

- ① 아카이브 앱 쪽 거르기: 구현 첫 단계에서 실측한 뒤 "속한 카테고리 중 하나라도 이름이 같으면"으로 바꾼다.
- ② 대표 카테고리: 앱이 콘텐츠의 카테고리를 앱 카테고리 목록 순서로 정렬하고, 배지 순서도 함께 바뀐다. 목록에 없는 카테고리는 뒤에 둔다.
- ③ 변경 중 표시: 지금처럼 글자 없이 바로 반영하고 콘텐츠 관리를 잠근다.
- 고를 카테고리가 0개인 상태는 동작만 정하고 디자인은 '디자인 확인 필요'로 올린다.

## 바꾼 것

- 새 화면 `frontend/lib/shared/category/category_change_screen.dart`(Figma `403:4438`, 2026-11-17 조회).
  - 헤더 "‹ 카테고리 변경", "N개 선택"·"전체 선택/전체 해제", 행(폴더 색·이름·저장 시각 규칙·원형 체크), 아래 고정 "선택 완료".
  - 미분류 행은 없다. 지우는 중 행은 누를 수 없고, 전체 선택/해제가 건너뛴다.
  - "선택 완료" 판정 순서(이슈 1–6단계): 중복 제출 무시 → 계정 세대가 다르면 닫기 → 콘텐츠가 없으면 닫기 → 처음 체크와 같으면 닫기 → 최신 목록 순서로 지우는 중·지워진 것을 뺀 목록 → 닫고 변경 시작.
  - 화면이 열린 동안의 최신 카테고리 목록·계정 세대·콘텐츠 존재 여부는 `CategoryChangeScope`(앱 `MaterialApp.builder`)로 받는다. 공급원은 `CategoryManagementViewModel`이다. 계정 세대는 저장소 `accountVersion`이다.
- 체크 자산 2개(`category-change-check-selected/unselected.svg`)를 Figma 원본 그대로 추가했다. 뒤로·폴더 아이콘은 기존 자산과 같아 재사용했다.
- 저장소 `beginContentCategoryChange(int, List<int>)`: 중복 합치기, 모르는 ID·지우는 중·지워진 ID·미분류와 다른 카테고리 혼합이면 시작 거절, `[]`는 바로 미분류로 보이고 `PUT []`.
- 앱 동작·뷰모델 5곳·화면 콜백을 카테고리 ID 목록으로 바꿨다.
- `contentFromApi`: 앱 카테고리 목록 순서로 정렬, 목록에 없는 것은 뒤에 서버 순서로 둔다.
- 아카이브 `ContentListView`의 서버 목록 없는 갈래: 속한 카테고리 중 하나라도 이름이 같으면 보인다.
  - 실측: 실제 앱 조립은 아카이브에 항상 서버 목록을 넘겨 이 갈래를 타지 않는다(`category_multi_select_app_test` 'archive'에서 단언).
- 콘텐츠 관리 메뉴 설명을 "이 콘텐츠를 넣을 카테고리를 골라요."로 바꿨다.
- 옛 `CategoryChangeSheet`·`CategoryChangeTile`은 쓰는 곳이 없어 지웠다.
- 문서: `docs/figma-ui-alignment-plan.md`(현재 기준 [64], 디자인 확인 필요 3건), `CHANGELOG.md` 미배포 추가. `frontend/README.md`는 `lib/shared/category/` 안내가 이미 있어 바꾸지 않았다.

## 새 테스트

- `frontend/test/data/content_repository_test.dart` #408 group: 입력 목록 표의 각 행, 여러 개 실패 되돌림, 계정 초기화 뒤 늦은 응답.
- `frontend/test/presentation/content_mapper_test.dart`: 앱 [A,B]·서버 [B,A], 부분 목록, 빈 목록.
- `frontend/test/app/content_category_change_test.dart`(34건): 시작 체크, 토글·N, 전체 선택/해제, 지우는 중 행과 삭제 상태 변화, 스크롤, 0개 상태, 판정 표 9행·지워진 카테고리·계정 변경·콘텐츠 삭제·연타, ‹·Android 뒤로·iOS 밀기, 스크린리더, 넘침(40자·"N개 선택/전체 해제"·메뉴 설명, 1.0/1.3배, 320폭), 아카이브 거르기.
- `frontend/test/category_multi_select_app_test.dart`(8건, 실제 앱 + 가짜 HTTP): 진입 4곳(아카이브·즐겨찾기·검색·상세), 두 폴더·홈 두 칩·해제 시 빠짐·홈 카드와 상세의 목록 순서, 실패 되돌림, 열린 사이 원본 {A}→{B} 갱신 두 사례.
- 응답 뒤 계정 변경은 기존 `content_mutation_test` 'old-account category success/failure'가 같은 경로를 고정한다(인자만 목록으로 연결).

## 바뀐 기존 테스트

이슈 허용표 범위:

| 파일 | 바꾼 것 |
| --- | --- |
| `test/sheet_safe_area_test.dart` | 타입 이름, 헤더 위치·화면 높이 단언을 새 화면 기준으로, 행 누른 뒤 "선택 완료", 콜백 인자 목록, 긴 목록 행 찾기를 스크롤로 |
| `test/phone_width_test.dart` | 타입 이름, 닫기를 ‹로 |
| `test/theme_font_overflow_test.dart` | 행 위젯 교체(`CategoryChangeRow`) |
| `test/uncategorized_name_test.dart` | 두 테스트를 "변경 화면에 미분류 행 없음"으로 바꾸고 이름도 바꿈 |
| `test/data/content_repository_test.dart` | 시작 함수 인자 `2` → `[2]` |
| `test/category_delete_test.dart`, `content_mutation_test.dart`, `feed_pagination_test.dart`, `bookmark_alignment_test.dart`, `support/category_archive_preview.dart` | 콜백 인자·타입만 목록으로(기대값 그대로) |
| `test/support/unclassified_preview.dart` | 타입 이름, 행 누른 뒤 "선택 완료", 닫힘 대기 |
| `test/support/category_content_preview.dart` | 원래 카테고리 해제 + "여행" 체크 + "선택 완료" |

사용자 승인으로 추가한 행(2026-11-17 "추천대로", 행 누르기가 토글이 되어 허용표만으로 기존 결과를 지킬 수 없음):

| 파일 | 바꾼 것 | 지킨 것 |
| --- | --- | --- |
| `test/support/detail_preview.dart` | `_cat` 해제 → "선택 완료"(결과 [_second]). host 콜백을 ID 목록으로 받아 `copyWith(categories: ...)` | require·record 문구, 장면 순서, 결과 카테고리 하나 |
| `test/support/search_preview.dart` | 101 해제 + 102 체크 → "선택 완료"(결과 [102]) | 같음 |

사용자 승인으로 추가한 행(결정 ②, 2026-11-17 "추천대로"):

| 파일 | 바꾼 것 | 지킨 것 |
| --- | --- | --- |
| `test/archive_all_alignment_test.dart` 'source mapper preserves all embedded categories and absent metadata fallback' | 순서 [103,104,105,106,101,102] → [101,102,103,104,106,105], 105 인덱스 2 → 5, 대표 103 → 101 | 105 이름·색, 미분류 대체, 테스트 이름 |
| `test/category_delete_test.dart` 'stale rename callback rolls back to the latest category name and preserves secondary membership' | 순서 [202,101] → [101,202], 최신 이름 참조 `last` → `first` | '최신 이름', 멤버십 두 개, 테스트 이름 |

## 리뷰

- 티켓 검수(`3007b0e..9b3317c`): Standards 0건, Spec 중간 1건.
- 지적: 이슈가 반드시 넣으라고 한 "열린 사이 원본 갱신 {A}→{B}" 두 사례 테스트가 없었다. 수용했다(`4696839`).
  - 변경 화면을 {A}로 연 뒤 서버 기록을 {B}로 바꾸고, 화면 아래 아카이브의 실제 서버 읽기로 저장소 콘텐츠가 [B]가 된 것을 먼저 단언한다.
  - S1={A}: 요청 0회·닫힘·{B} 유지. S1={A,C}: 요청 1회·본문 [A,C]·최종 [A,C].
  - 변형: 처음 체크와 같으면 닫는 판정을 끈 복사본에서 S1={A} 테스트가 실패했다. 원본으로 되돌리고 차이가 없는지 확인했다.
- 같은 상태(열린 화면 아래 대상 콘텐츠가 바뀜)를 만드는 진입점: 피드 읽기(필터 전환·재시도·더 불러오기), 다른 쓰기 뒤 새로고침, 공유 저장 뒤 새로고침, 상세 읽기, 카테고리 이름 변경·삭제 정규화, 계정 초기화(판정 2단계가 막음). 화면은 연 시점 콘텐츠로 처음 체크를 잡으므로 결과가 같다.

## 검사

- 부분 검사 원본 로그는 작업 폴더 `.utmp/ticket-408/partial-*`에 있다. 실패를 먼저 확인한 단계: 저장소(컴파일 실패), 정렬(2건), 아카이브 거르기(1건).
- 카테고리를 다루는 테스트 75개 파일: `+2922`(구현 커밋 전 작업 트리).
- 전체 검증(main을 합친 `37c2e95`): `VERIFY result=PASS scope=all checks=12 failed=0`.
  - 앱 단계 `dart format --output=none --set-exit-if-changed lib test`·`flutter analyze --no-pub`·`flutter test --no-pub`(`+3824`)는 `app-validation.yml`과 같은 명령이라 따로 돌리지 않았다.
  - `pytest: 2743 passed, 49 skipped, 3 warnings in 347.03s (0:05:47)`
  - `pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 이 문서 커밋은 문서만 바꾸므로 전체 검증을 반복하지 않았다(근거 커밋 `37c2e95`).

## 화면 확인

감독이 기기에서 확인했다. 대상은 제품 커밋 `97f8285`다. 제품·테스트 코드는 전체 검증을 받은 `37c2e95`와 같고 그 뒤 바뀐 것은 이 문서뿐이다. 변경 전은 시작 커밋 `3007b0e`를 따로 꺼낸 임시 작업 트리에서 빌드했고, 촬영 뒤 지웠다. 로컬 대역 데이터(가짜 HTTP)로 확인했으며 운영 서버·실기기 결과가 아니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 기기 | iPhone 16 Simulator, iOS 18.6 | Medium_Phone Emulator, Android 16(API 36) |
| 화면 크기 | 393×852pt, 배율 3 | 411.43×914.29dp, 배율 2.625(1080×2400) |
| 안전 영역 | 위 59 / 아래 34 | 위 24 / 아래 24 |

- 같은 플랫폼의 변경 전·후는 같은 기종·크기·데이터·상태·글자 배율·스크롤 위치로 맞췄다. 글자 배율은 기본 1.0, 메뉴 설명과 40자 이름은 1.3이다. 스크롤은 맨 위 또는 목록 끝이다. 원본 화면은 보정하지 않았다.
- 촬영한 상태 11개(플랫폼마다 변경 전·후 각 11장, 조건 판정 모두 통과):

| 상태 | 내용 |
| --- | --- |
| home | 홈 카드의 대표 카테고리 |
| menu, menu13 | 콘텐츠 관리 메뉴의 새 설명(배율 1.0, 1.3) |
| two | 두 개 선택 |
| all | 전체 선택 뒤("전체 해제" 보임) |
| zero | 미분류 콘텐츠로 열어 0개 선택 |
| deleting | 지우는 중 행 포함(체크 유지, "삭제 중…") |
| long | 40자 이름, 배율 1.3(한 줄 말줄임) |
| scroll | 목록 끝까지 스크롤, "선택 완료" 고정 |
| folder101, folder102 | 같은 콘텐츠가 두 폴더에 모두 보임 |

- 변경 전은 옛 단일 선택 바텀시트다. 변경 전 two·all은 같은 콘텐츠로 연 옛 화면이며, 옛 화면이 여러 개 고르기를 했다는 뜻이 아니다. zero는 "미분류 콘텐츠를 열어 0개 선택"이며, 고를 카테고리 자체가 없는 상태가 아니다.
- 홈 대표 카테고리와 배지 순서가 전·후에 다른 것은 결정 ②의 결과다.
- 폴더 화면의 개수(폴더 4개·2개, 전체 5개)는 서버 `total_count`가 아니다. 대역 서버가 `next_cursor=null`로 전체 결과를 한 번에 주어, 앱이 받은 항목 수로 보인 값이다.
- 저장: 두 플랫폼 모두 콘텐츠 601에 102를 더해 "선택 완료" → `PUT category_ids=[101,102]` 1회.
- 뒤로: 콘텐츠 602의 체크를 바꾼 뒤 뒤로 나가면 요청이 더 가지 않았다. Android는 시스템 뒤로 키, iOS는 화면 위 ‹ 버튼으로 확인했다.
- OS 스크롤: Android는 실제 OS 스와이프로 목록 끝(offset 345.71 = 최대)에 닿았다. iOS는 OS 스와이프 뒤 양수 offset을 확인했다(끝에서 튕기는 중의 값이라 멈춘 위치·속도의 근거로 쓰지 않는다).
- 영상: 두 플랫폼의 선택·스크롤 원본 영상(iOS 2.995초·4.712초, Android 2.681초·3.933초)과 Android 비교 영상을 남겼다. 영상 속 스크롤은 앱 안 명령으로 움직였으며 OS 스크롤 근거와 따로 본다.
- 스크린리더 구조(행의 이름·선택 여부, 버튼)는 접근성 트리로 확인했다. 실제 음성은 아래 사람 확인 대기다.
- 함께 합친 #406 iOS 설정(앱 이름 허투루, 세로 방향, 비면제 암호화 false, privacy manifest)이 빌드 산출물에 들어 있음을 확인했다.
- Figma 비교: [64] `406:4306`(2026-11-17 조회, 375×812)과 변경 전·후를 플랫폼별 한 장으로 나란히 비교했다. 기기와 Figma 프레임의 크기·안전 영역 차이는 이미지에 적었다. 메뉴 설명은 사용자 결정 문구이고 별도 Figma가 없어 그 칸을 비웠다.
- 로컬 증거: `.utmp/ticket-408/compare-ios.png`, `.utmp/ticket-408/compare-android.png`, `.utmp/ticket-408/compare-android.mp4`, `.utmp/ticket-408/screens/`, `.utmp/ticket-408/final-capture-evidence.md`(Git에 올리지 않는 작업 폴더).
- 촬영 도구 보충 검수: Standards 0건, Spec 낮음 1건. 위 개수 표시 근거 설명이 틀린 것을 바로잡았고, 제품·대역 데이터 수정과 재촬영은 필요 없었다.

### 기존 helper 실행

기존 촬영 helper 두 개와 Android 보완 실행에서 아래 실패가 나왔다. 모두 시작 커밋 `3007b0e`에서도 같은 조건·같은 결과라 **기존 실패, 별도 작업**으로 기록했다. 원본 helper의 기대값은 바꾸지 않았다.

| helper | 실패 | 기준 / 현재 | 원인 |
| --- | --- | --- | --- |
| `test/support/detail_preview.dart` | 원본 사진 시트를 열 때 `readAsset` 2회(기대 1회) | 3/3 / 3/3, iPhone 16 Simulator | 상세의 원본 사진 읽기가 끝난 뒤 시트를 열면, 이미 받은 사진을 쓰지 않고 다시 읽는다(진행 중인 읽기만 재사용). 사진 상세 동작이라 #408과 무관하다 |
| `test/support/category_content_preview.dart` | 첫 단언: 화면 `총 -개`, 측정 `총 5개` | 3/3 / 3/3, iPhone 16 Simulator | 대역 서버가 `total_count`를 주지 않고 다음 페이지가 남아 있어 앱이 `총 -개`를 그린다. #408 조작 앞에서 실패한다 |
| 같은 helper(첫 단언을 넘긴 보완 실행) | 삭제한 콘텐츠가 목록에 남음 | 같음 | 삭제 확인 창에서 "삭제"를 누르지 않는 것으로 추정(화면 정황, 코드로 확정하지 않음) |
| 같은 helper | 이번주 추천 요청 2건이 대역 서버에 없음 | 같음 | 대역 서버가 이 요청을 처리하지 않아 오류 스낵바가 뜬다 |
| 같은 helper, Android 보완 실행 | 정렬 팝업 항목 Row 오른쪽 2.5px 넘침(`frontend/lib/features/archive/archive_widgets.dart:540`, `_ArchiveSortOption`) | 각 1회 같은 오류 | 가용 폭 113, 높이 27에 글자·간격·선택 체크가 들어간다. 실제 제품 위젯이라 같은 폭·글꼴·배율·선택 옵션이면 실제 앱에서도 날 수 있다(운영 앱은 확인하지 않음) |

- category_content의 보완 실행: `total_count=5`를 넣은 작업 폴더 복사본으로 기준·현재 모두 첫 단언과 #408 카테고리 조작을 포함한 12개 확인을 통과했다. 그 뒤 삭제 단언·이번주 추천 2건·2.5px 넘침이 남아, **helper 전체 통과가 아니다**.
- 실패 지점 뒤에 도달하지 못해 미검증인 장면: detail helper의 원본 사진 시트 닫기·하단 탭 4개·뒤로 도착지, category_content helper의 삭제 정상 흐름·하단 탭 4개·마지막 완료.
- 정상 비교에서 뺀 자료: 기준 실행 중 찍힌 Android System UI "응답 없음" 화면, 이번주 추천 오류 스낵바가 아래를 가린 보완 목록 화면.
- 로컬 진단 보고: `.utmp/ticket-408/diagnosis/report.md`, `.utmp/ticket-408/category-diagnosis/report.md`, 실행 기록 `.utmp/ticket-408/category-capture/runs/`.

## 미검증·사람 확인 대기

- 미검증: 고를 카테고리가 0개인 상태 촬영(디자인 확인 필요, 동작은 자동 테스트로 확인). iOS 화면 가장자리 밀어서 뒤로(촬영 도구가 지원하지 않음, 자동 위젯 테스트로 따로 확인).
- 범위 밖, 사용자 확인 대기: 운영 서버 0.6.2 테스트 빌드와 사용자 계정(두 카테고리 지정 → 아카이브 두 폴더·홈 두 칩 → 하나 해제), 실기기 iPhone 13 VoiceOver 음성. 로컬 결과나 자동 semantics 테스트로 대신하지 않는다.
- 0.6.1 이하 앱은 카테고리를 바꾸면 하나만 보내 여러 개 지정이 한 개로 바뀐다(테스터는 0.6.2로 올린다). 배포된 0.6.1 바이너리는 확인하지 않았다.
