# ShipyardKit

ShipyardKit is the Swift package and setup bundle for adding Shipyard-powered announcements, Ask responses, roadmap suggestions, roadmap voting, and daily Roadmap pull visibility to Apple apps.

It also exposes service-token APIs for native admin tools, including a Mac planner surface that can list products, load release-grouped planner items, update working versions, manage internal planner items, and edit planning tasks.

Current SDK version: `0.2.1`. Update `VERSION` and `ShipyardClient.sdkVersion` every time the SDK changes; `scripts/bump-version.mjs` does both and opens a changelog entry.

Zip and hand off the top-level `ShipyardKit/` folder. That folder is the complete distributable package for a developer or installer.

It ships three app-facing areas that fit well near Settings or About:

- **Announcements**: one-way messages pushed from Shipyard into the app.
- **Ask**: lightweight questions that collect a rating, choice, or text response.
- **Roadmap**: public feature and bug-fix suggestions, voting, and release-aware status.

The API is intentionally named around generic `items` because Shipyard will support more item types beyond roadmap suggestions over time.

## Preferred App Layout

The preferred build is one Shipyard section near Settings or About with three clearly labeled entries:

- Announcements
- Ask
- Roadmap

Use the host app's normal list row, card, or settings-cell style. Each entry should open a dedicated surface for that function, and Roadmap submission should only offer Feature and Bug Fix.

The Roadmap entry should open a Roadmap page within Settings or the nearest equivalent app area. That page should:

- let users submit a Feature or Bug Fix request
- show active public roadmap items in their current status
- include an actual upvote button on each item, not just a decorative count or icon
- style the unvoted button with a quieter/duller treatment and the voted button with a stronger treatment using colors from the app's theme

Before wiring UI, ask the app owner:

> Do you want the recommended Shipyard layout, or should I adapt Announcements, Ask, and Roadmap to this app's existing design?

If they choose the recommended layout, use the three-entry Settings/About pattern. If they choose a custom design, keep the same labels and behavior unless the app owner explicitly approves different wording.

## What ShipyardKit does

- Mints short-lived, scoped end-user tokens from Shipyard.
- Runs one daily Roadmap pull per installed app/device when the app calls `pullRoadmapDaily()`, so Shipyard can show which apps, platforms, app versions, and SDK versions are using the Roadmap integration.
- Submits roadmap suggestions as `waiting_review` so admins can moderate before publishing.
- Lets users submit roadmap suggestions as `feature` or `bugfix`.
- Reads cached public Roadmap items for immediate display and refreshes them in the background when users open Roadmap.
- Fetches the latest Engagement updates for the configured product.
- Lets the app respond to Ask items for single choice, multi choice, star rating, numeric rating, and open text responses.
- Lets the app record announcement lifecycle events such as shown, dismissed, and clicked.
- Breaks public items into planner item-type categories.
- Sorts item-type categories by total votes and sorts items inside each category from most upvoted to least upvoted.
- Can also group public items by roadmap status in lifecycle order: Open, Planned, In Progress, Shipped, Closed. Items inside each status stay sorted by vote count.
- Shows roadmap availability from Shipyard release versions, for example `Coming in 1.2.3`, `Update to get this`, or `Included in your version`.
- Formats optional target dates as labels such as `Target Mar 2026`.
- Shows published developer responses attached to roadmap items while preserving line breaks and bullets from Shipyard.
- Parses Shipyard ISO dates with or without fractional seconds and can show `Dev replied ...` relative labels.
- Supports voting and unvoting.
- Supports native admin/planner apps with explicit service API tokens: product planning lists, product detail with release groups, product planning updates, planner item create/update/bulk workflows, moderation counts, and checklist tasks.

## What ShipyardKit does not do

- It does not require user sign-in.
- It does not embed admin keys, service keys, or API tokens in the app.
- It does not publish submissions publicly before review.
- It does not manage service API token storage for native admin/planner apps. Store those tokens in the host app's secure account/keychain layer and pass them explicitly to service-token methods.

