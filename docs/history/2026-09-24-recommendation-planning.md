# 재발견 추천 계획과 당시 단계 상태

- 최초 기록일: 2026-09-24
- 영역: 추천
- 이관 기준: `c04a7556cb7cfea0dd273992e411e0ee6537c853`

당시 작성된 원문을 출처별로 보존한 기록입니다. 과거 승인·푸시 예외와 실행 결과는 해당 작업에 한정됩니다.
수치·문구·한계가 다른 기록은 그대로 남겼으며, 이번 이관은 재실행·운영 성공을 뜻하지 않습니다.
[이력 목차](README.md) · [원문 이관 대조표](migration-map.json)

## 원문 출처: docs/content-recommendation-plan.md

<a id="b-7d374fc200723f38"></a>

### 콘텐츠 재발견 추천 구현 계획

<a id="b-d09d24bd495dcf99"></a>

- 작성일: 2026-09-24
- 작업 브랜치: `feature/content-recommendation`
- 코드 확인 기준: `8caeb67`에서 분기, 4단계 커밋 `cb0bac8` 위에 5단계 구현
- 현재 상태: 1~5단계 구현 및 로컬 검증 완료. 6단계는2026-10-21 Today 버튼·추천 상세 탐색을 부분 연결했으며 Weekly·실제 카드 노출은 미구현. 7단계 운영 검증은 미착수

<a id="b-fa9156cc0235bc27"></a>

2~7절은 합의한 제품 동작이다. 8절의 DB 구조는 1단계, 저장·열람 수집과 view POST 확장은
2단계에서 구현했다. Today 선정·일별 조회는 3단계, 콘텐츠·카테고리 노출 수집은 4단계에서
구현했다. Weekly 집계·선정·조회는 5단계에서 구현했다. 프론트의 Today 버튼·상세 탐색은12절, Weekly 표시·카테고리 이동·실제 카드 노출·추천 유입 연결은13절의 검증 범위로 부분 완료다. 운영 추천 품질·실기기 검증은 별도다.

<a id="b-20c1208cb4ccd8ee"></a>

### 8. 데이터·코드 변경 계획

<a id="b-9b2ce0567cabdf88"></a>

### 기존 파일의 변경 위치

<a id="b-3639bf51f456b21b"></a>

| 파일·함수 | 작업과 이유 |
| --- | --- |
| `backend/app/models/content.py` — `Content` | 열람·추천 집계 필드 추가 |
| `backend/app/models/content_event.py` — `ContentEvent` | 재시도 식별, 복수 분류 스냅샷, 추천 유입 정보 지원 |
| `backend/app/repositories/event_repository.py` — `create()` 및 신규 조회 | 이벤트 생성 확장, 중복 처리, 기간별 집계 지원. `read_user_stats()` 의미 유지 |
| `backend/app/services/content_service.py` — `create_content()` 이벤트 생성 지점 | 모든 저장 경로에서 실제 소속 카테고리 스냅샷 기록 |
| `backend/app/services/content_service.py` — `record_view()` | 이벤트 중복 방지와 횟수·시각·스냅샷을 하나의 트랜잭션으로 처리 |
| `backend/app/repositories/content_repository.py` — `get_owned()`, `mark_viewed()` 및 신규 조회 | 기존 행 잠금 활용, 열람 집계 갱신, 정상 개수·추천 후보 조회 |
| `backend/app/repositories/category_repository.py` | 현재 보유 수·유효 카테고리 조회 재사용 |
| `backend/app/schemas/content.py`, `backend/app/api/v1/endpoints/contents.py` — view POST | 이벤트 ID·추천 유입 입력과 재시도 응답 계약 확장 |
| `backend/app/models/__init__.py`, `backend/app/api/v1/router.py` | 새 모델·추천 API 등록 |
| `backend/alembic/versions/` | 신규 필드·테이블·제약·인덱스·기존 열람 수 초기화 |

<a id="b-77fc5c3a0b848d64"></a>

직접 입력·공유·스크린샷에 별도 저장 이벤트 구현을 중복 추가하지 않는다.
`ShareIntakeService`, `UploadService`, `SummaryWorker`는 공통 수집과 과거 기록 보존을 검증할 경로다.

<a id="b-777e89a5925902b6"></a>

### 9. API·프론트 연동 계획

<a id="b-09cce238d720b1c7"></a>

프론트 연동 작업:

<a id="b-1d0f2946f24b3c7c"></a>

