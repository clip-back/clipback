"""Restore failure evidence keeps only allowlisted fields (no Docker needed)."""

import json

import pytest

from scripts.operator_errors import CheckError
from tests.deployment.restore_evidence import (
    COPIED_INPUTS,
    RestoreEvidence,
    restore_summary,
)

SECRETS = (
    "postgresql://owner:hunter2@db:5432/clipback",
    "control101-private-key",
    "reader101-private-key",
    "backup-row-content",
    "/tmp/pytest/runs/abc.report.json",
)


def clean_result(**changes):
    result = {
        "passed": True,
        "cleanup_passed": True,
        "executors_stopped": True,
        "child_stopped": True,
        "source_lock_released": True,
        "source_database_verified": True,
        "restore_receipt_finished": True,
        "remaining_resource_kinds": [],
        "run_id": "run-secret-id",
        "backup_id": "backup-secret-id",
        "image": "clipback-operator-api:check",
        "report_file": SECRETS[4],
        "database_url": SECRETS[0],
        "credentials": {"OPERATOR_CONTROL_KEY": SECRETS[1]},
        "rows": [SECRETS[3]],
    }
    result.update(changes)
    return result


def workspace_with(tmp_path, *names):
    workspace = tmp_path / "run-workspace"
    workspace.mkdir()
    for name in names:
        (workspace / name).write_text(SECRETS[3])
    return workspace


def assert_no_secrets(text):
    for secret in (*SECRETS, "run-secret-id", "backup-secret-id", "clipback-operator-api"):
        assert secret not in text


def test_summary_keeps_only_allowlisted_flags_codes_and_kind_counts(tmp_path):
    result = clean_result(
        passed=False,
        cleanup_passed=False,
        executors_stopped=False,
        remaining_resource_kinds=["container", "volume", "container"],
        error="restore_timeout",
    )

    summary = restore_summary(result, workspace_with(tmp_path), returncode=1)

    assert summary["result"] == {
        "passed": False,
        "cleanup_passed": False,
        "executors_stopped": False,
        "child_stopped": True,
        "source_lock_released": True,
        "source_database_verified": True,
        "restore_receipt_finished": True,
        "error": "restore_timeout",
    }
    assert summary["remaining_resource_kinds"] == {"container": 2, "volume": 1}
    assert summary["cleanup_steps"]["docker_resource_removal"] == "failed"
    assert summary["cleanup_steps"]["workspace_input_removal"] == "skipped"
    assert summary["command_returncode"] == 1
    assert set(summary) == {
        "result",
        "remaining_resource_kinds",
        "cleanup_steps",
        "child_process_running",
        "command_returncode",
    }
    assert_no_secrets(json.dumps(summary))


@pytest.mark.parametrize(
    "value",
    [None, 1, 0, "true", ["x"], {"a": 1}, SECRETS[0]],
)
def test_wrong_types_become_none_or_unrecognized(value):
    result = {name: value for name in ("passed", "cleanup_passed", "child_stopped")}
    result["error"] = value
    result["remaining_resource_kinds"] = value if isinstance(value, list) else [value]

    summary = restore_summary(result, None, returncode=value)

    assert summary["result"]["passed"] is None
    assert summary["result"]["cleanup_passed"] is None
    # A code-shaped string such as "true" is kept as a code; anything else is not copied.
    assert summary["result"]["error"] in (None, "unrecognized", "true")
    assert set(summary["remaining_resource_kinds"]) == {"other"}
    assert summary["command_returncode"] in (None, 1, 0)
    assert_no_secrets(json.dumps(summary))


@pytest.mark.parametrize("value", [None, 7, "postgresql://x:y@h/d", [1]])
def test_non_mapping_result_is_recorded_without_content(value):
    assert restore_summary(value) == {"result": None}


def test_error_codes_with_secret_text_are_not_copied():
    summary = restore_summary(clean_result(error=f"connect failed {SECRETS[0]}"))

    assert summary["result"]["error"] == "unrecognized"


def test_docker_removal_failure_is_attributed(tmp_path):
    workspace = workspace_with(tmp_path, *COPIED_INPUTS[:1])
    result = clean_result(
        passed=False,
        cleanup_passed=False,
        executors_stopped=False,
        restore_receipt_finished=False,
        remaining_resource_kinds=["container"],
    )

    steps = restore_summary(result, workspace)["cleanup_steps"]

    assert steps == {
        "docker_resource_removal": "failed",
        "workspace_input_removal": "skipped",
        "workspace_removal": "skipped",
        "unattributed": False,
    }


def test_left_workspace_input_is_attributed_by_fixed_name_only(tmp_path):
    workspace = workspace_with(tmp_path, "credentials.json", "events.json")
    result = clean_result(passed=False, cleanup_passed=False)

    summary = restore_summary(result, workspace)

    assert summary["cleanup_steps"] == {
        "docker_resource_removal": "passed",
        "workspace_input_removal": "failed",
        "workspace_inputs_left": ["credentials.json", "events.json"],
        "workspace_removal": "skipped",
        "unattributed": False,
    }
    assert_no_secrets(json.dumps(summary))


