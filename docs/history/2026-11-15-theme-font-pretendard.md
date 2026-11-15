# 글꼴을 따로 주지 않은 글자도 앱 글꼴 Pretendard로 (#391)

2026-11-15, 브랜치 `fix/theme-font-pretendard`. 시작 커밋 `2baefa0`, 구현 커밋 `29b085f`, 검수 반영 커밋 `93995a5`. 이후 변경은 이 문서뿐이며 제품·테스트 코드는 `93995a5`와 같다.

## 문제

- #380 진단에서 저장 실패 안내(SaveErrorToast)의 글꼴이 Pretendard가 아니라 기기 기본 글꼴(Android `Roboto`, iOS `CupertinoSystemText`)이었다.
- 원인은 앱 테마다. `clipback_app.dart`는 `ThemeData(fontFamily: 'Pretendard', textTheme: textTheme)`로 테마를 만드는데, `textTheme`은 `MaterialApp` 바깥 기본 테마(플랫폼 글자 묶음)에서 와서 글꼴 이름이 이미 들어 있다. Flutter는 `fontFamily`를 기본 글자 묶음에만 입힌 뒤 넘겨받은 `textTheme`을 합치므로 플랫폼 글꼴이 Pretendard를 덮었다.
- 그래서 글꼴을 따로 주지 않은 글자(테마 글자를 받는 `Text`, 버튼 기본 글자 등)가 양 플랫폼에서 Pretendard가 아니었다.

## 사용자 결정

- 2026-11-15 조율 질문: "별도 이슈로 조사 (Recommended)".
- 2026-11-15 정할 점 네 개:
  - (a) 고치는 방식: "테마 한 곳 수정 (Recommended)"
  - (b) 적용 범위: 전체, 이슈 하나(추천대로. (a)가 테마 수정이므로 자동으로 전체)
  - (c) 넘침 시험 범위: "고정 크기·바뀌는 문구 위치만 (Recommended)"
  - (d) 촬영 범위: "대표 화면 5곳 (Recommended)"
  - 굵기 700·800: "이번엔 확인만 (Recommended)". 글꼴 이름만 바꾸고 실제 굵기를 확인해 보고한다.
- 2026-11-15 구현 중 "추천대로"(선택지 B): 테마 수정은 그대로 두고, 테마가 닿지 않는 3곳의 버튼 `textStyle`에 `fontFamily: 'Pretendard'`만 한 줄씩 더한다. 크기·두께·색·줄높이는 그대로다.
  - `frontend/lib/shared/widgets/buttons.dart:33` `PrimaryButton`(`AppText.primaryButtonLabel`)
  - `frontend/lib/features/search/search_screen.dart:372` 검색 결과 없음 '전체 리스트 보기' 버튼
  - `frontend/lib/features/account/my_screen.dart:173` 마이 개수 '다시 시도' 버튼
  - 근거: `ButtonStyle.textStyle`은 테마 글자에 합쳐지지 않고 통째로 쓰여, 테마 수정 뒤에도 `fontFamily`가 null(기기 기본 글꼴)이었다. 이슈 글꼴 출처 표는 `PrimaryButton`을 '테마 상속'으로 적었으나 실제는 달랐다. 같은 유형은 이 3곳뿐이었다.

## 바꾼 것

