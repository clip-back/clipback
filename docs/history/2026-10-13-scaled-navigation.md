# 확대 하단 탭과 최근 카테고리

- 최초 기록일: 2026-10-13
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-c2d65bc87207489b"></a>

### 확대 하단 탭과 최근 카테고리 행 (`d01873c`)

<a id="b-cfe1fe62ab255d8e"></a>

아래 조회 노드·96/124/140px 측정과 625개 테스트는 이전 `svNWsTFh8Ws1Mpt8XQIcrN / 261007`으로 이 커밋 당시 수행한 검증입니다.
현재 OS 하단 안전 영역의 승인 기준과 이번 실행 명령·결과는 다음 절을 따릅니다.

<a id="b-02ec54b8a61feaf5"></a>

공유 `ClipbackNavigationBar`의 라벨은 56px 폭에서 실제 글자 배율을 유지하고 최대 두 줄·말줄임으로 표시합니다.
네 라벨 중 가장 높은 값을 공통 영역으로 사용해 아이콘 상단을 맞추며, 증가분을 항목 56px·행 64px·전체 바 96px에
함께 더합니다. 배율 1의 전체 높이 96px, 기존 색상·탭 목적지·하단 인디케이터를 유지합니다.
추가 버튼은 72×72px·중앙·위로 22px 위치이며, 행의 제약을 받지 않게 바 전체 Stack에 배치합니다.
버튼의 중심과 바 안쪽 하단 가장자리 탭을 각각 확인합니다.

<a id="b-04eed9cfdee07a45"></a>

빈 홈의 `CategoryHomeRow`는 텍스트 열에 남은 폭을 할당하고 이름·시각을 각각 한 줄 말줄임으로 표시합니다.
폴더·화살표·색상·글자 크기·행 탭과 기존 고정 시각 문구를 유지합니다.
API·데이터 모델·콘텐츠 보존/삭제 정책과 다른 카테고리 행의 디자인은 변경하지 않습니다.
확대 상태는 별도 Figma 프레임이 없어 사용자가 승인한 위 배치를 기준으로 합니다.
일반 디자인 기준은 하단 탭 `111:3680`, C01 `111:3584`, C02 `111:3681`이며
2026-10-13 22:23:08 KST(13:23:08 UTC)에 다시 조회했습니다.

<a id="b-ffd5e0e418e7fc2d"></a>

```bash
# frontend/ — 단위 회귀와 기존 안전 영역 검사를 함께 실행합니다.
flutter test --no-pub test/scaled_navigation_layout_test.dart test/home_alignment_test.dart test/top_safe_area_test.dart
flutter analyze --no-pub
flutter test --no-pub

# 실제 공유 탭의 여섯 사용 화면 및 확대 탭 단독 검사: 대역 데이터/합성 포인터입니다.
flutter run --no-pub -d <device-id> -t test/support/navigation_layout_preview.dart
```

<a id="b-00932f3a12c1e15c"></a>

`test/scaled_navigation_layout_test.dart`는 Android/iOS 설정, 폭 320·375px, 배율 1·1.5·2에서
하단 탭 높이·라벨·아이콘 정렬·활성 표시·네 탭과 추가 버튼 입력, 긴 카테고리의 말줄임·전체 행 탭을 검사합니다.
상세의 페이지 이동/저장 진입과 Placeholder의 실제 Navigator 복귀도 확인합니다.
제품 두 위젯에 대한 수정 전 실패를 재현한 후 수정 코드에서 전체 Flutter 테스트 **625 passed**와
`flutter analyze --no-pub` **문제 없음**을 확인했습니다.

<a id="b-7f77f93a3786394e"></a>

`navigation_layout_preview.dart`는 실제 홈·아카이브·즐겨찾기·마이·상세·Placeholder를 일반 배율로 순회하고,
공통 탭은 375px의 배율 1.5/2 및 320px의 배율 2에서 따로 검사합니다.
실제 탭·홈 카드·상세 이전/다음·Placeholder 복귀와 추가 버튼 중심/하단 입력을 합성 포인터로 실행합니다.
`clipback-navigation-*` 기기 임시 폴더에 PNG 9개와 `report.json`을 저장하며 `NAV_LAYOUT PASS/FAIL`을 출력합니다.
실제 세션·HTTP·네이티브 공유·저장은 사용하지 않고, 제품 진입점은 `lib/main.dart`로 유지합니다.

