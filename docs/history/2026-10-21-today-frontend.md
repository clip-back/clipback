# Today 버튼과 상세 탐색 연결

- 최초 기록일: 2026-10-21
- 영역: 추천
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-eb03dee3ff2fe3fd"></a>

### 홈 Today 추천의 실제 연결 — 2026-10-21

<a id="b-8a93428ff8085e1e"></a>

기준 `9bf6b6e`에서 `feature/home-today-recommendation`으로 분기했다. 홈 ‘오늘의 콘텐츠 보기’는 이제 홈 첫 항목이 아니라 인증된 Today API의 최대5개를 서버 rank 순서대로 연다. 홈 첫 항목601·추천 첫 항목606을 다르게 고정한 변경 전 검사에서601 진입을 재현했고, 제품 수정 전 양 플랫폼 홈/상세4장을 새로 촬영했으나 Android 최초 촬영은 OS 대화상자로 가려져 제외하고 기준 코드로 재촬영했다. 상세 경위는 아래에 기록하며 촬영 대역의 소스 해시는 전후 동일하다.

<a id="b-a89d8a413075ebe5"></a>

- 버튼에서만 조회하며 최초 홈 로딩·재빌드에 호출을 추가하지 않는다. 별도 유한 추천 목록은 일반 피드의 개수/필터/커서에 삽입하지 않는다. 홈에 없는 추천도 열 수 있으며 기존 상세의 이전/다음·연관 이동에 추천 항목을 유지한다. 매 버튼 진입은 새 조회와 첫 추천부터 시작하고 탐색 중 추가 조회·당일 보충·재번호·클라이언트 추첨은 없다.
- 각 추천 진입 전에 상세 GET을1회 수행한다.404는 대상만 제외하고 현재 화면과 기존 SnackBar 안내를 유지하며 다른 콘텐츠를 자동 대체하지 않는다. 기존 북마크·분류·삭제 처리와 계정/요청 세대의 오래된 응답 방어를 연결했다. 저장 화면의 열기/닫기도 대기 중 홈 요청을 무효화한다.
- 서버stage0은 ‘콘텐츠를 5개 이상 저장하면 오늘의 추천을 볼 수 있어요.’, 그 외0개는 ‘오늘 추천할 콘텐츠가 없어요. 나중에 다시 확인해 주세요.’, 일반 실패는 ‘오늘의 콘텐츠를 불러오지 못했어요. 다시 시도해 주세요.’,404는 ‘이 콘텐츠는 더 이상 볼 수 없어요.’를 기존 SnackBar로 표시한다. 빈 홈의 기존 저장 진입은 유지한다.
- 추천 상세 진입마다 UUID v4와 해당 `recommendation_item_id`로 view POST를1회 보낸다. 재전송은 같은 UUID이며 일반 상세의 기존 본문 없는 view와 구분한다. 기존 card_clicked/원본 링크 이벤트를 유지하고 지표 실패가 화면 진입을 실패시키지 않는다. 버튼에는 개별 추천이 표시되지 않으므로 조회·버튼·상세를 추천 카드 노출로 만들지 않았다. exposures API 호출은0회다.
- 서버 API·DB·선정 알고리즘과 홈/상세 화면 위젯·폰트·에셋을 바꾸지 않았다. 새 추천 화면·주간 추천·실제 카드 노출·확대 맞춤·운영 검증은 후속이며 추천 프론트 전체 완료가 아니다.

<a id="b-7e19f79e24b99405"></a>

검사: 새 Today 자동 검사21건, 관련82건, 전체 Flutter1,687건이 통과했고 `flutter analyze --no-pub` 문제0건이다. 전용 임시 PostgreSQL17에 현재 마이그레이션을 적용한 Today/view HTTP 통합 검사60건이 통과했다. 서버0/4/5/9/10개 경계·일별 선정/삭제, 프론트0/1/5개·순위 공백·조회만으로 지표0·중복/이탈/저장 화면/늦은 응답·조회와 쓰기 경합·추천 유입/일반 상세 분리·기존 원본 열기 회귀를 확인했다. [자동 검사](/private/tmp/clipback-today-recommendation-20261021/tests/after-related.log) · [전체 검사](/private/tmp/clipback-today-recommendation-20261021/tests/flutter-test.jsonl) · [PostgreSQL 계약](/private/tmp/clipback-today-recommendation-20261021/tests/backend-target.log).

