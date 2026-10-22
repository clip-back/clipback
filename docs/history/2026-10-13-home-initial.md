# 홈의 확정 영역 첫 적용

- 최초 기록일: 2026-10-13
- 영역: UI
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: frontend/README.md

<a id="b-ff1f5ef18a3cfa5c"></a>

### 홈 화면 맞춤 검증

<a id="b-0f8c0ce223b965b6"></a>

홈 커밋 `cc73b21` 당시 기준은 이전 파일 `svNWsTFh8Ws1Mpt8XQIcrN / 261007`의
C01 `111:3584`·C02 `111:3681`입니다. 당시 적용 영역과 과거 증거는
[Figma 화면 맞춤 계획](../figma-ui-alignment-plan.md)에 보존하며 새 기준·현재 보류 항목도 같은 문서를 따릅니다.
새 빈 홈은 `feed.initialized`, 로딩/오류 없음, 양쪽 필터 ID 없음과 콘텐츠 0개가 모두 확인될 때만 표시합니다.
미조회·필터 결과 없음·로딩·오류는 기존 표현을 유지합니다. 현재 최근 카테고리 블록도 유지합니다.

<a id="b-8aba70652798f248"></a>

홈 추천·최근 카드는 기본 크기 133×120px·298×186px이며 글자 확대 시 높이가 늘어납니다.
제목·요약은 각각 최대 2·3줄이고 요약은 카드의 남은 공간을 넘지 않습니다.
페이지 점은 최대 4개 카드의 중심을 기준으로 바뀝니다. 필터·피드 버전·표시 콘텐츠 ID 순서 변경은
첫 카드로 초기화하고, 북마크만 변경되면 현재 위치를 보존합니다. 추천 목적지는 현재 연결을 유지합니다.

<a id="b-9d3f5718d3a3e74e"></a>

```bash
# frontend/에서 실행합니다.
flutter test --no-pub test/home_alignment_test.dart test/top_safe_area_test.dart

# 제품 수정 전에 양 플랫폼에서 before 실행을 마친 뒤 원본 PNG/보고서를 보존합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_home_preview.dart \
  --dart-define=FIGMA_HOME_CHECK=true --dart-define=FIGMA_HOME_PHASE=before

# 수정 후 같은 기기·대역 데이터·글자 배율·스크롤 위치로 재촬영하고 동작을 검증합니다.
flutter run --no-pub -d <device-id> -t test/support/figma_home_preview.dart \
  --dart-define=FIGMA_HOME_CHECK=true --dart-define=FIGMA_HOME_PHASE=after
```

<a id="b-78e91e296360b333"></a>

이 전용 진입점은 실제 `HomeScreen`에 고정된 콘텐츠 4개/0개와 동일한 카테고리·조회 완료 상태를 전달합니다.
제품 `main.dart`나 서버 API를 변경하지 않고 실제 세션·HTTP·저장을 사용하지 않습니다.
자동 입력은 Flutter 합성 포인터입니다. 저장 시트 진입·키보드·닫기까지 확인하며 실제 저장 완료 검증은 아닙니다.
기기 임시 폴더 `clipback-home-*`에 PNG와 `report.json`을 저장하고 `FIGMA_HOME PASS/FAIL`을 출력합니다.
현재 프리뷰는 정상/빈 홈·각 배율 2·긴 카테고리의 빈 홈 배율 1/2, 총 여섯 상태를 수정 전후 각각 촬영합니다.
현재 프리뷰는 양 phase 모두 스크롤·마지막 카드·저장 입력의 키보드·확대 카드 관련 동작 다섯 장을 추가로 촬영해 총 11장을 남깁니다.
`baselineCaptured`는 여섯 비교 상태 촬영 완료 여부이며, 오류가 있어도 촬영 성공을 전체 검증 성공으로 바꾸지 않습니다.
`frameworkErrors`, `checksCompleted`, `passed`, 콜백·스크롤 측정값을 함께 확인합니다.
`normalHomeChecksPassed`·`interactionChecksCompleted`·`scaledScenesCaptured`는 일반 홈/동작/확대 촬영의 별도 결과입니다.
프레임워크 오류가 있으면 전체 `passed: false`로 기록하고 촬영 성공과 구분합니다.
이번 OS 작업의 `before` 통과는 기존 화면·동작의 기록이며, 새 OS 안전 영역 기준은 `after`에서만 판정합니다.
영상은 별도 `simctl recordVideo`/`adb screenrecord`로 촬영합니다. 화면 증거·로그·빌드 결과는 Git에서 제외합니다.
이전 홈 커밋 `cc73b21`은 전체 Flutter 테스트 **595 passed**, 정적 분석 문제 없음과 양 플랫폼 일반 배율의
홈·저장 진입·스크롤·페이지 점을 확인했습니다. 당시 배율 2의 하단 탭과 좁은 최근 카테고리 행 오류는 보류했고,
후속 승인에 따른 변경과 이번 재검증 결과는 아래에 구분합니다.
변경 전·후·Figma 3열 비교와 영상은 [프론트 진행 기록](../fe-merge-fixes.md)에 기록합니다.

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-d7f8c1cb5dcab8af"></a>

