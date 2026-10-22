# 공지 목록 표현과 복귀

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-c0ed255138c46cfb"></a>

### 공지사항 목록의 1배율 맞춤 — 2026-10-18 작업

<a id="b-3fbca00226238809"></a>

`56721f9` 기준 K01의 승인된1배율 **읽기 전용 공지 목록과 마이 왕복**을 적용했습니다. 기존 mock 제목3개와 순서, 최소79px/내부16px/행 간격8px/본문끝24px·긴 제목의 전체 자연 줄바꿈을 사용합니다. 헤더64px·뒤로24px/터치48px·중앙+0.5px과 실제 SafeArea 한 번을 적용합니다. 게시일/핀/화살표·상세·새 API는 추가하지 않습니다.

<a id="b-1c58e58401ed3a5b"></a>

- [K01 `111:4592`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4592)의 계획 조회17:10:48~17:10:54 KST와 구현 **2026-10-18 17:18:42~17:18:47 KST**를 구분합니다. 구현1회로375×812px 원본/컨텍스트를 확보하고 기존 뒤로SVG를 정확한 원본과 대조·재사용했습니다([출처](/private/tmp/clipback-notice-alignment-20261018/figma/reference-manifest.json), [대조](/private/tmp/clipback-notice-alignment-20261018/figma/back-reuse-audit.json)).
- [NoticeListScreen](../../frontend/lib/features/account/notice_list_screen.dart)·`AppRoute.noticeList`와 My의 선택적 `onOpenNotices`를 연결합니다. 실제 루트는4시트+별도 공지, callback 미주입 My는 기존5시트 fallback입니다. My 위치는 공지 왕복에서만 보존하고 다른 경로/계정·authEpoch·복구/오류·세션 clear 경계에서 초기화합니다. 오래된 callback은 캡처 generation/epoch·현재route/세션/처리 상태를 다시 검사합니다. API/모델·기존 인증/세션·공유 보안 정책은 유지합니다.
- **재현/자동 검사:** 최초 제품 수정 전17:32경의 양 플랫폼 시트 원본은 보존합니다. 도구 보완 후 기준 제품diff0으로 재현한 새 BEFORE는 iOS17:49:07·Android17:52:00~01 KST, 각29동작true/오류0·prompt 차단 없음입니다([게이트](/private/tmp/clipback-notice-alignment-20261018/product-edit-gate.json)). 제품4파일은17:52:20 KST에 기존 최종본과 같은bytes로 복원했습니다([일치](/private/tmp/clipback-notice-alignment-20261018/corrected-tool-final-restore.json)). 재동결 기준 제품10건은4통과/K01 부재6목표 실패, AFTER는 스타일/긴 문구/독립back12+이동/보안5+대역 계약3=**20/20통과**입니다([최종 집중](/private/tmp/clipback-notice-alignment-20261018/tests/after-target-refrozen-contract.log)). [최종 검증 요약](/private/tmp/clipback-notice-alignment-20261018/tests/validation-summary.json)의 최종 전체는 **1387/1387건·실패/건너뜀0·1분27초/exit0**, 분석은 **문제0·3.5초/exit0**입니다([전체](/private/tmp/clipback-notice-alignment-20261018/tests/flutter-test-final.log), [분석](/private/tmp/clipback-notice-alignment-20261018/tests/flutter-analyze-final.log)).
- **기기:** iPhone16/iOS18.6·Android13/API33 제스처의 AFTER 각30기록은 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0·공유 배너/팝업 없음입니다([iOS](/private/tmp/clipback-notice-alignment-20261018/ios/after/report.json), [Android](/private/tmp/clipback-notice-alignment-20261018/android/after/report.json)). 실제 창393×852/safe59·34와392.727×783.273/safe24·0에서 각79px 행3개·21px 문단·8px 간격·64px 헤더/48px hit를 확인했습니다. 기본 공지 최대 스크롤0·My 위치0→0이고, 비0 복원과 낮은 화면의 마지막24px은 위젯 검사입니다. Android 실제 keyevent4도 요청 증가 없이 복귀했으며 iOS는 프레임워크 Pop입니다.
- **증거/정리:** [기존 시트→새 목록→Figma2쌍](/private/tmp/clipback-notice-alignment-20261018/comparison-document.html)·[iOS](/private/tmp/clipback-notice-alignment-20261018/comparisons/ios-notice.png)·[Android](/private/tmp/clipback-notice-alignment-20261018/comparisons/android-notice.png)은 새 원본/동일 데이터·1배율/키보드 숨김/스크롤0이며 직접 대응하는 기존 K01 화면은 없음을 명시합니다. AFTER [iOS35.646667초](/private/tmp/clipback-notice-alignment-20261018/ios/after/actions.mp4)·[Android51.900044초](/private/tmp/clipback-notice-alignment-20261018/android/after/actions.mp4)의 [전체 디코딩/녹화](/private/tmp/clipback-notice-alignment-20261018/media-verification.json), [번들263/263](/private/tmp/clipback-notice-alignment-20261018/bundleverification.json), [환경 정리](/private/tmp/clipback-notice-alignment-20261018/cleanup-verification.json)를 확인했습니다. 소유 기기/ADB·포트 종료·제스처2 유지·설정/사용자 데이터 변경0이며 증거/빌드/AGENTS.md는 Git에서 제외합니다. [증거 요약](/private/tmp/clipback-notice-alignment-20261018/evidence-summary.json)은 현재 빌드 소스272개 SHA·가져온 도구31개의 BEFORE/AFTER 일치·HTML 로컬30/30링크를 기록합니다. [영상 프레임 검사](/private/tmp/clipback-notice-alignment-20261018/video-frame-review.json)도 통과했으며 영상의 반복 A01은 독립 대역 앱 생성 구간입니다.
- **시도/한계:** 첫17/1384·분석0은 [당시 기록](/private/tmp/clipback-notice-alignment-20261018/.attempts/initial-tools-automated-checks/manifest.json)입니다. 게스트 사용자/공유 자격 소유자 대역 불일치→기존 오류 배너의 헤더 가림은 대역/프리뷰를 수정해 양 플랫폼을 재촬영했고 제품의 공유 보안을 우회하지 않았습니다. Android 첫 OS 응답 없음과 대역/하네스 실패는 보존합니다. 기존 소개3장의320×480px 아래297px 넘침은 수정하지 않고 인증/소개만812px·My/공지480px으로 분리해 검사했습니다. 실제 공지/상세·운영 문안·새 확대·OAuth/운영 서버/실기기/CI는 후속/미검증입니다. 상세 실측·시도는 [계획](../figma-ui-alignment-plan.md)의 K01 기록을 따릅니다.

