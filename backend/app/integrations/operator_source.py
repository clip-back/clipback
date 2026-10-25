"""Anchored read-only access to an explicitly identified original Volume."""

import hashlib
import json
import os
import re
import stat
from contextlib import contextmanager

from app.integrations.storage_client import StorageUnavailableError

MARKER = ".clipback-source-id"
SOURCE_ID = re.compile(r"[A-Za-z0-9_-]{1,100}\Z")
_DIRECTORY = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


class SourceError(Exception):
    def __init__(self, code, status=503):
        self.code, self.status = code, status
        super().__init__(code)


def open_root(root):
    try:
        if not root.is_absolute():
            raise SourceError("source_root_invalid")
        return os.open(root, _DIRECTORY)
    except OSError as exc:
        raise SourceError("source_root_unavailable") from exc


def register_source(root, source_id):
    if not SOURCE_ID.fullmatch(source_id):
        raise SourceError("source_id_invalid")
    root_fd = open_root(root)
    try:
        try:
            fd = os.open(MARKER, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o600, dir_fd=root_fd)
            with os.fdopen(fd, "wb") as stream:
                stream.write((source_id + "\n").encode())
                stream.flush()
                os.fsync(stream.fileno())
            os.fsync(root_fd)
        except FileExistsError as exc:
            raise SourceError("source_already_registered") from exc
        except OSError as exc:
            raise SourceError("source_registration_failed") from exc
    finally:
        os.close(root_fd)


class SourceReader:
    def __init__(self, config):
        self.config = config

    @contextmanager
    def identified_root(self):
        root_fd = open_root(self.config.storage_root)
        try:
            try:
                fd = os.open(MARKER, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=root_fd)
                with os.fdopen(fd, "rb") as stream:
                    if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                        raise SourceError("source_identity_invalid")
                    identity = stream.read(102)
            except OSError as exc:
                raise SourceError("source_identity_unavailable") from exc
            if identity != (self.config.operator_source_id + "\n").encode():
                raise SourceError("source_identity_mismatch")
            yield root_fd
        finally:
            os.close(root_fd)

    def identify(self):
        with self.identified_root():
            return {"source_id": self.config.operator_source_id}

    def read(self, key):
        parts = key.split("/")
        if (not key or "\\" in key or "\x00" in key
                or any(part in {"", ".", "..", MARKER} for part in parts)):
            raise SourceError("source_key_invalid", 400)
        with self.identified_root() as root_fd:
            directories = []
            parent = root_fd
            try:
                for part in parts[:-1]:
                    parent = os.open(part, _DIRECTORY, dir_fd=parent)
                    directories.append(parent)
                fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
                with os.fdopen(fd, "rb") as stream:
                    info = os.fstat(stream.fileno())
                    if not stat.S_ISREG(info.st_mode):
                        raise SourceError("source_file_invalid", 400)
                    if info.st_size > self.config.screenshot_max_bytes:
                        raise SourceError("source_file_too_large")
                    body = stream.read(self.config.screenshot_max_bytes + 1)
                    if len(body) != info.st_size or len(body) > self.config.screenshot_max_bytes:
                        raise SourceError("source_file_changed")
                    return body
            except FileNotFoundError as exc:
                raise SourceError("source_file_missing", 404) from exc
            except OSError as exc:
                raise SourceError("source_read_failed") from exc
            finally:
                for fd in reversed(directories):
                    os.close(fd)


class RemoteSourceClient:
    """Operator-only local backend adapter; no source mutation methods are supported."""

    def __init__(self, config):
        self.url = config.operator_source_url.rstrip("/")
        self.source_id = config.operator_source_id
        self.key = config.operator_read_key.get_secret_value()
        self.limit = config.screenshot_max_bytes

    def headers(self):
        return {"Authorization": "Bearer " + self.key, "X-Source-ID": self.source_id}

    async def preflight(self):
        import httpx

        try:
            async with httpx.AsyncClient(
                timeout=10, trust_env=False, follow_redirects=False
            ) as http:
                async with http.stream("GET", self.url + "/source",
                                       headers=self.headers()) as response:
                    body = bytearray()
                    async for block in response.aiter_bytes():
                        body.extend(block)
                        if len(body) > 1024:
                            raise StorageUnavailableError("Remote source identity invalid")
                    if (response.status_code != 200
                            or json.loads(body) != {"source_id": self.source_id}):
                        raise StorageUnavailableError("Remote source identity failed")
        except (httpx.HTTPError, ValueError) as exc:
            raise StorageUnavailableError("Remote source unavailable") from exc

    async def read_file(self, storage_key):
        import httpx

        try:
            async with httpx.AsyncClient(
                timeout=10, trust_env=False, follow_redirects=False
            ) as http:
                async with http.stream("POST", self.url + "/source/read", headers=self.headers(),
                                       json={"storage_key": storage_key}) as response:
                    if response.status_code == 404:
                        raise FileNotFoundError("Content asset not found")
                    if response.status_code != 200:
                        raise StorageUnavailableError("Remote source read failed")
                    size = int(response.headers["X-Content-Size"])
                    if (response.headers.get("X-Source-ID") != self.source_id
                            or size < 0 or size > self.limit
                            or int(response.headers["Content-Length"]) != size):
                        raise StorageUnavailableError("Remote source response invalid")
                    body = bytearray()
                    async for block in response.aiter_bytes():
                        body.extend(block)
                        if len(body) > self.limit:
                            raise StorageUnavailableError("Remote source response too large")
                    if (len(body) != size or hashlib.sha256(body).hexdigest()
                            != response.headers.get("X-Content-SHA256")):
                        raise StorageUnavailableError("Remote source integrity failed")
                    return bytes(body)
        except (httpx.HTTPError, ValueError, KeyError) as exc:
            raise StorageUnavailableError("Remote source unavailable") from exc

    async def file_size(self, storage_key):
        return len(await self.read_file(storage_key))

    async def save_file(self, storage_key, content):
        raise StorageUnavailableError("Remote source is read-only")

    async def delete_file(self, storage_key):
        raise StorageUnavailableError("Remote source is read-only")
