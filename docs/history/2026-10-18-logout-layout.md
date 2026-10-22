# 로그아웃 확인 표현

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-8aba0c0a90d9e448"></a>

직전 `c06e990` 기준 작업은 **J03 로그아웃 확인의 승인된1배율 표현과 기존 로그아웃 연결**입니다. 계정 관리에서 확인 화면 진입·취소 시 로그아웃 요청0회이며 확인에서만 기존 로그아웃을 요청합니다. 대기 중 확인/취소/헤더·OS 뒤로를 잠그고 일반 실패는 확인 화면에서 기존 오류 안내·수동 재시도, 기기 세션 삭제 실패는 기존 복구 화면을 우선합니다. **집중12/전체1349·분석0·양 플랫폼 각19기록/전체true·오류0·새 비교2쌍/영상2개**를 확인했습니다. 비교 왼쪽은 새로 촬영한 기존 계정 관리이며 대응하는 J03 BEFORE가 없음을 명시합니다. 기존 계정/인증·공유 정책과 새 확대 보류는 유지합니다.

<a id="b-d9056bebb32be428"></a>

### 로그아웃 확인 화면의 1배율 맞춤 — 2026-10-18 작업

<a id="b-9305f1c86ac4a055"></a>

이번 `c06e990` 기준 작업은 **J03 로그아웃 확인의 승인된1배율 표현과 기존 로그아웃 연결**입니다. 계정 관리에서 확인 화면 진입·취소 시 로그아웃 요청0회이며 확인에서만 기존 로그아웃을 요청합니다. 대기 중 확인/취소/헤더·OS 뒤로를 잠그고 일반 실패는 확인 화면에서 기존 오류 안내·수동 재시도, 기기 세션 삭제 실패는 기존 복구 화면을 우선합니다. **집중12/전체1349·분석0·양 플랫폼 각19기록/전체true·오류0·새 비교2쌍/영상2개**를 확인했습니다. 비교 왼쪽은 새로 촬영한 기존 계정 관리이며 대응하는 J03 BEFORE가 없음을 명시합니다. 기존 계정/인증·공유 정책과 새 확대 보류는 유지합니다.

<a id="b-ce4efffa940e19a5"></a>

