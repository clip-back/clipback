"""Deletion ledger start point (ADR 0013, #344): verification from the start, disposal, R1 tip.

Observed through the ledger's public interface and the objects left in its store.
"""

import hashlib
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from types import SimpleNamespace
from uuid import uuid4

import boto3
import pytest
from moto import mock_aws
from pydantic import SecretStr

from app.core.deletion_ledger_config import DeletionLedgerSettings
from app.integrations.deletion_ledger import (
    DeletionLedger,
    LedgerUnavailableError,
    LocalLedgerStore,
    canonical_json,
    get_deletion_ledger,
)

ASSET = {"storage_backend": "s3", "storage_key": "a.png", "sha256": "a" * 64, "size_bytes": 3}
START = "start.json"


def image_record(content_id=10):
    return {
        "operation_id": str(uuid4()), "user_id": 1, "content_id": content_id,
        "saved_at": "2026-10-01T00:00:00+00:00", "deleted_at": "2026-11-01T00:00:00+00:00",
        "assets": [ASSET],
    }


def account_record():
    return {
        "kind": "account_deletion", "operation_id": str(uuid4()), "user_id": 2,
        "user_created_at": "2026-09-01T00:00:00+00:00",
        "deleted_at": "2026-11-02T00:00:00+00:00",
        "contents": [
            {"content_id": 11, "saved_at": "2026-10-02T00:00:00+00:00", "assets": [ASSET]},
        ],
    }


def event_key(sequence):
    return f"event-{sequence:020d}.json"


def receipt_key(event):
    return f"operation-{event['operation_id']}.json"


class RecordingStore(LocalLedgerStore):
    """Local store that records each call; `before_delete` runs just before a deletion."""

    def __init__(self, root):
        super().__init__(root)
        self.calls = []
        self.before_delete = None

    def read(self, key):
        self.calls.append(("read", key))
        return super().read(key)

    def write(self, key, value):
        self.calls.append(("write", key))
        return super().write(key, value)

    def delete(self, key):
        if self.before_delete is not None:
            self.before_delete(key)
        self.calls.append(("delete", key))
        return super().delete(key)


@pytest.fixture
def root(tmp_path):
    return tmp_path / "ledger"


@pytest.fixture
def ledger(root):
    value = DeletionLedger(RecordingStore(root))
    value.initialize()
    return value


def filled(ledger, count):
    events = [image_record(content_id=10 + number) for number in range(count)]
    for event in events:
        ledger.append(event)
    return events


def stored(root, key):
    return json.loads((root / key).read_text())


def digest_of(root, sequence):
    return hashlib.sha256(canonical_json(stored(root, event_key(sequence)))).hexdigest()


def write_start(root, value):
    (root / START).write_bytes(value if isinstance(value, bytes) else canonical_json(value))


def start_at(root, sequence):
    return {"namespace": stored(root, "head.json")["namespace"], "sequence": sequence,
            "digest": digest_of(root, sequence)}


def remove_through(root, events, sequence):
    """Remove the files of records 1..sequence as a finished disposal leaves them."""
    for number in range(1, sequence + 1):
        (root / receipt_key(events[number - 1])).unlink()
        (root / event_key(number)).unlink()


def remaining(root):
    return sorted(path.name for path in root.iterdir())


# --- Verification from the start point -------------------------------------------------


def test_missing_start_verifies_from_the_first_record(ledger, root):
    events = filled(ledger, 2)
    assert not (root / START).exists()
    assert ledger.read_verified_events() == events
    assert ledger.read_verified_checkpoint() == stored(root, "head.json")


def test_verification_starts_after_the_start_point_and_returns_later_records(ledger, root):
    events = filled(ledger, 4)
    write_start(root, start_at(root, 2))
    remove_through(root, events, 2)
    assert ledger.read_verified_events() == events[2:]
    head = ledger.read_verified_checkpoint()
    assert head == stored(root, "head.json") and head["sequence"] == 4


def test_start_at_head_verifies_an_empty_list(ledger, root):
    events = filled(ledger, 3)
    write_start(root, start_at(root, 3))
    remove_through(root, events, 3)
    assert ledger.read_verified_events() == []
    assert ledger.read_verified_checkpoint()["sequence"] == 3


