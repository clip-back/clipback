# 마이 앱 버전 표시 구현·검증

최초 기록일: 2026-10-30 KST. 시작 소스는 `f16a50e`, 통합 브랜치는 `fix/app-version-display`이다.
실행 기준은 [명세 #117](https://github.com/clip-back/clipback/issues/117)과 티켓
[#118](https://github.com/clip-back/clipback/issues/118)·[#119](https://github.com/clip-back/clipback/issues/119)이다.
현재 동작 기준은 [Figma 화면 맞춤 계획](../figma-ui-alignment-plan.md#figma-current-16)을 따른다.

## 진행 범위

| 티켓 | 이번 진행 | 남은 완료 조건 |
| --- | --- | --- |
| [#118](https://github.com/clip-back/clipback/issues/118) | `65d3a53`: 앱 시작 시 `package_info_plus`로 앱 정보를 한 번 읽어 앱 루트에 주입하고, 마이 "앱 버전" 줄에 `ver. {앱 버전}`·정보 없음 `-` 표시. 사용자 정보 모델·서버 매핑에서 앱 버전 제거 | 없음 ([2026-10-31 Figma 비교](#figma-기준-화면-비교-2026-10-31)) |
| [#119](https://github.com/clip-back/clipback/issues/119) | `0d834ca`: 앱 버전 시트 "현재 버전"에 `ver. {앱 버전} ({빌드 번호})`·정보 없음 `-` 표시, "업데이트" 줄 숨김과 [디자인 확인 필요](../figma-ui-alignment-plan.md#figma-pending-app-version) 기록 | 없음 ([2026-10-31 Figma 기준 화면 없음 확인](#figma-기준-화면-비교-2026-10-31)) |

리뷰 지적에 따라 사용자 정보(`/api/v1/users/me`) 대기·503 상태의 앱 루트 테스트, 변경 이력, 이 기록을 보완했다.
저장소 기본 버전 `0.1.0+1`은 바꾸지 않았다.

## 자동 검사

- 2026-10-30 통합 브랜치 `0d834ca`: `(cd frontend && flutter analyze --no-pub)` 문제 없음,
  `(cd frontend && flutter test --no-pub)` 1999개 통과, `git diff --check f16a50e` 통과.
- 2026-10-31 리뷰 보완 후: `(cd frontend && flutter analyze --no-pub)` 문제 없음,
  `(cd frontend && flutter test --no-pub)` 2000개 통과, `git diff --check` 통과.
- 앱 루트 테스트는 `frontend/test/app_version_display_test.dart`에 있다.
  - 마이 줄의 `ver. 0.2.0`, 정보 없음 `-`, 고정값 `ver. 1.1` 부재
  - 계정 전환(회원 → 로그아웃 → 게스트) 후 같은 앱 버전. 소개·관심사 화면은 `onDone` 콜백으로 넘긴다.
  - 마이 통계 503에서 같은 앱 버전
  - 사용자 정보 응답 대기 중(`계정 정보 확인 중`)과 이후 503에서 마이 화면을 유지하고 같은 앱 버전·시트 `ver. 0.2.0 (6)` 표시.
    마이 줄이 사용자 정보에 의존하도록 일부러 바꾸면 이 테스트가 실패함을 확인한 뒤 원래 코드로 되돌렸다.
  - 시트의 `ver. 0.2.0 (6)`, "업데이트"·"최신 버전입니다" 부재, 정보 없음 `-`

## 시뮬레이터·에뮬레이터 실행 (2026-10-30)

- 환경: iPhone 16 Pro / iOS 18.6 Simulator, Android Emulator `Medium_Phone`(sdk_gphone64_arm64) / Android 16 / 1080×2400.
- 서버: 로컬 Docker PostgreSQL과 로컬 `uvicorn`. 실행 시 `YOUTUBE_SUMMARY_ENABLED=false` 환경변수만 지정했다.
  운영 서버·실제 OAuth·실기기·원격 CI는 사용하지 않았다.
- 실행 방법: 제품 진입점 `lib/main.dart`를 그대로 호출하고 사람의 탭 순서(권한 안내 → 소개 → 관심사 1개 →
  게스트 시작 → 마이 → 맨 아래 스크롤 → "앱 버전")만 프로그램 입력으로 대신하는 저장소 밖 임시 드라이버를 사용했다.
  이 Mac에 Simulator 화면 앱이 없어 iOS에서 직접 탭할 수 없었다. 드라이버는 커밋하지 않았다.
- 조건: 매 실행 전 앱을 지워 새 게스트(저장 0·다시 본 0), 글자 배율 1, 플랫폼별 같은 기종·스크롤 위치.
- 변경 전은 `f16a50e`를 `flutter run` debug로, 변경 후는 `0d834ca`를 빌드 인자로 빌드·설치했다.
  - iOS: `--build-name=0.2.0 --build-number=6`, Info.plist `0.2.0`/`6` 확인
  - Android: `--build-name=0.2.0 --build-number=2`, versionName `0.2.0`/versionCode `2` 확인

| 플랫폼 | 마이 "앱 버전" 줄 (전 → 후) | 시트 "현재 버전" (전 → 후) | 시트 "업데이트" 줄 (전 → 후) |
| --- | --- | --- | --- |
| iOS | `ver. 1.1` → `ver. 0.2.0` | `ver. 1.1` → `ver. 0.2.0 (6)` | 최신 버전입니다 → 없음 |
| Android | `ver. 1.1` → `ver. 0.2.0` | `ver. 1.1` → `ver. 0.2.0 (2)` | 최신 버전입니다 → 없음 |

- 줄 배치·글자 스타일은 변경 전과 같고, 시트는 업데이트 줄이 빠진 만큼 낮아졌다.
- Android 변경 후 촬영 중 에뮬레이터 런처·시스템 UI의 "응답 없음" 창이 두 번 화면을 가렸다.
  재부팅 후 촬영 직전에 그 창이 있을 때만 "Wait"으로 닫고 다시 찍었으며 앱 화면은 보정하지 않았다.
- 스크린샷은 작업 폴더의 Git 추적 밖 `.herdr/app-version/screens/`에 보관했다(전후 원본 8장, 플랫폼별 비교 2장).
  새 checkout에는 포함되지 않는다.

## Figma 기준 화면 미확보

- AGENTS.md의 변경 전·후·Figma 3개 비교 중 Figma 기준 화면은 확보하지 못했다.
- 이유: Figma 연결(MCP)이 인증되지 않았고 로컬에 내보낸 Figma 이미지도 없었다. 대체 화면은 만들지 않았다.
- 기준 노드: 마이 J01 `111:4707`(Page 1 > `261007`). 앱 버전 시트 전용 노드는 문서에서 찾지 못했다.
- 남은 일: Figma 인증 후 기준 노드·조회 시점과 플랫폼별 3개 비교를 추가한다.

## Figma 기준 화면 비교 (2026-10-31)

- 2026-10-31 KST Figma 연결(MCP)을 인증하고 파일 `svNWsTFh8Ws1Mpt8XQIcrN`을 조회했다.
- 마이 "앱 버전" 줄: J01 `111:4707`을 375×842 원본 크기로 내보내, 2026-10-30에 찍은 변경 전·후 화면과
  플랫폼별로 나란히 비교했다. 기기 화면은 다시 촬영하지 않았다.
  - Figma는 `ver. 1.1` 두 자리 고정값이고 변경 후는 `ver. 0.2.0`이다.
    명세 #117대로 실제 값을 세 자리로 표시하는 것이며 디자인 변경으로 보지 않는다.
  - 줄 위치(고객지원 묶음 마지막 줄)와 오른쪽 정렬 회색 값 표시는 Figma와 같다.
  - 계정 카드·통계 값, 관리 항목(리마인드 설정·카테고리 관리), "이용약관 및 개인정보" 줄의 차이는
    게스트 데이터와 [현재 기준](../figma-ui-alignment-plan.md#figma-current-16)의 기존 결정 때문이며 이번 변경과 무관하다.
  - Figma는 iOS 프레임(375 기준, 상태 표시줄 포함)이라 Android 상태 표시줄·안전 영역과 다르다. 원본 화면은 보정하지 않았다.
- 앱 버전 시트: Figma 파일의 세 페이지(Page 1, 출시 준비 — 누락 UI 와이어프레임, 스토어 등록 이미지)에서
  "앱 버전"·"현재 버전"·"최신 버전입니다"를 찾았으나 시트 디자인은 없었다.
  "앱 버전" 문구는 J01의 줄(`111:4762`)에만 있다. 시트는 Figma 기준 화면이 없으므로 비교하지 않았고 대체 화면을 만들지 않았다.
  출시 준비 페이지의 필수 업데이트 화면(`89:3555`, `120:4942`)은 다른 기능이라 기준으로 쓰지 않았다.
- 비교 이미지는 Git 추적 밖 `.herdr/app-version/screens/`에 추가했다
  (`figma-J01-111-4707.png`, `ios-my-figma-comparison.png`, `android-my-figma-comparison.png`).

## 한계와 미검증

- 기기에서 정보 없음(`-`), 계정 전환, 사용자 정보 대기·실패는 실행하지 않았고 자동 테스트로만 확인했다.
- 플랫폼이 빈 앱 버전 문자열을 돌려주면 `ver. `로 표시되며 정보 없음으로 처리하지 않는다.
- 최신 버전 확인·업데이트 안내는 명세 범위 밖이며 [디자인 확인 필요](../figma-ui-alignment-plan.md#figma-pending-app-version)로 남겼다.
