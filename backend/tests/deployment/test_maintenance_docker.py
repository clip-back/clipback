"""Actual API/private control and server fallback over PostgreSQL18 in a built image."""

import json
import os
import subprocess
import time
from uuid import uuid4

import pytest

pytestmark = pytest.mark.skipif(
    os.environ.get("RUN_DOCKER_RECOVERY_TESTS") != "1",
    reason="Opt-in real Docker/PG18 and built images required",
)


def test_private_maintenance_survives_restart_and_operator_commands_cannot_write():
    name = "maintenance100-" + uuid4().hex[:12]
    db, api = name + "-db", name + "-api"
    api_image = os.environ.get("CLIPBACK_SOURCE_API_TEST_IMAGE", "clipback-api:ticket100")
    operator_image = os.environ.get("CLIPBACK_OPERATOR_TEST_IMAGE", "clipback-operator:ticket100")
    containers = []

    def docker(*args, check=True):
        return subprocess.run(["docker", *args], check=check, capture_output=True, text=True)

    env = [
        "-e",
        "APP_ENVIRONMENT=test",
        "-e",
        "YOUTUBE_SUMMARY_ENABLED=false",
        "-e",
        "DATABASE_URL=postgresql://postgres:fixture@127.0.0.1:5432/clipback",
        "-e",
        "STORAGE_ROOT=/data/screenshots",
        "-e",
        "DELETION_LEDGER_BACKEND=local",
        "-e",
        "DELETION_LEDGER_ROOT=/data/ledger",
    ]

    def command(image, *args):
        return docker(
            "run",
            "--rm",
            "--network",
            f"container:{db}",
            *env,
            "--entrypoint",
            "python",
            image,
            *args,
            check=False,
        )

    def request(path, *, method="GET", data=None, key=None, port=8000):
        payload = json.dumps(
            {"path": path, "method": method, "data": data, "key": key, "port": port}
        )
        code = """
import json,urllib.request,urllib.error
p=json.loads('PAYLOAD')
req=urllib.request.Request('http://127.0.0.1:'+str(p['port'])+p['path'],method=p['method'],
 data=json.dumps(p['data']).encode() if p['data'] is not None else None,
 headers={'Content-Type':'application/json',
  **({'Authorization':'Bearer '+p['key']} if p['key'] else {})})
try:
 with urllib.request.urlopen(req,timeout=3) as r: print(json.dumps([r.status,json.load(r)]))
except urllib.error.HTTPError as e: print(json.dumps([e.code,json.load(e)]))
""".replace("PAYLOAD", payload)
        return json.loads(docker("exec", api, "python", "-c", code).stdout)

    try:
        docker(
            "run",
            "-d",
            "--name",
            db,
            "-e",
            "POSTGRES_PASSWORD=fixture",
            "-e",
            "POSTGRES_DB=clipback",
            "postgres:18",
        )
        containers.append(db)
        for _ in range(200):
            if (
                docker(
                    "exec", db, "pg_isready", "-h", "127.0.0.1", "-U", "postgres", check=False
                ).returncode
                == 0
            ):
                break
            time.sleep(0.1)
        migrated = command(api_image, "-m", "alembic", "upgrade", "head")
        assert migrated.returncode == 0, migrated.stdout + migrated.stderr
        docker(
            "run",
            "-d",
            "--name",
            api,
            "--network",
            f"container:{db}",
            *env,
            "-e",
            "OPERATOR_SOURCE_ID=source100",
            "-e",
            "OPERATOR_READ_KEY=read100-safe-token",
            "-e",
            "OPERATOR_CONTROL_KEY=control100-safe-token",
            "-e",
            "OPERATOR_HOST=0.0.0.0",
            api_image,
        )
        containers.append(api)
        for _ in range(100):
            try:
                if request("/api/v1/health")[0] == 200:
                    break
            except Exception:
                time.sleep(0.1)
        assert request("/")[0] == 200
        run = str(uuid4())
        for key in ["read100-safe-token", "ordinary-app-token"]:
            assert (
                request(
                    "/maintenance/start", method="POST", data={"run_id": run}, key=key, port=9001
                )[0]
                == 403
            )
        control = {"key": "control100-safe-token", "port": 9001}
        assert (
            request("/maintenance/start", method="POST", data={"run_id": run}, **control)[1][
                "phase"
            ]
            == "draining"
        )
        assert (
            request("/maintenance/drain", method="POST", data={"run_id": run}, **control)[1][
                "phase"
            ]
            == "frozen"
        )
        assert request("/")[0] == 503
        assert request("/api/v1/health/ready")[0] == 200
        for module, args in [
            ("scripts.image_storage_admin", ["pause"]),
            ("scripts.image_deletions", ["retry"]),
        ]:
            refused = command(operator_image, "-m", module, *args)
            assert refused.returncode == 1
        status = command(operator_image, "-m", "scripts.maintenance", "status")
        assert status.returncode == 0
        assert json.loads(status.stdout)["phase"] == "frozen"
        docker("restart", api)
        for _ in range(100):
            try:
                if request("/api/v1/health")[0] == 200:
                    break
            except Exception:
                time.sleep(0.1)
        assert request("/")[0] == 503
        resumed = command(operator_image, "-m", "scripts.maintenance", "resume", "--run-id", run)
        assert resumed.returncode == 0, resumed.stdout + resumed.stderr
        assert request("/")[0] == 200
        assert request("/maintenance")[0] == 404
    finally:
        for container in reversed(containers):
            docker("rm", "-f", "-v", container, check=False)
