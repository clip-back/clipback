# 마이 통계 조회 상태·복구 구현

## 기준과 진행 경계

- 요청: [스펙 #80](https://github.com/clip-back/clipback/issues/80) 전체를 구현하고 #81 → #82·#83 → #84 순서로 통합한다.
- 통합 브랜치: `feature/account-stats-recovery`. 시작 커밋 `e96b33887ede1cb83a3b2b1ba69a6ba4eb712650`, 당시 main `00e092a59196b44013b3fadfb37e1a6cc6ee549e`.
- 구현자는 티켓별 작업트리에서 승인된 실제 앱·HTTP 대역·메모리 세션 경계에 RED→GREEN을 적용한다. 완료 커밋은 별도 병합 담당자가 통합한다.
- #81 구현·자동·양 플랫폼 실행 검증을 완료했고, #82·#83 제품 코드를 통합해 전체·네이티브 검증 중이다. #84와 최종 리뷰는 후속 진행한다.
- 푸시·PR·main 병합·배포는 수행하지 않는다. 실제 OAuth·운영 API·실기기 검증과 로컬 대역 검증을 구분한다.

## #81 최초 상태·수동 복구

- 커밋 `ad53c73e137d103dbdcc85720a03fa3d3bf8fcd8`. 미확인 수치의 null/`—`, 최초 대기·실패 안내, 통계 전용 재시도와 실제 0건을 구분한다.
- 사용자 Repository가 진행 중 조회와 전체 10초 요청 수명을 소유한다. 인증 갱신·재요청도 같은 시간에 포함하고, 종료된 단독 갱신의 늦은 결과는 세션을 바꾸지 못한다.
- 프로필과 통계를 독립 조회·반영한다. 플랫폼 보안 확인의 예외 처리는 일반 프로필 실패와 분리해 보존한다.
- 정상 패널의 최소 높이80·두 열·색상·폰트·원본 구분선을 보존하고, 공유 Table 행으로 라벨 줄바꿈·높이 증가·두 수치 정렬을 지원한다.
- 최초 미확인을0으로 기대한 기존 앱 테스트가 실패하는 RED 후 구현했으며, 프로필 보류·503에서도 통계9/3을 표시하는 별도 RED→GREEN을 확인했다.
- 503·연결 실패·잘못된 JSON·수치 필드 누락의 실패→재시도→실제0/0, 중복 입력의 HTTP1회, 프로필 재조회 없음, 자동 polling 없음, 인증 갱신과 재전송 합산10초, 늦은401·토큰 보호를 앱 경계에서 확인했다.
- 전체 `flutter test --no-pub --concurrency=2`: **1805/1805 통과**. `flutter analyze --no-pub`: **No issues found**. `flutter build web --no-pub`: **성공**. 마지막 정상 Figma fixture 검사 **10/10 통과**. diff 공백 검사 통과.
- 원시 RED·GREEN·검사 로그와 구현 인계: `/private/tmp/clipback-account-stats-implementation/81-notes.md` 및 같은 디렉터리의 `81-*.log`.

## 변경 전 화면과 디자인 출처

- 화면 코드 수정 전에 양 플랫폼에서 실제 앱 루트의 합성 세션·HTTP 응답을 사용해 정상218/72·실제0·최초 통계 지연·통계503·프로필503·프로필 지연을 글자1/2배율로 새로 실행했다. 플랫폼별 PNG12장과 영상1개를 보존했다.
- 두 플랫폼 모두 기존 글자2배율에서 `MyMetric` 두 Column의 bottom overflow37px을 재현했다. 원본 경고띠와 패널 밖 숫자를 보정하지 않았다. 1배율 장면에는 framework 오류가 없었다.
- Figma J01 `111:4707`과 패널 `111:4727`을 이번 작업에서 새로 조회했다. 정상 원본375×842·패널343×80이며 새 대기·실패·버튼 상태는 [사용자 승인 디자인](../frontend/account-stats-recovery.md#디자인-기준)을 따른다. 없는 Figma 상태를 만들어 채우지 않는다.
- 원본·환경·해시 manifest: `/private/tmp/clipback-account-stats-implementation/native/before-manifest.json`. 이후 변경 후 실행·비교는 이 기록에 추가한다.

## #81 양 플랫폼 실행

- iOS Simulator iPhone16Pro/iOS18.6과 Android Emulator `Clipback_Share_API_33`/Android13(API33)에서 새로 빌드·설치·실행했다. 실제 앱 루트와 HTTP·메모리 세션·소셜 대역을 사용하고, native share는 위임0으로 격리했다.
- 정상218/72·실제0·통계 지연·503·프로필503/지연을 글자1/2배율로 각각 캡처했다. 최초실패→실제 pointer 재시도→성공, 중복입력 HTTP1회, 프로필 독립, 잘못된 응답, 전체10초와 새 재시도 예산, 인증 갱신 포함 제한, 다른 설정 메뉴 이동, 현재401 인증 복구를 확인했다.
- iOS 원시 검사 **26/26 통과**. Android 원시 검사 **25/26 통과**이며 나머지1개는 변경 전과 같은 프로필 영역의 글자2배율1px overflow다. 통계 영역의 기존37px×2 overflow는 두 플랫폼 모두 해소됐다. 프로필·하단 탭의 확대 전용 디자인은 이번 통계 범위 밖으로 남긴다.
- 변경 전·후·Figma를 같은 플랫폼·기종·데이터·배율·스크롤 조건으로 표시한 비교: `/private/tmp/clipback-account-stats-implementation/native/comparison-after81.html`. 정상의 셋째 열은 새로 조회한 J01 원본이며, 새 실패 상태는 채택한 Figma가 없다는 이유와 승인 시안을 표시한다. 원본 이미지는 자르거나 보정하지 않았다.
- 원시 판정·해시·관측 시각: 같은 디렉터리의 `after81-native-receipt.md`, `after81-manifest.json`. 대표 이미지는 `{ios,android}/after81/first-error-scale1.png`, 확대는 `first-error-scale2.png`, 실제 재시도·이동 영상은 `stats-retry-menus.mp4`다.
- 기존 BEFORE 원본50개의 해시를 유지했다. 실행 후 이번 AVD·fixture 앱만 종료했으며 기존 iOS Simulator boot는 유지했다. 실제 OAuth·운영 서버·실기기 증거는 아니다.

## #82 마이 진입과 진행 중 조회 공유

- 커밋 `0a940085b891c2a8c42e14cebb319cf9f81c5816`. 실제 경로 변경을 추적하는 중앙 훅으로 탭·계정·공지·시스템 뒤로가기를 연결했다. 재빌드·동일 탭·앱 복귀만으로 조회하지 않는다.
- 홈→마이의 두 번째 stats HTTP가 없어서 실패하는 RED 후 구현했다. 유효한 bootstrap·재시도 조회는 공유하고8초·9초에 합류해도 원래10초 마감을 유지한다. 이탈 중 성공은 보존하며, 실패는 전역 오류를 만들지 않는다.
- 관련 앱·이동·인증 회귀 **146/146 통과**, analyze·diff 검사 통과. 기존 공지 스크롤 테스트는 복귀 시 새 stats GET1회만 허용하며 나머지 요청·쓰기·스크롤 보장을 유지한다.
- 증거와 인계: `/private/tmp/clipback-account-stats-implementation/82-notes.md`, `82-*.log`.

## #83 마지막 확인값과 콘텐츠 후속 갱신

- 커밋 `7616c62d061f8715bcf994773cad12683197a5a6`. 0/0을 포함한 마지막 확인값을 보존하며 재조회 대기·실패 문구를 구분한다. 성공한 두 수치는 함께 교체하고 안내를 제거한다.
- 콘텐츠 후속 갱신도 공통10초 조회를 사용한다. 통계 성공은 프로필 완료 전에 반영한다. 프로필 실패는 기존 공유 receipt의 확인 보류·재시도 계약을 위해 호출자에게 계속 전달한다.
- RED→GREEN으로 마지막값 표시, 다음 콘텐츠 갱신 중 이전 stats401 차단, 무효화된 단독 인증 갱신의 토큰 저장 차단, 이전 후속 프로필401 차단, 무효 시도의10초 후 실패 종료, 초기 프로필의 늦은401 차단을 각각 확인했다.
- 요청 수명 도우미에 선택적 현재 소유권 조건을 연결하고, 토큰 저장 전에 유효한 인증 갱신 소비자를 다시 확인한다. 플랫폼 계정 확인용 `verifySession`은 유지했다. 사용처가 없어진 `loadStats(apply:false)` 옵션은 제거했다.
- 실제0/0 지연·실패·재시도와 새9.999초 성공, 늦은9999/9999 무시, 새 앱 실행의 미확인 상태, 콘텐츠 삭제 성공과 프로필503의 독립성을 확인했다. 실제 공유 구성의 프로필503에서도 통계7/3은 표시되고 receipt는 보류되며 정상 재시도 후 같은 receipt를 확인했다.
- 최신 #82를 포함한 관련 검사 **273/273 통과**, analyze·diff 검사 통과. 상세 RED·GREEN·기존 공유/Repository 회귀: `/private/tmp/clipback-account-stats-implementation/83-notes.md`, `83-*.log`.

## #82·#83 통합 검사와 네이티브 입력 재현

- 제품 `7616c62`에서 전체 Flutter **1819/1819 통과**(3분4초), analyze **No issues found**, 제품 `lib/main.dart`의 웹 빌드 **성공**(37.8초). 로그는 `/private/tmp/clipback-account-stats-implementation/82-83-{full-test,analyze,web-build}.log`다.
- 이후 Android 실행에서 글자2배율의 마지막 확인값 실패 상태를 빠르게 두 번 누르면 stats 요청은1회지만 두 번째 입력이 올라온 ‘리마인드 설정’을 여는 문제를 재현했다. 원본 `native/android/after82-83/last-{error,retry-pending}-scale2.png`와 `stats-last-values.mp4`를 보존하고 #83 수정·재검증을 진행한다. 앞의 자동 검사 통과는 이 입력 문제의 해결 증거가 아니다.
- #82 첫 네이티브 시도는9.1초에 두 탭 왕복을 시작해 실제 복귀가10.43초가 됐다. 이미 만료 후여서 새 요청이 시작된 정상 동작을 ‘기존 요청 공유’ 실패로 잘못 판정한 harness 문제다. 원시 결과를 보존하고,10초 전에 실제 복귀하도록7.2초부터 왕복해 다시 검증한다.
