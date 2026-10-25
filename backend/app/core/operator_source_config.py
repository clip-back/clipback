"""Private source settings shared by the source listener and backup reader."""

from pathlib import Path

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class SourceSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=None)

    storage_root: Path
    operator_source_id: str = Field(pattern=r"^[A-Za-z0-9_-]{1,100}$")
    operator_read_key: SecretStr = Field(min_length=16)
    screenshot_max_bytes: int = Field(default=10 * 1024 * 1024, gt=0)
    operator_host: str = "::"
    operator_port: int = Field(default=9001, ge=1, le=65535)

    @field_validator("operator_read_key")
    @classmethod
    def safe_key(cls, value):
        raw = value.get_secret_value()
        if not raw.strip() or "\r" in raw or "\n" in raw:
            raise ValueError("Invalid operator read key")
        return value
