import SwiftUI

struct SavedCampaignDetailsView: View {
    @State private var viewModel: SavedCampaignViewModel
    var onSaved: ((CampaignSummary) -> Void)?
    init(campaign: CampaignSummary, service: any CampaignServicing, onSaved: ((CampaignSummary) -> Void)? = nil) {
        _viewModel = State(initialValue: SavedCampaignViewModel(campaign: campaign, service: service))
        self.onSaved = onSaved
    }
    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            Section("Campaign details") {
                LabeledContent("Name", value: viewModel.campaign.config.name)
                LabeledContent("Campaign leads", value: String(viewModel.campaign.config.leadIDs.count))
                Text(viewModel.campaign.config.offer.isEmpty ? "No offer entered" : viewModel.campaign.config.offer)
            }
            Section("AI assistant") {
                LabeledContent("AI name", value: viewModel.campaign.config.aiName ?? "CrewCrate Assistant")
                Text(viewModel.campaign.config.aiBrief ?? "No instructions entered")
                Button("Test AI", systemImage: "bubble.left.and.bubble.right") { viewModel.showsTest = true }
                    .disabled(viewModel.isLoading)
            }
            Section("Sales handoff") {
                Text(viewModel.campaign.config.qualification.isEmpty ? "No qualification rules entered" : viewModel.campaign.config.qualification)
                LabeledContent("Sales email", value: viewModel.campaign.config.handoffEmail)
            }
            if ["paused", "archived"].contains(viewModel.campaign.status) {
                Section { Text("Paused campaigns must be resumed before editing. Archived campaigns cannot be edited.").foregroundStyle(.secondary) }
            }
            if let error = viewModel.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Reload campaign") { Task { await viewModel.load() } }
                }
            }
        }
        .navigationTitle("Campaign details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { viewModel.showsEditor = true }.disabled(!viewModel.canEdit)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .overlay { if viewModel.isLoading { ProgressView() } }
        .fullScreenCover(isPresented: $viewModel.showsEditor) {
            CampaignDetailsView(viewModel: CampaignDetailsViewModel(service: viewModel.service, campaign: viewModel.campaign), onSaved: {
                viewModel.didSave($0); onSaved?($0)
            })
        }
        .sheet(isPresented: $viewModel.showsTest) {
            AITestView(viewModel: AITestViewModel(service: viewModel.service, partnerID: viewModel.campaign.partnerID, campaignID: viewModel.campaign.id))
        }
    }
}
