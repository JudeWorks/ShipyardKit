import XCTest
@testable import ShipyardKit

final class ShipyardMockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class ShipyardKitTests: XCTestCase {
    override func tearDown() {
        ShipyardMockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testModuleCompiles() {
        XCTAssertTrue(true)
    }

    func testInferredPlatformIsNotEmpty() {
        XCTAssertFalse(ShipyardClient.inferredPlatform().isEmpty)
    }

    func testSDKVersionIsSentWithSessionRequests() async throws {
        let productSlug = "sdk-version-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/mobile/public-session")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-ShipyardKit-Version"), ShipyardClient.sdkVersion)
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "ShipyardKit/\(ShipyardClient.sdkVersion)")
            let body = try Self.requestJSONBody(request)
            XCTAssertEqual(body["shipyardKitVersion"] as? String, ShipyardClient.sdkVersion)
            XCTAssertEqual(body["appVersion"] as? String, "1.0")
            XCTAssertEqual(body["buildNumber"] as? String, "1")
            return try Self.jsonResponse(
                for: request,
                status: 201,
                body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
            )
        }

        _ = try await client.refreshSession()
    }

    func testFetchSiteAnalyticsUsesServiceApiTokenAndDecodesHostnames() async throws {
        let productSlug = "site-analytics-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/analytics/web")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer service-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-ShipyardKit-Version"), ShipyardClient.sdkVersion)

            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(queryItems["days"], "30")
            XCTAssertEqual(queryItems["hostname"], "www.judeworks.app")
            XCTAssertEqual(queryItems["ws"], "judeworks")
            XCTAssertEqual(queryItems["productId"], "prod_123")
            XCTAssertEqual(queryItems["refresh"], "1")

            return try Self.jsonResponse(
                for: request,
                status: 200,
                jsonObject: [
                    "configured": true,
                    "available": true,
                    "error": NSNull(),
                    "hostname": "www.judeworks.app",
                    "days": 30,
                    "scope": [
                        "type": "product",
                        "productId": "prod_123",
                        "productSlug": "atlas",
                        "productName": "Atlas",
                        "pathPrefixes": ["/product/atlas", "/landing/atlas"]
                    ],
                    "totals": [
                        "visits": 42,
                        "edgeResponseBytes": 123456
                    ],
                    "trend": [
                        [
                            "date": "2026-06-01",
                            "visits": 12,
                            "edgeResponseBytes": 3456
                        ]
                    ],
                    "topPaths": [
                        [
                            "path": "/",
                            "visits": 30,
                            "edgeResponseBytes": 100000
                        ]
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
                ]
            )
        }

        let analytics = try await client.fetchSiteAnalytics(
            days: 30,
            hostname: "www.judeworks.app",
            workspaceSlug: "judeworks",
            productId: "prod_123",
            refresh: true,
            apiToken: "service-token"
        )

        XCTAssertTrue(analytics.available)
        XCTAssertEqual(analytics.selectedHostname, "www.judeworks.app")
        XCTAssertEqual(analytics.scope?.productSlug, "atlas")
        XCTAssertEqual(analytics.scope?.pathPrefixes ?? [], ["/product/atlas", "/landing/atlas"])
        XCTAssertEqual(analytics.allowedHostnames, ["judeworks.app", "www.judeworks.app", "judeworks.startshipyard.com"])
        XCTAssertEqual(analytics.totals.visits, 42)
        XCTAssertEqual(analytics.trend.first?.date, "2026-06-01")
        XCTAssertEqual(analytics.topPaths.first?.path, "/")
    }

    func testFetchAppAnalyticsUsesServiceApiTokenAndDecodesOverview() async throws {
        let productSlug = "app-analytics-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/analytics")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer service-token")

            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(queryItems["days"], "90")
            XCTAssertEqual(queryItems["productId"], "prod_123")
            XCTAssertEqual(queryItems["view"], "week")
            XCTAssertEqual(queryItems["activity"], "sessions")
            XCTAssertEqual(queryItems["ws"], "judeworks")

            return try Self.jsonResponse(for: request, status: 200, jsonObject: Self.appAnalyticsObject())
        }

        let analytics = try await client.fetchAppAnalytics(
            days: 90,
            productId: "prod_123",
            view: "week",
            activity: "sessions",
            workspaceSlug: "judeworks",
            apiToken: "service-token"
        )

        XCTAssertEqual(analytics.studio?.slug, "judeworks")
        XCTAssertEqual(analytics.products.first?.name, "Atlas")
        XCTAssertEqual(analytics.filters.activity, "sessions")
        XCTAssertEqual(analytics.summary.totalUnits, 44)
        XCTAssertEqual(analytics.appStoreEngagement.totals.sessions, 44)
        XCTAssertEqual(analytics.trend.first?.tooltip, "2026-06-01 to 2026-06-07")
        XCTAssertEqual(analytics.groupedApps.first?.productName, "Atlas")
        XCTAssertEqual(analytics.recentBreakdown.first?.date, "2026-06-07")
        XCTAssertEqual(analytics.syncRuns.first?.status, "completed")
    }

    func testStartAppAnalyticsSyncUsesServiceApiToken() async throws {
        let productSlug = "app-analytics-sync-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/analytics/sync")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer service-token")

            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(queryItems["ws"], "judeworks")
            XCTAssertEqual(queryItems["restart"], "force")

            return try Self.jsonResponse(
                for: request,
                status: 200,
                jsonObject: [
                    "ok": true,
                    "started": true,
                    "runId": "sync_123",
                    "queueJobId": "job_123",
                    "cancelledRunId": NSNull(),
                    "queuedDates": 2,
                    "range": ["from": "2026-06-06", "to": "2026-06-07"]
                ]
            )
        }

        let result = try await client.startAppAnalyticsSync(
            workspaceSlug: "judeworks",
            restart: true,
            apiToken: "service-token"
        )

        XCTAssertTrue(result.ok)
        XCTAssertTrue(result.started)
        XCTAssertEqual(result.runId, "sync_123")
        XCTAssertEqual(result.range?.to, "2026-06-07")
    }

    func testFetchProductsUsesServiceTokenAndDecodesPlanningFields() async throws {
        let client = makeMockClient(productSlug: "planner-products-\(UUID().uuidString)")
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/products")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer service-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-ShipyardKit-Version"), ShipyardClient.sdkVersion)

            let queryItems = try Self.queryItems(request)
            XCTAssertEqual(queryItems["ws"], "judeworks")
            XCTAssertEqual(queryItems["type"], "app")
            XCTAssertEqual(queryItems["sort"], "update_priority_desc")
            XCTAssertEqual(queryItems["minProgress"], "20")

            return try Self.jsonResponse(
                for: request,
                status: 200,
                jsonObject: [
                    "products": [
                        Self.productObject(
                            id: "prod_123",
                            name: "Atlas",
                            slug: "atlas",
                            workingVersion: "1.4.0",
                            workingVersionStatus: "building",
                            workingVersionProgress: 65
                        )
                    ]
                ]
            )
        }

        let products = try await client.fetchProducts(
            type: "app",
            sort: "update_priority_desc",
            minProgress: 20,
            workspaceSlug: "judeworks",
            apiToken: "service-token"
        )

        XCTAssertEqual(products.map(\.slug), ["atlas"])
        XCTAssertEqual(products.first?.planning?.workingVersion, "1.4.0")
        XCTAssertEqual(products.first?.workingVersionProgress, 65)
        XCTAssertEqual(products.first?.updatePriority?.priorityType, "update_priority_snoozed")
        XCTAssertEqual(products.first?.updatePriorityPaused, true)
        XCTAssertEqual(products.first?.updatePriorityPausedUntil, "2026-07-04T12:00:00.000Z")
        XCTAssertEqual(products.first?.updatePriorityDisplayLabel, "Paused · until Jul 4 · Snoozed")
    }

    func testFetchProductsCanRequestLightweightList() async throws {
        let client = makeMockClient(productSlug: "planner-products-light-\(UUID().uuidString)")
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/products")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer service-token")

            let queryItems = try Self.queryItems(request)
            XCTAssertEqual(queryItems["includePriority"], "0")
            XCTAssertEqual(queryItems["includeLatestUpdates"], "0")
            XCTAssertEqual(queryItems["includeSupport"], "0")

            var product = Self.productObject(id: "prod_123", name: "Atlas", slug: "atlas")
            [
                "latestUpdateAt",
                "daysSinceLastUpdate",
                "updatePriority",
                "updatePriorityRank",
                "updatePriorityScore",
                "updatePriorityType",
                "updatePriorityBasis",
                "updatePriorityPaused",
                "updatePriorityPausedUntil",
                "updatePrioritySnoozedUntil",
                "updatePriorityReviewSnoozedUntil",
                "updatePriorityRankLabel",
                "updatePriorityLabel",
                "updatePriorityDetail",
                "updatePriorityDisplayLabel",
                "supportUrl"
            ].forEach { product.removeValue(forKey: $0) }

            return try Self.jsonResponse(
                for: request,
                status: 200,
                jsonObject: [
                    "products": [product]
                ]
            )
        }

        let products = try await client.fetchProducts(
            includePriority: false,
            includeLatestUpdates: false,
            includeSupport: false,
            apiToken: "service-token"
        )

        XCTAssertEqual(products.map(\.slug), ["atlas"])
        XCTAssertNil(products.first?.updatePriority)
        XCTAssertNil(products.first?.latestUpdateAt)
        XCTAssertNil(products.first?.supportUrl)
    }

    func testFetchProductIncludesNativePlannerReleaseGroups() async throws {
        let client = makeMockClient(productSlug: "planner-detail-\(UUID().uuidString)")
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/products/atlas")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer service-token")
            let queryItems = try Self.queryItems(request)
            XCTAssertEqual(queryItems["includePlanner"], "1")
            XCTAssertEqual(queryItems["ws"], "judeworks")

            let item = Self.requestObject(
                id: "req_1",
                title: "Native planner polish",
                status: "in_progress",
                itemType: "polish",
                voteCount: 7,
                releaseVersion: "1.4.0"
            )
            return try Self.jsonResponse(
                for: request,
                status: 200,
                jsonObject: [
                    "product": Self.productObject(
                        id: "prod_123",
                        name: "Atlas",
                        slug: "atlas",
                        workingVersion: "1.4.0"
                    ),
                    "planner": [
                        "items": [item],
                        "workingVersion": "1.4.0",
                        "currentVersion": [
                            "key": "version:1.4.0",
                            "kind": "current",
                            "title": "1.4.0",
                            "releaseVersion": "1.4.0",
                            "count": 1,
                            "items": [item]
                        ],
                        "futureVersions": [],
                        "unassigned": [
                            "key": "unassigned",
                            "kind": "unassigned",
                            "title": "Backlog / Unassigned",
                            "releaseVersion": NSNull(),
                            "count": 0,
                            "items": []
                        ],
                        "groups": [
                            [
                                "key": "version:1.4.0",
                                "kind": "current",
                                "title": "1.4.0",
                                "releaseVersion": "1.4.0",
                                "count": 1,
                                "items": [item]
                            ]
                        ]
                    ]
                ]
            )
        }

        let detail = try await client.fetchProduct(
            slug: "atlas",
            workspaceSlug: "judeworks",
            apiToken: "service-token"
        )

        XCTAssertEqual(detail.product.slug, "atlas")
        XCTAssertEqual(detail.planner?.workingVersion, "1.4.0")
        XCTAssertEqual(detail.planner?.currentVersion?.items.first?.type, .polish)
        XCTAssertEqual(detail.planner?.currentVersion?.items.first?.visibility, "private")
        XCTAssertEqual(detail.planner?.currentVersion?.items.first?.sortOrder, 12)
        XCTAssertEqual(detail.planner?.groups.first?.count, 1)
    }

    func testUpdateProductPlanningUsesServiceWriteToken() async throws {
        let client = makeMockClient(productSlug: "planner-update-product-\(UUID().uuidString)")
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/products/atlas")
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer service-token")
            let body = try Self.requestJSONBody(request)
            XCTAssertEqual(body["workingVersion"] as? String, "1.4.0")
            XCTAssertEqual(body["workingVersionStatus"] as? String, "building")
            XCTAssertEqual(body["workingVersionProgress"] as? Int, 70)

            return try Self.jsonResponse(
                for: request,
                status: 200,
                jsonObject: [
                    "product": Self.productObject(
                        id: "prod_123",
                        name: "Atlas",
                        slug: "atlas",
                        workingVersion: "1.4.0",
                        workingVersionStatus: "building",
                        workingVersionProgress: 70
                    )
                ]
            )
        }

        let product = try await client.updateProduct(
            slug: "atlas",
            update: ShipyardProductUpdate(
                workingVersion: "1.4.0",
                workingVersionStatus: "building",
                workingVersionProgress: 70
            ),
            apiToken: "service-token"
        )

        XCTAssertEqual(product.workingVersion, "1.4.0")
        XCTAssertEqual(product.workingVersionProgress, 70)
    }

    func testPlannerItemAndTaskServiceWritesUseExpectedPayloads() async throws {
        let client = makeMockClient(productSlug: "planner-writes-\(UUID().uuidString)")
        await client.clearOfflineData()
        var paths: [String] = []

        ShipyardMockURLProtocol.requestHandler = { request in
            paths.append(request.url?.path ?? "")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer service-token")

            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/v1/requests"):
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["title"] as? String, "Build fast Mac planner")
                XCTAssertEqual(body["productSlug"] as? String, "atlas")
                XCTAssertEqual(body["status"] as? String, "planned")
                XCTAssertEqual(body["visibility"] as? String, "private")
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    jsonObject: [
                        "request": Self.requestObject(
                            id: "req_1",
                            title: "Build fast Mac planner",
                            status: "planned",
                            itemType: "feature",
                            voteCount: 1
                        )
                    ]
                )
            case ("PATCH", "/v1/requests/req_1"):
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["status"] as? String, "in_progress")
                XCTAssertEqual(body["releaseVersion"] as? String, "1.4.0")
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    jsonObject: [
                        "request": Self.requestObject(
                            id: "req_1",
                            title: "Build fast Mac planner",
                            status: "in_progress",
                            itemType: "feature",
                            voteCount: 1,
                            releaseVersion: "1.4.0"
                        )
                    ]
                )
            case ("GET", "/v1/requests/req_1/tasks"):
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    jsonObject: [
                        "request": Self.requestObject(id: "req_1", title: "Build fast Mac planner"),
                        "tasks": [
                            Self.taskObject(id: "task_1", requestId: "req_1", title: "Profile list rendering", isDone: false)
                        ]
                    ]
                )
            case ("POST", "/v1/requests/req_1/tasks"):
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["title"] as? String, "Profile list rendering")
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    jsonObject: [
                        "task": Self.taskObject(id: "task_1", requestId: "req_1", title: "Profile list rendering", isDone: false)
                    ]
                )
            case ("PATCH", "/v1/requests/req_1/tasks/task_1"):
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["isDone"] as? Bool, true)
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    jsonObject: [
                        "task": Self.taskObject(id: "task_1", requestId: "req_1", title: "Profile list rendering", isDone: true)
                    ]
                )
            case ("DELETE", "/v1/requests/req_1/tasks/task_1"):
                return try Self.jsonResponse(for: request, status: 200, jsonObject: ["ok": true])
            default:
                return try Self.jsonResponse(for: request, status: 404, body: #"{"error":"not found"}"#)
            }
        }

        let item = try await client.createPlannerItem(
            ShipyardPlannerItemInput(
                title: "Build fast Mac planner",
                productSlug: "atlas",
                status: "planned",
                visibility: "private",
                itemType: "feature"
            ),
            apiToken: "service-token"
        )
        let updated = try await client.updatePlannerItem(
            itemId: item.id,
            update: ShipyardPlannerItemUpdate(status: "in_progress", releaseVersion: "1.4.0"),
            apiToken: "service-token"
        )
        let tasks = try await client.fetchPlannerTasks(itemId: item.id, apiToken: "service-token")
        let createdTask = try await client.createPlannerTask(itemId: item.id, title: "Profile list rendering", apiToken: "service-token")
        let updatedTask = try await client.updatePlannerTask(
            itemId: item.id,
            taskId: createdTask.id,
            update: ShipyardPlannerTaskInput(isDone: true),
            apiToken: "service-token"
        )
        let deleted = try await client.deletePlannerTask(itemId: item.id, taskId: createdTask.id, apiToken: "service-token")

        XCTAssertEqual(updated.status, "in_progress")
        XCTAssertEqual(tasks.tasks.first?.title, "Profile list rendering")
        XCTAssertTrue(updatedTask.isDone)
        XCTAssertTrue(deleted)
        XCTAssertEqual(paths, [
            "/v1/requests",
            "/v1/requests/req_1",
            "/v1/requests/req_1/tasks",
            "/v1/requests/req_1/tasks",
            "/v1/requests/req_1/tasks/task_1",
            "/v1/requests/req_1/tasks/task_1"
        ])
    }

    func testDailyRoadmapPullRunsOncePerUTCDate() async throws {
        let productSlug = "daily-roadmap-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()
        let suiteName = "ShipyardKitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var sessionRequestCount = 0
        var roadmapRequestCount = 0

        ShipyardMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/v1/auth/mobile/public-session":
                sessionRequestCount += 1
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["sessionReason"] as? String, "roadmap_pull")
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
                )
            case "/v1/requests":
                roadmapRequestCount += 1
                let queryItems = try Self.queryItems(request)
                XCTAssertEqual(queryItems["product"], productSlug)
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    body: #"{"requests":[{"id":"req_daily","title":"Daily roadmap","description":null,"status":"open","itemType":"feature","voteCount":4}]}"#
                )
            default:
                return try Self.jsonResponse(for: request, status: 404, body: #"{"error":"not found"}"#)
            }
        }

        let first = try await client.pullRoadmapDaily(
            date: Date(timeIntervalSince1970: 1_779_811_200),
            userDefaults: defaults
        )
        let second = try await client.pullRoadmapDaily(
            date: Date(timeIntervalSince1970: 1_779_814_800),
            userDefaults: defaults
        )
        let nextDay = try await client.pullRoadmapDaily(
            date: Date(timeIntervalSince1970: 1_779_897_600),
            userDefaults: defaults
        )

        XCTAssertEqual(first?.map(\.id), ["req_daily"])
        XCTAssertNil(second)
        XCTAssertEqual(nextDay?.map(\.id), ["req_daily"])
        XCTAssertEqual(sessionRequestCount, 2)
        XCTAssertEqual(roadmapRequestCount, 2)
    }

    func testFetchAsksUsesAskEndpointAndDecodesAskPayload() async throws {
        let productSlug = "asks-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/v1/auth/mobile/public-session":
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
                )
            case "/v1/engagement/asks":
                let ask = Self.promptObject(id: "ask_1", promptType: "open_text")
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    jsonObject: [
                        "asks": [ask],
                        "prompts": [ask]
                    ]
                )
            default:
                return try Self.jsonResponse(for: request, status: 404, body: #"{"error":"not found"}"#)
            }
        }

        let asks = try await client.fetchAsks()

        XCTAssertEqual(asks.map(\.id), ["ask_1"])
        XCTAssertEqual(asks.first?.type, .openText)
    }

    func testPlannerItemTypesAreSupported() {
        XCTAssertEqual(
            ShipyardItemType.allCases.map(\.rawValue),
            ["idea", "update", "bugfix", "tweak", "polish", "feature", "launch"]
        )
        XCTAssertEqual(ShipyardItemType.polish.title, "Polish")
        XCTAssertEqual(ShipyardItem(id: "1", title: "Launch checklist", description: nil, status: "planned", itemType: "launch", voteCount: 1).type, .launch)
    }

    func testItemsGroupByCategoryAndSortByVotes() {
        let items = [
            ShipyardItem(id: "1", title: "Small feature", description: nil, status: "open", itemType: "feature", voteCount: 2),
            ShipyardItem(id: "2", title: "Critical crash", description: nil, status: "open", itemType: "bugfix", voteCount: 8),
            ShipyardItem(id: "3", title: "Big feature", description: nil, status: "open", itemType: "feature", voteCount: 10),
            ShipyardItem(id: "4", title: "Minor bug", description: nil, status: "open", itemType: "bugfix", voteCount: 1)
        ]

        let categories = items.shipyardGroupedByCategory()

        XCTAssertEqual(categories.map(\.itemType), [.feature, .bugfix])
        XCTAssertEqual(categories.map(\.totalVotes), [12, 9])
        XCTAssertEqual(categories[0].items.map(\.id), ["3", "1"])
        XCTAssertEqual(categories[1].items.map(\.id), ["2", "4"])
    }

    func testItemsGroupByStatusInLifecycleOrderAndSortByVotes() {
        let items = [
            ShipyardItem(id: "1", title: "Shipped low", description: nil, status: "shipped", itemType: "feature", voteCount: 1),
            ShipyardItem(id: "2", title: "Open high", description: nil, status: "open", itemType: "feature", voteCount: 9),
            ShipyardItem(id: "3", title: "In progress", description: nil, status: "in_progress", itemType: "feature", voteCount: 5),
            ShipyardItem(id: "4", title: "Open low", description: nil, status: "open", itemType: "bugfix", voteCount: 2),
            ShipyardItem(id: "5", title: "Planned", description: nil, status: "planned", itemType: "feature", voteCount: 4)
        ]

        let groups = items.shipyardGroupedByStatus()

        XCTAssertEqual(groups.map(\.status), ["open", "planned", "in_progress", "shipped"])
        XCTAssertEqual(groups[0].items.map(\.id), ["2", "4"])
    }

    func testAvailabilityLabelsUseReleaseVersionAndCurrentAppVersion() {
        let upcoming = ShipyardItem(
            id: "1",
            title: "Compact dashboard",
            description: nil,
            status: "in_progress",
            itemType: "feature",
            voteCount: 4,
            releaseVersion: "1.2.3"
        )
        let shipped = ShipyardItem(
            id: "2",
            title: "Export fixes",
            description: nil,
            status: "shipped",
            itemType: "bugfix",
            voteCount: 3,
            releaseVersion: "1.2.3"
        )

        XCTAssertEqual(upcoming.availabilityLabel(currentAppVersion: "1.2.0"), "Coming in 1.2.3")
        XCTAssertEqual(shipped.availabilityLabel(currentAppVersion: "1.2.0"), "Update to get this")
        XCTAssertEqual(shipped.availabilityLabel(currentAppVersion: "1.2.3"), "Included in your version")
        XCTAssertEqual(shipped.availabilityLabel(currentAppVersion: "1.3.0"), "Included in your version")
    }

    func testDeveloperResponseOnlyShowsWhenPublic() {
        let publicResponse = ShipyardItem(
            id: "1",
            title: "Import status",
            description: nil,
            status: "planned",
            itemType: "feature",
            voteCount: 5,
            developerResponse: "We are testing this now.\n\n- Keeps bullets\n- Keeps spacing",
            developerResponsePublic: true
        )
        let privateResponse = ShipyardItem(
            id: "2",
            title: "Internal response",
            description: nil,
            status: "planned",
            itemType: "feature",
            voteCount: 1,
            developerResponse: "Draft only",
            developerResponsePublic: false
        )

        XCTAssertEqual(publicResponse.developerResponseText, "We are testing this now.\n\n- Keeps bullets\n- Keeps spacing")
        XCTAssertNil(privateResponse.developerResponseText)
    }

    func testFractionalSecondDatesParse() {
        let date = ShipyardDateParser.date(from: "2026-05-28T04:28:18.572Z")
        XCTAssertNotNil(date)
    }

    func testTargetDateAndDeveloperReplyLabels() {
        let item = ShipyardItem(
            id: "1",
            title: "Timeline polish",
            description: nil,
            status: "planned",
            itemType: "feature",
            voteCount: 1,
            targetDate: "2026-03-15",
            developerRespondedAt: "2026-05-28T04:28:18.572Z"
        )

        XCTAssertEqual(item.targetDateLabel, "Target Mar 2026")
        XCTAssertNotNil(item.developerRespondedAtDate)
        XCTAssertNotNil(item.developerRespondedAtRelativeLabel(referenceDate: Date(timeIntervalSince1970: 1_779_942_498.572)))
    }

    func testAskTypeHelpersCoverAllSupportedTypes() {
        XCTAssertEqual(ShipyardPromptType.allCases.map(\.rawValue), [
            "single_choice",
            "multi_choice",
            "star_rating",
            "numeric_rating",
            "open_text"
        ])
        XCTAssertTrue(ShipyardPromptType.singleChoice.usesOptions)
        XCTAssertTrue(ShipyardPromptType.multiChoice.allowsMultipleOptions)
        XCTAssertEqual(ShipyardPromptType.starRating.ratingRange, 1...5)
        XCTAssertEqual(ShipyardPromptType.numericRating.ratingRange, 1...10)
        XCTAssertFalse(ShipyardPromptType.openText.usesRating)
    }

    func testFetchEngagementUpdatesDecodesAsksAndAnnouncements() async throws {
        let productSlug = "engagement-updates-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/v1/auth/mobile/public-session":
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
                )
            case "/v1/engagement/updates":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "product" })?.value, productSlug)
                let ask = Self.promptObject(id: "prompt_rating", promptType: "star_rating")
                let announcement = Self.announcementObject(id: "ann_1")
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    jsonObject: [
                        "asks": [ask],
                        "prompts": [ask],
                        "announcements": [announcement],
                        "refreshedAt": "2026-05-28T20:30:00.000Z"
                    ]
                )
            default:
                return try Self.jsonResponse(for: request, status: 404, body: #"{"error":"not found"}"#)
            }
        }

        let updates = try await client.fetchEngagementUpdates()

        XCTAssertEqual(updates.asks.map(\.id), ["prompt_rating"])
        XCTAssertEqual(updates.asks.first?.type, .starRating)
        XCTAssertEqual(updates.asks.first?.ratingRange, 1...5)
        XCTAssertEqual(updates.announcements.map(\.id), ["ann_1"])
        XCTAssertEqual(updates.announcements.first?.ctaLabel, "Open Reports")
        XCTAssertNotNil(updates.refreshedAt)
    }

    func testEngagementUpdatesUseShortLivedCacheUnlessReloadRequested() async throws {
        let productSlug = "engagement-cache-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()
        var sessionRequestCount = 0
        var updatesRequestCount = 0

        ShipyardMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/v1/auth/mobile/public-session":
                sessionRequestCount += 1
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
                )
            case "/v1/engagement/updates":
                updatesRequestCount += 1
                let ask = Self.promptObject(id: "prompt_cached", promptType: "single_choice")
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    jsonObject: [
                        "asks": [ask],
                        "prompts": [ask],
                        "announcements": [],
                        "refreshedAt": "2026-06-04T08:00:00.000Z"
                    ]
                )
            default:
                return try Self.jsonResponse(for: request, status: 404, body: #"{"error":"not found"}"#)
            }
        }

        let first = try await client.fetchEngagementUpdates()
        let second = try await client.fetchEngagementUpdates()
        let forced = try await client.fetchEngagementUpdates(cachePolicy: .reloadIgnoringCache)

        XCTAssertEqual(first.asks.map(\.id), ["prompt_cached"])
        XCTAssertEqual(second.asks.map(\.id), ["prompt_cached"])
        XCTAssertEqual(forced.asks.map(\.id), ["prompt_cached"])
        XCTAssertEqual(sessionRequestCount, 1)
        XCTAssertEqual(updatesRequestCount, 2)
    }

    func testAskResponsePayloadsCoverSupportedTypes() async throws {
        let productSlug = "ask-responses-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/v1/auth/mobile/public-session":
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
                )
            case "/v1/engagement/asks/prompt_single/respond":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["optionId"] as? String, "opt_1")
                XCTAssertNil(body["optionIds"])
                let prompt = Self.promptObject(id: "prompt_single", promptType: "single_choice")
                return try Self.promptResponse(for: request, prompt: prompt)
            case "/v1/engagement/asks/prompt_multi/respond":
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["optionIds"] as? [String], ["opt_1", "opt_2"])
                XCTAssertNil(body["optionId"])
                let prompt = Self.promptObject(id: "prompt_multi", promptType: "multi_choice")
                return try Self.promptResponse(for: request, prompt: prompt)
            case "/v1/engagement/asks/prompt_star/respond":
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["ratingValue"] as? Int, 5)
                let prompt = Self.promptObject(id: "prompt_star", promptType: "star_rating")
                return try Self.promptResponse(for: request, prompt: prompt)
            case "/v1/engagement/asks/prompt_numeric/respond":
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["ratingValue"] as? Int, 8)
                let prompt = Self.promptObject(id: "prompt_numeric", promptType: "numeric_rating")
                return try Self.promptResponse(for: request, prompt: prompt)
            case "/v1/engagement/asks/prompt_text/respond":
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["responseText"] as? String, "Works well")
                let prompt = Self.promptObject(id: "prompt_text", promptType: "open_text")
                return try Self.promptResponse(for: request, prompt: prompt)
            default:
                return try Self.jsonResponse(for: request, status: 404, body: #"{"error":"not found"}"#)
            }
        }

        _ = try await client.respondToAsk(askId: "prompt_single", optionId: "opt_1")
        _ = try await client.respondToAsk(askId: "prompt_multi", optionIds: ["opt_1", "opt_2"])
        _ = try await client.respondToAsk(askId: "prompt_star", ratingValue: 5)
        _ = try await client.respondToAsk(askId: "prompt_numeric", ratingValue: 8)
        _ = try await client.respondToAsk(askId: "prompt_text", responseText: "  Works well  ")
    }

    func testAnnouncementEventsSendLifecyclePayloads() async throws {
        let productSlug = "announcement-events-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()
        var eventTypes: [String] = []

        ShipyardMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/v1/auth/mobile/public-session":
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
                )
            case "/v1/engagement/announcements/ann_1/events":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                let body = try Self.requestJSONBody(request)
                let eventType = try XCTUnwrap(body["eventType"] as? String)
                eventTypes.append(eventType)
                XCTAssertEqual(body["screenKey"] as? String, "home")
                if eventType == "shown" {
                    XCTAssertEqual(body["visibleMs"] as? Int, 1200)
                } else {
                    XCTAssertNil(body["visibleMs"])
                }
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    jsonObject: [
                        "ok": true,
                        "announcement": Self.announcementObject(id: "ann_1")
                    ]
                )
            default:
                return try Self.jsonResponse(for: request, status: 404, body: #"{"error":"not found"}"#)
            }
        }

        _ = try await client.markAnnouncementShown(announcementId: "ann_1", visibleMs: 1200, screenKey: "home")
        _ = try await client.clickAnnouncement(announcementId: "ann_1", screenKey: "home")
        _ = try await client.dismissAnnouncement(announcementId: "ann_1", screenKey: "home")

        XCTAssertEqual(eventTypes, ["shown", "clicked", "dismissed"])
    }

    func testNotificationSubscriptionUsesMobileSessionToken() async throws {
        let productSlug = "notification-subscription-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()
        var paths: [String] = []

        ShipyardMockURLProtocol.requestHandler = { request in
            paths.append(request.url?.path ?? "")
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/v1/auth/mobile/public-session"):
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
                )
            case ("POST", "/v1/auth/mobile/notification-subscriptions"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["provider"] as? String, "apns")
                XCTAssertEqual(body["environment"] as? String, "sandbox")
                XCTAssertEqual(body["endpointToken"] as? String, "device-token")
                XCTAssertEqual(body["enabled"] as? Bool, true)
                XCTAssertEqual((body["metadata"] as? [String: String])?["topic"], "planner")
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    jsonObject: [
                        "subscription": [
                            "id": "sub_123",
                            "provider": "apns",
                            "environment": "sandbox",
                            "platform": "ios",
                            "enabled": true,
                            "updatedAt": "2026-06-21T17:00:00.000Z"
                        ]
                    ]
                )
            case ("DELETE", "/v1/auth/mobile/notification-subscriptions"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                let body = try Self.requestJSONBody(request)
                XCTAssertEqual(body["provider"] as? String, "apns")
                XCTAssertNil(body["endpointToken"])
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    jsonObject: ["disabled": true, "count": 1]
                )
            default:
                return try Self.jsonResponse(for: request, status: 404, body: #"{"error":"not found"}"#)
            }
        }

        let subscription = try await client.registerNotificationSubscription(
            endpointToken: "device-token",
            provider: "apns",
            environment: "sandbox",
            metadata: ["topic": "planner"]
        )
        let deleted = try await client.deleteNotificationSubscription(provider: "apns")

        XCTAssertEqual(subscription?.id, "sub_123")
        XCTAssertEqual(subscription?.environment, "sandbox")
        XCTAssertTrue(deleted.disabled)
        XCTAssertEqual(deleted.count, 1)
        XCTAssertEqual(paths, [
            "/v1/auth/mobile/public-session",
            "/v1/auth/mobile/notification-subscriptions",
            "/v1/auth/mobile/notification-subscriptions"
        ])
    }

    func testFetchItemsFallsBackToCachedDataWhenOffline() async throws {
        let productSlug = "offline-cache-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/v1/auth/mobile/public-session":
                XCTAssertEqual(request.httpMethod, "POST")
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
                )
            case "/v1/requests":
                XCTAssertEqual(request.httpMethod, "GET")
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    body: #"{"requests":[{"id":"req_cached","title":"Cached request","description":null,"status":"open","itemType":"feature","voteCount":4}]}"#
                )
            default:
                return try Self.jsonResponse(for: request, status: 404, body: #"{"error":"not found"}"#)
            }
        }
        let onlineItems = try await client.fetchItems()
        XCTAssertEqual(onlineItems.map(\.id), ["req_cached"])
        let cachedItems = await client.cachedItems()
        XCTAssertEqual(cachedItems?.map(\.id), ["req_cached"])

        ShipyardMockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let offlineItems = try await client.fetchItems()
        XCTAssertEqual(offlineItems.map(\.id), ["req_cached"])
    }

    func testOfflineWriteQueuesAndFlushesWhenOnline() async throws {
        let productSlug = "offline-write-\(UUID().uuidString)"
        let client = makeMockClient(productSlug: productSlug)
        await client.clearOfflineData()

        ShipyardMockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await client.submitItem(title: "Queued idea", description: "Created offline")
            XCTFail("Expected offlineQueued")
        } catch ShipyardError.offlineQueued {
            // Expected.
        }
        let queuedCount = await client.queuedWriteCount()
        XCTAssertEqual(queuedCount, 1)

        ShipyardMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/v1/auth/mobile/public-session":
                return try Self.jsonResponse(
                    for: request,
                    status: 200,
                    body: #"{"token":"test-token","expiresAt":"2099-01-01T00:00:00Z"}"#
                )
            case "/v1/requests":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                return try Self.jsonResponse(
                    for: request,
                    status: 201,
                    body: #"{"request":{"id":"req_synced","title":"Queued idea","description":"Created offline","status":"waiting_review","itemType":"feature","voteCount":1}}"#
                )
            default:
                return try Self.jsonResponse(for: request, status: 200, body: #"{"requests":[]}"#)
            }
        }

        let result = await client.syncQueuedWritesIfPossible(refreshAfterSync: false)
        XCTAssertEqual(result.flushedCount, 1)
        XCTAssertEqual(result.remainingCount, 0)
        let remainingQueuedCount = await client.queuedWriteCount()
        XCTAssertEqual(remainingQueuedCount, 0)
    }

    private func makeMockClient(productSlug: String) -> ShipyardClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ShipyardMockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return ShipyardClient(
            baseURL: URL(string: "https://example.com")!,
            productSlug: productSlug,
            installationIdProvider: { "test-installation-\(productSlug)" },
            appVersionProvider: { "1.0" },
            buildNumberProvider: { "1" },
            urlSession: session
        )
    }

    private static func jsonResponse(
        for request: URLRequest,
        status: Int,
        body: String
    ) throws -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        return (try XCTUnwrap(response), Data(body.utf8))
    }

    private static func jsonResponse(
        for request: URLRequest,
        status: Int,
        jsonObject: Any
    ) throws -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        let data = try JSONSerialization.data(withJSONObject: jsonObject)
        return (try XCTUnwrap(response), data)
    }

    private static func requestJSONBody(_ request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let httpBody = request.httpBody {
            data = httpBody
        } else {
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var streamedData = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count > 0 {
                    streamedData.append(contentsOf: buffer.prefix(count))
                } else {
                    break
                }
            }
            data = streamedData
        }
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }

    private static func queryItems(_ request: URLRequest) throws -> [String: String] {
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    private static func promptResponse(
        for request: URLRequest,
        prompt: [String: Any]
    ) throws -> (HTTPURLResponse, Data) {
        try jsonResponse(
            for: request,
            status: 200,
            jsonObject: [
                "ok": true,
                "ask": prompt,
                "prompt": prompt
            ]
        )
    }

    private static func promptObject(id: String, promptType: String) -> [String: Any] {
        [
            "id": id,
            "title": "How is this working?",
            "description": NSNull(),
            "promptType": promptType,
            "status": "live",
            "resultsVisibility": "show_after_vote",
            "minRating": 1,
            "maxRating": promptType == "numeric_rating" ? 10 : 5,
            "maxSelections": promptType == "multi_choice" ? 2 : NSNull(),
            "startsAt": NSNull(),
            "endsAt": NSNull(),
            "state": "live",
            "responseCount": 1,
            "averageRating": NSNull(),
            "options": [
                ["id": "opt_1", "label": "First", "value": "first", "sortOrder": 0, "voteCount": NSNull()],
                ["id": "opt_2", "label": "Second", "value": "second", "sortOrder": 1, "voteCount": NSNull()]
            ],
            "myResponse": NSNull(),
            "resultsVisible": false
        ]
    }

    private static func productObject(
        id: String,
        name: String,
        slug: String,
        workingVersion: String? = nil,
        workingVersionStatus: String? = nil,
        workingVersionProgress: Int = 0
    ) -> [String: Any] {
        [
            "id": id,
            "name": name,
            "slug": slug,
            "type": "app",
            "description": NSNull(),
            "status": "active",
            "visibility": "private",
            "platforms": ["mac"],
            "iconUrl": NSNull(),
            "primaryColor": "#2563EB",
            "secondaryColor": "#0F172A",
            "appStoreUrl": NSNull(),
            "websiteUrl": NSNull(),
            "productNumber": "12",
            "workingVersion": workingVersion as Any? ?? NSNull(),
            "workingVersionStatus": workingVersionStatus as Any? ?? NSNull(),
            "workingVersionProgress": workingVersionProgress,
            "planning": [
                "productNumber": "12",
                "workingVersion": workingVersion as Any? ?? NSNull(),
                "workingVersionStatus": workingVersionStatus as Any? ?? NSNull(),
                "workingVersionProgress": workingVersionProgress
            ],
            "latestUpdateAt": NSNull(),
            "daysSinceLastUpdate": NSNull(),
            "updatePriority": [
                "rank": 1,
                "score": 80,
                "daysSinceUpdate": 42,
                "staleDays": 12,
                "daysSincePlanningActivity": 12,
                "planningStaleDays": 0,
                "workingVersionProgress": workingVersionProgress,
                "downloadWeight": 1.2,
                "downloads": 16,
                "latestUpdateAt": NSNull(),
                "latestPlanningActivityAt": "2026-06-07T12:00:00.000Z",
                "reviewSnoozedUntil": NSNull(),
                "updatePrioritySnoozedUntil": "2026-07-04T12:00:00.000Z",
                "releaseScore": 0,
                "planningScore": 0,
                "priorityType": "update_priority_snoozed",
                "basis": "update_priority_snooze"
            ],
            "updatePriorityRank": 1,
            "updatePriorityScore": 80,
            "updatePriorityType": "update_priority_snoozed",
            "updatePriorityBasis": "update_priority_snooze",
            "updatePriorityPaused": true,
            "updatePriorityPausedUntil": "2026-07-04T12:00:00.000Z",
            "updatePrioritySnoozedUntil": "2026-07-04T12:00:00.000Z",
            "updatePriorityReviewSnoozedUntil": NSNull(),
            "updatePriorityRankLabel": "Paused",
            "updatePriorityLabel": "Snoozed",
            "updatePriorityDetail": "until Jul 4",
            "updatePriorityDisplayLabel": "Paused · until Jul 4 · Snoozed",
            "publicUrl": "/product/\(slug)",
            "supportUrl": "/support",
            "createdAt": "2026-06-01T12:00:00.000Z",
            "updatedAt": "2026-06-07T12:00:00.000Z"
        ]
    }

    private static func requestObject(
        id: String,
        title: String,
        status: String = "open",
        itemType: String = "feature",
        voteCount: Int = 1,
        releaseVersion: String? = nil
    ) -> [String: Any] {
        [
            "id": id,
            "title": title,
            "description": NSNull(),
            "status": status,
            "itemType": itemType,
            "voteCount": voteCount,
            "productId": "prod_123",
            "productName": "Atlas",
            "productSlugHint": "atlas",
            "origin": "internal",
            "visibility": "private",
            "sourceChannel": "admin",
            "notes": "Internal planning note",
            "releaseVersion": releaseVersion ?? NSNull(),
            "targetDate": NSNull(),
            "developerResponse": NSNull(),
            "developerResponsePublic": false,
            "developerRespondedAt": NSNull(),
            "linkedPostId": NSNull(),
            "sortOrder": 12,
            "createdAt": "2026-06-01T12:00:00.000Z",
            "updatedAt": "2026-06-07T12:00:00.000Z"
        ]
    }

    private static func taskObject(
        id: String,
        requestId: String,
        title: String,
        isDone: Bool
    ) -> [String: Any] {
        [
            "id": id,
            "requestId": requestId,
            "title": title,
            "isDone": isDone,
            "orderIndex": 0,
            "createdAt": "2026-06-07T12:00:00.000Z"
        ]
    }

    private static func appAnalyticsObject() -> [String: Any] {
        [
            "studio": [
                "id": "studio_123",
                "name": "JudeWorks",
                "slug": "judeworks",
                "reportingCurrency": "USD"
            ],
            "products": [
                [
                    "id": "prod_123",
                    "name": "Atlas",
                    "slug": "atlas",
                    "type": "app",
                    "status": "active",
                    "appStoreUrl": "https://apps.apple.com/app/id1234567890"
                ]
            ],
            "filters": [
                "days": 90,
                "productId": "prod_123",
                "view": "week",
                "activity": "sessions"
            ],
            "connection": [
                "configured": true,
                "reportingCurrency": "USD",
                "lastTestAt": "2026-06-07T12:00:00Z",
                "lastTestStatus": "ok",
                "lastTestError": NSNull(),
                "lastSyncAt": "2026-06-07T12:30:00Z",
                "lastSyncStatus": "completed",
                "lastSyncError": NSNull(),
                "mappedProducts": 1
            ],
            "freshness": [
                "status": "live",
                "label": "Current",
                "latestDataDate": "2026-06-07",
                "expectedLatestReportDate": "2026-06-07",
                "missingDays": 0,
                "activeSyncRunId": NSNull(),
                "latestSuccessfulRunRows": 12
            ],
            "chart": [
                "title": "Weekly Sessions",
                "subtitle": "Atlas · 90 days · 2026-03-10 to 2026-06-07",
                "description": "Opt-in app sessions from Apple App Store Connect usage reports.",
                "seriesLabel": "Sessions",
                "valueLabel": "Sessions",
                "valueUnit": "units",
                "xAxisLabel": "Report week",
                "yAxisLabel": "Sessions (units)",
                "bucketLabel": "week",
                "rangeLabel": "2026-03-10 to 2026-06-07",
                "selectedProductName": "Atlas",
                "latestDataDate": "2026-06-07",
                "freshnessLabel": "Current"
            ],
            "summary": [
                "totalUnits": 44,
                "totalProceeds": 10.5,
                "netProceeds": 10.5,
                "netProceedsDisplay": "USD 10.50",
                "paidAppProceeds": 3.5,
                "paidAppProceedsDisplay": "USD 3.50",
                "iapProceeds": 7,
                "iapProceedsDisplay": "USD 7.00",
                "totalProceedsDisplay": "USD 10.50",
                "totalRows": 2,
                "activeApps": 1,
                "averagePerBucket": 22,
                "medianPerBucket": 22,
                "peakBucketLabel": "2026-06-01 to 2026-06-07",
                "peakBucketValue": 44,
                "topAppName": "Atlas",
                "topAppUnits": 44,
                "momentumDirection": "up",
                "momentumDelta": 12,
                "trendBucketLabel": "week",
                "downloadMomentum": [
                    [
                        "key": "week",
                        "label": "Week",
                        "days": 7,
                        "current": 10,
                        "previous": 8,
                        "delta": 2,
                        "percentLabel": "+25%",
                        "currentStartDate": "2026-06-01",
                        "currentEndDate": "2026-06-07",
                        "previousStartDate": "2026-05-25",
                        "previousEndDate": "2026-05-31"
                    ]
                ],
                "proceedsMomentum": [
                    "label": "30 Days",
                    "days": 30,
                    "current": 10.5,
                    "previous": 8,
                    "delta": 2.5,
                    "percentLabel": "+31%",
                    "currentDisplay": "USD 10.50",
                    "deltaDisplay": "+USD 2.50",
                    "currentStartDate": "2026-05-09",
                    "currentEndDate": "2026-06-07",
                    "previousStartDate": "2026-04-09",
                    "previousEndDate": "2026-05-08"
                ],
                "activityLabel": "Sessions",
                "matchingAppsLabel": "Matching sessions rows in this app",
                "proceedsBreakdown": "USD 10.50"
            ],
            "appStoreEngagement": [
                "configured": true,
                "latestProcessingDate": "2026-06-08",
                "totals": [
                    "impressions": 120,
                    "uniqueImpressions": 80,
                    "productPageViews": 40,
                    "taps": 12,
                    "tapThroughRate": 0.1,
                    "sessions": 44,
                    "sessionUniqueDevices": 20,
                    "totalSessionDurationSeconds": 660,
                    "averageSessionDurationSeconds": 15
                ],
                "trend": [
                    [
                        "value": 120,
                        "label": "06-01-07",
                        "tooltip": "2026-06-01 to 2026-06-07",
                        "startDate": "2026-06-01",
                        "endDate": "2026-06-07",
                        "valueUnit": "impressions"
                    ]
                ],
                "topSources": [
                    [
                        "sourceType": "Search",
                        "impressions": 100,
                        "productPageViews": 30,
                        "taps": 10,
                        "rows": 2
                    ]
                ],
                "topApps": [
                    [
                        "productId": "prod_123",
                        "productName": "Atlas",
                        "appleAppId": "1234567890",
                        "impressions": 120,
                        "uniqueImpressions": 80,
                        "productPageViews": 40,
                        "taps": 12,
                        "activeDays": 7
                    ]
                ],
                "breakdown": [
                    [
                        "sourceType": "Search",
                        "pageType": "Product Page",
                        "eventName": "Impression",
                        "counts": 100,
                        "uniqueCounts": 70
                    ]
                ]
            ],
            "trend": [
                [
                    "value": 44,
                    "label": "06-01-07",
                    "tooltip": "2026-06-01 to 2026-06-07",
                    "startDate": "2026-06-01",
                    "endDate": "2026-06-07"
                ]
            ],
            "topApps": [
                [
                    "productId": "prod_123",
                    "productName": "Atlas",
                    "salesItemName": "App Sessions",
                    "activityType": "Sessions",
                    "mappingMethod": "stored_product_id",
                    "mappingConfidence": "high",
                    "mappingLabel": "Mapped using a saved app link",
                    "appleAppId": "1234567890",
                    "units": 44,
                    "activeDays": 7,
                    "proceeds": 0,
                    "proceedsDisplay": "USD 0.00"
                ]
            ],
            "groupedApps": [
                [
                    "productId": "prod_123",
                    "productName": "Atlas",
                    "appleAppId": "1234567890",
                    "units": 44,
                    "activeDays": 7,
                    "proceeds": 10.5,
                    "proceedsDisplay": "USD 10.50"
                ]
            ],
            "recentBreakdown": [
                [
                    "date": "2026-06-07",
                    "productId": "prod_123",
                    "productName": "Atlas",
                    "salesItemName": "App Sessions",
                    "activityType": "Sessions",
                    "mappingMethod": "stored_product_id",
                    "mappingConfidence": "high",
                    "mappingLabel": "Mapped using a saved app link",
                    "appleAppId": "1234567890",
                    "units": 44,
                    "proceeds": 0,
                    "proceedsDisplay": "USD 0.00"
                ]
            ],
            "unmappedSales": [
                "rowCount": 0,
                "itemCount": 0,
                "totalUnits": 0,
                "totalProceeds": 0,
                "totalProceedsDisplay": "USD 0.00",
                "items": []
            ],
            "syncRuns": [
                [
                    "id": "sync_123",
                    "days": 30,
                    "status": "completed",
                    "totalDates": 1,
                    "completedDates": 1,
                    "successDates": 1,
                    "failedDates": 0,
                    "insertedRows": 12,
                    "lastError": NSNull(),
                    "createdAt": "2026-06-07T12:00:00Z",
                    "startedAt": "2026-06-07T12:00:01Z",
                    "completedAt": "2026-06-07T12:00:02Z",
                    "updatedAt": "2026-06-07T12:00:02Z"
                ]
            ]
        ]
    }

    private static func announcementObject(id: String) -> [String: Any] {
        [
            "id": id,
            "title": "New export filters are live",
            "body": "Open Reports to try the updated export flow.",
            "ctaLabel": "Open Reports",
            "ctaUrl": "atlas://reports",
            "status": "live",
            "priority": 10,
            "clearable": true,
            "showOnce": false,
            "startsAt": NSNull(),
            "endsAt": NSNull(),
            "state": "live",
            "shownCount": 0,
            "dismissCount": 0,
            "clickCount": 0,
            "myState": NSNull()
        ]
    }
}
