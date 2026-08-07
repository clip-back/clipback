import asyncio
import os
import tempfile
from pathlib import Path
from typing import Protocol


class StorageClient(Protocol):
    async def save_file(self, storage_key: str, content: bytes) -> None: ...

    async def read_file(self, storage_key: str) -> bytes: ...

    async def delete_file(self, storage_key: str) -> None: ...


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
