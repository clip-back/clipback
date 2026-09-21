# Clipback Frontend

Flutter mobile frontend for the Clipback MVP.

As of 2026-09-21, the local `lib/main.dart` implements screens with mock data and
in-memory state. Login, content saving, account statistics, and settings shown in
these screens are not evidence of backend integration. Real API and device flows
remain to be verified; work in other checkouts is not covered here.

The current implementation mirrors the supplied Figma flows:

- Onboarding
- Login entry
- Home
- Search
- Archive list
- Category archive
- Bookmark list
- Content detail

Figma-exported SVG assets are registered under `assets/figma/` and `assets/icons/`.
Large exported illustration SVGs include embedded raster data, so matching PNG fallbacks are generated in `assets/figma/` for reliable Flutter rendering.

Run locally with Flutter installed:

```bash
cd frontend
flutter pub get
flutter run
```

## Backend integration boundaries

Use the backend public HTTPS domain and `/api/v1` exactly once in request URLs.
Protected APIs require the backend-issued Bearer access token. Account data and
statistics should come from `/users/me` and `/users/me/stats`; display statistics as
누적 저장 / 누적 열람, not current content totals.

The existing similar-content section filters already-loaded items by category;
today's content opens the first local item. Neither is a server recommendation.
The feed has no total-count field. Reminder and notification screens use mock data.
See [MVP scope decisions](../docs/backend-mvp-plan.md) before adding APIs for these.

For public URL and web CORS configuration, follow the
[deployment guide](../docs/railway-deployment.md).
