"""Supervise public API and optional private source listener as one deployment."""

import os
import signal
import subprocess
import sys
import time


def main():
    commands = [[sys.executable, "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0",
                 "--port", os.environ.get("PORT", "8000"), "--workers", "1"]]
    if os.environ.get("OPERATOR_READ_KEY"):
        from app.core.operator_source_config import SourceSettings

        try:
            config = SourceSettings()
            if config.operator_port == int(os.environ.get("PORT", "8000")):
                raise ValueError("Operator and public ports must differ")
        except ValueError:
            print("operator_configuration_invalid", file=sys.stderr)
            return 1
        commands.append([sys.executable, "-m", "uvicorn", "app.operator:create_operator_app",
                         "--factory", "--host", config.operator_host,
                         "--port", str(config.operator_port), "--workers", "1", "--no-access-log"])
    stopping = False

    def stop(signum, frame):
        nonlocal stopping
        stopping = True

    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, stop)
    children = []
    failed = False
    try:
        for command in commands:
            children.append(subprocess.Popen(command))
        while not stopping:
            if any(child.poll() is not None for child in children):
                failed = True
                break
            time.sleep(0.1)
    finally:
        for child in children:
            if child.poll() is None:
                child.terminate()
        for child in children:
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
