# 로그인 권한 안내

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-494bbfefab70adc4"></a>

직전 `e2ea948` 기준 작업은 **B01 로그인 권한 안내 시트의 승인된1배율 표현과 일반 로그인 선택 연결**입니다. 일반 로그인에서 처음 누른 소셜/게스트 동작은 안내 확인 뒤 실행하고, **실제 OS 권한은 요청하지 않습니다.** 계속하기 확인은 같은 로그인 진입에서 SDK 취소/오류·다른 공급자 재시도에도 유지하며, 안내 취소는 확인으로 처리하지 않고 새 로그인 진입/앱 재실행에는 다시 표시합니다. 기존 계정 연결·공급자 없는 표현과 인증/세션·공유 보안 정책은 유지합니다. 당시 **BEFORE4목표 실패·최종 v2양 플랫폼 각3기록/오류0, AFTER 집중20/전체1432·분석0·각17기록/전체true·오류0·새 비교2건/영상2개·번들273/273·환경 정리**를 확인했으며 이번 하단 탭 결과로 재사용하지 않습니다.

<a id="b-5722b897db7b8e73"></a>

### 로그인 권한 안내 시트의 1배율 맞춤 — 2026-10-18 작업

<a id="b-59fa3d0991643b5b"></a>

> `e2ea948` 기준 B01 `111:3478`의 로그인 위 안내와 승인한 반복/인증 연결 정책을 적용했다. **최종 집중20/전체1432·분석0, 양 플랫폼 각17기록/전체true·오류0·새 비교2건/영상2개·번들273/273·환경 정리**를 확인했다. 실제 OS 권한 허용·인증 전체 기능 완료를 뜻하지 않는다.

<a id="b-04bf37183a629541"></a>

### 기준과 적용 경계

<a id="b-65f3b8699db66f90"></a>

- Page 1 >261007의 [B01 사진·알림 권한 안내 `111:3478`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3478)의 계획 조회 **2026-10-18 18:55 KST**와 구현 조회 **19:02:49~19:02:54 KST /10:02:49~10:02:54 UTC**를 구분한다. 구현 직전에 `get_design_context`1회로375×812px 원본·컨텍스트를 함께 확보했다([조회 기록](/private/tmp/clipback-permission-guide-alignment-20261018/figma/reference-manifest.json)). 이전 파일/화면으로 대체하지 않는다.
- 로그인 전용 [PermissionGuideSheet](../../frontend/lib/features/auth/permission_guide_sheet.dart)는 `onContinue`를 받는 새 위젯이다. 흰 시트·최대375px·위 모서리16px, 딤 검정50%·블러2px을 배리어에서 각각 한 번 적용한다. 핸들50×5px/상8px, 좌우24px·본문상60px·제목 영역 최소135px·권한 행 시작 간격 최소80px, 아이콘42px/글자 앞8px을 사용한다. 제목18px/Bold/1.6·설명14px/Medium/1.5·권한명16px/SemiBold/AUTO·선택16px/Regular/AUTO는 실제 Pretendard와 기존 Bold 별칭 `PretendardDetail`을 명시한다.
- 기본 높이는460px+실제 하단 `viewPadding`이며 실제 상단 안전 영역 아래 가용 높이로 제한한다. 본문만 스크롤하고48px 계속하기를 분리해 아래32px+실제 OS 하단 여백을 한 번 확보한다. 낮은 화면은 자연 높이/스크롤을 사용하며 글자를 축소하지 않는다. 바깥 탭·핸들 드래그·OS 뒤로가기는 취소이고 새 닫기/로딩 디자인·가짜 OS 표시는 추가하지 않는다.
- [원본 에셋 대조](/private/tmp/clipback-permission-guide-alignment-20261018/figma/asset-source-audit.json)는 새1254×1254 PNG2개 `permission-b01-notification.png`/`permission-b01-photo.png`와 배경 로그인의 공급자/구분선 재사용을 구분한다. 배경 로고 SVG는 생성된 filter ID/참조/result 심볼명만 다르고 일관된 식별자 정규화 뒤 도형/치수가 같으므로 기존 A02를 유지한다. 원본 byte 동일이라고 보고하거나 공유 로고를 덮어쓰지 않는다. 전체 화면 이미지를 구현 에셋으로 사용하지 않는다.
- [루트 연결](../../frontend/lib/app/clipback_app.dart)은 일반 로그인 `!linkingGuest && onBack==null && providers.isNotEmpty`의 기존 콜백을 내부 래퍼로 감싼다. `LoginScreen`·`AppRoute`·인증 ViewModel/API/Repository/모델의 공개 계약은 바꾸지 않는다. 누른 동작을 캡처하고 동기 단일 실행 잠금을 잡으며, 계속하기 뒤 안내 route가 완전히 제거된 다음 최신 mounted/현재route·지원 공급자·generation/epoch·busy/복구/오류/pending clear를 다시 검사해 해당 동작만 한 번 실행한다.
- 안내 중에는 `authBusy`를 바꾸지 않으며 실제 인증부터 기존 스피너/잠금·SDK 취소/오류/수동 재시도를 따른다. 같은 로그인 진입의 확인은 재빌드·busy·인증 시도마다 증가하는 `authEpoch`로 초기화하지 않는다. 로그인 종료·계정 generation 변경·연결/복구/세션 삭제·앱 종료는 확인을 초기화한다. 안내 취소 후 재선택에는 다시 표시하고 영속 저장은 추가하지 않는다.
- app/session 양쪽 변경에서 대기 선택을 무효화하고 **이 안내의 route identity만** 제거한다. 다른 모달을 임의로 닫거나 늦은 승인을 실행하지 않는다. 계정 연결·공급자 없는 로그인, 신규 인증의 기존 소개3장→관심사·기존 회원 홈·발급 후 조회 실패의 복구와 공유 보안을 유지한다.

