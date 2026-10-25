"""Mac host controller for an authoritative, bounded, deletion-aware Docker restore.

It never starts maintenance or resumes the service. Source credentials stay in the
controller; the isolated child receives only a private workspace and Docker context.
"""

import argparse
import asyncio
import json
import os
import re
import shutil
import signal
import stat
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import urlsplit
from uuid import UUID, uuid4

import httpx
from pydantic import SecretStr, field_validator, model_validator
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine

from app.core.deletion_ledger_config import DeletionLedgerSettings
from scripts.check_backup_restore import (
    OWNER_LABEL,
    CheckError,
    Docker,
    RestoreDrill,
    check,
    load_backup,
    private_json,
    require,
)

MAX_SECONDS = 30 * 60
OWNER = re.compile(r"clipback-recovery-[0-9a-f]{32}\Z")


class RestoreSettings(DeletionLedgerSettings):
    database_url: str
    operator_control_url: str
    operator_control_key: SecretStr

    @field_validator("database_url")
    @classmethod
    def local_database(cls, value):
        url = make_url(value)
        if url.drivername not in {
            "postgres",
            "postgresql",
            "postgresql+asyncpg",
        } or url.host not in {"127.0.0.1", "localhost", "::1"}:
            raise ValueError("The Mac loopback database tunnel is required")
        return url.set(drivername="postgresql+asyncpg").render_as_string(hide_password=False)

    @model_validator(mode="after")
    def local_control(self):
        url = urlsplit(self.operator_control_url)
        key = self.operator_control_key.get_secret_value()
        if (
            url.scheme not in {"http", "https"}
            or url.hostname not in {"127.0.0.1", "localhost", "::1"}
            or url.username
            or url.password
            or url.query
            or url.fragment
            or url.path not in {"", "/"}
            or len(key) < 16
            or not key.strip()
            or "\r" in key
            or "\n" in key
        ):
            raise ValueError("The Mac loopback control tunnel and key are required")
        return self


class Control:
    def __init__(self, config):
        self.url = config.operator_control_url.rstrip("/") + "/maintenance"
        self.headers = {"Authorization": "Bearer " + config.operator_control_key.get_secret_value()}

    async def call(self, action="", payload=None):
        try:
            async with httpx.AsyncClient(
                timeout=3, trust_env=False, follow_redirects=False
            ) as http:
                if payload is None:
                    response = await http.get(self.url + action, headers=self.headers)
                else:
                    response = await http.post(
                        self.url + action, headers=self.headers, json=payload
                    )
            require(response.status_code == 200, "maintenance_control_failed")
            result = response.json()
            require(isinstance(result, dict), "maintenance_control_invalid")
            return result
        except (httpx.HTTPError, ValueError) as exc:
            raise CheckError("maintenance_control_unavailable") from exc

    async def frozen(self, run_id, generation=None, operation_id=None):
        result = await self.call()
        require(
            result.get("phase") == "frozen" and result.get("run_id") == run_id,
            "source_write_freeze_required",
        )
        require(
            generation is None or result.get("generation") == generation,
            "maintenance_generation_changed",
        )
        if operation_id is not None:
            require(
                any(
                    operation.get("id") == operation_id and operation.get("kind") == "restore"
                    for operation in result.get("operations", [])
                ),
                "restore_receipt_missing",
            )
        return result


async def paired_database(connection, run_id, generation, operation_id=None):
    """The direct DB tunnel must be the very database that issued the HTTP receipt."""
    from sqlalchemy.exc import SQLAlchemyError

    try:
        state = await connection.execute(
            text(
                "SELECT 1 FROM maintenance_state WHERE id=1 AND phase='frozen' "
                "AND run_id=:run AND generation=:generation"
            ),
            {"run": run_id, "generation": generation},
        )
        require(state.scalar() == 1, "source_database_mismatch")
        if operation_id is not None:
            operation = await connection.execute(
                text(
                    "SELECT 1 FROM maintenance_operations WHERE id=:operation AND kind='restore' "
                    "AND run_id=:run AND generation=:generation"
                ),
                {"operation": operation_id, "run": run_id, "generation": generation},
            )
            require(operation.scalar() == 1, "source_database_mismatch")
    except SQLAlchemyError as exc:
        raise CheckError("source_database_mismatch") from exc


def private_directory(path):
    require(not path.is_symlink(), "workspace_not_private")
    info = path.stat()
    require(
        stat.S_ISDIR(info.st_mode)
        and stat.S_IMODE(info.st_mode) == 0o700
        and info.st_uid == os.getuid(),
        "workspace_not_private",
    )


