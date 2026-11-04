# 모바일 전체 폭 — #233 구현·리뷰·자동 검증

2026-11-05, 시작 커밋 `800aa81`, `fix/phone-full-width` 워크트리에서 수행했다.
구현·부분 검사 이후 main 병합, 티켓 리뷰와 전체 자동 검증까지 기록한다. 변경 후 촬영·3열 비교·사용자 화면 판정은 감독의 후속 단계다.

## 결정과 구현

사용자 결정은 “35도 1번으로 진행하면 될 것 같아”, “폭 600 미만은 휴대폰으로 보고 화면 전체 폭을 쓰기. 600 이상(iPad 등)은 지금처럼 375 폭을 가운데에 두기.”다.

- `appContentWidth`는 가용 논리 폭 600 미만이면 그 폭, 600 이상이면375를 반환한다. `PhoneFrame`, 전역 bottom-sheet 테마, 저장 화면·공용 진입 화면에 적용했다. 권한 route의 별도375 상한은 제거해 전역 테마를 따르게 했다.
- 전역 테마는 최대 폭만 늘리지 않고 `BoxConstraints.tightFor(width: ...)`로 패널 폭을 채운다. 최대 폭만 늘린 중간 구현에서는 짧은 공지 시트가430·599에서 내용 너비로 줄어드는 실패를 확인했다.
- 열린 권한 route도 창 크기 변경을 따라야 하므로 진입 당시 폭을 constraints에 저장하지 않는다. 393에서 열고430·600·599·768·393으로 바꿔 같은 route·앱 State와 경계 정책을 확인한다. 중간 구현의 고정393 제약은430 창에서 왼쪽18.5px로 실패했다(`partial-width-live-red.log`).
- `phoneWidth=375`를 바꾸지 않아 카테고리·종료 확인 다이얼로그311px 등 별도 크기를 보존했다. 홈 카드298px·추천 카드133px, 내부16/24, 글자·아이콘·문구·API·인증·저장 로직은 변경하지 않았다. 가변 행의 가용 폭은 새 외곽을 따르며 비례 확대하지 않는다.
- `EntrySurface`는 현재 제품 호출처가 없지만 이슈에 명시된 공용 내부375 제한도 제거했다. 스플래시는 원래 외곽 배경이 전체 폭이고 내부는 고정 로고 그룹이므로 변경하지 않았다.

## 재현과 부분 검사

모든 검사 전에 `~/.heoturu-agents/busy.sh --wait`를 비동기 실행으로 기다렸고 실제 명령도 `busy.sh && ...`로 연결했다. 로그 첫 줄에 명령을 남겼다. 아래 로그는 저장소의 Git 제외 경로 `.utmp/ticket-233/`에 보존했다.

| 검사 | 결과·로컬 로그 |
| --- | --- |
| 제품 변경 전393 홈 콘텐츠 있음/없음·일반 로그인 실제 권한 route | 3개 모두 왼쪽9px로 실패, `partial-width-red.log` |
| 동일 재현 검사 수정 후 | 3개 통과, `partial-width-green.log` |
| 대표 iOS393, 배율1.0/1.3 경로·권한 검사 | 32개 통과, `partial-width-matrix-5.log` |
| 관련18개 파일 회귀 | 985개 통과, `partial-width-regression-2.log` |
| 일반 로그인 외곽 단언 보완 후 | 권한 파일39개 통과, `partial-width-permission-final.log` |
| 열린 권한 route의 폭 변경 보완 후 | 권한40개·Figma4개·촬영29개, 총73개 통과, `partial-width-live-green.log` |
| 기존 촬영 사전 검사 | 29개 통과, `partial-width-capture-check-1.log` — 제품 수정 후 위젯 대역 회귀이며 새 기기 촬영 아님 |
| `flutter analyze --no-pub` | No issues found, `partial-width-analyze-route-final.log` |

회귀 명령은 저장소 루트에서 다음과 같다.

