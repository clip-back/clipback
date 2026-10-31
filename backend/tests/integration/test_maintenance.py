"""Public/private HTTP maintenance contract over independent committed PostgreSQL sessions."""

import asyncio
import os
from uuid import uuid4

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture(autouse=True)
async def isolated_control_records():
    url = os.environ.get("MAINTENANCE_TEST_DATABASE_URL")
    if not url:
        pytest.skip("isolated MAINTENANCE_TEST_DATABASE_URL required")
    # This ticket owns a separate synthetic DB, never the shared fixture or production DB.
    from sqlalchemy.engine import make_url

    assert make_url(url).database == "clipback_maintenance100"
    engine = create_async_engine(url)
    async with engine.begin() as db:
        await db.execute(text("DELETE FROM maintenance_operations"))
        await db.execute(text("DELETE FROM maintenance_events"))
        await db.execute(
            text(
                "UPDATE maintenance_state SET phase='open',run_id=NULL,"
                "generation=0,drain_deadline=NULL,result=NULL WHERE id=1"
            )
        )
    yield
    await engine.dispose()


async def test_private_control_drains_admitted_http_and_requires_explicit_resume(tmp_path):
    from app.core.operator_source_config import SourceSettings
    from app.main import create_app
    from app.operator import create_operator_app
    from app.services.maintenance import MaintenanceGate

    url = os.environ.get("MAINTENANCE_TEST_DATABASE_URL")
    if not url:
        pytest.skip("isolated MAINTENANCE_TEST_DATABASE_URL required")
    engine = create_async_engine(url)
    gate = MaintenanceGate(async_sessionmaker(engine, expire_on_commit=False))
    run = str(uuid4())
    config = SourceSettings(
        storage_root=tmp_path,
        operator_source_id="test100",
        operator_read_key="read-key-123456789",
        operator_control_key="control-key-123456789",
    )
    operator = create_operator_app(config, maintenance=gate)
    public = create_app(maintenance=gate)
    started, finish = asyncio.Event(), asyncio.Event()

    @public.get("/slow")
    async def slow():
        started.set()
        await finish.wait()
        return {"done": True}

    headers = {"Authorization": "Bearer control-key-123456789"}
    async with (
        httpx.AsyncClient(transport=httpx.ASGITransport(app=public), base_url="http://app") as app,
        httpx.AsyncClient(
            transport=httpx.ASGITransport(app=operator), base_url="http://operator"
        ) as op,
    ):
        task = asyncio.create_task(app.get("/slow"))
        await started.wait()
        assert (await op.post("/maintenance/start", headers=headers, json={"run_id": run})).json()[
            "phase"
        ] == "draining"
        assert (await app.get("/api/v1/categories")).status_code == 503
        assert (await app.get("/api/v1/health")).status_code == 200
        assert (
            await op.post("/maintenance/resume", headers=headers, json={"run_id": run})
        ).status_code == 409
        finish.set()
        assert (await task).status_code == 200
        assert (await op.post("/maintenance/drain", headers=headers, json={"run_id": run})).json()[
            "phase"
        ] == "frozen"
        restarted = create_app(maintenance=MaintenanceGate(async_sessionmaker(engine)))
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=restarted), base_url="http://restart"
        ) as app2:
            assert (await app2.get("/")).status_code == 503
        assert (await op.post("/maintenance/resume", headers=headers, json={"run_id": run})).json()[
            "phase"
        ] == "open"
        assert (await app.get("/")).status_code == 200
        for token in ["read-key-123456789", "app-token"]:
            assert (
                await op.post(
                    "/maintenance/start",
                    headers={"Authorization": "Bearer " + token},
                    json={"run_id": str(uuid4())},
                )
            ).status_code == 403
    await engine.dispose()