def outside_repository(path):
    resolved = path.resolve()
    require(
        not any((ancestor / ".git").exists() for ancestor in (resolved, *resolved.parents)),
        "workspace_inside_repository",
    )


def write_private(path, value):
    descriptor, name = tempfile.mkstemp(prefix=".restore-", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "w") as output:
            json.dump(value, output, sort_keys=True)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
        parent = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(parent)
        finally:
            os.close(parent)
    finally:
        temporary.unlink(missing_ok=True)


def journal(workspace):
    private_directory(workspace)
    outside_repository(workspace)
    entry = workspace / "journal.json"
    require(
        not entry.is_symlink() and stat.S_IMODE(entry.stat().st_mode) == 0o600,
        "journal_not_private",
    )
    value = json.loads(entry.read_text())
    require(OWNER.fullmatch(value.get("owner", "")) is not None, "invalid_restore_owner")
    require(
        str(UUID(value["run_id"])) == value["run_id"]
        and workspace.name == "restore-" + UUID(value["run_id"]).hex,
        "invalid_workspace",
    )
    return value


def inspect_images(image, manifest, docker=None):
    docker = docker or Docker()
    require(
        not os.environ.get("DOCKER_HOST", "unix://").startswith(("tcp:", "ssh:")),
        "docker_must_be_local",
    )
    context = json.loads(docker("context", "inspect"))[0]
    host = os.environ.get("DOCKER_HOST") or context["Endpoints"]["docker"]["Host"]
    require(host.startswith("unix://"), "docker_must_be_local")
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/@:-]*", image) is not None, "invalid_image")
    metadata = json.loads(docker("image", "inspect", image))[0]
    require(
        (metadata["Config"].get("Labels") or {}).get("org.opencontainers.image.revision")
        == manifest["app_commit"],
        "image_revision_mismatch",
    )
    docker("image", "inspect", f"postgres:{manifest['postgres_major']}")
    if any(asset.get("storage_backend") == "s3" for asset in manifest["assets"]):
        docker("image", "inspect", "motoserver/moto:5.2.4")
    return metadata["Id"]


async def prepare(directory, credentials, image, root):
    # Fail on private input before configuration/network/filesystem changes.
    private_json(credentials)
    private_directory(root)
    outside_repository(root)
    manifest, paths = load_backup(directory)
    config = RestoreSettings()
    image_id = inspect_images(image, manifest)
    control = Control(config)
    state = await control.call()
    require(state.get("phase") == "open", "prepare_before_maintenance")
    from app.integrations.deletion_ledger import get_deletion_ledger

    ledger = get_deletion_ledger(config)
    await asyncio.to_thread(ledger.read_verified_checkpoint)
    engine = create_async_engine(config.database_url)
    try:
        async with engine.connect() as connection:
            await connection.execute(text("SELECT 1"))
    finally:
        await engine.dispose()
    docker_version = Docker()("version", "--format", "{{.Server.Version}}").decode().strip()
    run_id = str(uuid4())
    workspace = root / ("restore-" + UUID(run_id).hex)
    workspace.mkdir(mode=0o700)
    value = {
        "run_id": run_id,
        "owner": "clipback-recovery-" + uuid4().hex,
        "image": image_id,
        "backup_id": manifest["backup_id"],
        "stage": "preparing",
        "controller_pid": os.getpid(),
        "registration_attempted": False,
        "app_commit": manifest["app_commit"],
        "postgres_major": manifest["postgres_major"],
        "docker_version": docker_version,
    }
    try:
        write_private(workspace / "journal.json", value)
        backup = workspace / "backup"
        backup.mkdir(mode=0o700)
        for source in [directory / "manifest.json", *paths.values()]:
            target = backup / source.name
            shutil.copyfile(source, target)
            target.chmod(0o600)
        shutil.copyfile(credentials, workspace / "credentials.json")
        (workspace / "credentials.json").chmod(0o600)
        load_backup(backup)
        private_json(workspace / "credentials.json")
        value.update(stage="prepared", controller_pid=None)
        write_private(workspace / "journal.json", value)
    except BaseException:
        shutil.rmtree(workspace)
        raise
    return {
        "passed": True,
        "prepared": True,
        "run_id": run_id,
        "workspace": str(workspace),
        "backup_id": manifest["backup_id"],
    }


def owned_resources(owner, docker):
    require(OWNER.fullmatch(owner) is not None, "invalid_restore_owner")
    result = []
    for kind in ("container", "network", "volume"):
        flags = ["-aq"] if kind == "container" else ["-q"]
        identifiers = docker(kind, "ls", *flags, "--filter", f"label={OWNER_LABEL}={owner}")
        for identifier in identifiers.decode().split():
            info = json.loads(docker(kind, "inspect", identifier))[0]
            source = info.get("Config", {}) if kind == "container" else info
            require(
                (source.get("Labels") or {}).get(OWNER_LABEL) == owner,
                "resource_ownership_mismatch",
            )
            result.append((kind, identifier, info))
    return result


