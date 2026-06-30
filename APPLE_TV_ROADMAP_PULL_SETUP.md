# Apple TV Daily Roadmap Pull Setup

Use this path for Apple TV projects when Shipyard only needs daily Roadmap pull visibility.

Do not add visible Roadmap UI, Ask UI, Announcements, voting, inboxes, badges, or notification-style surfaces. The tvOS app should make one background Roadmap pull per day and otherwise stay unchanged.

## Required Shipyard Setup

- The Shipyard product must exist in the workspace.
- The product must be an app product in Shipyard. Product status does not block ShipyardKit mobile sessions.
- Use platform `tvos`.

## App Setup

1. Add `ShipyardKit/swift` as a local Swift package.
2. Add package product `ShipyardKit` to the tvOS app target.
3. Create one stable per-install ID and persist it. `UserDefaults` is acceptable for this background-pull mode; Keychain is also fine if the project already uses it.
4. Configure `ShipyardClient` with `baseURL`, `productSlug`, `platform: "tvos"`, and the install ID provider.
5. Call `pullRoadmapDaily()` on app launch.
6. Call it again when the app returns to active foreground state.

## Swift Example

```swift
import SwiftUI
import ShipyardKit

final class ShipyardTVRoadmapPuller {
    private let client: ShipyardClient

    init() {
        client = ShipyardClient(
            baseURL: URL(string: "https://acme-studio.startshipyard.com")!,
            productSlug: "atlas-tv",
            platform: "tvos",
            installationIdProvider: {
                let key = "shipyard.installationId"
                if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
                    return existing
                }
                let created = UUID().uuidString
                UserDefaults.standard.set(created, forKey: key)
                return created
            }
        )
    }

    func pullRoadmap() {
        Task {
            do {
                _ = try await client.pullRoadmapDaily()
            } catch {
                // Telemetry-only mode should not interrupt the tvOS experience.
            }
        }
    }
}

@main
struct AtlasTVApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let roadmapPuller = ShipyardTVRoadmapPuller()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    roadmapPuller.pullRoadmap()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        roadmapPuller.pullRoadmap()
                    }
                }
        }
    }
}
```

## Verification

- In a debug build, call `pullRoadmapDaily(force: true)` once to verify the server accepts the session and returns Roadmap data.
- Switch back to normal `pullRoadmapDaily()` before shipping.
- Confirm Shipyard Admin shows daily Roadmap pull activity for the tvOS product, app version, build number, and ShipyardKit version.

## Naming

- Daily Roadmap Pull: background Roadmap read used for app/platform/version activity visibility.
- Ask: answerable questions such as ratings, choices, and open text.
- Announcements: one-way messages pushed from Shipyard to the app.
