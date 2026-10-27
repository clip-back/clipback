# iOS 0.2.0 빌드 6 TestFlight 업로드

## 요청과 산출물

- 사용자가 iOS `0.2.0 (6)`의 TestFlight 업로드를 승인했다. App Store 정식 출시는 제외했다.
- [로컬 빌드 검증](2026-10-27-ios-b6-build.md)에서 생성한 `Runner.xcarchive`를 사용했다.
- 고정 소스: `a3972f9118ad1ffa8863d2e2ba64415a064063ee`. 새 빌드·앱 소스 수정 없음.
- 업로드 전 기존 로컬 IPA SHA-256이 빌드 기록과 일치함을 확인했다.
  Xcode가 같은 아카이브를 업로드용으로 다시 패키징했으므로 기존 로컬 IPA 해시를 서버 수신 파일의 해시로 주장하지 않는다.
- 대상: 허투루, App Store Connect 앱 ID `6821850037`, bundle ID `com.huturu.app`.

## 업로드 실행

Xcode의 기존 인증으로 `xcodebuild -exportArchive -archivePath <검증한 아카이브>
-exportOptionsPlist <업로드 설정> -exportPath <로컬 결과 폴더> -allowProvisioningUpdates`를 실행했다.

설정은 `method=app-store-connect`, `destination=upload`, `signingStyle=automatic`,
`manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`다. 버전·빌드 번호를 자동 증가시키지 않았다.
App Store 버전 연결·심사 제출·출시 명령은 실행하지 않았다.

| 시각 (KST) | 단계 | 실제 확인 결과 |
| --- | --- | --- |
| 2026-10-27 22:52 | Xcode 제출 시작 | 기존 아카이브로 업로드 준비 |
| 2026-10-27 22:54:09 | 업로드 완료 | `Upload succeeded`, `Uploaded Runner`, `EXPORT SUCCEEDED`, exit 0 |
| 2026-10-27 22:54 이후 | App Store Connect 목록 | `0.2.0 (6)`, 생성 시각 Oct 27, 2026 10:54 PM, `처리 중` 확인 |
| 2026-10-27 22:58 | Apple 처리 결과 | 업로드 목록 `완료`, 버전 0.2.0의 빌드 6 등록. 빌드 상태는 `수출 규정 관련 문서 누락` |

Chrome 연결이 제공되지 않아 앱 내 브라우저를 사용했다. 사용자가 직접 로그인·이중 인증을 완료했다.
인증값·개인 계정 정보는 기록하지 않는다. Xcode 초기 로그에 일부 계정의 자격 증명 경고가 있었지만
실제 업로드는 성공했으며 계정 설정·인증서를 임의로 삭제하거나 변경하지 않았다.

## 처리·테스트·공개 상태

- Apple 처리: 완료. 업로드 목록의 `완료`와 빌드 6 상세 링크를 확인했다.
- TestFlight 사용 가능 여부: `수출 규정 관련 문서 누락`. 암호화 관련 답변·문서 제출은 수행하지 않았다.
  처리 완료는 테스터에게 제공 가능하거나 설치가 검증됐다는 의미가 아니다.
- 테스트 그룹 배정·설치: 이번 요청은 업로드이며 별도 조작하지 않음.
- App Store 심사·정식 출시: 미실행.
- 실제 OAuth·실기기 및 기본 앱 아이콘 등 남은 확인은 [빌드 검증 기록](2026-10-27-ios-b6-build.md)을 따른다.
- [TestFlight 목록](https://appstoreconnect.apple.com/apps/6821850037/testflight/ios).
- [등록된 빌드 6](https://appstoreconnect.apple.com/teams/4063cb1a-d70f-484e-94be-c4f51537a01c/apps/6821850037/testflight/ios/6e42f5f9-ca48-4978-b023-204cf2955e45).
- 화면 증거: 로컬 `frontend/build/release-candidates/app-v0.2.0-ios-b6/evidence/testflight-build6.jpg`.
  계정 정보를 제외한 빌드 목록 영역을 캡처했으며 Git에는 포함하지 않는다.
