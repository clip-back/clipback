"""The real host controller uses private control, a live DB lock and local Docker."""

import asyncio
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import httpx
import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.services.maintenance import MaintenanceGate
from scripts.restore_execution import prepare, run_restore
from tests.deployment.test_image_backup_docker import bucket_backup as bucket_backup

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local API image are required",
)


@pytest.fixture
def live_context(bucket_backup, monkeypatch, tmp_path):
    store, _, _, _, image = bucket_backup
    fixture = store.fixture_context
    env = fixture["env"]
    for key, value in env.items():
        if key.startswith("DELETION_LEDGER_") or key in {"DATABASE_URL", "APP_ENVIRONMENT"}:
            monkeypatch.setenv(key, value)
    with socket.socket() as address:
        address.bind(("127.0.0.1", 0))
        port = address.getsockname()[1]
    url = f"http://127.0.0.1:{port}"
    monkeypatch.setenv("OPERATOR_CONTROL_URL", url)
    monkeypatch.setenv("OPERATOR_CONTROL_KEY", "control101-private-key")
    control_env = {
        **os.environ,
        "OPERATOR_SOURCE_ID": "fixture101",
        "OPERATOR_READ_KEY": "reader101-private-key",
        "STORAGE_ROOT": str(tmp_path),
        "PYTHONPATH": str(Path(__file__).parents[2]),
    }
    private = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "app.operator:create_operator_app",
            "--factory",
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
            "--no-access-log",
        ],
        env=control_env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(100):
            try:
                r = httpx.get(
                    url + "/maintenance",
                    headers={"Authorization": "Bearer control101-private-key"},
                    trust_env=False,
                    timeout=1,
                )
                if r.status_code == 200:
                    break
            except httpx.HTTPError:
                pass
            time.sleep(0.1)
        else:
            raise AssertionError("private control did not start")
        credentials = fixture["directory"] / "restore-credentials.json"
        root = tmp_path / "runs"
        root.mkdir(mode=0o700)
        yield {
            "fixture": fixture,
            "credentials": credentials,
            "root": root,
            "image": image,
            "directory": fixture["directory"] / "materialized",
            "private": private,
            "url": url,
        }
    finally:
        private.terminate()
        private.wait(timeout=10)


async def gate_for(env):
    from sqlalchemy.engine import make_url

    engine = create_async_engine(make_url(env["DATABASE_URL"]).set(drivername="postgresql+asyncpg"))
    return engine, MaintenanceGate(async_sessionmaker(engine, expire_on_commit=False))


def test_authoritative_live_restore_finishes_receipt_and_keeps_maintenance(live_context):
    item = live_context

    async def scenario():
        engine, gate = await gate_for(item["fixture"]["env"])
        try:
            prepared = await prepare(
                item["directory"], item["credentials"], item["image"], item["root"]
            )
            run_id = prepared["run_id"]
            await gate.start(run_id)
            await gate.drain(run_id)
            result = await run_restore(Path(prepared["workspace"]), timeout_seconds=120)
            assert result["passed"], result
            assert result["live_deletion_ledger_verified"] and result["source_lock_released"]
            assert result["restore_receipt_finished"] and result["cleanup_passed"]
            assert not Path(prepared["workspace"]).exists()
            state = await gate.status()
            assert state["phase"] == "frozen" and not state["operations"]
            await gate.resume(run_id)
        finally:
            await engine.dispose()

    asyncio.run(scenario())


def slow_target_docker(tmp_path, monkeypatch, *, stubborn_descendant=False):
    import shutil

    actual = shutil.which("docker")
    directory = tmp_path / "slow-docker"
    directory.mkdir()
    marker = tmp_path / "target-created"
    descendant = tmp_path / "restore-descendant.json"
    descendant_code = (
        "import json,os,signal,time;from pathlib import Path;"
        "signal.signal(signal.SIGTERM,signal.SIG_IGN);"
        f"Path({str(descendant)!r}).write_text(json.dumps({{'pid':os.getpid(),'group':os.getpgrp()}}));"
        "time.sleep(300)"
    )
    wrapper = directory / "docker"
    wrapper.write_text(f"""#!{sys.executable}
import os,sys,subprocess
from pathlib import Path
a=sys.argv[1:]
if a[:2]==["container","create"] and "--name" in a:
 name=a[a.index("--name")+1]
 if name.startswith("clipback-recovery-") and name.endswith("-db"):
  if {stubborn_descendant!r}:
   subprocess.Popen([sys.executable,"-c",{descendant_code!r}],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  a=a[:-1]+["--entrypoint","sh",a[-1],"-c","sleep 300"]
  Path({str(marker)!r}).write_text(name)
os.execv({actual!r},[{actual!r},*a])
""")
    wrapper.chmod(0o700)
    monkeypatch.setenv("PATH", str(directory) + os.pathsep + os.environ["PATH"])
    return marker