### 2026-10-13 — Figma 기준 홈의 확정된 영역 적용

<a id="b-2567a7bb6af7a7bc"></a>

- 브랜치 `feature/figma-ui-alignment`, 수정 전 기준 `6f8fa73`.
  홈 상단(8+56px), 소개(기본 140px/좌측 16px/캐릭터 99×123px/버튼 모서리 8px),
  추천(133×120px), 최근 카드(298×186px), 홈 칩(기본 32px), 페이지 점을 적용했다.
  글자 확대에는 높이를 늘리고 제목 2줄·요약 3줄 및 실제 남은 공간 제한을 적용한다.
  Weekly 제목만 화살표를 숨기며 다른 공통 헤더 기준·기존 연결은 유지했다.
- 빈 홈은 필터 없음·조회 완료·로딩/오류 없음·양쪽 콘텐츠 목록 0개를 확인한 경우에만 C02를 표시한다.
  ‘아직 저장한 콘텐츠가 없어요.’·‘지금 하나만 저장해볼까요?’·‘첫 콘텐츠 저장하기’와 기존 저장 진입을 사용한다.
  필터 빈 목록·미조회·로딩·오류는 기존 표현을 유지한다. 최대 4개 카드와 콘텐츠 보존 정책도 유지한다.
- 페이지 점은 카드 중심(offset/306)으로 갱신한다. 필터·피드 버전·복사한 표시 ID 순서 변경 시 위치와 점을
  초기화하고 북마크만 변경되면 유지한다. 북마크 44×44px 탭 영역을 카드 안에 배치해 경계 잘림도 방지했다.
- Figma C01 `111:3584`·C02 `111:3681`의 컨텍스트와 원본 375×910 화면을
  **2026-10-13 20:58:44 KST / 11:58:44 UTC**에 새로 조회했다.
  기존 캐릭터 PNG는 여백/잘림이 달라 재사용하지 않았다. `111:3678`의 SVG가 모바일에서 빈칸으로
  렌더링되는 것을 확인해 같은 개별 노드를 Figma에서 3배율 PNG(297×369px)로 내보냈다.
  `111:3712` 상자는 원본 PNG 71×82px를 논리 67×78px 및 그림자 여유로 배치했다.
  Figma 전체 화면 이미지는 구현 에셋으로 사용하지 않았다. 임시 Figma URL도 앱에 남기지 않았다.
- **제품 수정 전** 동일한 데이터로 두 플랫폼의 정상/빈 홈을 새로 캡처했다.
  iOS는 오류 0건, Android는 기존 추천 카드 아래 넘침 **13px·3px**을 재현했다.
  추가 OS 포함 스크린샷은 수정 전 설치된 동일 baseline 바이너리를 직접 재실행해 촬영했다.
  수정 전·후 보고서의 콘텐츠 ID·카테고리·피드 상태·기종/크기·배율 1·스크롤 0이 일치함을 확인했다.
