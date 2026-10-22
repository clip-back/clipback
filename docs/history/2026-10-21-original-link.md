# 원문 링크 외부 열기

- 최초 기록일: 2026-10-21
- 영역: 기능
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-2bd6ea5e13e45e30"></a>

### 원본 링크 외부 열기 검증 — 2026-10-21

<a id="b-019bd5d700f0b7de"></a>

- 상세의 링크 아이콘은 `url_launcher ^6.3.3`의 외부 모드로 실제 원본 URL을 연다. 사진 원본 시트·전문 펼침은 유지하고 손상된 링크 시트 에셋은 제거했다. 잘못된 URL/OS 거절/예외는 기존 오류 안내와 수동 재시도를 사용한다.
- 주입 가능한 `OriginalLinkOpener`와 상세 방문 소유권 검사로 중복·늦은 응답을 방어한다. OS 수락 후 같은 계정/상세의 정확한 ID만 기존 통계로 기록하며 통계 실패는 열기 성공과 분리한다. 기존 화면 필수 생성자/콜백·서버 API/모델은 유지한다.
- 실제 루트 프리뷰: `flutter run -t test/support/original_link_preview.dart --dart-define=ORIGINAL_LINK_PHASE=after -d <기기ID>`. API/세션/공유만 격리하며 URL 플러그인은 실제 구현이다. HTTP8767의 `/scene?kind=link|photo`, `/toggle`, `/scroll?offset=12`, `/original`, `/close-sheet`, `/state`로 관찰한다. Android는 검증용8768→8767 포워딩을 사용했다. 제품 실행/배포 진입점은 **`lib/main.dart`**다.
- 초기 집중72·최종 관련118·전체1666 통과(실패/건너뜀0), analyze 문제0. 기존 실제 글꼴·320/375px·1배율 및 확대 자동 검사를 유지했다. iPhone16/iOS18.6·Android13/API33 제스처에서 실제 Safari/Chrome 열기·복귀·사진 원본을 각각11/11로 확인했으며 수정 경로 Flutter/비동기 Dart 오류0이다.
- 제품 변경 전에 동일 대역·기기·데이터·배율로 새 BEFORE를 촬영해 SVG 오류를 양 플랫폼에서 재현했다. 전후 창/안전 여백/버튼 경계/스크롤0이 같고 F02 재조회 원본과3열2쌍을 제공한다. Figma와의 OS/예제 데이터 차이 및 초기 디스크/에뮬레이터/촬영 도구 진단을 구분했다. 운영 API·OAuth·공급자 앱·실기기·TestFlight·실제 기사 전문/미디어는 별도다.
- 검증 후 소유 기기/앱·8767/8768 임시 서버·8768/54709 포워딩·이번 빌드 데몬을 종료했다. Android 탐색2 설정은 보존했고 로컬 iOS `FLUTTER_TARGET=lib/main.dart`를 복원했다. 기존 ADB/다른 작업의 프로세스와 아카이브는 유지했다.

<a id="b-f4726e6de5f0a7a4"></a>

