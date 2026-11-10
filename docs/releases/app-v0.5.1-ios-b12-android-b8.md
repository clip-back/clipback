# app-v0.5.1-ios-b12-android-b8

## 배포 개요

- 배포 식별자: app-v0.5.1-ios-b12-android-b8
- 배포 담당자: 저장소 운영자
- 준비일: 2026-11-09T02:49:09+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱·서버] 링크 저장 응답 유실 뒤 재시도 중복 방지 (#298, CHANGELOG 앱 0.5.1 수정); [앱] 잠긴 별·더보기를 눌러도 상세가 열리지 않음 (#297, CHANGELOG 앱 0.5.1 수정)
- 관련 PR·작업 링크: [잠긴 별·더보기 상세 열림 수정 #299](https://github.com/clip-back/clipback/pull/299)(#297), [링크 저장 재시도 중복 방지 #302](https://github.com/clip-back/clipback/pull/302)(#298, 서버 쪽도 이 PR로 병합)
- 앱 버전별 개요·이전 후보 링크: 개요 없음. 이전 버전 후보 [iOS 0.5.0(11)·Android 0.5.0(7)](app-v0.5.0-ios-b11-android-b7.md)
- 후보 준비 상태·미확인 사유: iOS 0.5.1(12) 아카이브·IPA와 Android 0.5.1(8) AAB 빌드 완료(2026-11-09). 두 산출물 모두 업로드 대상 후보이며 업로드 금지로 지정한 산출물은 없음. 후보 태그 생성·푸시(2026-11-09). iOS 12는 배포 세션이 App Store Connect에 업로드(2026-11-09 02:59 KST, Upload succeeded). Android 8은 사용자가 Play Console에 업로드(시각 미확인). iOS 12는 TestFlight 테스터에게, Android 8은 내부 테스트로 제공(사용자 보고, 2026-11-09, 시각·그룹·트랙 이름 미보고). 외부 베타 심사 미확인. iPhone 13 실기기 확인 결과 받음(사용자 확인, 2026-11-09, 아래 검증 결과의 실기기 행). Android 실기기 확인 미실행. 정식 공개 미실행

사용자 결정(2026-11-09, 원문): "빌드 하자 0.5.1로 하자". 스토어 최대 업로드 번호는 원문 "iOS 11·Android 7 확인함"이며 새 번호는 iOS 12·Android 8입니다.
포함 변경은 CHANGELOG `미배포`의 `수정` 2개 전부입니다(`추가`·`개선`과 `[iOS]`·`[Android]` 항목은 없었음). 새 기능 없이 수정만 들어가 PATCH 규칙에 따라 0.5.0에서 0.5.1로 올렸습니다.
#298 항목은 `[앱·서버]` 표시 그대로 `앱 0.5.1`로 옮겼습니다. 서버 쪽은 이미 [backend-2026-11-09-1](backend-2026-11-09-1.md)로 운영 반영을 확인했고, 그 기록이 이 줄을 다음 앱 후보에 남겼습니다. [배포 절차](../release-process.md#서버-자동-배포와-사후-기록)의 "앱 후보는 서버 항목을 중복 기록하지 않고 서버 기록을 연결"에 따라 서버 영역에서 그 기록을 연결하고, 변경 이력에 서버 항목을 따로 만들지 않았습니다.

`app-ios-v0.5.0-b11`(`901a3b1`)..`3626004`의 `frontend/` 변경은 위 두 항목의 PR(#299·#302)과 화면 변화 없는 코드 정리·도구 수정입니다. 아래 다섯 PR은 변경 이력 항목이 없으며, 각 PR 본문·커밋이 사용자 동작을 유지한다고 적었습니다.

| 커밋 | PR(이슈) | 내용 | 변경 이력 없는 이유 |
| --- | --- | --- | --- |
| `85c30e0` | #284(#276·#282·#283) | 카테고리 생성·수정·목록 재조회·피드 갱신 요청 판정을 `ApiRequestScope.settle`로 통합 | 동작 고정 테스트를 두고 옮긴 정리. "사용자에게 보이는 동작은 같다"(커밋 본문) |
| `cfb0765` | #291(#288) | 저장 화면 제출 상태를 시트별 객체로 분리 | "콜백 두 개와 사용자 동작은 유지"(PR 본문) |
| `c55242c` | #293(#292) | 기기 촬영 도구의 오래된 기대값과 화면 전환 검사 수정 | `frontend/test/support/`의 촬영 도구와 문서만 바꿈. 앱 코드(`frontend/lib/`) 변경 없음, "앱 코드·화면·위젯 테스트 기대값은 그대로"(PR 본문) |
| `3b3d10f` | #300(#294) | 주간 추천 방문 상태를 `HomeWeeklyViewModel`로 분리 | 동작 고정 테스트를 두고 옮긴 정리, "화면 변화가 없어"(PR 본문) |
| `813702b` | #306(#301) | 오늘의 추천 열기 상태를 상세 ViewModel로 이동 | "기존 동작을 유지"(PR 본문), 화면 변화 없음 |

그 밖의 커밋은 서버(`d07751d` #285: #277, `91bb8eb` #286: #281, `26b7bf3` #305: #157·#158 — 각각 [backend-2026-11-08-1](backend-2026-11-08-1.md)·[backend-2026-11-09-1](backend-2026-11-09-1.md))과 배포 기록 문서(#275, #287, #307)입니다.

팀 피드백 시트(“[허투루] 앱 테스트 피드백”)에서 이 빌드에 든 줄: B열 62 → #297, B열 63 → #298 (2026-11-09 02:50 KST 무렵 조회). 코드 정리 PR은 시트 줄과 연결되지 않습니다. 시트는 고치지 않았습니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-11-09T02:49:09+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-11-09T02:49:09+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인 보고(조율 전달 "iOS 11·Android 7 확인함", 2026-11-09; 정확한 확인 시각은 미확인이라 배포 세션 지시 수신 시각 기재) / 2026-11-09T02:49:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 11 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인 보고(조율 전달 "iOS 11·Android 7 확인함", 2026-11-09; 정확한 확인 시각은 미확인이라 배포 세션 지시 수신 시각 기재) / 2026-11-09T02:49:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 7 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.5.1 | 0.5.1 |
| 실제 빌드 번호 | 12 | 8 |
| 빌드 소스 SHA | 3626004b94e14a4613fbcd0e1236c50c9d1d0311 | 3626004b94e14a4613fbcd0e1236c50c9d1d0311 |
| 후보 태그·실제 생성 여부 | app-ios-v0.5.1-b12 (2026-11-09 생성·푸시, annotated) | app-android-v0.5.1-b8 (2026-11-09 생성·푸시, annotated) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미결정 — 업로드·실기기 확인 전 | 미결정 — 업로드·실기기 확인 전 |
| 빌드 결과·산출물 식별자 | 아카이브·IPA 내보내기 성공. 아카이브 `frontend/build/release-candidates/app-v0.5.1-ios-b12/Runner.xcarchive`(생성 2026-11-09 02:51 KST), IPA `frontend/build/release-candidates/app-v0.5.1-ios-b12/ipa/clipback_frontend.ipa` 42,843,555바이트, SHA-256 `4feb04621fed451c461b46b6635a4322563990aebfabb2c725fcf43a6258a314` — 본앱 `com.huturu.app` 0.5.1(12), 공유 확장 `com.huturu.app.ShareExtension` 0.5.1(12), 팀 `8X6N747PQM`, 권한 설명 3종 존재 | Release AAB 성공. `frontend/build/release-candidates/app-v0.5.1-android-b8/app-release.aab`, 74,525,084바이트, SHA-256 `f5254e419da5105f5310b2cfb9827c509cc96d2256fdebb5d922b199546aa492`. versionName 0.5.1·versionCode 8 확인 |
| 업로드·처리 상태 | 후보 아카이브 `app-v0.5.1-ios-b12/Runner.xcarchive`를 `xcodebuild -exportArchive`(destination upload)로 App Store Connect에 업로드 성공(2026-11-09 02:59 KST). App Store Connect 처리 완료 — TestFlight 테스터 제공이 이뤄졌다는 사용자 보고(2026-11-09)로 판단 | 사용자가 Play Console에 업로드(사용자 보고, 2026-11-09 수신, 업로드 시각 미확인). 올린 파일이 `app-v0.5.1-android-b8/app-release.aab`인지는 사용자 보고 없음. Play 처리 완료 — 내부 테스트 제공이 이뤄졌다는 사용자 보고(2026-11-09)로 판단 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | TestFlight 테스터에게 제공(사용자 보고, 2026-11-09). 내부·외부 그룹과 그룹 이름은 사용자 보고 없음, 제공 시각 미확인 | 내부 테스트로 제공(사용자 보고, 2026-11-09). 트랙 이름은 사용자 보고 없음, 제공 시각 미확인 |
| 심사 상태 | 미확인 — 외부 베타 심사 여부는 사용자 보고 없음 | 미확인 |
| 정식 공개 상태·공개 범위 | 미실행 | 미실행 |
| 실제 공개일·시각 | 해당 없음 — 공개 전 | 해당 없음 — 공개 전 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중. #298의 서버 쪽은 [backend-2026-11-09-1](backend-2026-11-09-1.md) 사후 기록 |
| 서버 소스 SHA·산출물 식별자 | 운영 중 3626004b94e14a4613fbcd0e1236c50c9d1d0311 / Railway deployment `e1b2e05c-5de0-44b6-9b7a-3a5cc41f6c74`(SUCCESS, 2026-11-09 01:32 KST 생성) — 앱 빌드 소스와 같은 커밋. `3626004`는 배포 기록 문서만 바꿔 `backend/`는 backend-2026-11-09-1의 `26b7bf3`과 같음(`git diff 26b7bf3 3626004 -- backend/` 빈 결과) |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 앱 후보에서 서버 후보를 만들지 않음 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 불필요 — `901a3b1..3626004`에 `backend/alembic/versions/` 변경 없음. head `202611060022` 그대로 |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | #298은 `POST /api/v1/contents`의 선택적 `Idempotency-Key`를 서버가 먼저 받아야 함. 순서: 서버(`ef9f6a8` 운영 반영 2026-11-08 19:15 KST, backend-2026-11-09-1) → 앱 업로드. 선행 조건 충족. #297은 서버 의존 없음 |
| 기존 앱과의 호환성 | `/api/v1` 유지. 키 없는 요청(배포된 0.5.0 이하 앱)은 지금처럼 동작하고, 0.5.1 앱이 키를 보내도 기존 응답과 같음(backend-2026-11-09-1). 이 산출물과 운영 서버의 실제 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱, 새 revision 없음) |
| 실제 서버 배포 상태·시각·근거 | 배포 세션에서 `railway deployment list --json` 조회(2026-11-09 02:50 KST): `3626004` SUCCESS, 이전 `26b7bf3` 배포는 REMOVED. `/api/v1/health/ready` 200(2026-11-09 02:50 KST) |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.5.0(11)·Android 0.5.0(7) 산출물 보존(`frontend/build/release-candidates/`). 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버 복구는 backend-2026-11-09-1과 [Railway 배포·복구](../railway-deployment.md) 참조. 서버의 #298을 되돌려도 0.5.1 앱은 키 헤더가 무시될 뿐 저장은 동작함(재시도 중복 방지만 사라짐) |

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함. 같은 앱 소스의 검사는 원격 CI 결과(아래)만 있음 |
| 산출물 정적 검사(iOS IPA) | IPA의 본앱·공유 확장 `Info.plist`, 아카이브 `Info.plist`, `codesign -dvv`·`codesign --verify --deep --strict`, 포함된 provisioning profile, entitlements | 통과 | 0.5.1(12)·공유 확장 0.5.1(12). Apple Distribution 인증서·팀 `8X6N747PQM`, 서명 검증 통과, profile `iOS Team Store Provisioning Profile: com.huturu.app`, `get-task-allow` false. 권한 설명 3종 존재 |
| 산출물 정적 검사(Android AAB) | `:app:validateReleaseSigning`, 병합 manifest, `jarsigner -verify`, 업로드 인증서(`META-INF/UPLOAD.RSA`) 지문, `.so`의 ELF LOAD 정렬 | 통과 | `com.huturu.app`·0.5.1(8)·minSdk 24·targetSdk 36. `jar verified`. 업로드 인증서 SHA-256 `B0:76:98:8A…87:E5:9A:D0`, 빌드 7 AAB의 인증서와 같음. `.so` 12개 중 64비트 8개 모두 16KB 이상 정렬. bundletool 검사는 미실행(미설치) |
| 원격 CI | `813702b`의 App Validation·Backend Validation, `3626004`의 Backend Validation (push) | 모두 success | [App Validation run 42492637634](https://github.com/clip-back/clipback/actions/runs/42492637634)(`813702b`, 이후 `3626004`까지 `frontend/` 변경 없음 — App Validation은 `frontend/` 변경 때만 실행), [Backend Validation run 42500439306](https://github.com/clip-back/clipback/actions/runs/42500439306)(`3626004`). 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함(메모리 8GB). 변경별 시뮬레이터 확인은 각 PR 작업 기록에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유 |
| 실제 OAuth·외부 공급자 | 실기기 행의 #250 확인: iPhone 13에서 Google·Apple·카카오 실제 로그인·탈퇴·재가입과 공급자 쪽 연결 목록 확인 | 통과(실기기, 사용자 확인 2026-11-09) | 실기기 행 참조. Android 실제 로그인은 미실행 |
| 운영 서버 | Railway production 배포 목록, `/api/v1/health/ready` (2026-11-09 02:50 KST) | `3626004` SUCCESS, health 200 | 이 앱 후보와 운영 API의 연동은 실기기 행의 사용자 확인(2026-11-09) 참조: #250 탈퇴의 운영 DB·Bucket 정리 확인, #298 제출 키 전송(`share_receipts`) 확인. 같은 키 재시도의 결과는 미확인 |
| 실기기 | iPhone 13 / iOS 26.1, TestFlight 0.5.1(12), 운영 서버. 사용자가 순서표(설치 → #298·#245 → Google·Apple·카카오 탈퇴·재가입)대로 진행. Android 실기기는 미실행 | 설치 통과, #250 통과, #245 통과(낭독 메모), #298 방법 미확인, 0.4.1에서 업그레이드 못 함 (실기기, 사용자 확인 2026-11-09) | 설치: TestFlight 0.5.1(12) 설치, 마이 앱 버전 `ver. 0.5.1`. #250: Google·Apple·카카오 세 계정 모두 탈퇴 완료 화면, 탈퇴 뒤 그 계정의 운영 DB 행 수 모두 0, 탈퇴 사유 줄 기록, 사진 원본 삭제 기록 완료·Bucket 원본 없음(Google 계정), 각 공급자의 연결 목록에서 허투루가 사라짐(Google은 저장된 로그인으로 다시 연 실행에서 탈퇴), 재가입 때 새 계정 생성(Apple은 이메일 공유 화면이 다시 뜸). 선택 항목인 서버 로그 `Provider revocation failed` 확인은 "성공"으로 표시됐으나 로그 유무 값은 적히지 않음. #245: VoiceOver로 공유 저장 시트를 들음. 두 번 탭 직후와 버튼을 눌렀을 때 들린 말 "처리중 생략부호 흐리게 표시됨"(사용자 메모 원문), "저장 완료!" 들림, 중복 저장 없음. 점을 "생략부호"로 읽는 문제는 #318(시트 71번)로 고쳐 [앱 0.5.2 후보](app-v0.5.2-ios-b13-android-b9.md)에 들어감. #298: 방법 미확인. 저장 직후 비행기 모드를 켜자 앱에 링크 요청 제한 시간이 없어 실패 안내로 끝나지 않고 "허투루가 정보를 추출 중입니다" 화면에 머물렀고, 저장 버튼이 꺼져 같은 화면에서 다시 저장하지 못함. 위에 뜬 "공유 저장을 준비하지 못했어요. 다시 시도해주세요." 띠는 공유 준비 알림이며 링크 저장 실패 안내가 아님(시트 70번). 다시 저장 전 운영 DB에 그 링크 1줄 저장, 운영 `share_receipts`에 `kind=content` 줄이 있어 앱의 제출 키 전송은 확인. 같은 키 재시도가 한 콘텐츠로 남는지는 미확인이며, 멈춤은 #319(시트 70번)로 고쳐 앱 0.5.2 후보에 들어감. 0.4.1(10)에서 0.5.1로 올리기(선택): 못 함. 계정 번호 등 계정 식별자는 옮기지 않음. 순서표에서 사람이 볼 수 없어 뺀 카카오·Google SDK 상태 확인은 미실행 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-11-09 02:49 | 후보 예약 | 사용자 확인 스토어 최대 업로드(App Store Connect 11, Play 7, 2026-11-09 사용자 보고, 시각 미확인이라 지시 수신 시각 02:49 KST 기재)로 iOS 0.5.1(12)·Android 0.5.1(8) 예약. 소스 main `3626004` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성 |
| 2026-11-09 02:49–02:52 | iOS 아카이브·IPA 내보내기 | 빌드 차례 확인(비어 있음) 뒤 실행. Git 제외 `SocialAuth.xcconfig`를 본체에서 복사해 같음을 확인(값 미출력). `flutter pub get --enforce-lockfile` 뒤 `flutter build ipa --release --no-pub -t lib/main.dart --build-name=0.5.1 --build-number=12`, 공개 소셜 Dart define 3개. Flutter 3.47.9. 작업 트리 HEAD `3626004`, 변경은 CHANGELOG·배포 기록뿐 | 145초 성공, 0.5.1(12) 확인. 산출물을 본체 후보 폴더로 복사(IPA SHA-256 일치). 업로드 미실행 |
| 2026-11-09 02:52–02:54 | Android AAB | iOS 빌드 종료 후 실행. 저장소 밖 값 파일에서 서명 설정·공개 SDK 설정을 불러옴(값 미출력). `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.5.1 --build-number=8`, 운영 API·공개 SDK 설정 지정. 빌드 뒤 단독 `:app:validateReleaseSigning` BUILD SUCCESSFUL | 91초 성공, 0.5.1(8) 확인. 본체 후보 폴더로 복사(SHA-256 일치), `./gradlew --stop`으로 데몬 정지. 업로드 미실행 |
| 2026-11-09 02:57 | 태그 생성·푸시 | 사용자 승인(2026-11-09, 선택 원문: "태그 생성·push (Recommended)", "iOS 12 App Store Connect 업로드 (Recommended)", "기록 브랜치 push·PR (Recommended)". Android 8 업로드는 승인 항목 아님 — 사용자가 직접). 만들기 전 로컬·origin에 같은 태그 없음 확인. annotated 태그 `app-ios-v0.5.1-b12`·`app-android-v0.5.1-b8`을 `3626004b94e14a4613fbcd0e1236c50c9d1d0311`에 만들어 origin에 푸시 | origin `ls-remote`로 두 태그가 `3626004`를 가리킴을 확인 |
| 2026-11-09 02:57–02:59 | iOS 업로드 | 같은 승인. 빌드 차례 확인(비어 있음) 뒤 실행. 올리기 전 아카이브의 본앱 `com.huturu.app`·공유 확장 `com.huturu.app.ShareExtension` 모두 0.5.1(12), 소스 `3626004`(이 기록) 대조. 새로 빌드하지 않고 같은 아카이브를 `xcodebuild -exportArchive -allowProvisioningUpdates`로 업로드. 내보내기 설정은 IPA 내보내기와 같은 자동 서명·팀 `8X6N747PQM`·method `app-store-connect`에서 destination만 upload로, 빌드 번호 자동 변경(`manageAppVersionAndBuildNumber`)은 끔. Xcode에 로그인된 계정 사용 | 116초, `Upload succeeded`·`EXPORT SUCCEEDED`, 한 번 시도. 로그에 Xcode에 등록된 다른 계정 하나의 자격 증명 로드 실패 경고가 있었으나(0.5.0 때와 같음) 업로드에 영향 없음. App Store Connect 처리·TestFlight 제공은 미확인(사용자 확인 대기). Android 8 업로드는 사용자 진행 예정, 미확인 |
| 2026-11-09 (시각 미확인) | 테스터 제공 보고 수신 | 사용자 보고(조율 경유). 조율의 요청 "iOS 12 처리 뒤 TestFlight 테스터 제공, Android 8 Play Console 내부 테스트 업로드"에 원문 "둘 다 제공했어" | 사용자 보고, 화면 증거 받지 않음. Android에 올린 파일이 후보 AAB인지는 따로 확인받지 않음. iOS 테스트 그룹(내부·외부)·이름, Android 트랙 이름, 업로드·제공 시각은 사용자 보고 없음. 외부 베타 심사·실기기 확인 미확인, 정식 배포 대상 지정은 미결정 |
| 2026-11-09 (시각 미확인) | 실기기 확인 결과 수신 | iPhone 13 / iOS 26.1에서 사용자가 순서표대로 진행하고 조율에 결과 표를 전달. 앱 0.5.2 후보 준비 때(2026-11-11) 조율 작업 파일의 순서표 끝 표를 읽어 옮김 | 검증 결과의 실기기 행 참조. 사용자 확인 결과이며 원 자료에 화면 증거는 없음 |