- 수정 전 홈 회귀 테스트 29개는 **6 passed / 23 failed**였으며 Android 추천 넘침을 재현했다.
  최종 홈 35개 + 안전 영역 11개 + 콘텐츠 변경 61개는 **107 passed**다.
  폭 320/375px·iOS/Android 테마·배율 1/2의 긴 문구, 0/1/4개, 실제 포인터 드래그와 점,
  필터/버전/ID 변경 초기화·북마크 위치 보존·처리 중 비활성화·북마크 네 모서리 탭을 검증했다.
  기존 콘텐츠 변경 테스트의 카테고리 탐색을 현재 홈 전용 태그 구조에 맞추고 기존 크기/말줄임 검사를 유지했다.
- 최종 `flutter test --no-pub --reporter expanded` **595 passed**,
  `flutter analyze --no-pub` **문제 없음**, 변경 Dart 8개 형식 검사 **0 changed**다.
  Flutter 3.44.9 / Dart 3.12.2, 기존 잠금파일을 사용하며 의존성을 변경하지 않았다.
- [홈 기기 프리뷰](../../frontend/test/support/figma_home_preview.dart)는 실제 HomeScreen과 고정 메모리 데이터를 사용한다.
  제품 진입점·API·데이터 모델·저장 시점·콘텐츠 보존은 변경하지 않았다. 실제 세션/HTTP/저장을 사용하지 않는다.
  합성 포인터로 today/archive/content/bookmark를 각각 1회 확인하고 북마크의 콘텐츠 탭 전파가 없음을 확인했다.
  가로 드래그의 마지막 점은 **3/4**, 실제 저장 시트의 키보드 표시 및 닫기를 양쪽에서 확인했다.

<a id="b-5cb5404a32e5c941"></a>

| 플랫폼 | 이번 실행 결과 |
| --- | --- |
| iPhone 16 / iOS 18.6 Simulator | 앱 논리 크기 393×852, DPR 3, 안전 영역 위 59/아래 34px. 일반 배율 홈 오류 0건, 세로 스크롤 0→83px, 키보드 약 335.85px. 배율 2 카드 높이 316px를 추가 스크롤 후 viewport 안에서 확인했다. |
| Pixel 3a 설정 Clipback_Share_API_33 / Android 13 API 33 Emulator (`sdk_gphone64_arm64`) | 앱 논리 크기 392.7×783.3, DPR 2.75, 안전 영역 위 24/아래 0px. 일반 배율 홈 오류 0건이며 기존 추천 13px·3px 넘침이 사라졌다. 세로 스크롤 0→116.73px, 키보드 약 251.64px. 배율 2 카드 높이 316px를 viewport 안에서 확인했다. |

<a id="b-0a61553494112ac3"></a>

- **기기 전체 결과는 양쪽 모두 `passed: false`**다. 글자 배율 2의 기존 하단 탭 Column에서
  9px·43px 아래 넘침이 정상/빈 홈에 각각 발생해 플랫폼별 프레임워크 오류 **8건**을 보존했다.
  `checksCompleted`, `normalHomeChecksPassed`, `interactionChecksCompleted`, `scaledScenesCaptured`는 모두 true다.
  일반 배율 홈/동작 성공을 확대 전체 화면 성공으로 보고하지 않는다.
- 별도 좁은 화면 검사에서 기존 최근 카테고리 행의 가로 넘침도 확인했다.
  K02 `111:4667`·K03 `111:4683`의 미정 본문/상태, 필터·로딩·오류,
  확대 하단 탭/좁은 최근 카테고리 행은 [디자인 확인 필요 목록](../figma-ui-alignment-plan.md)에 기록했다.
  새 안내·공지 카드/상세는 보류하고 현재 최근 카테고리 블록을 유지한다. Today/Weekly API·추천/공지 목적지·
  실제 읽지 않은 알림 데이터 연결은 후속 작업이며 고정 알림 점을 추가하지 않았다.
- 아래 비교는 OS 포함 원본 PNG다. Figma는 375×910·상태바 50px이며 실제 기기 크기/안전 영역이 다르다.
  앱 PhoneFrame의 최대 폭 375px 및 양쪽 여백, 네이티브 상태/제스처 영역을 보정하거나 잘라내지 않았다.
  기존 앱 내부 홈 인디케이터와 실제 OS 인디케이터 처리도 그대로 보인다.
  빈 홈은 안내·공지 카드 보류와 최근 카테고리 유지로 아래쪽 배치가 C02와 다르다.
  예시 콘텐츠/카테고리/북마크 차이는 고정 대역 데이터와 Figma 예시 데이터 차이다.