- Page 1 > 261007의 [J03 `111:5767`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-5767)을 구현 직전 **2026-10-18 14:22:47~14:22:53 KST**에 컨텍스트/원본1회로 조회했습니다. 계획 조회14:19 KST와 구분하며 실패/추가 MCP 호출·대체 원본은 없습니다.
- [확인 화면](../../frontend/lib/features/account/logout_confirmation_screen.dart)은 내부 `AppRoute.logoutConfirmation`과 확인/취소/busy를 사용합니다. 기존 계정 화면 생성자/콜백·API/모델은 유지합니다. 제목은 기존 실제 Bold OTF 등록을 사용하고 헤더64px·일러스트224px·각 버튼48px·하단32px+OS 여백을 적용합니다. 낮은 화면은 본문만 스크롤합니다.
- [최종 자동 요약](/private/tmp/clipback-logout-alignment-20261018/tests/validation-summary.json): BEFORE 전용11건(1통과/미존재 차이10실패)·호환 회귀259통과 후 제품을 적용했습니다. AFTER 전용12·전체1349/1349(실패/건너뜀0·106초)·분석0/exit0입니다. 12번째 J03 Apple 무효화 검사는 AFTER에 추가했으며 기존 확대 회귀를 유지합니다. 컴파일 parent-data/단위검사 플랫폼 보정의 첫 실패 로그는 같은 tests 디렉터리에 보존합니다.
- [새 비교2쌍](/private/tmp/clipback-logout-alignment-20261018/comparison-document.html)·[iOS](/private/tmp/clipback-logout-alignment-20261018/comparisons/ios-logout.png)·[Android](/private/tmp/clipback-logout-alignment-20261018/comparisons/android-logout.png)은 **기존 J02 → 새 J03 → Figma**입니다. 직접 대응하는 J03 BEFORE는 없었으며 OS 창/안전 영역·데이터/1배율/scroll0을 그대로 기록합니다. 양 플랫폼 각19기록·스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0입니다([iOS 보고서](/private/tmp/clipback-logout-alignment-20261018/ios/after/report.json)·[Android 보고서](/private/tmp/clipback-logout-alignment-20261018/android/after/report.json)). 기본 최대 스크롤0이며 낮은 viewport의 드래그/끝24px 접근은 위젯 검사입니다.
- AFTER 영상 [iOS15.85초](/private/tmp/clipback-logout-alignment-20261018/ios/after/actions.mp4)·[Android28.157278초](/private/tmp/clipback-logout-alignment-20261018/android/after/actions.mp4)과 [전체 디코딩/녹화 검사](/private/tmp/clipback-logout-alignment-20261018/media-verification.json)를 제공합니다. `/run`의 독립 회원/게스트 검사를 위한 앱 재생성으로 영상에 A01/반복 시작 구간이 있으며 제품 로그아웃 왕복의 스플래시 재실행을 뜻하지 않습니다. Android 실제 Back keyevent4는 [별도 기록](/private/tmp/clipback-logout-alignment-20261018/android/after/native-back.json), iOS는 프레임워크 Pop 전달입니다. 기존 SnackBar를 보존하며 새 오류 UI는 없습니다.
- [번들254항목](/private/tmp/clipback-logout-alignment-20261018/bundleverification.json)은 원본/로컬/iOS/APK 이미지·실제 Bold 폰트·보호 소스 범위를 확인합니다. [환경 정리](/private/tmp/clipback-logout-alignment-20261018/cleanup-verification.json)는 소유 iOS/Android·드라이버/포트·ADB 종료를 확인했고 설정 변경/사용자 데이터 삭제/별도 호스트 HTTP 서버 실행은 없습니다. 상세 정책/실측은 [계획](../figma-ui-alignment-plan.md)의 이번 J03 기록을 따릅니다. 실제 OAuth·운영 서버·영속 데이터·실기기/CI와 구분하며 탈퇴·별도 오류 디자인·J02 시스템 복귀·새 확대는 후속입니다.

<a id="b-cc59826cdae093b7"></a>

### 로그아웃 확인 재현 명령

<a id="b-20721795a0587180"></a>

```sh
flutter test --no-pub test/logout_alignment_test.dart
flutter test --no-pub
flutter analyze --no-pub
flutter run --no-pub -t test/support/logout_alignment_preview.dart --dart-define=LOGOUT_ALIGNMENT_PHASE=after -d <device-id>
```

<a id="b-176e11e5de5a3a0a"></a>

프리뷰는 실제 ClipbackApp·메모리 API/세션을 사용하고 첫 실행부터 네이티브 공유를 격리합니다. `/scene?kind=member` 또는 `/scene?kind=guest`는 정적 상태, `/run`은 AFTER 동작, `/baseline-run`은 BEFORE 동작용입니다. BEFORE는 기준 커밋의 제품 소스와 동결 프리뷰를 함께 빌드하며 현재 제품의 phase 이름만 바꿔 대체하지 않습니다. 각 실행에서 실제 스타일/레이아웃/에셋/동작 판정을 전체 결과에 연결합니다. 보고서 서버8767은 검증 종료 후 정리하며 운영 계정으로 실행하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-99f43c39bb16e326"></a>

