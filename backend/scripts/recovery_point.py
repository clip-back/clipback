"""Recovery point key layout, identifier formats and manifest reading (ADR 0004).

Published points live in the backup Bucket; downloaded points are private folders that the
isolated restore check reads. The store argument is the backup Bucket adapter, which only
performs S3 reads and writes.
"""

import json
import re
import shutil
import tarfile
import tempfile
from datetime import datetime
from pathlib import PurePosixPath

from scripts.operator_errors import require, sha256_file

BACKUP_ID = r"[A-Za-z0-9._-]{1,100}"
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
ORIGINALS_PREFIX = "originals/"
POINTS_PREFIX = "points/"
RECEIPTS_PREFIX = "gc/points/"


def original_key(sha256):
    return f"{ORIGINALS_PREFIX}sha256/{sha256}"


def point_prefix(backup_id):
    return f"{POINTS_PREFIX}{backup_id}/"


def point_id(key):
    """The backup ID segment of a key under a point prefix."""
    return key.split("/")[1]


def point_dump_key(backup_id):
    return point_prefix(backup_id) + "database.dump"


def point_manifest_key(backup_id):
    return point_prefix(backup_id) + "manifest.json"


def receipt_key(backup_id):
    return f"{RECEIPTS_PREFIX}{backup_id}.json"


def receipt_backup_id(key):
    """The backup ID named by a cleanup receipt key, or None for a malformed name."""
    match = re.fullmatch(rf"{re.escape(RECEIPTS_PREFIX)}({BACKUP_ID})\.json", key)
    return match[1] if match else None


def require_backup_id(value, code):
    require(bool(re.fullmatch(BACKUP_ID, value)), code)


def require_app_commit(value, code):
    require(bool(re.fullmatch(r"[0-9a-f]{40}", value)), code)


def canonical_json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def completed_points(store):
    """IDs whose completion manifest is published, sorted."""
    return sorted(
        point_id(entry["key"])
        for entry in store.list_objects(POINTS_PREFIX)
        # The unescaped "." is kept as published; tightening it is a behavior change.
        if re.fullmatch(rf"{POINTS_PREFIX}{BACKUP_ID}/manifest.json", entry["key"])
    )


def read_point_manifest(store, backup_id):
    require_backup_id(backup_id, "invalid_backup_id")
    return json.loads(store.read(point_manifest_key(backup_id)))


def read_retiring_points(store):
    """Yield (backup ID, receipt key, manifest) per cleanup receipt, one receipt at a time."""
    for item in store.list_objects(RECEIPTS_PREFIX):
        identifier = receipt_backup_id(item["key"])
        require(identifier is not None, "invalid_gc_receipt")
        yield identifier, item["key"], json.loads(store.read(item["key"]))


def validate_archive(path):
    """Reject links, special files, ambiguous paths and duplicate file entries."""
    files, directories, size = set(), set(), 0
    with tarfile.open(path, "r:*") as archive:
        for member in archive:
            name = member.name
            normalized = PurePosixPath(name)
            require(
                not normalized.is_absolute() and ".." not in normalized.parts and "\\" not in name,
                "unsafe_archive",
            )
            require(member.isfile() or member.isdir(), "unsafe_archive")
            require(not member.issparse() and member.size >= 0, "unsafe_archive")
            key = str(normalized)
            if key == ".":
                require(member.isdir(), "unsafe_archive")
                continue
            parents = {str(parent) for parent in normalized.parents} - {"."}
            require(not parents.intersection(files), "unsafe_archive")
            if member.isfile():
                require(key not in files and key not in directories, "unsafe_archive")
                require(
                    not any(p.startswith(key + "/") for p in files | directories), "unsafe_archive"
                )
                files.add(key)
                size += member.size
            else:
                require(key not in files, "unsafe_archive")
                directories.add(key)
    return files, size


