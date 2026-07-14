# ShipyardKit Swift Package

`ShipyardKit` is the Swift package product developers add to Apple apps for daily Roadmap pull visibility, Announcements, Ask, and Roadmap flows backed by Shipyard. It also includes service-token APIs for native admin tools, including Mac planner apps.

Current SDK version: `0.2.3`.

## Install via Swift Package Manager

### Local package

1. In Xcode, choose `File -> Add Package Dependencies...`.
2. Click `Add Local...`.
3. Select `ShipyardKit/swift`.
4. Add product `ShipyardKit` to your app target.

### Remote package

1. Publish this Swift package folder to a git repository.
2. Add the package URL in Xcode.
3. Choose a branch or version tag.
4. Add product `ShipyardKit`.

## Integration Steps

Before wiring the app, confirm the Shipyard product exists in the workspace and is an app product. Product status does not block ShipyardKit mobile sessions.

1. `import ShipyardKit`.
2. Create a stable per-install identifier.
3. Instantiate `ShipyardClient` with `baseURL`, `productSlug`, and `installationIdProvider`.
   Optional: pass `platform` explicitly (`ios`, `ipados`, `macos`, `tvos`, `watchos`, `visionos`) or let ShipyardKit infer it.
   By default, ShipyardKit also sends `CFBundleShortVersionString`, `CFBundleVersion`, and `ShipyardClient.sdkVersion`.
4. Call `syncDaily()` on launch and foreground resume so Roadmap, Engagement, queued writes, and the Shipyard check-in complete once per UTC day.
5. Call `refreshSession()` before the first write, or let `submitItem`/`vote` mint a session automatically.
6. When the user opens Roadmap, call `cachedItems()` first to render stored items immediately, then call normal `pullRoadmapDaily()` and replace the visible groups only when it returns fresh content.
7. Call `fetchItems()` when you need an explicit public item read outside the daily/background pull flow.
8. Use `shipyardGroupedByStatus()` on the items returned by `fetchItems()` or `pullRoadmapDaily(...)` for Open, Planned, In Progress, Shipped, and Closed sections sorted by upvotes inside each section.
9. For Apple TV/tvOS apps, wire only `pullRoadmapDaily()` by default and do not add visible Shipyard UI unless admin instructions explicitly request it.
10. Preferred build for other Apple apps: add three separate rows under Support. Roadmap is always visible; Announcements and Ask are hidden unless Shipyard returns current displayable content for that row. Other Support features remain app-owned.
11. The Roadmap entry should open a Roadmap page in Settings or the nearest equivalent app area. It should let users submit Feature or Bug Fix requests, show active public items in their current status, and put a real tappable upvote button on each item.
12. Style the upvote button from app theme colors: quieter/duller when the install has not voted on that item, stronger/bolder after the install has voted.
13. Roadmap suggestions should only offer Feature and Bug Fix.
14. Use `syncDaily()` as the only passive lifecycle coordinator. It returns cached or fresh Roadmap and Engagement data, suppresses repeat same-day pulls, and retries incomplete content later without repeating the daily check-in.
15. Branch on `ask.type` and use `respondToAsk(...)` for every Ask type: single choice, multi choice, star rating, numeric rating, and open text.
16. Use `markAnnouncementShown(...)`, `dismissAnnouncement(...)`, and `clickAnnouncement(...)` for announcement tracking tied to actual UI display and interaction.
17. If the app opts into push notifications, call `registerNotificationSubscription(endpointToken:provider:environment:)` after APNs registration and `deleteNotificationSubscription(provider:)` when notifications are disabled.
18. Call `item.availabilityLabel(currentAppVersion:)` when rendering roadmap items with Shipyard release versions.
19. Show `item.targetDateLabel` and `item.developerRespondedAtRelativeLabel()` when present.
20. Call `submitItem(title:description:itemType:)` to create a moderated item.
21. Call `vote(itemId:unvote:)` for voting.
22. Treat `ShipyardError.offlineQueued` as a successful local save. The SDK persists the write and automatically retries when the device is online again.

## Upgrade From 0.2.2 To 0.2.3

- Replace passive lifecycle calls to `pullRoadmapDaily()`, `fetchEngagementUpdates()`, or `refreshCachedDataAndSyncQueuedWrites()` with `syncDaily()`.
- Move Roadmap, Announcements, and Ask into separate rows under Support. Keep only Roadmap permanently visible.
- Remove `force: true` from ordinary Roadmap opens.

## Upgrade From 0.2.0 To 0.2.1

- Replace deprecated lifecycle helpers and repeated Engagement refreshes with `syncDaily()` on launch and foreground resume.
- For visible Roadmap screens, render `cachedItems()` first, then run normal `pullRoadmapDaily()` and update only when it returns fresh content.
- Prefer `fetchAsks()` and `respondToAsk(...)` over compatibility helpers in new or touched Ask UI.
- Update site/admin usage summaries to prefer `dailyRoadmapPullRows` and `dailyRoadmapInstallCount`.
- Rename local setup references from `APPLE_TV_DAILY_ACTIVE_SETUP.md` to `APPLE_TV_ROADMAP_PULL_SETUP.md`.

## Native Mac Planner

Native planner/admin apps should use service API tokens passed explicitly to each service method. Do not use mobile feedback session tokens for planner administration.

Core planner calls:

- `fetchProducts(...)`: product list with planning fields, update priority, snoozed/paused display fields, and sorting/filtering. Use `includePriority: false`, `includeLatestUpdates: false`, and `includeSupport: false` for lightweight picker/list screens.
- `fetchProduct(slug:includePlanner:...)`: selected product plus release-grouped planner items.
- `updateProduct(slug:update:...)`: product planning fields such as product number, working version, status, and progress.
- `fetchPlannerCounts(...)`: waiting-review counts for native badges.
- `createPlannerItem(...)` / `updatePlannerItem(...)`: admin/internal planner item workflows.
- `createPlannerItems(...)` / `updatePlannerItems(...)`: bulk planning actions.
- `fetchPlannerTasks(...)`, `createPlannerTask(...)`, `updatePlannerTask(...)`, `deletePlannerTask(...)`: checklist tasks.

```swift
let products = try await client.fetchProducts(
    type: "app",
    sort: "update_priority_desc",
    workspaceSlug: "acme-studio",
    apiToken: serviceApiToken
)

let detail = try await client.fetchProduct(
    slug: "atlas",
    includePlanner: true,
    workspaceSlug: "acme-studio",
    apiToken: serviceApiToken
)

let groupedPlannerItems = detail.planner?.groups ?? []

_ = try await client.updateProduct(
    slug: "atlas",
    update: ShipyardProductUpdate(
        workingVersion: "1.4.0",
        workingVersionStatus: "building",
        workingVersionProgress: 70
    ),
    workspaceSlug: "acme-studio",
    apiToken: serviceApiToken
)

let item = try await client.createPlannerItem(
    ShipyardPlannerItemInput(
        title: "Polish native planner keyboard flow",
        productSlug: "atlas",
        status: "planned",
        visibility: "private",
        origin: "internal",
        itemType: "polish"
    ),
    workspaceSlug: "acme-studio",
    apiToken: serviceApiToken
)

_ = try await client.createPlannerTask(
    itemId: item.id,
    title: "Profile large release groups on macOS",
    workspaceSlug: "acme-studio",
    apiToken: serviceApiToken
)
```

## Background Roadmap Pull Only

For Apple TV or other apps where you only need daily Roadmap pull visibility, call `pullRoadmapDaily()` and do not wire the rest of the visible SDK surface.

```swift
Task {
    _ = try? await client.pullRoadmapDaily()
}
```

The SDK records the last successful UTC day in `UserDefaults`, so launch/resume calls on the same day only perform one background Roadmap pull. Use `force: true` only in debug verification.

## Cleanup After Install

If the app uses `ShipyardKit/swift` as a local Swift package, keep that folder in the repo. If the app uses a remote package URL or has moved the SDK into its own package structure, remove the copied top-level `ShipyardKit/` handoff folder after verifying Xcode no longer references the local path.

## Public API

```swift
let client = ShipyardClient(
    baseURL: URL(string: "https://acme-studio.startshipyard.com")!,
    productSlug: "atlas",
    installationIdProvider: { stableInstallationId() }
)

_ = try await client.refreshSession()
let daily = await client.syncDaily()
let cachedItems = await client.cachedItems()
let items = try await client.fetchItems()
let statusGroups = items.shipyardGroupedByStatus()
let categories = try await client.fetchItemCategories()
let updates = daily.engagementUpdates
let availability = items.first?.availabilityLabel(currentAppVersion: "1.0.2")
let target = items.first?.targetDateLabel
let replyTime = items.first?.developerRespondedAtRelativeLabel()
let item = try await client.submitItem(
    title: "Add offline mode",
    description: "Helpful for field teams.",
    itemType: .feature
)
let bug = try await client.submitItem(
    title: "Fix CSV export date formatting",
    description: nil,
    itemType: .bugfix
)
if let updates, let ask = updates.asks.first {
    switch ask.type {
    case .singleChoice:
        if let option = ask.options.first {
            _ = try await client.respondToAsk(askId: ask.id, optionId: option.id)
        }
    case .multiChoice:
        _ = try await client.respondToAsk(askId: ask.id, optionIds: ask.options.prefix(2).map(\.id))
    case .starRating, .numericRating:
        _ = try await client.respondToAsk(askId: ask.id, ratingValue: 5)
    case .openText:
        _ = try await client.respondToAsk(askId: ask.id, responseText: "This is working well.")
    case nil:
        break
    }
}
if let updates, let announcement = updates.announcements.first {
    _ = try await client.markAnnouncementShown(
        announcementId: announcement.id,
        visibleMs: 1500,
        screenKey: "dashboard"
    )
}
```

## Offline Behavior

ShipyardKit is ready for offline-first app surfaces:

- GET responses from Roadmap, Ask, Announcements, and engagement updates are cached in Application Support and returned when the device is offline.
- Offline writes from roadmap suggestion submission, voting, Ask responses, and announcement events are saved to a persisted queue without storing bearer tokens.
- The queue replays with a fresh mobile session token when connectivity returns, and apps can also force a pass with `syncQueuedWritesIfPossible()`.
- Only clearly offline transport failures are queued, so ambiguous failures that may have reached the server are not replayed blindly.

Recommended launch/resume hook:

```swift
.task {
    _ = await client.syncDaily()
}
.onChange(of: scenePhase) { phase in
    if phase == .active {
        Task {
            _ = await client.syncDaily()
        }
    }
}
```

Recommended offline write handling:

```swift
do {
    _ = try await client.submitItem(
        title: "Add offline mode",
        description: "Helpful for field teams.",
        itemType: .feature
    )
} catch ShipyardError.offlineQueued {
    // Show a saved/offline message and clear the local form.
} catch {
    // Show the real failure.
}
```

## Fallback Without SPM

If needed, copy `Sources/ShipyardKit/ShipyardClient.swift` directly into your app target. Prefer SwiftPM for versioning.
