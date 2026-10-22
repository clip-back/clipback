# 스플래시와 시작 흐름

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-b861334a26998d1f"></a>

앞선 `af93402` 기준 작업은 **A01 스플래시의1배율 표현·900ms 실제 시작 흐름과 네이티브 시작 리소스 맞춤**입니다. 신규24/전체1326·분석0, 양 플랫폼 Flutter/루트 각11시나리오·전체true/오류0을 확인했습니다. iOS 네이티브의 완전 불투명 로고/정적 색상은 미검증·부분 비교이며 아래 A01 기록에서 구분합니다. 소개3장·기존 인증/콘텐츠 보존 정책과1배율 우선 기준은 유지합니다.

<a id="b-a27213e83d9876db"></a>

### 스플래시의 1배율 표현과 실제 앱 시작 흐름 — 2026-10-18 작업

<a id="b-d4a36fe11a93e076"></a>

> `af93402` 기준 A01의 승인된 Flutter 표현·900ms 시작 흐름과 네이티브 시작 리소스를 적용했다. 신규24건·전체1326건·분석0을 확인했다. Flutter 양 플랫폼 판정은 통과했으며, **iOS 네이티브 시작 단계의 완전 불투명 로고·정적 색상은 미검증**이다. 네이티브 번들 검사나 Flutter 화면 통과를 해당 시각 검증으로 대신하지 않는다.

<a id="b-c5fd2c3c33787d69"></a>

### 적용 범위와 원본

<a id="b-a8a1724f80e4da2c"></a>

- 기준은 Page 1 > `261007`의 [A01 `111:3380`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3380)이다. 계획 조회 **2026-10-18 12:45:22~12:45:26 KST**와 구현 직전 **13:03:00~13:03:05 KST / 04:03:00~04:03:05 UTC**의 컨텍스트·375×812px 원본 확보를 구분한다([조회 기록](/private/tmp/clipback-splash-alignment-20261018/figma/context.json)). 호출 제한·다른 파일의 대체 원본은 없었다.
- **13:04:00 KST**에 원본 그룹 `111:3384`만 PNG 1×/2×/3×로, 로고 `111:3385`만 4× PNG로 읽기 전용 내보내기를 했다([내보내기](/private/tmp/clipback-splash-alignment-20261018/figma/native-exports.json)). Flutter는 별도 원본 SVG를 사용한다. 전체 화면 스크린샷·가짜 상태바/OS 표시를 구현 에셋으로 사용하지 않았다.
- **Flutter:** 창 전체 `#FFD75C`·실제 SafeArea 한 번·콘텐츠 최대375px이다. 원본 흰 반짝임 로고148.771×50px, 뒤16px과 실제 Ria Sans Regular16px/자간0/`#C5A544`/AUTO 태그라인으로 자연 그룹232×89px을 구성했다. 그룹 중심은 안전 영역 중앙−23.5px·가로 중앙+0.5px이며393px 창의 바깥 회색 여백도 제거했다. 글자/전체 화면을 축소하지 않고 낮은 viewport는 스크롤한다. 전환 중 가용 폭0에서 음수 폭이 생긴 재현은 폭0으로 제한해 수정하고 별도 회귀를 추가했다.
- **폰트 격리:** 기존 공식 OTF535,616bytes·SHA256 `d211588444df94fe17e7ada6f5c96ef03d83a8f657785e710c5c7f3e58ba0eaf`를 그대로 재사용하고 `RiaSansSplash`400 별칭만 추가했다. `RiaSansLogin`·기존 미등록 `RiaSans`/공유 `EntryTagline`·로그인·소개 화면은 유지한다. [실제 iOS/APK 폰트 번들9항목](/private/tmp/clipback-splash-alignment-20261018/font-final-bundle.json)이 통과했으며 단순 스타일 이름을 실제 폰트 포함 증거로 사용하지 않는다.
- **네이티브:** iOS는 `SplashA01Brand`의 원본 그룹 PNG232×89/464×178/696×267px을 노란 LaunchScreen의 같은 안전 영역 위치에 둔다. Android는 주간/야간·API31+ 테마를 분리하고 소개 문구 없이 원본 로고를 표시한다. Android12+의 OS 마스킹 안에 전체 로고가 들어가도록 4× 원본596×200px을 리사이즈/재색칠하지 않고 투명1152×1152px(288dp) 중앙 `(278,476)`에 넣었다([안전 캔버스](/private/tmp/clipback-splash-alignment-20261018/native-android-padded-icon.json)). Android12 미만은 노란 배경·중앙 로고 리소스이며 실행 환경이 없어 정적/빌드 호환성만 확인했다. 앱 아이콘·공유 Activity/테마·네이티브 전체 화면 설정·OS 애니메이션과 기존 인증 계약은 바꾸지 않았다.