- 기준 `c06e990`·브랜치 `feature/figma-ui-alignment`에서 J03 `111:5767`의 승인된1배율 상단/문구/원본 일러스트/버튼을 추가했습니다. 계정 관리의 기존 콜백 타입을 유지하고 내부 `AppRoute.logoutConfirmation`만 추가했습니다. 기존 ViewModel/Repository/API/모델·보안 처리와 J02 외형은 변경하지 않았습니다.
- 진입·취소·헤더/OS 복귀는 로그아웃 요청0이며 확인에서만 기존 로그아웃을 요청합니다. 현재 경로/mounted/인증 busy/복구/연결 오류를 다시 검사해 오래된 콜백·중복/복귀를 차단합니다. 일반 실패는 J03/기존 오류 SnackBar/수동 재시도, 성공·무효화는 기존 로그인, 로컬 세션 삭제 실패는 기존 복구 화면을 우선합니다. Future 완료만으로 강제 이동하지 않습니다.
- 계획 조회 **2026-10-18 14:19 KST**와 별도로 구현 직전 **14:22:47~14:22:53 KST**에 같은 파일의 컨텍스트·375×812px 원본을1회 조회했습니다. 실패/추가 MCP 호출·대체 원본은 없습니다. [새 양 플랫폼 BEFORE 게이트](/private/tmp/clipback-logout-alignment-20261018/product-edit-gate.json) 뒤 제품을 적용했습니다. 당시 J03가 없었으므로 새 J02 직전 원본/즉시 로그아웃 기록을 사용하고 J03 BEFORE를 만들지 않았습니다.
- [자동 결과](/private/tmp/clipback-logout-alignment-20261018/tests/validation-summary.json): BEFORE 전용11건=1통과/목표 실패10·호환 회귀259/259, AFTER 전용12/12·전체1349/1349·실패/건너뜀0·106초·분석0/exit0입니다. J03 중 Apple 무효화/오래된 콜백12번째 검사는 AFTER에 추가했고 기존 세션·공유·저장·확대 회귀를 유지했습니다. 초기 parent-data 컴파일/검사 전용 platform override 실패 로그는 보존하며 최종 성공으로 합산하지 않습니다.
- [새 비교2쌍](/private/tmp/clipback-logout-alignment-20261018/comparison-document.html)은 **기존 J02 → 새 J03 → Figma**이며 같은 회원 데이터·1배율·키보드 숨김·scroll0의 새 원본입니다. [iOS](/private/tmp/clipback-logout-alignment-20261018/ios/after/report.json)·[Android](/private/tmp/clipback-logout-alignment-20261018/android/after/report.json)의 각19기록은 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0입니다. 정상 최대 스크롤0과 낮은 viewport의 위젯 실제 드래그/마지막24px을 구분합니다. 실제 OS 창/안전 영역·최대375px 차이를 보정하지 않습니다.
- 플랫폼별 AFTER [iOS15.85초](/private/tmp/clipback-logout-alignment-20261018/ios/after/actions.mp4)·[Android28.157278초](/private/tmp/clipback-logout-alignment-20261018/android/after/actions.mp4)의 전체 디코딩exit0/녹화 완료와 시작/종료/중간 동작을 확인했습니다([미디어](/private/tmp/clipback-logout-alignment-20261018/media-verification.json)·[프레임](/private/tmp/clipback-logout-alignment-20261018/video-frame-review.json)). `/run`이 독립 데이터를 위해 새 ClipbackApp을 만드는 A01/반복 시작 구간은 도구 동작이며 제품의 로그아웃 왕복 스플래시 재실행을 의미하지 않습니다. Android [실제 Back keyevent4](/private/tmp/clipback-logout-alignment-20261018/android/after/native-back.json)와 iOS 프레임워크 Pop 전달을 구분합니다.
- [번들/폰트/보호 소스254/254](/private/tmp/clipback-logout-alignment-20261018/bundleverification.json)·[환경 정리](/private/tmp/clipback-logout-alignment-20261018/cleanup-verification.json)는 모두 통과했습니다. 소유 iOS/Android·드라이버/포트·ADB를 종료했고 설정 변경0·사용자 데이터 삭제/별도 호스트 HTTP 서버false입니다. 화면 증거·빌드·AGENTS.md는 Git 밖에 유지하며 푸시/PR은 하지 않습니다. 실제 OAuth·운영 서버·영속 저장·실기기·CI 검증은 아니며 별도 오류 디자인·게스트/연결 정책·탈퇴·J02 자체 복귀·새 확대 및 A01 iOS 네이티브 정적 불투명/색상은 후속입니다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-038572a1635fa72d"></a>

