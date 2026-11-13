# app-v0.6.0-ios-b14-android-b10

## 배포 개요

- 배포 식별자: app-v0.6.0-ios-b14-android-b10
- 배포 담당자: 저장소 운영자
- 준비일: 2026-11-14T02:39:11+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱] 마이 고객지원 이용약관 및 개인정보·오픈소스 라이선스 (#349, CHANGELOG 앱 0.6.0 추가); [앱] 문의하기 구글 폼 (#336, CHANGELOG 앱 0.6.0 개선); [앱] 콘텐츠 상세 제목·요약 글씨 1px 키움 (#336, CHANGELOG 앱 0.6.0 개선); [앱] 링크 저장 결과 예시 썸네일 제거 (#350, CHANGELOG 앱 0.6.0 수정); [iOS] [Android] 마이 최근 다시 본 콘텐츠 (#338, CHANGELOG 앱 0.6.0 수정)
- 관련 PR·작업 링크: [상세 제목·요약 글씨 1px 키우고 문의하기를 구글 폼으로 열기 #337](https://github.com/clip-back/clipback/pull/337)(#336), [마이 통계를 최근 7일 다시 본 콘텐츠 수로 변경 #340](https://github.com/clip-back/clipback/pull/340)(#338), [마이 고객지원에 처리방침·약관 링크와 오픈소스 라이선스 화면 추가 #351](https://github.com/clip-back/clipback/pull/351)(#349), [저장 화면의 고정 예시 그림 제거 #352](https://github.com/clip-back/clipback/pull/352)(#350)
- 앱 버전별 개요·이전 후보 링크: 개요 없음. 이전 버전 후보 [iOS 0.5.2(13)·Android 0.5.2(9)](app-v0.5.2-ios-b13-android-b9.md)
- 후보 준비 상태·미확인 사유: iOS 0.6.0(14) 아카이브·IPA와 Android 0.6.0(10) AAB 빌드 완료(2026-11-14). 두 산출물 모두 업로드 대상 후보이며 업로드 금지로 지정한 산출물은 없음. 후보 태그 미생성, 업로드 미실행(사용자 승인 대기). Android 10은 Play 비공개 테스트(Alpha) 트랙에 처음 올릴 예정(사용자 결정 "B로 하자": 0.5.2는 Alpha에 올리지 않음). 테스트 배포·심사·실기기 확인·정식 공개 미실행

사용자 결정(2026-11-14, 조율 전달): iOS 14·Android 10, 소스 main `84ff8b0`, 포함 변경은 CHANGELOG `미배포`의 앱 항목 전부. 처음 지시는 사용자 버전 0.5.3이었으나, 미배포에 `[앱]` `추가`(#349)가 있어 [버전 결정](../release-process.md#버전-결정)의 "기능 추가는 가운데 숫자"와 맞지 않아 배포 세션이 멈추고 물었고, 사용자가 0.6.0을 골랐습니다(2026-11-14 "0.6.0 (Recommended)"). 스토어 최대 업로드 번호는 iOS 13(App Store Connect)·Android 9(Play Console)이며 사용자가 2026-11-14에 확인했습니다.
포함 변경은 `추가` 1개(#349), `개선` 2개(#336), `수정` 2개(#350, #338)입니다. 같은 `미배포`의 `[서버]` 항목 넷(#346, #339, #338, #342)은 [backend-2026-11-14-1](backend-2026-11-14-1.md)로 옮겼습니다.

`app-ios-v0.5.2-b13`(`42480b3`)..`84ff8b0`의 `frontend/` 변경은 위 다섯 항목의 PR 넷(#337, #340, #351, #352)뿐입니다(`git log 42480b3..84ff8b0 -- frontend/`). 그 밖의 커밋은 서버(`8192a2b` #341: #339, `d3b9c97` #343: #342, `fc969b4` #348: #344 — [backend-2026-11-14-1](backend-2026-11-14-1.md))와 배포 기록 문서(#335)입니다.

팀 피드백 시트(“[허투루] 앱 테스트 피드백”)에서 이 빌드에 든 줄: B열 55 → #349, B열 56 → #350, B열 18 → #336, B열 28 → #336(콘텐츠 상세 제목·요약만 반영, 나머지 화면은 나중), B열 13 → #338 (2026-11-14 02:48 KST 무렵 조회, 다섯 줄 모두 I열 "구현 완료"). 시트는 고치지 않았습니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-11-14T02:39:11+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-11-14T02:39:11+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인(조율 전달, 2026-11-14; 정확한 확인 시각은 미확인이라 배포 세션 확인 시각 기재) / 2026-11-14T02:38:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 13 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 versionCode https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인(조율 전달, 2026-11-14; 정확한 확인 시각은 미확인이라 배포 세션 확인 시각 기재) / 2026-11-14T02:38:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 9 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.6.0 | 0.6.0 |
| 실제 빌드 번호 | 14 | 10 |
| 빌드 소스 SHA | 84ff8b07edcffd9a421845ff5758a2ddc099f929 | 84ff8b07edcffd9a421845ff5758a2ddc099f929 |
| 후보 태그·실제 생성 여부 | app-ios-v0.6.0-b14 (미생성 — 사용자 승인 대기) | app-android-v0.6.0-b10 (미생성 — 사용자 승인 대기) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미결정 — 업로드·실기기 확인 전 | 미결정 — 업로드·실기기 확인 전 |
| 빌드 결과·산출물 식별자 | 아카이브·IPA 내보내기 성공. 아카이브 `frontend/build/release-candidates/app-v0.6.0-ios-b14/Runner.xcarchive`(생성 2026-11-14 02:42 KST), IPA `frontend/build/release-candidates/app-v0.6.0-ios-b14/ipa/clipback_frontend.ipa` 42,381,180바이트, SHA-256 `7780dd0eec31c7504867d47978c6e11cb0868e741d859d3554206388ee3a22a0` — 본앱 `com.huturu.app` 0.6.0(14), 공유 확장 `com.huturu.app.ShareExtension` 0.6.0(14), 팀 `8X6N747PQM`, 권한 설명 3종 존재. 업로드 대상 후보(업로드 금지 아님) | Release AAB 성공. `frontend/build/release-candidates/app-v0.6.0-android-b10/app-release.aab`, 74,554,915바이트, SHA-256 `d5511efea5ea0f147ba27274862e9c96ff371e5a02e057acff77415baca94176`. versionName 0.6.0·versionCode 10 확인. 업로드 대상 후보(업로드 금지 아님) |
| 업로드·처리 상태 | 미실행 — 사용자 승인 대기 | 미실행 — 사용자 승인 대기. 승인 뒤 Play 비공개 테스트(Alpha) 트랙 업로드 예정 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | 미실행 — 업로드 전 | 미실행 — 업로드 전. 대상 트랙: 비공개 테스트(Alpha), 이 앱에서 Alpha에 처음 올리는 빌드 |
| 심사 상태 | 미실행 — 업로드 전 | 미실행 — 업로드 전 |
| 정식 공개 상태·공개 범위 | 미실행 | 미실행 |
| 실제 공개일·시각 | 해당 없음 — 공개 전 | 해당 없음 — 공개 전 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중. 같은 시기 서버 변경은 [backend-2026-11-14-1](backend-2026-11-14-1.md) 사후 기록(#338, #339, #342, #346), 그 전 서버 변경은 [backend-2026-11-11-1](backend-2026-11-11-1.md) |
| 서버 소스 SHA·산출물 식별자 | 운영 중 84ff8b07edcffd9a421845ff5758a2ddc099f929 / Railway deployment `0f8b35ed-9e99-48ac-a9e1-7045ecefee23`(SUCCESS, 2026-11-14 02:35 KST 생성) — 앱 빌드 소스와 같은 커밋 |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 앱 후보에서 서버 후보를 만들지 않음 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 불필요 — `42480b3..84ff8b0`에 `backend/alembic/versions/` 변경 없음. head `202611060022` 그대로 |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | #338의 앱 "최근 다시 본 콘텐츠"는 서버 마이 통계 새 필드에 의존(서버 먼저, PR #340). `885d05a` 운영 반영(2026-11-12 17:17 KST 생성 deployment, [backend-2026-11-14-1](backend-2026-11-14-1.md)) 확인으로 선행 조건 충족. #349의 개인정보처리방침 페이지(`https://huturu-app.github.io/privacy`)와 #336의 문의 구글 폼은 저장소 밖 웹 주소이며 이 세션에서 열리는지 확인하지 않음 |
| 기존 앱과의 호환성 | `/api/v1` 유지. 이번 앱 변경은 요청 형식을 바꾸지 않고, #338은 서버가 더한 응답 필드를 읽음(누적 `reopened_count`는 이전 앱을 위해 서버에 남음). 이 산출물과 운영 서버의 실제 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱, 새 revision 없음) |
| 실제 서버 배포 상태·시각·근거 | 배포 세션에서 `railway deployment list --json` 조회(2026-11-14 02:47 KST): `84ff8b0` 네 서비스 SUCCESS, 이전 배포는 모두 REMOVED. `/api/v1/health/ready` 200(2026-11-14 02:47 KST) |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.5.2(13)·Android 0.5.2(9) 산출물 보존(`frontend/build/release-candidates/`). 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버 복구는 backend-2026-11-14-1과 [Railway 배포·복구](../railway-deployment.md) 참조 |

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함. 같은 앱 소스의 검사는 원격 CI 결과(아래)만 있음 |
| 산출물 정적 검사(iOS IPA) | IPA의 본앱·공유 확장 `Info.plist`, 아카이브 `Info.plist`, `codesign -dvv`·`codesign --verify --deep --strict`, 포함된 provisioning profile, entitlements | 통과 | 0.6.0(14)·공유 확장 0.6.0(14). Apple Distribution 인증서·팀 `8X6N747PQM`, 서명 검증 통과, profile `iOS Team Store Provisioning Profile: com.huturu.app`, `get-task-allow` false. 권한 설명 3종 존재 |
| 산출물 정적 검사(Android AAB) | `:app:validateReleaseSigning`, 병합 manifest, `jarsigner -verify`, 업로드 인증서(`META-INF/UPLOAD.RSA`) 지문, `.so`의 ELF LOAD 정렬 | 통과 | `com.huturu.app`·0.6.0(10)·minSdk 24·targetSdk 36. `jar verified.` 업로드 인증서 SHA-256 `B0:76:98:8A…87:E5:9A:D0`, 빌드 9 AAB의 인증서와 같음. `.so` 12개 중 64비트 8개 모두 16KB 이상 정렬. bundletool 검사는 미실행(미설치) |
| 원격 CI | `84ff8b0`의 App Validation (push)·Backend Validation (push) | 모두 success(Backend의 operator-recovery·deployment job은 skipped) | [App Validation run 43474259214](https://github.com/clip-back/clipback/actions/runs/43474259214), [Backend Validation run 43474259320](https://github.com/clip-back/clipback/actions/runs/43474259320). 빌드 시작(02:40 KST) 때는 진행 중이었고 02:47 KST 확인에서 완료. 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함(메모리 8GB). 변경별 시뮬레이터 확인은 각 PR 작업 기록에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유 |
| 실제 OAuth·외부 공급자 | 미실행 | 미실행 | 업로드·테스터 제공 전. #336 문의 구글 폼·#349 처리방침 웹 페이지 열기도 미확인 |
| 운영 서버 | Railway production 배포 목록, `/api/v1/health/ready` (2026-11-14 02:38–02:47 KST) | `84ff8b0` SUCCESS, health 200 | 이 앱 후보와 운영 API의 연동(#338 최근 다시 본 콘텐츠 숫자)은 미실행 |
| 실기기 | 미실행 | 미실행 | 업로드·테스터 제공 전 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-11-14 02:38 | 버전 확인 | 지시된 0.5.3을 [버전 결정](../release-process.md#버전-결정)과 대조: 미배포에 `[앱]` `추가`(#349)가 있어 MINOR 규칙과 맞지 않음. 조율에 묻고 멈춤 | 사용자 결정 0.6.0(2026-11-14, 조율 전달). 빌드 번호 iOS 14·Android 10 그대로, 작업 브랜치 이름을 `chore/app-release-0.6.0-ios-b14-android-b10`으로 바꿈 |
| 2026-11-14 02:39 | 후보 예약 | 사용자 확인 스토어 최대 업로드(App Store Connect 13, Play 9, 2026-11-14 사용자 확인, 시각 미확인이라 배포 세션 확인 시각 02:38 KST 기재)로 iOS 0.6.0(14)·Android 0.6.0(10) 예약. 소스 main `84ff8b0` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성 |
| 2026-11-14 02:40–02:43 | iOS 아카이브·IPA 내보내기 | 다른 작업자의 `flutter test`가 끝나기를 빌드 차례 확인으로 기다린 뒤 실행. Git 제외 `SocialAuth.xcconfig`를 본체에서 복사해 같음을 확인(값 미출력). `flutter pub get --enforce-lockfile` 뒤 `flutter build ipa --release --no-pub -t lib/main.dart --build-name=0.6.0 --build-number=14`, 공개 소셜 Dart define 3개. Flutter 3.47.9. 작업 트리 HEAD `84ff8b0`, 변경은 CHANGELOG·배포 기록뿐 | 162초 성공, 0.6.0(14) 확인. 산출물을 본체 후보 폴더로 복사(IPA SHA-256 일치, 아카이브 `diff -r` 같음). 업로드 미실행 |
| 2026-11-14 02:43–02:46 | Android AAB | iOS 빌드 종료 후 차례 확인 뒤 실행. 저장소 밖 값 파일에서 서명 설정·공개 SDK 설정을 불러옴(값 미출력). `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.6.0 --build-number=10`, 운영 API·공개 SDK 설정 지정. 빌드 뒤 단독 `:app:validateReleaseSigning` 통과 | 148초 성공, 0.6.0(10) 확인. 본체 후보 폴더로 복사(SHA-256 일치), `./gradlew --stop`으로 데몬 정지. 업로드 미실행 |