- `frontend/lib/app/clipback_app.dart`: `Theme.of(context).textTheme.apply(fontFamily: 'Pretendard', bodyColor:…, displayColor:…)`. 스낵바 `contentTextStyle`의 중복 `fontFamily` 지정은 지웠다(결과는 Pretendard 14·색 그대로). 주석을 새 동작으로 고쳤다.
- 위 결정 B의 3곳에 `fontFamily: 'Pretendard'` 한 줄씩.
- 그대로인 것: 이미 Pretendard·`PretendardDetail`·`RiaSans`를 명시한 글자, 모든 글자의 크기·두께·색·줄높이·자간·배치.
- 새 테스트:
  - `frontend/test/theme_font_root_test.dart`: 루트 앱(`ClipbackApp`) 테마(Android·iOS)에서 테마 글자 묶음, 링크 저장 지연 안내(실제 저장 흐름), 일반형 목록 카드 제목·본문·배지, 콘텐츠 삭제 대화상자 버튼, `PrimaryButton`, `EmptyStatePanel`, 검색 결과 없음 버튼, 마이 '다시 시도'의 글꼴 Pretendard와 크기·굵기·줄높이(선언값, 미선언은 테마값 또는 null 그대로).
  - `frontend/test/theme_font_overflow_test.dart`: 실제 Pretendard 글꼴을 불러와(미로드면 실패) 폭 320·배율 1.0/1.3마다 따로 시험한다. 대상은 지연 안내, 사진 형식 안내, 목록 카드 최장 제목·본문, 카테고리 변경 줄 40자, `PrimaryButton`, 대화상자 3종 버튼, 홈 빈 상태, `EmptyStatePanel` 최장 문구, 전체보기 정렬 메뉴, 로그인 소셜·게스트 버튼, 검색 결과 없음 버튼, 마이 '다시 시도'다. 가로(말줄임·대상 위젯 안)와 세로(재배치 문단 높이 ≤ 할당 높이·`ClipRect`)를 나눠 본다. 알려진 잘림은 값을 기록하는 단언으로 두고 시험 이름에 드러낸다(아래 범위 밖 발견).
  - `frontend/test/support/theme_font_app.dart`: 루트 앱 + 홈 메모리 API, 링크 저장 POST 붙잡기, 앱 내비게이터로 위젯 띄우기, Pretendard 로드 확인.
- `CHANGELOG.md` 미배포 수정 한 줄.

## 바뀐 기존 테스트

| 테스트 | 바꾼 것 | 근거 |
| --- | --- | --- |
| `frontend/test/snackbar_font_root_test.dart` `_expectNoticeFont` | 테마 `bodyMedium`·`labelLarge` 글꼴 `Roboto` → `Pretendard`, 그 줄 주석, 함수 doc 끝 구절 | 이슈 허용 표 1행. 안내 글꼴·크기·색·두께·줄높이·자간 단언은 그대로 |
| 같은 파일 `SnackBarAction label keeps the theme labelLarge font` | 버튼 글자 `Roboto` → `Pretendard` | 이슈 허용 표 2행. 크기 단언·이름은 그대로 |
| `frontend/test/heic_photo_test.dart` `415 format message fits a 320pt toast at text scale …` | 표에 더한 행: 테마 복사본 `apply`에 `fontFamily: 'Pretendard'`, 글꼴 단언 `isNot('Pretendard')` → `'Pretendard'`, 주석 | 이슈 "커밋 전에 위 git grep을 다시 돌려 표 밖의 … 단언이 있으면 같은 기준으로 표에 더한다"와 감독 판단. 줄 수·폭 240·넘침·배율·이름은 그대로 |

- 고치지 않은 것(이슈 표 "바꾸지 않아도 됨"): `home_alignment_test.dart`의 'received' 테마, `uncategorized_name_test.dart`, 앱 병합을 따라 만든 테스트 테마(`bottom_safe_area`·`save_base_typography`·`save_scaled_layout`·`scaled_navigation_layout`), `test/support/*_preview.dart` 11곳. 모두 통과한다.
- `snackbar_font_root_test.dart` 파일 머리 주석("the rest of the theme and the SnackBarAction label keep their fonts")은 허용 칸 밖이라 그대로 두었다.
- 커밋 전 `git grep -nE "Roboto|CupertinoSystem|matchesGoldenFile|textTheme|DefaultTextStyle" -- frontend/test`의 표 밖 결과는 위 `heic_photo_test.dart`와 `category_management_alignment_test.dart:415`(본문 색 단언만, 글꼴·폭·줄 수 아님)였다.

## 굵기 700·800 (바꾸지 않음, 확인만)

앱의 `Pretendard` 글꼴 묶음에는 400·500·600 파일만 있다(700은 `PretendardDetail`). 같은 글을 굵기만 바꿔 폭(20px)과 그린 픽셀 양(40px 알파 합)을 flutter_tester 엔진에서 쟀다. 기기(iOS·Android) 엔진 값은 확인하지 않았다.

| 요청 굵기 | 폭 | 그린 양 | 실제로 쓰이는 얼굴 |
| --- | --- | --- | --- |
| 600 | 286.44 | 1,889,052 | Pretendard-SemiBold |
| 700 | 286.44 | 1,889,052 | SemiBold 그대로(합성 굵게 없음) |
| 800 | 286.44 | 2,066,318 (+9.4%) | SemiBold + 합성 굵게 |
| 참고: `PretendardDetail` 700 | 287.50 | 2,110,531 | Pretendard-Bold |