`c06e990` 기준 Page 1 > `261007`의 [J03 로그아웃 확인](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-5767)(`111:5767`)에 승인된1배율 표현과 확인/취소 단계를 추가했다. 계정 관리 전체 기능·실제 공급자/운영 세션 검증의 완료를 뜻하지 않으며 J01/J02와 이전 작업 기록은 당시 결과로 보존한다.

<a id="b-f8ecb275f474310b"></a>

- **표현:** 전용 Pretendard로 헤더18/SemiBold/−0.45/검정/AUTO, 제목24/Bold/−0.6/#1A1A1A/1.6, 설명16/Medium/−0.4/#767676/1.5, 버튼16/SemiBold/자간0/22px을 명시했다. 제목은 기존 `PretendardDetail`의 실제 `Pretendard-Bold.otf`를 사용하며 합성 굵기로 대체하지 않는다. 최대375px·실제 안전 영역 한 번·헤더64px/중앙+0.5px·뒤로24px/좌16px/hit48px·제목 간격8px, 헤더→제목16px·문단 사이8px을 적용한다.
- **본문/하단:** 원본 일러스트224×224px/cover는 가로 중앙+0.5px·안전 영역 세로 중앙−8px이다. 실제 문단을 측정해 이미지 앞 최소16px·본문 끝24px을 확보하고 낮은 viewport에서 스크롤한다. 버튼은 좌우16px·각48px·간격8px/R8·하단32px+실제 OS 여백 한 번이다. 확인은 #1A1A1A/#FFD75C, 취소는 흰 배경/#1A1A1A/1px #767676이며 busy에서도 문구·색상을 유지해 입력만 잠근다. 새 일러스트1개를 등록하고 정확히 일치하는 기존 뒤로가기 SVG를 재사용했다([원본 대조](/private/tmp/clipback-logout-alignment-20261018/figma/asset-audit.json)). 가짜 OS 표시·전체 화면 에셋은 추가하지 않았다.
- **경로/실패/보안:** 내부 `AppRoute.logoutConfirmation`을 추가하고 기존 공개 `AccountManagementScreen.onLogout` 타입을 유지한다. 진입·확인·취소는 현재 경로와 mounted/인증 busy/세션 복구/연결 오류를 다시 검사한다. 취소·헤더/OS 뒤로는 요청 없이 J02로 복귀하며 busy에는 모두 잠긴다. 확인은 기존 `AppViewModel.logout()`을 호출하고 Future 완료만으로 강제 이동하지 않는다. 일반 실패는 J03·기존 SnackBar·수동 재시도, 성공/무효화는 기존 로그인 전환, 서버 성공 후 로컬 clear 실패는 기존 복구 화면을 우선한다. API/Repository/모델·인증/공유 보안 처리와 J02 자체 시스템 복귀/스크롤 정책은 변경하지 않았다.
- **조회/BEFORE:** 계획 조회 **2026-10-18 14:19 KST**와 별도로 구현 직전 **14:22:47~14:22:53 KST(05:22:47~05:22:53 UTC)**에 같은 파일의 J03 컨텍스트·375×812px 원본을 `get_design_context` **1회**로 확보했다([컨텍스트](/private/tmp/clipback-logout-alignment-20261018/figma/J03.json)·[원본](/private/tmp/clipback-logout-alignment-20261018/figma/J03.png)). 실패/추가 MCP 호출·다른 파일/대체 디자인은 없다. 현재 J03가 없던 기준 커밋에서 양 플랫폼의 새 J02 로그아웃 직전 원본과 즉시 요청 동작을 먼저 확보한 뒤 제품을 적용했다([수정 전 게이트](/private/tmp/clipback-logout-alignment-20261018/product-edit-gate.json)·[적용 시각](/private/tmp/clipback-logout-alignment-20261018/product-applied-at.json)). 없는 J03 BEFORE를 생성하지 않았다.
- **자동 검사:** BEFORE 전용11건은1통과/화면 미존재에 따른 목표 실패10건이며 기존 helper/프리뷰 보완 후 기준 커밋 회귀259/259도 통과했다. AFTER는 전용 **12/12**, 전체 `flutter test --no-pub` **1349/1349·실패/건너뜀0·106초/exit0**, `flutter analyze --no-pub` **문제0/exit0**이다([최종 요약](/private/tmp/clipback-logout-alignment-20261018/tests/validation-summary.json)·[전체](/private/tmp/clipback-logout-alignment-20261018/tests/full-test.log)·[분석](/private/tmp/clipback-logout-alignment-20261018/tests/analyze.log)). 12번째 J03 중 Apple 무효화/오래된 콜백 검사는 AFTER에 추가했으므로 BEFORE11건과 같은 개수로 보고하지 않는다. 실제 폰트·iOS/Android×320/375px×1배율·낮은 viewport 실제 드래그, 회원/게스트 취소 요청0·확인1/중복 잠금·실패/재시도·로컬 clear 복구·종료 후 응답·기존 세션/공유/확대 회귀를 검사했다. 진행 중 요청을 기다리기 전에 게이트를 풀 수 있도록 기존 helper의 request Future를 보존했다.
- **준비 중 실패:** 첫 AFTER 컴파일에서 추상 `ContainerBoxParentData` 인스턴스 생성 오류를 전용 concrete parent-data로 수정했고([첫 컴파일](/private/tmp/clipback-logout-alignment-20261018/tests/after-target-compile-attempt.log)), 단위 검사 전용 platform override를 바로잡았다([초기 검사](/private/tmp/clipback-logout-alignment-20261018/tests/after-target-foundation-override-attempt.log)). 이전 실패를 최종 성공으로 합산하지 않으며 제품/검사 최종 소스 해시는 최종 요약을 따른다.

