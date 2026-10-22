# 검색 화면 표현

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-0e5f5d54a5dd50f8"></a>

### 검색 화면의1배율 맞춤 — 2026-10-18 작업

<a id="b-54db793dbee2927a"></a>

`50ec0c3` 기준으로 Page 1 > `261007`의 [H01 검색 전](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3991) (`111:3991`)·[H02 결과 있음](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4070) (`111:4070`)·[H03 결과 없음](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4043) (`111:4043`)의 **승인된 검색 1배율 표현**을 적용·검증했다. 검색 기록 영속화·검색 전체 기능·새 확대 맞춤 완료를 뜻하지 않는다.

<a id="b-0b61f0137757d1ea"></a>

- **사용자 확정:** 검색 결과 개수 행은 숨기고 종료 문구는 ‘취소’15px/Medium, 최근 검색어는 모두14px/Medium으로 통일한다. H01의 ‘닫기’와 한 행만15px인 원본 차이를 승인 예외로 구분한다. 기존 예제5개·화면 내 추가/삭제·중복 제거/최신 우선/최대5개는 유지하며 화면 재생성 시 예제 초기화도 그대로다. 실제 기기/계정 기록 저장·삭제 정책은 후속이다.
- **상단/목록:** 실제 OS 상단 여백 다음16px·입력44px·하단16px의 검색 전용76px 영역과 입력14 Medium/−0.35/1.4·취소15 Medium/−0.375/AUTO를 적용했다. 다른 화면의64px 헤더는 유지한다. 최근 제목은 상단 아래16px·15 SemiBold/−0.375/#121212/AUTO, 제목→행16px·행32px/행간4px·시계18px/글자 간격9.542px이다. 입력칸은 남은 폭을 사용하며 원본292px을 강제하지 않는다. 개수 행/기존32px 공백을 제거해 첫 카드는 입력칸 하단16px 뒤에서 시작한다. 검색에서만 E01 카드 표현을 선택하고 실제 소속/색/순서·복수 배지 Wrap·173px 기본 본문·말줄임·원문을 보존한다.
- **확인된 빈 결과:** 현재 입력의 trim값과 제출 피드 검색어가 일치하고 다른 필터 없음·조회 완료·로딩/오류/다음 페이지 없음·피드/표시0일 때만 H03를 적용한다. 콜백 전용 사용도 현재 성공 요청의0만 적용한다. 원본 캐릭터81×123/cover·제목16 Medium/−0.4/#484848/AUTO·본문14 Medium/−0.35/#767676/1.6·16/8/16 간격·책18px/버튼을 맞췄다. 그룹은 최대260px·자연 높이/문단 폭으로 본문 중앙−92.5px을 본문 안으로 제한하고 짧은 공간에서는 스크롤한다. 버튼은 기존 전체보기 탭0·검색/카테고리 필터 없음으로 이동하며 기존 정렬은 보존한다.
- **동작 보존:** 입력만으로 API를 호출하지 않고 제출/최근어 선택에서만 조회한다. 공백 제출·지우기·독립 검색/커서·A→B→A/늦은 응답·기존 행을 남긴 추가 조회/오류/재시도·변경 잠금/실패 복원/성공 후 동일q 재조회·상세 왕복의 query/offset/비포커스를 유지한다. 공개 생성자/콜백·API/Repository/모델·공통 카드 기본값·공통 하단 바/OS·기존 키보드 회피는 바꾸지 않았다([보존 감사](/private/tmp/clipback-search-alignment-20261018/preservation-audit.json)).

<a id="b-eb696e5b78675598"></a>

### 이번 원본과 검사

<a id="b-5bf81fcbc3764477"></a>

