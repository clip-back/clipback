# 홈 기본·빈 표현 마무리

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-ad18a6186a4dcd5e"></a>

이번 `af13e37` 기준 작업은 **C01·확인된 C02의 승인된1배율 홈 표현 마무리**입니다. 홈 전용 로고·검정 검색/알림·헤더 중앙+0.5px, 추천 카드 여백/테두리·기존 예제의 빨간 강조, 최근 카드 내부/원본 미선택 별과 엄격한 빈 상태 판정을 맞췄습니다. **집중53/전체1367·최종 분석0·양 플랫폼 각23기록/전체true·프레임워크 오류0·새 비교4쌍/영상2개·환경 정리**를 확인했습니다. C02 안내/공지 대신 최근 카테고리·기존 단일 본문을 유지하며 실제 추천/공지 API·범위 밖 북마크 대기 중 부모 카드 탭 전파·새 확대는 후속입니다.

<a id="b-0d276965454810a8"></a>

### 홈 C01·C02의 1배율 표현 마무리 — 2026-10-18 작업

<a id="b-2af255c0d91d6416"></a>

- 현재 원본은 Page 1 >261007의 C01 `111:3584`·C02 `111:3681`, 모두 **375×910px**입니다. 구현 직전 **2026-10-18 16:05:27.872/16:05:28.064 KST**에 컨텍스트/원본을 각1회 확보했습니다([출처](/private/tmp/clipback-home-base-alignment-20261018/figma/reference-manifest.json)). 새 로고/미선택 별 원본SVG2개와 기존 PNG크롭/공용 SVG를 대조했으며 raw 원본과 렌더 PNG·실제 번들 일치를 구분합니다([에셋 근거](/private/tmp/clipback-home-base-alignment-20261018/figma/asset-source-audit.json)).
- [홈](../../frontend/lib/features/home/home_screen.dart)에 전용 표현을 적용하고 [북마크 버튼](../../frontend/lib/shared/content/bookmark_button.dart)의 선택적 `inactiveAsset` 기본값은 기존 에셋으로 유지합니다. 실제 콘텐츠/카테고리·최대4개·첫 배지·저장/목적지·공통 하단/OS 안전 영역·기존 확대를 보존합니다. 같은 피드 버전의 북마크 상태만 바뀌면 rail위치를 유지하고 성공 후 재조회·필터/버전/ID 순서 변경은 기존대로0으로 초기화합니다.
- C02는 query/isFavorite/category 필터 없음·조회 완료·항목0·로딩/오류/추가 페이지/커서 없음이 확인될 때만 적용합니다. 안내/공지 미정으로 기존 최근 카테고리2개/날짜/이동·단일 본문 자연 줄바꿈을 유지합니다. 원본의 두 문단/안내 카드/알림 점까지 동일하다고 보고하지 않습니다. 추천은 기존 예제 ‘일본 여행’·‘다이어트’ 빨간 강조이며 실제 추천 API는 아닙니다.
- 자동 검사는 BEFORE18건=8통과/목표 실패10·기준 회귀143통과, AFTER 집중53·상단 안전 영역11·전체 **1367/1367(86.91초)**·[최종 분석0/3.7초](/private/tmp/clipback-home-base-alignment-20261018/tests/final-restored-analyze.json)입니다([전체](/private/tmp/clipback-home-base-alignment-20261018/tests/final-checks.json)·[검사 제품 SHA/재촬영 복귀 일치](/private/tmp/clipback-home-base-alignment-20261018/tests/unit-verification-source-proof.json)). 옛 헤더Row 기대치의 첫 전체10실패와 점180ms 전환 중간 폭의 첫 네이티브false를 시도 기록에 보존하고 최종 재검증과 분리합니다. 후자는 제품 변경 없이 프리뷰 대기만 보완해 양 플랫폼 BEFORE/AFTER를 다시 촬영했습니다.
- [변경 전→후→Figma4쌍](/private/tmp/clipback-home-base-alignment-20261018/comparison-document.html)·[iOS 개요](/private/tmp/clipback-home-base-alignment-20261018/comparisons/ios-overview.png)·[Android 개요](/private/tmp/clipback-home-base-alignment-20261018/comparisons/android-overview.png)는 같은 데이터/1배율/키보드 숨김/scroll0의 새 원본입니다. 최대 스크롤도 별도 기록하며 실제 OS 창/안전 여백과375×910px 원본을 보정하지 않습니다. [iOS](/private/tmp/clipback-home-base-alignment-20261018/ios/after/report.json)·[Android](/private/tmp/clipback-home-base-alignment-20261018/android/after/report.json) 각23기록의 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0을 확인했습니다.
- AFTER 영상 [iOS23.01초](/private/tmp/clipback-home-base-alignment-20261018/ios/after/actions.mp4)·[Android36.430122초](/private/tmp/clipback-home-base-alignment-20261018/android/after/actions.mp4)의 [전체 디코딩/녹화 완료](/private/tmp/clipback-home-base-alignment-20261018/media-verification.json)와 [실제 iOS/APK 번들294/294](/private/tmp/clipback-home-base-alignment-20261018/bundleverification.json)를 확인했습니다. 기존 프리뷰의 확대 반복 실행 결과를 이번1배율 증거로 재사용하지 않습니다.
- **범위 밖 기능 발견:** 비활성 별 재탭의 부모 카드 상세 이동은 PUT1회 중복 차단과 별개입니다([관찰](/private/tmp/clipback-home-base-alignment-20261018/known-bookmark-disabled-tap-observation.json)). 새 이동 잠금을 구현하지 않았고 전체true가 이를 차단했다는 뜻은 아닙니다. 보고서 `writeRequests`는 허용 밖 쓰기이므로 ‘모든 쓰기0’이 아니며 실제 즐겨찾기 PUT·열람 POST를 별도 검사합니다. 추가 콘텐츠 저장/카테고리 변경은 없습니다. 실제 OAuth·운영 서버/추천·영속 데이터·실기기/CI·새 확대는 미검증입니다.

