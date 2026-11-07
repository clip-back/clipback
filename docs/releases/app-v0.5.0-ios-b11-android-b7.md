# app-v0.5.0-ios-b11-android-b7

## 배포 개요

- 배포 식별자: app-v0.5.0-ios-b11-android-b7
- 배포 담당자: 저장소 운영자
- 준비일: 2026-11-07T17:54:02+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱] 회원 탈퇴 화면 (#256, CHANGELOG 앱 0.5.0 추가); [앱] 탈퇴 후 기기 정리 (#257, CHANGELOG 앱 0.5.0 추가); [앱] 즐겨찾기·카테고리 이동 중 “변경 중…” 문구 제거 (#265, CHANGELOG 앱 0.5.0 개선); [앱] 아이콘 버튼 스크린 리더 이름 (#202, CHANGELOG 앱 0.5.0 수정); [앱] 링크 상세의 전문 보기 제거 (#201, CHANGELOG 앱 0.5.0 수정)
- 관련 PR·작업 링크: [전문 보기 제거 #259](https://github.com/clip-back/clipback/pull/259)(#201), [회원 탈퇴 #261](https://github.com/clip-back/clipback/pull/261)(#250·#256·#257, 서버 #253·#254·#255도 이 PR로 병합), [아이콘 접근성 이름·미분류 예약 이름 #268](https://github.com/clip-back/clipback/pull/268)(#202, 서버 #191), [“변경 중…” 제거 #270](https://github.com/clip-back/clipback/pull/270)(#264·#265)
- 앱 버전별 개요·이전 후보 링크: 개요 없음. 이전 버전 후보 [iOS 0.4.1(10)·Android 0.4.1(6)](app-v0.4.1-ios-b10-android-b6.md)
- 후보 준비 상태·미확인 사유: iOS 0.5.0(11) 아카이브·IPA와 Android 0.5.0(7) AAB 빌드 완료(2026-11-07). 후보 태그 생성·푸시(2026-11-07). iOS 11은 배포 세션이 App Store Connect에 업로드(2026-11-07 18:14 KST, Upload succeeded). Android 7 업로드는 사용자 진행 예정, 미확인. App Store Connect 처리·테스터 제공·심사·실기기 확인 미확인, 정식 공개 미실행

사용자 결정(2026-11-07, 원문): "버전은 0.5.0으로 해줘 ios 10 android 6이야". 앞 숫자는 스토어 최대 업로드 번호이며 새 번호는 iOS 11·Android 7입니다.
포함 변경은 CHANGELOG `미배포`의 `[앱]` 항목 5개 전부입니다(`[iOS]`·`[Android]` 항목은 없었음). 새 기능인 회원 탈퇴(`추가`)가 들어가 MINOR 규칙에 따라 0.4.1에서 0.5.0으로 올렸습니다.
`[서버]` 항목 4개(#253·#254·#255·#191)는 운영 반영을 확인해 [backend-2026-11-07-1](backend-2026-11-07-1.md)로 옮겼으며 이 후보에는 중복 기록하지 않습니다.

`ea2825a..901a3b1`의 `frontend/` 변경은 위 앱 항목의 PR(#259·#261·#268·#270)과 화면 변화 없는 코드 정리(#272: #271, #274: #273·#212)입니다. 정리 PR 두 개는 사용자 동작 변화가 없다는 제외 사유를 PR에 적어 변경 이력 항목이 없습니다. 그 밖의 커밋은 문서(#260, #267)와 CI(#269)입니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-11-07T17:54:02+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-11-07T17:54:02+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인 보고(사용자 원문 "버전은 0.5.0으로 해줘 ios 10 android 6이야", 정확한 확인 시각은 미확인이라 배포 세션 지시 수신 시각 기재) / 2026-11-07T17:50:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 10 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인 보고(사용자 원문 "버전은 0.5.0으로 해줘 ios 10 android 6이야", 정확한 확인 시각은 미확인이라 배포 세션 지시 수신 시각 기재) / 2026-11-07T17:50:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 6 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.5.0 | 0.5.0 |
| 실제 빌드 번호 | 11 | 7 |
| 빌드 소스 SHA | 901a3b138894528ef17003874eef0ef28e58467a | 901a3b138894528ef17003874eef0ef28e58467a |
| 후보 태그·실제 생성 여부 | app-ios-v0.5.0-b11 (2026-11-07 생성·푸시, annotated) | app-android-v0.5.0-b7 (2026-11-07 생성·푸시, annotated) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미결정 — 테스트 배포·실기기 확인 전 | 미결정 — 테스트 배포·실기기 확인 전 |
| 빌드 결과·산출물 식별자 | 아카이브·IPA 내보내기 성공. 아카이브 `frontend/build/release-candidates/app-v0.5.0-ios-b11/Runner.xcarchive`(생성 2026-11-07 17:56 KST), IPA `frontend/build/release-candidates/app-v0.5.0-ios-b11/ipa/clipback_frontend.ipa` 42,842,956바이트, SHA-256 `4557a0299ac844e6d7a30280e46db948c174bd39099117b74e7be56240e09468` — 본앱 `com.huturu.app` 0.5.0(11), 공유 확장 `com.huturu.app.ShareExtension` 0.5.0(11), 팀 `8X6N747PQM`, 권한 설명 3종 존재 | Release AAB 성공. `frontend/build/release-candidates/app-v0.5.0-android-b7/app-release.aab`, 74,540,484바이트, SHA-256 `fb39451441a7168a9a5211d43d14f0fa713e317e3ef0e8e10b1d7d09f9996038`. versionName 0.5.0·versionCode 7 확인 |
| 업로드·처리 상태 | 후보 아카이브 `app-v0.5.0-ios-b11/Runner.xcarchive`를 `xcodebuild -exportArchive`(destination upload)로 App Store Connect에 업로드 성공(2026-11-07 18:14 KST). App Store Connect 처리 결과 미확인 | 사용자 진행 예정, 미확인 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | 미확인 — 처리 결과 확인 전 | 미실행 — 업로드 전 |
| 심사 상태 | 미확인 | 미실행 — 업로드 전 |
| 정식 공개 상태·공개 범위 | 미실행 | 미실행 |
| 실제 공개일·시각 | 해당 없음 — 공개 전 | 해당 없음 — 공개 전 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중. [서버] 항목은 [backend-2026-11-07-1](backend-2026-11-07-1.md) 사후 기록 |
| 서버 소스 SHA·산출물 식별자 | 운영 중 901a3b138894528ef17003874eef0ef28e58467a / Railway deployment `5246745b-d3ff-4b68-ab4b-8aeaa45ac56b`(SUCCESS, 2026-11-07 17:52 KST 생성) — 앱 빌드 소스와 같은 커밋 |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 앱 후보에서 서버 후보를 만들지 않음 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 필요 — `202611060022`(탈퇴 사유 통계 테이블, #253). 운영에 이미 적용됨(backend-2026-11-07-1). 앱 배포에 따른 추가 마이그레이션 없음 |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | 회원 탈퇴(#256·#257)는 `DELETE /api/v1/users/me`(#253)와 운영 `KAKAO_ADMIN_KEY`(#254)에 의존. 순서: 서버·마이그레이션(완료 확인, backend-2026-11-07-1) → 앱 업로드. 운영 탈퇴 동작(Apple 철회·카카오 연결 끊기 포함)의 실제 확인은 사용자 확인 필요 |
| 기존 앱과의 호환성 | `/api/v1` 유지. 새 API는 추가만 했고 기존 응답은 바꾸지 않음. #191의 예약 이름 거절은 기존 이름 중복 응답을 써서 0.4.1 앱도 기존 문구로 표시(CHANGELOG 설명). 배포된 0.4.1 앱과 운영 서버의 실제 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱). 서버 쪽 결과는 backend-2026-11-07-1 |
| 실제 서버 배포 상태·시각·근거 | 배포 세션에서 `railway deployment list --json` 조회(2026-11-07 17:55 KST): `901a3b1` SUCCESS. `/api/v1/health/ready` 200(2026-11-07 17:55 KST) |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.4.1(10)·Android 0.4.1(6) 산출물 보존(`frontend/build/release-candidates/`). 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버 복구는 [Railway 배포·복구](../railway-deployment.md) 참조 |

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함. 같은 소스의 앱 검사는 원격 CI 결과(아래)만 있음 |
| 산출물 정적 검사(iOS IPA) | IPA의 본앱·공유 확장 `Info.plist`, 아카이브 `Info.plist`, `codesign -dvv`·`codesign --verify --deep --strict`, 포함된 provisioning profile, entitlements | 통과 | 0.5.0(11)·공유 확장 0.5.0(11). Apple Distribution 인증서·팀 `8X6N747PQM`, 서명 검증 통과, profile `iOS Team Store Provisioning Profile: com.huturu.app`, `get-task-allow` false. 권한 설명 3종 존재 |
| 산출물 정적 검사(Android AAB) | `:app:validateReleaseSigning`, 병합 manifest, `jarsigner -verify`, 업로드 인증서(`META-INF/UPLOAD.RSA`) 지문, `.so`의 ELF LOAD 정렬 | 통과 | `com.huturu.app`·0.5.0(7)·minSdk 24·targetSdk 36. `jar verified`. 업로드 인증서 SHA-256 `b076988a…87e59ad0`(빌드 6과 같은 업로드 키). `.so` 12개 중 64비트(arm64-v8a·x86_64) 8개 모두 16KB 이상 정렬. bundletool이 설치돼 있지 않아 bundletool 검사는 미실행 |
| 원격 CI | `901a3b1`의 App Validation·Backend Validation (push) | 둘 다 success | [App Validation run 42357289958](https://github.com/clip-back/clipback/actions/runs/42357289958), [Backend Validation run 42357289947](https://github.com/clip-back/clipback/actions/runs/42357289947). 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함(메모리 8GB). 변경별 시뮬레이터 확인은 각 PR 작업 기록에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유 |
| 실제 OAuth·외부 공급자 | 미실행 | 미실행 | 업로드·테스터 제공 전. 탈퇴 때 Apple 토큰 철회·카카오 연결 끊기·Google 연결 해제의 실제 동작도 미확인 |
| 운영 서버 | Railway production 배포 목록, `/api/v1/health/ready` (2026-11-07 17:55 KST) | `901a3b1` SUCCESS, health 200 | 이 앱 후보와 운영 API의 연동(회원 탈퇴 포함) 검증은 미실행 — 사용자 확인 필요 |
| 실기기 | 미실행 | 미실행 | 업로드·테스터 제공 전 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-11-07 17:54 | 후보 예약 | 사용자 확인 스토어 최대 업로드(App Store Connect 10, Play 6, 2026-11-07 사용자 보고, 시각 미확인이라 지시 수신 시각 17:50 KST 기재)로 iOS 0.5.0(11)·Android 0.5.0(7) 예약. 소스 main `901a3b1` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성 |
| 2026-11-07 17:54–17:56 | iOS 아카이브·IPA 내보내기 | 빌드 차례 확인 뒤 실행. Git 제외 `SocialAuth.xcconfig`를 본체에서 복사해 같음을 확인(값 미출력). `flutter pub get --enforce-lockfile` 뒤 `flutter build ipa --release --no-pub -t lib/main.dart --build-name=0.5.0 --build-number=11`, 공개 소셜 Dart define 3개. Flutter 3.47.9. 작업 트리 HEAD `901a3b1`, 변경은 CHANGELOG·배포 기록뿐 | 143초 성공, 0.5.0(11) 확인. 산출물을 본체 후보 폴더로 복사(IPA SHA-256 일치). 업로드 미실행 |
| 2026-11-07 17:56–17:58 | Android AAB | iOS 빌드 종료 후 실행. 저장소 밖 값 파일에서 서명 설정·공개 SDK 설정을 불러옴(값 미출력). `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.5.0 --build-number=7`, 운영 API·공개 SDK 설정 지정. `android/gradlew`가 빌드 전에 없어 단독 `validateReleaseSigning`은 빌드 뒤 실행해 BUILD SUCCESSFUL | 98초 성공, 0.5.0(7) 확인. 본체 후보 폴더로 복사(SHA-256 일치), `./gradlew --stop`으로 데몬 정지. 업로드 미실행 |
| 2026-11-07 18:12 | 태그 생성·푸시 | 사용자 승인(2026-11-07, 원문 "1 2 4 진행해줘": 태그 2개 push, iOS 11 업로드, 기록 브랜치 push·PR. Android 7 업로드는 사용자가 직접). 푸시 직전 origin에 같은 태그 없음 확인. annotated 태그 `app-ios-v0.5.0-b11`·`app-android-v0.5.0-b7`을 `901a3b138894528ef17003874eef0ef28e58467a`에 만들어 origin에 푸시 | origin `ls-remote`로 두 태그가 `901a3b1`을 가리킴을 확인 |
| 2026-11-07 18:13–18:14 | iOS 업로드 | 같은 승인. 올리기 전 아카이브의 본앱 `com.huturu.app`·공유 확장 `com.huturu.app.ShareExtension` 모두 0.5.0(11), 소스 `901a3b1`(이 기록) 대조. 새로 빌드하지 않고 같은 아카이브를 `xcodebuild -exportArchive -allowProvisioningUpdates`로 업로드. 내보내기 설정은 IPA 내보내기와 같은 자동 서명·팀 `8X6N747PQM`·method `app-store-connect`에서 destination만 upload로, 빌드 번호 자동 변경(`manageAppVersionAndBuildNumber`)은 끔. Xcode에 로그인된 계정 사용 | 96초, `Upload succeeded`·`EXPORT SUCCEEDED`, 한 번 시도. 로그에 Xcode에 등록된 다른 계정 하나의 키체인 자격 증명 로드 실패 경고가 있었으나 업로드에 영향 없음. App Store Connect 처리·TestFlight 제공은 사용자 확인 대기. Android 7 업로드는 사용자 진행 예정, 미확인 |
