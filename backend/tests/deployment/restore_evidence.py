"""Safe failure evidence for live restore tests.

Only allowlisted flags, fixed codes, resource kinds and counts leave this module. Tokens,
connection strings, credentials, backup contents and raw exception messages are never copied.
"""

import json
import os
import re
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path

import pytest

FAILURE = pytest.StashKey[BaseException]()
CODE = re.compile(r"[a-z][a-z0-9_]{0,79}")
FLAGS = (
    "passed",
    "cleanup_passed",
    "executors_stopped",
    "child_stopped",
    "source_lock_released",
    "source_database_verified",
    "restore_receipt_finished",
)
# cleanup_owned reports these kinds; "unknown" means Docker inspection itself failed.
RESOURCE_KINDS = ("container", "network", "volume", "unknown")
# The copied inputs run_restore deletes from its workspace before removing the workspace.
COPIED_INPUTS = ("backup", "credentials.json", "events.json", "child-report.json", "temporary")


def code(value):
    if value is None:
        return None
    return value if isinstance(value, str) and CODE.fullmatch(value) else "unrecognized"


def error_name(exc):
    from scripts.operator_errors import CheckError

    name = type(exc).__name__
    return f"{name}:{code(str(exc))}" if isinstance(exc, CheckError) else name


def maintenance(state):
    if not isinstance(state, dict):
        return {"phase": None, "operations": None}
    operations = state.get("operations")
    return {
        "phase": code(state.get("phase")),
        "operations": len(operations) if isinstance(operations, list) else None,
    }


def child_running(workspace):
    try:
        pid = json.loads((workspace / "journal.json").read_text()).get("child_pid")
    except (OSError, ValueError, AttributeError):
        return None
    if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
        return None
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except OSError:
        return None
    return True


def cleanup_steps(result, workspace):
    """Attribute cleanup_passed=false to the run_restore cleanup step that left something."""
    flags = {name: result.get(name) is True for name in FLAGS}
    kinds = result.get("remaining_resource_kinds")
    docker = "failed" if kinds or not flags["executors_stopped"] else "passed"
    if not (flags["child_stopped"] and flags["executors_stopped"]):
        inputs = directory = "skipped"
    elif workspace is None:
        inputs = directory = "unknown"
    else:
        left = [name for name in COPIED_INPUTS if (workspace / name).exists()]
        inputs = "failed" if left else "passed"
        if not (inputs == "passed" and docker == "passed" and flags["restore_receipt_finished"]):
            directory = "skipped"
        else:
            directory = "failed" if workspace.exists() else "passed"
    steps = {
        "docker_resource_removal": docker,
        "workspace_input_removal": inputs,
        "workspace_removal": directory,
    }
    if workspace is not None and inputs == "failed":
        steps["workspace_inputs_left"] = left
    if code(result.get("error")) == "workspace_cleanup_failed":
        steps["workspace_removal"] = "failed"
    # cleanup_owned also fails when `docker rm` errors but nothing remains afterwards.
    steps["unattributed"] = result.get("cleanup_passed") is False and "failed" not in (
        steps["docker_resource_removal"],
        steps["workspace_input_removal"],
        steps["workspace_removal"],
    )
    return steps


def restore_summary(result, workspace=None, *, returncode=None):
    if not isinstance(result, dict):
        return {"result": None}
    kinds = result.get("remaining_resource_kinds")
    kinds = kinds if isinstance(kinds, list) else []
    return {
        "result": {
            **{
                name: result.get(name) if isinstance(result.get(name), bool) else None
                for name in FLAGS
            },
            "error": code(result.get("error")),
        },
        "remaining_resource_kinds": dict(
            Counter(kind if kind in RESOURCE_KINDS else "other" for kind in kinds)
        ),
        "cleanup_steps": cleanup_steps(result, workspace),
        "child_process_running": None if workspace is None else child_running(workspace),
        "command_returncode": returncode if isinstance(returncode, int) else None,
    }


class RestoreEvidence:
    def __init__(self, test):
        self.test = test
        self.maintenance_at_start = None
        self.restores = []
        self.collection_errors = []

    def start(self, read_state):
        try:
            self.maintenance_at_start = maintenance(read_state())
        except Exception as exc:
            self.collection_errors.append(error_name(exc))

    def record(self, result, workspace=None, *, returncode=None):
        """Snapshot a run_restore result immediately; return it unchanged for the test."""
        try:
            self.restores.append(restore_summary(result, workspace, returncode=returncode))
        except Exception as exc:
            self.collection_errors.append(error_name(exc))
        return result

    def summary(self):
        return "restore evidence: " + json.dumps(
            {"maintenance_at_start": self.maintenance_at_start, "restores": self.restores},
            sort_keys=True,
        )

    def write(self, directory, *, failure, read_state, private_returncode):
        try:
            maintenance_at_failure = maintenance(read_state())
        except Exception as exc:
            maintenance_at_failure = None
            self.collection_errors.append(error_name(exc))
        value = {
            "test": self.test,
            "failed_at": datetime.now(UTC).isoformat(timespec="seconds"),
            "failure": error_name(failure),
            "maintenance_at_start": self.maintenance_at_start,
            "maintenance_at_failure": maintenance_at_failure,
            "private_control_returncode": (
                private_returncode if isinstance(private_returncode, int) else None
            ),
            "restores": self.restores,
            "collection_errors": self.collection_errors,
        }
        directory = Path(directory)
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / (re.sub(r"[^A-Za-z0-9_.-]", "_", self.test) + ".json")
        path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
        return path
