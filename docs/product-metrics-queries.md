# Product Metrics Queries

Clipback의 제품 이벤트는 `content_events`에 append-only로 저장한다. 아래 PostgreSQL 예시는
모두 `[start_at, end_at)` 기간을 기준으로 하며 `:start_at`, `:end_at`에는 UTC timestamp를
전달한다.

클라이언트는 `category_filter_used`, `card_clicked`, `original_link_opened`만 기록한다.
`content_created`와 `content_reopened`는 백엔드 도메인 흐름에서 기록하므로 metrics API로
전송하지 않는다. `category_changed`도 콘텐츠 분류 변경·카테고리 삭제 시 서버가 기록한다.

2026-09-25 로컬 코드 기준 이벤트 저장과 사용자별 누적 통계 API는 구현되어 있다.
`GET /api/v1/users/me/stats`는 기간 제한 없이 저장·반복 열람 이벤트를 세며, 상세 GET은
열람을 기록하지 않는다. view POST에 UUID를 보내면 같은 사용자의 동일 요청 재시도는
한 번만 센다. 새 상세 진입에는 새 UUID를 사용한다. 본문 없음 또는 JSON `null`로 호출하는
기존 요청은 매번 기록하므로 재시도도 포함될 수 있다. 이미 저장된 과거 이벤트는 제거하지 않는다.

새 저장·열람 이벤트의 `category_ids_at_event`는 당시 실제 카테고리 ID의 정렬된 배열이다.
미분류도 실제 ID를 보존하며, 이후 분류 변경·삭제는 배열을 바꾸지 않는다. 과거 `NULL`은
당시 분류 미확인, 빈 배열은 수집 당시 분류 없음이다. 복수 분류여도 본 이벤트는 한 행이며
아래 누적 집계에 카테고리 배열을 펼쳐 중복 계산하지 않는다.
열람의 `recommendation_item_id`는 검증된 추천 유입이며 노출 증거는 아니다.
추천 노출은 별도 `recommendation_exposures`에 저장한다. Weekly는 당시 카테고리별 행동을
집계하고 조회마다 새 배치·항목을 저장하지만 이벤트나 카운터는 증가시키지 않는다.
Today 조회는 당일 최초 비어 있지 않은 배치만 저장하며 이벤트·노출·열람/추천 카운터를
늘리지 않는다. 추천 항목 ID를 연결한 실제 view POST는 기존 열람 이벤트 집계에 포함된다.

콘텐츠·카테고리 삭제 시 이벤트는 유지되지만 해당 FK는 NULL이 될 수 있다.
아래 콘텐츠 ID 기반 비율은 삭제된 콘텐츠의 이력을 복원하지 못하므로 누적 횟수와 구분한다.

## 추천 카드 노출

인증된 `POST /api/v1/recommendations/exposures`에 `client_event_id` UUID와
`recommendation_item_id` 정수를 필수로 보낸다. 같은 사용자·UUID·항목의 재전송은 같은
201 응답과 최초 시각을 반환하며 한 번만 센다. 다른 항목에 UUID를 재사용하면 409다.
대상 삭제 후에도 이미 성공한 재시도는 성공하고, 새 UUID로 삭제 대상을 기록하면 404다.
새 방문에서 다시 표시한 카드는 새 UUID로 기록한다. 같은 방문의 재렌더링에는 ID를 유지한다.

`recommended_at`은 대상 잠금 이후 서버에서 처리한 UTC 시각이다. 전송 지연이 있으면
실제 클라이언트 표시 시각과 다를 수 있다. 프론트의 실제 화면 노출 전송은 6단계 범위다.
콘텐츠 노출만 해당 콘텐츠의 추천 횟수·마지막 시각·위치를 갱신한다. 카테고리 카드 노출은
소속 콘텐츠 노출로 펼치지 않는다. 노출은 기존 저장·열람 이벤트와 누적 통계에 포함하지 않는다.

아래 쿼리는 실제 대상 테이블을 조인하지 않아 대상 삭제 후에도 원래 대상 ID와 노출 수를 보존한다.
`target_kind`와 함께 ID를 해석한다. 콘텐츠와 카테고리의 같은 정수 ID는 다른 대상이다.

```sql
SELECT
    exposure.user_id,
    batch.type AS surface,
    item.target_kind,
    item.target_id_snapshot,
    COUNT(*) AS exposures,
    MAX(exposure.recommended_at) AS last_exposed_at
FROM recommendation_exposures AS exposure
JOIN recommendation_batch_items AS item ON item.id = exposure.recommendation_item_id
JOIN recommendation_batches AS batch ON batch.id = item.batch_id
WHERE exposure.user_id = batch.user_id
  AND exposure.recommended_at >= :start_at
  AND exposure.recommended_at < :end_at
GROUP BY exposure.user_id, batch.type, item.target_kind, item.target_id_snapshot;
```


