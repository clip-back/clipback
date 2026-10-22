# 알림 목록과 빈 위젯

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-919c903ad0ebb223"></a>

직전 `220f313` 기준 작업은 **C03 알림 목록의 승인된1배율 표현·홈 왕복과 명시적 빈 위젯**입니다. 기존 제목/시간3개·순서를 읽기 전용으로 보존하고 설정은 기존 ReminderSheet로 연결합니다. 홈 세로·최근 카드/점은 알림 왕복에서만 유지합니다. **BEFORE16건=1통과/화면 부재15목표 실패·양 플랫폼 각18기록을 확인했습니다. 최종 AFTER 집중25/전체1412·분석0·각28기록/전체true·오류0·목록2쌍+신규 빈2건·영상2개·번들270/270·환경 정리를 확인했습니다.** 빈 위젯은 명시적 items=[] 장면이며 실제 루트의 알림0 조회 결과가 아닙니다. 운영 알림/읽음/삭제/API·설정은 후속입니다. 앞선 K01 기록은 당시 결과로 보존합니다.

<a id="b-09899fbf1fcb497a"></a>

### 홈 알림 화면의 1배율 맞춤 — 2026-10-18 작업

<a id="b-6ab6dfe41119151a"></a>

`220f313` 기준 **C03-2 목록·홈 왕복과 C03-1의 명시적 빈 위젯**을 적용합니다. 기존 제목/시간3개·순서를 읽기 전용으로 보존하며 실제 알림/읽음/삭제/API는 추가하지 않습니다. 헤더64px·최소76px 행·좌우/상16·하24px·행 간격8px·원본 표시/설정/빈 일러스트를 사용합니다. 제목/시간은 글자 축소·말줄임 없이 자연 줄바꿈합니다.

<a id="b-a8c27b830a91d767"></a>

