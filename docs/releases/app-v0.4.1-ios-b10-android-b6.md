# app-v0.4.1-ios-b10-android-b6

## 배포 개요

- 배포 식별자: app-v0.4.1-ios-b10-android-b6
- 배포 담당자: 저장소 운영자
- 준비일: 2026-11-06T15:32:18+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱] 공유 저장 중 전송 상태 표시 (#245, CHANGELOG 앱 0.4.1 개선); [앱] 하단 즐겨찾기 별 아이콘 위치 고정 (#240, CHANGELOG 앱 0.4.1 수정); [앱] 빈 화면 상자·검색 캐릭터 고해상도 원본 교체 (#241, CHANGELOG 앱 0.4.1 수정); [앱] 카테고리 무지개 색상 버튼 숨김과 단색 8개 배치 (#242, CHANGELOG 앱 0.4.1 수정); [앱] 아카이브 빈 화면 안내 문구와 저장 완료 버튼 (#237, CHANGELOG 앱 0.4.1 수정); [앱] 콘텐츠 삭제 전 확인 창 (#238, CHANGELOG 앱 0.4.1 수정); [앱] 마이 관리 메뉴 정리와 앱 버전 팝업 제거 (#239, CHANGELOG 앱 0.4.1 수정); [앱] 사진 저장 지연 후 재시도 중복 방지 (#235, CHANGELOG 앱 0.4.1 수정); [앱] 휴대폰 화면·시트 바깥 좌우 여백 제거 (#233, CHANGELOG 앱 0.4.1 수정); [앱] 홈 흰 패널을 하단 탭까지 연결 (#232, CHANGELOG 앱 0.4.1 수정); [앱] 허투루 픽 문구와 카테고리 이름 색 (#231, CHANGELOG 앱 0.4.1 수정)
- 관련 PR·작업 링크: [허투루 픽 문구 #234](https://github.com/clip-back/clipback/pull/234)(#231), [홈 흰 패널 #236](https://github.com/clip-back/clipback/pull/236)(#232), [바깥 좌우 여백 #243](https://github.com/clip-back/clipback/pull/243)(#233), [사진 저장 중복 방지 #244](https://github.com/clip-back/clipback/pull/244)(#235), [마이 메뉴 #246](https://github.com/clip-back/clipback/pull/246)(#239), [삭제 확인 창 #247](https://github.com/clip-back/clipback/pull/247)(#238), [빈 화면·저장 문구·색상 선택·하단 별 #248](https://github.com/clip-back/clipback/pull/248)(#237·#240·#241·#242), [공유 저장 전송 상태 #258](https://github.com/clip-back/clipback/pull/258)(#245)
- 앱 버전별 개요·이전 후보 링크: 개요 없음. 이전 버전 후보 [iOS 0.4.0(9)·Android 0.4.0(5)](app-v0.4.0-ios-b9-android-b5.md)
- 후보 준비 상태·미확인 사유: iOS 0.4.1(10) 아카이브·IPA와 Android 0.4.1(6) AAB 빌드 완료(2026-11-06). 후보 태그 생성·푸시(2026-11-06). iOS 10은 배포 세션이 App Store Connect에 업로드(2026-11-06 16:13 KST, Upload succeeded), Android 6은 사용자가 Play Console에 업로드. 양 플랫폼 업로드 완료(사용자 보고, 2026-11-07, 시각 미확인). iOS 10은 TestFlight 내부 그룹에, Android 6은 Play 내부 테스트 트랙에 제공(사용자 보고, 2026-11-07, 시각·그룹 이름 미보고). 심사·실기기 확인 미확인, 정식 공개 미실행

사용자 결정(2026-11-06, 원문): "버전 : 0.4.1 / 빌드 번호 : 스토어 상 iOS 9, Android 5 / 포함 범위 : 지금 main (201 제외)".
포함 변경은 CHANGELOG `미배포`의 `[앱]` 항목 11개 전부입니다(`[iOS]`·`[Android]` 항목은 없었음). 모두 `개선`·`수정`이라 PATCH 규칙에 따라 0.4.1입니다.
제목 없이 있던 삭제 확인 창 항목은 PR #247이 닫은 이슈 #238로 확인해 번호를 붙였습니다. #201(요약과 전문 같음)은 main에 없어 들어 있지 않습니다.
`[서버]` 항목 6개는 운영 반영을 확인해 [backend-2026-11-06-1](backend-2026-11-06-1.md)로 옮겼으며 이 후보에는 중복 기록하지 않습니다.

`78aecf5..ea2825a`의 `frontend/` 변경은 모두 위 앱 항목의 PR에 속하며 변경 이력 없이 빌드에 들어간 앱 변경은 없습니다. 그 밖의 커밋은 문서(#230 배포 기록, #249 AGENTS.md)입니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-11-06T15:32:18+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-11-06T15:32:18+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인 보고(사용자 원문 "빌드 번호 : 스토어 상 iOS 9, Android 5", 정확한 확인 시각은 미확인이라 조율 수신 시각 기재) / 2026-11-06T15:30:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 9 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인 보고(사용자 원문 "빌드 번호 : 스토어 상 iOS 9, Android 5", 정확한 확인 시각은 미확인이라 조율 수신 시각 기재) / 2026-11-06T15:30:00+09:00 KST | 수동 확인값: 최대 업로드 빌드 5 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.4.1 | 0.4.1 |
| 실제 빌드 번호 | 10 | 6 |
| 빌드 소스 SHA | ea2825a7c2075cef8a296f91f759df346ea4d680 | ea2825a7c2075cef8a296f91f759df346ea4d680 |
| 후보 태그·실제 생성 여부 | app-ios-v0.4.1-b10 (2026-11-06 생성·푸시, annotated) | app-android-v0.4.1-b6 (2026-11-06 생성·푸시, annotated) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미결정 — 테스트 배포·실기기 확인 전 | 미결정 — 테스트 배포·실기기 확인 전 |
| 빌드 결과·산출물 식별자 | 아카이브·IPA 내보내기 성공. 아카이브 `frontend/build/release-candidates/app-v0.4.1-ios-b10/Runner.xcarchive`(생성 2026-11-06 15:40 KST), IPA `frontend/build/release-candidates/app-v0.4.1-ios-b10/ipa/clipback_frontend.ipa` 42,812,874바이트, SHA-256 `e4baf3ba8549e511edfdd1e178fb3af9d666c92815b80f9645c22b1bd4217c8e` — 본앱 `com.huturu.app` 0.4.1(10), 공유 확장 `com.huturu.app.ShareExtension` 0.4.1(10), 팀 `8X6N747PQM`, 권한 설명 3종 존재 | Release AAB 성공. `frontend/build/release-candidates/app-v0.4.1-android-b6/app-release.aab`, 74,404,918바이트, SHA-256 `b073f34de16edbbcee92e782a99135206ad2384362f8e776ed0284a3dbf8c679`. versionName 0.4.1·versionCode 6 확인 |
| 업로드·처리 상태 | 후보 아카이브 `app-v0.4.1-ios-b10/Runner.xcarchive`를 `xcodebuild -exportArchive`(destination upload)로 App Store Connect에 업로드 성공(2026-11-06 16:13 KST). 업로드 완료(사용자 보고, 2026-11-07, 시각 미확인). App Store Connect 처리 완료 — TestFlight 제공이 이뤄졌다는 사용자 보고(2026-11-07)로 판단 | 사용자가 Play Console에 업로드, 업로드 완료(사용자 보고, 2026-11-07, 시각 미확인). 올린 파일이 `app-v0.4.1-android-b6/app-release.aab`인지는 사용자가 따로 확인해 주지 않음. Play 처리 완료 — 내부 테스트 트랙 제공이 이뤄졌다는 사용자 보고(2026-11-07)로 판단 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | TestFlight 내부 그룹에 제공(사용자 보고, 2026-11-07, 시각·그룹 이름 미보고) | Play 내부 테스트 트랙에 제공(사용자 보고, 2026-11-07, 시각 미보고) |
| 심사 상태 | 미확인 | 미확인 |
| 정식 공개 상태·공개 범위 | 미실행 | 미실행 |
| 실제 공개일·시각 | 해당 없음 — 공개 전 | 해당 없음 — 공개 전 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중. [서버] 항목은 [backend-2026-11-06-1](backend-2026-11-06-1.md) 사후 기록 |
| 서버 소스 SHA·산출물 식별자 | 운영 중 ea2825a7c2075cef8a296f91f759df346ea4d680 / Railway deployment `20c91c37-6d01-4d1d-8815-21c42d6abf2f`(SUCCESS, 2026-11-06 15:25 KST 생성) — 앱 빌드 소스와 같은 커밋 |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 앱 후보에서 서버 후보를 만들지 않음 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 불필요 — `78aecf5..ea2825a`에 `backend/alembic/versions/` 변경 없음 |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | 앱 항목은 새 서버 동작에 의존하지 않음. #235의 같은 제출 재요청 처리는 기존 서버 동작을 쓰며 이 PR의 `backend/` 변경은 통합 테스트 1개뿐. 선행 조건 없음 |
| 기존 앱과의 호환성 | `/api/v1` 유지, 이번 범위에 API 변경 없음. 배포된 0.4.0 앱과 운영 서버의 실제 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱) |
| 실제 서버 배포 상태·시각·근거 | 배포 세션에서 `railway deployment list --json` 조회(2026-11-06 15:31 KST): `ea2825a` SUCCESS. `/api/v1/health/ready` 200(2026-11-06 15:31 KST) |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.4.0(9)·Android 0.4.0(5) 산출물 보존(`frontend/build/release-candidates/`). 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버 복구는 [Railway 배포·복구](../railway-deployment.md) 참조 |

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함. 같은 소스의 앱 검사는 원격 CI 결과(아래)만 있음 |
| 산출물 정적 검사(iOS IPA) | IPA의 본앱·공유 확장 `Info.plist`, 아카이브 `Info.plist`, `codesign -dvv`·`codesign --verify --deep --strict`, 포함된 provisioning profile, entitlements | 통과 | 0.4.1(10)·공유 확장 0.4.1(10). Apple Distribution 인증서·팀 `8X6N747PQM`, 서명 검증 통과, profile `iOS Team Store Provisioning Profile: com.huturu.app`, `get-task-allow` false. 권한 설명 3종 존재 |
| 산출물 정적 검사(Android AAB) | `:app:validateReleaseSigning`, 병합 manifest, `jarsigner -verify`, 업로드 인증서(`META-INF/UPLOAD.RSA`) 지문, `.so`의 ELF LOAD 정렬 | 통과 | `com.huturu.app`·0.4.1(6)·minSdk 24·targetSdk 36. `jar verified`. 업로드 인증서 SHA-256 `b076988a…87e59ad0`(빌드 5와 같은 업로드 키). `.so` 12개 중 64비트(arm64-v8a·x86_64) 8개 모두 16KB 이상 정렬. bundletool이 설치돼 있지 않아 bundletool 검사는 미실행 |
| 원격 CI | `ea2825a`의 App Validation·Backend Validation (push) | 둘 다 success | [App Validation run 42174385833](https://github.com/clip-back/clipback/actions/runs/42174385833), [Backend Validation run 42174385780](https://github.com/clip-back/clipback/actions/runs/42174385780). 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함(메모리 8GB, 다른 작업이 기기 사용 중). 변경별 시뮬레이터 확인은 각 PR 작업 기록에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유 |
| 실제 OAuth·외부 공급자 | 미실행 | 미실행 | 업로드·테스터 제공 전 |
| 운영 서버 | Railway production 배포 목록, `/api/v1/health/ready` (2026-11-06 15:31 KST) | `ea2825a` SUCCESS, health 200 | 이 앱 후보와 운영 API의 연동 검증은 미실행 |
| 실기기 | 미실행 | 미실행 | 업로드·테스터 제공 전 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-11-06 15:32 | 후보 예약 | 사용자 확인 스토어 최대 업로드(App Store Connect 9, Play 5, 2026-11-06 15:30 KST 조율 수신)로 iOS 0.4.1(10)·Android 0.4.1(6) 예약. 소스 main `ea2825a` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성 |
| 2026-11-06 15:38–15:41 | iOS 아카이브·IPA 내보내기 | 다른 작업의 에뮬레이터 종료를 기다린 뒤 실행. Git 제외 `SocialAuth.xcconfig`를 본체에서 복사해 같음을 확인(값 미출력). `flutter build ipa --release --no-pub -t lib/main.dart --build-name=0.4.1 --build-number=10`, 공개 소셜 Dart define 3개. Flutter 3.47.9. 작업 트리 HEAD `ea2825a`, 변경은 CHANGELOG·배포 기록뿐 | 154초 성공, 0.4.1(10) 확인. 산출물을 본체 후보 폴더로 복사(IPA SHA-256 일치). 업로드 미실행 |
| 2026-11-06 15:41–15:44 | Android AAB | iOS 빌드 종료 후 실행. 저장소 밖 값 파일에서 서명 설정·공개 SDK 설정을 불러옴(값 미출력). `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.4.1 --build-number=6`, 운영 API·공개 SDK 설정 지정. `android/gradlew`가 빌드 전에 없어 단독 `validateReleaseSigning`은 빌드 뒤 실행해 BUILD SUCCESSFUL | 114초 성공, 0.4.1(6) 확인. 본체 후보 폴더로 복사(SHA-256 일치), `./gradlew --stop`으로 데몬 1개 정지. 업로드 미실행 |
| 2026-11-06 16:07 | 태그 생성·푸시 | 사용자 승인(2026-11-06, 원문 "모두 추천대로": 태그 2개 push와 기록 PR 초안). 푸시 직전 로컬·origin에 같은 태그 없음 확인. annotated 태그 `app-ios-v0.4.1-b10`·`app-android-v0.4.1-b6`를 `ea2825a7c2075cef8a296f91f759df346ea4d680`에 만들어 origin에 푸시, 배포 브랜치 푸시 | origin `ls-remote`로 두 태그가 `ea2825a`를 가리킴을 확인. 업로드는 사용자가 직접 하며 처리·테스터 제공은 사용자 보고 후 기록 |
| 2026-11-06 16:11–16:13 | iOS 업로드 | 사용자 승인(2026-11-06, 원문 "둘 다 해줘": 배포 세션이 iOS 0.4.1(10) 업로드). 올리기 전 아카이브의 본앱 `com.huturu.app`·공유 확장 `com.huturu.app.ShareExtension` 모두 0.4.1(10), 소스 `ea2825a`(이 기록) 대조. 새로 빌드하지 않고 같은 아카이브를 `xcodebuild -exportArchive -allowProvisioningUpdates`로 업로드. 내보내기 설정은 기존 IPA 내보내기와 같은 자동 서명·팀 `8X6N747PQM`·method `app-store-connect`에서 destination만 upload로, 빌드 번호 자동 변경(`manageAppVersionAndBuildNumber`)은 끔. Xcode에 로그인된 계정 사용 | 131초, `Upload succeeded`·`EXPORT SUCCEEDED`, 한 번 시도. 로그에 Xcode에 등록된 다른 계정 하나의 키체인 자격 증명 로드 실패 경고가 있었으나 업로드에 영향 없음. App Store Connect 처리·TestFlight 내부 그룹 제공은 사용자 확인 대기 |
| 2026-11-07 (시각 미확인) | 업로드 완료 보고 수신 | 사용자 보고(원문 "0.4.1 업로드 모두 완료 했어"): iOS 0.4.1(10)은 배포 세션이 2026-11-06 16:13 KST에 App Store Connect로 업로드한 것, Android 0.4.1(6)은 사용자가 Play Console에 업로드 | 사용자 보고, 화면 증거 받지 않음. Android에 올린 파일이 후보 AAB인지는 따로 확인받지 않음. App Store Connect·Play 처리, TestFlight 내부 그룹·Play 내부 테스트 트랙 제공, 심사, 실기기 확인은 미확인 |
| 2026-11-07 (시각 미확인) | 테스터 제공 보고 수신 | 사용자 보고(원문 "테스터에게 모두 제공 헀어"): iOS 0.4.1(10)은 TestFlight 내부 그룹, Android 0.4.1(6)은 Play 내부 테스트 트랙에 제공. 조율이 팀 앱 테스트 피드백 시트에서 이 빌드에 든 16줄(B열 7·23·24·25·27·31·35·37·42·43·44·46·48·51·54·59)의 반영 여부를 "반영 완료"로 바꿈 | 사용자 보고, 화면 증거 받지 않음. 그룹 이름·제공 시각 미보고. 심사·실기기 확인 미확인, 정식 배포 대상 지정은 미결정 |
