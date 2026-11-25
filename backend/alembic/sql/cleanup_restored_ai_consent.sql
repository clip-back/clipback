-- Run on the restored target after deletion ledger replay and upgrade, while writes are frozen.
BEGIN;

WITH removed AS (
    DELETE FROM ai_transfer_consents
    WHERE status = 'granted'
    RETURNING user_id
)
SELECT count(*) AS grants_removed FROM removed;

WITH cancelled AS (
    UPDATE summary_jobs
    SET status = 'skipped',
        error_code = 'ai_consent_required',
        lease_token = NULL,
        lease_expires_at = NULL
    WHERE status IN ('queued', 'processing')
    RETURNING content_id
), released AS (
    DELETE FROM usage_records
    WHERE kind = 'ai_summary' AND content_id IN (SELECT content_id FROM cancelled)
    RETURNING id
)
SELECT (SELECT count(*) FROM cancelled) AS jobs_cancelled,
       (SELECT count(*) FROM released) AS summary_records_removed;

COMMIT;
