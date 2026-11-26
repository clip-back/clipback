# 현재 안내 문서의 경과 기록·중복·끝난 문서 정리 (#484)

기록일: 2026-11-26. 기준 커밋 `0ad6e50`. 문서만 바꿨으며 앱·서버 코드, 테스트, CI 설정은 바꾸지 않았다.
[Figma 화면 맞춤 계획](../figma-ui-alignment-plan.md)의 재배치는 이 PR에 넣지 않고, 앱 PR(#477·#479·#478)이 병합된 뒤 다음 PR에서 한다(2026-11-26 사용자 결정 "1–3만 지금 PR, figma는 다음 PR").

## 이관 기준

| 옮긴 문서·절 | 새 위치 | 옛 경로 |
| --- | --- | --- |
| `docs/backend/image-operator-execution-plan.md` | [2026-10-26 실행 계획](2026-10-26-image-operator-execution-plan.md) | 한 줄 안내와 옛 제목 앵커 |
| `docs/backend/image-storage-merge-preparation.md` | [2026-10-25 병합 준비](2026-10-25-image-storage-merge-preparation.md) | 한 줄 안내와 옛 제목 앵커 |
| `docs/backend/image-storage-compatible-deployment.md` | [2026-10-25 호환 배포 체크리스트](2026-10-25-image-storage-compatible-deployment-checklist.md) | 한 줄 안내와 옛 제목 앵커 |
| `docs/android-internal-test-release-spec.md` | [2026-10-28 Android 내부 테스트 명세](2026-10-28-android-internal-test-release-spec.md) | 한 줄 안내와 옛 제목 앵커 |
| `docs/frontend/account-stats-recovery-spec.md`(#80 본문 사본) | [2026-10-24 #80 사본](2026-10-24-account-stats-recovery-issue-80.md) | 한 줄 안내와 옛 제목 앵커 |
| `docs/frontend/category-save-recovery-spec.md`(#86 본문 사본) | [2026-10-25 #86 사본](2026-10-25-category-save-recovery-issue-86.md) | 한 줄 안내와 옛 제목 앵커 |
| `frontend/design_cache/figma_624_16572.md` | [2026-09-07 Figma 디자인 캐시](2026-09-07-figma-design-cache.md) | 한 줄 안내와 옛 제목 앵커 |
| `frontend/design_cache/figma_exports/*.png` 3장(참조 0건) | 삭제(git 기록에 남음) | — |
| `frontend/test/support/README.md`의 #223 전환 결정 문장 | [#223 이력](2026-11-03-http-response-hold-helper.md#현재-문서에서-옮김484) | 현재 안내 문장으로 바꿈 |
| `docs/releases/TESTER-NOTES.md`의 0.6.0 설명용 예시 | 삭제, [0.7.0 후보의 테스터 안내](../releases/app-v0.7.0-ios-b16-android-b12.md#테스터-안내) 링크 | 옛 예시 제목 앵커 |

그 밖에 지운 경과 문장은 같은 사실이 이미 연결한 이력·배포 기록에 있어 링크만 남겼다(api-contracts 테스트 수치 → 2026-09-22·24·25 이력, railway·backend-mvp-plan 운영 경과 → 2026-10-22·10-26 이력, image-storage-policy 현재 상태 → 이미지 보관 이력 4개, 복구 정책 문서 3개 머리말, 빈 상태 그림·탈퇴 승인 원문).
`frontend/README.md`의 사진·공유·카테고리 설명 중 `docs/frontend/behavior.md`에 없던 문장(이미지 저장 일시 중단의 본앱 표시·Android 이미지 URI 원본, 단색 8개 색 줄, 키 없는 기존 인터페이스, 선택기 압축 해제·비변환 이름 보존, 원본 접근 엔드포인트, Bucket 전용 HTTP 클라이언트, 캐시 경로)은 behavior로 옮긴 뒤 README에서 지웠다.
작업 이력 목차는 표 밖 목록 10개를 표에 넣고 표 전체를 최신순으로 정렬했다(같은 날짜는 원래 순서, 날짜 미확인 2행은 끝).

## 검증

`.utmp/docs-cleanup/anchor_check.py`(추적 중인 `.md`의 상대 링크 파일·`#앵커` 검사, 커밋하지 않음)로 확인했다.

- 링크 검사: `ANCHOR_CHECK broken=9 files=379`. 9줄은 `0ad6e50` 기준선과 같다(괄호 안 코드·절대 경로를 링크로 읽은 것, 실제 깨진 링크 0건).
- 옛 경로 앵커: 옮긴 7개 파일과 TESTER-NOTES의 `0ad6e50` 제목 slug·`id` 집합이 현재 같은 경로의 앵커 집합에 모두 들어 있다(빠짐 0).
- `frontend/README.md`의 `<a id>` 111개 유지. figma 문서는 아직 바꾸지 않았다.
- 문서의 `ruff check`·`compileall` 대상이 CI `backend-validation.yml`과 같은 `app scripts alembic tests`다.
- 저장소 밖 키트가 쓰는 경로·절 제목 유지, `git diff --check` 통과, `.md` 밖 변경은 PNG 3장 삭제뿐.
- `frontend/README.md` 50,335B → 약 45.3KB.
- 전체 앱·서버 검사와 시뮬레이터·에뮬레이터 실행은 문서만 바꾼 작업이라 하지 않았다.

## 검수 반영

검수(높음 0·중간 4·낮음 2)를 모두 반영했다: 옛 경로 안내 파일과 TESTER-NOTES에 옛 제목 앵커 보존, backend-mvp-plan에서 혼합 백업 복원과 일일 백업 예약 외 생성(`restore_verified=false`) 구분, TESTER-NOTES 예시를 세 채널 문구가 있는 0.7.0 후보로, 사진 고유 조건을 behavior에 보충, #223 결정 문장을 이력으로 옮김, 첫 운영 체크리스트 #344 체크를 관측한 사실로 한정.

## 범위 밖 발견

- `docs/backend/image-deletion.md`의 원본 삭제 재시도 서비스 "운영 적용은 병합 뒤 확인하기 전" 문장은 #339 운영 적용 기록과 어긋난다. 이번 이슈 범위에 없어 고치지 않았다.
