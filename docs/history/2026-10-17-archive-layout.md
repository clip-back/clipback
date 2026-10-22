# 아카이브 전체보기 표현

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-46d54839798b9834"></a>

### 아카이브 전체보기의 1배율 맞춤 — 2026-10-17

<a id="b-7d7523cb29caa9fc"></a>

`35c3f5b` 기준으로 Page 1 > `261007`의 E01(`111:4117`) 정상 전체보기 상단·탭·정렬/개수 행과 콘텐츠 카드를 적용·검증했다. 사용자 기준으로 실제 복수 소속을 모두 순서대로 보이며 긴 이름은 한 줄 말줄임, 줄이 늘면 카드 높이를 늘린다. 미분류 콘텐츠 목록·원본 없는 빈/로딩/오류 상태·새 확대 맞춤은 이번 완료 범위가 아니다.

<a id="b-bdb9d5c0312e948e"></a>

- [이번 Figma 원본/컨텍스트](/private/tmp/clipback-archive-all-20261017/figma/reference-index.json): **2026-10-17 12:02:39 UTC /21:02:39 KST**에 E01 컨텍스트와 원본을 한 번 조회했다. 프레임은375×1102px, MCP PNG 원본은349×1024px이다. 누락/fallback0이며 원본을 늘리거나 스크롤별 대체 디자인을 만들지 않는다.
- 루트 전체보기에서 검증된 공통 카테고리 헤더64px·탭 외부64px/내부52px을 재사용하고 정렬/개수 행을52px로 맞췄다. 제목18SemiBold−0.45/검정, 탭16SemiBold−0.4, 정렬/개수14Medium−0.35/#767676의 Pretendard/AUTO다. 미선택 탭은 충돌하는 원본 기준을 임의 확정하지 않고 기존600을 유지한다.
- 한 행 카드는173px·좌우/상하16px이며 배지 영역은 최소22px/폭=카드−116px이다. Wrap8/8에 실제 `content.categories`의 이름·순서·tint/deep 색을 보존하고 긴 이름은 한 줄 말줄임한다. 추가 Wrap 높이만큼111px 본문 묶음을 함께 내린다. 제목16SemiBold/1.4·한 줄/최대폭min(311,카드−40), 요약15Regular/1.6·최대 두 줄/말줄임, 날짜14Regular/AUTO·아래16px을 적용한다.
- 원본 북마크28px·더보기24px을 시각 간격16px/오른쪽16px로 배치하고 각28px 탭 영역을 카드 전체 Stack 안에 둔다.22px 헤더 밖의 탭 영역이 잘리지 않도록 분리했으며 작업 중 잠금과 상태 안내를 유지한다. 구분선은 원본0.5px·실제 가용 폭이며 한 행 카드의 y127.5~128px에 표시한다. Figma의4px 슬롯과 실제 선 두께를 혼동하지 않는다.
- [원본/등록 감사](/private/tmp/clipback-archive-all-20261017/static-assets-verification.json): 검색1개는 기존 파일과 byte 동일, 설정/비선택 별2개는 기하/색이 같고 내부 clip ID 또는 XML 속성 순서만 달라 재사용했다. 선택 별·정렬 화살표·회색 더보기·구분선4개는 E01 원본 SVG를 그대로 등록했다. 모두 원색 무필터로 사용하고 전역 별/더보기 에셋을 덮어쓰지 않았다. 새 AFTER APK·iOS App.framework의7역할은 로컬 바이트/SHA·SVG root 크기와 일치했다. 원본과 byte 동일한5역할/비시각 XML만 다른2역할을 구분했다. 양 플랫폼 새 OS원본4장과 실제 SVG36회 관측에서 검색/설정24px·화살표16px·별28px·더보기24px·선335×0.5px 및 무필터를 확인했고 누락/불일치0이다. 양 기기의 실제 카드 폭은375px이며320px은 자동 검사 범위다.
- [보존 감사](/private/tmp/clipback-archive-all-20261017/preservation-audit.json): 기존 공유 카드 기본 본문과 정렬 팝업을 보존하고 표현 옵션 `archiveAllStyle=false`의 기본값은 유지한다. 검색·즐겨찾기·카테고리/미분류 목록에는 새 E01 표현을 적용하지 않는다. API/모델/Repository/FeedPage/루트 복귀·계정 정책과 기존 필수 생성 인수·콜백은 그대로다. API 목록의 개수는 ‘불러온 N개’이며 전체 통계999와 구별한다.
- [변경 전 게이트](/private/tmp/clipback-archive-all-20261017/before-gate.json): 제품 수정 전 같은6개 콘텐츠·1배율·키보드0·실제 스크롤0/300px의 새 OS원본을 플랫폼별2장씩 확보했다. [동결 프리뷰](/private/tmp/clipback-archive-all-20261017/fixture-manifest.json)의 canonical SHA는 `86d7babbdb13d5ff6eef5dcc548ba213001ea3b3ff06a6e8cdc1f47bfd5c0e12`다. 같은14개 집중 RED는5통과/9목표 차이이며 과거 검증을 이번 성공으로 사용하지 않는다.
- 선행 iOS 시도는 기존 native 공유 대기 안내가 헤더를 가려 비교에서 제외하고 [.attempts 진단](/private/tmp/clipback-archive-all-20261017/.attempts/native-pending-share-ios/attempt.json)에 원본을 보존했다. canonical 대역은 native 공유 채널을 메모리로 격리했으며 제품 공유 API/서비스는 변경하지 않았다. 초기 앱은 기존 native 공유 상태를 읽어 배너를 표시했다. mock 공유 자격 요청까지 확인됐지만 native 호출 완료 추적이 없어 실제 publish 완료 여부는 확인할 수 없다. 진단을 위해 기존 큐·자격 내용은 별도로 조회·출력·삭제하지 않았으며 자격 정보를 추정해 복원하지 않았다. 이후 canonical 채널 격리에서는 네이티브 위임0 계약을 적용했다.
- [이번 자동 검사](/private/tmp/clipback-archive-all-20261017/automatic-checks.json): 집중 **26/26**(5.420초), 관련 **309/309**(24.670초), 프리뷰 공유 격리 계약 **3/3**(2.576초), 전체 **1141/1141**(76.907초) 통과·건너뜀/오류0, `flutter analyze --no-pub` **문제0건**(3.1초)이다. 전체 검사 후 사용하지 않는 import 한 줄만 제거하고 최종 분석을 다시 통과했으며 런타임 로직은 바뀌지 않았다. 기존 확대·저장·페이지/복귀·분류/삭제 검사를 유지한다.
- 집중 검사는 실제 Pretendard·iOS/Android×폭320/375px×1배율의 글자/7역할 SVG·복수 배지/긴 이름·metadata 누락 ID와 빈 소속 fallback·기본 공유 카드 보존을 확인했다. 별도12개 회귀로 작업 중 잠금과28px 버튼의 중심/위1px/아래1px 탭을 확인하고, 공유 격리3개는 검증 도구가 기존 native 큐/자격 저장소를 읽거나 쓰지 않는 계약을 검사했다. AFTER 양 플랫폼 실행과 새 비교4쌍/영상2개·환경 정리도 아래 실제 결과로 확인했다. 자동 검사와 네이티브 실행 근거를 구분한다.
- 기기 프리뷰는 실제 ClipbackApp·API/Repository/ViewModel/복귀 동선에 in-process MockClient와 메모리 세션을 연결한다. 합성 포인터/controller·native IME 검증을 외부 HTTP·실제 OAuth·영속 저장·운영 서버·실기기·원격 CI 성공으로 보고하지 않는다.

