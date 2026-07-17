import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_production_rejects_default_secret() -> None:
    with pytest.raises(ValidationError):
        Settings(
            app_environment="production",
            secret_key="change-this-in-production",
            _env_file=None,
        )


def test_local_allows_default_secret() -> None:
    settings = Settings(
        app_environment="local",
        secret_key="change-this-in-production",
        _env_file=None,
    )

    assert settings.app_environment == "local"