async def test_deadline_failure_survives_late_drain_and_process_death(tmp_path, monkeypatch):
    import subprocess
    import sys

    from app.core.operator_source_config import SourceSettings
    from app.operator import create_operator_app
    from app.services import maintenance

    url = os.environ.get("MAINTENANCE_TEST_DATABASE_URL")
    if not url:
        pytest.skip("isolated MAINTENANCE_TEST_DATABASE_URL required")
    engine = create_async_engine(url)
    gate = maintenance.MaintenanceGate(async_sessionmaker(engine, expire_on_commit=False))
    config = SourceSettings(
        storage_root=tmp_path,
        operator_source_id="test100",
        operator_read_key="read-key-123456789",
        operator_control_key="control-key-123456789",
    )
    op_app = create_operator_app(config, maintenance=gate)
    headers = {"Authorization": "Bearer control-key-123456789"}
    run = str(uuid4())
    monkeypatch.setattr(maintenance, "DRAIN_SECONDS", 0.03)
    child_code = """
import asyncio,os
from sqlalchemy.ext.asyncio import create_async_engine,async_sessionmaker
from app.services.maintenance import MaintenanceGate
async def main():
 engine=create_async_engine(os.environ['MAINTENANCE_TEST_DATABASE_URL'])
 gate=MaintenanceGate(async_sessionmaker(engine,expire_on_commit=False))
 async with gate.operation('independent-process'):
  print('admitted',flush=True)
  await asyncio.sleep(120)
asyncio.run(main())
"""
    child = subprocess.Popen([sys.executable, "-c", child_code], stdout=subprocess.PIPE, text=True)
    try:
        assert await asyncio.to_thread(child.stdout.readline) == "admitted\n"
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=op_app), base_url="http://op"
        ) as op:
            await op.post("/maintenance/start", headers=headers, json={"run_id": run})
            child.kill()
            child.wait(timeout=5)
            # A dead executor cannot be auto-expired based on loss of a DB connection.
            response = await op.post("/maintenance/drain", headers=headers, json={"run_id": run})
            assert response.status_code == 409
            status = (await op.get("/maintenance", headers=headers)).json()
            assert status["phase"] == "draining" and status["result"] == "drain_timeout"
            receipt = status["operations"][0]["id"]
            recover = {"run_id": run, "operation_id": receipt}
            assert (
                await op.post("/maintenance/recover", headers=headers, json=recover)
            ).status_code == 409
            recover["executor_stopped"] = True
            assert (
                await op.post("/maintenance/recover", headers=headers, json=recover)
            ).status_code == 200
            assert (
                await op.post("/maintenance/drain", headers=headers, json={"run_id": run})
            ).status_code == 409
            await op.post("/maintenance/resume", headers=headers, json={"run_id": run})
        # Even with no admitted work, an expired acquisition must not become frozen.
        run = str(uuid4())
        await gate.start(run)
        await asyncio.sleep(0.05)
        with pytest.raises(maintenance.MaintenanceError, match="maintenance_drain_timeout"):
            await gate.drain(run)
        await gate.resume(run)
    finally:
        if child.poll() is None:
            child.kill()
            child.wait(timeout=5)
        await engine.dispose()


async def test_background_completion_and_restore_receipt_block_resume(tmp_path):
    from fastapi import BackgroundTasks
    from fastapi.responses import JSONResponse

    from app.main import create_app
    from app.services.maintenance import MaintenanceError, MaintenanceGate

    engine = create_async_engine(os.environ["MAINTENANCE_TEST_DATABASE_URL"])
    gate = MaintenanceGate(async_sessionmaker(engine, expire_on_commit=False))
    app = create_app(maintenance=gate)
    started, released = asyncio.Event(), asyncio.Event()

    async def update_after_response():
        started.set()
        await released.wait()
        (tmp_path / "finished").write_text("business change finished")

    @app.get("/background")
    async def background(tasks: BackgroundTasks):
        tasks.add_task(update_after_response)
        return JSONResponse({"accepted": True}, background=tasks)

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://app"
    ) as http:
        pending = asyncio.create_task(http.get("/background"))
        await started.wait()
        run_id = str(uuid4())
        await gate.start(run_id)
        draining = asyncio.create_task(gate.drain(run_id))
        await asyncio.sleep(0.02)
        assert not draining.done()
        assert not (tmp_path / "finished").exists()
        released.set()
        await pending
        frozen = await draining
        assert frozen["phase"] == "frozen" and (tmp_path / "finished").is_file()
        restore = await gate.begin_restore(run_id, frozen["generation"])
        with pytest.raises(MaintenanceError, match="maintenance_operations_active"):
            await gate.resume(run_id)
        with pytest.raises(MaintenanceError, match="executor_stop_confirmation_required"):
            await gate.finish_restore(run_id, restore["operation_id"])
        await gate.finish_restore(run_id, restore["operation_id"], executor_stopped=True)
        assert (await gate.resume(run_id))["phase"] == "open"
    await engine.dispose()


