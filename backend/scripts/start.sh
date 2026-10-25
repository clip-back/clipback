#!/bin/sh
set -eu
python -c 'from app.core.storage_health import check_configured_storage; check_configured_storage()'
exec python -m scripts.serve