def test_total_timeout_stops_real_child_and_daemon_container(live_context, monkeypatch, tmp_path):
    item = live_context
    marker = slow_target_docker(tmp_path, monkeypatch)

    async def scenario():
        engine, gate = await gate_for(item["fixture"]["env"])
        try:
            prepared = await prepare(
                item["directory"], item["credentials"], item["image"], item["root"]
            )
            workspace = Path(prepared["workspace"])
            owner = json.loads((workspace / "journal.json").read_text())["owner"]
            await gate.start(prepared["run_id"])
            await gate.drain(prepared["run_id"])
            result = await run_restore(workspace, timeout_seconds=8)
            assert marker.exists(), "The timeout must exercise an actual daemon-owned container"
            # The killed child must not strand its private runtime.env in the global temp root.
            import tempfile
            for temporary in Path(tempfile.gettempdir()).glob("clipback-recovery-private-*"):
                env = temporary / "runtime.env"
                assert not env.exists() or f"@{owner}-db:5432" not in env.read_text()
            assert not result["passed"] and result["error"] == "restore_timeout", result
            assert result["child_stopped"] and result["executors_stopped"]
            assert result["cleanup_passed"] and result["restore_receipt_finished"]
            state = await gate.status()
            assert state["phase"] == "frozen" and not state["operations"]
            await gate.resume(prepared["run_id"])
        finally:
            await engine.dispose()

    asyncio.run(scenario())



def test_timeout_stops_descendants_even_after_the_restore_leader_exits(
    live_context, monkeypatch, tmp_path
):
    import signal

    item = live_context
    slow_target_docker(tmp_path, monkeypatch, stubborn_descendant=True)
    descendant = tmp_path / "restore-descendant.json"

    async def scenario():
        engine, gate = await gate_for(item["fixture"]["env"])
        try:
            prepared = await prepare(
                item["directory"], item["credentials"], item["image"], item["root"]
            )
            await gate.start(prepared["run_id"])
            await gate.drain(prepared["run_id"])
            result = await run_restore(Path(prepared["workspace"]), timeout_seconds=8)
            assert descendant.exists(), "The timeout must exercise a real descendant executor"
            executor = json.loads(descendant.read_text())
            try:
                os.kill(executor["pid"], 0)
            except ProcessLookupError:
                stopped = True
            else:
                stopped = False
            assert stopped, "A terminated leader does not prove its descendant stopped"
            assert result["child_stopped"] and result["restore_receipt_finished"], result
            state = await gate.status()
            assert state["phase"] == "frozen" and not state["operations"]
            await gate.resume(prepared["run_id"])
        finally:
            if descendant.exists():
                executor = json.loads(descendant.read_text())
                try:
                    os.killpg(executor["group"], signal.SIGKILL)
                except ProcessLookupError:
                    pass
            await engine.dispose()

    asyncio.run(scenario())


def test_control_disconnect_stops_child_but_keeps_durable_recovery(
    live_context, monkeypatch, tmp_path
):
    import shutil

    item = live_context
    marker = slow_target_docker(tmp_path, monkeypatch)

    async def scenario():
        engine, gate = await gate_for(item["fixture"]["env"])
        try:
            prepared = await prepare(
                item["directory"], item["credentials"], item["image"], item["root"]
            )
            workspace = Path(prepared["workspace"])
            await gate.start(prepared["run_id"])
            await gate.drain(prepared["run_id"])
            running = asyncio.create_task(run_restore(workspace, timeout_seconds=60))
            for _ in range(200):
                if marker.exists():
                    break
                await asyncio.sleep(0.1)
            assert marker.exists()
            item["private"].terminate()
            await asyncio.to_thread(item["private"].wait, timeout=10)
            result = await running
            assert not result["passed"] and not result["restore_receipt_finished"]
            assert result["child_stopped"] and result["executors_stopped"]
            assert result["source_lock_released"] and result["cleanup_passed"]
            state = await gate.status()
            assert state["phase"] == "frozen" and len(state["operations"]) == 1
            # The server-side fallback is independent of the lost Mac control connection.
            await gate.finish_restore(
                prepared["run_id"], state["operations"][0]["id"], executor_stopped=True
            )
            await gate.resume(prepared["run_id"])
            assert not (workspace / "backup").exists()
            assert not (workspace / "credentials.json").exists()
            shutil.rmtree(workspace)
        finally:
            await engine.dispose()

    asyncio.run(scenario())