<a id="b-ffff2ce597980720"></a>

### 홈 1배율 재현 명령

<a id="b-5096cb1716504931"></a>

```sh
flutter test --no-pub test/home_base_alignment_test.dart test/home_alignment_test.dart
flutter test --no-pub
flutter analyze --no-pub
flutter run --no-pub -t test/support/home_base_alignment_preview.dart --dart-define=HOME_BASE_PHASE=after -d <device-id>
```

<a id="b-1f3adccb3aac3826"></a>

새 프리뷰는 실제 ClipbackApp·메모리 API/세션을 사용하고 첫 실행부터 공유를 격리합니다. `/scene?kind=normal|empty`는1배율 정적 상태, `/max-scroll`은 최대 스크롤, `/run`은 동작 검사이며 실제 스타일/기하/에셋/동작을 전체 판정에 연결합니다. 기존 `figma_home_preview.dart` 기본/확대 실행과 자동 검사는 유지합니다. 운영 계정/서버로 실행하는 도구가 아닙니다. 정책/실측·시도 기록은 [계획](../figma-ui-alignment-plan.md)의 이번 홈 기록을 따릅니다.

<a id="b-31a22c836ca947af"></a>

[최종 검증 요약](/private/tmp/clipback-home-base-alignment-20261018/tests/validation-summary.json)·[증거/소스 명세](/private/tmp/clipback-home-base-alignment-20261018/evidence-summary.json)는 빌드된269개 소스 SHA와 동결된 프리뷰/fixture2개 일치·비교4쌍/영상2개를 기록합니다. [환경 정리](/private/tmp/clipback-home-base-alignment-20261018/cleanup-verification.json)는 소유 시뮬레이터/에뮬레이터·포워딩·ADB를 종료하고5037/8767/8768 포트 닫힘·제스처2 유지·설정/사용자 데이터 변경0을 확인했습니다. 호스트 임시 비교 HTTP 서버는 실행하지 않았으며 증거·빌드·AGENTS.md는 커밋에서 제외하고 푸시/PR은 하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-e4044547fcc1081a"></a>

