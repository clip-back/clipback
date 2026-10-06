from pathlib import Path
from tempfile import NamedTemporaryFile


def check_storage(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=root, prefix=".health-") as probe:
        probe.write(b"ok")
        probe.flush()