<a id="b-05f82c12f37b13d7"></a>

- [양 플랫폼 실측/동작](/private/tmp/clipback-archive-all-20261017/native-validation-summary.json): iPhone16/iOS18.6은 창393×852px·DPR3·OS상단59/하단34px, Android13/API33 제스처(Clipback_Share_API_33, sdk_gphone64_arm64)는 창392.73×783.27px·DPR2.75·OS상단24/하단0px이다. 각 **33기록·style/layout/behavior/coverage/checksCompleted/전체 passed:true·프레임워크 오류0건**을 확인했다. 촬영4상태는 모두 실제1배율/IME0/스크롤0 또는300px이다.
- 실제 루트 앱에서 관리/검색/상세/카테고리 탭 왕복 후 전체보기 탭0·같은 FeedPage/버전/ID 순서·스크롤300px을 보존했다. 합성 포인터8회 이동의 실제 드래그, 최대 위치의 마지막 행과6행 모두 완전 노출, 북마크 PUT/복원, 더보기 열기/취소, 저장 진입/추가 저장 없는 닫기, 기존 최신순↔북마크 우선의 서버 대역 조회/순서·스크롤 초기화를 확인했다.
- [시점별 데이터/동일 조건 QA](/private/tmp/clipback-archive-all-20261017/pair-verification.json)는 복사된 `bookmarkedIds`/`rows.bookmarked`의 `[601,602]→[602]` 전이와 PUT2회, 실행 중 즉시 요구 조건·최종 원본 데이터 복원을 대조했다(ID 접두어는 `api-`). `snapshot.serverRecords`는 mutable list 참조이므로 과거 북마크 상태의 증거로 사용하지 않고 최종/정적 보존 확인에만 사용했다.
- 실제 전 행 방문 후 `maximum_scroll` 기록의 끝 위치는 iOS661.00px·Android660.73px이다. 최종 정렬 후 snapshot의 `maxScrollExtent`는 가변 높이 sliver의 지연 추정값이므로 이 실측 대신 사용하지 않는다. 부분 노출/cache 행과 완전 노출을 구별했고 배지2줄/3줄에서 본문·선·날짜가 함께 내려갔다.
- [새 변경 전 → 변경 후 → Figma 비교4쌍](/private/tmp/clipback-archive-all-20261017/comparison-document.html)·[비교 QA](/private/tmp/clipback-archive-all-20261017/comparison-qa.json): BEFORE 원본4장 불변, 동결 fixture/최종 빌드 소스 일치, 조건 불일치/원본 누락/팝업/대상 잘림0이다. [iOS 두 스크롤 비교](/private/tmp/clipback-archive-all-20261017/comparisons/ios-comparison-overview.png)·[Android 두 스크롤 비교](/private/tmp/clipback-archive-all-20261017/comparisons/android-gesture-comparison-overview.png)를 함께 제공한다.
- Figma375×1102px의 예제 이름/색/총6개·한 개 배지와 실제6개 대역/복수 소속·‘불러온6개’, OS 창/안전 영역은 다르다. 기존 공통 하단64px+실제 OS 여백을 유지해 Figma고정96px과 전체 좌표 일치를 주장하지 않는다. 원본을 자르거나 OS를 보정하지 않았고 스크롤300용/복수 소속용 대체 Figma를 만들지 않았다.
- [iOS AFTER 영상](/private/tmp/clipback-archive-all-20261017/ios/after/interaction.mp4): **22.688333초·1178×2556px**. [Android AFTER 영상](/private/tmp/clipback-archive-all-20261017/android-gesture/after/interaction.mp4): **33.047200초·1080×2220px**. [전체 디코딩 검사](/private/tmp/clipback-archive-all-20261017/media-verification.json)는2개 모두 종료0/오류로그0바이트이며 동작 완료까지 녹화를 유지했다.
- [환경 정리](/private/tmp/clipback-archive-all-20261017/cleanup-verification.json): 사용 앱 종료·기기 shutdown·이번 포워딩 제거·영상 종료를 확인하고 기기 데이터를 보존했다. 탐색/키보드 설정 변경0, Android 제스처 원상태와 iOS 키보드 원상태를 확인했다. [HTML 참조/문법 검사](/private/tmp/clipback-archive-all-20261017/comparison-html-verification.json)는4조건/원본12참조를 정적으로 검사한 결과이며 브라우저·비교HTTP서버는 실행하지 않았다. 새3버튼/확대 기기 촬영·운영 검증은 수행하지 않았다.