def test_files_left_at_or_before_the_start_are_not_read(ledger, root):
    """Interrupted file deletion: verification passes and the next deletion removes them."""
    events = filled(ledger, 3)
    write_start(root, start_at(root, 2))
    (root / event_key(1)).write_text("not json")
    ledger.store.calls.clear()
    assert ledger.read_verified_events() == events[2:]
    assert ("read", event_key(1)) not in ledger.store.calls
    assert ("read", event_key(2)) not in ledger.store.calls


@pytest.mark.parametrize("corruption", [
    "not_json", "not_object", "missing_field", "extra_field", "other_namespace",
    "digest_not_hex", "digest_short", "sequence_string", "sequence_negative", "sequence_bool",
])
def test_corrupt_start_point_fails_every_full_verification(ledger, root, corruption):
    filled(ledger, 3)
    value = start_at(root, 1)
    changes = {
        "not_json": b"{not json",
        "not_object": b"[1]",
        "missing_field": {k: v for k, v in value.items() if k != "digest"},
        "extra_field": {**value, "event": {}},
        "other_namespace": {**value, "namespace": str(uuid4())},
        "digest_not_hex": {**value, "digest": "z" * 64},
        "digest_short": {**value, "digest": "a" * 62},
        "sequence_string": {**value, "sequence": "1"},
        "sequence_negative": {**value, "sequence": -1},
        "sequence_bool": {**value, "sequence": True},
    }
    write_start(root, changes[corruption])
    head = stored(root, "head.json")
    for read in (ledger.read_verified_events, ledger.read_verified_checkpoint,
                 lambda: ledger.read_verified_events(head)):
        with pytest.raises(LedgerUnavailableError):
            read()


def test_start_digest_must_link_to_the_next_record(ledger, root):
    filled(ledger, 3)
    write_start(root, {**start_at(root, 1), "digest": "b" * 64})
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events()


def test_start_after_head_fails(ledger, root):
    filled(ledger, 2)
    write_start(root, {**start_at(root, 2), "sequence": 3})
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_checkpoint()


def test_checkpoint_before_the_start_fails(ledger, root):
    events = filled(ledger, 3)
    older = {**stored(root, "head.json"), "sequence": 1, "digest": digest_of(root, 1)}
    write_start(root, start_at(root, 2))
    remove_through(root, events, 2)
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events(older)


def test_checkpoint_at_the_start_must_carry_its_digest(ledger, root):
    events = filled(ledger, 3)
    at_start = {**stored(root, "head.json"), "sequence": 2, "digest": digest_of(root, 2)}
    write_start(root, start_at(root, 2))
    remove_through(root, events, 2)
    assert ledger.read_verified_events(at_start) == []
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events({**at_start, "digest": "c" * 64})


def test_start_lost_after_a_disposal_removed_the_first_record_fails(ledger, root):
    events = filled(ledger, 3)
    write_start(root, start_at(root, 1))
    remove_through(root, events, 1)
    (root / START).unlink()
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events()


def test_start_lost_before_any_record_was_removed_is_not_detected(ledger, root):
    """Q-B5 design limit: nothing disposed in any run yet and records 1..head all remain."""
    events = filled(ledger, 3)
    ledger.advance_start(2)
    (root / START).unlink()
    assert ledger.read_verified_events() == events


def test_start_lost_during_a_later_disposal_fails(ledger, root):
    """A previous disposal finished (record 1 is gone); the next one raised the start."""
    filled(ledger, 4)
    ledger.dispose_through(1)
    ledger.advance_start(3)
    (root / START).unlink()
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events()


def test_start_read_error_is_not_treated_as_missing(ledger, root):
    filled(ledger, 2)
    (root / START).mkdir()
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events()


# --- Tip check (R1) ---------------------------------------------------------------------


