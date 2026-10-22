# 로그인 선택 표현

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-ca7488643ccd4b04"></a>

앞선 `f4752bf` 기준 작업은 **A02 일반 로그인 선택의1배율 로고·태그라인·지원 공급자 버튼·또는/게스트 표현 맞춤**입니다. 집중20/관련366/전체1302·분석0과 iOS16/Android15기록·오류0·새2쌍/영상2개·환경 정리를 확인했습니다. iOS/Android의 기존 지원 공급자·인증/게스트/온보딩 정책을 보존하며 계정 연결/onBack/공급자가 없는 legacy, 약관 블록과 새 확대는 후속으로 둡니다. 실제 검사·기기 결과와 한계는 아래 이번 독립 기록을 따릅니다.

<a id="b-acfbe599d99cce12"></a>

### 로그인 선택 화면의 1배율 맞춤 — 2026-10-18 작업

<a id="b-d38f0e3bff132500"></a>

> 완료 범위는 일반 A02의 승인된1배율 표현이다. 집중20/관련366/전체1302·분석0, iOS16/Android15기록·오류0, 새2쌍/영상2개와 환경 정리를 확인했다. 이전 검증을 이번 성공으로 사용하지 않는다.

<a id="b-b2ef209056ab5e8c"></a>

`f4752bf` 기준으로 Page 1 > `261007`의 [A02 로그인/회원가입 선택](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3407) (`111:3407`)에서 **승인된 일반 진입의 1배율 로고·태그라인·지원 공급자 버튼·또는/게스트 표현**을 맞췄다. 새 표현은 `!linkingGuest && onBack == null && providers.isNotEmpty`에서만 사용한다. 계정 연결·onBack이 있는 조합·공급자가 없는 상태는 기존 본문/스타일을 유지한다. 인증/연결/온보딩 전체 기능이나 새 확대 맞춤의 완료를 뜻하지 않는다.

<a id="b-25c449c6ede0ec41"></a>