- 계획 조회18:08:14~19 KST와 구현 **2026-10-18 18:18:19~25 KST**를 구분하고 C03-1 `125:4173`·C03-2 `111:5410` 컨텍스트/375×812px 원본을 각1회 확보했습니다([출처](/private/tmp/clipback-notification-alignment-20261018/figma/reference-manifest.json)). 기존 뒤로 SVG는 정확한 bytes를 재사용하고 표시/설정/빈 원본3개를 로컬 등록합니다([대조](/private/tmp/clipback-notification-alignment-20261018/figma/asset-source-audit.json)). 두375×812px 원본의 공통 헤더·실제 OS 표시를 원본 그대로 비교합니다.
- [NotificationListScreen](../../frontend/lib/features/home/notification_list_screen.dart)은 필수 record 목록 `items`와 `onBack`/`onOpenSettings`를 받습니다. HomeScreen/HomeHero의 선택적 `onOpenNotifications` 미주입은 기존 시트 fallback입니다. 실제 루트는 고정2슬롯에서 홈 State·세로/최근 카드/활성 점을 알림 왕복에 한해 보존하고 다른 경로/계정·인증/세션 복구 경계에서는 기존 초기화를 유지합니다. 숨은 홈의 입력/접근성/포커스·애니메이션 ticker와 비활성 알림 PopScope를 차단합니다. 설정은 기존 ReminderSheet이며 모달 중 중복/복귀 콜백을 차단합니다.
- 빈 장면은 **명시적 items=[] 독립 위젯**입니다. 루트는 예제3개를 계속 표시하므로 홈 콘텐츠0·목록 없음·API 로딩을 알림0으로 추정하지 않습니다. 기존 실제 Bold 별칭·86×100px 원본 크롭/알파 그림자·자연 높이를 사용하며 낮은 화면에서도 본문 끝24px까지 스크롤합니다. API/Repository/모델·인증/세션/공유 보안 정책은 유지합니다.
- **현재 검증:** [동결](/private/tmp/clipback-notification-alignment-20261018/tool-source-freeze.json) 기준 BEFORE16건=폰트1통과/C03 부재15목표 실패·양 플랫폼 각18기록/오류0·홈16px/최근320px/점1 왕복을 확인했습니다. 새 시트 원본은 iOS18:32:36~37·Android18:33:51~52 KST이며 [18:34:11 게이트](/private/tmp/clipback-notification-alignment-20261018/product-edit-gate.json) 뒤 제품을 적용했습니다. AFTER [최종 집중25/25](/private/tmp/clipback-notification-alignment-20261018/tests/after-target-final.log)(스타일7+콘텐츠/빈9+이동/보안9·약5초/exit0)는 통과했고 [iOS](/private/tmp/clipback-notification-alignment-20261018/ios/after/report.json)·[Android](/private/tmp/clipback-notification-alignment-20261018/android/after/report.json)의 각28기록은 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0입니다. 최종 [전체1412/1412](/private/tmp/clipback-notification-alignment-20261018/tests/flutter-test-final.log)는1분24초·실패/건너뜀0·exit0, [분석](/private/tmp/clipback-notification-alignment-20261018/tests/flutter-analyze-final.log)은문제0·3.5초·exit0입니다. 최초 전체1412 통과 뒤 발견한 블록 중괄호 lint2건을 보완해 전체/분석을 다시 실행했습니다. 첫21/25의 단위 입력/대역/정리4실패는 별도 원본으로 보존하고 제품·촬영 fixture를 바꾸지 않고 단위 검사만 교정했습니다([입력](/private/tmp/clipback-notification-alignment-20261018/content-unit-input-correction.json), [대역/정리](/private/tmp/clipback-notification-alignment-20261018/navigation-unit-harness-correction.json)).
- 목록은 기존 시트→새 목록→Figma2쌍, 빈은 BEFORE가 없는 신규2건으로 구분합니다. [비교 문서](/private/tmp/clipback-notification-alignment-20261018/comparison-document.html)는 실제 OS 여백·예제 데이터 차이를 표시하고 두 원본의 공통 헤더를 기준으로 사용합니다. AFTER 영상 [iOS31.323333초](/private/tmp/clipback-notification-alignment-20261018/ios/after/actions-preview.mp4)·[Android52.813544초](/private/tmp/clipback-notification-alignment-20261018/android/after/actions-preview.mp4)의 원본/표시본 전체 디코딩0·정확한 시작/끝/2초 간격 시각 검사, [실제 번들270/270](/private/tmp/clipback-notification-alignment-20261018/bundleverification.json)·[환경 정리](/private/tmp/clipback-notification-alignment-20261018/cleanup-verification.json)를 확인했습니다. 영상은 목록으로 시작/종료하며 중간 A01은 독립 대역 앱 초기화입니다. 실제 알림/푸시/읽음/삭제·운영 설정·원본 없는 상태·새 확대와 운영 서버/OAuth/실기기는 후속입니다. 기존 소개의 낮은 viewport 오류는 수정하지 않고 소개812px/홈·알림480px 검사를 구분합니다.

<a id="b-820335917bd52a7c"></a>

- [증거 요약](/private/tmp/clipback-notification-alignment-20261018/evidence-summary.json)은 촬영 전후 native import34개와 현재 제품9파일의 동일성을 확인합니다. 보호 소스279개 중 공유 프리뷰1개는 촬영 뒤 중괄호만 달라 전체 현재 SHA가 모두 같다고 보고하지 않습니다. [형식 교정 기록](/private/tmp/clipback-notification-alignment-20261018/post-capture-lint-only-correction.json)에 원본 역재구성·현재 SHA와 native 재실행 없이 최종 자동 검사한 범위를 남겼습니다.

<a id="b-f859211f6ec5ff31"></a>

### 알림 화면 재현 명령

<a id="b-5e813247218782cd"></a>

```sh
flutter test --no-pub test/notification_list_figma_test.dart test/notification_list_content_test.dart test/notification_navigation_test.dart
flutter test --no-pub
flutter analyze --no-pub
flutter run --no-pub -t test/support/notification_alignment_preview.dart --dart-define=NOTIFICATION_PHASE=before -d <device-id>
flutter run --no-pub -t test/support/notification_after_preview.dart --dart-define=NOTIFICATION_PHASE=after -d <device-id>
```

<a id="b-2905456623f57c3e"></a>

