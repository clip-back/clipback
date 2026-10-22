# Weekly 표시·이동·실제 노출 연결

- 최초 기록일: 2026-10-21
- 영역: 추천
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-02251ad4386f41a2"></a>

최근 `9e52b98` 기준 **홈 Weekly 표시·실제 카테고리 이동·보이는 카드 노출·추천 유입을 연결**했다. 신규21/전체1,708·정적 분석0·임시 PostgreSQL 계약100개와 새 비교6쌍/영상2개의 실제 결과는 아래 Weekly 독립 기록을 따른다. 운영 추천 품질·공지·새 확대는 후속이다.

<a id="b-fb24b149d2b8b8bb"></a>

### 2026-10-21 Weekly 프론트 연결 — 승인 범위 완료

<a id="b-00b76e0d0bdb9b05"></a>

기준 `9e52b98`에서 `feature/home-weekly-recommendation`으로 분기했다. 완료 범위는 **Weekly 표시·카테고리 이동·실제 카드 노출·추천 유입 연결**이다. 서버 선정 알고리즘·DB·Today 동작·기존 콘텐츠/저장 정책과 기존 확대 자동 검사는 유지한다.

<a id="b-426e9ee613098a3a"></a>

- 실제 홈 첫 프레임 이후 방문당 인증된 Weekly GET1회, 서버 순서/항목ID/순위/유형/기간·배치·카테고리를 보존한 최대2개 흰 카드다. `MOST_SAVED`·`MOST_VIEWED`·`REDISCOVERY`의 승인 문구와 실제 카테고리명만 빨간 강조를 사용한다. 고정 노란 공지 카드를 제거했다.133×120px·여백/테두리·두 줄 말줄임과 기존 확대 구조를 유지한다.
- 홈 첫 초기화·900ms 스플래시를 연장하지 않는다. 다른 화면에서 홈으로 돌아오면 새 방문/배치를 조회하고 이전 카드를 숨긴다. 필터/스크롤/재빌드·모달/시트·OS 백그라운드 복귀는 같은 방문이다. 조회 중/0개에는 제목·카드·해당 간격을 함께 숨긴다. 실패는 기존 SnackBar ‘이번주 추천을 불러오지 못했어요. 다시 시도해 주세요.’와 해당 방문에만 유효한 수동 재시도다. 새 스켈레톤/오류 디자인은 없다.
- 추천은 일반 피드/개수/커서·홈 필터/Today Stage와 분리한다. 카드는 실제 categoryID로 F01을 열고 검색/다른 필터를 해제하되 아카이브 정렬은 보존한다. Weekly F01의 헤더 뒤로→홈, 일반 아카이브의 기존 복귀를 구분한다. F01↔상세의 항목ID/categoryID/계정 소유권은 홈 방문 종료와 분리하며 다른 카테고리/전체/검색/다시보기·계정 변경에는 해제한다. 실제 소속이 확인된 상세와 이전/다음 진입만 추천 열람에 귀속하고 일반 상세/Today와 섞지 않는다.
- 앱 전면·홈 최상위·모달 없음에서 카드와 모든 상위 가로/세로 viewport의 실제 면적 교집합이50% 이상인 첫 프레임에만 노출한다. 방문/항목당 UUID1개이며 스크롤/재빌드/모달/OS 복귀 중복을 차단한다. 응답 수신·카테고리 이동을 열람으로 만들지 않는다. 기존 인증 재전송은 같은 UUID이고 통계 실패는 조회/이동을 막거나 새 배치/자동 재시도 루프를 만들지 않는다. 계정·방문·요청 변경/종료 후 늦은 응답과 예약된 측정을 무효화한다. 확정 삭제된 카테고리는 제외하고 보충하지 않는다.

<a id="b-7f612af7306ae96f"></a>

검증: 신규 자동21개(Repository/API7·루트8·실제 폰트/viewport6), 전체 `flutter test --no-pub` **1,708개 통과**·`flutter analyze --no-pub` **문제0건**. 기존 확대·인증/공유/세션·콘텐츠 변경·페이지네이션·원본 링크 회귀를 유지했다. 새 홈 GET을 알지 못한 기존 테스트 대역에는 빈 Weekly 정상 계약을 명시했으며 기존 보안/오류 검사를 삭제하거나 건너뛰지 않았다. 별도 임시 PostgreSQL17에서 전체 마이그레이션 적용 후 기존 Weekly/exposure/view HTTP 통합 **100개 통과**(Starlette 의존성 deprecation 경고1건). 대역 통과로 운영 API 성공을 대신하지 않는다.

<a id="b-36e1e0388e4ab253"></a>

