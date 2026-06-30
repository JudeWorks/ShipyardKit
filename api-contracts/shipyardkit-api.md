# ShipyardKit API Contract

## 1) Create mobile session

`POST /v1/auth/mobile/public-session`

### Request

```json
{
  "productSlug": "atlas",
  "installationId": "ios-install-abc123",
  "platform": "ios",
  "appVersion": "1.0.2",
  "buildNumber": "102",
  "shipyardKitVersion": "0.2.1",
  "sessionReason": "roadmap_pull"
}
```

### Success (201)

```json
{
  "token": "shipyard_mobile_feedback....",
  "expiresAt": "2026-05-13T21:15:10.000Z",
  "scopes": [
    "engagement:read_public_mobile",
    "engagement:respond_public_mobile",
    "requests:create_public_mobile",
    "requests:vote_public_mobile",
    "notifications:subscribe_public_mobile"
  ],
  "client": {
    "installationId": "ios-install-abc123",
    "platform": "ios",
    "appVersion": "1.0.2",
    "buildNumber": "102",
    "shipyardKitVersion": "0.2.1"
  }
}
```

ShipyardKit also sends `X-ShipyardKit-Version: 0.2.1` on SDK requests.

`pullRoadmapDaily()` maps to this endpoint and then reads `GET /v1/requests`. The SDK sends `sessionReason: "roadmap_pull"` when it refreshes the mobile session for that daily read. Shipyard records one app/platform/version activity row per UTC day per install, so the site can show which apps are using the Roadmap pull without presenting it as a separate outbound signal.

The target product must be an app product, but it does not need to be live. ShipyardKit mobile sessions work for app products in any product status.

### Errors

- `400`: invalid body or missing required fields
- `403`: product is not an app product
- `404`: product not found
- `429`: rate limited
- `503`: session signing not configured

## Mobile notification subscriptions

These routes use the short-lived token returned by `POST /v1/auth/mobile/public-session` and require the `notifications:subscribe_public_mobile` scope.

### Register or refresh subscription

`POST /v1/auth/mobile/notification-subscriptions`

```json
{
  "provider": "apns",
  "environment": "production",
  "endpointToken": "device-push-token",
  "enabled": true,
  "metadata": {
    "topic": "planner"
  }
}
```

Returns:

```json
{
  "subscription": {
    "id": "sub_123",
    "provider": "apns",
    "environment": "production",
    "platform": "ios",
    "enabled": true,
    "updatedAt": "2026-06-21T17:00:00.000Z"
  }
}
```

`ShipyardClient.registerNotificationSubscription(...)` maps to this endpoint.

### Disable subscription

`DELETE /v1/auth/mobile/notification-subscriptions`

```json
{
  "provider": "apns"
}
```

Returns:

```json
{
  "disabled": true,
  "count": 1
}
```

`ShipyardClient.deleteNotificationSubscription(...)` maps to this endpoint.

## Service API: web analytics

`GET /v1/analytics/web?ws=judeworks&hostname=www.judeworks.app&days=30`

This route is for authenticated admin tools and native dashboard apps. It does not use the mobile feedback session token.

### Headers

`Authorization: Bearer <service_api_key>`

The token must have `api:read`.

### Query params

- `days`: `7` or `30`; defaults to `7`
- `hostname`: optional hostname selector; must be one of the workspace's allowed hostnames
- `ws`: optional workspace slug override; use this when calling from a shared host such as `app.startshipyard.com`
- `productId`: optional app/clip product ID; when present, traffic is scoped to `/product/:slug` and `/landing/:slug`
- `refresh`: set to `1` to bypass the server-side cache

### Success (200)

```json
{
  "configured": true,
  "available": true,
  "error": null,
  "hostname": "www.judeworks.app",
  "days": 30,
  "scope": {
    "type": "site"
  },
  "totals": {
    "visits": 42,
    "uniqueVisitors": 18,
    "edgeResponseBytes": 123456
  },
  "trend": [
    {
      "date": "2026-06-01",
      "visits": 12,
      "uniqueVisitors": 6,
      "edgeResponseBytes": 3456
    }
  ],
  "topPaths": [
    {
      "path": "/",
      "visits": 30,
      "edgeResponseBytes": 100000
    }
  ],
  "allowedHostnames": [
    "judeworks.app",
    "www.judeworks.app",
    "judeworks.startshipyard.com"
  ],
  "selectedHostname": "www.judeworks.app",
  "cached": false,
  "refreshedAt": "2026-06-07T12:00:00.000Z",
  "expiresAt": "2026-06-07T12:15:00.000Z"
}
```