<a id="b-d7f15afb7d40142a"></a>

### 공지사항 재현 명령

<a id="b-8b23c27d7eda1fe9"></a>

```sh
flutter test --no-pub test/notice_list_figma_test.dart test/notice_list_content_test.dart test/notice_navigation_test.dart test/notice_fixture_contract_test.dart
flutter test --no-pub
flutter analyze --no-pub
flutter run --no-pub -t test/support/notice_alignment_preview.dart --dart-define=NOTICE_PHASE=after -d <device-id>
```

<a id="b-d39e3fbbd631d6b1"></a>

프리뷰는 실제 ClipbackApp·메모리 API/세션과 최초 실행부터의 공유 격리를 사용합니다. `/scene?kind=member`는 정적 목록/기준 시트, `/max-scroll`은 본문 끝, `/run`은 회원·게스트/기존4시트/계정·관리/탭·저장 닫기/세션 무효화 검사입니다. 같은 동결 도구를 기준 제품과 수정 제품에 각각 빌드하며 phase 이름만 바꿔 BEFORE를 대신하지 않습니다. 공유 준비 종료·오류/초안 없음과 실제 스타일/경계/에셋/동작을 전체 판정에 연결합니다. 운영 서버/계정으로 실행하는 도구가 아닙니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-dff47a596dcdded3"></a>