## Package Contents

- `INSTALL_GUIDE.md`: canonical setup guide for automated installs.
- `APPLE_TV_ROADMAP_PULL_SETUP.md`: tvOS setup path for a background daily Roadmap pull with no visible Announcements, Ask, Roadmap, or voting UI.
- `VERSION` and `CHANGELOG.md`: SDK release number and release notes.
- `SETUP_CHECKLIST.md`: pass/fail checklist for manual or automated installs.
- `env.example`: configuration values to map into the app.
- `user-setup/shipyardkit-config.example.json`: starter config file for the values the installer must enter.
- `user-setup/README.md`: where to find each value in Shipyard.
- `api-contracts/shipyardkit-api.md`: endpoint contract.
- `security/threat-model.md`: security model and abuse protections.
- `swift/Package.swift`: Swift Package manifest for `ShipyardKit`.
- `swift/Sources/ShipyardKit/ShipyardClient.swift`: Swift client.
- `swift/examples/ShipyardKitExampleView.swift`: SwiftUI example using fictional Acme/Atlas values.

## Server Requirements

Your Shipyard backend must support:

- `POST /v1/auth/mobile/public-session`
- `GET /v1/engagement/updates` with ShipyardKit scoped bearer token
- `GET /v1/engagement/asks` with ShipyardKit scoped bearer token
- `GET /v1/engagement/announcements` with ShipyardKit scoped bearer token
- `POST /v1/engagement/asks/:id/respond` with ShipyardKit scoped bearer token
- `POST /v1/engagement/announcements/:id/events` with ShipyardKit scoped bearer token
- `POST /v1/auth/mobile/notification-subscriptions` with ShipyardKit scoped bearer token
- `DELETE /v1/auth/mobile/notification-subscriptions` with ShipyardKit scoped bearer token
- `GET /v1/requests` with ShipyardKit scoped bearer token for Roadmap pulls
- `POST /v1/requests` with ShipyardKit scoped bearer token
- `POST /v1/requests/:id/vote` with ShipyardKit scoped bearer token

Native admin or Mac planner builds additionally need service-token access to:

- `GET /v1/products`
- `GET /v1/products/:slug?includePlanner=1`
- `PATCH /v1/products/:slug`
- `GET /v1/requests/counts`
- `POST /v1/requests`
- `PATCH /v1/requests/:id`
- `POST /v1/requests/bulk`
- `PATCH /v1/requests/bulk`
- `GET /v1/requests/:id/tasks`
- `POST /v1/requests/:id/tasks`
- `PATCH /v1/requests/:id/tasks/:taskId`
- `DELETE /v1/requests/:id/tasks/:taskId`

And have:

- `SESSION_SECRET` configured
- Target product exists in the workspace
- Target product is an app product. Product status does not block ShipyardKit mobile sessions.

## Human Setup

Before installing, collect:

- `shipyardBaseUrl`
- `productSlug`
- target app `platform`
- confirmation of where app config should live
- whether to use the recommended Shipyard layout or a custom app-specific design
- permission to submit one test item during setup