<a id="b-3fc95ad507993789"></a>

최종 iOS/Android 홈 프리뷰는 모두 통과했습니다. 동일한 여섯 비교 상태의 프레임워크 오류는 플랫폼별
**14건 → 0건**이며 수정 후 `passed`·`checksCompleted`·동작 완료·확대 촬영 완료는 모두 `true`입니다.
바 높이 96px/140px(배율 1/2), 추가 버튼 72×72px·위로 22px 위치, 스크롤·페이지 점·저장 시트의
키보드·닫기를 확인했습니다. 최종 공유 내비게이션 프리뷰도 양 플랫폼에서
`passed`·`checksCompleted: true`, 프레임워크 오류 0건·`failure: null`로 통과했습니다.
바 높이 96/124/140px(배율 1/1.5/2), 네 아이콘 정렬·탭, 상세 이전/다음 각 1회와
Placeholder 복귀, 세 확대 조건에서 추가 버튼 중심/하단 입력 총 6회를 확인했습니다.
여섯 실제 본문은 일반 배율이며 확대는 공통 탭 단독 검사라는 범위를 유지합니다.
기종·OS·최종 코드의 측정값과 영상은 [프론트 진행 기록](../fe-merge-fixes.md)에 기록하며
과거 커밋의 성공을 이번 결과로 사용하지 않습니다.
비교 자료 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout`이고
`comparison-document.html`과 플랫폼별 `ios-expanded-comparison.html`·`android-expanded-comparison.html`에서
변경 전·후·Figma를 원본 그대로 비교합니다. 확대 Figma 화면을 임의로 만들어 채우지 않습니다.

<a id="b-5a46a6a76080d12c"></a>

마이·상세 본문의 배율 2에는 변경 전부터 있는 별도 넘침이 있어 새 배치를 임의로 구현하지 않았습니다.
이 두 본문의 통합 검사는 일반 배율이며, 공통 탭 단독 확대 성공을 전체 본문 성공으로 확대하지 않습니다.
본문 확대 디자인과 진입/저장 화면의 별도 홈 인디케이터는 [디자인 확인 필요 목록](../figma-ui-alignment-plan.md#디자인-확인-필요)에 남깁니다.
실제 OAuth·운영 서버·실기기·원격 CI는 이번 로컬 화면 검증에 포함하지 않습니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-9f4b2a13904c55cb"></a>

### 2026-10-13 — 확대 글자·좁은 화면의 하단 탭과 홈 카테고리 넘침 수정

<a id="b-4774d055f9e9898c"></a>

- 브랜치 `feature/figma-ui-alignment`, 변경 전 기준 `cc73b21`.
  사용자가 하단 탭 이름 최대 두 줄·높이 확장과 최근 카테고리 이름/날짜 각각 한 줄 말줄임을 확정했다.
  글자를 줄이지 않는다. OS 인디케이터·하단 안전 영역 변경, 안내·공지, 추천 API, 저장 화면 맞춤은 제외한다.
- [공통 하단 탭](../../frontend/lib/shared/widgets/navigation_bar.dart)은 Pretendard 12px/Medium·자간 −0.3px을
  명시한다. 폭 56px에서 실제 TextScaler로 네 라벨을 측정하고 가장 높은 라벨 공간을 공유한다.
  기본 배율보다 늘어난 높이를 항목 56px·내부 64px·전체 96px에 동일하게 더한다.
  아이콘은 높이 28px과 같은 위쪽 위치를 유지하고 라벨은 공통 영역의 위쪽부터 배치한다.
- 저장 버튼의 선언 크기 72px가 기존 64px Row에 의해 실제 높이 64px로 제한되는 문제도 검사에서 확인했다.
  버튼은 전체 바의 Stack에 높이 72px·상단 −22px로 배치하고 Row에는 같은 폭의 자리를 유지한다.
  원형 버튼 중심뿐 아니라 하단 가장자리에서 2px 안쪽의 실제 포인터 탭도 확인한다.
  기존 색상·탭 연결·앱 내부 인디케이터·공개 생성자/콜백은 유지한다.
- [최근 카테고리 행](../../frontend/lib/shared/category/category_widgets.dart)은 텍스트 열에 남은 폭을 할당하며
  이름·날짜 각각 `maxLines: 1`과 말줄임을 적용한다. 확대 시 행 높이는 글자에 따라 늘어난다.
  폴더 40px·화살표 18px·간격·전체 행 탭과 고정 날짜는 유지한다. API·데이터 모델은 변경하지 않는다.
- Figma 공통 내비게이션 `111:3680`, C01 `111:3584`, C02 `111:3681`의 컨텍스트와 원본을
  **2026-10-13 22:23:08 KST / 13:23:08 UTC**에 새로 조회했다.
  확대 상태와 기존 최근 카테고리 행의 전용 Figma는 없다. 기본 배율 원본과 사용자 확정 기준을 구분하며
  대체 디자인 이미지는 만들지 않았다.
- **제품 수정 전에** 두 플랫폼에서 이번 기준 커밋으로 정상 홈·빈 홈·긴 카테고리, 배율 1/2의
  여섯 화면을 새로 촬영했다. 초기화된 조회 완료·필터 없음·로딩/오류 없음 상태, 동일 콘텐츠 ID와
  카테고리 순서·긴 이름·기종/화면 크기·배율·스크롤 0을 고정했다. 이전 커밋의 화면을 재사용하지 않았다.
  각 플랫폼의 변경 전 보고서는 `baselineCaptured: true`, `checksCompleted: true`, `passed: false`,
  프레임워크 오류 **14건**이었다. 하단 탭은 배율 2에서 9px·43px 넘침,
  긴 카테고리는 iOS 194/650px·Android 216/695px의 가로 넘침을 기록했다.
- [확대 레이아웃 테스트](../../frontend/test/scaled_navigation_layout_test.dart) 30개는 수정 전 **30 failed**였다.
  폭 320/375px·iOS/Android 테마·배율 1/1.5/2에서 라벨/아이콘 위치와 잘림, 카테고리 말줄임,
  네 탭·저장 버튼·행의 실제 탭 호출을 검사한다. 공유 하단 바를 쓰는 홈·아카이브·즐겨찾기·Placeholder의
  확대 상태와 마이·상세의 기본 상태를 검사하고 상세 이전/다음 및 저장 시트 진입도 확인한다.
  마이·상세 본문의 기존 배율 2 오류는 범위 밖이며 아래 보류 목록에 기록했다.
- 초기 수정의 버튼 하단 탭 누락은 **26 passed / 4 failed**로 재현했다.
  최종 수정 후 확대 30개 + 홈 35개 + 안전 영역 11개 **76 passed**를 확인했다.
  최종 `flutter test --no-pub --reporter expanded` **625 passed**,
  `flutter analyze --no-pub` **문제 없음**이다. Flutter 3.44.9 / Dart 3.12.2,
  기존 잠금파일을 사용하며 의존성을 변경하지 않았다.
- [홈 프리뷰](../../frontend/test/support/figma_home_preview.dart)와
  [공유 하단 탭 프리뷰](../../frontend/test/support/navigation_layout_preview.dart)는 실제 화면과 고정 메모리 데이터를 사용한다.
  제품 진입점에 테스트 분기를 추가하지 않으며 세션·HTTP·운영 데이터·실제 저장을 사용하지 않는다.
  홈의 저장 시트와 실제 키보드 insets 확인은 최대 15초 동안 기다린다. 이전 2.5초 대기의 Android 시간 초과
  자료는 `android/after/initial`에 보존하고 실제 키보드 표시가 확인된 재실행 결과와 구분한다.
- 최종 코드를 고정한 뒤 홈·공유 하단 탭 프리뷰를 각 플랫폼에서 새로 실행했다.
  네 보고서 모두 **`passed: true`·`checksCompleted: true`·프레임워크 오류 0건**이다.
  이전 버튼 배치의 중간 실행 자료는 `pre-hitfix`로 보존하며 최종 결과와 구분한다.

<a id="b-7d1ecad5341560a5"></a>

| 플랫폼 | 최종 홈·공유 하단 탭의 실제 실행 결과 |
| --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 논리 크기 393×852, DPR 3, 안전 영역 위 59/아래 34px. 정상·빈·긴 카테고리의 배율 1/2 홈 모두 오류 0건. 일반 홈 세로 스크롤 0→83px, 키보드 첫 양수 inset 약 335.24px·실제 표시/닫기 확인. 확대 카드 높이 316px, y=368.375~684.375로 viewport y=59~712 안에서 확인. |
| Pixel 3a 설정 Clipback_Share_API_33 / Android 13 API 33 Emulator (`sdk_gphone64_arm64`) | 논리 크기 392.7×783.3, DPR 2.75, 안전 영역 위 24/아래 0px. 같은 여섯 홈 상태 모두 오류 0건. 일반 홈 세로 스크롤 0→116.73px. 첫 양수 키보드 inset 약 104.73px는 표시 애니메이션 중의 값이며, OS 포함 촬영에서는 실제 키보드 전체 표시/닫기를 확인. 확대 카드 높이 316px, y=314.58~630.58로 viewport y=24~643.27 안에서 확인. |

<a id="b-90fddd7a86577888"></a>

- 양쪽 홈에서 today/archive/content/bookmark 호출 각각 1회, 북마크의 카드 탭 전파 없음,
  마지막 페이지 점 **3/4**, 빈 홈 저장 진입·실제 키보드·닫기를 확인했다.
- 공유 프리뷰는 양쪽에서 실제 홈·아카이브·즐겨찾기·마이·상세·Placeholder를 **배율 1**로 확인했다.
  공통 하단 탭은 별도 폭 375px/배율 1.5·2 및 폭 320px/배율 2에서 확인했다.
  바 높이는 배율 1/1.5/2에서 **96/124/140px**, 아이콘 28px·네 아이콘 상단 일치,
  라벨 영역 포함·탭 항목 폭 56px·최소 높이 56px, 추가 버튼 72×72px·상단 −22px이다.
  각 확대 조건에서 저장 버튼의 중심·하단 가장자리 탭은 각각 한 번 호출됐다.
  archive/bookmark/my 탭 각 4회·home 5회·카드 1회·상세 이전/다음 각 1회·추가 버튼 총 6회이며
  상세 페이지 버튼은 바와 겹치지 않았다. Placeholder의 실제 Navigator 복귀도 확인했다.
- 홈 비교 프레임워크/OS 원본 PNG는 변경 전 6개·변경 후 11개씩, 공유 프리뷰는 9개씩 확보했다.
  두 플랫폼의 변경 전·후 보고서에서 기종·논리 크기·DPR·insets·콘텐츠 ID·카테고리·긴 이름·조회 상태·
  배율 1/2·스크롤 0이 일치함을 대조하고 `comparison-validation.json`에 원본 해시와 결과를 기록했다.

<a id="b-3ea861dc27bfd436"></a>

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout`.

