"""Explicit resources for backup commands, without importing API/provider settings."""

from pathlib import Path
from typing import Literal

from pydantic import Field, SecretStr, field_validator, model_validator
from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.deletion_ledger_config import DeletionLedgerSettings
from app.integrations.operator_source import RemoteSourceClient
from app.integrations.storage_client import StorageRouter, StorageUnavailableError


class OperatorSettings(DeletionLedgerSettings):
    database_url: str
    storage_root: Path
    storage_backend: Literal["local", "s3"] = "local"
    operator_source_url: str | None = None
    operator_source_id: str | None = Field(default=None, pattern=r"^[A-Za-z0-9_-]{1,100}$")
    operator_read_key: SecretStr | None = None
    screenshot_max_bytes: int = Field(default=10 * 1024 * 1024, gt=0)
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
        if any((self.operator_source_url, self.operator_source_id, self.operator_read_key)):
            from urllib.parse import urlsplit

            if not all((self.operator_source_url, self.operator_source_id, self.operator_read_key)):
                raise ValueError("Complete remote source configuration is required")
            url = urlsplit(self.operator_source_url)
            if (url.scheme not in {"http", "https"} or not url.hostname or url.username
                    or url.password or url.query or url.fragment or url.path not in {"", "/"}
                    or len(self.operator_read_key.get_secret_value()) < 16
                    or not self.operator_read_key.get_secret_value().strip()
                    or "\r" in self.operator_read_key.get_secret_value()
                    or "\n" in self.operator_read_key.get_secret_value()):
                raise ValueError("Remote source configuration is invalid")
        if (self.app_environment == "production" and self.storage_backend == "local"
                and not self.operator_source_url):
            raise ValueError("Production Volume backups require an identified remote source")
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


class UnidentifiedLocalSource:
    """Production Bucket backups cannot fall back to an unverified legacy Volume."""

    async def read_file(self, storage_key):
        raise StorageUnavailableError("Legacy local originals require an identified remote source")

    async def file_size(self, storage_key):
        await self.read_file(storage_key)

    async def save_file(self, storage_key, content):
        raise StorageUnavailableError("Operator source is read-only")

    async def delete_file(self, storage_key):
        raise StorageUnavailableError("Operator source is read-only")


class OperatorRuntime:
    def __init__(self, config=None):
        self.config = config or OperatorSettings()
        self.engine = create_async_engine(self.config.database_url)
        self.sessions = async_sessionmaker(self.engine, expire_on_commit=False)
        if self.config.operator_source_url:
            local = RemoteSourceClient(self.config)
        elif self.config.app_environment == "production":
            local = UnidentifiedLocalSource()
        else:
            local = None
        self.storage = StorageRouter(self.config, local_client=local)

    async def preflight_source(self):
        if self.config.operator_source_url:
            await self.storage.for_backend("local").preflight()

    async def close(self):
        await self.engine.dispose()
