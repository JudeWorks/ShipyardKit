# ShipyardKit Changelog

## Unreleased

## 0.25.3 — 2026-08-31

- Removed all Apple credential-store framework imports and calls. The stable
  installation helper and scoped continuity proof now persist exclusively in
  app-local `UserDefaults`.
- Added a one-time Cloudflare continuity transition so verified 0.25.2 installs
  can move to UserDefaults persistence without entering a repeated 401 loop.
  This does not require a PostgreSQL migration; after the exchange, proof
  omission fails closed again.
- Made 0.25.3 the first Cloudflare-only SDK release. The server routes 0.25.3+
  to D1 and a per-workspace SQLite Durable Object without Neon fallback, while
  0.25.2 and older remain on the legacy Neon compatibility path.
- Made the support-email privacy boundary explicit: the host app version/build
  may be included, but ShipyardKit/SDK version and installation/session values
  must remain out of customer-visible email.
- Made offline replay reentrancy-safe so writes queued while a flush is waiting
  on the network cannot be overwritten, and report success only after the
  queue is durably written.
- Treats retryable HTTP failures such as Cloudflare `503` responses like an
  offline connection for writes, preserving the change in the durable queue
  and presenting the non-disruptive saved-offline result to the host app.
- Treats timeouts, dropped connections, temporarily unavailable resources, and
  disconnected background sessions as transient: reads retain cached content
  and writes enter the durable retry queue.
- Rehydrates queued Device Activity with the current continuity proof, and
  invalidates/retries a cached session token once after a 401 response.

## 0.25.2 — 2026-08-31

- Scoped installation continuity proofs to the stable installation identifier,
  migrated existing proof entries, and added one-time recovery when a stale
  proof is rejected so affected installs can bootstrap a fresh mobile session
  instead of remaining stuck on repeated 401 responses.
- Declared ShipyardKit API contract version 1 on every SDK request. The contract
  stays at the HTTP/JSON boundary, so the same app build works while Shipyard's
  storage moves from Neon PostgreSQL to Cloudflare-backed services.
- No host-app integration changes are required when upgrading from 0.25.0.


## 0.25.0 — 2026-07-20

- Standardized the public engagement model on `ShipyardAsk`, `ShipyardAskType`,
  `ShipyardAskOption`, `ShipyardAskResponse`, `fetchAsks()`, and
  `respondToAsk(...)`.
- Removed CheckIn- and Prompt-named SDK compatibility APIs. Previously shipped
  builds can still complete pulls through server-side empty compatibility
  responses, but ShipyardKit 0.25.0 uses only the canonical Ask contract.
- Renamed Ask option totals from votes to selections so they cannot be confused
  with Roadmap votes.
- Standardized passive SDK telemetry language on Device Activity, including
  Device Activity Events, Active Devices, Daily Active Devices, and Last Device
  Activity.
- Removed deprecated daily active-device ping/check-in helpers. `syncDaily()` is
  the lifecycle coordinator and `pullRoadmapDaily()` remains the explicit
  Roadmap read.

## 0.2.5 — 2026-07-20

- Added compile-time Simulator detection to every mobile session and queued
  daily activity report. ShipyardKit now reports `runtimeEnvironment` as either
  `simulator` or `physical_device` without changing the opaque installation id.
- Simulator activity can now be stored for diagnostics while remaining
  excluded from Active Devices and production analytics totals.

## 0.2.4 — 2026-07-16

- Added a server-issued, app-local installation continuity proof for mobile
  sessions. ShipyardKit persists the proof and immediately
  exchanges a bootstrap session for a continuity-verified session.
- Added recovery for installations that received and discarded a bootstrap
  proof before proof-capable ShipyardKit code was available.
- Added a macOS-safe Swift package test helper that builds disposable XCTest
  artifacts outside downloaded and cloud-backed project folders, preventing
  intermittent Gatekeeper “damaged” alerts during installer verification.
- Added `syncDaily()` as the standard lifecycle coordinator for one Roadmap,
  Engagement, queued-write, and check-in cycle per UTC calendar day.