<a id="b-e6331a1e1b79df54"></a>

- [모든 원본 3열 비교](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/comparison-document.html)는
  iOS/Android와 정상·빈·긴 카테고리의 배율 1/2를 선택해 **변경 전 → 변경 후 → Figma 기본 원본** 순서로 보여준다.
  OS 안전 영역·기기 크기·PhoneFrame 여백·상태바 시각을 보정하지 않는다.
  C02 안내·공지 대신 유지한 최근 카테고리 영역과 고정 대역 데이터 차이는 기존 보류 범위다.

<a id="b-7586fd26aa5f4973"></a>

| 최종 실행 증거 | iOS | Android |
| --- | --- | --- |
| 홈 동작 영상 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/after/interaction.mp4) | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/after/interaction.mp4) |
| 공유 하단 탭 동작 영상 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/navigation/interaction.mp4) | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/navigation/interaction.mp4) |
| 홈 보고서 | [보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/after/report.json) | [보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/after/report.json) |
| 공유 하단 탭 보고서 | [보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/navigation/report.json) | [보고서](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/navigation/report.json) |
| 홈 → 공유 하단 탭 결합 영상 | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/ios/interaction-final.mp4) | [영상](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout/android/interaction-final.mp4) |

<a id="b-684f1825d43f4c07"></a>

