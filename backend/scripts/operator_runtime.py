"""Explicit resources for backup commands, without importing API/provider settings."""

from pathlib import Path
from typing import Literal

from pydantic import SecretStr, field_validator, model_validator
from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.deletion_ledger_config import DeletionLedgerSettings
from app.integrations.storage_client import StorageRouter


class OperatorSettings(DeletionLedgerSettings):
    database_url: str
    storage_root: Path
    storage_backend: Literal["local", "s3"] = "local"
    s3_endpoint_url: str | None = None
    s3_bucket: str | None = None
    s3_region: str = "auto"
    s3_addressing_style: Literal["virtual", "path"] = "virtual"
    s3_access_key_id: SecretStr | None = None
    s3_secret_access_key: SecretStr | None = None

    @field_validator("database_url")
    @classmethod
    def database_connection(cls, value):
        try:
            url = make_url(value)
        except ArgumentError as exc:
            raise ValueError("A PostgreSQL database is required") from exc
        if url.drivername not in {"postgres", "postgresql", "postgresql+asyncpg"}:
            raise ValueError("A PostgreSQL database is required")
        return url.set(drivername="postgresql+asyncpg").render_as_string(hide_password=False)

    @model_validator(mode="after")
    def source_configuration(self):
        if not self.storage_root.is_absolute():
            raise ValueError("STORAGE_ROOT must be absolute")
        if self.storage_backend == "s3":
            for key in ("s3_endpoint_url", "s3_bucket", "s3_access_key_id", "s3_secret_access_key"):
                value = getattr(self, key)
                raw = value.get_secret_value() if isinstance(value, SecretStr) else value
                if not raw or not raw.strip():
                    raise ValueError("Original Bucket configuration is required")
            if self.app_environment == "production" and not self.s3_endpoint_url.startswith("https://"):
                raise ValueError("Original Bucket must use HTTPS in production")
        if self.deletion_ledger_backend == "local":
            if self.deletion_ledger_root.resolve().is_relative_to(self.storage_root.resolve()):
                raise ValueError("Deletion ledger must be outside originals")
            if self.app_environment == "production" and self.storage_backend == "s3":
                raise ValueError("Production Bucket images require an independent Bucket ledger")
        elif (self.deletion_ledger_s3_endpoint_url == self.s3_endpoint_url
              and self.deletion_ledger_s3_bucket == self.s3_bucket):
            raise ValueError("Deletion ledger must be independent from originals")
        return self


class OperatorRuntime:
    def __init__(self, config=None):
        self.config = config or OperatorSettings()
        self.engine = create_async_engine(self.config.database_url)
        self.sessions = async_sessionmaker(self.engine, expire_on_commit=False)
        self.storage = StorageRouter(self.config)

    async def close(self):
        await self.engine.dispose()
