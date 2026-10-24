# 마이 통계 조회 상태·복구 구현

## 기준과 진행 경계

- 요청: [스펙 #80](https://github.com/clip-back/clipback/issues/80) 전체를 구현하고 #81 → #82·#83 → #84 순서로 통합한다.
- 통합 브랜치: `feature/account-stats-recovery`. 시작 커밋 `e96b33887ede1cb83a3b2b1ba69a6ba4eb712650`, 당시 main `00e092a59196b44013b3fadfb37e1a6cc6ee549e`.
- 구현자는 티켓별 작업트리에서 승인된 실제 앱·HTTP 대역·메모리 세션 경계에 RED→GREEN을 적용한다. 완료 커밋은 별도 병합 담당자가 통합한다.
- 현재 #81 구현 커밋은 통합했으며 네이티브 검증 중이다. #82~#84와 최종 리뷰·전체 검증은 아직 진행 전이다.
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
