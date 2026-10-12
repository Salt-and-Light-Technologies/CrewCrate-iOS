import SwiftUI

struct OwnerBusinessAnalyticsView: View {
    @State private var model: OwnerBusinessAnalyticsModel
    init(business: BusinessSummary, analyticsService: any OwnerAnalyticsServicing,
         campaignService: any CampaignWorkspaceServicing) {
        _model = State(initialValue: OwnerBusinessAnalyticsModel(business: business,
            analyticsService: analyticsService, campaignService: campaignService))
    }
    var body: some View {
        List {
            Section {
                Text(model.business.name).font(.title2.bold())
                Text("Business performance · owner overview").font(.subheadline).foregroundStyle(.secondary)
            }
            if let analytics = model.analytics {
                Section("Workspace activity") {
                    LabeledContent("Contacts", value: String(analytics.total_contacts))
                    LabeledContent("Campaigns", value: String(analytics.campaign_count))
                    LabeledContent("Contact files imported", value: String(analytics.import_count))
                    LabeledContent("Business access", value: analytics.access_approved ? "Approved" : "Awaiting approval")
                }
                Section("Contact review") {
                    LabeledContent("Eligible review status", value: String(analytics.lead_status_counts["eligible", default: 0]))
                    LabeledContent("Needs review", value: String(analytics.lead_status_counts["unreviewed", default: 0]))
                    LabeledContent("Excluded", value: String(analytics.lead_status_counts["excluded", default: 0]))
                    Text("Review status does not establish delivery, registry clearance or recovered sales.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Manual follow-up records") {
                    LabeledContent("Total records", value: String(analytics.manual_conversation_count))
                    LabeledContent("Interested", value: String(analytics.manual_status_counts["interested", default: 0]))
                    LabeledContent("Appointments recorded", value: String(analytics.manual_status_counts["appointment", default: 0]))
                    LabeledContent("Handoffs recorded", value: String(analytics.manual_status_counts["handoff", default: 0]))
                    LabeledContent("Closed status", value: String(analytics.manual_status_counts["closed", default: 0]))
                    Text("These are manually recorded statuses, not verified replies, bookings or payments.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if model.isLoading { ProgressView("Loading business activity…") }
            if let error = model.analyticsError {
                Section("Overview unavailable") {
                    Text(error).foregroundStyle(.red)
                    Button("Reload overview") { Task { await model.load() } }.disabled(model.isLoading)
                }
            }
            Section("Recovered profit and your share") {
                Text("Financial reporting is not connected yet.")
                Text("Collected payments, direct job costs and commission will appear here when supporting records are available.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Campaign plans") {
                if model.campaigns.isEmpty && !model.isLoading && model.campaignsError == nil {
                    Text("This business has no campaign plans yet.").foregroundStyle(.secondary)
                }
                ForEach(model.campaigns) { campaign in
                    DisclosureGroup(campaign.config.name) {
                        LabeledContent("Status", value: campaign.statusTitle)
                        LabeledContent("Attached contacts", value: String(campaign.config.lead_ids.count))
                        Text(campaign.config.offer.isEmpty ? "No offer recorded" : campaign.config.offer)
                            .font(.subheadline)
                    }
                }
                if let error = model.campaignsError { Text(error).foregroundStyle(.red) }
            }
            Section {
                Text("Businesses create and manage their campaigns. This owner view is for oversight.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Business analytics")
        .task { await model.load() }
        .refreshable { await model.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh business analytics").disabled(model.isLoading)
            }
        }
    }
}