def test_tip_with_its_last_record_never_reads_the_start(ledger, root):
    """Start = head but the last record file remains: checked by the record, start unread."""
    events = filled(ledger, 2)
    write_start(root, b"corrupt start is not read")
    ledger.store.calls.clear()
    assert ledger.read_checkpoint_tip() == stored(root, "head.json")
    assert ledger.read_operation(events[1]["operation_id"]) == events[1]
    assert ledger.append(image_record())["sequence"] == 3
    assert ("read", START) not in ledger.store.calls


def test_tip_reads_head_namespace_last_record_and_start_only_when_it_is_gone(ledger, root):
    """User decision ("응", 2026-11-13): 3 reads, plus the start only without the last record."""
    filled(ledger, 2)
    ledger.store.calls.clear()
    ledger.read_checkpoint_tip()
    assert ledger.store.calls == [
        ("read", "head.json"), ("read", "namespace.json"), ("read", event_key(2)),
    ]
    ledger.dispose_through(2)
    ledger.store.calls.clear()
    ledger.read_checkpoint_tip()
    assert ledger.store.calls == [
        ("read", "head.json"), ("read", "namespace.json"), ("read", event_key(2)),
        ("read", START),
    ]


def test_fully_disposed_ledger_keeps_accepting_deletions(ledger, root):
    """R1: tip from the start point; the next record links to the start digest."""
    events = filled(ledger, 2)
    ledger.dispose_through(2)
    start = stored(root, START)
    assert ledger.read_checkpoint_tip() == start == stored(root, "head.json")
    account = account_record()
    checkpoint = ledger.append(account)
    assert checkpoint["sequence"] == 3
    assert stored(root, event_key(3))["previous_digest"] == start["digest"]
    assert ledger.read_operation(account["operation_id"]) == account
    with pytest.raises(LedgerUnavailableError, match="missing"):
        ledger.read_operation(events[0]["operation_id"])


@pytest.mark.parametrize("start", ["missing", "corrupt", "other_sequence", "other_digest",
                                   "other_namespace"])
def test_tip_without_its_last_record_needs_a_start_equal_to_head(ledger, root, start):
    events = filled(ledger, 2)
    value = start_at(root, 2)
    remove_through(root, events, 2)
    changes = {
        "missing": None, "corrupt": b"{",
        "other_sequence": {**value, "sequence": 1},
        "other_digest": {**value, "digest": "d" * 64},
        "other_namespace": {**value, "namespace": str(uuid4())},
    }
    if changes[start] is not None:
        write_start(root, changes[start])
    for call in (ledger.read_checkpoint_tip, lambda: ledger.append(image_record()),
                 lambda: ledger.read_operation(events[1]["operation_id"])):
        with pytest.raises(LedgerUnavailableError):
            call()
    assert not (root / event_key(3)).exists()


def test_unreadable_last_record_is_not_replaced_by_the_start(ledger, root):
    filled(ledger, 2)
    write_start(root, start_at(root, 2))
    (root / event_key(2)).write_text("not json")
    for call in (ledger.read_checkpoint_tip, lambda: ledger.append(image_record())):
        with pytest.raises(LedgerUnavailableError):
            call()


# --- Disposal ---------------------------------------------------------------------------


def test_disposal_writes_the_start_then_removes_receipts_and_records_in_order(ledger, root):
    events = filled(ledger, 3)
    expected_start = start_at(root, 2)
    ledger.store.calls.clear()
    assert ledger.dispose_through(2) == expected_start
    assert stored(root, START) == expected_start
    calls = ledger.store.calls
    written = calls.index(("write", START))
    first_delete = next(index for index, call in enumerate(calls) if call[0] == "delete")
    assert ("read", START) in calls[written:first_delete]
    assert [key for op, key in calls if op == "delete"] == [
        receipt_key(events[0]), event_key(1), receipt_key(events[1]), event_key(2),
    ]
    assert remaining(root) == sorted([
        "head.json", "namespace.json", START, event_key(3), receipt_key(events[2]),
    ])
    assert ledger.read_verified_events() == events[2:]


def test_unconfirmed_start_write_removes_no_file(ledger, root, monkeypatch):
    filled(ledger, 2)
    before = remaining(root)
    write = ledger.store.write

    def lost(key, value):
        if key != START:
            write(key, value)
        raise OSError("acknowledgement lost")

    monkeypatch.setattr(ledger.store, "write", lost)
    with pytest.raises(LedgerUnavailableError, match="unconfirmed"):
        ledger.dispose_through(2)
    assert remaining(root) == before


