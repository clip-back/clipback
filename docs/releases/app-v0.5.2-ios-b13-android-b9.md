# app-v0.5.2-ios-b13-android-b9

## 배포 개요

- 배포 식별자: app-v0.5.2-ios-b13-android-b9
- 배포 담당자: 저장소 운영자
- 준비일: 2026-11-11T03:13:45+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱] 랜덤 보기 마지막 카드 뒤 카테고리 목록 자동 복귀 (#309, CHANGELOG 앱 0.5.2 수정); [앱] 함께 보면 좋은 콘텐츠 카테고리 겹치는 콘텐츠 최대 3개 (#310, CHANGELOG 앱 0.5.2 수정); [앱] 마이 공지사항 메뉴 숨김 (#311, CHANGELOG 앱 0.5.2 개선); [앱] 공유 저장 시트 처리 중 버튼 읽는 이름 "전송 중" (#318, CHANGELOG 앱 0.5.2 수정); [앱] 링크 저장 응답 20초 제한·같은 화면 재시도 (#319, CHANGELOG 앱 0.5.2 수정)
- 관련 PR·작업 링크: [랜덤보기 마지막 카드 뒤 카테고리 목록 자동 복귀 #312](https://github.com/clip-back/clipback/pull/312)(#309), [함께 보면 좋은 콘텐츠 최대 3개, 마이 공지사항 메뉴 숨김 #313](https://github.com/clip-back/clipback/pull/313)(#310, #311), [공유 처리 중 버튼의 읽는 이름을 전송 중으로 #323](https://github.com/clip-back/clipback/pull/323)(#318), [링크 저장 응답 20초 제한·같은 화면 재시도 #324](https://github.com/clip-back/clipback/pull/324)(#319)
- 앱 버전별 개요·이전 후보 링크: 개요 없음. 이전 버전 후보 [iOS 0.5.1(12)·Android 0.5.1(8)](app-v0.5.1-ios-b12-android-b8.md)
- 후보 준비 상태·미확인 사유: iOS 0.5.2(13) 아카이브·IPA와 Android 0.5.2(9) AAB 빌드 완료(2026-11-11). 두 산출물 모두 업로드 대상 후보이며 업로드 금지로 지정한 산출물은 없음. 후보 태그 생성·푸시(2026-11-11). iOS 13은 배포 세션이 App Store Connect에 업로드(2026-11-11 03:27 KST, Upload succeeded). Android 9는 사용자가 Play Console 내부 테스트에 업로드(시각 미확인). iOS 13은 TestFlight 테스터에게, Android 9는 내부 테스트로 제공(사용자 보고, 2026-11-11, 시각·그룹·트랙 이름 미보고). 외부 베타 심사 미확인. iPhone 13 실기기 확인 결과 받음(실기기(사용자 확인), 2026-11-13, 아래 검증 결과의 실기기 행). Android 실기기 확인 미실행. 정식 공개 미실행

사용자 결정(2026-11-11, 조율 전달): 사용자 버전 0.5.2, iOS 13·Android 9. 스토어 최대 업로드 번호는 iOS 12(App Store Connect)·Android 8(Play Console versionCode)이며 사용자가 2026-11-11에 확인했습니다.
포함 변경은 CHANGELOG `미배포`의 `개선` 1개(#311)와 `수정` 4개(#309, #310, #318, #319) 전부입니다(`추가`와 `[iOS]`·`[Android]`·`[서버]` 항목은 없었음). 새 기능 없이 기존 흐름을 유지하는 개선·수정만 들어가 PATCH 규칙에 따라 0.5.1에서 0.5.2로 올렸습니다.

`app-ios-v0.5.1-b12`(`3626004`)..`42480b3`의 `frontend/` 변경은 위 다섯 항목의 PR 넷(#312, #313, #323, #324)뿐입니다(`git log 3626004..42480b3 -- frontend/`). 그 밖의 커밋은 서버(`7a6fdd3` #316: #314, #315 — [backend-2026-11-09-2](backend-2026-11-09-2.md), `42480b3` #332: #320 — [backend-2026-11-11-1](backend-2026-11-11-1.md))와 배포 기록 문서(#308, #317)입니다.

팀 피드백 시트(“[허투루] 앱 테스트 피드백”)에서 이 빌드에 든 줄: B열 68 → #309, B열 69 → #310, B열 30 → #311, B열 71 → #318, B열 70 → #319 (2026-11-11 03:20 KST 무렵 조회, 다섯 줄 모두 I열 "구현 완료"). 시트는 고치지 않았습니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-11-11T03:13:45+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-11-11T03:13:45+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인(조율 전달, 2026-11-11; 정확한 확인 시각은 미확인이라 배포 세션 지시 수신 시각 기재) / 2026-11-11T03:10:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 12 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 versionCode https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인(조율 전달, 2026-11-11; 정확한 확인 시각은 미확인이라 배포 세션 지시 수신 시각 기재) / 2026-11-11T03:10:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 8 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.5.2 | 0.5.2 |
| 실제 빌드 번호 | 13 | 9 |
| 빌드 소스 SHA | 42480b36989883836e1f0698bedff68bf415b648 | 42480b36989883836e1f0698bedff68bf415b648 |
| 후보 태그·실제 생성 여부 | app-ios-v0.5.2-b13 (2026-11-11 생성·푸시, annotated) | app-android-v0.5.2-b9 (2026-11-11 생성·푸시, annotated) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미결정 — 업로드·실기기 확인 전 | 미결정 — 업로드·실기기 확인 전 |
| 빌드 결과·산출물 식별자 | 아카이브·IPA 내보내기 성공. 아카이브 `frontend/build/release-candidates/app-v0.5.2-ios-b13/Runner.xcarchive`(생성 2026-11-11 03:15 KST), IPA `frontend/build/release-candidates/app-v0.5.2-ios-b13/ipa/clipback_frontend.ipa` 42,843,544바이트, SHA-256 `212eb4166f1bba1be187fedc4855a21bb079e56fbe84dd26981ec691fd906079` — 본앱 `com.huturu.app` 0.5.2(13), 공유 확장 `com.huturu.app.ShareExtension` 0.5.2(13), 팀 `8X6N747PQM`, 권한 설명 3종 존재. 업로드 대상 후보(업로드 금지 아님) | Release AAB 성공. `frontend/build/release-candidates/app-v0.5.2-android-b9/app-release.aab`, 74,534,951바이트, SHA-256 `34240f584b207968b80bbb9fc7efd68938021b5d7ad551be8ad7c81301419cdc`. versionName 0.5.2·versionCode 9 확인. 업로드 대상 후보(업로드 금지 아님) |
| 업로드·처리 상태 | 후보 아카이브 `app-v0.5.2-ios-b13/Runner.xcarchive`를 `xcodebuild -exportArchive`(destination upload)로 App Store Connect에 업로드 성공(2026-11-11 03:27 KST). App Store Connect 처리 완료 — TestFlight 테스터 제공이 이뤄졌다는 사용자 보고(2026-11-11)로 판단 | 사용자가 Play Console 내부 테스트에 업로드(사용자 보고, 2026-11-11 수신, 업로드 시각 미확인). 올린 파일이 `app-v0.5.2-android-b9/app-release.aab`인지는 사용자 보고 없음. Play 처리 완료 — 내부 테스트 제공이 이뤄졌다는 사용자 보고(2026-11-11)로 판단 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | TestFlight 테스터에게 제공(사용자 보고, 2026-11-11). 내부·외부 그룹과 그룹 이름은 사용자 보고 없음, 제공 시각 미확인 | 내부 테스트로 제공(사용자 보고, 2026-11-11). 트랙 이름은 사용자 보고 없음, 제공 시각 미확인 |
| 심사 상태 | 미확인 — 외부 베타 심사 여부는 사용자 보고 없음 | 미확인 |
| 정식 공개 상태·공개 범위 | 미실행 | 미실행 |
| 실제 공개일·시각 | 해당 없음 — 공개 전 | 해당 없음 — 공개 전 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중. 같은 시기 서버 변경은 [backend-2026-11-11-1](backend-2026-11-11-1.md) 사후 기록(#320, 변경 이력 항목 없음), 그 전 서버 변경은 [backend-2026-11-09-2](backend-2026-11-09-2.md) |
| 서버 소스 SHA·산출물 식별자 | 운영 중 42480b36989883836e1f0698bedff68bf415b648 / Railway deployment `aa1cc469-db65-4f27-bc10-a125f962ef29`(SUCCESS, 2026-11-10 16:08 KST 생성) — 앱 빌드 소스와 같은 커밋 |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 앱 후보에서 서버 후보를 만들지 않음 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 불필요 — `3626004..42480b3`에 `backend/alembic/versions/` 변경 없음. head `202611060022` 그대로 |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | 이 후보의 앱 변경은 새 서버 동작에 의존하지 않음(PR #312·#313·#323·#324 본문: API·DB 변경 없음). #319의 같은 화면 재저장이 한 번만 저장되는 것은 이미 운영 중인 제출 키 처리([backend-2026-11-09-1](backend-2026-11-09-1.md), `ef9f6a8` 운영 반영 2026-11-08 19:15 KST)를 씀. 선행 조건 충족 |
| 기존 앱과의 호환성 | `/api/v1` 유지. 이번 앱 변경은 요청·응답 형식을 바꾸지 않음. 이 산출물과 운영 서버의 실제 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱, 새 revision 없음) |
| 실제 서버 배포 상태·시각·근거 | 배포 세션에서 `railway deployment list --json` 조회(2026-11-11 03:12 KST): `42480b3` SUCCESS, 이전 배포는 모두 REMOVED. `/api/v1/health/ready` 200(2026-11-11 03:13 KST) |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.5.1(12)·Android 0.5.1(8) 산출물 보존(`frontend/build/release-candidates/`). 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버 복구는 backend-2026-11-11-1과 [Railway 배포·복구](../railway-deployment.md) 참조 |

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함. 같은 앱 소스의 검사는 원격 CI 결과(아래)만 있음 |
| 산출물 정적 검사(iOS IPA) | IPA의 본앱·공유 확장 `Info.plist`, 아카이브 `Info.plist`, `codesign -dvv`·`codesign --verify --deep --strict`, 포함된 provisioning profile, entitlements | 통과 | 0.5.2(13)·공유 확장 0.5.2(13). Apple Distribution 인증서·팀 `8X6N747PQM`, 서명 검증 통과, profile `iOS Team Store Provisioning Profile: com.huturu.app`, `get-task-allow` false. 권한 설명 3종 존재 |
| 산출물 정적 검사(Android AAB) | `:app:validateReleaseSigning`, 병합 manifest, `jarsigner -verify`, 업로드 인증서(`META-INF/UPLOAD.RSA`) 지문, `.so`의 ELF LOAD 정렬 | 통과 | `com.huturu.app`·0.5.2(9)·minSdk 24·targetSdk 36. `jar verified`. 업로드 인증서 SHA-256 `B0:76:98:8A…87:E5:9A:D0`, 빌드 8 AAB의 인증서와 같음. `.so` 12개 중 64비트 8개 모두 16KB 이상 정렬. bundletool 검사는 미실행(미설치) |
| 원격 CI | `6f650d8`의 App Validation (push), `42480b3`의 Backend Validation (push) | 모두 success | [App Validation run 42652660050](https://github.com/clip-back/clipback/actions/runs/42652660050)(`6f650d8`, 이후 `42480b3`까지 `frontend/` 변경 없음 — App Validation은 `frontend/` 변경 때만 실행), [Backend Validation run 42773256594](https://github.com/clip-back/clipback/actions/runs/42773256594)(`42480b3`). 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함(메모리 8GB). 변경별 시뮬레이터 확인은 각 PR 작업 기록에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유 |
| 실제 OAuth·외부 공급자 | 미실행 | 미실행 | 테스터 제공 뒤 사용자 확인 결과 보고 없음 |
| 운영 서버 | Railway production 배포 목록, `/api/v1/health/ready` (2026-11-11 03:12–03:13 KST) | `42480b3` SUCCESS, health 200 | 이 앱 후보와 운영 API의 연동은 실기기 행의 사용자 확인(2026-11-13) 참조: #319 링크 저장이 운영 서버에서 한 줄만 남음 |
| 실기기 | iPhone 13 / iOS 26.1, TestFlight 0.5.2(13), 운영 서버, 본인 계정. 사용자가 순서표(설치 → #311 → #309 → #310 → #318 → #319 → 테스트 콘텐츠 정리)대로 진행. Android 실기기는 미실행 | 설치·#311·#309·#310·#318·#319 모두 통과 (실기기(사용자 확인), 2026-11-13) | 설치: TestFlight 0.5.2(13), 마이 앱 버전 `ver. 0.5.2`. #311: 마이 고객지원에 공지사항 없음. #309: 랜덤 보기 마지막 카드를 넘기면 카테고리 목록으로 돌아감. #310: 상세의 함께 보면 좋은 콘텐츠가 3개 이하. #318: VoiceOver가 저장 중 버튼을 "전송중, 흐리게 표시됨"으로 읽음(사용자 메모 원문, "생략부호" 없음). #319: 링크 저장 중 비행기 모드를 켜자 20초 뒤 지연 안내가 뜨고 저장 버튼이 다시 켜짐. 다시 저장 전 운영 DB에 그 링크 1줄(서버는 저장했고 앱만 응답을 못 받은 상황 성립), 같은 화면에서 다시 저장한 뒤 링크 하나만 남음. 테스트 콘텐츠·캡처 삭제: 성공. 이번 후보 변경 범위 밖 관찰로, 사진 콘텐츠를 지울 때 이미지 삭제 실패 안내가 두 번 뜬 뒤 삭제가 성공함(사용자 메모 "메세지는 정확히 못봄"). 원인 조사·수정은 이 기록에서 하지 않음. 순서표 미확인으로 남은 것: 비행기 모드 때 앱이 20초 제한까지 기다렸는지 연결 오류로 끝났는지의 구분(사용자는 20초 뒤 지연 안내로 통과 표시), VoiceOver가 저장 중에 스스로 다시 읽는지, Android 실기기. 계정 식별자는 옮기지 않음 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-11-11 03:13 | 후보 예약 | 사용자 확인 스토어 최대 업로드(App Store Connect 12, Play 8, 2026-11-11 사용자 확인, 시각 미확인이라 지시 수신 시각 03:10 KST 기재)로 iOS 0.5.2(13)·Android 0.5.2(9) 예약. 소스 main `42480b3` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성 |
| 2026-11-11 03:14–03:16 | iOS 아카이브·IPA 내보내기 | 빌드 차례 확인(비어 있음) 뒤 실행. Git 제외 `SocialAuth.xcconfig`를 본체에서 복사해 같음을 확인(값 미출력). `flutter pub get --enforce-lockfile` 뒤 `flutter build ipa --release --no-pub -t lib/main.dart --build-name=0.5.2 --build-number=13`, 공개 소셜 Dart define 3개. Flutter 3.47.9. 작업 트리 HEAD `42480b3`, 변경은 CHANGELOG·배포 기록뿐 | 145초 성공, 0.5.2(13) 확인. 산출물을 본체 후보 폴더로 복사(IPA SHA-256 일치). 업로드 미실행 |
| 2026-11-11 03:16–03:19 | Android AAB | iOS 빌드 종료 후 차례 확인 뒤 실행. 저장소 밖 값 파일에서 서명 설정·공개 SDK 설정을 불러옴(값 미출력). `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.5.2 --build-number=9`, 운영 API·공개 SDK 설정 지정. 빌드 뒤 단독 `:app:validateReleaseSigning` BUILD SUCCESSFUL | 117초 성공, 0.5.2(9) 확인. 본체 후보 폴더로 복사(SHA-256 일치), `./gradlew --stop`으로 데몬 정지. 업로드 미실행 |
| 2026-11-11 03:25 | 태그 생성·푸시 | 사용자 승인(2026-11-11, 조율 전달 원문 "진행해줘": 태그 생성·push, iOS 13 업로드, 기록 브랜치 push·PR. Android 9 업로드는 사용자가 직접). 만들기 전 로컬·origin에 같은 태그 없음 확인. annotated 태그 `app-ios-v0.5.2-b13`·`app-android-v0.5.2-b9`를 `42480b36989883836e1f0698bedff68bf415b648`에 만들어 origin에 푸시 | origin `ls-remote`로 두 태그가 `42480b3`을 가리킴을 확인 |
| 2026-11-11 03:25–03:27 | iOS 업로드 | 같은 승인. 빌드 차례 확인(비어 있음) 뒤 실행. 올리기 전 보존 아카이브가 빌드 직후 아카이브와 같음(`diff -r`)을, 본앱 `com.huturu.app`·공유 확장 `com.huturu.app.ShareExtension` 모두 0.5.2(13)임을 확인. 새로 빌드하지 않고 보존 아카이브를 `xcodebuild -exportArchive -allowProvisioningUpdates`로 업로드. 내보내기 설정은 IPA 내보내기와 같은 자동 서명·팀 `8X6N747PQM`·method `app-store-connect`에서 destination만 upload로, 빌드 번호 자동 변경(`manageAppVersionAndBuildNumber`)은 끔. Xcode에 로그인된 계정 사용 | 118초, `Upload succeeded`(03:27:17 KST)·`EXPORT SUCCEEDED`, 한 번 시도. 로그에 Xcode에 등록된 다른 계정 하나의 자격 증명 로드 실패 경고가 있었으나(0.5.1 때와 같음) 업로드에 영향 없음. App Store Connect 처리·TestFlight 제공은 미확인. Android 9 업로드는 사용자 진행 예정, 미확인 |
| 2026-11-11 (시각 미확인) | 테스터 제공 보고 수신 | 사용자 보고(조율 경유) 원문 "제공 완료": iOS 13 TestFlight 테스터 제공, Android 9 Play Console 내부 테스트 업로드·제공 | 사용자 보고, 화면 증거 받지 않음. Android에 올린 파일이 후보 AAB인지는 따로 확인받지 않음. iOS 테스트 그룹(내부·외부)·이름, Android 트랙 이름, 업로드·제공 시각은 사용자 보고 없음. 외부 베타 심사·실기기 확인 미확인, 정식 배포 대상 지정은 미결정 |
| 2026-11-13 (시각 미확인) | 실기기 확인 결과 수신 | iPhone 13 / iOS 26.1에서 사용자가 순서표대로 진행하고 조율에 결과 표를 전달. 조율 작업 파일의 순서표 끝 표를 읽어 옮김 | 검증 결과의 실기기 행 참조. 사용자 확인 결과이며 원 자료에 화면 증거는 없음. 사진 콘텐츠 삭제 때 실패 안내 두 번 뒤 성공한 관찰은 범위 밖으로 조율이 따로 처리 |
