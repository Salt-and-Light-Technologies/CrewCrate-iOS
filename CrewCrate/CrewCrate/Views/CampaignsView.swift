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
                    Label("Your campaigns", systemImage: "megaphone")
                } description: {
                    Text(viewModel.workspaces.isEmpty
                        ? "Your account is connected. An assigned workspace is needed to save campaigns."
                        : "Tap the plus button to create your first campaign.")
                }
            } else {
                List(viewModel.campaigns) { campaign in
                    NavigationLink {
                        SavedCampaignDetailsView(campaign: campaign, service: viewModel.service, onSaved: { viewModel.replace($0) })
                    } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(campaign.config.name).font(.headline)
                        Text(campaign.status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline).foregroundStyle(.secondary)
                        if !campaign.config.offer.isEmpty { Text(campaign.config.offer).font(.subheadline) }
                    }.padding(.vertical, 6)
                    }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Campaigns")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { viewModel.showsDetails = true } label: { Image(systemName: "plus") }
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
