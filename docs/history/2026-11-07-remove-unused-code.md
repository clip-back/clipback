# 안 쓰는 서버·앱 코드 15곳과 passlib 삭제, deptry를 서버 CI에 추가 (#271)

2026-11-07, 시작 커밋 `67f7e2f` 기준으로 구현하고 티켓·최종 리뷰(지적 0건)와 전체 검증까지 마쳤다.
코드 커밋은 `aee4409`이고, 전체 검증의 기준 코드도 `aee4409`이다.
사용자 결정에 따라 15행 삭제와 deptry CI 추가를 한 이슈로 했고, `CategoryCardPager`·`CategoryFeaturedCard`는 지우지 않았다.

## 구현

- 서버에서 지운 것: `app/db/init_db.py`(파일), `app/utils/pagination.py`의 `CursorParams`(파일), `UserRepository.list_all`,
  `SocialIdentityRepository.get_by_user_provider`(테스트 가짜 저장소의 같은 이름 메서드 포함), `MaintenanceGate.assert_frozen`, 의존성 `passlib[bcrypt]`.
- 앱에서 지운 것: `shared/content/filter_bar.dart`의 `ActiveFilterBar`(파일), `LinkAddSheet`, `RelatedContentTile`, `MyStatCard`, `MyMenuTile`, `AccountSheet`,
  `FloatingAddButton`, `ClipbackApi.health`·`readiness`·`createContentFromShare`, `FeedPage`의 `pendingRequest`·`trackRequest`·`clearPendingRequest`와 필드 `_pending`.
- 이 삭제로 안 쓰게 된 것도 지웠다: `flutter analyze`가 알린 import 8개와 비공개 메서드 `ClipbackApi._getPublic`(health·readiness만 불렀다).
  상세 프리뷰 도구(`frontend/test/support/detail_preview.dart`)는 `RelatedContentTile` 대체 경로만 빼고 `detail-related-card-…` 키 경로를 남겼다.
- 직접 import하는 간접 의존성을 직접 선언했다(사용자 승인): `pydantic>=2.9.0`, `starlette>=0.46.0`, `botocore>=1.35.0,<2`. 이 하한에서의 동작은 확인하지 않았다.
- deptry: `dev` 추가 의존성에 `deptry==0.25.1`, `pyproject.toml`에 `[tool.deptry]`(`optional_dependencies_dev_groups = ["dev"]`, DEP002 예외 `asyncpg`·`python-multipart`·`uvicorn`).
  `backend-validation.yml`의 `lint` 작업에 `Lint` 다음 `Check dependencies`(`deptry .`) 단계를 더했다. 서버 README 기본 검증과 `docs/backend/testing.md` Validation에도 명령을 넣었다.
- 서버 API 계약(`/health`, `/health/ready`, `/contents/share`)과 iOS·Android 네이티브 공유 호출은 그대로다. 화면에 보이는 위젯은 바뀌지 않아 기기 촬영은 하지 않았다(사용자 결정).

## 검증

- 생성·호출 0회: 작업 전(`67f7e2f`) `git grep -n -w`로 지울 이름을 찾으면 선언·생성자 줄, 테스트 가짜 저장소, 프리뷰 도구 경로, 문서 1줄만 나왔다.
  작업 뒤에는 `docs/history/` 밖 0회, `git grep -n -E 'health\(\)|readiness\(\)' -- frontend` 0회, 지운 파일 경로 언급 0회다.
- deptry 차단 확인(`backend/` 가상환경, deptry 0.25.1): 변경 뒤 `deptry .`는 `Success! No dependency issues found.`(154개 파일, 종료 코드 0).
  `dependencies`에 `passlib[bcrypt]>=1.7.4`를 잠시 넣으면 `DEP002 'passlib' defined as a dependency but not used in the codebase` 1건으로 종료 코드 1.
  백업으로 되돌린 뒤 백업과 같고 `passlib`가 0회임을 확인했다. 전체 검증 뒤 `aee4409`에서 다시 돌린 `deptry .`도 0건, 종료 코드 0.
- 부분 검사(구현 중): 관련 pytest 55 passed, 6 skipped. skip 6건은 `tests/repositories/test_social_identity_repository.py`(1)와 `tests/integration/test_maintenance.py`(5)로,
  검사용 DB 주소가 없어서였다. 아래 전체 검증은 검사용 DB를 만들어 돌렸고 이 6건은 skip 목록에 없다(실행됨).
- 리뷰: 티켓 리뷰가 단일 이슈 최종 리뷰를 겸했고 Standards·Spec 모두 지적 0건이다.
- 전체 검증(`aee4409`): `VERIFY result=PASS scope=all checks=11 failed=0`. 앱 테스트 3253개 통과, pytest 2235 passed, 47 skipped.
  - `pytest skip: 46 tests/deployment (RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are … 외 6종)`
  - `pytest skip: 1 tests/integration (CLIPBACK_IMAGE_TEST_S3_ENDPOINT is required for the local s…)`
- 미검증: PR의 Backend Validation `lint` 작업에서 deptry 단계가 통과하는지(push·PR 승인 뒤 원격 CI에서 확인 대기), 새 하한 버전(`pydantic` 2.9.0 등) 설치 환경, iOS Simulator·Android Emulator 실행(화면 변경 없음).
