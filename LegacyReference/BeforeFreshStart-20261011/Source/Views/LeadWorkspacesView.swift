import SwiftUI
import UniformTypeIdentifiers

struct LeadWorkspacesView: View {
    @Bindable var viewModel: LeadWorkspacesViewModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image("CrateMark").resizable().scaledToFit().frame(width: 44, height: 44).accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text("Recover opportunities").font(.headline)
                            Text("Review lead data across every industry.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if viewModel.isDemo { LeadDemoNotice() }
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red); Button("Try again") { Task { await viewModel.load() } } }
                }
                Section("Partner workspaces") {
                    if viewModel.isLoading && viewModel.workspaces.isEmpty { ProgressView("Loading workspaces…") }
                    else if viewModel.workspaces.isEmpty { Text("No partner workspaces are available.").foregroundStyle(.secondary) }
                    ForEach(viewModel.workspaces) { workspace in
                        NavigationLink(value: workspace.id) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(workspace.name).font(.headline)
                                PartnerStatusBadge(status: workspace.status)
                                Text("\(workspace.totalLeads) stored leads · \(workspace.importCount) imports").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Lead workspaces")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .toolbar { Button("Refresh", systemImage: "arrow.clockwise") { Task { await viewModel.load() } }.disabled(viewModel.isLoading) }
            .navigationDestination(for: UUID.self) { id in
                LeadWorkspaceView(viewModel: viewModel.detail(id: id)).onDisappear { Task { await viewModel.load() } }
            }
        }.tint(.indigo)
    }
}