<a id="b-b60bb187fd90802f"></a>

### 검사·화면 증거

<a id="b-b600d1a00dd5909b"></a>

- 초기 촬영 공통 소스는 **19:12:46 KST**에 [동결](/private/tmp/clipback-permission-guide-alignment-20261018/.attempts/first-frozen-tools/preview-source-freeze.json)했고 [BEFORE 스타일 검사](/private/tmp/clipback-permission-guide-alignment-20261018/tests/before-target-final.log)는4건 모두 기존 B01 부재의 목표 실패다. [초기 iOS BEFORE](/private/tmp/clipback-permission-guide-alignment-20261018/.attempts/first-frozen-tools/ios/before/report.json)·[초기 Android BEFORE](/private/tmp/clipback-permission-guide-alignment-20261018/.attempts/first-frozen-tools/android/before/report.json)는 각3기록의 기존 선택 즉시 인증·새 안내 부재를 확인하며 동작true/프레임워크 오류0이다. 새 B01의 스타일/레이아웃/에셋/전체는false인 것을 목표 차이로 보존한다.
- 기준 제품diff0·새 플랫폼 원본·소스해시를 확인한 [초기19:15:36 KST 게이트](/private/tmp/clipback-permission-guide-alignment-20261018/.attempts/first-frozen-tools/product-edit-gate.json) 뒤 **19:15:59 KST**에 제품4파일을 적용했다([초기 적용/원본 SHA](/private/tmp/clipback-permission-guide-alignment-20261018/.attempts/first-frozen-tools/applied-product-source.json)). 신규 안내에 대응하는 BEFORE 시트를 생성하지 않고 기존 로그인 원본을 사용한다. 원본 PNG2개의 bytes 그대로 등록했으며 초기 에셋 대조의 미등록 상태와 실제 등록/빌드 증거를 구분한다.
- 제품 수정 전 기존 인증 helper를 baseline 호환 runtime 탐색으로 보완했다. 완료를 기다리는 인증은 callback Future를 먼저 보관→B01 실제 계속하기 탭→기존 completion을 기다린다. HTTP/SDK 대기·취소/중복 검사는 자동 승인하지 않고 원본 Future를 호출자가 통제한다. 기존 login/interest/safe-area 네이티브 프리뷰도 실제 확인 단계를 거치되 BEFORE에는 시트가 없으면 아무 동작을 추가하지 않는다.
- 기준 제품에서 기존 인증 관련5개 파일의 **167/167건 통과**를 확인했다([BEFORE 기존 회귀](/private/tmp/clipback-permission-guide-alignment-20261018/tests/before-auth-regression.log)). 제어 helper·프리뷰와 새 탐색 검사10파일의 정적 분석은 **문제0**이다([BEFORE 분석](/private/tmp/clipback-permission-guide-alignment-20261018/tests/before-helper-analysis.log)). 이 결과를 AFTER 전체 검사나 양 플랫폼 실행 성공으로 재사용하지 않는다.
- [초기 native 시도](/private/tmp/clipback-permission-guide-alignment-20261018/.attempts/after-animated-barrier-oracle/attempt-record.json)의 iOS17기록은 동작true/프레임워크 오류0이지만 guest 안내 checkpoint에서 진입 애니메이션의 검정 alpha127/255를 목표128/255와 비교해 에셋 판정1건이 실패했다. 초기 정적 화면/제품 스타일은 통과했으나 이를 전체 실행 성공으로 보고하지 않는다. 실제 route animation 완료를 기다리도록 **프리뷰 관측 시점만** 보완하고, 제품4파일을 byte 보존→기준 `e2ea948` 제품으로 일시 복원→새 도구 동결/양 플랫폼 BEFORE 재촬영/새 게이트→동일 제품 bytes 복원→AFTER 재실행한다. [초기 동결/양 플랫폼 근거](/private/tmp/clipback-permission-guide-alignment-20261018/.attempts/first-frozen-tools/attempt-record.json)는 최종 증거로 사용하지 않는다.
- 최종 도구는 실제 시트 진입 animation 완료를 대기하는 관측 보완 뒤 **19:24:01 KST**에 [v2로 재동결](/private/tmp/clipback-permission-guide-alignment-20261018/preview-source-freeze.json)했다. 같은 기준 제품에서 **iOS19:26:22~19:26:23·Android19:26:46~19:26:47 KST**의 새 BEFORE를 다시 확보했고 각각 기존 동작3기록/오류0이다([최종 iOS BEFORE](/private/tmp/clipback-permission-guide-alignment-20261018/ios/before/report.json), [최종 Android BEFORE](/private/tmp/clipback-permission-guide-alignment-20261018/android/before/report.json)). [19:27:04 KST v2게이트](/private/tmp/clipback-permission-guide-alignment-20261018/product-edit-gate-v2.json)의262항목 통과 뒤 **19:27:31 KST**에 [최종 제품4파일](/private/tmp/clipback-permission-guide-alignment-20261018/final-product-restore.json)을 초기 구현과 같은SHA/bytes로 복원했다. 도구 교정을 위한 제품 변경은0이며 새 BEFORE와 같은 v2도구로 AFTER를 실행했다.
- 더 앞선 [첫 프레임 전 하네스 시도](/private/tmp/clipback-permission-guide-alignment-20261018/.attempts/initial-pre-first-frame-harness/attempt-record.json)는 `runApp` 첫 프레임 전 capture context 조회로 멈췄다. 양 플랫폼 빌드는exit0였고 비교용 native capture0/별도 진단 스크린샷1이며, context 준비/구문 lint를 교정한 뒤 재동결/재빌드했다. 제품 baseline을 바꾸거나 실패 시도를 삭제하지 않는다.
- 최초 AFTER 집중20건은 **19통과/1실패**였다([최초 로그](/private/tmp/clipback-permission-guide-alignment-20261018/tests/after-target-initial.log)). 첫 SDK 경계 검사는 `authenticate`가 실제 호출을 기록하기 전에 callback 안에서 assertion을 던지는 구조였다. 앱의 기존 인증 오류 처리가 이를 잡으면 실제 실패가 SDK 목록 `[]`로 가려질 수 있다. 최초 어느 predicate가 실패했는지는 기록되지 않아 구체적인 완료 콜백 순서가 원인이라고 확정하지 않는다.
- [단일 진단1/1](/private/tmp/clipback-permission-guide-alignment-20261018/tests/after-sdk-boundary-observation.log)에서는 SDK 순간 route inactive/current false·overlay2개 unmounted·B01 element0을 관측했다. 관측용 `.completed` 플래그 대신 실제 route/overlay/위젯 관측값만 수집하고 원 인증 Future 완료 뒤 판정하도록 **AFTER 단위 검사만** 보완했다([교정/원본 SHA](/private/tmp/clipback-permission-guide-alignment-20261018/navigation-unit-boundary-correction.json)). 최초 소스/로그는 `.attempts/sdk-boundary-unit-observation/`에 보존하며 제품·동결한 native 촬영 의존 소스는 바꾸지 않았다.
- 새 탐색 검사는 실제 루트·기존 메모리 API/세션·최초 실행부터 공유 격리를 사용한다. 안내 전 SDK/guest 요청0·계속 후1회·route.completed 뒤 SDK 시작, 배리어/드래그/OS 취소·재표시, 같은 진입의 SDK 취소/API 실패 후 공급자 변경 재시도, 안내/SDK 중 중복 차단, 로그아웃/앱 재실행 뒤 재표시, 연결/공급자 없음 제외, 종료 후 늦은 승인과 route 무효화 시 다른 모달 보존을 검증한다. 스타일 검사는 실제 폰트·iOS/Android×320/375px×1배율의 글자·크롭·간격·배리어·하단 여백과 낮은 화면의 마지막 안내 접근을 별도로 판정한다.
- [최종 AFTER 집중20/20](/private/tmp/clipback-permission-guide-alignment-20261018/tests/after-target-final.log)은 스타일4·낮은 viewport2·실제 루트 이동/인증 경계14건이며 **3초/exit0**이다. 수정 영역의 원본 글자/크롭·자연 높이/본문 스크롤·footer/안전 여백과 승인·취소/재시도/단일 실행·route 제거·보안 경계를 실제 판정했다. [최종 전체1432/1432](/private/tmp/clipback-permission-guide-alignment-20261018/tests/flutter-test-final.log)는 **2분28초/exit0**이며 기존 인증/세션·공유·관심사/계정·안전 영역·확대 회귀를 포함한다. [최종 분석](/private/tmp/clipback-permission-guide-alignment-20261018/tests/flutter-analyze-final.log)은 **문제0/3.8초/exit0**, [포맷](/private/tmp/clipback-permission-guide-alignment-20261018/tests/dart-format-final.log)은 **16파일/변경0/0.34초**다. 최종 양 플랫폼 실행·새 비교/영상·번들/정리는 아래 실제 근거를 따른다. iPhone16/iOS18.6·Android13/API33 제스처, 같은 데이터/1배율·키보드 숨김·스크롤0을 사용하며 기존 로그인→새 B01→Figma의2건으로 전달한다. 직접 대응하는 기존 B01 시트가 없으므로 가짜 BEFORE를 만들지 않는다.
- 최종 [iOS AFTER](/private/tmp/clipback-permission-guide-alignment-20261018/ios/after/report.json)·[Android AFTER](/private/tmp/clipback-permission-guide-alignment-20261018/android/after/report.json)는 각각17기록의 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0이다. 실제 선택 전 요청0·안내 승인/취소·SDK 단일 실행/취소·같은 진입의 다른 공급자/실패 재시도·새 진입의 재표시·게스트 발급/기존 목적지와 최종 B01 복귀를 확인한다. 양 플랫폼 OS 포함 PNG를 직접 열어 제목·권한 두 행·계속하기의 의도하지 않은 잘림/겹침이 없음을 확인했다. 기본 최대 스크롤0은 무스크롤로 기록하며 낮은 viewport의 실제 마지막 안내 접근은 별도 자동 검사와 구분한다.

