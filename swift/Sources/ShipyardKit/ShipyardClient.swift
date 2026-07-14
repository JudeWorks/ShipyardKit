import Foundation
import Security
import CryptoKit
import Network
#if canImport(UIKit)
import UIKit
#endif

public enum ShipyardItemType: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case idea
    case update
    case bugfix
    case tweak
    case polish
    case feature
    case launch

    public var id: String { rawValue }

    public static var roadmapSuggestionCases: [ShipyardItemType] {
        [.feature, .bugfix]
    }

    public var title: String {
        switch self {
        case .idea: return "Idea"
        case .update: return "Update"
        case .bugfix: return "Bug Fix"
        case .tweak: return "Tweak"
        case .polish: return "Polish"
        case .feature: return "Feature"
        case .launch: return "Launch"
        }
    }
}

public struct ShipyardItem: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String?
    public let status: String
    public let itemType: String?
    public let voteCount: Int
    public let productId: String?
    public let productName: String?
    public let productSlugHint: String?
    public let origin: String?
    public let visibility: String?
    public let sourceChannel: String?
    public let notes: String?
    public let releaseVersion: String?
    public let targetDate: String?
    public let developerResponse: String?
    public let developerResponsePublic: Bool?
    public let developerRespondedAt: String?
    public let linkedPostId: String?
    public let sortOrder: Int?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        title: String,
        description: String?,
        status: String,
        itemType: String?,
        voteCount: Int,
        productId: String? = nil,
        productName: String? = nil,
        productSlugHint: String? = nil,
        origin: String? = nil,
        visibility: String? = nil,
        sourceChannel: String? = nil,
        notes: String? = nil,
        releaseVersion: String? = nil,
        targetDate: String? = nil,
        developerResponse: String? = nil,
        developerResponsePublic: Bool? = nil,
        developerRespondedAt: String? = nil,
        linkedPostId: String? = nil,
        sortOrder: Int? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.itemType = itemType
        self.voteCount = voteCount
        self.productId = productId
        self.productName = productName
        self.productSlugHint = productSlugHint
        self.origin = origin
        self.visibility = visibility
        self.sourceChannel = sourceChannel
        self.notes = notes
        self.releaseVersion = releaseVersion
        self.targetDate = targetDate
        self.developerResponse = developerResponse
        self.developerResponsePublic = developerResponsePublic
        self.developerRespondedAt = developerRespondedAt
        self.linkedPostId = linkedPostId
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var type: ShipyardItemType {
        ShipyardItemType(rawValue: itemType ?? "") ?? .feature
    }

    public var normalizedStatus: String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public var releaseVersionLabel: String? {
        let value = releaseVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    public var developerResponseText: String? {
        guard developerResponsePublic == true else { return nil }
        let value = developerResponse?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    public var targetDateLabel: String? {
        let value = targetDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }

        if let date = ShipyardDateParser.date(from: value) {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.dateFormat = "MMM yyyy"
            return "Target \(formatter.string(from: date))"
        }

        return "Target \(value)"
    }

    public var developerRespondedAtDate: Date? {
        ShipyardDateParser.date(from: developerRespondedAt)
    }

    public func developerRespondedAtRelativeLabel(referenceDate: Date = Date()) -> String? {
        guard let developerRespondedAtDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: developerRespondedAtDate, relativeTo: referenceDate)
        return "Dev replied \(relative)"
    }

    public func availabilityLabel(currentAppVersion: String?) -> String? {
        guard let version = releaseVersionLabel else {
            if normalizedStatus == "shipped" { return "Shipped" }
            return nil
        }

        switch normalizedStatus {
        case "planned", "in_progress":
            return "Coming in \(version)"
        case "shipped", "closed":
            guard let currentAppVersion,
                  ShipyardVersionComparator.compare(currentAppVersion, version) != .orderedAscending
            else {
                return "Update to get this"
            }
            return "Included in your version"
        default:
            return nil
        }
    }
}

public enum ShipyardDateParser {
    public static func date(from value: String?) -> Date? {
        let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: raw) {
            return date
        }

        let internetFormatter = ISO8601DateFormatter()
        internetFormatter.formatOptions = [.withInternetDateTime]
        if let date = internetFormatter.date(from: raw) {
            return date
        }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        return dateOnlyFormatter.date(from: raw)
    }
}

public enum ShipyardReadCachePolicy: Equatable, Sendable {
    case automatic
    case reloadIgnoringCache
}

public enum ShipyardVersionComparator {
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionParts(lhs)
        let right = versionParts(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftPart = index < left.count ? left[index] : .number(0)
            let rightPart = index < right.count ? right[index] : .number(0)
            let result = comparePart(leftPart, rightPart)
            if result != .orderedSame { return result }
        }

        return .orderedSame
    }

    private enum VersionPart: Equatable {
        case number(Int)
        case text(String)
    }

    private static func versionParts(_ value: String) -> [VersionPart] {
        value
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map { part in
                if let number = Int(part) {
                    return .number(number)
                }
                return .text(String(part))
            }
    }

    private static func comparePart(_ lhs: VersionPart, _ rhs: VersionPart) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (.number(left), .number(right)):
            if left == right { return .orderedSame }
            return left < right ? .orderedAscending : .orderedDescending
        case let (.text(left), .text(right)):
            return left.compare(right)
        case (.number, .text):
            return .orderedDescending
        case (.text, .number):
            return .orderedAscending
        }
    }
}

public struct ShipyardSiteAnalyticsTotals: Codable, Sendable {
    public let visits: Int
    public let uniqueVisitors: Int?
    public let edgeResponseBytes: Int64

    public init(visits: Int, uniqueVisitors: Int? = nil, edgeResponseBytes: Int64) {
        self.visits = visits
        self.uniqueVisitors = uniqueVisitors
        self.edgeResponseBytes = edgeResponseBytes
    }
}

public struct ShipyardSiteAnalyticsTrendPoint: Codable, Identifiable, Sendable {
    public let date: String
    public let visits: Int
    public let uniqueVisitors: Int?
    public let edgeResponseBytes: Int64

    public var id: String { date }

    public init(date: String, visits: Int, uniqueVisitors: Int? = nil, edgeResponseBytes: Int64) {
        self.date = date
        self.visits = visits
        self.uniqueVisitors = uniqueVisitors
        self.edgeResponseBytes = edgeResponseBytes
    }
}

public struct ShipyardSiteAnalyticsTopPath: Codable, Identifiable, Sendable {
    public let path: String
    public let visits: Int
    public let edgeResponseBytes: Int64

    public var id: String { path }

    public init(path: String, visits: Int, edgeResponseBytes: Int64) {
        self.path = path
        self.visits = visits
        self.edgeResponseBytes = edgeResponseBytes
    }
}

public struct ShipyardSiteAnalyticsScope: Codable, Sendable {
    public let type: String
    public let productId: String?
    public let productSlug: String?
    public let productName: String?
    public let pathPrefixes: [String]?

    public init(
        type: String,
        productId: String? = nil,
        productSlug: String? = nil,
        productName: String? = nil,
        pathPrefixes: [String]? = nil
    ) {
        self.type = type
        self.productId = productId
        self.productSlug = productSlug
        self.productName = productName
        self.pathPrefixes = pathPrefixes
    }
}

public struct ShipyardSiteAnalytics: Codable, Sendable {
    public let configured: Bool
    public let available: Bool
    public let error: String?
    public let hostname: String
    public let days: Int
    public let scope: ShipyardSiteAnalyticsScope?
    public let totals: ShipyardSiteAnalyticsTotals
    public let trend: [ShipyardSiteAnalyticsTrendPoint]
    public let topPaths: [ShipyardSiteAnalyticsTopPath]
    public let allowedHostnames: [String]
    public let selectedHostname: String
    public let cached: Bool
    public let refreshedAt: String?
    public let expiresAt: String?

    public init(
        configured: Bool,
        available: Bool,
        error: String?,
        hostname: String,
        days: Int,
        scope: ShipyardSiteAnalyticsScope? = nil,
        totals: ShipyardSiteAnalyticsTotals,
        trend: [ShipyardSiteAnalyticsTrendPoint],
        topPaths: [ShipyardSiteAnalyticsTopPath],
        allowedHostnames: [String],
        selectedHostname: String,
        cached: Bool,
        refreshedAt: String?,
        expiresAt: String?
    ) {
        self.configured = configured
        self.available = available
        self.error = error
        self.hostname = hostname
        self.days = days
        self.scope = scope
        self.totals = totals
        self.trend = trend
        self.topPaths = topPaths
        self.allowedHostnames = allowedHostnames
        self.selectedHostname = selectedHostname
        self.cached = cached
        self.refreshedAt = refreshedAt
        self.expiresAt = expiresAt
    }
}

public struct ShipyardAnalyticsProduct: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let slug: String
    public let type: String?
    public let status: String?
    public let appStoreUrl: String?

    public init(id: String, name: String, slug: String, type: String? = nil, status: String? = nil, appStoreUrl: String? = nil) {
        self.id = id
        self.name = name
        self.slug = slug
        self.type = type
        self.status = status
        self.appStoreUrl = appStoreUrl
    }
}

public struct ShipyardAppAnalyticsStudio: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let slug: String
    public let reportingCurrency: String

    public init(id: String, name: String, slug: String, reportingCurrency: String) {
        self.id = id
        self.name = name
        self.slug = slug
        self.reportingCurrency = reportingCurrency
    }
}

public struct ShipyardAppAnalyticsFilters: Codable, Sendable {
    public let days: Int
    public let productId: String
    public let view: String
    public let activity: String

    public init(days: Int, productId: String, view: String, activity: String) {
        self.days = days
        self.productId = productId
        self.view = view
        self.activity = activity
    }
}

public struct ShipyardAppAnalyticsConnection: Codable, Sendable {
    public let configured: Bool
    public let reportingCurrency: String
    public let lastTestAt: String?
    public let lastTestStatus: String?
    public let lastTestError: String?
    public let lastSyncAt: String?
    public let lastSyncStatus: String?
    public let lastSyncError: String?
    public let mappedProducts: Int?

    public init(
        configured: Bool,
        reportingCurrency: String,
        lastTestAt: String? = nil,
        lastTestStatus: String? = nil,
        lastTestError: String? = nil,
        lastSyncAt: String? = nil,
        lastSyncStatus: String? = nil,
        lastSyncError: String? = nil,
        mappedProducts: Int? = nil
    ) {
        self.configured = configured
        self.reportingCurrency = reportingCurrency
        self.lastTestAt = lastTestAt
        self.lastTestStatus = lastTestStatus
        self.lastTestError = lastTestError
        self.lastSyncAt = lastSyncAt
        self.lastSyncStatus = lastSyncStatus
        self.lastSyncError = lastSyncError
        self.mappedProducts = mappedProducts
    }
}

public struct ShipyardAppAnalyticsFreshness: Codable, Sendable {
    public let status: String
    public let label: String
    public let latestDataDate: String?
    public let expectedLatestReportDate: String?
    public let missingDays: Int
    public let activeSyncRunId: String?
    public let latestSuccessfulRunRows: Int?

    public init(
        status: String,
        label: String,
        latestDataDate: String? = nil,
        expectedLatestReportDate: String? = nil,
        missingDays: Int,
        activeSyncRunId: String? = nil,
        latestSuccessfulRunRows: Int? = nil
    ) {
        self.status = status
        self.label = label
        self.latestDataDate = latestDataDate
        self.expectedLatestReportDate = expectedLatestReportDate
        self.missingDays = missingDays
        self.activeSyncRunId = activeSyncRunId
        self.latestSuccessfulRunRows = latestSuccessfulRunRows
    }
}

