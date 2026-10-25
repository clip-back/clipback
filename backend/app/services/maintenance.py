"""Persistent admission and explicit maintenance. Lost executors never auto-expire."""

import asyncio
import os
import socket
from contextlib import asynccontextmanager
from contextvars import ContextVar
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import select

from app.models.maintenance import MaintenanceEvent, MaintenanceOperation, MaintenanceState

DRAIN_SECONDS = 60
CONTROL_TABLES = frozenset({"maintenance_state", "maintenance_operations", "maintenance_events"})
_active = ContextVar("maintenance_admission", default=None)


class MaintenanceError(Exception):
    def __init__(self, code="maintenance_active"):
        self.code = code
        super().__init__(code)


class MaintenanceAdmissionError(MaintenanceError):
    """Admission was refused or could not be confirmed; business work never starts."""


class MaintenanceGate:
    def __init__(self, sessions):
        self.sessions = sessions
        self.executor = f"{socket.gethostname()}:{os.getpid()}:{uuid4()}"

    async def _state(self, session):
        row = await session.get(MaintenanceState, 1, with_for_update=True)
        if row is None:
            raise MaintenanceError("maintenance_state_unavailable")
        return row

    @staticmethod
    def _owner(row, run_id, generation=None):
        if row.run_id != run_id or (generation is not None and row.generation != generation):
            raise MaintenanceError("maintenance_owner_mismatch")

    @staticmethod
    def _event(session, action, run_id, operation_id=None):
        session.add(
            MaintenanceEvent(
                action=action,
                run_id=run_id,
                operation_id=operation_id,
                recorded_at=datetime.now(UTC),
            )
        )

    async def admit(self, kind):
        async with self.sessions() as session, session.begin():
            row = await self._state(session)
            if row.phase != "open":
                raise MaintenanceError()
            identifier = str(uuid4())
            session.add(
                MaintenanceOperation(
                    id=identifier,
                    kind=kind,
                    executor=self.executor,
                    registered_at=datetime.now(UTC),
                )
            )
        return identifier

    async def complete(self, identifier):
        async with self.sessions() as session, session.begin():
            await self._state(session)
            operation = await session.get(MaintenanceOperation, identifier)
            if operation is None or operation.executor != self.executor:
                raise MaintenanceError("operation_owner_mismatch")
            await session.delete(operation)

    @asynccontextmanager
    async def operation(self, kind):
        # Nested operations belong to their enclosing fully awaited operation.
        if _active.get() is not None:
            yield
            return
        try:
            identifier = await self.admit(kind)
        except Exception as exc:
            raise MaintenanceAdmissionError("maintenance_admission_unavailable") from exc
        token = _active.set(identifier)
        try:
            yield
        except BaseException:
            # Cancellation can leave a mutating to_thread call alive. Keep evidence.
            raise
        else:
            await self.complete(identifier)
        finally:
            _active.reset(token)

    async def status(self):
        async with self.sessions() as session:
            row = await session.get(MaintenanceState, 1)
            if row is None:
                raise MaintenanceError("maintenance_state_unavailable")
            operations = (await session.scalars(select(MaintenanceOperation))).all()
            result = row.result
            if (
                row.phase == "draining"
                and row.drain_deadline is not None
                and datetime.now(UTC) >= row.drain_deadline
            ):
                result = "drain_timeout"
            return {
                "phase": row.phase,
                "run_id": row.run_id,
                "generation": row.generation,
                "result": result,
                "drain_deadline": row.drain_deadline.isoformat() if row.drain_deadline else None,
                "operations": [
                    {"id": x.id, "kind": x.kind, "executor": x.executor, "run_id": x.run_id}
                    for x in operations
                ],
            }

    async def start(self, run_id):
        async with self.sessions() as session, session.begin():
            row = await self._state(session)
            if row.phase != "open":
                self._owner(row, run_id)
            else:
                if row.run_id == run_id:
                    raise MaintenanceError("maintenance_run_id_reused")
                row.phase, row.run_id = "draining", run_id
                row.generation += 1
                row.drain_deadline = datetime.now(UTC) + timedelta(seconds=DRAIN_SECONDS)
                row.result = "draining"
                self._event(session, "start", run_id)
        return await self.status()

    async def drain(self, run_id):
        try:
            async with asyncio.timeout(DRAIN_SECONDS) as deadline:
                return await self._drain(run_id, deadline)
        except TimeoutError as exc:
            # Connection/lock stalls must not extend acquisition. Persistent block survives.
            raise MaintenanceError("maintenance_drain_timeout") from exc

    async def _drain(self, run_id, deadline):
        while True:
            async with self.sessions() as session, session.begin():
                row = await self._state(session)
                self._owner(row, run_id)
                if row.phase == "frozen":
                    break
                if row.phase != "draining":
                    raise MaintenanceError("maintenance_not_draining")
                if row.result == "drain_timeout" or datetime.now(UTC) >= row.drain_deadline:
                    if row.result != "drain_timeout":
                        row.result = "drain_timeout"
                        self._event(session, "drain_timeout", run_id)
                    timed_out = True
                else:
                    timed_out = False
                    operation = await session.scalar(select(MaintenanceOperation.id).limit(1))
                    if operation is None:
                        row.phase, row.result = "frozen", "frozen"
                        self._event(session, "frozen", run_id)
                        break
            if timed_out:
                raise MaintenanceError("maintenance_drain_timeout")
            await asyncio.sleep(0.1)
        return await self.status()

    async def assert_frozen(self, run_id, generation=None):
        async with self.sessions() as session, session.begin():
            row = await self._state(session)
            self._owner(row, run_id, generation)
            if row.phase != "frozen":
                raise MaintenanceError("source_write_freeze_required")
            return row.generation

    async def begin_restore(self, run_id, generation=None):
        async with self.sessions() as session, session.begin():
            row = await self._state(session)
            self._owner(row, run_id, generation)
            if row.phase != "frozen":
                raise MaintenanceError("source_write_freeze_required")
            if await session.scalar(select(MaintenanceOperation.id).limit(1)) is not None:
                raise MaintenanceError("maintenance_operations_active")
            identifier = str(uuid4())
            session.add(
                MaintenanceOperation(
                    id=identifier,
                    kind="restore",
                    executor=self.executor,
                    run_id=run_id,
                    generation=row.generation,
                    registered_at=datetime.now(UTC),
                )
            )
            self._event(session, "restore_start", run_id, identifier)
            current_generation = row.generation
        return {"operation_id": identifier, "generation": current_generation}

    async def finish_restore(self, run_id, identifier, *, executor_stopped=False):
        if executor_stopped is not True:
            raise MaintenanceError("executor_stop_confirmation_required")
        async with self.sessions() as session, session.begin():
            row = await self._state(session)
            self._owner(row, run_id)
            operation = await session.get(MaintenanceOperation, identifier)
            if (
                operation is None
                or operation.kind != "restore"
                or operation.run_id != run_id
                or operation.generation != row.generation
            ):
                raise MaintenanceError("restore_owner_mismatch")
            # Caller confirms its child processes ended and source locks were released.
            await session.delete(operation)
            self._event(session, "restore_finished", run_id, identifier)
        return await self.status()

    async def recover(self, run_id, identifier, *, executor_stopped):
        if executor_stopped is not True:
            raise MaintenanceError("executor_stop_confirmation_required")
        async with self.sessions() as session, session.begin():
            row = await self._state(session)
            self._owner(row, run_id)
            if row.phase == "open":
                raise MaintenanceError("maintenance_required")
            operation = await session.get(MaintenanceOperation, identifier)
            if operation is None:
                raise MaintenanceError("operation_missing")
            await session.delete(operation)
            self._event(session, "executor_stopped", run_id, identifier)
        return await self.status()

    async def resume(self, run_id):
        async with self.sessions() as session, session.begin():
            row = await self._state(session)
            self._owner(row, run_id)
            if await session.scalar(select(MaintenanceOperation.id).limit(1)) is not None:
                raise MaintenanceError("maintenance_operations_active")
            row.phase, row.result = "open", "resumed"
            row.drain_deadline = None
            self._event(session, "resume", run_id)
        return await self.status()


def default_gate():
    from app.db.session import AsyncSessionLocal

    return MaintenanceGate(AsyncSessionLocal)
