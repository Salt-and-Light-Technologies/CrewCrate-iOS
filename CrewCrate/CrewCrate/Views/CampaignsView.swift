import SwiftUI

struct CampaignsView: View {
    @State var viewModel: CampaignsViewModel
    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if viewModel.isLoading && !viewModel.hasLoaded {
                ProgressView("Loading campaigns…")
            } else if let error = viewModel.error {
                ContentUnavailableView {
                    Label("Couldn’t load campaigns", systemImage: "wifi.exclamationmark")
                } description: { Text(error) } actions: {
                    Button("Try again") { Task { await viewModel.load() } }
                }
            } else if viewModel.campaigns.isEmpty {
                ContentUnavailableView {
                    Label("Create your first campaign", systemImage: "megaphone")
                } description: {
                    Text(viewModel.workspaces.isEmpty
                        ? "First, open Account and set up your business."
                        : "Describe your offer, add contacts, and try your assistant before sending anything.")
                } actions: {
                    if !viewModel.workspaces.isEmpty {
                        Button("Create a campaign") { viewModel.showsDetails = true }
                            .buttonStyle(CrewPrimaryButtonStyle()).frame(maxWidth: 320)
                    }
                }
            } else {
                List(viewModel.campaigns) { campaign in
                    NavigationLink {
                        SavedCampaignDetailsView(campaign: campaign, service: viewModel.service, onSaved: { viewModel.replace($0) })
                    } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(campaign.config.name).font(.headline)
                        Text(campaign.status == "ready_to_connect" ? "Draft" : campaign.status.capitalized)
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("\(campaign.config.leadIDs.count) contacts").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                    }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .onAppear { Task { await viewModel.load() } }
        .navigationTitle("Campaigns")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { viewModel.showsDetails = true } label: { Label("New campaign", systemImage: "plus") }
                    .accessibilityLabel("Create campaign")
                    .disabled(viewModel.isLoading || !viewModel.hasLoaded)
            }
        }
        .task { if !viewModel.hasLoaded { await viewModel.load() } }
        .fullScreenCover(isPresented: $viewModel.showsDetails, onDismiss: { Task { await viewModel.load() } }) {
            CampaignDetailsView(viewModel: CampaignDetailsViewModel(service: viewModel.service, workspaces: viewModel.workspaces))
        }
    }
}