[3열 비교](/private/tmp/clipback-original-link-20261021/comparison-document.html) · [실제 검사/한계](/private/tmp/clipback-original-link-20261021/verification-summary.json) · [iOS 영상](/private/tmp/clipback-original-link-20261021/after/ios/after-final.mp4) · [Android 영상](/private/tmp/clipback-original-link-20261021/after/android/after-final.mp4) · [계획/적용 범위](../figma-ui-alignment-plan.md#원문-보기-오류와-원본-링크-열기--2026-10-21)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-91b3076c7d1334ea"></a>

### 2026-10-21 · 원문 보기 오류와 원본 링크 열기

<a id="b-a14ad9559aaec18e"></a>

- `main/b169d93` 기준, `fix/original-link-opening`. F02 `111:3842`의 기존 링크 아이콘에서 OS 외부 앱/브라우저를 바로 여는 사용자 확정 동작을 연결했다. 손상 instagram.svg와 링크 시트를 제거하고 사진 원본/전문 펼침을 보존했다. Figma 컨텍스트·375×890px 렌더 원본을18:15 KST에 재조회했다.
- URL 검증·중복 차단·실패 안내/수동 재시도·상세/계정 세대와 ID 고정·늦은 응답 방어를 추가했다. OS 수락 뒤 기존 통계를1회 기록하고 통계 실패는 분리한다. API·Repository 계약·모델·세션/공유 보안 처리는 유지했다.
- BEFORE 제품222파일의 기준 일치와 촬영 대역 동결을 확인하고 양 플랫폼 SVG XML 오류를 먼저 재현했다. 초기 집중72, 최종 관련118, 전체1666 통과(실패/건너뜀0), analyze 문제0. 기존 1배율 실제 글꼴·안전 영역·확대·사진 원본 회귀를 포함한다.
- iPhone16/iOS18.6·Android13/API33 제스처에서 실제 Safari/Chrome 열기와 복귀·펼침/스크롤12px·대상601 이벤트1회·사진 시트/링크 이벤트0·공유 격리·오류0을 각각11/11로 확인했다. BEFORE/AFTER 창·안전 여백·버튼 경계·스크롤0은 같다. 새3열2쌍·영상2개(iOS10.005초306프레임, Android9.230611초179프레임)의 전체 디코딩과 녹화 완료를 확인했다.
- 디스크 부족 빌드 실패·초기 Android System UI ANR·촬영 대역과 관찰 필드 진단을 보존하고, 캐시 정리/host GPU 재실행 뒤 새 최종 결과와 구분했다. 아카이브/과거 비교 자료는 유지했다. OS/예제 데이터 차이와 대응 Figma 없는 브라우저/사진 시트를 별도 설명한다.
- API/세션/통계/공유 대역과 실제 OS URL 실행을 구분한다. 실제 전문/미디어·공급자 앱·운영 API·OAuth·실기기·TestFlight는 미검증/후속이다. 새 디자인/새 확대를 추가하지 않았다.
- 검증 후 소유 기기/앱·8767/8768 임시 서버·8768/54709 포워딩·이번 빌드 데몬을 종료했다. Android 탐색2 설정은 보존했고 로컬 iOS `FLUTTER_TARGET=lib/main.dart`를 복원했다. 기존 ADB/다른 작업의 프로세스와 아카이브는 유지했다.

<a id="b-bf6834926a62cdcf"></a>

[3열 비교2쌍](/private/tmp/clipback-original-link-20261021/comparison-document.html) · [검사/한계](/private/tmp/clipback-original-link-20261021/verification-summary.json) · [iOS 영상](/private/tmp/clipback-original-link-20261021/after/ios/after-final.mp4) · [Android 영상](/private/tmp/clipback-original-link-20261021/after/android/after-final.mp4)

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-322c6ddadd0d59ce"></a>

### 원문 보기 오류와 원본 링크 열기 — 2026-10-21

<a id="b-bf3f4b4a14b642fa"></a>

- 기준 `main/b169d93`, 작업 브랜치 `fix/original-link-opening`. Page 1 >261007·F02 `111:3842` 컨텍스트와 원본을 **2026-10-21 18:15 KST**에 새로 조회했다. 이번 렌더 PNG는375×890px이며 실제 OS 창에 맞춰 자르거나 보정하지 않았다. 기존 링크 아이콘·글자·배치는 유지한다.
- 사용자 확정대로 링크 아이콘은 기존 요약/URL 시트 대신 실제 OS 외부 앱/브라우저를 바로 연다. `url_launcher ^6.3.3`·`externalApplication`을 주입 가능한 서비스로 분리했다. 링크 전용 시트 분기·손상 instagram.svg·미사용 상수/import를 제거했고, 사진 원본 시트와 전문 펼침은 유지했다. 실제 전문은 아직 mapper의 요약 재사용이며 기사 수집/미디어 기능을 추가한 것이 아니다.
- HTTP(S) 절대 URL/호스트를 검사하고 앞뒤 공백만 정리한다. 경로·쿼리·fragment는 보존한다. 빈/잘못된 URL·false·예외에는 기존 SnackBar로 수동 재시도를 안내하며 새 로딩/실패 디자인은 만들지 않았다. 요청 중 중복 실행을 막고 완료 뒤 새 탭은 다시 실행할 수 있다.
- 버튼 콜백은 상세 방문의 handle/세대에 묶고 실행 직전 URL·콘텐츠 ID를 고정한다. 동일 계정/상세가 유효한 OS 수락 후에만 기존 `original_link_opened`를1회 기록한다. 이동·같은 ID 재진입·계정 변경·무효화·dispose의 늦은 응답/콜백은 무시하며 이전 완료가 새 요청의 잠금을 풀지 않는다. 통계 실패는 열기 성공을 바꾸거나 재실행하지 않는다. 서버 API·Repository 계약·모델·세션/공유 보안 정책은 변경하지 않았다.
- **제품 변경 전** 촬영 대역의 요청 전달/루트 재생성을 검증한 뒤 소스를 동결하고, 제품222파일의 기준 SHA 일치를 확인한 상태로 양 플랫폼 BEFORE를 새로 확보했다. 링크 시트의 `XmlParserException: ">" expected at 12:28`을 두 플랫폼 모두 재현했다. 동결한 대역 소스 SHA는 AFTER에도 같다.
- 초기 집중72/72, 추가 소유권 겹침 검사를 포함한 관련118/118, 전체 `flutter test --no-pub --concurrency=2` **1666/1666** 통과(실패/건너뜀0), `flutter analyze --no-pub` 문제0이다. 실제 Pretendard의 iOS/Android×320/375px×1배율 상세/안전 영역과 기존 확대·사진 인증 다운로드/캐시/재시도 검사를 유지했다.
- iPhone16/iOS18.6·Android13/API33 제스처에서 **실제 플러그인·Safari/Chrome**을 사용했다. 플랫폼별11/11 판정: 외부 열기·대상601 통계1회·복귀 뒤 동일 콘텐츠/펼침/스크롤12px·링크 시트 없음·사진 원본 시트와 링크 이벤트0·공유 격리·수정 경로 Flutter 오류/비동기 Dart 예외0이다. 실제 창은 iOS393×852pt(상59/하34), Android392.727×783.273dp(Flutter view의 상24/하0)이며 OS 탐색 영역은 원본 스크린샷에 포함했다. BEFORE/AFTER 창·viewPadding·링크 버튼 경계·스크롤0이 일치한다.
- 새 BEFORE/AFTER/F02 **3열2쌍**과 AFTER 영상2개를 제공한다. iOS10.005초/306프레임·Android9.230611초/179프레임이며 녹화 종료·전체 디코딩을 확인했다. 원본은 보존하고 표시용 비교본만 같은 폭으로 축소했다. 외부 브라우저/사진 시트의 별도 Figma 원본은 없으며 새 디자인으로 채우지 않았다. 링크/뒤로가기/더보기 원본 에셋의 실제 양 플랫폼 번들 바이트 일치와 손상 SVG의 번들 제외도 확인했다.
- 초기 빌드는 디스크 부족으로 실패했다. 재생성 가능한 빌드 캐시만 정리하고 기존 아카이브·비교 자료는 보존한 뒤 재빌드했다. Android 소프트웨어 GPU의 System UI ANR 이후 host GPU·1536MB·2코어로 재실행했으며 최종 BEFORE/AFTER는 같은 설정이다. 촬영 대역/브라우저 첫 실행/Activity 관찰 필드의 초기 진단은 별도 로그로 보존하고 최종 성공으로 덮지 않았다.
- API·통계·세션·공유는 메모리 대역, URL 실행/브라우저는 실제 OS 검증이다. OS 수락이 모든 외부 페이지의 로딩 완료를 보장하지 않는다. 공급자 앱 직접 연결·운영 API·OAuth·실기기·TestFlight·실제 전문/미디어·새 확대는 미검증/후속이며 상세 전체 기능 완료로 표시하지 않는다.
- 검증 후 소유 기기/앱·8767/8768 임시 서버·8768/54709 포워딩·이번 빌드 데몬을 종료했다. Android 탐색2 설정은 보존했고 로컬 iOS `FLUTTER_TARGET=lib/main.dart`를 복원했다. 기존 ADB/다른 작업의 프로세스와 아카이브는 유지했다.

<a id="b-75fb83651b034df3"></a>

[3열 비교2쌍](/private/tmp/clipback-original-link-20261021/comparison-document.html) · [검사/한계](/private/tmp/clipback-original-link-20261021/verification-summary.json) · [iOS 판정](/private/tmp/clipback-original-link-20261021/after/ios/native-result.json) · [Android 판정](/private/tmp/clipback-original-link-20261021/after/android/native-result.json) · [iOS 영상](/private/tmp/clipback-original-link-20261021/after/ios/after-final.mp4) · [Android 영상](/private/tmp/clipback-original-link-20261021/after/android/after-final.mp4)