def test_lost_registration_response_retains_journal_until_authoritative_recovery(
    live_context, monkeypatch
):
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    from threading import Thread

    item = live_context
    dropped = []

    class Proxy(BaseHTTPRequestHandler):
        def do_GET(self):
            self.forward()

        def do_POST(self):
            self.forward()

        def log_message(self, *_):
            pass

        def forward(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            result = httpx.request(
                self.command,
                item["url"] + self.path,
                content=body,
                headers={
                    "Authorization": "Bearer control101-private-key",
                    "Content-Type": "application/json",
                },
                trust_env=False,
                timeout=5,
            )
            if self.path.endswith("/restore/start") and result.status_code == 200 and not dropped:
                dropped.append(True)
                self.connection.shutdown(socket.SHUT_RDWR)
                self.close_connection = True
                return
            self.send_response(result.status_code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(result.content)))
            self.end_headers()
            self.wfile.write(result.content)

    proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
    thread = Thread(target=proxy.serve_forever, daemon=True)
    thread.start()
    monkeypatch.setenv("OPERATOR_CONTROL_URL", f"http://127.0.0.1:{proxy.server_port}")

    async def scenario():
        engine, gate = await gate_for(item["fixture"]["env"])
        try:
            prepared = await prepare(
                item["directory"], item["credentials"], item["image"], item["root"]
            )
            workspace = Path(prepared["workspace"])
            await gate.start(prepared["run_id"])
            await gate.drain(prepared["run_id"])
            env = {**os.environ, "PYTHONPATH": str(Path(__file__).parents[2])}
            command = [sys.executable, "-m", "scripts.restore_execution"]
            failed = await asyncio.to_thread(
                subprocess.run,
                [*command, "run", "--workspace", str(workspace)],
                env=env,
                capture_output=True,
                text=True,
                timeout=30,
            )
            result = json.loads(failed.stdout)
            assert failed.returncode == 1 and not result["passed"]
            assert not result["restore_receipt_finished"] and workspace.exists()
            saved = json.loads((workspace / "journal.json").read_text())
            assert saved["registration_attempted"] and "operation_id" not in saved
            state = await gate.status()
            assert state["phase"] == "frozen" and len(state["operations"]) == 1
            recovered = await asyncio.to_thread(
                subprocess.run,
                [*command, "cleanup", "--workspace", str(workspace), "--confirm-executors-stopped"],
                env=env,
                capture_output=True,
                text=True,
                timeout=30,
            )
            assert recovered.returncode == 0, recovered.stdout
            report = json.loads(recovered.stdout)
            assert report["restore_receipt_finished"] and not workspace.exists()
            state = await gate.status()
            assert state["phase"] == "frozen" and not state["operations"]
            await gate.resume(prepared["run_id"])
        finally:
            await engine.dispose()

    try:
        asyncio.run(scenario())
    finally:
        proxy.shutdown()
        proxy.server_close()
        thread.join(timeout=5)


