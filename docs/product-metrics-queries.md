# Product Metrics Queries

Clipback의 제품 이벤트는 `content_events`에 append-only로 저장한다. 아래 PostgreSQL 예시는
모두 `[start_at, end_at)` 기간을 기준으로 하며 `:start_at`, `:end_at`에는 UTC timestamp를
전달한다.

클라이언트는 `category_filter_used`, `card_clicked`, `original_link_opened`만 기록한다.
`content_created`와 `content_reopened`는 백엔드 도메인 흐름에서 기록하므로 metrics API로
전송하지 않는다. `category_changed`도 콘텐츠 분류 변경·카테고리 삭제 시 서버가 기록한다.

2026-09-24 로컬 코드 기준 이벤트 저장과 사용자별 누적 통계 API는 구현되어 있다.
`GET /api/v1/users/me/stats`는 기간 제한 없이 저장·반복 열람 이벤트를 세며, 상세 GET은
열람을 기록하지 않는다. view POST에 UUID를 보내면 같은 사용자의 동일 요청 재시도는
한 번만 센다. 새 상세 진입에는 새 UUID를 사용한다. 본문 없음 또는 JSON `null`로 호출하는
기존 요청은 매번 기록하므로 재시도도 포함될 수 있다. 이미 저장된 과거 이벤트는 제거하지 않는다.

새 저장·열람 이벤트의 `category_ids_at_event`는 당시 실제 카테고리 ID의 정렬된 배열이다.
미분류도 실제 ID를 보존하며, 이후 분류 변경·삭제는 배열을 바꾸지 않는다. 과거 `NULL`은
당시 분류 미확인, 빈 배열은 수집 당시 분류 없음이다. 복수 분류여도 본 이벤트는 한 행이며
아래 누적 집계에 카테고리 배열을 펼쳐 중복 계산하지 않는다.
열람의 `recommendation_item_id`는 검증된 추천 유입이며 노출 증거는 아니다.
추천 횟수·노출 수집·Weekly 집계는 후속 단계에서 구현한다.

콘텐츠·카테고리 삭제 시 이벤트는 유지되지만 해당 FK는 NULL이 될 수 있다.
아래 콘텐츠 ID 기반 비율은 삭제된 콘텐츠의 이력을 복원하지 못하므로 누적 횟수와 구분한다.


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

`category_id IS NULL`은 카테고리 문맥 없이 발생한 클릭이거나, 참조 카테고리가 이후 삭제된 이벤트다. 카드 노출
이벤트가 없으므로 이 값은 클릭 횟수이며 CTR은 아니다.

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

- 실제 카드 CTR: 카드 노출 이벤트와 노출 단위 정의가 필요하다.
- 7일 리텐션: 앱 세션 또는 활성 사용자 이벤트와 기준 cohort 정의가 필요하다.
- 저장 완료 시간: 저장 시작 이벤트와 동일 시도를 연결할 식별자가 필요하다.

사용자별 누적 저장·열람 집계 API는 구현되어 있다. 이 문서의 기간별 제품 분석 집계 API, 관리자 대시보드와 외부 분석 도구 연동은 후속 범위다.