직전 `af13e37` 기준 작업은 **C01·확인된 C02의 승인된1배율 홈 표현 마무리**입니다. 홈 전용 로고·검정 검색/알림·헤더 중앙+0.5px, 추천 카드 여백/테두리·기존 예제의 빨간 강조, 최근 카드 내부/원본 미선택 별과 엄격한 빈 상태 판정을 맞췄습니다. **집중53/전체1367·최종 분석0·양 플랫폼 각23기록/전체true·프레임워크 오류0·새 비교4쌍/영상2개·환경 정리**를 확인했습니다. C02 안내/공지 대신 최근 카테고리·기존 단일 본문을 유지하며 실제 추천/공지 API·범위 밖 북마크 대기 중 부모 카드 탭 전파·새 확대는 후속입니다.

<a id="b-3cbbdd12046edf0a"></a>

- `af13e37`·`feature/figma-ui-alignment`에서 승인된1배율 홈 상단/원본 로고·추천 카드 여백/테두리/기존 예제 빨간 강조·최근 카드 내부/원본 미선택 별과 엄격한 C02 판정을 적용했습니다. 제품5파일에 한정하며 공용 북마크의 선택적 에셋 기본값·기존 API/모델·데이터/저장·공통 하단/OS 안전 영역/확대 회귀를 유지했습니다.
- C01 `111:3584`·C02 `111:3681` 컨텍스트/원본은 **2026-10-18 16:05:27.872/16:05:28.064 KST**에 각1회 확보한375×910px입니다([출처](/private/tmp/clipback-home-base-alignment-20261018/figma/reference-manifest.json)). 원본/크롭/공유 SVG 대조와 신규SVG2개는 [에셋 기록](/private/tmp/clipback-home-base-alignment-20261018/figma/asset-source-audit.json)을 따릅니다. C02 안내/공지 미정·기존 최근 카테고리2개와 단일 본문 자연 줄바꿈/고정 날짜·알림 점 미추가는 승인 예외이며 C02 전체 구조 일치가 아닙니다.
- BEFORE 전용18건=8통과/목표 실패10·기준 회귀143건을 확인하고 최초 새 양 플랫폼 BEFORE 뒤 제품을 적용했습니다. 도구의 점 전환 대기 보완 후 정확한 기준/최종 제품으로 양쪽 BEFORE/AFTER를 새로 만들었으며 [최종 게이트](/private/tmp/clipback-home-base-alignment-20261018/product-edit-gate.json)와 [전후 동결 명세](/private/tmp/clipback-home-base-alignment-20261018/comparison-manifest.json)에 실제 원본·fixture해시를 남겼습니다. 최초16:23:24.947 KST 적용과 최종16:35:38.401 KST 복귀를 구분합니다.
- 최종 집중53/53·상단 안전 영역11/11·전체 **1367/1367/86.91초·실패/건너뜀0·exit0**, 최종분석 **0건/3.7초·exit0**입니다([전체](/private/tmp/clipback-home-base-alignment-20261018/tests/final-checks.json)·[최종 분석](/private/tmp/clipback-home-base-alignment-20261018/tests/final-restored-analyze.json)·[제품 SHA 일치](/private/tmp/clipback-home-base-alignment-20261018/restored-final-product-proof.json)). 첫 전체1357/10실패는 헤더 외곽+8px 대신 이동한 Row를 측정한 옛기대이고 finder를 바로잡았습니다. 첫 네이티브 전체false는180ms 점 전환의 중간 폭 측정으로 대기만 보완했습니다. 두 실패 시도를 `.attempts/`에 보존하고 최종 성공으로 합산하지 않습니다.
- [새 비교4쌍](/private/tmp/clipback-home-base-alignment-20261018/comparison-document.html)과 [iOS](/private/tmp/clipback-home-base-alignment-20261018/ios/after/report.json)·[Android](/private/tmp/clipback-home-base-alignment-20261018/android/after/report.json)의 각23기록은 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0입니다. 정상/빈 홈·실제 목적지·필터·스크롤/점·북마크 실패/재시도/성공 재조회·빈 저장/무저장 닫기를 확인했습니다. 같은 버전의 북마크 상태만 변경되면 위치를 유지하지만 성공 재조회/버전 변경은0이며 새 루트 복원은 없습니다. 실제 OS 창/안전 여백·원본375×910px 차이를 보정하지 않았습니다.
- [별도 기능 관찰](/private/tmp/clipback-home-base-alignment-20261018/known-bookmark-disabled-tap-observation.json)은 대기 중 비활성 별 재탭→부모 상세 이동입니다. PUT중복은1회로 막지만 상세/열람 요청·홈 unmount/복귀 rail0은 가능하며 새 이동 잠금 정책은 후속입니다. 전체true가 해당 잠금을 의미하지 않습니다. `writeRequests=0`은 허용 밖 쓰기0이며 실제 즐겨찾기 PUT·열람 POST와 추가 저장/카테고리 변경 여부는 별도 기록합니다.
- AFTER [iOS23.01초](/private/tmp/clipback-home-base-alignment-20261018/ios/after/actions.mp4)·[Android36.430122초](/private/tmp/clipback-home-base-alignment-20261018/android/after/actions.mp4)의 [전체 디코딩/녹화](/private/tmp/clipback-home-base-alignment-20261018/media-verification.json)와 [실제 번들294/294](/private/tmp/clipback-home-base-alignment-20261018/bundleverification.json)를 통과했습니다. 최초부터 공유를 격리한 메모리 대역 결과이며 실제 OAuth·운영 서버·영속 데이터·실기기/CI 검증과 구분합니다. 안내/공지·추천 API·로딩/오류·부모 탭 이동 정책·새 확대와 기존 A01 네이티브 정적 색상/불투명 미검증은 후속입니다. 화면 증거·빌드·AGENTS.md는 제외하며 푸시/PR은 하지 않습니다.

