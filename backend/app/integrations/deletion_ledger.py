"""Independent deletion receipts. Callers serialize writers with advisory lock 74264002."""

import hashlib
import json
import os
import tempfile
from datetime import datetime
from pathlib import Path
from uuid import UUID, uuid4

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.deletion_ledger_config import DeletionLedgerSettings

LEDGER_WRITE_LOCK = 74264002
IMAGE_CLEANUP_LOCK = 74264001
EMPTY_DIGEST = "0" * 64


class LedgerUnavailableError(Exception):
    pass


class DeletedAsset(BaseModel):
    model_config = ConfigDict(extra="forbid")
    storage_backend: str = Field(pattern=r"^(local|s3)$")
    storage_key: str = Field(min_length=1, max_length=512)
    sha256: str | None = Field(default=None, pattern=r"^[0-9a-f]{64}$")
    size_bytes: int | None = Field(default=None, ge=0)


class DeletionIntent(BaseModel):
    model_config = ConfigDict(extra="forbid")
    operation_id: UUID
    user_id: int = Field(gt=0)
    content_id: int = Field(gt=0)
    saved_at: str
    deleted_at: str
    assets: list[DeletedAsset] = Field(min_length=1)

    @field_validator("saved_at", "deleted_at")
    @classmethod
    def require_aware_timestamp(cls, value: str) -> str:
        if datetime.fromisoformat(value).utcoffset() is None:
            raise ValueError("Deletion timestamps require a timezone")
        return value


def canonical_json(value: dict) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


class LocalLedgerStore:
    def __init__(self, root: Path):
        self.root = root.resolve()

    def read(self, key: str) -> bytes:
        return (self.root / key).read_bytes()

    def write(self, key: str, value: bytes) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        temporary_path = None
        try:
            with tempfile.NamedTemporaryFile(dir=self.root, delete=False) as temporary:
                temporary_path = temporary.name
                temporary.write(value)
                temporary.flush()
                os.fsync(temporary.fileno())
            os.replace(temporary_path, self.root / key)
        finally:
            if temporary_path is not None:
                Path(temporary_path).unlink(missing_ok=True)
        descriptor = os.open(self.root, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)


class S3LedgerStore:
    def __init__(self, config: DeletionLedgerSettings):
        self.bucket = config.deletion_ledger_s3_bucket
        self.client = boto3.client(
            "s3",
            endpoint_url=config.deletion_ledger_s3_endpoint_url,
            region_name=config.deletion_ledger_s3_region,
            aws_access_key_id=config.deletion_ledger_s3_access_key_id.get_secret_value(),
            aws_secret_access_key=config.deletion_ledger_s3_secret_access_key.get_secret_value(),
            config=Config(
                signature_version="s3v4",
                connect_timeout=1,
                read_timeout=2,
                retries={"total_max_attempts": 1},
                s3={"addressing_style": config.deletion_ledger_s3_addressing_style},
            ),
        )

    def read(self, key: str) -> bytes:
        try:
            response = self.client.get_object(Bucket=self.bucket, Key=key)
            with response["Body"] as stream:
                return stream.read()
        except ClientError as exc:
            if exc.response["Error"]["Code"] in {"NoSuchKey", "404", "NotFound"}:
                raise FileNotFoundError(key) from exc
            raise

    def write(self, key: str, value: bytes) -> None:
        self.client.put_object(
            Bucket=self.bucket, Key=key, Body=value, ContentType="application/json"
        )


