# ShipyardKit Threat Model and Security Notes

## Goals

- Allow anonymous end-users to submit and vote from within mobile apps.
- Prevent leaking long-lived privileged secrets in distributed client binaries.
- Limit abuse and blast radius if a client token is captured.

## What not to do

- Do not embed `SERVICE_API_KEY`, `API_TOKEN`, or admin secrets in the app.
- Do not reuse admin mobile auth (`/v1/auth/mobile/callback`) for end-user ShipyardKit sessions.
- Do not bypass `waiting_review` for public end-user submissions.

## Security model

1. App requests short-lived scoped token from `POST /v1/auth/mobile/public-session`.
2. Token is signed with `SESSION_SECRET`.
3. Token only allows scoped public operations:
   - `requests:create_public_mobile`
   - `requests:vote_public_mobile`
   - `engagement:read_public_mobile`
   - `engagement:respond_public_mobile`
4. Token is bound to:
   - workspace
   - product
   - installationId
   - platform
5. Token may carry optional client telemetry such as app version, build number, and ShipyardKit version.

## Abuse controls

- Durable database-backed rate limits on token minting, item creation, and voting.
- Durable database-backed rate limits on Ask responses and announcement events.
- Moderation queue default (`waiting_review`) for all public item submissions.
- Mobile sessions are limited to app products. Product status does not block ShipyardKit mobile sessions.
- Item type is normalized to the public roadmap suggestion allow-list for public/mobile clients: `feature` or `bugfix`.

## Operational recommendations

- Keep token TTL short.
- Refresh token proactively near expiry.
- Treat repeated 401/403 responses as token/session invalidation and re-mint.
- Log high-frequency vote/submit patterns and tune limits.
