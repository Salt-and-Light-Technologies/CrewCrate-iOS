import SwiftUI

struct DemoOnlineCampaignView: View {
    @State private var viewModel = DemoOnlineCampaignViewModel()
    var body: some View {
        let campaign = viewModel.campaign
        List {
            Section {
                Label("Online · Demo", systemImage: "circle.fill").foregroundStyle(.green)
                Text(campaign.title).font(.title2.bold())
                Text("Fictional campaign preview. Authorization, messages and results are simulated; no contacts are reached.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Performance") {
                LabeledContent("Recipients", value: "\(campaign.recipients)")
                NavigationLink { DemoMessagesSentView(viewModel: viewModel.messagesSent()) } label: {
                    LabeledContent("Messages sent", value: "\(campaign.messagesSent)")
                }
                ProgressView("Contacted", value: viewModel.contactProgress, total: 1)
                LabeledContent("Replies", value: "\(campaign.replies)")
                LabeledContent("Reply rate", value: viewModel.replyRate.formatted(.percent.precision(.fractionLength(0))))
                LabeledContent("Sales handoffs", value: "\(campaign.salesHandoffs)")
                LabeledContent("Conversions", value: "\(campaign.conversions)")
                LabeledContent("Recovered revenue", value: campaign.revenue.formatted(.currency(code: "USD")))
            }
            Section("Campaign details") {
                LabeledContent("AI name", value: campaign.aiName)
                Text(campaign.offer)
                Text(campaign.goal).font(.subheadline).foregroundStyle(.secondary)
                LabeledContent("Sales handoff email", value: campaign.handoffEmail)
            }
            Section("Completed preparation · Demo") {
                Label("Recipients eligible and opted in", systemImage: "checkmark.circle.fill")
                Label("Messaging setup authorized", systemImage: "checkmark.circle.fill")
                Label("Reporting ready", systemImage: "checkmark.circle.fill")
                Label("Agreement finalized", systemImage: "checkmark.circle.fill")
                Label("Partner workspace approved", systemImage: "checkmark.circle.fill")
                Label("Campaign finalized", systemImage: "checkmark.circle.fill")
            }.foregroundStyle(.green)
            Section("Sending plan") {
                LabeledContent("Hours", value: "9:00 AM–5:00 PM")
                LabeledContent("Time zone", value: "America/Chicago")
                LabeledContent("Daily contact limit", value: "100")
                LabeledContent("Maximum follow-ups", value: "1")
            }
            Section("Sample activity") {
                Label("Emma contacted 100 recipients in the latest demo batch", systemImage: "message")
                Label("12 interested leads handed to sales", systemImage: "person.2")
                Label("4 conversions recorded in the latest demo batch", systemImage: "checkmark.seal")
            }
        }
        .navigationTitle("Demo campaign")
        .navigationBarTitleDisplayMode(.inline)
    }
}
