"""Operator-only image usage and upload admission; no public administration endpoint."""

from __future__ import annotations

import argparse
import asyncio
import calendar
import json
from datetime import UTC, date, datetime
from pathlib import Path
from typing import TYPE_CHECKING

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Content
from app.models.content_asset import AssetType, ContentAsset
from app.models.image_storage_control import ImageStorageControl, ImageTransferCounter
from app.models.user import User
from app.services.image_storage_control import TRANSFER_KINDS, set_uploads_paused
from scripts.image_backup import BackupBucket

if TYPE_CHECKING:
    from app.integrations.storage_client import S3StorageClient, StorageRouter


def local_storage_usage(root: Path) -> dict | None:
    # File names/keys are intentionally never included in the report.
    if not root.is_dir():
        return None
    files = [path for path in root.rglob("*") if path.is_file() and not path.is_symlink()]
    return {"size_bytes": sum(path.stat().st_size for path in files), "objects": len(files)}


def bucket_storage_usage(storage: S3StorageClient) -> dict:
    size, count = 0, 0
    for page in storage.client.get_paginator("list_objects_v2").paginate(Bucket=storage.bucket):
        for item in page.get("Contents", []):
            size += item["Size"]
            count += 1
    return {"size_bytes": size, "objects": count}


async def usage_report(
    session: AsyncSession,
    storage: StorageRouter,
    backup: BackupBucket,
    *,
    month: date,
) -> dict:
    """Point-in-time observed storage; no source writes, prices, URLs, titles or credentials."""
    accounts = {
        user_id: {"user_id": user_id, "original_bytes": 0, "original_count": 0}
        for user_id in (await session.scalars(select(User.id).order_by(User.id))).all()
    }
    assets = (
        await session.execute(
            select(Content.user_id, ContentAsset)
            .join(
                ContentAsset,
                ContentAsset.content_id == Content.id,
            )
            .where(ContentAsset.asset_type == AssetType.SCREENSHOT)
        )
    ).all()
    for user_id, asset in assets:
        size = asset.size_bytes
        if size is None:
            size = await storage.for_backend(asset.storage_backend).file_size(asset.storage_key)
        accounts[user_id]["original_bytes"] += size
        accounts[user_id]["original_count"] += 1
    counters = {kind: {"operations": 0, "payload_bytes": 0} for kind in TRANSFER_KINDS}
    first = month.replace(day=1)
    last = first.replace(day=calendar.monthrange(first.year, first.month)[1])
    for counter in (
        await session.scalars(
            select(ImageTransferCounter).where(
                ImageTransferCounter.day >= first,
                ImageTransferCounter.day <= last,
            )
        )
    ).all():
        counters[counter.kind]["operations"] += counter.operations
        counters[counter.kind]["payload_bytes"] += counter.size_bytes
    local = await asyncio.to_thread(local_storage_usage, storage.config.storage_root)
    cloud = None
    if storage.config.s3_bucket:
        cloud = await asyncio.to_thread(bucket_storage_usage, storage.for_backend("s3"))
    backup_objects = await asyncio.to_thread(backup.list_objects)
    return {
        "generated_at": datetime.now(UTC).isoformat(),
        "month_utc": first.strftime("%Y-%m"),
        "uploads_paused": bool(await session.scalar(select(ImageStorageControl.uploads_paused))),
        "accounts": list(accounts.values()),
        "logical_originals": {
            "size_bytes": sum(account["original_bytes"] for account in accounts.values()),
            "count": len(assets),
        },
        "physical_storage": {
            "local_originals": local,
            "bucket_originals": cloud,
            "backup": {
                "size_bytes": sum(item["size_bytes"] for item in backup_objects),
                "objects": len(backup_objects),
            },
        },
        "observed_transfers": counters,
        "provider_transfer_bytes": None,
        "backup_transfer_bytes": None,
        "deletion_ledger_storage_bytes": None,
        "deletion_ledger_transfer_bytes": None,
        "actual_cost_krw": None,
        "monthly_design_goal_krw": 10_000,
        "limitations": [
            "Storage is a scan, not an atomic snapshot; concurrent changes may affect totals.",
            "Upload payloads count only committed saves; failed writes/retries are not complete.",
            "Proxy payloads are prepared response bytes, not proof the client received them.",
            "Access grants are not downloads. Direct Bucket downloads are unobserved.",
            "Network overhead, backup transfers and provider billing require provider records.",
            "Independent deletion-ledger storage and transfers are unmeasured; listed storage "
            "fields are not total image-system storage or cost.",
            "KRW 10000 is an image storage/transfer/backup design goal, not a bill or hard cap; "
            "server, database and AI costs are separate.",
        ],
    }


async def run(args):
    from app.db.session import AsyncSessionLocal, engine
    from app.integrations.storage_client import get_storage_client

    try:
        async with AsyncSessionLocal() as session:
            if args.command == "report":
                return await usage_report(
                    session,
                    get_storage_client(),
                    BackupBucket.from_config_file(args.backup_config),
                    month=args.month,
                )
            from app.services.maintenance import MaintenanceGate
            async with MaintenanceGate(AsyncSessionLocal).operation("image_admission"):
                await set_uploads_paused(session, args.command == "pause")
                return {"uploads_paused": args.command == "pause"}
    finally:
        await engine.dispose()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("pause", help="Wait for admitted saves, then reject new image saves")
    commands.add_parser("resume", help="Allow new image saves again")
    report = commands.add_parser("report", help="Report bytes separately from unknown billing")
    report.add_argument("--backup-config", type=Path, required=True)
    report.add_argument(
        "--month",
        type=lambda value: date.fromisoformat(value + "-01"),
        default=datetime.now(UTC).date().replace(day=1),
    )
    args = parser.parse_args()
    try:
        result = asyncio.run(run(args))
    except Exception:
        # Provider exceptions may include object keys, endpoint URLs or credentials.
        print(json.dumps({"passed": False, "error": "image_storage_operation_failed"}))
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
