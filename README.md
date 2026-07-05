# Clipback

Monorepo for the Clipback MVP.

## Structure

```text
backend/   FastAPI backend service.
frontend/  Frontend application. Planned.
docs/      Product and API documents. Planned.
```

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
