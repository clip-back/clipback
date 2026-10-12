#!/usr/bin/env python3
"""Derive native sharing API configuration from the same Flutter DART_DEFINES."""
import base64
import os
import pathlib
import plistlib

value = "https://clipback-production.up.railway.app/api/v1"
for item in os.environ.get("DART_DEFINES", "").split(","):
    if not item:
        continue
    decoded = base64.b64decode(item).decode("utf-8")
    name, separator, setting = decoded.partition("=")
    if separator and name == "CLIPBACK_API_BASE_URL":
        value = setting.rstrip("/")
output = pathlib.Path(os.environ["TARGET_BUILD_DIR"]) / os.environ["UNLOCALIZED_RESOURCES_FOLDER_PATH"] / "ShareBuildConfig.plist"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(plistlib.dumps({"apiBaseUrl": value}))