<a id="b-e5c5acedb43aa574"></a>

### 시작 흐름·자동 검증

<a id="b-f18c884a3fa1c490"></a>

- 최초 Flutter A01 생성부터900ms 동안 기존 세션 복구·API 조회를 병렬 실행한다. 루트는 `showing → mounting → ready` 순서로 진행하고,900ms 뒤 당시 복구 결과의 로그인·홈 또는 기존 `SessionRestoreScreen` 로딩/오류·재시도로 연결한다. 네트워크 완료까지 스플래시를 연장하거나 홈으로 강제 이동하지 않는다. OS 시작 화면의 표시 시간과900ms는 합산 제어하지 않는다.
- 후속 화면의 첫 프레임 뒤 공유 준비·`PendingSharePrompt`·대기 UI 효과·최신 저장 실패 배너를 재개한다. `AppDependencies.canPrepareSharing`은 선택적 내부 콜백이며 기본true를 기존 조건과 AND한다. 큐·효과를 삭제하지 않고 보안 차단·세션 무효화·Apple credential 확인은 지연하지 않는다. 로그아웃·앱 복귀·재빌드에 시작 단계를 재생하지 않는다. 공개 `ClipbackApp`/`SplashScreen` 생성자·콜백·API/모델은 유지한다.
- 제품 수정 전 새 비교 도구/데이터를 동결하고 실제 기준 앱에서 목표 검사 **19건 중2통과/17실패**를 재현했다([BEFORE 검사](/private/tmp/clipback-splash-alignment-20261018/tests/before-target-tests.log)). 기존 실제 시작에는 A01이 연결되지 않았으므로 독립 A01 위젯 촬영과 실제 앱 시작 영상을 구분했다. 두 촬영 프리뷰 소스의 동결 해시는 BEFORE/AFTER 빌드 기록에서 유지한다.
- 신규 **레이아웃10·실제 시작11·공유3 =24건**, 전체 `flutter test --no-pub` **1326/1326**, `flutter analyze --no-pub` **문제0/exit0**을 확인했다([최종 전체](/private/tmp/clipback-splash-alignment-20261018/tests/final-full-test.log)·[최종 분석](/private/tmp/clipback-splash-alignment-20261018/tests/final-analyze.log)). 기존 인증/세션·공유·영속 저장·확대 검사를 삭제하거나 건너뛰지 않았다.
- 실제 폰트·iOS/Android 테마×320/375px×1배율과393px/낮은/폭0 viewport를 검사한다. 시작 검사는899/900ms·복구 선행·빠른/느린 복구·오류/재시도·만료·Apple 철회 확인·저장 실패 배너·중복/재빌드/복귀/종료를 포함한다.899ms에 공유 안내가 없고900ms 첫 후속 프레임에도 없으며 다음 프레임에 나타나는 경계를 확인했다.
- UI 효과 검사는 세션 없음 복구에서 실제 발생한 **`CloseTransientRoutesEffect`**를 투명 테스트 경로로 관찰한다. 해당 경로가899ms까지 남고 후속 첫 프레임 뒤 한 번만 닫히며, 이후 새 경로는 재빌드/복귀에도 닫히지 않는지 확인했다. 임의 효과를 주입하거나 일반 Apple 철회가 `MessageEffect`를 발생시켰다고 보고하지 않는다. 공유 검사는 시작 중 큐 조회/준비 없음·해제 뒤 한 번 준비·ACK/삭제 없음·기본 콜백 호환성과 보안 차단/세션 삭제의 즉시 실행을 확인했다.

