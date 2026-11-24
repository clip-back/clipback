-- Roll back the monthly-limit release before redeploying the old API image.
DO $rollback$
BEGIN
    LOCK TABLE alembic_version IN SHARE ROW EXCLUSIVE MODE;
    IF (SELECT count(*) FROM alembic_version) <> 1
       OR NOT EXISTS (SELECT 1 FROM alembic_version WHERE version_num = '202611230026') THEN
        RAISE EXCEPTION 'Expected only Alembic revision 202611230026';
    END IF;

    UPDATE summary_jobs SET error_code = 'daily_limit_exceeded'
    WHERE error_code = 'monthly_limit_exceeded';

    ALTER TABLE contents
        DROP CONSTRAINT ck_contents_screenshot_summary_skip_reason,
        DROP COLUMN screenshot_summary_skip_reason;
    DROP TABLE usage_records;

    UPDATE alembic_version SET version_num = '202611170023'
    WHERE version_num = '202611230026';
END;
$rollback$;
