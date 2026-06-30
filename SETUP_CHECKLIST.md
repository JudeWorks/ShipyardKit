# ShipyardKit Setup Checklist

Use this after integration to confirm ShipyardKit is ready for developer or LLM-assisted installation.

## Package

- [ ] The app target depends on Swift package product `ShipyardKit`.
- [ ] App code imports `ShipyardKit`.
- [ ] No references remain to old package names.

## Config

- [ ] Installer filled values from `ShipyardKit/user-setup/shipyardkit-config.example.json` or mapped them into the app config.
- [ ] `shipyardBaseUrl` points to the correct Shipyard workspace deployment.
- [ ] `productSlug` matches the product where Roadmap suggestions should land.
- [ ] App sends a stable per-install `installationId` and does not regenerate it every launch.
- [ ] App sends correct `platform`.
- [ ] App sends app version and build number in mobile session payloads (ShipyardKit defaults to `CFBundleShortVersionString` and `CFBundleVersion`).
- [ ] App sends `shipyardKitVersion` in mobile session payloads (ShipyardKit defaults to `ShipyardClient.sdkVersion`).
- [ ] Server has `SESSION_SECRET` set.

## Product Controls

- [ ] Target product exists in the Shipyard workspace.
- [ ] Target product is an app product.
- [ ] Product status is not treated as a blocker; ShipyardKit mobile sessions work for app products in any status.

## Token Flow

- [ ] App successfully calls `POST /v1/auth/mobile/public-session`.
- [ ] App calls `pullRoadmapDaily()` on launch and foreground resume when daily Roadmap pull visibility is wanted.
- [ ] Repeated lifecycle `pullRoadmapDaily()` calls on the same UTC day do not send duplicate background Roadmap pulls; `force: true` is only used for user-initiated Roadmap opens or debug verification.
- [ ] Opening Roadmap renders `cachedItems()` first when cached data exists, then runs `pullRoadmapDaily(force: true)` in the background and updates the visible Roadmap if fresh data differs.
- [ ] Repeated `fetchEngagementUpdates()` calls within 15 minutes use the SDK cache unless the user deliberately refreshes with `cachePolicy: .reloadIgnoringCache`.
- [ ] Token is stored in memory only, or secure storage with expiry awareness.
- [ ] Expired token triggers refresh and retry.
- [ ] App never ships a static `SERVICE_API_KEY`, `API_TOKEN`, or admin secret.

## App Layout

- [ ] User was asked whether to use the recommended Shipyard layout or a custom app-specific design.
- [ ] Full integration uses exactly three user-facing areas: Announcements, Ask, and Roadmap.
- [ ] Recommended layout, if chosen, is one Shipyard section near Settings/About with three rows/cards/list entries.
- [ ] Custom design, if chosen, preserves the Announcements, Ask, and Roadmap labels and behavior unless the user explicitly approved different wording.
- [ ] Roadmap opens as a page inside Settings or the nearest equivalent app settings/about area.
- [ ] Roadmap page includes both item submission and public item browsing.

## Engagement Read Flow

- [ ] App successfully calls `GET /v1/engagement/updates` with the scoped token.
- [ ] The app refreshes Engagement data on launch and foreground resume when Announcements or Ask are enabled.
- [ ] If the app has dedicated Announcements or Ask areas, opening them also refreshes Engagement data.
- [ ] Ask UI only appears when asks are returned.
- [ ] Announcement UI only appears when announcements are returned.
- [ ] If the app shows an announcement, it records `shown` only after the announcement is actually visible on screen.
- [ ] If the app supports announcement dismissal, it only sends dismissal events for clearable announcements.

## Apple TV Roadmap Pull Only Flow