직전 `56721f9` 기준 작업은 **K01 공지사항 목록의 승인된1배율 표현과 마이 왕복**입니다. 기존 mock 제목3개와 순서를 읽기 전용으로 보존하고 최소79px 행·자연 줄바꿈·별도64px 헤더를 적용합니다. My 스크롤은 공지 왕복에서만 유지하며 다른 경로와 계정/보안 경계에서는 초기화합니다. **재동결 집중20/전체1387·분석0·양 플랫폼 각30기록/전체true·오류0·새2쌍/영상2개·번들263/263·환경 정리를 확인했습니다.** 실제 결과는 아래 독립 기록을 따릅니다. 날짜/핀/화살표/상세·새 API와 운영 공지 기능은 후속입니다.

<a id="b-66f1e2b85b2eb76d"></a>

`56721f9` 기준 K01의 승인된1배율 **읽기 전용 별도 공지 목록과 마이 왕복**을 적용했습니다. 기존 mock 제목3개/순서·최소79px/내부16px/간격8px/본문끝24px·긴 제목 전체 자연 줄바꿈을 사용하며 날짜/핀/화살표/상세·새 API는 추가하지 않습니다. 실제 루트는4시트+별도 공지이며 My callback 미주입은 기존5시트 fallback을 유지합니다. My 위치는 공지 왕복에서만 보존하고 다른 경로/계정·인증epoch·복구/오류/세션 clear 경계에서는 초기화합니다.

<a id="b-79514c9e992f320d"></a>

- **원본:** [K01 `111:4592`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4592)의 계획17:10:48~17:10:54 KST·구현 **2026-10-18 17:18:42~17:18:47 KST** 조회를 구분합니다. 구현1회로375×812px 원본/컨텍스트를 확보하고 기존 뒤로SVG를 대조·재사용했습니다([출처](/private/tmp/clipback-notice-alignment-20261018/figma/reference-manifest.json)). 헤더64px·원본뒤로24px/터치48px·중앙+0.5px·최대375px/실제 SafeArea 한 번을 적용하고 API/Repository/모델·공유/세션 정책은 유지합니다.
- **BEFORE/집중:** 최초 제품 수정 전17:32경 시트 원본은 보존하며 도구 보완 후 기준 제품diff0으로 새 BEFORE를 재현했습니다. iOS17:49:07·Android17:52:00~01 KST의 각29동작true/오류0·prompt 차단 없음이고 K01 부재의 목표false는 그대로 남깁니다([게이트](/private/tmp/clipback-notice-alignment-20261018/product-edit-gate.json)).17:52:20 KST에 제품4파일을 기존 최종본과 같은bytes로 복원했습니다([일치](/private/tmp/clipback-notice-alignment-20261018/corrected-tool-final-restore.json)). 재동결 기준 제품10건=4통과/부재6목표 실패, AFTER 집중 **20/20**(스타일/긴 문구/독립back12·이동/보안5·대역 계약3)을 통과했고 [최종 검증 요약](/private/tmp/clipback-notice-alignment-20261018/tests/validation-summary.json)의 최종 전체는1387/1387건(1분27초/exit0)·분석0(3.5초/exit0)입니다([전체](/private/tmp/clipback-notice-alignment-20261018/tests/flutter-test-final.log), [분석](/private/tmp/clipback-notice-alignment-20261018/tests/flutter-analyze-final.log), [집중](/private/tmp/clipback-notice-alignment-20261018/tests/after-target-refrozen-contract.log)).
- **native:** iPhone16/iOS18.6·Android13/API33 제스처의 각30기록은 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0·공유 prompt 차단 없음입니다([iOS](/private/tmp/clipback-notice-alignment-20261018/ios/after/report.json), [Android](/private/tmp/clipback-notice-alignment-20261018/android/after/report.json)). 실제 원본에 OS 팝업/오류 배너가 없음을 확인했습니다. 행3개 각79px·문단21px/간격8px·헤더64px/hit48px이며 기본 최대 스크롤0·My 위치0→0입니다. 비0 복원/낮은 viewport의 마지막24px은 위젯 검사로 구분하며 Android 실제 keyevent4 복귀도 추가 요청0입니다.
- **증거:** [기존 시트→새 목록→Figma2쌍](/private/tmp/clipback-notice-alignment-20261018/comparison-document.html)·[iOS](/private/tmp/clipback-notice-alignment-20261018/comparisons/ios-notice.png)·[Android](/private/tmp/clipback-notice-alignment-20261018/comparisons/android-notice.png)은 실제 OS 원본/같은 데이터·1배율/스크롤0입니다. 직접 대응하는 기존 K01은 없으며 기존 시트와 비교합니다. AFTER [iOS35.646667초](/private/tmp/clipback-notice-alignment-20261018/ios/after/actions.mp4)·[Android51.900044초](/private/tmp/clipback-notice-alignment-20261018/android/after/actions.mp4)의 [전체 디코딩/녹화](/private/tmp/clipback-notice-alignment-20261018/media-verification.json)·[번들263/263](/private/tmp/clipback-notice-alignment-20261018/bundleverification.json)·[환경 정리](/private/tmp/clipback-notice-alignment-20261018/cleanup-verification.json)를 확인했습니다. 소유 기기/ADB·포트 종료·제스처2 유지·설정/사용자 데이터 변경0이며 증거/빌드/AGENTS.md를 커밋에서 제외합니다. [증거 요약](/private/tmp/clipback-notice-alignment-20261018/evidence-summary.json)·[영상 프레임 검사](/private/tmp/clipback-notice-alignment-20261018/video-frame-review.json)는 실제 소스/도구 일치·2비교/영상·시각 확인을 기록합니다. 반복 A01은 독립 대역 앱 생성 구간입니다.
- **시도/후속:** 첫17/전체1384·분석0은 [당시 기록](/private/tmp/clipback-notice-alignment-20261018/.attempts/initial-tools-automated-checks/manifest.json)입니다. 게스트 대역 사용자/공유 소유자 불일치가 만든 기존 오류 배너·Android 첫 OS 응답 없음과 대역/하네스 시도는 분리 보존하고 대역을 보완해 재촬영했습니다. 기존 소개3장의320×480px 아래297px 넘침은 수정하지 않고 인증/소개만812px·My/공지480px으로 분리해 검사했습니다. 원본 없는 소개·운영 공지/게시일/고정·K02/K03 상세·리마인드/문의/약관·새 확대·실제 OAuth/운영 서버/실기기/CI는 후속/미검증이며 공지 전체 기능 완료로 표시하지 않습니다. 상세 실측·정책·명령은 [계획](../figma-ui-alignment-plan.md)·[프론트 README](../../frontend/README.md)의 K01 기록을 따릅니다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-ea0e00f19b660f8e"></a>

