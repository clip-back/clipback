# iOS 식별자와 서명 설정

- 최초 기록일: 2026-10-12
- 영역: iOS
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-5b812ead9e8461e8"></a>

### 2026-10-12 — iOS 앱 식별자·서명 팀 정리

<a id="b-732e6e57a3290805"></a>

- 사용자가 변경한 iOS 설정을 `chore/ios-app-signing` 브랜치로 분리했다. Runner의
  Debug·Profile·Release에서 Bundle ID는 `com.clipback.app` → `com.huturu.app`,
  서명 Team은 `BNTT9T6W95` → `8X6N747PQM`으로 바뀐다. `Info.plist`의
  `CFBundleVersion`은 항목 위치만 이동했으며 파싱한 전체 설정값은 기존과 동일하다.
- 프론트 README의 실행·소셜 설정 안내를 새 식별자와 팀에 맞췄다. 백엔드 README와
  `.env.example` 주석에는 Apple의 `APPLE_CLIENT_ID`가 새 Bundle ID와 일치해야 함을 기록했다.
  실제 환경변수 값·서비스 코드·토큰 암호화 키·API 계약·의존성·DB/migration은 변경하지 않았다.
- 실제 로그인 전 Google iOS OAuth client·URL scheme, 카카오 iOS 플랫폼 등록,
  Apple App ID·팀/키·프로비저닝과 배포 서버 설정을 각각 확인해야 한다. 저장소 변경으로
  외부 설정이 자동 반영되지는 않으며, Apple의 단일 audience를 바꾸면 이전 Bundle ID용
  토큰을 계속 허용하지 않는 점을 백엔드 문서에 명시했다.
- 이번 작업에서 `flutter analyze --no-pub` **문제 없음**(2.9초), `flutter test --no-pub`
  **497 passed**(45초)를 확인했다. 기존 테스트와 assertion을 변경하지 않았다.
- `flutter build ios --debug --no-codesign --no-pub` **성공**(Xcode 빌드 39.9초).
  생성된 `Runner.app/Info.plist`의 Bundle ID가 `com.huturu.app`임을 확인했다.
  기기용 컴파일 결과이며 코드 서명·프로비저닝이나 실제 기기 설치 성공을 뜻하지 않는다.
- `plutil -lint`로 프로젝트·Info.plist·entitlements를 검증했고, 세 빌드 구성의 Team/Bundle ID,
  `.env.example`의 기존 설정값 보존, 사용자 iOS 변경 원문의 보존을 확인했다.
  문서 갱신 후 `git diff --check`를 통과했다.
- 미검증: 실제 iPhone 설치·실행·사진 업로드, 공급자 콘솔·실제 OAuth, TestFlight·운영 배포.
  백엔드는 문서·예제 주석만 바뀌므로 Python·DB 테스트를 실행하지 않았다.
  `AGENTS.md`는 계속 Git 추적에서 제외하고 빌드 생성물·로컬 인증 설정은 커밋하지 않는다.
