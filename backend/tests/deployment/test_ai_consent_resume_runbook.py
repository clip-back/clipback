import os
import re
import subprocess
from pathlib import Path

import pytest

RUNBOOK = Path(__file__).resolve().parents[3] / "docs/backend/image-operator-first-run.md"
CONFIRMED = {
    "ai_restore_db_confirmed": "yes",
    "ai_restore_replica_confirmed": "yes",
    "ai_restore_api_value": "true",
    "ai_restore_worker_value": "true",
    "ai_restore_run_id": "synthetic-run",
}


@pytest.mark.parametrize("override", [
    {},
    {"ai_restore_db_confirmed": ""},
    {"ai_restore_replica_confirmed": ""},
    {"ai_restore_api_value": "false"},
    {"ai_restore_api_value": ""},
    {"ai_restore_worker_value": "false"},
    {"ai_restore_worker_value": ""},
    {"ai_restore_run_id": ""},
])
def test_documented_restore_resume_requires_all_confirmations(override):
    snippet = re.search(
        r"(?ms)^   ```sh\n(   if \[ .*?^   fi)\n   ```", RUNBOOK.read_text(),
    )
    assert snippet is not None
    result = subprocess.run(
        ["sh", "-c", 'python() { printf "%s\\n" "$*"; }\n' + snippet[1]],
        env={**os.environ, **CONFIRMED, **override},
        capture_output=True, text=True, timeout=5, check=False,
    )
    if override:
        assert result.returncode == 1
        assert result.stdout == ""
        assert "점검을 유지합니다" in result.stderr
    else:
        assert result.returncode == 0
        assert result.stdout.splitlines() == [
            "-m scripts.maintenance resume --run-id synthetic-run",
        ]
