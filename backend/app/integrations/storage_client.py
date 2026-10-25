from __future__ import annotations

import asyncio
import os
import tempfile
from pathlib import Path
from typing import TYPE_CHECKING, Protocol

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

if TYPE_CHECKING:
    from app.core.config import Settings


class StorageClient(Protocol):
    async def save_file(self, storage_key: str, content: bytes) -> None: ...

    async def read_file(self, storage_key: str) -> bytes: ...

    async def delete_file(self, storage_key: str) -> None: ...

    async def file_size(self, storage_key: str) -> int: ...


class LocalStorageClient:
    def __init__(self, root: Path) -> None:
        self.root = root.resolve()

    async def save_file(self, storage_key: str, content: bytes) -> None:
        path = self._resolve(storage_key)
        await asyncio.to_thread(self._write_atomically, path, content)

    async def read_file(self, storage_key: str) -> bytes:
        path = self._resolve(storage_key)
        return await asyncio.to_thread(path.read_bytes)

    async def delete_file(self, storage_key: str) -> None:
        path = self._resolve(storage_key)
        await asyncio.to_thread(path.unlink, missing_ok=True)

    async def file_size(self, storage_key: str) -> int:
        return (await asyncio.to_thread(self._resolve(storage_key).stat)).st_size

    def _resolve(self, storage_key: str) -> Path:
        path = (self.root / storage_key).resolve()
        try:
            path.relative_to(self.root)
        except ValueError as exc:
            raise ValueError("Storage key escapes the storage root") from exc
        return path

    @staticmethod
    def _write_atomically(path: Path, content: bytes) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary_path: str | None = None
        try:
            with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temporary_file:
                temporary_path = temporary_file.name
                temporary_file.write(content)
                temporary_file.flush()
                os.fsync(temporary_file.fileno())
            os.replace(temporary_path, path)
        finally:
            if temporary_path is not None:
                Path(temporary_path).unlink(missing_ok=True)


class StorageUnavailableError(OSError):
    """The configured object store could not complete an operation."""


class S3StorageClient:
    def __init__(self, config: Settings) -> None:
        if not all((config.s3_bucket, config.s3_endpoint_url,
                    config.s3_access_key_id, config.s3_secret_access_key)):
            raise StorageUnavailableError("Object storage is not configured")
        self.bucket = config.s3_bucket
        self.client = boto3.client(
            "s3",
            endpoint_url=config.s3_endpoint_url,
            region_name=config.s3_region,
            aws_access_key_id=config.s3_access_key_id.get_secret_value(),
            aws_secret_access_key=config.s3_secret_access_key.get_secret_value(),
            config=Config(
                signature_version="s3v4", connect_timeout=1, read_timeout=2,
                retries={"total_max_attempts": 1},
                s3={"addressing_style": config.s3_addressing_style},
            ),
        )

    async def save_file(self, storage_key: str, content: bytes) -> None:
        await asyncio.to_thread(self._put, storage_key, content)

    def _put(self, storage_key: str, content: bytes) -> None:
        try:
            self.client.put_object(Bucket=self.bucket, Key=storage_key, Body=content)
        except (BotoCoreError, ClientError) as exc:
            raise StorageUnavailableError("Object storage write failed") from exc

    async def read_file(self, storage_key: str) -> bytes:
        return await asyncio.to_thread(self._read, storage_key)

    def _read(self, storage_key: str) -> bytes:
        try:
            response = self.client.get_object(Bucket=self.bucket, Key=storage_key)
            with response["Body"] as stream:
                return stream.read()
        except ClientError as exc:
            if exc.response["Error"]["Code"] in {"NoSuchKey", "404", "NotFound"}:
                raise FileNotFoundError("Content asset not found") from exc
            raise StorageUnavailableError("Object storage read failed") from exc
        except BotoCoreError as exc:
            raise StorageUnavailableError("Object storage read failed") from exc

    async def delete_file(self, storage_key: str) -> None:
        await asyncio.to_thread(self._delete, storage_key)

    def _delete(self, storage_key: str) -> None:
        try:
            self.client.delete_object(Bucket=self.bucket, Key=storage_key)
        except (BotoCoreError, ClientError) as exc:
            raise StorageUnavailableError("Object storage delete failed") from exc

    async def file_size(self, storage_key: str) -> int:
        return await asyncio.to_thread(self._file_size, storage_key)

    def _file_size(self, storage_key: str) -> int:
        try:
            return self.client.head_object(Bucket=self.bucket, Key=storage_key)["ContentLength"]
        except ClientError as exc:
            if exc.response["Error"]["Code"] in {"NoSuchKey", "404", "NotFound"}:
                raise FileNotFoundError("Content asset not found") from exc
            raise StorageUnavailableError("Object storage read failed") from exc
        except BotoCoreError as exc:
            raise StorageUnavailableError("Object storage read failed") from exc

    async def download_url(self, storage_key: str, *, mime_type: str, expires_in: int) -> str:
        try:
            return await asyncio.to_thread(
                self.client.generate_presigned_url,
                "get_object",
                Params={
                    "Bucket": self.bucket, "Key": storage_key, "ResponseContentType": mime_type,
                },
                ExpiresIn=expires_in,
            )
        except (BotoCoreError, ClientError) as exc:
            raise StorageUnavailableError("Object storage access failed") from exc

    def check_ready(self) -> None:
        try:
            self.client.list_objects_v2(Bucket=self.bucket, MaxKeys=1)
        except (BotoCoreError, ClientError) as exc:
            raise StorageUnavailableError("Object storage unavailable") from exc


class StorageRouter:
    def __init__(self, config: Settings, *, local_client=None) -> None:
        self.config = config
        self.backend = config.storage_backend
        self._clients: dict[str, StorageClient] = {
            "local": local_client or LocalStorageClient(config.storage_root)
        }

    def for_backend(self, backend: str) -> StorageClient:
        if backend == "s3" and backend not in self._clients:
            self._clients[backend] = S3StorageClient(self.config)
        if backend not in self._clients:
            raise ValueError("Unsupported asset storage backend")
        return self._clients[backend]

    async def save_file(self, storage_key: str, content: bytes) -> None:
        await self.for_backend(self.backend).save_file(storage_key, content)

    async def read_file(self, storage_key: str, *, backend: str = "local") -> bytes:
        return await self.for_backend(backend).read_file(storage_key)

    async def delete_file(self, storage_key: str, *, backend: str | None = None) -> None:
        await self.for_backend(backend or self.backend).delete_file(storage_key)


def get_storage_client() -> StorageRouter:
    from app.core.config import settings

    return StorageRouter(settings)
