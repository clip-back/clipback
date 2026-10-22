# 카테고리 목록 표현

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-9ed9bafec172edfd"></a>

### 카테고리 목록 화면의 1배율 맞춤 — 2026-10-17

<a id="b-2344cb40853ba106"></a>

`36e9725` 기준으로 [E02 기본](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4133)·[E03 미분류 있음](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4160)의 확정 영역을 적용했다. 헤더64px·탭64/52/46px·정렬 행52px·일반 행44px·미분류 배너48px과 Pretendard 기본 글자·정확한SVG7개를 맞췄다. 일반 행의 개수는 표시만 숨기고 서버 메타데이터/더보기 집계·실제 이름/날짜/색상을 보존한다. 미분류 배너는 실제 서버 개수>0일 때만 표시하며 집계 누락을 빈 계정 확인으로 사용하지 않는다.

<a id="b-e3613a97db129c9e"></a>

설정은 기존 카테고리 관리로 연결하고 마이의 기존 진입도 유지한다. 관리 상단/OS 뒤로가기는 진입 화면으로 돌아가며 아카이브 카테고리 탭·목록 위치를 복원한다. 다른 계정으로 바뀌면 세션 스크롤/복귀 출처를 초기화한다. 기본 `CategoryRow`의 관리 UI·CRUD/API·모델·콘텐츠 보존 정책은 유지한다. 정렬 메뉴/화살표와 미선택 굵기 확정, 전체/미분류 콘텐츠 목록·관리 화면 맞춤은 후속이다.

<a id="b-c8a502182481e704"></a>

새 검사는 다음과 같이 실행한다. 네이티브 프리뷰는 제품 위젯/시트와 메모리 콜백을 사용하고 루트 앱 연결·계정 전환 시 스크롤 초기화는 실제 `ClipbackApp` 회귀 검사로 별도 확인한다.

<a id="b-2e41b700f752ce38"></a>

```bash
cd frontend
flutter test --no-pub test/category_archive_alignment_test.dart test/feed_pagination_test.dart
flutter run --no-pub -d <device-id> -t test/support/category_archive_preview.dart --dart-define=CATEGORY_ARCHIVE_PHASE=after
```

<a id="b-cf7a3f6d8bf21bad"></a>

프리뷰는 loopback `:8767`의 `/ready`·`/state`·`/status`, 정적 `/scene?kind=zero|positive&scroll=0`, 동작 `/run`을 제공한다. `zero`도 일반 카테고리12개가 있는 **미분류 메타데이터0개** 상태이며 전체 계정 빈 상태가 아니다. Android는 `adb -s <serial> forward tcp:8768 tcp:8767` 후 host의8768포트로 접근하며 종료 후 포워딩을 제거한다. 사진/저장 등 다른 프리뷰의 기존 실행 경로는 변경하지 않았다.

<a id="b-2a5e802ebd24faaf"></a>

- [이번 자동 검사](/private/tmp/clipback-category-archive-20261017/automatic-checks.json): 집중72/관련246/전체1,008건 통과·건너뜀0, 정적 분석 문제0건이다. iOS/Android 테마×폭320/375px×1배율의 스타일·경계·말줄임·정렬·탭을 확인했다. 기존 확대/저장/상세 회귀도 전체 실행에 포함했다.
- [Figma 조회](/private/tmp/clipback-category-archive-20261017/figma/reference-manifest.json)는 **08:24:09~08:24:15 UTC /17:24:09~17:24:15 KST**, 컨텍스트+원본2회·fallback/누락0이다. [BEFORE 게이트](/private/tmp/clipback-category-archive-20261017/before-gate.json) 통과 후 제품을 수정했다. 프리뷰의 실제 앱 테마를 보완하기 전 빌드는 `.attempts/theme-preflight/`에 보존하고 최종 촬영에서 제외했다.
- [동결 프리뷰/검사](/private/tmp/clipback-category-archive-20261017/fixture-manifest.json): SHA256 `227775685f4552f3c8743a11e71a2db8a9e244ad76d81b948ee1754fcb0cfa26` / `7576ce075821a6e108ba987e63983c54163ae330be73fbb057a4e3d01c2c6c85`는 전후 동일하다. [에셋/번들 검사](/private/tmp/clipback-category-archive-20261017/static-assets-verification.json)와 [보존 감사](/private/tmp/clipback-category-archive-20261017/preservation-audit.json)를 별도로 남긴다.

<a id="b-f2285bd12595dc33"></a>