<a id="b-1b6e53b52603f574"></a>

- [최종 검증 요약](/private/tmp/clipback-home-base-alignment-20261018/tests/validation-summary.json)·[증거/소스 명세](/private/tmp/clipback-home-base-alignment-20261018/evidence-summary.json)는 빌드된269소스와 현재 SHA·동결 프리뷰/fixture2개 전후 동일·HTML57링크 유효를 확인합니다. [환경 정리](/private/tmp/clipback-home-base-alignment-20261018/cleanup-verification.json)는 소유 iOS/Android·포워딩/ADB 종료·5037/8767/8768 닫힘·제스처2 유지이며 설정 변경0·사용자 데이터 삭제/호스트 임시 비교 HTTP 서버 실행false입니다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-953d92e66d09fa1e"></a>

`af13e37` 기준 Page 1 > `261007`의 [C01 콘텐츠 있음](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3584)(`111:3584`)·[C02 확인된 빈 홈](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3681)(`111:3681`)에서 **승인된1배율 홈 표현**을 마무리했다. 과거 홈·확대/안전 영역 결과는 당시 기록으로 보존하며 이번 완료를 홈 전체 기능·C02 전체 구조의 원본 일치로 확대하지 않는다.

<a id="b-79f5779b05cbcffc"></a>

