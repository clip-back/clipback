"""Initialize the independent ledger, retry a bounded batch of original deletions, or delete
one account like the app's account deletion without a reason record."""

import argparse
import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.deletion_ledger_config import DeletionLedgerSettings  # noqa: E402
from app.integrations.deletion_ledger import get_deletion_ledger  # noqa: E402


class AccountNotFoundError(Exception):
    """No account with the number, including one already deleted."""


async def run(args) -> dict:
    if args.command in {"init", "checkpoint"}:
        ledger = get_deletion_ledger(DeletionLedgerSettings())
        if args.command == "init":
            return await asyncio.to_thread(ledger.initialize)
        return await asyncio.to_thread(ledger.read_verified_checkpoint)

    # Retry and account deletion touch application data and originals, so keep the full API
    # configuration contract.
    from app.db.session import AsyncSessionLocal, engine
    from app.services.image_deletion_service import retry_image_deletions
    from app.services.maintenance import MaintenanceGate

    try:
        if args.command == "delete-account":
            async with MaintenanceGate(AsyncSessionLocal).operation("account_deletion"), \
                    AsyncSessionLocal() as session:
                try:
                    return await delete_account(session, args.user_id)
                except AccountNotFoundError as exc:
                    # A settled no-op: end the admission normally, unlike uncertain failures.
                    missing = exc
            raise missing
        async with MaintenanceGate(AsyncSessionLocal).operation("deletion_retry"), \
                AsyncSessionLocal() as session:
            return await retry_image_deletions(session, limit=args.limit)
    finally:
        await engine.dispose()


async def delete_account(session, user_id: int) -> dict:
    from sqlalchemy import func, select

    from app.core.config import settings
    from app.core.exceptions import AuthenticationError
    from app.integrations.social_auth_client import get_social_auth_client
    from app.integrations.storage_client import StorageRouter
    from app.models.image_deletion import ImageDeletion
    from app.services import account_deletion_service

    try:
        operation_ids = await account_deletion_service.delete_account(
            session,
            StorageRouter(settings),
            get_social_auth_client(),
            user_id=user_id,
            reasons=None,
        )
    except AuthenticationError as exc:
        raise AccountNotFoundError from exc
    # Originals left behind stay in the cleanup list for `retry`; the account is gone.
    pending = await session.scalar(
        select(func.count()).select_from(ImageDeletion).where(
            ImageDeletion.operation_id.in_(operation_ids),
            ImageDeletion.completed.is_(False),
        )
    )
    return {"deleted": True, "pending_original_cleanup": pending}


def account_number(value: str) -> int:
    try:
        number = int(value)
    except ValueError:
        number = 0
    if number < 1:
        raise argparse.ArgumentTypeError("must be a positive account number")
    return number


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
    account = commands.add_parser(
        "delete-account", help="Delete one account like the app, without a reason record"
    )
    account.add_argument("--user-id", type=account_number, required=True)
    account.add_argument("--confirm-irreversible", action="store_true", required=True)
    args = parser.parse_args()
    try:
        result = asyncio.run(run(args))
    except AccountNotFoundError:
        print("Account not found; nothing was deleted", file=sys.stderr)
        return 1
    except Exception:
        # SDK messages/connection strings can contain endpoint or credential details.
        if args.command == "delete-account":
            message = "Account deletion failed; no successful completion is confirmed"
        else:
            message = "Image deletion operation failed; no successful completion is confirmed"
        print(message, file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 1 if result.get("pending", 0) else 0


if __name__ == "__main__":
    raise SystemExit(main())