Notes:

- Active custom-domain workspaces expose the apex hostname, `www` hostname, and generated workspace hostname in `allowedHostnames`.
- `totals.uniqueVisitors` is a best-effort period unique-IP count; `trend[].uniqueVisitors` is the daily unique-IP count for that bucket. Both can be `null` when the Cloudflare GraphQL schema/token does not expose that metric.
- Product-scoped requests return `scope.type: "product"` with the selected product ID, slug, name, and path prefixes.
- If Cloudflare analytics is not configured or temporarily unavailable, the route returns the same shape with `available: false`, zero totals, empty arrays, and an `error` message.
- `ShipyardClient.fetchSiteAnalytics(...)` maps to this endpoint and requires an explicit service API token.

## Service API: App Store analytics

`GET /v1/analytics?ws=judeworks&days=30&productId=prod_123&activity=download&view=day`

This route is for authenticated admin tools and native dashboard apps. It returns the same App Store Connect analytics payload used by the admin analytics dashboard. It does not use the mobile feedback session token.

### Headers

`Authorization: Bearer <service_api_key>`

The token must have `api:read`.

### Query params

- `days`: `7`, `30`, `90`, or `180`; defaults to `30`
- `productId`: optional app/clip product ID; omit or use `all` for all apps
- `activity`: `download`, `paid`, `iap`, `purchase`, `update`, `redownload`, `sessions`, or `all`
- `view`: `day`, `week`, or `month`
- `ws`: optional workspace slug override

### Success (200)

The response includes:

- `studio`, `products`, `filters`, `connection`, and `freshness`
- chart metadata and trend buckets
- sales/download summaries, top apps, grouped app rows, recent daily breakdown, and unmapped sales
- App Store discovery and usage analytics under `appStoreEngagement`
- recent sync runs

`ShipyardClient.fetchAppAnalytics(...)` maps to this endpoint and requires an explicit service API token.

## Service API: create App Store Bundle ID

`POST /v1/analytics/app-store/bundle-ids?ws=judeworks`

Creates an explicit Bundle ID through the public App Store Connect API. This reserves the Bundle ID only; it does not claim the App Store app name.

### Headers

`Authorization: Bearer <service_api_key>`

The token must have `api:write`.

### Body

- `name`: required Bundle ID display name
- `identifier`: required reverse-DNS Bundle ID, for example `com.example.relaynotes`
- `platform`: optional `IOS`, `MAC_OS`, or `UNIVERSAL`; defaults to `IOS`

## Service API: start App Store analytics sync

`POST /v1/analytics/sync?ws=judeworks`

This route queues missing App Store analytics dates for the selected workspace.

### Headers

`Authorization: Bearer <service_api_key>`

The token must have `api:write`.

### Query params

- `ws`: optional workspace slug override
- `restart`: set to `force` to cancel the current active sync run and start fresh

`ShipyardClient.startAppAnalyticsSync(...)` maps to this endpoint and requires an explicit service API token.

## Service API: native product planner

These routes are for authenticated admin tools and native Mac planner apps. They do not use mobile feedback session tokens.

### Headers

`Authorization: Bearer <service_api_key>`

Reads require `api:read`. Writes require `api:write`.

### Product planning list

`GET /v1/products?ws=judeworks&type=app&sort=update_priority_desc`

Important query params:

- `ws`: optional workspace slug override
- `type`: `app` or `web`
- `visibility`: `public` or `private`
- `status`: product status filter
- `versionStatus` or `workingVersionStatus`: working-version status filter
- `workingVersion`: exact working-version filter
- `productNumber`: exact product-number filter
- `includePriority`: `0` or `1`, defaults to `1`. Set to `0` for lightweight product pickers. `sort=update_priority_*` forces priority on.
- `includeLatestUpdates`: `0` or `1`, defaults to `1`. Set to `0` to omit `latestUpdateAt` and `daysSinceLastUpdate`. Priority and days-since-update sorts force it on.
- `includeSupport`: `0` or `1`, defaults to `1`. Set to `0` to skip support-page lookup.
- `sort`: `name_asc`, `name_desc`, `progress_desc`, `progress_asc`, `product_number_asc`, `product_number_desc`, `status`, `version_status`, `working_version_asc`, `working_version_desc`, `days_since_update_asc`, `days_since_update_desc`, `update_priority_asc`, or `update_priority_desc`
- `minProgress` / `maxProgress`: progress range filters from `0` to `100`

Success returns:

