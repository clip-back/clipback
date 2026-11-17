# 아카이브 정렬 팝업 폭 149 (#423, 팀 피드백 시트 123)

2026-11-17, 브랜치 `fix/sort-popup-width`. 시작 커밋 `accf960`. 구현 `31475ef`, 검수 반영 `9bf71ab`. 구현·검수·전체 검증·양 플랫폼 변경 전·후 화면 확인을 기록했다. 사용자 시각 판정은 남았다.

## 문제

아카이브 전체보기(E01)·카테고리별 목록(F01)의 정렬 팝업에서 '즐겨찾기 우선'이 선택된 줄(문구와 체크)이 Android 14 이상 글자 1.3배와 iOS xxxL에서 줄 폭 113을 넘었다. 폭 145는 #198에서 선형 1.3배(14→18.2)로 잰 값인데, 실제 Android 14+는 1.3배를 비선형으로 적용해 14sp를 18.8로, iOS xxxL은 23/17(≈1.3529)로 키운다. 측정·원인 표는 이슈 #423 본문에 있다.

## 사용자 결정

2026-11-17 "추천대로 해줘": 팝업 폭 145 → 149, 패딩·체크·글자 크기 그대로(#198 방식 유지, 재는 배율만 실제 플랫폼 값). 0.6.2에 넣는다.

## 바꾼 것

- `frontend/lib/features/archive/archive_widgets.dart`: 정렬 팝업 `BoxConstraints.tightFor(width: 145)` → `149`. 그 밖 제품 코드 변경 없음. E01·F01이 같은 위젯을 쓴다.
- 새 테스트 `frontend/test/sort_popup_platform_scale_test.dart`: 루트 앱 병합 테마·실제 Pretendard, 폭 320에서 `ArchiveToolbar(archiveAllStyle: true)`의 팝업을 연다. Android 비선형 1.3(Android SDK android-36.1 `FontScaleConverterFactory.java:101–108` 표를 옮긴 `TextScaler`)과 iOS xxxL(`TextScaler.linear(23 / 17)`) × 선택(최신순·즐겨찾기 우선) 4개와 표 단위 테스트 1개. 팝업 문구가 넣은 배율을 받는지, 선택 체크가 하나이고 줄(Row) 오른쪽 안에 있는지, 넘침 오류가 없는지 본다. 폭 상수는 단언하지 않는다.
- `docs/figma-ui-alignment-plan.md` figma-current-36 폭 값·근거·링크, `CHANGELOG.md` 미배포 수정 한 줄.

기존 테스트는 바꾸지 않았다(이슈 허용 표 모두 "바꾸지 않음").

## 검사

- 테스트 먼저: 145에서 Android 비선형 1.3·즐겨찾기 우선과 iOS xxxL·즐겨찾기 우선 두 테스트가 실패(넘침 2.5·3.3), 148 변형에서는 iOS xxxL·즐겨찾기 우선만 실패(0.265), 149에서 통과. 검수 반영 뒤 체크 위치 단언도 145에서 실패(체크 오른쪽 147.50·148.27 > 줄 145)하고 149에서 통과했다. 바꾼 부분 실행(새 테스트를 포함한 정렬 관련 6파일) 140개 통과.
- 전체 검증 `verify.py`: HEAD `9bf71ab`, 작업 트리 변경 없음에서 `VERIFY result=PASS scope=all checks=12 failed=0`. 앱 3명령(`dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub` 3,943개 통과)은 그 verify의 같은 단계로 확인했다. 백엔드 pytest 2,751 통과·49 건너뜀(Docker 배포 복구 48, 로컬 S3 1).
- 검수(`31475ef`, Claude Opus high): 높음·중간 0, 낮음 4. 체크 위치 단언 추가, CHANGELOG를 Android 14 이상으로 좁힘, 정렬 탭 흐름 테스트 파일을 부분 실행에 더함은 반영했다. 공유 helper `withThemeFontApp`에 배율 인자를 더하자는 제안은 이슈 허용 범위 밖의 지원 파일 변경이라 하지 않고, 같은 흐름이라는 주석만 남겼다.
- 기기 측정 스크립트 `test/support/archive_all_preview.dart`의 정렬 탭 기록과 `category_content_preview.dart`의 정렬 기록은 기기 `/run`에서만 돌아, 이번에는 컴파일만 확인했다(flutter test에 포함).

## 화면 확인

로컬 메모리 데이터(홈 대역 콘텐츠 4개), 맨 위 스크롤, E01 아카이브 전체보기. 변경 전은 시작 커밋 `accf960`, 변경 후는 `9bf71ab` debug 빌드. 같은 진입 파일로 아카이브 탭 → 정렬 버튼 → '즐겨찾기 우선' → 정렬 버튼 다시 열기 순서로 눌렀다. 글자 크기는 OS 설정으로 바꾸고 끝나면 되돌렸다(iOS `large`, Android `1.0` 확인). 열린 팝업은 촬영 진입 파일에 팝업 화면으로 등록해 찍었다(작업 폴더 `.utmp`, 커밋 안 함).

| 플랫폼 | 기종·OS | 논리 크기 | OS 안전 영역(위/아래) |
| --- | --- | --- | --- |
| iOS Simulator | iPhone 16, iOS 18.6 | 393×852 | 59 / 34 |
| Android Emulator | Medium_Phone, Android 16(API 36) | 411.43×914.29 | 24 / 24 |

| 상태 | OS 글자(앱이 받은 14px) | 변경 전: 줄 오른쪽 · 체크 오른쪽 | 변경 후: 줄 오른쪽 · 체크 오른쪽 |
| --- | --- | --- | --- |
| 정렬 버튼 닫힘 | iOS large·Android 1.0(14) | 버튼 그대로 | 버튼 그대로 |
| 팝업, 즐겨찾기 우선 선택 | iOS large(14) | 145 · 145, 넘침 없음 | 149 · 149, 넘침 없음 |
| 팝업, 즐겨찾기 우선 선택 | iOS xxxL(18.94) | 145 · 148.27, 넘침 띠 "RIGHT OVERFLOWED BY 3.…" | 149 · 149, 띠 없음 |
| 팝업, 즐겨찾기 우선 선택 | Android 1.0(14) | 145 · 145, 넘침 없음 | 149 · 149, 넘침 없음 |
| 팝업, 즐겨찾기 우선 선택 | Android 1.3(18.8) | 145 · 147.48, 넘침 띠 "RIGHT OVERFLOWED BY 2.5 PIXELS" | 149 · 149, 띠 없음 |

- 줄 왼쪽은 전·후 모두 32, 팝업 위치·높이·'최신순' 줄은 같고 오른쪽만 4 넓어졌다. '최신순' 줄은 모든 상태에서 넘치지 않았다.
- 보호 검증: 팝업을 열지 않은 아카이브 목록에서 팝업 촬영을 시도하면 두 플랫폼 모두 찍지 않고 실패했다. 위젯 확인에서 1.7배 넘침을 넣으면 체크 위치 판정이 실패했다.
- 넘침 판정은 화면의 넘침 띠와 앱 위치 값으로 했다. 이번 촬영 실행에서는 iOS 기기 로그·Android logcat 어디에도 Flutter 넘침 오류 줄이 남지 않았다.
- 변경 전·변경 후·Figma 3열 비교: 작업 폴더 `.utmp/ticket-423-screens/compare-ios.png`·`compare-android.png`(커밋 안 함), 촬영 조건 일치 검사 통과. Figma는 닫힌 상태만 E01 `111:4117`(2026-11-17 14:38 KST 조회, 375×1102 내보내기)이고 열린 팝업 원본은 없다(2026-11-03 조회).
- 남은 확인: 사용자 시각 판정. 실기기·운영(release) 앱 확인은 하지 않았다. Android 1.5배 이상·iOS 접근성 큰 글자 단계는 범위 밖이다.
