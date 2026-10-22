# F01 카테고리별 콘텐츠 목록

- 최초 기록일: 2026-10-19
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-5c6452578d60afa9"></a>

### F01 카테고리별 콘텐츠 목록1배율

<a id="b-066316ab8f5baf0e"></a>

현재 Page 1 >261007의 [F01](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3968)을 일반 카테고리 선택 목록에 적용했다. 상단의 실제 색상 폴더/설정·52px 행·E01 카드·원본 랜덤 버튼을 사용하며, 목록과 버튼 영역을 분리해 마지막 행에 접근한다. 설정은 기존 관리로 복귀하고 정렬/불러온 개수·복수 소속·추가 페이지·실제 OS 여백을 유지한다. 미분류/전체보기의 기본 표현과 API/모델·새 확대는 변경하지 않는다.

<a id="b-2453462725f83da1"></a>

```bash
flutter test --no-pub test/category_content_alignment_test.dart test/category_content_geometry_test.dart test/category_content_fixture_contract_test.dart
flutter run -t test/support/category_content_preview.dart --dart-define=CATEGORY_CONTENT_PHASE=after
```

<a id="b-b5ff1293d5a602d5"></a>

프리뷰는 실제 루트 앱·메모리 API/세션과 첫 실행부터 공유 채널 격리를 사용한다. 기기 내부 loopback8767의 `/scene`은 고정 첫 페이지/스크롤0, `/run`은 실제 정렬·왕복·변경/복구18동작, `/status`는 실제 스타일·경계·에셋·API 대상과 전체 판정을 반환한다. 개발 대역이며 실제 OAuth/운영 서버/실기기나 영속 저장 검증이 아니다. 데이터/측정 고정과 `is_favorite=false` 대역 보완은 [명세](/private/tmp/clipback-category-content-alignment-20261019/harness-amendment.json)를 따른다.

<a id="b-c3d86888c8b5abd6"></a>

이번 최종 전체1601건·분석0, 양 플랫폼 각각18동작/전체true·오류0·새2쌍/영상2개와 실제 빌드 번들349항목을 확인했다. [실제 검사](/private/tmp/clipback-category-content-alignment-20261019/tests/final-summary.json)·[비교/영상](/private/tmp/clipback-category-content-alignment-20261019/comparison-document.html)·[실측](/private/tmp/clipback-category-content-alignment-20261019/comparison-manifest.json)·[환경 정리](/private/tmp/clipback-category-content-alignment-20261019/cleanup-verification.json). 같은 데이터·1배율·키보드 숨김·스크롤0을 사용하며 Figma375×1396의 긴 원본과 실제 OS 창 높이는 다르다. 초기 도구/설치/OS 응답대기 시도는 최종 성공과 구분한다. 상세는 [계획 문서](../figma-ui-alignment-plan.md)의 F01 독립 기록을 따른다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-1bb10523bdfcd5b7"></a>

### 2026-10-19 F01 카테고리별 콘텐츠 목록1배율

<a id="b-4fdce5b9b9623653"></a>

- 기준 `aab5226`, 같은 `feature/figma-ui-alignment`에서 F01 `111:3968`의 상단/52px 행·E01 카드·랜덤 버튼을 적용했다. 실제 ID/색상·복수 소속·불러온 N개·기존 정렬/페이지/변경/복귀·OS 안전 영역을 보존하며 마지막 카드는 버튼 위로 끝까지 스크롤한다.
- BEFORE 제품215파일 불변·양 플랫폼 새 원본2장과12목표 실패를 먼저 확보했다. 컨텍스트14:37:32 KST·원본375×1396 보관14:55:44 KST를 기록했다. 데이터/정적 측정은 유지하고 대역의 음성 즐겨찾기 필터를 독립 계약 검사로 보완했다. 검증용 첫 프레임 대기15→60초와 OS 상태 감시를 추가했으며 제품 시간/화면은 변경하지 않았다.
- 최종 전체1601통과·분석0, 실제 Pretendard/폭320·375의 F01 스타일/기하/콜백24건·대역 계약2건과 기존 확대/목록/안전 영역/변경 처리를 포함한다. 최종 iOS/Android 각각18동작·전체true/오류0·새2쌍/영상2개·번들349항목을 확인했다. 초기 미사용 import/기하 프로브와 E06의 기존 카드 유지 기대 실패를 수정했으며 검사를 삭제하거나 건너뛰지 않았다.
- [검사 요약](/private/tmp/clipback-category-content-alignment-20261019/tests/final-summary.json)·[비교2쌍/영상2개](/private/tmp/clipback-category-content-alignment-20261019/comparison-document.html)·[실측](/private/tmp/clipback-category-content-alignment-20261019/comparison-manifest.json)·[대역 보완](/private/tmp/clipback-category-content-alignment-20261019/harness-amendment.json)·[번들](/private/tmp/clipback-category-content-alignment-20261019/bundle-verification.json)·[환경 정리](/private/tmp/clipback-category-content-alignment-20261019/cleanup-verification.json). 원본 OS/예제 데이터 차이와 초기 플랫폼 이름/설치/OS 응답대기 시도를 구분한다. 메모리 대역의 결과이며 실제 OAuth·운영 서버·실기기·CI 완료가 아니다.
- 완료는 F01 정상 목록의 승인된1배율 범위다. 원본 없는 빈/로딩/오류·새 정렬 메뉴·전체 집계·새 확대·다시보기 순서/진행은 후속이다. 화면 증거/빌드/`AGENTS.md` 제외, 소유 기기/포워딩/ADB/임시 파일 정리, 푸시/PR 없음.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-a904aa66217fc3eb"></a>