> `56721f9` 기준 K01의 승인된1배율 목록과 마이 왕복을 적용했다. **재동결 도구의 집중20/전체1387·분석0, 양 플랫폼 각30기록의 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0·새2쌍/영상2개·환경 정리를 확인했다.** 실제 공지 데이터/상세 기능 완료를 뜻하지 않는다.

<a id="b-2b2846c5d3333b01"></a>

### 기준·구현·이동 경계

<a id="b-f42817129aee2b01"></a>

- 기준은 Page 1 >261007의 [K01 `111:4592`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-4592)다. 계획 조회 **2026-10-18 17:10:48~17:10:54 KST**와 구현 조회 **17:18:42~17:18:47 KST /08:18:42~08:18:47 UTC**를 구분한다. 구현 `get_design_context`1회로375×812px 컨텍스트/원본을 확보했다([출처](/private/tmp/clipback-notice-alignment-20261018/figma/reference-manifest.json), [컨텍스트](/private/tmp/clipback-notice-alignment-20261018/figma/K01-context.json), [원본](/private/tmp/clipback-notice-alignment-20261018/figma/K01-original.png)). 기존 뒤로가기 SVG는 정확한 원본과 대조해 필터 없이 재사용했고 새 에셋/전체 화면 이미지/가짜 OS 표시는 추가하지 않았다([대조](/private/tmp/clipback-notice-alignment-20261018/figma/back-reuse-audit.json)).
- [공지 목록](../../frontend/lib/features/account/notice_list_screen.dart)은 최대375px·배경`#F5F5F5`·실제 SafeArea 한 번·고정64px 헤더와 스크롤 본문을 사용한다. 뒤로24px·좌16px·제목 앞8px·48×48px 터치 영역·헤더 내용 중앙+0.5px을 적용한다. 헤더는 Pretendard18px/SemiBold·자간−0.45px·검정·AUTO, 제목은18px/Medium·−0.45px·`#1A1A1A`·AUTO다. 흰 행은 가용 폭 전체·최소79px·내부16px·행 사이8px이며 첫 행은 헤더 바로 아래, 본문 끝은24px이다. 긴 제목은 축소/말줄임 없이 전체 원문을 자연 줄바꿈하고 행 높이를 늘린다.
- 기존 mock 제목3개와 순서·읽기 전용을 유지한다. 원본의 날짜·핀·화살표/상세 목적지를 임의로 채우지 않는다. [루트](../../frontend/lib/app/clipback_app.dart)의 `AppRoute.noticeList`와 [MyScreen](../../frontend/lib/features/account/my_screen.dart)의 선택적 `onOpenNotices`를 연결한다. 실제 루트는 기존4시트(리마인드/권한/문의/버전)+별도 공지이며 callback 미주입 My는 기존5시트 fallback이다. 헤더/OS 뒤로는 요청 없이 마이로 복귀하고 하단 탭은 추가하지 않는다. 기존 필수 콜백·API/Repository/모델·공유/세션 정책은 유지한다.
- My 전용 `PageStorageBucket`과 `PageStorageKey('my-scroll')`로 **My↔공지 왕복에서만** 위치를 보존한다. 다른 경로·accountGeneration/authEpoch·복구/오류·세션 부재/pendingSessionClear 경계에서는 bucket을 교체하며 `ObjectKey(bucket)`으로 이전 position의 쓰기를 분리한다. 이동 콜백은 build 시 generation/epoch를 캡처하고 실행 시 mounted·현재route·busy/복구/오류·hasSession/pendingSessionClear를 재검사한다. 일반 마이 복원이나 새 인증 정책을 추가하지 않는다.

