"""Read-only snapshot, executed inside the source or isolated restored API.

Input JSON arrives on stdin, never argv. Output is PRIVATE backup metadata and
must go to a mode-0600 file, not a terminal/log. It contains no tokens or secrets.
"""

import asyncio
import hashlib
import json
import os
import re
import sys
import urllib.request
from datetime import UTC, datetime
from urllib.error import HTTPError

from sqlalchemy import text

# This source is embedded into the API image matching an older backup revision.
# Keep the host error type while allowing images predating the operator package.
try:
    from scripts.check_backup_restore import CheckError
except ModuleNotFoundError as exc:
    if exc.name != "scripts.check_backup_restore":
        raise

    class CheckError(Exception):
        """Fixed snapshot error codes in historical API images."""


# Backup wire contract: operational records are excluded even when the matching
# historical API image predates the module that implements maintenance.
CONTROL_TABLES = frozenset({"maintenance_state", "maintenance_operations", "maintenance_events"})


def fingerprint(value):
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
    ).hexdigest()


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def get(path, token):
    request = urllib.request.Request(
        f"http://127.0.0.1:{os.environ.get('PORT', '8000')}/api/v1/{path}",
        headers={"Authorization": "Bearer " + token},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.read()


def check_deleted_access(token, deleted, token_account_deleted):
    """Deleted data stays hidden: 404 for a living token account, 401 once it is deleted."""
    status = 401 if token_account_deleted else 404
    paths = ["users/me"] if token_account_deleted else []
    for item in deleted:
        paths.append(f"contents/{item['content_id']}")
        paths += [f"uploads/assets/{identifier}" for identifier in item["asset_ids"]]
        paths += [f"uploads/assets/{identifier}/access" for identifier in item["asset_ids"]]
    for path in paths:
        try:
            get(path, token)
        except HTTPError as exc:
            if exc.code != status:
                raise ValueError("Deleted original API access differs") from None
        else:
            raise ValueError("Deleted original was exposed")


async def matching_accounts(session, records):
    """Recorded accounts in this DB; a reused number with another creation time is not one."""
    matches = []
    for record in records:
        if await session.scalar(
            text("SELECT id FROM users WHERE id = :id AND created_at = :created_at"),
            {"id": record["user_id"],
             "created_at": datetime.fromisoformat(record["user_created_at"])},
        ) is not None:
            matches.append(record["user_id"])
    return matches


async def account_rows(session, user_ids):
    """Row counts per table that references the accounts. Older schemas have fewer tables."""
    rows = {"users": await session.scalar(
        text("SELECT count(*) FROM users WHERE id = ANY(:ids)"), {"ids": user_ids}
    )}
    references = await session.execute(text(
        "SELECT c.conrelid::regclass::text, quote_ident(a.attname) FROM pg_constraint c "
        "JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1] "
        "WHERE c.contype = 'f' AND c.confrelid = 'public.users'::regclass "
        "AND cardinality(c.conkey) = 1 ORDER BY 1, 2"
    ))
    for table, column in references.all():
        rows[table] = rows.get(table, 0) + await session.scalar(
            text(f"SELECT count(*) FROM {table} WHERE {column} = ANY(:ids)"), {"ids": user_ids}
        )
    return rows


async def snapshot(payload, *, runtime=None):
    if runtime is None:
        from app.core.config import settings
        from app.db.session import AsyncSessionLocal
        from app.integrations.storage_client import get_storage_client

        root, sessions, configured_storage = (
            settings.storage_root.resolve(), AsyncSessionLocal, get_storage_client()
        )
    else:
        root, sessions, configured_storage = (
            runtime.config.storage_root.resolve(), runtime.sessions, runtime.storage
        )
    version = payload.get("format_version", 1)
    # Accounts deleted by applied records (ADR 0008); the token may belong to one of them.
    deleted_accounts = payload.get("deleted_accounts", [])
    token_account_deleted = payload.get("token_account_deleted", False)
    authenticated_user = None
    if version == 2 and payload.get("verify_api", True) and not token_account_deleted:
        authenticated_user = json.loads(get("users/me", payload["access_token"]))["id"]
    async with sessions() as session:
        # Caller freezes writers or provides a protected, exported DB snapshot.
        await session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
        if payload.get("snapshot_id"):
            snapshot_id = payload["snapshot_id"]
            if not re.fullmatch(r"[0-9A-Fa-f-]+", snapshot_id):
                raise ValueError("Invalid exported snapshot")
            await session.execute(text(f"SET TRANSACTION SNAPSHOT '{snapshot_id}'"))
        names = (
            (
                await session.execute(
                    text(
                        "SELECT tablename FROM pg_tables WHERE schemaname='public' "
                        "ORDER BY tablename"
                    )
                )
            )
            .scalars()
            .all()
        )
        tables = {}
        for name in names:
            if name in CONTROL_TABLES:
                continue
            quoted = '"' + name.replace('"', '""') + '"'
            tables[name] = await session.scalar(text(f"SELECT count(*) FROM public.{quoted}"))
        revisions = list(
            (
                await session.execute(
                    text("SELECT version_num FROM alembic_version ORDER BY version_num")
                )
            ).scalars()
        )
        links = [
            list(row)
            for row in await session.execute(
                text(
                    "SELECT content_id, category_id FROM content_categories "
                    "ORDER BY content_id, category_id"
                )
            )
        ]
        assets = []
        columns = "id, content_id, storage_key"
        if version == 2:
            columns += ", storage_backend, size_bytes, sha256"
        storage = configured_storage if version == 2 else None
        for row in await session.execute(text(f"SELECT {columns} FROM content_assets ORDER BY id")):
            if version == 2:
                try:
                    content_bytes = await storage.read_file(
                        row.storage_key, backend=row.storage_backend
                    )
                except FileNotFoundError as exc:
                    raise CheckError("original_missing") from exc
                except OSError as exc:
                    raise CheckError("original_read_failed") from exc
                size, digest = len(content_bytes), hashlib.sha256(content_bytes).hexdigest()
                if (row.size_bytes is not None and size != row.size_bytes) or (
                    row.sha256 is not None and digest != row.sha256
                ):
                    raise CheckError("original_hash_mismatch")
            else:
                path = (root / row.storage_key).resolve()
                if not path.is_relative_to(root) or not path.is_file():
                    raise ValueError("Invalid or missing stored asset")
                size, digest = path.stat().st_size, file_hash(path)
            asset = {
                "id": row.id,
                "storage_key": row.storage_key,
                "size_bytes": size,
                "sha256": digest,
            }
            if version == 2:
                asset.update(
                    content_id=row.content_id,
                    storage_backend=row.storage_backend,
                    backup_key=f"originals/sha256/{digest}",
                )
            assets.append(asset)
        matches = None
        if "account_deletions" in payload:
            matches = await matching_accounts(session, payload["account_deletions"])
        if deleted_accounts and any((await account_rows(session, deleted_accounts)).values()):
            raise ValueError("Deleted account rows remain")
        sample = payload.get("sample")
        if token_account_deleted:
            # A deleted account's token opens no original; image GET is skipped.
            sample = None
        elif version == 2 and (not sample or not any(
            a["id"] == sample.get("asset_id") and a["content_id"] == sample.get("content_id")
            for a in assets
        )):
            candidates = assets
            if authenticated_user is not None:
                owned = set((await session.execute(
                    text("SELECT id FROM contents WHERE user_id=:user_id"),
                    {"user_id": authenticated_user},
                )).scalars())
                candidates = [asset for asset in assets if asset["content_id"] in owned]
            sample = ({"content_id": candidates[0]["content_id"], "asset_id": candidates[0]["id"]}
                      if candidates else None)
        content = None
        if sample:
            content = await session.scalar(
                text("SELECT to_jsonb(c) FROM contents c WHERE id=:id"),
                {"id": sample["content_id"]},
            )
            asset_content = await session.scalar(
                text("SELECT content_id FROM content_assets WHERE id=:id"),
                {"id": sample["asset_id"]},
            )
            if not content or asset_content != content["id"]:
                raise ValueError("Sample asset does not belong to content")
    expected = next((a for a in assets if sample and a["id"] == sample["asset_id"]), None)
    categories = sorted(
        category_id for content_id, category_id in links if content and content_id == content["id"]
    )

    def projection(value):
        keys = (
            "id",
            "content_type",
            "source",
            "title",
            "summary",
            "original_url",
            "is_favorite",
            "saved_at",
            "last_viewed_at",
        )
        result = {key: value[key] for key in keys}
        for key in ("saved_at", "last_viewed_at"):
            if result[key] is not None:
                result[key] = datetime.fromisoformat(result[key]).astimezone(UTC).isoformat()
        return result

    if payload.get("verify_api", True):
        token = payload["access_token"]
        check_deleted_access(token, payload.get("deleted", []), token_account_deleted)
        if sample:
            public = json.loads(get(f"contents/{sample['content_id']}", token))
            image = get(f"uploads/assets/{sample['asset_id']}", token)
            if (
                not any(asset["id"] == sample["asset_id"] for asset in public["assets"])
                or projection(public) != projection(content)
                or sorted(category["id"] for category in public["categories"]) != categories
                or hashlib.sha256(image).hexdigest() != expected["sha256"]
            ):
                raise ValueError("Authenticated API data differs")
        elif authenticated_user is None and not token_account_deleted:
            # A real authenticated request still proves the restored account/session.
            get("users/me", token)
    referenced = {
        asset["storage_key"] for asset in assets if asset.get("storage_backend", "local") == "local"
    }
    # Remote source inventory is not exposed; zero is not proof of no extra source files.
    extra = sum(
        1
        for path in root.rglob("*")
        if path.is_file() and path.name != ".clipback-source-id"
        and str(path.relative_to(root)) not in referenced
    )
    result = {
        "migration_revisions": revisions,
        "tables": tables,
        "category_links_sha256": fingerprint(links),
        "assets": assets,
        "sample": {
            "content_id": content["id"],
            "asset_id": sample["asset_id"],
            "saved_at": projection(content)["saved_at"],
            "category_ids": categories,
            "content_sha256": fingerprint(projection(content)),
        } if sample else None,
        "extra_file_count": extra,
    }
    if matches is not None:
        result["matching_accounts"] = matches
    return result


if __name__ == "__main__":
    try:
        print(json.dumps(asyncio.run(snapshot(json.load(sys.stdin))), sort_keys=True))
    except Exception:
        # Avoid tracebacks that can include URLs, response bodies or credentials.
        print('{"error":"snapshot_failed"}')
        raise SystemExit(1) from None