- 결합 영상은 원본 네 영상 스트림을 플랫폼별로 시간순 연결했다. 스케일·재프레이밍·재인코딩 없이
  `ffmpeg -c copy`를 사용하며 원본도 보존했다. ffprobe로 iOS H.264 1178×2556/192.198초,
  Android H.264 1080×2220/240.834초를 확인했다. 비교에 쓰는 iOS PNG는 원본 1179×2556 그대로다.

<a id="b-d26c5f8b543a99de"></a>

- 남은 디자인 확인: 앱 내부 홈 인디케이터와 실제 OS 영역 처리, 마이 본문 배율 2의 하단 넘침 6px/59px,
  상세 본문 배율 2의 오른쪽 넘침 112px/92px. 마이는 J01 `111:4707`·J02 `111:4533`,
  상세는 F02 `111:3842`·F03 `111:3771`·F04 `111:3909`의 확대/좁은 상태 확인이 필요하다.
  본문 디자인은 임의로 수정하지 않았다. [계획의 디자인 확인 목록](../figma-ui-alignment-plan.md)을 따른다.
- 실제 OAuth·운영 서버·실기기·원격 CI·실제 저장 완료는 이번 로컬 대역 검증에 포함하지 않는다.
  화면 증거·빌드 생성물·`AGENTS.md`는 커밋에서 제외하며 푸시·PR을 수행하지 않는다.
