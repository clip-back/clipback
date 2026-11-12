# 백엔드 API 계약

현재 API의 요청·응답·오류·권한·재시도 계약을 모은 참조 문서입니다. 서버 준비·실행은 [백엔드 README](../../backend/README.md), 전용 테스트 DB와 로컬 검증은 [테스트 안내](testing.md)를 따릅니다.
기존 문서의 영어 설명과 코드·JSON 예시는 그대로 보존합니다. 코드 경로·설정·명령은 별도 표기가 없으면 `backend/` 기준입니다.

## 문서 내 목차

- [담당 기준](#담당-기준)
- [MVP Scope](#mvp-scope)
- [API 구현 목록](#api-구현-목록)
- [Guest Authentication](#guest-authentication)
- [Mobile Social Authentication](#mobile-social-authentication)
- [Native Mobile Share Authentication and Retries](#native-mobile-share-authentication-and-retries)
- [My Page Account and Statistics](#my-page-account-and-statistics)
- [회원 탈퇴](#회원-탈퇴)
- [Content View Events](#content-view-events)
- [Today Recommendations](#today-recommendations)
- [Weekly Recommendations](#weekly-recommendations)
- [Recommendation Exposures](#recommendation-exposures)
- [Category Summaries](#category-summaries)
- [Personal Categories: Update and Delete](#personal-categories-update-and-delete)
- [Content Category Validation](#content-category-validation)
- [Content URL Length](#content-url-length)
- [Tag Replacement](#tag-replacement)
- [Feed Pagination](#feed-pagination)
- [Screenshot Storage](#screenshot-storage)
- [추천 API 연결 계약](#추천-api-연결-계약)

## 담당 기준

- 일반 HTTP 계약과 API 목록: 이 문서
- 자동 분류·AI 계약: [카테고리 추천 정책](../category-recommendation-policy.md)
- Today·Weekly 선정·시간·집계·삭제 정책: [콘텐츠 재발견 정책](../content-recommendation-plan.md)
- YouTube·인스타그램 URL·요약 상태·오류 코드·worker·공급자 설정: [요약 안내](../youtube-summary.md)
- 화면 상태·클라이언트 재전송: [프론트 동작 기준](../frontend/behavior.md)
- 운영·마이그레이션·복구 실행: [Railway 운영](../railway-deployment.md)

## MVP Scope

- Save link-based content from share flow or direct input.
- Save YouTube videos/Shorts immediately and summarize eligible public videos asynchronously.
  See [YouTube API, worker and rollout guide](../youtube-summary.md); enabled by default; Gemini and YouTube API keys are required.
- Summarize saved Instagram reels/posts (`/reel/`, `/p/`, `/tv/`) asynchronously from the public page caption with OpenAI;
  disabled by default (`INSTAGRAM_SUMMARY_ENABLED`), see the Instagram section of the same guide.
  `summary_error_code` also returns `content_unavailable`, `unsupported_content` and `insufficient_content` (always `skipped`).
- Upload screenshot-based content.
- Prefer manual category selection; otherwise use AI recommendation or uncategorized fallback.
- Personalize default categories and support category editing, deletion, summaries, and recent lists.
- Support guest/social authentication and My Page account information and lifetime statistics.
- Save user-owned free-form tags with content and replace them later.
- Update favorite state and permanently delete owned content.
- Provide a latest-first home feed with text search plus category and favorite filters.
- Provide content detail and original link access metadata.
- Track product metrics such as re-open events and category filter usage.

<a id="4-api-구현-목록"></a>

## API 구현 목록

| Method | Path | 목적 | 상태 |
| --- | --- | --- | --- |
| `POST` | `/api/v1/auth/guest` | 게스트 생성과 JWT 발급 | 구현 |
| `POST` | `/api/v1/auth/refresh` | refresh token 회전 | 구현 |
| `POST` | `/api/v1/auth/logout` | 인증 세션 폐기 | 구현 |
| `POST` | `/api/v1/auth/social/apple/challenge` | Apple 로그인·게스트 승격용 5분 일회용 nonce 발급 | 구현 |
| `POST` | `/api/v1/auth/social/{provider}` | 소셜 가입·로그인 | 구현 |
| `POST` | `/api/v1/auth/social/{provider}/upgrade` | 게스트 데이터 유지 소셜 전환 | 구현 |
| `GET` | `/api/v1/users/me` | 현재 사용자·가입일·연동 로그인 제공자 조회 | 구현 |
| `GET` | `/api/v1/users/me/stats` | 이벤트 기준 누적 저장·열람 횟수(삭제 후에도 유지)와 최근 7×24시간 다시 본 보관 중 콘텐츠 수 | 구현 |
| `DELETE` | `/api/v1/users/me` | 회원 탈퇴: 계정과 그 계정의 서비스 데이터 즉시 삭제, 탈퇴 사유 기록 | 구현 |
| `GET` | `/api/v1/categories` | 기본·사용자 카테고리 목록과 내 콘텐츠 수·마지막 저장일 | 구현 |
| `GET` | `/api/v1/categories/recent` | 내 콘텐츠 저장순 최근 카테고리, 미분류·빈 카테고리 제외 | 구현 |
| `POST` | `/api/v1/categories` | 사용자 카테고리 생성 | 구현 |
| `PATCH` | `/api/v1/categories/{id}` | 개인화된 기본·사용자 카테고리 이름·색상 수정 | 구현 |
| `DELETE` | `/api/v1/categories/{id}` | 카테고리 삭제, 콘텐츠 보존 및 필요 시 미분류 이동 | 구현 |
| `POST` | `/api/v1/contents` | 링크 직접 입력 저장 | 구현 |
| `POST` | `/api/v1/contents/share` | OS 공유 링크 저장 | Instagram·YouTube 구현 |
| `GET` | `/api/v1/contents/{id}` | 콘텐츠 상세 조회 | 구현 |
| `PUT` | `/api/v1/contents/{id}/categories` | 콘텐츠 카테고리 보정 | 구현 |
| `PUT` | `/api/v1/contents/{id}/tags` | 콘텐츠 태그 전체 교체 | 구현 |
| `PUT` | `/api/v1/contents/{id}/favorite` | 콘텐츠 즐겨찾기 상태 지정 | 구현 |
| `DELETE` | `/api/v1/contents/{id}` | 콘텐츠 영구 삭제 | 구현 |
| `POST` | `/api/v1/contents/{id}/view` | 재열람 기록 | 구현 |
| `GET` | `/api/v1/feed` | 제목·요약·태그 검색과 카테고리·즐겨찾기 필터 | 구현 |
| `GET` | `/api/v1/recommendations/today` | Today 선정·일별 결과와 최신 카드 조회 | 구현 |
| `GET` | `/api/v1/recommendations/weekly` | Weekly 집계·카드 선정과 현재 카테고리 요약 조회 | 구현 |
| `POST` | `/api/v1/recommendations/exposures` | 추천 카드 노출과 UUID 중복 방지·추천 집계 | 구현 |
| `POST` | `/api/v1/uploads/screenshots` | 스크린샷 콘텐츠 저장 | 구현 |
| `GET` | `/api/v1/uploads/assets/{id}` | 인증된 스크린샷 자산 조회 | 구현 |
| `GET` | `/api/v1/uploads/assets/{id}/access` | 원본 권한 확인·직접 다운로드 정보 | 구현 |
| `POST` | `/api/v1/metrics/events` | 사용자 행동 이벤트 기록 | 구현 |
| `GET` | `/api/v1/health` | 서버 응답 확인 | 구현 |
| `GET` | `/api/v1/health/ready` | DB·이미지 저장소 준비 상태 | 구현 |

요청·응답의 세부 계약은 [엔드포인트별 계약 안내](#guest-authentication)와 실행 중인 서버의 `/docs`를 참고한다.
피드 응답은 `items`, `next_cursor`, `total_count`다. `total_count`는 같은 사용자·카테고리·즐겨찾기·검색어 조건의 목록 전체 개수(0 이상의 정수)이며 커서·limit과 무관하게 매 요청 다시 센다.
`next_cursor`는 해석하지 않고 그대로 전달하는 문자열이며, 검색·카테고리·즐겨찾기 조건, 정렬이나 계정이 바뀌면 초기화한다.
`sort`는 `latest`(기본) 또는 `favorites_first`이며 상세 계약은 [Feed Pagination](#feed-pagination)을 따른다.

위 목록은 MVP 현황 문서에서, 다음 엔드포인트별 상세 설명은 기존 백엔드 README에서 이관했습니다. 추천 정책 문서에 있던 추가 HTTP 조건은 마지막 절에 출처를 구분해 보존합니다.

## 카테고리 생성·수정 제출 복구

`POST /api/v1/categories`와 `PATCH /api/v1/categories/{category_id}`는 선택적 UUID `Idempotency-Key`를 받는다.
키 없는 기존 요청의 상태·본문·검증은 유지한다. 키가 있으면 같은 계정·키의 작업 종류, 수정 대상 ID,
정규화된 전송 이름·색상과 부분 수정 필드의 존재 여부를 비교하고, DB 변경과 최소 처리 결과를 같은 트랜잭션에 저장한다.
동시 제출은 직렬화하며 같은 제출의 재전송은 원래 HTTP 상태와 결과를 재사용한다.

- 생성 성공 `201`과 수정 성공 `200`은 기존 카테고리 필드와 `submission: {key, status: "succeeded", replayed}`를 반환한다.
- 확정된 이름 중복 `409`는 `code: "category_name_exists"`, `detail`, 같은 형태의 `submission`을 반환하며
  `status`는 `"rejected"`다. 같은 키의 거절은 나중에 이름이 비어도 재실행하지 않는다.
- 수정 성공 기록이 없는 대상의 부재·소유권 거절은 기존 `404`와 `code: "category_target_missing"`,
  `status: "rejected"`인 제출 기록을 반환한다. 원래 성공 기록이 있으면 대상 삭제 뒤에도 과거 `200`을 재사용한다.
- 같은 계정·키를 다른 내용이나 작업에 사용하면 `409 category_submission_conflict`로 응답하며
  원래 제출의 성공·거절로 간주할 `submission`은 제공하지 않는다. 잘못된 UUID와 스키마 입력은 기존 `422` 검증을 따른다.
- 기록을 재사용할 때만 `replayed: true`다. 원래 성공 뒤 수정·삭제된 카테고리를 덮거나 재생성하지 않는다.
  처리 기록은 자동 만료시키지 않고 카테고리 삭제 후에도 유지한다. [회원 탈퇴](#회원-탈퇴)로 계정 행을 지우면
  `category_submissions`는 사용자 FK의 cascade로 함께 지워진다. 콘텐츠·이벤트·추천·카테고리처럼 cascade가 없는
  표는 탈퇴 처리가 순서대로 먼저 지운다.

`202610250015`는 기존 테이블을 바꾸지 않고 `category_submissions`를 추가한다. 신규 앱 배포 전에 migration과
이 서버 계약을 먼저 적용한다. 생성·수정 복구의 후속 목록 조회는 저장 트랜잭션과 별개다.
앱은 `GET /api/v1/categories`의 정상 배열·항목과 정상 빈 배열을 현재 목록으로 반영한다.
각 항목의 `content_count: int`, `last_saved_at: datetime | null`은 목록의 필수 요약 필드다.
빈 HTTP 본문·JSON null·잘못된 배열/항목을 빈 목록으로 보정하지 않으며 마지막 확인 목록을 유지한다.
저장 후 이 조회의 실패는 저장 성공을 바꾸지 않고 카테고리 GET만 재시도한다.

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

The root, health, OpenAPI, and authentication endpoints are public except for guest
social upgrades, share-credential issuance, and Apple challenges with `purpose=upgrade`.
User, content, category,
feed, upload, and metric endpoints require Bearer authentication.

Production must set `APP_ENVIRONMENT=production` and replace the example
`SECRET_KEY`; startup validation rejects the default production secret.

## Mobile Social Authentication

Google and Kakao sign-in use their Flutter SDKs on iOS and Android. Send the provider
**ID token** in `{ "token": "<id-token>" }` to
`POST /api/v1/auth/social/google` or `/kakao`. Access tokens are not accepted in place
of OIDC ID tokens. Successful responses are 200 with the same Clipback access/refresh
token fields as guest authentication, plus `is_new_user`.

An authenticated guest preserves the same user ID and saved data through
`POST /api/v1/auth/social/{provider}/upgrade`. A successful upgrade revokes every
previous guest session and returns a new token pair. A provider account already
linked elsewhere returns 409 and leaves the guest data and sessions intact. There
is no automatic account merge, email-based linking, or second-provider linking.
New Naver login and upgrade requests are rejected; historical Naver identities
remain readable and are not deleted by the migration.

Google requires `GOOGLE_CLIENT_IDS`, an allowlist of the audiences actually used by
the registered clients. Kakao requires OIDC enabled and `KAKAO_CLIENT_IDS`, an
allowlist of registered Native/REST app keys used by the clients. An SDK-issued
Kakao ID token uses that SDK's initialization key as its audience. A nonempty
`KAKAO_CLIENT_IDS` list is authoritative; when empty, `KAKAO_REST_API_KEY` remains
the legacy single-audience fallback. Neither provider's ID/access tokens are stored.
`KAKAO_ADMIN_KEY` is the server-only Kakao admin key used to unlink an account on
[회원 탈퇴](#회원-탈퇴). Production startup requires it; development and test start
without it and skip the unlink.

### Apple iOS authentication

Apple sign-in currently targets iOS only. Configure all of `APPLE_CLIENT_ID` (the
iOS bundle ID), `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (server-only
`.p8` PEM), and `APPLE_TOKEN_ENCRYPTION_KEY` (a dedicated Fernet key). Keep both
private keys out of the Flutter build and logs. Preserve the encryption key across
deployments and with protected backups; replacing it without re-encrypting existing
credentials makes them unreadable. Apple settings remain optional at app startup
so existing Google/Kakao deployments continue to start. Apple endpoints return
503 while required configuration is unavailable.

The current Flutter iOS app uses bundle ID `com.huturu.app`. Set `APPLE_CLIENT_ID`
to this value and use `APPLE_TEAM_ID` and a Sign in with Apple key for the team
that owns that App ID. Changing the Xcode project does not update deployed server
settings or Apple provisioning. Recheck these settings when switching from the
previous `com.clipback.app` identifier; keep the token encryption key unchanged.
The backend validates one configured Apple audience, so switching `APPLE_CLIENT_ID`
does not continue accepting Apple ID tokens issued for the previous bundle ID.

1. Call `POST /api/v1/auth/social/apple/challenge` with `{ "purpose": "login" }`,
   or `{ "purpose": "upgrade" }` and the guest Bearer token. The 201 response is
   `{ "challenge_id": "<uuid>", "nonce": "<random-value>", "expires_at": "<utc>" }`.
   Pass the returned nonce unchanged to the native Apple request. An upgrade
   challenge is bound to its guest; a login challenge cannot be used for upgrade.
2. Send the resulting credentials to `POST /api/v1/auth/social/apple`, or to
   `/api/v1/auth/social/apple/upgrade` with the guest Bearer token:

   ```json
   {
     "token": "<apple-identity-token>",
     "authorization_code": "<single-use-authorization-code>",
     "challenge_id": "<uuid>",
     "display_name": "Optional first-authorization name"
   }
   ```

The server checks the JWT signature, issuer, exact configured audience, expiry,
subject and nonce, exchanges the code with Apple, and requires the exchanged token's
subject and nonce to match. `display_name` is optional user-supplied profile text,
normalized only on initial signup/guest upgrade; subsequent login does not overwrite
the profile. Email comes only from verified token claims and can be absent or an
Apple private relay address. The identity key is `(apple, sub)`, never email.
SDK requests carry only an ID token, so `at_hash` is not checked on that input. Apple
server grants also supply an access token when available: it is used to verify any
`at_hash` claim and then discarded without storage. Authentication validation errors
return a generic 422 message without echoing request tokens, codes, or other input.

Challenges expire after five minutes and are consumed atomically **before** external
validation. A failed exchange or 409 therefore requires a new challenge and a fresh
Apple authorization; clients must not blindly resend the previous code. An incorrect
purpose/guest binding does not consume another attempt's challenge. Expired
challenges are removed when issuing a new one. Success responses use `no-store`.

Apple refresh tokens are encrypted in `apple_credentials` and never returned to
clients. They are separate from rotating Clipback refresh tokens. When an Apple
account calls `/api/v1/auth/refresh`, the server checks Apple only if the last successful
verification is at least 24 hours old. Concurrent refreshes serialize on the user
before session/credential locks. Confirmed invalid grants or mismatched subjects
revoke all Clipback sessions and clear the unusable provider token, returning 401.
Provider outages return 502; missing/mismatched configuration or unreadable encrypted
credentials return 503. These errors preserve existing credentials and do not log
the user out. A refresh response without a replacement Apple refresh token preserves
the old one; an initial code exchange without one fails without changing an account.

Ordinary logout revokes only the Clipback session. Apple connection removal/account
deletion, web/Android Apple callbacks and scheduled provider polling are outside
this implementation. The iOS client also handles credential revocation locally.

Apply migration `202610110013` before enabling Apple clients. It extends the provider
CHECK while retaining historical Naver values and adds challenge/credential tables.
Downgrade refuses to remove the schema when Apple identities exist; use a compatible
app/database backup for rollback. Automated tests replace providers; actual SDK
configuration, Apple entitlements, Google signing IDs, Kakao app keys and real-device
login/cancel/restart/revocation still require separate verification.

## Native Mobile Share Authentication and Retries

`POST /api/v1/auth/share-credential` requires an ordinary access Bearer token and
returns `200` with `Cache-Control: no-store`:

```json
{
  "share_token": "<share-only-jwt>",
  "expires_at": "2026-10-12T12:00:00Z",
  "user_id": 123,
  "session_id": 456
}
```

The JWT has `type=share`, `scope=share:write`, and the issuing user's parent session
ID. Its expiry never exceeds the issuing access token or parent session expiry.
There is no share refresh token. Only `POST /contents/share` and
`POST /uploads/screenshots` accept this credential; both also retain ordinary access
authentication. Reads, downloads, edits, deletes, refresh and credential issuance
remain access-only. Revoking or expiring the parent session invalidates its share
credentials. Ordinary refresh rotates the parent's token without changing its
session ID. Apple validation policy and main-app session storage remain unchanged.

Both save routes accept an optional `Idempotency-Key` UUID header. Persist the key
and input before the first send and reuse both after an uncertain response. A new
share action, even of the same URL, must have a new UUID. Requests without this
header keep existing behavior.

- Same user, key and input return `201` with the existing content. Different input
  or request kind returns `409`; replay after content deletion returns `410`.
- PostgreSQL transaction advisory locks serialize matching user/key requests before
  metadata, OCR or file writes. Different users cannot replay one another's receipt.
- The receipt, content, asset, creation event and YouTube summary job commit together
  inside the existing content service. Instagram links get their job the same way. Summary completion is not required to return
  a saved content response.
- Fingerprints use stable input fields and actual image bytes, not multipart
  boundaries, filenames, extracted metadata or AI output. A replay creates no new
  image file, OCR call, event or summary job.
- On a lost commit acknowledgement, screenshot cleanup checks the receipt using a
  fresh connection after reacquiring the transaction lock. If the commit cannot be
  verified, retain the file and report failure rather than delete a possibly
  committed asset. Retry the original key to learn the result.

Apply migration `202610120014` and the compatible API before releasing mobile share
clients. The `share_receipts` table keeps content IDs after content deletion to
prevent resurrection. Do not prune receipts while their keys can be retried.
Downgrade removes this guarantee, so stop share clients before reverting the schema.
No new production environment variable is required.

Instagram `/share/...` URLs resolve through the existing bounded, DNS-pinned
metadata client. Only a resolved supported Instagram post URL is saved. Login walls,
JavaScript-only redirects, unsafe targets and unresolved short links are rejected;
general website sharing and video attachments are not added.

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

`GET /api/v1/users/me/stats` uses the same authentication and returns lifetime event counts
plus the recent reopened content count:

```json
{
  "saved_count": 218,
  "reopened_count": 72,
  "recent_reopened_count": 9
}
```

- `saved_count` counts the current user's recorded `content_created` events.
- `reopened_count` counts their recorded `content_reopened` events, including repeat
  views of the same content. It can exceed the save count. It is kept unchanged for
  already released apps (0.5.2 and earlier); current apps do not read it
  ([ADR 0012](../adr/0012-my-stats-recent-reopened-count.md)).
- `recent_reopened_count` counts distinct contents among the current user's
  `content_reopened` events whose content still exists and whose event time is at or after
  the server's request time (UTC) minus 7×24 hours (the boundary counts). Repeat views of
  the same content count once, deleted contents drop out, and other accounts and event
  types never count. The window is fixed by the server; there is no request parameter.
- Deleting content preserves `saved_count` and `reopened_count`: its events remain with a
  null `content_id`.
- No recorded events returns `0` for both fields. Other event types do not count.
- Reading content detail does not record a view. A successful
  `POST /api/v1/contents/{id}/view` records one. Requests with the same client event
  ID count once; legacy requests without a body count on every call.
- Historical content without recorded events is not backfilled or estimated. There
  are no period, category, favorite, or pagination parameters.

The current app labels `saved_count` / `recent_reopened_count` as **저장한 콘텐츠 / 최근 다시 본
콘텐츠**. `saved_count` and `reopened_count` are event counts, not counts of distinct or
currently retained content. Reading either My Page endpoint does not create events.

Existing guest accounts and authentication endpoints remain supported. Social-only
sign-up is a separate follow-up; this change does not remove guest data or require a
migration.

## 회원 탈퇴

`DELETE /api/v1/users/me`는 기존 Bearer 인증을 쓰고 본문으로 고른 탈퇴 사유 목록을 받는다.

```json
{"reasons": ["low_usage", "other"]}
```

- 사유 값은 `rejoin`(재가입), `low_usage`(이용 빈도 및 기대감이 낮음), `privacy_security`(개인정보보호 및 보안),
  `other`(기타)다. 1개 이상, 같은 값은 한 번만 보낸다. 값은 정확히 같을 때만 받으며 공백 정리·대소문자 변환을 하지 않는다.
- 성공은 `204`, 본문 없음이다. 계정·콘텐츠·이벤트·추천 기록·계정 소유 카테고리·태그·세션·소셜 연결을 그 자리에서 지운다.
  공용 카테고리("미분류"·템플릿)는 남는다. 다른 기기의 세션은 기존처럼 다음 요청에서 `401`이다.
- 처리 순서는 공급자 연결 정리 → 삭제 장부에 계정 탈퇴 기록 하나 → DB 삭제와 탈퇴 사유 기록을 한 트랜잭션 → 커밋 뒤 Bucket 원본 삭제다.
- 공급자 연결 정리: Apple 계정은 저장된 refresh token으로 Apple 토큰 철회(`POST https://appleid.apple.com/auth/revoke`,
  `token_type_hint=refresh_token`)를, 카카오 계정은 `KAKAO_ADMIN_KEY`와 카카오 회원번호로 연결 끊기(`POST https://kapi.kakao.com/v1/user/unlink`,
  `target_id_type=user_id`)를 시도한다. Google은 앱이 기기에서 연결 해제하고, 네이버 연결은 철회 없이 지운다.
  Apple 토큰이 이미 비어 있으면 철회하지 않고, 개발·테스트에서 어드민 키가 없으면 연결 끊기를 건너뛴다.
  시간 초과·공급자 오류·설정 없음·토큰 복호화 실패가 나도 삭제는 끝까지 하고(ADR 0007), 실패는 서버 경고 로그
  `Provider revocation failed: provider=… reason=timeout|provider_error|not_configured|token_unreadable operation_id=…`로 남는다.
  로그에는 토큰 값·어드민 키·계정 번호·이메일이 없다. 운영자는 작업 ID로 장부의 계정 탈퇴 기록을 찾는다.
  공급자 연결을 끊은 뒤 DB 삭제가 실패해도 연결을 되돌리지 않는다(D30).
  장부·기록 형식과 운영자 재시도는 [이미지 삭제 운영](image-deletion.md)을 따른다(ADR 0007·0008).
- 탈퇴 사유 기록(`account_deletion_reasons`)에는 고른 사유 목록과 한국 표준시(Asia/Seoul) 탈퇴 날짜만 있다.
  계정 번호·이메일·이름은 없고 보관 기한이 없다. 탈퇴가 실패하면 사유 기록도 남지 않는다.

| 상황 | 응답 | 계정·데이터 |
| --- | --- | --- |
| 삭제 성공 | `204` | 모두 삭제 |
| Apple 철회·카카오 연결 끊기 실패(시간 초과·공급자 오류·설정 없음·토큰 복호화 실패) | `204` | 모두 삭제, 실패는 서버 로그 |
| DB 삭제 뒤 Bucket 원본 삭제 실패 | `204` | DB는 삭제, 원본은 삭제 작업 목록에 미완료로 남아 운영자 재시도가 지움 |
| 본문 없음·JSON 아님·목록 없음·빈 목록·허용 밖 값·타입 오류·중복 | `422` | 변화 없음 |
| 세션 없음·만료·이미 삭제된 계정 | `401` | 변화 없음 |
| 삭제 장부 기록 실패 | `503` | 계정 그대로 |
| DB 삭제 실패와 그 밖의 오류 | `5xx` | 계정 그대로. 이미 쓴 장부 기록은 확정된 탈퇴 요청으로 남아 다시 요청하면 같은 기록을 쓰고, 운영자 재시도·복원 때 지운다 |
| 서비스 점검 중 | `503` `service_maintenance` | 변화 없음 |

오류가 겹치면 점검 `503` → JSON으로 읽히지 않는 본문 `422` → 인증 `401` → 본문 검증 `422` → 처리 중 오류 순서로 하나만 돌려준다.
같은 계정의 요청이 겹치면 계정 단위 잠금(PostgreSQL advisory lock)으로 차례를 세운다. 이 잠금은 공급자 연결 정리보다 먼저 잡으므로
뒤 요청은 앞 요청이 끝날 때까지 공급자 요청을 보내지 않고, 끝난 뒤 계정을 다시 확인한다. 그다음 기존 순서(장부 → 계정)대로 잠근다.
이 잠금은 탈퇴 요청(같은 처리를 쓰는 운영자 계정 삭제 포함)만 쓰므로 운영자 재시도와 교착이 없고, 공급자 요청 중에도 다른 계정의 삭제는 막지 않는다.
앞 요청이 성공했으면 `401`, 장부 기록에서 실패했으면 처음부터 다시 처리하고, 장부 기록 뒤 DB에서 실패했으면 같은 장부 기록을 다시 쓴다.

앱은 사유 목록을 보내고 `204`만 성공으로 본다. `401`은 기존 세션 갱신·만료 처리를 따르며, 그 밖의 응답·연결 실패는 실패다.
로그인 갱신과 재전송을 포함한 제출 전체를 60초에서 끊고 늦은 응답은 버린다. 다른 요청의 대기 정책은 그대로다.
0.4.0 앱은 이 요청을 보내지 않는다. 서버를 먼저 배포한 뒤 앱을 배포한다.

## Content View Events

`POST /api/v1/contents/{id}/view` requires Bearer authentication and accepts an
optional JSON body:

```json
{
  "client_event_id": "550e8400-e29b-41d4-a716-446655440000",
  "recommendation_item_id": 123
}
```

- A supplied object requires a UUID `client_event_id`; `recommendation_item_id`
  is an optional JSON integer from 1 to 2,147,483,647. Empty objects, invalid values, and unknown
  fields return `422`. No body or JSON `null` keeps the legacy behavior.
- Use a new UUID for each real detail entry and reuse it for retries of that entry.
  The same user, UUID, content, and recommendation item return the same `201`
  response without changing the event, snapshot, count, or timestamp. Reusing the
  UUID with different request content returns `409`. Different users may reuse a UUID.
- The response remains `{"content_id": 123, "event_type": "content_reopened"}`.
  Deleted or unowned content returns `404`, including retries.
- New views atomically record all current category IDs, increment `open_count`,
  and set `last_viewed_at` to the event's UTC timestamp. Legacy calls also collect
  these values, but cannot distinguish retries from new entries.
- Recommendation items must belong to the caller's batch and reference an owned
  live target: a Today content item must match the content; a Weekly category item
  must match one of its current categories. Missing, inaccessible, or deleted
  targets return `404`; type or target mismatches return `422`. No previous
  exposure is required, and batch dates do not expire referrals. Successful retries
  do not revalidate changed/deleted categories while the content still exists.
- Views never record recommendation exposures or update recommendation counters.
  Weekly generation and exposure collection use the separate recommendation endpoints below.

All save routes also record sorted, unique category IDs from the final saved
content, including the actual `미분류` ID when assigned. Later classification or
deletion preserves this snapshot. Historical `NULL` means unknown; `[]` means no
categories at collection. Save-request deduplication is not implemented.

## Today Recommendations

`GET /api/v1/recommendations/today` requires Bearer authentication. Successful
requests return `200` with `Cache-Control: no-store`. The user, KST date, and maximum
of five items are determined by the server; there is no refresh or date override.

```json
{
  "stage": 0,
  "recommendation_date": "2026-09-24",
  "batch_id": null,
  "generated_at": null,
  "items": []
}
```

Each item contains `recommendation_item_id`, its original `rank`, and `content`
using the existing `ContentRead` response. Scores are stored internally. Use the
item ID as `recommendation_item_id` in a detail-entry view request.

- Stage is based on current owned content rows: 0–4 gives Stage 0 (hidden), 5–9
  Stage 1 (priority ordering), and 10+ Stage 2 (weighted sampling). Summary status
  does not exclude saved content, and multiple categories do not multiply counts.
- Stage 1 prefers content without an actual exposure yesterday in KST, then
  never-viewed content, the oldest last view, and the most recent save. Exact ties
  are random; yesterday-exposed content fills remaining slots. No time exclusion
  or category cap applies at Stage 1.
- Stage 2 applies the agreed view/save/exposure filters, scores, top candidate pool,
  and weighted sampling without replacement. It first allows at most two per
  category, including uncategorized, then relaxes that cap within the same pool.
  The draw order is stored as rank. See the
  [recommendation plan](../content-recommendation-plan.md) for exact thresholds.
- The first nonempty result is fixed for that KST date. Zero initial candidates
  leave `batch_id` null and are reevaluated next time. Once created, the batch,
  item IDs, ranks, scores, and generation timestamp remain fixed.
- Deleted items are omitted without replacement or renumbering. Even if all items
  are deleted, the existing batch metadata remains. Views, favorites, and category
  changes update card details without reselection. Stage 0 returns empty items
  while retaining any existing batch metadata; returning to five contents that
  day reuses that batch. Stage 1/2 transitions also preserve the current batch.
- First generation serializes per user, locks candidate content while reading its
  categories, and stores batch and items atomically. After waiting for content
  locks, it checks the KST date again. Concurrent new saves affect later requests'
  current Stage, but do not refill an already-fixed result.
- This GET may create the daily batch. It does not record views or exposures and
  does not update their counters. Record actual card displays with the exposure POST.

## Weekly Recommendations

`GET /api/v1/recommendations/weekly` requires Bearer authentication and returns
`200` with `Cache-Control: no-store`. Weekly is independent of Today Stage: even
one saved content can make its owned category eligible. User, period, and the
maximum of two cards are server-controlled.

```json
{
  "period_start": "2026-09-18T15:00:00Z",
  "period_end": "2026-09-25T06:00:00Z",
  "batch_id": null,
  "generated_at": null,
  "items": []
}
```

The half-open period starts at KST midnight six dates before today and ends at
server UTC time captured after content locking. It is neither the last 168 hours
nor a Monday-based week. Each item contains `recommendation_item_id`, `rank`,
`card_type`, and `category` in the existing `CategorySummaryRead` format
(`id`, `name`, `color`, `is_default`, `content_count`, `last_saved_at`). The category
count and last save describe current holdings, not period activity. Scores,
activity counts, and ready-made copy are not returned.

- Every GET reevaluates current data and creates a new `WEEKLY_PICK` batch with
  a null recommendation date when at least one card is selected. `generated_at`
  equals `period_end`. Empty results create no batch. Retrying GET can produce
  new cards and IDs; previous batches and their referral/exposure IDs are retained.
- Eligible categories are owned, not uncategorized, and contain current owned
  content. Summary-job status does not exclude content. Deleted content's activity
  is excluded; currently empty or deleted categories cannot become cards.
- Saves count `content_created` event rows; views count distinct content IDs per
  category. Both use `category_ids_at_event` only, including multiple categories
  once each. NULL/empty arrays have no category activity; later classification
  never reassigns past events. Repeated views can update the last activity time.
- Choose one `MOST_SAVED`, then one `MOST_VIEWED` from remaining categories.
  Each ranking uses activity count, latest event time, current content count,
  then random choice among exact ties. Actual behavior cards precede fallback;
  view-only activity gives `MOST_VIEWED` rank 1.
- Fill remaining places with distinct `REDISCOVERY` categories. Prefer those
  without a category-card exposure in the same period, uniformly at random.
  Otherwise prefer the oldest per-category **last** exposure; exact ties are
  random. Content exposures and generated batches are not category exposures.
- User `FOR NO KEY UPDATE`, then content IDs in ascending `FOR SHARE` order keep
  current holdings and historical aggregation consistent. All content aggregates
  use the captured IDs. Saves committed after this capture enter the next request.
  Empty responses also commit; failures roll back the whole new batch and items.
- GET does not change events, counters, or saved/viewed totals. Use returned item
  IDs for exposure POST and view POST of a currently matching category member.
  The frontend must retain item IDs within a home visit and reuse them for exposure
  retries; it must not fetch a replacement Weekly batch for the same retry.

Frontend integration remains stage 6. This change adds no migration or deployment.

Local validation on 2026-09-25 used Python 3.12.7 and isolated PostgreSQL 17.7:
**857 tests passed**, with no PostgreSQL skips (70 new: 31 selection, 20 API and
aggregation, 19 independent-connection concurrency cases). Concurrency tests
observe real lock waits, including classification/deletion/view/exposure ordering,
new saves excluded until the next request, midnight rollover, and rollback recovery.
The full suite ran in its own database; a separate empty database passed
`alembic upgrade head` and `alembic check`. Ruff, compileall, and `git diff --check`
passed. External AI/OCR/metadata were replaced and the YouTube worker disabled.
One existing Starlette/httpx deprecation warning remains. Remote CI, Docker,
frontend/device behavior, and production deployment were not validated in this run.

## Recommendation Exposures

`POST /api/v1/recommendations/exposures` requires Bearer authentication and one
card per request. Send a new UUID for each card displayed on a new home visit;
reuse that UUID for rerenders and retries within the same visit. Frontend display
tracking is not connected yet (stage 6).

```json
{
  "client_event_id": "550e8400-e29b-41d4-a716-446655440000",
  "recommendation_item_id": 123
}
```

Both fields are required. The item ID must be a JSON integer from 1 through
2,147,483,647; strings, booleans, fractions, missing/null bodies, and extra fields
return `422`. User, target, surface, rank, score, and timestamp come from the server.

New events and identical retries return `201` with `Cache-Control: no-store`:

```json
{
  "exposure_id": 456,
  "client_event_id": "550e8400-e29b-41d4-a716-446655440000",
  "recommendation_item_id": 123,
  "recommended_at": "2026-09-24T06:00:00Z"
}
```

- The server validates the owned batch and live target: Today content or Weekly
  category only. Missing, inaccessible, or deleted targets return `404`; an
  accessible item with an invalid type combination returns `422`. Old batches,
  current Stage 0, and still-owned empty categories remain valid.
- The same user/UUID/item returns the original response without recounting, even
  after target deletion. Reusing the UUID for another item returns `409` before
  target validation. Different users may reuse UUIDs. View and exposure UUIDs
  have independent namespaces; neither event requires the other first.
- `recommended_at` is server UTC time captured after target locking. Delayed
  requests count when processed, not at a client-provided display time.
- A new content exposure increments `recommendation_count` and sets
  `last_recommended_at` and `last_recommended_surface` in the same transaction.
  Category exposures only create history and never mark member content exposed.
  Views, saved/viewed totals, and existing daily recommendation items are unchanged.
- Same-user requests serialize with `FOR NO KEY UPDATE`, then lock the actual
  content for update or category for key share. UUID uniqueness and atomic commit
  prevent double counting; failures roll back the event and aggregate together.
- Weekly category collection accepts the item IDs returned by the Weekly GET.
  No new migration, frontend integration, or deployment is included.

Local verification on 2026-09-24: Python 3.12.7 / PostgreSQL 17.7, **787 tests
passed**, including 70 new exposure tests and independent-connection lock checks.
Ruff, compileall, empty-database upgrade, Alembic check, and Git diff checks passed.
The existing Starlette/httpx deprecation warning remains. Remote CI, Docker,
production deployment, and actual frontend visibility tracking were not tested.

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

## Content Category Validation

Direct saves (`POST /api/v1/contents`), shared saves (`POST /api/v1/contents/share`),
screenshot uploads (`POST /api/v1/uploads/screenshots`), and category updates
(`PUT /api/v1/contents/{content_id}/categories`) use the same category combination rule.
After duplicate IDs are removed and category access is checked, combining the shared
`미분류` category with any other category returns `422` with
`{"detail": "Uncategorized category cannot be combined with other categories"}`.
Missing or inaccessible category IDs return `404` before the combination check.

Selecting `미분류` alone (including repeated copies of its ID) or multiple available
ordinary categories remains valid. Empty selections retain the existing automatic
classification/fallback behavior for saves and `미분류` assignment for updates.
Rejected saves create no content, tags, events, asset rows, or summary jobs. Rejected
updates preserve existing categories, events, and the summary job's `apply_category` flag.
Metadata extraction and OCR keep their existing order; an uploaded screenshot file is
removed through the existing compensation path when category validation rejects the save.
No request/response fields or database migration are added.

## Content URL Length

`POST /api/v1/contents` accepts HTTP(S) URLs up to 2,048 characters in
`original_url`. The limit applies to the serialized URL after URL encoding and
normalization, matching `contents.original_url VARCHAR(2048)`. For example, a
short Korean path can exceed the limit after percent encoding. OpenAPI exposes
`maxLength: 2048`; oversized input returns `422` before metadata extraction.

Instagram host/path normalization and metadata redirect results are checked too.
A final URL longer than 2,048 characters returns `422` without creating content,
tags, events, or a summary job, and without calling category recommendation. URLs
are never truncated or replaced with the original short redirect URL. Metadata
extraction failure does not bypass URL validation.

`POST /api/v1/contents/share` keeps the existing limits: `url` accepts up to 2,048
characters and `raw_text` up to 5,000. A URL extracted from `raw_text` is checked
after Instagram/YouTube normalization, so a long tracking query can still be
accepted when the normalized URL fits. Shared `url` input remains subject to its
input limit even if normalization could shorten it. Screenshots may still omit
`original_url`. No database migration or response shape change is required.

Local verification on 2026-09-22: 540 tests passed on Python 3.12 with PostgreSQL
17 (34 added); Ruff, compileall, and empty-database `alembic upgrade head` /
`alembic check` passed. The existing Starlette/httpx deprecation warning remains.
The API regression reproduced a `500` for a 2,050-character URL before the fix.
External metadata was stubbed; live sites, Railway, real devices, and the local
Docker deployment check were not exercised. Remote CI results are reported on
the PR separately.

## Tag Replacement

`PUT /api/v1/contents/{id}/tags` accepts `{ "tag_names": [...] }` and replaces the
content's entire tag set. Existing tag normalization and deduplication still apply.
An empty list clears all tag links while preserving reusable tag records. Missing
and other users' content both return `404`.

Concurrent replacements for the same content are serialized using a PostgreSQL
row lock acquired before reading its current tags. The last successful transaction
in lock acquisition order determines the final set, without merging concurrent
requests. Each success response contains that request's applied tag set even if a
later writer finishes before the response is returned.

An unchanged tag set skips relationship updates but still ends the transaction and
releases its lock. Failures roll back both tag creation and relationship changes.
The lock is per content, not per user; other content can be edited independently.
No version field, conflict response, or database migration is required.

## Feed Pagination

`GET /api/v1/feed` returns the authenticated user's content in `saved_at DESC, id DESC`
order by default (`sort=latest`). `sort=favorites_first` puts favorites first, then uses
`saved_at DESC, id DESC` within each segment. Other sort values (including empty) return
request validation `422`. Optional `q` (title, summary, and tags), `category_id`, and `is_favorite` filters
combine with pagination. `limit` defaults to 20 and accepts 1–100.

- `total_count` counts the same user/category/favorite/search filters before cursor and limit, independently of sort.
  It is recalculated on every page; whitespace-only search has no filter. Missing or foreign
  categories return zero. Multiple category membership does not duplicate a content.
  This additive field preserves old app compatibility; no schema or index migration is required.
- The response is `{ "items": [...], "next_cursor": "...", "total_count": 25 }`. `next_cursor` is
  `null` when there is no next page.
- Pass the returned cursor unchanged in the next request's `cursor` query parameter.
  Latest cursors keep the existing `v1.` format followed by unpadded URL-safe Base64 JSON containing `saved_at`
  and `id`. The timestamp uses UTC and preserves microseconds. Clients must treat this
  value as opaque rather than deriving a cursor from an item ID.
  Favorites-first cursors use `f1.` with the same fields plus a boolean `is_favorite`.
  A cursor from a different sort, or a numeric cursor with favorites-first, returns
  `422 {"detail":"Invalid feed cursor"}`.
- The next page uses all keys of the selected sort, so ID allocation order does not cause missing or
  repeated items. A new cursor continues to work after its anchor content is deleted.
  Newly saved content before the cursor is visible on refresh; pagination does not
  hold a database snapshot across requests.
- Existing numeric ID cursors are still accepted when the anchor content belongs to
  the current user and still exists, for latest sort only. Only its saved time and ID are looked up; changes
  to its categories, favorites, or text do not invalidate the anchor. Responses always
  emit the new format when another page exists.
- Malformed or unsupported cursors, invalid field types, timezone-less timestamps,
  IDs outside `1..2147483647`, and cursors longer than 512 characters return `422`.
  Missing, deleted, and other users' numeric anchors return the same `422` error.
  Clear the cursor and reload the first page after an invalid cursor response.
- Reset the cursor whenever the account, sort, or search/category/favorite filters change.
  Every page enforces the authenticated user's ownership filter.

Old apps may continue their `is_favorite=true` then `false` requests without `sort`.
Deploy the server first. An old server ignores the new sort and returns latest order.
Changing favorites while paging can move items across the cursor; write success reloads
from page one. No database migration is required.

## Screenshot Storage

Original deletion uses the existing content DELETE endpoint. It confirms an independent
deletion receipt before committing the DB removal and a durable physical-cleanup job.
Missing/unavailable receipts reject deletion with 503; repeated missing content remains 404.
See [deletion, retry and recovery contracts](image-deletion.md) for partial failures,
failed-upload cleanup, and the limits of already-issued signed URLs.

`POST /api/v1/uploads/screenshots` accepts one PNG, JPEG, or WebP image up to
10MiB as multipart form data and returns the saved content with its asset metadata.
The original bytes are preserved without resizing or recompression. `STORAGE_BACKEND`
selects `local` (default, rooted at `STORAGE_ROOT`) or a private S3-compatible Bucket
for new uploads. Each asset records its own storage backend, actual byte length and
SHA-256; pre-existing assets remain `local` with nullable integrity metadata until
an explicit migration fills it. Changing the writer never changes old asset locations.
Original images share one byte quota per server user ID across the main app and
both native share extensions: guests have 30MiB (31,457,280 bytes), connected
accounts 300MiB (314,572,800 bytes). Exact equality is accepted. Completed
idempotent shares replay before checking the quota; new saves check it before
OCR and keep the same user's database lock through commit/rollback. Missing
legacy size metadata is resolved from its original store; unverifiable sizes
reject a new save with 503 rather than count as zero. Deleted content leaves
the live sum immediately after deletion commits; cache and backup bytes do not
count. Promotion preserves the user ID and existing bytes while raising the
limit. Existing over-quota images remain readable and deletable.

Quota rejection is HTTP409 with `detail.code=image_quota_exceeded` and
`detail.limit_bytes`. One file exceeding the configured 10MiB limit is HTTP413
with `detail.code=image_file_too_large` and `detail.limit_bytes`. Clients inspect
the error code before treating every 409 as an idempotency conflict.
OpenAI OCR extracts text, title, and summary and feeds category recommendation.
New screenshot summaries are instructed to use concise Korean informational prose
with noun-ending sentences (for example, `성수동 카페 소개. 대표 메뉴와 영업시간 안내.`),
without greetings, promotional language, or conversational endings. Facts must come
from the image. This prompt applies to new uploads; existing saved summaries and
descriptions extracted from links are unchanged. Actual model adherence requires
checking real screenshot responses; mocked tests cannot verify writing quality.
OCR failure preserves image saving with fallback content; valid manual category
selection remains authoritative. Keep the existing `/data` volume mounted while
local assets remain. S3 configuration and rollout checks are described in the
[Railway deployment guide](../railway-deployment.md#bucket-원본-보관).

`GET /api/v1/uploads/assets/{id}/access` is Bearer-authenticated and checks the
current owner's access before checking the actual file. It returns `asset_id`,
`mode` (`proxy` or `direct`), `url`, nullable `expires_at`, `mime_type`, `size_bytes`
and the original's hexadecimal `sha256`, with `Cache-Control: private, no-store`.
Local assets use the existing relative authenticated asset URL and no expiry.
The relative URL follows the configured `API_V1_PREFIX`, just like the upload
and binary routes (for example, `/api/v9/uploads/assets/{id}`).
Bucket assets use a GET URL signed for 120 seconds with the asset MIME override;
Bucket credentials are never sent to the app. A signed URL is itself a temporary
access credential: do not persist it or log its query string. Logout does not
revoke already-issued URLs, whose remaining request-start validity is at most
120 seconds. Expiry does not interrupt a transfer already accepted by the store.
Unknown legacy integrity metadata is calculated from actual original bytes for
this response; it is not treated as zero and does not change asset location.
Unauthenticated requests return 401; foreign, deleted or missing originals return
404; unavailable storage returns a generic 503. The app uses a separate client
without Clipback authorization or cookies for Bucket GETs, rejects redirects,
checks bounded length/MIME/SHA-256 before use, and reacquires access once after a
Bucket 403. Bucket errors do not trigger app token refresh or session invalidation.

Saved images are private. Use the Bearer-authenticated asset URL returned in
`ContentRead.assets` to download an image. The existing URL, response shape and
Bearer authentication are retained for both local and Bucket assets, so older
apps continue to work. Bucket credentials are never returned; the signed URL contains
the object path, so it must be treated as temporary access information.
A missing or foreign asset returns 404; a Bucket outage during upload or read
returns 503 with a generic error. The DB commit remains authoritative for cleanup:
failed writes do not produce a successful content response, rollback cleans the
new file, and an uncertain acknowledged commit never deletes a committed original.
Normal content deletion removes the file from the asset's recorded backend;
durable delete retries and backup deletion rules are separate rollout work.

<a id="9-api프론트-연결-계약"></a>

## 추천 API 연결 계약

Today 조회는 3단계, 노출 POST는 4단계, Weekly 조회는 5단계에서 구현했으며,
기존 view POST의 이벤트 ID·추천 유입 확장은 2단계에서 구현했다.

| 구분 | API | 계약 |
| --- | --- | --- |
| 신규 | `GET /api/v1/recommendations/today` | 현재 Stage, 기준 날짜, 배치 ID, 순서가 있는 콘텐츠 목록. 미생성 빈 결과와 기존 배치의 빈 결과를 구별 |
| 신규 | `GET /api/v1/recommendations/weekly` | 카드 유형, 카테고리 정보, 추천 결과 식별정보. 0~2개 |
| 신규 | `POST /api/v1/recommendations/exposures` | 필수 UUID와 추천 항목 ID로 노출 기록, 재시도 중복 방지 |
| 확장 | `POST /api/v1/contents/{id}/view` | 상세 진입 이벤트 ID와 선택적 추천 유입 정보 수신 |

Today 성공 응답은 200과 `Cache-Control: no-store`를 사용한다. 응답은 현재 `stage`,
KST `recommendation_date`, nullable `batch_id`·`generated_at`, 최대 5개의 `items`다.
각 항목은 `recommendation_item_id`, 최초 `rank`, 기존 `ContentRead` 형식의 최신 `content`를
포함하며 점수는 공개하지 않는다. 삭제 후 남은 순위는 다시 매기지 않는다.

Weekly 성공 응답은 200·`Cache-Control: no-store`와 UTC `period_start`·`period_end`,
nullable `batch_id`·`generated_at`, 최대 두 개 `items`다. 항목은 `recommendation_item_id`,
`rank`, `card_type`, 기존 `CategorySummaryRead` 형식의 `category`다. 카테고리의
`content_count`·`last_saved_at`은 현재 보유 콘텐츠 기준이며 기간 내 행동 수와 다르다.
문구·행동 건수·점수는 공개하지 않는다. 배치가 있으면 `generated_at=period_end`다.
GET 재시도도 새 배치를 만들 수 있으므로 같은 홈 방문에서는 기존 항목 ID를 보관하고,
노출 재전송을 위해 Weekly를 다시 조회하지 않는다.

노출 POST에는 `client_event_id` UUID와 `recommendation_item_id` JSON 정수(1~2,147,483,647)가
필수다. 본문 없음·`null`·빈 객체·잘못된 값·미정의 필드는 422다. 인증된 사용자와 실제
항목→배치에서 대상·추천 위치·순위·점수를 결정하며 클라이언트 시각이나 대상 ID를 받지 않는다.
신규·재시도 모두 201·`Cache-Control: no-store`와
`{exposure_id, client_event_id, recommendation_item_id, recommended_at}`을 반환한다.

같은 사용자·UUID·항목은 최초 응답을 반환하고 다른 항목에 UUID를 재사용하면 대상 검증보다
먼저 409다. UUID는 사용자별·이벤트 테이블별로 독립적이다. 신규 노출은 본인 배치·실제 대상의
소유권을 확인하고 Today 콘텐츠/Weekly 카테고리 조합만 허용한다. 접근 불가·삭제는 404,
접근 가능한 항목의 유형 불일치는 422다. 배치 날짜·현재 Stage·빈 카테고리 여부로 만료시키지 않는다.
열람과 노출은 서로 선행 조건이 없으며 기존 당일 선정 결과를 변경하지 않는다.

사용자는 인증에서 결정한다. 대상 소유권과 추천 결과·대상의 일치를 서버에서 검증한다.
추천 점수·순위는 클라이언트가 임의 제출한 값을 신뢰하지 않는다.
view POST의 동일 이벤트 재시도는 기존 201 및 `{content_id, event_type}`을 반환하고,
다른 콘텐츠·추천 항목·이벤트 유형에 같은 사용자·UUID를 재사용하면 409로 거절한다.

view POST는 본문 없음 또는 JSON `null`을 계속 허용하며 매번 새 열람으로 기록한다.
본문 객체에는 `client_event_id` UUID가 필수이고 `recommendation_item_id`는 1~2,147,483,647 범위의 선택적 JSON 정수다.
빈 객체·잘못된 값·미정의 필드는 422다. 새 프론트는 새 상세 진입마다 새 UUID를 발급하고
재시도에는 동일 UUID를 사용해야 한다. 기존 이벤트 ID 없는 호출의 재시도 중복 방지는 보장하지 않는다.

신규 추천 유입은 본인 배치·실제 대상의 소유권을 검증한다. Today 콘텐츠는 열람 대상과 일치하고,
Weekly 카테고리는 현재 소속이어야 한다. 접근 불가·삭제 대상은 404, 유형·대상 불일치는 422다.
노출 기록이나 배치 만료 조건은 요구하지 않는다. 동일 요청 재시도는 이후 분류 변경·삭제가 있어도
다시 검증하지 않지만, 콘텐츠가 삭제됐거나 본인 소유가 아니면 재시도도 404다.

클라이언트의 조회·노출·재전송 동작은 [추천 프론트 연결 계약](../frontend/behavior.md#추천-프론트-연결-계약)을 따릅니다.


## 본앱 사진 수동 재시도

`POST /api/v1/uploads/screenshots`의 선택적 `Idempotency-Key`(UUID)는 계정별 제출을 식별한다.
같은 키·사진 바이트·분류·태그는 기존 콘텐츠를 반환하며 처리 중인 요청은 트랜잭션 잠금으로 직렬화한다.
파일명은 입력 지문에 포함하지 않는다. 다른 입력은 409, 저장했던 콘텐츠 삭제 후 재시도는 410이며 새 콘텐츠로 우회하지 않는다.
본앱은 같은 저장 화면의 사진 수동 재시도와 인증 갱신에 이 키를 전달한다. 키 없는 0.4.0 요청은 기존처럼 별도 저장한다.
서버 요청·응답 계약과 DB 스키마는 이번 변경에서 바꾸지 않았다. 앱은 손상되거나 필수 필드가 누락된 성공 응답도 저장 결과로 표시하지 않는다.

## 본앱 링크 수동 재시도

`POST /api/v1/contents`도 선택적 `Idempotency-Key`(UUID)를 받아 같은 공유 영수증(`share_receipts`, 종류 `content`)으로 처리한다.
같은 계정·키·요청 본문은 기존 콘텐츠를 201로 반환하며 메타데이터 추출·AI 추천·생성 이벤트·요약 작업을 새로 만들지 않는다.
처리 중인 요청은 트랜잭션 잠금으로 직렬화한다. 다른 본문이나 다른 요청 종류(`/contents/share`·사진 업로드)에 쓴 키는 409,
저장했던 콘텐츠 삭제 뒤 재시도는 410이다. 다른 계정의 같은 키는 서로 영향이 없다.
키 없는 요청(배포된 앱 0.4.x·0.5.0)은 지금처럼 매번 새 콘텐츠를 만든다. 응답 형식과 DB 스키마는 바꾸지 않았다.
본앱은 같은 저장 화면의 같은 링크 재저장과 인증 갱신에 같은 키를 보낸다. 서버를 먼저 배포한다.