public struct ShipyardAppAnalyticsChartMetadata: Codable, Sendable {
    public let title: String
    public let subtitle: String
    public let description: String
    public let seriesLabel: String
    public let valueLabel: String
    public let valueUnit: String
    public let xAxisLabel: String
    public let yAxisLabel: String
    public let bucketLabel: String
    public let rangeLabel: String
    public let selectedProductName: String?
    public let latestDataDate: String?
    public let freshnessLabel: String
}

public struct ShipyardAppAnalyticsMomentum: Codable, Sendable {
    public let key: String?
    public let label: String
    public let days: Int
    public let current: Double
    public let previous: Double
    public let delta: Double
    public let percentLabel: String
    public let currentDisplay: String?
    public let deltaDisplay: String?
    public let currentStartDate: String
    public let currentEndDate: String
    public let previousStartDate: String
    public let previousEndDate: String
}

public struct ShipyardAppAnalyticsSummary: Codable, Sendable {
    public let totalUnits: Double
    public let totalProceeds: Double
    public let netProceeds: Double
    public let netProceedsDisplay: String
    public let paidAppProceeds: Double
    public let paidAppProceedsDisplay: String
    public let iapProceeds: Double
    public let iapProceedsDisplay: String
    public let totalProceedsDisplay: String
    public let totalRows: Int
    public let activeApps: Int
    public let averagePerBucket: Double
    public let medianPerBucket: Double
    public let peakBucketLabel: String
    public let peakBucketValue: Double
    public let topAppName: String
    public let topAppUnits: Double
    public let momentumDirection: String
    public let momentumDelta: Double
    public let trendBucketLabel: String
    public let downloadMomentum: [ShipyardAppAnalyticsMomentum]
    public let proceedsMomentum: ShipyardAppAnalyticsMomentum
    public let activityLabel: String
    public let matchingAppsLabel: String
    public let proceedsBreakdown: String?
}

public struct ShipyardAppAnalyticsTrendPoint: Codable, Identifiable, Sendable {
    public let value: Double
    public let label: String
    public let tooltip: String
    public let startDate: String
    public let endDate: String
    public let valueUnit: String?

    public var id: String { "\(startDate):\(endDate):\(label)" }
}

public struct ShipyardAppAnalyticsEngagementTotals: Codable, Sendable {
    public let impressions: Int
    public let uniqueImpressions: Int
    public let productPageViews: Int
    public let taps: Int
    public let tapThroughRate: Double
    public let sessions: Int
    public let sessionUniqueDevices: Int
    public let totalSessionDurationSeconds: Double
    public let averageSessionDurationSeconds: Double
}

public struct ShipyardAppAnalyticsSource: Codable, Sendable {
    public let sourceType: String
    public let impressions: Int
    public let productPageViews: Int
    public let taps: Int
    public let rows: Int
}

public struct ShipyardAppAnalyticsEngagementApp: Codable, Sendable {
    public let productId: String?
    public let productName: String
    public let appleAppId: String
    public let impressions: Int
    public let uniqueImpressions: Int
    public let productPageViews: Int
    public let taps: Int
    public let activeDays: Int
}

public struct ShipyardAppAnalyticsEngagementBreakdown: Codable, Sendable {
    public let sourceType: String
    public let pageType: String
    public let eventName: String
    public let counts: Int
    public let uniqueCounts: Int
}

public struct ShipyardAppAnalyticsEngagement: Codable, Sendable {
    public let configured: Bool
    public let latestProcessingDate: String?
    public let totals: ShipyardAppAnalyticsEngagementTotals
    public let trend: [ShipyardAppAnalyticsTrendPoint]
    public let topSources: [ShipyardAppAnalyticsSource]
    public let topApps: [ShipyardAppAnalyticsEngagementApp]
    public let breakdown: [ShipyardAppAnalyticsEngagementBreakdown]
}

public struct ShipyardAppAnalyticsAppSummary: Codable, Sendable {
    public let productId: String?
    public let productName: String
    public let salesItemName: String?
    public let activityType: String?
    public let mappingMethod: String?
    public let mappingConfidence: String?
    public let mappingLabel: String?
    public let appleAppId: String
    public let units: Double
    public let activeDays: Int
    public let proceeds: Double
    public let proceedsDisplay: String
}

public struct ShipyardAppAnalyticsBreakdownRow: Codable, Sendable {
    public let date: String
    public let productId: String?
    public let productName: String
    public let salesItemName: String
    public let activityType: String
    public let mappingMethod: String
    public let mappingConfidence: String
    public let mappingLabel: String
    public let appleAppId: String
    public let units: Double
    public let proceeds: Double
    public let proceedsDisplay: String
}

public struct ShipyardAppAnalyticsUnmappedItem: Codable, Sendable {
    public let appleAppId: String
    public let salesItemName: String
    public let activityType: String
    public let units: Double
    public let proceeds: Double
    public let proceedsDisplay: String
    public let mappingLabel: String
}

public struct ShipyardAppAnalyticsUnmappedSales: Codable, Sendable {
    public let rowCount: Int
    public let itemCount: Int
    public let totalUnits: Double
    public let totalProceeds: Double
    public let totalProceedsDisplay: String
    public let items: [ShipyardAppAnalyticsUnmappedItem]
}

public struct ShipyardAppAnalyticsSyncRun: Codable, Identifiable, Sendable {
    public let id: String
    public let days: Int
    public let status: String
    public let totalDates: Int
    public let completedDates: Int
    public let successDates: Int
    public let failedDates: Int
    public let insertedRows: Int
    public let lastError: String?
    public let createdAt: String?
    public let startedAt: String?
    public let completedAt: String?
    public let updatedAt: String?
}

public struct ShipyardAppAnalytics: Codable, Sendable {
    public let studio: ShipyardAppAnalyticsStudio?
    public let products: [ShipyardAnalyticsProduct]
    public let filters: ShipyardAppAnalyticsFilters
    public let connection: ShipyardAppAnalyticsConnection
    public let freshness: ShipyardAppAnalyticsFreshness
    public let chart: ShipyardAppAnalyticsChartMetadata
    public let summary: ShipyardAppAnalyticsSummary
    public let appStoreEngagement: ShipyardAppAnalyticsEngagement
    public let trend: [ShipyardAppAnalyticsTrendPoint]
    public let topApps: [ShipyardAppAnalyticsAppSummary]
    public let groupedApps: [ShipyardAppAnalyticsAppSummary]
    public let recentBreakdown: [ShipyardAppAnalyticsBreakdownRow]
    public let unmappedSales: ShipyardAppAnalyticsUnmappedSales
    public let syncRuns: [ShipyardAppAnalyticsSyncRun]
}

public struct ShipyardAppAnalyticsSyncRange: Codable, Sendable {
    public let from: String?
    public let to: String?
}

public struct ShipyardAppAnalyticsSyncResult: Codable, Sendable {
    public let ok: Bool
    public let started: Bool
    public let runId: String?
    public let queueJobId: String?
    public let cancelledRunId: String?
    public let queuedDates: Int
    public let message: String?
    public let range: ShipyardAppAnalyticsSyncRange?
}

public struct ShipyardProductPlanning: Codable, Sendable {
    public let productNumber: String?
    public let workingVersion: String?
    public let workingVersionStatus: String?
    public let workingVersionProgress: Int?
}

public struct ShipyardProductUpdatePriority: Codable, Sendable {
    public let rank: Int?
    public let score: Double?
    public let daysSinceUpdate: Int?
    public let staleDays: Int?
    public let daysSincePlanningActivity: Int?
    public let planningStaleDays: Int?
    public let workingVersionProgress: Int?
    public let downloadWeight: Double?
    public let downloads: Int?
    public let latestUpdateAt: String?
    public let latestPlanningActivityAt: String?
    public let reviewSnoozedUntil: String?
    public let updatePrioritySnoozedUntil: String?
    public let releaseScore: Double?
    public let planningScore: Double?
    public let priorityType: String?
    public let basis: String?
}

public struct ShipyardAppStoreSummary: Codable, Sendable {
    public let currentVersion: String?
    public let currentVersionReleaseDate: String?
    public let currentVersionPostSlug: String?
    public let currentReleaseNotesSummary: String?
    public let versionHistoryCount: Int?
    public let versionHistoryPulledAt: String?
    public let lastSyncAt: String?
    public let trackId: String?
    public let country: String?
    public let reviewSubmittedAt: String?
    public let reviewFollowUpAt: String?
}

public struct ShipyardProduct: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let slug: String
    public let type: String?
    public let description: String?
    public let status: String?
    public let visibility: String?
    public let platforms: [String]?
    public let iconUrl: String?
    public let primaryColor: String?
    public let secondaryColor: String?
    public let appStoreUrl: String?
    public let websiteUrl: String?
    public let productNumber: String?
    public let workingVersion: String?
    public let workingVersionStatus: String?
    public let workingVersionProgress: Int?
    public let planning: ShipyardProductPlanning?
    public let appStore: ShipyardAppStoreSummary?
    public let latestUpdateAt: String?
    public let daysSinceLastUpdate: Int?
    public let updatePriority: ShipyardProductUpdatePriority?
    public let updatePriorityRank: Int?
    public let updatePriorityScore: Double?
    public let updatePriorityType: String?
    public let updatePriorityBasis: String?
    public let updatePriorityPaused: Bool?
    public let updatePriorityPausedUntil: String?
    public let updatePrioritySnoozedUntil: String?
    public let updatePriorityReviewSnoozedUntil: String?
    public let updatePriorityRankLabel: String?
    public let updatePriorityLabel: String?
    public let updatePriorityDetail: String?
    public let updatePriorityDisplayLabel: String?
    public let publicUrl: String?
    public let supportUrl: String?
    public let createdAt: String?
    public let updatedAt: String?
}

public struct ShipyardProductList: Codable, Sendable {
    public let products: [ShipyardProduct]
}

public struct ShipyardServiceAPIKey: Codable, Sendable {
    public let id: String
    public let name: String
    public let scopes: [String]
    public let allowedProductSlugs: [String]
    public let status: String
    public let expiresAt: String?
    public let rotationRecommended: Bool
}

public struct ShipyardServiceAPIKeyStatus: Codable, Sendable {
    public let ok: Bool
    public let serverTime: String
    public let apiKey: ShipyardServiceAPIKey
}

public struct ShipyardPlannerReleaseGroup: Codable, Identifiable, Sendable {
    public let key: String
    public let kind: String
    public let title: String
    public let releaseVersion: String?
    public let count: Int
    public let items: [ShipyardItem]

    public var id: String { key }
}

public struct ShipyardProductPlanner: Codable, Sendable {
    public let items: [ShipyardItem]
    public let workingVersion: String?
    public let currentVersion: ShipyardPlannerReleaseGroup?
    public let futureVersions: [ShipyardPlannerReleaseGroup]
    public let unassigned: ShipyardPlannerReleaseGroup
    public let groups: [ShipyardPlannerReleaseGroup]
}

public struct ShipyardProductDetail: Codable, Sendable {
    public let product: ShipyardProduct
    public let planner: ShipyardProductPlanner?
}

public struct ShipyardProductUpdate: Encodable, Sendable {
    public var name: String?
    public var description: String?
    public var status: String?
    public var visibility: String?
    public var platforms: [String]?
    public var primaryColor: String?
    public var secondaryColor: String?
    public var appStoreUrl: String?
    public var websiteUrl: String?
    public var productNumber: String?
    public var workingVersion: String?
    public var workingVersionStatus: String?
    public var workingVersionProgress: Int?

