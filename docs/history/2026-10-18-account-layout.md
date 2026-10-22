# 계정 관리 표현

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-b3be602588881ceb"></a>

앞선 `4d18060` 기준 작업은 **J02 계정 관리의 승인된1배율 상단·아바타·이름·계정 행 맞춤**입니다. 긴 문구는 축소·말줄임 없이 줄바꿈하고 높이를 늘립니다. 집중14/관련266/전체1265·분석0·별도 실제 루트/긴 문구 검사와 양 플랫폼 각16동작/오류0·새 비교4쌍/영상2개·환경 정리를 확인했습니다. 실제 연결 계약·공급자별 표현·탈퇴 API·시스템 복귀·새 확대는 후속입니다.

<a id="b-622a112492310aa9"></a>

### 계정 관리 화면의 1배율 맞춤 — 2026-10-18 작업

<a id="b-a5e07f434ccacf5a"></a>

`4d18060` 기준으로 Page 1 > `261007`의 [J02 프로필/계정 관리](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4533) (`111:4533`)에서 **승인된 상단·아바타·이름·계정 행의 1배율 표현**을 적용했다. 연결/인증 정책·탈퇴 API·시스템 뒤로가기·공급자별 표현과 계정 관리 전체 기능 완료를 뜻하지 않는다. J01과 이전 커밋의 검사·조회·비교는 위의 당시 기록으로 보존한다.

<a id="b-c99f7316ff3a696d"></a>

- **확정한 글자·배치:** 계정 관리 전용 Pretendard/AUTO를 명시했다. 상단18/SemiBold/−0.45/검정, 이름20/SemiBold/−0.5/검정, 섹션16/SemiBold/−0.4/#1A1A1A, 계정 문구/메뉴14/Medium/−0.35/검정, 연결됨14/Medium/−0.35/#767676이다. 헤더64px·중앙+0.5px·뒤로가기24px/좌16px/제목 간격8px과 hit48px을 적용한다. 헤더 아래16px·아바타140px/가로 중앙+0.5px·이름 앞16px/가로 중앙·섹션 앞16px, 섹션44px·그룹 좌우16px/R8/흰 배경을 맞춘다. 카드 폭은 실제 가용 폭−32px이며343px을 강제하지 않는다.
- **긴 문구·스크롤:** 이름과 실제 계정 문구는 축소·말줄임 없이 줄바꿈한다. 행은 최소41px·내부 좌우16/상하12px이고 내용에 따라 자연 높이를 사용한다. 연결됨→화살표16px, 추가 연결/재확인 행 사이0px·다음 계정 섹션 앞16px, 로그아웃/탈퇴 행 사이10px을 적용했다. 헤더를 고정하고 본문을 스크롤하며 본문 끝24px과 실제 OS 하단 여백을 각각 한 번 확보한다. 하단 탭/가짜 OS 인디케이터는 추가하지 않았다.
- **정확한 에셋:** 원형 배경140×140px SVG만 새로 등록했다. 캐릭터 PNG·뒤로가기24px·메뉴 화살표는 해당 J02 원본과 로컬 SHA가 같아 기존3개를 재사용한다. 캐릭터 clip88.038×97.821px/좌24.23·상18.84px과 원본 크롭 폭153.23%/높이136.21%/좌−23.01%/상−14.52%, 화살표 논리 슬롯5×10px과 원본 선 영역6.66667×11.6667px을 별도로 측정했다. SVG 색 필터·전체 화면 에셋은 사용하지 않는다([원본 대조](/private/tmp/clipback-account-alignment-20261018/figma/asset-audit.json)·[소스/실효 에셋 판정](/private/tmp/clipback-account-alignment-20261018/static-assets-verification.json)). 원본/로컬3재사용·1신규, APK/iOS 번들2종과 AFTER 정적4상태의 에셋·기하도 통과했다.
- **데이터·동작 보존:** 실제 이름/providerLabel·누적 저장/재열람·기존 버전 값을 유지하며 문구로 공급자·인증 상태를 추정하지 않는다. `isGuest=false`의 실제 계정 문구/연결됨은 읽기 전용, true는 계정 연결하기, null은 계정 정보 다시 확인을 유지한다. busy 중 연결/재확인·로그아웃은 비활성이며 기존 뒤로가기·탈퇴 안내는 유지한다. 공개 생성자/콜백·API/Repository/모델·전역 테마/공통 아이콘·마이페이지와 기존 인증/세션 정책은 변경하지 않았다. 회원 탈퇴는 기존 API 미지원 안내다.