1. Copy or unzip the top-level `ShipyardKit/` folder into the target app repo.
2. Fill `ShipyardKit/user-setup/shipyardkit-config.example.json` with the real Shipyard workspace and product values, or copy it to the app's own config system.
3. Add `ShipyardKit/swift` as a local Swift Package in Xcode.
4. Add product `ShipyardKit` to the app target.
5. `import ShipyardKit`.
6. Create a stable per-install identifier using Keychain or persisted `UserDefaults`.
7. Instantiate `ShipyardClient` with your Shipyard workspace URL, product slug, platform, and installation id provider.
   - ShipyardKit automatically includes app version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`) in mobile session payloads unless you override providers.
   - ShipyardKit also sends `ShipyardClient.sdkVersion` as `shipyardKitVersion` and `X-ShipyardKit-Version`.
8. Ask whether to use the recommended Shipyard layout or a custom app-specific design.
9. Add the Shipyard area near Settings or About with three entries: Announcements, Ask, and Roadmap.
10. Roadmap suggestions are only for `Feature` and `Bug Fix`.
11. Choose the roadmap layout:
    - Status roadmap: call `fetchItems().shipyardGroupedByStatus()` to show Open, Planned, In Progress, Shipped, and Closed groups. Items inside each group are sorted by upvotes.
    - Type sections: call `fetchItemCategories()` only if the app specifically wants Feature and Bug Fix sections.
12. Call `pullRoadmapDaily()` on app launch and foreground resume. This performs a background Roadmap read at most once per UTC day per install and lets Shipyard report which apps are using the Roadmap pull without extra UI. When the user opens Roadmap, render `cachedItems()` immediately when available, then call `pullRoadmapDaily(force: true)` in the background and update the visible groups if the fresh response changed.
13. Refresh Engagement data on app launch and foreground resume when the app uses Announcements or Ask. ShipyardKit caches engagement reads for 15 minutes by default, so repeated lifecycle calls do not hammer the API.
14. Call `fetchEngagementUpdates()` to load current Ask items and Announcements in one request; use `cachePolicy: .reloadIgnoringCache` only for deliberate user-initiated refreshes.
15. If the app shows Ask UI, branch on `ask.type` and support every current type:
    - `.singleChoice`: submit one option id.
    - `.multiChoice`: submit selected option ids and honor `maxSelections` when present.
    - `.starRating`: submit a value from 1 to 5.
    - `.numericRating`: submit a value from 1 to 10.
    - `.openText`: submit non-empty text up to 2000 characters.
16. Submit Ask answers with the matching `respondToAsk(...)` overload.
17. If the app shows an announcement on screen, call `markAnnouncementShown(...)` only after the announcement is actually visible to the user.
18. If the app lets the user dismiss or tap an announcement CTA, call `dismissAnnouncement(...)` or `clickAnnouncement(...)`.
19. For each roadmap item, call `item.availabilityLabel(currentAppVersion:)` with the installed app version to show version-aware status text.
20. If `item.targetDateLabel` is present, show it near the availability/status pills.
21. If `item.developerResponseText` is present, render it with multiline text so Shipyard line breaks and bullets remain readable.
22. If `item.developerRespondedAtRelativeLabel()` is present, show it next to the developer response heading.
23. Submit one clearly labeled test item from the app, for example `ShipyardKit integration test - safe to delete`.
24. Ask the Shipyard admin user to confirm the item appears in Shipyard Admin > Planning > Requests under pending requests.
25. Run `SETUP_CHECKLIST.md` before shipping.
26. Clean up the copied ShipyardKit handoff files after integration.

## Post-Install Cleanup

After the app is wired and verified, clean up the copied `ShipyardKit/` folder based on how the SDK is installed:

- If Xcode uses `ShipyardKit/swift` as a local Swift package, keep `ShipyardKit/swift`, `VERSION`, and `CHANGELOG.md` in the repo. You may remove installer-only files such as `INSTALL_GUIDE.md`, `SETUP_CHECKLIST.md`, `APPLE_TV_ROADMAP_PULL_SETUP.md`, `api-contracts/`, `security/`, and `user-setup/` after their instructions have been copied into project docs or completed.
- If the app uses a remote Swift Package URL or the SDK has been moved into the app's own package structure, remove the copied top-level `ShipyardKit/` handoff folder after confirming Xcode no longer depends on that local path.
- Do not leave temporary `shipyardkit-config.json` files, copied example config files, or one-off setup notes in the app bundle unless the app intentionally uses them at runtime.
- Keep the real runtime config in the app's normal configuration system and keep the stable installation ID storage in app code.

## Daily Roadmap Pull Only

For apps where you only want Shipyard to see daily Roadmap pull usage, including Apple TV apps, install ShipyardKit and call only `pullRoadmapDaily()`. Do not add visible Roadmap, Ask, Announcement, vote, or inbox UI.

```swift
import ShipyardKit