core 프리뷰는 실제 ClipbackApp·메모리 API/세션·첫 실행부터의 공유 격리를 사용합니다. BEFORE는 실제 `220f313` 제품, AFTER는 수정 제품에서 빌드하며 phase 값만 바꾸어 이전 화면을 대신하지 않습니다. `/scene?kind=list&session=member`는 목록, AFTER 전용 `/empty-scene`은 명시적 빈 위젯, `/max-scroll`은 본문 끝, `/run`은 회원/게스트·홈 위치/점·설정·복귀·기존 목적지와 무효화를 검사합니다. AFTER adapter만 새 빈 위젯을 import하며 baseline에 존재하지 않는 장면을 BEFORE로 생성하지 않습니다. 실제 스타일·경계·에셋·동작 및 공유 prompt 차단 여부를 전체 판정에 연결합니다. 운영 서버/계정으로 실행하는 도구가 아닙니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-5e0f56ad4e5b6a4b"></a>

직전 `220f313` 기준 C03 알림 목록/명시적 빈 위젯 작업의 집중25/전체1412·분석0·각28기록/오류0·목록2쌍/신규 빈2건·영상2개는 당시 독립 기록으로 보존하며 이번 B01 결과로 재사용하지 않습니다.

<a id="b-a5b3ff38d5dec6f5"></a>

- `220f313`·`feature/figma-ui-alignment`에서 C03-2 `111:5410`의 승인된1배율 읽기 전용 별도 목록과 홈 왕복·C03-1 `125:4173`의 명시적 빈 위젯을 적용했습니다. 기존 제목/시간3개·순서·실제 SafeArea/최대375px을 유지합니다. 홈 세로/최근 rail/점은 알림 왕복만 보존하며 다른 라우트·계정/인증 경계의 기존 초기화를 유지합니다. 설정은 기존 ReminderSheet이고 API/Repository/모델·세션/공유 정책은 변경하지 않습니다.
- 계획 조회18:08:14~19 KST와 구현 **2026-10-18 18:18:19~25 KST**를 구분해 각 컨텍스트·375×812px 원본을1회 확보했습니다([출처](/private/tmp/clipback-notification-alignment-20261018/figma/reference-manifest.json)). 기존 뒤로 SVG bytes 일치·신규 표시/설정/빈 원본3개를 확인했습니다([에셋](/private/tmp/clipback-notification-alignment-20261018/figma/asset-source-audit.json)). 두375×812px 원본의 공통 헤더/OS 표시를 기준으로 사용합니다. 전체 화면 이미지를 구현 에셋으로 사용하지 않습니다.
- [최종 도구 동결](/private/tmp/clipback-notification-alignment-20261018/tool-source-freeze.json) 후 BEFORE16건=폰트1통과/화면 부재15목표 실패, 양 플랫폼 baseline각18기록/오류0·홈16px/최근320px/점1 왕복 보존을 확인했습니다. 새 시트 원본은 iOS18:32:36~37·Android18:33:51~52 KST이고 [18:34:11 게이트](/private/tmp/clipback-notification-alignment-20261018/product-edit-gate.json) 뒤 제품을 적용했고18:36:43 KST 최종 소스 SHA를 기록했습니다. 사용하지 않은 초기 oracle build-only 시도(exit0)는 판정 가정을 교정한 뒤 BEFORE를 재빌드/촬영했으며 원본을 수정하지 않았습니다.
- AFTER 최초25건은21통과/4실패입니다([당시 로그](/private/tmp/clipback-notification-alignment-20261018/tests/after-target-initial.log)). Android 빈 단위 검사의360→300px 입력 교정2건과 상세GET 대역 누락·semanticsHandle 정리 교정2건은 [입력](/private/tmp/clipback-notification-alignment-20261018/content-unit-input-correction.json)·[단위 하네스](/private/tmp/clipback-notification-alignment-20261018/navigation-unit-harness-correction.json)에 전후 소스/원인을 기록했습니다. 제품·공통 촬영 fixture는 바꾸지 않았고 최초 소스/로그를 보존합니다. AFTER [최종 집중25/25](/private/tmp/clipback-notification-alignment-20261018/tests/after-target-final.log)(스타일7+콘텐츠/빈9+이동/보안9·약5초/exit0)는 통과했고 [iOS](/private/tmp/clipback-notification-alignment-20261018/ios/after/report.json)·[Android](/private/tmp/clipback-notification-alignment-20261018/android/after/report.json)의 각28기록은 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0입니다. 최초 전체1412건 통과 후 분석에서 단위/공유 프리뷰의 블록 중괄호 lint2건을 발견해 보완했습니다. 최종 [전체1412/1412](/private/tmp/clipback-notification-alignment-20261018/tests/flutter-test-final.log)·실패/건너뜀0·1분24초/exit0와 [분석0](/private/tmp/clipback-notification-alignment-20261018/tests/flutter-analyze-final.log)·3.5초/exit0를 재확인했습니다.
- 목록의 기존 시트→새 목록→Figma2쌍과 빈 BEFORE 없는 신규2건을 구분합니다. 빈은 명시적 items=[] 독립 위젯으로 실제 루트의 알림0 결과가 아니며 홈 콘텐츠0으로 추정하지 않습니다. 실제 OS 여백/예제 데이터 차이를 표시하고 대체 화면을 만들지 않습니다. 실제 알림/푸시/읽음/삭제/상세 목적지·운영 설정·원본 없는 로딩/오류·새 확대는 후속입니다. 기존 소개320×480px 오류는 수정하지 않고 소개812px/홈·알림480px 검증으로 구분합니다. 메모리 대역과 실제 OAuth/운영 서버/실기기/CI는 구분하며 증거·빌드·AGENTS.md 제외/푸시·PR 없음입니다.
- [새 비교 문서](/private/tmp/clipback-notification-alignment-20261018/comparison-document.html)는 목록의 완전3열2쌍과 BEFORE 없는 빈2열2건입니다. AFTER [iOS31.323333초](/private/tmp/clipback-notification-alignment-20261018/ios/after/actions-preview.mp4)·[Android52.813544초](/private/tmp/clipback-notification-alignment-20261018/android/after/actions-preview.mp4)의 [원본 디코딩/녹화](/private/tmp/clipback-notification-alignment-20261018/media-verification.json)·[정확한 시작/끝/2초 간격 시각 검사](/private/tmp/clipback-notification-alignment-20261018/video-frame-review.json)·[번들270/270](/private/tmp/clipback-notification-alignment-20261018/bundleverification.json)·[환경 정리](/private/tmp/clipback-notification-alignment-20261018/cleanup-verification.json)를 확인했습니다. 양 영상은 목록으로 시작/종료하며 중간 A01은 대역 초기화 구간입니다. Android 실제 OS Back·공통 원본 헤더/OS 픽셀과 빈 알파12점도 별도 증거로 확인했습니다. 소유 기기/ADB/포트5037·8767~8769 종료·제스처2 유지·설정/사용자 데이터 변경0입니다. [증거 요약](/private/tmp/clipback-notification-alignment-20261018/evidence-summary.json)은 촬영 전후 native import34개·현재 제품9파일의 SHA 일치와 보호 소스279개 중 공유 프리뷰1개의 촬영 후 중괄호 차이를 구분합니다. [형식 교정](/private/tmp/clipback-notification-alignment-20261018/post-capture-lint-only-correction.json)은 원본 역재구성·현재 SHA로 중괄호/공백만의 차이를 확인하며 native 재실행 없이 최종 자동 검사를 수행한 범위를 기록합니다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-6dfec648a92cd0a3"></a>