    public init(
        name: String? = nil,
        description: String? = nil,
        status: String? = nil,
        visibility: String? = nil,
        platforms: [String]? = nil,
        primaryColor: String? = nil,
        secondaryColor: String? = nil,
        appStoreUrl: String? = nil,
        websiteUrl: String? = nil,
        productNumber: String? = nil,
        workingVersion: String? = nil,
        workingVersionStatus: String? = nil,
        workingVersionProgress: Int? = nil
    ) {
        self.name = name
        self.description = description
        self.status = status
        self.visibility = visibility
        self.platforms = platforms
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.appStoreUrl = appStoreUrl
        self.websiteUrl = websiteUrl
        self.productNumber = productNumber
        self.workingVersion = workingVersion
        self.workingVersionStatus = workingVersionStatus
        self.workingVersionProgress = workingVersionProgress
    }
}

public struct ShipyardProductInput: Encodable, Sendable {
    public var name: String
    public var slug: String?
    public var type: String
    public var description: String?
    public var status: String?
    public var visibility: String?
    public var platforms: [String]?
    public var workingVersion: String?
    public var workingVersionStatus: String?
    public var workingVersionProgress: Int?

    public init(
        name: String,
        slug: String? = nil,
        type: String = "app",
        description: String? = nil,
        status: String? = nil,
        visibility: String? = "private",
        platforms: [String]? = nil,
        workingVersion: String? = nil,
        workingVersionStatus: String? = nil,
        workingVersionProgress: Int? = nil
    ) {
        self.name = name
        self.slug = slug
        self.type = type
        self.description = description
        self.status = status
        self.visibility = visibility
        self.platforms = platforms
        self.workingVersion = workingVersion
        self.workingVersionStatus = workingVersionStatus
        self.workingVersionProgress = workingVersionProgress
    }
}

public struct ShipyardProductIconUploadResult: Codable, Sendable {
    public let product: ShipyardProduct
}

public struct ShipyardPlannerItemInput: Encodable, Sendable {
    public var title: String
    public var description: String?
    public var productId: String?
    public var productSlug: String?
    public var status: String?
    public var visibility: String?
    public var origin: String?
    public var notes: String?
    public var developerResponse: String?
    public var developerResponsePublic: Bool?
    public var itemType: String?
    public var releaseVersion: String?
    public var sortOrder: Int?
    public var targetDate: String?
    public var productName: String?
    public var productSlugHint: String?
    public var linkedPostId: String?

    public init(
        title: String,
        description: String? = nil,
        productId: String? = nil,
        productSlug: String? = nil,
        status: String? = nil,
        visibility: String? = nil,
        origin: String? = nil,
        notes: String? = nil,
        developerResponse: String? = nil,
        developerResponsePublic: Bool? = nil,
        itemType: String? = nil,
        releaseVersion: String? = nil,
        sortOrder: Int? = nil,
        targetDate: String? = nil,
        productName: String? = nil,
        productSlugHint: String? = nil,
        linkedPostId: String? = nil
    ) {
        self.title = title
        self.description = description
        self.productId = productId
        self.productSlug = productSlug
        self.status = status
        self.visibility = visibility
        self.origin = origin
        self.notes = notes
        self.developerResponse = developerResponse
        self.developerResponsePublic = developerResponsePublic
        self.itemType = itemType
        self.releaseVersion = releaseVersion
        self.sortOrder = sortOrder
        self.targetDate = targetDate
        self.productName = productName
        self.productSlugHint = productSlugHint
        self.linkedPostId = linkedPostId
    }
}

public struct ShipyardPlannerItemUpdate: Encodable, Sendable {
    public var title: String?
    public var description: String?
    public var productId: String?
    public var status: String?
    public var visibility: String?
    public var origin: String?
    public var notes: String?
    public var developerResponse: String?
    public var developerResponsePublic: Bool?
    public var itemType: String?
    public var releaseVersion: String?
    public var sortOrder: Int?
    public var targetDate: String?
    public var productName: String?
    public var productSlugHint: String?
    public var linkedPostId: String?

    public init(
        title: String? = nil,
        description: String? = nil,
        productId: String? = nil,
        status: String? = nil,
        visibility: String? = nil,
        origin: String? = nil,
        notes: String? = nil,
        developerResponse: String? = nil,
        developerResponsePublic: Bool? = nil,
        itemType: String? = nil,
        releaseVersion: String? = nil,
        sortOrder: Int? = nil,
        targetDate: String? = nil,
        productName: String? = nil,
        productSlugHint: String? = nil,
        linkedPostId: String? = nil
    ) {
        self.title = title
        self.description = description
        self.productId = productId
        self.status = status
        self.visibility = visibility
        self.origin = origin
        self.notes = notes
        self.developerResponse = developerResponse
        self.developerResponsePublic = developerResponsePublic
        self.itemType = itemType
        self.releaseVersion = releaseVersion
        self.sortOrder = sortOrder
        self.targetDate = targetDate
        self.productName = productName
        self.productSlugHint = productSlugHint
        self.linkedPostId = linkedPostId
    }
}

public struct ShipyardPlannerBulkCreateInput: Encodable, Sendable {
    public var titles: [String]
    public var productId: String?
    public var productSlug: String?
    public var description: String?
    public var status: String?
    public var visibility: String?
    public var origin: String?
    public var itemType: String?
    public var releaseVersion: String?
    public var targetDate: String?

    public init(
        titles: [String],
        productId: String? = nil,
        productSlug: String? = nil,
        description: String? = nil,
        status: String? = nil,
        visibility: String? = nil,
        origin: String? = nil,
        itemType: String? = nil,
        releaseVersion: String? = nil,
        targetDate: String? = nil
    ) {
        self.titles = titles
        self.productId = productId
        self.productSlug = productSlug
        self.description = description
        self.status = status
        self.visibility = visibility
        self.origin = origin
        self.itemType = itemType
        self.releaseVersion = releaseVersion
        self.targetDate = targetDate
    }
}

public struct ShipyardPlannerBulkUpdateInput: Encodable, Sendable {
    public var ids: [String]
    public var status: String?
    public var visibility: String?
    public var itemType: String?
    public var releaseVersion: String?
    public var targetDate: String?
    public var developerResponse: String?
    public var developerResponsePublic: Bool?

    public init(
        ids: [String],
        status: String? = nil,
        visibility: String? = nil,
        itemType: String? = nil,
        releaseVersion: String? = nil,
        targetDate: String? = nil,
        developerResponse: String? = nil,
        developerResponsePublic: Bool? = nil
    ) {
        self.ids = ids
        self.status = status
        self.visibility = visibility
        self.itemType = itemType
        self.releaseVersion = releaseVersion
        self.targetDate = targetDate
        self.developerResponse = developerResponse
        self.developerResponsePublic = developerResponsePublic
    }
}

public struct ShipyardPlannerTask: Codable, Identifiable, Sendable {
    public let id: String
    public let requestId: String
    public let title: String
    public let isDone: Bool
    public let orderIndex: Int
    public let createdAt: String?
}

public struct ShipyardPlannerTaskList: Codable, Sendable {
    public let request: ShipyardItem
    public let tasks: [ShipyardPlannerTask]
}

public struct ShipyardPlannerTaskInput: Encodable, Sendable {
    public var title: String?
    public var isDone: Bool?
    public var orderIndex: Int?

    public init(title: String? = nil, isDone: Bool? = nil, orderIndex: Int? = nil) {
        self.title = title
        self.isDone = isDone
        self.orderIndex = orderIndex
    }
}

public struct ShipyardPlannerBulkItemsEnvelope: Codable, Sendable {
    public let requests: [ShipyardItem]
    public let count: Int?
}

public struct ShipyardPlannerTaskEnvelope: Codable, Sendable {
    public let task: ShipyardPlannerTask
}

public struct ShipyardDeleteResult: Codable, Sendable {
    public let ok: Bool
}

public struct ShipyardPlannerCounts: Codable, Sendable {
    public let waitingReviewCount: Int
    public let hasNotifications: Bool
    public let latestWaitingReviewAt: String?
    public let refreshedAt: String?
}

public struct ShipyardItemCategory: Identifiable, Sendable {
    public let itemType: ShipyardItemType
    public let items: [ShipyardItem]

    public var id: String { itemType.rawValue }
    public var title: String { itemType.title }
    public var totalVotes: Int { items.reduce(0) { $0 + max(0, $1.voteCount) } }

    public init(itemType: ShipyardItemType, items: [ShipyardItem]) {
        self.itemType = itemType
        self.items = items.shipyardSortedByVotes()
    }
}

public struct ShipyardStatusGroup: Identifiable, Sendable {
    public let status: String
    public let title: String
    public let items: [ShipyardItem]

    public var id: String { status }
    public var totalVotes: Int { items.reduce(0) { $0 + max(0, $1.voteCount) } }

    public init(status: String, title: String, items: [ShipyardItem]) {
        self.status = status
        self.title = title
        self.items = items.shipyardSortedByVotes()
    }
}

public extension Array where Element == ShipyardItem {
    static var shipyardStatusOrder: [String] {
        ["open", "planned", "in_progress", "shipped", "closed"]
    }

    static func shipyardStatusTitle(_ status: String) -> String {
        switch status {
        case "open": return "Open"
        case "planned": return "Planned"
        case "in_progress": return "In Progress"
        case "shipped": return "Shipped"
        case "closed": return "Closed"
        default: return status
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + String($0.dropFirst()) }
            .joined(separator: " ")
        }
    }

    func shipyardSortedByVotes() -> [ShipyardItem] {
        sorted { lhs, rhs in
            if lhs.voteCount != rhs.voteCount {
                return lhs.voteCount > rhs.voteCount
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func shipyardGroupedByCategory() -> [ShipyardItemCategory] {
        let grouped = Dictionary(grouping: self, by: { $0.type })
        return ShipyardItemType.allCases.compactMap { type in
            guard let items = grouped[type], !items.isEmpty else { return nil }
            return ShipyardItemCategory(itemType: type, items: items)
        }
        .sorted { lhs, rhs in
            if lhs.totalVotes != rhs.totalVotes {
                return lhs.totalVotes > rhs.totalVotes
            }
            if lhs.items.count != rhs.items.count {
                return lhs.items.count > rhs.items.count
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func shipyardGroupedByStatus(includeEmpty: Bool = false) -> [ShipyardStatusGroup] {
        let grouped = Dictionary(grouping: self, by: { $0.normalizedStatus })
        let knownGroups = Self.shipyardStatusOrder.compactMap { status -> ShipyardStatusGroup? in
            let items = grouped[status] ?? []
            guard includeEmpty || !items.isEmpty else { return nil }
            return ShipyardStatusGroup(status: status, title: Self.shipyardStatusTitle(status), items: items)
        }

        let knownStatuses = Set(Self.shipyardStatusOrder)
        let customGroups = grouped.keys
            .filter { !knownStatuses.contains($0) }
            .sorted()
            .compactMap { status -> ShipyardStatusGroup? in
                let items = grouped[status] ?? []
                guard includeEmpty || !items.isEmpty else { return nil }
                return ShipyardStatusGroup(status: status, title: Self.shipyardStatusTitle(status), items: items)
            }

        return knownGroups + customGroups
    }
}

public struct ShipyardSessionInfo: Sendable {
    public let token: String
    public let expiresAt: Date
}

public enum ShipyardPromptType: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case singleChoice = "single_choice"
    case multiChoice = "multi_choice"
    case starRating = "star_rating"
    case numericRating = "numeric_rating"
    case openText = "open_text"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .singleChoice: return "Single Choice"
        case .multiChoice: return "Multiple Choice"
        case .starRating: return "5-Star Rating"
        case .numericRating: return "1 to 10 Rating"
        case .openText: return "Open Text"
        }
    }

    public var usesOptions: Bool {
        self == .singleChoice || self == .multiChoice
    }

    public var allowsMultipleOptions: Bool {
        self == .multiChoice
    }

    public var usesRating: Bool {
        self == .starRating || self == .numericRating
    }

    public var ratingRange: ClosedRange<Int>? {
        switch self {
        case .starRating: return 1...5
        case .numericRating: return 1...10
        case .singleChoice, .multiChoice, .openText: return nil
        }
    }
}
public typealias ShipyardCheckInType = ShipyardPromptType
public typealias ShipyardAskType = ShipyardPromptType

public struct ShipyardPromptOption: Codable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let value: String
    public let sortOrder: Int
    public let voteCount: Int?
}
public typealias ShipyardCheckInOption = ShipyardPromptOption
public typealias ShipyardAskOption = ShipyardPromptOption

public struct ShipyardPromptResponse: Codable, Sendable {
    public let selectedOptionIds: [String]
    public let ratingValue: Int?
    public let responseText: String?
    public let submittedAt: String
    public let updatedAt: String
}
public typealias ShipyardCheckInResponse = ShipyardPromptResponse
public typealias ShipyardAskResponse = ShipyardPromptResponse

public struct ShipyardPrompt: Codable, Identifiable, Sendable {
    public let id: String
    public let productId: String?
    public let title: String
    public let description: String?
    public let promptType: String
    public let status: String
    public let resultsVisibility: String
    public let minRating: Int
    public let maxRating: Int
    public let maxSelections: Int?
    public let startsAt: String?
    public let endsAt: String?
    public let state: String
    public let responseCount: Int
    public let averageRating: Double?
    public let options: [ShipyardPromptOption]
    public let myResponse: ShipyardPromptResponse?
    public let resultsVisible: Bool

    public var type: ShipyardPromptType? {
        ShipyardPromptType(rawValue: promptType)
    }

    public var typeTitle: String {
        type?.title ?? promptType
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + String($0.dropFirst()) }
            .joined(separator: " ")
    }

    public var usesOptions: Bool {
        type?.usesOptions ?? false
    }

    public var allowsMultipleOptions: Bool {
        type?.allowsMultipleOptions ?? false
    }

    public var usesRating: Bool {
        type?.usesRating ?? false
    }

    public var ratingRange: ClosedRange<Int>? {
        if let range = type?.ratingRange {
            return range
        }
        guard usesRating else { return nil }
        return min(minRating, maxRating)...max(minRating, maxRating)
    }

    public var hasCurrentResponse: Bool {
        myResponse != nil
    }
}
public typealias ShipyardCheckIn = ShipyardPrompt
public typealias ShipyardAsk = ShipyardPrompt

