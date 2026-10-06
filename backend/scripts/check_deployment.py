"""Build-independent Docker persistence/restore check; deletes only its UUID-named resources."""

import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
PROBE = (ROOT / "tests/deployment/probe.py").read_text()


def docker(*args, **kwargs):
    return subprocess.run(
        ["docker", *args], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **kwargs
    ).stdout


def wait_for(command):
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        try:
            command()
            return
        except subprocess.CalledProcessError:
            time.sleep(1)
    raise RuntimeError("Container readiness timed out")


def run(image):
    prefix = "clipback-check-" + uuid4().hex[:12]
    network, db, api = [prefix + suffix for suffix in ("-net", "-db", "-api")]
    volumes = [prefix + suffix for suffix in ("-pg", "-files", "-restored-pg", "-restored-files")]
    database_url = f"postgresql://postgres:deployment%25test%40@{db}:5432/clipback"
    environment = [
        "APP_ENVIRONMENT=production",
        "YOUTUBE_SUMMARY_ENABLED=false",
        "SECRET_KEY=deployment-check-secret",
        "OPENAI_API_KEY=unused-test-key",
        'GOOGLE_CLIENT_IDS=["unused-test-id"]',
        "KAKAO_REST_API_KEY=unused-test-key",
        "BACKEND_CORS_ORIGINS=[]",
        f"DATABASE_URL={database_url}",
        "STORAGE_ROOT=/data/screenshots",
        "PORT=8123",
    ]
    env_args = [arg for value in environment for arg in ("-e", value)]

    def start_db(volume):
        docker(
            "run",
            "-d",
            "--name",
            db,
            "--network",
            network,
            "-e",
            "POSTGRES_PASSWORD=deployment%test@",
            "-e",
            "POSTGRES_DB=clipback",
            "-v",
            f"{volume}:/var/lib/postgresql/data",
            "postgres:16",
        )
        wait_for(
            lambda: docker(
                "exec", db, "pg_isready", "-h", "127.0.0.1", "-U", "postgres", "-d", "clipback"
            )
        )

    def start_api(volume):
        docker(
            "run",
            "-d",
            "--name",
            api,
            "--network",
            network,
            *env_args,
            "-v",
            f"{volume}:/data",
            image,
        )
        wait_for(
            lambda: docker(
                "exec",
                api,
                "python",
                "-c",
                "import urllib.request; urllib.request.urlopen("
                "'http://127.0.0.1:8123/api/v1/health/ready', timeout=3)",
            )
        )

    def probe(state=None):
        args = (json.dumps(state),) if state else ()
        return json.loads(docker("exec", "-i", api, "python", "-", *args, input=PROBE.encode()))

    try:
        docker("network", "create", "--internal", network)
        for volume in volumes:
            docker("volume", "create", volume)
        start_db(volumes[0])
        docker("run", "--rm", "--network", network, *env_args, image, "alembic", "upgrade", "head")
        docker("run", "--rm", "--network", network, *env_args, image, "alembic", "check")
        start_api(volumes[1])
        state = probe()
        assert probe(state) == {"verified": True}
        docker("rm", "-f", api)
        docker("rm", "-f", db)
        start_db(volumes[0])
        start_api(volumes[1])
        assert probe(state) == {"verified": True}
        print("Container recreation preserved authentication, content and image bytes.")

        # Stop all application writes before creating the paired backup.
        docker("stop", api)
        with tempfile.TemporaryDirectory(prefix=prefix) as directory:
            dump = Path(directory) / "database.dump"
            archive = Path(directory) / "images.tar"
            dump.write_bytes(docker("exec", db, "pg_dump", "-U", "postgres", "-Fc", "clipback"))
            archive.write_bytes(
                docker(
                    "run",
                    "--rm",
                    "--network",
                    "none",
                    "-v",
                    f"{volumes[1]}:/data:ro",
                    image,
                    "tar",
                    "-C",
                    "/data",
                    "-cf",
                    "-",
                    ".",
                )
            )
            docker("rm", "-f", api)
            docker("rm", "-f", db)
            start_db(volumes[2])
            docker(
                "exec",
                "-i",
                db,
                "pg_restore",
                "-U",
                "postgres",
                "-d",
                "clipback",
                "--exit-on-error",
                input=dump.read_bytes(),
            )
            docker(
                "run",
                "--rm",
                "-i",
                "--network",
                "none",
                "-v",
                f"{volumes[3]}:/data",
                image,
                "tar",
                "-C",
                "/data",
                "-xf",
                "-",
                input=archive.read_bytes(),
            )
        start_api(volumes[3])
        assert probe(state) == {"verified": True}
        print("Paired backup restored into new volumes and passed the same API checks.")
    except Exception:
        for container in (api, db):
            result = subprocess.run(
                ["docker", "logs", "--tail", "30", container], capture_output=True, text=True
            )
            print(result.stdout, result.stderr)
        raise
    finally:
        for container in (api, db):
            subprocess.run(["docker", "rm", "-f", container], capture_output=True)
        for volume in volumes:
            subprocess.run(["docker", "volume", "rm", volume], capture_output=True)
        subprocess.run(["docker", "network", "rm", network], capture_output=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", default="clipback-backend:check")
    run(parser.parse_args().image)