<a id="b-0c2247df6efbc89e"></a>

### 이번 조회와 자동 검사

<a id="b-833c9b5e8f204221"></a>

- 계획 조회 **2026-10-18 02:16:53~02:16:59 KST**와 별도로 구현 직전 **02:22:55~02:23:00 KST /2026-10-17 17:22:55~17:23:00 UTC**에 J02 컨텍스트·375×812px 원본을 한 번의 `get_design_context` 호출로 함께 확보했다. 제한/fallback·별도 스크린샷/메타데이터 호출은 없고 같은 파일의 정확한 J02만 사용했다([원본/조회 기록](/private/tmp/clipback-account-alignment-20261018/figma/native-reference-manifest.json)). 원본 화면의 제목은 ‘계정 관리’이며 컨텍스트 생성코드의 ‘게정 관리’ 오탈자는 따르지 않고 올바른 기존 제목을 유지한다. 원본은 카카오 회원 예제다. 게스트에는 기존 상태와 승인된 공통1배율 표현을 적용하며 게스트/미확인 전용 원본은 미확보이고 새 상태별 디자인은 후속이다.
- 제품 수정 전 [집중 검사](/private/tmp/clipback-account-alignment-20261018/tests/focused-before-summary.json)14건 중4통과/목표 차이10실패를 재현했다. 스타일4건·이름18→20px4건·낮은 viewport의 기존 비스크롤/실제 overflow2건이며 fixture 캐스팅/탐색 예외는0이다([분류](/private/tmp/clipback-account-alignment-20261018/tests/before-diagnostic.json)). 정상393×852px 실제 루트 probe는1테스트/회원·게스트2상태, 프레임워크 오류/예상 밖 요청/콘텐츠 쓰기0으로 목표 실패와 정상 촬영 가능 여부를 분리했다([BEFORE 루트 검사](/private/tmp/clipback-account-alignment-20261018/tests/baseline-root-probe.json)).
- [동결 검사/데이터](/private/tmp/clipback-account-alignment-20261018/fixture-manifest.json)의 기존67개 소스를 변경하지 않고 신규 검사/프리뷰2개를 포함한69개 소스의 전후 SHA를 유지한다. [BEFORE 게이트](/private/tmp/clipback-account-alignment-20261018/before-gate.json)에서 기준 커밋 제품·새 원본4장·동일 조건·오류0·직접 시각 확인을 검사한 뒤 **2026-10-17 17:34:48 UTC**에 제품을 적용했다. 제품 변경은 해당 화면과 원형 배경 SVG에 한정한다.
- AFTER 집중 **14/14**, 관련 **266/266**, 전체 **1265/1265** 통과(실패/건너뜀0), `flutter analyze --no-pub` 문제0이다([집중](/private/tmp/clipback-account-alignment-20261018/tests/focused-after-summary.json)·[관련](/private/tmp/clipback-account-alignment-20261018/tests/related-after-summary.json)·[전체](/private/tmp/clipback-account-alignment-20261018/tests/all-after-summary.json)·[분석](/private/tmp/clipback-account-alignment-20261018/tests/analyze-after-summary.json)). 실제 Pretendard·iOS/Android 테마×320/375px×1배율의 스타일/기하/에셋·일반 행41px·긴 문구·isGuest3값×busy2값·읽기 전용 행·콜백·낮은 viewport의 마지막 행/24px/OS 여백을 확인했다. 관련 인증·사용자 매핑·누적 통계·세션·안전영역·기존 확대 검사를 유지했고 기존 J02 본문 확대 검사가 없다는 점을 새 확대 성공으로 바꾸지 않는다.
- [AFTER 실제 루트 앱 별도 검사](/private/tmp/clipback-account-alignment-20261018/tests/fixture-probe-after-summary.json)1테스트/회원·게스트2상태에서 실제 스타일/레이아웃/에셋 true·프레임워크 오류0을 확인했다. 동결 소스를 수정하지 않은 [긴 문구 별도 검사](/private/tmp/clipback-account-alignment-20261018/tests/long-copy-after-summary.json)도 양 플랫폼2건 통과했다. 폭320px/1배율에서 계정 문구14px·softWrap true·3줄51px/행75px, 이름20px·가운데 정렬·2줄48px으로 필요한 높이 증가를 실측했다.