def test_cleanup_failure_blocks_resume_until_owned_executor_is_stopped(
    live_context, monkeypatch, tmp_path
):
    import shutil

    from scripts.restore_execution import cleanup_owned

    item = live_context
    marker = slow_target_docker(tmp_path, monkeypatch)
    block = tmp_path / "refuse-container-removal"
    block.write_text("synthetic fault")
    wrapper = tmp_path / "slow-docker" / "docker"
    wrapper.write_text(
        wrapper.read_text().replace(
            "os.execv(",
            f'if a[:2]==["container","rm"] and Path({str(block)!r}).exists():\n'
            " raise SystemExit(1)\nos.execv(",
        )
    )

    async def scenario():
        engine, gate = await gate_for(item["fixture"]["env"])
        try:
            prepared = await prepare(
                item["directory"], item["credentials"], item["image"], item["root"]
            )
            workspace = Path(prepared["workspace"])
            owner = json.loads((workspace / "journal.json").read_text())["owner"]
            await gate.start(prepared["run_id"])
            await gate.drain(prepared["run_id"])
            result = await run_restore(workspace, timeout_seconds=8)
            assert marker.exists()
            assert not result["passed"] and not result["cleanup_passed"]
            assert not result["executors_stopped"] and not result["restore_receipt_finished"]
            assert "container" in result["remaining_resource_kinds"]
            assert workspace.exists()
            state = await gate.status()
            assert state["phase"] == "frozen" and len(state["operations"]) == 1
            blocked = httpx.post(
                item["url"] + "/maintenance/resume",
                json={"run_id": prepared["run_id"]},
                headers={"Authorization": "Bearer control101-private-key"},
                timeout=3,
                trust_env=False,
            )
            assert blocked.status_code == 409
            block.unlink()
            cleaned = await asyncio.to_thread(cleanup_owned, owner)
            assert cleaned["cleanup_passed"] and cleaned["executors_stopped"]
            await gate.finish_restore(
                prepared["run_id"], state["operations"][0]["id"], executor_stopped=True
            )
            await gate.resume(prepared["run_id"])
            shutil.rmtree(workspace)
        finally:
            block.unlink(missing_ok=True)
            await engine.dispose()

    asyncio.run(scenario())


def test_source_database_disconnect_retains_receipt_until_lock_is_verified_gone(
    live_context, monkeypatch, tmp_path
):
    import shutil

    from sqlalchemy import text

    item = live_context
    marker = slow_target_docker(tmp_path, monkeypatch)

    async def scenario():
        engine, gate = await gate_for(item["fixture"]["env"])
        try:
            prepared = await prepare(
                item["directory"], item["credentials"], item["image"], item["root"]
            )
            workspace = Path(prepared["workspace"])
            await gate.start(prepared["run_id"])
            await gate.drain(prepared["run_id"])
            running = asyncio.create_task(run_restore(workspace, timeout_seconds=60))
            for _ in range(200):
                if marker.exists():
                    break
                await asyncio.sleep(0.1)
            assert marker.exists()
            pid = json.loads((workspace / "journal.json").read_text())["lock_backend_pid"]
            async with engine.begin() as connection:
                assert await connection.scalar(
                    text("SELECT pg_terminate_backend(:pid)"), {"pid": pid}
                )
            result = await running
            assert not result["passed"] and not result["restore_receipt_finished"]
            assert result["executors_stopped"] and result["child_stopped"]
            assert not result["source_lock_released"]
            state = await gate.status()
            assert state["phase"] == "frozen" and len(state["operations"]) == 1
            async with engine.connect() as connection:
                assert (
                    await connection.scalar(
                        text(
                            "SELECT count(*) FROM pg_locks WHERE locktype='advisory' AND pid=:pid"
                        ),
                        {"pid": pid},
                    )
                    == 0
                )
            await gate.finish_restore(
                prepared["run_id"], state["operations"][0]["id"], executor_stopped=True
            )
            await gate.resume(prepared["run_id"])
            shutil.rmtree(workspace)
        finally:
            await engine.dispose()

    asyncio.run(scenario())


def test_wrong_database_tunnel_cannot_authorize_a_restore(live_context, monkeypatch):
    import shutil

    from sqlalchemy.engine import make_url

    item = live_context

    async def scenario():
        engine, gate = await gate_for(item["fixture"]["env"])
        try:
            prepared = await prepare(
                item["directory"], item["credentials"], item["image"], item["root"]
            )
            workspace = Path(prepared["workspace"])
            await gate.start(prepared["run_id"])
            await gate.drain(prepared["run_id"])
            wrong = make_url(item["fixture"]["env"]["DATABASE_URL"]).set(database="postgres")
            monkeypatch.setenv("DATABASE_URL", wrong.render_as_string(hide_password=False))
            result = await run_restore(workspace, timeout_seconds=120)
            assert not result["passed"] and result["error"] == "source_database_mismatch", result
            assert not result["restore_receipt_finished"]
            state = await gate.status()
            assert state["phase"] == "frozen" and len(state["operations"]) == 1
            await gate.finish_restore(
                prepared["run_id"], state["operations"][0]["id"], executor_stopped=True
            )
            await gate.resume(prepared["run_id"])
            shutil.rmtree(workspace)
        finally:
            await engine.dispose()

    asyncio.run(scenario())