let client = ShipyardClient(
    baseURL: URL(string: "https://acme-studio.startshipyard.com")!,
    productSlug: "atlas-tv",
    platform: "tvos",
    installationIdProvider: { stableInstallationId() }
)

Task {
    _ = try? await client.pullRoadmapDaily()
}
```

Call it on app launch and whenever the app becomes active. The SDK stores the last successful UTC date in `UserDefaults`, so repeated calls on the same day do not send another background Roadmap pull. Pass `force: true` only for manual testing.

## Native Mac Planner

For a first-class Mac planner, use the service-token methods instead of mobile feedback tokens. A good native planner should keep reads fast and explicit:

- Load product rows with `fetchProducts(...)`, using `sort: "update_priority_desc"` or a user-selected sort.
- For product pickers or screens that only need names/icons/basic planning fields, call `fetchProducts(includePriority: false, includeLatestUpdates: false, includeSupport: false, ...)` to avoid the heavier ranking and lookup work.
- Use `updatePriorityPaused`, `updatePriorityPausedUntil`, and `updatePriorityDisplayLabel` to match Shipyard Admin's snoozed update-priority state, such as `Paused · until Jul 4 · Snoozed`.
- Load a selected product with `fetchProduct(slug:includePlanner: true, ...)` and render `planner.groups` so the current working version, future versions, and backlog match Shipyard Admin.
- Save working-version metadata with `updateProduct(slug:update:...)`.
- Create and edit private/internal planner items with `createPlannerItem(...)` and `updatePlannerItem(...)`.
- Use `fetchPlannerCounts(...)` for waiting-review badges.
- Use `fetchPlannerTasks(...)`, `createPlannerTask(...)`, `updatePlannerTask(...)`, and `deletePlannerTask(...)` for checklist-style planning.

Example:

```swift
let products = try await client.fetchProducts(
    type: "app",
    sort: "update_priority_desc",
    workspaceSlug: "judeworks",
    apiToken: serviceApiToken
)

let detail = try await client.fetchProduct(
    slug: "atlas",
    includePlanner: true,
    workspaceSlug: "judeworks",
    apiToken: serviceApiToken
)

let updated = try await client.updateProduct(
    slug: "atlas",
    update: ShipyardProductUpdate(
        workingVersion: "1.4.0",
        workingVersionStatus: "building",
        workingVersionProgress: 70
    ),
    workspaceSlug: "judeworks",
    apiToken: serviceApiToken
)

let item = try await client.createPlannerItem(
    ShipyardPlannerItemInput(
        title: "Polish native planner keyboard flow",
        productSlug: "atlas",
        status: "planned",
        visibility: "private",
        origin: "internal",
        itemType: "polish",
        releaseVersion: updated.workingVersion
    ),
    workspaceSlug: "judeworks",
    apiToken: serviceApiToken
)

