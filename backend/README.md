# Clipback Backend

FastAPI backend scaffold for the Clipback MVP.

## MVP Scope

- Save link-based content from share flow or direct input.
- Upload screenshot-based content.
- Require category selection at save time.
- Save user-owned free-form tags with content and replace them later.
- Update favorite state and permanently delete owned content.
- Provide a latest-first home feed with text search plus category and favorite filters.
- Provide content detail and original link access metadata.
- Track product metrics such as re-open events and category filter usage.

## Local Development

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
uvicorn app.main:app --reload
```

## Database Migrations

Set `DATABASE_URL` to your PostgreSQL database before running migrations.

Example:

```env
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5433/clipback
```

Start the local PostgreSQL service from the repository root:

```bash
docker compose up -d postgres
```

The Compose service exposes PostgreSQL on host port `5433` to avoid conflicts with
an existing local PostgreSQL running on `5432`.

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
```

API docs will be available at:

```text
http://127.0.0.1:8000/docs
```

## Validation

The backend supports Python 3.11 and 3.12. Run the same checks used by CI from the
`backend` directory:

```bash
ruff check app alembic tests
pytest -q
python -m compileall app alembic tests
alembic upgrade head
alembic check
```

The migration checks require PostgreSQL and a valid `DATABASE_URL`.

Category repository tests additionally require an explicit `TEST_DATABASE_URL` pointing
to a dedicated PostgreSQL test database with migrations applied. They roll back each
test's transaction and are skipped locally when the variable is not set. CI runs them
against its PostgreSQL service after applying migrations.

```bash
export TEST_DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5433/clipback_test
DATABASE_URL="$TEST_DATABASE_URL" alembic upgrade head
pytest -q tests/repositories/test_category_repository.py
```

## Guest Authentication

Create a guest session with `POST /api/v1/auth/guest`. The response contains a
7-day access token and a rotating 90-day refresh token.

Send the access token to protected endpoints:

```text
Authorization: Bearer <access_token>
```

Use `POST /api/v1/auth/refresh` to rotate the refresh token and issue a new token
pair. Use `POST /api/v1/auth/logout` to revoke the refresh session and all access
tokens issued for that session.

Social sign-in uses credentials obtained by the Flutter provider SDKs. Send a Google
or Kakao ID token, or a Naver access token, to `POST /api/v1/auth/social/{provider}`.
The response uses the same Clipback access and refresh tokens and adds `is_new_user`.
An authenticated guest can preserve existing data by calling
`POST /api/v1/auth/social/{provider}/upgrade`; the previous guest sessions are revoked
after a successful upgrade. Provider tokens are verified for the request and are not
stored.

The root, health, OpenAPI, and authentication endpoints are public except for guest
social upgrades. User, content, category, feed, upload, and metric endpoints require
Bearer authentication.

Production must set `APP_ENVIRONMENT=production` and replace the example
`SECRET_KEY`; startup validation rejects the default production secret.

## Category Summaries

Both category list endpoints require Bearer authentication and return arrays of
`CategorySummaryRead` objects:

- `GET /api/v1/categories` keeps the existing default-first, category-ID ascending
  order and includes empty categories and the shared default `미분류` category.
- `GET /api/v1/categories/recent?limit=2` returns categories with saved content,
  excluding `미분류`. The default limit is 2, valid values are 1 through 20, and
  invalid values return `422`. Results sort by `last_saved_at` descending, then
  category ID ascending. There is no pagination; no matching categories returns `[]`.

```json
[
  {
    "id": 3,
    "name": "여행",
    "color": "#0891B2",
    "is_default": false,
    "content_count": 5,
    "last_saved_at": "2026-09-07T03:00:00Z"
  }
]
```

`content_count` counts only the current user's content currently assigned to each
category. `last_saved_at` is the maximum original content `saved_at`, not a category
creation, move, or view time. Both fields are always present; an empty category has
`content_count: 0` and `last_saved_at: null`.

Links and screenshots count regardless of favorite state. A content item assigned
to multiple categories counts once in each, so summing category counts may exceed
the user's total content count. Deletion and category moves affect the next query;
moving older content preserves its original save time. No counters or event history
are used, and no migration is required.

Category creation responses and categories nested inside content responses continue
to use `CategoryRead` without these aggregate fields.

## Screenshot Storage

`POST /api/v1/uploads/screenshots` accepts one PNG, JPEG, or WebP image up to
10MB as multipart form data and returns the saved content with its asset metadata.
Set `STORAGE_ROOT` to change the local filesystem storage directory.

Saved images are private. Use the Bearer-authenticated asset URL returned in
`ContentRead.assets` to download an image.

## Structure

```text
app/api          HTTP routes grouped by API version.
app/core         Settings, security, logging, shared exceptions.
app/db           SQLAlchemy session and database bootstrap.
app/models       Database models.
app/schemas      Pydantic request/response schemas.
app/repositories Data access layer.
app/services     Business logic layer.
app/integrations External systems such as AI, OCR, metadata, and storage.
tests            API, service, and repository tests.
```