class DeletionLedger:
    """Small append-only receipt chain; immutable events are verified against the current head.

    Initialization is an explicit operator action. Missing head/epoch never means no deletions.
    The chain detects missing/corrupt records, not a malicious rollback of the entire store.
    """

    def __init__(self, store: LocalLedgerStore | S3LedgerStore):
        self.store = store

    def initialize(self) -> dict:
        try:
            self.store.read("namespace.json")
        except FileNotFoundError:
            try:
                self.store.read("head.json")
            except FileNotFoundError:
                namespace = str(uuid4())
                self.store.write("namespace.json", canonical_json({"namespace": namespace}))
                self.store.write(
                    "head.json",
                    canonical_json(
                        {
                            "namespace": namespace,
                            "sequence": 0,
                            "digest": EMPTY_DIGEST,
                        }
                    ),
                )
            else:
                raise LedgerUnavailableError("Deletion ledger namespace is missing")
        return self.read_verified_checkpoint()

    def _read(self, key: str, *, missing_ok: bool = False) -> dict | None:
        try:
            value = json.loads(self.store.read(key))
            if not isinstance(value, dict):
                raise ValueError("Invalid deletion ledger object")
            return value
        except FileNotFoundError as exc:
            if missing_ok:
                return None
            raise LedgerUnavailableError("Deletion ledger cannot be verified") from exc
        except (OSError, ValueError, BotoCoreError, ClientError) as exc:
            raise LedgerUnavailableError("Deletion ledger cannot be verified") from exc

    def _validate_head(self, checkpoint: dict) -> str:
        try:
            namespace = self._read("namespace.json")["namespace"]
            UUID(namespace)
            if set(checkpoint) != {"namespace", "sequence", "digest"}:
                raise ValueError("Invalid checkpoint")
            if (
                checkpoint["namespace"] != namespace
                or type(checkpoint["sequence"]) is not int
                or checkpoint["sequence"] < 0
                or len(bytes.fromhex(checkpoint["digest"])) != 32
            ):
                raise ValueError("Invalid checkpoint")
            return namespace
        except (KeyError, TypeError, ValueError) as exc:
            raise LedgerUnavailableError("Deletion ledger cannot be verified") from exc

    def _validate_record(self, record: dict, checkpoint: dict, sequence: int) -> dict:
        try:
            if (
                set(record) != {"namespace", "sequence", "previous_digest", "event"}
                or record["namespace"] != checkpoint["namespace"]
                or type(record["sequence"]) is not int
                or record["sequence"] != sequence
                or len(bytes.fromhex(record["previous_digest"])) != 32
            ):
                raise ValueError("Invalid deletion event")
            event = DeletionIntent.model_validate(record["event"]).model_dump(mode="json")
            if event != record["event"]:
                raise ValueError("Noncanonical deletion event")
            return event
        except (KeyError, TypeError, ValueError) as exc:
            raise LedgerUnavailableError("Deletion ledger cannot be verified") from exc

    def _read_tip(self) -> dict:
        """Foreground writes validate the head/tip only; recovery verifies the entire prefix."""
        checkpoint = self._read("head.json")
        self._validate_head(checkpoint)
        if checkpoint["sequence"] == 0:
            if checkpoint["digest"] != EMPTY_DIGEST:
                raise LedgerUnavailableError("Invalid empty deletion ledger")
        else:
            record = self._read(f"event-{checkpoint['sequence']:020d}.json")
            self._validate_record(record, checkpoint, checkpoint["sequence"])
            if hashlib.sha256(canonical_json(record)).hexdigest() != checkpoint["digest"]:
                raise LedgerUnavailableError("Invalid deletion ledger tip")
        return checkpoint

    def read_verified_checkpoint(self) -> dict:
        checkpoint = self._read("head.json")
        self.read_verified_events(checkpoint)
        return checkpoint

    def read_checkpoint_tip(self) -> dict:
        """Bounded capture only. Verify its full immutable prefix before publishing a backup."""
        return self._read_tip()

    def read_verified_events(self, checkpoint: dict | None = None) -> list[dict]:
        checkpoint = checkpoint if checkpoint is not None else self._read("head.json")
        try:
            self._validate_head(checkpoint)
            sequence = checkpoint["sequence"]
            previous = EMPTY_DIGEST
            events = []
            for number in range(1, sequence + 1):
                record = self._read(f"event-{number:020d}.json")
                event = self._validate_record(record, checkpoint, number)
                if record["previous_digest"] != previous:
                    raise ValueError("Invalid event sequence")
                previous = hashlib.sha256(canonical_json(record)).hexdigest()
                events.append(event)
            if previous != checkpoint["digest"]:
                raise ValueError("Invalid checkpoint digest")
            return events
        except (KeyError, TypeError, ValueError) as exc:
            raise LedgerUnavailableError("Deletion ledger cannot be verified") from exc

    def _publish_record(self, record: dict) -> dict:
        target = {
            "namespace": record["namespace"],
            "sequence": record["sequence"],
            "digest": hashlib.sha256(canonical_json(record)).hexdigest(),
        }
        receipt = {**target, "event": record["event"]}
        receipt_key = f"operation-{record['event']['operation_id']}.json"
        try:
            self.store.write(f"event-{record['sequence']:020d}.json", canonical_json(record))
            self.store.write(receipt_key, canonical_json(receipt))
            self.store.write("head.json", canonical_json(target))
        except (OSError, BotoCoreError, ClientError):
            # A PUT acknowledgement can be lost after storage committed it. Verify directly.
            pass
        if self._read_tip() != target or self._read(receipt_key) != receipt:
            raise LedgerUnavailableError("Deletion ledger write is unconfirmed")
        return target

    def _operation(self, operation_id: str, checkpoint: dict) -> dict | None:
        receipt = self._read(f"operation-{UUID(operation_id)}.json", missing_ok=True)
        if receipt is None:
            return None
        try:
            sequence = receipt["sequence"]
            if (
                set(receipt) != {"namespace", "sequence", "digest", "event"}
                or receipt["namespace"] != checkpoint["namespace"]
                or type(sequence) is not int
                or not 1 <= sequence <= checkpoint["sequence"]
                or receipt["event"]["operation_id"] != operation_id
            ):
                raise ValueError("Invalid deletion receipt")
            record = self._read(f"event-{sequence:020d}.json")
            self._validate_record(record, checkpoint, sequence)
            if (
                record["event"] != receipt["event"]
                or hashlib.sha256(canonical_json(record)).hexdigest() != receipt["digest"]
            ):
                raise ValueError("Invalid deletion receipt")
            return receipt["event"]
        except (KeyError, TypeError, ValueError) as exc:
            raise LedgerUnavailableError("Deletion ledger cannot be verified") from exc

    def read_operation(self, operation_id: str) -> dict:
        event = self._operation(operation_id, self._read_tip())
        if event is None:
            raise LedgerUnavailableError("Deletion operation is missing")
        return event

    def append(self, event: dict) -> dict:
        event = DeletionIntent.model_validate(event).model_dump(mode="json")
        checkpoint = self._read_tip()
        # Complete one interrupted writer before reusing its sequence for another operation.
        sequence = checkpoint["sequence"] + 1
        pending = self._read(f"event-{sequence:020d}.json", missing_ok=True)
        if pending is not None:
            self._validate_record(pending, checkpoint, sequence)
            if pending["previous_digest"] != checkpoint["digest"]:
                raise LedgerUnavailableError("Interrupted deletion event conflicts")
            checkpoint = self._publish_record(pending)
        previous = self._operation(event["operation_id"], checkpoint)
        if previous is not None:
            if {k: v for k, v in previous.items() if k != "deleted_at"} != {
                k: v for k, v in event.items() if k != "deleted_at"
            }:
                raise LedgerUnavailableError("Deletion operation identity conflicts")
            return checkpoint
        return self._publish_record(
            {
                "namespace": checkpoint["namespace"],
                "sequence": checkpoint["sequence"] + 1,
                "previous_digest": checkpoint["digest"],
                "event": event,
            }
        )


def get_deletion_ledger(config: DeletionLedgerSettings | None = None) -> DeletionLedger:
    if config is None:
        # API callers retain full settings validation; standalone operators supply ledger settings.
        from app.core.config import settings

        config = settings
    store = (
        S3LedgerStore(config)
        if config.deletion_ledger_backend == "s3"
        else LocalLedgerStore(config.deletion_ledger_root)
    )
    return DeletionLedger(store)
