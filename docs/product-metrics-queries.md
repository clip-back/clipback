# Product Metrics Queries

Clipback의 제품 이벤트는 `content_events`에 append-only로 저장한다. 아래 PostgreSQL 예시는
모두 `[start_at, end_at)` 기간을 기준으로 하며 `:start_at`, `:end_at`에는 UTC timestamp를
전달한다.

클라이언트는 `category_filter_used`, `card_clicked`, `original_link_opened`만 기록한다.
`content_created`와 `content_reopened`는 백엔드 도메인 흐름에서 기록하므로 metrics API로
전송하지 않는다.

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

`category_id IS NULL`은 전체 피드처럼 특정 카테고리 문맥 없이 발생한 클릭이다. 카드 노출
이벤트가 없으므로 이 값은 클릭 횟수이며 CTR은 아니다.

## 링크 상세 조회 대비 원본 링크 열기

기간 중 한 번 이상 상세 조회된 링크 콘텐츠 가운데 원본 링크가 한 번 이상 열린 콘텐츠의
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

집계 API, 관리자 대시보드와 외부 분석 도구 연동은 별도 작업으로 구현한다.
