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

## 실행 검증 상태

iOS Simulator와 Android Emulator의 실행 검증은 빌드 슬롯과 작업용 디스크 공간을 확보한 뒤 이 브랜치에서 수행한다.
실제 운영 Railway·OAuth·개인 이미지·실기기·원격 CI 검증은 포함하지 않는다. 운영 배포와 데이터 이관도 수행하지 않는다.