- [Figma 조회/원본](/private/tmp/clipback-search-alignment-20261018/figma/reference-index.json): **2026-10-17 15:16:17~15:16:23 UTC /2026-10-18 00:16:17~00:16:23 KST**에 세 노드의 컨텍스트·375×812 원본을 각각 한 번, 구현 MCP3호출로 확보했다. 계획 단계 조회와 구분하며 별도 메타데이터/스크린샷 호출·fallback·대체 원본은 없다.
- [에셋 감사](/private/tmp/clipback-search-alignment-20261018/static-assets-verification.json): 원본10개 중 신규4SVG(검색 힌트/입력·시계·삭제)와 H03 PNG1개를 그대로 등록했다. 지우기/비선택 별은 ID/속성 순서를 정규화한 XML이 동일하고 더보기/구분선/책은 byte동일해 기존5개를 재사용했다. 최종 로컬/양 번들·실제6정적 상태의 경로/슬롯/색 필터·PNG cover를 확인한다. 기존 선택 별은 공유 E01의 보조 상태이며 이번 H02 비선택 원본과 혼동하지 않는다.
- [변경 전 게이트](/private/tmp/clipback-search-alignment-20261018/before-gate.json): 초기 실패 자료를 보존한 뒤 제품을 기준 커밋의 정확한 바이트로 되돌려 새 OS원본6장을 다시 확보하고 동일 제품 변경을 재적용했다. [동결 소스](/private/tmp/clipback-search-alignment-20261018/fixture-manifest.json) SHA `7e8c925a1e7960e874e2f8c9e34da6fa1fbf99f48d390a334f0e3274297459c6`를 전후 동일하게 유지했다. 고정 대역은 검색 대상8건/4+4페이지·다른 저장 콘텐츠1건·계정 통계999를 구분하고 결과0을 삭제/전체 저장0으로 만들지 않는다. 실제 앱의 변경 전3상태 별도 probe도3/3·오류0·JSON 직렬화를 확인했으며 native IME 증거와 구분한다.
- [변경 전 재현](/private/tmp/clipback-search-alignment-20261018/tests/focused-before-summary.json): 첫 구현 전 동일한`50ec0c3`·동일 집중 검사에서34건 중15통과/예상 차이19/예상 밖0을 재현했다. 이 원본 로그는 당시 시각으로 보존하며 모달 촬영 도구 교정과 독립적이다. 새 동결 이후 AFTER 집중 **34/34**, 관련 **687/687**, 전체 **1241/1241** 통과·실패/건너뜀0, `flutter analyze --no-pub` 문제0이다([집중](/private/tmp/clipback-search-alignment-20261018/tests/focused-after-summary.json)·[관련](/private/tmp/clipback-search-alignment-20261018/tests/related-after-summary.json)·[전체](/private/tmp/clipback-search-alignment-20261018/tests/all-after-summary.json)·[분석](/private/tmp/clipback-search-alignment-20261018/tests/analyze-after-summary.json)). 실제 Pretendard·iOS/Android×320/375px×1배율의 실효 스타일·긴/복수 소속·타깃/가드·짧은 본문 스크롤을 확인했다. 기존 확대 회귀를 유지하고 상단 안전 영역 검사의 검색 입력 기대치만+10→+16px로 갱신했다.
- [AFTER 동일 프리뷰 별도 실제 앱 검사](/private/tmp/clipback-search-alignment-20261018/tests/after-fixture-probe-summary.json)에서도 세 상태의 실제 스타일·레이아웃 true·프레임워크 오류0·JSON 직렬화를 확인했다. 자동·대역 검사와 아래 네이티브 실행을 별도로 기록한다.

<a id="b-fa36b8c155a12fe2"></a>

