"""API 프로세스 수명 동안의 게스트 발급·저장 시 자동 요약 상한."""

import json
import logging
import time
from collections import Counter, deque
from datetime import UTC, datetime
from ipaddress import IPv6Address, ip_address

from fastapi import HTTPException, Request

from app.core.recommendation_config import RECOMMENDATION_TIMEZONE

GUEST_IP_HOURLY_LIMIT = 20
GUEST_GLOBAL_HOURLY_LIMIT = 300
GUEST_SUMMARY_DAILY_LIMIT = 20
MEMBER_SUMMARY_DAILY_LIMIT = 100
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


class DailySummaryLimit:
    def __init__(self):
        self._day = None
        self._counts: Counter[int] = Counter()

    def admit(self, user_id: int, *, is_guest: bool) -> bool:
        day = now().astimezone(RECOMMENDATION_TIMEZONE).date()
        if day != self._day:
            self._counts.clear()
            self._day = day
        limit = GUEST_SUMMARY_DAILY_LIMIT if is_guest else MEMBER_SUMMARY_DAILY_LIMIT
        if self._counts[user_id] >= limit:
            logger.info(json.dumps({"event": "summary_daily_limit_exceeded", "user_id": user_id}))
            return False
        self._counts[user_id] += 1
        return True
