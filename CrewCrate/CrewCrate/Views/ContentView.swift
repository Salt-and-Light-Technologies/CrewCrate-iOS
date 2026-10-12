import SwiftUI

struct ContentView: View {
    @State private var service: SupabaseSession
    @State private var viewModel: AuthenticationViewModel
    init() {
        let service = SupabaseSession()
        _service = State(initialValue: service)
        _viewModel = State(initialValue: AuthenticationViewModel(service: service))
    }

    var body: some View {
        Group {
            if viewModel.isRestoring {
                ProgressView("Restoring your session…")
            } else if viewModel.needsPasswordUpdate {
                NavigationStack { UpdatePasswordView() }
            } else if let identity = viewModel.identity {
                BusinessAccessView(identity: identity, service: service)
                    .id(identity.userID)
            } else {
                NavigationStack { LoginView() }
            }
        }
        .environment(viewModel)
        .environment(WorkerPushState.shared)
        .onChange(of: viewModel.identity?.userID) { _, userID in
            if userID != nil { WorkerPushState.shared.activate() }
        }
        .task { await viewModel.restore() }
        .onOpenURL { url in Task { await viewModel.handleCallback(url) } }
        .alert("CrewCrate", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
            Button("OK", role: .cancel) { viewModel.notice = nil }
        } message: {
            Text(viewModel.notice ?? "")
        }
        .overlay {
            if viewModel.isBusy && !viewModel.isRestoring {
                ProgressView().padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

#Preview { ContentView() }