<a id="b-9a1cfb86d0200ae2"></a>

### 실제 재현과 최종 검사

<a id="b-35502ff8a0f17500"></a>

- **BEFORE와 제품 게이트:** 최초 제품 수정 전17:32경 양 플랫폼 기존 NoticeSheet 원본/각29동작을 확보했다([최초 보관](/private/tmp/clipback-notice-alignment-20261018/.attempts/after-guest-return-anr-1/product-edit-gate.json)). 도구 보완 후17:46:00 KST에 제품을 정확한56721f9 기준(diff0)으로 재현하고([기준 복원](/private/tmp/clipback-notice-alignment-20261018/corrected-tool-baseline-swap.json)), 새 도구로 iOS **17:49:07**·Android **17:52:00~17:52:01 KST**의 기존 시트를 다시 촬영했다. 새 BEFORE 각29기록은 동작true·프레임워크 오류0·공유 prompt 차단 없음이며 K01 부재의 스타일/레이아웃/에셋/전체false는 보존한다([새 게이트](/private/tmp/clipback-notice-alignment-20261018/product-edit-gate.json)). 새 화면의 가짜 BEFORE를 만들지 않았다. 17:52:20 KST에 제품4파일을 처음 최종 빌드/검사와 같은bytes로 복원했다([복원 일치](/private/tmp/clipback-notice-alignment-20261018/corrected-tool-final-restore.json)). 최초 수정 전 촬영과 도구 보완 후 기준 제품 재현 촬영을 구분한다.
- **자동 검사:** 재동결 도구의 기준 제품 스타일7+계약3=10건은4통과(폰트1+계약3)/K01 부재6목표 실패다([BEFORE](/private/tmp/clipback-notice-alignment-20261018/tests/before-target-refrozen-contract.log)). 최초 이동5건은 세션 복구→낮은 My 실스크롤→공지 탭 후 새 화면 부재만 재현했다. AFTER는 스타일/기하/긴 제목/독립 back12·루트 이동/보안5·대역 계약3의 **20/20건 통과**다([최종 집중](/private/tmp/clipback-notice-alignment-20261018/tests/after-target-refrozen-contract.log)). 실제 Pretendard·iOS/Android×320/375px×1배율·낮은 viewport 실드래그/마지막24px·긴 제목 전체 표시, 비0 My 복원/다른 경로 초기화·새 계정/무효화·pending clear의 old/rebuilt back 차단을 확인한다. 긴 제목/독립 back5건은 새 생성자가 필요한 AFTER 추가 검사다. 기존 인증/세션·공유·안전 영역·확대 회귀를 유지했다. 최종 `flutter test --no-pub`는 **1387/1387건·실패/건너뜀0·1분27초/exit0**([원본](/private/tmp/clipback-notice-alignment-20261018/tests/flutter-test-final.log)), `flutter analyze --no-pub`는 **문제0·3.5초/exit0**다([원본](/private/tmp/clipback-notice-alignment-20261018/tests/flutter-analyze-final.log)). 새 계약3건을 포함한 재실행 결과이며 첫1384건을 이번 성공으로 재사용하지 않는다. [최종 검증 요약](/private/tmp/clipback-notice-alignment-20261018/tests/validation-summary.json)은 집중/전체/분석·양 플랫폼/동일 제품 소스·환경 정리의 실제 통과를 함께 기록한다.
- **양 플랫폼 실행:** iPhone16/iOS18.6·Android13/API33 제스처에서 각30기록의 스타일/레이아웃/에셋/동작/전체true·프레임워크 오류0·공유 prompt 차단 없음이다([iOS](/private/tmp/clipback-notice-alignment-20261018/ios/after/report.json), [Android](/private/tmp/clipback-notice-alignment-20261018/android/after/report.json)). 회원/게스트의 진입·세 제목 읽기 전용/요청 없음·헤더/프레임워크 Pop 복귀, 기존4시트/계정/관리·네 탭·추가 저장 없는 닫기·세션 무효화 뒤 오래된 back 차단·최종 재진입을 확인했다. Android의 실제 `keyevent4`도 마이 복귀/요청 증가0을 확인했다([OS Back](/private/tmp/clipback-notice-alignment-20261018/android/after/native-os-back.json)). iOS는 프레임워크 Pop 전달이다. 실제 기기의 My 위치는0→0만 관찰했고 비0 복원은 낮은 viewport 위젯 검사로 별도 증명한다. 기본 공지 최대 스크롤0도 무스크롤로 기록하며 낮은 화면의 마지막24px 접근과 구분한다.

