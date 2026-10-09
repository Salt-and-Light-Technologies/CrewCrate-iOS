import SwiftUI

struct CampaignWorkspacesView: View {
    @Bindable var viewModel: CampaignWorkspacesViewModel
    var body: some View {
        NavigationStack {
            List {
                Section { MessagingBoundaryNotice(isDemo: viewModel.isDemo) }
                if let error = viewModel.errorMessage { Section { Text(error).foregroundStyle(.red) } }
                Section("Partner campaigns") {
                    if viewModel.isBusy { ProgressView() }
                    ForEach(viewModel.workspaces) { workspace in
                        NavigationLink { CampaignListView(viewModel: viewModel.list(workspace)) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(workspace.name).font(.headline)
                                PartnerStatusBadge(status: workspace.status)
                                Text("Partner-managed plans · owner visibility").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }.navigationTitle("Campaigns")
                .task { await viewModel.load() }.refreshable { await viewModel.load() }
        }.tint(.indigo)
    }
}
