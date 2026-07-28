# Debug Session: superadmin-icon-bug
- **Status**: [OPEN]
- **Issue**: Superadmin badge on profile renders as the white default shield instead of the icon uploaded via admin /admin/icon-settings and stored in app_settings.super_admin_icon_url.
- **Debug Server (collector, fallback)**: http://85.230.36.174:7777/event
- **Primary Evidence Channel**: Flutter runtime `debugPrint` lines prefixed `[DEBUG]` directly in flutter run console.
- **Log File (collector only)**: /tmp/superadmin-icon-bug/trae-debug-log-superadmin-icon-bug.ndjson

## Reproduction Steps
1. Login in the app with the superadmin user (email matches DEFAULT_SUPERADMIN_EMAILS in lib/auth.ts backend).
2. Open the creator profile tab.
3. Observe the superadmin badge next to the user handle.
4. Expected: icon uploaded via /admin/icon-settings, pixel-identical to file preview in admin.
5. Actual: a generic white shield icon (`Icons.shield_rounded`).
6. If visible, press either the top-right refresh button (profile app bar) or the inline "Force reload badge" button in the profile body debug block.

## Hypotheses & Verification
| ID | Hypothesis | Likelihood | Effort | Evidence |
|----|------------|------------|--------|----------|
| A | Backend does not attach stored superadmin icon URL to /auth/me or /users/:id payloads | Medium | Low | Pending — captured in debugPrint A:fetchMe and A:fetchUserProfile |
| B | App receives correct URL but Image.network fails / never finishes / never reaches frameBuilder | High | Low | Pending — captured in debugPrint B + on-device debug panel (imageStatus, resolved url) |
| C | URL normalization / URL shape mismatch (relative /uploads vs https://sawrly.com) prevents the image from loading, falls back to white shield | Medium | Low | Pending — captured in debugPrint C:buildSuperadminBadge raw/normalized/imageUrl |
| D | App renders stale cached profile and never re-fetches after build deployment (cached token-user, cached image) | Medium | Low | Pending — new inline "Force reload badge" + cache-buster query t=<_badgeReloadTick> + bypassCache for /users/:id |
| E | The PNG file stored at /api/uploads/badges/<uuid>.png has wrong MIME or fails CORS/imageCodec on Android | Low | Medium | Pending — step 1: confirm B status=error; then curl the resolved URL |

## Backend Evidence (live, collected 2026-07-28 UTC)
- `/api/config/public` returns `superAdminIconUrl = "/api/uploads/badges/65ed8c7e-92c1-4225-a63d-7f43f22ac443.png"`
- DB `app_settings.super_admin_icon_url` matches exactly the public config URL above.
- Icon page save path: `app_settings` key `super_admin_icon_url`.
- Backend badge helper writes `superadmin_badge_icon_url` to `/auth/me` and `/users/:id` via `lib/superadmin-badge.ts` (env override has priority; if env SUPERADMIN_BADGE_ICON_URL is missing, falls back to app_settings row — which is the expected path).

## Mobile Evidence Plan
Each debug line is bound to a hypothesis ID and emits:
- A: /auth/me + /users/:id raw payload fields (is_superadmin, superadmin_badge_icon_url, superadmin_badge_label, email)
- B: image status enum: `loaded`, `error`, `missing-url`, `not-rendered-yet`
- C: raw icon url, normalized url, final url with cache buster
- D: force-reload path requested / cache-buster tick incremented

## On-Device Debug Block
Visible only when `isOwner && displayUser.isSuperadmin`, inserted below "نطاق الخدمة".
Fields shown on screen:
- `imageStatus`
- `raw` (the URL from User.superadminBadgeIconUrl before normalization)
- `resolved` (final URL passed to Image.network, including `?t=...`)
- Button: "Force reload badge"

## Verification Conclusion
Pending (user has not yet run instrumented build + shared console block screenshot).
