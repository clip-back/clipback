"""Server-side explicit maintenance fallback. Requires only DATABASE_URL, never API secrets."""
import argparse
import asyncio
import json
from uuid import UUID

from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.services.maintenance import MaintenanceError, MaintenanceGate


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=None)
    database_url: str


async def run(args):
    url = make_url(Settings().database_url)
    if url.drivername not in {"postgres", "postgresql", "postgresql+asyncpg"}:
        raise MaintenanceError("postgresql_required")
    engine = create_async_engine(url.set(drivername="postgresql+asyncpg"))
    gate = MaintenanceGate(async_sessionmaker(engine, expire_on_commit=False))
    try:
        if args.command == "status":
            return await gate.status()
        run_id = str(args.run_id)
        if args.command == "start":
            await gate.start(run_id)
            return await gate.drain(run_id)
        if args.command == "resume":
            return await gate.resume(run_id)
        return await gate.recover(run_id, str(args.operation_id),
            executor_stopped=args.confirm_executor_stopped)
    finally:
        await engine.dispose()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status")
    for name in ("start", "resume", "recover"):
        item = commands.add_parser(name)
        item.add_argument("--run-id", type=UUID, required=True)
        if name == "recover":
            item.add_argument("--operation-id", type=UUID, required=True)
            item.add_argument("--confirm-executor-stopped", action="store_true", required=True)
    try:
        print(json.dumps(asyncio.run(run(parser.parse_args())), sort_keys=True))
        return 0
    except Exception as exc:
        code = exc.code if isinstance(exc, MaintenanceError) else "maintenance_unavailable"
        print(json.dumps({"passed": False, "error": code}, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
