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


def test_production_requires_openai_api_key() -> None:
    with pytest.raises(ValidationError):
        Settings(
            app_environment="production",
            secret_key="production-secret",
            openai_api_key=None,
            _env_file=None,
        )


def test_production_accepts_openai_api_key() -> None:
    settings = Settings(
        app_environment="production",
        secret_key="production-secret",
        openai_api_key="test-key",
        _env_file=None,
    )

    assert settings.openai_model == "gpt-5.4-nano-2026-03-17"


def test_screenshot_storage_defaults() -> None:
    settings = Settings(_env_file=None)

    assert str(settings.storage_root) == "storage"
    assert settings.screenshot_max_bytes == 10 * 1024 * 1024


def test_screenshot_max_bytes_must_be_positive() -> None:
    with pytest.raises(ValidationError):
        Settings(screenshot_max_bytes=0, _env_file=None)