<a id="b-ab3b0d4bdf0106fb"></a>

### 양 플랫폼 실행·비교와 한계

<a id="b-d77b2389e19a2a02"></a>

| 플랫폼 | 실제 논리창 / DPR / 상·하 안전 여백 | Flutter 그룹 / top / 로고–문구 간격 | 실제 루트 결과 |
| --- | --- | --- | --- |
| iPhone16 / iOS18.6 | 393×852px /3 /59·34px | 232×89px /370.5px /16px | 11시나리오·스타일/레이아웃/에셋/동작/전체true·오류0 |
| Android13 / API33 제스처 | 392.727×783.273px /2.75 /24·0px | 232×89px /335.636px /16px | 11시나리오·스타일/레이아웃/에셋/동작/전체true·오류0 |

<a id="b-b306b56d183cab8d"></a>

- 원본과 결과는 Git 밖의 [비교 문서](/private/tmp/clipback-splash-alignment-20261018/comparison-document.html), [Flutter 개요](/private/tmp/clipback-splash-alignment-20261018/comparisons/flutter-overview.png), [네이티브 개요](/private/tmp/clipback-splash-alignment-20261018/comparisons/native-overview.png)에서 구분한다. 비교4건 중 Flutter2쌍과 Android 네이티브1쌍은 완전 비교이고, **iOS 네이티브1건은 짧은 희미한 실제 전환 프레임만 확보한 부분 비교다.** `nativeTransitionOnly: true`·`fullyOpaqueStaticColorVerified: false`로 구분하며 완전한 정적 브랜드 색상/불투명 표시 성공으로 집계하지 않는다. 원본이 없는 구간을 Flutter 화면이나 대체 이미지로 채우지 않았다. Android의 로고 전용 OS 위치·마스킹과 실제 OS 창/안전 영역은 승인 예외이고 Figma375×812 원본을 기기 크기에 강제하거나 원본을 보정하지 않는다.
- 시작 영상은 [iOS BEFORE](/private/tmp/clipback-splash-alignment-20261018/ios/before/startup.mp4)·[iOS AFTER](/private/tmp/clipback-splash-alignment-20261018/ios/after/startup.mp4)·[Android BEFORE](/private/tmp/clipback-splash-alignment-20261018/android/before/startup.mp4)·[Android AFTER](/private/tmp/clipback-splash-alignment-20261018/android/after/startup.mp4)의4개다. 원본 콜드 스타트의 OS→Flutter→후속 화면을 기록하며 별도 네이티브 대기나 가짜 화면을 추가하지 않았다. 원본 전체 디코딩과 선택 프레임 검사는 [미디어 검사](/private/tmp/clipback-splash-alignment-20261018/media-verification.json)의 실제 완료 항목을 따른다. 영상 디코딩 성공을 iOS 정적 색상/불투명 표시 검증으로 확대하지 않는다.
- 각 AFTER 보고서([iOS](/private/tmp/clipback-splash-alignment-20261018/ios/after/report.json)·[Android](/private/tmp/clipback-splash-alignment-20261018/android/after/report.json))의11시나리오는 빠른 빈 세션→로그인·기존 세션→홈, 느린 복구→기존 복구→홈, 저장소 오류→재시도→로그인, 복귀 시 재생 없음과 독립 타이머1회를 확인한다. 처음부터 네이티브 공유를 격리했고 실제 공유 채널 위임0·미지원 메서드0·운영 자격/큐 출력·삭제0이다. 메모리 대역 결과를 실제 OAuth·운영 서버·계정 데이터 영속성·실기기·원격CI 검증으로 확대하지 않는다.
- 첫 Android 빌드의 색상/Drawable 타입 오류, 전환 중 폭0의 음수 폭, OS 마스크에 잘린 로고를 각각 수정하고 재검증했다. 실패 원본은 `.attempts`와 [시도 기록](/private/tmp/clipback-splash-alignment-20261018/attempt-audit.json)에 보존하며 성공 결과로 사용하지 않는다. iOS 기존 기기와 캐시 없는 새 동일 모델 시뮬레이터에서도 노란 배경과 짧은 희미한 전환만 확인했다. 완전 불투명 브랜드의 안정된 네이티브 정적 프레임을 확보하지 못했으므로 해당 색상/불투명도는 미검증으로 남긴다. Android는 실제 영상 PTS3.5005초에서 전체 원본 로고를 확인했다. [네이티브 리소스/번들48항목](/private/tmp/clipback-splash-alignment-20261018/native-final-bundle.json) 통과는 실제 iOS 픽셀 검증과 구분한다. 기존 시작 스냅샷 캐시는 복구 가능한 별도 경로로 옮겼으며 계정DB/공유 큐를 지우지 않았다. 새 동일 모델 시뮬레이터 진단 영상은 별도 근거로 보관하고 canonical Flutter/루트 기록과 섞지 않는다. [최종 환경 정리](/private/tmp/clipback-splash-alignment-20261018/cleanup-verification.json)에서 소유 앱/시뮬레이터/에뮬레이터 종료·포워딩 제거·ADB 종료·8767/8768 포트 닫힘과 추가 생성 시뮬레이터 삭제를 확인했다. Android 제스처 설정은2로 유지했고 사용자 앱 제거·기존 기기 데이터 삭제·임시 HTTP 서버 실행은 없었다.
- 기존 소개3장에 대응하는 현재 원본은 미확보다. B01은 권한 안내, B02/B03은 관심사 선택 상태이며 소개3장으로 대응시키지 않는다. 해당 소개 흐름·권한/관심사·약관·계정 연결용 로그인과 새 확대 맞춤은 유지/보류한다. 이번 완료는 A01의 승인 영역이며 온보딩·인증 전체 완료를 뜻하지 않는다. Android API24~30 실행과 실제 공급자·운영 서버·실기기는 미검증이다.

