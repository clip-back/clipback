"""One minimal business schema for manual backup and PostgreSQL maintenance tests."""

import hashlib


def manual_backup_seed_sql():
    """Keep the original Docker fixture SQL, values and original98 digest together."""
    return """
CREATE TABLE alembic_version(version_num text); INSERT INTO alembic_version VALUES('fixture98');
CREATE TABLE users(id int, created_at timestamptz); INSERT INTO users VALUES(1);
CREATE TABLE contents(id int, content_type text, source text, title text, summary text,
 original_url text, is_favorite bool, saved_at timestamptz, last_viewed_at timestamptz);
INSERT INTO contents VALUES(1,'screenshot','screenshot','fixture','summary',NULL,false,
 '2026-10-26T00:00:00Z',NULL);
CREATE TABLE content_assets(id int, content_id int, storage_key text, storage_backend text,
 size_bytes bigint, sha256 text);
INSERT INTO content_assets VALUES(1,1,'original.png','local',10,'DIGEST');
CREATE TABLE content_categories(content_id int, category_id int);
CREATE TABLE image_deletions(operation_id text, completed bool, attempts int, user_id int,
 content_id int, intent json, deleted_at timestamptz);
INSERT INTO image_deletions VALUES('pending98',false,0);
""".replace("DIGEST", hashlib.sha256(b"original98").hexdigest())
