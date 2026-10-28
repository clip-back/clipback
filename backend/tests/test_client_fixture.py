from pytest import MonkeyPatch

from app.main import app
from tests.conftest import client


def test_client_fixture_restores_maintenance_between_clients():
    original_gate = app.state.maintenance
    try:
        for _ in range(2):
            with MonkeyPatch.context() as patch:
                fixture = client.__wrapped__(patch)
                try:
                    next(fixture)
                    assert app.state.maintenance is not original_gate
                finally:
                    fixture.close()
            assert getattr(app.state, "maintenance", None) is original_gate
    finally:
        app.state.maintenance = original_gate
