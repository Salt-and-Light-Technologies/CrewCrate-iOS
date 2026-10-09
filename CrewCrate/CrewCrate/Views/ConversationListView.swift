import SwiftUI

struct ConversationListView: View {
    @State private var viewModel: ConversationListViewModel
    init(viewModel: ConversationListViewModel) { _viewModel = State(initialValue: viewModel) }
    var body: some View {
        @Bindable var model = viewModel
        List {
            Section { Text("Manual follow-up tracking").font(.headline); Text("These are internal records, not SMS conversations or verified appointments. No messages are sent or received.").font(.subheadline).foregroundStyle(.secondary) }
            if let error = viewModel.errorMessage { Section { Text(error).foregroundStyle(.red) } }
            Section("Start tracking a recipient") {
                Picker("Recipient", selection: $model.selectedLead) {
                    Text("Choose").tag(UUID?.none)
                    ForEach(viewModel.recipients) { Text($0.name.isEmpty ? $0.phone : $0.name).tag(Optional($0.id)) }
                }
                TextField("Internal note", text: $model.note, axis: .vertical).lineLimit(3...6)
                Button("Create tracking record") { Task { await viewModel.create() } }
            }
            Section("Tracking records") {
                if viewModel.records.isEmpty { Text("No manual records yet.").foregroundStyle(.secondary) }
                ForEach(viewModel.records) { record in
                    NavigationLink { ConversationTrackingView(viewModel: viewModel.detail(record)) } label: {
                        VStack(alignment: .leading) { Text(viewModel.recipientName(record.leadID)).font(.headline); Text(record.status.title).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if viewModel.more { Button("Load more records") { Task { await viewModel.load(more: true) } } }
                if viewModel.isBusy { ProgressView() }
            }
        }.disabled(viewModel.isBusy).navigationTitle("Follow-up tracking").navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }.refreshable { await viewModel.load() }
    }
}
