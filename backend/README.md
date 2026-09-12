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

PostgreSQL repository tests additionally require an explicit `TEST_DATABASE_URL` pointing
to a dedicated PostgreSQL test database with migrations applied. They roll back each
test's transaction and are skipped locally when the variable is not set. CI runs them
against its PostgreSQL service after applying migrations.

```bash
export TEST_DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5433/clipback_test
DATABASE_URL="$TEST_DATABASE_URL" alembic upgrade head
pytest -q tests/repositories
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

## My Page Account and Statistics

`GET /api/v1/users/me` requires Bearer authentication and returns the existing account
fields plus its creation time and linked social providers:

```json
{
  "id": 7,
  "email": null,
  "display_name": "사용자",
  "is_guest": false,
  "created_at": "2026-09-07T03:00:00Z",
  "linked_providers": ["kakao"]
}
```

`created_at` is the original account creation timestamp, including a timezone. The
frontend formats the displayed date. `linked_providers` contains only provider names
(`google`, `kakao`, `naver`) sorted alphabetically, or `[]` without linked identities.
Provider subjects and authentication tokens are never included; this endpoint reads
the database without contacting social providers.

`GET /api/v1/users/me/stats` uses the same authentication and returns lifetime event counts:

```json
{
  "saved_count": 218,
  "reopened_count": 72
}
```

- `saved_count` counts the current user's recorded `content_created` events.
- `reopened_count` counts their recorded `content_reopened` events, including repeat
  views of the same content. It can exceed the save count.
- Deleting content preserves these counts: its events remain with a null `content_id`.
- No recorded events returns `0` for both fields. Other event types do not count.
- Reading content detail does not record a view. A successful
  `POST /api/v1/contents/{id}/view` records one; separately recorded retries count too.
- Historical content without recorded events is not backfilled or estimated. There
  are no period, category, favorite, or pagination parameters.

Frontend integration should label these values **누적 저장 / 누적 열람**. They are event
counts, not counts of distinct or currently retained content. Reading either My Page
endpoint does not create events.

Existing guest accounts and authentication endpoints remain supported. Social-only
sign-up is a separate follow-up; this change does not remove guest data or require a
migration.

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
are used. The summaries themselves require no schema changes.

Category creation responses and categories nested inside content responses continue
to use `CategoryRead` without these aggregate fields.

## Personal Categories: Update and Delete

Default categories are copied into each user's ownership at initial guest or social
signup. `is_default: true` marks a provided category; it does not prevent editing.
Only the global `미분류` remains shared and immutable. Existing global defaults stay
in the database as hidden signup templates, never as selectable category IDs.
Login and guest-to-social promotion do not recreate deleted categories.

`PATCH /api/v1/categories/{category_id}` accepts a partial object:

```json
{"name": "여행 준비", "color": "#0891B2"}
```

- Only supplied fields change. `color: null` removes the color; omitted color stays.
- Name is trimmed, nonblank, at most 40 characters, and cannot be null. Color keeps
  the existing maximum of 20 characters. Empty objects and unknown fields return `422`.
- A case-insensitive duplicate among other visible categories returns `409`.
  The target is excluded, allowing case changes and identical-value requests.
- Success returns `200` with `CategoryRead` (`id`, `name`, `color`, `is_default`).
  Renaming or recoloring does not create content events.

`DELETE /api/v1/categories/{category_id}` has no request body and returns `204`
with no response body. Deleting an empty category is allowed. A repeated delete
returns `404`. Both mutations require Bearer authentication (`401` on failure).
Unknown IDs, another user's categories, shared templates and `미분류` return `404`.

Deletion removes only that category's links. Other categories remain; content with
no remaining category receives `미분류`. Content, images, tags, favorite state and
original save times remain. Each changed content records `category_changed` with
`before_category_ids` and `after_category_ids`; past events remain and their deleted
`category_id` becomes null. Cumulative saves/views do not change. Missing `미분류`
when needed rolls back everything with `500`; a concurrent new reference that
prevents deletion rolls back everything with `409`. No automatic retry is performed.

Frontend: allow both provided and custom categories to be edited/deleted, but disable
these actions for the shared `미분류`. After success, refetch category lists and affected
content; counts and recent categories reflect the current relationships immediately.

### Deploying existing data

Migration `202609070010` creates personal defaults for existing users and moves
content links and event `category_id` references by owner. If a user already has a
case-insensitive matching name, that personal category is reused (smallest ID if
legacy case variants exist), retaining its name, color and `is_default` value.
Historical event JSON snapshots are retained unchanged. There are no new columns.

Stop application writes, back up the database, apply `alembic upgrade head`, and
start the new backend together. Do not run old writers against the migrated database.
Clients must discard cached category IDs and refetch the category list. Personal
edits/deletions cannot be losslessly merged back into shared categories, so downgrade
is explicitly refused; rollback requires restoring the pre-migration backup and old
application together. Validate this data migration on a backup before production.

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


## MVP API integration tests

`tests/integration` exercises HTTP routes, real authentication, services, PostgreSQL
repositories, and local image storage together. Only social-provider verification,
web metadata, AI recommendations, and OCR responses are replaced with deterministic
results. Unexpected external HTTP requests fail the test, even when caught by an
application fallback. No external credentials are required.

Use a dedicated test database, never an application database:

```sh
DATABASE_URL="$TEST_DATABASE_URL" .venv/bin/alembic upgrade head
.venv/bin/pytest -q tests/repositories tests/integration
```

Set `TEST_DATABASE_URL` explicitly to a PostgreSQL asyncpg URL before running these
commands. Without it, DB tests skip; an invalid connection or missing migrations
fails. The CI PostgreSQL job applies migrations and runs both suites as required
checks. Existing Python 3.11/3.12 jobs continue running tests without a database.

Each integration test opens an outer transaction. Every sequential HTTP request
uses a new session and savepoint, allowing actual application commits and rollbacks
while rolling back the entire test at teardown. This is not a concurrency harness;
existing separate-connection repository tests cover concurrency. Each test uses a
fresh app and temporary storage directory; settings and client replacements are
restored afterward.

Scenarios cover guest/social login and promotion, token refresh/logout, direct and
shared link saving, category personalization/deletion, feed filters and pagination,
cumulative view statistics, screenshot download/deletion, cross-user isolation, and
DB failure compensation that removes an already-written image. These tests do not
validate live provider credentials, external service quality, deployment, or load.

## Railway deployment

The runtime image uses Python 3.12, one Uvicorn worker, and `${PORT:-8000}`.
Set the Railway service root to `/backend`, attach a volume at `/data`, set
`STORAGE_ROOT=/data/screenshots`, and run `alembic upgrade head` as the pre-deploy
command. `/api/v1/health/ready` checks PostgreSQL and writable storage with a
three-second timeout; `/api/v1/health` retains its existing liveness contract.

See [Railway deployment and paired backup/restore](../docs/railway-deployment.md)
for all required variables, dashboard settings, Docker persistence checks, and
recovery instructions. Actual Railway provisioning and deployment are separate
from these repository changes.
