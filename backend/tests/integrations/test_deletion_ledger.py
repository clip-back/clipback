"""Account deletion records in the deletion ledger (ADR 0008), observed through its readers."""

import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from types import SimpleNamespace
from uuid import uuid4

import boto3
import pytest
from botocore.exceptions import ConnectionClosedError, ReadTimeoutError
from moto import mock_aws
from pydantic import SecretStr

from app.core.deletion_ledger_config import DeletionLedgerSettings
from app.integrations.deletion_ledger import (
    DeletionLedger,
    LedgerUnavailableError,
    LocalLedgerStore,
    deleted_contents,
    get_deletion_ledger,
)

ASSET = {"storage_backend": "s3", "storage_key": "a.png", "sha256": "a" * 64, "size_bytes": 3}


@pytest.fixture
def ledger(tmp_path):
    value = DeletionLedger(LocalLedgerStore(tmp_path / "ledger"))
    value.initialize()
    return value


def image_record(**overrides):
    return {
        "operation_id": str(uuid4()), "user_id": 1, "content_id": 10,
        "saved_at": "2026-10-01T00:00:00+00:00", "deleted_at": "2026-11-01T00:00:00+00:00",
        "assets": [ASSET], **overrides,
    }


def account_record(**overrides):
    return {
        "kind": "account_deletion", "operation_id": str(uuid4()), "user_id": 1,
        "user_created_at": "2026-09-01T00:00:00+00:00",
        "deleted_at": "2026-11-02T00:00:00+00:00",
        "contents": [
            {"content_id": 11, "saved_at": "2026-10-02T00:00:00+00:00", "assets": [ASSET]},
        ],
        **overrides,
    }


def test_ledger_with_only_image_records_reads_unchanged(ledger, tmp_path):
    record = image_record()
    ledger.append(record)
    stored = json.loads((tmp_path / "ledger" / f"event-{1:020d}.json").read_text())
    assert stored["event"] == record
    assert ledger.read_verified_events() == [record]


def test_account_record_is_written_and_verified_by_every_reader(ledger):
    from scripts.image_backup_jobs import latest_deletions

    before = ledger.read_verified_checkpoint()
    image, account = image_record(), account_record()
    ledger.append(image)
    checkpoint = ledger.append(account)
    # Backup creation: bounded tip capture, then full prefix verification.
    assert ledger.read_checkpoint_tip() == checkpoint
    assert ledger.read_verified_events(checkpoint) == [image, account]
    assert ledger.read_operation(account["operation_id"]) == account
    # Restore: the live ledger is newer than the backup checkpoint.
    assert latest_deletions(ledger, before) == (checkpoint, [image, account])
    # A record appended after an account record still verifies the chain.
    later = image_record(content_id=12)
    ledger.append(later)
    assert ledger.read_verified_events() == [image, account, later]


def test_account_record_without_image_contents_is_accepted(ledger):
    record = account_record(contents=[])
    ledger.append(record)
    assert ledger.read_verified_events() == [record]


@pytest.mark.parametrize("change", [
    {"user_created_at": "2026-09-01T00:00:00"},
    {"user_created_at": None},
    {"user_created_at": 1},
    {"deleted_at": "2026-11-02"},
    {"user_id": 0},
    {"user_id": 1.5},
    {"user_id": [1]},
    {"user_id": None},
    {"kind": "account"},
    {"contents": None},
    {"contents": [{"content_id": 11, "saved_at": "2026-10-02T00:00:00+00:00", "assets": []}]},
    {"contents": [{"content_id": 0, "saved_at": "2026-10-02T00:00:00+00:00",
                   "assets": [ASSET]}]},
    {"contents": [{"content_id": 11, "saved_at": "2026-10-02T00:00:00", "assets": [ASSET]}]},
    {"contents": [[]]},
    {"email": "user@example.com"},
    {"display_name": "사용자"},
])
def test_invalid_account_record_is_never_written(ledger, change):
    with pytest.raises(ValueError):
        ledger.append(account_record(**change))
    assert ledger.read_verified_checkpoint()["sequence"] == 0


@pytest.mark.parametrize("missing", ["user_created_at", "contents", "deleted_at", "kind"])
def test_account_record_missing_a_field_is_never_written(ledger, missing):
    record = account_record()
    del record[missing]
    with pytest.raises(ValueError):
        ledger.append(record)
    assert ledger.read_verified_checkpoint()["sequence"] == 0


def test_tampered_account_record_stops_verification(ledger, tmp_path):
    ledger.append(account_record())
    path = tmp_path / "ledger" / f"event-{1:020d}.json"
    record = json.loads(path.read_text())
    record["event"]["email"] = "user@example.com"
    path.write_text(json.dumps(record))
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events()


def test_retried_account_deletion_reuses_its_confirmed_record(ledger):
    first = account_record()
    checkpoint = ledger.append(first)
    retried = {**first, "deleted_at": "2026-11-03T00:00:00+00:00", "contents": []}
    assert ledger.append(retried) == checkpoint
    assert ledger.read_operation(first["operation_id"]) == first
    other_account = {**first, "user_created_at": "2026-09-05T00:00:00+00:00"}
    with pytest.raises(LedgerUnavailableError, match="identity conflicts"):
        ledger.append(other_account)


def test_deleted_contents_flattens_account_records_into_image_identities():
    image, account = image_record(), account_record()
    assert deleted_contents(image) == [image]
    assert deleted_contents(account) == [{
        "user_id": 1, "deleted_at": account["deleted_at"], "content_id": 11,
        "saved_at": "2026-10-02T00:00:00+00:00", "assets": [ASSET],
    }]
    assert deleted_contents(account_record(contents=[])) == []