<a id="b-17a14ca9754ac319"></a>

Figma는 Page1 >261007의 C01 `111:3584`·F02 `111:3842`를 구현 전에 각각 재조회했고 원본과 컨텍스트를 보관했다. 응답 보관 시각은2026-10-21 20:12:33 KST이며 실제 도구 조회 이후의 파일 보관 시각이다. [출처 기록](/private/tmp/clipback-today-recommendation-20261021/figma/reference-manifest.json). 예제 데이터·실제 OS 창과 여백의 차이를 유지하며 원본은 보정하지 않는다.

<a id="b-c8854c88489a43ab"></a>

기기 실행은 iPhone16/iOS18.6·Android13/API33 제스처에서 새로 수행해 최종 iOS26/26·Android27/27이 통과했다. 양쪽 홈 앱 영역의 변경 전후 픽셀은 동일하고 창 크기·안전 여백도 동일하다. 첫 상세는601→606으로 대상과 불러온 개수가 달라지는 의도된 변경이다. 홈→추천5개 순서/양 끝→북마크→원본 외부 열기/복귀→홈→실패·stage0·빈 결과→수동 재시도를 확인했다. 프레임워크·Dart 비동기 오류는 최종 실행0건이며 영상의 종료·전체 디코딩·PTS를 별도로 검사했다.

<a id="b-cf9605f8bac88935"></a>

초기 Android OS System UI 응답 없음 대화상자가 촬영을 가린 사실을 원본 이미지 검토에서 발견했다. 가린 최초 BEFORE/AFTER·첫 판정은 진단 폴더에 보존하고 최종 비교/성공 근거에서 제외했다. 수정한 제품4파일을 `9bf6b6e` 내용으로 일시 복원해 유효한 Android BEFORE를 다시 촬영한 다음, 구현 파일을 전체 검사 통과 당시 해시와 일치하게 복원했다. 따라서 Android 최종 BEFORE는 최초 제품 수정 이전 촬영이 아닌 기준 코드 재촬영이며 이 차이를 숨기지 않는다. 촬영 대역의 소스는 계속 동일하다. 빌드/검사 병행 중 발생한 대역의 프레임 대기 timeout과 attach 실행 옵션 진단도 최종 성공으로 덮지 않았다. 실제 OS 브라우저 열기/앱 복귀를 확인했으며 외부 페이지 본문 로딩 완료를 성공 조건으로 삼지 않았다.

<a id="b-c995f66cfab3123b"></a>

자료: [3열 비교4쌍](/private/tmp/clipback-today-recommendation-20261021/comparison-document.html) · [검증 요약과 한계](/private/tmp/clipback-today-recommendation-20261021/verification-summary.json) · [iOS 영상](/private/tmp/clipback-today-recommendation-20261021/after/ios/after.mp4) · [Android 영상](/private/tmp/clipback-today-recommendation-20261021/after/android/after.mp4). 대역/로컬 DB 검증은 운영 API·실제 OAuth·실기기·TestFlight·원격CI 검증과 구분한다. 화면 증거·DB·빌드·AGENTS.md는 커밋에서 제외하며 푸시/PR은 하지 않는다.

<a id="b-d3d353edde251b44"></a>

검증 후 소유 Flutter 실행·Gradle·임시 PostgreSQL·iPhone/Android 기기·8776 포워딩을 종료했다. Android 제스처 설정2는 변경하지 않았고 기존 ADB 서버는 유지했다. iOS 생성 설정의 `FLUTTER_TARGET=lib/main.dart`를 복원했으며 이는 Archive/서명/배포 검증이 아니다.

## 원문 출처: docs/content-recommendation-plan.md

<a id="b-755258ced17e313b"></a>

### 12. 2026-10-21 Today 프론트 부분 연결
