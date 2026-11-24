"""AI 전송 동의: an account's stored decision, the server switch and the 재동의 rule decide
whether one piece of data may be sent to an external AI (#474). Every judgment point asks here.

Judgments read the current committed row each time (READ COMMITTED, column reads; no ORM
identity cache), so a decision committed before a judgment starts is always seen.
"""

from dataclasses import dataclass
from datetime import datetime
from typing import Literal

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import AuthenticationError

UNDECIDED = "undecided"
GRANTED = "granted"
DENIED = "denied"
NOTICE_VERSION = 1
AI_CONSENT_REQUIRED = "ai_consent_required"

ConsentStatus = Literal["undecided", "granted", "denied"]


@dataclass(frozen=True)
class ConsentRecord:
    status: Literal["granted", "denied"]
    notice_version: int
    decided_at: datetime
    granted_after_denial: bool


def effective_status(record: ConsentRecord | None) -> ConsentStatus:
    return UNDECIDED if record is None else record.status


def ai_allowed(record: ConsentRecord | None, *, required: bool, data_at: datetime) -> bool:
    """Whether data whose time is `data_at` may be AI-processed under this record and switch."""
    status = effective_status(record)
    if status == DENIED:
        return False
    if status == UNDECIDED:
        return not required
    # A grant after a denial covers only data that started after that grant.
    return not record.granted_after_denial or data_at >= record.decided_at


def save_allowed(
    record: ConsentRecord | None, *, started_under: ConsentRecord | None, required: bool,
) -> bool:
    """Whether a save request may send data now. `started_under` is the committed record its
    first check read. A re-grant covers the save only when the save started under that same
    committed decision; a re-grant committed during the save is another decision and does
    not. A first grant has no such condition."""
    status = effective_status(record)
    if status == DENIED:
        return False
    if status == UNDECIDED:
        return not required
    return not record.granted_after_denial or started_under == record


_READ = text("""
    SELECT clock_timestamp() AS now, c.status, c.notice_version, c.decided_at,
           c.granted_after_denial
    FROM (VALUES (1)) AS one
    LEFT JOIN ai_transfer_consents AS c ON c.user_id = :user_id
""")


def _record(row) -> ConsentRecord | None:
    if row.status is None:
        return None
    return ConsentRecord(
        status=row.status, notice_version=row.notice_version, decided_at=row.decided_at,
        granted_after_denial=row.granted_after_denial,
    )


async def read_consent(
    session: AsyncSession, user_id: int,
) -> tuple[datetime, ConsentRecord | None]:
    """The DB clock and the account's stored record. A read failure propagates."""
    row = (await session.execute(_READ, {"user_id": user_id})).one()
    return row.now, _record(row)


class SaveAIConsent:
    """The AI consent checks of one save request (G1a·G1b·G2a·G2b·G3).

    The request starts under the committed decision its first check reads. A decision is
    identified by the whole record: a change always writes a new time.
    """

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.started = False
        self.started_under: ConsentRecord | None = None

    async def allows(self, user_id: int) -> bool:
        _, record = await read_consent(self.session, user_id)
        if not self.started:
            self.started, self.started_under = True, record
        return save_allowed(
            record, started_under=self.started_under, required=settings.ai_consent_required,
        )


_LOCK_USER = text("SELECT id FROM users WHERE id = :user_id FOR KEY SHARE")
_UPSERT = text("""
    INSERT INTO ai_transfer_consents AS c
        (user_id, status, notice_version, decided_at, granted_after_denial)
    VALUES (:user_id, :status, :notice_version, clock_timestamp(), false)
    ON CONFLICT (user_id) DO UPDATE SET
        status = excluded.status,
        notice_version = excluded.notice_version,
        -- Taken after this row's lock: a decision that waited is not dated before the wait.
        decided_at = clock_timestamp(),
        granted_after_denial = (c.status = 'denied' AND excluded.status = 'granted')
    WHERE c.status IS DISTINCT FROM excluded.status
""")
_SELECT = text("""
    SELECT status, notice_version, decided_at, granted_after_denial
    FROM ai_transfer_consents WHERE user_id = :user_id
""")


async def decide(
    session: AsyncSession, user_id: int, *, status: Literal["granted", "denied"],
) -> ConsentRecord:
    """Store and commit the account's decision. The same status again keeps the row and time."""
    try:
        # KEY SHARE waits for an account deletion holding FOR UPDATE and stays compatible
        # with the photo save's NO KEY UPDATE.
        if await session.scalar(_LOCK_USER, {"user_id": user_id}) is None:
            raise AuthenticationError()
        await session.execute(
            _UPSERT, {"user_id": user_id, "status": status, "notice_version": NOTICE_VERSION},
        )
        record = _record((await session.execute(_SELECT, {"user_id": user_id})).one())
        await session.commit()
    except Exception:
        await session.rollback()
        raise
    return record
