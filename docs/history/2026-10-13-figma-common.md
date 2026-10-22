# 공통 글자와 버튼 스타일

- 최초 기록일: 2026-10-13
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-7d08af25e5bc2fa3"></a>

`a9eb69d`까지의 앱 구현·검증은 현재 다시 선택한 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 당시 `261007` 기준입니다.
공통 텍스트·섹션 제목·기본 버튼은 `6f8fa73`, 홈은 `cc73b21`, 확대 레이아웃은 `d01873c`,
OS 하단 안전 영역은 `a9eb69d`에서 적용했습니다. 이후 선택했던 `261008`의 전체 재대조·적용은 완료하지 않았습니다.
아래 과거 조회 시각·노드·테스트 수·이미지/영상은 당시 출처와 결과로 보존하며 **이번 Page 1 기준의 새 검증으로 바꾸지 않습니다.**
`b905769`의 기준 전환은 문서만 갱신했습니다. 이후 2026-10-15에는 당시 `261008`의 D05/D09를 조회해
사진 결과의 링크 전용 문구와 성공한 제출 입력의 고정을 `a14111f`에 적용했습니다. 당시 집중 11개·관련 132개·전체 703개 검사와
정적 분석을 통과했고 양 플랫폼의 문구·입력 고정 동작을 확인했습니다. 당시 남긴 배율 2의 넘침은 아래 후속 확대 작업에서
사용자 확정 기준으로 수정하고 `5d12e9d`에서 자동·양 플랫폼 실행 검증을 완료했습니다. `b0d0c71`에서는 저장 화면 하단 안전 영역·본문/버튼 겹침을 정리하고 자동·양 플랫폼 실행 검증을 마쳤습니다. `52132f0`에서는 링크 입력의 붙여넣기 문구와 입력행 확대 높이를 수정하고 자동·양 플랫폼 실행 검증을 마쳤습니다. `52132f0` 기준의 후속 작업에서는 당시 `261008`의 D01/D02/D03의 붙여넣기 버튼 색상·테두리·명시적 Pretendard를 적용하고 자동·기기·비교 자료 검증을 마쳤습니다. 각 결과는 아래 별도 기록을 따릅니다.
이 부분 적용을 새 디자인 전체의 완료로 보고하지 않습니다.
`a54c387`을 기준으로 한 후속 작업에서는 저장 화면의 기본 1배율 글자·공통 상단을 적용하고 자동·양 플랫폼 실행·비교 검증을 마쳤습니다. 당시 `261008` D07(`912:16551`)의 원본 미확보와 나머지 저장 화면의 보류 범위는 아래 기록을 따릅니다. 새 Page 1 D07의 원본 확보가 과거 비교의 누락을 소급 해소하지 않습니다.
이후 `b082db8` 기준의 작업에서 저장 결과 미리보기 제목·콘텐츠 제목·출처의 1배율 글자까지 적용하고 새 자동 검사·양 플랫폼 실행·4쌍 비교를 확인했습니다. 저장 화면 전체 맞춤은 계속 미완료입니다.
`1036398`에 저장한 `108ef0f` 기준 작업은 당시 `261008`의 저장 결과 카테고리 제목·상태 안내·실제 이름의 1배율 글자에 한정해 적용·검증했습니다. 실제 문구·읽기 전용 카테고리·기존 상세 변경 안내는 유지합니다.

<a id="b-96ab71a8caa21d28"></a>

### Figma 공통 스타일과 기기 프리뷰

<a id="b-04c69ea3359a7c33"></a>

공통 스타일의 구현·검증 기록은 이전 `svNWsTFh8Ws1Mpt8XQIcrN / 261007` 기준입니다.
테스트 전용 프리뷰의 사용법은 유지하며 실행 성공을 새 `261008` 디자인 적용 완료로 보고하지 않습니다.

<a id="b-237eb27ab8912786"></a>

`AppText.sectionTitle`은 Pretendard 18px/SemiBold, 자간 −0.45px과 폰트 기본 행간을 사용합니다.
`SectionHeader`는 최소 높이 44px·세로 여백 각 8px이며, 긴 제목을 한 줄 말줄임으로 표시하고
오른쪽 24px 아이콘을 유지합니다. 글자가 확대되면 헤더 높이가 늘어납니다.
`AppText.primaryButtonLabel`은 기존 16px/w700을 공유합니다. 글자 색상은 각 버튼의
`foreground`를 따르며 기존 높이·모서리·탭 동작을 유지합니다.

<a id="b-d3141486599da6f6"></a>

`test/common_text_style_test.dart`는 320·375px 폭과 글자 배율 1·2에서 제목과 아이콘의 배치·탭을,
버튼 높이 52·56px에서 기본·사용자 지정 색상과 탭 동작을 확인합니다.

<a id="b-168dc3ca31025aab"></a>