> `220f313` 기준 C03-2 목록·홈 왕복과 C03-1의 명시적 빈 위젯을 적용했다. **최종 집중25/전체1412·분석0·양 플랫폼 각28기록/전체true·오류0·목록2쌍+신규 빈2건·영상2개·번들270/270·환경 정리**를 확인했다. 실제 알림 API·운영 기능 완료가 아니다.

<a id="b-3d97075715b332e3"></a>

### 기준·화면·이동 경계

<a id="b-c14aef1ced329143"></a>

- Page 1 >261007의 [C03-1 알림 없음 `125:4173`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=125-4173)·[C03-2 목록 `111:5410`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-5410)의 계획 조회 **2026-10-18 18:08:14~18:08:19 KST**와 구현 조회 **18:18:19~18:18:25 KST**를 구분한다. 구현 직전에 각1회 컨텍스트·375×812px 원본을 확보했다([조회 기록](/private/tmp/clipback-notification-alignment-20261018/figma/reference-manifest.json)). 두375×812px 원본 모두 상태 바·뒤로가기/알림/설정 헤더·하단 OS 표시가 있다. 실제 원본 픽셀과 컨텍스트를 함께 기준으로 사용한다.
- [NotificationListScreen](../../frontend/lib/features/home/notification_list_screen.dart)은 필수 `items: List<({String title, String time})>`·`onBack`·`onOpenSettings`를 받는다. 목록은 기존 제목/시간3개와 순서를 보존하고 읽기 전용이다. 헤더64px·뒤로24px/터치48px·설정24px/터치44px, 목록 좌우/상16·하24px·최소76px/모서리8px/내부16px·행 간격8px을 적용한다. 제목16px/Medium/자간−0.4px·시간12px/Medium/자간−0.3px은 AUTO이며 제목·시간 모두 축소/말줄임 없이 자연 줄바꿈한다. 시간 최대 폭64px·원본 표시19px/앞 간격16px·제목/시간 간격8px을 사용한다.
- 빈 표현은 `items=[]`에만 표시되는 위젯이다. 실제 루트는 계속 기존 예제3개를 주입하므로 홈 콘텐츠0을 알림0으로 추정하지 않는다. 일러스트86×100px·원본 크롭과 알파 형태 그림자, 제목24px/Bold/1.6·설명16px/Medium/1.5·원문 개행과16/8px 간격을 적용한다. 그룹 최대224px·설명 최대192px·본문 중앙 대비 시작−240px/최소상16px·본문끝24px이며 낮은 화면에서는 자연 높이/스크롤로 접근한다. 기존 실제 Bold 별칭 `PretendardDetail`을 해당 역할에만 사용한다.
- 기존 뒤로 SVG는 원본 bytes 일치로 재사용한다. 표시 SVG·설정 SVG·빈 원본 PNG는 원본 bytes 그대로 새 로컬3에셋에 등록한다([에셋 대조](/private/tmp/clipback-notification-alignment-20261018/figma/asset-source-audit.json)). 설정은 기존 archive 설정과 bytes가 다르므로 덮어쓰지 않는다. 전체 화면 이미지·가짜 상태 바/키보드/인디케이터는 구현에 사용하지 않는다.
- `HomeScreen`·`HomeHero`의 선택적 `onOpenNotifications`와 내부 `AppRoute.notificationList`를 추가한다. 미주입 호출자는 기존 NotificationSheet fallback을 유지한다. 실제 루트는 고정2슬롯 flow로 홈 State를 유지해 세로/최근 rail/활성 점을 알림 왕복에서만 보존한다. 비활성 홈은 포커스·semantics·입력과 애니메이션 ticker를 차단하며, 알림을 닫으면 비활성 PopScope를 제거한다. 검색/상세/다른 루트로 나가면 기존처럼 홈을 dispose한다.
- generation/authEpoch/현재route·mounted/세션 존재·pending clear·busy/복구/연결 오류를 재검사해 오래된 열기/복귀/설정 콜백을 차단한다. 설정은 기존 ReminderSheet로 열고 중복 진입 및 모달 중 목록 복귀 콜백도 막는다. 숨은 홈에도 최신 피드를 전달해 필터/피드 버전/표시ID 변경 시 기존 rail0 초기화, 북마크만 변경될 때 위치 보존을 유지한다. API/Repository/모델·세션/공유 보안을 변경하지 않는다.

