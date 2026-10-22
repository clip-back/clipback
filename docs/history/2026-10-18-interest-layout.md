# 관심사 선택 표현

- 최초 기록일: 2026-10-18
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-855c7f6e6b2d3d08"></a>

### 관심사 선택 화면의 1배율 맞춤 — 2026-10-18 작업

<a id="b-2464b0466229c337"></a>

> `2a3c912` 기준 B02·B03·B04의 승인된1배율 표현과 화면 안 선택 동작을 적용하고 자동·양 플랫폼 실행을 검증했다. 제품 수정 전 새 BEFORE·컴파일 가능한 재현 검사11건(1통과/목표 차이10실패)을 확보했다. **집중20/전체1337·분석0과 양 플랫폼 각16기록·스타일/레이아웃/에셋/동작/전체true·오류0을 확인했다. 새 비교6쌍·영상2개/전체 디코딩·환경 정리를 확인했다.** A01 iOS 네이티브 정적 불투명/색상 미검증과 이전 기록은 그대로 유지한다.

<a id="b-0e6f7c2199a09c51"></a>

### 기준·표현·승인된 선택 동작

<a id="b-f92657d0d7d87508"></a>

- 기준은 Page 1 > `261007`의 [B02 선택 전 `111:3530`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3530)·[B03 선택 후 `111:3546`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3546)·[B04 개수 초과 `111:3562`](https://www.figma.com/design/svNWsTFh8Ws1Mpt8XQIcrN/?node-id=111-3562)다. 계획 조회 **2026-10-18 13:45:21~13:45:28 KST**와 구현 재조회 **13:51:22~13:51:27 KST /04:51:22~04:51:27 UTC**를 구분한다. 구현 재조회는 `get_design_context` **3회**로375×812px 원본/컨텍스트를 모두 확보했다([B02](/private/tmp/clipback-interest-alignment-20261018/figma/B02.json)·[B03](/private/tmp/clipback-interest-alignment-20261018/figma/B03.json)·[B04](/private/tmp/clipback-interest-alignment-20261018/figma/B04.json)). 추가 메타데이터/스크린샷 호출·Figma 쓰기·대체 원본은 없다.
- **글자:** 기존 두 줄 제목은 실제 Bold 파일의 `PretendardDetail`24px/700·자간−0.6px·`#1A1A1A`·행간1.6, 기존 안내는 Pretendard16px/Medium·−0.4px·`#767676`·1.5다. 선택 행은16px/Medium·−0.4px·`#1A1A1A`·AUTO, 다음은16px/SemiBold·자간0·22px 행간이다. 새로운 전역 테마/폰트 등록 없이 기존 Pretendard/실제 Bold를 재사용한다.
- **본문:** 기존 PhoneFrame 최대375px·실제 SafeArea 한 번을 유지한다. 제목은 안전 영역 아래80px·좌우16px, 제목→안내8px·안내→행31.2px이며 설계의 명목 첫 행은 안전 영역 아래220px이며 실제 폰트 문단의 줄 메트릭 반올림으로 Flutter 실측은219.2px이다. 제목76px(명목76.8px)에서 발생한0.8px 차이를 위치 보정으로 숨기지 않고 제목→안내8px·안내→행31.2px은 엄격히 유지한다. 여섯 행의 기존 문구/순서를 보존하고 행44px·흰 배경·모서리4px·좌우16px·행 사이8px, 원24px·체크14px을 맞춘다. 선택 원은 `#1A1A1A`·노란 체크, 미선택 원은 `#D1D1D1`·흰 체크다. 낮은 viewport는 본문만 스크롤하고 마지막 행 뒤24px에 접근한다.
- **다음/하단:** 버튼56px·좌우16px·모서리8px·버튼 아래32px+실제 OS 하단 여백 한 번이다. 처음은0개 선택이며0개에서는 회색 `#D1D1D1`/흰 문구·실제 비활성,1~3개에서 검정/노란 문구로 활성화한다. ‘완료’를 ‘다음’으로 바꾸되 기존 `onDone`의 홈 이동은 유지한다. 상단 뒤로가기는 제거하지만 공개 `onBack`·화면/행 생성자·콜백과 기존 시스템 뒤로가기 정책은 바꾸지 않는다.
- **초과 안내:** 네 번째 선택은 추가하지 않고 ‘최대 3개까지만 선택 가능해요’를14px/Medium·−0.35px·`#FF3C40`·1.5로 표시한다. 원본 경고18px·글자 앞4px을 사용하며, 버튼 위에 기본1배율21px 안내+16px 간격의37px 영역을 항상 확보해 본문·버튼·스크롤이 뛰지 않게 한다. 표시3초·반복 초과 시3초 재시작·정상 선택/해제 시 즉시 숨김·종료 시 타이머 취소는 **승인된 구현 기본값**이며 Figma에 표시 시간이 있다고 추정하지 않는다. 기존 `TextScaler`와 자연 높이는 유지하고 새 확대 맞춤은 추가하지 않는다.
- **정확한 에셋:** 선택/미선택 체크14×14px·경고18×18px의 원본 SVG3개를 화면 전용 로컬 파일로 등록한다([원본 치수/해시](/private/tmp/clipback-interest-alignment-20261018/figma/asset-manifest.json)). 기존 공유 `assets/icons/check.svg`는24px·다른 SHA이므로 덮어쓰지 않는다. 원본색·도형을 보존하고 전체 화면 이미지/가짜 OS 표시는 구현에 사용하지 않는다.

<a id="b-018b939e79065565"></a>

### 기능 경계·검사와 기록

<a id="b-ff47ecaf666dcc90"></a>

- 기존 안내 **‘최대 3개까지 선택해 주세요.’**를 보존한다. Figma의 기본 카테고리 생성 안내로 바꾸지 않는다. 선택값은 현재 화면의 private Set이며 외부 전달·영속 저장·사용자/추천 API 반영·기본 카테고리 생성·B05 진행 화면은 추가하지 않는다. 루트는 기존 소개→관심사→홈 경로이고 원본 없는 소개3장·B01 권한 안내·A06 게스트 정책·약관은 별도 보류다([승인 차이](/private/tmp/clipback-interest-alignment-20261018/comparison-exceptions.json)). 화면을 다시 만들 때0개로 시작하는 동작을 선택 복원/저장 성공으로 보고하지 않는다.
- **BEFORE:** 동일 기준 커밋의 새 APK/iOS Simulator 빌드를 성공했고([빌드/동결 기록](/private/tmp/clipback-interest-alignment-20261018/before-build.json)), 새 전용 검사는 컴파일한11건 중1통과·10실패로 목표 차이를 재현했다([최종 BEFORE 검사](/private/tmp/clipback-interest-alignment-20261018/tests/before-target.log)). 경고 영역은 숨겨도37px을 유지하므로 마운트된 Text 존재와 실제 `Visibility` 표시를 구분하도록 검사만 정정하고 같은 제품 기준으로 다시 실행했다. 첫 검사 로그는 별도 보관하며 이후 성공으로 사용하지 않는다. 첫 BEFORE 프리뷰는 첫 프레임 전 GlobalKey 문맥을 읽어 준비 서버 전에 실패했고 촬영 원본은 없었다. 제품 결함으로 합산하지 않고 도구를 보완한 뒤 새 동결 소스로 양 플랫폼 기준 빌드를 다시 만들어 촬영했다([실패/재동결 기록](/private/tmp/clipback-interest-alignment-20261018/attempt-audit.json)).
- **검사 범위:** 실제 Pretendard/실제 Bold·iOS/Android 테마×320/375px×1배율에서 글자·제목2줄/간격·행/원/체크·다음/하단/안전 영역·에셋을 검사한다.0/1/3개·네 번째 거절·3초 경계/반복 재시작·정상 변경 시 숨김·해제 후0개 차단·낮은 화면의 마지막 행/24px·종료 후 늦은 타이머를 포함한다. 기존 인증/소개·입력/세션·저장·공유·기존 확대 자동 검사는 유지한다. 기존 루트 helper와 로그인 프리뷰는 무선택일 때 실제 첫 행을 선택하고 실제 다음을 탭하도록 보완하며, 공개 `onDone()` 직접 호출을 UI 비활성 검사로 사용하지 않는다.
- **최종 자동 결과:** 새 전용11건+기존 인증 안전 영역9건의 집중20/20을 통과했다([최종 집중 검사](/private/tmp/clipback-interest-alignment-20261018/tests/after-target.log)). 첫 AFTER의 명목 첫 행220px 판정은 실제 폰트 문단76px과 명목76.8px의0.8px 차이를 반영해 위치1px 허용으로 보완하고 실제8/31.2px 간격/글자 판정은 유지했다. 행44.00000000000006px의 부동소수점 차이는1e-6 허용으로 구분했다. 이전16통과/4실패 로그는 별도 보관하며 최종 통과로 합산하지 않는다. `flutter analyze --no-pub`는 문제0/exit0을 확인했다([분석 원본](/private/tmp/clipback-interest-alignment-20261018/tests/analyze.log)). 전체 `flutter test --no-pub`는 **1337/1337건 통과·실패/건너뜀0·약105초/exit0**다([전체 원본](/private/tmp/clipback-interest-alignment-20261018/tests/full-test.log)). 신규11건을 포함한 이번 실행이며 과거 A01의1326건을 이번 성공으로 재사용하지 않는다.
- **기기/비교:** iPhone16/iOS18.6·Android13/API33 제스처의 선택 전/선택 후/네 번째 초과 상태를 같은 데이터·1배율·키보드 숨김·scroll0으로 새로 촬영했다. 실제 결과는 [변경 전→후→Figma6쌍](/private/tmp/clipback-interest-alignment-20261018/comparison-document.html), [iOS3상태 개요](/private/tmp/clipback-interest-alignment-20261018/comparisons/ios-overview.png)·[Android3상태 개요](/private/tmp/clipback-interest-alignment-20261018/comparisons/android-overview.png)와 플랫폼별 AFTER 영상1개씩이다. [비교 원본/소스/동일 조건 명세](/private/tmp/clipback-interest-alignment-20261018/comparison-manifest.json)에 새 OS 원본12장과 Figma3원본·전체6쌍을 기록했다. 새 BEFORE 원본은 플랫폼별3장씩 확보했고 실제 루트/정적16기록씩·프레임워크 오류0을 확인했다. BEFORE의 목표 전체 판정false는 기존 차이의 재현이며 성공으로 바꾸지 않는다. AFTER도 플랫폼별3상태의 새 원본을 확보했고 각 상태 스타일/레이아웃/에셋true·프레임워크 오류0이다. 실제 루트/정적 최종 보고서의16기록과 스타일/레이아웃/에셋/동작/전체 판정은 양 플랫폼 모두true다([iOS](/private/tmp/clipback-interest-alignment-20261018/ios/after/report.json)·[Android](/private/tmp/clipback-interest-alignment-20261018/android/after/report.json)). 비교6쌍·영상2개를 제공하며 Figma 누락/대체 디자인0이다. 원본을 보정하거나 미확보 항목을 대체 이미지로 채우지 않았다. 정적 전용 호스트의 DEBUG 배지는 양쪽 동일한 기술 오버레이로 보존하며 제품 승인 디자인으로 간주하지 않는다. 실제 루트 앱은 기존처럼 배지를 표시하지 않는다.
- **실제 측정:** iPhone16/iOS18.6의 논리창393×852px/DPR3·상하 안전59/34px·내부375px/left9px에서 제목top139px/높이76px·첫 행top278.2px·버튼343×56px/bottom786px을 확인했다. Android13/API33 제스처의 논리창392.727×783.273px/DPR2.75·안전24/0px·내부375px/left8.864px에서 제목top104px/높이76px·첫 행top243.2px·버튼343×56px/bottom751.273px이다. 양쪽 첫 행은 안전 영역+219.2px, 버튼 아래는32px+실제 OS 하단 여백이며 안내 슬롯37px과 실제8/31.2px 간격을 유지한다.
- **실제 동작·번들:**16기록은 신규 게스트/신규 소셜→기존 소개→관심사→기존 홈, 정규화0개/실제 다음 차단,3개 선택·네 번째 거절/안내, 반복 재시작/3초 해제·정상 해제 시 숨김·다른 항목 재선택·마지막 행 접근·다음1회·종료 후 타이머 취소를 확인했다. 처음부터 공유를 격리했고 실제 공유 채널 위임0·미지원 메서드0이다. 보고서의 실제 요청에는 카테고리 생성/콘텐츠 변경이 없으며 기존 인증 발급·세션 보존 동작과 구분한다. [원본/실제 번들/보호 경계249항목](/private/tmp/clipback-interest-alignment-20261018/bundleverification.json)이 모두 통과했다. 원본 SVG3개와 실제 iOS/APK bytes·기존 실제 폰트/등록·다른 제품/네이티브 소스 불변은 확인했지만 운영 관심사 저장이나 실제 공급자 인증을 증명하지 않는다.
- **영상·환경 정리:** AFTER 영상은 [iOS22.163333초](/private/tmp/clipback-interest-alignment-20261018/ios/after/actions.mp4)·[Android37.514378초](/private/tmp/clipback-interest-alignment-20261018/android/after/actions.mp4)다. [미디어 검사](/private/tmp/clipback-interest-alignment-20261018/media-verification.json)는 두 원본의 전체 디코딩exit0·진단0·동작 구간 포함·녹화 완료·SHA 일치를 확인했다. 인코딩된 실제 길이를 기록하며 대기시간을 임의 합산하거나 영상을 잘라 실패를 숨기지 않는다. 기본 두 기기의 최대 스크롤은0px인 무스크롤이고 낮은 viewport의 마지막 행/본문 끝24px 접근은 위젯 검사에서 별도로 확인했다.
- [최종 환경 정리](/private/tmp/clipback-interest-alignment-20261018/cleanup-verification.json)에서 소유 앱·시뮬레이터/에뮬레이터 종료, 포워딩 제거·ADB 종료·8767/8768 포트 닫힘을 확인했다. Android 제스처 설정2와 기존 키보드/기기 설정을 변경하지 않았고 사용자 앱 제거·계정/공유 데이터 삭제·임시 비교 HTTP 서버 실행은 없었다. 화면 증거·빌드·`AGENTS.md`는 Git 밖에 유지하며 푸시/PR은 수행하지 않는다.
- **상태 정규화:** BEFORE는 첫 항목이 기본 선택돼 있으므로 선택 전 비교에서는 이를 실제 탭으로 해제한다. 선택 후·초과도 같은 실제 선택을 탭으로 만든다. BEFORE에는 초과 안내가 없었던 차이를 그대로 남긴다. 양 플랫폼 BEFORE의 실제 최초 선택 기록은 `[0]`이며 이후 `root_empty`/정적 상태 준비가 실제 탭으로 정규화한 상태와 구분한다. 초기0개 조건은 전용 위젯 검사와 실제 네이티브 최초 기록 모두에서 확인했다. AFTER의 `initialSelectedIndices`는 양 플랫폼 모두 `[]`이며 이후 정적 상태 정규화와 별개다. 실제 OS 창/안전 여백·최대375px 프레임·예제 설명 문구 차이는 승인 예외로 표시하고 원본을 보정하지 않는다.
- **미검증/후속:** 실제 API/OAuth·운영 서버·실기기·관심사 저장/복원·기본 카테고리 생성·B01 권한/거절·소개 원본·새 확대/3버튼 촬영은 이번 범위가 아니다. 첫 실행부터 네이티브 공유 채널을 격리한 메모리 대역 결과를 실제 계정 데이터 보존·공급자 성공 증거로 확대하지 않는다. A01의 iOS 네이티브 불투명/정적 색상 미검증은 이번 화면 작업으로 해소되지 않는다.

<a id="b-1f8e2817cfcb78a6"></a>

### 관심사 화면 재현 명령

<a id="b-bc2a5fb13ea60de3"></a>

```bash
cd frontend
flutter test --no-pub test/interest_alignment_test.dart test/auth_safe_area_test.dart
flutter test --no-pub
flutter analyze --no-pub
```

<a id="b-f49fdb4c3f2368ae"></a>

전용 검사 [interest_alignment_test.dart](../../frontend/test/interest_alignment_test.dart)는 실제 폰트·공개 위젯·실제 탭을 사용합니다. 하단37px을 유지하는 숨김 안내는 Text가 마운트됐는지 대신 `Visibility`의 실제 표시 상태로 판정합니다. [기존 루트 helper](../../frontend/test/auth_navigation.dart)와 [로그인 프리뷰](../../frontend/test/support/login_alignment_preview.dart)는 유효한 관심사를 실제로 선택하고 다음을 탭하며, BEFORE의 ‘완료’ fallback은 같은 촬영 소스의 기준 커밋 호환 용도입니다. 운영 관심사 저장이나 카테고리 생성 API는 호출하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-f54c37c3f95a71f3"></a>

직전 관심사 작업은 `2a3c912` 기준 **B02·B03·B04 관심사 선택의1배율 표현과 승인된 화면 안 선택 동작 맞춤**입니다. 새 BEFORE/재현11건(1통과/10실패)을 확보했고 AFTER 집중20/전체1337·분석0과 양 플랫폼 각16기록·전체true/오류0을 확인했습니다. 새 비교6쌍·영상2개/전체 디코딩·환경 정리를 확인했습니다. 선택값 저장·기본 카테고리 생성·권한/소개와 기존 인증·콘텐츠 보존 정책은 별도입니다.
