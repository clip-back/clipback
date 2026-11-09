"""콘텐츠 저장 재시도·실패 흐름 고정 테스트(#321).

상위 스펙 #320의 미확인 행(R03·R07·R16·R18a–R18d·R24)과 순서 조합·fingerprint 변형 입력을
기준 코드 906d253(backend 동일 bd9047e)에서 실제 실행해 관측한 값 그대로 동결한다.
실패 주입은 SQLAlchemy `AsyncSession`, 저장소 client class, 전송 관측·이벤트 repository,
외부 호출 대역, 정리 helper 함수 객체에만 건다. 라우트·업로드·콘텐츠 저장·처리 기록 module 위치에
묶지 않으므로 구조를 옮긴 뒤에도 이 파일을 그대로 실행한다.
기대값을 바꾸어 통과시키지 않는다.
"""

import asyncio
import hashlib
import json
import os
import sys
from contextlib import asynccontextmanager
from dataclasses import dataclass
from datetime import datetime
from types import SimpleNamespace
from uuid import uuid4

import httpx
import pytest
import pytest_asyncio
import uvicorn
from sqlalchemy import delete, event, func, select, text, update
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import settings
from app.db.session import get_db
from app.integrations.metadata_client import MetadataClient
from app.integrations.ocr_client import OCRClient
from app.integrations.storage_client import (
    LocalStorageClient,
    S3StorageClient,
    StorageUnavailableError,
)
from app.main import create_app
from app.models.category import Category
from app.models.content import Content
from app.models.content_asset import ContentAsset
from app.models.content_event import ContentEvent, ContentEventType
from app.models.image_deletion import ImageDeletion
from app.models.share_receipt import ShareReceipt
from app.models.summary_job import SummaryJob
from app.models.user import User
from app.repositories.event_repository import EventRepository
from app.services.image_deletion_service import cleanup_failed_upload
from app.services.image_storage_control import ImageUploadControl, set_uploads_paused
from tests.integration.helpers import guest, request

pytestmark = pytest.mark.asyncio

REAL_COMMIT = AsyncSession.commit
REAL_ROLLBACK = AsyncSession.rollback
REAL_EXECUTE = AsyncSession.execute
PARTIAL = b"partial-original"
BUCKET = "original-images"
TIME_LIMIT = 10  # 교착 탐지용 시험 제한(초). 운영 timeout이 아니다.
WEB = "https://example.com/a"
IG = "https://www.instagram.com/reel/XYZ789/"
GUEST_LIMIT = 31_457_280


# ---------------------------------------------------------------------------
# 공통 관측 도구
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def flow(external_responses, monkeypatch, tmp_path, s3_storage):
    """독립 PostgreSQL 연결로 실제 commit/rollback을 하는 API와 관측 도구."""
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    monkeypatch.setattr(settings, "storage_backend", "local")
    monkeypatch.setattr(settings, "storage_root", tmp_path)
    engine = create_async_engine(url)
    # 잠금 확인·연결 종료용. NullPool이라 확인 연결은 쓰고 나면 바로 닫힌다.
    checker = create_async_engine(url, poolclass=NullPool)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    from app.services.maintenance import MaintenanceGate
    app = create_app(maintenance=MaintenanceGate(sessions))
    state = SimpleNamespace(
        errors=[], request_sessions=[], user_ids=[], finalizers=[], root=tmp_path, s3=s3_storage,
        engine=engine, checker=checker, sessions=sessions,
    )

    async def db():
        async with sessions() as session:
            state.request_sessions.append(session)
            yield session

    async def recording_app(scope, receive, send):
        # ServerErrorMiddleware가 500을 보낸 뒤 다시 던지는 원래 예외를 기록한다.
        try:
            await app(scope, receive, send)
        except BaseException as exc:
            state.errors.append(exc)
            raise

    app.dependency_overrides[get_db] = db
    state.asgi = recording_app
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=recording_app, raise_app_exceptions=False),
            base_url="http://test",
        ) as client:
            headers, _, user = await guest(client)
            state.user_ids.append(user["id"])
            state.client, state.headers, state.user_id = client, headers, user["id"]
            yield state
    finally:
        for finalize in state.finalizers:
            finalize()
        # 테스트의 AsyncSession 대역이 남아 있어도 정리되도록 연결에서 직접 지운다.
        async with engine.begin() as connection:
            for model in (ImageDeletion, ContentEvent, Content, Category):
                await connection.execute(delete(model).where(model.user_id.in_(state.user_ids)))
            await connection.execute(delete(User).where(User.id.in_(state.user_ids)))
        await engine.dispose()
        await checker.dispose()


def submission_lock_id(user_id: int, key) -> int:
    digest = hashlib.sha256(f"share:{user_id}:{key}".encode()).digest()
    return int.from_bytes(digest[:8], "big", signed=True)


async def lock_free_elsewhere(state, lock: int) -> bool:
    """별도 연결의 비차단 시도로 제출 잠금이 비었는지 본다. 잡았으면 곧바로 놓는다."""
    async with state.checker.connect() as connection:
        acquired = await connection.scalar(
            text("SELECT pg_try_advisory_xact_lock(:key)"), {"key": lock},
        )
        await connection.rollback()
    return bool(acquired)


async def lock_waiting_backends(state) -> int:
    """이 DB에서 잠금을 기다리는 backend 수."""
    async with state.checker.connect() as connection:
        return await connection.scalar(text(
            "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() "
            "AND pid <> pg_backend_pid() AND wait_event_type = 'Lock'"
        ))


async def connection_leaks(state) -> dict[str, int]:
    """시험 뒤 남은 연결·트랜잭션·advisory 잠금을 센다."""
    async with state.checker.connect() as connection:
        busy = await connection.scalar(text(
            "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() "
            "AND pid <> pg_backend_pid() AND state <> 'idle'"
        ))
        advisory = await connection.scalar(text(
            "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND database = "
            "(SELECT oid FROM pg_database WHERE datname = current_database())"
        ))
    return {"pool_checked_out": state.engine.pool.checkedout(),
            "non_idle_backends": busy, "advisory_locks": advisory}


def patch_function_everywhere(monkeypatch, original, replacement) -> list[str]:
    """app 패키지에서 같은 함수 객체를 가리키는 모든 이름을 바꾼다(import 위치와 무관)."""
    patched = []
    for name, module in list(sys.modules.items()):
        if module is None or not (name == "app" or name.startswith("app.")):
            continue
        for attribute, value in list(vars(module).items()):
            if value is original:
                monkeypatch.setattr(module, attribute, replacement)
                patched.append(f"{name}.{attribute}")
    assert "app.services.image_deletion_service.cleanup_failed_upload" in patched
    return patched


def install_cleanup_probe(monkeypatch, calls: list, events: list | None = None) -> None:
    """실제 cleanup_failed_upload를 실행하면서 호출과 결과를 센다."""

    async def probe(session, storage, **kwargs):
        calls.append(["entered", kwargs["storage_key"]])
        if events is not None:
            events.append("cleanup_entered")
        try:
            await cleanup_failed_upload(session, storage, **kwargs)
        except BaseException as exc:
            calls[-1][0] = f"raised:{type(exc).__name__}"
            raise
        calls[-1][0] = "returned"

    patch_function_everywhere(monkeypatch, cleanup_failed_upload, probe)


def install_storage_probe(monkeypatch, saves: list, *, write_fault=None, delete_fault=False):
    """두 저장소 client의 save_file 진입/완료를 기록하고 쓰기·삭제 실패를 한 번 주입한다."""
    armed = SimpleNamespace(write=write_fault, delete=delete_fault)

    def partial_write(client, storage_key):
        if isinstance(client, LocalStorageClient):
            path = client.root / storage_key
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(PARTIAL)
        else:
            client.client.put_object(Bucket=client.bucket, Key=storage_key, Body=PARTIAL)

    for cls in (LocalStorageClient, S3StorageClient):
        real_save, real_delete = cls.save_file, cls.delete_file

        async def save_file(self, storage_key, content, _real=real_save):
            saves.append(["entered", storage_key])
            fault, armed.write = armed.write, None
            if fault is not None:
                kind, timing = fault.split("_")
                if timing == "partial":
                    partial_write(self, storage_key)
                saves[-1][0] = "raised"
                if kind == "oserror":
                    raise OSError("injected original write failure")
                raise StorageUnavailableError("injected original storage outage")
            await _real(self, storage_key, content)
            saves[-1][0] = "completed"

        async def delete_file(self, storage_key, _real=real_delete):
            if armed.delete:
                armed.delete = False
                raise StorageUnavailableError("injected original delete failure")
            await _real(self, storage_key)

        monkeypatch.setattr(cls, "save_file", save_file)
        monkeypatch.setattr(cls, "delete_file", delete_file)


def stored_objects(state) -> dict[str, bytes]:
    objects = {
        f"local:{path.relative_to(state.root)}": path.read_bytes()
        for path in state.root.rglob("*") if path.is_file() and "screenshots" in path.parts
    }
    for item in state.s3.list_objects_v2(Bucket=BUCKET).get("Contents", []):
        body = state.s3.get_object(Bucket=BUCKET, Key=item["Key"])["Body"].read()
        objects[f"s3:{item['Key']}"] = body
    return objects


def describe_object(objects: dict[str, bytes], backend: str, key: str | None, png: bytes) -> str:
    if key is None:
        return "not_written"
    body = objects.get(f"{backend}:{key}")
    if body is None:
        return "absent"
    return {png: "png", PARTIAL: "partial"}.get(body, "other")


async def user_rows(state) -> dict[str, int]:
    user_id = state.user_id
    async with state.engine.connect() as connection:
        async def count(statement):
            return await connection.scalar(select(func.count()).select_from(statement.subquery()))

        return {
            "contents": await count(select(Content.id).where(Content.user_id == user_id)),
            "assets": await count(select(ContentAsset.id).join(Content).where(
                Content.user_id == user_id)),
            "events": await count(select(ContentEvent.id).where(
                ContentEvent.user_id == user_id,
                ContentEvent.event_type == ContentEventType.CONTENT_CREATED)),
            "receipts": await count(select(ShareReceipt.key).where(
                ShareReceipt.user_id == user_id)),
            "summary_jobs": await count(select(SummaryJob.content_id).join(Content).where(
                Content.user_id == user_id)),
        }


async def deletion_rows(state) -> list[dict]:
    async with state.engine.connect() as connection:
        rows = (await connection.execute(
            select(ImageDeletion.content_id, ImageDeletion.completed, ImageDeletion.last_error,
                   ImageDeletion.attempts, ImageDeletion.intent)
            .where(ImageDeletion.user_id == state.user_id).order_by(ImageDeletion.deleted_at)
        )).all()
    return [
        {
            "content_id": row.content_id, "completed": row.completed,
            "last_error": row.last_error, "attempts": row.attempts,
            "keys": [asset["storage_key"] for asset in row.intent["assets"]],
        }
        for row in rows
    ]


def response_body(response: httpx.Response):
    try:
        return response.json()
    except ValueError:
        return response.text


def assert_frozen(expected: dict, case_id: str, observed) -> None:
    assert case_id in expected, "OBSERVED " + json.dumps(
        {case_id: observed}, ensure_ascii=False, sort_keys=True,
    )
    assert observed == expected[case_id], "OBSERVED " + json.dumps(
        {case_id: observed}, ensure_ascii=False, sort_keys=True,
    )


# ---------------------------------------------------------------------------
# R18a–R18d·R16: 원본 쓰기 실패 분기와 정리 helper
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Fault:
    id: str
    write: str | None = None  # save_file 실패: <oserror|unavailable>_<before|partial>
    after: str | None = None  # 원본 쓰기 성공 뒤 실패
    verify_fails: bool = False  # 커밋 실패 뒤 별도 연결 재확인도 실패(R16)
    cleanup: str | None = None  # 정리 실패: journal(정리 작업 기록 commit) / delete(원본 DELETE)


