# 본앱 링크 저장 재시도에 제출 키 보내기 (#298)

2026-11-08, 시작 커밋 `c55242c` 기준으로 구현하고 main `f52660b`(#297)를 병합한 뒤 티켓 리뷰 반영과 전체 검증을 마쳤다.
코드 커밋은 `fe6fa5c`(구현), `785d148`(리뷰 반영), `3c3c0ff`(빈 카테고리 검사 범위 조정)와 `3211e33`(재검수 실패 문구 보존)이다.

## 사용자 결정

- 2026-11-08 "A. 앱이 키를 보냄 (Recommended)": 링크에도 사진과 같은 제출 키 규칙을 쓰고 서버 `POST /contents`는 기존 영수증을 재사용한다.
  키 없는 요청은 지금처럼 새 콘텐츠다. 서버 쪽 URL 중복 합치기(B·C)와 링크 요청 제한 시간(R2)은 범위 밖이다.
- 2026-11-08 "매개변수만 허용 (Recommended)": 링크 콜백 타입에 키 인자를 더하고, 테스트 대역 클로저에는 키 매개변수만 기계적으로 추가한다.
  기대값을 바꾸는 기존 테스트는 #288 G5 하나다. Zone으로 키를 우회 전달하지 않는다.

## 원인과 구현

- 원인: 서버가 링크를 저장한 뒤 응답이 끊기면 앱은 실패를 띄우고 입력을 남긴다. 다시 저장하면 두 요청을 같은 제출로 알 방법이 없어 새 행이 생겼다.
- 서버 `backend/app/api/v1/endpoints/contents.py`: 선택적 UUID `Idempotency-Key`를 받아 `prepare_share_write`(같은 계정·키 트랜잭션 잠금 → 영수증 조회)를
  종류 `content`, 요청 본문(`ContentCreate`) 지문으로 호출한다. 지문은 Pydantic 기본값·URL 정규화 이후, 메타데이터 추출 전 값이다. 재전송은 기존 콘텐츠를 돌려주고, 다른 입력·종류는 409, 삭제 뒤는 410이다.
  영수증은 기존 `save_link`가 콘텐츠·이벤트·요약 작업과 같은 commit에 넣는다. DB 스키마는 바꾸지 않았다.
- 앱: `SaveLinkCallback` → `ContentSaveViewModel.addLink` → `ContentActions.saveLink` → `ContentRepository.saveLink` → `ClipbackApi.createContent`로 키를 넘긴다.
  `ContentSaveSubmission.linkChanged`가 입력·붙여넣기(`_validateLink`)·지우기(`_clearLink`)에서 주소가 바뀌면 키를 버리고, 같은 주소의 재저장은 키를 이어 쓴다.
  저장 시트마다 새 제출 상태라 화면을 새로 열면 새 키다.
- 앱 `createContent`는 저장 응답을 사진과 같은 공통 검사(`_savedContent`: 목록 필드·`is_favorite`·`original_url`·`last_viewed_at` 존재와 타입, ID 1 이상)와
  링크 조건(`content_type == link`, `original_url` 있음)으로 확인한다. 손상 응답은 링크 저장의 기존 기본 실패 문구 "저장하지 못했어요. 다시 시도해 주세요."로 실패 처리해 같은 키로 다시 저장할 수 있다.
  사진 업로드의 손상 응답 문구("저장 결과를 확인하지 못했어요. 다시 시도해 주세요.")는 그대로다.
  공통 조회 파서(`ApiContent.fromJson`)의 허용 규칙은 그대로다. 빈 카테고리 거절은 사진에만 남겼다(아래 리뷰 참고).
- 링크 요청에는 사진의 요청 범위 취소(`ApiRequestScope`)를 붙이지 않았다. 저장 중 시트를 닫아도 상세가 열리는 기존 동작(#288 G2)을 유지한다.

## 테스트

- 서버 `backend/tests/integration/test_content_create_idempotency.py`: 같은 키 재전송(같은 ID, 행·이벤트·요약 작업 1개, 메타데이터 추출 1회),
  다른 입력·공유 경로 키 409, 다른 계정 분리, 삭제 뒤 410, UUID 아닌 키 422, 키 없는 두 번은 별개 2행.
  `test_share_write_concurrency.py`에 같은 키 동시 요청 1행 테스트를 새 함수로 더했다(독립 PostgreSQL 연결).
- 앱 `frontend/test/link_save_submission_key_test.dart`(실제 앱 + 가짜 서버): 응답 유실 뒤 재저장이 같은 키·결과 ID·홈 1건,
  주소 변경·새 시트의 새 키, 실패 → 입력·붙여넣기·지우기로 다른 주소 → 원래 주소가 새 키(같은 주소 단순 재시도는 같은 키),
  409·410 실패 표시, 손상 성공 응답 17종(필드 누락·null·타입 오류, 잘못된 ID, 사진 종류, 배열 본문)의 실패 표시와 재시도 키 유지, 401 갱신 뒤 같은 키.
- 기존 테스트: #288 G5는 이름을 "G5 link and photo saves each send a key"로, 링크 단언을 UUID 키로 바꿨다.
  대역 클로저 매개변수 추가는 32개 파일이며 `save_submission_behavior_test.dart`의 G1, G4 반복, G7, G8 반복, G9a, G9b 6곳을 포함한다. 다른 기대값·이름은 바꾸지 않았다.
- 수정 전 재현: 서버 새 테스트 5개, 앱 새 테스트 5개(구현), 리뷰 반영 새 테스트 21개가(그 뒤 빈 카테고리 1종을 빼 20개) 기준 코드에서 실패했다.

## 리뷰

- 티켓 리뷰(`c55242c...92fbe36`): Standards 0건, Spec 중간 2건.
  - S1 손상된 링크 성공 응답을 성공으로 처리: 저장 응답 검사를 더해 반영(`785d148`).
    전체 앱 테스트에서 기존 대기 화면 fixture(`link_pending_fixture.dart`)의 빈 카테고리 응답이 실패로 바뀌어,
    이슈의 손상 기준이 아닌 빈 카테고리 검사는 사진에만 남겼다(`3c3c0ff`). 서버는 링크에도 카테고리를 하나 이상 돌려준다.
  - S2 주소를 바꿨다가 제출 없이 되돌리면 이전 키 재사용: 입력 시점에 키를 버리도록 반영(`785d148`).
  - 같은 원인의 진입점: 홈·보관함·즐겨찾기·상세·마이의 링크 저장은 모두 같은 저장 시트·콜백·API를 쓰며 iOS·Android 공통 Dart 경로다.
    주소를 바꾸는 곳은 입력·붙여넣기·지우기 세 곳이고 모두 연결했다.
- 재검수(`2a612b3`): Standards 0건, Spec 낮음 1건. S1·S2 해결, 사진 검사 추출과 링크의 빈 카테고리 허용은 수용.
  - F1 손상된 링크 성공 응답의 실패 문구가 사진용 문구로 바뀜: 이슈의 화면 문구 보존 조건에 맞춰 링크는 기존 기본 실패 문구로 되돌렸다.
    사진 문구와 기존 테스트 단언은 그대로다. 신규 링크 테스트의 기대 문구를 바꾼 뒤 구현 전 17종 실패를 확인했다.

## 검증

2026-11-08, 재검수 반영 코드(로컬, 대역 데이터, 커밋 직전 작업 트리. 커밋에는 이 코드와 이력 문서만 들어간다).

- 전체 검증 `python3 ~/.heoturu-agents/verify.py`: `VERIFY result=PASS scope=all checks=11 failed=0`.
  앱 테스트 `+3428: All tests passed!`, 백엔드 `pytest: 2325 passed, 47 skipped, 3 warnings`.
  CI App Validation 4개 명령과 서버 `ruff check app scripts alembic tests`·`pytest`는 verify 단계와 같다. verify에 없는 `deptry .`는 같은 코드에서 따로 실행해 통과했다.
  - pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)
  - pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)
