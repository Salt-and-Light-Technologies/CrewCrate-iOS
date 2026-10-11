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
            Section("Recipient review") {
                NavigationLink {
                    RecipientReviewView(viewModel: RecipientReviewViewModel(campaign: viewModel.campaign, service: viewModel.service), onSaved: {
                        viewModel.didSave($0); onSaved?($0)
                    })
                } label: { Label("Review and select leads", systemImage: "person.crop.circle.badge.checkmark") }
            }
            Section("Sending readiness") {
                LabeledContent("Status", value: viewModel.campaign.status.replacingOccurrences(of: "_", with: " ").capitalized)
                LabeledContent("Recipients passing checks", value: String(viewModel.campaign.recipientCount ?? 0))
                if viewModel.campaign.config.messageTemplate.isEmpty {
                    Text("Your AI assistant will create the opening message when you check campaign readiness.").foregroundStyle(.secondary)
                } else { Text(viewModel.campaign.config.messageTemplate) }
                ForEach(Array((viewModel.campaign.blockers ?? []).enumerated()), id: \.offset) { _, blocker in
                    Text(blocker).font(.footnote).foregroundStyle(.secondary)
                }
                Button("Check campaign readiness") {
                    Task { if let campaign = await viewModel.prepare() { onSaved?(campaign) } }
                }.disabled(!viewModel.canPrepare)
                Button("Start messages") { Task { await viewModel.start() } }.disabled(!viewModel.canStart)
                Text("SMS provider connection is pending. No messages will be queued or sent until a provider is connected and sending requirements pass.").font(.footnote).foregroundStyle(.secondary)
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