## Weekly 카테고리 행동 집계

Weekly는 KST 오늘을 포함한 7개 날짜의 첫날 00시부터 잠금 이후 서버 현재 시각까지의
`[start_at, end_at)`을 사용한다. 저장은 이벤트 행 수, 열람은 카테고리별 고유 콘텐츠 수다.
반복 열람은 수를 늘리지 않지만 최근 열람 시각에 반영된다. 현재 관계는 보유 수와 빈 카테고리
판별에만 사용하며 과거 이벤트는 배열 스냅샷으로 연결한다. NULL·빈 배열은 활동 없음이다.
분류를 이동한 콘텐츠도 현재 존재하면 과거 카테고리에서 집계하며, 그 카테고리가 현재 비어
있으면 후보에서 제외한다. 삭제된 콘텐츠와 타 사용자 데이터는 집계하지 않는다.

아래 SQL은 단일 조회 시점의 분석 예시다. 실제 서비스는 사용자·콘텐츠 잠금을 먼저 획득하고
모든 콘텐츠 집계에 확보한 ID 집합을 적용해 도중에 저장된 콘텐츠가 섞이지 않도록 한다.

```sql
WITH eligible AS (
    SELECT category.id, COUNT(content.id) AS content_count,
           MAX(content.saved_at) AS last_saved_at
    FROM categories AS category
    JOIN content_categories AS relation ON relation.category_id = category.id
    JOIN contents AS content ON content.id = relation.content_id
    WHERE category.user_id = :user_id
      AND content.user_id = :user_id
      AND category.name <> '미분류'
    GROUP BY category.id
), activity AS (
    SELECT category.id,
           COUNT(event.id) FILTER (WHERE event.event_type = 'content_created') AS saved_count,
           COUNT(DISTINCT event.content_id)
               FILTER (WHERE event.event_type = 'content_reopened') AS viewed_count,
           MAX(event.created_at)
               FILTER (WHERE event.event_type = 'content_created') AS last_saved_event_at,
           MAX(event.created_at)
               FILTER (WHERE event.event_type = 'content_reopened') AS last_viewed_event_at
    FROM eligible AS category
    JOIN content_events AS event ON category.id = ANY(event.category_ids_at_event)
    JOIN contents AS content ON content.id = event.content_id
    WHERE event.user_id = :user_id
      AND content.user_id = :user_id
      AND event.event_type IN ('content_created', 'content_reopened')
      AND event.created_at >= :start_at AND event.created_at < :end_at
    GROUP BY category.id
)
SELECT eligible.*, COALESCE(activity.saved_count, 0) AS saved_count,
       COALESCE(activity.viewed_count, 0) AS viewed_count,
       activity.last_saved_event_at, activity.last_viewed_event_at
FROM eligible
LEFT JOIN activity USING (id);
```

저장·열람 순위는 행동 수→최근 해당 이벤트 시각→현재 보유 수→완전 동점 랜덤이다.
반환 순서는 MOST_SAVED→MOST_VIEWED→REDISCOVERY이며 각 카테고리는 한 번만 선정한다.
행동이 없는 자리는 재발견으로 채운다. 재발견은 같은 기간에 본인 Weekly 카테고리 카드 노출이
없는 후보를 우선하고, 모두 노출됐다면 카테고리별 `MAX(recommended_at)`이 가장 오래된 후보를
선정한다. 원본 노출과 행동 행을 직접 함께 조인해 집계 건수를 부풀리지 않는다.

Weekly 조회는 저장·열람·노출 이벤트나 누적 통계를 갱신하지 않는다. 프론트는 같은 홈 방문의
추천 항목 ID를 유지해 실제 노출 재전송에 사용한다. 조회 재시도로 새 배치가 만들어져도
그 자체를 노출로 세지 않는다.

2026-09-25 로컬 Python 3.12.7·격리 PostgreSQL 17.7에서 전체 857개 테스트가 통과했다.
신규 70개는 순수 선정 31개·API/집계 20개·독립 연결 동시성 19개이며, 스냅샷·중복 배열·
삭제·사용자 격리·조회 무집계를 확인했다. 위 Weekly SQL도 별도 검증 DB에서 실행했다.
Ruff·compileall·빈 DB upgrade/check·Git diff 검사를 통과했다. 프론트 실제 전송·원격 CI·
실기기·운영 검증은 포함하지 않는다.