<a id="b-5fe226d09638f4c5"></a>

### 재현·최종 검증 기록

<a id="b-772db9e49fb60051"></a>

- [최종 도구 동결](/private/tmp/clipback-notification-alignment-20261018/tool-source-freeze.json)은 **18:30:17 KST**이며 baseline 호환 core·AFTER 전용 빈 위젯 adapter를 제품 수정 전에 동결했다. [BEFORE 검사](/private/tmp/clipback-notification-alignment-20261018/tests/before-target-alpha-frozen.log)는16건=폰트1통과/C03 부재15목표 실패다. 신규 빈 위젯을 import하는 AFTER adapter를 baseline 실행으로 잘못 사용하지 않는다.
- 제품 수정 전 새 시트 원본은 **iOS18:32:36~18:32:37·Android18:33:51~18:33:52 KST**에 확보했다. 양 플랫폼의 baseline18기록은 동작true/프레임워크 오류0이고 홈 세로16px/최근 rail320px/활성 점1의 기존 왕복 보존을 확인했다. 제품diff0과 출처/해시를 검증한 [18:34:11 KST 게이트](/private/tmp/clipback-notification-alignment-20261018/product-edit-gate.json) 뒤 제품을 적용하고 **18:36:43 KST**에 최종 제품/원본 SHA 일치를 기록했다([제품/원본 일치](/private/tmp/clipback-notification-alignment-20261018/applied-product-source.json)). 없는 빈 BEFORE를 만들지 않았다.
- AFTER [집중25/25](/private/tmp/clipback-notification-alignment-20261018/tests/after-target-final.log)(스타일7+콘텐츠/빈9+이동/보안9·exit0/약5초)를 통과했다. 최종 [전체1412/1412](/private/tmp/clipback-notification-alignment-20261018/tests/flutter-test-final.log)는 **1분24초·실패/건너뜀0·exit0**, [분석](/private/tmp/clipback-notification-alignment-20261018/tests/flutter-analyze-final.log)은 **문제0·3.5초·exit0**이다. 처음 전체1412 통과 후 분석에서 발견한 블록 중괄호 lint2건은 [당시 전체](/private/tmp/clipback-notification-alignment-20261018/tests/flutter-test-pre-lint.log)·[당시 분석](/private/tmp/clipback-notification-alignment-20261018/tests/flutter-analyze-pre-lint.log)으로 보존한다. 중괄호만 보완한 뒤 전체/분석을 다시 실행했으며 새 배율별/3버튼 촬영은 추가하지 않고 기존 확대 자동 검사를 유지했다.
- 첫 AFTER 집중은 **21통과/4실패**로 보존한다([초기 로그](/private/tmp/clipback-notification-alignment-20261018/tests/after-target-initial.log)). Android 빈 위젯의360px 높이가 실제로 스크롤을 필요로 하지 않은 입력2건은300px로 교정했다([입력 기록](/private/tmp/clipback-notification-alignment-20261018/content-unit-input-correction.json)). 다른2건은 상세 왕복 단위 검사만의 GET/contents/601 대역 계약 누락과 semanticsHandle 정리 시점이었다. 단위 파일에만 상세 JSON composition·try/finally를 적용했고 공통 촬영 fixture/제품은 바꾸지 않았다([교정 기록](/private/tmp/clipback-notification-alignment-20261018/navigation-unit-harness-correction.json)). 최초 소스/로그는 `.attempts/after-unit-harness-corrections/`에 보존한다. 사용하지 않은 초기 oracle build-only 시도(exit0)는 별도로 보존하고 알파 그림자 판정 가정을 교정한 뒤 BEFORE를 재빌드·촬영했으며 원본을 변조하지 않았다.