```bash
# frontend/에서 실행. 연결된 Simulator 또는 Emulator ID를 지정합니다.
flutter test --no-pub test/common_text_style_test.dart

# 기본 모드: 상단 도구막대에서 home, empty, components, scaled를 선택합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_common_style_preview.dart

# 자동 모드: 화면 캡처, 합성 포인터 스크롤·탭과 컴포넌트 측정을 실행합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_common_style_preview.dart \
  --dart-define=FIGMA_COMMON_STYLE_CHECK=true
```

<a id="b-101618f168fe79aa"></a>

자동 모드는 기기 임시 폴더 `clipback-common-style-*`에 PNG 5개와 `report.json`을 저장하고,
로그에 경로와 `FIGMA_COMMON_STYLE PASS/FAIL`을 출력합니다. 홈·홈 스크롤·빈 홈·공통 컴포넌트·
글자 배율 2의 컴포넌트를 캡처합니다. 영상은 별도로 기기 화면을 촬영합니다.
`report.json`의 `passed`는 전체 실행의 성공 여부이고, `checksCompleted`는 측정·탭 시나리오를 끝까지
실행했는지 표시합니다. `componentChecksPassed`와 `componentFrameworkErrors`는 변경한 공통 컴포넌트의
검증 결과·오류를 표시하며 `frameworkErrorDetails`에는 오류가 발생한 화면을 기록합니다.
따라서 기존 홈의 오류가 남아 전체 실행이 실패해도 공통 컴포넌트 결과와 구분해 확인할 수 있습니다.
첫 공통 스타일 커밋 `6f8fa73`의 Android 실행은 기존 Weekly 카드 넘침으로 전체 `passed: false`, 공통 `componentChecksPassed: true`였습니다. 아래 홈 작업에서 같은 오류를 새로 재현하고 수정 후 재검증했습니다. 일반 배율의 홈과 글자 배율 2의 기존 하단 탭 오류를 구분합니다.
이 프리뷰는 실제 홈·공통 위젯에 메모리 데이터를 전달하며 실제 세션·HTTP·네이티브 공유 서비스를
사용하지 않습니다. 합성 포인터 검증은 사람의 수동 조작·실제 OAuth·운영 서버 검증과 구분합니다.
제품 진입점은 `lib/main.dart`이며 테스트 전용 프리뷰를 출시하지 않습니다.
플랫폼별 전체·공통 컴포넌트 실행 결과는 [프론트 진행 기록](../fe-merge-fixes.md)을 따릅니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-52caa28a8092bae6"></a>

### 2026-10-13 — Figma 공통 텍스트 스타일 첫 구현

<a id="b-b60c4c93755db83b"></a>

- 브랜치: `feature/figma-ui-alignment`, 기준: 계획 문서 커밋 `f6e2793`.
  사용자는 기존 화면 맞춤과 카테고리 삭제 시 콘텐츠 보존을 선택했다.
  이 결정은 게스트 정책 변경이나 신규 M 보완안 전체의 승인을 뜻하지 않는다.
- 첫 구현 커밋은 공통 스타일에 한정한다. `AppText.sectionTitle`은 Pretendard 18px/w600,
  자간 −0.45px과 기존 텍스트 색상을 사용한다. 본문 스타일을 상속하지 않고 `height`를 지정하지 않아
  폰트 기본 행간을 사용한다. `primaryButtonLabel`은 기존 16px/w700을 옮기며 색상을 지정하지 않는다.
- `SectionHeader`는 제목의 남은 폭을 `Expanded`로 제한하고 한 줄 말줄임을 적용한다.
  최소 높이 44px·세로 여백 각 8px·오른쪽 24px 아이콘을 사용하며 글자 확대 시 높이가 늘어난다.
  `PrimaryButton`의 높이 52/56px, 기본·사용자 지정 foreground·배경·8px 모서리·클릭을 보존한다.
  기존 생성자와 콜백 인터페이스, API·데이터 모델·저장·삭제 처리를 변경하지 않는다.
- 홈의 공통 섹션 제목 3곳에 적용했다. 홈 배치·문구·일러스트·페이지 점·추천 연결은 미착수이며,
  이번 결과를 홈 전체의 Figma 일치로 보고하지 않는다. 승인된 콘텐츠 보존 정책은 계획의 DEC-01에 반영했다.
- 구현 직전에 Figma `111:3604`의 최근 콘텐츠 제목·chevron 디자인 컨텍스트와 스크린샷을 새로 조회했다.
  기존 로컬 chevron 에셋은 329바이트, 24×24 viewBox이며 실제 24px 렌더링을 확인해 재사용했다.
