"""Operator command `image_deletions delete-account` run as a real process (#255).

Each case starts the command in a new Python process against committed PostgreSQL rows,
the test ledger and a temporary storage root. Provider calls go to a fake HTTP transport.
"""

import asyncio
import json
import os
import sys
from pathlib import Path

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import delete, func, select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings
from app.db.session import get_db
from app.integrations.deletion_ledger import get_deletion_ledger
from app.main import create_app
from app.models.account_deletion_reason import AccountDeletionReason
from app.models.category import Category
from app.models.content import Content
from app.models.content_event import ContentEvent
from app.models.image_deletion import ImageDeletion
from app.models.maintenance import MaintenanceOperation, MaintenanceState
from app.models.user import User
from app.services.maintenance import MaintenanceGate
from tests.integration.helpers import guest, link, request
from tests.integration.test_account_deletion import database_rows
from tests.integration.test_image_deletion import upload

pytestmark = pytest.mark.asyncio
BACKEND = Path(__file__).resolve().parents[2]
FORMS = {
    "module": ["-m", "scripts.image_deletions"],
    "script": ["scripts/image_deletions.py"],
}
NOT_FOUND = "Account not found; nothing was deleted\n"
FAILED = "Account deletion failed; no successful completion is confirmed\n"
DB_PASSWORD = "synthetic-db-password"
ADMIN_KEY = "synthetic-kakao-admin-key"
KAKAO_MEMBER = "5151515151"
# Runs the script given second with every provider request answered 200 by a fake transport
# that records the request to the file given first.
FAKE_HTTP = (
    "import json, runpy, sys\n"
    "import httpx\n"
    "log = sys.argv.pop(1)\n"
    "async def answer(self, request):\n"
    "    with open(log, 'a') as file:\n"
    "        file.write(json.dumps({'url': str(request.url),\n"
    "                               'body': request.content.decode(),\n"
    "                               'auth': request.headers.get('Authorization')}) + '\\n')\n"
    "    return httpx.Response(200, json={})\n"
    "httpx.AsyncHTTPTransport.handle_async_request = answer\n"
    "sys.argv[0] = sys.argv.pop(1)\n"
    "runpy.run_path(sys.argv[0], run_name='__main__')\n"
)
# The gate's control rows are service state; a failed run keeps its admission as evidence.
SERVICE_TABLES = {"maintenance_state", "maintenance_operations", "maintenance_events"}


@pytest_asyncio.fixture
async def operator(external_responses, monkeypatch, tmp_path):
    """Committed rows for a separate process; every account made here is removed after."""
    database_url = os.environ.get("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("TEST_DATABASE_URL is required for PostgreSQL tests")
    engine = create_async_engine(database_url)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    app = create_app(maintenance=MaintenanceGate(sessions))
    monkeypatch.setattr(settings, "storage_root", tmp_path)

    async def db():
        async with sessions() as session:
            yield session

    app.dependency_overrides[get_db] = db
    users = []
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app, raise_app_exceptions=False),
            base_url="http://test",
        ) as client:
            yield client, engine, users
    finally:
        async with sessions() as session:
            await session.execute(text("DROP TRIGGER IF EXISTS t255_fail ON users"))
            await session.execute(text("DROP FUNCTION IF EXISTS t255_fail()"))
            for model in (ImageDeletion, ContentEvent, Content, Category):
                await session.execute(delete(model).where(model.user_id.in_(users)))
            await session.execute(delete(User).where(User.id.in_(users)))
            await session.execute(
                delete(MaintenanceOperation).where(MaintenanceOperation.kind == "account_deletion")
            )
            await session.commit()
        await engine.dispose()


async def account(operator, png_bytes, *, social=False):
    """An account with a link and an image, so every deletion step has work to do."""
    client, _, users = operator
    if social:
        tokens = await request(client, "POST", "auth/social/kakao", json={"token": KAKAO_MEMBER})
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        user = await request(client, "GET", "users/me", headers=headers)
    else:
        headers, _, user = await guest(client)
    users.append(user["id"])
    await link(client, headers)
    image = await upload(client, headers, png_bytes)
    return headers, user, image


