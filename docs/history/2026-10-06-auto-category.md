# 저장 시 자동 분류 연결

- 최초 기록일: 2026-10-06
- 영역: 저장
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/fe-merge-fixes.md

<a id="b-95c55ef6aa350dfc"></a>

### PR 5 시작 — 2026-10-06

<a id="b-85e2e6688ab215eb"></a>

- PR #41은 2026-10-06 12:54 KST, `9cea2589c408eb675a49d7786476b64f535ec765`로 FE에 병합되었다.
  위 최신 FE에서 `fix/fe-auto-category`를 만들었다. 비교 main은 `8c759d1`이다.
- 저장 화면의 첫 일반 카테고리 강제 지정과 이름 태그 주입을 제거한다. 선택 없는 링크·사진은
  빈 카테고리·태그 목록으로 저장하고, 명시적 카테고리와 API 복수 목록 계약은 유지한다.
- `summary_status`를 클라이언트 모델에 보존하고 실제 카테고리와 YouTube 처리 상태를 표시한다.
  고정 자동 분류 성공 문구와 작동하지 않는 변경 장식은 제거한다.
- 사용자 선택에 따라 저장 전 수동 선택 UI와 자동 폴링은 추가하지 않는다. 상세 화면에서 수동 변경하며,
  비동기 결과는 기존 상세 조회·앱 새로고침에서 반영한다. 초기 저장 후 분류 PUT은 보내지 않는다.
- Flutter 3.44.9 / Dart 3.12.2의 `flutter pub get --enforce-lockfile` 통과.
  사용자 `AGENTS.md` diff와 잠금파일 SHA-256이 PR 4 종료 값과 같음을 확인했다.
- 순서: 잘못된 요청·성공 문구 재현 → 최소 구현 → Flutter·전용 DB·Chrome 검증 →
  화면 공유·커밋·푸시·FE 대상 일반 PR → PR 링크 기록 후 최종 head 원격 CI.
- 제품 수정 전 `content_auto_category_test.dart`는 **0 passed / 3 failed**였다.
  링크 JSON과 사진 multipart에 첫 카테고리 ID `101`·이름 태그가 실제 전송됐으며,
  미분류 결과에도 고정 자동 분류 성공 문구가 표시되는 제품 오류를 확인했다.
- 구현: 저장 콜백은 선택적 카테고리를 받으며 현재 저장 화면은 선택 없이 호출한다.
  카테고리 이름 태그 주입을 제거하고 `summary_status`를 모델·복사 경로에 보존했다.
  확인창은 처리 중 안내·미분류·저장된 카테고리를 구분하고 상세 화면의 변경 경로를 안내한다.
  기존 자동 선택에만 쓰이던 저장창 인자와 마이 화면의 카테고리 전달 인자를 정리했다.

<a id="b-7e45dcacc93edb11"></a>

### PR 5 구현·검증 — 2026-10-06

<a id="b-f95408c3133922d5"></a>

- 새 `content_auto_category_test.dart`의 최초 재현 3건은 수정 후 모두 통과했다. 총 **40건**으로 확장해
  선택 없는 JSON·실제 multipart, 명시적 분류와 복수 값 계약, `###` 이름, 서버 분류 표시,
  요약 상태 기본값·복사, YouTube 모든 처리 상태와 미분류 조합, 30초 동안 폴링·분류 PUT 없음,
  다음 상세 조회와 새 앱 인스턴스의 완료 결과 반영을 확인했다.
  PR 4 테스트는 앱의 기본 전송값과 제거된 저장창 인자만 수정했으며 명시적 복수 값 검증은 유지했다.
- Flutter 3.44.9 / Dart 3.12.2에서 `flutter pub get --enforce-lockfile`,
  `flutter analyze --no-pub`(이슈 0), `flutter test --no-pub`(**188 passed**, 실패·skip 0),
  `flutter build web --no-pub`를 통과했다. 기존 CupertinoIcons 폰트 경고는 남아 있다.
- 같은 브랜치 백엔드로 새 전용 cluster의 테스트·Chrome DB를 각각 준비했다.
  로컬 Docker daemon을 사용할 수 없어 **PostgreSQL 17.7**을 사용했으며,
  두 DB 모두 migration 전체 upgrade와 `alembic check`를 통과했다.
  `tests/integration/test_auth_flow.py`, `test_content_flow.py`, `test_upload_and_isolation.py`,
  `test_content_category_validation.py`, `test_youtube_summary.py`는 **43 passed, skip 0**,
  Starlette/httpx 경고 1건이었다. PostgreSQL 16·Docker는 최종 head의 원격 CI로 별도 확인한다.
