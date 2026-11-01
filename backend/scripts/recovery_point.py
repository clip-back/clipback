"""Recovery point key layout, identifier formats and the manifest contract (ADR 0004).

Published points live in the backup Bucket; downloaded points are private folders that the
isolated restore check reads. Both are checked against one manifest contract, and every
violation is `invalid_manifest`. The store argument is the backup Bucket adapter, which only
performs S3 reads and writes.
"""

import json
import re
import shutil
import tarfile
import tempfile
from datetime import datetime
from pathlib import PurePosixPath

from scripts.operator_errors import CheckError, require, sha256_file

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
    return match[1] if match and is_backup_id(match[1]) else None


def is_backup_id(value):
    """Letters, digits, dots, underscores and hyphens; `.` and `..` alone would be path steps."""
    return (
        isinstance(value, str)
        and bool(re.fullmatch(BACKUP_ID, value))
        and value not in {".", ".."}
    )


def is_sha256(value):
    return isinstance(value, str) and bool(SHA256.fullmatch(value))


def require_backup_id(value, code):
    require(is_backup_id(value), code)


def require_app_commit(value, code):
    require(isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{40}", value)), code)


def canonical_json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def completed_points(store):
    """IDs whose completion manifest is published, sorted."""
    return sorted(
        point_id(entry["key"])
        for entry in store.list_objects(POINTS_PREFIX)
        if re.fullmatch(rf"{POINTS_PREFIX}{BACKUP_ID}/manifest\.json", entry["key"])
        and is_backup_id(point_id(entry["key"]))
    )


def _parse_manifest(raw):
    try:
        return json.loads(raw)
    except ValueError as exc:
        raise CheckError("invalid_manifest") from exc


def read_point_json(store, backup_id):
    """A published point manifest as JSON, before the contract check."""
    require_backup_id(backup_id, "invalid_backup_id")
    return _parse_manifest(store.read(point_manifest_key(backup_id)))


def read_point_manifest(store, backup_id):
    """A published point manifest that keeps the contract for this backup ID."""
    manifest = read_point_json(store, backup_id)
    check_point_manifest(manifest, backup_id)
    return manifest


def point_unchanged(store, backup_id, manifest):
    """Whether the published manifest still equals `manifest`; the reread is not checked."""
    try:
        return json.loads(store.read(point_manifest_key(backup_id))) == manifest
    except ValueError:
        return False


def read_retiring_points(store):
    """Yield (backup ID, receipt key, manifest) per cleanup receipt, one receipt at a time.

    The receipt name and a JSON object are checked here; the caller checks the contract.
    """
    for item in store.list_objects(RECEIPTS_PREFIX):
        identifier = receipt_backup_id(item["key"])
        require(identifier is not None, "invalid_gc_receipt")
        manifest = _parse_manifest(store.read(item["key"]))
        require(isinstance(manifest, dict), "invalid_manifest")
        yield identifier, item["key"], manifest


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


def read_downloaded_manifest(directory):
    """The folder's manifest JSON as written, without checking it or the files."""
    return json.loads((directory / "manifest.json").read_text())


MANIFEST_FIELDS = {
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
    "extra_file_count",
}
SAMPLE_FIELDS = {"content_id", "asset_id", "saved_at", "category_ids", "content_sha256"}


def _field(value, key):
    """A required field; a missing field or a parent that is not an object breaks the contract."""
    require(isinstance(value, dict) and key in value, "invalid_manifest")
    return value[key]


def _aware_time(value):
    try:
        return datetime.fromisoformat(value).tzinfo is not None
    except (TypeError, ValueError):
        return False


def check_point_manifest(manifest, backup_id):
    """Raise `invalid_manifest` unless a published manifest or receipt keeps the contract."""
    _check_manifest(manifest, backup_id=backup_id)


def load_backup(directory):
    """Check a downloaded folder and return (manifest, file paths)."""
    try:
        manifest = read_downloaded_manifest(directory)
    except ValueError as exc:
        raise CheckError("invalid_manifest") from exc
    paths, expanded_size = _check_manifest(manifest, directory=directory)
    # Reserve space for unpacked files, a generously sized restored DB, and runtime overhead.
    required = expanded_size + paths["database"].stat().st_size * 6 + 1024**3
    require(shutil.disk_usage(tempfile.gettempdir()).free >= required, "insufficient_disk_space")
    return manifest, paths


def _check_manifest(manifest, *, backup_id=None, directory=None):
    """The one manifest contract for published points and downloaded folders.

    A published point is format 2, names `backup_id` and has no `images` entry. A downloaded
    folder also checks its files in the restore check's stage order: top-level fields, the
    database and images files, archive safety, then each asset, then the sample's asset.
    Format 1 folders are still read without the format 2 checks.
    """
    require(
        isinstance(manifest, dict)
        and manifest.get("format_version") in ((1, 2) if directory else (2,)),
        "invalid_manifest",
    )
    version = manifest["format_version"]
    allowed = set(MANIFEST_FIELDS)
    if directory:
        allowed.add("images")
    if version == 2:
        allowed.add("deletion_checkpoint")
    require(set(manifest).issubset(allowed), "invalid_manifest")
    require(manifest.get("origin") in ("production", "synthetic"), "invalid_manifest")
    if backup_id is None:
        require_backup_id(manifest.get("backup_id"), "invalid_manifest")
    else:
        require(manifest.get("backup_id") == backup_id, "invalid_manifest")
    require_app_commit(manifest.get("app_commit"), "invalid_manifest")
    require(_aware_time(_field(manifest, "captured_at")), "invalid_manifest")
    major = _field(manifest, "postgres_major")
    require(type(major) is int and 13 <= major <= 30, "invalid_manifest")
    revisions = _field(manifest, "migration_revisions")
    tables = _field(manifest, "tables")
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
    require(is_sha256(_field(manifest, "category_links_sha256")), "invalid_manifest")
    sample = _field(manifest, "sample")
    if sample is None:
        require(version == 2 and not _field(manifest, "assets"), "invalid_manifest")
    else:
        require(isinstance(sample, dict) and set(sample) == SAMPLE_FIELDS, "invalid_manifest")
        require(
            all(type(sample[k]) is int and sample[k] > 0 for k in ("content_id", "asset_id")),
            "invalid_manifest",
        )
        require(_aware_time(sample["saved_at"]), "invalid_manifest")
        require(
            isinstance(sample["category_ids"], list)
            and all(type(v) is int and v > 0 for v in sample["category_ids"]),
            "invalid_manifest",
        )
        require(is_sha256(sample["content_sha256"]), "invalid_manifest")
    paths = {}
    roles = [("database", "database.dump")]
    if directory:
        roles.append(("images", "images.tar"))
    for role, filename in roles:
        entry = _field(manifest, role)
        require(_field(entry, "file") == filename, "invalid_manifest")
        if version == 2 and role == "database":
            require(
                _field(entry, "backup_key") == point_dump_key(manifest["backup_id"]),
                "invalid_manifest",
            )
        if directory:
            path = directory / filename
            require(not path.is_symlink() and path.is_file(), "invalid_backup_file")
        size = _field(entry, "size_bytes")
        require(type(size) is int and size > 0, "invalid_manifest")
        require(is_sha256(_field(entry, "sha256")), "invalid_manifest")
        if directory:
            require(
                path.stat().st_size == size and sha256_file(path) == entry["sha256"],
                "backup_hash_mismatch",
            )
            paths[role] = path
    if directory:
        files, expanded_size = validate_archive(paths["images"])
    assets = _field(manifest, "assets")
    require(isinstance(assets, list), "invalid_manifest")
    seen, tar_files, tar_directories = set(), set(), set()
    for asset in assets:
        asset_id = _field(asset, "id")
        require(type(asset_id) is int and asset_id > 0 and asset_id not in seen, "invalid_manifest")
        seen.add(asset_id)
        key = _field(asset, "storage_key")
        require(
            isinstance(key, str)
            and key
            and not PurePosixPath(key).is_absolute()
            and ".." not in PurePosixPath(key).parts
            and "\\" not in key,
            "invalid_manifest",
        )
        size = _field(asset, "size_bytes")
        require(
            type(size) is int and size >= 0 and is_sha256(_field(asset, "sha256")),
            "invalid_manifest",
        )
        prefix = "screenshots/"
        if version == 2:
            require(asset.get("storage_backend") in ("local", "s3"), "invalid_manifest")
            require(
                type(asset.get("content_id")) is int and asset["content_id"] > 0, "invalid_manifest"
            )
            require(
                asset.get("backup_key") == original_key(asset["sha256"]), "invalid_manifest"
            )
            if asset["storage_backend"] == "s3":
                prefix = "s3/"
            # download writes one tar member per asset; equal or nested paths cannot coexist.
            tar_path = PurePosixPath(prefix + key)
            require(
                tar_path not in tar_files
                and tar_path not in tar_directories
                and not tar_files.intersection(tar_path.parents),
                "invalid_manifest",
            )
            tar_files.add(tar_path)
            tar_directories.update(tar_path.parents)
        if directory:
            require(prefix + key in files, "missing_asset")
    require(sample is None or sample["asset_id"] in seen, "invalid_manifest")
    if directory:
        return paths, expanded_size