<a id="b-6056bfc6be662617"></a>

| 플랫폼 | 논리창 / DPR / 상·하 안전 여백 | 시트 경계 / 본문 viewport | 계속하기 / 버튼 아래 여백 | 최대 스크롤 |
| --- | --- | --- | --- | --- |
| iPhone16 /iOS18.6 | 393×852px /3 /59·34px | 375×494px·top358px /380px | 327×48px·top738px /32+34px | 0px |
| Android13 /API33 제스처 | 392.727×783.273px /2.75 /24·0px | 375×460px·top323.273px /380px | 327×48px·top703.273px /32+0px | 0px |

<a id="b-b95ef3df9fafc5ae"></a>

- [Android 실제 OS Back](/private/tmp/clipback-permission-guide-alignment-20261018/android/after/native-os-back.json)은 `adb shell input keyevent 4`로 안내를 닫고 요청 증가0·SDK/guest/social 발급0·전체true를 확인했다. 공통/iOS의 프레임워크 Pop 전달 검사와 구분한다. [실제 iOS/APK 번들273/273](/private/tmp/clipback-permission-guide-alignment-20261018/bundleverification.json)은 원본 PNG·실제 폰트/등록·보호 소스의 일치를 확인한다. [원본 시각 검토](/private/tmp/clipback-permission-guide-alignment-20261018/root-static-visual-review.json)는 실제 OS 포함 AFTER 두 장과 정확한 B01 원본을 보정 없이 대조한 근거다.
- [새 비교 문서](/private/tmp/clipback-permission-guide-alignment-20261018/comparison-document.html)·[비교 명세](/private/tmp/clipback-permission-guide-alignment-20261018/comparison-manifest.json)는 **기존 일반 로그인→새 B01→정확한 Figma의3열2건**이다([iOS](/private/tmp/clipback-permission-guide-alignment-20261018/comparisons/ios-permission-guide.png), [Android](/private/tmp/clipback-permission-guide-alignment-20261018/comparisons/android-permission-guide.png)). 기존 B01 자체의 BEFORE는 없으므로 같은 기존 시트의 완전한 전후2쌍으로 세지 않는다. 같은 플랫폼/고정 데이터/1배율·키보드 숨김·스크롤0을 사용하며 실제 OS 창·안전 여백을 보정하지 않는다. HTML 로컬38링크도 확인했다.
- AFTER 원본 영상 [iOS17.375초](/private/tmp/clipback-permission-guide-alignment-20261018/ios/after/actions.mp4)·[Android69.068689초](/private/tmp/clipback-permission-guide-alignment-20261018/android/after/actions.mp4)의 [전체 디코딩/녹화](/private/tmp/clipback-permission-guide-alignment-20261018/media-verification.json)는exit0이다. [채팅용 재생본](/private/tmp/clipback-permission-guide-alignment-20261018/chat-preview-manifest.json)은960px 높이/30fps 표시용이며 원본을 보존한다([iOS 재생본](/private/tmp/clipback-permission-guide-alignment-20261018/ios/after/actions-preview.mp4), [Android 재생본](/private/tmp/clipback-permission-guide-alignment-20261018/android/after/actions-preview.mp4)). [시작/중간/끝](/private/tmp/clipback-permission-guide-alignment-20261018/video-frame-review.json)·[2초 간격](/private/tmp/clipback-permission-guide-alignment-20261018/video-interval-review.json) 시각 검토도 통과했다. 실제 iOS 시작은A01/종료는B01이며 Android는B01/B01이다.
- 영상 중 독립 대역 시나리오를 초기화하는 `_fresh`는 기존 root를 `SizedBox.shrink`로 내린 뒤2개 painted frame을 기다리고 새 ClipbackApp을 만든다. 이때의 짧은 검정·뒤따르는A01은 제품의 안내 취소/복귀 때 발생하는 것으로 보고하지 않는다. [iOS 두 구간](/private/tmp/clipback-permission-guide-alignment-20261018/ios-reset-frame-verification.json)의0.133초/0.148초와 [Android 다섯 reset](/private/tmp/clipback-permission-guide-alignment-20261018/android-reset-frame-verification.json)은 실제 직전/직후 프레임·소스와 대조했고 원본 영상을 변경하지 않았다. 영상 전체에 검정 프레임이 없다고 보고하지 않는다.
- [환경 정리](/private/tmp/clipback-permission-guide-alignment-20261018/cleanup-verification.json)는 소유 iPhone16/API33·포워딩/태스크 시작 ADB 정리와 앱 driver 포트 종료·제스처 탐색2 유지·사용자 데이터 삭제/설정 변경 없음을 확인한다. [최종 증거 요약](/private/tmp/clipback-permission-guide-alignment-20261018/evidence-summary.json)은 보호 소스257개 drift0·공통 native import9개 BEFORE/AFTER 일치·현재 제품/도구의 SHA 일치와 모든 최종 증거의 통과를 기록한다. 호스트 비교 HTTP 서버를 새로 유지하지 않는다.
- [최종 검증 집계](/private/tmp/clipback-permission-guide-alignment-20261018/validation-summary.json)의21개 검사는 전체/집중·분석/포맷·양 플랫폼/원본/미디어·현재 소스/에셋·환경 정리·변경 범위와 AGENTS 비추적을 함께 확인하며 전체true다.
- 약관 보류·Android Apple 미노출/뒤따르는 흐름의60px 차이와 실제 OS 여백은 기존 사용자 승인 예외로 구분한다. 실제 OS 권한 요청/상태 조회·거절/설정 이동, 기존 소개3장 원본·약관·새 확대 맞춤은 후속이다. 메모리 대역을 실제 OAuth/운영 서버/실기기/원격CI의 성공으로 보고하지 않으며 기존 확대 자동 검사는 유지한다. 화면 증거·빌드·AGENTS.md는 Git 밖에 두고 푸시/PR은 하지 않는다.