_ = try await client.createPlannerTask(
    itemId: item.id,
    title: "Profile large release groups on macOS",
    workspaceSlug: "judeworks",
    apiToken: serviceApiToken
)
```

## Upgrade From 0.2.0 To 0.2.1

For existing integrations, update `ShipyardKit/swift`, `VERSION`, and `CHANGELOG.md`, then make these migration edits:

- Replace deprecated lifecycle calls such as `pingDailyActiveDevice()` or `checkInDailyActiveDevice()` with `pullRoadmapDaily()` on launch and foreground resume.
- Update visible Roadmap screens to render `cachedItems()` first, then run `pullRoadmapDaily(force: true)` in the background and refresh the visible groups only when the response changes.
- Prefer `fetchAsks()` and `respondToAsk(...)` for Ask UI.
- Read `dailyRoadmapPullRows` and `dailyRoadmapInstallCount` in site/admin usage summaries when available.
- Replace local references to `APPLE_TV_DAILY_ACTIVE_SETUP.md` with `APPLE_TV_ROADMAP_PULL_SETUP.md`.

## Installer Guide

Use `INSTALL_GUIDE.md` exactly. The installer should read this README first, then wire the package without adding static API keys.

Before installation begins, confirm:

- `shipyardBaseUrl` if it is not already present in app config or project docs
- `productSlug` if it is not already present in app config or project docs
- confirmation of the correct app target if the repo contains more than one app target
- confirmation of the config location if the repo has multiple config systems
- whether to use the recommended Shipyard layout or adapt Announcements, Ask, and Roadmap to the app's existing design
- permission to submit one clearly labeled test item through the app

The installer may derive these from the codebase when obvious, but it should still ask the user to confirm before shipping:

- `platform`
- current app version source, usually `CFBundleShortVersionString`
- current build number source, usually `CFBundleVersion`
- when the app should refresh Engagement updates, for example app launch, foreground resume, or when the user opens Announcements or Ask

If those values are missing and cannot be discovered safely, installation should stop before editing app integration code.

## Install Order

For both manual and automated installs, the recommended order is:

1. Read this `README.md`.
2. Read `user-setup/README.md`.
3. Fill or map values from `user-setup/shipyardkit-config.example.json`.
4. Add `swift/` as a local Swift package.
5. Wire `ShipyardClient`.
6. Add the required mode:
   - For daily Roadmap pull only, call `pullRoadmapDaily()` and stop there.
   - For full apps, add Announcements, Ask, and Roadmap UI plus submission, fetch, and vote wiring.
7. Submit one test item when Roadmap submission is enabled.
8. Run `SETUP_CHECKLIST.md`.

## Finding Values In Shipyard

- `shipyardBaseUrl`: open your Shipyard workspace in a browser and copy the origin, for example `https://acme-studio.startshipyard.com`.
- `productSlug`: open the product in Shipyard and copy the slug from the product URL. For `https://acme-studio.startshipyard.com/products/atlas`, use `atlas`.
- `platform`: use `ios`, `ipados`, `macos`, `tvos`, `watchos`, or `visionos`.
  - If omitted in `ShipyardClient`, ShipyardKit infers it automatically from runtime/target.

The example company is Acme Corp and the example product is Atlas. Replace every Acme/Atlas value before shipping.

## Minimal Swift Example

```swift
import ShipyardKit

let client = ShipyardClient(
    baseURL: URL(string: "https://acme-studio.startshipyard.com")!,
    productSlug: "atlas",
    installationIdProvider: { stableInstallationId() }
)

_ = try await client.pullRoadmapDaily()
let items = try await client.fetchItems()
let cachedItems = await client.cachedItems()
let categories = try await client.fetchItemCategories()
let statusGroups = items.shipyardGroupedByStatus()
let updates = try await client.fetchEngagementUpdates()
let availability = items.first?.availabilityLabel(currentAppVersion: "1.0.2")
let target = items.first?.targetDateLabel
let replyTime = items.first?.developerRespondedAtRelativeLabel()
let askType = updates.asks.first?.type
let created = try await client.submitItem(
    title: "Add compact dashboard widgets",
    description: "Useful on smaller phones.",
    itemType: .feature
)
if let ask = updates.asks.first {
    switch ask.type {
    case .singleChoice:
        if let option = ask.options.first {
            _ = try await client.respondToAsk(askId: ask.id, optionId: option.id)
        }
    case .multiChoice:
        _ = try await client.respondToAsk(askId: ask.id, optionIds: ask.options.prefix(2).map(\.id))
    case .starRating, .numericRating:
        _ = try await client.respondToAsk(askId: ask.id, ratingValue: 4)
    case .openText:
        _ = try await client.respondToAsk(askId: ask.id, responseText: "Search feels faster.")
    case nil:
        break
    }
}
if let announcement = updates.announcements.first {
    _ = try await client.markAnnouncementShown(
        announcementId: announcement.id,
        visibleMs: 1200,
        screenKey: "home"
    )
}
```

## Final Verification

The integration is not complete until a real test submission reaches Shipyard. Use a title that is easy to find and delete, then ask the user to check Admin > Planning > Requests. Mark the setup done only after the user confirms the test item is visible there.