```json
{
  "products": [
    {
      "id": "prod_123",
      "name": "Atlas",
      "slug": "atlas",
      "type": "app",
      "status": "active",
      "visibility": "private",
      "productNumber": "12",
      "workingVersion": "1.4.0",
      "workingVersionStatus": "building",
      "workingVersionProgress": 65,
      "planning": {
        "productNumber": "12",
        "workingVersion": "1.4.0",
        "workingVersionStatus": "building",
        "workingVersionProgress": 65
      },
      "latestUpdateAt": "2026-06-07T12:00:00.000Z",
      "daysSinceLastUpdate": 7,
      "updatePriority": {
        "rank": 1,
        "score": 88,
        "priorityType": "update_priority_snoozed",
        "basis": "update_priority_snooze",
        "updatePrioritySnoozedUntil": "2026-07-04T12:00:00.000Z"
      },
      "updatePriorityRank": 1,
      "updatePriorityScore": 88,
      "updatePriorityType": "update_priority_snoozed",
      "updatePriorityBasis": "update_priority_snooze",
      "updatePriorityPaused": true,
      "updatePriorityPausedUntil": "2026-07-04T12:00:00.000Z",
      "updatePrioritySnoozedUntil": "2026-07-04T12:00:00.000Z",
      "updatePriorityReviewSnoozedUntil": null,
      "updatePriorityRankLabel": "Paused",
      "updatePriorityLabel": "Snoozed",
      "updatePriorityDetail": "until Jul 4",
      "updatePriorityDisplayLabel": "Paused · until Jul 4 · Snoozed"
    }
  ]
}
```

`ShipyardClient.fetchProducts(...)` maps to this endpoint, including lightweight list controls via `includePriority`, `includeLatestUpdates`, and `includeSupport`.

### Product detail with release planner

`GET /v1/products/atlas?ws=judeworks&includePlanner=1`

Optional enrichment query params:

- `includePriority`: `0` or `1`, defaults to `1`
- `includeLatestUpdates`: `0` or `1`, defaults to `1`
- `includeSupport`: `0` or `1`, defaults to `1`

When `includePlanner=1`, the response includes private planner items and release-version groups:

```json
{
  "product": { "id": "prod_123", "name": "Atlas", "slug": "atlas" },
  "planner": {
    "items": [{ "id": "req_123", "title": "Compact dashboard", "status": "in_progress" }],
    "workingVersion": "1.4.0",
    "currentVersion": {
      "key": "version:1.4.0",
      "kind": "current",
      "title": "1.4.0",
      "releaseVersion": "1.4.0",
      "count": 1,
      "items": [{ "id": "req_123", "title": "Compact dashboard" }]
    },
    "futureVersions": [],
    "unassigned": {
      "key": "unassigned",
      "kind": "unassigned",
      "title": "Backlog / Unassigned",
      "releaseVersion": null,
      "count": 0,
      "items": []
    },
    "groups": []
  }
}
```

`ShipyardClient.fetchProduct(slug:includePlanner:...)` maps to this endpoint.

### Product planning update

`PATCH /v1/products/:slug`

Common planner fields:

```json
{
  "productNumber": "12",
  "workingVersion": "1.4.0",
  "workingVersionStatus": "building",
  "workingVersionProgress": 70
}
```

Returns `{ "product": { ... } }`.

`ShipyardClient.updateProduct(slug:update:...)` maps to this endpoint.

### Planner item create/update/bulk

- `GET /v1/requests/counts`
- `POST /v1/requests`
- `PATCH /v1/requests/:id`
- `POST /v1/requests/bulk`
- `PATCH /v1/requests/bulk`

Service-token planner writes may set admin-only fields such as `status`, `visibility`, `origin`, `notes`, `developerResponse`, `developerResponsePublic`, `itemType`, `releaseVersion`, `sortOrder`, `targetDate`, `productId`, and `linkedPostId`.

`ShipyardClient.fetchPlannerCounts(...)`, `createPlannerItem(...)`, `updatePlannerItem(...)`, `createPlannerItems(...)`, and `updatePlannerItems(...)` map to these endpoints.

### Planner tasks

- `GET /v1/requests/:id/tasks`
- `POST /v1/requests/:id/tasks`
- `PATCH /v1/requests/:id/tasks/:taskId`
- `DELETE /v1/requests/:id/tasks/:taskId`

Task payload:

```json
{
  "title": "Profile list rendering",
  "isDone": false,
  "orderIndex": 0
}
```