- Chrome은 전용 API·파일 저장소·DB를 사용했다. 메타데이터·OCR·AI·YouTube 공급자만 고정 대역으로
  바꾸고 외부 HTTP를 차단·집계했다. YouTube는 자동 worker를 멈춰 대기 화면을 확인한 다음
  실제 `SummaryWorker.run_once()`의 claim·finish·DB 변경을 실행했다.

<a id="b-fb55b98338531147"></a>

| 실제 Chrome 검증 | 요청·이벤트·DB 확인 결과 |
| --- | --- |
| 일반 링크 저장 | `category_ids=[]`, `tag_names=[]`, 201. AI 1회, 첫 분류 취업 대신 공부로 저장·표시 |
| 사진 저장 | 분류·태그 multipart part 없음, 201. OCR·AI 각 1회, 공부로 저장·표시, 파일 원본 일치 |
| AI 오류 링크 저장 | 201, 미분류 유지. 이벤트의 추천 실패 `error` 확인, 화면은 원인을 추정하지 않고 미분류 안내 |
| 첫 YouTube 대기 → 완료 | 201·`queued`·`apply_category=True`, 미분류 및 처리 중 안내. worker 후 `completed`·공부, 새로고침·상세 조회에 반영 |
| 두 번째 YouTube 수동 변경 | 대기 중 상세 UI에서 취업으로 PUT 1회. `apply_category=False`, worker 완료 후에도 취업 보존 |

<a id="b-8f3430bc0bf36d5d"></a>

- 확인창에 머무는 동안 추가 상세 조회·분류 PUT은 없었다. 일반 링크·사진의 생성 이벤트는 `ai`,
  실패 링크는 `uncategorized`로 기록됐으며, YouTube 생성 시점의 미분류 snapshot은 후속 변경에도 보존됐다.
  최종 콘텐츠·저장 이벤트 각 5건, 첨부파일·파일 각 1건, 태그 0건이며 동일 사용자·세션을 유지했다.
  카테고리 추천 대역 3회, OCR 1회, YouTube 공급자 2회, 외부 HTTP 시도 0회였다.
- 로컬 화면 증거는 원래 체크아웃의 ignored `frontend/build/verification/pr5/`에 저장하고 대화에 공유한다.
  `01-link-auto.jpg`, `02-photo-auto.jpg`, `03-uncategorized.jpg`, `04-youtube-pending.jpg`,
  `05-youtube-completed.jpg`, `06-manual-preserved.jpg`는 실제 Chrome 캡처이며 화면·토큰·서버 로그·DB 파일은 커밋하지 않는다.
- 한계: 자동 폴링은 없으므로 후속 분류는 다음 조회 시 반영된다. 운영 배포·실제 OCR/AI·OAuth·실기기는
  검증하지 않았다. OCR 오류 fallback은 기존 통합 테스트로 확인했고 Chrome에서는 AI 오류 fallback을 실행했다.
  OCR 성공 응답의 빈 텍스트 시나리오는 이번 Chrome 검증에서 별도 실행하지 않았다.
  기존 사진 확인창의 링크 문구와 저장된 원본 재표시는 이번 범위에 포함하지 않는다.
  백엔드·DB·의존성·잠금파일 변경과 migration은 없다.
- 실제 화면과 결과를 대화에 공유했다. 제품 코드·새 테스트의 별도 읽기 전용 리뷰에서도
  승인 범위의 추가 결함은 발견되지 않았다. `git diff --check`와 새 테스트의 whitespace 검사를 통과했다.
  사용자 `AGENTS.md`는 원래 체크아웃에 그대로 두고 커밋에서 제외한다.
- 관련 6개 파일을 `5bf4501`로 커밋·푸시하고 FE 대상 일반
  [PR #42](https://github.com/clip-back/clipback/pull/42)를 생성했다.
  이 링크 기록을 추가 푸시한 최종 head에서 Backend Validation을 수동 실행하며,
  실제 결과·실행 링크는 PR 본문과 작업 대화에 기록한다. PR은 병합하지 않는다.
