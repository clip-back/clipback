"""Initialize the independent ledger or retry a bounded batch of original deletions."""

import argparse
import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.deletion_ledger_config import DeletionLedgerSettings  # noqa: E402
from app.integrations.deletion_ledger import get_deletion_ledger  # noqa: E402


async def run(args) -> dict:
    if args.command in {"init", "checkpoint"}:
        ledger = get_deletion_ledger(DeletionLedgerSettings())
        if args.command == "init":
            return await asyncio.to_thread(ledger.initialize)
        return await asyncio.to_thread(ledger.read_verified_checkpoint)

    # Retry touches application data and originals, so keep the full API configuration contract.
    from app.db.session import AsyncSessionLocal, engine
    from app.services.image_deletion_service import retry_image_deletions

    try:
        async with AsyncSessionLocal() as session:
            return await retry_image_deletions(session, limit=args.limit)
    finally:
        await engine.dispose()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    initialize = commands.add_parser("init", help="Bootstrap a new independent ledger epoch")
    initialize.add_argument("--confirm-new-namespace", action="store_true", required=True)
    commands.add_parser("checkpoint", help="Read and verify the current ledger")
    retry = commands.add_parser(
        "retry", help="Reconcile accepted intents and retry original cleanup"
    )
    retry.add_argument("--limit", type=int, default=100, choices=range(1, 1001), metavar="1..1000")
    args = parser.parse_args()
    try:
        result = asyncio.run(run(args))
    except Exception:
        # SDK messages/connection strings can contain endpoint or credential details.
        print(
            "Image deletion operation failed; no successful completion is confirmed",
            file=sys.stderr,
        )
        return 1
    print(json.dumps(result, sort_keys=True))
    return 1 if result.get("pending", 0) else 0


if __name__ == "__main__":
    raise SystemExit(main())
