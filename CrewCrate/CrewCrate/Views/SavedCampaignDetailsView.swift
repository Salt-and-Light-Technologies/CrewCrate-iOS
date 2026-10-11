import SwiftUI

struct SavedCampaignDetailsView: View {
    let campaign: CampaignSummary
    let service: any CampaignServicing
    @State private var showsTest = false
    var body: some View {
        Form {
            Section("Campaign details") {
                LabeledContent("Name", value: campaign.config.name)
                Text(campaign.config.offer.isEmpty ? "No offer entered" : campaign.config.offer)
            }
            Section("AI assistant") {
                LabeledContent("AI name", value: campaign.config.aiName ?? "CrewCrate Assistant")
                Text(campaign.config.aiBrief ?? "No instructions entered")
                Button("Test AI", systemImage: "bubble.left.and.bubble.right") { showsTest = true }
            }
            Section("Sales handoff") {
                Text(campaign.config.qualification.isEmpty ? "No qualification rules entered" : campaign.config.qualification)
                LabeledContent("Sales email", value: campaign.config.handoffEmail)
            }
        }
        .navigationTitle("Campaign details")
        .sheet(isPresented: $showsTest) {
            AITestView(viewModel: AITestViewModel(service: service, partnerID: campaign.partnerID, campaignID: campaign.id))
        }
    }
}