## 사용자별 저장 수와 최초 저장

```sql
SELECT
    user_id,
    COUNT(*) AS saves,
    MIN(created_at) AS first_saved_at
FROM content_events
WHERE event_type = 'content_created'
  AND created_at >= :start_at
  AND created_at < :end_at
GROUP BY user_id;
```

## 콘텐츠 재열람률

기간 중 저장된 사용자-콘텐츠 쌍 가운데 같은 기간에 한 번 이상 재열람된 비율이다.

```sql
WITH created AS (
    SELECT DISTINCT user_id, content_id
    FROM content_events
    WHERE event_type = 'content_created'
      AND created_at >= :start_at
      AND created_at < :end_at
),
reopened AS (
    SELECT DISTINCT user_id, content_id
    FROM content_events
    WHERE event_type = 'content_reopened'
      AND created_at >= :start_at
      AND created_at < :end_at
)
SELECT
    COUNT(reopened.content_id)::double precision / NULLIF(COUNT(created.content_id), 0)
        AS content_reopen_rate
FROM created
LEFT JOIN reopened USING (user_id, content_id);
```

## 카테고리 필터 사용

```sql
SELECT
    category_id,
    COUNT(*) AS filter_uses,
    COUNT(DISTINCT user_id) AS users
FROM content_events
WHERE event_type = 'category_filter_used'
  AND created_at >= :start_at
  AND created_at < :end_at
GROUP BY category_id
ORDER BY filter_uses DESC;
```

## 카드 클릭과 카테고리 문맥

```sql
SELECT
    category_id,
    COUNT(*) AS card_clicks,
    COUNT(DISTINCT user_id) AS users,
    COUNT(DISTINCT content_id) AS contents
FROM content_events
WHERE event_type = 'card_clicked'
  AND created_at >= :start_at
  AND created_at < :end_at
GROUP BY category_id
ORDER BY card_clicks DESC;
```

`category_id IS NULL`은 카테고리 문맥 없이 발생한 클릭이거나, 참조 카테고리가 이후 삭제된 이벤트다.
이 클릭 이벤트는 개별 추천 노출과 연결되지 않으므로 이 값은 클릭 횟수이며 CTR은 아니다.

## 링크 상세 조회 대비 원본 링크 열기

기간 중 view POST로 재열람이 기록된 현재 남아 있는 링크 콘텐츠 가운데 원본 링크가 한 번 이상 열린 콘텐츠의
비율이다.

```sql
WITH viewed_links AS (
    SELECT DISTINCT event.user_id, event.content_id
    FROM content_events AS event
    JOIN contents AS content ON content.id = event.content_id
    WHERE event.event_type = 'content_reopened'
      AND content.content_type = 'link'
      AND event.created_at >= :start_at
      AND event.created_at < :end_at
),
opened_links AS (
    SELECT DISTINCT user_id, content_id
    FROM content_events
    WHERE event_type = 'original_link_opened'
      AND created_at >= :start_at
      AND created_at < :end_at
)
SELECT
    COUNT(opened_links.content_id)::double precision
        / NULLIF(COUNT(viewed_links.content_id), 0) AS original_link_open_rate
FROM viewed_links
LEFT JOIN opened_links USING (user_id, content_id);
```

## AI 추천과 미분류 할당 비율

```sql
SELECT
    metadata_json::jsonb ->> 'category_assignment_method' AS assignment_method,
    COUNT(*) AS contents,
    COUNT(*)::double precision / SUM(COUNT(*)) OVER () AS share
FROM content_events
WHERE event_type = 'content_created'
  AND created_at >= :start_at
  AND created_at < :end_at
GROUP BY assignment_method
ORDER BY contents DESC;
```

## 현재 계산할 수 없는 지표

- 실제 카드 CTR: 프론트 노출 수집과 개별 노출에 대한 클릭 연결이 필요하다.
  추천 항목은 여러 방문에서 반복 노출될 수 있어 항목 ID만 연결한 열람 수를 노출별 클릭 수로 간주하지 않는다.
- 7일 리텐션: 앱 세션 또는 활성 사용자 이벤트와 기준 cohort 정의가 필요하다.
- 저장 완료 시간: 저장 시작 이벤트와 동일 시도를 연결할 식별자가 필요하다.

사용자별 누적 저장·열람 집계 API는 구현되어 있다. 이 문서의 기간별 제품 분석 집계 API, 관리자 대시보드와 외부 분석 도구 연동은 후속 범위다.