<a id="b-c608591c2d0c0795"></a>

### 양 플랫폼 실행과 새 비교

<a id="b-a4fef8684a1d3a6e"></a>

| 플랫폼 | 실제 논리창 / DPR | OS 상·하 여백 | AFTER 본문 viewport | 본문 스크롤 전→후 | AFTER 동작 |
| --- | --- | --- | --- | --- | --- |
| iPhone16 / iOS18.6 | 393×852px /3.0 | 59/34px | 695px | 비스크롤→최대0px(무스크롤) | 16기록·전체통과/오류0 |
| Android13 / API33 제스처 | 392.7×783.3px /2.75 | 24/0px | 695.273px | 비스크롤→최대0px(무스크롤) | 16기록·전체통과/오류0 |

<a id="b-3db4a219c93db600"></a>

- [변경 전→후→Figma4쌍](/private/tmp/clipback-account-alignment-20261018/comparison-document.html)·[동일 조건/실측 판정](/private/tmp/clipback-account-alignment-20261018/pair-verification.json)에서 회원/게스트×두 플랫폼의 새 OS 원본8장을 비교했다. 같은 기종·데이터·1배율·키보드 숨김·scroll0이며 실제 OS 여백과 Figma375×812px/상태 프레임50px, 기존 PhoneFrame 폭 최대375px의 차이를 보정하지 않는다. 실제 시각/상태바·다이내믹 아일랜드(기존 iOS 게스트 BEFORE의 검은 pill 포함)는 OS 원본 그대로 유지했다. 원본은 카카오 회원 예제이며 게스트 전용 원본은 아니다. 헤더/아바타/크롭/글자/행/에셋/여백의 실제 경계와 전체 판정을 연결했고 수정 영역의 의도하지 않은 잘림/겹침·팝업·공유 배너는0이다.
- 개요: [iOS](/private/tmp/clipback-account-alignment-20261018/comparisons/ios-comparison-overview.png)·[Android](/private/tmp/clipback-account-alignment-20261018/comparisons/android-gesture-comparison-overview.png). AFTER 영상: [iOS](/private/tmp/clipback-account-alignment-20261018/ios/after/interaction.mp4)·[Android](/private/tmp/clipback-account-alignment-20261018/android-gesture/after/interaction.mp4). [영상 검사](/private/tmp/clipback-account-alignment-20261018/media-verification.json)에서 두 원본의 SHA·시작/종료와 중간 동작·전체 디코딩/녹화 완료를 확인했다. 원본 편집0·디코딩 실패0이며 녹화의 대기시간을 인코딩된 영상 길이에 임의 합산하지 않는다.
- 양 플랫폼에서 실제 루트 앱의 마이 두 진입점/헤더 복귀, 읽기 전용 계정 행·탈퇴 미지원 안내·스크롤, 게스트 연결 화면 진입/취소 후 계정/통계 보존, 로그아웃 대기/잠금/중복 방지·실패 후 원복/재시도·성공 후 로그인과 최종 회원 J02 재진입을 확인했다. 각16기록의 스타일/레이아웃/에셋/동작/커버리지/전체 `passed:true`·프레임워크 오류0이다. 회원 logout 요청0, 게스트2회(실패503→성공204), 모든 세션의 예상 밖 요청/콘텐츠 쓰기0·콘텐츠6건 유지다. 실제 계정 연결/OAuth 성공을 의미하지 않는다. 정상 네이티브 최대 스크롤0은 무스크롤로 기록하며 낮은 viewport의 끝24px/마지막 행 접근은 별도 위젯 검사로 확인했다.
- Android 초기 BEFORE 원본2장은 System UI 응답 없음 팝업으로 채택하지 않고 `.attempts/android-before-systemui-popup`에 보존했다. 당시 Wait2회 뒤 XML은 정상이었으나 PNG에 팝업이 재등장했으며 정확한 원인은 미확정이다. 초기 escape 가설을 철회하고 새 기동·재촬영·직접 시각 확인을 거친 최종2장은 추가 Wait0·팝업0이다. 해당 시도를 성공 비교에 포함하지 않는다([환경 정정 기록](/private/tmp/clipback-account-alignment-20261018/native-ui-recovery-amendment.json)).
- [네이티브 실측/시나리오 요약](/private/tmp/clipback-account-alignment-20261018/native-validation-summary.json)·[비교 시각 검토](/private/tmp/clipback-account-alignment-20261018/comparison-visual-review.json)·[HTML 검사](/private/tmp/clipback-account-alignment-20261018/comparison-html-verification.json)를 확인했다. [환경 정리](/private/tmp/clipback-account-alignment-20261018/cleanup-verification.json)는 소유 앱/시뮬레이터/에뮬레이터·포워딩·ADB를 종료하고8767/8768 포트가 닫혔음을 확인한다. 탐색/키보드 설정 변경0·기기 wipe/앱 uninstall0·임시 비교 HTTP서버 없음이며 증거는 Git 밖에 보존한다.

