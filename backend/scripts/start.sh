#!/bin/sh
set -eu
python -c 'from app.core.storage_health import check_configured_storage; check_configured_storage()'
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}" --workers 1
