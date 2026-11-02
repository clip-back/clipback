"""Read-only audit of every completed point and cleanup receipt in the backup Bucket (#177).

Operators run it locally from `backend/`; it is not part of the operator or API image.
It only lists and reads objects, and prints no Bucket name, credential or config path.
"""

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path

from scripts.image_backup import BackupBucket, verify_backup
from scripts.operator_errors import CheckError, require
from scripts.recovery_point import (
    RECEIPTS_PREFIX,
    canonical_json,
    check_point_manifest,
    completed_points,
    read_point_json,
    read_retiring_points,
)


def error_code(exc):
    return str(exc) if isinstance(exc, CheckError) else type(exc).__name__


def outcome(check):
    try:
        check()
        return "passed"
    except Exception as exc:
        return error_code(exc)


def check_receipt(store, points, identifier, manifest):
    # Same order as maintain; the receipt's objects may already be gone, so none are read.
    if identifier in points:
        require(canonical_json(read_point_json(store, identifier)) == canonical_json(manifest),
                "gc_receipt_conflict")
    require(manifest.get("format_version") == 2, "retention_requires_v2")
    check_point_manifest(manifest, identifier)


def audit(store):
    report = {"checked_at": datetime.now(UTC).isoformat(timespec="seconds"), "points": {}}
    points = completed_points(store)
    for identifier in points:
        report["points"][identifier] = outcome(lambda: verify_backup(store, identifier))
    # One listing: its failure names no receipt, so it is the top-level error.
    receipts = store.list_objects(RECEIPTS_PREFIX)
    report["receipts"] = dict.fromkeys((item["key"] for item in receipts), "not_checked")
    try:
        for identifier, key, manifest in read_retiring_points(store, receipts):
            report["receipts"][key] = outcome(
                lambda: check_receipt(store, points, identifier, manifest)
            )
    except Exception as exc:
        # Receipts are read in key order; reading stops at the first receipt that fails.
        first = next(key for key, value in report["receipts"].items() if value == "not_checked")
        report["receipts"][first] = error_code(exc)
    report["passed"] = all(
        value == "passed" for value in [*report["points"].values(), *report["receipts"].values()]
    )
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup-config-file", type=Path,
                        help="Private JSON file; otherwise BACKUP_BUCKET_CONFIG_JSON is consumed")
    args = parser.parse_args()
    try:
        store = (BackupBucket.from_config_file(args.backup_config_file)
                 if args.backup_config_file else BackupBucket.from_environment())
        report = audit(store)
    except Exception as exc:
        # No key to report against, and earlier point results are not kept.
        report = {"passed": False, "error": error_code(exc)}
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