- **검사 도구 교정과 재촬영:** 첫 동결 도구는 더보기 시트를 실제 배경 탭으로 닫은 뒤150ms에 제거 여부를 검사해,200ms 종료 애니메이션 도중 동작 검사가 실패했다. [외부 실제 앱 진단](/private/tmp/clipback-search-alignment-20261018/tests/modal-dismiss-diagnostic.json)에서 정상 종료·데이터/쓰기 불변을 확인하고 도구만 실제 진입/종료 완료를 기다리게 고쳤다. [초기 실패 자료](/private/tmp/clipback-search-alignment-20261018/.attempts/fbe4-epoch/attempt.json)는 실패로 보존했으며 현재 성공 수에 포함하지 않는다. 새 동결 도구로 변경 전6장·변경 후6장과 동작 영상을 모두 새로 만들었다. 제품 변경8파일의 바이트는 초기 구현과 동일하다([재촬영 기준 복원](/private/tmp/clipback-search-alignment-20261018/baseline-recapture-restored.json)·[도구 교정 이력](/private/tmp/clipback-search-alignment-20261018/modal-synchronization-amendment.json)).

<a id="b-a2412439728bb5fc"></a>

### 양 플랫폼 실행과 새 비교

<a id="b-f26902f21339c88f"></a>

| 플랫폼 | 논리창 / DPR | OS 상·하 여백 | 실제 IME: 검색 전 / 결과 / 없음 | 동작 기록 |
| --- | --- | --- | --- | --- |
| iPhone16 / iOS18.6 | Size(393.0, 852.0) / 3.0 | 59 / 34px | 336 / 336 / 0px | 42 · 전체 통과/오류0 |
| Android13 / API33 제스처 | Size(392.7, 783.3) / 2.75 | 24 / 0px | 274.909 / 274.909 / 0px | 42 · 전체 통과/오류0 |

<a id="b-a0e19ffde7670a98"></a>

| 플랫폼 | 입력칸 상단 OS 여백 이후 전→후 | 입력칸 하단→첫 카드 전→후 | AFTER 빈 그룹 / 이미지 / 버튼 |
| --- | --- | --- | --- |
| iOS | 10→16px | 79→16px | 260×239 / 81×123 / 155.009×35px |
| Android | 10→16px | 79→16px | 260×239 / 81×123 / 155.009×35px |

<a id="b-a065f7ac94967b1f"></a>

- [실측/동작 요약](/private/tmp/clipback-search-alignment-20261018/native-validation-summary.json)·[독립 판정](/private/tmp/clipback-search-alignment-20261018/pair-verification.json): 실제 입력/제출·최근어 선택/삭제·공백/지우기·추가 조회/전체 행 노출/최대 스크롤·상세 왕복/비포커스·더보기 취소·변경 실패/재시도·지연 응답·조회 오류/재시도·진입원별 취소·빈 CTA·저장 진입/추가 저장 없는 닫기를 확인했다. H02는 원본 조건을 위해 제출 후 입력창을 다시 탭한 준비를 기록하며 제품의 포커스 정책을 바꾸지 않는다. 첫 실행부터 공유 채널을 메모리 격리했고 기존 공유 큐/자격의 내용을 조회/출력/삭제하지 않았다.
- [3열 비교6쌍](/private/tmp/clipback-search-alignment-20261018/comparison-document.html)·[비교 QA](/private/tmp/clipback-search-alignment-20261018/comparison-qa.json): 같은 기종·고정 데이터·1배율·스크롤0·동일 실제 키보드 상태로 전후 OS원본 각6장을 비교했다. 원본 자르기/보정 없이 OS 창·안전 여백·키보드 언어/높이·기존 PhoneFrame375px 상한·예제 데이터 차이를 명시한다.

<a id="b-f60e8518b93cdf71"></a>

| 상태 | iOS | Android 제스처 |
| --- | --- | --- |
| H01 검색 전 · 실제 키보드 표시 | [3열 비교](/private/tmp/clipback-search-alignment-20261018/comparisons/ios-search_initial_scale_1_scroll_0.png) | [3열 비교](/private/tmp/clipback-search-alignment-20261018/comparisons/android-gesture-search_initial_scale_1_scroll_0.png) |
| H02 결과 있음 · 실제 키보드 표시 | [3열 비교](/private/tmp/clipback-search-alignment-20261018/comparisons/ios-search_results_scale_1_scroll_0.png) | [3열 비교](/private/tmp/clipback-search-alignment-20261018/comparisons/android-gesture-search_results_scale_1_scroll_0.png) |
| H03 조회 완료0 · 키보드 숨김 | [3열 비교](/private/tmp/clipback-search-alignment-20261018/comparisons/ios-search_empty_scale_1_scroll_0.png) | [3열 비교](/private/tmp/clipback-search-alignment-20261018/comparisons/android-gesture-search_empty_scale_1_scroll_0.png) |

