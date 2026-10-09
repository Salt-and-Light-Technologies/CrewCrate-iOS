import SwiftUI

struct CampaignListView: View {
    @State private var viewModel: CampaignListViewModel
    @State private var creating = false
    init(viewModel: CampaignListViewModel) { _viewModel = State(initialValue: viewModel) }
    var body: some View {
        List {
            Section { Text(viewModel.name).font(.headline); MessagingBoundaryNotice(isDemo: viewModel.isDemo) }
            if let error = viewModel.errorMessage { Section { Text(error).foregroundStyle(.red) } }
            Section("Campaigns") {
                if viewModel.records.isEmpty && !viewModel.isBusy { Text("Create your first campaign.").foregroundStyle(.secondary) }
                ForEach(viewModel.records) { campaign in
                    NavigationLink { CampaignEditorView(viewModel: viewModel.editor(id: campaign.id)) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(campaign.config.name).font(.headline)
                            Text("\(campaign.status.title) · \(campaign.recipientCount) permitted recipients").font(.caption).foregroundStyle(.secondary)
                            if campaign.needsRecheck { Text("Readiness needs another check").font(.caption).foregroundStyle(.orange) }
                        }.padding(.vertical, 4)
                    }
                }
                if viewModel.hasMore { Button("Load more campaigns") { Task { await viewModel.load(more: true) } } }
                if viewModel.isBusy { ProgressView() }
            }
        }.navigationTitle("Campaigns").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("New campaign", systemImage: "plus") { creating = true } } }
            .task { await viewModel.load() }.refreshable { await viewModel.load() }
            .sheet(isPresented: $creating, onDismiss: { Task { await viewModel.load() } }) {
                NavigationStack { CampaignEditorView(viewModel: viewModel.editor()).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { creating = false } } } }
            }
    }
}