```sh
~/.heoturu-agents/busy.sh && (cd frontend && flutter test --no-pub \
  test/phone_width_test.dart test/home_alignment_test.dart \
  test/home_base_alignment_test.dart test/permission_guide_figma_test.dart \
  test/permission_guide_navigation_test.dart test/sheet_safe_area_test.dart \
  test/scaled_navigation_layout_test.dart test/detail_alignment_test.dart \
  test/search_alignment_test.dart test/archive_all_alignment_test.dart \
  test/bookmark_alignment_test.dart test/category_sheet_alignment_test.dart \
  test/category_management_alignment_test.dart test/category_archive_alignment_test.dart \
  test/save_scaled_layout_test.dart test/save_footer_layout_test.dart \
  test/save_search_safe_area_test.dart test/category_auth_recovery_test.dart)
```

검사 범위:

- 375·393·430·599·600·768 × iOS/Android × 실제 번들 Pretendard1.0/1.3. 홈 있음/없음, 실제 일반 로그인 권한 route, 공용 영향 화면의 표시 중 Scaffold·하단 탭 및 시트 패널 외곽을 단언한다. 600의 좌우112.5/487.5, 768의196.5/571.5는 독립 기대값이다.
- 내부16px 헤더,24px 권한 본문, 고정298px 홈 카드와42px 권한 아이콘을 외곽과 나누어 확인한다. 기존 Figma 맞춤 검사도 유지했다. 새 테스트가 기존 기대값을 일괄 치환하지 않는다.
- 홈→상세·검색·알림·아카이브·카테고리·즐겨찾기·마이·계정·공지·연결 로그인·로그아웃은 실제 앱 callback/탭을 사용한다. 최초 로딩·로그인 진행/취소/실패·충돌·관심사·온보딩·세션 복원·임시 안내·공용 진입 화면은 실제 앱 테마의 Navigator에 제품 위젯을 띄워 외곽을 검증한다. 이 후자 검사는 인증/로딩 원인의 재현을 뜻하지 않는다.
- 저장·홈 알림 설정·마이 설정/권한/문의/버전·카테고리 생성/동작/수정·콘텐츠 동작/카테고리 변경은 제품 진입 경로를 사용한다. 원본 이미지 시트는 실제 상세 route에서 실패 응답·오류 표시·닫힘·상세 State 보존까지 단언한다.
- 일반 앱이 목록 화면으로 연결하는 fallback 공지/알림 패널은 제품과 동일한 public modal 옵션 및 실제 앱 테마에서 검사한다. 저장 대기 공유 선택은 호스트의 `dart:io` 네이티브 공유 제한 때문에 실제 앱에서 얻은 테마와 제품 `PendingSharePrompt`의 실제 chooser route를 사용한다. 네이티브 공유 성공 증거가 아니다.
- 대역 키보드 표시/숨김에서 저장 route·controller·URL 보존, 저장 버튼 접근과 검색 입력, 카테고리 한글40자·수정 버튼 접근을 확인했다. 실제 권한 route는 스크롤 끝으로 이동한 뒤 드래그 닫힘·LoginScreen 복귀·인증 요청 없음까지 확인했다.
- 기존 저장 확대/안전 영역, 카테고리 입력·오류 복구 및 계정 변경 중 시트 수명 회귀를 함께 실행했다. 원본 이미지의 성공 응답·인셋 변경 시 중복 요청 방지는 기존 `sheet_safe_area_test.dart`가 확인한다.

중간 실패 로그는 삭제하지 않았다. `partial-width-matrix-1`은 const double map 테스트 작성 오류,2는 헤더/버튼 기대 및 플랫폼 override 정리 시점,3은 가운데 카드와16px 헤더의 혼동,4는 사진 전용 원본 시트에 링크 fixture를 넣은 잘못된 상태였다. 원본 시트 검사를 실제 스크린샷 상세 route로 바꾼 뒤5가 통과했다. `partial-width-regression-1`의 공지 시트 폭 축소는 테마의 최소 폭까지 지정해 해결했고, 태블릿 공유 시트 측정은 전체 overlay 대신 실제 Material로 바로잡았다. 로그별 실패를 제품 결함으로 일괄 집계하지 않는다.

## 감독의 변경 전 기기 증거와 승인 예외

아래는 감독 기록의 인용이며 이번 구현 작업자가 기기를 실행한 결과가 아니다.