def test_start_write_is_confirmed_by_reading_it_back(ledger, root, monkeypatch):
    """A lost acknowledgement after the store committed is not a failure."""
    filled(ledger, 2)
    write = ledger.store.write

    def committed(key, value):
        write(key, value)
        raise OSError("acknowledgement lost")

    monkeypatch.setattr(ledger.store, "write", committed)
    assert ledger.advance_start(1) == start_at(root, 1)


def test_start_cannot_move_back_or_past_head(ledger, root):
    filled(ledger, 3)
    ledger.advance_start(2)
    for sequence in (1, 4):
        with pytest.raises(ValueError):
            ledger.advance_start(sequence)
    assert ledger.advance_start(2) == stored(root, START)


def test_interrupted_file_deletion_continues_on_the_next_call(ledger, root):
    events = filled(ledger, 3)
    ledger.advance_start(3)
    deleted = []

    def fail_third(key):
        if len(deleted) == 2:
            raise OSError("delete failed")
        deleted.append(key)

    ledger.store.before_delete = fail_third
    with pytest.raises(OSError):
        ledger.delete_disposed()
    assert deleted == [receipt_key(events[0]), event_key(1)]
    ledger.store.before_delete = None
    ledger.store.calls.clear()
    assert ledger.delete_disposed() == 2
    assert [key for op, key in ledger.store.calls if op == "delete"] == [
        receipt_key(events[1]), event_key(2), receipt_key(events[2]), event_key(3),
    ]
    assert remaining(root) == sorted(["head.json", "namespace.json", START])
    assert ledger.delete_disposed() == 0


def test_deleting_a_missing_object_succeeds_locally(ledger, root):
    ledger.store.delete("operation-absent.json")
    assert not (root / "operation-absent.json").exists()


# --- Full flow and interleaving (R1) ------------------------------------------------------


def test_dispose_everything_then_append_capture_and_verify(ledger, root):
    """start = head > 0 → files removed → new append → new checkpoint capture → verification."""
    filled(ledger, 3)
    start = ledger.dispose_through(3)
    assert remaining(root) == sorted(["head.json", "namespace.json", START])
    new = image_record(content_id=99)
    ledger.append(new)
    assert stored(root, event_key(4))["previous_digest"] == start["digest"]
    checkpoint = ledger.read_checkpoint_tip()
    assert checkpoint["sequence"] == 4
    assert ledger.read_verified_events(checkpoint) == [new]
    assert ledger.read_verified_checkpoint() == checkpoint


@pytest.mark.parametrize("moment", ["before_last_record", "after_last_record"])
def test_append_during_file_deletion(ledger, root, moment):
    """`maintain` deletes files outside the lock; an API append arrives in between."""
    filled(ledger, 3)
    ledger.advance_start(3)
    new = image_record(content_id=99)
    appended = []

    def interleave(key):
        last = event_key(3)
        if not appended and (
            (moment == "before_last_record" and key == last)
            or (moment == "after_last_record" and key == "after")
        ):
            appended.append(ledger.append(new))

    ledger.store.before_delete = interleave
    ledger.delete_disposed()
    if moment == "after_last_record":
        assert not (root / event_key(3)).exists()
        interleave("after")
    assert appended[0]["sequence"] == 4
    assert remaining(root) == sorted([
        "head.json", "namespace.json", START, event_key(4), receipt_key(new),
    ])
    assert ledger.read_verified_events() == [new]