def load_backup(directory):
    manifest = json.loads((directory / "manifest.json").read_text())
    require(
        isinstance(manifest, dict) and manifest.get("format_version") in {1, 2}, "invalid_manifest"
    )
    version = manifest["format_version"]
    allowed = {
        "format_version",
        "backup_id",
        "origin",
        "captured_at",
        "app_commit",
        "postgres_major",
        "migration_revisions",
        "tables",
        "category_links_sha256",
        "assets",
        "sample",
        "database",
        "images",
        "extra_file_count",
    }
    if version == 2:
        allowed.add("deletion_checkpoint")
    require(set(manifest).issubset(allowed), "invalid_manifest")
    require(manifest.get("origin") in {"production", "synthetic"}, "invalid_manifest")
    require_backup_id(manifest.get("backup_id", ""), "invalid_manifest")
    require_app_commit(manifest.get("app_commit", ""), "invalid_manifest")
    captured = datetime.fromisoformat(manifest["captured_at"])
    require(captured.tzinfo is not None, "invalid_manifest")
    major = manifest["postgres_major"]
    require(type(major) is int and 13 <= major <= 30, "invalid_manifest")
    revisions, tables = manifest["migration_revisions"], manifest["tables"]
    require(
        isinstance(revisions, list)
        and revisions
        and all(isinstance(v, str) and v for v in revisions),
        "invalid_manifest",
    )
    require(
        isinstance(tables, dict)
        and tables
        and all(isinstance(k, str) and type(v) is int and v >= 0 for k, v in tables.items()),
        "invalid_manifest",
    )
    require(bool(SHA256.fullmatch(manifest["category_links_sha256"])), "invalid_manifest")
    sample = manifest["sample"]
    paths = {}
    if sample is None:
        require(version == 2 and not manifest["assets"], "invalid_manifest")
    else:
        require(
            isinstance(sample, dict)
            and all(type(sample[k]) is int and sample[k] > 0 for k in ("content_id", "asset_id")),
            "invalid_manifest",
        )
        require(
            set(sample) == {"content_id", "asset_id", "saved_at", "category_ids", "content_sha256"},
            "invalid_manifest",
        )
        require(datetime.fromisoformat(sample["saved_at"]).tzinfo is not None, "invalid_manifest")
        require(
            isinstance(sample["category_ids"], list)
            and all(type(v) is int and v > 0 for v in sample["category_ids"]),
            "invalid_manifest",
        )
        require(bool(SHA256.fullmatch(sample["content_sha256"])), "invalid_manifest")
    for role, filename in (("database", "database.dump"), ("images", "images.tar")):
        entry = manifest[role]
        require(entry["file"] == filename, "invalid_manifest")
        path = directory / filename
        require(not path.is_symlink() and path.is_file(), "invalid_backup_file")
        require(type(entry["size_bytes"]) is int and entry["size_bytes"] > 0, "invalid_manifest")
        require(bool(SHA256.fullmatch(entry["sha256"])), "invalid_manifest")
        require(
            path.stat().st_size == entry["size_bytes"] and sha256_file(path) == entry["sha256"],
            "backup_hash_mismatch",
        )
        paths[role] = path
    files, expanded_size = validate_archive(paths["images"])
    assets = manifest["assets"]
    require(isinstance(assets, list), "invalid_manifest")
    seen = set()
    for asset in assets:
        require(
            type(asset["id"]) is int and asset["id"] > 0 and asset["id"] not in seen,
            "invalid_manifest",
        )
        seen.add(asset["id"])
        key = asset["storage_key"]
        require(
            isinstance(key, str)
            and key
            and not PurePosixPath(key).is_absolute()
            and ".." not in PurePosixPath(key).parts
            and "\\" not in key,
            "invalid_manifest",
        )
        require(
            type(asset["size_bytes"]) is int
            and asset["size_bytes"] >= 0
            and bool(SHA256.fullmatch(asset["sha256"])),
            "invalid_manifest",
        )
        prefix = "screenshots/"
        if version == 2:
            require(asset.get("storage_backend") in {"local", "s3"}, "invalid_manifest")
            require(
                type(asset.get("content_id")) is int and asset["content_id"] > 0, "invalid_manifest"
            )
            require(
                asset.get("backup_key") == original_key(asset["sha256"]), "invalid_manifest"
            )
            if asset["storage_backend"] == "s3":
                prefix = "s3/"
        require(prefix + key in files, "missing_asset")
    require(sample is None or sample["asset_id"] in seen, "invalid_manifest")
    # Reserve space for unpacked files, a generously sized restored DB, and runtime overhead.
    required = expanded_size + paths["database"].stat().st_size * 6 + 1024**3
    require(shutil.disk_usage(tempfile.gettempdir()).free >= required, "insufficient_disk_space")
    return manifest, paths