- 제품 `800aa81`에서 iOS39/39·Android39/39, PNG/조건 JSON78쌍과 플랫폼별5영상. 감독의 `before-final-audit.json`에서78/78 확인했다. 실패 Android 저장 영상은 성공 수에 포함하지 않았다.
- iOS iPhone16/iOS18.6:393×852, OS top59/bottom34. Android Medium_Phone Android16/API36:411.428571×914.285714, top24/bottom24. live MediaQuery의 OS/app 인셋을 별도로 기록했다.
- iOS kernel `106292fb889c`, Android 기본 APK `213eae51a7b3`, Android prefill APK `dff1e8e68437`. 기존 산출물·이미지·영상·JSON은 그대로 보존했다.
- Figma 파일 `svNWsTFh8Ws1Mpt8XQIcrN`의 원본26개를 감독이2026-11-04 23:27 KST 조회했다. 개별 노드·시각은 `figma/retrieval.json`, 상태별 대응은 `capture-plan.md`에 있다. 핵심은 C01 `111:3584`, C02 `111:3681`, B01 `111:3478`·`111:3508`, 공통 하단 `111:3680`이다. 원본 없는 상태는 대체 디자인으로 채우지 않는다.
- 사용자 승인 예외(2026-11-05, “추천대로 진행해줘”): **Android save-input은 실제 타이핑이 아닌 대역 입력**으로 지정 URL을 미리 채운다. 전후 동일 `/save-prefill` 경로이며 native 타이핑/붙여넣기 성공 증거가 아니다. 이 경로도 실패하면 해당 한 장면만 사유와 함께 미검증으로 남기고 진행하는 예외도 승인됐다. 감독의 변경 전 prefill 촬영은 통과해 장면 제외 예외는 사용하지 않았다. iOS는 native 입력 증거다. 최종 PR 초안에도 이 문구를 옮긴다.
- 카테고리40자 입력·키보드·수정 버튼 접근은 감독이 확인했다. 저장 탭 후 PATCH 대역 응답 부재는 제품 결함으로 보지 않으며, 이번 구현에서 촬영 fixture는 변경하지 않았다. 실제 저장 성공 증거로 세지 않는다.
- Android 권한1.3은 스크롤13 후 드래그 닫힘이 확인됐다. iOS 감독 입력에서는 드래그 닫힘이 없고 바깥 탭 닫힘만 확인됐다. 도구의 좌표/입력 전달 한계를 제품 결함으로 단정하지 않는다. 일부 iOS 저장 PNG의 키보드 누락은 OS/app 인셋336과 영상으로 구분하며 원본을 보정하지 않는다.

## 병합·리뷰와 비교 조건 검사 보완