<a id="b-687718685378a7df"></a>

프리뷰는 실제 ClipbackApp·메모리 인증/API와 최초 실행부터 격리한 공유 채널을 사용한다. BEFORE는 기준 `e2ea948` 제품에서, AFTER는 수정 제품에서 빌드하며 phase 플래그만 바꿔 이전 화면을 대신하지 않는다.

<a id="b-bc89f02da26b265a"></a>

```bash
# frontend/ — 관련 검사와 전체/분석을 별도로 수행한다.
flutter test --no-pub test/permission_guide_figma_test.dart test/permission_guide_content_test.dart test/permission_guide_navigation_test.dart
flutter test --no-pub
flutter analyze --no-pub

# 실제 기준 제품에서 before, 수정 제품에서 after로 빌드한다.
flutter run --no-pub -t test/support/permission_guide_alignment_preview.dart --dart-define=PERMISSION_GUIDE_PHASE=before -d <device-id>
flutter run --no-pub -t test/support/permission_guide_alignment_preview.dart --dart-define=PERMISSION_GUIDE_PHASE=after -d <device-id>
```

<a id="b-f0abb0eaea5de7f7"></a>

`/scene`은 새 root의 일반 로그인에서 실제 카카오 선택으로 B01을 열고, BEFORE에는 안내 없는 기존 로그인 원본을 기록한다. `/max-scroll`은 본문 끝, `/run`은 승인·취소/재표시·SDK/guest 잠금/재시도·새 진입을 검사하며 `/status`는 현재 상태를 읽는다. 실제 스타일·레이아웃·에셋·동작과 최초 실행부터 격리한 공유 prompt 상태를 전체 판정에 연결한다. 운영 권한/OAuth 성공 증거로 사용하지 않는다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-05186547697a6826"></a>

