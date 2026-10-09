import SwiftUI
import UniformTypeIdentifiers

struct AccountCSVSection: View {
    @Bindable var viewModel: LeadWorkspaceViewModel
    let onUpload: () -> Void
    var body: some View {
        Section("Upload New CSV Files") {
            if let workspace = viewModel.workspace { Text(workspace.name).font(.subheadline).foregroundStyle(.secondary) }
            if let notice = viewModel.notice { Text(notice).foregroundStyle(.indigo) }
            if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
            ForEach(viewModel.batches) { file in
                VStack(alignment: .leading, spacing: 4) {
                    Label(file.fileName, systemImage: "doc.text")
                    Text("\(file.imported) contacts · \(file.timestamp.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                }
            }
            if viewModel.hasMoreImports { Button("Show more uploaded files") { Task { await viewModel.loadMore("imports") } } }
            Button(viewModel.batches.isEmpty ? "Upload New CSV Files" : "Upload more CSV files", systemImage: "doc.badge.plus") { onUpload() }
                .disabled(viewModel.isBusy || viewModel.workspace?.canImport != true)
            if viewModel.isBusy { ProgressView() }
        }
        .task { await viewModel.load() }
    }
}
