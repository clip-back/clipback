# 카테고리 관리 표현

- 최초 기록일: 2026-10-17
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-bd3d9dd1d71dba91"></a>

### 카테고리 관리 화면의 1배율 맞춤 — 2026-10-17

<a id="b-008e8d67ef222035"></a>

`70b2ab1` 기준으로 Page 1 > `261007`의 E04(`111:4569`) 관리 본화면을 맞췄다. 개별 행의 콘텐츠 개수는 사용자 확정으로 숨기며 상단 총수·서버 메타데이터·더보기의 실제 개수와 기존 삭제 안내는 유지한다. 완료는 관리 본화면의1배율이며 생성/수정/삭제 시트의 디자인·전체/미분류 콘텐츠 목록·새 확대 대응은 후속이다.

<a id="b-ffd5ee25c51dbf49"></a>

- [이번 Figma 조회](/private/tmp/clipback-category-management-20261017/figma/reference-manifest.json): **2026-10-17 09:29:08~09:29:13 UTC /18:29:08~18:29:13 KST**, E04 컨텍스트+375×812 원본1회 성공·별도 메타데이터/스크린샷 재호출·fallback/누락0이다. 다른 파일/노드나 이전 기기 이미지를 대체 원본으로 사용하지 않았다.
- 제품 변경은 CategoryManagementScreen 한 파일이다. 헤더64px·뒤로가기 원본24px/보이는 좌16px·제목 간격8px/시작48px을 맞추고 기존48px 터치 영역은 유지했다. 제목은 공통 AppText.sectionTitle을 재사용해 Pretendard18/SemiBold/−0.45/검정/AUTO다. 추가 버튼은 헤더에서52px 개수 행 오른쪽으로 옮겨 원본24px·보이는 우16px·기존48px 터치를 유지한다. 개수는 Pretendard14/Medium/−0.35/#767676/AUTO로 표시한다.
- 검증된 CategoryRow의 archiveStyle:true를 재사용해44px 행·행 사이16px·좌16/우6px·폴더40×34px·글자 앞12px·텍스트 최대156px·이름/날짜2px·더보기44px/원24px을 유지한다. 이름15/Medium/−0.375/#1A1A1A·날짜12/Regular/−0.3/#B5BDC3의 AUTO/한 줄 말줄임을 사용한다. 실제 이름/색/날짜 없음 문구·작업 중 안내/잠금은 보존하고 관리 행에는 새 탭 이동을 추가하지 않는다.
- 총 N은 전달된 목록에서 미분류를 제외한 카테고리 수이며 콘텐츠 수 합계나 새 전체 계정 집계가 아니다. 입력 순서를 그대로 사용하고 아카이브 최신순을 관리에 적용하지 않는다. 기존0개 표현을 유지하며 미조회/로딩/오류/빈 상태의 새 디자인은 만들지 않았다. 하단은 기존 SafeArea에서 실제 여백을 한 번 적용한다. 목록의 ValueKey는 측정용이며 관리 자체의 새 위치 복원/영속 저장을 추가하지 않는다.
- [원본 SVG/로컬/번들/실제 슬롯 검사](/private/tmp/clipback-category-management-20261017/static-assets-verification.json): back=detail-back24·add=archive-folder-plus24·folder=archive-category-folder40×34·more=archive-category-more19.2×18.4 네 원본이 기존 로컬 파일과 동일하여 새 에셋/등록 변경0이다. 폴더6색의 같은 도형을 확인했고 실제 분류색만 적용하며 나머지는 원색 무필터로 재사용했다. 전체 Figma 이미지/임시URL을 제품에 사용하지 않았다.
- [수정 전 게이트](/private/tmp/clipback-category-management-20261017/before-gate.json)로 새 OS원본2개·실제 테마·1배율/스크롤0/키보드0·제품 기준 소스를 확인한 뒤 수정했다. [동결 소스](/private/tmp/clipback-category-management-20261017/fixture-manifest.json)의 새 프리뷰 `cd3e21abdd8ff95a2d35a17977fa2776ea04ef4d6a1c6271017bfd37cea1c15b`·집중 검사 `6bdcf9647792fe87d2eec37631192a3e29037924142ae857f38bd9e7b1352913`와 기존 선택자 호환4파일은 전후 동일하다. 최종 RED47건=11통과/36목표 차이·예상 밖 실패0이다. 초기 프리플라이트 보완 전 시도를 최종 성공으로 사용하지 않는다.
- [이번 자동 검사](/private/tmp/clipback-category-management-20261017/automatic-checks.json): 집중 **119건**(14.64초), 관련 **216건**(17.31초), 전체 **1055건**(51.58초) 통과·건너뜀/오류0, flutter analyze --no-pub 문제0건(4.29초)이다. 집중 검사는 iOS/Android×폭320/375px×1배율×하단0/34/48px×카테고리0/1/12개와 실제 문단/아이콘/터치 경계를 확인했다. 기존 확대/삭제/저장/시트/복귀 검사를 삭제하거나 건너뛰지 않았다.
- [보존 감사](/private/tmp/clipback-category-management-20261017/preservation-audit.json)로 공개 생성자/콜백·미분류 제외/입력순서·액션의 실제 서버 개수 전달, 공통 행 기본값/아카이브 외형·API/모델/Repository/App 복귀·기존 에셋을 확인했다. 기존 회귀4파일은 새 키를 우선하고 구 선택자를 fallback으로 쓰도록 보완했으며 동작 기대는 유지했다.
- iPhone16/iOS18.6: 창Size(393.0, 852.0)·DPR3.0·OS상단59.0/하단34.0px, **20기록·프레임워크 오류0건·style/layout/behavior/coverage/checksCompleted/전체 passed:true**다. 실제 키보드 inset 약336.00→0px과 입력/컨트롤러·목록 보존을 확인했다.
- Android13/API33 제스처(AVD Clipback_Share_API_33·sdk_gphone64_arm64): 창Size(392.7, 783.3)·DPR2.75·OS상단24.0/하단0.0px, **20기록·프레임워크 오류0건·style/layout/behavior/coverage/checksCompleted/전체 passed:true**다. 실제 키보드 inset 약274.91→0px과 입력/컨트롤러·목록 보존을 확인했다.
- [네이티브 실측/동작](/private/tmp/clipback-category-management-20261017/native-validation-summary.json)·[독립 동일 조건 QA](/private/tmp/clipback-category-management-20261017/pair-verification.json): 스크롤하며12행을 모두 완전히 노출하고 입력 순서/최대 위치의 마지막 행·하단 여백·합성 포인터8회 실제 드래그를 확인했다. 추가/수정/삭제 취소와 실제 로컬 콜백1회씩·총수/이름/색의 재렌더·원본 콘텐츠/메타데이터 복원, 뒤로가기/재진입을 검증했다. 네이티브 호스트는 직접 reactive 렌더이고 실제 ClipbackApp의 진입 출처/모달 우선 OS뒤로가기/아카이브 탭·위치/계정 전환 분리는 별도 자동 검사다.
- 고정12개 대역/합성 포인터·controller 입력·메모리 CRUD를 실제 HTTP/영속 저장·OAuth·운영 서버·실기기·원격 CI 증거로 확대하지 않는다. 실제 OS 창/하단 여백과 Figma375×812·예시6개/이름/색/날짜는 다르며 전체 절대 좌표 일치를 주장하지 않는다. 원본을 자르거나 OS 안전 영역을 보정하지 않았다.
- [새 비교2쌍](/private/tmp/clipback-category-management-20261017/comparison-document.html)·[비교 QA](/private/tmp/clipback-category-management-20261017/comparison-qa.json): BEFORE/AFTER 새 OS원본 각2장·완전3열2쌍·Figma/조건 누락0이다. [HTML 검사](/private/tmp/clipback-category-management-20261017/comparison-html-verification.json)는 참조/문법 정적 검사이며 브라우저/비교HTTP서버는 실행하지 않았다.
- [iOS AFTER 영상](/private/tmp/clipback-category-management-20261017/ios/after/interaction.mp4): 28.966667초·[1178, 2556]px, 전체 디코딩 종료코드0/오류로그0바이트·동작 완료까지 녹화 유지 확인.
- [Android AFTER 영상](/private/tmp/clipback-category-management-20261017/android-gesture/after/interaction.mp4): 60.700344초·[1080, 2220]px, 전체 디코딩 종료코드0/오류로그0바이트·동작 완료까지 녹화 유지 확인.
- [환경 정리](/private/tmp/clipback-category-management-20261017/cleanup-verification.json): 사용한 앱/기기·포워딩/임시 서버를 정리하고 탐색/키보드 설정과 기기 데이터를 보존했다. 이전 검증 기록은 당시 근거로 유지한다.