- 첫 AFTER 동작 검사의 하단 ‘아카이브’ 선택자가 같은 이름의 상단 제목을 눌러 검증이 중단됐다. 제품 오류/통과로 처리하지 않고 `.attempts/nav-locator/`에 실패 원본·영상·리포트를 보존했다. 하단 바 내부로 합성 포인터 대상을 한정하는 검증 코드 한 줄만 수정하고, 기준 커밋 소스를 다시 적용해 BEFORE4원본을 새로 촬영한 뒤 동일 도구/데이터로 AFTER를 재검증했다. 렌더링·데이터·목표 판정은 바꾸지 않았으며 최초 성공 검사를 재촬영 결과로 사용하지 않는다.

<a id="b-af4c3ba18a5c7cb6"></a>

- 검증 도구의 선택자 보완 후 최종 동결 소스로 전체1,008건과 분석0건을 다시 확인했다. [소스 일치 기록](/private/tmp/clipback-category-archive-20261017/automatic-source-stamps.json)에 실행 전후 제품/프리뷰/검사 SHA256을 남겼다. SDK 캐시 권한으로 시작 전 중단된0건 실행은 시도 로그에 보존하고 테스트 성공으로 합산하지 않았다.

<a id="b-a52c0e119b3fa2fe"></a>

- [최종 양 플랫폼 실측/동작](/private/tmp/clipback-category-archive-20261017/native-validation-summary.json)과 [동일 조건/동결 QA](/private/tmp/clipback-category-archive-20261017/pair-verification.json): 새 BEFORE/AFTER OS원본 각4장·완전3열4쌍, Figma/조건 누락0건이다. 같은 대역 데이터·1배율·키보드0·스크롤0을 유지하며 원본을 자르거나 OS 영역을 보정하지 않았다.
- iPhone16/iOS18.6: 창 Size(393.0, 852.0)·DPR3.0·OS상단59.0/하단34.0px, 30기록·프레임워크 오류0건·style/layout/behavior/coverage/checksCompleted/전체 passed:true다. 실제 키보드 inset336.0→0px, 관리 복귀 탭1·스크롤180.0→180.0px을 확인했다.
- Android13/API33 제스처(AVD `Clipback_Share_API_33`·`sdk_gphone64_arm64`): 창 Size(392.7, 783.3)·DPR2.75·OS상단24.0/하단0.0px, 30기록·프레임워크 오류0건·style/layout/behavior/coverage/checksCompleted/전체 passed:true다. 실제 키보드 inset약274.91→0px, 관리 복귀 탭1·스크롤180.0→180.0px을 확인했다.
- 양 플랫폼에서 미분류0/2 각각 스크롤하며 일반 행12개의 완전 노출·최대 스크롤 마지막 행, 합성 포인터8회 이동의 실제 드래그, 검색/탭 왕복·실제 미분류ID99/일반ID101·관리 복귀, 생성/수정/삭제 시트와 실제 키보드·입력 보존·취소, 메모리콜백 생성/수정/삭제 및 고정 데이터 복원, 저장 진입 후 추가 저장 없는 닫기·네 하단 탭 콜백을 확인했다. 기본1배율의 목록 확인이며 전용 확대/3버튼 촬영은 추가하지 않았다.
- 네이티브 호스트의 관리/다른 화면 이동은 제품 위젯과 Navigator/메모리 대역을 사용한다. 실제 루트 앱의 관리 출처/OS뒤로가기/계정 세대 분리는 별도 ClipbackApp 자동 검사로 확인했다. 합성 포인터·controller 입력/로컬 콜백은 실제 HTTP 저장·OAuth·운영 서버·실기기·원격 CI 증거가 아니다.
- Figma375×812·예시6행과 실제 OS 창/안전 여백·대역12행/이름/날짜/분류색은 다르다. 공통 하단 바의64px+OS여백 정책을 유지하므로 Figma고정96px와 같다고 보고하지 않는다. 확정된 구성요소의 치수·역할·색상/간격을 확인했으며 전체 절대 좌표 일치를 주장하지 않는다.
- [새3열 비교4쌍](/private/tmp/clipback-category-archive-20261017/comparison-document.html) · [비교 QA](/private/tmp/clipback-category-archive-20261017/comparison-qa.json) · [영상 전체 디코딩](/private/tmp/clipback-category-archive-20261017/media-verification.json) · [환경 정리](/private/tmp/clipback-category-archive-20261017/cleanup-verification.json). 초기 실패 자료를 최종 성공 자료로 재사용하지 않았다.
- [iOS AFTER 영상](/private/tmp/clipback-category-archive-20261017/ios/after/interaction.mp4): 39.570000초·[1178, 2556]px, 전체 디코딩 종료코드0/오류로그0바이트·동작 완료까지 녹화 유지 확인.
- [Android AFTER 영상](/private/tmp/clipback-category-archive-20261017/android-gesture/after/interaction.mp4): 81.898311초·[1080, 2220]px, 전체 디코딩 종료코드0/오류로그0바이트·동작 완료까지 녹화 유지 확인.
- 검증 후 앱/기기·이번8767/8768포워딩·서버를 정리했고 Android 탐색/IME와 iOS 키보드 설정을 보존했다. [HTML 참조/문법 검사](/private/tmp/clipback-category-archive-20261017/comparison-html-verification.json)는 정적 검사이며 이번에는 비교HTTP서버·브라우저 상호작용을 실행하지 않았다.