<a id="b-515fd33eba849c4b"></a>

| 플랫폼 | 실제 논리창 / DPR / 상·하 안전 여백 | 375px 프레임 left / 헤더 높이 | 본문 viewport / 행3개 / 문단 / 간격 | 최대 스크롤 |
| --- | --- | --- | --- | --- |
| iPhone16 / iOS18.6 | 393×852px /3 /59·34px | 9px /64px | y123~818px /각79px /21px /8px | 0px |
| Android13 / API33 제스처 | 392.727×783.273px /2.75 /24·0px | 8.864px /64px | y88~783.273px /각79px /21px /8px | 0px |

<a id="b-cc88fc1f9d813152"></a>

- 두 플랫폼의 최종 OS 원본을 직접 대조해 팝업/배너·의도하지 않은 잘림/겹침 없음을 확인했다. OS 창/안전 여백·예제 문구·날짜/핀/화살표/상세 보류는 원본과의 차이로 설명하며 원본을 보정하지 않는다. **기존 시트→새 목록→Figma2쌍**은 [비교 문서](/private/tmp/clipback-notice-alignment-20261018/comparison-document.html)·[iOS](/private/tmp/clipback-notice-alignment-20261018/comparisons/ios-notice.png)·[Android](/private/tmp/clipback-notice-alignment-20261018/comparisons/android-notice.png)에서 확인한다. 기존 시트와 새 목록은 같은 회원 데이터/1배율·키보드 숨김·스크롤0이며 직접 대응하는 기존 K01 화면은 없음을 명시한다. 원본/구성은 [비교 명세](/private/tmp/clipback-notice-alignment-20261018/comparison-manifest.json)를 따른다.
- AFTER 영상은 [iOS35.646667초](/private/tmp/clipback-notice-alignment-20261018/ios/after/actions.mp4)·[Android51.900044초](/private/tmp/clipback-notice-alignment-20261018/android/after/actions.mp4)이며 [전체 디코딩/녹화 검사](/private/tmp/clipback-notice-alignment-20261018/media-verification.json)의 원본 SHA·decode/녹화 exit0을 확인했다. [채팅용 재생본](/private/tmp/clipback-notice-alignment-20261018/chat-preview-manifest.json)은960px/30fps 표시용이며 원본을 보존한다. 원본/재생본 전체 디코딩과 시작/중간/종료 및 추가44프레임의 [시각 검사](/private/tmp/clipback-notice-alignment-20261018/video-frame-review.json)를 확인했다. 영상의 A01/반복 시작 구간은 독립 회원/게스트 대역을 새 ClipbackApp으로 만드는 검사 준비이며 제품의 공지 왕복에서 스플래시가 재생된다는 뜻은 아니다. [실제 iOS/APK 번들263/263](/private/tmp/clipback-notice-alignment-20261018/bundleverification.json)과 [환경 정리](/private/tmp/clipback-notice-alignment-20261018/cleanup-verification.json)를 확인했다. 소유 iOS/Android 종료·제스처2 유지·5037/8767/8768/8769 포트 닫힘·설정 변경/사용자 데이터 삭제0·호스트 임시 HTTP 서버 실행 없음이다. [최종 증거 요약](/private/tmp/clipback-notice-alignment-20261018/evidence-summary.json)은 빌드 소스272개 SHA의 현재 일치와 가져온 도구 소스31개의 BEFORE/AFTER 동일·HTML 로컬30/30링크/2비교·미디어/정리의 실제 결과를 기록한다.