- 화면 증거는 아래 로컬 폴더에 보관하며 **Git에서 제외**했다. 프레임워크 PNG 7개/플랫폼과 OS 포함
  PNG 7개/플랫폼, report.json, 로그·영상 및 Figma 기준을 보존한다. 첫 재시도의 SVG 빈칸 증거도 after/initial에 보존했다.

<a id="b-44b60613915dcbf2"></a>

증거 루트: `/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment`.

<a id="b-5c2365bc28654c6e"></a>

| 비교 | 변경 전 | 변경 후 | Figma 원본 |
| --- | --- | --- | --- |
| iOS 정상 홈 | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/before/native_00_home.png) | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/after/native_00_home.png) | [C01](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/figma/C01.png) |
| iOS 빈 홈 | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/before/native_01_empty_home.png) | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/after/native_01_empty_home.png) | [C02](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/figma/C02.png) |
| Android 정상 홈 | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/before/native_00_home.png) | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/after/native_00_home.png) | [C01](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/figma/C01.png) |
| Android 빈 홈 | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/before/native_01_empty_home.png) | [원본](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/after/native_01_empty_home.png) | [C02](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/figma/C02.png) |

<a id="b-0b30126c59b1f86c"></a>

페이지 점·스크롤·저장 시트·키보드와 확대 상태를 담은 영상:
[iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/after/interaction.mp4), [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/after/interaction.mp4).
보고서: [iOS](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/ios/after/report.json), [Android](/Users/leehyeongyu/.codex/visualizations/2026/10/13/01a134c9-8406-7d63-99b0-73cf2847c45a/home-alignment/android/after/report.json).

<a id="b-8b625226420a0f37"></a>

- 첫 실행은 디스크 공간 부족으로 빌드가 실패했다. 저장소의 재생성 가능한 테스트/웹/해시 빌드 캐시만 정리한 뒤
  다시 빌드·실행했다. 기존 화면 증거와 사용자 파일·AVD·세션/DB 데이터는 보존했다.
- 실제 OAuth·운영 서버·실기기·실제 저장 완료·원격 CI는 이번 검증 범위에 포함하지 않는다.
  최종 diff·로컬 문서 링크 83개·공백·생성 파일/민감 정보 제외를 확인했다. 변경 13개 파일만 한 커밋으로 저장한다.
  푸시·PR은 수행하지 않는다. AGENTS.md는 계속 로컬 제외 파일로 유지한다.

<a id="b-98aa8ef6e7aa9990"></a>

- 최종 H.264 영상은 iOS 약 86초·Android 약 169초이며 ffprobe와 영상 장면을 확인했다.
  Flutter·녹화 세션과 이번 작업에서 실행한 Simulator/Emulator를 종료했고 기존 기기 데이터는 보존했다.

## 원문 출처: docs/figma-ui-alignment-plan.md

<a id="b-115a405138de8266"></a>

### 홈 커밋의 적용 범위와 디자인 확인 필요

<a id="b-c247a08f7f40c1f2"></a>

홈 작업 기준은 `6f8fa73`이다. Figma C01 `111:3584`·C02 `111:3681`의 디자인 컨텍스트와
원본 375×910 스크린샷을 2026-10-13 20:58:44 KST(11:58:44 UTC)에 새로 조회했다.
아래 완료 영역은 당시 `261007` 기준의 기록이다. 이어지는 디자인 확인 목록은 이번에 Page 1 노드로 갱신했으며 아래 과거 기기 검증은 다시 실행하지 않았다.

<a id="b-ed2133b8de8162df"></a>