구현 커밋은 `f3c3385`다. 감독이 main `f264735`의 홈 흰 패널 변경(#232/#236)을 병합한 `347b0c2`에서 티켓 리뷰를 받았다. 리뷰 확정 지적은 Standards 0건 / Spec 0건이며, 검수자가 관련 테스트467개를 통과시켰다(`.utmp/review-233.md`, `.utmp/review-233-tests.log`). 이 수치는 구현자의 전체 검사와 별개다. 반영하거나 보류할 확정 지적은 없다.

리뷰가 직접 재현한 기존 비교 도우미의 조건 누락은 별도 검증 한계로 보완했다. 전역 키트 대신 `.utmp/ticket-233/compare_checked.py`를 두고, 이미지 생성 전에 전후 플랫폼·논리 크기·OS/app 안전 영역과 키보드 인셋·글자 배율·모드·화면/route·입력/포커스/provenance·가로/세로 offset의 일치를 확인한다. 각 JSON 안의 OS/app 불일치와 필드 누락도 거부한다. Android 저장은 양쪽 모두 `-prefill` 이름과 승인된 대역 입력 provenance를 요구한다.

폭 변경에 따른 geometry·최대 스크롤 범위는 같다고 요구하지 않는다. 입력 caret 끝 정렬에 따른 offset 차이도 자동 보정하지 않고 실제 차이를 출력하며 비교 생성을 거부한다. 리뷰용 변형 JSON과 before를 after로 재사용하는 경로도 거부한다. 메타데이터 일치는 실제 촬영 진위나 사용자 화면 승인을 대신하지 않는다.

로컬 대역 검사11개가 통과했다(`partial-compare-guard-3.log`): before 복사본78쌍, 리뷰 변형3개, 필드 누락56경로×3방향, OS/app 불일치·입력/provenance·중첩 화면 상태 누락, geometry/max 변경 허용·caret offset 차이 거부·렌더 호출 차단을 확인했다. 실제 after나 비교 이미지는 생성하지 않았다. 사용 명령과 플랫폼별 예시는 `.utmp/ticket-233/capture-plan.md`의 ‘리뷰 후 전후 비교 guard’에 있다. 원본·기존 감독 도우미·전역 파일은 변경하지 않았다.

## 전체 검증과 추가 회귀 보완

전체 검증의 실행 순서와 결과를 구분한다. 로그는 모두 `.utmp/ticket-233/` 아래다.

1. 첫 실행은 백엔드2047통과·46skip·3warnings 및 앱 분석까지 통과한 뒤 Orca 재시작으로 앱 테스트가 중단됐다. 전체 PASS가 아니다. 당시 로그11개를 바이트 대조한 복사본과 SHA manifest로 `interrupted-orca-restart/`에 보존했다.
2. 감독의 재개 지시로 전체 검증을 다시 실행했다. root `verify-result.txt`는 `FAIL scope=all checks=10 failed=1 failed_checks=app:test`다. 백엔드2047통과·46skip·3warnings, 앱2839통과·4실패였다. 로그인·로그인 실패·계정 충돌·초기 로딩의 기존393 창 테스트에 과거375 폭 기대가 남아 있었고 실제393과 달랐다. 실패 로그는 덮어쓰지 않았다.
3. 해당4개 파일의 테스트를393 전체 폭과600의375 중앙 정렬로 각각 나누고 좌우 경계를 독립 수치로 단언했다. 기존 안전 영역·footer·로고 그룹·배경 단언을 유지했으며 제품 코드는 바꾸지 않았다. 부분 검사53개가 통과했다(`partial-wide-auth-regression.log`).
4. `busy.sh --wait` 이후 다음 명령을600초 제한으로 실행해 최종 전체 검증을 통과했다. 기준은 `347b0c2`와 위4개 테스트 수정이다. 입력 파일 해시는 `verification-final-source.json`, 당시 테스트 diff는 `verification-final-tests.diff`에 남겼다. 이후 변경은 이력·목차뿐이며 커밋 전 동일 해시 여부를 필수 확인한다.

```sh
~/.heoturu-agents/busy.sh && python3 ~/.heoturu-agents/verify.py --log-dir .utmp/ticket-233/final
```

최종 `final/verify-result.txt`와 단계 로그를 직접 대조했다.

- 전체10단계 통과. 백엔드 ruff·compileall·DB migration/check·pytest, 앱 pub get·analyze·test 포함.
- `final/backend-pytest.log`: **2047 passed, 46 skipped, 3 warnings in 168.82s (0:02:48)**.
- `final/app-test.log`: **2847 tests passed**, 테스트 출력 경과시간02:17, verify 단계140.1초.
- `final/app-analyze.log`: `No issues found!`.
- 전체 출력 `verify-final-run.log`; 아래 skip은 통과로 세지 않으며 Docker 배포/복구 및 S3 통합 조건을 갖춘 환경의 검증이 별도로 필요하다.

```text
pytest skip: 45 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
VERIFY result=PASS scope=all checks=10 failed=0 logs=/Users/leehyeongyu/orca/workspaces/Clipback/phone-full-width/.utmp/ticket-233/final
```

## 남은 검증

변경 후 iOS/Android 촬영, 플랫폼별 변경 전·후·Figma 3열 비교 및 최종 화면 판정은 미완료다. 위젯 대역의 인셋/입력 검사를 실제 OS 키보드 검증으로 대체하지 않는다. 실기기·실제 OAuth·운영 API·원격 CI는 이번 단계에서 실행하지 않았다. 이슈 댓글·종료·push·PR 생성도 하지 않았다.