- Added `pullEngagementDaily()` and `cachedEngagementUpdates()` so
  Announcements and Ask can use cached-first, once-daily behavior.
- Split the daily check-in marker from successful Roadmap and Engagement read
  markers. Failed content can retry later the same day without repeating the
  successful or queued check-in.
- Forced Roadmap reads no longer repeat the daily check-in.
- Updated the standard UI contract to three separate rows under Support:
  Roadmap is always visible; Announcements and Ask exist only with current
  content. Other Support features remain app-owned.
- Updated installer guidance, starter configuration, checklist, API contract,
  and SwiftUI example to remove passive `force: true` and repeated lifecycle
  Engagement refreshes.

## 0.2.2 — 2026-07-06

- Daily check-in reliability: the session call now retries once with a short
  jittered delay on transient failures (connectivity, 408/425/429/5xx).
- Offline check-ins are no longer lost: when the only app open of the day
  happens offline, the check-in is queued with its UTC day and delivered on
  the next connection (`activityDate`, accepted by the server up to 2 days
  late).
- Added the first `ShipyardInstallationIdentifier.stable()` install-id helper.
  The current implementation is UserDefaults-only and intentionally follows
  the app installation lifecycle.
- Note: `pullCount` on daily activity rows counts session refreshes for the
  day, not roadmap fetches.


## 0.2.1 - 2026-06-27

- Added `pullRoadmapDaily()` as the preferred Roadmap activity read, with `sessionReason: "roadmap_pull"` on the mobile session refresh.
- Added `cachedItems()` so Roadmap views can render stored items immediately, then refresh in the background and update only when fresh data differs.
- Updated setup docs, examples, API contracts, and the installer guide to frame activity around daily Roadmap pulls instead of legacy app activity wording.

### Upgrade from 0.2.0

- Replace lifecycle calls to deprecated daily activity helpers with `pullRoadmapDaily()` on launch and foreground resume.
- When opening a visible Roadmap page, render `cachedItems()` first, then run `pullRoadmapDaily(force: true)` in the background and update the visible groups if the fresh response differs.
- Use the new Roadmap usage count fields in site/admin code: `dailyRoadmapPullRows` and `dailyRoadmapInstallCount`. Older count fields remain for compatibility.
- Prefer `fetchAsks()` and `respondToAsk(...)` for Ask UI. CheckIn-named SDK helpers and response keys remain only as compatibility aliases.
- Rename any local setup references from `APPLE_TV_DAILY_ACTIVE_SETUP.md` to `APPLE_TV_ROADMAP_PULL_SETUP.md`.
- For full UI installs, make Roadmap a Settings/About page that lets users submit Feature or Bug Fix requests, lists active roadmap items in their current status, and uses a real upvote button with distinct unvoted and voted states based on the app theme.

## 0.2.0 - 2026-06-08

- Removed legacy app identifier fields from ShipyardKit engagement setup and session payloads.
- Changed `ShipyardClient` setup to use product/workspace configuration only: `baseURL`, `productSlug`, and `installationIdProvider`.
- Updated setup docs, examples, API contracts, and tests so apps work once their product exists and engagement is enabled.

## 0.1.2 - 2026-06-04

- Added a 15-minute default cache for authenticated engagement reads so launch, foreground, and repeated view renders do not repeatedly call `/v1/engagement/updates`.
- Added `ShipyardReadCachePolicy.reloadIgnoringCache` for deliberate user-initiated refreshes.

## 0.1.1 - 2026-06-03

- Renamed the preferred app-facing engagement surface from legacy prompt wording to Ask while keeping backward-compatible aliases.
- Added recommended Announcements, Ask, and Roadmap layout guidance for Settings/About areas.
- Added post-install cleanup instructions for copied ShipyardKit handoff folders.
- Clarified Roadmap suggestions as Feature or Bug Fix only.

## 0.1.0

- Added the first explicit ShipyardKit SDK version.
- ShipyardKit now sends its SDK version in public session payloads and request headers.
