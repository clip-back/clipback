from collections.abc import Iterator

from fastapi.testclient import TestClient
import pytest

from app.main import app


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(app) as test_client:
        yield test_client

