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


def test_screenshot_storage_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    for variable in (
        "STORAGE_ROOT",
        "SCREENSHOT_MAX_BYTES",
        "OCR_MODEL",
        "OCR_TIMEOUT_SECONDS",
        "OCR_MAX_OUTPUT_TOKENS",
    ):
        monkeypatch.delenv(variable, raising=False)

    settings = Settings(_env_file=None)

    assert str(settings.storage_root) == "storage"
    assert settings.screenshot_max_bytes == 10 * 1024 * 1024
    assert settings.ocr_model == "gpt-5.4-nano-2026-03-17"
    assert settings.ocr_timeout_seconds == 5
    assert settings.ocr_max_output_tokens == 4096


def test_screenshot_max_bytes_must_be_positive() -> None:
    with pytest.raises(ValidationError):
        Settings(screenshot_max_bytes=0, _env_file=None)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("ocr_timeout_seconds", 0),
        ("ocr_max_output_tokens", 0),
    ],
)
def test_ocr_numeric_settings_must_be_positive(field: str, value: int) -> None:
    with pytest.raises(ValidationError):
        Settings(**{field: value}, _env_file=None)