async def command(*args, form="module", env=None, prefix=()):
    process = await asyncio.create_subprocess_exec(
        sys.executable,
        *prefix,
        *FORMS[form],
        "delete-account",
        *args,
        cwd=BACKEND,
        env={
            **os.environ,
            "DATABASE_URL": os.environ["TEST_DATABASE_URL"],
            "STORAGE_ROOT": str(settings.storage_root),
            "DELETION_LEDGER_ROOT": str(settings.deletion_ledger_root),
            "YOUTUBE_SUMMARY_ENABLED": "false",
            **(env or {}),
        },
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    output, error = await asyncio.wait_for(process.communicate(), timeout=60)
    return process.returncode, output.decode(), error.decode()


async def account_data(engine):
    async with engine.connect() as connection:
        rows = await database_rows(connection)
    return {name: value for name, value in rows.items() if name not in SERVICE_TABLES}


async def scalar(engine, statement):
    async with engine.connect() as connection:
        return await connection.scalar(statement)


async def user_exists(engine, user_id):
    return await scalar(engine, select(User.id).where(User.id == user_id)) is not None


def ledger_events():
    return get_deletion_ledger().read_verified_events()


def deleted(user_id):
    return ["--user-id", str(user_id), "--confirm-irreversible"]


@pytest.mark.parametrize("form", FORMS)
async def test_both_forms_delete_the_account_like_the_app_without_a_reason_record(
    operator, png_bytes, tmp_path, form,
):
    client, engine, _ = operator
    other_headers, other, other_image = await account(operator, png_bytes)
    headers, user, _ = await account(operator, png_bytes)
    reasons = await scalar(engine, select(func.count()).select_from(AccountDeletionReason))

    code, output, error = await command(*deleted(user["id"]), form=form)

    assert (code, output, error) == (
        0, '{"deleted": true, "pending_original_cleanup": 0}\n', ""
    )
    assert not await user_exists(engine, user["id"])
    await request(client, "GET", "users/me", headers=headers, status=401)
    [record] = ledger_events()
    assert record["kind"] == "account_deletion" and record["user_id"] == user["id"]
    # No reason record: the operator command deletes without reasons (D19).
    assert await scalar(
        engine, select(func.count()).select_from(AccountDeletionReason)
    ) == reasons
    # Only the other account's original is left.
    assert len(list(tmp_path.rglob("*.png"))) == 1
    assert (await request(client, "GET", "users/me", headers=other_headers))["id"] == other["id"]
    original = await client.get(other_image["assets"][0]["download_url"], headers=other_headers)
    assert original.status_code == 200 and original.content == png_bytes


async def test_original_left_behind_is_still_success_and_retry_finishes_it(
    operator, png_bytes, tmp_path,
):
    _, engine, _ = operator
    _, user, _ = await account(operator, png_bytes)
    [original] = tmp_path.rglob("*.png")
    original.parent.chmod(0o555)
    try:
        code, output, error = await command(*deleted(user["id"]))
    finally:
        original.parent.chmod(0o755)

    assert (code, output, error) == (
        0, '{"deleted": true, "pending_original_cleanup": 1}\n', ""
    )
    assert not await user_exists(engine, user["id"])
    assert original.exists()
    retry = await asyncio.create_subprocess_exec(
        sys.executable, "scripts/image_deletions.py", "retry",
        cwd=BACKEND,
        env={
            **os.environ,
            "DATABASE_URL": os.environ["TEST_DATABASE_URL"],
            "STORAGE_ROOT": str(tmp_path),
            "DELETION_LEDGER_ROOT": str(settings.deletion_ledger_root),
            "YOUTUBE_SUMMARY_ENABLED": "false",
        },
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    output, error = await asyncio.wait_for(retry.communicate(), timeout=60)
    assert retry.returncode == 0, error.decode()
    assert json.loads(output)["pending"] == 0
    assert not original.exists()


async def test_social_account_is_unlinked_through_the_command(operator, png_bytes, tmp_path):
    _, engine, _ = operator
    _, user, _ = await account(operator, png_bytes, social=True)
    log = tmp_path / "provider-requests.jsonl"

    code, output, error = await command(
        *deleted(user["id"]),
        form="script",
        env={"KAKAO_ADMIN_KEY": ADMIN_KEY},
        prefix=("-c", FAKE_HTTP, str(log)),
    )

    assert (code, error) == (0, ""), error
    assert json.loads(output) == {"deleted": True, "pending_original_cleanup": 0}
    [unlink] = [json.loads(line) for line in log.read_text().splitlines()]
    assert unlink["url"] == "https://kapi.kakao.com/v1/user/unlink"
    assert unlink["auth"] == f"KakaoAK {ADMIN_KEY}"
    assert unlink["body"] == f"target_id_type=user_id&target_id={KAKAO_MEMBER}"
    assert not await user_exists(engine, user["id"])


async def test_missing_or_already_deleted_account_is_1_and_changes_nothing(operator, png_bytes):
    _, engine, _ = operator
    _, user, _ = await account(operator, png_bytes)
    missing = await scalar(engine, select(func.max(User.id))) + 1000
    before = await account_data(engine)

    assert await command(*deleted(missing)) == (1, "", NOT_FOUND)
    assert await account_data(engine) == before
    assert ledger_events() == []

    assert (await command(*deleted(user["id"])))[0] == 0
    events = ledger_events()
    before = await account_data(engine)

    assert await command(*deleted(user["id"])) == (1, "", NOT_FOUND)
    assert await account_data(engine) == before
    assert ledger_events() == events


async def test_ledger_failure_is_1_and_keeps_the_account(operator, png_bytes, tmp_path):
    _, engine, _ = operator
    _, user, _ = await account(operator, png_bytes)
    before = await account_data(engine)
    missing_ledger = tmp_path / "missing-ledger"

    code, output, error = await command(
        *deleted(user["id"]), env={"DELETION_LEDGER_ROOT": str(missing_ledger)}
    )

    assert (code, output, error) == (1, "", FAILED)
    assert await account_data(engine) == before
    assert len(list(tmp_path.rglob("*.png"))) == 1


async def test_database_failure_after_the_record_is_1_and_a_rerun_reuses_the_record(
    operator, png_bytes, tmp_path,
):
    _, engine, _ = operator
    _, user, _ = await account(operator, png_bytes)
    async with engine.begin() as connection:
        await connection.execute(text(
            "CREATE FUNCTION t255_fail() RETURNS trigger LANGUAGE plpgsql AS "
            "$$BEGIN RAISE EXCEPTION 'injected database failure'; END$$"
        ))
        await connection.execute(text(
            "CREATE TRIGGER t255_fail BEFORE DELETE ON users "
            f"FOR EACH ROW WHEN (OLD.id = {user['id']}) EXECUTE FUNCTION t255_fail()"
        ))
    before = await account_data(engine)

    code, output, error = await command(*deleted(user["id"]))

    assert (code, output, error) == (1, "", FAILED)
    assert await account_data(engine) == before
    assert len(list(tmp_path.rglob("*.png"))) == 1
    # The record stays as a confirmed deletion request (U2).
    [record] = ledger_events()
    assert record["user_id"] == user["id"]

    async with engine.begin() as connection:
        await connection.execute(text("DROP TRIGGER t255_fail ON users"))
    code, output, error = await command(*deleted(user["id"]))

    assert (code, output, error) == (
        0, '{"deleted": true, "pending_original_cleanup": 0}\n', ""
    )
    assert ledger_events() == [record]
    assert not await user_exists(engine, user["id"])


async def test_other_failures_are_1_with_a_fixed_message_and_no_secrets(operator, png_bytes):
    _, engine, _ = operator
    _, user, _ = await account(operator, png_bytes)
    before = await account_data(engine)
    unreachable = f"postgresql+asyncpg://clipback:{DB_PASSWORD}@127.0.0.1:9/clipback_missing"

    code, output, error = await command(
        *deleted(user["id"]), env={"DATABASE_URL": unreachable}
    )

    assert (code, output, error) == (1, "", FAILED)
    assert DB_PASSWORD not in error and "127.0.0.1" not in error
    assert await account_data(engine) == before


async def test_full_api_configuration_is_required(operator, png_bytes):
    """Production without its required settings (provider keys, OpenAI…) never starts."""
    _, engine, _ = operator
    _, user, _ = await account(operator, png_bytes)
    before = await account_data(engine)

    code, output, error = await command(
        *deleted(user["id"]), env={"APP_ENVIRONMENT": "production"}
    )

    assert (code, output, error) == (1, "", FAILED)
    assert await account_data(engine) == before
    assert ledger_events() == []


async def test_maintenance_blocks_the_command(operator, png_bytes):
    _, engine, _ = operator
    _, user, _ = await account(operator, png_bytes)
    async with engine.begin() as connection:
        await connection.execute(
            MaintenanceState.__table__.update().values(phase="frozen")
        )
    before = await account_data(engine)
    try:
        code, output, error = await command(*deleted(user["id"]))
    finally:
        async with engine.begin() as connection:
            await connection.execute(MaintenanceState.__table__.update().values(phase="open"))

    assert (code, output, error) == (1, "", FAILED)
    assert await account_data(engine) == before
    assert ledger_events() == []


@pytest.mark.parametrize("args", [
    pytest.param([], id="nothing"),
    pytest.param(["--confirm-irreversible"], id="no-user-id"),
    pytest.param(["--user-id", "--confirm-irreversible"], id="empty-user-id"),
    pytest.param(["--user-id", "", "--confirm-irreversible"], id="blank"),
    pytest.param(["--user-id", "abc", "--confirm-irreversible"], id="letters"),
    pytest.param(["--user-id", "1.5", "--confirm-irreversible"], id="decimal"),
    pytest.param(["--user-id", "0", "--confirm-irreversible"], id="zero"),
    pytest.param(["--user-id", "-3", "--confirm-irreversible"], id="negative"),
    pytest.param(["--user-id", "USER"], id="no-confirmation"),
])
async def test_input_error_is_2_and_changes_nothing(operator, png_bytes, args):
    _, engine, _ = operator
    _, user, _ = await account(operator, png_bytes)
    args = [str(user["id"]) if arg == "USER" else arg for arg in args]
    before = await account_data(engine)

    code, output, error = await command(*args)

    assert code == 2 and output == "" and "usage:" in error
    assert await account_data(engine) == before
    assert ledger_events() == []
