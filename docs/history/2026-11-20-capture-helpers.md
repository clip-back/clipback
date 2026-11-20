# 촬영 helper 두 개를 지금 앱 동작에 맞추기 (#431, 팀 피드백 시트 120·121)

2026-11-20, 브랜치 `test/capture-helpers-120-121`. 시작 커밋 `b4e1cd8`. 구현 `20f180a`(120)·`c620033`(121), 검수 반영 `9cecab3`. 앱 코드(`frontend/lib`)는 바꾸지 않았다.

## 문제

상세 화면 helper(`frontend/test/support/detail_preview.dart`)와 카테고리 콘텐츠 helper(`frontend/test/support/category_content_preview.dart`)의 `/run`이 #247 이후 앱 동작을 따라가지 못해 HTTP 500으로 멈췄다. 원인과 허용 범위 표는 이슈 #431 본문에 있다.

## 사용자 결정

- 시트 120 "추천대로" = A: 원본 시트를 열 때 권한을 다시 확인하는 앱 동작은 그대로 둔다. helper의 원본 사진 단언을 "시트 열기에서 권한 재확인 = 읽기 누적 2회, 같은 사진"으로 고친다.
- 시트 121과 묶어 한 이슈로 진행한다. 2026-11-20 이슈 승인 "올려 (추천)".

## 바꾼 것

- 120 `detail_preview.dart`: 시트를 연 뒤 `readAsset` 누적 2회와 두 호출의 assetId가 같은지 확인한다. 시트 이미지가 같은 바이트이고 `BoxFit.contain`인지 보는 단언은 그대로다. 실패 문구와 기록 이름은 `photo_original_sheet_access_rechecked`로 바꿨다(이슈 허용 표 범위).
- 121 `frontend/test/fixtures/category_content_fixture.dart`:
  - 목록 응답이 거른 전체 개수 `total_count`를 준다(카테고리 101 = 6).
  - `GET /api/v1/recommendations/weekly`에 빈 추천을 답한다. 다른 메서드는 기존처럼 `unexpected`에 남기고 501로 답한다(검수 반영).
  - 측정의 개수 글자는 `총 ${displayTotalCount ?? 불러온 개수}개`로 찾는다.
- 121 `category_content_preview.dart`: 삭제 단계에서 확인 창의 '삭제'(`content-delete-confirm`)까지 누른다.
- 121 `frontend/test/category_content_fixture_contract_test.dart`: `total_count == 6` 단언 한 줄을 더했다. 다른 기존 테스트는 바꾸지 않았다.

## 검사

- 재현: 시작 커밋에서 iPhone 16 / iOS 18.6 Simulator로 돌렸다. 두 helper 모두 이슈와 같게 HTTP 500이었다.
  - 상세: "Original photo sheet must share one local read callback…" 오류, `readAsset` 2회(assetId 9, 9).
  - 카테고리: 첫 단언 실패, `countLabel=null`, 주간 추천 요청 2건이 `unexpected`로 남았다.
- 테스트 먼저: contract 테스트에 넣은 `total_count` 단언이 수정 전에 실패했다(Actual null).
- 바꾼 부분 실행: 120은 `screenshot_asset_test.dart`·`sheet_safe_area_test.dart` 35개 통과. 121은 contract·alignment·geometry 46개 통과, 검수 반영 뒤 메서드 확인 테스트를 더해 47개 통과.
- 전체 검증 `verify.py`: HEAD `9cecab3`, 작업 트리 변경 없음에서 `VERIFY result=PASS scope=all checks=12 failed=0`.
  - 앱 3명령(`dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub` 3,943개 통과)은 이 verify의 같은 단계로 확인했다.
  - 백엔드 pytest는 2,751 통과·49 건너뜀(Docker 배포 복구 48, 로컬 S3 1).
- 검수(`20f180a`·`c620033`): 높음·중간 0, 낮음 1. "주간 추천 분기가 메서드를 보지 않는다"를 반영해 GET에만 답하게 했다.

## 기기 실행 확인

로컬 대역 데이터로 `flutter run --no-pub -d <기기> -t <helper> --dart-define=<PHASE>=after`를 실행했다. `/ready`가 200이 된 뒤 `curl http://127.0.0.1:8767/run`을 불렀다(Android는 `adb forward tcp:8768 tcp:8767` 뒤 8768). 커밋 `c620033` debug 빌드다.

| 기기 | 상세 helper | 카테고리 콘텐츠 helper |
| --- | --- | --- |
| iPhone 16, iOS 18.6 Simulator | HTTP 200, 오류 없음, 원본 시트 권한 재확인·하단 탭 4개·뒤로 기록 통과 | HTTP 200, `behaviorPassed=true`, `unexpected` 0건, 화면 오류 0건, 18개 기록 통과, 툴바 `총 6개` |
| Medium_Phone, Android 16(API 36) Emulator | iOS와 같음 | iOS와 같음 |

- 검수 반영(`9cecab3`)은 기기에서 다시 돌리지 않았다. 앱은 주간 추천을 GET으로만 보내므로(`frontend/lib/clipback_api.dart` 847행) 기기 결과는 달라지지 않는다.
- 상세 helper 보고서의 `stylePassed`는 false다. 요약·제목 글꼴 지적 때문이며, 변경 전 재현 응답에도 같은 지적이 있었다. 이번 범위 밖이다.
- CI, 실기기, 운영 서버 확인은 하지 않았다.
