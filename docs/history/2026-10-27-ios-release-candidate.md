# iOS 0.2.0 빌드 6 후보 준비

최초 기록일: 2026-10-27 (KST). 빌드 대상 소스: `a3972f9118ad1ffa8863d2e2ba64415a064063ee`.
사용자 요청은 실제 버전·기존 업로드 빌드 확인과 다음 후보 준비이며 업로드·배포는 제외했다.
현재 후보의 대상·상태·후속 확인은 [후보 기록](../releases/app-v0.2.0-ios-b6.md)을 따른다.

## 실제 스토어 조회

사용자가 직접 로그인한 App Store Connect를 읽기 전용으로 확인했다. 이 결과는 로컬 아카이브에서 추정한 값이 아니다. 조회 시점은 2026-10-27 19:58~20:00 KST다.

- 앱: 허투루, Apple ID `6821850037`, 번들 ID `com.huturu.app`.
- [전체 iOS 업로드 목록](https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios)의 더 보기를 펼쳐 버전 `0.1.0` 빌드 1의 실패 2건과 빌드 2·3·4·5의 완료 항목을 확인했다. 최고 업로드 빌드는 5였다.
- [빌드 5 메타데이터](https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios/37ed7d7c-04dd-4a0e-9644-288cff91f98e/metadata)는 `0.1.0`, 빌드 `5`, 바이너리 상태 `검증됨`, 업로드 날짜 `2026년 10월 19일 오후 10:45`, 위 번들 ID를 표시했다.
- TestFlight 진행 상태는 빌드 5·3이 `수출 규정 관련 문서 누락`, 빌드 4가 `제출 준비 완료`, 빌드 2가 `테스트 중`이었다. 최고 업로드 빌드를 현재 테스트가 배정된 빌드로 간주하지 않았다.
- [App Store 버전 이력](https://appstoreconnect.apple.com/apps/6821850037/distribution/activity/ios/versions)에는 `1.0`의 `제출 준비 중` 기록만 표시됐다. 배포 화면도 `1.0` 제출 준비 중이며 빌드가 연결되지 않았다. 이 값을 정식 공개 완료나 TestFlight의 업로드 버전으로 해석하지 않았다.
- 앱 목록의 갱신된 Apple Developer Program 계약 검토 안내를 확인했다. 계정 소유자의 검토·동의와 수출 규정 정보 결정은 수행하지 않았다. 스토어 입력·저장·심사 제출·그룹 추가도 수행하지 않았다.

## 후보 선택과 기록 생성

현재 소스의 원본 직접 다운로드·계정별 캐시·한도 안내, 카테고리 제출과 목록 복구, 마이 통계와 홈 복구 변경을 iOS 후보에 포함했다. 새 기능·의미 있는 개선을 포함하므로 기존 TestFlight `0.1.0`에서 MINOR를 올린 `0.2.0`을 선택했고, 확인한 최고 빌드 5 다음인 6을 예약했다. 첫 정식 출시용 `1.0.0`의 완료 기준을 충족했다고 판단하지 않았으며 기존 App Store `1.0` 초안도 변경하지 않았다.

도구에는 플랫폼·스토어 출처·조회 시각·최고 빌드 5를 가진 수동 확인 JSON을 임시 파일로 전달했다. 파일은 커밋하지 않았으며, 재확인할 수 있는 출처와 결과는 이 이력과 후보 기록에 남겼다.

`backend/`에서 `python -m scripts.prepare_release app`에 다음 값을 전달했다.

- `--version 0.2.0`, `--ios-build 6`, `--ios-source a3972f9118ad1ffa8863d2e2ba64415a064063ee`
- 원본 열람·캐시·한도, 카테고리 복구, 마이 통계, 홈·계정 전환의 4개 변경 요약
- `--ios-store-history`의 실제 조회 근거, `--environment production`, `--api-version /api/v1`

결과는 `created=true`, `ios_remote_tags=checked`, `ios_store_history=manual_snapshot`, `identifier_checks_complete=true`, `deployment_verified=false`였다. 로컬·원격 앱 태그와 이전 후보 기록에 충돌이 없었으며 [새 후보 파일](../releases/app-v0.2.0-ios-b6.md)을 생성했다. Android는 이 후보의 대상이 아니다.

CHANGELOG의 iOS 대상 10개 개선·1개 수정을 `앱 0.2.0`에 연결했다. 공통 변경의 Android 적용분과 Android 전용 뒤로가기 수정은 `미배포`에 남겨 두 플랫폼이 공개된 것으로 표시하지 않았다. 서버 변경도 이번 앱 후보에 임의로 포함하거나 배포 완료로 옮기지 않았다.

## 기존 서버와 CI 읽기 전용 확인

- 소스 커밋의 [Backend Validation run 40482827908](https://github.com/clip-back/clipback/actions/runs/40482827908)은 `completed/success`이며 lint, test 3.11·3.12, migration, deployment, operator-recovery 6개가 모두 성공했다. 이번 준비에서 새 CI를 실행한 결과는 아니다.
- `railway deployment list --service clipback --environment production --limit 3 --json`에서 deployment `d3222dc0-c3af-4680-8260-1ba729a31078`이 `SUCCESS`, commitHash가 위 후보 소스와 같음을 확인했다. 생성 시각은 `2026-10-27T09:42:29.546Z`(KST 18:42:29)다. 이전 PR 병합 뒤의 기존 자동 배포를 조회한 것이며, 이번 요청에서 새 배포를 실행하지 않았다.
- 저장소 migration head는 `202610260020`이다. 운영 DB의 현재 revision과 실제 사용자 흐름은 조회·검증하지 않았으므로 완료로 표시하지 않았다.

## 확인 범위와 미실행

문서·후보 기록만 변경했다. 후보 생성 출력, 소스 SHA·번호·대상 범위의 일치와 Markdown 상대 링크 146개(앵커 포함)의 대상 존재, 최종 diff 공백 검사를 확인해 모두 통과했다. CHANGELOG는 선택한 iOS 항목 11개와 미배포 Android 항목 12개가 남음을 대조했다. 이번 작업의 앱 테스트·Flutter 빌드·서명·iOS Simulator·Android Emulator·실기기·원본 열람·실제 OAuth 시나리오는 미실행이다. 기존 CI 성공이나 로컬 아카이브를 빌드 6의 실행 검증 근거로 재사용하지 않는다.

Android는 앞선 확인에서 현재 브라우저 계정의 Play Console이 개발자 계정 가입 화면으로 연결됐고, 실제 다른 계정이나 배포 이력은 미확인이다. Android 번호나 후보를 추정해 만들지 않았다.

실제 업로드·TestFlight 배포·스토어 제출·서버 배포·계약 수락·실제 후보 태그 생성·푸시·PR 생성은 수행하지 않았다. 코드의 기본 버전도 변경하지 않았다. 후보 문서의 후속 커밋과 빌드 소스 SHA를 구분해 유지한다.
