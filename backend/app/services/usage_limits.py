"""게스트 발급 상한과 계정별 AI 요약 월 한도."""

import json
import logging
import time
from collections import Counter, deque
from datetime import UTC, datetime, timedelta
from ipaddress import IPv6Address, ip_address

from fastapi import HTTPException, Request

from app.core.recommendation_config import RECOMMENDATION_TIMEZONE
from app.repositories.usage_record_repository import AI_SUMMARY, UsageRecordRepository

GUEST_IP_HOURLY_LIMIT = 20
GUEST_GLOBAL_HOURLY_LIMIT = 300
GUEST_SUMMARY_MONTHLY_LIMIT = 20
MEMBER_SUMMARY_MONTHLY_LIMIT = 30
GUEST_LIMIT_MESSAGE = "지금은 게스트로 시작할 수 없어요. 잠시 후 다시 시도해 주세요."
logger = logging.getLogger(__name__)


def now() -> datetime:
    return datetime.now(UTC)


def monotonic() -> float:
    return time.monotonic()


def client_ip(request: Request) -> str:
    try:
        address = ip_address(request.headers.get("x-real-ip", ""))
        if isinstance(address, IPv6Address):
            address = address.ipv4_mapped or IPv6Address(int(address))
        return str(address)
    except ValueError:
        return request.client.host if request.client else "unknown"


class GuestIssuanceLimit:
    def __init__(self):
        self._issued: deque[tuple[float, str]] = deque()
        self._pending: Counter[str] = Counter()

    def reserve(self, ip: str) -> None:
        cutoff = monotonic() - 3600
        while self._issued and self._issued[0][0] <= cutoff:
            self._issued.popleft()
        scope = None
        if len(self._issued) + self._pending.total() >= GUEST_GLOBAL_HOURLY_LIMIT:
            scope = "global"
        elif sum(key == ip for _, key in self._issued) + self._pending[ip] >= GUEST_IP_HOURLY_LIMIT:
            scope = "ip"
        if scope:
            logger.info(json.dumps({"event": "guest_issuance_rejected", "scope": scope}))
            raise HTTPException(429, GUEST_LIMIT_MESSAGE)
        self._pending[ip] += 1

    def finish(self, ip: str, *, succeeded: bool) -> None:
        self._pending[ip] -= 1
        if not self._pending[ip]:
            del self._pending[ip]
        if succeeded:
            self._issued.append((monotonic(), ip))


def month_start(at: datetime) -> datetime:
    return at.astimezone(RECOMMENDATION_TIMEZONE).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0,
    )


class MonthlySummaryLimit:
    def __init__(self, records: UsageRecordRepository) -> None:
        self.records = records

    async def admit(self, user_id: int, *, is_guest: bool, kind: str) -> datetime | None:
        decided_at = now()
        start = month_start(decided_at)
        end = month_start(start + timedelta(days=31))
        limit = GUEST_SUMMARY_MONTHLY_LIMIT if is_guest else MEMBER_SUMMARY_MONTHLY_LIMIT
        if await self.records.count(user_id, kind=AI_SUMMARY, start=start, end=end) >= limit:
            logger.info(json.dumps({
                "event": "summary_monthly_limit_exceeded", "user_id": user_id, "kind": kind,
            }))
            return None
        return decided_at

    async def record(self, user_id: int, *, content_id: int, decided_at: datetime) -> None:
        await self.records.add(
            user_id=user_id, kind=AI_SUMMARY, recorded_at=decided_at, content_id=content_id,
            retain_from=month_start(month_start(decided_at) - timedelta(days=1)),
        )
