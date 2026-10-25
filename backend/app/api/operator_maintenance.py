"""Restricted private maintenance commands; never exposes shell or source deletion."""

import secrets
from uuid import UUID

from fastapi import Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.services.maintenance import MaintenanceError, MaintenanceGate


class Run(BaseModel):
    run_id: UUID


class RestoreRun(Run):
    generation: int | None = None


class Finish(Run):
    operation_id: UUID


class Recovery(Finish):
    executor_stopped: bool = False


def install_control(app, config, gate=None):
    async def authorize(authorization: str = Header(default="")):
        key = config.operator_control_key
        if key is None or not secrets.compare_digest(
            authorization.encode(), ("Bearer " + key.get_secret_value()).encode()
        ):
            raise HTTPException(403, detail="operator_forbidden")

    # The read-only source listener needs no DB credentials when control is not configured.
    def get_gate():
        nonlocal gate
        if gate is None:
            if not config.database_url:
                raise HTTPException(503, detail="maintenance_configuration_missing")
            from sqlalchemy.engine import make_url

            url = make_url(config.database_url).set(drivername="postgresql+asyncpg")
            engine = create_async_engine(url)
            gate = MaintenanceGate(async_sessionmaker(engine, expire_on_commit=False))
        return gate

    async def call(method, *args, **kwargs):
        try:
            return await getattr(get_gate(), method)(*args, **kwargs)
        except MaintenanceError as exc:
            raise HTTPException(409, detail=exc.code) from None
        except Exception:
            raise HTTPException(503, detail="maintenance_unavailable") from None

    @app.get("/maintenance", dependencies=[Depends(authorize)])
    async def status():
        return await call("status")

    @app.post("/maintenance/start", dependencies=[Depends(authorize)])
    async def start(body: Run):
        return await call("start", str(body.run_id))

    @app.post("/maintenance/drain", dependencies=[Depends(authorize)])
    async def drain(body: Run):
        return await call("drain", str(body.run_id))

    @app.post("/maintenance/resume", dependencies=[Depends(authorize)])
    async def resume(body: Run):
        return await call("resume", str(body.run_id))

    @app.post("/maintenance/recover", dependencies=[Depends(authorize)])
    async def recover(body: Recovery):
        return await call(
            "recover",
            str(body.run_id),
            str(body.operation_id),
            executor_stopped=body.executor_stopped,
        )

    @app.post("/maintenance/restore/start", dependencies=[Depends(authorize)])
    async def begin_restore(body: RestoreRun):
        return await call("begin_restore", str(body.run_id), body.generation)

    @app.post("/maintenance/restore/finish", dependencies=[Depends(authorize)])
    async def finish_restore(body: Recovery):
        return await call(
            "finish_restore",
            str(body.run_id),
            str(body.operation_id),
            executor_stopped=body.executor_stopped,
        )
