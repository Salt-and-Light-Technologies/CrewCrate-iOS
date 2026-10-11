import SwiftUI

struct ConversationTrackingView: View {
    @State private var viewModel: ConversationViewModel
    init(viewModel: ConversationViewModel) { _viewModel = State(initialValue: viewModel) }
    var body: some View {
        @Bindable var model = viewModel
        Form {
            Section { Text("Manual record only. Status is entered by your team; it is not a delivery receipt or verified sale.").font(.subheadline).foregroundStyle(.secondary) }
            if let error = viewModel.errorMessage { Section { Text(error).foregroundStyle(.red) } }
            Section("Update follow-up") {
                Picker("Status", selection: $model.status) { ForEach(ConversationStatus.allCases) { Text($0.title).tag($0) } }
                TextField("Internal note", text: $model.note, axis: .vertical).lineLimit(3...8)
                Button("Save status and note") { Task { await viewModel.save() } }
            }
            Section("Recorded history") {
                ForEach(viewModel.notes) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.status.title).font(.headline)
                        Text(note.note)
                        Text("\(note.actorName) · \(note.timestamp.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if viewModel.more { Button("Load more notes") { Task { await viewModel.load(more: true) } } }
                if viewModel.isBusy { ProgressView() }
            }
        }.disabled(viewModel.isBusy).navigationTitle("Tracking detail").navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }.refreshable { await viewModel.load() }
    }
}
