-- Shared by Alembic and the post-deployment Railway SQL console.
WITH month_kst AS (
    SELECT date_trunc('month', statement_timestamp() AT TIME ZONE 'Asia/Seoul') AS month_start
),
bounds AS (
    SELECT month_start AT TIME ZONE 'Asia/Seoul' AS starts_at,
           (month_start + interval '1 month') AT TIME ZONE 'Asia/Seoul' AS ends_at
    FROM month_kst
),
missing_contents AS MATERIALIZED (
    SELECT c.id, c.user_id, c.saved_at, c.content_type
    FROM users u
    JOIN contents c ON c.user_id = u.id
    CROSS JOIN bounds b
    WHERE c.saved_at >= b.starts_at AND c.saved_at < b.ends_at
      AND NOT EXISTS (
          SELECT 1 FROM usage_records r WHERE r.content_id = c.id AND r.kind = 'ai_summary'
      )
      AND (
          (c.content_type = 'link' AND EXISTS (
              SELECT 1 FROM summary_jobs j WHERE j.content_id = c.id
                AND j.status IN ('queued', 'processing', 'completed')
          ))
          OR (c.content_type = 'screenshot' AND EXISTS (
              SELECT 1
              FROM content_events e
              WHERE e.content_id = c.id AND e.event_type = 'content_created'
                AND e.created_at >= b.starts_at AND e.created_at < b.ends_at
                AND CASE WHEN pg_input_is_valid(e.metadata_json, 'jsonb')
                         THEN CAST(e.metadata_json AS jsonb) ->> 'ocr_status' = 'success'
                         ELSE false
                    END
          ))
      )
    -- Take FK locks before the job lock, in the order used by worker finalization.
    ORDER BY u.id, c.id
    FOR KEY SHARE OF u, c
),
missing_links AS (
    SELECT c.id, c.user_id, c.saved_at
    FROM missing_contents c
    JOIN summary_jobs j ON j.content_id = c.id
    WHERE c.content_type = 'link' AND j.status IN ('queued', 'processing', 'completed')
    -- Recheck the status after waiting for a worker that may have finalized the job.
    ORDER BY c.user_id, c.id
    FOR NO KEY UPDATE OF j
),
removed AS (
    DELETE FROM usage_records r USING summary_jobs j
    WHERE r.content_id = j.content_id AND r.kind = 'ai_summary'
      AND j.status IN ('failed', 'skipped')
    RETURNING 1
),
inserted AS (
    INSERT INTO usage_records (user_id, content_id, kind, recorded_at)
    SELECT user_id, id, 'ai_summary', saved_at FROM missing_links
    UNION ALL
    SELECT user_id, id, 'ai_summary', saved_at FROM missing_contents WHERE content_type = 'screenshot'
    ON CONFLICT (content_id) WHERE kind = 'ai_summary' AND content_id IS NOT NULL DO NOTHING
    RETURNING 1
)
SELECT (SELECT count(*) FROM inserted) AS inserted,
       (SELECT count(*) FROM removed) AS removed;