@pytest.fixture
def s3_ledger_settings():
    with mock_aws():
        boto3.client("s3", region_name="us-east-1").create_bucket(Bucket="ledger")
        settings = DeletionLedgerSettings(
            app_environment="test", deletion_ledger_backend="s3",
            deletion_ledger_s3_endpoint_url="https://s3.amazonaws.com",
            deletion_ledger_s3_bucket="ledger", deletion_ledger_s3_region="us-east-1",
            deletion_ledger_s3_access_key_id=SecretStr("testing"),
            deletion_ledger_s3_secret_access_key=SecretStr("testing"),
        )
        get_deletion_ledger(settings).initialize()
        yield settings


def fail_first_get(ledger, error):
    sent = []

    def fail(request, **kwargs):
        sent.append(request)
        if len(sent) == 1:
            raise error(endpoint_url="https://s3.amazonaws.com")

    ledger.store.client.meta.events.register("before-send.s3.GetObject", fail)


@pytest.mark.parametrize("error", [ReadTimeoutError, ConnectionClosedError])
def test_operator_ledger_reads_survive_one_transient_failure(s3_ledger_settings, error):
    """Backup and retention jobs read the ledger with operator_reads (#342)."""
    record = image_record()
    get_deletion_ledger(s3_ledger_settings).append(record)
    ledger = get_deletion_ledger(s3_ledger_settings, operator_reads=True)
    fail_first_get(ledger, error)
    assert ledger.read_verified_events() == [record]


@pytest.mark.parametrize("error", [ReadTimeoutError, ConnectionClosedError])
def test_api_ledger_reads_keep_failing_on_one_transient_failure(s3_ledger_settings, error):
    """Operator read limits never reach API deletion, which keeps its single short attempt."""
    ledger = get_deletion_ledger(s3_ledger_settings)
    fail_first_get(ledger, error)
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events()


def test_ledger_client_limits_per_caller(s3_ledger_settings):
    """User decision (#342): operator reads 3s connect, 10s read, 4 attempts; API unchanged."""
    def limits(ledger):
        config = ledger.store.client.meta.config
        return config.connect_timeout, config.read_timeout, config.retries["total_max_attempts"]

    assert limits(get_deletion_ledger(s3_ledger_settings)) == (1, 2, 1)
    assert limits(get_deletion_ledger(s3_ledger_settings, operator_reads=True)) == (3, 10, 1)


@pytest.fixture
def http_ledger(tmp_path):
    """Path-style S3 stand-in serving a real ledger; `plan` scripts how the next GETs fail.

    drop: connection closed before any response. cut: HTTP 200 headers, then closed mid-body.
    stall: HTTP 200 headers, then no body for longer than the read timeout.
    """
    root = tmp_path / "served"
    served = DeletionLedger(LocalLedgerStore(root))
    served.initialize()
    record = image_record()
    served.append(record)
    plan, gets, release = [], [], threading.Event()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            gets.append(self.path)
            failure = plan.pop(0) if plan else None
            if failure == "drop":
                self.close_connection = True
                return
            path = root / self.path.split("/", 2)[2]
            body = path.read_bytes() if path.exists() else (
                b"<Error><Code>NoSuchKey</Code></Error>"
            )
            self.send_response(200 if path.exists() else 404)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if failure == "stall":
                release.wait(15)
            elif failure != "cut":
                self.wfile.write(body)
            self.close_connection = failure is not None

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    settings = DeletionLedgerSettings(
        app_environment="test", deletion_ledger_backend="s3",
        deletion_ledger_s3_endpoint_url=f"http://127.0.0.1:{server.server_port}",
        deletion_ledger_s3_bucket="ledger", deletion_ledger_s3_region="us-east-1",
        deletion_ledger_s3_addressing_style="path",
        deletion_ledger_s3_access_key_id=SecretStr("testing"),
        deletion_ledger_s3_secret_access_key=SecretStr("testing"),
    )
    yield SimpleNamespace(settings=settings, record=record, plan=plan, gets=gets)
    release.set()
    server.shutdown()
    server.server_close()


@pytest.mark.parametrize("failure", ["drop", "cut", "stall"])
def test_operator_read_survives_one_request_or_body_failure(http_ledger, failure):
    """#342 decision S1: a failure before the response or while receiving the body is retried."""
    http_ledger.plan[:] = [failure]
    ledger = get_deletion_ledger(http_ledger.settings, operator_reads=True)
    assert ledger.read_verified_events() == [http_ledger.record]


@pytest.mark.parametrize("failure", ["drop", "cut", "stall"])
def test_api_read_is_not_retried(http_ledger, failure):
    """API deletion keeps its single attempt; the first failure ends the read."""
    http_ledger.plan[:] = [failure]
    with pytest.raises(Exception):
        get_deletion_ledger(http_ledger.settings).read_verified_events()
    assert len(http_ledger.gets) == 1


@pytest.mark.parametrize("failure", ["drop", "cut"])
def test_operator_read_has_four_attempts_in_total(http_ledger, failure):
    """Request and body share one budget of 4 attempts; SDK retries never multiply it."""
    http_ledger.plan[:] = [failure] * 3
    ledger = get_deletion_ledger(http_ledger.settings, operator_reads=True)
    assert ledger.read_verified_events() == [http_ledger.record]
    http_ledger.gets.clear()
    http_ledger.plan[:] = [failure] * 4
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events()
    assert len(http_ledger.gets) == 4 and len(set(http_ledger.gets)) == 1
