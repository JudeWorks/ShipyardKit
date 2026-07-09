# ShipyardKit Changelog

## 0.2.3 — 2026-07-09

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
- New `ShipyardInstallationIdentifier.stable()` Keychain-backed install id
  helper (with UserDefaults migration + fallback) so reinstalls do not mint
  a new "device". The README and example now use it.
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