UPLOAD_FAULTS = [
    # R18b save_file 일반 OSError(쓰기 전 / 새 storage_key에 부분 바이트를 남긴 뒤)
    Fault("B1", write="oserror_before"),
    Fault("B2", write="oserror_partial"),
    # R18c save_file StorageUnavailableError
    Fault("C1", write="unavailable_before"),
    Fault("C2", write="unavailable_partial"),
    Fault("C3", write="unavailable_partial", cleanup="journal"),
    Fault("C4", write="unavailable_partial", cleanup="delete"),
    # R18d 원본 쓰기 성공 뒤 관측/저장 실패
    Fault("D1", after="observe"),
    Fault("D2", after="event"),
    Fault("D3", after="category"),
    Fault("D4", after="commit_rejected"),
    Fault("D5", after="commit_ack_lost"),
    Fault("D6", after="event", cleanup="journal"),
    Fault("D7", after="event", cleanup="delete"),
    # R16 커밋 실패 뒤 재확인 연결 실패
    Fault("V1", after="commit_rejected", verify_fails=True),
    Fault("V2", after="commit_ack_lost", verify_fails=True),
]

EXPECTED_UPLOAD_FAILURES: dict = {
    "B1-key": {
        "body": "Internal Server Error", "cleanup_helper": [], "cleanup_key_is_request_key": True,
        "errors": ["OSError"], "image_deletions": [], "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 0, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 500,
    },
    "B1-nokey": {
        "body": "Internal Server Error", "cleanup_helper": [], "cleanup_key_is_request_key": True,
        "errors": ["OSError"], "image_deletions": [], "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 0, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 500,
    },
    "B2-key": {
        "body": "Internal Server Error", "cleanup_helper": [], "cleanup_key_is_request_key": True,
        "errors": ["OSError"], "image_deletions": [], "objects": 1, "original": "partial",
        "retry": {
            "failed_attempt_original": "partial", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 500,
    },
    "B2-nokey": {
        "body": "Internal Server Error", "cleanup_helper": [], "cleanup_key_is_request_key": True,
        "errors": ["OSError"], "image_deletions": [], "objects": 1, "original": "partial",
        "retry": {
            "failed_attempt_original": "partial", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 500,
    },
    "C1-key": {
        "body": {"detail": "Image storage is temporarily unavailable"},
        "cleanup_helper": ["returned"], "cleanup_key_is_request_key": True, "errors": [],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 503,
    },
    "C1-nokey": {
        "body": {"detail": "Image storage is temporarily unavailable"},
        "cleanup_helper": ["returned"], "cleanup_key_is_request_key": True, "errors": [],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 503,
    },
    "C2-key": {
        "body": {"detail": "Image storage is temporarily unavailable"},
        "cleanup_helper": ["returned"], "cleanup_key_is_request_key": True, "errors": [],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 503,
    },
    "C2-nokey": {
        "body": {"detail": "Image storage is temporarily unavailable"},
        "cleanup_helper": ["returned"], "cleanup_key_is_request_key": True, "errors": [],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 503,
    },
    "C3-key": {
        "body": {"detail": "Image storage is temporarily unavailable"},
        "cleanup_helper": ["raised:ConnectionError"], "cleanup_key_is_request_key": True,
        "errors": [], "image_deletions": [], "objects": 1, "original": "partial",
        "retry": {
            "failed_attempt_original": "partial", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 503,
    },
    "C3-nokey": {
        "body": {"detail": "Image storage is temporarily unavailable"},
        "cleanup_helper": ["raised:ConnectionError"], "cleanup_key_is_request_key": True,
        "errors": [], "image_deletions": [], "objects": 1, "original": "partial",
        "retry": {
            "failed_attempt_original": "partial", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 503,
    },
    "C4-key": {
        "body": {"detail": "Image storage is temporarily unavailable"},
        "cleanup_helper": ["returned"], "cleanup_key_is_request_key": True, "errors": [],
        "image_deletions": [
            {
                "attempts": 1, "completed": False, "content_id": 0, "keys": ["<request>"],
                "last_error": "original_cleanup_unavailable",
            },
        ],
        "objects": 1, "original": "partial",
        "retry": {
            "failed_attempt_original": "partial", "image_deletions": 1, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 503,
    },
    "C4-nokey": {
        "body": {"detail": "Image storage is temporarily unavailable"},
        "cleanup_helper": ["returned"], "cleanup_key_is_request_key": True, "errors": [],
        "image_deletions": [
            {
                "attempts": 1, "completed": False, "content_id": 0, "keys": ["<request>"],
                "last_error": "original_cleanup_unavailable",
            },
        ],
        "objects": 1, "original": "partial",
        "retry": {
            "failed_attempt_original": "partial", "image_deletions": 1, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["raised"], "status": 503,
    },
    "D1-key": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["RuntimeError"],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D1-nokey": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["RuntimeError"],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D2-key": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["RuntimeError"],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D2-nokey": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["RuntimeError"],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D3-key": {
        "body": {"detail": "Category not found"}, "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": [],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 2, "objects": 0,
            "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
            "status": 404,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 404,
    },
    "D3-nokey": {
        "body": {"detail": "Category not found"}, "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": [],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 2, "objects": 0,
            "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
            "status": 404,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 404,
    },
    "D4-key": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["ConnectionError"],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D4-nokey": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["ConnectionError"],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D5-key": {
        "body": "Internal Server Error", "cleanup_helper": [], "cleanup_key_is_request_key": True,
        "errors": ["ConnectionError"], "image_deletions": [], "objects": 1, "original": "png",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 0, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D5-nokey": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["ConnectionError"], "image_deletions": [],
        "objects": 1, "original": "png",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 2, "contents": 2, "events": 2, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D6-key": {
        "body": "Internal Server Error", "cleanup_helper": ["raised:ConnectionError"],
        "cleanup_key_is_request_key": True, "errors": ["RuntimeError"], "image_deletions": [],
        "objects": 1, "original": "png",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D6-nokey": {
        "body": "Internal Server Error", "cleanup_helper": ["raised:ConnectionError"],
        "cleanup_key_is_request_key": True, "errors": ["RuntimeError"], "image_deletions": [],
        "objects": 1, "original": "png",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D7-key": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["RuntimeError"],
        "image_deletions": [
            {
                "attempts": 1, "completed": False, "content_id": 0, "keys": ["<request>"],
                "last_error": "original_cleanup_unavailable",
            },
        ],
        "objects": 1, "original": "png",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 1, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "D7-nokey": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["RuntimeError"],
        "image_deletions": [
            {
                "attempts": 1, "completed": False, "content_id": 0, "keys": ["<request>"],
                "last_error": "original_cleanup_unavailable",
            },
        ],
        "objects": 1, "original": "png",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 1, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "V1-key": {
        "body": "Internal Server Error", "cleanup_helper": [], "cleanup_key_is_request_key": True,
        "errors": ["ConnectionError"], "image_deletions": [], "objects": 1, "original": "png",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "V1-nokey": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["ConnectionError"],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "objects": 0, "original": "absent",
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "V2-key": {
        "body": "Internal Server Error", "cleanup_helper": [], "cleanup_key_is_request_key": True,
        "errors": ["ConnectionError"], "image_deletions": [], "objects": 1, "original": "png",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 0, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
    "V2-nokey": {
        "body": "Internal Server Error", "cleanup_helper": ["returned"],
        "cleanup_key_is_request_key": True, "errors": ["ConnectionError"], "image_deletions": [],
        "objects": 1, "original": "png",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 2, "contents": 2, "events": 2, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
        "save_file": ["completed"], "status": 500,
    },
}


@pytest.mark.parametrize("backend", ["local", "s3"])
@pytest.mark.parametrize("keyed", [True, False], ids=["key", "nokey"])
@pytest.mark.parametrize("fault", UPLOAD_FAULTS, ids=lambda fault: fault.id)
async def test_upload_failure_branches_keep_original_cleanup_contract(
    flow, png_bytes, monkeypatch, fault, keyed, backend,
):
    monkeypatch.setattr(settings, "storage_backend", backend)
    saves, cleanups = [], []
    install_storage_probe(
        monkeypatch, saves, write_fault=fault.write, delete_fault=fault.cleanup == "delete",
    )
    install_cleanup_probe(monkeypatch, cleanups)
    armed = SimpleNamespace(
        after=fault.after, journal=fault.cleanup == "journal", verify=fault.verify_fails,
        commit_failed=False,
    )
    real_observe, real_event = ImageUploadControl.observe, EventRepository.create

    async def observe(self, kind, size_bytes=0, *, commit=False):
        if armed.after == "observe" and kind.startswith("original_upload_"):
            armed.after = None
            raise RuntimeError("injected transfer observation failure")
        return await real_observe(self, kind, size_bytes, commit=commit)

    async def create_event(self, **kwargs):
        if armed.after == "event":
            armed.after = None
            raise RuntimeError("injected event write failure")
        return await real_event(self, **kwargs)

    async def commit(self):
        if armed.journal and any(isinstance(item, ImageDeletion) for item in self.new):
            armed.journal = False
            raise ConnectionError("injected cleanup journal commit failure")
        if armed.after in ("commit_rejected", "commit_ack_lost") and self in flow.request_sessions:
            mode, armed.after = armed.after, None
            armed.commit_failed = True
            if mode == "commit_ack_lost":
                await REAL_COMMIT(self)
            raise ConnectionError("injected commit failure")
        await REAL_COMMIT(self)

    async def execute(self, statement, params=None, **kwargs):
        if (armed.verify and armed.commit_failed and self not in flow.request_sessions
                and "pg_advisory_xact_lock(" in str(statement)):
            armed.verify = False
            raise ConnectionError("injected verification connection failure")
        return await REAL_EXECUTE(self, statement, params, **kwargs)

    monkeypatch.setattr(ImageUploadControl, "observe", observe)
    monkeypatch.setattr(EventRepository, "create", create_event)
    monkeypatch.setattr(AsyncSession, "commit", commit)
    monkeypatch.setattr(AsyncSession, "execute", execute)
    headers = {**flow.headers, **({"Idempotency-Key": str(uuid4())} if keyed else {})}
    form = {"data": {"category_ids": "99999999"}} if fault.after == "category" else {}
    upload = {"files": {"file": ("image.png", png_bytes, "image/png")}, **form}
    assert stored_objects(flow) == {}

    response = await asyncio.wait_for(
        flow.client.post("/api/v1/uploads/screenshots", headers=headers, **upload), TIME_LIMIT,
    )
    storage_key = saves[0][1] if saves else None
    objects = stored_objects(flow)

    def deletions_view(rows):
        return [{**row, "keys": ["<request>" if key == storage_key else key
                                 for key in row["keys"]]} for row in rows]

    observed = {
        "status": response.status_code,
        "body": response_body(response),
        "errors": [type(error).__name__ for error in flow.errors],
        "save_file": [event for event, _ in saves],
        "cleanup_helper": [event for event, _ in cleanups],
        "cleanup_key_is_request_key": all(key == storage_key for _, key in cleanups),
        "original": describe_object(objects, backend, storage_key, png_bytes),
        "objects": len(objects),
        "image_deletions": deletions_view(await deletion_rows(flow)),
        "rows": await user_rows(flow),
    }
    # 실패 주입이 모두 풀린 상태에서 같은 요청을 다시 보낸다. 키가 있으면 같은 키다.
    retry = await asyncio.wait_for(
        flow.client.post("/api/v1/uploads/screenshots", headers=headers, **upload), TIME_LIMIT,
    )
    retry_objects = stored_objects(flow)
    observed["retry"] = {
        "status": retry.status_code,
        "failed_attempt_original": describe_object(retry_objects, backend, storage_key, png_bytes),
        "objects": len(retry_objects),
        "image_deletions": len(await deletion_rows(flow)),
        "rows": await user_rows(flow),
    }
    assert_frozen(EXPECTED_UPLOAD_FAILURES, f"{fault.id}-{'key' if keyed else 'nokey'}", observed)


PRE_WRITE_REJECTIONS = ["invalid_image", "empty", "too_large", "paused", "quota"]
EXPECTED_PRE_WRITE: dict = {
    "empty-key": {
        "body": {"detail": "Screenshot file cannot be empty"}, "cleanup_helper": [], "errors": [],
        "image_deletions": [], "new_objects": 0, "ocr_calls": 0, "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 422,
    },
    "empty-nokey": {
        "body": {"detail": "Screenshot file cannot be empty"}, "cleanup_helper": [], "errors": [],
        "image_deletions": [], "new_objects": 0, "ocr_calls": 0, "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 422,
    },
    "invalid_image-key": {
        "body": {"detail": "Unsupported or invalid screenshot image"}, "cleanup_helper": [],
        "errors": [], "image_deletions": [], "new_objects": 0, "ocr_calls": 0, "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 415,
    },
    "invalid_image-nokey": {
        "body": {"detail": "Unsupported or invalid screenshot image"}, "cleanup_helper": [],
        "errors": [], "image_deletions": [], "new_objects": 0, "ocr_calls": 0, "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 415,
    },
    "paused-key": {
        "body": {
            "detail": {
                "code": "image_uploads_paused",
                "message": "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.",
            },
        },
        "cleanup_helper": [], "errors": [], "image_deletions": [], "new_objects": 0, "ocr_calls": 0,
        "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 409,
    },
    "paused-nokey": {
        "body": {
            "detail": {
                "code": "image_uploads_paused",
                "message": "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.",
            },
        },
        "cleanup_helper": [], "errors": [], "image_deletions": [], "new_objects": 0, "ocr_calls": 0,
        "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 409,
    },
    "quota-key": {
        "body": {
            "detail": {
                "code": "image_quota_exceeded", "limit_bytes": 31457280,
                "message": (
                    "이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요."
                ),
            },
        },
        "cleanup_helper": [], "errors": [], "image_deletions": [], "new_objects": 0, "ocr_calls": 0,
        "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 409,
    },
    "quota-nokey": {
        "body": {
            "detail": {
                "code": "image_quota_exceeded", "limit_bytes": 31457280,
                "message": (
                    "이미지 보관 한도에 도달했어요. 기존 이미지를 삭제한 뒤 다시 저장해 주세요."
                ),
            },
        },
        "cleanup_helper": [], "errors": [], "image_deletions": [], "new_objects": 0, "ocr_calls": 0,
        "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 409,
    },
    "too_large-key": {
        "body": {"detail": {"code": "image_file_too_large", "limit_bytes": 10485760}},
        "cleanup_helper": [], "errors": [], "image_deletions": [], "new_objects": 0, "ocr_calls": 0,
        "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 413,
    },
    "too_large-nokey": {
        "body": {"detail": {"code": "image_file_too_large", "limit_bytes": 10485760}},
        "cleanup_helper": [], "errors": [], "image_deletions": [], "new_objects": 0, "ocr_calls": 0,
        "retry_status": 201,
        "row_delta": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
        "save_file": [], "status": 413,
    },
}


@pytest.mark.parametrize("backend", ["local", "s3"])
@pytest.mark.parametrize("keyed", [True, False], ids=["key", "nokey"])
@pytest.mark.parametrize("rejection", PRE_WRITE_REJECTIONS)
async def test_pre_write_rejection_never_reaches_storage_or_cleanup(
    flow, png_bytes, monkeypatch, rejection, keyed, backend,
):
    """R18a: 원본 쓰기 전 거절은 save_file·정리 helper·정리 작업 없이 기존 응답을 낸다."""
    monkeypatch.setattr(settings, "storage_backend", backend)
    if rejection == "quota":
        existing = await request(flow.client, "POST", "uploads/screenshots", status=201,
                                 headers=flow.headers,
                                 files={"file": ("image.png", png_bytes, "image/png")})
        async with flow.engine.begin() as connection:
            await connection.execute(update(ContentAsset).where(
                ContentAsset.id == existing["assets"][0]["id"],
            ).values(size_bytes=GUEST_LIMIT - len(png_bytes) + 1))
    saves, cleanups, ocr_calls = [], [], []
    install_storage_probe(monkeypatch, saves)
    install_cleanup_probe(monkeypatch, cleanups)
    real_ocr = OCRClient.extract

    async def ocr(self, **kwargs):
        ocr_calls.append("ocr")
        return await real_ocr(self, **kwargs)

    monkeypatch.setattr(OCRClient, "extract", ocr)
    content = {
        "invalid_image": b"not-an-image",
        "empty": b"",
        "too_large": png_bytes + bytes(10 * 1024 * 1024 + 1 - len(png_bytes)),
    }.get(rejection, png_bytes)
    headers = {**flow.headers, **({"Idempotency-Key": str(uuid4())} if keyed else {})}
    before_rows, before_objects = await user_rows(flow), stored_objects(flow)
    if rejection == "paused":
        async with flow.sessions() as session:
            await set_uploads_paused(session, True)
    try:
        response = await flow.client.post(
            "/api/v1/uploads/screenshots", headers=headers,
            files={"file": ("image.png", content, "image/png")},
        )
    finally:
        if rejection == "paused":
            async with flow.sessions() as session:
                await set_uploads_paused(session, False)
    after_rows = await user_rows(flow)
    observed = {
        "status": response.status_code,
        "body": response_body(response),
        "errors": [type(error).__name__ for error in flow.errors],
        "save_file": [event for event, _ in saves],
        "cleanup_helper": [event for event, _ in cleanups],
        "ocr_calls": len(ocr_calls),
        "new_objects": len(stored_objects(flow)) - len(before_objects),
        "image_deletions": await deletion_rows(flow),
        "row_delta": {name: after_rows[name] - before_rows[name] for name in after_rows},
    }
    # 거절은 처리 기록을 남기지 않으므로 같은 키로 올바른 새 이미지를 저장할 수 있다.
    if rejection == "quota":
        async with flow.engine.begin() as connection:
            await connection.execute(update(ContentAsset).values(size_bytes=len(png_bytes))
                                     .where(ContentAsset.id == existing["assets"][0]["id"]))
    retry = await flow.client.post("/api/v1/uploads/screenshots", headers=headers,
                                   files={"file": ("image.png", png_bytes, "image/png")})
    observed["retry_status"] = retry.status_code
    assert_frozen(EXPECTED_PRE_WRITE, f"{rejection}-{'key' if keyed else 'nokey'}", observed)


# ---------------------------------------------------------------------------
# 원 트랜잭션 종료 → 별도 연결 재확인 → 정리 순서와 R24(rollback 실패·연결 종료·취소)
# ---------------------------------------------------------------------------


async def run_commit_failure(flow, png_bytes, monkeypatch, *, commit_mode, rollback_mode="normal",
                             keyed=True, expect_unfinished=False) -> dict:
    """스크린샷 저장의 첫 콘텐츠 commit에 실패를 넣고 사건 순서와 결과를 기록한다.

    commit_mode: rejected(commit 호출 없이 거절) / terminated(원 backend 종료 뒤 commit) /
    cancelled(서버 task 안에서 CancelledError).
    rollback_mode: normal / raise_after(실제 rollback 뒤 예외) /
    raise_before(실제 rollback 없이 예외).
    expect_unfinished면 시험 제한 시간까지 끝나지 않은 상태를 관측한 뒤
    요청 task 취소·원 세션 rollback·연결 반환을 하고 정리 결과를 함께 돌려준다.
    """
    key = uuid4()
    lock = submission_lock_id(flow.user_id, key)
    events, saves, cleanups = [], [], []
    install_storage_probe(monkeypatch, saves)
    install_cleanup_probe(monkeypatch, cleanups, events)
    state = SimpleNamespace(armed=True, session=None, rollback_armed=rollback_mode != "normal")

    async def where_lock() -> str:
        return "lock_free" if await lock_free_elsewhere(flow, lock) else "lock_held"

    async def commit(self):
        if state.armed and self in flow.request_sessions:
            state.armed, state.session = False, self
            events.append(f"commit_attempted:{await where_lock()}")
            if commit_mode == "rejected":
                raise ConnectionError("injected rejected commit")
            if commit_mode == "cancelled":
                raise asyncio.CancelledError()
            pid = await self.scalar(text("SELECT pg_backend_pid()"))
            async with flow.checker.connect() as connection:
                await connection.execute(text("SELECT pg_terminate_backend(:pid)"), {"pid": pid})
                await connection.commit()
        await REAL_COMMIT(self)

    async def rollback(self):
        if self is not state.session:
            return await REAL_ROLLBACK(self)
        armed, state.rollback_armed = state.rollback_armed, False
        if armed and rollback_mode == "raise_before":
            events.append("original_rollback_failed_without_server_rollback")
            raise RuntimeError("injected rollback failure before server rollback")
        try:
            await REAL_ROLLBACK(self)
        except BaseException as exc:
            events.append(f"original_rollback_raised:{type(exc).__name__}")
            raise
        events.append(f"original_rollback_done:{await where_lock()}")
        if armed:
            raise RuntimeError("injected rollback acknowledgement failure")

    async def execute(self, statement, params=None, **kwargs):
        if (state.session is not None and self not in flow.request_sessions
                and "pg_advisory_xact_lock(" in str(statement)
                and lock in (params or {}).values()):
            events.append("verification_lock_requested")
            result = await REAL_EXECUTE(self, statement, params, **kwargs)
            events.append("verification_lock_acquired")
            return result
        return await REAL_EXECUTE(self, statement, params, **kwargs)

    monkeypatch.setattr(AsyncSession, "commit", commit)
    monkeypatch.setattr(AsyncSession, "rollback", rollback)
    monkeypatch.setattr(AsyncSession, "execute", execute)
    headers = {**flow.headers, **({"Idempotency-Key": str(key)} if keyed else {})}
    upload = {"files": {"file": ("image.png", png_bytes, "image/png")}}
    loop = asyncio.get_running_loop()
    task = asyncio.create_task(
        flow.client.post("/api/v1/uploads/screenshots", headers=headers, **upload),
    )
    started = loop.time()
    try:
        done, _ = await asyncio.wait({task}, timeout=TIME_LIMIT)
        failed_elapsed = loop.time() - started
        if expect_unfinished:
            assert not done, f"request finished within {TIME_LIMIT}s: {events}"
            objects = stored_objects(flow)
            observed = {
                "events": list(events),
                "finished_within_time_limit": False,
                "lock_at_time_limit": await where_lock(),
                "lock_waiting_backends": await lock_waiting_backends(flow),
                "cleanup_helper": [event for event, _ in cleanups],
                "original": describe_object(objects, "local", saves[0][1], png_bytes),
                "objects": len(objects),
                "image_deletions": await deletion_rows(flow),
                "rows": await user_rows(flow),
            }
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)
            await asyncio.wait_for(REAL_ROLLBACK(state.session), TIME_LIMIT)
            await state.session.close()
            observed["after_cleanup"] = {
                "request_task_cancelled": task.cancelled(),
                "lock": await where_lock(),
                **await connection_leaks(flow),
            }
            return observed
        assert done, f"failed request did not finish within {TIME_LIMIT}s: {events}"
        if task.cancelled():
            outcome = "cancelled"
        elif task.exception() is not None:
            outcome = f"raised:{type(task.exception()).__name__}"
        else:
            outcome = task.result().status_code
        storage_key = saves[0][1]
        objects = stored_objects(flow)
        observed = {
            "events": list(events),
            "outcome": outcome,
            # 연결 종료 오류의 하위 class(InternalError 등)는 종료 시점에 따라 달라
            # 계열 이름으로 본다.
            "errors": ["DBAPIError" if isinstance(error, DBAPIError) else type(error).__name__
                       for error in flow.errors],
            "cleanup_helper": [event for event, _ in cleanups],
            "original": describe_object(objects, "local", storage_key, png_bytes),
            "objects": len(objects),
            "image_deletions": [{**row, "keys": ["<request>" for _ in row["keys"]]}
                                for row in await deletion_rows(flow)],
            "rows": await user_rows(flow),
            "lock_after_request": await where_lock(),
        }
        started = loop.time()
        retry = await asyncio.wait_for(
            flow.client.post("/api/v1/uploads/screenshots", headers=headers, **upload),
            TIME_LIMIT,
        )
        retry_elapsed = loop.time() - started
        retry_objects = stored_objects(flow)
        observed["retry"] = {
            "status": retry.status_code,
            "failed_attempt_original": describe_object(retry_objects, "local", storage_key,
                                                       png_bytes),
            "objects": len(retry_objects),
            "image_deletions": len(await deletion_rows(flow)),
            "rows": await user_rows(flow),
        }
        assert failed_elapsed < TIME_LIMIT and retry_elapsed < TIME_LIMIT
        return observed
    finally:
        # 시험이 실패해도 요청 task 취소·원 세션 rollback·연결 종료를 보장한다.
        if not task.done():
            task.cancel()
        await asyncio.gather(task, return_exceptions=True)
        if state.session is not None:
            try:
                await asyncio.wait_for(REAL_ROLLBACK(state.session), TIME_LIMIT)
            except Exception:
                pass
            await state.session.close()


EXPECTED_COMMIT_FAILURES: dict = {
    "connection_terminated_at_commit": {
        "cleanup_helper": ["returned"], "errors": ["DBAPIError"],
        "events": [
            "commit_attempted:lock_held", "original_rollback_done:lock_free",
            "verification_lock_requested", "verification_lock_acquired", "cleanup_entered",
            "original_rollback_done:lock_free",
        ],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "lock_after_request": "lock_free", "objects": 0, "original": "absent", "outcome": 500,
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
    },
    "connection_terminated_at_commit_nokey": {
        "cleanup_helper": ["returned"], "errors": ["DBAPIError"],
        "events": [
            "commit_attempted:lock_free", "original_rollback_done:lock_free", "cleanup_entered",
            "original_rollback_done:lock_free",
        ],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "lock_after_request": "lock_free", "objects": 0, "original": "absent", "outcome": 500,
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
    },
    "rejected": {
        "cleanup_helper": ["returned"], "errors": ["ConnectionError"],
        "events": [
            "commit_attempted:lock_held", "original_rollback_done:lock_free",
            "verification_lock_requested", "verification_lock_acquired", "cleanup_entered",
            "original_rollback_done:lock_free",
        ],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "lock_after_request": "lock_free", "objects": 0, "original": "absent", "outcome": 500,
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
    },
    "rollback_raises_after_release": {
        "cleanup_helper": ["returned"], "errors": ["RuntimeError"],
        "events": [
            "commit_attempted:lock_held", "original_rollback_done:lock_free",
            "verification_lock_requested", "verification_lock_acquired", "cleanup_entered",
            "original_rollback_done:lock_free",
        ],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "lock_after_request": "lock_free", "objects": 0, "original": "absent", "outcome": 500,
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
    },
    "rollback_raises_after_release_nokey": {
        "cleanup_helper": ["returned"], "errors": ["RuntimeError"],
        "events": [
            "commit_attempted:lock_free", "original_rollback_done:lock_free", "cleanup_entered",
            "original_rollback_done:lock_free",
        ],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "lock_after_request": "lock_free", "objects": 0, "original": "absent", "outcome": 500,
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
    },
    "rollback_raises_before_release": {
        "after_cleanup": {
            "advisory_locks": 0, "lock": "lock_free", "non_idle_backends": 0, "pool_checked_out": 0,
            "request_task_cancelled": True,
        },
        "cleanup_helper": [],
        "events": [
            "commit_attempted:lock_held", "original_rollback_failed_without_server_rollback",
            "verification_lock_requested",
        ],
        "finished_within_time_limit": False, "image_deletions": [],
        "lock_at_time_limit": "lock_held", "lock_waiting_backends": 1, "objects": 1,
        "original": "png",
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
    },
    "rollback_raises_before_release_nokey": {
        "cleanup_helper": ["returned"], "errors": ["RuntimeError"],
        "events": [
            "commit_attempted:lock_free", "original_rollback_failed_without_server_rollback",
            "cleanup_entered", "original_rollback_done:lock_free",
        ],
        "image_deletions": [
            {
                "attempts": 1, "completed": True, "content_id": 0, "keys": ["<request>"],
                "last_error": None,
            },
        ],
        "lock_after_request": "lock_free", "objects": 0, "original": "absent", "outcome": 500,
        "retry": {
            "failed_attempt_original": "absent", "image_deletions": 1, "objects": 1,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
    },
    "server_task_cancelled_at_commit": {
        "cleanup_helper": [], "errors": ["CancelledError"],
        "events": ["commit_attempted:lock_held"], "image_deletions": [],
        "lock_after_request": "lock_free", "objects": 1, "original": "png", "outcome": "cancelled",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
    },
    "server_task_cancelled_at_commit_nokey": {
        "cleanup_helper": [], "errors": ["CancelledError"],
        "events": ["commit_attempted:lock_free"], "image_deletions": [],
        "lock_after_request": "lock_free", "objects": 1, "original": "png", "outcome": "cancelled",
        "retry": {
            "failed_attempt_original": "png", "image_deletions": 0, "objects": 2,
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 0, "summary_jobs": 0},
            "status": 201,
        },
        "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
    },
}


async def test_rejected_commit_ends_original_transaction_before_verification(
    flow, png_bytes, monkeypatch,
):
    """정상 rollback 가능한 commit 거절: 원 연결이 제출 잠금을 쥔 채 거절되고,
    rollback 완료로 잠금을 푼 뒤에야 별도 연결이 같은 잠금으로 재확인하며,
    그 다음 실패 원본을 정리한다."""
    observed = await run_commit_failure(flow, png_bytes, monkeypatch, commit_mode="rejected")
    assert_frozen(EXPECTED_COMMIT_FAILURES, "rejected", observed)


@pytest.mark.parametrize(("case_id", "commit_mode", "rollback_mode", "keyed"), [
    ("rollback_raises_after_release", "rejected", "raise_after", True),
    ("rollback_raises_after_release_nokey", "rejected", "raise_after", False),
    ("connection_terminated_at_commit", "terminated", "normal", True),
    ("connection_terminated_at_commit_nokey", "terminated", "normal", False),
    ("server_task_cancelled_at_commit", "cancelled", "normal", True),
    ("server_task_cancelled_at_commit_nokey", "cancelled", "normal", False),
    ("rollback_raises_before_release_nokey", "rejected", "raise_before", False),
])
async def test_commit_failure_outside_normal_rollback_keeps_observed_branch(
    flow, png_bytes, monkeypatch, case_id, commit_mode, rollback_mode, keyed,
):
    """R24: rollback 자체 실패·연결 종료·서버 task 취소를 정상 rollback과 따로 관측해 동결한다.
    ASGITransport는 요청을 같은 task에서 돌리므로 클라이언트 대기 시간 초과는 여기서 보지 않고
    실제 서버 시험에서 따로 본다."""
    observed = await run_commit_failure(
        flow, png_bytes, monkeypatch, commit_mode=commit_mode, rollback_mode=rollback_mode,
        keyed=keyed,
    )
    assert_frozen(EXPECTED_COMMIT_FAILURES, case_id, observed)


async def test_rollback_failure_keeping_transaction_open_does_not_finish_within_time_limit(
    flow, png_bytes, monkeypatch,
):
    """R24(키 있음): rollback이 서버 트랜잭션을 끝내지 못한 채 예외를 내면,
    별도 연결 재확인이 원 연결의 제출 잠금을 기다려 요청이 시험 제한 시간 안에 끝나지 않는다
    (2026-11-10 사용자 결정으로 기존 관측 동결). 제한 시간 뒤의 결과는 관측하지 않는다.
    끝나면 요청 task 취소·원 세션 rollback·연결 반환으로 잠금·트랜잭션이 남지 않음을 확인한다."""
    observed = await run_commit_failure(
        flow, png_bytes, monkeypatch, commit_mode="rejected", rollback_mode="raise_before",
        expect_unfinished=True,
    )
    assert_frozen(EXPECTED_COMMIT_FAILURES, "rollback_raises_before_release", observed)


# ---------------------------------------------------------------------------
# 클라이언트 HTTP 대기 시간 초과: 실제 uvicorn 서버(127.0.0.1 임의 포트)에서 서버 task를 분리해 관측
# ---------------------------------------------------------------------------

REAL_ASYNC_HANDLE = httpx.AsyncHTTPTransport.handle_async_request
CLIENT_TIMEOUT = 0.5


class LoopbackTransport(httpx.AsyncHTTPTransport):
    """`external_responses`의 외부 HTTP 차단과 별도로 127.0.0.1 시험 서버에만 보낸다."""

    async def handle_async_request(self, request):
        assert request.url.host == "127.0.0.1", request.url
        return await REAL_ASYNC_HANDLE(self, request)


@asynccontextmanager
async def running_server(app):
    server = uvicorn.Server(uvicorn.Config(
        app, host="127.0.0.1", port=0, lifespan="off", log_config=None, log_level="warning",
        timeout_graceful_shutdown=1,
    ))
    task = asyncio.create_task(server.serve())
    try:
        async with asyncio.timeout(TIME_LIMIT):
            while not server.started:
                assert not task.done(), "test server stopped before start"
                await asyncio.sleep(0.01)
        yield server.servers[0].sockets[0].getsockname()[1]
    finally:
        server.should_exit = True
        await asyncio.wait_for(task, TIME_LIMIT)


async def port_closed(port: int) -> bool:
    try:
        _, writer = await asyncio.open_connection("127.0.0.1", port)
    except OSError:
        return True
    writer.close()
    await writer.wait_closed()
    return False


SERVER_TIMEOUT_CASES = [
    ("content", "after_server_finished"),
    ("content", "while_server_running"),
    ("screenshot", "after_server_finished"),
    ("screenshot", "while_server_running"),
]
EXPECTED_SERVER_TIMEOUT: dict = {
    "content-after_server_finished": {
        "after_cleanup": {
            "advisory_locks": 0, "non_idle_backends": 0, "pool_checked_out": 0, "port_closed": True,
        },
        "after_server_finished": {
            "rows": {"assets": 0, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "server_statuses": [201],
        },
        "at_client_timeout": {
            "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
            "server_finished": 0,
        },
        "errors": [], "external_calls": ["metadata"], "first_client": "ReadTimeout", "objects": 0,
        "retry": {"is_server_saved_content": True, "status": 201},
        "rows": {"assets": 0, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
        "server_entered_external_work": True, "server_statuses": [201],
    },
    "content-while_server_running": {
        "after_cleanup": {
            "advisory_locks": 0, "non_idle_backends": 0, "pool_checked_out": 0, "port_closed": True,
        },
        "at_client_timeout": {
            "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
            "server_finished": 0,
        },
        "errors": [], "external_calls": ["metadata"], "first_client": "ReadTimeout", "objects": 0,
        "retry": {"is_server_saved_content": True, "status": 201}, "retry_waits_for_first": True,
        "rows": {"assets": 0, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
        "server_entered_external_work": True, "server_statuses": [201, 201],
    },
    "screenshot-after_server_finished": {
        "after_cleanup": {
            "advisory_locks": 0, "non_idle_backends": 0, "pool_checked_out": 0, "port_closed": True,
        },
        "after_server_finished": {
            "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
            "server_statuses": [201],
        },
        "at_client_timeout": {
            "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
            "server_finished": 0,
        },
        "errors": [], "external_calls": ["ocr"], "first_client": "ReadTimeout", "objects": 1,
        "retry": {"is_server_saved_content": True, "status": 201},
        "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
        "server_entered_external_work": True, "server_statuses": [201],
    },
    "screenshot-while_server_running": {
        "after_cleanup": {
            "advisory_locks": 0, "non_idle_backends": 0, "pool_checked_out": 0, "port_closed": True,
        },
        "at_client_timeout": {
            "rows": {"assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0},
            "server_finished": 0,
        },
        "errors": [], "external_calls": ["ocr"], "first_client": "ReadTimeout", "objects": 1,
        "retry": {"is_server_saved_content": True, "status": 201}, "retry_waits_for_first": True,
        "rows": {"assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0},
        "server_entered_external_work": True, "server_statuses": [201, 201],
    },
}


@pytest.mark.parametrize(("path_kind", "retry_timing"), SERVER_TIMEOUT_CASES,
                         ids=[f"{kind}-{timing}" for kind, timing in SERVER_TIMEOUT_CASES])
async def test_client_timeout_against_real_server_keeps_save_and_replays_same_content(
    flow, png_bytes, monkeypatch, path_kind, retry_timing,
):
    """클라이언트가 응답 전에 HTTP 대기 시간 초과로 끊어도 서버 task는 따로 진행한다.
    서버 저장 완료 여부와 같은 키 재요청의 응답을 실제 서버에서 관측해 동결한다."""
    path, payload = SAVE_PATHS[path_kind]
    entered, release, external = asyncio.Event(), asyncio.Event(), []
    if path_kind == "screenshot":
        real_external = OCRClient.extract

        async def slow_external(self, **kwargs):
            external.append("ocr")
            entered.set()
            await asyncio.wait_for(release.wait(), TIME_LIMIT)
            return await real_external(self, **kwargs)

        monkeypatch.setattr(OCRClient, "extract", slow_external)
    else:
        real_external = MetadataClient.extract_from_url

        async def slow_external(self, url):
            external.append("metadata")
            entered.set()
            await asyncio.wait_for(release.wait(), TIME_LIMIT)
            return await real_external(self, url)

        monkeypatch.setattr(MetadataClient, "extract_from_url", slow_external)
    server_statuses = []

    async def served(scope, receive, send):
        status = []

        async def capture(message):
            if message["type"] == "http.response.start":
                status.append(message["status"])
            await send(message)

        try:
            await flow.asgi(scope, receive, capture)
        finally:
            if scope["type"] == "http":
                server_statuses.append(status[0] if status else None)

    async def wait_for_server(count: int) -> None:
        async with asyncio.timeout(TIME_LIMIT):
            while len(server_statuses) < count:
                await asyncio.sleep(0.01)

    headers = {**flow.headers, "Idempotency-Key": str(uuid4())}
    url = f"/api/v1/{path}"
    observed = {}
    retry_task = None
    try:
        async with running_server(served) as port, httpx.AsyncClient(
            transport=LoopbackTransport(), base_url=f"http://127.0.0.1:{port}",
            timeout=httpx.Timeout(TIME_LIMIT),
        ) as client:
            try:
                await client.post(url, headers=headers,
                                  timeout=httpx.Timeout(TIME_LIMIT, read=CLIENT_TIMEOUT),
                                  **payload(png_bytes))
            except httpx.TimeoutException as exc:
                observed["first_client"] = type(exc).__name__
            else:
                observed["first_client"] = "response"
            observed["server_entered_external_work"] = entered.is_set()
            observed["at_client_timeout"] = {
                "server_finished": len(server_statuses), "rows": await user_rows(flow),
            }
            if retry_timing == "while_server_running":
                retry_task = asyncio.create_task(client.post(url, headers=headers,
                                                             **payload(png_bytes)))
                await asyncio.sleep(CLIENT_TIMEOUT)
                observed["retry_waits_for_first"] = not retry_task.done()
                release.set()
                retry = await asyncio.wait_for(retry_task, TIME_LIMIT)
                await wait_for_server(2)
            else:
                release.set()
                await wait_for_server(1)
                observed["after_server_finished"] = {
                    "server_statuses": list(server_statuses), "rows": await user_rows(flow),
                }
                retry = await client.post(url, headers=headers, **payload(png_bytes))
            async with flow.engine.connect() as connection:
                saved_ids = (await connection.execute(
                    select(Content.id).where(Content.user_id == flow.user_id)
                )).scalars().all()
            observed["retry"] = {
                "status": retry.status_code,
                "is_server_saved_content": [retry.json()["id"]] == saved_ids,
            }
            observed["server_statuses"] = list(server_statuses)
            observed["external_calls"] = list(external)
            observed["errors"] = [type(error).__name__ for error in flow.errors]
            observed["rows"] = await user_rows(flow)
            observed["objects"] = len(stored_objects(flow))
    finally:
        release.set()
        if retry_task is not None:
            await asyncio.gather(retry_task, return_exceptions=True)
    observed["after_cleanup"] = {"port_closed": await port_closed(port),
                                 **await connection_leaks(flow)}
    assert_frozen(EXPECTED_SERVER_TIMEOUT, f"{path_kind}-{retry_timing}", observed)


# ---------------------------------------------------------------------------
# HTTP 계약 보강: R03 현재 콘텐츠·오류 본문·키 유무별 기록·fingerprint 변형·판정 순서·사전 오류
# ---------------------------------------------------------------------------


def placeholder_content(body: dict) -> dict:
    """가변값의 존재·타입·형식을 단언한 뒤 비교용 자리표시자로 바꾼다. 필드는 빼지 않는다."""
    body = dict(body)
    assert isinstance(body["id"], int)
    datetime.fromisoformat(body["saved_at"])
    body["id"], body["saved_at"] = "<id>", "<saved_at>"
    if body["last_viewed_at"] is not None:
        datetime.fromisoformat(body["last_viewed_at"])
        body["last_viewed_at"] = "<last_viewed_at>"
    for name in ("categories", "tags"):
        items = []
        for item in body[name]:
            assert isinstance(item["id"], int)
            items.append({**item, "id": "<id>"})
        body[name] = items
    assets = []
    for asset in body["assets"]:
        assert isinstance(asset["id"], int)
        assert asset["download_url"] == f"/api/v1/uploads/assets/{asset['id']}"
        assets.append({**asset, "id": "<id>", "download_url": "/api/v1/uploads/assets/<id>"})
    body["assets"] = assets
    return body


@pytest.fixture
def external_calls(monkeypatch, external_responses):
    calls = []
    metadata, ocr = MetadataClient.extract_from_url, OCRClient.extract

    async def counted_metadata(self, url):
        calls.append("metadata")
        return await metadata(self, url)

    async def counted_ocr(self, **kwargs):
        calls.append("ocr")
        return await ocr(self, **kwargs)

    monkeypatch.setattr(MetadataClient, "extract_from_url", counted_metadata)
    monkeypatch.setattr(OCRClient, "extract", counted_ocr)
    return calls


SAVE_PATHS = {
    "content": ("contents", lambda png: {"json": {"original_url": WEB}}),
    "link": ("contents/share", lambda png: {"json": {"url": IG}}),
    "screenshot": ("uploads/screenshots",
                   lambda png: {"files": {"file": ("image.png", png, "image/png")}}),
}


async def count_rows(db, user_id: int) -> dict[str, int]:
    async def count(statement):
        return await db.scalar(select(func.count()).select_from(statement.subquery()))

    return {
        "contents": await count(select(Content.id).where(Content.user_id == user_id)),
        "events": await count(select(ContentEvent.id).where(
            ContentEvent.user_id == user_id,
            ContentEvent.event_type == ContentEventType.CONTENT_CREATED)),
        "receipts": await count(select(ShareReceipt.key).where(ShareReceipt.user_id == user_id)),
    }


EXPECTED_CURRENT_REPLAY: dict = {
    "replay-content": {
        "conflict": [409, {"detail": "Idempotency key belongs to another input"}],
        "deleted": [410, {"detail": "Previously saved content was deleted"}],
        "first": {
            "assets": [],
            "categories": [{"color": "#4F46E5", "id": "<id>", "is_default": True, "name": "취업"}],
            "content_type": "link", "id": "<id>", "is_favorite": False, "last_viewed_at": None,
            "original_url": "https://example.com/a", "saved_at": "<saved_at>", "source": "web",
            "summary": "통합 설명", "summary_error_code": None, "summary_status": "not_requested",
            "tags": [], "title": "통합 제목",
        },
        "new_external_calls": [],
        "replay": {
            "assets": [],
            "categories": [{"color": None, "id": "<id>", "is_default": False, "name": "현재 분류"}],
            "content_type": "link", "id": "<id>", "is_favorite": True,
            "last_viewed_at": "<last_viewed_at>", "original_url": "https://example.com/a",
            "saved_at": "<saved_at>", "source": "web", "summary": "통합 설명",
            "summary_error_code": None, "summary_status": "not_requested",
            "tags": [{"id": "<id>", "name": "현재 태그"}], "title": "자동으로 바뀐 제목",
        },
        "replay_equals_current_read": True, "replay_id_is_first_id": True,
        "rows_after_replay_and_conflict": {"contents": 1, "events": 1, "receipts": 1},
        "rows_before_replay": {"contents": 1, "events": 1, "receipts": 1},
    },
    "replay-link": {
        "conflict": [409, {"detail": "Idempotency key belongs to another input"}],
        "deleted": [410, {"detail": "Previously saved content was deleted"}],
        "first": {
            "assets": [],
            "categories": [{"color": "#4F46E5", "id": "<id>", "is_default": True, "name": "취업"}],
            "content_type": "link", "id": "<id>", "is_favorite": False, "last_viewed_at": None,
            "original_url": "https://www.instagram.com/reel/XYZ789/", "saved_at": "<saved_at>",
            "source": "instagram", "summary": "통합 설명", "summary_error_code": "disabled",
            "summary_status": "skipped", "tags": [], "title": "통합 제목",
        },
        "new_external_calls": [],
        "replay": {
            "assets": [],
            "categories": [{"color": None, "id": "<id>", "is_default": False, "name": "현재 분류"}],
            "content_type": "link", "id": "<id>", "is_favorite": True,
            "last_viewed_at": "<last_viewed_at>",
            "original_url": "https://www.instagram.com/reel/XYZ789/", "saved_at": "<saved_at>",
            "source": "instagram", "summary": "통합 설명", "summary_error_code": "disabled",
            "summary_status": "skipped", "tags": [{"id": "<id>", "name": "현재 태그"}],
            "title": "자동으로 바뀐 제목",
        },
        "replay_equals_current_read": True, "replay_id_is_first_id": True,
        "rows_after_replay_and_conflict": {"contents": 1, "events": 1, "receipts": 1},
        "rows_before_replay": {"contents": 1, "events": 1, "receipts": 1},
    },
    "replay-screenshot": {
        "conflict": [409, {"detail": "Idempotency key belongs to another input"}],
        "deleted": [410, {"detail": "Previously saved content was deleted"}],
        "first": {
            "assets": [
                {
                    "asset_type": "screenshot", "download_url": "/api/v1/uploads/assets/<id>",
                    "id": "<id>", "mime_type": "image/png",
                },
            ],
            "categories": [{"color": "#4F46E5", "id": "<id>", "is_default": True, "name": "취업"}],
            "content_type": "screenshot", "id": "<id>", "is_favorite": False,
            "last_viewed_at": None, "original_url": None, "saved_at": "<saved_at>",
            "source": "screenshot", "summary": "화면 요약", "summary_error_code": None,
            "summary_status": "not_requested", "tags": [], "title": "화면 제목",
        },
        "new_external_calls": [],
        "replay": {
            "assets": [
                {
                    "asset_type": "screenshot", "download_url": "/api/v1/uploads/assets/<id>",
                    "id": "<id>", "mime_type": "image/png",
                },
            ],
            "categories": [{"color": None, "id": "<id>", "is_default": False, "name": "현재 분류"}],
            "content_type": "screenshot", "id": "<id>", "is_favorite": True,
            "last_viewed_at": "<last_viewed_at>", "original_url": None, "saved_at": "<saved_at>",
            "source": "screenshot", "summary": "화면 요약", "summary_error_code": None,
            "summary_status": "not_requested", "tags": [{"id": "<id>", "name": "현재 태그"}],
            "title": "자동으로 바뀐 제목",
        },
        "replay_equals_current_read": True, "replay_id_is_first_id": True,
        "rows_after_replay_and_conflict": {"contents": 1, "events": 1, "receipts": 1},
        "rows_before_replay": {"contents": 1, "events": 1, "receipts": 1},
    },
}


@pytest.mark.parametrize("path_kind", list(SAVE_PATHS))
async def test_replay_returns_current_content_and_keeps_conflict_and_deleted_bodies(
    api, database_connection, png_bytes, external_calls, path_kind,
):
    """R03·R04·R05: 같은 키 재시도는 저장 뒤 바뀐 현재 콘텐츠를 돌려주고 새 작업을 하지 않는다."""
    headers, _, user = await guest(api)
    path, payload = SAVE_PATHS[path_kind]
    writes = {**headers, "Idempotency-Key": str(uuid4())}
    first = await request(api, "POST", path, status=201, headers=writes, **payload(png_bytes))
    calls_after_first = list(external_calls)
    category = await request(api, "POST", "categories", status=201, headers=headers,
                             json={"name": "현재 분류"})
    await request(api, "PUT", f"contents/{first['id']}/favorite", headers=headers,
                  json={"is_favorite": True})
    await request(api, "PUT", f"contents/{first['id']}/tags", headers=headers,
                  json={"tag_names": ["현재 태그"]})
    await request(api, "PUT", f"contents/{first['id']}/categories", headers=headers,
                  json={"category_ids": [category["id"]]})
    await request(api, "POST", f"contents/{first['id']}/view", status=201, headers=headers,
                  json={"client_event_id": str(uuid4())})
    # 자동 요약 worker가 제목을 바꾼 상태를 DB에서 만든다.
    await database_connection.execute(
        update(Content).where(Content.id == first["id"]).values(title="자동으로 바뀐 제목"),
    )
    current = await request(api, "GET", f"contents/{first['id']}", headers=headers)
    rows = await count_rows(database_connection, user["id"])
    replay = await request(api, "POST", path, status=201, headers=writes, **payload(png_bytes))
    other_input = {
        "content": {"json": {"original_url": WEB + "?other"}},
        "link": {"json": {"url": IG, "raw_text": "다른 글"}},
        "screenshot": {"files": {"file": ("image.png", png_bytes + b"x", "image/png")}},
    }[path_kind]
    conflict = await api.post(f"/api/v1/{path}", headers=writes, **other_input)
    rows_after = await count_rows(database_connection, user["id"])
    await request(api, "DELETE", f"contents/{first['id']}", status=204, headers=headers)
    deleted = await api.post(f"/api/v1/{path}", headers=writes, **payload(png_bytes))
    observed = {
        "first": placeholder_content(first),
        "replay": placeholder_content(replay),
        "replay_equals_current_read": replay == current,
        "replay_id_is_first_id": replay["id"] == first["id"],
        "new_external_calls": external_calls[len(calls_after_first):],
        "rows_before_replay": rows,
        "rows_after_replay_and_conflict": rows_after,
        "conflict": [conflict.status_code, conflict.json()],
        "deleted": [deleted.status_code, deleted.json()],
    }
    assert_frozen(EXPECTED_CURRENT_REPLAY, f"replay-{path_kind}", observed)


EXPECTED_RECEIPT_COUNTS: dict = {
    "receipts-content": {
        "after_keyed": {"contents": 3, "events": 3, "receipts": 1},
        "after_keyless": {"contents": 2, "events": 2, "receipts": 0},
        "keyless_distinct_contents": True, "receipt_kinds": ["content"],
    },
    "receipts-link": {
        "after_keyed": {"contents": 3, "events": 3, "receipts": 1},
        "after_keyless": {"contents": 2, "events": 2, "receipts": 0},
        "keyless_distinct_contents": True, "receipt_kinds": ["link"],
    },
    "receipts-screenshot": {
        "after_keyed": {"contents": 3, "events": 3, "receipts": 1},
        "after_keyless": {"contents": 2, "events": 2, "receipts": 0},
        "keyless_distinct_contents": True, "receipt_kinds": ["screenshot"],
    },
}


@pytest.mark.parametrize("path_kind", list(SAVE_PATHS))
async def test_receipts_are_written_only_for_keyed_saves(
    api, database_connection, png_bytes, path_kind,
):
    headers, _, user = await guest(api)
    path, payload = SAVE_PATHS[path_kind]
    keyless = [await request(api, "POST", path, status=201, headers=headers,
                             **payload(png_bytes)) for _ in range(2)]
    after_keyless = await count_rows(database_connection, user["id"])
    await request(api, "POST", path, status=201,
                  headers={**headers, "Idempotency-Key": str(uuid4())}, **payload(png_bytes))
    kinds = (await database_connection.execute(
        select(ShareReceipt.kind).where(ShareReceipt.user_id == user["id"])
    )).scalars().all()
    observed = {
        "keyless_distinct_contents": keyless[0]["id"] != keyless[1]["id"],
        "after_keyless": after_keyless,
        "after_keyed": await count_rows(database_connection, user["id"]),
        "receipt_kinds": kinds,
    }
    assert_frozen(EXPECTED_RECEIPT_COUNTS, f"receipts-{path_kind}", observed)


C1, C2, C1_STR = "<c1>", "<c2>", "<c1-str>"


@dataclass(frozen=True)
class Variant:
    id: str
    path: str
    first: dict
    second: dict


def share_json(**fields):
    return {"json": fields}


def link_json(**fields):
    return {"json": {"original_url": WEB, **fields}}


PNG, PNG_LAST_BYTE = "<png>", "<png-last-byte-changed>"


def shot(*, name="image.png", mime="image/png", content=PNG, **data):
    return {"files": {"file": (name, content, mime)}, **({"data": data} if data else {})}


FINGERPRINT_VARIANTS = [
    # 일반 링크: 검증된 ContentCreate의 JSON mode 전체 dump
    Variant("FL01-explicit-defaults", "contents", link_json(), link_json(
        content_type="link", category_ids=[], tag_names=[], source="unknown", title=None,
        summary=None, is_favorite=False)),
    Variant("FL02-url-normalized-by-httpurl", "contents",
            {"json": {"original_url": "https://example.com"}},
            {"json": {"original_url": "HTTPS://EXAMPLE.COM/"}}),
    Variant("FL03-category-order", "contents", link_json(category_ids=[C1, C2]),
            link_json(category_ids=[C2, C1])),
    Variant("FL04-category-numeric-string", "contents", link_json(category_ids=[C1]),
            link_json(category_ids=[C1_STR])),
    Variant("FL05-category-duplicate", "contents", link_json(category_ids=[C1]),
            link_json(category_ids=[C1, C1])),
    Variant("FL06-tag-leading-hash", "contents", link_json(tag_names=["태그"]),
            link_json(tag_names=["#태그"])),
    Variant("FL07-tag-fullwidth-and-tab", "contents", link_json(tag_names=["A b"]),
            link_json(tag_names=["Ａ\tb"])),
    Variant("FL08-tag-nbsp-and-newline", "contents", link_json(tag_names=["a b c"]),
            link_json(tag_names=[" a b\nc "])),
    Variant("FL09-tag-fullwidth-hash", "contents", link_json(tag_names=["태그"]),
            link_json(tag_names=["＃태그"])),
    Variant("FL10-tag-casefold-duplicate", "contents", link_json(tag_names=["Tag"]),
            link_json(tag_names=["Tag", "tag"])),
    Variant("FL11-tag-display-case", "contents", link_json(tag_names=["Tag"]),
            link_json(tag_names=["tag"])),
    Variant("FL12-favorite-lax-bool", "contents", link_json(is_favorite=True),
            link_json(is_favorite="yes")),
    Variant("FL13-empty-title-vs-null", "contents", link_json(title=None), link_json(title="")),
    # 공유 링크: URL 해석 전 ContentShareCreate dump
    Variant("FS01-explicit-defaults", "contents/share", share_json(url=IG), share_json(
        url=IG, raw_text=None, mime_type=None, source_app=None, platform=None, attachments=[],
        category_ids=[], tag_names=[], is_favorite=False)),
    Variant("FS02-url-whitespace", "contents/share", share_json(url=IG),
            share_json(url=f"  {IG} ")),
    Variant("FS03-raw-text-differs", "contents/share", share_json(url=IG, raw_text="글 A"),
            share_json(url=IG, raw_text="글 B")),
    Variant("FS04-url-vs-raw-text-same-target", "contents/share", share_json(url=IG),
            share_json(raw_text=f"보세요 {IG}")),
    Variant("FS05-category-order", "contents/share", share_json(url=IG, category_ids=[C1, C2]),
            share_json(url=IG, category_ids=[C2, C1])),
    Variant("FS06-tag-leading-hash", "contents/share", share_json(url=IG, tag_names=["태그"]),
            share_json(url=IG, tag_names=["#태그"])),
    # 스크린샷: 카테고리·태그 JSON + NUL + 실제 파일 바이트
    Variant("FP01-filename-mime-claim", "uploads/screenshots", shot(),
            shot(name="other.jpg", mime="image/jpeg")),
    Variant("FP02-last-byte", "uploads/screenshots", shot(), shot(content=PNG_LAST_BYTE)),
    Variant("FP03-same-bytes-other-category", "uploads/screenshots", shot(),
            shot(category_ids=C1)),
    Variant("FP04-category-order", "uploads/screenshots", shot(category_ids=[C1, C2]),
            shot(category_ids=[C2, C1])),
    Variant("FP05-tag-leading-hash", "uploads/screenshots", shot(tag_names="태그"),
            shot(tag_names="#태그")),
    Variant("FP06-tag-casefold-duplicate", "uploads/screenshots", shot(tag_names="Tag"),
            shot(tag_names=["Tag", "tag"])),
]


def resolve_ids(value, ids: dict):
    if isinstance(value, dict):
        return {key: resolve_ids(item, ids) for key, item in value.items()}
    if isinstance(value, list):
        return [resolve_ids(item, ids) for item in value]
    if isinstance(value, tuple):
        return tuple(resolve_ids(item, ids) for item in value)
    return ids.get(value, value) if isinstance(value, str) else value


EXPECTED_FINGERPRINT: dict = {
    "FL01-explicit-defaults": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FL02-url-normalized-by-httpurl": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FL03-category-order": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FL04-category-numeric-string": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FL05-category-duplicate": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FL06-tag-leading-hash": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FL07-tag-fullwidth-and-tab": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FL08-tag-nbsp-and-newline": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FL09-tag-fullwidth-hash": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FL10-tag-casefold-duplicate": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FL11-tag-display-case": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FL12-favorite-lax-bool": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FL13-empty-title-vs-null": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FP01-filename-mime-claim": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FP02-last-byte": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FP03-same-bytes-other-category": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FP04-category-order": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FP05-tag-leading-hash": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FP06-tag-casefold-duplicate": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FS01-explicit-defaults": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
    "FS02-url-whitespace": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FS03-raw-text-differs": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FS04-url-vs-raw-text-same-target": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FS05-category-order": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": {"detail": "Idempotency key belongs to another input"}, "second_status": 409,
    },
    "FS06-tag-leading-hash": {
        "new_external_calls": [], "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": ["same_content"], "second_status": 201,
    },
}


@pytest.mark.parametrize("variant", FINGERPRINT_VARIANTS, ids=lambda variant: variant.id)
async def test_fingerprint_input_variants_keep_replay_or_conflict(
    api, database_connection, png_bytes, external_calls, variant,
):
    headers, _, user = await guest(api)
    c1 = await request(api, "POST", "categories", status=201, headers=headers,
                       json={"name": "첫 분류"})
    c2 = await request(api, "POST", "categories", status=201, headers=headers,
                       json={"name": "둘째 분류"})
    ids = {C1: c1["id"], C2: c2["id"], C1_STR: str(c1["id"]), PNG: png_bytes,
           PNG_LAST_BYTE: png_bytes[:-1] + bytes([png_bytes[-1] ^ 1])}
    writes = {**headers, "Idempotency-Key": str(uuid4())}
    first = await api.post(f"/api/v1/{variant.path}", headers=writes,
                           **resolve_ids(variant.first, ids))
    assert first.status_code == 201, first.text
    calls = len(external_calls)
    second = await api.post(f"/api/v1/{variant.path}", headers=writes,
                            **resolve_ids(variant.second, ids))
    observed = {
        "second_status": second.status_code,
        "second": (["same_content"] if second.status_code == 201
                   and second.json() == first.json() else second.json()),
        "new_external_calls": external_calls[calls:],
        "rows": await count_rows(database_connection, user["id"]),
    }
    assert_frozen(EXPECTED_FINGERPRINT, variant.id, observed)


EXPECTED_KIND_CONFLICT: dict = {
    "content->content": {
        "first_kind_replays": True, "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": [201, "same_content"],
    },
    "content->link": {
        "first_kind_replays": True, "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": [409, {"detail": "Idempotency key belongs to another input"}],
    },
    "content->screenshot": {
        "first_kind_replays": True, "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": [409, {"detail": "Idempotency key belongs to another input"}],
    },
    "link->content": {
        "first_kind_replays": True, "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": [409, {"detail": "Idempotency key belongs to another input"}],
    },
    "link->link": {
        "first_kind_replays": True, "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": [201, "same_content"],
    },
    "link->screenshot": {
        "first_kind_replays": True, "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": [409, {"detail": "Idempotency key belongs to another input"}],
    },
    "screenshot->content": {
        "first_kind_replays": True, "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": [409, {"detail": "Idempotency key belongs to another input"}],
    },
    "screenshot->link": {
        "first_kind_replays": True, "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": [409, {"detail": "Idempotency key belongs to another input"}],
    },
    "screenshot->screenshot": {
        "first_kind_replays": True, "rows": {"contents": 1, "events": 1, "receipts": 1},
        "second": [201, "same_content"],
    },
}


@pytest.mark.parametrize("second_kind", list(SAVE_PATHS))
@pytest.mark.parametrize("first_kind", list(SAVE_PATHS))
async def test_one_key_cannot_cross_save_kinds(
    api, database_connection, png_bytes, first_kind, second_kind,
):
    """서로 다른 저장 종류의 같은 키는 충돌이다(R04). 같은 종류·같은 입력은 재사용(R02)."""
    headers, _, user = await guest(api)
    writes = {**headers, "Idempotency-Key": str(uuid4())}
    first_path, first_payload = SAVE_PATHS[first_kind]
    second_path, second_payload = SAVE_PATHS[second_kind]
    first = await request(api, "POST", first_path, status=201, headers=writes,
                          **first_payload(png_bytes))
    second = await api.post(f"/api/v1/{second_path}", headers=writes,
                            **second_payload(png_bytes))
    again = await request(api, "POST", first_path, status=201, headers=writes,
                          **first_payload(png_bytes))
    observed = {
        "second": [second.status_code, "same_content" if second.status_code == 201
                   and second.json() == first else second.json()],
        "first_kind_replays": again == first,
        "rows": await count_rows(database_connection, user["id"]),
    }
    assert_frozen(EXPECTED_KIND_CONFLICT, f"{first_kind}->{second_kind}", observed)


ORDER_CASES = [
    # (id, 미리 저장한 키 상태, 요청 파일, 중단, 한도 초과, 저장 콘텐츠 삭제)
    ("O1-new-paused-and-quota", None, "png", True, True, False),
    ("O2-used-key-other-input-corrupt-image", "other", "corrupt", False, False, False),
    ("O3-used-key-empty-file", "other", "empty", False, False, False),
    ("O4-used-key-oversize-file", "other", "too_large", False, False, False),
    ("O5-completed-key-quota-exceeded", "same", "png", False, True, False),
    ("O6-completed-key-paused", "same", "png", True, False, False),
    ("O7-completed-key-paused-content-deleted", "same", "png", True, False, True),
    ("O8-new-corrupt-image-paused", None, "corrupt", True, False, False),
    ("O9-new-corrupt-image-quota", None, "corrupt", False, True, False),
    ("O10-used-key-other-input-paused-and-quota", "other", "png", True, True, False),
]
EXPECTED_ORDER: dict = {
    "O1-new-paused-and-quota": {
        "body": {
            "detail": {
                "code": "image_uploads_paused",
                "message": "이미지 저장이 일시 중단되었어요. 잠시 후 다시 시도해 주세요.",
            },
        },
        "new_external_calls": [], "new_files": 0,
        "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 409,
    },
    "O10-used-key-other-input-paused-and-quota": {
        "body": {"detail": "Idempotency key belongs to another input"}, "new_external_calls": [],
        "new_files": 0, "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 409,
    },
    "O2-used-key-other-input-corrupt-image": {
        "body": {"detail": "Idempotency key belongs to another input"}, "new_external_calls": [],
        "new_files": 0, "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 409,
    },
    "O3-used-key-empty-file": {
        "body": {"detail": "Screenshot file cannot be empty"}, "new_external_calls": [],
        "new_files": 0, "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 422,
    },
    "O4-used-key-oversize-file": {
        "body": {"detail": {"code": "image_file_too_large", "limit_bytes": 10485760}},
        "new_external_calls": [], "new_files": 0,
        "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 413,
    },
    "O5-completed-key-quota-exceeded": {
        "body": "same_content", "new_external_calls": [], "new_files": 0,
        "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 201,
    },
    "O6-completed-key-paused": {
        "body": "same_content", "new_external_calls": [], "new_files": 0,
        "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 201,
    },
    "O7-completed-key-paused-content-deleted": {
        "body": {"detail": "Previously saved content was deleted"}, "new_external_calls": [],
        "new_files": 0, "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 410,
    },
    "O8-new-corrupt-image-paused": {
        "body": {"detail": "Unsupported or invalid screenshot image"}, "new_external_calls": [],
        "new_files": 0, "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 415,
    },
    "O9-new-corrupt-image-quota": {
        "body": {"detail": "Unsupported or invalid screenshot image"}, "new_external_calls": [],
        "new_files": 0, "row_delta": {"contents": 0, "events": 0, "receipts": 0}, "status": 415,
    },
}


@pytest.mark.parametrize("case", ORDER_CASES, ids=[case[0] for case in ORDER_CASES])
async def test_screenshot_decision_order_for_overlapping_conditions(
    api, database_connection, png_bytes, external_calls, tmp_path, case,
):
    case_id, key_state, file_kind, paused, over_quota, delete_saved = case
    headers, _, user = await guest(api)
    writes = {**headers, "Idempotency-Key": str(uuid4())}
    other_png = png_bytes + b"other-input"
    saved = None
    if key_state is not None:
        saved = await request(api, "POST", "uploads/screenshots", status=201, headers=writes,
                              files={"file": ("image.png", png_bytes, "image/png")})
    else:
        saved = await request(api, "POST", "uploads/screenshots", status=201, headers=headers,
                              files={"file": ("image.png", png_bytes, "image/png")})
    if over_quota:
        await database_connection.execute(update(ContentAsset).where(
            ContentAsset.id == saved["assets"][0]["id"],
        ).values(size_bytes=GUEST_LIMIT - len(png_bytes) + 1))
    if delete_saved:
        await request(api, "DELETE", f"contents/{saved['id']}", status=204, headers=headers)
    if paused:
        async with AsyncSession(bind=database_connection,
                                join_transaction_mode="create_savepoint") as db:
            await set_uploads_paused(db, True)
    content = {
        "png": png_bytes if key_state != "other" else other_png,
        "corrupt": b"\x89PNG\r\n\x1a\n" + b"\0" * (len(png_bytes) - 8),
        "empty": b"",
        "too_large": png_bytes + bytes(10 * 1024 * 1024 + 1 - len(png_bytes)),
    }[file_kind]
    calls, rows = len(external_calls), await count_rows(database_connection, user["id"])
    files = len(list(tmp_path.rglob("*.png")))
    response = await api.post("/api/v1/uploads/screenshots",
                              headers=writes if key_state is not None else headers,
                              files={"file": ("image.png", content, "image/png")})
    after = await count_rows(database_connection, user["id"])
    observed = {
        "status": response.status_code,
        "body": ("same_content" if response.status_code == 201 and response.json() == saved
                 else response.json()),
        "new_external_calls": external_calls[calls:],
        "new_files": len(list(tmp_path.rglob("*.png"))) - files,
        "row_delta": {name: after[name] - rows[name] for name in after},
    }
    assert_frozen(EXPECTED_ORDER, case_id, observed)


def placeholder_error_urls(body: dict) -> dict:
    """pydantic 오류 문서 URL은 라이브러리 버전을 담으므로 형식을 확인한 뒤 자리표시자로 바꾼다."""
    if not isinstance(body.get("detail"), list):
        return body
    errors = []
    for error in body["detail"]:
        if "url" in error:
            prefix, _, rest = error["url"].removeprefix("https://errors.pydantic.dev/").partition("/")
            assert prefix and rest == f"v/{error['type']}", error["url"]
            error = {**error, "url": "https://errors.pydantic.dev/<version>/v/<type>"}
        errors.append(error)
    return {**body, "detail": errors}


PRE_ERROR_CASES = [
    # (id, 경로, 인증, 키, 본문)
    ("P01-no-auth-bad-key-bad-body", "contents", None, "bad", {"json": {"original_url": 123}}),
    ("P02-bad-key-bad-body", "contents", "main", "bad", {"json": {"original_url": 123}}),
    ("P03-share-token-on-main-link-bad-key", "contents", "share", "bad",
     {"json": {"original_url": WEB}}),
    ("P04-share-no-auth-bad-key", "contents/share", None, "bad", {"json": {"url": IG}}),
    ("P05-share-bad-key-bad-body", "contents/share", "share", "bad", {"json": {"url": 123}}),
    ("P06-screenshot-bad-key", "uploads/screenshots", "main", "bad", "png"),
    ("P07-screenshot-no-auth-bad-key-no-file", "uploads/screenshots", None, "bad", {}),
    ("P08-screenshot-bad-key-no-file", "uploads/screenshots", "main", "bad", {}),
    ("P09-screenshot-bad-key-empty-file", "uploads/screenshots", "share", "bad", "empty"),
    ("P10-screenshot-bad-key-blank-tag", "uploads/screenshots", "main", "bad", "blank_tag"),
    ("P11-screenshot-key-blank-tag", "uploads/screenshots", "main", "valid", "blank_tag"),
    ("P12-screenshot-key-bad-category", "uploads/screenshots", "main", "valid", "bad_category"),
    ("P13-link-key-blank-tag", "contents", "main", "valid",
     {"json": {"original_url": WEB, "tag_names": [""]}}),
    ("P14-link-key-null-tag", "contents", "main", "valid",
     {"json": {"original_url": WEB, "tag_names": [None]}}),
    ("P15-link-key-number-tag", "contents", "main", "valid",
     {"json": {"original_url": WEB, "tag_names": [1]}}),
    ("P16-share-key-null-category", "contents/share", "share", "valid",
     {"json": {"url": IG, "category_ids": [None]}}),
]
EXPECTED_PRE_ERRORS: dict = {
    "P01-no-auth-bad-key-bad-body": {
        "body": {"detail": "Invalid authentication credentials"},
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 401,
    },
    "P02-bad-key-bad-body": {
        "body": {
            "detail": [
                {
                    "ctx": {"error": "invalid character: found `n` at 0"}, "input": "not-a-uuid",
                    "loc": ["header", "idempotency-key"],
                    "msg": "Input should be a valid UUID, invalid character: found `n` at 0",
                    "type": "uuid_parsing",
                },
                {
                    "input": 123, "loc": ["body", "original_url"],
                    "msg": "URL input should be a string or URL", "type": "url_type",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 422,
    },
    "P03-share-token-on-main-link-bad-key": {
        "body": {"detail": "Invalid authentication credentials"},
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 401,
    },
    "P04-share-no-auth-bad-key": {
        "body": {"detail": "Invalid authentication credentials"},
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 401,
    },
    "P05-share-bad-key-bad-body": {
        "body": {
            "detail": [
                {
                    "ctx": {"error": "invalid character: found `n` at 0"}, "input": "not-a-uuid",
                    "loc": ["header", "idempotency-key"],
                    "msg": "Input should be a valid UUID, invalid character: found `n` at 0",
                    "type": "uuid_parsing",
                },
                {
                    "input": 123, "loc": ["body", "url"], "msg": "Input should be a valid string",
                    "type": "string_type",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 422,
    },
    "P06-screenshot-bad-key": {
        "body": {
            "detail": [
                {
                    "ctx": {"error": "invalid character: found `n` at 0"}, "input": "not-a-uuid",
                    "loc": ["header", "idempotency-key"],
                    "msg": "Input should be a valid UUID, invalid character: found `n` at 0",
                    "type": "uuid_parsing",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 422,
    },
    "P07-screenshot-no-auth-bad-key-no-file": {
        "body": {"detail": "Invalid authentication credentials"},
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 401,
    },
    "P08-screenshot-bad-key-no-file": {
        "body": {
            "detail": [
                {
                    "ctx": {"error": "invalid character: found `n` at 0"}, "input": "not-a-uuid",
                    "loc": ["header", "idempotency-key"],
                    "msg": "Input should be a valid UUID, invalid character: found `n` at 0",
                    "type": "uuid_parsing",
                },
                {
                    "input": None, "loc": ["body", "file"], "msg": "Field required",
                    "type": "missing",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 422,
    },
    "P09-screenshot-bad-key-empty-file": {
        "body": {
            "detail": [
                {
                    "ctx": {"error": "invalid character: found `n` at 0"}, "input": "not-a-uuid",
                    "loc": ["header", "idempotency-key"],
                    "msg": "Input should be a valid UUID, invalid character: found `n` at 0",
                    "type": "uuid_parsing",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 422,
    },
    "P10-screenshot-bad-key-blank-tag": {
        "body": {
            "detail": [
                {
                    "ctx": {"error": "invalid character: found `n` at 0"}, "input": "not-a-uuid",
                    "loc": ["header", "idempotency-key"],
                    "msg": "Input should be a valid UUID, invalid character: found `n` at 0",
                    "type": "uuid_parsing",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "status": 422,
    },
    "P11-screenshot-key-blank-tag": {
        "body": {
            "detail": [
                {
                    "ctx": {"error": {}}, "input": [" # "], "loc": ["tag_names"],
                    "msg": "Value error, Tag name cannot be blank", "type": "value_error",
                    "url": "https://errors.pydantic.dev/<version>/v/<type>",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "same_key_valid_retry": 201,
        "status": 422,
    },
    "P12-screenshot-key-bad-category": {
        "body": {
            "detail": [
                {
                    "input": "abc", "loc": ["body", "category_ids", 0],
                    "msg": "Input should be a valid integer, unable to parse string as an integer",
                    "type": "int_parsing",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "same_key_valid_retry": 201,
        "status": 422,
    },
    "P13-link-key-blank-tag": {
        "body": {
            "detail": [
                {
                    "ctx": {"error": {}}, "input": [""], "loc": ["body", "tag_names"],
                    "msg": "Value error, Tag name cannot be blank", "type": "value_error",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "same_key_valid_retry": 201,
        "status": 422,
    },
    "P14-link-key-null-tag": {
        "body": {
            "detail": [
                {
                    "input": None, "loc": ["body", "tag_names", 0],
                    "msg": "Input should be a valid string", "type": "string_type",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "same_key_valid_retry": 201,
        "status": 422,
    },
    "P15-link-key-number-tag": {
        "body": {
            "detail": [
                {
                    "input": 1, "loc": ["body", "tag_names", 0],
                    "msg": "Input should be a valid string", "type": "string_type",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "same_key_valid_retry": 201,
        "status": 422,
    },
    "P16-share-key-null-category": {
        "body": {
            "detail": [
                {
                    "input": None, "loc": ["body", "category_ids", 0],
                    "msg": "Input should be a valid integer", "type": "int_type",
                },
            ],
        },
        "rows": {"contents": 0, "events": 0, "receipts": 0}, "same_key_valid_retry": 201,
        "status": 422,
    },
}


@pytest.mark.parametrize("case", PRE_ERROR_CASES, ids=[case[0] for case in PRE_ERROR_CASES])
async def test_overlapping_pre_validation_errors_keep_http_result(
    api, database_connection, png_bytes, case,
):
    """R07·R22·R24 사전 오류: 미들웨어·인증·요청 검증의 기존 HTTP 결과와 키 미소비를 동결한다."""
    case_id, path, auth, key, body = case
    headers, _, user = await guest(api)
    credential = await request(api, "POST", "auth/share-credential", headers=headers)
    auth_headers = {
        None: {}, "main": headers,
        "share": {"Authorization": f"Bearer {credential['share_token']}"},
    }[auth]
    key_value = "not-a-uuid" if key == "bad" else str(uuid4())
    files = {
        "png": {"files": {"file": ("image.png", png_bytes, "image/png")}},
        "empty": {"files": {"file": ("image.png", b"", "image/png")}},
        "blank_tag": {"files": {"file": ("image.png", png_bytes, "image/png")},
                      "data": {"tag_names": " # "}},
        "bad_category": {"files": {"file": ("image.png", png_bytes, "image/png")},
                         "data": {"category_ids": "abc"}},
    }
    kwargs = files[body] if isinstance(body, str) else body
    response = await api.post(f"/api/v1/{path}",
                              headers={**auth_headers, "Idempotency-Key": key_value}, **kwargs)
    observed = {
        "status": response.status_code,
        "body": placeholder_error_urls(response.json()),
        "rows": await count_rows(database_connection, user["id"]),
    }
    if key == "valid":
        # 사전 오류는 키를 쓰지 않으므로 같은 키의 올바른 입력은 새로 저장된다.
        retry_payload = next(build for kind_path, build in SAVE_PATHS.values() if kind_path == path)
        retry = await api.post(f"/api/v1/{path}",
                               headers={**auth_headers, "Idempotency-Key": key_value},
                               **retry_payload(png_bytes))
        observed["same_key_valid_retry"] = retry.status_code
    assert_frozen(EXPECTED_PRE_ERRORS, case_id, observed)


EXPECTED_ATOMIC: dict = {
    "atomic-content": {
        "commit_rejected": True, "failed": 500, "objects_after_failure": 0,
        "objects_after_retry": 0, "retry": 201,
        "rows_after_failure": {
            "assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0,
        },
        "rows_after_retry": {
            "assets": 0, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0,
        },
    },
    "atomic-link": {
        "commit_rejected": True, "failed": 500, "objects_after_failure": 0,
        "objects_after_retry": 0, "retry": 201,
        "rows_after_failure": {
            "assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0,
        },
        "rows_after_retry": {
            "assets": 0, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 1,
        },
    },
    "atomic-screenshot": {
        "commit_rejected": True, "failed": 500, "objects_after_failure": 0,
        "objects_after_retry": 1, "retry": 201,
        "rows_after_failure": {
            "assets": 0, "contents": 0, "events": 0, "receipts": 0, "summary_jobs": 0,
        },
        "rows_after_retry": {
            "assets": 1, "contents": 1, "events": 1, "receipts": 1, "summary_jobs": 0,
        },
    },
}


@pytest.mark.parametrize("path_kind", list(SAVE_PATHS))
async def test_content_and_receipt_commit_together(flow, png_bytes, monkeypatch, path_kind):
    """처리 기록이 들어간 저장 트랜잭션의 commit이 거절되면
    콘텐츠·이벤트·요약 작업·기록이 모두 남지 않는다."""
    armed = SimpleNamespace(on=True, receipt_connections=set())

    def remember_receipt_insert(connection, cursor, statement, *args):
        if statement.lstrip().upper().startswith("INSERT INTO SHARE_RECEIPTS"):
            armed.receipt_connections.add(connection)

    async def commit(self):
        connection = (await self.connection()).sync_connection
        if armed.on and connection in armed.receipt_connections:
            armed.on = False
            raise ConnectionError("injected rejected commit with receipt")
        await REAL_COMMIT(self)

    monkeypatch.setattr(AsyncSession, "commit", commit)
    event.listen(flow.engine.sync_engine, "before_cursor_execute", remember_receipt_insert)
    flow.finalizers.append(lambda: event.remove(
        flow.engine.sync_engine, "before_cursor_execute", remember_receipt_insert))
    path, payload = SAVE_PATHS[path_kind]
    writes = {**flow.headers, "Idempotency-Key": str(uuid4())}
    failed = await asyncio.wait_for(
        flow.client.post(f"/api/v1/{path}", headers=writes, **payload(png_bytes)), TIME_LIMIT,
    )
    observed = {
        "failed": failed.status_code,
        "commit_rejected": not armed.on,
        "rows_after_failure": await user_rows(flow),
        "objects_after_failure": len(stored_objects(flow)),
    }
    retry = await asyncio.wait_for(
        flow.client.post(f"/api/v1/{path}", headers=writes, **payload(png_bytes)), TIME_LIMIT,
    )
    observed["retry"] = retry.status_code
    observed["rows_after_retry"] = await user_rows(flow)
    observed["objects_after_retry"] = len(stored_objects(flow))
    assert_frozen(EXPECTED_ATOMIC, f"atomic-{path_kind}", observed)