- F01 카테고리별 콘텐츠 목록 작업 기준: `aab5226`. Page 1 >261007·F01 `111:3968`의 폴더/설정 상단·52px 행·E01 카드 재사용·원본 랜덤 버튼을 적용했다. 실제 ID/색상·복수 소속·불러온 개수·정렬/페이지와 OS 안전 영역을 유지한다. 최종 전체1601·분석0, 양 플랫폼 각18동작/전체true·오류0·새2쌍/영상2개와 번들349건을 확인했다. 완료는 승인된 F01 정상 목록1배율이며 미정 빈/오류/로딩·새 확대와 다시보기 순서 복원은 후속이다.
## 상태와 비교 기준

<a id="b-0d5c4c18cfcae72e"></a>

### F01 카테고리별 콘텐츠 목록의 1배율 맞춤 — 이번 독립 기록

<a id="b-14ca06abbd067572"></a>

- 기준은 `aab5226`·`feature/figma-ui-alignment`이며 E02/E03 카테고리 목록과 구분되는 F01 `111:3968`이다. 구현 컨텍스트는 **2026-10-19 14:37:32 KST**에 한 번 재조회했고, 같은 노드의375×1396px 원본 PNG는 `get_screenshot(maxDimension=1600)`으로 확보해 **14:55:44 KST**에 보관했다. 초기 컨텍스트의276×1024px 미리보기와 원본 PNG를 구분한다. [참조/조회 기록](/private/tmp/clipback-category-content-alignment-20261019/figma/reference.json).
- 상단64px·내용 중앙+0.5px·뒤로/검색/설정24px·폴더23.5294×20px과18px/SemiBold/AUTO 제목을 적용한다. 폴더는 실제 피드의 카테고리ID로 색상을 연결하며 긴 이름은 한 줄 말줄임한다. 설정은 기존 카테고리 관리, 헤더 뒤로는 기존 카테고리 목록 복귀다. 이름이 같은 카테고리도 ID로 구분한다.
- 상단 뒤 불필요한8px과56px 툴바를 없애52px 행 바로 아래에서 첫 카드가 시작한다. 최신순/북마크 우선의 기존 팝업·조회 정책과 `불러온 N개`를 유지한다. 기존 E01 카드 표현을 F01에서 선택해173px·제목1줄/요약2줄·0.5px 원본선·별28/더보기24px·시각 간격16px을 재사용한다. 실제 복수 소속은 원래 색상/순서로 Wrap하며 추가 높이만큼 본문/날짜를 함께 내린다. 다른 목록의 공통 기본값·공통 하단 바·API/Repository/모델은 바꾸지 않는다.
- 랜덤 보기는 원본18px 책갈피·16px/SemiBold/AUTO·간격4px·패딩10px이다. 일반1배율의 자연 시각 크기는99.109375×39px이고 탭 영역은 높이44px이다. 우측16px·하단 바 위16px에 배치한다. 본문과 자연 높이 하단 영역을 분리해 최대 스크롤에서 마지막 카드를 버튼 위로 올릴 수 있게 했다. 불러온 최대5개 선정·재추첨/진행 정책과 저장/닫기는 기존대로다.
- [제품 수정 전 gate](/private/tmp/clipback-category-content-alignment-20261019/before-gate.json)는 제품215파일의 기준 동일성과 양 플랫폼 새 BEFORE2장을 확인한다. [수정 전 집중 재현](/private/tmp/clipback-category-content-alignment-20261019/tests/before-focused.log)은12실패로 상속 행간/색상/자간·56px 행·아이콘/랜덤 표현과 마지막 카드 가림을 재현했다. 목표 실패와 실제 촬영/프레임워크 오류를 분리한다. [최종 검사 요약](/private/tmp/clipback-category-content-alignment-20261019/tests/final-summary.json)은 전체 **1601건 통과**·`flutter analyze --no-pub` 오류/경고0이며 실제 Pretendard·iOS/Android 테마×320/375px의 F01 스타일/기하/콜백24건·대역 계약2건과 기존 미분류·전체보기·검색·즐겨찾기·페이지/변경·안전 영역·확대 검사를 포함한다. 기존 검사를 삭제하거나 건너뛰지 않았다.
- 촬영 데이터·프리뷰 진입·스타일/기하 측정은 고정했다. 독립 계약 검사에서 발견한 대역의 `is_favorite=false` 누락만 보완했다. 일반 BEFORE 촬영은 해당 필터를 사용하지 않았고 데이터 생성·정적 host/측정은 동일하다. Android 첫 프레임 준비 지연에 맞춰 검증 진입의 프레임 대기만15→60초로 보완했으며 제품 시간/화면은 바꾸지 않았다. [대역 보완 근거](/private/tmp/clipback-category-content-alignment-20261019/harness-amendment.json)·[변경 diff](/private/tmp/clipback-category-content-alignment-20261019/harness-amendment.diff). 이 대역은 운영 API/실제 저장이나 OAuth의 성공 증거가 아니다.
- iOS는 이번15:19 촬영의 제품218파일·실제 설치 커널/에셋121개가 현재와 동일함을 [대조](/private/tmp/clipback-category-content-alignment-20261019/ios-product-equivalence.json)했다. 이후 변경은 검증 진입의 프레임 관찰15→60초뿐이며 화면/데이터/동작은 같다. 후속 iOS 부팅 관찰 실패는 이 성공 촬영과 분리한다.
- 최종 iPhone16/iOS18.6·Android13/API33 제스처에서 각각18동작의 스타일·레이아웃·에셋·동작·전체 `passed:true`, 프레임워크 오류0을 확인했다. 카테고리ID·정렬/위치0·추가 페이지·설정/검색/상세 왕복·북마크 실패/수동 재시도·최대 스크롤/마지막 행·랜덤 대상/복귀·추가 저장 없는 닫기·분류/삭제·조회 실패/재시도·네 탭을 검사했다. 새 배율별·3버튼 기기 촬영은 추가하지 않았다.
- **변경 전 → 변경 후 → Figma 총2쌍**: [iOS](/private/tmp/clipback-category-content-alignment-20261019/comparisons/ios-category-content.png)·[Android](/private/tmp/clipback-category-content-alignment-20261019/comparisons/android-category-content.png), [비교 문서](/private/tmp/clipback-category-content-alignment-20261019/comparison-document.html), [실측](/private/tmp/clipback-category-content-alignment-20261019/comparison-manifest.json). 고정 카테고리101/같은5개 첫 페이지·1배율·키보드0·스크롤0과 실제 OS 창/여백을 유지했다. iOS의 첫 카드 시작187→175px·헤더64px/하단98px 유지, 두 플랫폼 툴바56→52px·랜덤 버튼 아래24→16px을 확인했다. Figma는6개 예제의375×1396px 긴 원본이며 실제 OS 창 높이·예제 문구/개수·복수 소속·OS 여백을 보정하지 않았다.
- AFTER 영상: [iOS](/private/tmp/clipback-category-content-alignment-20261019/ios/after/interaction.mp4)·[Android](/private/tmp/clipback-category-content-alignment-20261019/android/after/interaction.mp4). 녹화 완료와 실제 PTS 장면/종료 상태·전체 디코딩을 확인했다. [기기/영상 명세](/private/tmp/clipback-category-content-alignment-20261019/comparison-manifest.json). 초기 iOS 플랫폼 이름 판정 실패, Android 설치/OS 응답대기, 대역 계약 보완 전 실행 및 초기 검사 실패는 별도 시도이며 최종 성공에 합산하지 않았다. Android의 준비 단계 OS 상태와 최종 녹화는 [실행 기록](/private/tmp/clipback-category-content-alignment-20261019/android/after/driver.json)으로 구분한다.
- [번들 확인](/private/tmp/clipback-category-content-alignment-20261019/bundle-verification.json)은349항목으로 소스/실행 산출물 해시·원본 SVG와실제 iOS/APK 에셋121개·실제 폰트 등록을 대조했다. 신규 폴더/책갈피2개는 원본 bytes를 유지하며 뒤로/검색/설정/카드/하단 원본은 일치하는 기존 파일을 재사용한다. [환경 정리](/private/tmp/clipback-category-content-alignment-20261019/cleanup-verification.json)는 소유 기기·앱·포워딩/임시 파일·ADB·8767/8768 포트를 확인하고 사용자 데이터·기존 탐색 설정을 보존한다.
- 완료는 **F01 정상 목록의 승인된1배율 표현**에 한정한다. 일반 빈/로딩/오류·정확한 전체 집계·새 정렬 메뉴·새 확대와 다시보기 순서/진행 복원은 후속이며 과거 검증 기록과 승인 예외를 유지한다. 같은 브랜치의 한 커밋 범위이며 화면 증거·빌드·`AGENTS.md`를 제외하고 푸시/PR은 하지 않는다.
