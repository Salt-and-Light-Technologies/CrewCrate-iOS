import SwiftUI
import UniformTypeIdentifiers

struct ConnectedAccountView: View {
    @State private var choosingFile = false
    @State private var uploadWorkspace: LeadWorkspaceViewModel?
    @State private var reviewingWorkspace: LeadWorkspaceViewModel?
    @Bindable var session: SessionViewModel
    var body: some View {
        NavigationStack {
            Form {
                Section("Connected account") {
                    Text(session.email.isEmpty ? "CrewCrate account" : session.email)
                    if let identity = session.identity {
                        Text(identity.is_owner ? "Owner access verified by CrewCrate" : "Partner access verified by CrewCrate").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let experience = session.experience {
                    ForEach(experience.handoffDirectories) { directory in AccountSalesHandoffSection(viewModel: directory) }
                    ForEach(experience.contactWorkspaces) { workspace in
                        AccountCSVSection(viewModel: workspace) {
                            workspace.clearImportError()
                            uploadWorkspace = workspace
                            choosingFile = true
                        }
                    }
                }
                Section { Button("Sign out", role: .destructive) { Task { await session.signOut() } }.disabled(session.isBusy) }
            }.navigationTitle("Account")
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.commaSeparatedText, .plainText], allowsMultipleSelection: false) { result in
            guard let workspace = uploadWorkspace else { return }
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await workspace.uploadSelectedFile(url)
                        if workspace.requiresColumnMapping { reviewingWorkspace = workspace }
                    }
                }
            case .failure(let error): workspace.reportError(error)
            }
        }
        .sheet(item: $reviewingWorkspace, onDismiss: {
            uploadWorkspace?.cancelImport()
            if let workspace = uploadWorkspace { Task { await workspace.load() } }
        }) { workspace in
            NavigationStack {
                LeadWorkspaceView(viewModel: workspace)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { reviewingWorkspace = nil } } }
            }
        }
    }
}