<a id="b-fbde7e62ccc322d2"></a>

이번 고정 데이터의 실제 경계(logical px):

<a id="b-a17ab700e04f7c90"></a>

| 항목 | 변경 전 → 변경 후 | 확인 범위 |
| --- | --- | --- |
| 탭 외부/내부 높이 | 52/52 → 64/52 | 양 플랫폼·스크롤0 |
| 정렬/개수 행 높이 | 56 → 52 | 양 플랫폼 |
| 목록 viewport 시작 | iOS239 →239, Android204 →204 | 기존8px 분리 여백을 포함한 합계 높이 보존 |
| 한 행 카드/Wrap | 173/기존 첫 배지25 →173/22 | 소속1개·같은 줄의2개·긴 이름·미분류 fallback |
| 3개 소속 카드/Wrap | 173/첫 배지25 →203/52 | 실제2줄·본문/선/날짜+30px |
| 6개 소속 카드/Wrap | 173/첫 배지25 →233/82 | 실제3줄·본문/선/날짜+60px |
| 제목 폭/선 두께 | 335/1 →311/0.5 | 실제 카드375px·요약48px/최대2줄 유지 |
| 날짜 아래 여백 | 16 →16 | 전후/양 플랫폼 |

<a id="b-16f480b8cf870789"></a>

