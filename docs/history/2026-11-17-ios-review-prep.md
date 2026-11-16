# iOS App Store 심사 준비 — 앱 privacy manifest·수출 규정 키·번들 이름·iPhone 세로 전용 (#406)

2026-11-17 기록. [이슈 #406](https://github.com/clip-back/clipback/issues/406)의 구현 커밋 `80485f5`(시작 `dd2b019`) 결과다.
App Store Connect 업로드·심사 결과와 실기기 확인은 포함하지 않는다.

## 변경과 결정

- 앱(Runner) 타깃에 [privacy manifest](../../frontend/ios/Runner/PrivacyInfo.xcprivacy)를 리소스로 넣었다.
  `NSPrivacyTracking` false, 추적 도메인 없음, FileTimestamp `3B52.1`, 수집 유형 7종(Name·EmailAddress·UserID·PhotosorVideos·OtherUserContent·SearchHistory는 AppFunctionality, ProductInteraction은 ProductPersonalization·Analytics)이며 모두 Linked true·Tracking false다.
  `file_picker` 8.3.7이 가져오는 `DKImagePickerController`·`DKPhotoGallery`의 manifest가 빌드 결과에 빠져 있어, 앱 실행 파일에 정적으로 연결되는 두 라이브러리의 선언을 앱 manifest에 함께 적었다(D1).
- 앱 `Info.plist`: `CFBundleName` `clipback_frontend`→`허투루`(D4), `ITSAppUsesNonExemptEncryption` false(D3), 화면 방향 세로만·`UISupportedInterfaceOrientations~ipad` 삭제(D6). 손으로 고쳐 기존 키 순서를 지켰다.
- 프로젝트·공유 확장의 `TARGETED_DEVICE_FAMILY`를 6개 구성 모두 `1`(iPhone만)로 바꿨다(D5).
- 카메라·위치·사진 사용 문구, 공유 확장 Info.plist·entitlements, `file_picker` 버전, Dart 코드는 바꾸지 않았다(D2).
- 설명은 [개발 안내의 TestFlight 절](../frontend/development.md#testflight-권한-설명과-재업로드)과 CHANGELOG `미배포`에 더했다.

D3 확인 출처: 사용자가 App Store Connect 0.6.1(15) 빌드 일반 정보(업로드 2026-11-15)에서 확인한 답 **"앱의 비면제 암호화 포함 아니요"**를 2026-11-17 조율이 전했다. 이 확인 뒤에 키를 넣었다.

## 검수

검수 지적 0건(Standards 0, Spec 0)이라 반영한 변경이 없다.

0.6.1(15) 아카이브의 기존 manifest 목록 파일에는 `Runner.app | 있음 | UserDefaults` 줄이 있었다. 실제 아카이브 `Runner.app` 루트에는 `PrivacyInfo.xcprivacy`가 없음을 작업자와 검수가 각각 직접 확인했다. 이 줄은 하위 번들의 파일을 잡은 목록 결과로 보고 루트 존재 근거로 쓰지 않았다.
검수는 두 앱의 모든 manifest 상대 경로와 파싱 내용을 재귀 대조했으며, 새 루트 파일을 뺀 19개 SDK manifest가 모두 같았다.

## 확인 결과

| 완료 조건 | 결과 |
|---|---|
| 1. `plutil -lint` | 앱 Info.plist, 공유 확장 Info.plist, `PrivacyInfo.xcprivacy` 모두 OK |
| 2. `flutter build ios --release --no-codesign` | 성공(Runner.app 48.5MB). 빌드에 따른 `project.pbxproj`·`Generated.xcconfig` 등 부수 변경 없음 |
| 2. 산출물 Runner.app | 루트 manifest가 소스와 같고 위 내용과 일치. `CFBundleName`·`CFBundleDisplayName` 허투루, `ITSAppUsesNonExemptEncryption` false, `UIDeviceFamily` [1], 방향 세로만, `~ipad` 키 없음, 카메라·위치·사진 문구 3개 그대로 |
| 2. 공유 확장 | `UIDeviceFamily` [1], `ITSAppUsesNonExemptEncryption` 없음 |
| 2. SDK manifest 목록 | 0.6.1(15)과 비교해 앱 루트 manifest 한 줄만 차이 (`DKImagePickerController`·`DKPhotoGallery`·`objective_c`·`App`·공유 확장은 전과 같이 없음) |

원 명령·출력은 작업 디렉터리의 `.utmp/ticket-406/partial-plutil-lint/`, `partial-build-ios-release/`, `partial-app-bundle-check/`, 검수 대조는 `.utmp/review-406-checks/run.log`에 보존했다.

- Android: 바뀐 파일이 없어 에뮬레이터를 실행하지 않았다.
- 새 자동 테스트는 만들지 않았다(이슈 결정, 자동 테스트로 잴 동작 변경 없음).
- 실기기(iPhone 13, TestFlight 0.6.2)의 이름·세로 고정·사진 저장·공유 확장 저장, App Store Connect의 수출 규정 질문 없음·ITMS 경고 메일 없음은 0.6.2 배포 뒤 확인 예정이다.

## 전체 검증

커밋 `80485f5`에서 실행:

```text
VERIFY result=PASS scope=all checks=12 failed=0
```

- 백엔드 pytest: 2743 passed, 49 skipped, 3 warnings. skip은 `tests/deployment` 48개(Docker 복구 테스트 미설정), `tests/integration` 1개(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT` 미설정).
- 앱 테스트: +3766 All tests passed.
