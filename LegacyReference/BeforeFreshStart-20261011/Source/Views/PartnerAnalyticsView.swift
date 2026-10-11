import SwiftUI

struct PartnerAnalyticsView: View {
    @Bindable var viewModel: PartnerHomeViewModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your recovery performance").font(.title2.bold())
                        Text("Campaign touchpoints, from selected leads to sales follow-up.").foregroundStyle(.secondary)
                    }
                    Toggle("Show demo analytics", isOn: $viewModel.showsDemo)
                        .onChange(of: viewModel.showsDemo) { _, _ in Task { await viewModel.load() } }
                    if viewModel.showsDemo {
                        Label("Demo workspace · Fictional campaigns and results", systemImage: "sparkles").font(.subheadline.bold()).foregroundStyle(.indigo)
                    }
                    if viewModel.isLoading { ProgressView("Loading campaign analytics…") }
                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        Button("Try again") { Task { await viewModel.load() } }
                    }
                    if viewModel.hasLoaded {
                        filters
                        if viewModel.snapshots.isEmpty {
                            ContentUnavailableView("No campaigns yet", systemImage: "chart.bar.xaxis", description: Text("Your onboarding is complete. Campaign performance will appear here as campaigns are added to your workspace."))
                        } else {
                            overview
                            Text("Campaign performance").font(.title3.bold())
                            if viewModel.filtered.isEmpty { Text("No campaigns match these filters.").foregroundStyle(.secondary) }
                            ForEach(viewModel.filtered) { snapshot in CampaignAnalyticsCard(snapshot: snapshot) }
                        }
                    }
                    if !viewModel.showsDemo { Text("Messaging is not connected yet. Sent messages, replies, verified conversions and recovered revenue are unavailable. Sales touches and appointments below are manual records, not verified outcomes.")
                        .font(.footnote).foregroundStyle(.secondary) }
                }.padding(20)
            }.navigationTitle("Analytics")
                .task { await viewModel.load() }
                .refreshable { await viewModel.load() }
        }
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter campaigns").font(.headline)
            Picker("Campaign", selection: $viewModel.campaignFilter) {
                Text("All campaigns").tag(nil as UUID?)
                ForEach(viewModel.snapshots) { row in Text(row.campaign.config.name).tag(Optional(row.id)) }
            }
            Picker("Status", selection: $viewModel.statusFilter) {
                Text("All statuses").tag(nil as CampaignStatus?)
                ForEach([CampaignStatus.draft, .readyToConnect, .paused, .archived], id: \.self) { Text($0.title).tag(Optional($0)) }
            }
        }.padding().background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("At a glance").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if viewModel.showsDemo {
                    AnalyticsMetric(title: "Messages sent", value: "\(viewModel.sent)", symbol: "paperplane")
                    AnalyticsMetric(title: "Replies", value: "\(viewModel.replies)", symbol: "bubble.left.and.bubble.right")
                    AnalyticsMetric(title: "Conversions", value: "\(viewModel.conversions)", symbol: "checkmark.seal")
                    AnalyticsMetric(title: "Recovered revenue", value: viewModel.revenue.formatted(.currency(code: "USD")), symbol: "dollarsign.circle")
                }
                AnalyticsMetric(title: "Campaigns", value: "\(viewModel.filtered.count)", symbol: "megaphone")
                AnalyticsMetric(title: "Selected leads", value: "\(viewModel.recipients)", symbol: "person.3")
                AnalyticsMetric(title: "Sales touches", value: "\(viewModel.touches)", symbol: "person.crop.circle.badge.checkmark", note: viewModel.showsDemo ? "Demo" : "Manually recorded")
                AnalyticsMetric(title: "Appointments", value: "\(viewModel.appointments)", symbol: "calendar", note: viewModel.showsDemo ? "Demo" : "Manually recorded")
            }
            Text("Lead totals count campaign memberships. A lead in two campaigns is counted twice. Manual status totals show current status, not historical transitions.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
private struct AnalyticsMetric: View {
    let title: String
    let value: String
    let symbol: String
    var note: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            if let note { Text(note).font(.caption2).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, minHeight: 80, alignment: .leading).padding(12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
    }
}
private struct CampaignAnalyticsCard: View {
    let snapshot: CampaignSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) { Text(snapshot.campaign.config.name).font(.headline); Text(snapshot.partnerName).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text(snapshot.campaign.status.title).font(.caption.weight(.semibold)).padding(7).background(.indigo.opacity(0.12), in: Capsule())
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                AnalyticsMetric(title: "Selected leads", value: "\(snapshot.recipients)", symbol: "person.3")
                AnalyticsMetric(title: "Messages sent", value: snapshot.demoMetrics.map { "\($0.sent)" } ?? "—", symbol: "paperplane", note: snapshot.demoMetrics == nil ? "Not connected" : "Demo")
                AnalyticsMetric(title: "Replies", value: snapshot.demoMetrics.map { "\($0.replies)" } ?? "—", symbol: "bubble.left.and.bubble.right", note: snapshot.demoMetrics == nil ? "Not connected" : "Demo")
                AnalyticsMetric(title: "Sales touches", value: "\(snapshot.salesTouches)", symbol: "phone", note: snapshot.demoMetrics == nil ? "Manually recorded" : "Demo")
                AnalyticsMetric(title: "Interested", value: "\(snapshot.recorded(.interested))", symbol: "hand.thumbsup", note: snapshot.demoMetrics == nil ? "Manual current status" : "Demo")
                AnalyticsMetric(title: "Appointments", value: "\(snapshot.recorded(.appointment))", symbol: "calendar", note: snapshot.demoMetrics == nil ? "Manual current status" : "Demo")
                AnalyticsMetric(title: "Sales handoffs", value: "\(snapshot.recorded(.handoff))", symbol: "arrow.right.circle", note: snapshot.demoMetrics == nil ? "Manual current status" : "Demo")
                AnalyticsMetric(title: "Conversions", value: snapshot.demoMetrics.map { "\($0.conversions)" } ?? "—", symbol: "checkmark.seal", note: snapshot.demoMetrics == nil ? "Not verified" : "Demo")
                AnalyticsMetric(title: "Recovered revenue", value: snapshot.demoMetrics.map { $0.revenue.formatted(.currency(code: "USD")) } ?? "—", symbol: "dollarsign.circle", note: snapshot.demoMetrics == nil ? "Not available" : "Demo")
            }
            if snapshot.campaign.ownerHold { Label("Campaign paused by CrewCrate", systemImage: "pause.circle").foregroundStyle(.orange) }
        }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.secondary.opacity(0.18)))
    }
}