- [ ] If this is a background-pull-only tvOS app, installer followed `APPLE_TV_ROADMAP_PULL_SETUP.md`.
- [ ] tvOS config uses `platform: "tvos"`.
- [ ] tvOS app has no visible Roadmap, Ask, Announcements, voting, inbox, or notification-style Shipyard UI.
- [ ] tvOS app calls only `pullRoadmapDaily()` during normal runtime.
- [ ] In tvOS background-pull-only mode, `force: true` is used only for debug verification and removed before shipping.

## Ask Response Flow

- [ ] App branches on `ask.type` instead of guessing from title or option count.
- [ ] Single-choice Ask submits with one option id.
- [ ] Multi-choice Ask submits multiple option ids when applicable.
- [ ] Multi-choice Ask honors `maxSelections` when present.
- [ ] Star rating Ask submits values from 1 to 5.
- [ ] Numeric rating Ask submits values from 1 to 10.
- [ ] Open-text Ask submits response text with basic empty-state validation.
- [ ] Re-answering an Ask updates the same install's current response cleanly.
- [ ] At least one Ask or Announcement with app/build targeting was tested against expected version/build behavior.

## Roadmap Submission Flow

- [ ] User can select only `Feature` and `Bug Fix` for public roadmap suggestions.
- [ ] Submit flow lives on the Roadmap page or is reachable directly from it.
- [ ] `POST /v1/requests` succeeds with scoped token.
- [ ] New item appears in admin as `waiting_review`.
- [ ] Installer submitted a clearly labeled test item, for example `ShipyardKit integration test - safe to delete`.
- [ ] User confirmed the test item is visible in Shipyard Admin > Planning > Requests.
- [ ] New item is not shown publicly until approved.

## Voting Flow

- [ ] Public Roadmap items are grouped intentionally: either status groups via `fetchItems().shipyardGroupedByStatus()` or Feature/Bug Fix categories via `fetchItemCategories()`.
- [ ] Roadmap screen refresh on open does not block showing cached Roadmap data.
- [ ] Roadmap shows active public items in their current status; Closed appears only if the app intentionally includes historical closed items.
- [ ] Status groups, if used, appear in lifecycle order: Open, Planned, In Progress, Shipped, Closed.
- [ ] Type categories, if used, are sorted by total votes, most upvoted first.
- [ ] Items inside each status/category are sorted by vote count, most upvoted first.
- [ ] Items with `releaseVersion` show version-aware labels using `availabilityLabel(currentAppVersion:)`.
- [ ] The app passes `CFBundleShortVersionString` or equivalent current app version for availability comparisons.
- [ ] Items with `targetDateLabel` show the target date without wrapping cramped pills/buttons.
- [ ] Items with `developerResponseText` show the developer response publicly.
- [ ] Items with `developerRespondedAtRelativeLabel()` show the developer reply timestamp when available.
- [ ] Developer response text preserves line breaks, spacing, and bullets in the app UI.
- [ ] Each roadmap item has an actual tappable upvote button.
- [ ] Upvote button shows both vote count and voted/unvoted state.
- [ ] Unvoted upvote state uses a quieter/duller treatment from the app theme.
- [ ] Voted upvote state uses a stronger/bolder treatment from the app theme.
- [ ] `POST /v1/requests/:id/vote` increments vote count.
- [ ] Repeating vote from same install returns already-voted semantics.
- [ ] Sending `{ "unvote": true }` removes vote for same install.

## Regression Safety

- [ ] Web request submission still works with same-origin + Turnstile.
- [ ] Web users can choose Feature or Bug Fix consistently with the app flow.
- [ ] Web roadmap vote flow still works with cookie-based voter token.
- [ ] App handles 401/403/429 gracefully with user-visible retry messaging.

## Cleanup

- [ ] If Xcode uses `ShipyardKit/swift` as a local Swift package, that folder is still present and referenced intentionally.
- [ ] If Xcode uses a remote package URL or a moved SDK package, the copied top-level `ShipyardKit/` handoff folder was removed.
- [ ] Temporary copied config examples and one-off setup notes were removed unless they are intentionally used at runtime.
- [ ] Final app config lives in the app's normal config system.
