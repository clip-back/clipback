from pathlib import Path
from tempfile import NamedTemporaryFile


def check_storage(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=root, prefix=".health-") as probe:
        probe.write(b"ok")
        probe.flush()


def check_configured_storage() -> None:
    from app.core.config import settings
    from app.integrations.storage_client import S3StorageClient

    if settings.storage_backend == "local":
        check_storage(settings.storage_root)
    else:
        client = S3StorageClient(settings)
        try:
            client.check_ready()
        finally:
            client.client.close()