전체보기 정상 목록의 승인 범위만 완료다. 미선택 탭 굵기 확정·미분류 콘텐츠 화면·빈/로딩/오류의 새 디자인·시트 배경/자유 색상 선택·새 확대 맞춤은 보류한다. 과거 검사·촬영 결과는 이번 결과로 바꾸지 않는다.

<a id="b-8e2e2345ed6626b0"></a>

집중/격리 검사와 관련 회귀 일부의 재현 예시다. 전체 검사는 아래 별도 명령으로 실행한다. 현재 checkout을 사용하며 이전 빌드/캡처를 이번 결과로 사용하지 않는다:

<a id="b-20941bbe6bb46593"></a>

```sh
cd frontend
/Users/leehyeongyu/flutter/bin/flutter test --no-pub test/archive_all_alignment_test.dart test/archive_all_mutation_test.dart test/archive_all_share_isolation_test.dart test/feed_pagination_test.dart test/top_safe_area_test.dart
/Users/leehyeongyu/flutter/bin/flutter test --no-pub
/Users/leehyeongyu/flutter/bin/flutter analyze --no-pub
/Users/leehyeongyu/flutter/bin/flutter run --no-pub -t test/support/archive_all_preview.dart --dart-define=ARCHIVE_ALL_PHASE=after -d <device-id>
```

<a id="b-78bacec474c9e240"></a>

프리뷰 loopback은8767이며 `/scene?offset=0`·`/scene?offset=300`으로 새 고정 상태를 준비하고 `/run`으로 실제 앱 이동·스크롤·탭을 확인한다. Android에서는 이번 세션에 필요한8768→8767 포워딩을 사용한 뒤 제거한다. 기본6행의 완전 노출은 스크롤 구간의 합집합으로 확인하며 cache에 생성된 행이나 일부만 보인 행을 완전 노출로 세지 않는다. BEFORE 캡처는 제품 수정 전 기준 빌드에서 확보해야 하므로 AFTER 명령에서 phase 이름만 바꾼 결과를 변경 전으로 사용하지 않는다.