- **적용 표현:** 홈 전용 원본 로고71.41×24.0003px을24px 슬롯에 표시하고 헤더 바깥 상8px/내부56px·좌우16px을 유지한다. 내용 전체는 중앙+0.5px이며 검색/알림24px은 검정, 간격16px·기존 터치/이동은 유지한다. 추천133×120px의 좌16/우21/상하16px을 맞추고1px 테두리를 foreground 페인트로 옮겨 레이아웃 여백에 더하지 않는다. 기존 문구의 **‘일본 여행’·‘다이어트’만 빨간색**으로 강조하며 두 줄 말줄임·확대 자연 높이를 유지한다. Figma의 ‘취업’ 예제로 문구/데이터를 바꾸지 않은 사용자 승인 예외이고 실제 개인화 결과가 아니다.
- **최근 카드/공유 경계:** 카드298×186px의 내부를 좌16.5/우15.5/상하16px·별44px hit의 right3.5/top4px로 맞춘다. 미선택 원본28px/선1.5px만 홈에 적용한다. `BookmarkActionButton.inactiveAsset`은 선택 인수이고 기본값 `Assets.star`로 다른 화면을 보존한다. 기존 선택 별·색상/잠금·최대4개/불러온 순서/첫 카테고리 배지·실제 제목/요약을 유지한다. 공통 하단/OS 안전 영역·PageDots/온보딩·전역 테마/공통 아이콘 기본값·공개 필수인수/콜백·API/모델/저장 정책은 변경하지 않는다.
- **C02 조건/승인 차이:** 표시 목록/피드 항목0·조회 완료·로딩/오류 없음에 더해 active/feed 카테고리 없음·query null·isFavorite null·hasMore false·nextCursor null일 때만 C02를 표시한다. 빈 문자열 query도 미확정으로 두며 필터/추가 페이지/미조회 상태를 전체 저장0으로 오판하지 않는다. 안내·공지 카드/상세 본문은 미정이라 **기존 최근 카테고리2개·고정 날짜·행/이동을 유지**한다. 이는 원본과 가장 큰 구조 차이다. 빈 안내 본문은 기존 단일 Text의 자연 줄바꿈/스타일을 유지하므로 원본의 두 문단/강제 개행과 행 구성까지 같다고 보고하지 않는다. 실제 읽지 않은 알림이 없어 원본의 고정 빨간 점도 추가하지 않는다([비교 예외](/private/tmp/clipback-home-base-alignment-20261018/comparison-exceptions.json)).
- **조회/에셋:** 현재 파일의 C01/C02 컨텍스트·원본을 각1회 새로 확보했다. 실제 queriedAt는 **2026-10-18 16:05:27.872/16:05:28.064 KST(07:05:27.872/07:05:28.064 UTC)**이며 두 원본은 **375×910px**이다([조회 명세](/private/tmp/clipback-home-base-alignment-20261018/figma/reference-manifest.json)). 같은 파일의 정확한 원본을 사용하고 과거812px 이미지를 대체하지 않는다. 새 로고/별 SVG2개는 원본 bytes 그대로 등록한다. 검색/알림/화살표는 SVG 자식 도형 정규화가 정확히 일치한다. hero99×123px/상자 논리67×78px·페인트71×82px은 기존 크롭/그림자를 재사용한다. raw 원본 일치와 기존 렌더 PNG의 시각 비교를 구분하며 hero 평균 채널 차이1.2/255 미만·상자0.087/255 대조를 보존했다([에셋 근거](/private/tmp/clipback-home-base-alignment-20261018/figma/asset-source-audit.json)). 전체 화면 이미지나 가짜 OS 표시는 구현에 사용하지 않는다.

<a id="b-1d5fe1ef5cade385"></a>

### 재현·자동 검사와 재촬영 기록

<a id="b-74dd83ea568bda7a"></a>