async def test_cancelled_mutating_thread_cannot_be_declared_drained(tmp_path, monkeypatch):
    import threading

    from app.main import create_app
    from app.services import maintenance

    engine = create_async_engine(os.environ["MAINTENANCE_TEST_DATABASE_URL"])
    gate = maintenance.MaintenanceGate(async_sessionmaker(engine, expire_on_commit=False))
    app = create_app(maintenance=gate)
    started, release, ended = threading.Event(), threading.Event(), threading.Event()

    def write_later():
        started.set()
        release.wait(10)
        (tmp_path / "thread-write").write_text("finished")
        ended.set()

    @app.get("/thread")
    async def thread():
        await asyncio.to_thread(write_later)
        return {"done": True}

    monkeypatch.setattr(maintenance, "DRAIN_SECONDS", 0.05)
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://app"
        ) as http:
            pending = asyncio.create_task(http.get("/thread"))
            assert await asyncio.to_thread(started.wait, 5)
            pending.cancel()
            with pytest.raises(asyncio.CancelledError):
                await pending
            run_id = str(uuid4())
            await gate.start(run_id)
            with pytest.raises(maintenance.MaintenanceError, match="maintenance_drain_timeout"):
                await gate.drain(run_id)
            status = await gate.status()
            assert status["operations"] and not ended.is_set()
            assert (await http.get("/")).status_code == 503
            release.set()
            assert await asyncio.to_thread(ended.wait, 5)
            await gate.recover(run_id, status["operations"][0]["id"], executor_stopped=True)
            await gate.resume(run_id)
    finally:
        release.set()
        await engine.dispose()


async def test_summary_worker_finishes_admitted_result_before_freeze():
    from types import SimpleNamespace

    from sqlalchemy import delete, select

    from app.core.config import settings
    from app.integrations.youtube_summary_client import VideoSummary
    from app.models.content import Content, ContentType
    from app.models.summary_job import SummaryJob
    from app.models.user import User
    from app.services.maintenance import MaintenanceGate
    from app.services.summary_worker import SummaryWorker

    engine = create_async_engine(os.environ["MAINTENANCE_TEST_DATABASE_URL"])
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    gate = MaintenanceGate(sessions)
    async with sessions() as db:
        owner = User(display_name="maintenance fixture")
        db.add(owner)
        await db.flush()
        content = Content(
            user_id=owner.id, content_type=ContentType.LINK, title="before", summary="before"
        )
        db.add(content)
        await db.flush()
        db.add(
            SummaryJob(
                content_id=content.id,
                kind="youtube",
                target_id="dQw4w9WgXcQ",
                status="queued",
                model="fixture",
                apply_title=True,
                apply_summary=True,
                apply_category=False,
            )
        )
        await db.commit()
    entered, release = asyncio.Event(), asyncio.Event()

    async def summarize(*args):
        entered.set()
        await release.wait()
        return VideoSummary("after", "finished summary", None, {})

    worker = SummaryWorker(
        sessions,
        SimpleNamespace(summarize=summarize),
        settings.model_copy(update={"youtube_summary_enabled": True}),
        maintenance=gate,
    )
    try:
        pending = asyncio.create_task(worker.run_once())
        await entered.wait()
        run = str(uuid4())
        await gate.start(run)
        assert await worker.run_once() is False
        draining = asyncio.create_task(gate.drain(run))
        await asyncio.sleep(0.02)
        assert not draining.done()
        release.set()
        assert await pending is True
        assert (await draining)["phase"] == "frozen"
        async with sessions() as db:
            assert await db.scalar(select(Content.title).where(Content.id == content.id)) == "after"
            assert (
                await db.scalar(
                    select(SummaryJob.status).where(SummaryJob.content_id == content.id)
                )
                == "completed"
            )
        await gate.resume(run)
    finally:
        async with sessions() as db:
            await db.execute(delete(Content).where(Content.id == content.id))
            await db.execute(delete(User).where(User.id == owner.id))
            await db.commit()
        await engine.dispose()