- 최종 변경 Dart 5개 형식 검사 **0 changed**, 로컬 문서 링크 **106개 모두 존재**, 최종 diff·공백·
  생성 파일/민감 정보 제외를 확인했다. 이번 작업에서 부팅한 Simulator·Emulator와 Flutter/녹화 프로세스를
  종료하고 AVD·앱 데이터를 보존했다. 원본 비교를 확인할 로컬 브라우저와 읽기 전용 비교 서버는 유지한다.
  제품 2개·테스트/프리뷰 3개·문서 3개, 총 8개 파일만 한 커밋으로 저장한다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-306085aacf8d60e8"></a>

### 확대 하단 탭·최근 카테고리 행 커밋 `d01873c`의 적용 범위

<a id="b-70e88b5f3c4dab86"></a>

작업 기준은 `cc73b21`이다. Figma 하단 탭 `111:3680`, C01 `111:3584`, C02 `111:3681`을
2026-10-13 22:23:08 KST(13:23:08 UTC)에 조회했다. Figma에는 확대 상태의 확정 프레임이 없으므로
사용자가 승인한 ‘하단 라벨 최대 두 줄·필요한 높이 확장’과 ‘카테고리 이름/시각 각 한 줄 말줄임’을
확대 상태의 구현 기준으로 삼는다. 기본 크기·색상·동선과 콘텐츠 보존 정책을 유지한다.

<a id="b-7fd07c25721a352e"></a>

| 적용 영역 | 승인 기준과 구현 |
| --- | --- |
| 공통 하단 탭 | Pretendard 12px/Medium·자간 −0.3px·폭 56px의 라벨을 실제 글자 배율로 최대 두 줄·말줄임 처리한다. 네 라벨의 최대 높이를 공통 영역으로 사용해 아이콘 상단을 맞춘다. 기본 라벨 높이보다 늘어난 만큼 항목 56px·행 64px·전체 바 96px의 높이를 함께 늘린다. 배율 1의 바 높이는 96px이다. |
| 추가 버튼 | 기본 크기 72×72px·바 위로 22px 올라온 중앙 위치를 유지한다. 행에는 72px 자리를 남기고 버튼은 바 전체 Stack의 마지막 자식으로 배치하여 행의 높이 제약을 받지 않게 한다. 바 안쪽의 버튼 하단 가장자리 탭도 한 번 실행돼야 한다. |
| 최근 카테고리 | `CategoryHomeRow`의 텍스트 열에 남은 폭을 할당하고 이름·시각을 각각 최대 한 줄·말줄임 처리한다. 폴더·화살표·색상·글자 크기·전체 행 탭과 기존 고정 시각 문구를 유지한다. 실제 시각 연결과 다른 카테고리 행 디자인은 후속 작업이다. |
| 공유 영향 범위 | 하단 탭은 홈·아카이브·즐겨찾기·마이·상세·Placeholder에서 사용한다. 상세의 페이지 이동 버튼 조합과 Placeholder의 Navigator 복귀를 확인한다. 화면 생성자·공개 콜백·API·데이터·삭제 처리와 홈 인디케이터는 변경하지 않는다. |