Figma: Page1 >261007, 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 C01 `111:3584`·F01 `111:3968` 컨텍스트를 **2026-10-21 21:32:22 KST**에 각각 재조회했다. C01 원본375×910px·F01 원본375×1396px을 보관했다. F01은 기본 컨텍스트의 축소 이미지와 구분해 자연 크기 원본도 확보했다. [출처/보관 시각](/private/tmp/clipback-weekly-recommendation-20261021/figma/reference-manifest.json).

<a id="b-029ad82c122c6d1d"></a>

기기: iPhone16/iOS18.6·Android13/API33 제스처에서 같은 고정 데이터·1배율·키보드 숨김·스크롤0으로 BEFORE/AFTER를 새로 촬영했다. **제품 수정 전에 BEFORE6장 원본을 직접 열어 앱 전면·OS 대화상자 없음**을 확인했다. 홈 예제3개→실제 추천2개, 재발견 문구와 공지 제외, 목적지 전체 카테고리→선택ID의 F01은 의도한 변경이다. 재발견·로딩·빈/오류 전용 원본은 없으므로 공통 C01을 참조하며 대체 디자인을 만들지 않았다.

<a id="b-db3b831a930fba09"></a>

최종 네이티브 결과와 영상 검사: iOS22/22·Android22/22, 스타일/레이아웃/동작/전체 `passed:true`, 프레임워크/Dart 비동기 오류0건. iOS 22.058333초·Android 25.623511초 영상의 녹화 정상 종료·전체 디코딩 종료0/오류0·원본 PTS 증가와 주요/마지막 장면을 확인했다. 실제 문단 글꼴/굵기/자간/색상/행간·133×120px 카드·경계, 실제 탭·모달·스크롤·OS 복귀·카테고리/상세·북마크·F01 복귀·새 방문/배치/UUID·실패/재시도·빈 결과를 검사했다. iOS 창393×852px/상59·하34px, Android Flutter 창392.727×783.273px/상24·하0px이며 Android 실제 OS 탐색 표시는 창 밖에 있다. Figma 예제 콘텐츠·카테고리 색/개수와 OS 창/안전 영역 차이를 유지하며 원본을 보정하지 않는다.

<a id="b-15cbdefca6e71f89"></a>

자료: [3열 비교6쌍](/private/tmp/clipback-weekly-recommendation-20261021/comparison-document.html) · [최종 검증 요약](/private/tmp/clipback-weekly-recommendation-20261021/verification-summary.json) · [iOS 영상](/private/tmp/clipback-weekly-recommendation-20261021/after/ios/after.mp4) · [Android 영상](/private/tmp/clipback-weekly-recommendation-20261021/after/android/after.mp4) · [전체 Flutter](/private/tmp/clipback-weekly-recommendation-20261021/tests/flutter-final.log) · [로컬 DB](/private/tmp/clipback-weekly-recommendation-20261021/tests/backend.log).

<a id="b-44d34b4be6057614"></a>

촬영 도구의 최초 프레임 판정과 Android OS 복귀 전환 대기 보완 시도는 `diagnostics`에 보존하고 최종 성공 근거에서 제외했다. 제품 대기/타이밍을 바꾸지 않았고 촬영 중 무거운 빌드/전체 검사를 병행하지 않았다. 고정 비교 데이터와 장면은 보존했으며 AFTER용 모달/정렬/오류 제어와 경계 수집을 프리뷰에 보완한 사실은 소스 동결 기록과 구분한다.

<a id="b-4946218daabd7cd1"></a>

후속: 운영 추천 품질/운영 서버·실제 OAuth·실기기·TestFlight·원격CI, 공지 데이터/목적지, 새 확대 맞춤과 원본 없는 상태 디자인. 로컬 대역/DB·시뮬레이터/에뮬레이터 확인 범위이며 추천 전체 제품 완료가 아니다. 화면 증거·빌드·임시DB·AGENTS.md는 커밋에서 제외하고 푸시/PR은 하지 않는다. 소유 Flutter 실행/앱·iPhone/Android 가상 기기·8776 포워딩·네이티브 녹화 임시 파일·임시 PostgreSQL 클러스터·이번 Gradle 데몬을 종료/정리했다. Android 제스처 설정2는 변경하지 않았고 기존 ADB 서버는 보존했다. 제품 iOS 생성 설정은 `FLUTTER_TARGET=lib/main.dart`로 복원했다. 설정 복원은 Archive/배포 검증이 아니다.

## 원문 출처: docs/content-recommendation-plan.md

<a id="b-58536e4a0677aaab"></a>

### 13. 2026-10-21 Weekly 프론트 연결 — 승인 범위 완료