- Page 1 >261007의 [B01 사진·알림 권한 안내 `111:3478`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3478)의 계획 조회 **2026-10-18 18:55 KST**와 구현 조회 **19:02:49~19:02:54 KST /10:02:49~10:02:54 UTC**를 구분한다. 구현 직전에 `get_design_context`1회로375×812px 원본·컨텍스트를 함께 확보했다([조회 기록](/private/tmp/clipback-permission-guide-alignment-20261018/figma/reference-manifest.json)). 이전 파일/화면으로 대체하지 않는다.
- 로그인 전용 [PermissionGuideSheet](../../frontend/lib/features/auth/permission_guide_sheet.dart)는 `onContinue`를 받는 새 위젯이다. 흰 시트·최대375px·위 모서리16px, 딤 검정50%·블러2px을 배리어에서 각각 한 번 적용한다. 핸들50×5px/상8px, 좌우24px·본문상60px·제목 영역 최소135px·권한 행 시작 간격 최소80px, 아이콘42px/글자 앞8px을 사용한다. 제목18px/Bold/1.6·설명14px/Medium/1.5·권한명16px/SemiBold/AUTO·선택16px/Regular/AUTO는 실제 Pretendard와 기존 Bold 별칭 `PretendardDetail`을 명시한다.
- 기본 높이는460px+실제 하단 `viewPadding`이며 실제 상단 안전 영역 아래 가용 높이로 제한한다. 본문만 스크롤하고48px 계속하기를 분리해 아래32px+실제 OS 하단 여백을 한 번 확보한다. 낮은 화면은 자연 높이/스크롤을 사용하며 글자를 축소하지 않는다. 바깥 탭·핸들 드래그·OS 뒤로가기는 취소이고 새 닫기/로딩 디자인·가짜 OS 표시는 추가하지 않는다.
- [원본 에셋 대조](/private/tmp/clipback-permission-guide-alignment-20261018/figma/asset-source-audit.json)는 새1254×1254 PNG2개 `permission-b01-notification.png`/`permission-b01-photo.png`와 배경 로그인의 공급자/구분선 재사용을 구분한다. 배경 로고 SVG는 생성된 filter ID/참조/result 심볼명만 다르고 일관된 식별자 정규화 뒤 도형/치수가 같으므로 기존 A02를 유지한다. 원본 byte 동일이라고 보고하거나 공유 로고를 덮어쓰지 않는다. 전체 화면 이미지를 구현 에셋으로 사용하지 않는다.
- [루트 연결](../../frontend/lib/app/clipback_app.dart)은 일반 로그인 `!linkingGuest && onBack==null && providers.isNotEmpty`의 기존 콜백을 내부 래퍼로 감싼다. `LoginScreen`·`AppRoute`·인증 ViewModel/API/Repository/모델의 공개 계약은 바꾸지 않는다. 누른 동작을 캡처하고 동기 단일 실행 잠금을 잡으며, 계속하기 뒤 안내 route가 완전히 제거된 다음 최신 mounted/현재route·지원 공급자·generation/epoch·busy/복구/오류/pending clear를 다시 검사해 해당 동작만 한 번 실행한다.
- 안내 중에는 `authBusy`를 바꾸지 않으며 실제 인증부터 기존 스피너/잠금·SDK 취소/오류/수동 재시도를 따른다. 같은 로그인 진입의 확인은 재빌드·busy·인증 시도마다 증가하는 `authEpoch`로 초기화하지 않는다. 로그인 종료·계정 generation 변경·연결/복구/세션 삭제·앱 종료는 확인을 초기화한다. 안내 취소 후 재선택에는 다시 표시하고 영속 저장은 추가하지 않는다.
- app/session 양쪽 변경에서 대기 선택을 무효화하고 **이 안내의 route identity만** 제거한다. 다른 모달을 임의로 닫거나 늦은 승인을 실행하지 않는다. 계정 연결·공급자 없는 로그인, 신규 인증의 기존 소개3장→관심사·기존 회원 홈·발급 후 조회 실패의 복구와 공유 보안을 유지한다.