<a id="b-fec367906a26f0e3"></a>

### 양 플랫폼 새 비교와 실제 동작

<a id="b-98da967b5ea41aa5"></a>

| 플랫폼 | 실제 논리창 / 안전 상·하 / 프레임 left | 제목 top·높이 / 설명 top·높이 | 일러스트 top / 크기 | 확인·취소 top / 취소 bottom |
| --- | --- | --- | --- | --- |
| iPhone16 / iOS18.6 | 393×852 /59·34 /9px | 139·38 /185·24px | 318.5px /224×224px | 682·738 /786px |
| Android13 / API33 제스처 | 392.727×783.273 /24·0 /8.864px | 104·38 /150·24px | 283.636px /224×224px | 647.273·703.273 /751.273px |

<a id="b-a2748cd6bfdb03d5"></a>

- [기존 계정 관리 → 새 J03 → Figma2쌍](/private/tmp/clipback-logout-alignment-20261018/comparison-document.html), [iOS](/private/tmp/clipback-logout-alignment-20261018/comparisons/ios-logout.png)·[Android](/private/tmp/clipback-logout-alignment-20261018/comparisons/android-logout.png), [동일 조건/원본 기록](/private/tmp/clipback-logout-alignment-20261018/comparison-manifest.json)을 제공한다. 같은 기종·회원 데이터·1배율·키보드 숨김·scroll0이며 원본 OS 창/안전 여백과 Figma375×812px을 보정하지 않는다. 직접 대응하는 J03 BEFORE는 존재하지 않았고 왼쪽은 새로 촬영한 J02다. 양 플랫폼 버튼343×48px·헤더64px이며 기본 최대 스크롤0은 무스크롤로 기록한다. 낮은 viewport의 실제 드래그/끝24px 접근은 위젯 검사로 별도 확인했다.
- 양 플랫폼 실제 루트/메모리 대역 각 **19기록**에서 스타일/레이아웃/에셋/동작/전체 `passed:true`·프레임워크 오류0이다([iOS](/private/tmp/clipback-logout-alignment-20261018/ios/after/report.json)·[Android](/private/tmp/clipback-logout-alignment-20261018/android/after/report.json)). 회원/게스트 진입·취소/헤더 복귀·프레임워크 Pop 요청, 대기 중 중복/복귀 차단·503 후 확인 화면/세션 유지·수동 재시도→로그인, 로컬 clear 실패의 복구 화면과 최종 J03 재진입을 확인했다. Android는 별도로 실제 `adb shell input keyevent 4` 뒤 계정 복귀·추가 요청0·세션 보존을 확인했다([실제 Back](/private/tmp/clipback-logout-alignment-20261018/android/after/native-back.json)). iOS 뒤로는 프레임워크 Pop 전달이며 네이티브 엣지 스와이프 증거로 보고하지 않는다.
- AFTER 원본 영상은 [iOS15.850000초](/private/tmp/clipback-logout-alignment-20261018/ios/after/actions.mp4)·[Android28.157278초](/private/tmp/clipback-logout-alignment-20261018/android/after/actions.mp4)이며 [미디어 검사](/private/tmp/clipback-logout-alignment-20261018/media-verification.json)·[프레임 검토](/private/tmp/clipback-logout-alignment-20261018/video-frame-review.json)에서 전체 디코딩exit0·녹화 완료·시작/종료/중간 동작을 확인했다. 채팅용960px 높이/30fps 프리뷰는 원본과 별도로 보존한다. `/run`은 독립 회원/게스트 데이터를 위해 새 ClipbackApp을 생성하므로 영상에 A01 시작/반복 초기화 구간이 있고 최종 J03로 끝난다. 이는 도구의 재생성으로, 제품 로그아웃 왕복에서 스플래시가 재실행된다는 뜻이 아니다. 기존 오류 SnackBar를 유지하며 새 오류 UI를 추가하지 않았다.
- [실제 iOS/APK 번들·폰트·보호 범위254/254](/private/tmp/clipback-logout-alignment-20261018/bundleverification.json)를 통과했다. 새 PNG/기존 SVG의 원본 bytes·실제 Bold 폰트/등록·네이티브 및 ViewModel/Repository 불변 검증과 실제 공급자/운영 서버 증거는 구분한다. [환경 정리](/private/tmp/clipback-logout-alignment-20261018/cleanup-verification.json)는 소유 iOS Shutdown·Android 종료·드라이버/포트 닫힘·ADB 종료를 모두 확인했다. 설정 변경0·사용자 데이터 삭제false·별도 호스트 HTTP 서버false다. emulator 종료 직후 일시 offline인 첫 스냅샷은 `.attempts/cleanup-emulator-offline-race-1.json`에 보존하고 실제 종료를 재확인한 최종 판정true와 구분한다. 증거·빌드·AGENTS.md는 Git 밖에 보존하며 푸시/PR은 하지 않는다.

<a id="b-ea8f17dad5d48b78"></a>

**후속/미검증:** 실제 OAuth·운영 서버·영속 데이터·실기기·원격 CI는 검증하지 않았다. 최초 실행부터 공유 채널을 격리한 메모리 API/세션의 로컬 결과다. 원본 없는 별도 로딩/오류 표현·J02 자체 시스템 복귀/복원·게스트/연결 정책·탈퇴·새 확대는 후속이며 기존 확대 자동 검사는 유지한다. A01 iOS 네이티브 완전 불투명/정적 색상 미검증과 이전 보류는 해소되지 않았다.