def cleanup_owned(owner):
    docker = Docker()
    errors = []
    try:
        resources = owned_resources(owner, docker)
        for kind, identifier, _ in resources:
            try:
                docker(
                    kind,
                    "rm",
                    *(["-f", "-v"] if kind == "container" else []),
                    identifier,
                    timeout=15,
                )
            except CheckError:
                errors.append(kind)
        remaining = owned_resources(owner, docker)
        stopped = not any(
            kind == "container" and info["State"]["Running"] for kind, _, info in remaining
        )
        return {
            "cleanup_passed": not errors and not remaining,
            "executors_stopped": stopped,
            "remaining_resource_kinds": [kind for kind, _, _ in remaining],
        }
    except (CheckError, ValueError, KeyError, IndexError):
        return {
            "cleanup_passed": False,
            "executors_stopped": False,
            "remaining_resource_kinds": ["unknown"],
        }


def alive(pid):
    if not pid:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def process_group_alive(group):
    if not group:
        return False
    try:
        os.killpg(group, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        # An unobservable group is not proof that all executors stopped.
        return True


async def stop_child(child):
    if child is None:
        return True
    try:
        # The restore leader can exit while its Docker CLI descendants survive.
        # The new-session process group, rather than only wait(), owns them all.
        for signum in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(child.pid, signum)
            except ProcessLookupError:
                break
            deadline = time.monotonic() + 3
            while process_group_alive(child.pid) and time.monotonic() < deadline:
                await asyncio.sleep(0.05)
            if not process_group_alive(child.pid):
                break
        await asyncio.wait_for(child.wait(), timeout=3)
        return child.returncode is not None and not process_group_alive(child.pid)
    except (OSError, TimeoutError):
        return False


def child_environment(workspace):
    names = {"PATH", "HOME", "TMPDIR", "DOCKER_CONTEXT", "DOCKER_CONFIG", "DOCKER_HOST"}
    result = {key: value for key, value in os.environ.items() if key in names}
    result["PYTHONPATH"] = str(Path(__file__).resolve().parents[1])
    result["PYTHONDONTWRITEBYTECODE"] = "1"
    temporary = workspace / "temporary"
    temporary.mkdir(mode=0o700)
    result["TMPDIR"] = str(temporary)
    return result


async def run_restore(workspace, *, timeout_seconds=MAX_SECONDS):
    require(0 < timeout_seconds <= MAX_SECONDS, "invalid_restore_timeout")
    value = journal(workspace)
    require(value["stage"] == "prepared", "restore_already_started")
    try:
        descriptor = os.open(
            workspace / "execution.lock", os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600
        )
        os.close(descriptor)
    except FileExistsError as exc:
        raise CheckError("restore_already_started") from exc
    started = time.monotonic()
    report = {
        "passed": False,
        "run_id": value["run_id"],
        "backup_id": value["backup_id"],
        "maintenance_resumed": False,
        "restore_receipt_finished": False,
        "live_deletion_ledger_verified": False,
        "maintenance_verified": False,
        "source_database_verified": False,
        "app_commit": value["app_commit"],
        "postgres_major": value["postgres_major"],
        "image": value["image"],
        "docker_version": value["docker_version"],
        "python_version": sys.version.split()[0],
    }
    child = connection = engine = control = spawn = None
    registration_attempted = False
    lock_acquired = False
    value.update(stage="starting", controller_pid=os.getpid())
    write_private(workspace / "journal.json", value)
    try:
        config = RestoreSettings()
        control = Control(config)
        state = await control.frozen(value["run_id"])
        started = time.monotonic()
        value["generation"] = state["generation"]
        report["maintenance_generation"] = state["generation"]
        engine = create_async_engine(config.database_url)
        async with asyncio.timeout(timeout_seconds):
            registration_attempted = True
            value["registration_attempted"] = True
            write_private(workspace / "journal.json", value)
            registration = await control.call(
                "/restore/start", {"run_id": value["run_id"], "generation": value["generation"]}
            )
            value["operation_id"] = registration["operation_id"]
            write_private(workspace / "journal.json", value)
            connection = await engine.connect()
            value["lock_backend_pid"] = await connection.scalar(text("SELECT pg_backend_pid()"))
            write_private(workspace / "journal.json", value)
            await paired_database(
                connection, value["run_id"], value["generation"], value["operation_id"]
            )
            report["source_database_verified"] = True
            from app.integrations.deletion_ledger import LEDGER_WRITE_LOCK, get_deletion_ledger

            await connection.execute(
                text("SELECT pg_advisory_lock_shared(:key)"), {"key": LEDGER_WRITE_LOCK}
            )
            lock_acquired = True
            manifest = json.loads((workspace / "backup" / "manifest.json").read_text())
            from scripts.image_backup_jobs import latest_deletions

            checkpoint, events = await asyncio.to_thread(
                latest_deletions, get_deletion_ledger(config), manifest.get("deletion_checkpoint")
            )
            write_private(workspace / "events.json", events)
            report["deletion_sequence"] = checkpoint["sequence"]
            spawn = asyncio.create_task(
                asyncio.create_subprocess_exec(
                    sys.executable,
                    "-m",
                    "scripts.restore_execution",
                    "_child",
                    "--workspace",
                    str(workspace),
                    env=child_environment(workspace),
                    start_new_session=True,
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.DEVNULL,
                )
            )
            child = await asyncio.shield(spawn)
            value.update(stage="running", child_pid=child.pid)
            write_private(workspace / "journal.json", value)
            while child.returncode is None:
                await control.frozen(value["run_id"], value["generation"], value["operation_id"])
                await connection.execute(text("SELECT 1"))
                await asyncio.sleep(0.25)
            result = json.loads((workspace / "child-report.json").read_text())
            require(
                child.returncode == 0 and result.get("passed") is True,
                result.get("error", "isolated_restore_failed"),
            )
            await control.frozen(value["run_id"], value["generation"], value["operation_id"])
            await connection.execute(text("SELECT 1"))
            report.update(result)
            report["live_deletion_ledger_verified"] = True
            report["maintenance_verified"] = True
    except TimeoutError:
        report["error"] = "restore_timeout"
    except CheckError as exc:
        report["error"] = str(exc)
    except BaseException as exc:
        report["error"] = (
            "restore_interrupted"
            if isinstance(exc, (KeyboardInterrupt, asyncio.CancelledError))
            else "restore_execution_failed"
        )
    finally:
        spawn_unknown = False
        if spawn is not None and child is None:
            try:
                # Capture the eventual OS process even if the validation budget expired
                # while Python was constructing its process transport. Cleanup may exceed
                # the validation budget; it must not falsely declare an unknown child stopped.
                child = await asyncio.shield(spawn)
                value["child_pid"] = child.pid
                write_private(workspace / "journal.json", value)
            except BaseException:
                spawn_unknown = True
        child_stopped = not spawn_unknown and await stop_child(child)
        resource_state = await asyncio.to_thread(cleanup_owned, value["owner"])
        report.update(resource_state)
        report["child_stopped"] = child_stopped
        lock_released = connection is None and not lock_acquired
        if connection is not None:
            try:
                if lock_acquired:
                    from app.integrations.deletion_ledger import LEDGER_WRITE_LOCK

                    lock_released = await connection.scalar(
                        text("SELECT pg_advisory_unlock_shared(:key)"), {"key": LEDGER_WRITE_LOCK}
                    )
                else:
                    lock_released = True
                await connection.rollback()
                await connection.close()
            except Exception:
                lock_released = False
                try:
                    await connection.invalidate()
                except Exception:
                    pass
        report["source_lock_released"] = bool(lock_released)
        if engine is not None:
            await engine.dispose()
        if not registration_attempted:
            report["restore_receipt_finished"] = True
        if (
            child_stopped
            and resource_state["executors_stopped"]
            and lock_released
            and report["source_database_verified"]
        ):
            if value.get("operation_id"):
                try:
                    await control.call(
                        "/restore/finish",
                        {
                            "run_id": value["run_id"],
                            "operation_id": value["operation_id"],
                            "executor_stopped": True,
                        },
                    )
                    report["restore_receipt_finished"] = True
                except CheckError:
                    report["error"] = "restore_terminalization_unconfirmed"
        report["passed"] = bool(
            report.get("passed")
            and not report.get("error")
            and report["cleanup_passed"]
            and report["source_lock_released"]
            and report["child_stopped"]
            and report["restore_receipt_finished"]
        )
        value["stage"] = "finished" if report["restore_receipt_finished"] else "recovery_required"
        write_private(workspace / "journal.json", value)
        report["elapsed_seconds"] = round(time.monotonic() - started, 3)
        report["report_file"] = str(workspace.with_suffix(".report.json"))
        # Only this run's copied inputs are removed; source backup and originals are untouched.
        if child_stopped and resource_state["executors_stopped"]:
            for name in (
                "backup",
                "credentials.json",
                "events.json",
                "child-report.json",
                "temporary",
            ):
                path = workspace / name
                try:
                    if path.is_dir():
                        shutil.rmtree(path)
                    else:
                        path.unlink(missing_ok=True)
                except OSError:
                    report["cleanup_passed"] = report["passed"] = False
            if report["cleanup_passed"] and report["restore_receipt_finished"]:
                try:
                    shutil.rmtree(workspace)
                except OSError:
                    report["cleanup_passed"] = report["passed"] = False
                    report["error"] = "workspace_cleanup_failed"
        try:
            write_private(workspace.with_suffix(".report.json"), report)
        except OSError:
            report["passed"] = False
            report["error"] = "report_write_failed"
    return report


async def recover_workspace(workspace, *, confirmed):
    require(confirmed, "executor_stop_confirmation_required")
    value = journal(workspace)
    require(
        not alive(value.get("controller_pid")) and not alive(value.get("child_pid"))
        and not process_group_alive(value.get("child_pid")),
        "restore_executor_still_running",
    )
    result = await asyncio.to_thread(cleanup_owned, value["owner"])
    if value.get("stage") == "finished":
        result["restore_receipt_finished"] = True
    elif result["executors_stopped"] and value.get("registration_attempted"):
        config = RestoreSettings()
        engine = create_async_engine(config.database_url)
        try:
            async with engine.connect() as connection:
                active = await connection.scalar(
                    text("SELECT count(*) FROM pg_locks WHERE locktype='advisory' AND pid=:pid"),
                    {"pid": value.get("lock_backend_pid", -1)},
                )
                require(active == 0, "source_lock_still_active")
            control = Control(config)
            status = await control.frozen(value["run_id"], value.get("generation"))
            operations = [
                operation
                for operation in status.get("operations", [])
                if operation.get("run_id") == value["run_id"] and operation.get("kind") == "restore"
            ]
            require(len(operations) <= 1, "restore_receipt_ambiguous")
            async with engine.connect() as connection:
                await paired_database(
                    connection,
                    value["run_id"],
                    status["generation"],
                    operations[0]["id"] if operations else None,
                )
            if operations:
                await control.call(
                    "/restore/finish",
                    {
                        "run_id": value["run_id"],
                        "operation_id": operations[0]["id"],
                        "executor_stopped": True,
                    },
                )
            result["restore_receipt_finished"] = True
        finally:
            await engine.dispose()
    result.update(
        passed=bool(result["cleanup_passed"]), run_id=value["run_id"], maintenance_resumed=False
    )
    if result["cleanup_passed"]:
        try:
            shutil.rmtree(workspace)
        except OSError:
            result["cleanup_passed"] = result["passed"] = False
            result["error"] = "workspace_cleanup_failed"
    write_private(workspace.with_suffix(".recovery.json"), result)
    return result


def child_run(workspace):
    value = journal(workspace)
    events = json.loads((workspace / "events.json").read_text())
    report = check(
        workspace / "backup",
        workspace / "credentials.json",
        value["image"],
        RestoreDrill(owner=value["owner"], deletion_events=events),
    )
    write_private(workspace / "child-report.json", report)
    return 0 if report["passed"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    item = commands.add_parser("prepare")
    item.add_argument("--backup-dir", type=Path, required=True)
    item.add_argument("--credentials-file", type=Path, required=True)
    item.add_argument("--image", required=True)
    item.add_argument("--run-root", type=Path, required=True)
    for name in ("run", "cleanup", "_child"):
        item = commands.add_parser(name)
        item.add_argument("--workspace", type=Path, required=True)
        if name == "run":
            item.add_argument("--timeout-seconds", type=float, default=MAX_SECONDS)
        if name == "cleanup":
            item.add_argument("--confirm-executors-stopped", action="store_true", required=True)
    args = parser.parse_args()
    try:
        if args.command == "_child":
            return child_run(args.workspace)
        if args.command == "prepare":
            report = asyncio.run(
                prepare(args.backup_dir, args.credentials_file, args.image, args.run_root)
            )
        elif args.command == "cleanup":
            report = asyncio.run(
                recover_workspace(args.workspace, confirmed=args.confirm_executors_stopped)
            )
        else:
            report = asyncio.run(run_restore(args.workspace, timeout_seconds=args.timeout_seconds))
        print(json.dumps(report, sort_keys=True))
        return 0 if report["passed"] else 1
    except Exception as exc:
        code = str(exc) if isinstance(exc, CheckError) else "restore_preflight_failed"
        print(json.dumps({"passed": False, "error": code}, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
