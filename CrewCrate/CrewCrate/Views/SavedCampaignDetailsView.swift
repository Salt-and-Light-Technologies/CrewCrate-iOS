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
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.campaign.config.name).font(.title2.bold())
                    Text(viewModel.campaign.config.offer.isEmpty ? "Add an offer to tell people what your business can do for them." : viewModel.campaign.config.offer).foregroundStyle(.secondary)
                    Label("\(viewModel.campaign.config.leadIDs.count) contacts in this campaign", systemImage: "person.2")
                        .font(.subheadline)
                }.padding(.vertical, 8)
            }
            Section("Manage your campaign") {
                Button { viewModel.showsEditor = true } label: {
                    CrewTaskLabel(title: "Campaign setup", subtitle: "Change your offer, assistant or sending hours", symbol: "slider.horizontal.3")
                }.disabled(!viewModel.canEdit)
                NavigationLink {
                    RecipientReviewView(viewModel: RecipientReviewViewModel(campaign: viewModel.campaign, service: viewModel.service), onSaved: {
                        viewModel.didSave($0); onSaved?($0)
                    })
                } label: {
                    CrewTaskLabel(title: "Choose contacts", subtitle: "Pick who should receive your messages", symbol: "person.2")
                }
                Button { viewModel.showsTest = true } label: {
                    CrewTaskLabel(title: "Try your assistant", subtitle: "Have a practice conversation. No texts are sent.", symbol: "bubble.left.and.bubble.right")
                }.disabled(viewModel.isLoading)
            }
            Section {
                DisclosureGroup("Assistant and team details") {
                    LabeledContent("Assistant", value: viewModel.campaign.config.aiName?.isEmpty == false ? viewModel.campaign.config.aiName! : "CrewCrate Assistant")
                    Text(viewModel.campaign.config.aiBrief?.isEmpty == false ? viewModel.campaign.config.aiBrief! : "No instructions added yet.")
                    Text(viewModel.campaign.config.qualification.isEmpty ? "Add when your team should take over in Campaign setup." : viewModel.campaign.config.qualification)
                    LabeledContent("Team email", value: viewModel.campaign.config.handoffEmail)
                }
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
                .buttonStyle(CrewPrimaryButtonStyle())
                .disabled(viewModel.isLoading)
            } footer: {
                Text("Connect an SMS provider to start sending messages.")
            }
        }
        .navigationTitle("Campaign details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit campaign") { viewModel.showsEditor = true }.disabled(!viewModel.canEdit)
                    Button("Remove all contacts", role: .destructive) { confirmsRemoveList = true }
                        .disabled(!viewModel.canEdit || viewModel.campaign.config.leadIDs.isEmpty || viewModel.campaign.ownerHold == true)
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Campaign options")
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