<a id="b-e9cec17ac6824927"></a>

| 미분류 메타데이터 | iOS 변경 전 → 후 → Figma | Android 변경 전 → 후 → Figma |
| --- | --- | --- |
| 0개·배너 없음 | [3열 비교](/private/tmp/clipback-category-archive-20261017/comparisons/ios-category_archive_zero_scale_1_top.png) | [3열 비교](/private/tmp/clipback-category-archive-20261017/comparisons/android-gesture-category_archive_zero_scale_1_top.png) |
| 2개·배너 있음 | [3열 비교](/private/tmp/clipback-category-archive-20261017/comparisons/ios-category_archive_positive_scale_1_top.png) | [3열 비교](/private/tmp/clipback-category-archive-20261017/comparisons/android-gesture-category_archive_positive_scale_1_top.png) |

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-d9eba336eef9f9c5"></a>

기준 `36e9725`, Page 1 >261007의 E02(`111:4133`)·E03(`111:4160`)에서 상단/탭/정렬 행·일반 행·미분류 배너의 확정 표현을 적용했다. 원본SVG7개와 역할별 Pretendard를 사용하고 일반 행의 개수만 숨겼으며 실제 서버 집계/더보기 안내·실제 이름/날짜/분류색과 시각/ID/null 정렬을 유지했다. 미분류 배너는 실제 메타데이터 양수에만 표시한다. 설정→기존 관리·마이 진입을 유지하고 관리 복귀 탭/스크롤 보존·계정 세대 변경 초기화를 추가했다.

<a id="b-da0e5f57c9f52f61"></a>

- [이번 Figma 기록](/private/tmp/clipback-category-archive-20261017/figma/reference-manifest.json): 08:24:09~08:24:15 UTC(17:24:09~17:24:15 KST), E02/E03 컨텍스트+원본2회 성공·누락/fallback0이다.
- 제품 수정 전 실제 앱 테마 누락을 보완하고 동결했다. 초기 빌드/시도는 `.attempts/theme-preflight/`이며 최종 촬영으로 사용하지 않았다. 최종 RED7통과/10목표 실패·예상 밖 실패0과 theme probe1통과 뒤 새 BEFORE4원본/[게이트](/private/tmp/clipback-category-archive-20261017/before-gate.json)를 확보했다. [동결 SHA](/private/tmp/clipback-category-archive-20261017/fixture-manifest.json)는 전후 동일하다.
- [자동 검사](/private/tmp/clipback-category-archive-20261017/automatic-checks.json): 집중72/관련246/전체1,008건 통과·건너뜀/오류0, `flutter analyze --no-pub` 문제0건이다. 실제 `ClipbackApp`에서 관리 복귀/마이 출처/계정 전환/OS뒤로가기4건도 확인했다. 기존 확대·상세·저장 검사를 유지했다. [API/기존 행 보존](/private/tmp/clipback-category-archive-20261017/preservation-audit.json)·[에셋 검사](/private/tmp/clipback-category-archive-20261017/static-assets-verification.json)를 남긴다.
- 완료는 확정된 카테고리 목록1배율이다. 정렬 메뉴/화살표·미선택 탭 굵기 충돌·원본 없는 로딩/오류/전체 빈 상태는 확인 필요로 남겼다. 전체/미분류 콘텐츠 목록·관리 화면 맞춤과 새 확대 대응은 후속이다. API/모델/CRUD·콘텐츠 보존 정책 변경은 없다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-31b607ce9c589d22"></a>

기준 커밋은 `36e9725`이며 Page 1 > `261007`의 E02 기본(`111:4133`)·E03 미분류 있음(`111:4160`)을 대상으로 한다. 완료는 확정된 카테고리 목록 표현에 한정한다. 전체 콘텐츠 목록·미분류 콘텐츠 목록·카테고리 관리의 디자인 맞춤, 정렬 기능·API·데이터 모델 변경은 포함하지 않는다.

<a id="b-a60d2493b37945df"></a>