- 같은 날 `785d148`의 첫 전체 검증은 위 빈 카테고리 fixture 8개로 `app:test` 실패였다. `3c3c0ff`의 전체 검증은 위와 같은 수치로 통과했다.
- 미실행: Docker deployment 테스트와 원격 CI(PR 생성 뒤 확인).
  운영 확인은 완료 조건 밖이다. 화면 문구·배치는 바뀌지 않아 3면 비교 촬영은 하지 않는다.

## 플랫폼 실행 확인

2026-11-08, 코드 `3211e33`, main `f52660b` 포함. 실제 ClipbackApp과 메모리 API 대역으로 실행했다.
두 플랫폼에서 OS 네이티브 입력으로 `https://example.com/g-link`를 입력하고 저장 버튼을 눌렀다.
실제 `createContent`가 UUID `Idempotency-Key`를 보낸 요청 1회, 201 응답 1회, 결과 ID 7과 저장 완료 화면을 확인했다.
키 없음·잘못된 UUID·다른 URL은 대역이 422로 거절하며 사전 검사에서 이를 확인했다.
이는 앱 실행 확인이며 실제 백엔드와 연결한 종단간 검사나 운영 확인이 아니다.

| 플랫폼 | 환경 | 확인 결과 |
| --- | --- | --- |
| iOS | iPhone 16 Simulator, iOS 18.6, 393×852 pt, 배율 1.0 | UUID 요청·결과 ID·저장 완료 통과, 원본 PNG와 AX 확인 |
| Android | Medium_Phone Emulator, Android 16, 411.43×914.29 논리 크기, 배율 1.0 | UUID 요청·결과 ID·저장 완료 통과, 원본 PNG와 AX 확인 |

입력 시 iOS는 화면 키보드 없이 네이티브 입력을 전달했고, Android는 화면 키보드 인셋 약 336.38이었다.
키보드 배치 검사가 아닌 `nativeText` 조건으로 실제 문자열·포커스·선택 범위·입력 출처를 검증했다.
결과 화면에서는 양쪽 모두 키보드가 없고 링크·미리보기·카테고리·저장 완료 버튼이 보이며 원본 PNG를 감독이 확인했다.
예상 밖 API 요청은 없었다. 결과 시트 아래 홈 목록 개수는 기기 probe에서 관측하지 못했으며, 홈 1건 조건은 별도 앱 회귀 테스트 근거다.
화면 문구·배치 변경이 없어 변경 전/후/Figma 3면 비교는 하지 않았다.

기기 잠금을 플랫폼별로 잡았고 Android qemu 프로세스는 잠금에 등록했다.
iOS는 설치된 Xcode에 Simulator GUI 앱이 없어 지정한 시뮬레이터 ID로 부팅하고 Orca helper로 입력·AX를 확인했으며,
등록할 Simulator GUI 프로세스는 없었다. 잠금은 유지했고 실기기에는 설치하지 않았다.
각 플랫폼 종료 뒤 잠금을 해제했고 Android 빌드 뒤 Gradle 데몬 종료를 확인했다.

로컬 증거는 `.utmp/ticket-298/screens/{ios,android}-after-save-result.png`와 같은 이름 JSON, 입력 증거·AX 기록이다.
촬영 진입 파일·manifest와 플랫폼별 빌드/사전 검사 로그도 같은 티켓 폴더에 보존했다.
PR에는 원본 스크린샷을 사용자가 첨부한다.
