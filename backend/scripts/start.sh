#!/bin/sh
set -eu
python -c 'from app.core.config import settings; from app.core.storage_health import check_storage; check_storage(settings.storage_root)'
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}" --workers 1
