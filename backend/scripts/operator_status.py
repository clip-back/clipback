"""Compact read-only Railway cron and GitHub PR status for local operators."""

import argparse
import json
import subprocess


def read_json(command):
    result = subprocess.run(command, capture_output=True, text=True, timeout=60, check=True)
    return json.loads(result.stdout)


def cron_status(service, environment):
    rows = read_json(["railway", "cron", "list", "--service", service,
                      "--environment", environment, "--limit", "5", "--json"])
    return {"service": service, "environment": environment, "runs": [
        {key: row.get(key) for key in (
            "id", "deploymentId", "status", "createdAt", "completedAt", "durationSeconds"
        )} for row in rows
    ], "backup_objects_verified": False}


def pr_status(number):
    result = read_json(["gh", "pr", "view", str(number), "--json",
                        "url,state,headRefOid,mergeable,mergeStateStatus,reviewDecision,"
                        "statusCheckRollup"])
    checks = result.pop("statusCheckRollup")
    result["checks"] = [{key: check.get(key) for key in (
        "name", "status", "conclusion", "state"
    )} for check in checks or []]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    cron = sub.add_parser("cron")
    cron.add_argument("--service", required=True)
    cron.add_argument("--environment", default="production")
    pr = sub.add_parser("pr")
    pr.add_argument("number", type=int)
    args = parser.parse_args()
    try:
        result = (cron_status(args.service, args.environment) if args.command == "cron"
                  else pr_status(args.number))
        print(json.dumps(result, sort_keys=True))
        return 0
    except (OSError, subprocess.SubprocessError, ValueError, TypeError, KeyError):
        # Provider stderr/metadata may contain commands, credentials or user material.
        print(json.dumps({"passed": False, "error": "status_query_failed"}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