- 홈에서 Today·Weekly 조회 및 카드 유형별 표시.
- Stage 0, 빈 결과, 1~4개 Today, 0~2개 Weekly 처리.
- 실제 화면에 표시된 카드만 노출 전송. 재렌더링·재시도에는 같은 이벤트 ID 유지.
- 새 방문·상세 진입은 새 이벤트 ID 사용. 카드에서 상세까지 추천 유입 정보 전달.
- 상세에서 홈 복귀·앱 백그라운드 복귀를 새 홈 방문으로 볼지 등 방문 경계는 프론트 연동 계약에 명시하고 검증한다.
- 삭제·즐겨찾기·분류 변경 후 서버의 당일 선정 결과와 최신 카드 정보 반영.
- 현재 체크아웃의 `frontend/lib/main.dart`에서 홈의 첫 콘텐츠 열기 연결과 `_openDetail()`이 연동 대상이다.

<a id="b-44c6612b8d423e36"></a>

### 10. 구현 순서와 완료 기준

<a id="b-a1c3e3199f02542c"></a>

각 단계는 구현 → 해당 검증 → 이 문서의 진행 상태 갱신 순서로 수행한다.
기능을 구현하기 전에 이전 단계가 이미 완료된 것으로 표시하지 않는다.

<a id="b-3d6f1ce88a110ad5"></a>

| 단계 | 작업 | 검증 기준 | 상태 |
| --- | --- | --- | --- |
| 1 | DB·마이그레이션·집계 초기화 | 빈 DB 및 기존 데이터 적용, 기존 열람 수 초기화, 미확인 과거 분류 유지, 제약·삭제 호환 | 완료 — 로컬 검증, 원격 CI 미실행 |
| 2 | 저장·열람 이벤트 수집 확장 | 모든 저장 경로의 실제 복수 분류, 반복 진입과 재시도 구분, 롤백·누적 통계 유지 | 완료 — 로컬 검증, 원격 CI 미실행 |
| 3 | Today 선정·일별 배치·조회 API | Stage 경계, 점수·필터·추첨, 일별 유지·삭제·복귀, 동시 배치 생성 | 완료 — 로컬 검증, 원격 CI 미실행 |
| 4 | 콘텐츠·카테고리 노출 기록 API | 실제 노출만 집계, 재시도·동시 요청 중복 방지, 열람과 분리, 사용자 격리 | 완료 — 로컬 검증, 원격 CI 미실행 |
| 5 | Weekly 집계·카드·조회 API | 7일 경계, 고유 열람·분류 이동·삭제, 동점·중복·재발견·빈 결과 | 완료 — 로컬 검증, 원격 CI 미실행 |
| 6 | 프론트 연동 | 실제 표시·진입, 재렌더·재시도, 카드 유형, 당일 삭제·갱신 동작 | 부분 적용 — Today 버튼·최대5개 상세 연결. Weekly/실제 카드 노출 후속 |
| 7 | 통합 검증·문서·배포 확인 | 전체 회귀, DB migration·CI, 배포 후 저장·노출·열람 흐름을 각각 확인 | 미착수 |

<a id="b-32672b9edbb64423"></a>

### 11. 문서와 현재 검증 기록

<a id="b-dea21d2b7a1c1500"></a>

- 이 문서: 합의 정책, 구현 순서, 단계별 실제 진행 상태.
- [백엔드 진행 현황](../backend-mvp-plan.md): 구현 완료 범위와 남은 작업.
- [백엔드 README](../../backend/README.md): 구현 후 실제 요청·응답 계약과 실행 안내.
- [제품 지표](../product-metrics-queries.md): 구현 후 노출·추천 유입·재시도 집계 정의와 SQL.
- [카테고리 자동 분류 정책](../category-recommendation-policy.md): 기존 저장 시 자동 분류와의 경계.

<a id="b-4f93c2ab48ae2d2b"></a>

### 운영 반영 경계

<a id="b-69a405fa8bf714ec"></a>

1단계를 단독 운영 배포하지 않는다. 1단계는 초기값을 준비하고 2단계 수집 코드가 이후
`open_count`·마지막 열람 시각·이벤트 ID·스냅샷을 갱신한다. 추천 노출 관련 집계는 4단계 범위다.

<a id="b-ef937fb29b934c0d"></a>

2단계와 함께 **기존 쓰기 중지 → 마이그레이션·최종 집계 초기화 → 새 수집 코드 시작 → 쓰기 재개**
순으로 반영한다. 초기화 이후 구버전이 계속 열람을 기록하면 카운터가 어긋나므로,
Railway pre-deploy migration 성공만으로 전환이 완료됐다고 판단하지 않는다.
