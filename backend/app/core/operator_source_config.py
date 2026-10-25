"""Private source settings shared by the source listener and backup reader."""

from pathlib import Path

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class SourceSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=None)

    storage_root: Path
    operator_source_id: str = Field(pattern=r"^[A-Za-z0-9_-]{1,100}$")
    operator_read_key: SecretStr = Field(min_length=16)
    operator_control_key: SecretStr | None = Field(default=None, min_length=16)
    database_url: str | None = None
    screenshot_max_bytes: int = Field(default=10 * 1024 * 1024, gt=0)
    operator_host: str = "::"
    operator_port: int = Field(default=9001, ge=1, le=65535)

    @field_validator("operator_read_key", "operator_control_key")
    @classmethod
    def safe_key(cls, value):
        if value is None:
            return value
        raw = value.get_secret_value()
        if not raw.strip() or "\r" in raw or "\n" in raw:
            raise ValueError("Invalid operator read key")
        return value

    @model_validator(mode="after")
    def separate_control(self):
        if self.operator_control_key and self.operator_control_key == self.operator_read_key:
            raise ValueError("Operator control and read keys must differ")
        return self
