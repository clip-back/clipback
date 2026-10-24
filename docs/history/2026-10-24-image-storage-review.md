# 이미지 보관 두 축 리뷰와 최종 수정 검증

기록일: 2026-10-24. 명세 #64와 하위 #65–#74 구현을 통합한
`5671e79a6c3451068cf053d185a9334fd9f3144c…fc638da5449efb2117741f3999d593e0f7f3ecb8`의
두 독립 정적 리뷰와 그 후 단일 수정 작업을 기록합니다. 독립 리뷰어는 검사를 재실행하지 않았습니다.
수정 브랜치는 `fix/image-storage-review`, 제품·테스트 수정 커밋은
`f300fd8bc1c4e895ec6f753cb029eefdc267ba94`입니다. 코드 수정, 실행 검증, 메시지 교정은 서로 다른 사실입니다.

## Standards

명시 규칙 위반 1건, 설계상 판단 사항 2건입니다. 기존 저장소 라우터·플랫폼 대역·화면 재사용은
저장소 규칙에 따른 구현이므로 별도 냄새로 분류하지 않았습니다.

1. **표준 위반 — 커밋 제목:** `a7ebda6f5607c29030ea0e9cb4d2931a563d4cc8`의
   `Merge branch 'feature/image-storage-integration' into feature/image-storage-migration-73`는
   [Git 규칙](../git-conventions.md#commit)의 `<type>: <summary>` 형식·한국어 summary와
   [머지 규칙](../git-conventions.md#merge)을 충족하지 않습니다.
2. **판단 사항 — Duplicated Code 가능성:** 운영 재조정
   `retry_image_deletions`와 격리 복원의 `recovery_deletions.apply`에서
   `matches_deletion_identity` → 현재 실제 assets로 cleanup intent 작성 → 콘텐츠 삭제 →
   `deletion_job` 생성이 반복됩니다. 삭제 기준을 바꿀 때 두 경로가 달라질 수 있습니다.
3. **판단 사항 — Primitive Obsession 가능성:** `image_backup`·`image_backup_jobs`가
   `74264001/74264002`를 직접 복제합니다. 이미 삭제 기록 모듈에 있는
   `IMAGE_CLEANUP_LOCK`·`LEDGER_WRITE_LOCK`과 잠금 대상이 달라질 여지가 있습니다.

수정과 근거:

- `apply_deletion_intent`라는 작은 공통 적용 함수만 추출했습니다. 동일 원본이 아니면 보호하고,
  동일하면 현재 실제 보관 위치의 assets로 물리 정리 작업을 기록합니다. 잠금·검증·조회·배치 한도·
  commit·실행 환경은 호출자에 남겼습니다. 새로운 타입이나 실행 계층은 추가하지 않았습니다.
- 백업·복원 실행 경계에서 기존 잠금 상수를 재사용합니다. lazy import를 유지하여
  오프라인 materialize·검증·`--help`가 앱 Settings나 DB 초기화를 요구하게 만들지 않았습니다.
- 제목은 `chore: 이미지 보관 이관 브랜치 통합 기준 반영`으로 교정하는 일회용 절차를 준비했습니다.
  실제 통합 ref는 이 수정 작업에서 변경하지 않았습니다. 소스 병합 뒤 merger가 적용하도록 분리했습니다.
  아래의 메타데이터 교정 증거와 원본 이력 보존 조건을 따릅니다.

## Spec

확정된 명세 위반은 **0건**입니다. 요구 누락·부분 구현, 요청 밖 동작, 요구와 다른 구현으로 보고할
구체적인 결함을 발견하지 못했습니다.

#64와 #65–#74를 기준으로 원본 바이트·혼합 저장소 호환, 계정 한도와 공유 재전송, 권한 확인 뒤 캐시
재사용, 계정 변경 중 응답 폐기, 영속 삭제와 최신 기록 적용, 일일 백업·보존, 이관 재개 경계를
대조했습니다. 테스트 통과 자체를 근거로 삼지 않고 제품 코드와 실패 처리도 확인했습니다.

#64의 “기존 인증 API 통합 테스트를 중심으로 … 외부 동작을 검증”하고 운영 변경은 “별도 실행 범위를
확인”한다는 경계를 적용했습니다. 운영 Railway 자원·IAM·일정·배포·이관, 실제 OAuth·실기기 미검증은
이번 로컬 코드 완료의 누락으로 계산하지 않았습니다. 직접 Bucket 전송량 등 미관측 비용은 운영 보고에
`null`과 한계로 표시하며 실제 청구액으로 주장하지 않습니다. 기존 실행 결과의 경계를 확인한 정적 리뷰입니다.

## Root 추가 확인 — 구성된 API 경로

별도 root 확인 1건입니다. 두 독립 리뷰 보고서에 섞어 우선순위를 다시 매기지 않습니다.
`UploadService.asset_access`가 local 원본의 URL을 `/api/v1`으로 고정하여 기존
`settings.api_v1_prefix`와 달라질 수 있었습니다. 앱은 구성된 API base와 proxy URL을 대조하므로
비기본 prefix에서 원본 열람을 방해합니다.

- 실제 인증 API에 `/api/v1`·`/api/v9`를 각각 구성한 업로드 → access descriptor → 원본 바이트
  GET 회귀를 먼저 작성했습니다. RED: 기본 1개 통과·`/api/v9` 1개 실패(0.71초), descriptor URL만
  `/api/v1`이어서 실패했습니다. 실제 라우팅과 기존 download URL은 `/api/v9`였습니다.
- 기존 설정을 재사용한 한 줄 수정 뒤 GREEN: 2개 통과(0.38초). 크기·SHA·원본 바이트·MIME과
  미인증 401·다른 계정 404도 같은 API 경계에서 확인합니다. 새 설정은 추가하지 않았습니다.
- 현재 [API 계약](../backend/api-contracts.md)과
  [미배포 변경 내역](../../CHANGELOG.md)에 동작을 반영했습니다.

## 실행 검증

모든 아래 검사는 이 수정 작업에서 새로 실행했습니다. 기존 #74 결과를 이번 실행으로 합산하지 않습니다.

- 관련 API 원본·삭제 재조정·이관·백업·보존: **64 passed**, 기존 deprecation warning 1개, 15.00초.
- 전체 backend: **1,106 passed / 19 skipped**, 기존 warning 1개, 68.92초.
  기본 `DATABASE_URL`은 localhost:1의 의도적으로 잘못된 값이며, `TEST_DATABASE_URL`만
  전용 PG17/loopback55464의 `clipback_image_74`를 가리켰습니다.
  `CLIPBACK_IMAGE_TEST_S3_ENDPOINT=http://127.0.0.1:55465`를 켰으므로 실제 HTTP 운영 CLI
  회귀 1개도 1,106개에 **포함**됩니다. 19개 skip은 아래 별도 opt-in 실제 Docker 검사입니다.
- 실제 Docker 최초 전체 실행: **18 passed / 1 failed**, 기존 warning 1개, 411.80초.
  실패는 source fixture PG16에 기본 PG17 operator 이미지를 지정한 설정 오류였습니다.
  같은 이미지로 실패 사례를 재현(1 failed, 76.10초)하고 private 관찰자로 정리 전 실제 종료1과
  stdout의 `{"error":"pg_dump_version_mismatch","passed":false}`를 확보했습니다.
  제품은 exact-major 검사에서 올바르게 거부했습니다. 실제 `pg_dump`는 잘못된 이미지 17.11,
  source와 맞춘 새 operator 이미지 16.15입니다. 같은 `f300fd8` 제품 소스·같은 영향 사례를
  PG16 operator로 재실행하여 **1 passed**(기존 warning 1개, 65.65초)를 확인했습니다.
  이 operator 환경변수는 19개 중 해당 사례의 daily 실행에서만 사용되므로 나머지 18개를
  반복하지 않았습니다. **19개 사례를 모두 검증**했으나 단일 실행의 19 PASS라고 합산하지 않습니다.
  `RUN_DOCKER_RECOVERY_TESTS=1`로 v1 PG16/18, v2 Bucket 백업·온라인 삭제/보존·운영 이미지,
  이관/재개와 이전 지점 복원, 다중 계정의 살아 있는/삭제된/원본 없는 sample,
  PostgreSQL 최종 TCP 준비 경계를 실행합니다. 공통화된 실제 복원 삭제 경로와 잠금 계약을 포함합니다.
- 전체 backend Ruff와 `git diff --check` 통과. 스키마 변경이 없으므로 Alembic 재실행은 하지 않았습니다.
- frontend/lib·iOS·Android 제품 코드는 변경하지 않았습니다. 이번 리뷰 수정에서는 Flutter·기기 빌드를
  재실행하지 않았습니다. 기본 경로 API 회귀는 위 검사로 새로 확인했고, 이전 실제 양쪽 OS 기본 경로·
  캐시·재시작·공유 증거의 소스와 대역 범위는 [#74 통합 이력](2026-10-24-image-storage-integration.md)을
  따릅니다. 비기본 prefix의 실제 모바일 재실행이나 이번 Docker를 운영 Railway로 주장하지 않습니다.

API·operator 이미지들은 제품·스크립트 커밋 `f300fd8bc1c4e895ec6f753cb029eefdc267ba94`로 새로 빌드했습니다.
`clipback-image-review-api:check`와 PG17 `clipback-image-review-operator:check`, source fixture와
맞춘 PG16 `clipback-image-review-operator16:check` 모두 OCI revision 라벨이 이 커밋입니다.
전자는 실제 API·후자들은 변경된 운영 스크립트를 포함합니다. 설정 오류 확인 후 제품을 바꾸지 않았습니다. 이후 문서 변경은 제품 tree를
바꾸지 않습니다. 원시 명령·로그·이미지 ID는 private 인계 디렉터리에 보존합니다.

초기 관련 검사 1회는 backend가 아닌 저장소 루트에서 실행해 기존 CLI의 상대 `scripts/` 경로가 없어
1개 실패했습니다. 제품 실패가 아니며 문서의 backend 작업 디렉터리로 바로잡은 29개 검사와
최종 관련 64개·전체 1,106개 실행에서 해결됐습니다. 실행 위치 오류를 제품 수정으로 처리하지 않았습니다.

## 수정 후 독립 후속 검토

같은 두 독립 리뷰어가 `fc638da…f300fd8`의 의미 있는 delta를 읽기 전용으로 다시 확인했습니다.
Standards 리뷰는 코드 지적 2건이 모두 해결됐고 제목 교정 절차의 실질적인 누락도 없다고 확인했습니다.
Spec 리뷰는 새 명세 지적 0건으로 초기 0건 결론을 유지했습니다. 잠금·검증·배치·commit·물리 정리
순서와 삭제 후 결과용 자산 ID 수집이 유지되는지도 확인했습니다. 두 리뷰어 모두 검사나 ref 변경은
하지 않았으며 진행 중인 실제 Docker 결과는 후속 정적 결론에 포함하지 않았습니다.

후속 원문은 private `review-standards-followup.md`·`review-spec-followup.md`에 보존합니다.
이 확인은 `f300fd8` 기준이며 커밋 제목의 **실제 통합 ref 적용은 source 병합 뒤 merger 작업**입니다.

## 별도 메타데이터 교정 절차 검증

작업 전용 `/private/tmp/clipback-image-implementation/reword-image-storage-merge.py`와
`reword-procedure.md`를 merger에게 인계합니다. Git에 일회용 운영 코드를 추가하지 않았습니다.

- 실제 통합 `fc638da`에서 dry-run: 대상 merge와 후손 **22개** 객체를 계획하되 ref는 바꾸지 않았습니다.
  tip tree 전후 모두 `5dc71e6e3e0bd6dc18889f31eb7e581fa98db70c`입니다.
- 정확한 최종 스크립트를 새 작업 전용 로컬 복제본에 실제 적용했습니다. 원본 HEAD는 새 task-owned
  backup ref에 보존하고, expected-old SHA를 조건으로 통합 ref를 원자 갱신했습니다.
- 매 commit의 tree·author·committer·timestamps·모든 다른 메시지·부모 순서와 merge topology를
  보존하며 target 제목만 교정합니다. `5671e79` main 조상이 유지됩니다. 서명된 commit은 거부합니다.
- dirty checkout, stale HEAD, `feature/fe-sync-main` 지정은 각각 거부하고 모든 ref가 그대로임을
  확인했습니다. 실제 script는 통합 브랜치 하나와 새 `backup/image-storage-review-*`만 허용합니다.
- 최종 source 병합 후 merger가 확인한 **새 full HEAD**로 다시 dry-run·apply해야 합니다.
  `git update-ref --stdin`의 같은 transaction에 새 backup 생성과 CAS를 묶고, clean root만 허용합니다.
  reset·stash·force-push·원격·사용자 ref 조작은 없습니다. 교정 전 검증 SHA는 backup과 기존 ticket
  브랜치로 계속 조회할 수 있습니다. tree가 동일한 메타데이터 작업에 제품 검사를 반복할 필요는 없습니다.

## 실제 통합과 제목 교정 완료

2026-10-24 최종 수정 브랜치를 `--no-ff`로 병합한 뒤 관련 API·삭제·백업 smoke **47 passed**,
전체 backend Ruff·공백 검사·단일 Alembic head `202610230018`을 확인했다.
이후 위 절차를 실제 통합 브랜치에 적용했다. 교정 전 HEAD `1d83f99d1a169a83a7367b3ace796fbd2576d963`은
`backup/image-storage-review-before-title`에 보존했다. 교정 후 HEAD는
`935c5eab63175ebb75edf8f8053b047dc92c2205`다.

대상과 후손 25개 객체의 tree·작성자·시간·부모 순서·병합 구조를 보존하면서 대상 제목 하나만
`chore: 이미지 보관 이관 브랜치 통합 기준 반영`으로 바꿨다. 전체 tip tree는 전후 모두
`e6db897f815878fb67e6bed863f27070db347d37`이며, 다른 기존 ref는 모두 그대로다(전체 ref 148→149).
main 조상과 깨끗한 작업 트리를 확인했다. 원래 대상은 현재 통합 조상에서 빠졌으며 원래 검증 SHA들은
보존 브랜치와 기존 티켓 브랜치로 계속 조회할 수 있다. 파일 내용이 같은 메타데이터 작업이므로
전체 검사를 반복하지 않았다. 이후 완료 문서만 추가한다.

| 원래 검증·작업 SHA | 현재 통합 이력의 대응 SHA |
| --- | --- |
| `a7ebda6f5607c29030ea0e9cb4d2931a563d4cc8` 제목 대상 | `40ca10e92a5123173f8b71ec17fca73a2e1ea444` |
| `80ec2200d81b548e9691e553eb2b49d26715f6b0` #74 최종 검사 소스 | `d1ce5af44e32008e16ed689ad15ce42154a2a924` |
| `d5db19fd7b71b9aa5b47e50458f16e972d772dc8` #74 최종 문서 | `9d59ee94ce16f63c8df66fc752da645b300b0cde` |
| `df680d0a40a8c7f07b5121d7a54c6ab765f33b95` #74 병합 | `1c49270cc2c559e4324f40ba420f363c5b70a15b` |
| `fc638da5449efb2117741f3999d593e0f7f3ecb8` 초기 리뷰 기준 | `d564e3eae5a745e9234ab6b0d7bc2c35952e42e2` |
| `f300fd8bc1c4e895ec6f753cb029eefdc267ba94` 최종 제품·테스트 수정 | `7af2b6630fe3a1b7e7805aa49e913f071ad66759` |

Standards의 명시 위반 1건·판단 사항 2건과 root 추가 확인 1건을 모두 해결했다.
Spec의 확정 위반은 초기·수정 후 검토 모두 0건이다. 아래 발견 수는 해결 전 독립 보고서의 수를 유지한다.

private 증거: `review-prefix-red.log`, `review-prefix-green.log`, `review-focused-green.log`,
`review-full-backend.log`, `review-docker.log`, `review-docker-focused-diagnostic.log`,
`review-operator-diagnostic-failure.json`, `review-docker-operator16-green.log`,
`review-ruff.log`, `review-docker-images.txt`,
`reword-live-dry-run.json`, `reword-final-copy-apply.json`, `reword-negative-guards.json`,
`review-private-script-sha256.json`, `reword-merger-post-review-applied.json`,
`reword-merger-post-review-verification.json`. 경로 루트는 `/private/tmp/clipback-image-implementation`입니다.
원시 자격 증명·덤프·개인 설정은 Git에 포함하지 않았습니다. 검증용 원본 이력과 화면 증거를 보존한 뒤
구현자 작업 트리를 일반 `git worktree remove`로 정리했습니다. 사용자 프론트 작업 트리는 유지했습니다.
운영 자원·PR·원격 ref는 변경하지 않았습니다.

마지막 문서 확인에서 변경 문서의 로컬 링크 605개와 공개 JSON·HTML 증거 96개를 점검했고,
끊긴 링크·JWT·서명 쿼리 후보는 없었습니다. main 대비 추가 파일에 로컬 환경·DB·화면 생성물·
`AGENTS.md`가 포함되지 않았고, 커밋 메시지 형식·공백 검사도 확인했습니다.
작업 소유권을 확인한 합성 S3·PostgreSQL과 이번에 실행한 Android 에뮬레이터는 종료했습니다.
클러스터·AVD 데이터와 화면·영상은 보존했고, 이미 앱이 종료된 iOS Simulator는 그대로 뒀습니다.

축별 발견 수: **Standards 3건(명시 1·판단 2), 축 내 가장 큰 항목은 커밋 제목 규칙 위반**;
**Spec 0건, 축 내 가장 큰 항목 없음**. Root의 구성 prefix 1건은 별도로 해결했습니다.
