"""Explicit one-time source Volume registration; never creates the source directory."""

import argparse
import json
from pathlib import Path

from app.integrations.operator_source import SourceError, register_source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    register = commands.add_parser("register")
    register.add_argument("--root", type=Path, required=True)
    register.add_argument("--source-id", required=True)
    register.add_argument("--confirm-volume", action="store_true", required=True)
    args = parser.parse_args()
    try:
        register_source(args.root, args.source_id)
        print(json.dumps({"passed": True, "source_id": args.source_id}))
        return 0
    except SourceError as exc:
        print(json.dumps({"passed": False, "error": exc.code}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