def test_append_that_read_head_before_the_last_record_was_deleted(ledger, root):
    """Barrier: append has read head; the last record file disappears before it is read."""
    filled(ledger, 3)
    ledger.advance_start(3)
    head_read, proceed = threading.Event(), threading.Event()
    read = ledger.store.read

    def paused(key):
        value = read(key)
        if key == "head.json" and threading.current_thread() is not threading.main_thread():
            head_read.set()
            assert proceed.wait(5)
        return value

    ledger.store.read = paused
    new, result = image_record(content_id=99), {}
    worker = threading.Thread(target=lambda: result.update(checkpoint=ledger.append(new)))
    worker.start()
    assert head_read.wait(5)
    assert ledger.delete_disposed() == 3
    assert not (root / event_key(3)).exists()
    proceed.set()
    worker.join(5)
    assert result["checkpoint"]["sequence"] == 4
    assert ("read", START) in ledger.store.calls
    assert ledger.read_verified_events() == [new]
    assert remaining(root) == sorted([
        "head.json", "namespace.json", START, event_key(4), receipt_key(new),
    ])


# --- Readers that compare a recovery point with the live ledger -------------------------


def test_latest_deletions_follows_the_start(ledger, root):
    from scripts.image_backup_jobs import latest_deletions

    filled(ledger, 2)
    point = ledger.read_checkpoint_tip()
    older = {**point, "sequence": 1, "digest": digest_of(root, 1)}
    ledger.dispose_through(2)
    later = image_record(content_id=99)
    current = ledger.append(later)
    assert latest_deletions(ledger, point) == (current, [later])
    with pytest.raises(LedgerUnavailableError):
        latest_deletions(ledger, older)


# --- S3 store ---------------------------------------------------------------------------


@pytest.fixture
def s3_settings():
    with mock_aws():
        boto3.client("s3", region_name="us-east-1").create_bucket(Bucket="ledger")
        yield DeletionLedgerSettings(
            app_environment="test", deletion_ledger_backend="s3",
            deletion_ledger_s3_endpoint_url="https://s3.amazonaws.com",
            deletion_ledger_s3_bucket="ledger", deletion_ledger_s3_region="us-east-1",
            deletion_ledger_s3_access_key_id=SecretStr("testing"),
            deletion_ledger_s3_secret_access_key=SecretStr("testing"),
        )


def bucket_keys():
    listed = boto3.client("s3", region_name="us-east-1").list_objects_v2(Bucket="ledger")
    return sorted(item["Key"] for item in listed.get("Contents", []))


def test_s3_disposal_and_verification_without_listing(s3_settings):
    get_deletion_ledger(s3_settings).initialize()
    api = get_deletion_ledger(s3_settings)
    events = filled(api, 3)
    operator = get_deletion_ledger(s3_settings, operator_reads=True)
    sent = []
    operator.store.client.meta.events.register(
        "before-send.s3.*", lambda request, **kwargs: sent.append(request.method)
    )
    operator.store.client.meta.events.register(
        "before-call.s3.ListObjects*", lambda **kwargs: sent.append("LIST")
    )
    start = operator.dispose_through(2)
    assert "LIST" not in sent
    assert sent.count("DELETE") == 4
    assert bucket_keys() == sorted([
        "head.json", "namespace.json", START, event_key(3),
        f"operation-{events[2]['operation_id']}.json",
    ])
    assert operator.read_verified_events() == events[2:]
    assert start["sequence"] == 2
    api.store.delete("operation-absent.json")
    operator.dispose_through(3)
    assert api.append(image_record(content_id=99))["sequence"] == 4
    assert operator.read_verified_checkpoint()["sequence"] == 4


@pytest.fixture
def http_ledger(tmp_path):
    """Path-style S3 stand-in serving a local ledger; `failures[key]` scripts its next GETs.

    drop: connection closed before any response. cut: HTTP 200 headers, then closed mid-body.
    error: HTTP 500. DELETE requests follow `delete_failures` the same way.
    """
    root = tmp_path / "served"
    served = DeletionLedger(LocalLedgerStore(root))
    served.initialize()
    events = filled(served, 2)
    failures, requests = {}, []
    delete_failures = []

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def respond(self, failure, status, body):
            if failure == "drop":
                self.close_connection = True
                return
            if failure == "error":
                status, body = 500, b"<Error><Code>InternalError</Code></Error>"
            self.send_response(status)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if failure != "cut":
                self.wfile.write(body)
            self.close_connection = failure is not None

        def do_GET(self):
            key = self.path.split("/", 2)[2]
            requests.append(("GET", key))
            planned = failures.get(key)
            failure = planned.pop(0) if planned else None
            path = root / key
            if path.exists():
                self.respond(failure, 200, path.read_bytes())
            else:
                self.respond(failure, 404, b"<Error><Code>NoSuchKey</Code></Error>")

        def do_DELETE(self):
            key = self.path.split("/", 2)[2]
            requests.append(("DELETE", key))
            failure = delete_failures.pop(0) if delete_failures else None
            if failure is None:
                (root / key).unlink(missing_ok=True)
            self.respond(failure, 204, b"")

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
    yield SimpleNamespace(settings=settings, root=root, served=served, events=events,
                          failures=failures, delete_failures=delete_failures,
                          requests=requests)
    server.shutdown()
    server.server_close()


