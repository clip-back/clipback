"""Read-only snapshot, executed inside the source or isolated restored API.

Input JSON arrives on stdin, never argv. Output is PRIVATE backup metadata and
must go to a mode-0600 file, not a terminal/log. It contains no tokens or secrets.
"""

import asyncio
import hashlib
import json
import os
import sys
import urllib.request
from datetime import UTC, datetime

from sqlalchemy import text

from app.core.config import settings
from app.db.session import AsyncSessionLocal


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


async def snapshot(payload):
    root = settings.storage_root.resolve()
    async with AsyncSessionLocal() as session:
        # Capture the source while all app writes are stopped.
        await session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
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
        for row in await session.execute(
            text("SELECT id, content_id, storage_key FROM content_assets ORDER BY id")
        ):
            path = (root / row.storage_key).resolve()
            if not path.is_relative_to(root) or not path.is_file():
                raise ValueError("Invalid or missing stored asset")
            assets.append(
                {
                    "id": row.id,
                    "storage_key": row.storage_key,
                    "size_bytes": path.stat().st_size,
                    "sha256": file_hash(path),
                }
            )
        sample = payload["sample"]
        content = await session.scalar(
            text("SELECT to_jsonb(c) FROM contents c WHERE id=:id"), {"id": sample["content_id"]}
        )
        asset_content = await session.scalar(
            text("SELECT content_id FROM content_assets WHERE id=:id"), {"id": sample["asset_id"]}
        )
        if not content or asset_content != content["id"]:
            raise ValueError("Sample asset does not belong to content")
    expected = next(asset for asset in assets if asset["id"] == sample["asset_id"])
    categories = sorted(
        category_id for content_id, category_id in links if content_id == content["id"]
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
        public = json.loads(get(f"contents/{sample['content_id']}", token))
        image = get(f"uploads/assets/{sample['asset_id']}", token)
        if (
            not any(asset["id"] == sample["asset_id"] for asset in public["assets"])
            or projection(public) != projection(content)
            or sorted(category["id"] for category in public["categories"]) != categories
            or hashlib.sha256(image).hexdigest() != expected["sha256"]
        ):
            raise ValueError("Authenticated API data differs")
    referenced = {asset["storage_key"] for asset in assets}
    extra = sum(
        1
        for path in root.rglob("*")
        if path.is_file() and str(path.relative_to(root)) not in referenced
    )
    return {
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
        },
        "extra_file_count": extra,
    }


if __name__ == "__main__":
    try:
        print(json.dumps(asyncio.run(snapshot(json.load(sys.stdin))), sort_keys=True))
    except Exception:
        # Avoid tracebacks that can include URLs, response bodies or credentials.
        print('{"error":"snapshot_failed"}')
        raise SystemExit(1) from None