public struct ShipyardAnnouncementState: Codable, Sendable {
    public let shownCount: Int
    public let dismissedAt: String?
    public let clickedAt: String?
}

public struct ShipyardAnnouncement: Codable, Identifiable, Sendable {
    public let id: String
    public let productId: String?
    public let title: String
    public let body: String
    public let ctaLabel: String?
    public let ctaUrl: String?
    public let status: String
    public let priority: Int
    public let clearable: Bool
    public let showOnce: Bool
    public let startsAt: String?
    public let endsAt: String?
    public let state: String
    public let shownCount: Int
    public let dismissCount: Int
    public let clickCount: Int
    public let myState: ShipyardAnnouncementState?
}

public struct ShipyardEngagementUpdates: Sendable {
    public let asks: [ShipyardAsk]
    public let announcements: [ShipyardAnnouncement]
    public let refreshedAt: Date?

    public init(
        asks: [ShipyardAsk],
        announcements: [ShipyardAnnouncement],
        refreshedAt: Date?
    ) {
        self.asks = asks
        self.announcements = announcements
        self.refreshedAt = refreshedAt
    }

    @available(*, deprecated, renamed: "asks")
    public var checkIns: [ShipyardCheckIn] { asks }

    @available(*, deprecated, renamed: "asks")
    public var prompts: [ShipyardPrompt] { asks }
}

public enum ShipyardAnnouncementEventType: String, Codable, Sendable {
    case shown
    case dismissed
    case clicked
}

public struct ShipyardAnnouncementEventResult: Codable, Sendable {
    public let ok: Bool
    public let duplicate: Bool?
    public let announcement: ShipyardAnnouncement?
}

public struct ShipyardNotificationSubscription: Codable, Identifiable, Sendable {
    public let id: String
    public let provider: String
    public let environment: String
    public let platform: String
    public let enabled: Bool
    public let updatedAt: String
}

public struct ShipyardNotificationSubscriptionResult: Codable, Sendable {
    public let subscription: ShipyardNotificationSubscription?
}

public struct ShipyardNotificationSubscriptionDeleteResult: Codable, Sendable {
    public let disabled: Bool
    public let count: Int
}

public struct ShipyardPromptResponseResult: Codable, Sendable {
    public let ok: Bool
    public let prompt: ShipyardPrompt
    public let checkIn: ShipyardCheckIn?
    public let ask: ShipyardAsk?
}
public typealias ShipyardCheckInResponseResult = ShipyardPromptResponseResult
public typealias ShipyardAskResponseResult = ShipyardPromptResponseResult

public enum ShipyardError: Error, LocalizedError {
    case invalidURL
    case server(String, Int)
    case decodingFailed
    case missingToken
    case offlineQueued
    case offlineCacheUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Shipyard base URL."
        case .server(let message, let status):
            return "Shipyard error (\(status)): \(message)"
        case .decodingFailed:
            return "Could not decode Shipyard response."
        case .missingToken:
            return "Missing Shipyard token."
        case .offlineQueued:
            return "Saved offline. This change is queued and will sync automatically when Shipyard is online."
        case .offlineCacheUnavailable:
            return "Shipyard is offline and no cached data is available yet."
        }
    }
}

public struct ShipyardOfflineSyncResult: Sendable {
    public let flushedCount: Int
    public let droppedCount: Int
    public let remainingCount: Int

    public init(flushedCount: Int, droppedCount: Int = 0, remainingCount: Int) {
        self.flushedCount = flushedCount
        self.droppedCount = droppedCount
        self.remainingCount = remainingCount
    }
}

public struct ShipyardDailySyncResult: Sendable {
    public let roadmapItems: [ShipyardItem]?
    public let engagementUpdates: ShipyardEngagementUpdates?
    public let offlineWrites: ShipyardOfflineSyncResult
    public let isComplete: Bool

    public init(
        roadmapItems: [ShipyardItem]?,
        engagementUpdates: ShipyardEngagementUpdates?,
        offlineWrites: ShipyardOfflineSyncResult,
        isComplete: Bool
    ) {
        self.roadmapItems = roadmapItems
        self.engagementUpdates = engagementUpdates
        self.offlineWrites = offlineWrites
        self.isComplete = isComplete
    }
}

private struct SessionResponse: Codable {
    let token: String
    let expiresAt: String
}

private struct ItemsEnvelope: Codable {
    let requests: [ShipyardItem]
}

private struct ItemEnvelope: Codable {
    let request: ShipyardItem
}

private struct ProductEnvelope: Codable {
    let product: ShipyardProduct
}

private struct PromptsEnvelope: Codable {
    let asks: [ShipyardAsk]?
    let checkIns: [ShipyardCheckIn]?
    let prompts: [ShipyardPrompt]

    enum CodingKeys: String, CodingKey {
        case asks
        case checkIns
        case prompts
    }
}

private struct AnnouncementsEnvelope: Codable {
    let announcements: [ShipyardAnnouncement]
}

private struct EngagementUpdatesEnvelope: Codable {
    let asks: [ShipyardAsk]?
    let checkIns: [ShipyardCheckIn]?
    let prompts: [ShipyardPrompt]
    let announcements: [ShipyardAnnouncement]
    let refreshedAt: String?

    enum CodingKeys: String, CodingKey {
        case asks
        case checkIns
        case prompts
        case announcements
        case refreshedAt
    }
}

private struct PromptResponseRequest: Codable {
    let optionId: String?
    let optionIds: [String]?
    let ratingValue: Int?
    let responseText: String?
}

private struct AnnouncementEventRequest: Codable {
    let eventType: String
    let visibleMs: Int?
    let screenKey: String?
}

private struct NotificationSubscriptionRequest: Codable {
    let provider: String
    let environment: String?
    let endpointToken: String?
    let enabled: Bool?
    let metadata: [String: String]?
}

private struct SubmitItemRequest: Codable {
    let title: String
    let description: String?
    let itemType: String
}

private actor SessionStore {
    private var token: String?
    private var expiresAt: Date?

    func validToken(now: Date = Date()) -> String? {
        guard let token, let expiresAt else { return nil }
        // Refresh if within 2 minutes of expiry.
        if expiresAt.timeIntervalSince(now) <= 120 {
            return nil
        }
        return token
    }

    func set(token: String, expiresAt: Date) {
        self.token = token
        self.expiresAt = expiresAt
    }
}

fileprivate struct ShipyardClientScope: Codable, Hashable, Sendable {
    var baseURLString: String
    var productSlug: String

    init(baseURL: URL, productSlug: String) {
        self.baseURLString = Self.normalizedBaseURLString(baseURL)
        self.productSlug = productSlug
    }

    static func normalizedBaseURLString(_ url: URL) -> String {
        let raw = url.absoluteString
        return raw.hasSuffix("/") ? String(raw.dropLast()) : raw
    }
}

private actor ShipyardClientCache {
    static let shared = ShipyardClientCache()

    private var memory: [String: (data: Data, storedAt: Date)] = [:]
    private let directory: URL

    init() {
        let supportBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = supportBase
            .appendingPathComponent("ShipyardKit", isDirectory: true)
            .appendingPathComponent("APICache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func data(for key: String) -> Data? {
        if let cached = memory[key] {
            return cached.data
        }
        let fileURL = fileURLForKey(key)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        let storedAt = fileStoredAt(fileURL) ?? Date.distantPast
        memory[key] = (data, storedAt)
        return data
    }

    func freshData(for key: String, maxAge: TimeInterval, now: Date = Date()) -> Data? {
        guard maxAge > 0 else { return nil }
        if let cached = memory[key], now.timeIntervalSince(cached.storedAt) <= maxAge {
            return cached.data
        }
        let fileURL = fileURLForKey(key)
        guard let data = try? Data(contentsOf: fileURL),
              let storedAt = fileStoredAt(fileURL),
              now.timeIntervalSince(storedAt) <= maxAge
        else {
            return nil
        }
        memory[key] = (data, storedAt)
        return data
    }

    func store(_ data: Data, for key: String) {
        memory[key] = (data, Date())
        try? data.write(to: fileURLForKey(key), options: [.atomic])
    }

    func clear() {
        memory.removeAll()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURLForKey(_ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(filename).appendingPathExtension("json")
    }

    private func fileStoredAt(_ fileURL: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate]) as? Date
    }
}

fileprivate struct ShipyardQueuedQueryItem: Codable, Hashable, Sendable {
    var name: String
    var value: String?

    init(_ item: URLQueryItem) {
        name = item.name
        value = item.value
    }

    var urlQueryItem: URLQueryItem {
        URLQueryItem(name: name, value: value)
    }
}

fileprivate struct ShipyardQueuedWrite: Codable, Identifiable, Sendable {
    var id: UUID
    var scope: ShipyardClientScope
    var path: String
    var method: String
    var queryItems: [ShipyardQueuedQueryItem]
    var body: Data?
    var contentType: String?
    var queuedAt: Date
    var attempts: Int
    var lastError: String?

    init(
        scope: ShipyardClientScope,
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Data?,
        contentType: String?
    ) {
        id = UUID()
        self.scope = scope
        self.path = path
        self.method = method
        self.queryItems = queryItems.map(ShipyardQueuedQueryItem.init)
        self.body = body
        self.contentType = contentType
        queuedAt = Date()
        attempts = 0
        lastError = nil
    }
}