<a id="b-22678e1ff9dc0ee4"></a>

### 비교·후속 경계

<a id="b-cb3d90f5903c321c"></a>

- iPhone16/iOS18.6·Android13/API33 제스처의 AFTER 각28기록은 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0이다([iOS](/private/tmp/clipback-notification-alignment-20261018/ios/after/report.json), [Android](/private/tmp/clipback-notification-alignment-20261018/android/after/report.json)). 회원/게스트의 진입·읽기 전용/요청 없음·홈 위치/점 복귀·설정/중복 차단·기존 목적지·무저장 닫기·세션 무효화 뒤 오래된 복귀/설정 차단·명시적 빈 위젯/복귀·최종 목록 재진입을 확인했다. 운영 알림0 조회 성공으로 보고하지 않는다. 기본 목록/빈 최대 스크롤은0이며 낮은 viewport의 실제 끝24px 접근은 단위 검사와 구분한다.

<a id="b-403490ac2c58e1c6"></a>

| 플랫폼 | 실제 논리창 / DPR / 상·하 안전 여백 | 본문 viewport / 헤더 | 목록 행·문단 / 빈 그룹·이미지 |
| --- | --- | --- | --- |
| iPhone16 / iOS18.6 | 393×852px /3 /59·34px | y123~818px /64px | 343×76px·제목19/시간14px /자연216.216×210px·86×100px |
| Android13 / API33 제스처 | 392.727×783.273px /2.75 /24·0px | y88~783.273px /64px | 343×76px·제목19/시간14px /자연216.216×210px·86×100px |

<a id="b-d73301842b3c63f1"></a>