def gets(http_ledger, key):
    return [request for request in http_ledger.requests if request == ("GET", key)]


@pytest.mark.parametrize("failure", ["drop", "cut", "error"])
def test_operator_start_read_survives_one_failure(http_ledger, failure):
    http_ledger.served.advance_start(1)
    http_ledger.failures[START] = [failure]
    ledger = get_deletion_ledger(http_ledger.settings, operator_reads=True)
    assert ledger.read_verified_events() == http_ledger.events[1:]
    assert len(gets(http_ledger, START)) == 2


@pytest.mark.parametrize("failure", ["drop", "cut"])
def test_operator_start_read_has_four_attempts_of_its_own(http_ledger, failure):
    http_ledger.served.advance_start(1)
    ledger = get_deletion_ledger(http_ledger.settings, operator_reads=True)
    http_ledger.failures[START] = [failure] * 3
    assert ledger.read_verified_events() == http_ledger.events[1:]
    http_ledger.requests.clear()
    http_ledger.failures[START] = [failure] * 4
    with pytest.raises(LedgerUnavailableError):
        ledger.read_verified_events()
    assert len(gets(http_ledger, START)) == 4


@pytest.mark.parametrize("failure", ["drop", "cut", "error"])
def test_api_start_read_failure_is_not_missing(http_ledger, failure):
    """Like any API read, the single attempt fails (a cut body surfaces from urllib3)."""
    http_ledger.served.dispose_through(2)
    http_ledger.failures[START] = [failure]
    with pytest.raises(Exception):
        get_deletion_ledger(http_ledger.settings).read_checkpoint_tip()
    assert len(gets(http_ledger, START)) == 1


def test_api_tip_reads_the_start_once_only_without_the_last_record(http_ledger):
    ledger = get_deletion_ledger(http_ledger.settings)
    ledger.read_checkpoint_tip()
    assert http_ledger.requests == [
        ("GET", "head.json"), ("GET", "namespace.json"), ("GET", event_key(2)),
    ]
    http_ledger.served.dispose_through(2)
    http_ledger.requests.clear()
    assert ledger.read_checkpoint_tip()["sequence"] == 2
    assert http_ledger.requests == [
        ("GET", "head.json"), ("GET", "namespace.json"), ("GET", event_key(2)), ("GET", START),
    ]


@pytest.mark.parametrize("failure", ["drop", "error"])
def test_last_record_read_error_is_not_replaced_by_the_start(http_ledger, failure):
    http_ledger.served.advance_start(2)
    http_ledger.failures[event_key(2)] = [failure]
    with pytest.raises(LedgerUnavailableError):
        get_deletion_ledger(http_ledger.settings).read_checkpoint_tip()
    assert gets(http_ledger, START) == []


@pytest.mark.parametrize("failure", ["drop", "error"])
def test_object_deletion_is_attempted_once(http_ledger, failure):
    """Q-B6: one SDK attempt and no outer retry; the next run continues the deletion."""
    http_ledger.served.advance_start(2)
    operator = get_deletion_ledger(http_ledger.settings, operator_reads=True)
    http_ledger.delete_failures[:] = [failure]
    with pytest.raises(Exception):
        operator.delete_disposed()
    deletes = [request for request in http_ledger.requests if request[0] == "DELETE"]
    assert deletes == [("DELETE", receipt_key(http_ledger.events[0]))]
    assert operator.delete_disposed() == 2
    assert operator.read_verified_events() == []