- 이번 SDK는 Flutter **3.44.9 / Dart 3.12.2**다. 기존 잠금파일을 사용하고 의존성을 변경하지 않았다.
- 수정 전 `flutter test --no-pub test/common_text_style_test.dart`는 긴 제목 **4 failed**, 버튼 **4 passed**였다.
  폭 320/375px·글자 배율 1/2에서 오른쪽 넘침 78/413/23/358px을 재현했다.
  수정 후 같은 명령으로 **8 passed**를 확인했다. 실제 Pretendard 폰트와 Material 3 테마를 사용한다.
- `flutter test --no-pub --reporter expanded` **560 passed**, `flutter analyze --no-pub` **문제 없음**을 확인했다.
  변경 Dart 파일의 형식 검사도 **0 changed**였다. 기존 안전 영역 검사는 전체 테스트에 포함된다.
- [기기 프리뷰](../../frontend/test/support/figma_common_style_preview.dart)는 실제 홈과 공통 위젯에 메모리 데이터를
  전달한다. 실제 세션·HTTP·네이티브 공유 서비스를 사용하지 않으며 제품 `main.dart`에 테스트 분기를 추가하지 않는다.
  기본 모드는 상단 도구막대로 화면을 전환하고, 자동 모드는 합성 포인터로 홈 스크롤·제목/아이콘/버튼 탭을 확인한다.
  기기 임시 폴더에 PNG 5개와 측정·콜백·프레임워크 오류를 담은 `report.json`을 기록한다.
- iOS **iPhone 16 / iOS 18.6 Simulator**: 최종 Xcode 빌드 30.6초 후 실행했다.
  논리 크기는 393×852, 안전 영역은 위 59px·아래 34px이다. 결과는 `passed: true`,
  `checksCompleted: true`, `componentChecksPassed: true`, 프레임워크 오류 **0건**이었다.
- Android **Clipback_Share_API_33 / Android 13(API 33) Emulator**: AVD는 Pixel 3a 설정이고
  실제 시스템 모델은 `sdk_gphone64_arm64`다. Gradle 빌드 195.4초·설치 79.5초 후 실행했다.
  논리 크기는 392.7×783.3, 안전 영역은 위 24px·아래 0px이다. 측정·탭은 끝까지 실행했고
  `checksCompleted: true`, `componentChecksPassed: true`, 공통 컴포넌트 프레임워크 오류 **0건**이었다.
  **전체 결과는 `passed: false`**다. 기존 홈 Weekly 카드의 `Column`에서 아래쪽 넘침 13px·3px이 발생했다.
- Android 홈 넘침은 이번 공통 스타일 오류와 구분한다. 2026-10-12 모바일 공유 기록에도 13px 넘침이 있으며,
  이번 변경에는 `home_screen.dart`가 포함되지 않는다. 일반 섹션 제목 높이도 기존 44px을 유지했다.
  이 홈 레이아웃 문제는 UI-04~05 후속 작업으로 남기고 Android 홈 전체를 통과했다고 보고하지 않는다.
- 양 플랫폼에서 일반 제목 높이 **44px**, 글자 배율 2에서 **59px**, 아이콘 **24px**을 확인했다.
  버튼 높이 **56/52px**, 기본 foreground `AppColors.main`·사용자 지정 `AppColors.text`와 탭 1회 호출도 확인했다.
  제목·좌측 여백·아이콘을 각각 누른 콜백은 배율별 3회로 총 6회였고 각 버튼은 배율별 1회로 총 2회였다.
  120px 합성 포인터 이동으로 홈 스크롤은 iOS 78px·Android 110px 변했으며 카테고리 제목 탭 콜백은 각각 1회였다.
- 보고서에는 전체 `passed`와 별도로 `checksCompleted`, `componentChecksPassed`, `componentFrameworkErrors`,
  화면별 `frameworkErrorDetails`를 기록했다. 오류를 지우거나 공통 컴포넌트 통과를 전체 홈 통과로 확대하지 않는다.
- 증거는 Git에서 제외된 `frontend/build/verification/figma-ui-01/{ios,android}/`에 보관한다.
  각 플랫폼 PNG 5개(`00_home`, `01_home_scrolled`, `02_empty_home`, `03_components`, `04_components_scale_2`)와
  `report.json`과 플랫폼별 `interaction.mp4`를 확보하고 화면·영상의 실제 검증 장면을 확인했다.
  영상에는 홈 스크롤·제목 탭·버튼 탭·글자 확대 전환이 포함되며, Android의 기존 홈 넘침도 그대로 남겼다.
- 실제 OAuth·AI/OCR·운영 서버·실기기·원격 CI는 이번 공통 스타일 검증 범위에 포함하지 않는다.
  검증에 사용한 Flutter 실행·촬영·Simulator·Emulator는 종료했다.
  최종 diff·문서 링크·공백 검사는 커밋 직전에 수행한다. 로그·PNG·영상·빌드 생성물·`AGENTS.md`는 커밋에서 제외한다.