<a id="b-7ad76789bd10d773"></a>

- 개요: [iOS](/private/tmp/clipback-search-alignment-20261018/comparisons/ios-comparison-overview.png)·[Android](/private/tmp/clipback-search-alignment-20261018/comparisons/android-gesture-comparison-overview.png). AFTER 영상: [iOS](/private/tmp/clipback-search-alignment-20261018/ios/after/interaction.mp4)·[Android](/private/tmp/clipback-search-alignment-20261018/android-gesture/after/interaction.mp4). [미디어 검사](/private/tmp/clipback-search-alignment-20261018/media-verification.json)에서 원본의 실제 시작/마지막 상태·전체 디코딩 오류0·동작 전후 녹화 프로세스 생존을 확인했다. Android는 실제 동작72.132초/영상74.395초다. 정적 대기2.5+3초를 MP4 길이에 합산하는 추가 보조식은 벽시계와 인코딩 시간축이 일치한다는 가정에서 실패했으므로 [원값과 진단](/private/tmp/clipback-search-alignment-20261018/media-duration-diagnostic.json)을 보존했다. 정확한 인코더 시작 지연/정적 프레임 원인은 별도 계측하지 않았다. 완료 판정은 원본의 /run 이전 H03와 저장 닫기 이후 마이 화면, 중간 동작 표본·전체 디코딩·영상 길이가 실제 동작 시간 이상인지를 함께 확인하며 원본을 편집/시간 보정하지 않았다.
- [환경 정리](/private/tmp/clipback-search-alignment-20261018/cleanup-verification.json)·[최종 자원](/private/tmp/clipback-search-alignment-20261018/final-resource-check.json): 소유 앱/기기/포워딩/adb·임시 포트를 정리하고 탐색/키보드 원설정과 기기 데이터를 보존했다. [HTML 검사](/private/tmp/clipback-search-alignment-20261018/comparison-html-verification.json)는 정적 참조/문법 검사이며 브라우저/HTTP서버 실행 성공으로 보고하지 않는다.
- 실제 ClipbackApp/Repository·HTTP MockClient·메모리 세션·합성 입력과 네이티브 키보드 표시/여백의 로컬 검증이다. 운영 서버·실제 OAuth·영속 저장·실기기·원격 CI·새 확대/3버튼 검증은 아니다. 원본 없는 로딩/오류 등 표현과 실제 검색 기록 저장·삭제/전체 집계는 후속으로 유지한다.

<a id="b-a5b81207586bc593"></a>

### 검색 프리뷰 실행

<a id="b-1031b8e8427704fd"></a>

```bash
cd /Users/leehyeongyu/Desktop/project/Clipback/frontend
/Users/leehyeongyu/flutter/bin/flutter run --no-pub -t test/support/search_preview.dart --dart-define=SEARCH_PHASE=after -d <device-id>
```

<a id="b-1522a58b36c394ec"></a>

loopback8767의 `/scene?kind=initial|results|empty&offset=0`·`/state`·`/status`로 고정 상태를 준비·읽고 `/run`으로 동작을 검사한다. initial/results는 실제 키보드 표시, empty는 숨김이며 실제 inset을 기록한다. Android 소유8768→8767 포워딩은 검증 뒤 제거한다. phase는 기록용으로 AFTER 빌드를 BEFORE로 이름만 바꿔 사용하지 않는다. 첫 앱 실행 전에 공유 채널을 격리하고 실제 TextInput 채널은 유지한다.
