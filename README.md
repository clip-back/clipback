# Clipback

Monorepo for the Clipback MVP.

## Structure

```text
backend/   FastAPI backend service.
frontend/  Flutter app with API-backed auth, content, categories, and account stats.
docs/      MVP status, category policy, metrics, and deployment documents.
```

## Current status (2026-10-06)

This checkout combines the FE app with the backend from main (`8c759d1`).
The frontend uses backend APIs for authentication, content, categories, and account
statistics. Some recommendation and notification screens still use local or mock
behavior; remaining fixes and actual validation results are tracked in the
[FE integration progress](docs/fe-merge-fixes.md).

Backend APIs, PostgreSQL/HTTP integration tests, CI, and Railway deployment
configuration are included. Repository integration does not establish live Railway,
provider credential, backup, or real-device verification.

- [MVP status and remaining decisions](docs/backend-mvp-plan.md)
- [Backend setup and API contracts](backend/README.md)
- [Frontend scope](frontend/README.md)
- [Railway deployment and recovery](docs/railway-deployment.md)
- [Category recommendation policy](docs/category-recommendation-policy.md)
- [Product metrics](docs/product-metrics-queries.md)

## Backend

Start PostgreSQL:

```bash
docker compose up -d postgres
```

The local PostgreSQL container is exposed on host port `5433` to avoid conflicts with
an existing PostgreSQL running on `5432`.

Run migrations:

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
```

Run the API:

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload
```

Backend docs are available at:

```text
http://127.0.0.1:8000/docs
```