- 목록은 같은 회원 데이터·1배율·키보드 숨김·스크롤0의 **기존 시트→새 목록→Figma2쌍**으로 비교한다. 빈 위젯은 대응하는 BEFORE가 없어 **BEFORE 없음→명시적 빈 위젯→C03-1**의 신규2건으로 별도 표시하며 총4쌍의 완전 비교라고 세지 않는다. 실제 OS 창/안전 여백·최대375px 프레임·기존 예제 문구/시간과 원본 차이는 보정하지 않는다. [비교 문서](/private/tmp/clipback-notification-alignment-20261018/comparison-document.html)·목록 [iOS](/private/tmp/clipback-notification-alignment-20261018/comparisons/ios-notification-list.png)/[Android](/private/tmp/clipback-notification-alignment-20261018/comparisons/android-notification-list.png)·신규 빈 [iOS](/private/tmp/clipback-notification-alignment-20261018/comparisons/ios-notification-empty.png)/[Android](/private/tmp/clipback-notification-alignment-20261018/comparisons/android-notification-empty.png)에서 실제 원본과 비교한다. [명세](/private/tmp/clipback-notification-alignment-20261018/comparison-manifest.json)는 목록3열2쌍/빈2열2건을 구분한다.
- Android의 [실제 OS Back](/private/tmp/clipback-notification-alignment-20261018/android/after/native-os-back.json)은 홈 복귀·추가 요청 없음이며 iOS의 프레임워크 Pop 검사와 구분한다. [원본 헤더 픽셀](/private/tmp/clipback-notification-alignment-20261018/header-pixel-verification.json)에서 두 원본의 공통 헤더/OS 표시를 확인했다. [빈 이미지 알파](/private/tmp/clipback-notification-alignment-20261018/empty-alpha-pixel-verification.json)는 양 플랫폼 총12개 투명 모서리 샘플의 배경245를 확인해 직사각형 그림자가 생기지 않음을 검사한다.
- AFTER 원본 영상은 [iOS31.323333초](/private/tmp/clipback-notification-alignment-20261018/ios/after/actions.mp4)·[Android52.813544초](/private/tmp/clipback-notification-alignment-20261018/android/after/actions.mp4)이며 [원본 전체 디코딩/녹화](/private/tmp/clipback-notification-alignment-20261018/media-verification.json)·[960px/30fps 재생본](/private/tmp/clipback-notification-alignment-20261018/chat-preview-manifest.json)의 decode exit0을 확인했다. [정확한 시작/끝·2초 간격 시각 검사](/private/tmp/clipback-notification-alignment-20261018/video-frame-review.json)에서 양 영상은 실제 목록으로 시작/종료하며 중간 A01은 독립 대역 앱 초기화 구간이다. 이를 제품의 알림 복귀 때 스플래시가 재생되는 것으로 보고하지 않는다.
- [실제 번들270/270](/private/tmp/clipback-notification-alignment-20261018/bundleverification.json)은 원본 에셋·실제 폰트/등록과 보호 소스를 확인한다. [환경 정리](/private/tmp/clipback-notification-alignment-20261018/cleanup-verification.json)는 소유 iOS/Android·포워딩/ADB 종료·5037/8767/8768/8769 닫힘·제스처2 유지다. 초기 offline 관찰은 시도로 보존하고 최종 해소를 확인했으며 사용자 데이터/설정 변경이나 호스트 비교 HTTP 서버 실행은 없다. [최종 증거 요약](/private/tmp/clipback-notification-alignment-20261018/evidence-summary.json)은 촬영 전후 공통 native import34개의 동일성과 현재 제품9파일의 SHA 일치를 확인한다. 현재 보호 소스279개 중 공유 프리뷰1개에는 촬영 뒤 중괄호 차이가 있어 전체 소스가 모두 같은 것으로 보고하지 않는다. [형식 교정](/private/tmp/clipback-notification-alignment-20261018/post-capture-lint-only-correction.json)은 현재 SHA·원본 역재구성으로 중괄호/공백만의 차이를 검증하며 native 재실행 없이 최종 자동 검사를 다시 수행했음을 명시한다.
- 운영 알림 API/푸시·읽음/삭제·행/상세 목적지·실제 조회 완료0/로딩/오류 상태·리마인드 저장/권한·홈 최초 로딩/스켈레톤·새 확대는 후속이다. 원본 없는 상태는 임의로 디자인하지 않는다. 기존 소개3장의320×480px 아래297px 오류는 이 작업에서도 수정하지 않고 인증/소개 구간만812px, 홈/알림은480px로 구분한다. 메모리 API/세션·처음부터 격리한 공유 채널의 로컬 검증이며 실제 OAuth/운영 서버/실기기/원격CI를 증명하지 않는다. 화면 증거·빌드·AGENTS.md를 제외하고 푸시/PR은 하지 않는다.