- [Figma 조회 기록](/private/tmp/clipback-category-archive-20261017/figma/reference-manifest.json): **2026-10-17 08:24:09~08:24:15 UTC / 17:24:09~17:24:15 KST**, `get_design_context`2회로 컨텍스트와375×812 원본2개를 함께 확보했다. 별도 메타데이터/스크린샷 재호출·호출 제한·fallback·원본 누락은0이다. 당시 원본/조회 시각을 과거 검증과 구분한다.
- 상단64px·좌우16px·검색/설정24px·아이콘 간격16px, 탭 바깥64px/안쪽52px/선택46px, 정렬 행52px을 적용한다. 제목18/SemiBold/−0.45/검정, 탭16/SemiBold/−0.4, 정렬14/Medium/−0.35/#767676, 카테고리명15/Medium/−0.375/#1A1A1A, 날짜12/Regular/−0.3/#B5BDC3를 저장소 Pretendard로 명시하며 AUTO 행간을 유지한다.
- 일반 행44px·좌16/우6px·폴더40×34px·글자 앞12px·글자 폭 최대156px·이름/날짜 사이2px·한 줄 말줄임·더보기44px 탭 영역/원24px을 적용했다. 실제 날짜/null 표현·시각/ID/null 정렬·분류색·mutation 상태와 콜백은 보존했다. 보통행 개수만 숨기고 모델의 실제 개수와 더보기 안내의 서버 집계는 유지한다.
- 미분류 배너는 실제 카테고리 메타데이터 개수>0일 때만 표시한다.48px/R8·좌우16px·내부8px·bookmark20px·chevron24px과 실제 개수/카테고리 ID를 사용한다. 미조회/집계 누락을 확인된0 또는 빈 계정으로 판단하지 않으며 새 상태별 UX를 만들지 않았다.
- [에셋 검사](/private/tmp/clipback-category-archive-20261017/static-assets-verification.json): Figma 원본7개를 편집 없이 새 로컬SVG로 등록했다. 설정의 흰 내부/검정 선 등 원색을 유지하고 폴더만 실제 분류색을 적용한다.6색 폴더 원본의 같은 도형을 확인했으며 전역 아이콘을 교체하지 않았다. 임시 다운로드URL과 전체 Figma 화면 이미지를 제품 에셋으로 사용하지 않는다.
- 사용자 확정으로 설정→기존 카테고리 관리에 연결하고 마이 진입도 유지한다. 관리 상단 뒤로가기/시스템 뒤로가기는 진입 화면으로 돌아가며 아카이브 탭1·목록 위치를 세션 안에서 보존한다. 계정 세대가 바뀌면 스크롤 버킷과 복귀 출처를 초기화한다. 실제 `ClipbackApp`의 관리 복귀/마이 출처/계정 전환/모달 우선 OS뒤로가기4건을 별도 회귀 검사했다.
- 제품 수정 전 원본4장을 새로 확보하고 [BEFORE 게이트](/private/tmp/clipback-category-archive-20261017/before-gate.json)를 통과한 뒤 수정했다. [동결 소스](/private/tmp/clipback-category-archive-20261017/fixture-manifest.json)의 프리뷰 SHA256은 `227775685f4552f3c8743a11e71a2db8a9e244ad76d81b948ee1754fcb0cfa26`, 집중 검사 SHA256은 `7576ce075821a6e108ba987e63983c54163ae330be73fbb057a4e3d01c2c6c85`이며 전후 동일하다.
- 촬영 전 실제 앱 테마 누락을 발견해 프리뷰를 보완했고 이전 빌드/시도는 `.attempts/theme-preflight/`에 분리했다. 그 시도는 최종 BEFORE로 사용하지 않는다. 실제 루트 테마로 수정 전 목표 실패10건/통과7건·예상 밖 실패0건과 테마 probe1통과를 확인했다. Android/위젯의 기존 상속 Roboto와 iOS의 기존 CupertinoSystemText를 임의 Pretendard로 대체한 BEFORE를 만들지 않았다.
- [이번 자동 검사](/private/tmp/clipback-category-archive-20261017/automatic-checks.json): 실제 Pretendard·iOS/Android 테마×폭320/375px×1배율, 집중 **72/72**(14.73초), 관련 **246/246**(18.47초), 전체 `flutter test --no-pub` **1,008/1,008**(79.74초), `flutter analyze --no-pub` **문제0건**(5.06초)이다. 건너뜀/오류0, 기존 확대·저장·상세 검사를 삭제하거나 건너뛰지 않았다. [보존 감사](/private/tmp/clipback-category-archive-20261017/preservation-audit.json)로 공통 관리 행/화면·API·모델·시트·테마와 기존 정렬의 보존을 별도로 확인한다.
- 정렬 메뉴/화살표와 미선택 탭 굵기는 확정 전까지 보류한다. ‘최신순’은 기존 읽기 전용 텍스트이며 기존 정렬을 유지한다. 미선택 굵기는 컨텍스트 충돌 때문에 기존600을 유지하고 확정된 색상/크기만 적용했다. 미확정 로딩/오류/전체 빈 상태·전체/미분류 콘텐츠 목록·관리 화면·새 확대 대응은 후속이다.