`ShipyardClient.fetchPlannerTasks(...)`, `createPlannerTask(...)`, `updatePlannerTask(...)`, and `deletePlannerTask(...)` map to these endpoints.

## 2) Engagement updates

`GET /v1/engagement/updates?product=atlas`

Recommended mobile clients call this when opening Announcements or Ask surfaces. ShipyardKit caches this authenticated engagement read for 15 minutes by default; use `cachePolicy: .reloadIgnoringCache` only for deliberate user-initiated refreshes. Use `pullRoadmapDaily()` on app launch and foreground resume for daily Roadmap pull visibility.

### Headers

`Authorization: Bearer <mobile_feedback_token>`

### Success (200)

Returns:

```json
{
  "asks": [
    {
      "id": "ask_123",
      "title": "How satisfied are you with Atlas sync speed?",
      "promptType": "star_rating",
      "status": "live",
      "resultsVisibility": "show_after_vote",
      "minRating": 1,
      "maxRating": 5,
      "startsAt": "2026-05-20T18:00:00.000Z",
      "endsAt": "2026-06-01T18:00:00.000Z",
      "state": "live",
      "responseCount": 54,
      "averageRating": 4.2,
      "options": [],
      "myResponse": null,
      "resultsVisible": false
    }
  ],
  "announcements": [
    {
      "id": "announcement_123",
      "title": "New export filters are live",
      "body": "Open Reports to try the updated export flow.",
      "ctaLabel": "Open Reports",
      "ctaUrl": "atlas://reports",
      "status": "live",
      "priority": 10,
      "clearable": true,
      "showOnce": false,
      "startsAt": "2026-05-20T18:00:00.000Z",
      "endsAt": "2026-06-01T18:00:00.000Z",
      "state": "live",
      "shownCount": 321,
      "dismissCount": 42,
      "clickCount": 17,
      "myState": null
    }
  ],
  "refreshedAt": "2026-05-28T20:30:00.000Z"
}
```

Notes:

- Use this as the default app pull for current Engagement content.
- Add `?history=1` to include non-live items when the app needs history screens.
- `fetchEngagementUpdates()` maps to this endpoint. Use `updates.asks` in new SDK integrations.
- Default SDK reads use a 15-minute cache to prevent repeated lifecycle or view-render requests from becoming excessive API traffic.

## 3) Public Ask only

`GET /v1/engagement/asks?product=atlas`

### Headers

`Authorization: Bearer <mobile_feedback_token>`

### Success (200)

Returns `{ "asks": [{ ... }] }`. Legacy response keys remain for older SDK clients.

`fetchAsks()` maps to this endpoint.

Compatibility alias:

- `GET /v1/engagement/prompts?product=atlas`

## 4) Public announcements only

`GET /v1/engagement/announcements?product=atlas`

### Headers

`Authorization: Bearer <mobile_feedback_token>`

### Success (200)

Returns `{ "announcements": [{ ... }] }`.

`fetchAnnouncements()` maps to this endpoint.

## 5) Respond to Ask

`POST /v1/engagement/asks/:id/respond`

### Headers

`Authorization: Bearer <mobile_feedback_token>`

### Request examples

Single choice:

```json
{
  "optionId": "opt_123"
}
```

Multi choice:

```json
{
  "optionIds": ["opt_123", "opt_456"]
}
```

Rating:

```json
{
  "ratingValue": 4
}
```

Open text:

```json
{
  "responseText": "Search feels much faster in this build."
}
```

### Success (200)

Returns:

```json
{
  "ok": true,
  "ask": {
    "id": "ask_123"
  }
}
```

Notes:

- Shipyard stores one current response per install for each Ask.
- Re-sending a response updates the same install's answer.
- Mobile UI should branch on `promptType` or ShipyardKit's `ask.type` helper and support all current values: `single_choice`, `multi_choice`, `star_rating`, `numeric_rating`, and `open_text`.
- For `multi_choice`, respect `maxSelections` when it is present.
- `respondToAsk(...)` maps to this endpoint.

Compatibility alias:

- `POST /v1/engagement/prompts/:id/respond`

## 6) Record announcement event

`POST /v1/engagement/announcements/:id/events`

### Headers

`Authorization: Bearer <mobile_feedback_token>`

### Request

```json
{
  "eventType": "shown",
  "visibleMs": 1200,
  "screenKey": "home"
}
```

Supported `eventType` values:

- `shown`
- `dismissed`
- `clicked`

### Success (200)

Returns:

```json
{
  "ok": true,
  "announcement": {
    "id": "announcement_123"
  }
}
```

Notes:

- Only call `shown` after the announcement is actually visible on screen.
- `dismissed` is only valid for clearable announcements.
- `markAnnouncementShown(...)`, `dismissAnnouncement(...)`, `clickAnnouncement(...)`, and `recordAnnouncementEvent(...)` map to this endpoint.

## 7) Public item listing

`GET /v1/requests?product=atlas`

### Success (200)

Returns `{ "requests": [{ ... }] }`.

Each request may include roadmap release fields:

```json
{
  "id": "req_123",
  "title": "Compact dashboard widgets",
  "status": "in_progress",
  "itemType": "feature",
  "voteCount": 12,
  "releaseVersion": "1.2.3",
  "targetDate": "2026-07-01",
  "developerResponse": "We are testing this now.\n\n- Keeps bullets\n- Keeps spacing",
  "developerResponsePublic": true,
  "developerRespondedAt": "2026-05-26T05:00:00.000Z"
}
```

`releaseVersion` is set in Shipyard admin/planner. ShipyardKit uses it with the app's installed version to produce user-facing labels:

- `planned` or `in_progress` + `releaseVersion`: `Coming in 1.2.3`
- `shipped` + installed version older than `releaseVersion`: `Update to get this`
- `shipped` + installed version at or newer than `releaseVersion`: `Included in your version`
- `shipped` without `releaseVersion`: `Shipped`

ShipyardKit exposes both raw and presentation-ready reads:

- `fetchItems()` returns the API items.
- `cachedItems()` returns the last stored Roadmap items without network access, which lets the app render Roadmap immediately when a cached response exists.
- When a user opens Roadmap, render `cachedItems()` first, then call `pullRoadmapDaily(force: true)` in the background and update the visible groups if the fresh response differs.
- `fetchItems().shipyardGroupedByStatus()` groups items into Open, Planned, In Progress, Shipped, and Closed sections. Items inside each section are sorted from most upvoted to least upvoted.
- `fetchItemCategories()` groups items into planner item-type categories, sorts categories by total votes, and sorts each category's items from most upvoted to least upvoted.
- `ShipyardItem.availabilityLabel(currentAppVersion:)` returns version-aware display text when the item has enough release data.
- `ShipyardItem.targetDateLabel` returns labels such as `Target Mar 2026` when `targetDate` is present.
- `ShipyardItem.developerResponseText` returns the published developer response, or `nil` when no response is public. Render it as multiline text so spacing, bullets, and line breaks are preserved.
- `ShipyardItem.developerRespondedAtRelativeLabel()` returns labels such as `Dev replied 3d ago` when `developerRespondedAt` is present.
- `ShipyardDateParser.date(from:)` accepts Shipyard ISO dates with fractional seconds, without fractional seconds, or date-only strings.

Use `shipyardGroupedByStatus()` for roadmap lifecycle views. Use `fetchItemCategories()` when the app specifically wants planner item-type sections.

## 8) Create roadmap suggestion

`POST /v1/requests`

### Headers

`Authorization: Bearer <mobile_feedback_token>`

### Request

```json
{
  "title": "Add keyboard shortcuts to quick actions",
  "description": "Would help power users move faster.",
  "itemType": "feature"
}
```

`itemType` is optional and defaults to `feature`. Public/mobile roadmap suggestions may send only:

- `bugfix`
- `feature`

Authenticated admin/planner callers may still use the broader internal planner item-type set.

### Success (201)

Returns `{ "request": { ... } }`.

The created request lands in:

- `status: "waiting_review"`
- `origin: "user"`
- `visibility: "public"`
- product bound to the scoped token's product

### Queued success (202)

Mobile clients can opt into queued writes by sending `Prefer: respond-async`, adding `?async=1`, or setting `"queue": true` in the JSON body.

```json
{
  "queued": true,
  "jobId": "job_abc123",
  "status": "queued"
}
```

## 9) Vote / unvote

`POST /v1/requests/:id/vote`

### Headers

`Authorization: Bearer <mobile_feedback_token>`

### Vote request body

```json
{
  "unvote": false
}
```

### Unvote request body

```json
{
  "unvote": true
}
```

### Success (200)

Returns `{ "request": { ... } }` plus vote state hints such as:

- `alreadyVoted: true`
- `alreadyUnvoted: true`
- `unvoted: true`

### Queued success (202)

Mobile clients can opt into queued votes with `Prefer: respond-async`, `?async=1`, or `"queue": true`.

```json
{
  "queued": true,
  "jobId": "job_abc123",
  "status": "queued",
  "request": { }
}
```