- 제품 수정 전 전용18건 중 **8통과/목표 차이10실패**를 재현했다([BEFORE 검사](/private/tmp/clipback-home-base-alignment-20261018/tests/before-target.log)). 기존 홈/확대 하단 탭/상하 안전 영역의 기준 회귀는143/143·22초/exit0이다([기준 회귀](/private/tmp/clipback-home-base-alignment-20261018/tests/baseline-existing-regressions-summary.json)). 최초 제품 적용 전 양 플랫폼의 새 BEFORE·23동작/오류0·정적4장/최대 스크롤4장을 확보했다. 최초 적용16:23:24.947 KST와 이후 도구 재동결을 위한 정확한 기준 제품 복원/재촬영·최종 복귀16:35:38.401 KST를 구분한다([최초 적용](/private/tmp/clipback-home-base-alignment-20261018/initial-product-applied.json)·[최종 BEFORE 게이트](/private/tmp/clipback-home-base-alignment-20261018/product-edit-gate.json)·[최종 적용](/private/tmp/clipback-home-base-alignment-20261018/product-applied.json)).
- AFTER 집중 **53/53**, 보완한 상단 안전 영역 **11/11**, 전체 `flutter test --no-pub` **1367/1367·실패/건너뜀0·86.91초/exit0**이다([집중](/private/tmp/clipback-home-base-alignment-20261018/tests/after-target.log)·[상단 안전 영역](/private/tmp/clipback-home-base-alignment-20261018/tests/after-top-safe-area.log)·[전체 요약](/private/tmp/clipback-home-base-alignment-20261018/tests/final-checks.json)). 새 프리뷰와 최종 복귀 제품을 포함한 마지막 `flutter analyze --no-pub`는 **문제0·3.7초/exit0**이다([최종 분석](/private/tmp/clipback-home-base-alignment-20261018/tests/final-restored-analyze.json)). 제품5파일은 전체 검사를 실행한 최종SHA와 모두 같다([유닛 소스 근거](/private/tmp/clipback-home-base-alignment-20261018/tests/unit-verification-source-proof.json)·[복귀 확인](/private/tmp/clipback-home-base-alignment-20261018/restored-final-product-proof.json)). 실제 폰트·iOS/Android×320/375px×1배율의 역할/기하/에셋·엄격한 빈 판정·이동/입력·긴 문구/말줄임과 기존 확대/세션/저장 회귀를 유지했다. 새 확대·3버튼 반복 촬영은 추가하지 않았다.
- **첫 검사/도구 시도 보존:** 첫 전체1357통과/10실패(112.93초)는 홈 외곽56px 박스 대신 +0.5px 이동한 Row를 측정한 옛 기대치였다. finder만 `home-header`로 보완해 OS 상단+8px 검사를 유지하고 내부+0.5px은 별도 홈 기하 검사에서 확인했다. 로그는 `.attempts/first-full-old-header`에 보존한다. 첫 네이티브는 카테고리 전환의 PageDots180ms 애니메이션 중간 너비를 판정해 전체false였으므로 `.attempts/after-dot-animation-timing-1`에 당시 영상/보고서/소스를 보존했다. 제품은 그대로 두고 프리뷰의 판정 전 `await _settle(6)`만 추가해 다시 동결·정확한 기준/최종 제품으로 양 플랫폼 BEFORE/AFTER를 모두 새로 촬영했다. 최종 프리뷰/fixture2개 해시는 전후 동일하다([최종 비교 명세](/private/tmp/clipback-home-base-alignment-20261018/comparison-manifest.json)). 이전 실패를 최종 성공으로 합산하지 않는다.

<a id="b-1cc6f8f3d710b939"></a>

### 양 플랫폼 새 비교·동작·검증 한계

<a id="b-b0b8657a6aae0bf0"></a>

| 플랫폼 | 실제 논리창 / DPR | 상·하 안전 / 프레임 left | 정상 최대 스크롤 전→후 | 빈 홈 최대 스크롤 전→후 |
| --- | --- | --- | --- | --- |
| iPhone16 / iOS18.6 | 393×852 /3 | 59·34 /9px | 85→85px | 27→27px |
| Android13 / API33 제스처 | 392.727×783.273 /2.75 | 24·0 /8.864px | 84.727→84.727px | 26.727→26.727px |

<a id="b-fbeb040d76016b4a"></a>