<a id="b-78951adbbdcfcc3a"></a>

### 이전 시도와 후속

<a id="b-b9ee4aef7f3d1b53"></a>

- 첫 도구의17/전체1384·분석0은 [당시 자동 기록](/private/tmp/clipback-notice-alignment-20261018/.attempts/initial-tools-automated-checks/manifest.json)으로 보존하고 새 도구의 최종 결과와 구분한다. 게스트 프로필ID2/공유 자격user_id1 불일치가 기존 공유 오류 배너와 헤더 가림을 만든 원인을 계약3건의1통과/2실패로 재현한 뒤 수정·3통과시켰다([재현](/private/tmp/clipback-notice-alignment-20261018/tests/before-fixture-contract.log), [수정](/private/tmp/clipback-notice-alignment-20261018/tests/after-fixture-contract.log)). 제품의 공유 보안을 완화하지 않고 대역을 수정했으며 프리뷰는 준비 종료·오류/초안 없음과 매 기록의 prompt 차단 여부를 전체 판정에 연결했다. 첫 Android OS 응답 없음 팝업도 [실패 시도](/private/tmp/clipback-notice-alignment-20261018/.attempts/after-guest-return-anr-1/attempt.json)로 보존하고 원인을 부하 등으로 확정하지 않는다. 초기 대역 컴파일/MockClient 재-finalize·지연 생성 행의 스크롤 하네스 시도도 `.attempts`에 분리했다.
- 첫 AFTER 이동 검사에서 기존 소개3장이320×480px에서 아래297px RenderFlex 넘침을 보였다. 원본이 없는 소개 제품을 수정하거나 예외를 무시하지 않았고, 인증/소개 구간만812px로 실행한 뒤 My/공지480px으로 되돌려 검사했다([실패 원본](/private/tmp/clipback-notice-alignment-20261018/.attempts/navigation-low-legacy-intro/after-navigation.log)). 낮은 소개 화면의 통과로 보고하지 않는다. 운영 공지 데이터·게시일/고정 여부·K02/K03 미작성 상세·리마인드/문의/약관 운영 문안·새 확대·실제 OAuth/운영 서버/실기기·원격CI는 후속/미검증이며 공지 전체 기능 완료로 표시하지 않는다. 화면 증거·빌드·AGENTS.md는 Git 밖에 유지하고 푸시/PR은 하지 않는다.