<a id="b-6e48e317d4e477f6"></a>

### 확대 레이아웃 커밋 `d01873c` 당시의 검증 상태

<a id="b-f5f717ecce49035c"></a>

- [확대 레이아웃 회귀 테스트](../../frontend/test/scaled_navigation_layout_test.dart)는 Android/iOS 설정,
  폭 320·375px, 배율 1·1.5·2에서 하단 탭 기하·라벨·아이콘 정렬·활성 표시·네 탭과 추가 버튼 입력을 검사한다.
  추가 버튼은 중심과 바 안쪽 하단 가장자리 입력을 각각 확인하며 최근 카테고리의 긴 이름/시각과 전체 행 탭을 검사한다.
- 전체 Flutter 테스트 **625개 통과**, `flutter analyze --no-pub` **문제 없음**을 확인했다.
  일반 배율의 마이·상세 통합 검사와 배율 2의 공통 탭 검사를 확대 본문 전체 성공으로 바꾸지 않는다.
- 최종 [홈 프리뷰](../../frontend/test/support/figma_home_preview.dart)는 양 플랫폼에서 통과했다.
  변경 전·후 동일한 여섯 상태에서 각 플랫폼의 프레임워크 오류가 **14건 → 0건**으로 줄었고,
  수정 후 `passed`·`checksCompleted`·동작 완료·확대 촬영 완료는 모두 `true`다.
  후속 동작 다섯 장과 저장 시트·키보드·닫기, 마지막 카드 페이지 점, 확대 카드 스크롤을 확인했다.
  두 플랫폼 모두 바 높이 96px(배율 1)/140px(배율 2), 추가 버튼 72×72px·위로 22px 위치를 확인했다.
- 최종 [공유 내비게이션 프리뷰](../../frontend/test/support/navigation_layout_preview.dart)는 양 플랫폼에서 통과했다.
  `passed`·`checksCompleted`는 `true`, 프레임워크 오류는 0건, `failure`는 `null`이다.
  실제 여섯 화면은 일반 배율로 확인하고, 공통 탭은 375px의 배율 1.5/2와 320px의 배율 2로 별도 확인했다.
  바 높이 96/124/140px(배율 1/1.5/2), 네 아이콘 정렬·탭, 상세 이전/다음 각 1회,
  Placeholder 복귀와 추가 버튼 중심/하단 입력 각 1회씩 세 확대 조건에서 총 6회를 확인했다.
  마이·상세 본문 전체의 배율 2 통과를 뜻하지 않는다.
- 증거 루트는 `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/scaled-layout`이다.
  `comparison-document.html`에서 플랫폼별 원본 변경 전·후·Figma를 세 열로 비교한다.
  `ios-expanded-comparison.html`·`android-expanded-comparison.html`은 확대 상태 전달용 비교 자료이며 최종 기기 결과와 함께 확인한다.
  Figma 일반 배율과 실제 확대 상태·OS 안전 영역 차이를 설명하고 원본을 보정하거나 확대 기준 화면을 만들어 채우지 않는다.
- 기기 실행 결과·영상·미검증 범위는 [프론트 진행 기록](../fe-merge-fixes.md)을 따르며 실제 OAuth·운영 서버·실기기·원격 CI 성공을 뜻하지 않는다.
