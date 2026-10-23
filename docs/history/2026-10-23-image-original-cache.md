# 계정별 원본 이미지 기기 캐시

## 범위와 기준

- 최초 기록: 2026-10-23. 명세 [#64](https://github.com/clip-back/clipback/issues/64)의 하위 이슈 [#68](https://github.com/clip-back/clipback/issues/68).
- 브랜치: `feature/image-original-cache-68`. 통합 브랜치 `cc131bb`를 반영한 작업이다.
- 화면 디자인과 배치는 바꾸지 않는다. 원본을 열 때의 권한 확인·바이트 재사용·세션 경합을 다룬다.
  현재 계약은 [프론트 동작](../frontend/behavior.md#저장된-스크린샷-원본-조회)에 유지한다.

## 구현

- 실제 앱의 API 구성에서 `OriginalImageCache`를 주입한다. `path_provider`의 앱 전용 캐시 경로 하위에
  원본 바이트만 두며, 서버 환경·사용자 DB ID·자산 ID·SHA-256을 조합해 키를 만든다.
- 매번 인증된 접근 정보를 먼저 받고 같은 세션에서 확인한 사용자 ID를 사용한다. 캐시가 맞으면 Bucket 본문을
  다시 받지 않는다. 앱 재시작의 최초 세션 복원은 이전 캐시를 유지하며 현재 권한과 사용자 ID는 다시 확인한다.
- 읽을 때 크기·해시를 확인하고 손상 파일은 폐기한다. 쓰기는 검증한 바이트를 임시 파일에 완성한 뒤
  이름을 바꾸어 확정한다. 파일 작업은 직렬화하고 늦은 세션의 쓰기는 전후에 차단한다.
- 원본 열람 시 7일 미사용 파일·불완전한 파일을 정리하고 오래 사용하지 않은 파일부터 지워 기본 100MiB를 지킨다.
  OS 경로나 디스크가 불가능하면 캐시는 생략하되 검증된 온라인 원본은 표시한다.
- 로그아웃 시작·계정 변경·최종 인증 무효화는 캐시 작업 세대를 즉시 무효화하고 기존 파일을 삭제한다.
  기존 공유 세션 교체·인증 갱신·화면의 늦은 응답 차단은 유지한다.
- 상세 화면의 성공한 메모리 바이트가 다음 원본 열람을 우회하던 경로를 없앴다. 다시 열 때 표시 바이트를 비우고
  권한을 확인하며, 동시에 진행 중인 두 원본 표시는 하나의 요청을 공유한다.

## 자동 검증

작업 트리의 `frontend/`에서 실행했다. HTTP는 주입한 합성 응답이며 캐시 API 통합 검사는 매번 별도의 실제
임시 디렉터리를 만들고 종료 시 삭제한다. 위젯 검사에서는 OS 경로 플러그인을 사용할 수 없는 경계로 대체해
호스트 앱의 캐시 경로에 접근하지 않는다. 이 대체를 실제 기기 캐시 성공으로 취급하지 않는다.

- TDD 실패: 캐시 API 미구현, 세션 종료 후 캐시 파일 잔존, 원본 시트 재진입의 접근 요청이 2회 대신 1회인 경우를
  확인한 뒤 수정했다. 새 시간·용량 설정 검사도 실패 후 구현했다.
- `flutter test test/original_image_cache_test.dart --no-pub`: 12개 통과. 초기 10개 이후 직접 Bucket 본문 재사용과
  인증 무효화 중 세션 저장 실패 검사를 보완하고 다시 실행했다.
- `flutter test test/original_image_cache_test.dart test/screenshot_asset_api_test.dart test/screenshot_asset_access_test.dart test/screenshot_asset_test.dart test/view_models/content_view_models_test.dart test/original_link_root_test.dart test/today_root_test.dart test/bottom_safe_area_test.dart --no-pub`:
  당시 209개 통과. 캐시 재열람·삭제/서버 오류·계정 격리·앱 재실행·크기/해시 손상·7일 경계·용량 퇴출·늦은 파일 작업,
  기존 원본 인증/서명·상세 이동·두 표시의 동시 요청·안전 영역 검사를 포함한다.
- `flutter analyze --no-pub`: No issues found.
- `git diff --check`: 통과.
- 한도 처리 통합 `d328a61`을 병합한 후 캐시·원본 접근·원본 화면·한도 API 검사를 다시 실행해 **97개 통과**했다.
  여기에는 최종 12개 캐시 검사와 원본 재진입 직전 삭제된 경우 이전 표시 바이트를 폐기하는 위젯 검사가 포함된다.
  같은 통합 코드의 정적 분석도 No issues found였다. 전체 통합 검사는 후속 #74에서 수행한다.

## 모바일 실행 검증

- iPhone 16 Pro / iOS 18.6 Simulator: 실제 앱과 새 캐시 플러그인 빌드 **78.3초**.
  Android 13 / API 33, `Clipback_Share_API_33`: Debug APK 빌드 **138.3초**, 설치 **6.9초**.
  Android 빌드에서 의존성이 요구하는 SDK Platform 35 revision 2를 준비했다. 기존 Kotlin 2.2.10 지원 예고와
  Java 접근·폐기 API 경고는 남아 있으며 이번 작업에서 무관한 도구 설정을 바꾸지 않았다.
- 두 플랫폼 모두 실제 `ClipbackApp`·`ClipbackApi`·`path_provider`의 OS 앱 전용 디스크 캐시를 실행했다.
  별도 HTTP 클라이언트가 로컬 moto S3의 합성 원본을 실제 HTTP로 받았다. 프로필·인증·피드·공유 API 응답은 대역이며,
  실제 FastAPI 인증·소셜 제공자·운영 Railway·개인 이미지·실기기·원격 CI 성공으로 취급하지 않는다.
- 첫 열람은 접근 API 1회·Bucket 본문 1회·확정 캐시 파일 1개였다. 재진입은 접근 API가 2회로 늘고
  본문은 1회를 유지했다. Bucket 요청에 앱 Authorization·Cookie가 없는 것도 실제 요청에서 확인했다.
- `simctl terminate/launch` 및 `adb am force-stop/start`로 **실제 앱 프로세스를 재시작**했다.
  새 프로세스에서 접근 API는 1회, Bucket 본문은 0회로 기존 파일을 열었다. 두 플랫폼의 캐시가 모두
  478,337바이트·SHA-256 `0f0a8eb398ca1b3b3ee6564da8c72ddc53727b215ced115abc77b310b7780a82`로 원본과 같았다.
- 실제 앱의 로그아웃·게스트 시작·온보딩 콜백을 거쳐 계정을 바꿨다. 로그아웃 후 로그인 화면과 캐시 0개를 확인했고,
  다른 DB 사용자 ID 2로는 본문을 새로 받았다. 이후 접근 API를 404로 바꾸고 다시 열면 이전 원본 대신
  기존 누락 안내를 표시했으며 본문을 추가로 받지 않았다. Flutter framework·async·알 수 없는 공유 메서드 오류는 모두 0이었다.
- OS PNG를 원본 크기로 보존하고 직접 확인했다. 양쪽의 재진입·프로세스 재시작·삭제 안내 각각 3장과
  iOS 1206×2622 H.264 22.46초·Android 1080×2220 H.264 51.61초 영상을 보존했으며 `ffprobe`로 형식·길이도 확인했다.
  외부 `image-storage-implementation/cache-native/` 증거 폴더에 `ios-68-*`, `android-68-*`, 각 단계 상태 JSON,
  `native-68-result.json`, 실행 소스·로그가 있다. 영상은 실제 전환을 포함하며 이미지·영상의 원본을 보정하지 않았다.
- 실행 도구 소스 SHA-256은 `ce5f1e9e413eee754972a7c49c70414bbfdb814f5063e404fea08bdcafd7e92e`이다.
  기존 도구의 포괄적 `passed` 필드는 사진과 무관한 원문 링크 이벤트를 요구하므로 사진·캐시별 명시적 검사를
  별도로 평가해 `native-68-result.json`에 통과를 기록했다.
- 화면 디자인 변경은 없고 기존 로딩·오류 영역을 사용했다. 이 기능 증거의 상세 데이터는 최초 디자인 비교용
  고정 baseline과 다르므로 해당 세 장 비교를 대신하지 않는다. 공통 baseline/Figma 대조는 후속 #74에서 다룬다.

검증 앱은 두 플랫폼 모두 종료했으며 기기는 켜 둔다. 운영 배포와 실제 자료 이관은 수행하지 않는다.
