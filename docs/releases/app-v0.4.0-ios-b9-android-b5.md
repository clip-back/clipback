# app-v0.4.0-ios-b9-android-b5

## 배포 개요

- 배포 식별자: app-v0.4.0-ios-b9-android-b5
- 배포 담당자: 저장소 운영자
- 준비일: 2026-11-04T02:22:11+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱] 상세·목록 개수를 N / 전체·총 N개로 표시 (#224·#225, CHANGELOG 앱 0.4.0 추가); [앱][서버] 아카이브 즐겨찾기 우선 정렬을 서버 단일 목록으로 전환 (#224·#226, CHANGELOG 앱 0.4.0 개선); [앱] 홈 상단 소개 영역의 옛 "저장한 정보가 없어요." 삭제와 직전 소개 유지 (#217, CHANGELOG 앱 0.4.0 수정); [앱] 홈 최근 저장한 콘텐츠 영역 높이 고정 (#216, CHANGELOG 앱 0.4.0 수정); [앱] 화면 문구 북마크를 즐겨찾기로 통일 (#198, CHANGELOG 앱 0.4.0 수정); [앱] 홈의 최근 카테고리 영역 제거 (#197, CHANGELOG 앱 0.4.0 수정); [앱] 홈 미분류 칩 빈 화면 문구의 콘텐츠 중복 제거 (#189, CHANGELOG 앱 0.4.0 수정); [앱] 회원 탈퇴 안내 알림 중복 표시 수정 (#190, CHANGELOG 앱 0.4.0 수정); [앱] 앱 아이콘·시작 화면 로고 가운데 맞춤 (#180, CHANGELOG 앱 0.4.0 수정)
- 관련 PR·작업 링크: [아이콘·로고 가운데 맞춤 #181](https://github.com/clip-back/clipback/pull/181)(#180), [회원 탈퇴 알림 #192](https://github.com/clip-back/clipback/pull/192)(#190), [미분류 빈 화면 문구 #194](https://github.com/clip-back/clipback/pull/194)(#189), [최근 카테고리 제거 #199](https://github.com/clip-back/clipback/pull/199)(#197), [즐겨찾기 문구 #208](https://github.com/clip-back/clipback/pull/208)(#198), [최근 콘텐츠 높이 고정 #218](https://github.com/clip-back/clipback/pull/218)(#216), [홈 상단 소개 유지 #220](https://github.com/clip-back/clipback/pull/220)(#217), [전체 개수·즐겨찾기 우선 서버 정렬 #229](https://github.com/clip-back/clipback/pull/229)(#224, [ADR 0006](../adr/0006-feed-total-count.md), [작업 기록](../history/2026-11-03-feed-count-final.md))
- 앱 버전별 개요·이전 후보 링크: 개요 없음. 이전 버전 후보 [iOS 0.3.0(8)·Android 0.3.0(4)](app-v0.3.0-ios-b8-android-b4.md)
- 후보 준비 상태·미확인 사유: iOS 0.4.0(9) 아카이브·IPA와 Android 0.4.0(5) AAB 빌드 완료(2026-11-04). 후보 태그 생성·푸시(2026-11-04). TestFlight·Play 업로드는 사용자가 직접 하며 결과 미확인. 테스트 배포·심사·실기기 확인·정식 공개 미실행

포함 변경은 CHANGELOG `미배포`의 `[앱]` 항목 9개 전부입니다(`[iOS]`·`[Android]` 항목은 없었음). 앱의 목록 전체 개수와 즐겨찾기 우선 정렬(#224)은
서버의 `total_count`·`sort`에 의존하며, 서버는 main 자동 배포로 `78aecf5`가 운영에 반영된 것을 조율이 확인했습니다(2026-11-04).
`[앱][서버]` 즐겨찾기 우선 정렬 항목은 앱 변경을 포함하므로 앱 0.4.0으로 옮겼습니다. `미배포`에서 제목 없이 맨 위에 있던 `[앱]` 개수 표시 항목(#225)은 `추가`로 분류했습니다.
`[서버]` 항목 6개(#225 `total_count`, #203 자동 요약 형식, 복구 지점 관련 4개)는 이전 후보와 같은 기준으로 앱 후보에 넣지 않고 `미배포`에 남깁니다.

`835f915..78aecf5`의 `frontend/` 변경 중 변경 이력 항목이 없는 것은 Flutter 3.47.9 업그레이드(#209), Xcode 프로젝트 파일 형식(#196),
쓰지 않는 SVG 삭제(#213), 앱 CI·Dart 포맷(#215·#227), 테스트 도우미(#228)입니다. 사용자 동작 변화가 없어 제외됐지만 빌드에는 들어 있습니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-11-04T02:22:11+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-11-04T02:22:11+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인 보고(2026-11-04 채팅, 최대 0.3.0(8); 정확한 확인 시각은 미확인이라 배포 세션 수신 시각 기재) / 2026-11-04T02:21:53+09:00 KST | 수동 확인값: 최대 업로드 빌드 8 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인 보고(2026-11-04 채팅, 최대 0.3.0(4); 정확한 확인 시각은 미확인이라 배포 세션 수신 시각 기재) / 2026-11-04T02:21:53+09:00 KST | 수동 확인값: 최대 업로드 빌드 4 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.4.0 | 0.4.0 |
| 실제 빌드 번호 | 9 | 5 |
| 빌드 소스 SHA | 78aecf596cd02c7cc7993beda2fd9c0035cd96b0 | 78aecf596cd02c7cc7993beda2fd9c0035cd96b0 |
| 후보 태그·실제 생성 여부 | app-ios-v0.4.0-b9 (2026-11-04 생성·푸시, annotated) | app-android-v0.4.0-b5 (2026-11-04 생성·푸시, annotated) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미결정 — 테스트 배포·실기기 확인 전 | 미결정 — 테스트 배포·실기기 확인 전 |
| 빌드 결과·산출물 식별자 | 아카이브·IPA 내보내기 성공. 아카이브 `frontend/build/release-candidates/app-v0.4.0-ios-b9/Runner.xcarchive`(생성 2026-11-04 02:24 KST), IPA `frontend/build/release-candidates/app-v0.4.0-ios-b9/ipa/clipback_frontend.ipa` 41,821,122바이트, SHA-256 `4bba490ef56f4443081b5f9fcb6f575f02d90098079b68506f6d3fe70347a7f4` — 본앱 `com.huturu.app` 0.4.0(9), 공유 확장 `com.huturu.app.ShareExtension` 0.4.0(9), 팀 `8X6N747PQM`, 권한 설명 3종 존재 | Release AAB 성공. `frontend/build/release-candidates/app-v0.4.0-android-b5/app-release.aab`, 73,387,360바이트, SHA-256 `7955a776a81c2b0ab30c1cb7a9b04580563908b5577d5234518ffe00193b0f44`. versionName 0.4.0·versionCode 5 확인 |
| 업로드·처리 상태 | 미확인 — 사용자가 직접 업로드 예정 | 미확인 — 사용자가 직접 업로드 예정 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | 미실행 — 업로드 전 | 미실행 — 업로드 전 |
| 심사 상태 | 미실행 — 업로드 전 | 미실행 — 업로드 전 |
| 정식 공개 상태·공개 범위 | 미실행 | 미실행 |
| 실제 공개일·시각 | 해당 없음 — 공개 전 | 해당 없음 — 공개 전 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중 |
| 서버 소스 SHA·산출물 식별자 | 운영 중 78aecf596cd02c7cc7993beda2fd9c0035cd96b0(조율 확인, 2026-11-04) / Railway deployment ID 미확인 — 배포 세션에서 조회하지 않음 |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 앱 후보에서 서버 후보를 만들지 않음 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 불필요 — `835f915..78aecf5`에 `backend/alembic/versions/` 변경 없음 |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | 앱은 #224의 서버 `total_count`·`sort`에 의존. 서버 `78aecf5` 운영 반영(조율 확인, 2026-11-04) 뒤 앱 업로드 |
| 기존 앱과의 호환성 | `/api/v1` 유지. 응답 필드 추가만 함([ADR 0006](../adr/0006-feed-total-count.md) 호환 절). 배포된 0.3.0 앱과 운영 서버의 실제 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱) |
| 실제 서버 배포 상태·시각·근거 | `78aecf5` 운영 배포는 조율 확인(2026-11-04, 배포 시각 미확인). 배포 세션에서 `/api/v1/health/ready` 200(2026-11-04 02:22 KST) |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.3.0(8)·Android 0.3.0(4) 산출물 보존(`frontend/build/release-candidates/`). 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버 복구는 [Railway 배포·복구](../railway-deployment.md) 참조 |

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함. 같은 소스의 앱 검사는 원격 CI 결과(아래)만 있음 |
| 산출물 정적 검사(iOS IPA) | IPA의 본앱·공유 확장 `Info.plist`, 아카이브 `Info.plist`, `codesign -dvv`·`codesign --verify --deep --strict`, 포함된 provisioning profile, entitlements | 통과 | 0.4.0(9)·공유 확장 0.4.0(9). Apple Distribution 인증서·팀 `8X6N747PQM`, 서명 검증 통과, profile `iOS Team Store Provisioning Profile: com.huturu.app`, `get-task-allow` false. 권한 설명 3종 존재 |
| 산출물 정적 검사(Android AAB) | `:app:validateReleaseSigning`, 병합 manifest·`output-metadata.json`, AAB `base/manifest`, `jarsigner -verify`, 업로드 인증서(`META-INF/UPLOAD.RSA`) 지문, 64비트 `.so`의 ELF LOAD 정렬 | 통과 | `com.huturu.app`·0.4.0(5)·minSdk 24·targetSdk 36. 업로드 인증서 SHA-256 `b076988a…87e59ad0`(빌드 4와 같은 업로드 키). `.so` 12개 모두 16KB 이상 정렬. bundletool이 설치돼 있지 않아 bundletool 검사는 미실행 |
| 원격 CI | `78aecf5`의 App Validation·Backend Validation | App Validation success, Backend Validation 진행 중(2026-11-04 02:22 KST 조회 시 결론 없음) | [App Validation run 41682641915](https://github.com/clip-back/clipback/actions/runs/41682641915), [Backend Validation run 41682641921](https://github.com/clip-back/clipback/actions/runs/41682641921). 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 배포 작업 범위를 빌드·기록으로 정함(메모리 8GB 제약). 변경별 시뮬레이터 확인은 각 PR 작업 기록에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유 |
| 실제 OAuth·외부 공급자 | 미실행 | 미실행 | 업로드·설치 전 |
| 운영 서버 | `/api/v1/health/ready` (2026-11-04 02:22 KST) | 200 | 운영 SHA `78aecf5`는 조율 확인값이며 배포 세션에서 Railway를 조회하지 않음. 이 앱 후보와 운영 API의 연동 검증은 미실행 |
| 실기기 | 미실행 | 미실행 | 업로드·테스트 배포 전 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-11-04 02:22 | 후보 예약 | 사용자 확인 스토어 최대 업로드(App Store Connect 8, Play 4, 2026-11-04 채팅)로 iOS 0.4.0(9)·Android 0.4.0(5) 예약. 소스 main `78aecf5` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성 |
| 2026-11-04 02:22–02:25 | iOS 아카이브·IPA 내보내기 | Git 제외 `SocialAuth.xcconfig`를 본체에서 복사해 같음을 확인(값 미출력). `flutter build ipa --release --no-pub -t lib/main.dart --build-name=0.4.0 --build-number=9`, 공개 소셜 Dart define 3개. Flutter 3.47.9. 작업 트리 HEAD `78aecf5`, 변경은 CHANGELOG·이 기록뿐 | 아카이브 86초·IPA 37초 성공, 0.4.0(9) 확인. 산출물을 후보 폴더로 복사. 업로드 미실행 |
| 2026-11-04 02:25–02:28 | Android AAB | iOS 빌드 종료 후 실행. 저장소 밖 값 파일에서 서명 설정·공개 SDK 설정을 불러옴(값 미출력). `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.4.0 --build-number=5`, 운영 API·공개 SDK 설정 지정. 빌드 전 단독 `validateReleaseSigning`은 `android/gradlew`가 아직 생성되지 않아 실행되지 않았고, Release 빌드 안에서 자동 실행된 뒤 빌드 후 단독으로 다시 실행해 BUILD SUCCESSFUL | 약 120초 빌드 성공, 0.4.0(5) 확인. 후보 폴더로 복사, `./gradlew --stop`으로 데몬 1개 정지. 업로드 미실행 |
| 2026-11-04 | 태그 생성·푸시 | 사용자 승인(태그·브랜치 push만, 업로드는 사용자가 직접). annotated 태그 `app-ios-v0.4.0-b9`·`app-android-v0.4.0-b5`를 `78aecf5`에 만들어 origin에 푸시, 배포 브랜치 푸시 | origin `ls-remote`로 두 태그가 `78aecf5`를 가리킴을 확인. 업로드·처리·테스터 제공은 사용자 보고 후 기록 |
