# Android 백업·기기 이전에서 로그인 세션 제외 (#363)

2026-11-14, 브랜치 `fix/android-backup-session`. 시작 커밋 `3d1e2dd`, 구현 커밋 `e3c41db`(전체 검증 기준). 이 기록을 더한 커밋은 문서만 바꾸며 제품 코드는 `e3c41db`와 같다.
팀원 보안 점검 ⑧(로그인 세션이 Android 앱 데이터 백업·기기 이전에 실림)을 다룬다.

## 문제

- 로그인 세션(접근·갱신 토큰)은 `SharedPreferences`의 `FlutterSharedPreferences.xml`에 있다. 매니페스트에 백업 설정이 없어 Android 기본값대로 이 파일이 클라우드 백업과 기기 간 이전에 실렸다.

## 사용자 결정

- 2026-11-14 "추천대로 해줘": Android 백업·기기 이전에서 로그인 세션을 뺀다. 같은 파일의 탈퇴 정리 기록이 함께 빠지는 영향을 확인한다. Keychain·Keystore 이전(B안)과 iOS는 범위 밖이다.
- 2026-11-14 "추천대로": 게스트가 기기를 옮기면 이전 게스트 콘텐츠를 잃는 것과 최근 검색어가 옮겨지지 않는 것을 받아들인다. 세션 파일만 빼고 앱 데이터 백업 전체를 끄지 않는다.

## 구현

