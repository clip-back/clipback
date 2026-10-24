"""A ready restored database must accept TCP, including during slow image init."""

import json
import os

import pytest

from scripts.check_backup_restore import CheckError, RestoreDrill, check
from tests.deployment.test_backup_restore_docker import real_backup as real_backup

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="RUN_DOCKER_RECOVERY_TESTS=1 and a labelled local image are required",
)


class SlowInitializationDrill(RestoreDrill):
    def __init__(self, initialization_sql):
        super().__init__()
        self.initialization_sql = initialization_sql

    def container(self, name, *args):
        if name.endswith("-db"):
            args = (*args[:-1], "-v",
                    f"{self.initialization_sql}:/docker-entrypoint-initdb.d/99-delayed.sql:ro",
                    args[-1])
        return super().container(name, *args)

    def wait(self, *command):
        super().wait(*command)
        if command[:1] == ("exec",) and "pg_isready" in command:
            try:
                self.docker(
                    "exec", command[1], "pg_isready", "-h", "127.0.0.1",
                    "-U", "postgres", "-d", "clipback",
                )
            except CheckError:
                raise CheckError("database_readiness_returned_before_tcp") from None


def test_restoration_waits_for_final_tcp_server_during_slow_initialization(real_backup, tmp_path):
    directory, _, credentials, image = real_backup
    initialization = tmp_path / "delay.sql"
    initialization.write_text("SELECT pg_sleep(5);\n")
    initialization.chmod(0o644)
    report = check(directory, credentials, image, SlowInitializationDrill(initialization))
    assert report["passed"], json.dumps(report)
    assert report["authentication_passed"] and report["image_bytes_passed"]
    assert report["cleanup_passed"]