| 적용 영역 | 완료 기준 |
| --- | --- |
| 상단·소개 | 홈만 상단 여백 8px + 내부 56px, 소개 기본 높이 140px·좌측 16px·캐릭터 99×123px·버튼 모서리 8px. 좁은 화면·글자 확대에는 글자를 줄이지 않고 필요한 높이를 늘린다. |
| 정적 에셋 | 기존 PNG의 여백·잘림이 기준과 달라 C01 캐릭터 `111:3678`을 개별 PNG로 내보내고 99×123px으로 표시한다. 원본 PNG는 3배율 297×369px이며 잘림·투명도를 유지한다. 모바일에서 SVG 패턴이 빈칸으로 렌더링되어 동일 노드의 PNG를 사용한다. C02 상자 `111:3712`는 원본 PNG 71×82px를 67×78px 논리 영역과 그림자 여유(좌우 2px·아래 4px)로 배치한다. 전체 화면 이미지를 구현 에셋으로 사용하지 않는다. |
| 확인된 빈 홈 | 필터 없음·조회 완료·로딩/오류 없음·콘텐츠 0개가 확인되면 ‘아직 저장한 콘텐츠가 없어요.’·‘지금 하나만 저장해볼까요?’·‘첫 콘텐츠 저장하기’를 표시한다. 기존 저장 시트를 연다. 미확인/필터 빈 목록은 기존 표현을 보존한다. |
| 추천·최근 콘텐츠 | 추천 기본 133×120px·문구 최대 2줄, 최근 콘텐츠 기본 298×186px·제목 최대 2줄·요약 최대 3줄과 남은 공간 제한. 글자 확대에는 높이를 늘리고 변경 처리 상태도 보존한다. |
| 칩·제목 | 홈 카테고리 칩 기본 높이 32px, 선택 배경 #E4E4E4/글자 #484848·미선택 글자 #D1D1D1. Weekly 제목만 오른쪽 화살표를 숨기고 다른 SectionHeader의 기본 표시는 유지한다. |
| 페이지 점 | 최대 4개·가로 스크롤 유지. 카드 중심을 기준으로 점을 갱신한다. 필터·피드 버전·표시 ID 순서 변경 시 위치와 점을 초기화하고 북마크 상태만 바뀌면 유지한다. |

<a id="b-dfcd7666c5614cc3"></a>

### 디자인 확인 필요

<a id="b-a26de92ddd5e9b2b"></a>

현재 목록은 **Page 1 > `261007`의 이번 메타데이터 확인**과 기존 사용자 확정 기준을 구분한다.
기본 프레임·상세 컨텍스트의 확보, 적용 완료 기록, 상태별 디자인·데이터 계약 확정은 서로 다르다.
아래의 과거 적용·검증 완료는 이번 Page 1 기기 검증을 뜻하지 않는다.

<a id="b-167e5d4f74381746"></a>

UI-04·UI-05·UI-06은 당시 기록의 적용 영역만 부분 완료다. UI-09 상세와 UI-08 카테고리 목록·관리 본화면도 아래 각 독립 기록의 승인 영역만 완료다. 전체 화면 재대조·추천 API·미정 상태는 후속 범위다.

<a id="b-317c15edaa4dbbf2"></a>

### 홈 커밋 `cc73b21`의 실제 검증 결과

<a id="b-ddadd71babac44b1"></a>

- 관련 검사 107개, 전체 Flutter 테스트 595개와 정적 분석·형식 검사를 통과했다.
- iPhone 16/iOS 18.6 및 Android 13/API 33에서 일반 배율의 홈·빈 홈·페이지 점·탭·저장 시트/키보드를 확인했다.
  Android의 기존 추천 카드 13px·3px 넘침은 수정 후 사라졌다.
- 배율 2의 홈 카드 자체는 높이 316px로 커져 양쪽 viewport 안에서 확인했다.
  전체 화면은 기존 하단 탭 넘침 때문에 플랫폼별 8건 오류와 `passed: false`를 유지한다.
  좁은 화면의 기존 최근 카테고리 행도 당시에는 디자인 확인 대상으로 보류했다.
  해당 두 항목의 후속 승인과 재검증은 아래 확대 레이아웃 작업에 별도로 기록한다.
- 원본 변경 전·후·Figma의 플랫폼별 3열 비교와 영상, 동일 조건 대조·측정값·한계는
  [이번 진행 기록](../fe-merge-fixes.md#2026-10-13--figma-기준-홈의-확정된-영역-적용)에 남겼다.
  이번 결과를 C01·C02 전체 완료나 실기기/운영 서버 검증으로 확대하지 않는다.