- `AndroidManifest.xml`의 `<application>`에 `android:dataExtractionRules`(Android 12 이상)와 `android:fullBackupContent`(Android 11 이하)를 더했다. `allowBackup`은 기본값(true) 그대로다.
- `res/xml/data_extraction_rules.xml`은 `cloud-backup`·`device-transfer` 모두, `res/xml/backup_rules.xml`은 `full-backup-content`에서 `sharedpref`의 `FlutterSharedPreferences.xml`만 뺀다. `include`가 없어 다른 앱 데이터는 지금처럼 백업된다.
- 같은 파일의 Apple 사용자 ID·최근 검색어·탈퇴 정리 기록도 함께 빠진다. 탈퇴 정리 기록만 빠지고 세션이 남는 경우는 없다(같은 파일). Dart·iOS·서버는 바꾸지 않았고 새 자동 테스트도 만들지 않았다(이슈 Testing Decisions).
- 문서: [동작 기준](../frontend/behavior.md#갱신-토큰-저장), [프론트 README](../../frontend/README.md), `CHANGELOG.md` 미배포.

## 실측

환경: Android Emulator `Medium_Phone`(Android 16 / API 36, google_apis arm64, Play 스토어 없음). 로컬 대역 `frontend/tool/share_fixture_server.py`와 가짜 게스트 토큰을 썼고 운영 서버에는 요청하지 않았다. 시험은 Android 공식 [Test backup and restore](https://developer.android.com/identity/data/testingbackup)의 클라우드 백업 스크립트(LocalTransport, `is_encrypted=true`)와 기기 간 이전 스크립트(GMS `D2dTransport` 시험 모드)를 adb 경로만 바꿔 썼다. 둘 다 백업 → 앱 삭제 → 재설치(복원) 순서이며 설정 파일을 직접 복사하지 않았다. 판정은 복원 직후 앱 데이터의 `shared_prefs` 파일·키 이름(값은 기록하지 않음)과 앱 실행 뒤 첫 화면이다.

| 경우 | 변경 전 (`3d1e2dd`) | 변경 후 (`e3c41db`) |
| --- | --- | --- |
| 클라우드 백업 → 재설치 복원 | 세션이 복원돼 홈(로그인 상태) | 세션 파일 없음 → 로그인·게스트 선택 화면 |
| 기기 간 이전(D2D 시험 모드) | 세션이 복원돼 홈 | 세션 파일 없음 → 로그인·게스트 선택 화면 |
| 같은 기기 제자리 업데이트(`adb install -r`, 변경 전 → 변경 후) | — | 세션 유지 → 홈. 설치본 SHA-256이 변경 후 APK와 같음 |
| 공유하기 링크 1개·이미지 1개 | 저장 요청 2건 성공, 송신 앱 복귀 | 같음 |

- 변경 전 결과는 이슈의 "지금" 열 가정과 같았다.
- 변경 후 두 복원 경로에는 백업 대상 폴더에 대조 파일(`files/backup_probe.txt`)을 함께 넣었고 복원됐다. 복원 자체가 일어나지 않아 세션이 없는 경우와 구분된다.
- 변경 후 APK에만 두 속성이 들어간 것을 `aapt2`로 확인했다.
- 변경 후 D2D 스크립트 마지막 정리 단계의 `bmgr init`이 `-1000`을 냈다(변경 전 0). 백업 성공과 대조 파일 복원 뒤의 정리 단계라 결과 판정과 무관하다.
- 복원 뒤 첫 화면 비교(로컬 증거, 저장소에 넣지 않음): `.utmp/ticket-363/compare-cloud-restore.png`, `compare-d2d-restore.png`. 기존 화면이라 Figma 비교는 해당 없다. iOS는 바뀌지 않아 촬영하지 않았다.

### 시험 방법의 대체와 한계

- **profile APK로 실측.** 최초 작업 중 관찰(원 로그 없음): 변경 전 debug APK로 클라우드 백업을 돌리자 `Size quota exceeded`가 났고, logcat에 Flutter debug 자원(`kernel_blob.bin` 약 76MB)이 백업 대상으로 잡혔다. 이 출력은 같은 이름의 로그를 다음 실행이 덮어써 남지 않았고 다시 실험하지 않았다. 그래서 release와 같은 AOT인 profile APK로 변경 전·후를 실측했다. release 서명 APK는 실측하지 않았다.
- **임시 cleartext 허용.** 로컬 HTTP 대역에 붙도록 profile 빌드 동안만 `src/profile/AndroidManifest.xml`에 debug 매니페스트와 같은 `usesCleartextTraffic=true`를 넣고 되돌렸다. 변경 전 빌드는 APK는 만들었지만 되돌리기 스크립트가 경로 오류로 실패해 수동으로 되돌렸고, 그 뒤 `git status`가 비어 있음을 확인했다(별도 로그 없음). 고친 스크립트로 한 변경 후 빌드는 되돌리기와 `git diff --exit-code` 통과를 남겼다. 이 설정은 커밋에 없다.
- **업데이트 확인 명령 교체(감독 승인).** 이슈의 `flutter install`(덮어쓰기)은 이 Flutter에서 "Uninstalling old version..." 뒤 설치해 데이터가 지워졌다(변경과 무관). 같은 기기 제자리 업데이트는 `adb install -r`로 확인했다. Play 업데이트 실측은 아니다.
- **미실측: Android 11 이하.** API 30 이하 AVD가 없어 `backup_rules.xml` 경로는 파일 내용만 확인했다.
- **미실측: 실제 소셜 인증.** 소셜 계정 재로그인 뒤 서버 콘텐츠 복원과 카카오 SDK 토큰의 실제 동작은 확인하지 않았다. 게스트 대역 세션만 썼다.
- **범위 밖: 운영·실기기.** 실제 Google 백업, 서로 다른 실기기 간 이전, 운영 서버는 확인하지 않았다(실기기 Android 없음).

## 검증

- 부분 검사(로컬 `.utmp/ticket-363/partial-*.log`, 저장소에 넣지 않음): 변경 후 `flutter build apk --debug` 성공, `git diff --stat main -- backend` 비어 있음, `check-changelog` 통과.
- 전체 검증(`e3c41db`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트 3621건 통과. 백엔드 pytest 2656 passed, 49 skipped. skip은 `tests/deployment` 48건(`RUN_DOCKER_RECOVERY_TESTS=1`과 라벨 붙은 로컬 이미지 필요 외 6종, CI에서만 실행)과 `tests/integration` 1건(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT` 필요)이다. 백엔드는 이번에 바꾸지 않았다.
- 원격 CI는 push 전이라 미실행이다.

## 검토

검수(Codex, `.utmp/review-363.md`, `3d1e2dd...e3c41db`): Standards 0개, Spec 0개. 검수는 남은 실측 로그와 비교 이미지를 대조했고 기기를 다시 돌리지 않았다. 지적에 따라 debug 한도 초과를 보존된 증거가 아닌 작업 중 관찰로, profile 매니페스트 되돌리기의 변경 전 실패와 변경 후 성공을 나눠 적었다.

## 후속 결정

- **카카오 SDK 토큰은 이번 규칙에서 빠지지 않는다.** `kakao_flutter_sdk_auth` 2.0.1은 토큰을 `SharedPreferencesAsync`(DataStore, 세션과 다른 파일)에 암호화해 저장한다. 암호 키는 `ANDROID_ID`에서 만들어 다른 기기에서는 복호화에 실패해 SDK가 지우지만, 같은 기기 복원에서는 남을 수 있다(코드 근거, 실제 카카오 로그인으로 확인 안 함). 앱이 이 토큰으로 허투루 세션을 자동 복원하는 곳은 확인되지 않았다. 파일 하나만 뺀다는 결정 밖이라 추가로 빼지 않았다. 모든 공급자 토큰이 백업에서 빠진 것은 아니다.
- 조건부 확인 항목(확신 낮음): SDK v1에서 올라온 설치본이면 SDK가 legacy prefs 전체를 DataStore로 옮겨 세션 복제본이 규칙 밖에 남을 수 있다. 허투루는 소셜 로그인 도입 때부터 2.0.1이라 이번에 다루지 않았다.
