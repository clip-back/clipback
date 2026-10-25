"""Settings for ledger-only operator commands, independent from API/database startup."""

from pathlib import Path
from typing import Literal

from pydantic import SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class DeletionLedgerSettings(BaseSettings):
    # Explicit process environment only for standalone commands. API Settings keeps its .env policy.
    model_config = SettingsConfigDict(env_file=None)

    app_environment: Literal["local", "test", "production"] = "production"
    deletion_ledger_backend: Literal["local", "s3"] = "s3"
    deletion_ledger_root: Path = Path("deletion-ledger")
    deletion_ledger_s3_endpoint_url: str | None = None
    deletion_ledger_s3_bucket: str | None = None
    deletion_ledger_s3_region: str = "auto"
    deletion_ledger_s3_addressing_style: Literal["virtual", "path"] = "virtual"
    deletion_ledger_s3_access_key_id: SecretStr | None = None
    deletion_ledger_s3_secret_access_key: SecretStr | None = None

    @model_validator(mode="after")
    def require_ledger_configuration(self) -> "DeletionLedgerSettings":
        if self.deletion_ledger_backend == "s3":
            for key in (
                "deletion_ledger_s3_endpoint_url", "deletion_ledger_s3_bucket",
                "deletion_ledger_s3_access_key_id", "deletion_ledger_s3_secret_access_key",
            ):
                value = getattr(self, key)
                raw = value.get_secret_value() if isinstance(value, SecretStr) else value
                if not raw or not raw.strip():
                    raise ValueError(f"{key.upper()} is required for independent deletion ledger")
            if self.app_environment == "production" and not (
                self.deletion_ledger_s3_endpoint_url.startswith("https://")
            ):
                raise ValueError("DELETION_LEDGER_S3_ENDPOINT_URL must use HTTPS in production")
        return self
