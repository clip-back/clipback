import pytest

from app.api.v1.endpoints import auth
from tests.api.test_auth import FakeAuthService


@pytest.fixture
def guest_service(monkeypatch):
    service = FakeAuthService()
    monkeypatch.setattr(auth, "_build_auth_service", lambda db: service)
    return service


def test_guest_limit_boundary_and_message(client, guest_service):
    for _ in range(19):
        assert client.post("/api/v1/auth/guest").status_code == 201
    assert client.post("/api/v1/auth/guest").status_code == 201
    response = client.post("/api/v1/auth/guest")
    assert response.status_code == 429
    assert response.json() == {
        "detail": "지금은 게스트로 시작할 수 없어요. 잠시 후 다시 시도해 주세요."
    }


def test_guest_other_ip_and_global_limit(client, guest_service):
    for index in range(300):
        response = client.post(
            "/api/v1/auth/guest", headers={"X-Real-IP": f"10.0.{index // 256}.{index % 256}"}
        )
        assert response.status_code == 201
    assert client.post("/api/v1/auth/guest", headers={"X-Real-IP": "192.0.2.1"}).status_code == 429


def test_guest_window_and_rejections_do_not_count(client, guest_service, monkeypatch):
    from app.services import usage_limits

    clock = [0.0]
    monkeypatch.setattr(usage_limits, "monotonic", lambda: clock[0])
    for _ in range(20):
        assert client.post("/api/v1/auth/guest").status_code == 201
    clock[0] = 3599.999
    assert client.post("/api/v1/auth/guest").status_code == 429
    clock[0] = 3600
    for _ in range(20):
        assert client.post("/api/v1/auth/guest").status_code == 201
    assert client.post("/api/v1/auth/guest").status_code == 429


@pytest.mark.parametrize("value", [None, "", "invalid", "192.0.2.1, 192.0.2.2"])
def test_guest_invalid_header_uses_client_address(client, guest_service, value):
    for _ in range(20):
        assert client.post("/api/v1/auth/guest").status_code == 201
    headers = {"X-Forwarded-For": "192.0.2.5"}
    if value is not None:
        headers["X-Real-IP"] = value
    assert client.post("/api/v1/auth/guest", headers=headers).status_code == 429
    assert client.post("/api/v1/auth/guest", headers={"X-Real-IP": "192.0.2.6"}).status_code == 201


def test_guest_ipv6_is_normalized(client, guest_service):
    for _ in range(20):
        assert (
            client.post("/api/v1/auth/guest", headers={"X-Real-IP": "2001:db8::1"}).status_code
            == 201
        )
    assert (
        client.post(
            "/api/v1/auth/guest", headers={"X-Real-IP": "2001:0db8:0:0:0:0:0:1"}
        ).status_code
        == 429
    )
    assert (
        client.post("/api/v1/auth/guest", headers={"X-Real-IP": "2001:db8::2"}).status_code == 201
    )


def test_guest_failed_creation_does_not_count(client, guest_service, monkeypatch):
    from fastapi import HTTPException

    original = guest_service.create_guest_session

    async def fail():
        raise HTTPException(500, "injected")

    monkeypatch.setattr(guest_service, "create_guest_session", fail)
    assert client.post("/api/v1/auth/guest").status_code == 500
    monkeypatch.setattr(guest_service, "create_guest_session", original)
    for _ in range(20):
        assert client.post("/api/v1/auth/guest").status_code == 201
    assert client.post("/api/v1/auth/guest").status_code == 429


@pytest.mark.asyncio
async def test_guest_inflight_reservation_blocks_concurrent_request(monkeypatch):
    import asyncio

    import httpx

    from app.main import create_app
    from tests.support.maintenance import OpenUnitGate

    entered = asyncio.Event()
    release = asyncio.Event()
    service = FakeAuthService()
    original = service.create_guest_session

    async def slow():
        entered.set()
        await release.wait()
        return await original()

    monkeypatch.setattr(auth, "_build_auth_service", lambda db: service)
    app = create_app(maintenance=OpenUnitGate())
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as api:
        for _ in range(19):
            assert (await api.post("/api/v1/auth/guest")).status_code == 201
        monkeypatch.setattr(service, "create_guest_session", slow)
        pending = asyncio.create_task(api.post("/api/v1/auth/guest"))
        await entered.wait()
        try:
            assert (await api.post("/api/v1/auth/guest")).status_code == 429
        finally:
            release.set()
            assert (await pending).status_code == 201


@pytest.mark.asyncio
async def test_guest_missing_client_and_app_state_isolation(monkeypatch):
    import httpx

    from app.main import create_app
    from tests.support.maintenance import OpenUnitGate

    service = FakeAuthService()
    monkeypatch.setattr(auth, "_build_auth_service", lambda db: service)
    first = create_app(maintenance=OpenUnitGate())
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=first, client=None), base_url="http://test"
    ) as api:
        for _ in range(20):
            assert (await api.post("/api/v1/auth/guest")).status_code == 201
        assert (await api.post("/api/v1/auth/guest")).status_code == 429
    second = create_app(maintenance=OpenUnitGate())
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=second, client=None), base_url="http://test"
    ) as api:
        assert (await api.post("/api/v1/auth/guest")).status_code == 201


@pytest.mark.parametrize(
    "first,second",
    [("2001:db8::1%eth0", "2001:db8::1%eth1"), ("192.0.2.1", "::ffff:192.0.2.1")],
)
def test_guest_equivalent_ip_forms_share_limit(client, guest_service, first, second):
    for _ in range(20):
        assert client.post("/api/v1/auth/guest", headers={"X-Real-IP": first}).status_code == 201
    assert client.post("/api/v1/auth/guest", headers={"X-Real-IP": second}).status_code == 429