| 위치 | 선언 굵기 | 변경 전 글꼴 | 변경 후 렌더 |
| --- | --- | --- | --- |
| `shared/widgets/empty_state.dart:32` 빈 상태 제목 | 700 | 플랫폼 | SemiBold |
| `features/home/home_screen.dart:659` 홈 빈 상태 제목 | 700 | 플랫폼 | SemiBold |
| `features/search/search_screen.dart:352` 검색 결과 없음 제목 | 700 | 플랫폼 | SemiBold |
| `features/search/search_screen.dart:372` 검색 결과 없음 버튼 | 700 | null(기기 기본) | SemiBold(결정 B) |
| `shared/theme/app_text.dart` `primaryButtonLabel` | 700 | null(기기 기본) | SemiBold(결정 B) |
| `shared/category/category_sheets.dart:1019` 카테고리 선택 칩 | 700 | 플랫폼 | SemiBold |
| `shared/widgets/sheet_primitives.dart:28·65·121` 공통 시트 제목·줄 | 700 | 플랫폼 | SemiBold |
| `shared/theme/app_text.dart` `title24` | 800 | 플랫폼 | SemiBold + 합성 굵게(lib에서 쓰는 곳 없음) |

경로는 `frontend/lib/` 기준이다. 굵기 처리는 따로 정한다.

## 검사

- 바꾼 부분 테스트(`frontend/`):
  - 변경 전 실패 확인: 스낵바 테스트 7개 `Roboto`로 실패, 새 루트 앱 단언 실패, 결정 B 3곳을 잠시 되돌리면 검색·마이 버튼 단언 `null`로 실패.
  - 구현 뒤: 바꾼 4개 파일(overflow·root·snackbar·heic_photo) 85건 통과, 이슈 표 파일 8개 474건 통과, 바꾼 위젯·`ClipbackApp(`을 쓰는 테스트 59파일 1643건 통과.
  - 검수 반영 뒤: 넘침 시험 33건 통과, 알려진 잘림 기록을 지운 변형은 `clipped vertically: 29.0 > 22.4`로 실패, 바꾼 4개 파일 85건 통과.
