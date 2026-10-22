# 스크린샷 원본 조회

- 최초 기록일: 2026-10-06
- 영역: 조회
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-d61a5fa04712ff1f"></a>

### 2026-10-06 / PR 7 / PR 생성

<a id="b-1ab50f40fd8a656d"></a>

- PR #43의 FE 병합(`da895d3`)을 확인하고 최신 FE에서 `fix/fe-screenshot-original`을 만들었다.
  사용자 `AGENTS.md`는 원래 체크아웃에 보존하고 커밋에서 제외한다.
- 수정 전 재현: 사진 저장 → 확인창 종료 → 상세 복귀·재진입 후 원본 이미지 표시가 없는 위젯 테스트
  1건이 실패했다. 다운로드 전송 대기/본문 수신이 10초 이후에도 끝나지 않는 API 테스트 2건도 실패했다.
- 자산 정보를 화면 모델과 복사 경로에 보존하고, 기존 상세 펼침 영역·원문 창에서 같은 인증 다운로드
  상태를 공유한다. 상세 이탈·자산/계정 변경 시 바이트를 정리하고 늦은 응답을 무시한다.
  별도 확대 화면·영속 이미지 캐시·다운로드 기능은 추가하지 않는다.
- `readAsset()`은 기존 공통 인증 재시도를 유지하고 다운로드의 전송 대기/본문 수신에 각각 10초를
  적용한다. 일반 JSON 요청 정책은 변경하지 않는다. 오류·없는 자산·디코딩 실패를 구분하고 수동 재시도한다.
  리뷰 중 발견한 원문 창 첫 프레임 전 상세 교체 경합도 막고 회귀 테스트를 추가했다.
- Flutter 3.44.9 / Dart 3.12.2에서 `flutter pub get --enforce-lockfile`,
  `flutter analyze --no-pub`(이슈 0), `flutter test --no-pub`(**298 passed, skip 0**),
  `flutter build web --no-pub`를 통과했다. 기존 239개와 원본 API 29개·위젯/모델 30개를 포함한다.
  기존 CupertinoIcons 폰트 경고는 남아 있지만 빌드는 성공했다.
- 테스트는 PNG/JPEG/WebP 실제 디코딩과 렌더 비율, 저장 후 재진입/앱 재생성, 두 영역의 요청 공유,
  401 공유 갱신·저장 콜백 대기, 다운로드/본문 시간 초과, 403/404/503/최종401/연결/빈 바이트/손상 이미지,
  뒤로/인접 상세/자산/계정 전환 후 늦은 응답, 저장 실패 배너·다시 저장을 포함한다.
  이미지 재시도나 토큰 저장 재시도로 게스트·원래 업로드·열람/클릭을 반복하지 않는지도 확인했다.
- 같은 브랜치 백엔드와 새 폐기용 DB 3개에서 migration 전체 upgrade와 `alembic check`를 통과했다.
  Docker daemon을 사용할 수 없어 로컬은 **PostgreSQL 17.7**을 사용했다.
  `tests/integration/test_auth_flow.py`, `test_upload_and_isolation.py`,
  `tests/api/test_uploads.py`, `tests/services/test_upload_service.py`는 **36 passed, skip 0**, 경고 1건이다.
  PostgreSQL 16·Docker는 최종 head 원격 CI에서 별도로 확인한다.
- Chrome 전용 계정에 긴 PNG(900×2400)와 가로 PNG(1600×900)를 실제 로컬 업로드 API로 저장했다.
  fixture 호출을 브라우저 요청과 구분했고, 저장 전후 사용자·세션·refresh 저장값은 그대로였다.
  확장의 파일 URL 접근 권한 제약과 사용 중인 기본 창을 고려해 **이번 Chrome의 파일 선택/업로드 UI는
  실행 완료하지 않았다.** 저장 확인창 종료 후 재진입은 FilePicker/HTTP 대역 위젯 테스트에서 검증했다.
- Chrome에서 상세의 원본을 열기 전에는 다운로드가 없었으며, 자연 만료된 1분 access token으로
  `GET /uploads/assets/1` **401 → refresh 200 → GET 200**을 확인했다.
  해당 구간 refresh 1회·추가 게스트 0회, 원문 창을 열어 긴 이미지 끝까지 스크롤해도 추가 다운로드 0회였다.
- 앱 새로고침 후 같은 사용자·세션으로 목록과 원본을 다시 조회했다. 다른 사진의 원본에 503을 한 번
  주입하고 오류 안내를 확인했으며, 자동 반복 없이 수동 재시도 GET 200으로 복구했다.
  503→복구 구간 refresh/guest는 모두 0회였고 DB 열람/클릭/open_count는 각각 3을 유지했다.
  별도 만료 시점의 정상적인 갱신은 각 검증 구간과 구분했다.
- 원본 파일·다운로드 bytes의 SHA-256이 두 사진 모두 정확히 같았다. 최종 사용자/세션 1개,
  콘텐츠/첨부파일/저장 이벤트/저장 파일 각 2개, 실제 상세 진입 3회에 열람/클릭/open_count 각 3이었다.
  별도 probe DB의 실제 API로 소유자 bytes 200, 인증 없음 401, 다른 사용자/없는 자산/유실된 파일 404를 확인했다.
  OCR·AI 고정 대역 각 2회, 외부 HTTP 시도 0회이며 원본 조회는 공급자를 호출하지 않았다.
- 실제 Chrome 화면은 원래 체크아웃의 ignored `frontend/build/verification/pr7/`에 보존했다.
  `01-detail-original.jpg`, `02-original-sheet-top.jpg`, `03-original-sheet-bottom.jpg`,
  `04-after-reload.jpg`, `05-download-error.jpg`, `06-download-recovered.jpg`를 대화에 공유한다.
  화면·테스트 사진·인증값·로그·DB·저장 파일은 커밋하지 않는다.
- `git diff --check`, 신규 파일 whitespace와 최종 diff를 확인했다. 사용자 `AGENTS.md` 변경 및
  잠금파일의 SHA-256은 작업 전과 동일하다. 백엔드·DB·의존성 변경과 migration은 없다.
- 운영 배포·실제 OCR/AI·OAuth·실기기 및 Chrome 파일 선택 UI는 미검증이다.
  원본의 영속 캐시·확대·파일 다운로드 기능은 범위 밖이며, 시간 초과/화면 이탈이 서버 전송을 취소하지 않는다.

<a id="b-e5f51f2eecfeb3b1"></a>

- 실제 검증 화면과 결과를 대화에 공유하고 관련 6개 파일을 `d4ce0e5`로 커밋·푸시했다.
  FE 대상 일반 [PR #44](https://github.com/clip-back/clipback/pull/44)를 생성했다.
  이 PR 링크 기록을 추가 푸시한 최종 head에서 Backend Validation을 수동 실행한다.
  PostgreSQL 16·Docker 결과와 실행 링크는 PR 본문과 작업 대화에 기록하며, PR은 병합하지 않는다.
