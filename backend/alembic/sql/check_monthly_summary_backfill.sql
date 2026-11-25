WITH month_kst AS (
    SELECT date_trunc('month', statement_timestamp() AT TIME ZONE 'Asia/Seoul') AS month_start
),
bounds AS (
    SELECT month_start AT TIME ZONE 'Asia/Seoul' AS starts_at,
           (month_start + interval '1 month') AT TIME ZONE 'Asia/Seoul' AS ends_at
    FROM month_kst
),
photo_events AS (
    SELECT c.id, c.saved_at,
           CASE WHEN pg_input_is_valid(e.metadata_json, 'jsonb')
                THEN CAST(e.metadata_json AS jsonb)
           END AS metadata
    FROM content_events e
    JOIN contents c ON c.id = e.content_id
    CROSS JOIN bounds b
    WHERE c.content_type = 'screenshot' AND e.event_type = 'content_created'
      AND e.created_at >= b.starts_at AND e.created_at < b.ends_at
)
SELECT count(*) AS photo_events,
       count(*) FILTER (WHERE p.metadata IS NULL) AS unparseable_metadata,
       (
           SELECT count(*)
           FROM contents c
           JOIN summary_jobs j ON j.content_id = c.id
           CROSS JOIN bounds b
           WHERE c.content_type = 'link' AND j.status IN ('queued', 'processing', 'completed')
             AND c.saved_at >= b.starts_at AND c.saved_at < b.ends_at
       ) AS eligible_links,
       count(DISTINCT p.id) FILTER (
           WHERE p.metadata ->> 'ocr_status' = 'success'
             AND p.saved_at >= b.starts_at AND p.saved_at < b.ends_at
       ) AS eligible_screenshots
FROM photo_events p
CROSS JOIN bounds b;
