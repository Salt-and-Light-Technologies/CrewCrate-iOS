import SwiftUI

struct OwnerDashboardView: View {
    @Bindable var viewModel: OwnerDashboardViewModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image("CrateMark").resizable().scaledToFit().frame(width: 48, height: 48).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your partner overview").font(.headline)
                            Text("Track lead recovery and your partners’ sales activity.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                    DemoModeNotice()
                }
                if !viewModel.performance.isEmpty {
                    OwnerPerformanceSection(viewModel: viewModel)
                }
                if let error = viewModel.analyticsError {
                    Section("Partner performance") { Text(error).foregroundStyle(.red) }
                }
                Section("All sample partners") {
                    LabeledContent("Partners", value: "\(viewModel.partners.count)")
                    LabeledContent("Awaiting review", value: "\(viewModel.awaitingReviewCount)")
                    LabeledContent("Pilot approved", value: "\(viewModel.approvedCount)")
                    LabeledContent("Paused", value: "\(viewModel.pausedCount)")
                }
                Section {
                    Picker("Status", selection: $viewModel.statusFilter) {
                        Text("All statuses").tag(PartnerStatus?.none)
                        ForEach(PartnerStatus.allCases) { Text($0.rawValue).tag(Optional($0)) }
                    }
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        Button("Try again") { Task { await viewModel.load() } }
                    }
                }
                Section("Partners") {
                    if viewModel.isLoading && viewModel.partners.isEmpty {
                        ProgressView("Loading sample partners…")
                    } else if viewModel.filteredPartners.isEmpty {
                        ContentUnavailableView("No matching partners", systemImage: "building.2", description: Text("Try another search or status filter."))
                    } else {
                        ForEach(viewModel.filteredPartners) { partner in
                            NavigationLink(value: partner.id) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(partner.name).font(.headline)
                                    HStack {
                                        Text(partner.onboarding.industry).font(.subheadline).foregroundStyle(.secondary)
                                        Spacer()
                                        PartnerStatusBadge(status: partner.status)
                                    }
                                    Text(partner.missingLaunchRequirements.isEmpty ? "Demo launch requirements complete" : "\(partner.missingLaunchRequirements.count) launch requirements outstanding")
                                        .font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 6)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Owner overview")
            .searchable(text: $viewModel.search, prompt: "Search business or industry")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .toolbar {
                Button { Task { await viewModel.load() } } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(viewModel.isLoading).accessibilityLabel("Refresh partners")
            }
            .navigationDestination(for: UUID.self) { id in
                PartnerReviewView(viewModel: viewModel.makeReviewViewModel(id: id), leadWorkspace: viewModel.makeLeadViewModel(id: id))
                    .onDisappear { Task { await viewModel.load() } }
            }
            .tint(.indigo)
        }
    }
}

struct DemoModeNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Demo workspace", systemImage: "flask").font(.subheadline.weight(.semibold)).foregroundStyle(.indigo)
            Text("Sample businesses and local decisions only. Changes reset when the app restarts. No accounts, notifications, or campaigns are connected.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}
struct PartnerStatusBadge: View {
    let status: PartnerStatus
    private var color: Color {
        switch status {
        case .draft: .secondary
        case .submitted: .indigo
        case .changesRequested: .orange
        case .pilotApproved: .green
        case .paused: .red
        }
    }
    var body: some View {
        Text(status.rawValue).font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 5).background(color.opacity(0.12), in: Capsule())
    }
}