<a id="b-43d5cc6a4c41f2d5"></a>

**검증 한계와 후속:** 실제 ClipbackApp/Repository를 HTTP MockClient·메모리 세션/공유 채널 대역·합성 입력으로 실행하는 로컬 검증이다. 최초 실행부터 native share를 격리하며 기존 큐/자격 내용의 조회·출력·삭제를 하지 않는다. 실제 OAuth·운영 서버/설정·영속 저장·실기기·원격 CI는 미검증이다. 카카오 포함 공급자 배지/브랜드·원본 없는 게스트/미확인 등 상태별 표현·실제 연결 상태 계약·재확인 중복 방지·탈퇴 API·시스템 뒤로가기·새 확대 맞춤은 후속이다. J01의 약관/실제 운영 연결·네이티브 버전 조회 보류도 유지한다.

<a id="b-d69d55c8a4c712ff"></a>

계정 관리 전용 프리뷰는 [account_preview.dart](../../frontend/test/support/account_preview.dart)입니다. 실제 루트 앱의 마이에서 계정 관리로 진입하며 첫 실행부터 네이티브 공유 큐/자격과 격리된 메모리 API·세션을 사용합니다. 다음으로 빌드하고 소유 검증 기기에 설치/실행합니다. 앱 내부 loopback8767의 `/scene?kind=member`·`/scene?kind=guest`는 고정1배율·키보드 숨김·스크롤0의 정적 상태를 준비하며 `/state`·`/status`는 실제 스타일·경계·상태를 읽습니다. `/run`은 두 마이 진입점/헤더 복귀·읽기 전용 행·탈퇴 안내·스크롤·게스트 연결 취소·로그아웃 대기/중복 방지/실패/재시도/성공·최종 회원 J02 판정을 검사합니다. Android8768→8767 포워딩은 검증 뒤 제거합니다. `ACCOUNT_PHASE=before`는 이번 기준 제품의 동결 BEFORE 전용이며 AFTER 빌드를 이름만 바꿔 사용하지 않습니다.

<a id="b-84c554ac83aca1ef"></a>

```bash
flutter build ios --debug --no-pub --simulator -t test/support/account_preview.dart --dart-define=ACCOUNT_PHASE=after
flutter build apk --debug --no-pub -t test/support/account_preview.dart --dart-define=ACCOUNT_PHASE=after
flutter test --no-pub test/account_management_alignment_test.dart
```
