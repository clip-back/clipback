# app-v0.3.0-ios-b8-android-b4

## 배포 개요

- 배포 식별자: app-v0.3.0-ios-b8-android-b4
- 배포 담당자: 저장소 운영자
- 준비일: 2026-11-02T00:18:53+09:00 KST
- 포함한 [변경 이력](../../CHANGELOG.md)의 항목 또는 앵커: [앱] 앱 아이콘을 허투루 아이콘으로 교체 (CHANGELOG 앱 0.3.0 개선); [앱] 처리 중 문구를 ‘링크 정보를 처리 중이에요’로 변경 (CHANGELOG 앱 0.3.0 개선); [iOS] 공유 저장 시트와 저장 완료 안내 (CHANGELOG 앱 0.3.0 개선); [iOS] 공유 저장 실패 이유별 알림창 (CHANGELOG 앱 0.3.0 개선); [Android] 공유 저장 시트·완료 안내·실패 알림창 (CHANGELOG 앱 0.3.0 개선); [앱] 마이 화면 앱 버전을 설치된 앱 값으로 표시 (CHANGELOG 앱 0.3.0 수정)
- 관련 PR·작업 링크: [앱 아이콘 교체 #172](https://github.com/clip-back/clipback/pull/172)([작업 기록](../history/2026-11-01-app-icon.md)), [앱 버전 표시 #120](https://github.com/clip-back/clipback/pull/120), [인스타그램 자동 요약·처리 중 문구 #135](https://github.com/clip-back/clipback/pull/135), [다른 앱 공유 시트 #138](https://github.com/clip-back/clipback/pull/138)
- 앱 버전별 개요·이전 후보 링크: 개요 없음. 이전 후보 [iOS 0.3.0(7)·Android 0.3.0(3)](app-v0.3.0-ios-b7-android-b3.md)은 업로드하지 않고 이 후보로 대체
- 후보 준비 상태·미확인 사유: 후보 예약. 빌드·업로드·테스트 제공·실기기 확인 미실행

2026-11-02 사용자가 앱 아이콘 교체(#172)를 0.3.0에 포함하기로 해 빌드 소스를 `a70009c`에서 `835f915`로 바꿨습니다.
이전 후보의 보류 기록대로 소스를 바꿨으므로 새 빌드 번호로 새 후보를 만들었습니다. `a70009c..835f915`의 `frontend/` 변경 27개는
iOS·Android 앱 아이콘 리소스뿐이며 나머지 앱 변경 항목은 이전 후보와 같습니다.
iOS 0.2.0(6) 이후 처음 iOS에 배포하는 사진 원본 보존 수정(#116)과 인스타그램 링크 요약(서버 기능)에 대한 설명은 [이전 후보 기록](app-v0.3.0-ios-b7-android-b3.md#배포-개요)과 같습니다.

`미배포`의 `[서버]` 2개 항목(#134 자동 요약 예상 밖 오류의 즉시 실패, #169 정확한 `manifest.json` 키만 완료 지점으로 판단)은
Railway main 자동 배포로 운영에 반영됐지만, 이전 후보와 같은 기준으로 앱 후보에는 넣지 않았습니다. 서버 항목은 서버 배포 기록에서 다루며
이번 작업에서는 서버 기록을 만들지 않아 `미배포`에 남깁니다. #147·#156 PR 1은 동작 변화 없는 정리라 변경 이력 항목이 없습니다.

## 식별자 확인 근거

새 후보를 만들기 전에 기존 후보 기록·로컬 및 원격 태그·대상 플랫폼의 업로드 이력을 확인합니다.
출처에는 팀이 다시 확인할 수 있는 링크나 기록 식별자를 쓰며 자격 증명을 포함하지 않습니다.
원격 조회 실패와 로컬 자료만 확인한 상태를 전역 중복 없음으로 표시하지 않습니다.
스토어 최대 업로드 번호는 이전 후보 준비 때(2026-10-31 23:35 KST) 사용자가 확인한 값을 그대로 씁니다.
이전 후보의 iOS 7 아카이브와 Android 3 AAB는 어느 스토어에도 업로드하지 않았고(2026-11-01 배포 보류), 그 뒤 업로드도 없었다는 사용자 보고가 근거입니다.
iOS 7·Android 3은 이전 후보 기록에 예약된 번호이므로 재사용하지 않고 iOS 8·Android 4를 씁니다.

| 확인 범위 | 출처·확인 시점 (KST) | 결과·미확인 사유 |
| --- | --- | --- |
| 기존 후보 기록·로컬 태그 | 로컬 저장소 / 2026-11-02T00:18:53+09:00 KST | 충돌 없음 |
| 원격 태그 | origin / 2026-11-02T00:18:53+09:00 KST | ios: checked; android: checked |
| iOS 업로드 이력 | App Store Connect: 허투루 (Apple ID 6821850037, com.huturu.app), TestFlight 전체 빌드 업로드 목록 https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios — 사용자 확인 보고(app-v0.3.0-ios-b7-android-b3 기록값 재사용: 이후 iOS 7 포함 업로드 없음) / 2026-10-31T23:35:11+09:00 KST | 수동 확인값: 최대 업로드 빌드 6 |
| Android 업로드 이력 | Google Play Console: 허투루 (com.huturu.app), 앱 번들 탐색기 https://play.google.com/console/u/0/developers/5102284073432253588/app/4973475119660004180/releases/overview — 사용자 확인 보고(app-v0.3.0-ios-b7-android-b3 기록값 재사용: 이후 Android 3 포함 업로드 없음) / 2026-10-31T23:35:11+09:00 KST | 수동 확인값: 최대 업로드 빌드 2 |

## 모바일 플랫폼별 기록

서버 단독 배포이거나 특정 플랫폼이 대상이 아니면 해당 열을 `해당 없음`으로 표시합니다.
빌드·업로드·테스트 배포·심사·정식 공개를 각각 확인하고, 한 플랫폼의 성공을 다른 플랫폼에 복사하지 않습니다.
재업로드하면 최신 산출물로 표를 갱신하고 이전 시도의 값과 결과는 진행 기록에 보존합니다.

| 항목 | iOS | Android |
| --- | --- | --- |
| 배포 대상 여부 | 대상 | 대상 |
| 실제 앱 버전 | 0.3.0 | 0.3.0 |
| 실제 빌드 번호 | 8 | 4 |
| 빌드 소스 SHA | 835f915f61dcf34b9fbb977dcc3127cc679fe2f7 | 835f915f61dcf34b9fbb977dcc3127cc679fe2f7 |
| 후보 태그·실제 생성 여부 | app-ios-v0.3.0-b8 (미생성) | app-android-v0.3.0-b4 (미생성) |
| 최종 검증 빌드·정식 배포 대상 여부 | 미확인 | 미확인 |
| 빌드 결과·산출물 식별자 | 미확인 | 정상 Release AAB 성공. `frontend/build/release-candidates/app-v0.3.0-android-b4/app-release.aab`, 72,844,689바이트, SHA-256 `bc26edc53e4c0d2308878b166724ee5b407fa5cdd1dafee0a087941a5b2a4dd3`. 산출물의 versionName 0.3.0·versionCode 4 확인 |
| 업로드·처리 상태 | 미확인 | 미실행 — Play Console 업로드는 사용자가 진행 |
| 테스트 배포 상태·대상 트랙 또는 그룹 | 미확인 | 미확인 |
| 심사 상태 | 미확인 | 미확인 |
| 정식 공개 상태·공개 범위 | 미확인 | 미확인 |
| 실제 공개일·시각 | 미확인 | 미확인 |

## 서버와 마이그레이션

| 항목 | 기록 |
| --- | --- |
| 서버 배포 대상 여부 | 이번 앱 후보에서 신규 배포하지 않음 — main 자동 배포로 이미 운영 중 |
| 서버 소스 SHA·산출물 식별자 | 운영 중 835f915f61dcf34b9fbb977dcc3127cc679fe2f7 / Railway deployment `6ccf0414-eda9-4f07-987a-c457e097780a` |
| 서버 후보 태그·실제 생성 여부 | 해당 없음 — 앱 후보에서 서버 후보를 만들지 않음 |
| 배포 환경 | production |
| API 계약 버전 | /api/v1 |
| 마이그레이션 필요 여부·적용할 revision | 불필요 — `a70009c..835f915`에 migration 변경 없음. 기존 `202610310021`은 [backend-2026-10-31-1](backend-2026-10-31-1.md)에서 적용 |
| 앱·서버·마이그레이션 배포 순서와 선행 조건 | 서버는 앱 배포 전에 운영 반영 완료. 앱이 의존하는 서버 기능은 [backend-2026-10-31-1](backend-2026-10-31-1.md)과 같음 |
| 기존 앱과의 호환성 | `/api/v1` 유지. 이번 후보의 추가 변경은 앱 아이콘뿐이라 서버 호환성 영향 없음. 실제 구버전 연동 검증은 미실행 |
| 구버전 지원 종료 결정·긴급 예외 기록 | 해당 없음 |
| 실제 마이그레이션 실행 결과·근거 | 해당 없음(앱) |
| 실제 서버 배포 상태·시각·근거 | `railway deployment list --json` 조회(2026-11-02 00:18 KST): `835f915` SUCCESS(배포 생성 2026-11-02 00:15 KST, 이전 운영 `4b74132`는 2026-11-01 23:57 KST 배포 성공 후 교체). `/api/v1/health`·`/api/v1/health/ready` 200 |
| 복구 대상 SHA·산출물과 복구 시 주의 사항 | 앱: 이전 iOS 0.2.0(6)·Android 0.2.0(2) 산출물 보존. 스토어는 낮은 빌드 번호로 되돌릴 수 없으므로 수정 시 새 빌드 번호 사용. 서버 복구는 [Railway 배포·복구](../railway-deployment.md) 참조 |

## 검증 결과

실행한 항목은 명령·시나리오·결과·근거를 적습니다. 실행하지 않은 항목은 `미실행`과 이유를,
대상이 아닌 항목은 `해당 없음`을 적습니다. 화면·동작 증거와 CI 실행 링크도 해당 범위에 연결합니다.

| 검증 범위 | 명령·시나리오·기종·OS | 결과 | 근거 또는 미검증 사유 |
| --- | --- | --- | --- |
| 로컬 자동 검사·대역 데이터 | `frontend/`에서 `flutter analyze --no-pub`, `flutter test --no-pub -j 2` (2026-11-02 00:20~00:23 KST, Android 빌드 직전) | 통과 — 지적 0건, 2,018개 통과 | 빌드와 같은 작업 트리(`833e8b9`, `frontend/`는 `835f915`와 동일). 대역 데이터 검사이며 실제 공급자·운영 연동과 구분 |
| 산출물 정적 검사 | Android AAB: bundletool 1.18.3 `validate`·`dump manifest/config/resources`, `jarsigner -verify`, `keytool -printcert`, ELF 프로그램 헤더, 아이콘 PNG 픽셀 비교(Pillow 12.2.0) | 통과 | `com.huturu.app`·0.3.0(4)·minSdk 24·targetSdk 36·debuggable 없음·`android:icon="@mipmap/ic_launcher"`. 업로드 인증서 SHA-256 `b076988a…87e59ad0`(빌드 2·3과 같은 업로드 키). 아이콘: `mipmap-anydpi-v26/ic_launcher.xml`(적응형, 배경 `@color/ic_launcher_background`=`#ffd75c`, 전경 `@mipmap/ic_launcher_foreground`)과 5개 밀도의 `ic_launcher.png`·`ic_launcher_foreground.png` 포함. PNG 10개 모두 `835f915` 소스와 픽셀 일치, `ic_launcher.png` 5개는 `a70009c`의 이전 아이콘과 다름. arm64 Dart 바이너리에 운영 API·Google 웹 OAuth ID·카카오 Native key 포함, manifest에 카카오 콜백 scheme 포함(값은 기록하지 않음). ELF64 8개 모두 16KB 이상 정렬, ELF32 4개는 대상 아님, `PAGE_ALIGNMENT_16K` |
| 원격 CI | `835f915`의 Backend Validation | success | [run 41320300095](https://github.com/clip-back/clipback/actions/runs/41320300095). 프론트 검사를 포함하지 않으며 이번 후보 준비에서 새로 실행한 결과 아님 |
| iOS Simulator | 미실행 | 미실행 | 이번 배포 작업 지시: 메모리 8GB 제약으로 시뮬레이터를 띄우지 않음. 아이콘 교체의 시뮬레이터 확인은 [작업 기록](../history/2026-11-01-app-icon.md)에 있으며 이번 산출물 검증으로 쓰지 않음 |
| Android Emulator | 미실행 | 미실행 | iOS Simulator와 같은 이유로 에뮬레이터를 띄우지 않음 |
| 실제 OAuth·외부 공급자 | 미실행 | 미실행 | 실기기 Google·카카오·Apple 로그인과 인스타그램 링크 요약 결과를 사용자에게 받은 뒤 기록 |
| 운영 서버 | `railway deployment list --json`·`/api/v1/health`·`/api/v1/health/ready` (2026-11-02 00:18 KST) | SUCCESS·200·200 | 운영 `835f915`. 이 앱 후보와 운영 API의 연동 검증은 미실행 |
| 실기기 | 미실행 | 미실행 | 사용자가 스토어 업데이트 후 홈 화면 아이콘·공유 메뉴 아이콘·로그인·공유 저장 시트를 확인할 예정. 결과를 받기 전에는 완료로 적지 않음 |

## 진행 기록과 중단·복구

빌드·업로드·공개, 재업로드, 중단·롤백을 시간순으로 추가합니다. 같은 산출물의 재시도는 이 기록에 이어 적습니다.
소스를 수정한 새 후보는 새 파일로 만들고 이전 후보 링크를 남깁니다. 기존 실패·검증 결과를 새 후보의 성공으로 바꾸지 않습니다.
재업로드 시 플랫폼·버전·빌드 번호·SHA·산출물·처리 결과를 적고,
중단·롤백 시 사유·대상·복구할 SHA 또는 산출물과 실제 결과를 적습니다. 이전 기록은 삭제하지 않습니다.

| 시각 (KST) | 대상·단계 | 수행 내용·사유·산출물 또는 SHA | 결과·근거·후속 조치 |
| --- | --- | --- | --- |
| 2026-11-02 00:18 | 후보 예약 | main `835f915`(#172 앱 아이콘)를 배포 브랜치에 병합(`d0f28ff`) 후 이전 후보 기록의 스토어 최대 업로드(App Store Connect 6, Play 2)로 iOS 0.3.0(8)·Android 0.3.0(4) 예약. 소스 `835f915` | `prepare_release app` created=true, identifier_checks_complete=true(수동 확인값·원격 태그 범위). 태그 미생성, 빌드 미실행 |
| 2026-11-02 00:23 이전 | Android 서명 검증·로컬 검사 | 저장소 밖 값 파일에서 서명 설정·공개 SDK 설정을 불러옴(값 미출력). JDK 21.0.9로 `:app:validateReleaseSigning` → `flutter analyze`·`flutter test` | 서명 검증 BUILD SUCCESSFUL, analyze 0건, 테스트 2,018개 통과 |
| 2026-11-02 00:23 | Android 정상 빌드 | `flutter build appbundle --release --no-pub -t lib/main.dart --build-name=0.3.0 --build-number=4`, 운영 API·공개 SDK 설정 지정. 작업 트리 HEAD `833e8b9`는 `835f915`에 병합·문서 커밋만 더한 상태로 `frontend/` 차이 없음 | 약 46초 빌드 성공. 산출물을 후보 폴더로 복사하고 해시·서명·manifest·아이콘·16KB 정렬 검사 통과. 업로드 미실행 |
