"""Fixed operator error codes shared by the recovery point and restore check modules."""

import hashlib


class CheckError(Exception):
    """A fixed public error code, without subprocess output or private data."""


def require(condition, code):
    if not condition:
        raise CheckError(code)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()
