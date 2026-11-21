import subprocess
import sys
from pathlib import Path

import pytest

from app.schemas.tag import normalize_tag_name


@pytest.mark.parametrize("name", ["요\x00리", "요\ud83d리"], ids=["nul", "unpaired-surrogate"])
def test_tag_normalization_rejects_unsupported_characters(name):
    with pytest.raises(ValueError, match="Tag name contains unsupported characters"):
        normalize_tag_name(name)


def test_uvicorn_logs_only_the_exception_type_for_unhandled_asgi_errors():
    result = subprocess.run(
        [
            sys.executable,
            "-c",
            """
import logging
from logging.config import dictConfig
from sqlalchemy.exc import DBAPIError
from uvicorn.config import LOGGING_CONFIG
from app.core.logging import configure_logging

dictConfig(LOGGING_CONFIG)
configure_logging()
configure_logging()
logger = logging.getLogger("uvicorn.error")
try:
    raise DBAPIError("SELECT", ("synthetic-parameter",), ValueError("synthetic-driver-detail"))
except DBAPIError as exc:
    logger.error("Exception in ASGI application\\n", exc_info=exc)
logger.info("server lifecycle message")
""",
        ],
        cwd=Path(__file__).resolve().parents[1],
        capture_output=True,
        text=True,
        check=True,
    )
    output = result.stderr + result.stdout
    assert all(
        token not in output
        for token in ("synthetic-", "Traceback", "[parameters:", "[SQL:")
    )
    assert output.count('{"event": "unhandled_error", "exception_type": "DBAPIError"}') == 1
    assert "server lifecycle message" in output