- **배치·글자:** 실제 OS SafeArea 한 번·PhoneFrame 최대375px과 자연 스크롤을 유지한다. 본문 좌우16px/끝24px, 로고 그룹은 안전 영역 아래129px·폭232px/중앙+0.5px, 로고178.525×60px·태그라인 앞16px·기본 그룹99px·그룹 뒤159px으로 첫 공급자가 안전 영역 아래387px에 시작한다. 태그라인은 실제 Ria Sans Regular16px/색#767676·AUTO, 공급자15px/SemiBold/−0.375px·AUTO, 또는14px/Medium/자간0/#D1D1D1·AUTO, 게스트15px/SemiBold/자간0/#484848·AUTO다. 글자 배율을 강제하거나 FittedBox로 줄이지 않는다.
- **공급자/버튼:** 원본 순서 Kakao→Apple→Google 중 기존 지원 집합만 표시하며 입력 목록을 변경하지 않는다. iOS는3개, Android는Apple을 넣지 않은2개이고 빠진 버튼/간격의 빈 자리를 남기지 않는다. 높이52px/R8·버튼 사이8px, Kakao#FDDC3F/Apple검정/Google흰색+0.5px #D1D1D1 테두리를 적용한다. 실제 provider별 콜백을 유지하고 busy 때 인증/게스트 탭 잠금·기존 스피너를 보존하며 새 비활성/로딩 디자인은 추가하지 않는다.
- **정확한 원본/크롭:** [원본 대조/후보](/private/tmp/clipback-login-alignment-20261018/candidate/assets/asset-manifest.json)에5역할의 원본·치수·해시·crop/slot을 기록한다. 기존 Kakao586×586/Google512×512 PNG는 정확한 SHA/pixels가 같아 재사용한다. 공유 entry-logo는 경로 좌표3곳의0.0001 차이를 덮어쓰지 않고 새 로그인 전용SVG를 등록한다. Apple1187×1044 PNG·143×1 divider도 새 원본을 등록한다. Kakao24×24/158.33%·좌상−29.17%, Apple21×20/폭138.94%·높이123.77%·좌−19.47%/상−11.89%, Google18×18의 원본 크롭을 유지한다. 원본색 필터·전체 화면 구현 에셋은 사용하지 않는다.
- **구분선/게스트:** 공급자 블록 뒤24px·좌우8px inset의 ‘또는’ 행을 놓고 각 선/문구 사이8px을 둔다. divider는 원본 `M0 0.5H143`/stroke#D1D1D1/1px이며 원본 PNG의 실제 선이y640 한 행이라는 점을 확인해 문단 중앙 대비−1px 위치를 적용한다. 게스트는44px hit를 확보하고11px hit 앞 간격으로 ‘또는’ 문단과 글자 사이의 시각 간격24px을 유지한다. 일반 화면에 뒤로/취소 버튼을 새로 만들지 않는다.
- **실제 폰트·공유 영향 격리:** [공식 ZIP](https://www.lotteriafont.com/download/RiaSans.zip)의 Regular OTF535,616bytes/SHA `d211588444df94fe17e7ada6f5c96ef03d83a8f657785e710c5c7f3e58ba0eaf`와 동봉 라이선스PDF 원본을 등록한다. ZIP SHA는 `8ef1573713b0b1154ece20d3b894a018a2a212a6393dcf3fb1a5493f8c83caf9`, PDF SHA는 `adc998ae0819bec8b374ad8d65b33229efc02c28ebcc344f90c03481e3a852e8`이며 PDF의 임베딩 ‘허용’ 행을 시각 확인했다. 폰트 파일은 바꾸지 않고 Flutter family를 **RiaSansLogin**으로만 등록해 정상 로그인에서 쓴다. 기존 RiaSans/EntryTagline·Splash·Home·공유 로고·public SocialButton과 Pretendard 선언은 유지한다. style.fontFamily 문자열만으로 실제 glyph/폰트 가용성을 통과시키지 않으며 집중 검사에서 alias 로드 전후 기존 RiaSans+Pretendard fallback의 실제 TextPainter 자연 폭/높이가 같음을 확인했다. glyph raster의 픽셀 일치와 양 네이티브의 별도 측정은 이 위젯 판정으로 대체하지 않는다.
- **정책 보존/제외:** 제출한 공급자/guest 선택·중복 방지·SDK 취소·오류/수동 재시도·연결401/409·Apple challenge/일회용 코드 비재생을 유지한다. Apple 취소는 사전 challenge 요청이 있을 수 있으므로 전체HTTP0회로 오판하지 않는다. 신규 소셜/새 guest는 온보딩, 기존 사용자는홈이고 발급 성공 후 데이터 조회/저장 재시도는 인증/guest를 다시 발급하지 않는다. A02 약관 블록은 원문/시행일/목적지가 미확정이므로 문구/링크를 추가하지 않는다. A06·온보딩/관심사·일반/연결의 원본 없는 상태·새 확대는 후속이다.

<a id="b-033e5b175a1eebe8"></a>

### 원본·자동 검사·보호 계약

<a id="b-b834cbe7d193ba07"></a>

- 계획 조회 **2026-10-18 03:52:33~03:52:39 KST**와 구현 직전 **04:02:59~04:03:05 KST / 2026-10-17 19:02:59~19:03:05 UTC**를 구분한다. 구현 재조회는 A02 컨텍스트/375×812px 원본을 한 번의 호출로 함께 확보했으며 별도 OS 그림·대체 디자인을 만들지 않는다. 에셋은 응답에 포함된 정확한5원본만 내려받아 로컬 사용하고 임시 Figma URL을 런타임에 남기지 않는다. 호출 제한·보관 원본 fallback·대체 원본은 없었다([원본/조회 기록](/private/tmp/clipback-login-alignment-20261018/figma/native-reference-manifest.json)).
- 제품 수정 전 실제 Pretendard·iOS/Android 테마×320/375px×1배율의 집중20건에서 **10통과/목표 차이10실패**를 재현했다([BEFORE 검사](/private/tmp/clipback-login-alignment-20261018/tests/focused-before-summary.json)). RiaSansLogin이 없는 BEFORE는 해당 목표 판정을 실패로 남기되 촬영은 막지 않았다. 도구 사전 점검에서 실제 창393px/내부 PhoneFrame375px을 구분하도록 Scaffold 계측과393px 회귀를 보완했다. 첫 적용 뒤 SVG 내부 FittedBox까지 글자 축소로 세는 오판과 자연 viewport 끝을 창 끝으로 고정한 오판을 발견해, 실제 RichText 포함 여부/legacy 양성 검사와 OS 안전 경계/guest 노출 검사로 보완했다. 제품을 기준 상태로 복원하고 이 도구로 재동결·BEFORE 재빌드/새 원본2장을 다시 촬영했다. 첫19건·첫AFTER20건(15통과/도구 오판5실패)·첫 적용04:18:01은 별도 시도이며 최종 성공으로 재사용하지 않는다([도구 정정](/private/tmp/clipback-login-alignment-20261018/instrumentation-correction-audit.json)). 신규2개를 포함한 **전체 test Dart 소스73개**(실행 엔트리52개)와 빌드 입력251개를 동결했고, 양 플랫폼의 새 BEFORE2장/동일 조건/해시 및 root 직접 시각 확인을 거친 [BEFORE 게이트](/private/tmp/clipback-login-alignment-20261018/before-gate.json) 뒤 **2026-10-18 04:25:38 KST / 2026-10-17 19:25:38 UTC**에 제품7파일을 적용했다([적용 기록](/private/tmp/clipback-login-alignment-20261018/product-application.json)).
- AFTER [실제 자동 실행](/private/tmp/clipback-login-alignment-20261018/tests/after-checks-result.json)에서 **집중20/20·관련366/366·전체 `flutter test --no-pub`1302/1302**를 통과했다(실패/건너뜀0). `flutter analyze --no-pub`는 문제0/exit0다([분석 원본](/private/tmp/clipback-login-alignment-20261018/tests/analyze-after.txt)). 새 검사에는 글자/실제 폰트 가용성·로고/크롭/선·공급자 순서/지원 집합/입력 불변·보이는 탭 hit·busy·짧은 viewport 스크롤/끝24px·legacy 분기/공유 문단의 폭·높이 불변을 포함한다. 기존 auth_safe_area·social_login/social_auth·session_restore/persistence·연결/누적 통계·기존 확대 검사를 유지한다.
- 실제 적용 후 허용된 기존 LoginScreen/pubspec2개 외 **보호269파일·기존 test Dart 소스71개 불변**, LoginScreen 공개 생성자/필드/imports·guard 외 legacy 본문·public SocialButton 전체의 byte 보존을 확인했다. [최종 보호 감사](/private/tmp/clipback-login-alignment-20261018/preservation-audit.json)는 신규2개를 포함한 동결73개 test Dart 소스도 불변임을 확인한다. [원본/실효 에셋/번들 감사](/private/tmp/clipback-login-alignment-20261018/static-assets-verification.json)에서5시각 역할+공식 폰트/라이선스 총7역할의 원본/로컬/iOS/APK bytes와 실제2상태의 경로·slot·crop/무필터·정확한 RiaSansLogin400 선언/기존RiaSans 미등록·최종 빌드 입력을 확인했다. [네이티브 legacy 보강](/private/tmp/clipback-login-alignment-20261018/legacy-native-font-isolation.json)은 양 플랫폼 BEFORE smoke/AFTER 연결 화면의 실제 태그라인 스타일/정규화 위치·폭200.078125px/높이23px이 같음을 확인했다. 위젯/네이티브 문단 측정과 별도 glyph raster 픽셀 일치는 구분한다.

<a id="b-7eec925e4a9282bd"></a>

### 양 플랫폼 실행·새 비교와 후속 경계

<a id="b-87972e47833aa212"></a>

| 플랫폼 | 실제 창 / DPR / 상·하 안전 여백 | 내부 프레임 / 자연 viewport | 실제 로고 top / 공급자 첫 top / 게스트 hit | AFTER |
| --- | --- | --- | --- | --- |
| iPhone16 / iOS18.6 | 393×852px /3.0 /59·34px | 375px·left9px /679px | 188px /446px /343×44px | 16기록·7판정true/오류0 |
| Android13 / API33 제스처 | 392.7×783.3px /2.75 /24·0px | 375px·left8.864px /619px | 153px /411px /343×44px | 15기록·7판정true/오류0 |

<a id="b-9dc57f4369a0e409"></a>

- [변경 전→후→Figma2쌍](/private/tmp/clipback-login-alignment-20261018/comparison-document.html)과 [동일 조건/원본 판정](/private/tmp/clipback-login-alignment-20261018/pair-verification.json)에서 새 OS 원본4장·같은 기종/빈 메모리 세션/지원 집합/1배율/키보드 숨김/scroll0·조건 차이0/Figma 누락0을 확인했다. 실제 OS 창/안전 여백·Figma375×812px과 기존 PhoneFrame 최대375px을 보정하지 않았다. AndroidApple미지원·약관 보류와 원본 차이를 표시하며 원본을 자르거나 대체 디자인을 만들지 않았다. 자연 viewport는 OS 안전 경계 안에서 내용만큼 끝나며 창 끝까지 높이를 강제하지 않는다. 정상 네이티브 최대 스크롤0은 무스크롤로 기록하고 낮은 viewport의 접근/끝24px은 위젯 검사로 확인했다.
- 개요: [iOS](/private/tmp/clipback-login-alignment-20261018/comparisons/ios-comparison-overview.png)·[Android](/private/tmp/clipback-login-alignment-20261018/comparisons/android-gesture-comparison-overview.png). AFTER 영상: [iOS](/private/tmp/clipback-login-alignment-20261018/ios/after/interaction.mp4)·[Android](/private/tmp/clipback-login-alignment-20261018/android-gesture/after/interaction.mp4). [영상 판정](/private/tmp/clipback-login-alignment-20261018/media-verification.json)은2원본의 전체 디코딩/실제 첫끝/중간 및 후반 샘플을 확인했고 편집0·디코딩 실패0이다. 실제 인코딩 길이는 iOS22.67초/Android25.21초이며 대기시간을 임의 합산하지 않았다. 독립 메모리 시나리오 사이 `_fresh`/`runApp(SizedBox.shrink)` 초기화로 잠시 검은 앱 영역이 보일 수 있으며 제품의 새 로딩/인증 실패나 디코딩 오류로 해석하거나 잘라 숨기지 않는다.
- [실제 루트 시나리오/실측](/private/tmp/clipback-login-alignment-20261018/native-validation-summary.json)에서 iOS16/Android15기록의 스타일·레이아웃·에셋·동작·커버리지·실행 완료·전체 판정이 모두true/프레임워크 오류0이다. 빈 세션의 명시적 선택 전 발급0, 지원 공급자별 취소, pending/중복 잠금·취소 복귀, HTTP503 발급 오류 뒤 세션 없음/재시도, 기존 소셜→홈/새 소셜·guest→온보딩·관심사→홈, legacy 연결 진입/취소·계정 복귀, 로그아웃→일반 A02 복귀를 확인했다. Apple 취소만 사전 challenge1회를 허용하고 발급/저장0을 확인했다. 새 네이티브 오류 시나리오는 HTTP503이며 SDK 예외·연결401/409·발급 성공 후 데이터/저장 재시도는 기존 자동 회귀·제품 소스 불변으로 보존했다.
- 공급자/게스트·온보딩·프로필·계정 연결/뒤로/로그아웃은 측정 위치의 합성 pointer로 확인했다. guest 홈→마이는 `HomeScreen.onTab(AppRoute.my)` 준비 콜백이며 해당 하단 탭의 실제 UI hit 검증으로 보고하지 않는다. 서버 통계/콘텐츠 계약은 소스 불변·기존 회귀로 보존하며 빈 데이터 대역을 실제 운영 데이터 보존 증거로 확대하지 않는다. 최초 실행부터 native 공유를 격리해 기존 큐/자격의 조회·삭제·출력을 하지 않았다. 로컬 대역 결과는 실제 OAuth·운영 서버·영속 저장·실기기·원격CI 증거가 아니다.
- Android 첫 AFTER 원본/영상에는 System UI ANR 팝업이 재등장해 Flutter 판정true/오류0만으로 채택하지 않고 [제외 시도](/private/tmp/clipback-login-alignment-20261018/.attempts/android-system-ui-anr-after/attempt-review.json)로 보존했다. 제품 결함으로 단정하지 않고 같은 최종 소스/빌드/fixture로 Android만 재실행했다. 새 canonical 원본은 촬영 전후 연속 XML과 root의 원본 직접 확인을 거쳤고 팝업/복구 클릭0이며 iOS 원본은 유지했다. 도구 보완과 환경 재실행을 제품 수정/새 검증 대상 변경과 구분한다.
- [환경 정리](/private/tmp/clipback-login-alignment-20261018/cleanup-verification.json)는 소유 앱/시뮬레이터/에뮬레이터·포워딩·ADB 종료와8767/8768 포트 닫힘을 확인했다. 최종 탐색/키보드 설정 변경0·기기 wipe/앱 uninstall0·임시 비교 HTTP서버 없음이며 증거/빌드/AGENTS.md는 Git에서 제외한다.
- UI-02 완료는 **승인된 일반 A02 표현**에 한정한다. 약관 `111:3419`·DEC-06, 계정 연결/onBack/공급자 없음·busy/오류의 별도 디자인, A06·온보딩/관심사·새 확대는 후속이다. legacy의 본문/문구/콜백·기존 확대 자동 검사와 UI-03·UI-13·UI-14의 기능/정책 보류 및 과거 조회/검증 기록은 유지한다. 인증·온보딩 전체 기능이나 약관 적용 완료로 표시하지 않는다.

<a id="b-aad1944bb8a00071"></a>

전용 프리뷰는 [login_alignment_preview.dart](../../frontend/test/support/login_alignment_preview.dart)입니다. `/scene`은 실제 빈 메모리 세션의 일반 로그인을 스크롤0·키보드 숨김으로 준비합니다. `/run`은 지원 공급자별 취소·busy/중복 차단·HTTP503/재시도·기존/신규 소셜·guest/온보딩·연결 화면 취소·로그아웃 복귀를 실제 루트에서 검사합니다. `/state`·`/status`는 실제 글자·경계·원본 경로/크롭·폰트 가용성과 공유 격리를 읽습니다. BEFORE의 목표 실패는 정적 촬영을 막지 않습니다.

<a id="b-36ce385cc13e07c3"></a>

```bash
flutter build ios --debug --no-pub --simulator -t test/support/login_alignment_preview.dart --dart-define=LOGIN_ALIGNMENT_PHASE=after
flutter build apk --debug --no-pub -t test/support/login_alignment_preview.dart --dart-define=LOGIN_ALIGNMENT_PHASE=after
flutter test --no-pub test/login_alignment_test.dart
```

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-50ce394eefe53224"></a>

직전 화면 작업은 `f4752bf` 기준 **A02 일반 로그인 선택의1배율 외형 맞춤**입니다. canonical BEFORE 게이트 뒤 제품7파일을 적용했고 집중20/관련366/전체1302·분석0을 통과했습니다. iOS16/Android15기록·오류0·새2쌍/영상2개·환경 정리도 아래 이번 독립 기록에서 확인했습니다. 기존 인증/게스트/연결·온보딩 정책과 이전 기록은 유지하고 약관·일반 외 상태·새 확대는 분리합니다.