def test_workspace_directory_failure_is_attributed(tmp_path):
    workspace = workspace_with(tmp_path)
    result = clean_result(passed=False, cleanup_passed=False, error="workspace_cleanup_failed")

    steps = restore_summary(result, workspace)["cleanup_steps"]

    assert steps["workspace_input_removal"] == "passed"
    assert steps["workspace_removal"] == "failed"
    assert steps["unattributed"] is False


def test_unreceipted_run_keeps_workspace_without_blaming_cleanup(tmp_path):
    workspace = workspace_with(tmp_path)
    result = clean_result(passed=False, restore_receipt_finished=False)

    steps = restore_summary(result, workspace)["cleanup_steps"]

    assert steps["workspace_input_removal"] == "passed"
    assert steps["workspace_removal"] == "skipped"
    assert steps["unattributed"] is False


def test_cleanup_failure_without_left_resource_is_unattributed(tmp_path):
    result = clean_result(passed=False, cleanup_passed=False)

    steps = restore_summary(result, tmp_path / "removed")["cleanup_steps"]

    assert steps["docker_resource_removal"] == "passed"
    assert steps["workspace_removal"] == "passed"
    assert steps["unattributed"] is True


def test_child_process_state_comes_from_journal_pid_only(tmp_path):
    import os

    workspace = workspace_with(tmp_path)
    (workspace / "journal.json").write_text(
        json.dumps({"child_pid": os.getpid(), "owner": "secret-owner", "run_id": "run-secret-id"})
    )

    summary = restore_summary(clean_result(), workspace)

    assert summary["child_process_running"] is True
    assert "secret-owner" not in json.dumps(summary)
    (workspace / "journal.json").write_text(json.dumps({"child_pid": "1; rm -rf /"}))
    assert restore_summary(clean_result(), workspace)["child_process_running"] is None


def test_written_evidence_has_only_allowlisted_top_level_fields(tmp_path):
    evidence = RestoreEvidence("test_control_disconnect_stops_child_but_keeps_durable_recovery")
    evidence.start(lambda: {"phase": "frozen", "operations": [{"id": SECRETS[1]}], "run_id": "x"})
    result = clean_result(passed=False, cleanup_passed=False, remaining_resource_kinds=["volume"])
    assert evidence.record(result, workspace_with(tmp_path)) is result

    path = evidence.write(
        tmp_path / "evidence",
        failure=AssertionError(f"assert {SECRETS[0]}"),
        read_state=lambda: {"phase": "frozen", "operations": [], "run_id": SECRETS[1]},
        private_returncode=-15,
    )

    text = path.read_text()
    value = json.loads(text)
    assert set(value) == {
        "test",
        "failed_at",
        "failure",
        "maintenance_at_start",
        "maintenance_at_failure",
        "private_control_returncode",
        "restores",
        "collection_errors",
    }
    assert value["failure"] == "AssertionError"
    assert value["maintenance_at_start"] == {"phase": "frozen", "operations": 1}
    assert value["maintenance_at_failure"] == {"phase": "frozen", "operations": 0}
    assert value["private_control_returncode"] == -15
    assert value["restores"][0]["remaining_resource_kinds"] == {"volume": 1}
    assert value["collection_errors"] == []
    assert path.name == "test_control_disconnect_stops_child_but_keeps_durable_recovery.json"
    assert_no_secrets(text)
    assert value["restores"] == json.loads(evidence.summary().split(": ", 1)[1])["restores"]


def test_check_error_code_is_kept_but_other_messages_are_not(tmp_path):
    def unavailable():
        raise RuntimeError(SECRETS[0])

    evidence = RestoreEvidence("test_wrong_database_tunnel_cannot_authorize_a_restore[x/y]")
    evidence.start(unavailable)

    path = evidence.write(
        tmp_path,
        failure=CheckError("prepare_before_maintenance"),
        read_state=unavailable,
        private_returncode=None,
    )

    value = json.loads(path.read_text())
    assert value["failure"] == "CheckError:prepare_before_maintenance"
    assert value["maintenance_at_start"] is None
    assert value["maintenance_at_failure"] is None
    assert value["collection_errors"] == ["RuntimeError", "RuntimeError"]
    assert path.name == "test_wrong_database_tunnel_cannot_authorize_a_restore_x_y_.json"
    assert_no_secrets(path.read_text())
    secret_code = RestoreEvidence("t")
    assert (
        json.loads(
            secret_code.write(
                tmp_path,
                failure=CheckError(SECRETS[0]),
                read_state=dict,
                private_returncode="1",
            ).read_text()
        )["failure"]
        == "CheckError:unrecognized"
    )
