from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import SettingsConfigDict

from app.core.deletion_ledger_config import DeletionLedgerSettings


class Settings(DeletionLedgerSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    youtube_summary_enabled: bool = True
    gemini_api_key: SecretStr | None = None
    youtube_data_api_key: SecretStr | None = None
    gemini_model: str = Field(default="gemini-3.5-flash-lite", pattern=r"^[a-zA-Z0-9._-]+$")

    project_name: str = "Clipback API"
    app_environment: Literal["local", "test", "production"] = "local"
    api_v1_prefix: str = "/api/v1"
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5433/clipback"
    backend_cors_origins: list[str] = Field(
        default_factory=lambda: ["http://localhost:3000", "http://localhost:5173"]
    )
    secret_key: str = "change-this-in-production"
    access_token_expire_minutes: int = 60 * 24 * 7
    refresh_token_expire_days: int = 90
    metadata_total_timeout_seconds: float = Field(default=5.0, gt=0)
    metadata_max_redirects: int = Field(default=3, ge=0)
    metadata_max_response_bytes: int = Field(default=1_000_000, gt=0)
    metadata_user_agent: str = "ClipbackBot/0.1"
    openai_api_key: SecretStr | None = None
    openai_model: str = "gpt-5.4-nano-2026-03-17"
    ai_timeout_seconds: float = Field(default=2.0, gt=0)
    ai_max_output_tokens: int = Field(default=64, gt=0)
    ai_reasoning_effort: Literal["none"] = "none"
    ocr_model: str = "gpt-5.4-nano-2026-03-17"
    ocr_timeout_seconds: float = Field(default=5.0, gt=0)
    ocr_max_output_tokens: int = Field(default=4096, gt=0)
    google_client_ids: list[str] = Field(default_factory=list)
    kakao_client_ids: list[str] = Field(default_factory=list)
    kakao_rest_api_key: SecretStr | None = None
    apple_client_id: str | None = None
    apple_team_id: str | None = None
    apple_key_id: str | None = None
    apple_private_key: SecretStr | None = None
    apple_token_encryption_key: SecretStr | None = None
    social_auth_timeout_seconds: float = Field(default=5.0, gt=0)
    storage_root: Path = Path("storage")
    storage_backend: Literal["local", "s3"] = "local"
    s3_endpoint_url: str | None = None
    s3_bucket: str | None = None
    s3_region: str = "auto"
    s3_addressing_style: Literal["virtual", "path"] = "virtual"
    s3_access_key_id: SecretStr | None = None
    s3_secret_access_key: SecretStr | None = None
    deletion_ledger_backend: Literal["local", "s3"] = "local"
    screenshot_max_bytes: int = Field(default=10 * 1024 * 1024, gt=0)

    @field_validator("database_url")
    @classmethod
    def normalize_database_url(cls, value: str) -> str:
        for prefix in ("postgres://", "postgresql://"):
            if value.startswith(prefix):
                return "postgresql+asyncpg://" + value[len(prefix) :]
        return value

    @model_validator(mode="after")
    def reject_default_production_secret(self) -> "Settings":
        if self.app_environment == "production" and self.secret_key == "change-this-in-production":
            raise ValueError("SECRET_KEY must be changed in production")
        if self.app_environment == "production" and (
            self.openai_api_key is None or not self.openai_api_key.get_secret_value().strip()
        ):
            raise ValueError("OPENAI_API_KEY is required in production")
        if self.app_environment == "production" and not any(
            client_id.strip() for client_id in self.google_client_ids
        ):
            raise ValueError("GOOGLE_CLIENT_IDS is required in production")
        if self.app_environment == "production" and not any(
            client_id.strip() for client_id in self.kakao_client_ids
        ) and (
            self.kakao_rest_api_key is None
            or not self.kakao_rest_api_key.get_secret_value().strip()
        ):
            raise ValueError("KAKAO_CLIENT_IDS or KAKAO_REST_API_KEY is required in production")
        if self.app_environment == "production":
            if self.database_url == Settings.model_fields["database_url"].default:
                raise ValueError("DATABASE_URL must be configured in production")
            if not self.storage_root.is_absolute():
                raise ValueError("STORAGE_ROOT must be absolute in production")
        if self.storage_backend == "s3":
            for key in ("s3_endpoint_url", "s3_bucket", "s3_access_key_id", "s3_secret_access_key"):
                value = getattr(self, key)
                raw = value.get_secret_value() if isinstance(value, SecretStr) else value
                if not raw or not raw.strip():
                    raise ValueError(f"{key.upper()} is required for S3 storage")
            if self.app_environment == "production" and not self.s3_endpoint_url.startswith("https://"):
                raise ValueError("S3_ENDPOINT_URL must use HTTPS in production")
        if self.deletion_ledger_backend == "local":
            if self.deletion_ledger_root.resolve().is_relative_to(self.storage_root.resolve()):
                raise ValueError("DELETION_LEDGER_ROOT must be outside STORAGE_ROOT")
            if self.app_environment == "production" and self.storage_backend == "s3":
                raise ValueError("DELETION_LEDGER_BACKEND must be s3 for production Bucket images")
        else:
            if (
                self.deletion_ledger_s3_endpoint_url == self.s3_endpoint_url
                and self.deletion_ledger_s3_bucket == self.s3_bucket
            ):
                raise ValueError("DELETION_LEDGER_S3_BUCKET must be independent from image Bucket")
        if self.youtube_summary_enabled:
            for key in ("gemini_api_key", "youtube_data_api_key"):
                value = getattr(self, key)
                if value is None or not value.get_secret_value().strip():
                    raise ValueError(
                        f"{key.upper()} is required when YouTube summaries are enabled"
                    )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
