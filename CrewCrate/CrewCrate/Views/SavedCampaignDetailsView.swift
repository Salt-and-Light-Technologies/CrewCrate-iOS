import SwiftUI

struct SavedCampaignDetailsView: View {
    @State private var confirmsRemoveList = false
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
            Section("Campaign leads") {
                NavigationLink {
                    RecipientReviewView(viewModel: RecipientReviewViewModel(campaign: viewModel.campaign, service: viewModel.service), onSaved: {
                        viewModel.didSave($0); onSaved?($0)
                    })
                } label: { Label("Edit lead list / Review permissions", systemImage: "person.crop.circle.badge.checkmark") }
                Button("Remove lead list", role: .destructive) { confirmsRemoveList = true }
                    .disabled(!viewModel.canEdit || viewModel.campaign.config.leadIDs.isEmpty || viewModel.campaign.ownerHold == true)
                Text("Edit the selected recipients or remove this list from the campaign. Business contacts and opt-outs are preserved.").font(.footnote).foregroundStyle(.secondary)
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
            Section {
                Button("Start messages", systemImage: "paperplane.fill") {
                    viewModel.showSMSConnectionNotice()
                }
                .disabled(viewModel.isLoading)
            } footer: {
                Text("Connect an SMS provider to start sending messages.")
            }
        }
        .navigationTitle("Campaign details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { viewModel.showsEditor = true }.disabled(!viewModel.canEdit)
            }
        }
        .confirmationDialog("Remove all leads from this campaign?", isPresented: $confirmsRemoveList, titleVisibility: .visible) {
            Button("Remove lead list", role: .destructive) {
                Task { if let updated = await viewModel.removeLeadList() { onSaved?(updated) } }
            }
        } message: { Text("This resets campaign preparation. Contact records and permissions are kept.") }
        .onAppear { Task { await viewModel.load() } }
        .refreshable { await viewModel.load() }
        .alert("Campaign messages", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
            Button("OK", role: .cancel) { viewModel.notice = nil }
        } message: { Text(viewModel.notice ?? "") }
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
