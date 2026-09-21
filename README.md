# Clipback

Monorepo for the Clipback MVP.

## Structure

```text
backend/   FastAPI backend service.
frontend/  Flutter screens using mock data and local state in this checkout.
docs/      MVP status, category policy, metrics, and deployment documents.
```

## Current status (2026-09-21)

Core MVP backend APIs, PostgreSQL/HTTP integration tests, CI, and Railway deployment
configuration are implemented in this checkout (`9fbadd8`). The user has reported
Railway deployment; live connectivity, provider credentials, backups, and real-device
flows have not been verified by this documentation update. The local Flutter app
still uses mock data; this does not describe work in other checkouts.

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