- [변경 전→후→Figma4쌍](/private/tmp/clipback-home-base-alignment-20261018/comparison-document.html)·[iOS 개요](/private/tmp/clipback-home-base-alignment-20261018/comparisons/ios-overview.png)·[Android 개요](/private/tmp/clipback-home-base-alignment-20261018/comparisons/android-overview.png)는 정상/빈 홈×두 플랫폼의 새 원본8장을 비교한다. 같은 데이터·1배율·키보드 숨김·scroll0이며 최대 스크롤 원본도별도로 보존한다. OS 원본 창/안전 여백과 Figma375×910px을 보정하지 않는다. C02 안내/공지·본문 개행·최근 카테고리/알림 점, 추천 예제·실제 콘텐츠/색/순서·점 개수/선택 상태 차이를 원본 일치로 숨기지 않는다.
- 실제 루트 앱/메모리 API의 최종23기록씩은 양 플랫폼 모두 스타일/레이아웃/에셋/동작/전체 `passed:true`·프레임워크 오류0이다([iOS](/private/tmp/clipback-home-base-alignment-20261018/ios/after/report.json)·[Android](/private/tmp/clipback-home-base-alignment-20261018/android/after/report.json)). 검색 진입/취소·기존 알림 시트·Today→현재 피드 첫 상세, Weekly 제목/카드→기존 카테고리 탭·최근 제목→기존 전체 목록, 가로 스크롤/점·필터 초기화·상세·최대 스크롤, 빈 저장 진입/무저장 닫기·기존 최근 카테고리 이동을 확인했다. 화면 왕복의 새 홈 세로/rail 복원을 추가하지 않았다.
- 북마크 상태만 변경된 같은 ID/순서/피드 버전에서는 위치/점을 유지한다. 실패 후 현재 입력/세션과 수동 재시도를 보존하고 성공 후 재조회로 버전이 바뀌면 기존대로0으로 초기화한다. 일반 시나리오는503→성공의 즐겨찾기 PUT2회, 별도 비활성 탭 관찰은PUT1회이며 열람 POST도 별도 허용 요청이다. `writeRequests`는 허용 목록 밖 쓰기 수이므로0을 ‘모든 쓰기0’으로 해석하지 않는다. 추가 콘텐츠 저장/카테고리 변경 없음과 실제 즐겨찾기 변경·열람 기록을 구분한다.
- **범위 밖 발견:** 기준 제품의 양 플랫폼에서 북마크 대기 중 비활성 별 영역을 실제 재탭하면 PUT중복은 차단돼1회지만 부모 카드 탭으로 상세에 진입한다. 상세/열람 요청과 홈 unmount로 복귀 rail0이 발생할 수 있다([별도 관찰](/private/tmp/clipback-home-base-alignment-20261018/known-bookmark-disabled-tap-observation.json)). 최초 실패는 `.attempts/before-runtime-parent-tap-1`에 보존하고, 도구의 중단 없는 위치 유지 검사와 이 독립 관찰을 분리했다. 새 이동 잠금 정책은 이번에 추가하지 않는다. 최종 동작/전체true는 승인 범위의 판정이며 요청 중 상세 이동 차단까지 성공했다는 뜻이 아니다.
- 새 AFTER 원본 영상 [iOS23.010000초](/private/tmp/clipback-home-base-alignment-20261018/ios/after/actions.mp4)·[Android36.430122초](/private/tmp/clipback-home-base-alignment-20261018/android/after/actions.mp4)의 녹화 완료·전체 디코딩exit0/진단0·SHA/시작·종료·중간 동작을 확인했다([미디어](/private/tmp/clipback-home-base-alignment-20261018/media-verification.json)·[프레임 검토](/private/tmp/clipback-home-base-alignment-20261018/video-frame-review.json)). 원본과 채팅용960px 높이/30fps 프리뷰는 별도로 보존한다. 도구가 독립 정상/빈 데이터로 새 앱을 만드는 구간을 제품의 복원/재시작 정책으로 보고하지 않는다.
- [실제 iOS/APK·원본/기존 에셋·폰트·보호 경계294/294](/private/tmp/clipback-home-base-alignment-20261018/bundleverification.json)를 통과했다. 최초 실행부터 네이티브 공유를 격리한 로컬 메모리 검증이며 실제 OAuth·운영 서버/추천 API·영속 데이터·실기기·원격 CI는 미검증이다. 안내/공지·별도 로딩/오류·비활성 별의 부모 이동/복귀 정책·새 확대 및 A01 iOS 네이티브 완전 불투명/정적 색상은 후속이다. 화면 증거/빌드/AGENTS.md는 Git 밖에 유지하고 푸시/PR은 하지 않는다.

<a id="b-4dac486f3f5e9eef"></a>

- **최종 증거/정리:** [전체 검증 요약](/private/tmp/clipback-home-base-alignment-20261018/tests/validation-summary.json)·[증거 요약](/private/tmp/clipback-home-base-alignment-20261018/evidence-summary.json)은 새 비교4쌍·정적8장/최대 스크롤8장·빌드된269개 소스의 현재 SHA 일치·프리뷰/fixture2개 전후 동일·HTML57링크 유효를 기록한다. [환경 정리](/private/tmp/clipback-home-base-alignment-20261018/cleanup-verification.json)는 제스처 설정2 유지·설정 변경0, 소유 iOS Shutdown/Android 종료·포워딩/ADB 정리·5037/8767/8768 포트 닫힘을 확인했다. 사용자 데이터 삭제/앱 제거·호스트 임시 HTTP 비교 서버 실행은 없으며 증거만 Git 밖에 보존한다.
