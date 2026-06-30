# ShipyardKit Install Prompt

Use this exact prompt with the installer after copying this `ShipyardKit/` folder into the target app repo:

```text
Install and wire ShipyardKit in this Apple app project.

Source of truth is ./ShipyardKit.
Follow these rules exactly:
1) Read ./ShipyardKit/README.md first.
2) Read ./ShipyardKit/user-setup/README.md.
3) Before making integration edits, gather or confirm required install inputs.
4) Add the local Swift package from ./ShipyardKit/swift.
5) Add package product ShipyardKit to the app target.
6) Implement using module ShipyardKit.
7) Use ./ShipyardKit/swift/examples/ShipyardKitExampleView.swift as a reference only; adapt it to the app's existing UI.
8) Configure values from ./ShipyardKit/env.example.
9) Read and apply ./ShipyardKit/user-setup/shipyardkit-config.example.json as the starter config shape.
10) Follow security requirements in ./ShipyardKit/security/threat-model.md.
11) Follow endpoint contracts in ./ShipyardKit/api-contracts/shipyardkit-api.md.
12) Validate with ./ShipyardKit/SETUP_CHECKLIST.md and report each check pass/fail.

Required install inputs:
- shipyardBaseUrl
- productSlug
- app target platform
- install mode: `daily_roadmap_pull_only` or `full_engagement`
- layout choice for `full_engagement`: `recommended_shipyard_layout` or `custom_app_design`
- where integration config should live in this repo
- permission to submit one labeled test item during setup

Ask the user for these before installing if they are not already discoverable with high confidence:
- shipyardBaseUrl
- productSlug
- install mode; recommend `daily_roadmap_pull_only` for Apple TV projects unless the user explicitly wants UI
- layout choice when using `full_engagement`; ask: "Do you want the recommended Shipyard layout, or should I adapt Announcements, Ask, and Roadmap to this app's existing design?"
- which app target to modify if there is more than one
- which config file or config system should hold ShipyardKit values
- permission to submit the final test item when `full_engagement` includes Roadmap submission

If platform can be inferred from the repo, report the inferred value and ask the user to confirm it before shipping.
If shipyardBaseUrl or productSlug are missing and cannot be found safely, stop and ask the user before wiring the package.

Upgrade note for existing ShipyardKit 0.2.0 integrations:
- Update the copied `ShipyardKit/swift` package plus `VERSION` and `CHANGELOG.md`.
- Replace deprecated lifecycle calls such as `pingDailyActiveDevice()` or `checkInDailyActiveDevice()` with `pullRoadmapDaily()` on launch and foreground resume.
- Update visible Roadmap screens to render `cachedItems()` first, then call `pullRoadmapDaily(force: true)` in the background and refresh the visible Roadmap only when fresh data differs.
- Prefer `fetchAsks()` and `respondToAsk(...)` for Ask UI.
- Use `dailyRoadmapPullRows` and `dailyRoadmapInstallCount` in site/admin summaries when available; older count fields are compatibility fallbacks only.
- Replace local setup references to `APPLE_TV_DAILY_ACTIVE_SETUP.md` with `APPLE_TV_ROADMAP_PULL_SETUP.md`.

Implementation requirements:
- Do not embed static admin, service, or full-access API keys in the app.
- Use anonymous end-user flow unless the host app already has account identity to attach separately.
- Verify the target Shipyard product exists in the workspace and is an app product. Product status does not block ShipyardKit mobile sessions.
- Let ShipyardKit mint short-lived tokens through POST /v1/auth/mobile/public-session.
- Configure `pullRoadmapDaily()` on app launch and foreground resume so each install performs one background Roadmap pull per UTC day.
- `pullRoadmapDaily()` should be called freely from lifecycle hooks; the SDK suppresses duplicate successful Roadmap pulls for the same UTC day.
- Use `force: true` only for deliberate user-initiated Roadmap opens or debug verification, not for passive lifecycle hooks.
- For Apple TV projects using `daily_roadmap_pull_only`, read `APPLE_TV_ROADMAP_PULL_SETUP.md` and wire only `pullRoadmapDaily()`. Do not add visible Roadmap, Ask, Announcements, voting, inboxes, badges, or notification-style Shipyard UI.
- In `daily_roadmap_pull_only` mode, skip the rest of the endpoint/UI requirements below except public-session and Roadmap pull verification.
- In `full_engagement` mode, prefer one Shipyard section near Settings or About with exactly three areas: Announcements, Ask, and Roadmap.
- If the user chooses `recommended_shipyard_layout`, format those areas as distinct rows, cards, or list entries using the host app's normal settings/about style.
- If the user chooses `custom_app_design`, adapt the presentation to the app's existing design while preserving the exact area labels and behavior unless the user explicitly approves different wording.
- Use the scoped token for:
  - GET /v1/engagement/updates
  - GET /v1/engagement/asks
  - GET /v1/engagement/announcements
  - POST /v1/engagement/asks/:id/respond
  - POST /v1/engagement/announcements/:id/events
  - GET /v1/requests
  - POST /v1/requests
  - POST /v1/requests/:id/vote
- Roadmap is only for suggestions. Let users choose only Feature or Bug Fix.
- Expected Roadmap format for full engagement installs: a Roadmap page inside Settings or the nearest equivalent app settings/about area.
- The Roadmap page must let users submit a Feature or Bug Fix request.
- The Roadmap page must show active public roadmap items in their current status. Prefer status grouping in lifecycle order: Open, Planned, In Progress, Shipped; include Closed only when the app owner wants historical closed items shown.
- Each roadmap item must have an actual tappable upvote button. Do not make the vote count or icon merely decorative.
- The upvote button should show the current vote count and voted/unvoted state. Maintain local per-install vote state from successful `vote(itemId:)` and `vote(itemId:unvote: true)` calls when the API response does not include a persisted item-level voted flag.
- Style the unvoted upvote button with a quieter/duller color treatment and the voted state with a stronger/bolder treatment. Derive both colors from the app's existing theme.
- Refresh Engagement updates on app launch and foreground resume when the app uses Announcements or Ask unless the app has a clearly conflicting lifecycle pattern.
- Use `fetchEngagementUpdates()` as the default pull when the app needs both Ask and Announcements, and call it again when opening Announcements or Ask.
- If the app renders Ask UI, branch on `ask.type` and support every current type:
  - .singleChoice: submit exactly one option id.
  - .multiChoice: submit selected option ids and honor ask.maxSelections when present.
  - .starRating: submit values from 1 through 5.
  - .numericRating: submit values from 1 through 10.
  - .openText: submit non-empty response text, trimmed to the server limit.
- Submit Ask answers with the matching `respondToAsk(...)` overload.
- If the app renders announcements, only call markAnnouncementShown(...) after the announcement is actually visible on screen.
- If the app supports dismissal or CTA taps, wire dismissAnnouncement(...) and clickAnnouncement(...).
- Ask the user whether the Roadmap should be grouped by status or by Feature/Bug Fix type when the app does not already have a clear pattern.
- When the user opens Roadmap, render `cachedItems()` immediately if cached items exist, then call `pullRoadmapDaily(force: true)` in the background and update the displayed Roadmap if the fresh response differs.
- For status grouping, use fetchItems().shipyardGroupedByStatus() so sections stay in lifecycle order: Open, Planned, In Progress, Shipped, Closed. Items inside each status must be sorted by vote count.
- For type grouping, use fetchItemCategories() so planner item-type categories are sorted by total votes and items inside each category are sorted by vote count.
- Show release-aware labels by calling item.availabilityLabel(currentAppVersion:) with CFBundleShortVersionString when rendering each roadmap item.
- Show item.targetDateLabel when present.
- Show published developer responses by rendering item.developerResponseText when present. Use multiline text so spacing, bullets, and line breaks from Shipyard stay readable.
- Show item.developerRespondedAtRelativeLabel() next to the developer response heading when present.
- Do not squeeze pills/buttons into wrapping text. Put vote count, status, availability, and target date in a horizontal row that can scroll or otherwise preserve one-line labels.
- New submissions should land in waiting_review and not appear publicly until approved.
- After wiring submission, create one clearly labeled test item through the app, for example `ShipyardKit integration test - safe to delete`.
- Ask the user to open Shipyard Admin > Planning > Requests and confirm the test item appears under pending requests. Do not mark setup complete until the user reports that they can see it in Admin.
- Clean up copied ShipyardKit handoff files after setup:
  - If Xcode depends on `./ShipyardKit/swift` as a local Swift package, keep `./ShipyardKit/swift`, `./ShipyardKit/VERSION`, and `./ShipyardKit/CHANGELOG.md`.
  - If Xcode uses a remote package URL or the SDK was moved into the app's own package structure, remove the copied top-level `./ShipyardKit/` folder after confirming no project file references that local path.
  - Remove temporary copied config examples and one-off setup notes that are not used at runtime.
- Preserve existing app architecture and style.
- Keep changes minimal and production-safe.

Deliverables:
- list of files changed
- list of user-provided values and list of inferred values
- install mode used and why
- summary of where ShipyardClient is configured
- summary of where the daily Roadmap pull is called, and confirmation it uses normal once-per-day mode in production
- summary of how token refresh is handled
- summary of where and when Engagement updates are refreshed in the app
- summary of whether the app uses status grouping or Feature/Bug Fix categories, and how sorting works
- summary of the Roadmap open behavior, including cached-first render and background fresh pull update
- summary of how Ask is rendered and submitted, including which of single choice, multi choice, star rating, numeric rating, and open text are supported
- summary of how announcements are rendered and which events are recorded
- summary of how release/version availability labels are displayed
- summary of how target dates are displayed when present
- summary of how developer responses and developer reply timestamps are displayed with preserved formatting
- summary of the Roadmap page location and upvote button voted/unvoted visual treatment
- summary of item submission and error-handling UX
- title of the test item submitted, and whether the user confirmed it appeared in Admin > Planning > Requests
- cleanup performed, including whether the local package folder was kept or the copied handoff folder was removed
- checklist results
```