private actor ShipyardOfflineWriteQueue {
    static let shared = ShipyardOfflineWriteQueue()

    private var isLoaded = false
    private var entries: [ShipyardQueuedWrite] = []
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let supportBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = supportBase.appendingPathComponent("ShipyardKit", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("OfflineWriteQueue").appendingPathExtension("json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func count(for scope: ShipyardClientScope? = nil) -> Int {
        loadIfNeeded()
        guard let scope else {
            return entries.count
        }
        return entries.filter { $0.scope == scope }.count
    }

    func enqueue(
        scope: ShipyardClientScope,
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Data?,
        contentType: String?
    ) {
        loadIfNeeded()
        entries.append(
            ShipyardQueuedWrite(
                scope: scope,
                path: path,
                method: method,
                queryItems: queryItems,
                body: body,
                contentType: contentType
            )
        )
        persist()
    }

    func flush(using client: ShipyardClient) async -> ShipyardOfflineSyncResult {
        loadIfNeeded()
        let scope = client.offlineScope
        guard entries.contains(where: { $0.scope == scope }) else {
            return ShipyardOfflineSyncResult(flushedCount: 0, remainingCount: entries.count)
        }

        var flushedCount = 0
        var droppedCount = 0
        var remaining: [ShipyardQueuedWrite] = []
        var stoppedReplayingCurrentScope = false

        for var entry in entries {
            guard entry.scope == scope, !stoppedReplayingCurrentScope else {
                remaining.append(entry)
                continue
            }

            do {
                try await client.replayQueuedWrite(entry)
                flushedCount += 1
            } catch {
                entry.attempts += 1
                entry.lastError = error.localizedDescription

                if Self.shouldDropQueuedWrite(after: error) {
                    droppedCount += 1
                    continue
                }

                remaining.append(entry)
                if ShipyardClient.isConnectivityError(error) || Self.isAuthorizationError(error) || Self.isRetryableServerError(error) {
                    stoppedReplayingCurrentScope = true
                }
            }
        }

        entries = remaining
        persist()
        return ShipyardOfflineSyncResult(
            flushedCount: flushedCount,
            droppedCount: droppedCount,
            remainingCount: entries.filter { $0.scope == scope }.count
        )
    }

    func clear(scope: ShipyardClientScope? = nil) {
        loadIfNeeded()
        if let scope {
            entries.removeAll { $0.scope == scope }
        } else {
            entries.removeAll()
        }
        persist()
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        defer { isLoaded = true }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? decoder.decode([ShipyardQueuedWrite].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private static func isAuthorizationError(_ error: Error) -> Bool {
        guard case ShipyardError.server(_, let status) = error else { return false }
        return status == 401 || status == 403
    }

    private static func isRetryableServerError(_ error: Error) -> Bool {
        guard case ShipyardError.server(_, let status) = error else { return false }
        return status == 408 || status == 425 || status == 429 || status >= 500
    }

    private static func shouldDropQueuedWrite(after error: Error) -> Bool {
        guard case ShipyardError.server(_, let status) = error else { return false }
        guard (400..<500).contains(status) else { return false }
        return status != 408 && status != 425 && status != 429 && status != 401 && status != 403
    }
}

private final class ShipyardConnectivityMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ShipyardKit.NetworkMonitor", qos: .utility)

    init(onOnline: @escaping @Sendable () -> Void) {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                onOnline()
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

/// Stable per-install identifier persisted in the Keychain so it survives
/// app reinstalls and OS restores that keep the keychain. Falls back to a
/// UserDefaults-persisted UUID when the Keychain is unavailable. Using this
/// keeps "active device" counts honest: a reinstall does not mint a new
/// device.
public enum ShipyardInstallationIdentifier {
    public static func stable(
        service: String = "ShipyardKit",
        account: String = "installation-id",
        userDefaults: UserDefaults = .standard
    ) -> String {
        let defaultsKey = "shipyardkit_installation_id"
        if let existing = readKeychain(service: service, account: account), !existing.isEmpty {
            return existing
        }
        if let fallback = userDefaults.string(forKey: defaultsKey), !fallback.isEmpty {
            // Migrate a pre-Keychain id forward so the device identity is kept.
            _ = writeKeychain(service: service, account: account, value: fallback)
            return fallback
        }
        let generated = UUID().uuidString
        if !writeKeychain(service: service, account: account, value: generated) {
            userDefaults.set(generated, forKey: defaultsKey)
        }
        return generated
    }

    private static func readKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    private static func writeKeychain(service: String, account: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(baseQuery as CFDictionary)
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
}

public final class ShipyardClient: @unchecked Sendable {
    public static let sdkVersion = "0.2.3"
    public static let engagementReadCacheTTL: TimeInterval = 15 * 60

    public let baseURL: URL
    public let productSlug: String
    public let platform: String

    private let installationIdProvider: @Sendable () -> String
    private let appVersionProvider: @Sendable () -> String?
    private let buildNumberProvider: @Sendable () -> String?
    private let urlSession: URLSession
    private let sessionStore = SessionStore()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let cache = ShipyardClientCache.shared
    private let offlineWriteQueue = ShipyardOfflineWriteQueue.shared
    private var connectivityMonitor: ShipyardConnectivityMonitor?

    public static func inferredPlatform() -> String {
        #if os(tvOS)
        return "tvos"
        #elseif os(watchOS)
        return "watchos"
        #elseif os(visionOS)
        return "visionos"
        #elseif targetEnvironment(macCatalyst)
        return "macos"
        #elseif os(macOS)
        return "macos"
        #elseif os(iOS)
        #if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "ipados"
        }
        #endif
        return "ios"
        #else
        return "ios"
        #endif
    }

    public static func inferredAppVersion() -> String? {
        let value = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func inferredBuildNumber() -> String? {
        let value = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    public init(
        baseURL: URL,
        productSlug: String,
        platform: String = ShipyardClient.inferredPlatform(),
        installationIdProvider: @escaping @Sendable () -> String,
        appVersionProvider: @escaping @Sendable () -> String? = { ShipyardClient.inferredAppVersion() },
        buildNumberProvider: @escaping @Sendable () -> String? = { ShipyardClient.inferredBuildNumber() },
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.productSlug = productSlug
        self.platform = platform
        self.installationIdProvider = installationIdProvider
        self.appVersionProvider = appVersionProvider
        self.buildNumberProvider = buildNumberProvider
        self.urlSession = urlSession
        self.connectivityMonitor = nil
        self.connectivityMonitor = ShipyardConnectivityMonitor { [weak self] in
            guard let client = self else { return }
            Task {
                await client.syncQueuedWritesIfPossible()
            }
        }
    }

    public func fetchItems(status: String? = nil) async throws -> [ShipyardItem] {
        let queryItems = roadmapQueryItems(status: status)
        let data: Data
        do {
            data = try await authedReadRequest(path: "v1/requests", queryItems: queryItems)
        } catch {
            if !Self.isAuthorizationError(error) {
                throw error
            }
            data = try await readRequest(path: "v1/requests", queryItems: queryItems)
        }
        do {
            return try decoder.decode(ItemsEnvelope.self, from: data).requests
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func cachedItems(status: String? = nil) async -> [ShipyardItem]? {
        let queryItems = roadmapQueryItems(status: status)
        let key = cacheKey(path: "v1/requests", queryItems: queryItems)
        guard let data = await cache.data(for: key) else { return nil }
        return try? decoder.decode(ItemsEnvelope.self, from: data).requests
    }

    private func fetchItemsFromNetwork(status: String? = nil) async throws -> [ShipyardItem] {
        let queryItems = roadmapQueryItems(status: status)
        let data: Data
        do {
            data = try await authedReadRequest(
                path: "v1/requests",
                queryItems: queryItems,
                allowCachedFallback: false
            )
        } catch {
            if !Self.isAuthorizationError(error) {
                throw error
            }
            data = try await readRequest(
                path: "v1/requests",
                queryItems: queryItems,
                allowCachedFallback: false
            )
        }
        do {
            return try decoder.decode(ItemsEnvelope.self, from: data).requests
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func fetchItemCategories(status: String? = nil) async throws -> [ShipyardItemCategory] {
        let items = try await fetchItems(status: status)
        return items.shipyardGroupedByCategory()
    }

    public func fetchProducts(
        visibility: String? = nil,
        status: String? = nil,
        type: String? = nil,
        versionStatus: String? = nil,
        workingVersion: String? = nil,
        productNumber: String? = nil,
        sort: String? = nil,
        minProgress: Int? = nil,
        maxProgress: Int? = nil,
        includePriority: Bool? = nil,
        includeLatestUpdates: Bool? = nil,
        includeSupport: Bool? = nil,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> [ShipyardProduct] {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        var queryItems = serviceQueryItems(workspaceSlug: workspaceSlug)
        appendQueryItemIfPresent(name: "visibility", value: visibility, to: &queryItems)
        appendQueryItemIfPresent(name: "status", value: status, to: &queryItems)
        appendQueryItemIfPresent(name: "type", value: type, to: &queryItems)
        appendQueryItemIfPresent(name: "versionStatus", value: versionStatus, to: &queryItems)
        appendQueryItemIfPresent(name: "workingVersion", value: workingVersion, to: &queryItems)
        appendQueryItemIfPresent(name: "productNumber", value: productNumber, to: &queryItems)
        appendQueryItemIfPresent(name: "sort", value: sort, to: &queryItems)
        appendQueryItemIfPresent(name: "includePriority", value: includePriority, to: &queryItems)
        appendQueryItemIfPresent(name: "includeLatestUpdates", value: includeLatestUpdates, to: &queryItems)
        appendQueryItemIfPresent(name: "includeSupport", value: includeSupport, to: &queryItems)
        if let minProgress {
            queryItems.append(URLQueryItem(name: "minProgress", value: String(minProgress)))
        }
        if let maxProgress {
            queryItems.append(URLQueryItem(name: "maxProgress", value: String(maxProgress)))
        }

        let data = try await sendRequest(path: "v1/products", method: "GET", token: token, queryItems: queryItems)
        do {
            return try decoder.decode(ShipyardProductList.self, from: data).products
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    /// Verifies that a database-backed service key is valid for the requested workspace and
    /// returns its granted scopes. Unlike product listing, this endpoint cannot succeed through
    /// the public-read fallback, so native admin tools can use it as a connection check.
    public func fetchCurrentServiceAPIKey(
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardServiceAPIKeyStatus {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/settings/api-key/current",
            method: "GET",
            token: token,
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ShipyardServiceAPIKeyStatus.self, from: data)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func fetchProduct(
        slug: String,
        includePlanner: Bool = true,
        includePriority: Bool? = nil,
        includeLatestUpdates: Bool? = nil,
        includeSupport: Bool? = nil,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardProductDetail {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        var queryItems = serviceQueryItems(workspaceSlug: workspaceSlug)
        if includePlanner {
            queryItems.append(URLQueryItem(name: "includePlanner", value: "1"))
        }
        appendQueryItemIfPresent(name: "includePriority", value: includePriority, to: &queryItems)
        appendQueryItemIfPresent(name: "includeLatestUpdates", value: includeLatestUpdates, to: &queryItems)
        appendQueryItemIfPresent(name: "includeSupport", value: includeSupport, to: &queryItems)
        let data = try await sendRequest(
            path: "v1/products/\(pathComponent(slug))",
            method: "GET",
            token: token,
            queryItems: queryItems
        )
        do {
            return try decoder.decode(ShipyardProductDetail.self, from: data)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func updateProduct(
        slug: String,
        update: ShipyardProductUpdate,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardProduct {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/products/\(pathComponent(slug))",
            method: "PATCH",
            token: token,
            body: try encoder.encode(update),
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ProductEnvelope.self, from: data).product
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func createProduct(
        _ input: ShipyardProductInput,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardProduct {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/products",
            method: "POST",
            token: token,
            body: try encoder.encode(input),
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ProductEnvelope.self, from: data).product
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func uploadProductIcon(
        slug: String,
        imageData: Data,
        fileName: String,
        mimeType: String,
        platform: String = "ios",
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardProduct {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }
        let boundary = "ShipyardKit-\(UUID().uuidString)"
        var body = Data()
        func append(_ value: String) { body.append(Data(value.utf8)) }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"platform\"\r\n\r\n\(platform)\r\n")
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\nContent-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        append("\r\n--\(boundary)--\r\n")

        let data = try await sendRequest(
            path: "v1/products/\(pathComponent(slug))/icon",
            method: "POST",
            token: token,
            body: body,
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug),
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        do {
            return try decoder.decode(ShipyardProductIconUploadResult.self, from: data).product
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func fetchPlannerCounts(
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardPlannerCounts {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/requests/counts",
            method: "GET",
            token: token,
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ShipyardPlannerCounts.self, from: data)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func createPlannerItem(
        _ input: ShipyardPlannerItemInput,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardItem {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/requests",
            method: "POST",
            token: token,
            body: try encoder.encode(input),
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ItemEnvelope.self, from: data).request
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func updatePlannerItem(
        itemId: String,
        update: ShipyardPlannerItemUpdate,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardItem {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/requests/\(pathComponent(itemId))",
            method: "PATCH",
            token: token,
            body: try encoder.encode(update),
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ItemEnvelope.self, from: data).request
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func createPlannerItems(
        _ input: ShipyardPlannerBulkCreateInput,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> [ShipyardItem] {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/requests/bulk",
            method: "POST",
            token: token,
            body: try encoder.encode(input),
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ShipyardPlannerBulkItemsEnvelope.self, from: data).requests
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func updatePlannerItems(
        _ input: ShipyardPlannerBulkUpdateInput,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardPlannerBulkItemsEnvelope {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/requests/bulk",
            method: "PATCH",
            token: token,
            body: try encoder.encode(input),
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ShipyardPlannerBulkItemsEnvelope.self, from: data)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func fetchPlannerTasks(
        itemId: String,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardPlannerTaskList {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/requests/\(pathComponent(itemId))/tasks",
            method: "GET",
            token: token,
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ShipyardPlannerTaskList.self, from: data)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func createPlannerTask(
        itemId: String,
        title: String,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardPlannerTask {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/requests/\(pathComponent(itemId))/tasks",
            method: "POST",
            token: token,
            body: try encoder.encode(ShipyardPlannerTaskInput(title: title)),
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ShipyardPlannerTaskEnvelope.self, from: data).task
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func updatePlannerTask(
        itemId: String,
        taskId: String,
        update: ShipyardPlannerTaskInput,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardPlannerTask {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/requests/\(pathComponent(itemId))/tasks/\(pathComponent(taskId))",
            method: "PATCH",
            token: token,
            body: try encoder.encode(update),
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ShipyardPlannerTaskEnvelope.self, from: data).task
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    @discardableResult
    public func deletePlannerTask(
        itemId: String,
        taskId: String,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> Bool {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let data = try await sendRequest(
            path: "v1/requests/\(pathComponent(itemId))/tasks/\(pathComponent(taskId))",
            method: "DELETE",
            token: token,
            queryItems: serviceQueryItems(workspaceSlug: workspaceSlug)
        )
        do {
            return try decoder.decode(ShipyardDeleteResult.self, from: data).ok
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func fetchSiteAnalytics(
        days: Int = 7,
        hostname: String? = nil,
        workspaceSlug: String? = nil,
        productId: String? = nil,
        refresh: Bool = false,
        apiToken: String
    ) async throws -> ShipyardSiteAnalytics {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        var queryItems = [URLQueryItem(name: "days", value: String(days == 30 ? 30 : 7))]
        if let hostname = hostname?.trimmingCharacters(in: .whitespacesAndNewlines), !hostname.isEmpty {
            queryItems.append(URLQueryItem(name: "hostname", value: hostname))
        }
        if let workspaceSlug = workspaceSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !workspaceSlug.isEmpty {
            queryItems.append(URLQueryItem(name: "ws", value: workspaceSlug))
        }
        if let productId = productId?.trimmingCharacters(in: .whitespacesAndNewlines), !productId.isEmpty {
            queryItems.append(URLQueryItem(name: "productId", value: productId))
        }
        if refresh {
            queryItems.append(URLQueryItem(name: "refresh", value: "1"))
        }

        let data = try await sendRequest(path: "v1/analytics/web", method: "GET", token: token, queryItems: queryItems)
        do {
            return try decoder.decode(ShipyardSiteAnalytics.self, from: data)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func fetchAppAnalytics(
        days: Int = 30,
        productId: String? = nil,
        view: String? = nil,
        activity: String? = nil,
        workspaceSlug: String? = nil,
        apiToken: String
    ) async throws -> ShipyardAppAnalytics {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        let allowedDays: Set<Int> = [7, 30, 90, 180]
        var queryItems = [URLQueryItem(name: "days", value: String(allowedDays.contains(days) ? days : 30))]
        if let productId = productId?.trimmingCharacters(in: .whitespacesAndNewlines), !productId.isEmpty {
            queryItems.append(URLQueryItem(name: "productId", value: productId))
        }
        if let view = view?.trimmingCharacters(in: .whitespacesAndNewlines), !view.isEmpty {
            queryItems.append(URLQueryItem(name: "view", value: view))
        }
        if let activity = activity?.trimmingCharacters(in: .whitespacesAndNewlines), !activity.isEmpty {
            queryItems.append(URLQueryItem(name: "activity", value: activity))
        }
        if let workspaceSlug = workspaceSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !workspaceSlug.isEmpty {
            queryItems.append(URLQueryItem(name: "ws", value: workspaceSlug))
        }

        let data = try await sendRequest(path: "v1/analytics", method: "GET", token: token, queryItems: queryItems)
        do {
            return try decoder.decode(ShipyardAppAnalytics.self, from: data)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    @discardableResult
    public func startAppAnalyticsSync(
        workspaceSlug: String? = nil,
        restart: Bool = false,
        apiToken: String
    ) async throws -> ShipyardAppAnalyticsSyncResult {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ShipyardError.missingToken }

        var queryItems: [URLQueryItem] = []
        if let workspaceSlug = workspaceSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !workspaceSlug.isEmpty {
            queryItems.append(URLQueryItem(name: "ws", value: workspaceSlug))
        }
        if restart {
            queryItems.append(URLQueryItem(name: "restart", value: "force"))
        }

        let data = try await sendRequest(path: "v1/analytics/sync", method: "POST", token: token, queryItems: queryItems)
        do {
            return try decoder.decode(ShipyardAppAnalyticsSyncResult.self, from: data)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func fetchAsks(
        history: Bool = false,
        cachePolicy: ShipyardReadCachePolicy = .automatic
    ) async throws -> [ShipyardAsk] {
        let data = try await authedReadRequest(
            path: "v1/engagement/asks",
            queryItems: engagementQueryItems(history: history),
            cacheTTL: history ? 0 : Self.engagementReadCacheTTL,
            cachePolicy: cachePolicy
        )
        do {
            let envelope = try decoder.decode(PromptsEnvelope.self, from: data)
            return envelope.asks ?? envelope.checkIns ?? envelope.prompts
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func fetchPrompts(
        history: Bool = false,
        cachePolicy: ShipyardReadCachePolicy = .automatic
    ) async throws -> [ShipyardPrompt] {
        try await fetchAsks(history: history, cachePolicy: cachePolicy)
    }

    @available(*, deprecated, renamed: "fetchAsks(history:cachePolicy:)")
    public func fetchCheckIns(
        history: Bool = false,
        cachePolicy: ShipyardReadCachePolicy = .automatic
    ) async throws -> [ShipyardCheckIn] {
        try await fetchAsks(history: history, cachePolicy: cachePolicy)
    }

    public func fetchAnnouncements(
        history: Bool = false,
        cachePolicy: ShipyardReadCachePolicy = .automatic
    ) async throws -> [ShipyardAnnouncement] {
        let data = try await authedReadRequest(
            path: "v1/engagement/announcements",
            queryItems: engagementQueryItems(history: history),
            cacheTTL: history ? 0 : Self.engagementReadCacheTTL,
            cachePolicy: cachePolicy
        )
        do {
            return try decoder.decode(AnnouncementsEnvelope.self, from: data).announcements
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func fetchEngagementUpdates(
        history: Bool = false,
        cachePolicy: ShipyardReadCachePolicy = .automatic
    ) async throws -> ShipyardEngagementUpdates {
        let data = try await authedReadRequest(
            path: "v1/engagement/updates",
            queryItems: engagementQueryItems(history: history),
            cacheTTL: history ? 0 : Self.engagementReadCacheTTL,
            cachePolicy: cachePolicy
        )
        return try decodeEngagementUpdates(data)
    }

    public func cachedEngagementUpdates(history: Bool = false) async -> ShipyardEngagementUpdates? {
        let queryItems = engagementQueryItems(history: history)
        let key = cacheKey(path: "v1/engagement/updates", queryItems: queryItems)
        guard let data = await cache.data(for: key) else { return nil }
        return try? decodeEngagementUpdates(data)
    }

    private func fetchEngagementUpdatesFromNetwork(history: Bool) async throws -> ShipyardEngagementUpdates {
        let data = try await authedReadRequest(
            path: "v1/engagement/updates",
            queryItems: engagementQueryItems(history: history),
            cachePolicy: .reloadIgnoringCache,
            allowCachedFallback: false
        )
        return try decodeEngagementUpdates(data)
    }

    private func decodeEngagementUpdates(_ data: Data) throws -> ShipyardEngagementUpdates {
        let envelope: EngagementUpdatesEnvelope
        do {
            envelope = try decoder.decode(EngagementUpdatesEnvelope.self, from: data)
        } catch {
            throw ShipyardError.decodingFailed
        }
        return ShipyardEngagementUpdates(
            asks: envelope.asks ?? envelope.checkIns ?? envelope.prompts,
            announcements: envelope.announcements,
            refreshedAt: ShipyardDateParser.date(from: envelope.refreshedAt)
        )
    }

    public func respondToAsk(
        askId: String,
        optionId: String
    ) async throws -> ShipyardAsk {
        try await respondToEngagementPrompt(
            promptId: askId,
            pathSegment: "asks",
            optionIds: [optionId],
            ratingValue: nil,
            responseText: nil
        )
    }

    public func respondToAsk(
        askId: String,
        optionIds: [String]
    ) async throws -> ShipyardAsk {
        try await respondToEngagementPrompt(
            promptId: askId,
            pathSegment: "asks",
            optionIds: optionIds,
            ratingValue: nil,
            responseText: nil
        )
    }

    public func respondToAsk(
        askId: String,
        ratingValue: Int
    ) async throws -> ShipyardAsk {
        try await respondToEngagementPrompt(
            promptId: askId,
            pathSegment: "asks",
            optionIds: nil,
            ratingValue: ratingValue,
            responseText: nil
        )
    }

    public func respondToAsk(
        askId: String,
        responseText: String
    ) async throws -> ShipyardAsk {
        try await respondToEngagementPrompt(
            promptId: askId,
            pathSegment: "asks",
            optionIds: nil,
            ratingValue: nil,
            responseText: responseText
        )
    }

    public func respondToPrompt(
        promptId: String,
        optionId: String
    ) async throws -> ShipyardPrompt {
        try await respondToEngagementPrompt(
            promptId: promptId,
            pathSegment: "prompts",
            optionIds: [optionId],
            ratingValue: nil,
            responseText: nil
        )
    }

    public func respondToPrompt(
        promptId: String,
        optionIds: [String]
    ) async throws -> ShipyardPrompt {
        try await respondToEngagementPrompt(
            promptId: promptId,
            pathSegment: "prompts",
            optionIds: optionIds,
            ratingValue: nil,
            responseText: nil
        )
    }

    public func respondToPrompt(
        promptId: String,
        ratingValue: Int
    ) async throws -> ShipyardPrompt {
        try await respondToEngagementPrompt(
            promptId: promptId,
            pathSegment: "prompts",
            optionIds: nil,
            ratingValue: ratingValue,
            responseText: nil
        )
    }

    public func respondToPrompt(
        promptId: String,
        responseText: String
    ) async throws -> ShipyardPrompt {
        try await respondToEngagementPrompt(
            promptId: promptId,
            pathSegment: "prompts",
            optionIds: nil,
            ratingValue: nil,
            responseText: responseText
        )
    }

    @available(*, deprecated, renamed: "respondToAsk(askId:optionId:)")
    public func respondToCheckIn(
        checkInId: String,
        optionId: String
    ) async throws -> ShipyardCheckIn {
        try await respondToAsk(askId: checkInId, optionId: optionId)
    }

    @available(*, deprecated, renamed: "respondToAsk(askId:optionIds:)")
    public func respondToCheckIn(
        checkInId: String,
        optionIds: [String]
    ) async throws -> ShipyardCheckIn {
        try await respondToAsk(askId: checkInId, optionIds: optionIds)
    }

    @available(*, deprecated, renamed: "respondToAsk(askId:ratingValue:)")
    public func respondToCheckIn(
        checkInId: String,
        ratingValue: Int
    ) async throws -> ShipyardCheckIn {
        try await respondToAsk(askId: checkInId, ratingValue: ratingValue)
    }

    @available(*, deprecated, renamed: "respondToAsk(askId:responseText:)")
    public func respondToCheckIn(
        checkInId: String,
        responseText: String
    ) async throws -> ShipyardCheckIn {
        try await respondToAsk(askId: checkInId, responseText: responseText)
    }

    public func recordAnnouncementEvent(
        announcementId: String,
        eventType: ShipyardAnnouncementEventType,
        visibleMs: Int? = nil,
        screenKey: String? = nil
    ) async throws -> ShipyardAnnouncementEventResult {
        let payload = AnnouncementEventRequest(
            eventType: eventType.rawValue,
            visibleMs: visibleMs,
            screenKey: normalizedOptionalText(screenKey, maxLength: 120)
        )
        let data = try encoder.encode(payload)
        let responseData = try await authedWriteRequest(
            path: "v1/engagement/announcements/\(announcementId)/events",
            method: "POST",
            body: data
        )
        do {
            return try decoder.decode(ShipyardAnnouncementEventResult.self, from: responseData)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    @discardableResult
    public func markAnnouncementShown(
        announcementId: String,
        visibleMs: Int? = nil,
        screenKey: String? = nil
    ) async throws -> ShipyardAnnouncement? {
        let result = try await recordAnnouncementEvent(
            announcementId: announcementId,
            eventType: .shown,
            visibleMs: visibleMs,
            screenKey: screenKey
        )
        return result.announcement
    }

    @discardableResult
    public func dismissAnnouncement(
        announcementId: String,
        screenKey: String? = nil
    ) async throws -> ShipyardAnnouncement? {
        let result = try await recordAnnouncementEvent(
            announcementId: announcementId,
            eventType: .dismissed,
            visibleMs: nil,
            screenKey: screenKey
        )
        return result.announcement
    }

    @discardableResult
    public func clickAnnouncement(
        announcementId: String,
        screenKey: String? = nil
    ) async throws -> ShipyardAnnouncement? {
        let result = try await recordAnnouncementEvent(
            announcementId: announcementId,
            eventType: .clicked,
            visibleMs: nil,
            screenKey: screenKey
        )
        return result.announcement
    }

    @discardableResult
    public func registerNotificationSubscription(
        endpointToken: String,
        provider: String = "apns",
        environment: String = "production",
        enabled: Bool = true,
        metadata: [String: String]? = nil
    ) async throws -> ShipyardNotificationSubscription? {
        let payload = NotificationSubscriptionRequest(
            provider: provider,
            environment: environment,
            endpointToken: endpointToken,
            enabled: enabled,
            metadata: metadata
        )
        let responseData = try await authedWriteRequest(
            path: "v1/auth/mobile/notification-subscriptions",
            method: "POST",
            body: try encoder.encode(payload)
        )
        do {
            return try decoder.decode(ShipyardNotificationSubscriptionResult.self, from: responseData).subscription
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    @discardableResult
    public func deleteNotificationSubscription(
        provider: String = "apns"
    ) async throws -> ShipyardNotificationSubscriptionDeleteResult {
        let payload = NotificationSubscriptionRequest(
            provider: provider,
            environment: nil,
            endpointToken: nil,
            enabled: nil,
            metadata: nil
        )
        let responseData = try await authedWriteRequest(
            path: "v1/auth/mobile/notification-subscriptions",
            method: "DELETE",
            body: try encoder.encode(payload)
        )
        do {
            return try decoder.decode(ShipyardNotificationSubscriptionDeleteResult.self, from: responseData)
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func submitItem(
        title: String,
        description: String?,
        itemType: ShipyardItemType = .feature
    ) async throws -> ShipyardItem {
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = SubmitItemRequest(
            title: title,
            description: trimmedDescription?.isEmpty == true ? nil : trimmedDescription,
            itemType: itemType.rawValue
        )
        let data = try encoder.encode(payload)
        let responseData = try await authedWriteRequest(path: "v1/requests", method: "POST", body: data)
        do {
            return try decoder.decode(ItemEnvelope.self, from: responseData).request
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func vote(itemId: String, unvote: Bool = false) async throws -> ShipyardItem {
        let payload = try encoder.encode(["unvote": unvote])
        let responseData = try await authedWriteRequest(path: "v1/requests/\(itemId)/vote", method: "POST", body: payload)
        do {
            return try decoder.decode(ItemEnvelope.self, from: responseData).request
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    public func queuedWriteCount() async -> Int {
        await offlineWriteQueue.count(for: offlineScope)
    }

    @discardableResult
    public func syncQueuedWritesIfPossible(refreshAfterSync: Bool = true) async -> ShipyardOfflineSyncResult {
        let result = await offlineWriteQueue.flush(using: self)
        if refreshAfterSync && (result.flushedCount > 0 || result.droppedCount > 0) {
            _ = try? await pullRoadmapDaily()
            _ = try? await pullEngagementDaily()
        }
        return result
    }

    @available(*, deprecated, message: "Use syncDaily() for passive lifecycle synchronization.")
    @discardableResult
    public func refreshCachedDataAndSyncQueuedWrites(history: Bool = false) async -> ShipyardOfflineSyncResult {
        await syncDaily(history: history).offlineWrites
    }

    @discardableResult
    public func syncDaily(
        history: Bool = false,
        date: Date = Date(),
        calendar: Calendar = ShipyardClient.serverActivityCalendar,
        userDefaults: UserDefaults = .standard
    ) async -> ShipyardDailySyncResult {
        let offlineWrites = await syncQueuedWritesIfPossible(refreshAfterSync: false)
        var roadmapItems = await cachedItems()
        var engagementUpdates = await cachedEngagementUpdates(history: history)

        do {
            if let freshItems = try await pullRoadmapDaily(
                date: date,
                calendar: calendar,
                userDefaults: userDefaults
            ) {
                roadmapItems = freshItems
            }
        } catch {
            // Leave cached Roadmap content visible and retry later today.
        }
        do {
            if let freshUpdates = try await pullEngagementDaily(
                history: history,
                date: date,
                calendar: calendar,
                userDefaults: userDefaults
            ) {
                engagementUpdates = freshUpdates
            }
        } catch {
            // Leave cached Engagement content visible and retry later today.
        }

        let dayKey = Self.activityDayKey(for: date, calendar: calendar)
        let isComplete = userDefaults.string(forKey: dailyRoadmapPullDefaultsKey()) == dayKey
            && userDefaults.string(forKey: dailyEngagementPullDefaultsKey(history: history)) == dayKey

        return ShipyardDailySyncResult(
            roadmapItems: roadmapItems,
            engagementUpdates: engagementUpdates,
            offlineWrites: offlineWrites,
            isComplete: isComplete
        )
    }

    public func clearOfflineData() async {
        await cache.clear()
        await offlineWriteQueue.clear(scope: offlineScope)
    }

    fileprivate var offlineScope: ShipyardClientScope {
        ShipyardClientScope(baseURL: baseURL, productSlug: productSlug)
    }

    private func ensureSessionToken() async throws -> String {
        if let existing = await sessionStore.validToken() {
            return existing
        }
        return try await refreshSessionToken()
    }

    @discardableResult
    public func refreshSessionToken() async throws -> String {
        let session = try await refreshSession()
        return session.token
    }

    @discardableResult
    public func pullRoadmapDaily(
        status: String? = nil,
        date: Date = Date(),
        calendar: Calendar = ShipyardClient.serverActivityCalendar,
        userDefaults: UserDefaults = .standard,
        force: Bool = false
    ) async throws -> [ShipyardItem]? {
        let dayKey = Self.activityDayKey(for: date, calendar: calendar)
        let defaultsKey = dailyRoadmapPullDefaultsKey()
        let checkInKey = dailyCheckInDefaultsKey()
        if userDefaults.string(forKey: defaultsKey) == dayKey {
            // Migrate the pre-0.2.3 combined marker without repeating today's check-in.
            if userDefaults.string(forKey: checkInKey) != dayKey {
                userDefaults.set(dayKey, forKey: checkInKey)
            }
            if !force { return nil }
        }

        if userDefaults.string(forKey: checkInKey) != dayKey {
            do {
                _ = try await refreshSession(reason: "roadmap_pull")
                userDefaults.set(dayKey, forKey: checkInKey)
            } catch {
                // Queue the one daily check-in with its original UTC day, but
                // leave the Roadmap pull incomplete so content retries later.
                if Self.isConnectivityError(error) {
                    await enqueueOfflineDailyCheckIn(dayKey: dayKey, reason: "roadmap_pull")
                    userDefaults.set(dayKey, forKey: checkInKey)
                    throw ShipyardError.offlineQueued
                }
                throw error
            }
        }

        let items = try await fetchItemsFromNetwork(status: status)
        userDefaults.set(dayKey, forKey: defaultsKey)
        return items
    }

    @discardableResult
    public func pullEngagementDaily(
        history: Bool = false,
        date: Date = Date(),
        calendar: Calendar = ShipyardClient.serverActivityCalendar,
        userDefaults: UserDefaults = .standard,
        force: Bool = false
    ) async throws -> ShipyardEngagementUpdates? {
        let dayKey = Self.activityDayKey(for: date, calendar: calendar)
        let defaultsKey = dailyEngagementPullDefaultsKey(history: history)
        if !force, userDefaults.string(forKey: defaultsKey) == dayKey {
            return nil
        }

        let updates = try await fetchEngagementUpdatesFromNetwork(history: history)
        userDefaults.set(dayKey, forKey: defaultsKey)
        return updates
    }

    @available(*, deprecated, message: "Use pullRoadmapDaily() for the daily Roadmap read.")
    @discardableResult
    public func pingDailyActiveDevice(
        date: Date = Date(),
        calendar: Calendar = ShipyardClient.serverActivityCalendar,
        userDefaults: UserDefaults = .standard,
        force: Bool = false
    ) async throws -> ShipyardSessionInfo? {
        let dayKey = Self.activityDayKey(for: date, calendar: calendar)
        let defaultsKey = dailyAppActivityDefaultsKey()
        if !force, userDefaults.string(forKey: defaultsKey) == dayKey {
            return nil
        }

        let session = try await refreshSession(reason: "daily_activity")
        userDefaults.set(dayKey, forKey: defaultsKey)
        return session
    }

    @available(*, deprecated, message: "Use pullRoadmapDaily() for the daily Roadmap read.")
    @discardableResult
    public func checkInDailyActiveDevice(
        date: Date = Date(),
        calendar: Calendar = ShipyardClient.serverActivityCalendar,
        userDefaults: UserDefaults = .standard,
        force: Bool = false
    ) async throws -> ShipyardSessionInfo? {
        try await pingDailyActiveDevice(
            date: date,
            calendar: calendar,
            userDefaults: userDefaults,
            force: force
        )
    }

    private func enqueueOfflineDailyCheckIn(dayKey: String, reason: String) async {
        let installationId = installationIdProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !installationId.isEmpty else { return }
        var body: [String: String] = [
            "productSlug": productSlug,
            "installationId": installationId,
            "platform": platform,
            "shipyardKitVersion": Self.sdkVersion,
            "sessionReason": reason,
            "activityDate": dayKey
        ]
        if let appVersion = appVersionProvider(), !appVersion.isEmpty {
            body["appVersion"] = appVersion
        }
        if let buildNumber = buildNumberProvider(), !buildNumber.isEmpty {
            body["buildNumber"] = buildNumber
        }
        guard let data = try? encoder.encode(body) else { return }
        await offlineWriteQueue.enqueue(
            scope: offlineScope,
            path: "v1/auth/mobile/public-session",
            method: "POST",
            queryItems: [],
            body: data,
            contentType: "application/json"
        )
    }

    public func refreshSession() async throws -> ShipyardSessionInfo {
        try await refreshSession(reason: nil)
    }

    private func refreshSession(reason: String?) async throws -> ShipyardSessionInfo {
        let installationId = installationIdProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !installationId.isEmpty else {
            throw ShipyardError.server("installationId is required", 400)
        }

        let requestBody: [String: String] = {
            var body: [String: String] = [
                "productSlug": productSlug,
                "installationId": installationId,
                "platform": platform,
                "shipyardKitVersion": Self.sdkVersion
            ]
            if let appVersion = appVersionProvider(), !appVersion.isEmpty {
                body["appVersion"] = appVersion
            }
            if let buildNumber = buildNumberProvider(), !buildNumber.isEmpty {
                body["buildNumber"] = buildNumber
            }
            if let reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
                body["sessionReason"] = reason
            }
            return body
        }()

        let data = try encoder.encode(requestBody)
        var request = URLRequest(url: endpointURL("v1/auth/mobile/public-session"))
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applySDKHeaders(to: &request)

        // One retry with a short jittered delay for transient failures: this
        // call carries the daily check-in, so a flaky launch-time network
        // should not cost a device-day.
        var responseData: Data
        do {
            let (firstData, firstResponse) = try await urlSession.data(for: request)
            try validateStatus(data: firstData, response: firstResponse)
            responseData = firstData
        } catch {
            guard Self.isTransientSessionError(error) else { throw error }
            let jitterNanos = UInt64.random(in: 0...400_000_000)
            try? await Task.sleep(nanoseconds: 600_000_000 + jitterNanos)
            let (retryData, retryResponse) = try await urlSession.data(for: request)
            try validateStatus(data: retryData, response: retryResponse)
            responseData = retryData
        }
        let decoded: SessionResponse
        do {
            decoded = try decoder.decode(SessionResponse.self, from: responseData)
        } catch {
            throw ShipyardError.decodingFailed
        }
        guard let expiresAtDate = ShipyardDateParser.date(from: decoded.expiresAt) else {
            throw ShipyardError.decodingFailed
        }
        await sessionStore.set(token: decoded.token, expiresAt: expiresAtDate)
        return ShipyardSessionInfo(token: decoded.token, expiresAt: expiresAtDate)
    }

    private func readRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        allowCachedFallback: Bool = true
    ) async throws -> Data {
        let key = cacheKey(path: path, queryItems: queryItems)
        do {
            let data = try await sendRequest(path: path, method: "GET", queryItems: queryItems)
            await cache.store(data, for: key)
            return data
        } catch {
            if allowCachedFallback,
               Self.shouldUseCachedRead(after: error),
               let cached = await cache.data(for: key) {
                return cached
            }
            if Self.isConnectivityError(error) {
                throw ShipyardError.offlineCacheUnavailable
            }
            throw error
        }
    }

    private func authedReadRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        cacheTTL: TimeInterval = 0,
        cachePolicy: ShipyardReadCachePolicy = .automatic,
        allowCachedFallback: Bool = true
    ) async throws -> Data {
        let key = cacheKey(path: path, queryItems: queryItems)
        if cachePolicy == .automatic,
           let cached = await cache.freshData(for: key, maxAge: cacheTTL) {
            return cached
        }
        do {
            let token = try await ensureSessionToken()
            let data = try await sendRequest(path: path, method: "GET", token: token, queryItems: queryItems)
            await cache.store(data, for: key)
            return data
        } catch {
            if allowCachedFallback,
               Self.shouldUseCachedRead(after: error),
               let cached = await cache.data(for: key) {
                return cached
            }
            if Self.isConnectivityError(error) {
                throw ShipyardError.offlineCacheUnavailable
            }
            throw error
        }
    }

    private func authedWriteRequest(
        path: String,
        method: String,
        body: Data?,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        do {
            let token = try await ensureSessionToken()
            return try await sendRequest(
                path: path,
                method: method,
                token: token,
                body: body,
                queryItems: queryItems
            )
        } catch {
            if Self.isConnectivityError(error) {
                await offlineWriteQueue.enqueue(
                    scope: offlineScope,
                    path: path,
                    method: method,
                    queryItems: queryItems,
                    body: body,
                    contentType: body == nil ? nil : "application/json"
                )
                throw ShipyardError.offlineQueued
            }
            throw error
        }
    }

    fileprivate func replayQueuedWrite(_ entry: ShipyardQueuedWrite) async throws {
        let token = try await ensureSessionToken()
        _ = try await sendRequest(
            path: entry.path,
            method: entry.method,
            token: token,
            body: entry.body,
            queryItems: entry.queryItems.map(\.urlQueryItem),
            contentType: entry.contentType
        )
    }

    private func sendRequest(
        path: String,
        method: String,
        token: String? = nil,
        body: Data? = nil,
        queryItems: [URLQueryItem] = [],
        contentType: String? = nil
    ) async throws -> Data {
        var components = URLComponents(url: endpointURL(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { throw ShipyardError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applySDKHeaders(to: &request)
        if body != nil {
            request.setValue(contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)
        try validateStatus(data: data, response: response)
        return data
    }

    private func endpointURL(_ path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    private func applySDKHeaders(to request: inout URLRequest) {
        request.setValue("ShipyardKit/\(Self.sdkVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue(Self.sdkVersion, forHTTPHeaderField: "X-ShipyardKit-Version")
    }

    private func engagementQueryItems(history: Bool) -> [URLQueryItem] {
        var queryItems = [URLQueryItem(name: "product", value: productSlug)]
        if history {
            queryItems.append(URLQueryItem(name: "history", value: "1"))
        }
        return queryItems
    }

    private func serviceQueryItems(workspaceSlug: String?) -> [URLQueryItem] {
        let workspace = workspaceSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return workspace.isEmpty ? [] : [URLQueryItem(name: "ws", value: workspace)]
    }

    private func appendQueryItemIfPresent(name: String, value: String?, to queryItems: inout [URLQueryItem]) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            queryItems.append(URLQueryItem(name: name, value: trimmed))
        }
    }

    private func appendQueryItemIfPresent(name: String, value: Bool?, to queryItems: inout [URLQueryItem]) {
        guard let value else { return }
        queryItems.append(URLQueryItem(name: name, value: value ? "1" : "0"))
    }

    private func pathComponent(_ value: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#[]@!$&'()*+,;="))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func cacheKey(path: String, queryItems: [URLQueryItem]) -> String {
        var components = URLComponents(url: endpointURL(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        let urlString = components?.url?.absoluteString ?? endpointURL(path).absoluteString
        let installationId = installationIdProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "GET",
            urlString,
            offlineScope.baseURLString,
            offlineScope.productSlug,
            installationId
        ].joined(separator: "|")
    }

    private func roadmapQueryItems(status: String? = nil) -> [URLQueryItem] {
        var queryItems = [URLQueryItem(name: "product", value: productSlug)]
        if let status, !status.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        return queryItems
    }

    private static func shouldUseCachedRead(after error: Error) -> Bool {
        if isConnectivityError(error) {
            return true
        }
        guard case ShipyardError.server(_, let status) = error else {
            return false
        }
        return status == 408 || status == 425 || status == 429 || status >= 500
    }

    private static func isAuthorizationError(_ error: Error) -> Bool {
        guard case ShipyardError.server(_, let status) = error else {
            return false
        }
        return status == 401 || status == 403
    }

    fileprivate static func isTransientSessionError(_ error: Error) -> Bool {
        if isConnectivityError(error) {
            return true
        }
        guard case ShipyardError.server(_, let status) = error else { return false }
        return status == 408 || status == 425 || status == 429 || status >= 500
    }

    fileprivate static func isConnectivityError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return false
        }
        let code = URLError.Code(rawValue: nsError.code)

        switch code {
        case .notConnectedToInternet,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .internationalRoamingOff,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }

    private func respondToEngagementPrompt(
        promptId: String,
        pathSegment: String,
        optionIds: [String]?,
        ratingValue: Int?,
        responseText: String?
    ) async throws -> ShipyardPrompt {
        let normalizedOptionIds = optionIds?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let payload = PromptResponseRequest(
            optionId: normalizedOptionIds?.count == 1 ? normalizedOptionIds?.first : nil,
            optionIds: (normalizedOptionIds?.count ?? 0) > 1 ? normalizedOptionIds : nil,
            ratingValue: ratingValue,
            responseText: normalizedOptionalText(responseText, maxLength: 2000)
        )
        let data = try encoder.encode(payload)
        let responseData = try await authedWriteRequest(
            path: "v1/engagement/\(pathSegment)/\(promptId)/respond",
            method: "POST",
            body: data
        )
        do {
            let response = try decoder.decode(ShipyardPromptResponseResult.self, from: responseData)
            return response.ask ?? response.checkIn ?? response.prompt
        } catch {
            throw ShipyardError.decodingFailed
        }
    }

    private func normalizedOptionalText(_ value: String?, maxLength: Int) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }

    private func validateStatus(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(ServerError.self, from: data).error) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw ShipyardError.server(message, http.statusCode)
        }
    }

    public static var serverActivityCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let utc = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = utc
        }
        return calendar
    }

    private static func activityDayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func dailyRoadmapPullDefaultsKey() -> String {
        [
            "ShipyardKit",
            "dailyRoadmapPull",
            baseURL.absoluteString,
            productSlug,
            platform
        ].joined(separator: "|")
    }

    private func dailyCheckInDefaultsKey() -> String {
        [
            "ShipyardKit",
            "dailyCheckIn",
            baseURL.absoluteString,
            productSlug,
            platform
        ].joined(separator: "|")
    }

    private func dailyEngagementPullDefaultsKey(history: Bool) -> String {
        [
            "ShipyardKit",
            "dailyEngagementPull",
            baseURL.absoluteString,
            productSlug,
            platform,
            history ? "history" : "current"
        ].joined(separator: "|")
    }

    private func dailyAppActivityDefaultsKey() -> String {
        [
            "ShipyardKit",
            "dailyActiveDevice",
            baseURL.absoluteString,
            productSlug,
            platform
        ].joined(separator: "|")
    }
}

private struct ServerError: Codable {
    let error: String
}
