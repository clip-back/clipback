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

## iOS 시뮬레이터 확인 (완료 조건 3)

로컬 대역 검증이며 운영 서버는 쓰지 않았다. 감독이 변경 전 `dd2b019`와 변경 후 `70dbc2a`(코드는 `80485f5`와 같음)를 같은 조건·순서로 촬영했다.

- 기기: iPhone 16 / iOS 18.6 Simulator(같은 기기), 글자 배율 OS 기본.
- 빌드: `frontend/`에서 `flutter build ios --simulator --debug --no-pub --dart-define=CLIPBACK_API_BASE_URL=http://127.0.0.1:18765/api/v1 -t test/support/share_preview.dart`.
- 대역: `frontend/tool/share_fixture_server.py` 127.0.0.1:18765를 새로 띄운 상태.

| 단계 | 변경 전 | 변경 후 |
|---|---|---|
| 홈 화면 아이콘 이름 | 허투루 | 허투루 |
| 앱 실행(세로) | 정상 표시 | 변경 전과 같음 |
| 기기를 가로(landscape_left)로 돌림 | 가로로 회전(2556×1179) | **세로 유지(1179×2556)** |
| 저장 화면 → 사진 첨부 → PHPicker → 사진 1장 선택 | 카메라·위치 권한 창 없음 | 변경 전과 같음 |
| 허투루에 저장하기 | 대역 저장 요청 1건 도달(saved 0→1), 앱은 "저장 결과를 확인하지 못했어요" 알림 | 변경 전과 같음 |
| 공유 확장 링크 1건(`testExternalLinkSaveReturnsToSenderWithoutMainApp` 단독) | TEST SUCCEEDED, 대역 saved 1→2 | TEST SUCCEEDED, 대역 saved 1→2 |

- 공유 확장은 [iOS 공유 검증 안내](../../frontend/ios/ShareVerification/README.md)의 UI 테스트로 실행했고, 공유 시트·저장 완료 토스트·보내는 앱 복귀 화면을 남겼다.
- "저장 결과를 확인하지 못했어요"는 대역의 업로드 응답 형식 한계이며 이번 변경과 무관하다(Dart 코드 변경 없음, 전·후 같음). 그래서 사진 저장 뒤 앱 화면의 저장 완료 표시는 시뮬레이터에서 확인하지 못했고 0.6.2 실기기 확인 항목에 남긴다.
- 홈 상단 "공유한 항목의 최신 정보…"·하단 "이번주 추천…" 오류 알림 2개는 대역에 없는 API 때문이며 전·후 같게 보였다.
- 화면 방향 외 화면 구성 변경이 없어 Figma 비교는 하지 않았다(이슈 결정).

촬영 기록·스크린샷·영상은 작업 디렉터리의 `.utmp/ticket-406/before/`, `.utmp/ticket-406/after/`(공유 확장 영상 `b09-share-video.mp4`·`a09-share-video.mp4`), 비교 이미지는 `.utmp/ticket-406/compare/compare-ios-{1,2,3}.png`에 보존했다.

## 전체 검증

커밋 `80485f5`에서 실행:

```text
VERIFY result=PASS scope=all checks=12 failed=0
```

- 백엔드 pytest: 2743 passed, 49 skipped, 3 warnings. skip은 `tests/deployment` 48개(Docker 복구 테스트 미설정), `tests/integration` 1개(`CLIPBACK_IMAGE_TEST_S3_ENDPOINT` 미설정).
- 앱 테스트: +3766 All tests passed.