<a id="b-207829e1e7eab4d9"></a>

### A01 재현 명령과 프리뷰

<a id="b-b94ab3cf71a848b1"></a>

```bash
cd frontend
flutter test --no-pub test/splash_alignment_test.dart test/splash_startup_test.dart test/splash_share_startup_test.dart
flutter test --no-pub
flutter analyze --no-pub
flutter run -t test/support/splash_alignment_preview.dart --dart-define=SPLASH_ALIGNMENT_PHASE=after
```

<a id="b-aa2f4257b8ffc709"></a>

전용 프리뷰는 [splash_alignment_preview.dart](../../frontend/test/support/splash_alignment_preview.dart)이며 실제 루트·메모리 API·첫 실행부터의 공유 격리를 사용합니다. 내부8767포트의 `/scene`은 실제 A01 위젯을900ms 콜백 이후에도 독립 촬영하고, `/run`은 실제 루트11시나리오를 실행합니다. `/root?mode=empty|existing|slow-existing|error`는 시작 상태를 준비하고 `/state`·`/status`·`/export`는 현재 실측/판정을 읽습니다. 고정 A01 촬영을 실제 시작 체류시간 증거로 사용하지 않으며 콜드 스타트 영상은 네이티브 OS 화면을 따로 기록합니다. 기기 실행 시 포트 포워딩을 사용하고 끝나면 소유 기기/포워딩/ADB를 정리합니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-0c54a9bfbe6e09ad"></a>

직전 스플래시 작업은 `af93402` 기준 **A01 스플래시의1배율 표현·900ms 실제 시작 흐름과 네이티브 시작 리소스 맞춤**입니다. 신규24/전체1326·분석0, 양 플랫폼 Flutter/루트 각11시나리오·전체true/오류0을 확인했습니다. iOS 네이티브 시작의 완전 불투명 로고/정적 색상은 미검증·부분 비교이며 전체 시각 완료로 표시하지 않습니다. 소개3장·기존 인증/콘텐츠 보존 정책을 유지합니다.

<a id="b-79b2492abb7ab088"></a>

- 이 작업의 전달 커밋 제목은 `fix: 피그마 기준으로 스플래시와 앱 시작 흐름 맞춤`이며 같은 `feature/figma-ui-alignment`에서 최종 diff/공백/증거 제외를 검사한 뒤 저장합니다. 푸시·PR은 요청하지 않았으므로 수행하지 않습니다. 화면 증거·빌드·`AGENTS.md`는 커밋에 넣지 않습니다.