- 촬영 진입 파일(`.utmp`, 저장소 밖)의 빌드 전 확인: 변경 후 `PHASE=after` 29건·`after-empty` 25건 통과. `2baefa0` 임시 워크트리에서 `before` 29건·`before-empty` 25건 통과.
- 전체 검증(`93995a5`, 검수 반영 뒤 한 번): `VERIFY result=PASS scope=all checks=12 failed=0`. 앱 테스트 3766건 통과.
  - `pytest: 2667 passed, 49 skipped, 3 warnings in 328.93s (0:05:28)`
  - `pytest skip: 48 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 이 문서 커밋은 문서만 바꾸므로 전체 검사를 반복하지 않았다(근거 커밋 `93995a5`).
- 단일 이슈의 코드 리뷰(`2baefa0..29b085f`): 높음 0·중간 2·낮음 1. 촬영 도구의 붙잡은 요청 정리(종료 확인 뒤 비우고 실패면 격리), 넘침 시험의 세로 잘림 대조, 변경 내역 문구 한정을 모두 반영했다(`93995a5`).

## 화면 확인

로컬 대역 데이터(`HomeBaseServer`, 콘텐츠 4개·빈 데이터)로 확인했다. 실기기·운영 서버는 범위 밖이며 원격 CI는 PR 생성 뒤 확인한다.

| 플랫폼 | 기기·OS·크기 | 결과 |
| --- | --- | --- |
| iOS | iPhone 16 Simulator, iOS 18.6, 393×852, 안전 영역 위 59·아래 34 | 6상태 × 배율 1.0·1.3 = 12행, 변경 전·후 판정 모두 통과 |
| Android | Medium_Phone Emulator, Android 16, 1080×2400 | 같은 12행, 변경 전·후 판정 모두 통과 |

- 상태: S1 링크 저장 지연 안내, S2 홈 '최근 저장한 콘텐츠' 카드, S3 카테고리 삭제 확인, S4 보관함 카테고리 목록, S5 전체보기 정렬 메뉴, S6 즐겨찾기 빈 상태. 배율은 앱 안 글자 배율(`/scale`)이다.
- S1 입력은 OS 입력(`orca emulator type`)만 썼고 선입력은 없다. 링크 저장 POST를 앱의 20초 제한보다 오래 붙잡아 지연 안내를 띄웠다.
- S1 실측: 변경 전 iOS `CupertinoSystemText`·Android `Roboto`, 변경 후 두 플랫폼 `Pretendard`. 두 플랫폼·두 배율 모두 전후 `drawnLines 2 / relaidLines 2 / truncated false`. Android 1.3배는 줄바꿈 위치가 바뀌었다("잠시 후 / 다시" → "잠시 후 다 / 시 시도해"). 이슈의 "1.3배 3줄"은 폭 320 기준이며 393·411 기기에서는 2줄이다(폭 320은 위젯 테스트로 확인).
- 바뀐 글자는 S1 안내와 S5 정렬 메뉴 항목뿐이다. S2·S3·S4·S6의 대상 문구는 이미 Pretendard를 명시해 변경 전과 같다.
- Figma 기준(2026-11-15 15:32 KST 조회, 파일 `svNWsTFh8Ws1Mpt8XQIcrN`): S2 C01 `111:3584`, S3 E12 `111:4484`, S4 E02 `111:4133`, S5 E01 `111:4117`(닫힌 정렬 버튼만, 열린 메뉴 원본 없음), S6 I02 `111:4103`. S1은 원본 없음.
- 비교 이미지(전·후·Figma 3열, 상태 12행): `.utmp/ticket-391-screens/compare-ios.png`, `.utmp/ticket-391-screens/compare-android.png`. 조건(스크롤·배율·안전 영역) 불일치 없음. 감독이 원본을 직접 확인했다. 사용자 최종 시각 판정은 별도다.

## 범위 밖 발견

- 일반형 `ContentListCard`(보관함 형식이 아닌 카드)의 `CategoryBadge`가 이름 40자에서 카드 밖으로 나간다(폭 320, 1.0배 오른쪽 323.5, 1.3배 410.3). 원인은 배지 `Positioned`에 너비 제한이 없는 기존 구조(`frontend/lib/shared/content/content_list_card.dart:54–57`)이며 글꼴과 무관하다.
- 같은 카드의 1.3배 세로 잘림: 제목 문단 높이 29 > 고정 높이 22.4(`content_list_card.dart:101–106`), 본문 62 > `ClipRect` 48(`:118–123`). 1.0배는 맞는다. `2baefa0`에서도 같은 값이고 시험 글꼴로 바꿔도 높이가 같아 글꼴과 무관하다(글자 크기 × 줄높이 × 배율).
- 이 일반형 카드는 지금 앱에서 도달하는 화면이 없다(`frontend/lib/features/archive/archive_screen.dart:176`의 조건상 보관함·즐겨찾기·검색은 Pretendard 명시 카드를 쓴다). 제품 레이아웃은 고치지 않았다.
- 촬영 대상 중 S2·S3·S4·S6 문구, 대화상자 버튼 3종, 앱 보관함 탭 라벨, 홈 확정 빈 상태는 이미 Pretendard 명시였다(이슈 글꼴 출처 표와 다름).
- 앱 병합을 따라 만든 테스트 테마 복사본과 `test/support/*_preview.dart`의 미리보기 테마는 이제 앱 테마(Pretendard)와 다르다.
- S5 화면에서 정렬 메뉴 뒤 보관함 카드 요약 3번째 줄이 위아래로 잘려 보이는 것은 변경 전 화면에도 같다(이번 변경과 무관).

## 미검증

- 실기기, 원격 CI.
- iOS 기기의 `CupertinoSystemText` 출발 경로는 자동 테스트로 재현되지 않는다. 테스트의 바깥 기본 테마가 처음 만든 Android 값으로 캐시돼 iOS 그룹도 `Roboto`에서 출발한다. 이 경로는 iOS Simulator 촬영(변경 전 `CupertinoSystemText` → 변경 후 `Pretendard`)으로만 확인했다.
- 굵기 700·800의 기기 엔진 렌더.
