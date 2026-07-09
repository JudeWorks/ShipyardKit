import SwiftUI
import ShipyardKit

/// Example integration for a fictional company and product.
/// Replace Acme/Atlas values with your own Shipyard workspace and product.
enum ShipyardKitExampleConfig {
    static let client = ShipyardClient(
        baseURL: URL(string: "https://acme-studio.startshipyard.com")!,
        productSlug: "atlas",
        installationIdProvider: {
            // Keychain-backed: survives reinstalls so device counts stay honest.
            ShipyardInstallationIdentifier.stable()
        },
        appVersionProvider: {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        },
        buildNumberProvider: {
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        }
    )
}

struct ShipyardKitLauncherView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAnnouncements = false
    @State private var showingAsk = false
    @State private var showingRoadmap = false
    @State private var engagementUpdates: ShipyardEngagementUpdates?
    @State private var engagementError: String?

    private let client: ShipyardClient

    init(client: ShipyardClient = ShipyardKitExampleConfig.client) {
        self.client = client
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let engagementError {
                Text(engagementError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Support")
                    .font(.headline)
                Text("Roadmap is always available. Other rows appear only with current content.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showingRoadmap = true
                } label: {
                    Label("Roadmap", systemImage: "map")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)

                if !(engagementUpdates?.announcements ?? []).isEmpty {
                    Button {
                        showingAnnouncements = true
                    } label: {
                        Label("Announcements", systemImage: "megaphone")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }

                if !(engagementUpdates?.asks ?? []).isEmpty {
                    Button {
                        showingAsk = true
                    } label: {
                        Label("Ask", systemImage: "questionmark.bubble")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .sheet(isPresented: $showingAnnouncements) {
            ShipyardKitAnnouncementsSheet(
                client: client,
                announcements: engagementUpdates?.announcements ?? [],
                screenKey: "settings",
                onRefresh: refreshAfterInteraction
            )
        }
        .sheet(isPresented: $showingAsk) {
            ShipyardKitAskSheet(
                client: client,
                asks: engagementUpdates?.asks ?? [],
                onRefresh: refreshAfterInteraction
            )
        }
        .sheet(isPresented: $showingRoadmap) {
            ShipyardKitRoadmapSheet(client: client)
        }
        .task {
            await syncDaily()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await syncDaily() }
            }
        }
    }

    private func syncDaily() async {
        engagementError = nil
        let result = await client.syncDaily()
        engagementUpdates = result.engagementUpdates
    }

    private func refreshAfterInteraction() async {
        engagementError = nil
        do {
            engagementUpdates = try await client.fetchEngagementUpdates(cachePolicy: .reloadIgnoringCache)
        } catch {
            engagementError = error.localizedDescription
        }
    }
}

struct ShipyardKitAnnouncementsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let client: ShipyardClient
    let announcements: [ShipyardAnnouncement]
    let screenKey: String
    let onRefresh: () async -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(announcements) { announcement in
                    ShipyardKitAnnouncementView(
                        client: client,
                        announcement: announcement,
                        screenKey: screenKey,
                        onRefresh: onRefresh
                    )
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Announcements")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct ShipyardKitAskSheet: View {
    @Environment(\.dismiss) private var dismiss
    let client: ShipyardClient
    let asks: [ShipyardAsk]
    let onRefresh: () async -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(asks) { ask in
                    ShipyardKitAskView(
                        client: client,
                        ask: ask,
                        onRefresh: onRefresh
                    )
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Ask")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct ShipyardKitAnnouncementView: View {
    @Environment(\.openURL) private var openURL
    @State private var isWorking = false
    @State private var errorMessage: String?

    let client: ShipyardClient
    let announcement: ShipyardAnnouncement
    let screenKey: String
    let onRefresh: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(announcement.title)
                .font(.headline)
            Text(announcement.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                if let ctaLabel = announcement.ctaLabel,
                   let ctaUrl = announcement.ctaUrl,
                   let url = URL(string: ctaUrl) {
                    Button {
                        Task { await click(url: url) }
                    } label: {
                        Label(ctaLabel, systemImage: "arrow.up.forward")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
                }

                if announcement.clearable {
                    Button {
                        Task { await dismiss() }
                    } label: {
                        Label("Dismiss", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking)
                }
            }
            .font(.caption)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: announcement.id) {
            guard announcement.myState?.shownCount ?? 0 == 0 else { return }
            _ = try? await client.markAnnouncementShown(
                announcementId: announcement.id,
                screenKey: screenKey
            )
        }
    }

    private func click(url: URL) async {
        await runEvent {
            _ = try await client.clickAnnouncement(
                announcementId: announcement.id,
                screenKey: screenKey
            )
            await MainActor.run {
                openURL(url)
            }
        }
    }

    private func dismiss() async {
        await runEvent {
            _ = try await client.dismissAnnouncement(
                announcementId: announcement.id,
                screenKey: screenKey
            )
            await onRefresh()
        }
    }

    private func runEvent(_ operation: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        do {
            errorMessage = nil
            try await operation()
        } catch ShipyardError.offlineQueued {
            errorMessage = ShipyardError.offlineQueued.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ShipyardKitAskView: View {
    @State private var selectedOptionId: String?
    @State private var selectedOptionIds: Set<String>
    @State private var ratingValue: Int
    @State private var responseText: String
    @State private var isSubmitting = false
    @State private var message: String?

    let client: ShipyardClient
    let ask: ShipyardAsk
    let onRefresh: () async -> Void

    init(
        client: ShipyardClient,
        ask: ShipyardAsk,
        onRefresh: @escaping () async -> Void
    ) {
        self.client = client
        self.ask = ask
        self.onRefresh = onRefresh
        _selectedOptionId = State(initialValue: ask.myResponse?.selectedOptionIds.first)
        _selectedOptionIds = State(initialValue: Set(ask.myResponse?.selectedOptionIds ?? []))
        _ratingValue = State(initialValue: ask.myResponse?.ratingValue ?? ask.ratingRange?.lowerBound ?? 1)
        _responseText = State(initialValue: ask.myResponse?.responseText ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ask.title)
                    .font(.headline)
                if let description = ask.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(ask.typeTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            askControls

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(message == savedMessage ? .green : .red)
            } else if ask.hasCurrentResponse {
                Text(savedMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if ask.resultsVisible {
                askResults
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var askControls: some View {
        switch ask.type {
        case .singleChoice:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ask.options) { option in
                    Button {
                        selectedOptionId = option.id
                    } label: {
                        Label(option.label, systemImage: selectedOptionId == option.id ? "largecircle.fill.circle" : "circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                submitButton(disabled: selectedOptionId == nil) {
                    guard let selectedOptionId else { return }
                    _ = try await client.respondToAsk(
                        askId: ask.id,
                        optionId: selectedOptionId
                    )
                }
            }
        case .multiChoice:
            VStack(alignment: .leading, spacing: 8) {
                if let maxSelections = ask.maxSelections {
                    Text("Choose up to \(maxSelections).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(ask.options) { option in
                    Toggle(option.label, isOn: Binding(
                        get: { selectedOptionIds.contains(option.id) },
                        set: { isSelected in
                            if isSelected {
                                if let maxSelections = ask.maxSelections,
                                   selectedOptionIds.count >= maxSelections {
                                    return
                                }
                                selectedOptionIds.insert(option.id)
                            } else {
                                selectedOptionIds.remove(option.id)
                            }
                        }
                    ))
                }
                submitButton(disabled: selectedOptionIds.isEmpty) {
                    _ = try await client.respondToAsk(
                        askId: ask.id,
                        optionIds: Array(selectedOptionIds)
                    )
                }
            }
        case .starRating:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            ratingValue = value
                        } label: {
                            Image(systemName: value <= ratingValue ? "star.fill" : "star")
                        }
                        .buttonStyle(.plain)
                        .font(.title3)
                    }
                }
                submitButton(disabled: false) {
                    _ = try await client.respondToAsk(
                        askId: ask.id,
                        ratingValue: ratingValue
                    )
                }
            }
        case .numericRating:
            VStack(alignment: .leading, spacing: 8) {
                Stepper(
                    "Rating: \(ratingValue)",
                    value: $ratingValue,
                    in: ask.ratingRange ?? 1...10
                )
                submitButton(disabled: false) {
                    _ = try await client.respondToAsk(
                        askId: ask.id,
                        ratingValue: ratingValue
                    )
                }
            }
        case .openText:
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $responseText)
                    .frame(minHeight: 88)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                )
                submitButton(disabled: responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    _ = try await client.respondToAsk(
                        askId: ask.id,
                        responseText: responseText
                    )
                }
            }
        case nil:
            Text("Unsupported ask type: \(ask.promptType)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var askResults: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(ask.responseCount) response\(ask.responseCount == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
            if let averageRating = ask.averageRating {
                Text("Average rating: \(averageRating, specifier: "%.2f")")
                    .font(.caption)
            }
            ForEach(ask.options) { option in
                if let voteCount = option.voteCount {
                    Text("\(option.label): \(voteCount)")
                        .font(.caption)
                }
            }
        }
        .foregroundStyle(.secondary)
    }

    private var savedMessage: String {
        "Your response is saved."
    }

    private func submitButton(
        disabled: Bool,
        action: @escaping () async throws -> Void
    ) -> some View {
        Button {
            Task { await submit(action) }
        } label: {
            Label("Submit", systemImage: "paperplane")
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled || isSubmitting)
    }

    private func submit(_ action: () async throws -> Void) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            message = nil
            try await action()
            message = savedMessage
            await onRefresh()
        } catch ShipyardError.offlineQueued {
            message = ShipyardError.offlineQueued.localizedDescription
        } catch {
            message = error.localizedDescription
        }
    }
}

struct ShipyardKitRoadmapSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var statusGroups: [ShipyardStatusGroup] = []
    @State private var title = ""
    @State private var detail = ""
    @State private var itemType: ShipyardItemType = .feature
    @State private var isLoading = false
    @State private var errorMessage: String?

    let client: ShipyardClient

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggest a roadmap item")
                        .font(.headline)
                    Text("Roadmap suggestions are for feature ideas and bug fixes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Type", selection: $itemType) {
                        ForEach(ShipyardItemType.roadmapSuggestionCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField("Feature or bug fix", text: $title)
                        .textFieldStyle(.roundedBorder)
                    TextField("Details (optional)", text: $detail)
                        .textFieldStyle(.roundedBorder)
                    Button("Submit") {
                        Task { await submitItem() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }

                List {
                    ForEach(statusGroups) { group in
                        Section {
                            ForEach(group.items) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.title).font(.headline)
                                    if let description = item.description, !description.isEmpty {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    if let response = item.developerResponseText {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(["Developer response", item.developerRespondedAtRelativeLabel()].compactMap { $0 }.joined(separator: " · "))
                                                .font(.caption.weight(.semibold))
                                            Text(response)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(8)
                                        .background(Color.secondary.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            Button {
                                                Task { await vote(on: item.id, unvote: false) }
                                            } label: {
                                                Label("\(item.voteCount)", systemImage: "arrow.up")
                                            }
                                            .buttonStyle(.bordered)
                                            roadmapPill(group.title)
                                            if let availability = item.availabilityLabel(currentAppVersion: currentAppVersion) {
                                                roadmapPill(availability)
                                            }
                                            if let target = item.targetDateLabel {
                                                roadmapPill(target)
                                            }
                                        }
                                    }
                                    .lineLimit(1)
                                    .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 4)
                            }
                        } header: {
                            HStack {
                                Text(group.title)
                                Spacer()
                                Text("\(group.totalVotes) votes")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("Roadmap")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await bootstrap() }
            .refreshable { await loadCategories() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var currentAppVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private func bootstrap() async {
        if let cachedItems = await client.cachedItems() {
            applyRoadmapItems(cachedItems, force: true)
        }
        await refreshRoadmapFromNetwork(showLoading: statusGroups.isEmpty)
    }

    private func loadCategories() async {
        await refreshRoadmapFromNetwork(showLoading: true)
    }

    private func refreshRoadmapFromNetwork(showLoading: Bool) async {
        if showLoading { isLoading = true }
        defer {
            if showLoading { isLoading = false }
        }
        do {
            errorMessage = nil
            if let freshItems = try await client.pullRoadmapDaily() {
                applyRoadmapItems(freshItems, force: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyRoadmapItems(_ items: [ShipyardItem], force: Bool) {
        let groups = items.shipyardGroupedByStatus()
        if force || roadmapSignature(groups) != roadmapSignature(statusGroups) {
            statusGroups = groups
        }
    }

    private func roadmapSignature(_ groups: [ShipyardStatusGroup]) -> String {
        groups.flatMap { group in
            group.items.map { item in
                [
                    group.status,
                    item.id,
                    item.title,
                    item.description ?? "",
                    item.status,
                    item.itemType ?? "",
                    String(item.voteCount),
                    item.releaseVersion ?? "",
                    item.targetDate ?? "",
                    item.developerResponseText ?? "",
                    item.developerRespondedAt ?? "",
                    item.updatedAt ?? ""
                ].joined(separator: "\u{1f}")
            }
        }.joined(separator: "\u{1e}")
    }

    private func submitItem() async {
        isLoading = true
        defer { isLoading = false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        do {
            errorMessage = nil
            _ = try await client.submitItem(
                title: trimmedTitle,
                description: detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : detail,
                itemType: itemType
            )
            title = ""
            detail = ""
            itemType = .feature
            await loadCategories()
        } catch ShipyardError.offlineQueued {
            errorMessage = ShipyardError.offlineQueued.localizedDescription
            title = ""
            detail = ""
            itemType = .feature
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func vote(on itemId: String, unvote: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            errorMessage = nil
            _ = try await client.vote(itemId: itemId, unvote: unvote)
            await loadCategories()
        } catch ShipyardError.offlineQueued {
            errorMessage = ShipyardError.offlineQueued.localizedDescription
            await loadCategories()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func roadmapPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    ShipyardKitLauncherView()
}