<a id="b-08bf091a3f295080"></a>

관리 전용 프리뷰 실행:

<a id="b-9e26d6394cd0344f"></a>

```bash
cd frontend
flutter test --no-pub test/category_management_alignment_test.dart test/category_archive_alignment_test.dart test/feed_pagination_test.dart
flutter run --no-pub -d <device-id> -t test/support/category_management_preview.dart --dart-define=CATEGORY_MANAGEMENT_PHASE=after
```

<a id="b-8cb17fec3e5ae11c"></a>

loopback8767의 `/ready`·`/state`·`/status`, 정적 `/scene?scroll=0`·최대 위치 `/scene?scroll=max`, 동작 `/run`을 제공한다. Android는 `adb -s <serial> forward tcp:8768 tcp:8767` 후 host8768로 접근하며 종료 후 제거한다. `/run`의 CRUD는 메모리 대역이며 현재 데이터를 직접 재빌드한다. 기존 아카이브 프리뷰의 진입/복귀 검사는 유지한다.

<a id="b-11f1b5271c1cbac0"></a>

| 화면 | iOS 변경 전 → 후 → Figma | Android 변경 전 → 후 → Figma |
| --- | --- | --- |
| 관리·카테고리12개 | [3열 비교](/private/tmp/clipback-category-management-20261017/comparisons/ios-category_management_scale_1_top.png) | [3열 비교](/private/tmp/clipback-category-management-20261017/comparisons/android-gesture-category_management_scale_1_top.png) |
