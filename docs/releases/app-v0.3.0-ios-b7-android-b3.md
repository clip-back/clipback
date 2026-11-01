# app-v0.3.0-ios-b7-android-b3

## 배포 개요

- 배포 식별자: app-v0.3.0-ios-b7-android-b3
- 배포 담당자: 저장소 운영자
- 준비일: 2026-10-31T23:35:13+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱] 처리 중 문구를 ‘링크 정보를 처리 중이에요’로 변경 (CHANGELOG 앱 0.3.0 개선); [iOS] 공유 저장 시트와 저장 완료 안내 (CHANGELOG 앱 0.3.0 개선); [iOS] 공유 저장 실패 이유별 알림창 (CHANGELOG 앱 0.3.0 개선); [Android] 공유 저장 시트·완료 안내·실패 알림창 (CHANGELOG 앱 0.3.0 개선); [앱] 마이 화면 앱 버전을 설치된 앱 값으로 표시 (CHANGELOG 앱 0.3.0 수정)
- 관련 PR·작업 링크: [앱 버전 표시 #120](https://github.com/clip-back/clipback/pull/120), [인스타그램 자동 요약·처리 중 문구 #135](https://github.com/clip-back/clipback/pull/135), [다른 앱 공유 시트 #138](https://github.com/clip-back/clipback/pull/138), 서버 기록 [backend-2026-10-31-1](backend-2026-10-31-1.md)
- 앱 버전별 개요·이전 후보 링크: 해당 없음 — 0.3.0 첫 후보. 이전 버전: [iOS 0.2.0(6)](app-v0.2.0-ios-b6.md), [Android 0.2.0(2)](app-v0.2.0-android-b2.md)
- 후보 준비 상태·미확인 사유: Android 정상 Release AAB 생성·정적 검사 완료. iOS는 아카이브까지 성공했고 계약 갱신 수락 대기로 IPA 내보내기·업로드 보류. 2026-11-01 사용자 결정으로 양 플랫폼 배포 일시 보류. 업로드·테스트 제공·실기기 확인 미실행

iOS는 0.2.0(6)의 소스 `a3972f9` 이후 처음 빌드하므로, `앱 0.2.0`에 기록된 사진 원본 보존 수정(#116, [앱] 사진 첨부 시 JPEG 압축 끔)이 이 후보에서 iOS에 처음 배포됩니다. 변경 이력 항목은 `앱 0.2.0`에 그대로 둡니다.
이번 실기기 확인 대상인 인스타그램 링크 요약은 서버 기능이며 서버 기록에서 운영 반영을 확인했습니다. 앱에는 처리 중 문구 변경만 포함됩니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-10-31T23:35:13+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-10-31T23:35:13+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인 보고 / 2026-10-31T23:35:11+09:00 KST | 수동 확인값: 최대 업로드 빌드 6 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인 보고 / 2026-10-31T23:35:11+09:00 KST | 수동 확인값: 최대 업로드 빌드 2 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.3.0 | 0.3.0 |
| 실제 빌드 번호 | 7 | 3 |
| 빌드 소스 SHA | a70009cd9638a09787cbf61817c683c3818c674c | a70009cd9638a09787cbf61817c683c3818c674c |
| 후보 태그·실제 생성 여부 | app-ios-v0.3.0-b7 (미생성) | app-android-v0.3.0-b3 (미생성) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미확인 | 미확인 |
| 빌드 결과·산출물 식별자 | 아카이브 성공, IPA 내보내기 실패(Apple Developer 프로그램 계약 갱신 미수락: `PLA Update available`, 배포 인증서 발급 불가). `frontend/build/release-candidates/app-v0.3.0-ios-b7/Runner.xcarchive` — 본앱 `com.huturu.app` 0.3.0(7), 공유 확장 포함, 팀 `8X6N747PQM`, 권한 설명 3종 존재 | 정상 Release AAB 성공. `frontend/build/release-candidates/app-v0.3.0-android-b3/app-release.aab`, 72,810,293바이트, SHA-256 `16023073071dc17db4e17e89679fc6c34e0d32a07bb300a8d6610f3dce92dcfe`. 산출물의 versionName 0.3.0·versionCode 3 확인 |
| 업로드·처리 상태 | 미확인 | 미확인 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | 미확인 | 미확인 |
| 심사 상태 | 미확인 | 미확인 |
| 정식 공개 상태·공개 범위 | 미확인 | 미확인 |
| 실제 공개일·시각 | 미확인 | 미확인 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중. 상세는 [backend-2026-10-31-1](backend-2026-10-31-1.md) |
| 서버 소스 SHA·산출물 식별자 | 운영 중 a70009cd9638a09787cbf61817c683c3818c674c / Railway deployment `bd06fc52-d7be-4cff-aa54-f605f68d0675` (서버 기록 참조) |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 서버 기록 [backend-2026-10-31-1](backend-2026-10-31-1.md)에서 관리 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 앱 배포에 추가 migration 불필요. 서버의 `202610310021`은 이미 적용(서버 기록 참조) |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | 서버·migration 운영 반영(2026-10-31 17:08~22:55 KST)과 `INSTAGRAM_SUMMARY_ENABLED=true` 설정(23:20 KST) 이후 앱 배포 |
| 기존 앱과의 호환성 | `/api/v1` 유지. 0.2.0 앱도 운영 서버를 그대로 사용하며 인스타그램 처리 중에는 이전 문구가 보일 수 있음. 실제 구버전 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱) — 서버 migration 근거는 [backend-2026-10-31-1](backend-2026-10-31-1.md) |
| 실제 서버 배포 상태·시각·근거 | 2026-10-31 23:20 KST 재배포 SUCCESS, `/api/v1/health` 200 — [backend-2026-10-31-1](backend-2026-10-31-1.md) |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.2.0(6)·Android 0.2.0(2) 산출물 보존. 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버 복구는 서버 기록 참조 |

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | `frontend/`에서 `flutter analyze --no-pub`, `flutter test --no-pub -j 2` (2026-10-31 23:52 KST 빌드 직전) | 통과 — 지적 0건, 2,018개 통과 | 빌드와 같은 작업 트리. 대역 데이터 검사이며 실제 공급자·운영 연동과 구분 |
| 산출물 정적 검사 | Android AAB: bundletool 1.18.3 `validate`·`dump manifest/config`, `jarsigner -verify`, `keytool -printcert`, ELF 프로그램 헤더 | 통과 | `com.huturu.app`·0.3.0(3)·minSdk 24·targetSdk 36·debuggable 없음. 업로드 인증서 SHA-256 `b076988a…87e59ad0`(빌드 2와 같은 업로드 키). arm64 Dart 바이너리에 운영 API·Google 웹 OAuth ID·카카오 Native key 포함, manifest에 카카오 콜백 scheme 포함(값은 기록하지 않음). ELF64 8개 모두 16KB 정렬, ELF32 4개는 대상 아님, `PAGE_ALIGNMENT_16K` |
| 원격 CI | `a70009c`의 Backend Validation | success | [run 41207775622](https://github.com/clip-back/clipback/actions/runs/41207775622). 프론트 검사를 포함하지 않으며 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 이번 배포 작업 지시: 다른 작업 폴더의 백엔드 테스트와 메모리 8GB 제약으로 시뮬레이터를 띄우지 않음. 해당 기능의 시뮬레이터 검증은 #135·#138 작업 이력에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유로 에뮬레이터를 띄우지 않음 |
| 실제 OAuth·외부 공급자 | 미실행 | 미실행 | 실기기 Google 로그인·인스타그램 링크 요약 결과를 사용자에게 받은 뒤 기록 |
| 운영 서버 | Railway production 조회·`/api/v1/health` | SUCCESS·200 | 서버 기록 [backend-2026-10-31-1](backend-2026-10-31-1.md). 이 앱 후보와 운영 API의 연동 검증은 미실행 |
| 실기기 | 미실행 | 미실행 | Galaxy Play 업데이트 후 Google 로그인·공유 저장 시트·인스타그램 링크 요약을 사용자가 확인할 예정. 결과를 받기 전에는 완료로 적지 않음 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-10-31 23:35 | 후보 예약 | 사용자가 확인한 스토어 최대 업로드(App Store Connect 6, Play 2)로 iOS 0.3.0(7)·Android 0.3.0(3) 예약. 소스 `a70009c` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성, 빌드 미실행 |
| 2026-10-31 23:52 이전 | Android 서명 검증·로컬 검사 | 저장소 밖 값 파일에서 1Password 복원 서명 설정·공개 SDK 설정을 불러옴(값 미출력). JDK 21.0.9로 `:app:validateReleaseSigning` → `flutter analyze`·`flutter test` | 서명 검증 BUILD SUCCESSFUL, analyze 0건, 테스트 2,018개 통과 |
| 2026-10-31 23:52 | Android 정상 빌드 | `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.3.0 --build-number=3`, 운영 API·공개 SDK 설정 지정. 작업 트리 HEAD `c39117c`는 `a70009c`에 문서 커밋 2개만 더한 상태로 `frontend/` 차이 없음 | 108.6초 빌드 성공. 산출물을 후보 폴더로 복사하고 해시·서명·manifest·16KB 정렬 검사 통과. 업로드 미실행 |
| 2026-10-31 23:58 | iOS 아카이브·내보내기 | main 체크아웃의 Git 제외 `SocialAuth.xcconfig`를 사용자 승인 후 복사(URL scheme과 공개 ID 일치 확인). `flutter build ipa --release --no-pub -t lib/main.dart --build-name=0.3.0 --build-number=7`, 공개 소셜 Dart define 3개 | 161초 아카이브 성공, 0.3.0(7) 확인. IPA 내보내기는 `PLA Update available`, `No signing certificate "iOS Distribution" found`로 실패. 빌드 6의 ExportOptions(`app-store-connect`, automatic)로 `xcodebuild -exportArchive -allowProvisioningUpdates` 재시도도 같은 오류(exit 70). 계정 소유자의 계약 수락 후 같은 아카이브로 내보내기 재시도 |
| 2026-11-01 | 배포 보류 | 계정 소유자의 Apple 계약 수락을 바로 진행할 수 없어 사용자가 배포를 미루기로 결정 | iOS 아카이브·Android AAB는 후보 폴더에 보존. 재개 시 소스·빌드 번호·산출물을 바꾸지 않고 iOS는 같은 아카이브로 내보내기부터 재개. 소스를 바꾸면 새 빌드 번호로 새 후보 사용 |
